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
	# Refresh slider values from AudioManager
	_master_slider.value = AudioManager.master_volume * 100.0
	_sfx_slider.value = AudioManager.sfx_volume * 100.0
	_music_slider.value = AudioManager.music_volume * 100.0


func _on_master_changed(value: float) -> void:
	AudioManager.set_master_volume(value / 100.0)
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)


func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value / 100.0)
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)


func _on_music_changed(value: float) -> void:
	AudioManager.set_music_volume(value / 100.0)


func _on_back() -> void:
	visible = false
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		visible = false
		get_viewport().set_input_as_handled()