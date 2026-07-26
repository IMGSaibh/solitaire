class_name CardView
extends Control

@onready var texture_rect: TextureRect = $TextureRect

var card: CardData
signal card_clicked(card_view: CardView)
signal card_double_clicked(card_view: CardView)

func setup(card_data: CardData) -> void:
	card = card_data
	update_visual()

func update_visual() -> void:
	if card == null:
		return

	var texture_path : String
	if card.face_up:
		texture_path = get_texture_path(card)
	else:
		texture_path = "res://assets/cards/backs/back.png"
	var texture := load(texture_path) as Texture2D

	if texture == null:
		push_error("card texture could not be loaded: " + texture_path)
		return

	texture_rect.texture = texture

func get_texture_path(card_data: CardData) -> String:
	var suit_name := get_suit_name(card_data.suit)

	return "res://assets/cards/faces/%s_%02d.png" % [
		suit_name,
		card_data.rank
	]

func get_suit_name(suit: CardData.Suit) -> String:
	match suit:
		CardData.Suit.CLUBS:
			return "clubs"
		CardData.Suit.DIAMONDS:
			return "diamonds"
		CardData.Suit.HEARTS:
			return "hearts"
		CardData.Suit.SPADES:
			return "spades"
		_:
			return ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if event.double_click:
				card_double_clicked.emit(self)
			else:
				card_clicked.emit(self)