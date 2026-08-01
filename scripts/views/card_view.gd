class_name CardView
extends Control

@onready var texture_rect: TextureRect = $TextureRect

var card: CardData
var drag_payload: Variant = null
signal card_clicked(card_view: CardView)
signal card_double_clicked(card_view: CardView)


func setup(card_data: CardData) -> void:
	card = card_data
	update_visual()


func set_drag_payload(payload: Variant) -> void:
	drag_payload = payload


func update_visual() -> void:
	if card == null:
		return

	var texture_path: String
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
	return "res://assets/cards/faces/%s_%02d.png" % [suit_name, card_data.rank]


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


func _get_drag_data(at_position: Vector2) -> Variant:
	if drag_payload == null:
		return null

	var preview := Control.new()
	var dragged_cards: Array = drag_payload.get("cards", [])

	for i in range(dragged_cards.size()):
		var dragged_card := dragged_cards[i] as CardData
		var preview_card := TextureRect.new()

		preview_card.texture = load(get_texture_path(dragged_card)) as Texture2D
		preview_card.position = Vector2(-at_position.x, i * 28 - at_position.y)
		preview_card.size = Vector2(100, 140)
		preview_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE

		preview.add_child(preview_card)

	preview.size = Vector2(100, 140)
	set_drag_preview(preview)

	return drag_payload


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var pile_view := get_parent() as PileView

	if pile_view == null:
		return false

	return pile_view.can_accept_drop(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var pile_view := get_parent() as PileView

	if pile_view != null:
		pile_view.accept_drop(data)


var outline_tween: Tween


func outline_shader() -> void:
	if outline_tween != null:
		outline_tween.kill()

	texture_rect.set_instance_shader_parameter("outline_strength", 0.0)
	outline_tween = create_tween()
	outline_tween.tween_method(_set_outline_strength, 0.0, 1.0, 0.0)
	outline_tween.tween_method(_set_outline_strength, 1.0, 0.0, 0.5)


func _set_outline_strength(value: float) -> void:
	texture_rect.set_instance_shader_parameter("outline_strength", value)
