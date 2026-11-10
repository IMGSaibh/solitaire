class_name ButtonUi
extends Control

signal new_game_requested
signal restart_game_requested
signal auto_finish_requested
signal undo_requested
signal save_requested
signal load_requested
signal music_toggled(enabled: bool)

@onready var auto_finish_button: Button = %AutoFinishButton
@onready var new_game_button: Button = %NewGameButton
@onready var music_button: Button = %MusicButton


func _ready() -> void:
	%NewGameButton.pressed.connect(new_game_requested.emit)
	%RestartGameButton.pressed.connect(restart_game_requested.emit)
	auto_finish_button.pressed.connect(auto_finish_requested.emit)
	%UndoButton.pressed.connect(undo_requested.emit)
	%SaveButton.pressed.connect(save_requested.emit)
	%LoadButton.pressed.connect(load_requested.emit)
	music_button.toggled.connect(_on_music_toggled)
	_update_music_button_text(music_button.button_pressed)


func set_auto_finish_available(available: bool) -> void:
	auto_finish_button.visible = available


func set_new_game_available(available: bool) -> void:
	new_game_button.disabled = not available


func set_music_enabled(enabled: bool) -> void:
	music_button.set_pressed_no_signal(enabled)
	_update_music_button_text(enabled)


func _on_music_toggled(enabled: bool) -> void:
	_update_music_button_text(enabled)
	music_toggled.emit(enabled)


func _update_music_button_text(enabled: bool) -> void:
	music_button.text = "Musik: An" if enabled else "Musik: Aus"
	music_button.tooltip_text = "Musik ausschalten" if enabled else "Musik einschalten"
