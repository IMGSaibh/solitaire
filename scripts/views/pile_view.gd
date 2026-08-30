class_name PileView
extends Control

const CARD_THEME: SolitaireCardTheme = preload("res://data/card_theme.tres")
const SCORE_POPUP_DURATION := 1.75
const SCORE_POPUP_RISE := 70.0
const SCORE_POPUP_FONT_SIZE := 52

@export var card_scene: PackedScene
@onready var pile_texture: TextureRect = $PileTexture

var pile: CardPile
var card_views: Array[CardView] = []

signal card_clicked(pile_view: PileView, card_index: int)
signal pile_clicked(pile_view: PileView)
signal card_released(pile_view: PileView, card_index: int)
signal cards_dropped(data: CardDragData, target_pile: CardPile)


func setup(pile_data: CardPile, reusable_views: Dictionary, animate_adopted_cards: bool = false) -> void:
	pile = pile_data
	_refresh(reusable_views, animate_adopted_cards)
	_update_pile_texture()


func _update_pile_texture() -> void:
	if pile == null:
		pile_texture.hide()
		return

	match pile.type:
		CardPile.Type.FOUNDATION:
			pile_texture.texture = preload("res://assets/cards/foundation/foundation-01.png")
			pile_texture.show()
		CardPile.Type.TABLEAU:
			pile_texture.texture = preload("res://assets/cards/tableau/tableau-01.png")
			pile_texture.show()
		CardPile.Type.STOCK:
			pile_texture.texture = preload("res://assets/cards/stock/stock-01.png")
			pile_texture.show()
		CardPile.Type.WASTE:
			pile_texture.texture = preload("res://assets/cards/waste/waste-01.png")
			pile_texture.show()
		_:
			pile_texture.hide()


func _refresh(reusable_views: Dictionary, animate_adopted_cards: bool) -> void:
	var refreshed_views: Array[CardView] = []
	var animation_order := 0
	for i in range(pile.cards.size()):
		var card := pile.cards[i]
		var card_view: CardView = reusable_views.get(card) as CardView
		var was_adopted := false
		if card_view != null:
			reusable_views.erase(card)
			was_adopted = _adopt_card_view(card_view)
		else:
			card_view = _create_card_view()

		card_view.setup(card)
		card_view.set_drag_data(_create_drag_data(i))
		var target_global_position := get_global_transform() * _card_position(i)
		if animate_adopted_cards and was_adopted:
			card_view.animate_move_to(target_global_position, animation_order)
			animation_order += 1
		else:
			card_view.global_position = target_global_position
		refreshed_views.append(card_view)
		move_child(card_view, get_child_count() - 1)

	card_views = refreshed_views
	_update_drop_area()


func _create_card_view() -> CardView:
	var card_view := card_scene.instantiate() as CardView
	add_child(card_view)
	_connect_card_view(card_view)
	return card_view


func _adopt_card_view(card_view: CardView) -> bool:
	var old_pile_view := card_view.get_parent() as PileView
	if old_pile_view == self:
		_connect_card_view(card_view)
		return false
	if old_pile_view != null:
		# old_pile_view.release_card_view(card_view)
		card_views.erase(card_view)
		_disconnect_card_view_signals(card_view)
	card_view.reparent(self, true)
	_connect_card_view(card_view)
	return true


func _connect_card_view(card_view: CardView) -> void:
	if not card_view.card_clicked.is_connected(_on_card_view_clicked):
		card_view.card_clicked.connect(_on_card_view_clicked)
	if not card_view.card_released.is_connected(_on_card_view_released):
		card_view.card_released.connect(_on_card_view_released)
	if not card_view.drag_finished.is_connected(_on_card_drag_finished):
		card_view.drag_finished.connect(_on_card_drag_finished)

# func release_card_view(card_view: CardView) -> void:


func _disconnect_card_view_signals(card_view: CardView) -> void:
	if card_view.card_clicked.is_connected(_on_card_view_clicked):
		card_view.card_clicked.disconnect(_on_card_view_clicked)
	if card_view.card_released.is_connected(_on_card_view_released):
		card_view.card_released.disconnect(_on_card_view_released)
	if card_view.drag_finished.is_connected(_on_card_drag_finished):
		card_view.drag_finished.disconnect(_on_card_drag_finished)


func _card_position(index: int) -> Vector2:
	var y_position := index * CARD_THEME.tableau_offset if pile.type == CardPile.Type.TABLEAU else 0.0
	return Vector2(0.0, y_position)


func _update_drop_area() -> void:
	var card_count := pile.cards.size() if pile != null else 0
	var extra_height := 0.0
	if pile != null and pile.type == CardPile.Type.TABLEAU and card_count > 1:
		extra_height = (card_count - 1) * CARD_THEME.tableau_offset
	size = Vector2(CARD_THEME.card_size.x, CARD_THEME.card_size.y + extra_height)


func _on_card_view_clicked(card_view: CardView) -> void:
	var index := card_views.find(card_view)
	if index >= 0:
		card_clicked.emit(self, index)


func _on_card_view_released(card_view: CardView) -> void:
	var index := card_views.find(card_view)
	if index >= 0:
		card_released.emit(self, index)


func _on_card_drag_finished(_card_view: CardView) -> void:
	clear_outlines()


func _create_drag_data(card_index: int) -> CardDragData:
	if pile.type == CardPile.Type.STOCK:
		return null
	if pile.type != CardPile.Type.TABLEAU and card_index != pile.cards.size() - 1:
		return null
	if pile.type == CardPile.Type.TABLEAU and not KlondikeRules.can_pick_up_tableau_sequence(pile, card_index):
		return null
	return CardDragData.new(pile, card_index)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return can_accept_drop(data)


func can_accept_drop(data: Variant) -> bool:
	if not data is CardDragData:
		return false
	var typed_data := data as CardDragData
	return KlondikeRules.can_move(typed_data.source_pile, typed_data.start_index, pile)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	accept_drop(data)


func accept_drop(data: Variant) -> void:
	if not data is CardDragData or not can_accept_drop(data):
		return
	cards_dropped.emit(data as CardDragData, pile)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pile_clicked.emit(self)


func outline_cards(start_index: int) -> void:
	for i in range(maxi(start_index, 0), card_views.size()):
		card_views[i].set_outline_enabled(true)


func clear_outlines() -> void:
	for card_view in card_views:
		card_view.set_outline_enabled(false)


func show_score_popup(points: int) -> void:
	if points <= 0:
		return

	var popup := Label.new()
	popup.text = "+%d" % points
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 100
	popup.add_theme_font_size_override("font_size", SCORE_POPUP_FONT_SIZE)
	popup.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0))
	popup.add_theme_constant_override("outline_size", 6)
	add_child(popup)

	popup.position = Vector2(0.0, CARD_THEME.card_size.y * 0.35)
	popup.size = Vector2(CARD_THEME.card_size.x, 48.0)
	popup.pivot_offset = popup.size * 0.5
	popup.scale = Vector2(0.75, 0.75)

	var tween := popup.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "position:y", popup.position.y - SCORE_POPUP_RISE, SCORE_POPUP_DURATION)
	tween.tween_property(popup, "scale", Vector2.ONE, 0.2)
	tween.tween_property(popup, "modulate:a", 0.0, SCORE_POPUP_DURATION).set_delay(0.25)
	tween.chain().tween_callback(popup.queue_free)
