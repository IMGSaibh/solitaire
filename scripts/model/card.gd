class_name CardData
extends RefCounted


enum Suit {
	CLUBS,
	DIAMONDS,
	HEARTS,
	SPADES
}

var suit: Suit
var rank: int
var face_up: bool = false


func _init(p_suit: Suit, p_rank: int, p_face_up: bool = false) -> void:
	suit = p_suit
	rank = p_rank
	face_up = p_face_up

func is_red() -> bool:
	return suit == Suit.HEARTS or suit == Suit.DIAMONDS


func get_rank_name() -> String:
	match rank:
		1:
			return "A"
		11:
			return "J"
		12:
			return "Q"
		13:
			return "K"
		_:
			return str(rank)