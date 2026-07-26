class_name PileView
extends Control

@export var card_scene: PackedScene

var pile: CardPile


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