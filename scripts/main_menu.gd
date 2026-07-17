## Zorp Wiggles — Main Menu
## Main menu with start, settings, and quit buttons.

extends Control

@onready var start_button: Button = $StartButton
@onready var settings_button: Button = $SettingsButton
@onready var quit_button: Button = $QuitButton
var _settings_menu: Control = null

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# Phase 20: Create settings menu (reused from pause menu's settings)
	var sm_script = load("res://scripts/settings_menu.gd")
	_settings_menu = Control.new()
	_settings_menu.set_script(sm_script)
	_settings_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_menu.visible = false
	add_child(_settings_menu)

func _on_start_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	# Start biome music once the game scene loads
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_settings_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	if _settings_menu:
		_settings_menu.visible = true
		_settings_menu.show_menu()

func _on_quit_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	AudioManager.stop_music()
	get_tree().quit()