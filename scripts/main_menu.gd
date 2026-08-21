## Zorp Wiggles — Main Menu
## Main menu with start, settings, and quit buttons.
## Polished with entrance animations, button hover effects, and styled title.

extends Control

const SETTINGS_MENU_SCRIPT := preload("res://scripts/settings_menu.gd")
const MODE_SELECTOR_SCRIPT := preload("res://scripts/mode_selector.gd")
const CHARACTER_SELECT_SCRIPT := preload("res://scripts/character_select.gd")

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
		# ── Press feedback: quick scale-down on button down, bounce back
		#    on button up. Gives tactile "click" feedback matching the
		#    pause menu so both menus feel cohesive.
		btn.button_down.connect(_on_button_press.bind(btn))
		btn.button_up.connect(_on_button_release.bind(btn))
	# ── Phase 31: Add a "Continue" button if a save exists ──
	# Sits above the Start button. Only shown when SaveSystem reports a save.
	_add_continue_button()
	# Phase 20: Create settings menu (reused from pause menu's settings)
	_settings_menu = Control.new()
	_settings_menu.set_script(SETTINGS_MENU_SCRIPT)
	_settings_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_menu.visible = false
	add_child(_settings_menu)
	# ── Phase 25: Create Mode Selector UI ──
	# A full-screen overlay that lets the player pick Normal/Endless/Boss Rush/Speedrun.
	# The selected mode persists via GameModeManager and is used when the game starts.
	_mode_selector = Control.new()
	_mode_selector.set_script(MODE_SELECTOR_SCRIPT)
	_mode_selector.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mode_selector.mouse_filter = Control.MOUSE_FILTER_STOP
	_mode_selector.visible = false
	add_child(_mode_selector)
	# ── Phase 30: Create Character Select screen ──
	# Full-screen overlay for picking Zorp vs Zerp for solo runs.
	_character_select = Control.new()
	_character_select.set_script(CHARACTER_SELECT_SCRIPT)
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
	# Keep all menu actions visible across window sizes and aspect ratios.
	resized.connect(_layout_menu)
	_layout_menu()
	start_button.grab_focus()
	# Play entrance animation
	_animate_entrance()

## Lay out the menu from the current viewport instead of relying on the
## original 1280x720 pixel offsets. Dynamic buttons (continue/mode/character)
## previously pushed Quit and the controls legend below the viewport.
func _layout_menu() -> void:
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var center_x: float = viewport_size.x * 0.5
	var button_width: float = clampf(viewport_size.x * 0.42, 280.0, 420.0)
	var button_height: float = 52.0
	var gap: float = 10.0
	var buttons: Array[Button] = []
	if _continue_button:
		buttons.append(_continue_button)
	buttons.append(start_button)
	buttons.append(settings_button)
	var mode_button: Button = get_node_or_null("ModeSelectButton")
	var character_button: Button = get_node_or_null("CharacterSelectButton")
	if mode_button:
		buttons.append(mode_button)
	if character_button:
		buttons.append(character_button)
	buttons.append(quit_button)

	var title_top: float = maxf(24.0, viewport_size.y * 0.06)
	title_label.offset_left = maxf(16.0, center_x - minf(520.0, viewport_size.x * 0.46))
	title_label.offset_right = minf(viewport_size.x - 16.0, center_x + minf(520.0, viewport_size.x * 0.46))
	title_label.offset_top = title_top
	title_label.offset_bottom = title_top + 100.0
	title_label.add_theme_font_size_override("font_size", 42 if viewport_size.y < 700.0 else 56)
	subtitle_label.offset_left = maxf(16.0, center_x - button_width)
	subtitle_label.offset_right = minf(viewport_size.x - 16.0, center_x + button_width)
	subtitle_label.offset_top = title_label.offset_bottom + 8.0
	subtitle_label.offset_bottom = subtitle_label.offset_top + 32.0

	var total_height: float = buttons.size() * button_height + maxf(0.0, buttons.size() - 1) * gap
	var menu_top: float = subtitle_label.offset_bottom + 18.0
	var controls_top: float = viewport_size.y - 66.0
	var available_height: float = maxf(button_height, controls_top - menu_top - 12.0)
	# Compress spacing and button height on short windows before allowing scroll-
	# free content to clip. 720p keeps the full-size presentation.
	if total_height > available_height:
		gap = 6.0
		button_height = maxf(38.0, (available_height - (buttons.size() - 1) * gap) / buttons.size())
		total_height = buttons.size() * button_height + (buttons.size() - 1) * gap
	var y: float = menu_top + maxf(0.0, (available_height - total_height) * 0.5)
	for button in buttons:
		button.offset_left = center_x - button_width * 0.5
		button.offset_right = center_x + button_width * 0.5
		button.offset_top = y
		button.offset_bottom = y + button_height
		button.pivot_offset = Vector2(button_width * 0.5, button_height * 0.5)
		button.add_theme_font_size_override("font_size", 18 if button_height < 46.0 else 22)
		y += button_height + gap

	controls_label.offset_left = maxf(16.0, center_x - minf(480.0, viewport_size.x * 0.46))
	controls_label.offset_right = minf(viewport_size.x - 16.0, center_x + minf(480.0, viewport_size.x * 0.46))
	controls_label.offset_top = viewport_size.y - 62.0
	controls_label.offset_bottom = viewport_size.y - 8.0
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

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
	_continue_button.button_down.connect(_on_button_press.bind(_continue_button))
	_continue_button.button_up.connect(_on_button_release.bind(_continue_button))
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
	mode_btn.button_down.connect(_on_button_press.bind(mode_btn))
	mode_btn.button_up.connect(_on_button_release.bind(mode_btn))
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
	char_btn.button_down.connect(_on_button_press.bind(char_btn))
	char_btn.button_up.connect(_on_button_release.bind(char_btn))
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
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	title_tween.parallel().tween_property(title_label, "scale", Vector2.ONE, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Subtitle: fade in after title
	subtitle_label.modulate.a = 0.0
	var sub_tween := create_tween()
	sub_tween.tween_interval(0.2)
	sub_tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
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
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		btn_tween.parallel().tween_property(btn, "offset_top", orig_y, 0.35) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# Controls label: fade in last
	controls_label.modulate.a = 0.0
	var ctrl_tween := create_tween()
	ctrl_tween.tween_interval(0.7)
	ctrl_tween.tween_property(controls_label, "modulate:a", 1.0, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

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

## Press feedback: scale the button down to 0.92x on mouse down for a tactile
## "push" feel. The hover tween is killed so the press scale isn't fighting
## the hover scale. On release, a quick elastic bounce back gives the button
## a springy "released" feel that complements the click SFX. Matches the pause
## menu's press feedback so both menus feel cohesive.
func _on_button_press(btn: Button) -> void:
	if _hover_tweens.has(btn):
		var existing: Tween = _hover_tweens[btn]
		if is_instance_valid(existing):
			existing.kill()
	var tween := create_tween()
	tween.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.06) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_hover_tweens[btn] = tween

func _on_button_release(btn: Button) -> void:
	if _hover_tweens.has(btn):
		var existing: Tween = _hover_tweens[btn]
		if is_instance_valid(existing):
			existing.kill()
	var tween := create_tween()
	tween.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.12) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	_hover_tweens[btn] = tween

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
