## Zorp Wiggles — Main Menu
## Main menu with start, settings, and quit buttons.
## Polished with entrance animations, button hover effects, and styled title.

extends Control

@onready var start_button: Button = $StartButton
@onready var settings_button: Button = $SettingsButton
@onready var quit_button: Button = $QuitButton
@onready var title_label: Label = $Title
@onready var subtitle_label: Label = $Subtitle
@onready var controls_label: Label = $Controls
var _settings_menu: Control = null

# Track hover tweens so we can kill them before starting a new one (avoid jitter)
var _hover_tweens: Dictionary = {}  # button -> Tween

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# Connect hover signals for all menu buttons
	for btn in [start_button, settings_button, quit_button]:
		btn.mouse_entered.connect(_on_button_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_button_hover.bind(btn, false))
	# Phase 20: Create settings menu (reused from pause menu's settings)
	var sm_script = load("res://scripts/settings_menu.gd")
	_settings_menu = Control.new()
	_settings_menu.set_script(sm_script)
	_settings_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_menu.visible = false
	add_child(_settings_menu)
	# Play entrance animation
	_animate_entrance()

## Entrance animation: title fades + scales in, subtitle fades, buttons stagger up.
## Gives the menu a polished "presentation" feel instead of snapping in instantly.
func _animate_entrance() -> void:
	# Title: scale up from 0.8 + fade in with overshoot
	title_label.scale = Vector2(0.8, 0.8)
	title_label.modulate.a = 0.0
	var title_tween := create_tween()
	title_tween.tween_property(title_label, "modulate:a", 1.0, 0.4) \
		.set_ease(Tween.EASE_OUT)
	title_tween.parallel().tween_property(title_label, "scale", Vector2.ONE, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Subtitle: fade in after title
	subtitle_label.modulate.a = 0.0
	var sub_tween := create_tween()
	sub_tween.tween_interval(0.2)
	sub_tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.3) \
		.set_ease(Tween.EASE_OUT)
	# Buttons: slide up from below with staggered delay
	var buttons: Array[Button] = [start_button, settings_button, quit_button]
	for i in range(buttons.size()):
		var btn: Button = buttons[i]
		var orig_y: float = btn.offset_top
		btn.offset_top = orig_y + 40.0
		btn.modulate.a = 0.0
		var btn_tween := create_tween()
		btn_tween.tween_interval(0.3 + i * 0.08)
		btn_tween.tween_property(btn, "modulate:a", 1.0, 0.25) \
			.set_ease(Tween.EASE_OUT)
		btn_tween.parallel().tween_property(btn, "offset_top", orig_y, 0.35) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# Controls label: fade in last
	controls_label.modulate.a = 0.0
	var ctrl_tween := create_tween()
	ctrl_tween.tween_interval(0.7)
	ctrl_tween.tween_property(controls_label, "modulate:a", 1.0, 0.4) \
		.set_ease(Tween.EASE_OUT)

## Hover effect: buttons grow slightly and brighten on hover, shrink on exit.
## Uses a kill-and-recreate tween pattern to avoid jitter from overlapping tweens.
func _on_button_hover(btn: Button, is_hovering: bool) -> void:
	# Kill any existing hover tween on this button
	if _hover_tweens.has(btn):
		var existing: Tween = _hover_tweens[btn]
		if is_instance_valid(existing):
			existing.kill()
	var tween := create_tween()
	var target_scale := Vector2(1.06, 1.06) if is_hovering else Vector2.ONE
	tween.tween_property(btn, "scale", target_scale, 0.12) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_hover_tweens[btn] = tween
	# Play a subtle UI hover sound (only on enter, not exit, to avoid spam)
	if is_hovering:
		AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)

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