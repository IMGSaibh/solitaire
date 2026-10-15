## card_codec.gd
## Übersetzt zwischen deinen echten Klassen (CardData, CardPile, GameState,
## GameState.create_snapshot()-Dictionaries) und den kompakten int-Karten-IDs,
## die ThoughtfulSolver für Performance intern verwendet.
##
## ID-Format: id = suit * 13 + (rank - 1)  ->  suit 0..3 (CLUBS..SPADES wie
## CardData.Suit), rank 1..13 (1=Ass ... 13=König), exakt wie in CardData.
class_name CardCodec
extends RefCounted

static func rank_of(id: int) -> int:
	return (id % 13) + 1

static func suit_of(id: int) -> int:
	return int(id / 13.0)

static func card_to_id(card: CardData) -> int:
	return int(card.suit) * 13 + (card.rank - 1)

static func card_dict_to_id(card_dict: Dictionary) -> int:
	return int(card_dict.suit) * 13 + (int(card_dict.rank) - 1)

## Baut den Solver-Zustand direkt aus einer laufenden GameState-Instanz
## (Live-Spiel, für die "ist der aktuelle Stand noch gewinnbar?"-Prüfung).
static func state_from_game_state(gs: GameState, draw_count: int = 1, redeals_used: int = 0) -> Dictionary:
	var tableau_ids: Array = []
	var tableau_hidden: Array = []
	for pile in gs.tableau:
		var ids: Array = []
		var hidden_count := 0
		for c in pile.cards:
			ids.append(card_to_id(c))
			if not c.face_up:
				hidden_count += 1
		tableau_ids.append(ids)
		tableau_hidden.append(hidden_count)

	var foundation_ranks := [0, 0, 0, 0]
	for f_pile in gs.foundations:
		if not f_pile.is_empty():
			var top: CardData = f_pile.get_top_card()
			foundation_ranks[int(top.suit)] = top.rank

	var stock_ids: Array = []
	for c in gs.stock.cards:
		stock_ids.append(card_to_id(c))

	var waste_ids: Array = []
	for c in gs.waste.cards:
		waste_ids.append(card_to_id(c))

	return {
		"tableau": tableau_ids,
		"tableau_hidden": tableau_hidden,
		"foundation": foundation_ranks,
		"stock": stock_ids,
		"waste": waste_ids,
		"redeals_used": redeals_used,
		"draw_count": draw_count,
	}

## Baut den Solver-Zustand aus einem GameState.create_snapshot()-Dictionary
## (z. B. aus GameService.undo_stack oder einer gespeicherten Partie).
static func state_from_snapshot(snapshot: Dictionary, draw_count: int = 1, redeals_used: int = 0) -> Dictionary:
	var tableau_ids: Array = []
	var tableau_hidden: Array = []
	for pile in snapshot.get("tableau", []):
		var ids: Array = []
		var hidden_count := 0
		for card_dict in pile:
			ids.append(card_dict_to_id(card_dict))
			if not bool(card_dict.get("face_up", false)):
				hidden_count += 1
		tableau_ids.append(ids)
		tableau_hidden.append(hidden_count)

	var foundation_ranks := [0, 0, 0, 0]
	for pile in snapshot.get("foundations", []):
		if pile.size() > 0:
			var top: Dictionary = pile[pile.size() - 1]
			foundation_ranks[int(top.suit)] = int(top.rank)

	var stock_ids: Array = []
	for card_dict in snapshot.get("stock", []):
		stock_ids.append(card_dict_to_id(card_dict))

	var waste_ids: Array = []
	for card_dict in snapshot.get("waste", []):
		waste_ids.append(card_dict_to_id(card_dict))

	return {
		"tableau": tableau_ids,
		"tableau_hidden": tableau_hidden,
		"foundation": foundation_ranks,
		"stock": stock_ids,
		"waste": waste_ids,
		"redeals_used": redeals_used,
		"draw_count": draw_count,
	}
