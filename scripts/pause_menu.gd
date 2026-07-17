## Zorp Wiggles — Pause Menu (Phase 20: Audio & Polish)
## Full-screen pause overlay with Resume, Settings, and Quit buttons.
## Triggered by pressing P (the "pause" input action). Pauses the scene tree
## but keeps the pause menu itself responsive (PROCESS_MODE_ALWAYS).

extends Control

class_name PauseMenu

var _bg: ColorRect
var _panel: Panel
var _title: Label
var _resume_btn: Button
var _settings_btn: Button
var _quit_btn: Button
var _settings_menu: Control = null
var _is_paused: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep working when tree is paused
	_build_ui()


func _build_ui() -> void:
	# Semi-transparent background
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.02, 0.0, 0.05, 0.7)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# Centered panel
	_panel = Panel.new()
	_panel.offset_left = 390.0
	_panel.offset_top = 180.0
	_panel.offset_right = 890.0
	_panel.offset_bottom = 540.0
	add_child(_panel)

	# Title
	_title = Label.new()
	_title.offset_left = 400.0
	_title.offset_top = 200.0
	_title.offset_right = 880.0
	_title.offset_bottom = 260.0
	_title.text = "PAUSED"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 42)
	_title.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	add_child(_title)

	# Resume button
	_resume_btn = Button.new()
	_resume_btn.offset_left = 490.0
	_resume_btn.offset_top = 290.0
	_resume_btn.offset_right = 790.0
	_resume_btn.offset_bottom = 340.0
	_resume_btn.text = "▶  Resume"
	_resume_btn.add_theme_font_size_override("font_size", 20)
	add_child(_resume_btn)
	_resume_btn.pressed.connect(_on_resume)

	# Settings button
	_settings_btn = Button.new()
	_settings_btn.offset_left = 490.0
	_settings_btn.offset_top = 360.0
	_settings_btn.offset_right = 790.0
	_settings_btn.offset_bottom = 410.0
	_settings_btn.text = "⚙  Settings"
	_settings_btn.add_theme_font_size_override("font_size", 20)
	add_child(_settings_btn)
	_settings_btn.pressed.connect(_on_settings)

	# Quit button
	_quit_btn = Button.new()
	_quit_btn.offset_left = 490.0
	_quit_btn.offset_top = 430.0
	_quit_btn.offset_right = 790.0
	_quit_btn.offset_bottom = 480.0
	_quit_btn.text = "✖  Quit to Menu"
	_quit_btn.add_theme_font_size_override("font_size", 20)
	add_child(_quit_btn)
	_quit_btn.pressed.connect(_on_quit)

	# Settings menu (hidden by default)
	var sm_script = load("res://scripts/settings_menu.gd")
	_settings_menu = Control.new()
	_settings_menu.set_script(sm_script)
	_settings_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_menu.visible = false
	add_child(_settings_menu)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _is_paused and not (_settings_menu and _settings_menu.visible):
			_on_resume()
		elif not _is_paused:
			_show_pause()
		get_viewport().set_input_as_handled()


func _show_pause() -> void:
	_is_paused = true
	visible = true
	# Hide settings if open
	if _settings_menu:
		_settings_menu.visible = false
	# Pause the game
	GameManager.is_paused = true
	get_tree().paused = true
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)


func _on_resume() -> void:
	_is_paused = false
	visible = false
	GameManager.is_paused = false
	get_tree().paused = false
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)


func _on_settings() -> void:
	if _settings_menu:
		_settings_menu.visible = true
		_settings_menu.show_menu()
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)


func _on_quit() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	# Unpause before changing scenes
	_is_paused = false
	GameManager.is_paused = false
	get_tree().paused = false
	AudioManager.stop_music()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")