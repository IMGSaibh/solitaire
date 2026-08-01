class_name WinAnimation
extends Control

@export var card_scene: PackedScene

var animated_cards: Array[Dictionary] = []


func play(foundations: Array[CardPile], foundation_views: Array[PileView]) -> void:
	for foundation_index in range(foundations.size()):
		var foundation := foundations[foundation_index]
		var source_view := foundation_views[foundation_index]

		for card in foundation.cards:
			_spawn_card(card, source_view.global_position)
			await get_tree().create_timer(0.06).timeout


func _spawn_card(card: CardData, start_global_position: Vector2) -> void:
	var card_view := card_scene.instantiate() as CardView
	add_child(card_view)

	card_view.setup(card)
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_view.global_position = start_global_position
	card_view.pivot_offset = card_view.size / 2.0

	var horizontal_direction := -1.0 if randi() % 2 == 0 else 1.0
	animated_cards.append(
		{
			"view": card_view,
			"velocity": Vector2(
				horizontal_direction * randf_range(250.0, 600.0),
				randf_range(-750.0, -400.0),
			),
			"rotation_speed": randf_range(-4.0, 4.0),
			"bounces": 0,
		}
	)


func _process(delta: float) -> void:
	var floor_y := size.y

	for i in range(animated_cards.size() - 1, -1, -1):
		var state := animated_cards[i]
		var card_view := state["view"] as CardView

		if not is_instance_valid(card_view):
			animated_cards.remove_at(i)
			continue

		var velocity := state["velocity"] as Vector2

		velocity.y += 1400.0 * delta
		card_view.position += velocity * delta
		card_view.rotation += state["rotation_speed"] * delta

		if card_view.position.y + card_view.size.y >= floor_y:
			card_view.position.y = floor_y - card_view.size.y
			velocity.y = -abs(velocity.y) * 0.72
			state["bounces"] += 1

		state["velocity"] = velocity

		if state["bounces"] >= 4:
			animated_cards.remove_at(i)
			card_view.queue_free()
