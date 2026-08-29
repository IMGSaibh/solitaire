class_name CardPile
extends RefCounted

enum Type {
	STOCK,
	WASTE,
	FOUNDATION,
	TABLEAU,
}

var type: Type
var cards: Array[CardData] = []


func _init(p_type: Type) -> void:
	type = p_type


func add_card(card: CardData) -> void:
	assert(card != null, "Cannot add a null card")
	cards.append(card)


func remove_top_card() -> CardData:
	if cards.is_empty():
		return null

	return cards.pop_back()


func get_top_card() -> CardData:
	if cards.is_empty():
		return null

	return cards.back()


func is_empty() -> bool:
	return cards.is_empty()


func get_cards_from(start_index: int) -> Array[CardData]:
	if start_index < 0 or start_index >= cards.size():
		return []

	var result: Array[CardData] = []
	for i in range(start_index, cards.size()):
		result.append(cards[i])
	return result


func remove_cards_from(start_index: int) -> Array[CardData]:
	var removed := get_cards_from(start_index)
	if removed.is_empty():
		return removed
	cards.resize(start_index)
	return removed


func add_cards(new_cards: Array[CardData]) -> void:
	for card in new_cards:
		add_card(card)
