class_name PileView
extends Control


@export var card_scene: PackedScene

var pile: CardPile

signal card_clicked(pile_view: PileView, card_index: int)
signal pile_clicked(pile_view: PileView)
signal card_double_clicked(pile_view: PileView, card_index: int)
signal cards_dropped(source_pile: CardPile, cards: Array[CardData],	target_pile: CardPile)

func setup(pile_data: CardPile) -> void:
	pile = pile_data
	refresh()


func refresh() -> void:
	_clear_cards()

	if pile == null:
		return

	for i in range(pile.cards.size()):
		var card := pile.cards[i]

		var card_view := card_scene.instantiate() as CardView
		add_child(card_view)

		card_view.setup(card)
		card_view.set_drag_payload(_create_drag_payload(i))
		card_view.card_clicked.connect(_on_card_view_clicked.bind(i))
		card_view.card_double_clicked.connect(_on_card_double_clicked.bind(i))

		_position_card(card_view, i)


func _clear_cards() -> void:
	for child in get_children():
		if child is CardView:
			child.queue_free()


func _position_card(card_view: CardView, index: int) -> void:
	match pile.type:
		CardPile.Type.TABLEAU:
			card_view.position = Vector2(0, index * 28)

		_:
			card_view.position = Vector2.ZERO

func _on_card_view_clicked(_card_view: CardView, card_index: int) -> void:
	card_clicked.emit(self, card_index)

func _on_card_double_clicked(_card_view: CardView, card_index: int) -> void:
	card_double_clicked.emit(self, card_index)

func _create_drag_payload(card_index: int) -> Variant:
	if pile.type == CardPile.Type.STOCK:
		return null

	if card_index != pile.cards.size() - 1 \
	and pile.type != CardPile.Type.TABLEAU:
		return null

	if pile.type == CardPile.Type.TABLEAU \
	and not KlondikeRules.can_pick_up_tableau_sequence(pile, card_index):
		return null

	var dragged_cards: Array[CardData] = []

	for i in range(card_index, pile.cards.size()):
		dragged_cards.append(pile.cards[i])

	return {
		"source_pile": pile,
		"cards": dragged_cards
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return can_accept_drop(data)

func can_accept_drop(data: Variant) -> bool:
	if not data is Dictionary:
		return false

	var source_pile := data.get("source_pile") as CardPile
	var cards: Array[CardData] = data.get("cards", [])

	if source_pile == null or source_pile == pile or cards.is_empty():
		return false

	match pile.type:
		CardPile.Type.TABLEAU:
			return KlondikeRules.can_move_sequence_to_tableau(cards, pile)

		CardPile.Type.FOUNDATION:
			return cards.size() == 1 and KlondikeRules.can_move_to_foundation(cards[0], pile)
		_:
			return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	accept_drop(data)

func accept_drop(data: Variant) -> void:
	var source_pile := data.get("source_pile") as CardPile
	var cards: Array[CardData] = data.get("cards", [])

	cards_dropped.emit(source_pile, cards, pile)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pile_clicked.emit(self)
