class_name GameState
extends RefCounted

const FOUNDATION_COUNT := 4
const TABLEAU_COUNT := 7
const MAX_RANK := 13

var stock: CardPile
var waste: CardPile
var score := 0

var foundations: Array[CardPile] = []
var tableau: Array[CardPile] = []


func _init() -> void:
	_create_piles()


func _create_piles() -> void:
	stock = CardPile.new(CardPile.Type.STOCK)
	waste = CardPile.new(CardPile.Type.WASTE)

	for i in range(FOUNDATION_COUNT):
		foundations.append(CardPile.new(CardPile.Type.FOUNDATION))

	for i in range(TABLEAU_COUNT):
		tableau.append(CardPile.new(CardPile.Type.TABLEAU))


func clear_piles() -> void:
	stock.cards.clear()
	waste.cards.clear()

	for foundation in foundations:
		foundation.cards.clear()

	for pile in tableau:
		pile.cards.clear()


func are_all_cards_faced_up() -> bool:
	for pile in tableau:
		for card in pile.cards:
			if not card.face_up:
				return false
	return true


func is_game_won() -> bool:
	for foundation in foundations:
		if foundation.cards.size() != GameState.MAX_RANK:
			return false
	return true


func create_snapshot() -> Dictionary:
	return {
		"score": score,
		"stock": _serialize_pile(stock),
		"waste": _serialize_pile(waste),
		"foundations": foundations.map(_serialize_pile),
		"tableau": tableau.map(_serialize_pile),
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	var parsed_score := int(snapshot.get("score", 0))
	var stock_cards: Variant = _deserialize_cards(snapshot.get("stock", []))
	var waste_cards: Variant = _deserialize_cards(snapshot.get("waste", []))
	var foundation_piles := snapshot.get("foundations", []) as Array
	var tableau_piles := snapshot.get("tableau", []) as Array

	if stock_cards == null or waste_cards == null:
		return false
	if foundation_piles.size() != FOUNDATION_COUNT or tableau_piles.size() != TABLEAU_COUNT:
		return false

	var parsed_foundations: Array[Array] = []
	var parsed_tableau: Array[Array] = []
	for foundation_pile in foundation_piles:
		var parsed: Variant = _deserialize_cards(foundation_pile)
		if parsed == null:
			return false
		parsed_foundations.append(parsed)
	for tableau_pile in tableau_piles:
		var parsed: Variant = _deserialize_cards(tableau_pile)
		if parsed == null:
			return false
		parsed_tableau.append(parsed)

	stock.cards.assign(stock_cards)
	waste.cards.assign(waste_cards)
	score = parsed_score
	for i in range(FOUNDATION_COUNT):
		foundations[i].cards.assign(parsed_foundations[i])
	for i in range(TABLEAU_COUNT):
		tableau[i].cards.assign(parsed_tableau[i])
	return true


func _serialize_pile(pile: CardPile) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card in pile.cards:
		result.append(card.to_dict())
	return result


func _deserialize_cards(data: Variant) -> Variant:
	if not data is Array:
		return null
	var result: Array[CardData] = []
	for entry in data:
		if not entry is Dictionary:
			return null
		var card := CardData.from_dict(entry)
		if card == null:
			return null
		result.append(card)
	return result
