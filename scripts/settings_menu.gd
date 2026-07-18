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
# Track the entrance tween so we can kill it before starting a new one
var _entrance_tween: Tween = null
# Track whether the menu is currently animating out (prevents re-show flicker)
var _animating_out: bool = false


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
	_panel.offset_bottom = 620.0
	# Set pivot to center so scale animations scale from the middle
	# (same pattern as pause_menu — gives a proper pop-in effect)
	_panel.pivot_offset = Vector2(350.0, 260.0)  # (right-left)/2, (bottom-top)/2
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
		"RClick+Drag — Camera Rotate\n" +
		"\n" +
		"CO-OP (Player 2):\n" +
		"Arrows — Move | . — Shoot | Enter — Dash\n" +
		"RShift — Pulse | / — Revive | Enter(hold) — Drop In/Out"
	)
	_controls_label.add_theme_font_size_override("font_size", 14)
	_controls_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.8))
	add_child(_controls_label)

	# Back button
	_back_btn = Button.new()
	_back_btn.offset_left = 490.0
	_back_btn.offset_top = 540.0
	_back_btn.offset_right = 790.0
	_back_btn.offset_bottom = 590.0
	_back_btn.text = "← Back"
	_back_btn.add_theme_font_size_override("font_size", 18)
	add_child(_back_btn)
	_back_btn.pressed.connect(_on_back)


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
	)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		_on_back()
		get_viewport().set_input_as_handled()