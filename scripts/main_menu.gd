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
var _mode_selector: Control = null
var _character_select: Control = null  # Phase 30: Character select screen
var _continue_button: Button = null  # Phase 31: Continue from save

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
	# ── Phase 31: Add a "Continue" button if a save exists ──
	# Sits above the Start button. Only shown when SaveSystem reports a save.
	_add_continue_button()
	# Phase 20: Create settings menu (reused from pause menu's settings)
	var sm_script = load("res://scripts/settings_menu.gd")
	_settings_menu = Control.new()
	_settings_menu.set_script(sm_script)
	_settings_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_menu.visible = false
	add_child(_settings_menu)
	# ── Phase 25: Create Mode Selector UI ──
	# A full-screen overlay that lets the player pick Normal/Endless/Boss Rush/Speedrun.
	# The selected mode persists via GameModeManager and is used when the game starts.
	var ms_script = load("res://scripts/mode_selector.gd")
	_mode_selector = Control.new()
	_mode_selector.set_script(ms_script)
	_mode_selector.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mode_selector.mouse_filter = Control.MOUSE_FILTER_STOP
	_mode_selector.visible = false
	add_child(_mode_selector)
	# ── Phase 30: Create Character Select screen ──
	# Full-screen overlay for picking Zorp vs Zerp for solo runs.
	var cs_script = load("res://scripts/character_select.gd")
	_character_select = Control.new()
	_character_select.set_script(cs_script)
	_character_select.set_anchors_preset(Control.PRESET_FULL_RECT)
	_character_select.mouse_filter = Control.MOUSE_FILTER_STOP
	_character_select.visible = false
	add_child(_character_select)
	# Add a "Mode Select" button between Settings and Quit
	_add_mode_select_button()
	# ── Phase 30: Add a "Character" button between Mode and Quit ──
	_add_character_select_button()
	# Show the currently selected mode on the subtitle
	_update_mode_subtitle()
	# Play entrance animation
	_animate_entrance()

# ── Phase 31: Add a "Continue" button above Start if a save exists ──
# The button shows a short summary of the save (level, biome, time) so the
# player knows what they're resuming. If no save exists, the button is hidden
# and the Start button stays in its default position.
func _add_continue_button() -> void:
	if not SaveSystem or not SaveSystem.has_method("has_save"):
		return
	if not SaveSystem.has_save():
		return
	_continue_button = Button.new()
	_continue_button.name = "ContinueButton"
	_continue_button.offset_left = 490.0
	_continue_button.offset_top = 260.0
	_continue_button.offset_right = 790.0
	_continue_button.offset_bottom = 310.0
	_continue_button.add_theme_font_size_override("font_size", 18)
	var summary: String = SaveSystem.get_save_summary()
	_continue_button.text = "↺  CONTINUE\n" + summary
	_continue_button.pressed.connect(_on_continue_pressed)
	_continue_button.mouse_entered.connect(_on_button_hover.bind(_continue_button, true))
	_continue_button.mouse_exited.connect(_on_button_hover.bind(_continue_button, false))
	add_child(_continue_button)
	# Move it to be the first child (above Start) in the tree order
	move_child(_continue_button, start_button.get_index())
	# Shift the Start button down to make room
	start_button.offset_top = 340.0
	start_button.offset_bottom = 400.0
	# Shift Settings down too
	settings_button.offset_top = 420.0
	settings_button.offset_bottom = 480.0

func _on_continue_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	if SaveSystem and SaveSystem.has_method("load_and_restart"):
		if not SaveSystem.load_and_restart():
			GameManager.add_message("⚠ Could not load save — starting fresh")
			# Phase 35: use fade transition instead of a hard cut
			SceneTransition.change_scene("res://scenes/main.tscn")

# ── Phase 25: Add a "Mode Select" button to the menu programmatically ──
# We create it in code rather than editing the .tscn so the scene file stays
# stable. The button sits between Settings and Quit, matching their style.
func _add_mode_select_button() -> void:
	var mode_btn := Button.new()
	mode_btn.name = "ModeSelectButton"
	mode_btn.offset_left = 490.0
	mode_btn.offset_top = 500.0
	mode_btn.offset_right = 790.0
	mode_btn.offset_bottom = 560.0
	mode_btn.add_theme_font_size_override("font_size", 24)
	# Label includes the current mode so the player sees what's selected
	mode_btn.text = "🎮  MODE: %s" % (GameModeManager.get_mode_name() if GameModeManager else "Normal")
	mode_btn.pressed.connect(_on_mode_select_pressed)
	mode_btn.mouse_entered.connect(_on_button_hover.bind(mode_btn, true))
	mode_btn.mouse_exited.connect(_on_button_hover.bind(mode_btn, false))
	# Insert before the Quit button so the order is Start → Settings → Mode → Quit
	# We use move_child to reposition if needed; add_child appends by default.
	add_child(mode_btn)
	# Move it to be before the Quit button in the tree
	# get_index() returns the child's position in the parent's children list
	if quit_button:
		var quit_idx: int = quit_button.get_index()
		if quit_idx >= 0:
			move_child(mode_btn, quit_idx)
	# Shift the Quit button down to make room (its offset_top is 480 → 600)
	# Phase 30: extra room for the Character Select button at 540
	if quit_button:
		quit_button.offset_top = 640.0
		quit_button.offset_bottom = 700.0
	# Also shift the controls label down
	if controls_label:
		controls_label.offset_top = 750.0
		controls_label.offset_bottom = 860.0
	# Connect to mode-changed signal so the button label updates live
	if GameModeManager:
		GameModeManager.mode_changed.connect(_on_mode_changed)

# ── Phase 30: Add a "Character" button between Mode and Quit ──
# Opens the character select screen (Zorp vs Zerp for solo runs).
func _add_character_select_button() -> void:
	var char_btn := Button.new()
	char_btn.name = "CharacterSelectButton"
	char_btn.offset_left = 490.0
	char_btn.offset_top = 580.0
	char_btn.offset_right = 790.0
	char_btn.offset_bottom = 640.0
	char_btn.add_theme_font_size_override("font_size", 24)
	char_btn.text = "🛸  CHARACTER: %s" % _get_character_label()
	char_btn.pressed.connect(_on_character_select_pressed)
	char_btn.mouse_entered.connect(_on_button_hover.bind(char_btn, true))
	char_btn.mouse_exited.connect(_on_button_hover.bind(char_btn, false))
	add_child(char_btn)
	# Place before the Quit button
	if quit_button:
		var quit_idx: int = quit_button.get_index()
		if quit_idx >= 0:
			move_child(char_btn, quit_idx)
	# Connect to character-changed signal so the button label updates live
	if CharacterSelectManager:
		CharacterSelectManager.character_changed.connect(_on_character_changed)

func _get_character_label() -> String:
	if not CharacterSelectManager:
		return "Zorp"
	return CharacterSelectManager.get_character_name(CharacterSelectManager.get_selected_character())

func _on_character_select_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	if _character_select:
		_character_select.show_screen()

func _on_character_changed(_id: int) -> void:
	var char_btn: Button = get_node_or_null("CharacterSelectButton")
	if char_btn:
		char_btn.text = "🛸  CHARACTER: %s" % _get_character_label()

func _update_mode_subtitle() -> void:
	if not GameModeManager:
		return
	var mode_name: String = GameModeManager.get_mode_name()
	var mode_icon: String = GameModeManager.get_mode_icon()
	subtitle_label.text = "Godot Edition  |  %s %s mode" % [mode_icon, mode_name]

func _on_mode_select_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	if _mode_selector:
		_mode_selector.show_selector()

# ── Phase 25: Update the mode button label when the mode changes ──
# Connected to GameModeManager.mode_changed so the button always shows the
# currently selected mode (e.g. after picking one in the selector overlay).
func _on_mode_changed(_new_mode: int) -> void:
	var mode_btn: Button = get_node_or_null("ModeSelectButton")
	if mode_btn:
		mode_btn.text = "🎮  MODE: %s" % (GameModeManager.get_mode_name() if GameModeManager else "Normal")
	_update_mode_subtitle()

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
	# ── Phase 25: Include the Mode Select button in the stagger animation ──
	# ── Phase 30: Include the Character Select button too ──
	# ── Phase 31: Include the Continue button too ──
	var mode_btn_node: Button = get_node_or_null("ModeSelectButton")
	var char_btn_node: Button = get_node_or_null("CharacterSelectButton")
	var buttons: Array[Button] = []
	if _continue_button:
		buttons.append(_continue_button)
	buttons.append(start_button)
	buttons.append(settings_button)
	if mode_btn_node:
		buttons.append(mode_btn_node)
	if char_btn_node:
		buttons.append(char_btn_node)
	buttons.append(quit_button)
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
		AudioManager.play_sfx(AudioManager.SFX_UI_HOVER)

func _on_start_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	# Phase 35: fade transition into the game scene
	SceneTransition.change_scene("res://scenes/main.tscn")

func _on_settings_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	if _settings_menu:
		_settings_menu.visible = true
		_settings_menu.show_menu()

func _on_quit_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	AudioManager.stop_music()
	get_tree().quit()