## Zorp Wiggles — Settings Menu (Phase 20: Audio & Polish)
## Accessible from the pause menu. Provides volume sliders (Master/SFX/Music)
## and a controls reference. Changes apply immediately.

extends Control

class_name SettingsMenu

var _bg: ColorRect
var _panel: Panel
var _title: Label
var _back_btn: Button
var _master_slider: HSlider
var _sfx_slider: HSlider
var _music_slider: HSlider
var _master_label: Label
var _sfx_label: Label
var _music_label: Label
var _controls_label: Label
# ── Phase 30/31: Accessibility controls ──
var _acc_label: Label
var _filter_label: Label
var _filter_btn: Button
var _cb_label: Label
var _cb_btn: Button
var _scale_label: Label
var _scale_slider: HSlider
var _rebind_menu: Control = null  # Phase 31: Control rebinding overlay
var _autosave_btn: Button = null  # Phase 31: Auto-save toggle
var _tutorial_btn: Button = null  # Phase 31: Tutorial replay button
# Track the entrance tween so we can kill it before starting a new one
var _entrance_tween: Tween = null
# Track whether the menu is currently animating out (prevents re-show flicker)
var _animating_out: bool = false
# Track hover tweens so we can kill them before starting a new one (avoid jitter).
# Matches the hover-juice pattern used in main_menu, pause_menu, crafting_menu,
# death_screen, and victory_screen so all Button-based menus share a cohesive
# feel: buttons grow ~6% on hover with a short ease, shrink back on exit.
var _hover_tweens: Dictionary = {}  # button -> Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	# Background
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.02, 0.0, 0.05, 0.8)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# Panel
	_panel = Panel.new()
	_panel.offset_left = 290.0
	_panel.offset_top = 100.0
	_panel.offset_right = 990.0
	_panel.offset_bottom = 720.0
	# Set pivot to center so scale animations scale from the middle
	# (same pattern as pause_menu — gives a proper pop-in effect)
	_panel.pivot_offset = Vector2(350.0, 310.0)  # (right-left)/2, (bottom-top)/2
	add_child(_panel)

	# Title
	_title = Label.new()
	_title.offset_left = 300.0
	_title.offset_top = 120.0
	_title.offset_right = 980.0
	_title.offset_bottom = 170.0
	_title.text = "⚙ Settings"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	add_child(_title)

	# Volume section
	var section_y = 200.0
	_master_label = _make_label("Master Volume", 320.0, section_y, 200.0, 30.0)
	add_child(_master_label)
	_master_slider = _make_slider(540.0, section_y, 300.0)
	_master_slider.value = AudioManager.master_volume * 100.0
	_master_slider.value_changed.connect(_on_master_changed)
	add_child(_master_slider)

	_sfx_label = _make_label("SFX Volume", 320.0, section_y + 50.0, 200.0, 30.0)
	add_child(_sfx_label)
	_sfx_slider = _make_slider(540.0, section_y + 50.0, 300.0)
	_sfx_slider.value = AudioManager.sfx_volume * 100.0
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	add_child(_sfx_slider)

	_music_label = _make_label("Music Volume", 320.0, section_y + 100.0, 200.0, 30.0)
	add_child(_music_label)
	_music_slider = _make_slider(540.0, section_y + 100.0, 300.0)
	_music_slider.value = AudioManager.music_volume * 100.0
	_music_slider.value_changed.connect(_on_music_changed)
	add_child(_music_slider)

	# Controls reference
	_controls_label = Label.new()
	_controls_label.offset_left = 320.0
	_controls_label.offset_top = section_y + 170.0
	_controls_label.offset_right = 960.0
	_controls_label.offset_bottom = section_y + 370.0
	_controls_label.text = (
		"CONTROLS\n" +
		"WASD — Move | Mouse — Aim | LClick — Shoot\n" +
		"Space — Dash | Q — Pulse Wave | E — Trade\n" +
		"F — Summon Pet | G — Pet Fetch | C — Crafting\n" +
		"M — Minimap | Tab — Missions | P — Pause\n" +
		"T — Interact | V — Deploy | H — Fast Travel\n" +
		"X — Equipment | K — Skill Tree | F2 — Stats\n" +
		"F3 — FPS | MClick — Ping | F6 — Color Filter\n" +
		"F7 — Colorblind | F8 — UI Scale\n" +
		"RClick+Drag — Camera Rotate\n" +
		"\n" +
		"CO-OP (Player 2):\n" +
		"Arrows — Move | . — Shoot | Enter — Dash\n" +
		"RShift — Pulse | / — Revive | Enter(hold) — Drop In/Out"
	)
	_controls_label.add_theme_font_size_override("font_size", 14)
	_controls_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.8))
	add_child(_controls_label)

	# ── Phase 30/31: Accessibility section — color filter, colorblind, UI scale ──
	var acc_y: float = section_y + 250.0
	_acc_label = _make_label("── Accessibility ──", 320.0, acc_y, 360.0, 24.0)
	_acc_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	add_child(_acc_label)

	# Color filter cycle button
	_filter_label = _make_label("Color Filter", 320.0, acc_y + 30.0, 200.0, 30.0)
	add_child(_filter_label)
	_filter_btn = Button.new()
	_filter_btn.offset_left = 540.0
	_filter_btn.offset_top = acc_y + 28.0
	_filter_btn.offset_right = 840.0
	_filter_btn.offset_bottom = acc_y + 56.0
	_filter_btn.add_theme_font_size_override("font_size", 14)
	add_child(_filter_btn)
	_filter_btn.pressed.connect(_on_filter_cycle)
	_refresh_filter_label()

	# Colorblind mode cycle button
	_cb_label = _make_label("Colorblind Mode", 320.0, acc_y + 60.0, 200.0, 30.0)
	add_child(_cb_label)
	_cb_btn = Button.new()
	_cb_btn.offset_left = 540.0
	_cb_btn.offset_top = acc_y + 58.0
	_cb_btn.offset_right = 840.0
	_cb_btn.offset_bottom = acc_y + 86.0
	_cb_btn.add_theme_font_size_override("font_size", 14)
	add_child(_cb_btn)
	_cb_btn.pressed.connect(_on_colorblind_cycle)
	_refresh_colorblind_label()

	# UI scale slider
	_scale_label = _make_label("UI Scale", 320.0, acc_y + 90.0, 200.0, 30.0)
	add_child(_scale_label)
	_scale_slider = _make_slider(540.0, acc_y + 90.0, 300.0)
	_scale_slider.min_value = AccessibilityManager.UI_SCALE_MIN * 100.0
	_scale_slider.max_value = AccessibilityManager.UI_SCALE_MAX * 100.0
	_scale_slider.step = AccessibilityManager.UI_SCALE_STEP * 100.0
	_scale_slider.value = AccessibilityManager.get_ui_scale() * 100.0
	_scale_slider.value_changed.connect(_on_ui_scale_changed)
	add_child(_scale_slider)

	# ── Phase 31: Rebind Controls button ──
	# Opens the control rebinding overlay (full-screen). Sits below the UI
	# scale slider and above the back button.
	var rebind_btn := Button.new()
	rebind_btn.offset_left = 320.0
	rebind_btn.offset_top = acc_y + 130.0
	rebind_btn.offset_right = 840.0
	rebind_btn.offset_bottom = acc_y + 160.0
	rebind_btn.text = "⌨  Rebind Controls..."
	rebind_btn.add_theme_font_size_override("font_size", 14)
	add_child(rebind_btn)
	rebind_btn.pressed.connect(_on_rebind_controls)
	# Create the rebind menu (hidden by default)
	var rb_script = load("res://scripts/control_rebind_menu.gd")
	_rebind_menu = Control.new()
	_rebind_menu.set_script(rb_script)
	_rebind_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rebind_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_rebind_menu.visible = false
	add_child(_rebind_menu)

	# ── Phase 31: Gameplay section — auto-save toggle, tutorial replay ──
	var game_y: float = acc_y + 175.0
	var game_label := _make_label("── Gameplay ──", 320.0, game_y, 360.0, 24.0)
	game_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	add_child(game_label)

	# Auto-save toggle button
	var autosave_label := _make_label("Auto-Save", 320.0, game_y + 30.0, 200.0, 30.0)
	add_child(autosave_label)
	_autosave_btn = Button.new()
	_autosave_btn.offset_left = 540.0
	_autosave_btn.offset_top = game_y + 28.0
	_autosave_btn.offset_right = 840.0
	_autosave_btn.offset_bottom = game_y + 56.0
	_autosave_btn.add_theme_font_size_override("font_size", 14)
	add_child(_autosave_btn)
	_autosave_btn.pressed.connect(_on_autosave_toggle)
	_refresh_autosave_label()

	# Tutorial replay button
	_tutorial_btn = Button.new()
	_tutorial_btn.offset_left = 320.0
	_tutorial_btn.offset_top = game_y + 65.0
	_tutorial_btn.offset_right = 840.0
	_tutorial_btn.offset_bottom = game_y + 95.0
	_tutorial_btn.text = "🎓  Replay Tutorial"
	_tutorial_btn.add_theme_font_size_override("font_size", 14)
	add_child(_tutorial_btn)
	_tutorial_btn.pressed.connect(_on_tutorial_replay)

	# Back button
	_back_btn = Button.new()
	_back_btn.offset_left = 490.0
	_back_btn.offset_top = 620.0
	_back_btn.offset_right = 790.0
	_back_btn.offset_bottom = 670.0
	_back_btn.text = "← Back"
	_back_btn.add_theme_font_size_override("font_size", 18)
	add_child(_back_btn)
	_back_btn.pressed.connect(_on_back)
	# Connect hover signals for all settings buttons so they share the
	# cohesive hover-juice used across every other Button-based menu.
	for btn in [_back_btn, _filter_btn, _cb_btn, rebind_btn]:
		btn.mouse_entered.connect(_on_button_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_button_hover.bind(btn, false))


func _make_label(text: String, x: float, y: float, w: float, h: float) -> Label:
	var lbl = Label.new()
	lbl.offset_left = x
	lbl.offset_top = y
	lbl.offset_right = x + w
	lbl.offset_bottom = y + h
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	return lbl


func _make_slider(x: float, y: float, w: float) -> HSlider:
	var s = HSlider.new()
	s.offset_left = x
	s.offset_top = y
	s.offset_right = x + w
	s.offset_bottom = y + 30.0
	s.min_value = 0.0
	s.max_value = 100.0
	s.step = 1.0
	return s


func show_menu() -> void:
	visible = true
	_animating_out = false
	# Refresh slider values from AudioManager
	_master_slider.value = AudioManager.master_volume * 100.0
	_sfx_slider.value = AudioManager.sfx_volume * 100.0
	_music_slider.value = AudioManager.music_volume * 100.0
	# Refresh accessibility controls
	_refresh_filter_label()
	_refresh_colorblind_label()
	_refresh_autosave_label()
	if _scale_slider:
		_scale_slider.value = AccessibilityManager.get_ui_scale() * 100.0
	# ── Entrance animation: background fades in, panel scales up from 0.85
	#    with overshoot, title and controls fade in slightly after. Mirrors the
	#    pause menu's slide-in pattern so all menus share the same visual language.
	# Kill any existing entrance tween to avoid stacking
	if _entrance_tween and is_instance_valid(_entrance_tween):
		_entrance_tween.kill()
	# Reset state for a clean entrance
	_bg.modulate.a = 0.0
	_panel.scale = Vector2(0.85, 0.85)
	_panel.modulate.a = 0.0
	_title.modulate.a = 0.0
	_controls_label.modulate.a = 0.0
	_back_btn.modulate.a = 0.0
	# Fade in accessibility controls too
	for ctrl in [_acc_label, _filter_label, _filter_btn, _cb_label, _cb_btn, _scale_label, _scale_slider]:
		if ctrl:
			ctrl.modulate.a = 0.0
	_entrance_tween = create_tween()
	# Background fade
	_entrance_tween.tween_property(_bg, "modulate:a", 1.0, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Panel scale-in with overshoot (parallel to bg)
	_entrance_tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.12) \
		.set_ease(Tween.EASE_OUT)
	_entrance_tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Title + controls fade in after panel
	_entrance_tween.tween_property(_title, "modulate:a", 1.0, 0.15) \
		.set_ease(Tween.EASE_OUT)
	_entrance_tween.parallel().tween_property(_controls_label, "modulate:a", 1.0, 0.2) \
		.set_ease(Tween.EASE_OUT)
	# Accessibility controls fade in alongside controls
	for ctrl in [_acc_label, _filter_label, _filter_btn, _cb_label, _cb_btn, _scale_label, _scale_slider]:
		if ctrl:
			_entrance_tween.parallel().tween_property(ctrl, "modulate:a", 1.0, 0.2) \
				.set_ease(Tween.EASE_OUT)
	# Back button fades in last
	_entrance_tween.tween_property(_back_btn, "modulate:a", 1.0, 0.15) \
		.set_ease(Tween.EASE_OUT)


func _on_master_changed(value: float) -> void:
	AudioManager.set_master_volume(value / 100.0)
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)


func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value / 100.0)
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)


func _on_music_changed(value: float) -> void:
	AudioManager.set_music_volume(value / 100.0)


# ── Phase 30/31: Accessibility handlers ──

func _on_filter_cycle() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	AccessibilityManager.cycle_filter()
	_refresh_filter_label()

func _refresh_filter_label() -> void:
	if not _filter_btn:
		return
	var mode: int = AccessibilityManager.get_filter()
	_filter_btn.text = AccessibilityManager.FILTER_NAMES[mode] + "  ▸"
	_filter_btn.modulate = Color(1.0, 1.0, 1.0) if mode == 0 else Color(1.0, 0.95, 0.8)

func _on_colorblind_cycle() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	AccessibilityManager.cycle_colorblind_mode()
	_refresh_colorblind_label()

func _refresh_colorblind_label() -> void:
	if not _cb_btn:
		return
	var mode: int = AccessibilityManager.get_colorblind_mode()
	_cb_btn.text = AccessibilityManager.COLORBLIND_NAMES[mode] + "  ▸"
	_cb_btn.modulate = Color(1.0, 1.0, 1.0) if mode == 0 else Color(0.9, 1.0, 0.9)

func _on_ui_scale_changed(value: float) -> void:
	AccessibilityManager.set_ui_scale(value / 100.0)
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)

# ── Phase 31: Open the control rebinding overlay ──
func _on_rebind_controls() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	if _rebind_menu:
		_rebind_menu.visible = true
		_rebind_menu.show_menu()

# ── Phase 31: Auto-save toggle ──
func _on_autosave_toggle() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	if SaveSystem and SaveSystem.has_method("toggle_autosave"):
		SaveSystem.toggle_autosave()
	_refresh_autosave_label()

func _refresh_autosave_label() -> void:
	if not _autosave_btn:
		return
	if SaveSystem and SaveSystem.autosave_enabled:
		_autosave_btn.text = "ON  ✓"
		_autosave_btn.modulate = Color(0.9, 1.0, 0.9)
	else:
		_autosave_btn.text = "OFF  ✗"
		_autosave_btn.modulate = Color(1.0, 1.0, 1.0)

# ── Phase 31: Tutorial replay ──
func _on_tutorial_replay() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	if TutorialManager and TutorialManager.has_method("replay"):
		TutorialManager.replay()
		GameManager.add_message("🎓 Tutorial will replay as you play")

## Hover effect: buttons grow slightly (~6%) on hover and shrink back on exit.
## Mirrors the main/pause/crafting/death/victory menu hover juice so all
## Button-based menus share a cohesive feel. Pivot is set to the button center
## so the scale grows from the middle, not the top-left corner.
func _on_button_hover(btn: Button, is_hovering: bool) -> void:
	if not is_instance_valid(btn):
		return
	# Keep pivot centered so scale grows from the middle
	btn.pivot_offset = btn.size * 0.5
	# Kill any existing hover tween on this button
	if _hover_tweens.has(btn):
		var existing: Tween = _hover_tweens[btn]
		if is_instance_valid(existing):
			existing.kill()
		_hover_tweens.erase(btn)
	# Opportunistically clean up freed buttons from the dict
	for key in _hover_tweens.keys():
		if not is_instance_valid(key):
			_hover_tweens.erase(key)
	var target_scale := Vector2(1.06, 1.06) if is_hovering else Vector2.ONE
	var tween: Tween = create_tween()
	tween.tween_property(btn, "scale", target_scale, 0.12) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_hover_tweens[btn] = tween
	# Play a subtle UI hover sound on enter only (avoids spam on exit)
	if is_hovering:
		AudioManager.play_sfx(AudioManager.SFX_UI_HOVER)

func _on_back() -> void:
	if _animating_out:
		return  # Already animating out — don't double-trigger
	_animating_out = true
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	# ── Exit animation: panel scales down slightly + fades, background fades.
	#    The menu hides after the tween completes so it doesn't hard-cut. Mirrors
	#    the pause menu's resume animation for consistent menu language.
	if _entrance_tween and is_instance_valid(_entrance_tween):
		_entrance_tween.kill()
	_entrance_tween = create_tween()
	_entrance_tween.tween_property(_bg, "modulate:a", 0.0, 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_entrance_tween.parallel().tween_property(_panel, "modulate:a", 0.0, 0.15) \
		.set_ease(Tween.EASE_IN)
	_entrance_tween.parallel().tween_property(_panel, "scale", Vector2(0.9, 0.9), 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_entrance_tween.parallel().tween_property(_title, "modulate:a", 0.0, 0.12) \
		.set_ease(Tween.EASE_IN)
	_entrance_tween.parallel().tween_property(_controls_label, "modulate:a", 0.0, 0.12) \
		.set_ease(Tween.EASE_IN)
	_entrance_tween.parallel().tween_property(_back_btn, "modulate:a", 0.0, 0.12) \
		.set_ease(Tween.EASE_IN)
	# Fade out accessibility controls
	for ctrl in [_acc_label, _filter_label, _filter_btn, _cb_label, _cb_btn, _scale_label, _scale_slider]:
		if ctrl:
			_entrance_tween.parallel().tween_property(ctrl, "modulate:a", 0.0, 0.12) \
				.set_ease(Tween.EASE_IN)
	_entrance_tween.tween_callback(func():
		visible = false
		_animating_out = false
		# Reset visual state for next show
		_bg.modulate.a = 1.0
		_panel.modulate.a = 1.0
		_panel.scale = Vector2.ONE
		_title.modulate.a = 1.0
		_controls_label.modulate.a = 1.0
		_back_btn.modulate.a = 1.0
		# Reset hover scale on all buttons so reopening doesn't show a
		# leftover scaled-up button if the cursor was hovering on close.
		for btn in [_back_btn, _filter_btn, _cb_btn]:
			if btn:
				btn.scale = Vector2.ONE
		for ctrl in [_acc_label, _filter_label, _filter_btn, _cb_label, _cb_btn, _scale_label, _scale_slider]:
			if ctrl:
				ctrl.modulate.a = 1.0
	)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		_on_back()
		get_viewport().set_input_as_handled()