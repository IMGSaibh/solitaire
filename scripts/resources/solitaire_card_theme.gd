class_name SolitaireCardTheme
extends Resource

@export_group("Textures")
@export var face_directory := "res://assets/cards/faces"
@export var back_texture: Texture2D

@export_group("Layout")
@export var card_size := Vector2(150.0, 210.0)
@export var tableau_offset := 50.0

@export_group("Effects")
@export var card_material: ShaderMaterial


func get_face_texture(card: CardData) -> Texture2D:
	if card == null:
		return null
	var path := "%s/%s_%02d.png" % [face_directory, card.get_suit_name(), card.rank]
	return load(path) as Texture2D


func get_texture(card: CardData) -> Texture2D:
	if card == null:
		return null
	return get_face_texture(card) if card.face_up else back_texture
