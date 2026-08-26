extends SceneTree

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_tableau_rules()
	_test_foundation_rules()
	_test_atomic_move_and_history()
	_test_foundation_score_and_undo()
	_test_card_scores_only_once()
	_test_stock_recycling()
	_test_save_and_load()
	await _test_win_animation()

	if failures == 0:
		print("All Solitaire tests passed.")
	else:
		push_error("%d Solitaire test(s) failed." % failures)
	quit(failures)


func _test_win_animation() -> void:
	var animation_scene := load("res://scenes/main/game.tscn") as PackedScene
	var game := animation_scene.instantiate() as Control
	root.add_child(game)
	await process_frame

	var foundation := CardPile.new(CardPile.Type.FOUNDATION)
	foundation.add_card(_card(CardData.Suit.CLUBS, 1))
	var foundations: Array[CardPile] = [foundation]
	var foundation_views: Array[PileView] = [game.get_node("Board/Foundation1") as PileView]
	var animation := game.get_node("WinAnimationLayer") as WinAnimation
	animation.play(foundations, foundation_views)
	await create_timer(0.08).timeout
	_expect(animation.animated_cards.size() == 1, "Win animation can spawn a card")
	animation.stop()
	game.queue_free()
	await process_frame


func _test_tableau_rules() -> void:
	var empty_tableau := CardPile.new(CardPile.Type.TABLEAU)
	var red_king := _card(CardData.Suit.HEARTS, 13)
	var red_queen := _card(CardData.Suit.DIAMONDS, 12)
	_expect(KlondikeRules.can_move_to_tableau(red_king, empty_tableau), "King may move to empty tableau")
	_expect(not KlondikeRules.can_move_to_tableau(red_queen, empty_tableau), "Only king may move to empty tableau")

	var sequence: Array[CardData] = [
		_card(CardData.Suit.CLUBS, 10),
		_card(CardData.Suit.HEARTS, 9),
		_card(CardData.Suit.SPADES, 8),
	]
	_expect(KlondikeRules.is_valid_tableau_sequence(sequence), "Alternating descending sequence is valid")
	sequence[2] = _card(CardData.Suit.DIAMONDS, 8)
	_expect(not KlondikeRules.is_valid_tableau_sequence(sequence), "Same-color sequence is invalid")


func _test_foundation_rules() -> void:
	var foundation := CardPile.new(CardPile.Type.FOUNDATION)
	var ace := _card(CardData.Suit.CLUBS, 1)
	var two := _card(CardData.Suit.CLUBS, 2)
	_expect(KlondikeRules.can_move_to_foundation(ace, foundation), "Ace starts foundation")
	foundation.add_card(ace)
	_expect(KlondikeRules.can_move_to_foundation(two, foundation), "Matching next rank continues foundation")
	_expect(
		not KlondikeRules.can_move_to_foundation(_card(CardData.Suit.HEARTS, 2), foundation),
		"Different suit cannot continue foundation",
	)


func _test_atomic_move_and_history() -> void:
	var state := GameState.new()
	var service := GameService.new(state)
	var source := state.tableau[0]
	var target := state.tableau[1]
	var hidden_card := CardData.new(CardData.Suit.CLUBS, 4, false)
	var red_king := _card(CardData.Suit.HEARTS, 13)
	source.add_cards([hidden_card, red_king])

	var result := service.try_move(source, 1, target)
	_expect(result.succeeded, "Valid move succeeds")
	_expect(source.get_top_card() == hidden_card and hidden_card.face_up, "Move flips new tableau top card")
	_expect(target.get_top_card() == red_king, "Moved card reaches target")
	_expect(service.undo(), "Move can be undone")
	_expect(state.tableau[0].size() == 2 and state.tableau[1].is_empty(), "Undo restores piles")
	_expect(not state.tableau[0].cards[0].face_up, "Undo restores face-up state")


func _test_foundation_score_and_undo() -> void:
	var state := GameState.new()
	var service := GameService.new(state)
	var source := state.tableau[0]
	var foundation := state.foundations[CardData.Suit.CLUBS]
	source.add_card(_card(CardData.Suit.CLUBS, 1))

	var result := service.try_move(source, 0, foundation)
	_expect(result.succeeded, "Card can be moved to foundation for scoring")
	_expect(state.score == 10, "Foundation move awards 10 points")
	_expect(service.undo(), "Scoring foundation move can be undone")
	_expect(state.score == 0, "Undo removes foundation points")


func _test_card_scores_only_once() -> void:
	var state := GameState.new()
	var service := GameService.new(state)
	var first_tableau := state.tableau[0]
	var second_tableau := state.tableau[1]
	var third_tableau := state.tableau[2]
	var black_king := _card(CardData.Suit.CLUBS, 13)
	var red_queen := _card(CardData.Suit.HEARTS, 12)
	first_tableau.add_card(red_queen)
	second_tableau.add_card(black_king)

	var first_move := service.try_move(first_tableau, 0, second_tableau)
	_expect(first_move.succeeded, "Card can move to another tableau")
	_expect(first_move.points_awarded == 5 and state.score == 5, "First tableau move awards points")

	third_tableau.add_card(_card(CardData.Suit.SPADES, 13))
	var second_move := service.try_move(second_tableau, 1, third_tableau)
	_expect(second_move.succeeded, "Card can move between tableaus again")
	_expect(second_move.points_awarded == 0 and state.score == 5, "Card does not score a second time")

	var snapshot := state.create_snapshot()
	_expect(state.restore_snapshot(snapshot), "Scoring state survives snapshot restore")
	_expect(
		state.tableau[2].get_top_card().tableau_points_awarded,
		"Card remains marked as tableau-scored after restore",
	)

	var foundation_state := GameState.new()
	var foundation_service := GameService.new(foundation_state)
	var ace := _card(CardData.Suit.CLUBS, 1)
	var red_two := _card(CardData.Suit.DIAMONDS, 2)
	foundation_state.tableau[0].add_card(ace)
	foundation_state.tableau[1].add_card(red_two)
	var to_foundation := foundation_service.try_move(
		foundation_state.tableau[0],
		0,
		foundation_state.foundations[CardData.Suit.CLUBS],
	)
	var back_to_tableau := foundation_service.try_move(
		foundation_state.foundations[CardData.Suit.CLUBS],
		0,
		foundation_state.tableau[1],
	)
	var back_to_foundation := foundation_service.try_move(
		foundation_state.tableau[1],
		1,
		foundation_state.foundations[CardData.Suit.CLUBS],
	)
	_expect(to_foundation.points_awarded == 10, "Card receives its foundation points")
	_expect(back_to_tableau.points_awarded == 5, "Card can separately receive its tableau points")
	_expect(
		back_to_foundation.points_awarded == 0 and foundation_state.score == 15,
		"Card does not receive its foundation points twice",
	)

	var stack_state := GameState.new()
	var stack_service := GameService.new(stack_state)
	var red_king := _card(CardData.Suit.HEARTS, 13)
	var black_queen := _card(CardData.Suit.CLUBS, 12)
	var red_jack := _card(CardData.Suit.DIAMONDS, 11)
	stack_state.tableau[0].add_cards([black_queen, red_jack])
	stack_state.tableau[1].add_card(red_king)
	var stack_move := stack_service.try_move(stack_state.tableau[0], 0, stack_state.tableau[1])
	_expect(stack_move.points_awarded == 5, "A moved tableau sequence awards points only once")
	_expect(black_queen.tableau_points_awarded, "The attached card is marked as tableau-scored")
	_expect(not red_jack.tableau_points_awarded, "Cards hanging below it are not marked as scored")


func _test_stock_recycling() -> void:
	var state := GameState.new()
	var service := GameService.new(state)
	var first := CardData.new(CardData.Suit.CLUBS, 1, false)
	var second := CardData.new(CardData.Suit.CLUBS, 2, false)
	state.stock.add_cards([first, second])
	_expect(service.draw_from_stock() and service.draw_from_stock(), "Cards can be drawn from stock")
	_expect(state.waste.cards == [second, first], "Waste preserves draw order")
	_expect(service.recycle_waste(), "Waste can be recycled")
	_expect(state.stock.cards == [first, second], "Recycled stock restores original order")
	_expect(not state.stock.cards[0].face_up and not state.stock.cards[1].face_up, "Recycled cards are face down")


func _test_save_and_load() -> void:
	var state := GameState.new()
	var service := GameService.new(state)
	state.stock.add_card(CardData.new(CardData.Suit.SPADES, 7, false))
	var path := "user://solitaire_test_save.json"
	_expect(service.save_game(path) == OK, "Game can be saved")
	state.stock.cards.clear()
	_expect(service.load_game(path) == OK, "Game can be loaded")
	_expect(state.stock.size() == 1 and state.stock.get_top_card().rank == 7, "Load restores card data")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _card(suit: CardData.Suit, rank: int) -> CardData:
	return CardData.new(suit, rank, true)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAILED: " + message)
