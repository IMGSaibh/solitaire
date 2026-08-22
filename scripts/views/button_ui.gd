class_name ButtonUi
extends Control

signal new_game_requested
signal auto_finish_requested
signal undo_requested
signal save_requested
signal load_requested

@onready var auto_finish_button: Button = %AutoFinishButton


func _ready() -> void:
	%NewGameButton.pressed.connect(new_game_requested.emit)
	auto_finish_button.pressed.connect(auto_finish_requested.emit)
	%UndoButton.pressed.connect(undo_requested.emit)
	%SaveButton.pressed.connect(save_requested.emit)
	%LoadButton.pressed.connect(load_requested.emit)


func set_auto_finish_available(available: bool) -> void:
	auto_finish_button.visible = available
