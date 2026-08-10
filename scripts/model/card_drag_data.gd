class_name CardDragData
extends RefCounted

var source_pile: CardPile
var start_index: int


func _init(p_source_pile: CardPile, p_start_index: int) -> void:
	source_pile = p_source_pile
	start_index = p_start_index


func get_cards() -> Array[CardData]:
	if source_pile == null or start_index < 0 or start_index >= source_pile.cards.size():
		return []

	var result: Array[CardData] = []
	for i in range(start_index, source_pile.cards.size()):
		result.append(source_pile.cards[i])
	return result
