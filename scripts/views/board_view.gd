class_name BoardView
extends Control

const REFERENCE_SIZE := Vector2(1920.0, 1080.0)

var reference_positions: Dictionary = {}


func _ready() -> void:
	for child in get_children():
		if child is PileView:
			reference_positions[child] = child.position
	resized.connect(_layout_board)
	_layout_board.call_deferred()


func _layout_board() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var scale_factor := minf(size.x / REFERENCE_SIZE.x, size.y / REFERENCE_SIZE.y)
	var content_offset := (size - REFERENCE_SIZE * scale_factor) * 0.5
	for node in reference_positions:
		if not is_instance_valid(node):
			continue
		var pile_view := node as PileView
		pile_view.scale = Vector2.ONE * scale_factor
		pile_view.position = content_offset + (reference_positions[node] as Vector2) * scale_factor
