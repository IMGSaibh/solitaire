extends Control

var game_state: GameState

@onready var stock_view: PileView = $Board/Stock
@onready var waste_view: PileView = $Board/Waste
# var selected_waste_card: CardData = null
var selected_cards: Array[CardData] = []
var selected_source_pile: CardPile = null

@onready var foundation_views: Array[PileView] = [
	$Board/Foundation1,
	$Board/Foundation2,
	$Board/Foundation3,
	$Board/Foundation4
]

@onready var tableau_views: Array[PileView] = [
	$Board/Tableau1,
	$Board/Tableau2,
	$Board/Tableau3,
	$Board/Tableau4,
	$Board/Tableau5,
	$Board/Tableau6,
	$Board/Tableau7
]

func _ready() -> void:
	print("Solitaire gestartet!")
	game_state = GameState.new()
	game_state.new_game()
	stock_view.pile_clicked.connect(_on_stock_clicked)
	waste_view.pile_clicked.connect(_on_waste_clicked)
	
	for i in range(tableau_views.size()):
		tableau_views[i].pile_clicked.connect(_on_tableau_clicked.bind(i))

		tableau_views[i].card_clicked.connect(
		_on_tableau_card_clicked.bind(i)
		)	

	refresh_board()

	print("Stock: ", game_state.stock.size())

	for i in range(game_state.tableau.size()):
		print("---- Tableau ", i + 1)

		for card in game_state.tableau[i].cards:
			print(
				card.get_suit_name(),
				" ",
				card.get_rank_name(),
				" face_up=",
				card.face_up
			)

func refresh_board() -> void:
	stock_view.setup(game_state.stock)
	waste_view.setup(game_state.waste)

	for i in range(4):
		foundation_views[i].setup(
			game_state.foundations[i]
		)

	for i in range(7):
		tableau_views[i].setup(
			game_state.tableau[i]
		)

func _on_stock_clicked(_pile_view: PileView) -> void:
	draw_card_from_stock()

func draw_card_from_stock() -> void:
	if game_state.stock.is_empty():
		recycle_waste_to_stock()
		return

	var card := game_state.stock.remove_top_card()

	card.face_up = true
	game_state.waste.add_card(card)

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

	selected_cards = [
		game_state.waste.get_top_card()
	]

	selected_source_pile = game_state.waste


func _on_tableau_clicked(
	_pile_view: PileView,
	tableau_index: int
) -> void:

	if selected_cards.is_empty():
		return


	var target_pile := game_state.tableau[tableau_index]

	if target_pile == selected_source_pile:
		clear_selection()
		return

	if not KlondikeRules.can_move_sequence_to_tableau(
		selected_cards,
		target_pile
	):
		print("Zug nicht erlaubt")
		return

	move_selected_cards(target_pile)

func _on_tableau_card_clicked(
	_pile_view: PileView,
	card_index: int,
	tableau_index: int
) -> void:

	var pile := game_state.tableau[tableau_index]

	if not KlondikeRules.can_pick_up_tableau_sequence(
		pile,
		card_index
	):
		print("Diese Kartenfolge darf nicht aufgenommen werden")
		return

	selected_cards.clear()

	for i in range(card_index, pile.cards.size()):
		selected_cards.append(pile.cards[i])

	selected_source_pile = pile

	print("Ausgewählt: ", selected_cards.size(), " Karten")

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

func _flip_new_top_card(pile: CardPile) -> void:
	if pile.type != CardPile.Type.TABLEAU:
		return

	if pile.is_empty():
		return

	var top_card := pile.get_top_card()

	if not top_card.face_up:
		top_card.face_up = true
