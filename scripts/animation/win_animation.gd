class_name WinAnimation
extends Control

@export var card_scene: PackedScene

var animated_cards: Array[Dictionary] = []
var play_generation := 0


func _ready() -> void:
	set_process(false)


func play(foundations: Array[CardPile], foundation_views: Array[PileView]) -> void:
	stop()
	play_generation += 1
	var current_generation := play_generation
	set_process(true)

	for foundation_index in range(mini(foundations.size(), foundation_views.size())):
		var foundation := foundations[foundation_index]
		var source_view := foundation_views[foundation_index]
		for card in foundation.cards:
			if current_generation != play_generation:
				return
			_spawn_card(card, source_view)
			await get_tree().create_timer(0.06).timeout


func stop() -> void:
	play_generation += 1
	for state in animated_cards:
		var card_view := state.get("view") as CardView
		if is_instance_valid(card_view):
			card_view.queue_free()
	animated_cards.clear()
	set_process(false)


func _spawn_card(card: CardData, source_view: PileView) -> void:
	var card_view := card_scene.instantiate() as CardView
	add_child(card_view)
	card_view.setup(card)
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_view.global_position = source_view.global_position
	card_view.scale = source_view.get_global_transform().get_scale()
	card_view.pivot_offset = card_view.size / 2.0

	var horizontal_direction := -1.0 if randi() % 2 == 0 else 1.0
	animated_cards.append(
		{
			"view": card_view,
			"velocity": Vector2(horizontal_direction * randf_range(250.0, 600.0), randf_range(-750.0, -400.0)),
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
		card_view.rotation += float(state["rotation_speed"]) * delta
		if card_view.position.y + card_view.size.y * card_view.scale.y >= floor_y:
			card_view.position.y = floor_y - card_view.size.y * card_view.scale.y
			velocity.y = -abs(velocity.y) * 0.72
			state["bounces"] = int(state["bounces"]) + 1
		state["velocity"] = velocity

		if int(state["bounces"]) >= 4:
			animated_cards.remove_at(i)
			card_view.queue_free()

	if animated_cards.is_empty():
		set_process(false)
