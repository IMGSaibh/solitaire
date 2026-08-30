class_name KlondikeRules
extends RefCounted


static func can_move_to_tableau(card: CardData, target_pile: CardPile) -> bool:
	if card == null or target_pile == null:
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


static func can_move_to_foundation(card: CardData, target_pile: CardPile) -> bool:
	if card == null or target_pile == null or not card.face_up:
		return false

	if target_pile.type != CardPile.Type.FOUNDATION:
		return false

	# Leere Foundation startet immer mit Ass
	if target_pile.is_empty():
		return card.rank == 1

	var top_card := target_pile.get_top_card()

	var same_suit := card.suit == top_card.suit
	var next_rank := card.rank == top_card.rank + 1

	return same_suit and next_rank


static func can_pick_up_tableau_sequence(pile: CardPile, start_index: int) -> bool:
	if pile == null or pile.type != CardPile.Type.TABLEAU:
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
		if pile.cards[i] == null or not pile.cards[i].face_up:
			return false

	return true


static func can_move(source_pile: CardPile, start_index: int, target_pile: CardPile) -> bool:
	if source_pile == null or target_pile == null or source_pile == target_pile:
		return false

	var cards := source_pile.get_cards_from(start_index)
	match source_pile.type:
		CardPile.Type.TABLEAU:
			if not can_pick_up_tableau_sequence(source_pile, start_index):
				return false
		CardPile.Type.WASTE, CardPile.Type.FOUNDATION:
			if start_index != source_pile.cards.size() - 1 or cards.size() != 1 or not cards[0].face_up:
				return false
		_:
			return false

	match target_pile.type:
		CardPile.Type.TABLEAU:
			return can_move_to_tableau(cards[0], target_pile)
		CardPile.Type.FOUNDATION:
			return cards.size() == 1 and can_move_to_foundation(cards[0], target_pile)
		_:
			return false
