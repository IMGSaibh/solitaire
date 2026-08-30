class_name GameService
extends RefCounted

const DEFAULT_SAVE_PATH := "user://savegame.json"
const FOUNDATION_CARD_SCORE := 10
const TABLEAU_CARD_SCORE := 5

var state: GameState
var undo_stack: Array[Dictionary] = []


func _init() -> void:
	state = GameState.new()


func new_game() -> void:
	state.score = 0
	state.clear_piles()
	var deck := _create_deck()
	deck.shuffle()
	_deal_tableau(deck)
	_fill_stock(deck)
	undo_stack.clear()


func try_move(source: CardPile, start_index: int, target: CardPile) -> MoveResult:
	if not KlondikeRules.can_move(source, start_index, target):
		return MoveResult.failure()

	var before := state.create_snapshot()
	var moved_cards := source.remove_cards_from(start_index)
	target.add_cards(moved_cards)
	var moved_card: CardData = moved_cards.front()
	var points_awarded := 0
	if target.type == CardPile.Type.FOUNDATION and not moved_card.foundation_points_awarded:
		moved_card.foundation_points_awarded = true
		points_awarded = FOUNDATION_CARD_SCORE
	elif target.type == CardPile.Type.TABLEAU and not moved_card.tableau_points_awarded:
		moved_card.tableau_points_awarded = true
		points_awarded = TABLEAU_CARD_SCORE
	state.score += points_awarded
	_flip_new_top_tableau_card(source)
	undo_stack.append(before)
	return MoveResult.success(points_awarded)


func _create_deck() -> Array[CardData]:
	var deck: Array[CardData] = []
	for suit in CardData.Suit.values():
		for rank in range(1, GameState.MAX_RANK + 1):
			var card := CardData.new(suit, rank, false)
			deck.append(card)

	return deck


func _deal_tableau(tableau: Array[CardData]) -> void:
	for tableau_index in range(GameState.TABLEAU_COUNT):
		for card_index in range(tableau_index + 1):
			var card: CardData = tableau.pop_back()
			# only the top card of each tableau pile is face up at the start of the game
			card.face_up = card_index == tableau_index
			state.tableau[tableau_index].add_card(card)


func _fill_stock(stock: Array[CardData]) -> void:
	while not stock.is_empty():
		var card: CardData = stock.pop_back()
		card.face_up = false
		state.stock.add_card(card)


func draw_from_stock() -> bool:
	if state.stock.is_empty():
		return recycle_waste()

	var before := state.create_snapshot()
	var card := state.stock.remove_top_card()
	card.face_up = true
	state.waste.add_card(card)
	undo_stack.append(before)
	return true


func recycle_waste() -> bool:
	if state.waste.is_empty():
		return false

	var before := state.create_snapshot()
	while not state.waste.is_empty():
		var card := state.waste.remove_top_card()
		card.face_up = false
		state.stock.add_card(card)
	undo_stack.append(before)
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
	var previous: Dictionary = undo_stack.pop_back()
	if not state.restore_snapshot(previous):
		undo_stack.append(previous)
		return false
	return true


func save_game_to_json(path: String = DEFAULT_SAVE_PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ERR_CANT_OPEN
	file.store_string(JSON.stringify(state.create_snapshot(), "\t"))
	return OK


func load_game_from_json(path: String = DEFAULT_SAVE_PATH) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ERR_CANT_OPEN
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not state.restore_snapshot(parsed):
		return ERR_PARSE_ERROR
	undo_stack.clear()
	return OK


func _flip_new_top_tableau_card(pile: CardPile) -> void:
	if pile.type != CardPile.Type.TABLEAU or pile.is_empty():
		return
	var top_card := pile.get_top_card()
	if not top_card.face_up:
		top_card.face_up = true


func can_auto_finish() -> bool:
	return state.are_all_cards_faced_up() and state.stock.is_empty() and state.waste.is_empty()


func start_test_win_animation(win_animation: WinAnimation, foundation_views: Array[PileView]) -> void:
	var test_foundations: Array[CardPile] = []
	for i in range(GameState.FOUNDATION_COUNT):
		test_foundations.append(CardPile.new(CardPile.Type.FOUNDATION))
	var deck := _create_deck()
	for card in deck:
		card.face_up = true
		test_foundations[card.suit].add_card(card)
	win_animation.play(test_foundations, foundation_views)
