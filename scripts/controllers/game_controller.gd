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
	_cancel_auto_finish()
	win_animation.stop()
	win_animation_started = false
	game_service.new_game()
	clear_selection()
	refresh_board()


func refresh_board() -> void:
	score_label.text = "Punkte: %d" % game_state.score
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

	button_ui.set_auto_finish_available(
		game_service.can_auto_finish() and not is_game_won() and not auto_finish_running,
	)


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
			var card_view := source_view.card_views[card_index]
			var start_positions: Dictionary = {card_view: card_view.global_position}
			var result := game_service.try_move(source, card_index, foundation)
			if result.succeeded:
				_after_successful_move(foundation, start_positions)
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
	for view in _all_pile_views():
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
	auto_move_selected_cards(pile_view)


func _on_cards_dropped(data: CardDragData, target_pile: CardPile) -> void:
	if auto_finish_running or data == null:
		return
	var result := game_service.try_move(data.source_pile, data.start_index, target_pile)
	if not result.succeeded:
		return
	_after_successful_move(target_pile)


func auto_move_selected_cards(source_view: PileView) -> void:
	if selected_source_pile == null or selected_start_index < 0:
		return
	var target := game_service.find_automatic_target(selected_source_pile, selected_start_index)
	if target == null:
		clear_selection()
		return
	var start_positions: Dictionary = { }
	for i in range(selected_start_index, source_view.card_views.size()):
		var card_view := source_view.card_views[i]
		start_positions[card_view] = card_view.global_position
	var result := game_service.try_move(selected_source_pile, selected_start_index, target)
	if result.succeeded:
		_after_successful_move(target, start_positions)


func _after_successful_move(target_pile: CardPile, animation_starts: Dictionary = { }) -> void:
	clear_selection()
	refresh_board()
	_play_move_sound()
	_animate_moved_cards(animation_starts)
	if target_pile.type == CardPile.Type.FOUNDATION:
		check_for_win()


func _play_move_sound() -> void:
	move_card_audio.play()


func _animate_moved_cards(start_positions: Dictionary) -> void:
	var moved_views: Array[CardView] = []
	for view in start_positions:
		var card_view := view as CardView
		if is_instance_valid(card_view):
			moved_views.append(card_view)

	if moved_views.is_empty():
		return

	for order in range(moved_views.size()):
		var card_view := moved_views[order]
		card_view.animate_move_from(start_positions[card_view] as Vector2, order)


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
