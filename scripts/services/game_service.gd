class_name GameService
extends RefCounted

const DEFAULT_SAVE_PATH := "user://savegame.json"

var state: GameState
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []


func _init(p_state: GameState = null) -> void:
	state = p_state if p_state != null else GameState.new()


func new_game() -> void:
	state.new_game()
	clear_history()


func try_move(source: CardPile, start_index: int, target: CardPile) -> MoveResult:
	if not KlondikeRules.can_move(source, start_index, target):
		return MoveResult.failure("Move is not allowed")

	var before := state.create_snapshot()
	var moved_cards := source.remove_cards_from(start_index)
	target.add_cards(moved_cards)
	_flip_new_top_tableau_card(source)
	_record_change(before)
	return MoveResult.success(moved_cards)


func draw_from_stock() -> bool:
	if state.stock.is_empty():
		return recycle_waste()

	var before := state.create_snapshot()
	var card := state.stock.remove_top_card()
	card.face_up = true
	state.waste.add_card(card)
	_record_change(before)
	return true


func recycle_waste() -> bool:
	if state.waste.is_empty():
		return false

	var before := state.create_snapshot()
	while not state.waste.is_empty():
		var card := state.waste.remove_top_card()
		card.face_up = false
		state.stock.add_card(card)
	_record_change(before)
	return true


func find_automatic_target(source: CardPile, start_index: int) -> CardPile:
	if source == null or start_index < 0 or start_index >= source.cards.size():
		return null

	if start_index == source.cards.size() - 1:
		for foundation in state.foundations:
			if KlondikeRules.can_move(source, start_index, foundation):
				return foundation

	for tableau_pile in state.tableau:
		if KlondikeRules.can_move(source, start_index, tableau_pile):
			return tableau_pile
	return null


func undo() -> bool:
	if undo_stack.is_empty():
		return false
	var current := state.create_snapshot()
	var previous: Dictionary = undo_stack.pop_back()
	if not state.restore_snapshot(previous):
		undo_stack.append(previous)
		return false
	redo_stack.append(current)
	return true


func redo() -> bool:
	if redo_stack.is_empty():
		return false
	var current := state.create_snapshot()
	var next: Dictionary = redo_stack.pop_back()
	if not state.restore_snapshot(next):
		redo_stack.append(next)
		return false
	undo_stack.append(current)
	return true


func save_game(path: String = DEFAULT_SAVE_PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(state.create_snapshot()))
	return OK


func load_game(path: String = DEFAULT_SAVE_PATH) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not state.restore_snapshot(parsed):
		return ERR_PARSE_ERROR
	clear_history()
	return OK


func clear_history() -> void:
	undo_stack.clear()
	redo_stack.clear()


func _record_change(before: Dictionary) -> void:
	undo_stack.append(before)
	redo_stack.clear()


func _flip_new_top_tableau_card(pile: CardPile) -> void:
	if pile.type != CardPile.Type.TABLEAU or pile.is_empty():
		return
	var top_card := pile.get_top_card()
	if not top_card.face_up:
		top_card.face_up = true
