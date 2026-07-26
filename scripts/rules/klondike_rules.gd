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