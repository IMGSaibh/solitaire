extends Control

var game_service: GameService
var game_state: GameState
var selected_source_pile: CardPile
var selected_start_index := -1
var win_animation_started := false

@onready var stock_view: PileView = $Board/Stock
@onready var waste_view: PileView = $Board/Waste
@onready var foundation_views: Array[PileView] = [$Board/Foundation1, $Board/Foundation2, $Board/Foundation3, $Board/Foundation4]
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


func _ready() -> void:
	game_service = GameService.new()
	game_state = game_service.state
	_connect_signals_to_views()
	new_game()


func _connect_signals_to_views() -> void:
	stock_view.pile_clicked.connect(_on_stock_clicked)
	stock_view.card_clicked.connect(_on_card_clicked)
	waste_view.pile_clicked.connect(_on_waste_clicked)
	waste_view.card_clicked.connect(_on_card_clicked)
	waste_view.card_released.connect(_on_card_released)
	waste_view.cards_dropped.connect(_on_cards_dropped)

	for view in tableau_views:
		view.card_clicked.connect(_on_card_clicked)
		view.card_released.connect(_on_card_released)
		view.cards_dropped.connect(_on_cards_dropped)

	for view in foundation_views:
		view.card_clicked.connect(_on_card_clicked)
		view.card_released.connect(_on_card_released)
		view.cards_dropped.connect(_on_cards_dropped)


func new_game() -> void:
	win_animation.stop()
	win_animation_started = false
	game_service.new_game()
	clear_selection()
	refresh_board()


func refresh_board() -> void:
	var reusable_views: Dictionary = { }
	for view in _all_pile_views():
		for card_view in view.card_views:
			if card_view.card != null:
				reusable_views[card_view.card] = card_view

	stock_view.setup_with_pool(game_state.stock, reusable_views)
	waste_view.setup_with_pool(game_state.waste, reusable_views)
	for i in range(foundation_views.size()):
		foundation_views[i].setup_with_pool(game_state.foundations[i], reusable_views)
	for i in range(tableau_views.size()):
		tableau_views[i].setup_with_pool(game_state.tableau[i], reusable_views)

	for unused_view in reusable_views.values():
		if is_instance_valid(unused_view):
			unused_view.queue_free()


func _select_cards(pile_view: PileView, card_index: int) -> void:
	clear_selection()
	var pile := pile_view.pile
	if pile == null or card_index < 0 or card_index >= pile.cards.size():
		return

	match pile.type:
		CardPile.Type.TABLEAU:
			if not KlondikeRules.can_pick_up_tableau_sequence(pile, card_index):
				return
		CardPile.Type.WASTE, CardPile.Type.FOUNDATION:
			if card_index != pile.cards.size() - 1 or not pile.cards[card_index].face_up:
				return
		_:
			return

	selected_source_pile = pile
	selected_start_index = card_index
	pile_view.outline_cards(card_index)


func clear_selection() -> void:
	selected_source_pile = null
	selected_start_index = -1
	for view in _all_pile_views():
		view.clear_outlines()


func _on_card_clicked(pile_view: PileView, card_index: int) -> void:
	match pile_view.pile.type:
		CardPile.Type.STOCK:
			_on_stock_clicked(pile_view)
		CardPile.Type.WASTE:
			_select_cards(pile_view, card_index)
		CardPile.Type.TABLEAU:
			_select_cards(pile_view, card_index)
		CardPile.Type.FOUNDATION:
			_select_cards(pile_view, card_index)


func _on_stock_clicked(_pile_view: PileView) -> void:
	clear_selection()
	if game_service.draw_from_stock():
		refresh_board()


func _on_waste_clicked(pile_view: PileView) -> void:
	if not game_state.waste.is_empty():
		_select_cards(pile_view, game_state.waste.cards.size() - 1)


func _on_card_released(pile_view: PileView, card_index: int) -> void:
	if selected_source_pile != pile_view.pile or selected_start_index != card_index:
		return
	auto_move_selected_cards()


func _on_cards_dropped(data: CardDragData, target_pile: CardPile) -> void:
	if data == null:
		return
	var result := game_service.try_move(data.source_pile, data.start_index, target_pile)
	if not result.succeeded:
		return
	_after_successful_move(target_pile)


func auto_move_selected_cards() -> void:
	if selected_source_pile == null or selected_start_index < 0:
		return
	var target := game_service.find_automatic_target(selected_source_pile, selected_start_index)
	if target == null:
		clear_selection()
		return
	var result := game_service.try_move(selected_source_pile, selected_start_index, target)
	if result.succeeded:
		_after_successful_move(target)


func _after_successful_move(target_pile: CardPile) -> void:
	clear_selection()
	refresh_board()
	if target_pile.type == CardPile.Type.FOUNDATION:
		check_for_win()


func undo() -> void:
	if game_service.undo():
		win_animation.stop()
		win_animation_started = false
		clear_selection()
		refresh_board()


func redo() -> void:
	if game_service.redo():
		clear_selection()
		refresh_board()
		check_for_win()


func save_game() -> Error:
	return game_service.save_game()


func load_game() -> Error:
	var error := game_service.load_game()
	if error == OK:
		win_animation.stop()
		win_animation_started = false
		clear_selection()
		refresh_board()
		check_for_win()
	return error


func check_for_win() -> void:
	if win_animation_started or not is_game_won():
		return
	win_animation_started = true
	win_animation.play(game_state.foundations, foundation_views)


func is_game_won() -> bool:
	for foundation in game_state.foundations:
		if foundation.size() != GameState.MAX_RANK:
			return false
	return true


func _all_pile_views() -> Array[PileView]:
	var result: Array[PileView] = [stock_view, waste_view]
	result.append_array(foundation_views)
	result.append_array(tableau_views)
	return result


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed:
		match event.keycode:
			KEY_Z:
				undo()
			KEY_Y:
				redo()
			KEY_S:
				save_game()
			KEY_L:
				load_game()
			KEY_N:
				new_game()
	elif OS.is_debug_build() and event.keycode == KEY_W:
		_start_test_win_animation()


func _start_test_win_animation() -> void:
	var test_foundations: Array[CardPile] = []
	for i in range(GameState.FOUNDATION_COUNT):
		test_foundations.append(CardPile.new(CardPile.Type.FOUNDATION))
	var deck := game_state.create_deck()
	for card in deck:
		card.face_up = true
		test_foundations[card.suit].add_card(card)
	win_animation.play(test_foundations, foundation_views)
