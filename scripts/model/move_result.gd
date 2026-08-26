class_name MoveResult
extends RefCounted

var succeeded: bool
var points_awarded: int


func _init(p_succeeded: bool, p_points_awarded: int = 0) -> void:
	succeeded = p_succeeded
	points_awarded = p_points_awarded


static func success(points: int = 0) -> MoveResult:
	return MoveResult.new(true, points)


static func failure() -> MoveResult:
	return MoveResult.new(false)
