extends Control

@onready var texture_rect: TextureRect = $TextureRect

var suit: String
var rank: int
var face_up := true

func set_card(card_suit: String, card_rank: int) -> void:
    suit = card_suit
    rank = card_rank

    var path := "res://assets/cards/faces/%s_%02d.png" % [suit, rank]
    texture_rect.texture = load(path)