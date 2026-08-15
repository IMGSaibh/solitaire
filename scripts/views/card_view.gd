class_name CardView
extends Control

const CARD_THEME: SolitaireCardTheme = preload("res://data/card_theme.tres")

@onready var texture_rect: TextureRect = $TextureRect

var card: CardData
var drag_data: CardDragData
var drag_started := false
var hidden_drag_views: Array[CardView] = []

signal card_clicked(card_view: CardView)
signal card_released(card_view: CardView)
signal drag_finished(card_view: CardView)


func _ready() -> void:
	if CARD_THEME.card_material == null:
		push_error("Card theme has no shader material")
		return
	texture_rect.material = CARD_THEME.card_material.duplicate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_show_dragged_cards()
		drag_finished.emit(self)


func setup(card_data: CardData) -> void:
	card = card_data
	visible = true
	set_outline_enabled(false)
	update_visual()


func set_drag_data(data: CardDragData) -> void:
	drag_data = data


func update_visual() -> void:
	var texture := CARD_THEME.get_texture(card)
	if texture == null:
		push_error("Card texture could not be loaded")
		return
	texture_rect.texture = texture


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_started = false
			card_clicked.emit(self)
		elif not drag_started:
			card_released.emit(self)


func _get_drag_data(at_position: Vector2) -> Variant:
	if drag_data == null:
		return null
	var dragged_cards := drag_data.get_cards()
	if dragged_cards.is_empty():
		return null

	drag_started = true
	var preview := Control.new()
	for i in range(dragged_cards.size()):
		var preview_card := TextureRect.new()
		# Ignore the source texture's native pixel size before assigning it.
		# Otherwise high-resolution card assets enlarge the drag preview.
		preview_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		preview_card.custom_minimum_size = Vector2.ZERO
		preview_card.position = Vector2(-at_position.x, i * CARD_THEME.tableau_offset - at_position.y)
		preview_card.size = CARD_THEME.card_size
		preview_card.texture = CARD_THEME.get_face_texture(dragged_cards[i])
		preview_card.material = texture_rect.material.duplicate()
		var preview_material := preview_card.material as ShaderMaterial
		preview_material.set_shader_parameter("outline_enabled", true)
		preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(preview_card)

	preview.size = Vector2(
		CARD_THEME.card_size.x,
		CARD_THEME.card_size.y + CARD_THEME.tableau_offset * (dragged_cards.size() - 1),
	)
	set_drag_preview(preview)
	_hide_dragged_cards(dragged_cards)
	return drag_data


func _hide_dragged_cards(dragged_cards: Array[CardData]) -> void:
	var pile_view := get_parent() as PileView
	if pile_view == null:
		return
	hidden_drag_views.clear()
	for card_view in pile_view.card_views:
		if card_view.card in dragged_cards:
			card_view.hide()
			hidden_drag_views.append(card_view)


func _show_dragged_cards() -> void:
	for card_view in hidden_drag_views:
		if is_instance_valid(card_view):
			card_view.show()
	hidden_drag_views.clear()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var pile_view := get_parent() as PileView
	return pile_view != null and pile_view.can_accept_drop(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var pile_view := get_parent() as PileView
	if pile_view != null:
		pile_view.accept_drop(data)


func set_outline_enabled(enabled: bool) -> void:
	if not is_node_ready():
		return
	var shader_material := texture_rect.material as ShaderMaterial
	shader_material.set_shader_parameter("outline_enabled", enabled)
