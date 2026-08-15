class_name PileView
extends Control

const CARD_THEME: SolitaireCardTheme = preload("res://data/card_theme.tres")

@export var card_scene: PackedScene

@onready var pile_texture: TextureRect = $PileTexture

var pile: CardPile
var card_views: Array[CardView] = []

signal card_clicked(pile_view: PileView, card_index: int)
signal pile_clicked(pile_view: PileView)
signal card_released(pile_view: PileView, card_index: int)
signal cards_dropped(data: CardDragData, target_pile: CardPile)


func setup(pile_data: CardPile) -> void:
	pile = pile_data
	refresh()


func setup_with_pool(pile_data: CardPile, reusable_views: Dictionary) -> void:
	pile = pile_data
	_refresh_from_pool(reusable_views, false)
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


func refresh() -> void:
	if pile == null:
		_clear_cards()
		return

	var local_pool: Dictionary = { }
	for card_view in card_views:
		if card_view.card != null:
			local_pool[card_view.card] = card_view
	_refresh_from_pool(local_pool, true)


func _refresh_from_pool(reusable_views: Dictionary, free_unused: bool) -> void:
	var refreshed_views: Array[CardView] = []
	for i in range(pile.cards.size()):
		var card := pile.cards[i]
		var card_view: CardView = reusable_views.get(card) as CardView
		if card_view != null:
			reusable_views.erase(card)
			_adopt_card_view(card_view)
		else:
			card_view = _create_card_view()

		card_view.setup(card)
		card_view.set_drag_data(_create_drag_data(i))
		_position_card(card_view, i)
		refreshed_views.append(card_view)
		move_child(card_view, get_child_count() - 1)

	if free_unused:
		for unused_view in reusable_views.values():
			if is_instance_valid(unused_view):
				unused_view.queue_free()
		reusable_views.clear()
	card_views = refreshed_views
	_update_drop_area()


func _create_card_view() -> CardView:
	var card_view := card_scene.instantiate() as CardView
	add_child(card_view)
	_connect_card_view(card_view)
	return card_view


func _adopt_card_view(card_view: CardView) -> void:
	var old_pile_view := card_view.get_parent() as PileView
	if old_pile_view != self:
		if old_pile_view != null:
			old_pile_view.release_card_view(card_view)
		card_view.reparent(self, false)
	_connect_card_view(card_view)


func _connect_card_view(card_view: CardView) -> void:
	if not card_view.card_clicked.is_connected(_on_card_view_clicked):
		card_view.card_clicked.connect(_on_card_view_clicked)
	if not card_view.card_released.is_connected(_on_card_view_released):
		card_view.card_released.connect(_on_card_view_released)
	if not card_view.drag_finished.is_connected(_on_card_drag_finished):
		card_view.drag_finished.connect(_on_card_drag_finished)


func release_card_view(card_view: CardView) -> void:
	card_views.erase(card_view)
	_disconnect_card_view_signals(card_view)


func _disconnect_card_view_signals(card_view: CardView) -> void:
	if card_view.card_clicked.is_connected(_on_card_view_clicked):
		card_view.card_clicked.disconnect(_on_card_view_clicked)
	if card_view.card_released.is_connected(_on_card_view_released):
		card_view.card_released.disconnect(_on_card_view_released)
	if card_view.drag_finished.is_connected(_on_card_drag_finished):
		card_view.drag_finished.disconnect(_on_card_drag_finished)


func _clear_cards() -> void:
	for card_view in card_views:
		card_view.queue_free()
	card_views.clear()
	_update_drop_area()


func _position_card(card_view: CardView, index: int) -> void:
	var y_position := index * CARD_THEME.tableau_offset if pile.type == CardPile.Type.TABLEAU else 0.0
	card_view.position = Vector2(0.0, y_position)


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
