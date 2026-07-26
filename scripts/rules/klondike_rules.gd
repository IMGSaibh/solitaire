class_name KlondikeRules
extends RefCounted


static func can_move_to_tableau(
	card: CardData,
	target_pile: CardPile
) -> bool:
	if card == null:
		return false

	if target_pile.type != CardPile.Type.TABLEAU:
		return false

	# Leeres Tableau: nur König erlaubt
	if target_pile.is_empty():
		return card.rank == 13

	var target_card := target_pile.get_top_card()

	if not target_card.face_up:
		return false

	var correct_rank := card.rank == target_card.rank - 1
	var alternating_color := card.is_red() != target_card.is_red()

	return correct_rank and alternating_color

static func can_pick_up_tableau_sequence(
	pile: CardPile,
	start_index: int
) -> bool:
	if pile.type != CardPile.Type.TABLEAU:
		return false

	if start_index < 0 or start_index >= pile.cards.size():
		return false

	var first_card := pile.cards[start_index]

	if not first_card.face_up:
		return false

	for i in range(start_index, pile.cards.size() - 1):
		var upper := pile.cards[i]
		var lower := pile.cards[i + 1]

		var correct_rank := lower.rank == upper.rank - 1
		var alternating_color := lower.is_red() != upper.is_red()

		if not correct_rank or not alternating_color:
			return false

	return true

static func can_move_sequence_to_tableau(
	cards: Array[CardData],
	target_pile: CardPile
) -> bool:
	if cards.is_empty():
		return false

	var first_card := cards[0]

	return can_move_to_tableau(first_card, target_pile)