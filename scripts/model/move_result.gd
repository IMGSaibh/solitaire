class_name MoveResult
extends RefCounted

var succeeded: bool
var reason: String
var moved_cards: Array[CardData]


func _init(p_succeeded: bool, p_reason: String = "", p_moved_cards: Array[CardData] = []) -> void:
	succeeded = p_succeeded
	reason = p_reason
	moved_cards = p_moved_cards


static func success(cards: Array[CardData]) -> MoveResult:
	return MoveResult.new(true, "", cards)


static func failure(message: String) -> MoveResult:
	return MoveResult.new(false, message)
