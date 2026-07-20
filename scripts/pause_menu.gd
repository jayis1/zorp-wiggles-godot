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

# Track hover tweens so we can kill them before starting a new one (avoid jitter)
var _hover_tweens: Dictionary = {}  # button -> Tween


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
	# Set pivot to center so scale animations (slide-in) scale from the middle
	# instead of the top-left corner, giving a proper "pop" effect.
	_panel.pivot_offset = Vector2(250.0, 180.0)  # (right-left)/2, (bottom-top)/2
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

	# Connect hover signals for all pause menu buttons (matches main menu polish)
	for btn in [_resume_btn, _settings_btn, _quit_btn]:
		btn.mouse_entered.connect(_on_button_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_button_hover.bind(btn, false))

	# Settings menu (hidden by default)
	var sm_script = load("res://scripts/settings_menu.gd")
	_settings_menu = Control.new()
	_settings_menu.set_script(sm_script)
	_settings_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_menu.visible = false
	add_child(_settings_menu)


func _unhandled_input(event: InputEvent) -> void:
	# ── Phase 35: Input handling audit ──
	# Don't allow pausing when a death or victory screen is showing.
	# Those screens own the pause state and have their own buttons.
	# Without this guard, the pause menu would open on top of them
	# and the player could get stuck in a nested pause state.
	if event.is_action_pressed("pause"):
		if GameManager and not GameManager.player_is_alive and not GameManager.player_is_downed:
			# Player is dead (not downed) — death screen owns the state
			get_viewport().set_input_as_handled()
			return
		# Check for active victory screen via its is_shown-like state
		var victory: Node = get_tree().get_first_node_in_group("victory_screen")
		if victory and victory.has_method("is_shown") and victory.is_shown():
			get_viewport().set_input_as_handled()
			return
		# Check for active intro cinematic — pausing during the cinematic
		# would freeze the cinematic tween (PROCESS_MODE_ALWAYS on the
		# pause menu, but the cinematic isn't paused-aware) and leave the
		# player stuck with no way to resume the cinematic.
		if GameManager and GameManager.player and is_instance_valid(GameManager.player):
			if GameManager.player.has_meta("cinematic_active") and bool(GameManager.player.get_meta("cinematic_active", false)):
				get_viewport().set_input_as_handled()
				return
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
	# ── Smooth slide-in animation: the panel scales up from 80% with a fade,
	#    and each button slides in from below with a staggered delay. This makes
	#    pausing feel polished instead of a hard snap. The tweens use
	#    PROCESS_MODE_ALWAYS (inherited from this node) so they run while the
	#    tree is paused.
	_animate_pause_in()

func _animate_pause_in() -> void:
	# Fade in the background
	_bg.modulate.a = 0.0
	var bg_tween := create_tween()
	bg_tween.tween_property(_bg, "modulate:a", 1.0, 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Panel scale-in from 0.8 with overshoot
	_panel.scale = Vector2(0.8, 0.8)
	_panel.modulate.a = 0.0
	var panel_tween := create_tween()
	panel_tween.tween_property(_panel, "modulate:a", 1.0, 0.15) \
		.set_ease(Tween.EASE_OUT)
	panel_tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Title fades in slightly after the panel
	_title.modulate.a = 0.0
	var title_tween := create_tween()
	title_tween.tween_interval(0.08)
	title_tween.tween_property(_title, "modulate:a", 1.0, 0.2) \
		.set_ease(Tween.EASE_OUT)
	# Buttons slide up from below with staggered delays
	var buttons: Array[Button] = [_resume_btn, _settings_btn, _quit_btn]
	for i in range(buttons.size()):
		var btn: Button = buttons[i]
		var orig_y: float = btn.offset_top
		btn.offset_top = orig_y + 30.0  # Start 30px below
		btn.modulate.a = 0.0
		var btn_tween := create_tween()
		btn_tween.tween_interval(0.1 + i * 0.06)
		btn_tween.tween_property(btn, "modulate:a", 1.0, 0.15) \
			.set_ease(Tween.EASE_OUT)
		btn_tween.parallel().tween_property(btn, "offset_top", orig_y, 0.25) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## Hover effect: buttons grow slightly on hover, shrink on exit.
## Mirrors the main menu's hover juice so both menus feel cohesive.
## Uses a kill-and-recreate tween pattern to avoid jitter from overlapping tweens.
## Plays a subtle UI click sound on enter only (not exit, to avoid spam).
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
	if is_hovering:
		AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)


func _on_resume() -> void:
	_is_paused = false
	# ── Smooth fade-out: panel and buttons fade and scale down slightly before
	#    the menu disappears. The unpause happens immediately (game resumes
	#    right away) but the visual lingers for ~0.15s so it doesn't hard-cut.
	GameManager.is_paused = false
	get_tree().paused = false
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	# Fade out everything
	if _bg:
		var bg_out := create_tween()
		bg_out.tween_property(_bg, "modulate:a", 0.0, 0.15) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	if _panel:
		var panel_out := create_tween()
		panel_out.tween_property(_panel, "modulate:a", 0.0, 0.15) \
			.set_ease(Tween.EASE_IN)
		panel_out.parallel().tween_property(_panel, "scale", Vector2(0.9, 0.9), 0.15) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		panel_out.tween_callback(func():
			visible = false
			# Reset visual state for next pause
			_bg.modulate.a = 1.0
			_panel.modulate.a = 1.0
			_panel.scale = Vector2.ONE
			_title.modulate.a = 1.0
			for btn in [_resume_btn, _settings_btn, _quit_btn]:
				btn.modulate.a = 1.0
				btn.scale = Vector2.ONE  # Reset hover scale
		)
	else:
		visible = false


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
	# Phase 35: fade transition back to the main menu
	SceneTransition.change_scene("res://scenes/main_menu.tscn")