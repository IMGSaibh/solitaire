class_name CardData
extends RefCounted

enum Suit {
	CLUBS,
	DIAMONDS,
	HEARTS,
	SPADES,
}

var suit: Suit
var rank: int
var face_up: bool = false
var tableau_points_awarded: bool = false
var foundation_points_awarded: bool = false


func _init(
	p_suit: Suit,
	p_rank: int,
	p_face_up: bool = false,
	p_tableau_points_awarded: bool = false,
	p_foundation_points_awarded: bool = false,
) -> void:
	suit = p_suit
	rank = p_rank
	face_up = p_face_up
	tableau_points_awarded = p_tableau_points_awarded
	foundation_points_awarded = p_foundation_points_awarded


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


func get_suit_name() -> String:
	match suit:
		Suit.CLUBS:
			return "clubs"
		Suit.DIAMONDS:
			return "diamonds"
		Suit.HEARTS:
			return "hearts"
		Suit.SPADES:
			return "spades"
		_:
			return "unknown"


func to_dict() -> Dictionary:
	return {
		"suit": suit,
		"rank": rank,
		"face_up": face_up,
		"tableau_points_awarded": tableau_points_awarded,
		"foundation_points_awarded": foundation_points_awarded,
	}


static func from_dict(data: Dictionary) -> CardData:
	var parsed_suit := int(data.get("suit", -1))
	var parsed_rank := int(data.get("rank", 0))
	if parsed_suit not in Suit.values() or parsed_rank < 1 or parsed_rank > 13:
		return null
	return CardData.new(
		parsed_suit as Suit,
		parsed_rank,
		bool(data.get("face_up", false)),
		bool(data.get("tableau_points_awarded", false)),
		bool(data.get("foundation_points_awarded", false)),
	)
