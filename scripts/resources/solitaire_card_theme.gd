class_name SolitaireCardTheme
extends Resource

@export var face_directory := "res://assets/cards/faces"
@export var back_texture: Texture2D
@export var card_size := Vector2(150.0, 210.0)
@export var tableau_offset := 50.0
@export var outline_color := Color.RED
@export_range(0.0, 3.0) var outline_width := 2.0


func get_face_texture(card: CardData) -> Texture2D:
	if card == null:
		return null
	var path := "%s/%s_%02d.png" % [face_directory, card.get_suit_name(), card.rank]
	return load(path) as Texture2D


func get_texture(card: CardData) -> Texture2D:
	if card == null:
		return null
	return get_face_texture(card) if card.face_up else back_texture
