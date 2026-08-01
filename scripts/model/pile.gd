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


func size() -> int:
	return cards.size()
