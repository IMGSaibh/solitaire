extends Control

var game_service: GameService
var game_state: GameState
var selected_source_pile: CardPile
var selected_start_index := -1
var win_animation_started := false
var auto_finish_running := false
var auto_finish_run_id := 0

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
@onready var button_ui: ButtonUi = $ButtonUi
@onready var move_card_audio: AudioStreamPlayer = $MoveCardAudio
@onready var score_label: Label = $ScorePanel/ScoreLabel


func _ready() -> void:
	game_service = GameService.new()
	game_state = game_service.state
	_connect_signals_to_views()
	new_game()


func _connect_signals_to_views() -> void:
	button_ui.new_game_requested.connect(new_game)
	button_ui.auto_finish_requested.connect(_on_auto_finish_requested)
	button_ui.undo_requested.connect(undo)
	button_ui.save_requested.connect(save_game)
	button_ui.load_requested.connect(load_game)
	stock_view.pile_clicked.connect(_on_stock_clicked)
	stock_view.card_clicked.connect(_on_card_clicked)
	waste_view.pile_clicked.connect(_on_waste_clicked)
	waste_view.card_clicked.connect(_on_card_clicked)
	waste_view.card_released.connect(_on_card_released)
	for view in tableau_views:
		view.card_clicked.connect(_on_card_clicked)
		view.card_released.connect(_on_card_released)
		view.cards_dropped.connect(_on_cards_dropped)

	for view in foundation_views:
		view.card_clicked.connect(_on_card_clicked)
		view.card_released.connect(_on_card_released)
		view.cards_dropped.connect(_on_cards_dropped)


func new_game() -> void:
	_cancel_auto_finish()
	win_animation.stop()
	win_animation_started = false
	game_service.new_game()
	clear_selection()
	refresh_board()


func refresh_board(animate_moved_cards: bool = false) -> void:
	score_label.text = "Punkte: %d" % game_state.score
	var reusable_views: Dictionary = { }
	var all_pile_views: Array[PileView] = [stock_view, waste_view]
	all_pile_views.append_array(foundation_views)
	all_pile_views.append_array(tableau_views)

	for view in all_pile_views:
		for card_view in view.card_views:
			if card_view.card != null:
				reusable_views[card_view.card] = card_view

	stock_view.setup(game_state.stock, reusable_views, animate_moved_cards)
	waste_view.setup(game_state.waste, reusable_views, animate_moved_cards)
	for i in range(foundation_views.size()):
		foundation_views[i].setup(game_state.foundations[i], reusable_views, animate_moved_cards)
	for i in range(tableau_views.size()):
		tableau_views[i].setup(game_state.tableau[i], reusable_views, animate_moved_cards)

	for unused_view in reusable_views.values():
		if is_instance_valid(unused_view):
			unused_view.queue_free()

	button_ui.set_auto_finish_available(game_service.can_auto_finish() and not game_state.is_game_won() and not auto_finish_running)


func _on_auto_finish_requested() -> void:
	if auto_finish_running or not game_service.can_auto_finish():
		return
	auto_finish_running = true
	auto_finish_run_id += 1
	var run_id := auto_finish_run_id
	clear_selection()
	refresh_board()

	while run_id == auto_finish_run_id and _auto_finish_next_card():
		await get_tree().create_timer(CardView.AUTO_MOVE_DURATION).timeout

	if run_id != auto_finish_run_id:
		return
	auto_finish_running = false
	refresh_board()
	check_for_win()


func _auto_finish_next_card() -> bool:
	var source_views: Array[PileView] = [waste_view]
	source_views.append_array(tableau_views)

	for source_view in source_views:
		var source := source_view.pile
		if source == null or source.is_empty():
			continue
		var card_index := source.cards.size() - 1
		for foundation in game_state.foundations:
			if not KlondikeRules.can_move(source, card_index, foundation):
				continue
			var result := game_service.try_move(source, card_index, foundation)
			if result.succeeded:
				_after_successful_move(foundation, result.points_awarded)
				return true
	return false


func _cancel_auto_finish() -> void:
	auto_finish_run_id += 1
	auto_finish_running = false


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
	var all_pile_views: Array[PileView] = [stock_view, waste_view]
	all_pile_views.append_array(foundation_views)
	all_pile_views.append_array(tableau_views)
	for view in all_pile_views:
		view.clear_outlines()


func _on_card_clicked(pile_view: PileView, card_index: int) -> void:
	if auto_finish_running:
		return
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
	if auto_finish_running:
		return
	clear_selection()
	if game_service.draw_from_stock():
		refresh_board()


func _on_waste_clicked(pile_view: PileView) -> void:
	if auto_finish_running:
		return
	if not game_state.waste.is_empty():
		_select_cards(pile_view, game_state.waste.cards.size() - 1)


func _on_card_released(pile_view: PileView, card_index: int) -> void:
	if auto_finish_running:
		return
	if selected_source_pile != pile_view.pile or selected_start_index != card_index:
		return
	auto_move_selected_cards()


func _on_cards_dropped(data: CardDragData, target_pile: CardPile) -> void:
	if auto_finish_running or data == null:
		return
	var result := game_service.try_move(data.source_pile, data.start_index, target_pile)
	if not result.succeeded:
		return
	_after_successful_move(target_pile, result.points_awarded)


func auto_move_selected_cards() -> void:
	if selected_source_pile == null or selected_start_index < 0:
		return
	var target := game_service.find_automatic_target(selected_source_pile, selected_start_index)
	if target == null:
		clear_selection()
		return
	var result := game_service.try_move(selected_source_pile, selected_start_index, target)
	if result.succeeded:
		_after_successful_move(target, result.points_awarded)


func _after_successful_move(target_pile: CardPile, points_awarded: int = 0) -> void:
	clear_selection()
	refresh_board(true)
	_play_move_sound()
	_show_score_on_pile(target_pile, points_awarded)


func _show_score_on_pile(card_pile: CardPile, points: int) -> void:
	if card_pile.type == CardPile.Type.FOUNDATION:
		var foundation_index := game_state.foundations.find(card_pile)
		foundation_views[foundation_index].show_score_popup(points)
	if card_pile.type == CardPile.Type.TABLEAU:
		var tableau_index := game_state.tableau.find(card_pile)
		tableau_views[tableau_index].show_score_popup(points)


func _play_move_sound() -> void:
	move_card_audio.play()


func undo() -> void:
	_cancel_auto_finish()
	if game_service.undo():
		win_animation.stop()
		win_animation_started = false
		clear_selection()
		refresh_board()


func save_game() -> Error:
	return game_service.save_game()


func load_game() -> Error:
	_cancel_auto_finish()
	var error := game_service.load_game()
	if error == OK:
		win_animation.stop()
		win_animation_started = false
		clear_selection()
		refresh_board()
		check_for_win()
	return error


func check_for_win() -> void:
	if win_animation_started or not game_state.is_game_won():
		return
	win_animation_started = true
	win_animation.play(game_state.foundations, foundation_views)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed:
		match event.keycode:
			KEY_Z:
				undo()
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
