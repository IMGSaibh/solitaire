extends Control

var game_state: GameState
var selected_cards: Array[CardData] = []
var selected_source_pile: CardPile = null

@onready var stock_view: PileView = $Board/Stock
@onready var waste_view: PileView = $Board/Waste
@onready var foundation_views: Array[PileView] = [
	$Board/Foundation1,
	$Board/Foundation2,
	$Board/Foundation3,
	$Board/Foundation4,
]
@onready var tableau_views: Array[PileView] = [
	$Board/Tableau1,
	$Board/Tableau2,
	$Board/Tableau3,
	$Board/Tableau4,
	$Board/Tableau5,
	$Board/Tableau6,
	$Board/Tableau7,
]
@onready var win_animation: WinAnimation = $WinAnimationLayer

var win_animation_started := false


func _ready() -> void:
	print("Solitaire gestartet!")
	print("================================")
	game_state = GameState.new()
	game_state.new_game()
	stock_view.pile_clicked.connect(_on_stock_clicked)
	stock_view.card_clicked.connect(_on_card_clicked)
	waste_view.pile_clicked.connect(_on_waste_clicked)
	waste_view.card_clicked.connect(_on_card_clicked)
	waste_view.card_double_clicked.connect(_on_waste_card_double_clicked)
	waste_view.cards_dropped.connect(_on_cards_dropped)

	for i in range(tableau_views.size()):
		tableau_views[i].pile_clicked.connect(_on_tableau_empty_clicked.bind(i))
		tableau_views[i].card_clicked.connect(_on_card_clicked)
		tableau_views[i].card_double_clicked.connect(_on_tableau_card_double_clicked.bind(i))
		tableau_views[i].cards_dropped.connect(_on_cards_dropped)

	for i in range(foundation_views.size()):
		foundation_views[i].pile_clicked.connect(_on_foundation_clicked.bind(i))
		foundation_views[i].card_clicked.connect(_on_card_clicked)
		foundation_views[i].cards_dropped.connect(_on_cards_dropped)

	refresh_board()


func refresh_board() -> void:
	stock_view.setup(game_state.stock)
	waste_view.setup(game_state.waste)

	for i in range(4):
		foundation_views[i].setup(game_state.foundations[i])

	for i in range(7):
		tableau_views[i].setup(game_state.tableau[i])


func _on_card_clicked(pile_view: PileView, card_index: int) -> void:
	match pile_view.pile.type:
		CardPile.Type.STOCK:
			_on_stock_clicked(pile_view)

		CardPile.Type.WASTE:
			_on_waste_clicked(pile_view)

		CardPile.Type.TABLEAU:
			var tableau_index := tableau_views.find(pile_view)
			if tableau_index >= 0:
				_on_tableau_card_clicked(pile_view, card_index, tableau_index)

		CardPile.Type.FOUNDATION:
			var foundation_index := foundation_views.find(pile_view)
			if foundation_index >= 0:
				_on_foundation_card_clicked(pile_view, card_index, foundation_index)


func _on_stock_clicked(_pile_view: PileView) -> void:
	draw_card_from_stock()


func draw_card_from_stock() -> void:
	print("Ziehe Karte vom Stock")
	if game_state.stock.is_empty():
		print("Stock ist leer, recyceln des Abwurfstapels")
		recycle_waste_to_stock()
		return

	var card := game_state.stock.remove_top_card()

	card.face_up = true
	game_state.waste.add_card(card)
	clear_selection()
	stock_view.refresh()
	waste_view.refresh()


func recycle_waste_to_stock() -> void:
	if game_state.waste.is_empty():
		return

	while not game_state.waste.is_empty():
		var card := game_state.waste.remove_top_card()

		card.face_up = false
		game_state.stock.add_card(card)

	stock_view.refresh()
	waste_view.refresh()


func _on_waste_clicked(_pile_view: PileView) -> void:
	if game_state.waste.is_empty():
		return

	selected_cards.clear()
	selected_cards.append(game_state.waste.get_top_card())

	selected_source_pile = game_state.waste

	print("Ausgewählt: ", selected_cards[0].get_suit_name(), " ", selected_cards[0].get_rank_name())


func _on_tableau_empty_clicked(_pile_view: PileView, tableau_index: int) -> void:
	print("Tableau empty angeklickt: ", tableau_index)
	if selected_cards.is_empty():
		return

	var target_pile := game_state.tableau[tableau_index]

	if target_pile == selected_source_pile:
		clear_selection()
		return

	if not KlondikeRules.can_move_sequence_to_tableau(selected_cards, target_pile):
		print("Zug nicht erlaubt")
		print("\n")
		clear_selection()
		return

	move_selected_cards(target_pile)


func _on_tableau_card_clicked(_pile_view: PileView, card_index: int, tableau_index: int) -> void:
	print("Tableau clicked: ", tableau_index, ", Karte ", card_index)
	var pile := game_state.tableau[tableau_index]

	# Es sind bereits Karten ausgewählt:
	# Dann ist dieses Tableau das Ziel des Zuges.
	if not selected_cards.is_empty():
		if pile == selected_source_pile:
			clear_selection()
			return

		if not KlondikeRules.can_move_sequence_to_tableau(selected_cards, pile):
			print("Zug nicht erlaubt")
			print("\n")
			clear_selection()
			return

		move_selected_cards(pile)
		return

	# Noch nichts ausgewählt:
	# Dann versuchen wir, ab dieser Tableau-Karte eine Folge auszuwählen.
	if not KlondikeRules.can_pick_up_tableau_sequence(pile, card_index):
		print("Diese Kartenfolge darf nicht aufgenommen werden")
		return

	selected_cards.clear()

	for i in range(card_index, pile.cards.size()):
		selected_cards.append(pile.cards[i])

	selected_source_pile = pile
	_pile_view.outline_cards(card_index)

	print(
		"Karte clicked: ",
		selected_cards[0].get_suit_name(),
		" ",
		selected_cards[0].get_rank_name(),
		" Anzahl: ",
		selected_cards.size(),
	)
	print("\n")


func move_selected_cards(target_pile: CardPile) -> void:
	if selected_source_pile == null:
		return

	for card in selected_cards:
		selected_source_pile.cards.erase(card)
		target_pile.add_card(card)

	_flip_new_top_card(selected_source_pile)

	clear_selection()
	refresh_board()


func clear_selection() -> void:
	selected_cards.clear()
	selected_source_pile = null


func _on_cards_dropped(
	source_pile: CardPile,
	cards: Array[CardData],
	target_pile: CardPile,
) -> void:
	if source_pile == null or source_pile == target_pile or cards.is_empty():
		return

	var move_is_valid := false

	match target_pile.type:
		CardPile.Type.TABLEAU:
			move_is_valid = KlondikeRules.can_move_sequence_to_tableau(cards, target_pile)

		CardPile.Type.FOUNDATION:
			move_is_valid = (
				cards.size() == 1 and KlondikeRules.can_move_to_foundation(cards[0], target_pile)
			)

	if not move_is_valid:
		return

	for card in cards:
		if not source_pile.cards.has(card):
			return

	for card in cards:
		source_pile.cards.erase(card)
		target_pile.add_card(card)

	_flip_new_top_card(source_pile)
	clear_selection()
	refresh_board()

	if target_pile.type == CardPile.Type.FOUNDATION:
		check_for_win()


func _flip_new_top_card(pile: CardPile) -> void:
	if pile.type != CardPile.Type.TABLEAU:
		return

	if pile.is_empty():
		return

	var top_card := pile.get_top_card()

	if not top_card.face_up:
		top_card.face_up = true


func _on_foundation_clicked(_pile_view: PileView, foundation_index: int) -> void:
	if selected_cards.is_empty():
		return

	var target_pile := game_state.foundations[foundation_index]

	# Nicht auf den eigenen Stapel legen
	if target_pile == selected_source_pile:
		clear_selection()
		return

	if selected_cards.size() != 1:
		print("Nur einzelne Karten dürfen auf die Foundation")
		return

	var card := selected_cards[0]

	if not KlondikeRules.can_move_to_foundation(card, target_pile):
		print("Foundation-Zug nicht erlaubt")
		print("\n")
		return

	move_selected_card_to_foundation(target_pile)


func move_selected_card_to_foundation(target_pile: CardPile) -> void:
	if selected_source_pile == null:
		return

	if selected_cards.size() != 1:
		return

	var card := selected_cards[0]

	selected_source_pile.cards.erase(card)
	target_pile.add_card(card)

	_flip_new_top_card(selected_source_pile)

	clear_selection()
	refresh_board()
	check_for_win()


func _on_waste_card_double_clicked(_pile_view: PileView, card_index: int) -> void:
	if game_state.waste.is_empty():
		return

	# Nur die oberste Waste-Karte darf bewegt werden.
	if card_index != game_state.waste.cards.size() - 1:
		return

	var card := game_state.waste.get_top_card()

	auto_move_to_foundation(card, game_state.waste)


func _on_tableau_card_double_clicked(
	_pile_view: PileView,
	card_index: int,
	tableau_index: int,
) -> void:
	var pile := game_state.tableau[tableau_index]

	if pile.is_empty():
		return

	if card_index != pile.cards.size() - 1:
		return

	var card := pile.get_top_card()

	if not card.face_up:
		return

	auto_move_to_foundation(card, pile)


func auto_move_to_foundation(card: CardData, source_pile: CardPile) -> void:
	for foundation in game_state.foundations:
		if KlondikeRules.can_move_to_foundation(card, foundation):
			source_pile.cards.erase(card)
			foundation.add_card(card)

			_flip_new_top_card(source_pile)

			clear_selection()
			refresh_board()
			check_for_win()
			return


func _on_foundation_card_clicked(
	_pile_view: PileView,
	card_index: int,
	foundation_index: int,
) -> void:
	var pile := game_state.foundations[foundation_index]

	if pile.is_empty():
		return

	if card_index != pile.cards.size() - 1:
		return

	# Es ist noch nichts ausgewählt:
	# Foundation-Karte wird zur Quelle.
	if selected_cards.is_empty():
		selected_cards.clear()
		selected_cards.append(pile.get_top_card())
		selected_source_pile = pile

		print(
			"Foundation-Karte ausgewählt: ",
			selected_cards[0].get_suit_name(),
			" ",
			selected_cards[0].get_rank_name(),
		)
		return


func start_win_animation() -> void:
	win_animation.play(game_state.foundations, foundation_views)


func check_for_win() -> void:
	if win_animation_started or not is_game_won():
		return

	win_animation_started = true
	start_win_animation()


func is_game_won() -> bool:
	for foundation in game_state.foundations:
		if foundation.size() != 13:
			return false

	return true

# ============================================================================
# Debug implementation for animation test. Only available in debug builds.
# ============================================================================


func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event is InputEventKey:
		if event.keycode == KEY_W and event.pressed and not event.echo:
			_start_test_win_animation()


func _start_test_win_animation() -> void:
	var test_foundations: Array[CardPile] = []

	for i in range(4):
		test_foundations.append(CardPile.new(CardPile.Type.FOUNDATION))

	var deck := game_state.create_deck()

	for card in deck:
		card.face_up = true
		test_foundations[card.suit].add_card(card)

	win_animation.play(test_foundations, foundation_views)
