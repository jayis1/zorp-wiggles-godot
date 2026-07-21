## Zorp Wiggles — Character Select Screen (Phase 30: Visual & Audio Polish)
## Full-screen overlay shown from the main menu when the player clicks
## "Character Select". Lets the player pick between Zorp (tanky all-rounder)
## and Zerp (fast & fragile) for solo runs. Each character has a stat preview
## panel showing HP, damage, dash speed, and walk speed relative to baseline.
##
## Controls:
##   ←/→ or A/D — cycle characters
##   Enter / Space — confirm selection and close
##   Esc / Backspace — close without changing selection
##   Click on a character card — select + confirm
##
## The selection persists via CharacterSelectManager and is read by player.gd
## at _ready to apply the active profile's stats + color.

extends Control

const CARD_W: float = 320.0
const CARD_H: float = 420.0
const CARD_Y: float = 200.0
const CARD_GAP: float = 80.0

var _selected_idx: int = 0
var _hover_idx: int = -1
var _bg_alpha: float = 0.0
var _appear_t: float = 0.0
var _closed: bool = false
var _back_btn: Button = null
var _confirm_btn: Button = null
var _hover_tweens: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_selected_idx = CharacterSelectManager.get_selected_character()
	# Back + Confirm buttons (bottom-right)
	_back_btn = Button.new()
	_back_btn.text = "← Back"
	_back_btn.offset_left = 360.0
	_back_btn.offset_top = 680.0
	_back_btn.offset_right = 540.0
	_back_btn.offset_bottom = 730.0
	_back_btn.add_theme_font_size_override("font_size", 20)
	_back_btn.pressed.connect(_on_back)
	_back_btn.pivot_offset = Vector2(90.0, 25.0)
	add_child(_back_btn)
	_confirm_btn = Button.new()
	_confirm_btn.text = "✓ Confirm"
	_confirm_btn.offset_left = 580.0
	_confirm_btn.offset_top = 680.0
	_confirm_btn.offset_right = 800.0
	_confirm_btn.offset_bottom = 730.0
	_confirm_btn.add_theme_font_size_override("font_size", 20)
	_confirm_btn.pressed.connect(_on_confirm)
	_confirm_btn.pivot_offset = Vector2(110.0, 25.0)
	add_child(_confirm_btn)
	for btn in [_back_btn, _confirm_btn]:
		btn.mouse_entered.connect(_on_button_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_button_hover.bind(btn, false))
	# Connect to CharacterSelectManager so external changes update the UI
	if CharacterSelectManager.character_changed.is_connected(_on_character_changed):
		CharacterSelectManager.character_changed.disconnect(_on_character_changed)
	CharacterSelectManager.character_changed.connect(_on_character_changed)


func _on_character_changed(_id: int) -> void:
	_selected_idx = _id
	queue_redraw()


## Show the screen — called from main_menu's Character Select button.
func show_screen() -> void:
	visible = true
	_closed = false
	_bg_alpha = 0.0
	_appear_t = 0.0
	_selected_idx = CharacterSelectManager.get_selected_character()
	# Animate buttons in
	for btn in [_back_btn, _confirm_btn]:
		btn.modulate.a = 0.0
		btn.scale = Vector2(0.85, 0.85)
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(_back_btn, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_back_btn, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(_confirm_btn, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT).set_delay(0.08)
	tw.parallel().tween_property(_confirm_btn, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(0.08)
	queue_redraw()


func _hide() -> void:
	visible = false
	_closed = true


func _process(delta: float) -> void:
	if not visible:
		return
	_bg_alpha = minf(_bg_alpha + delta / 0.25, 1.0)
	_appear_t = minf(_appear_t + delta / 0.4, 1.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _closed:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k == KEY_ESCAPE or k == KEY_BACKSPACE:
			_on_back()
			get_viewport().set_input_as_handled()
		elif k == KEY_ENTER or k == KEY_SPACE or k == KEY_KP_ENTER:
			_on_confirm()
			get_viewport().set_input_as_handled()
		elif k == KEY_LEFT or k == KEY_A:
			_cycle(-1)
			get_viewport().set_input_as_handled()
		elif k == KEY_RIGHT or k == KEY_D:
			_cycle(1)
			get_viewport().set_input_as_handled()


func _cycle(dir: int) -> void:
	var count: int = CharacterSelectManager.Character.size()
	_selected_idx = posmod(_selected_idx + dir, count)
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# Click on a character card to select + confirm
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var card_idx: int = _card_at_point(event.position)
		if card_idx >= 0:
			_selected_idx = card_idx
			AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
			# Delay confirm slightly so the player sees the selection highlight
			var tw := create_tween()
			tw.tween_interval(0.12)
			tw.tween_callback(_on_confirm)
			queue_redraw()


func _card_at_point(p: Vector2) -> int:
	var count: int = CharacterSelectManager.Character.size()
	var total_w: float = count * CARD_W + (count - 1) * CARD_GAP
	var start_x: float = (size.x - total_w) / 2.0
	for i in count:
		var x: float = start_x + i * (CARD_W + CARD_GAP)
		if p.x >= x and p.x <= x + CARD_W and p.y >= CARD_Y and p.y <= CARD_Y + CARD_H:
			return i
	return -1


func _on_back() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	_hide()


func _on_confirm() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	CharacterSelectManager.set_character(_selected_idx)
	_hide()


func _on_button_hover(btn: Button, is_hovering: bool) -> void:
	if _hover_tweens.has(btn):
		var existing: Tween = _hover_tweens[btn]
		if is_instance_valid(existing):
			existing.kill()
	var tw := create_tween()
	var target_scale := Vector2(1.06, 1.06) if is_hovering else Vector2.ONE
	tw.tween_property(btn, "scale", target_scale, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_hover_tweens[btn] = tw
	if is_hovering:
		AudioManager.play_sfx(AudioManager.SFX_UI_HOVER)


func _draw() -> void:
	if not visible:
		return
	var ss := size
	# Background dim
	var bg := Color(0.03, 0.03, 0.10, 0.85 * _bg_alpha)
	draw_rect(Rect2(Vector2.ZERO, ss), bg, true)
	# Title
	var title_font := get_theme_default_font()
	var title_col := Color(0.6, 0.9, 1.0, _appear_t)
	draw_string(title_font, Vector2(ss.x / 2.0 - 200.0, 90.0), "CHOOSE YOUR CHARACTER", HORIZONTAL_ALIGNMENT_CENTER, 400, 36, title_col)
	# Subtitle
	var sub_col := Color(0.7, 0.75, 0.85, _appear_t * 0.9)
	draw_string(title_font, Vector2(ss.x / 2.0 - 240.0, 130.0), "← → to switch | Enter to confirm | Esc to cancel", HORIZONTAL_ALIGNMENT_CENTER, 480, 16, sub_col)
	# Draw character cards
	var count: int = CharacterSelectManager.Character.size()
	var total_w: float = count * CARD_W + (count - 1) * CARD_GAP
	var start_x: float = (ss.x - total_w) / 2.0
	for i in count:
		var x: float = start_x + i * (CARD_W + CARD_GAP)
		var is_selected: bool = (i == _selected_idx)
		var is_hover: bool = (i == _hover_idx)
		_draw_card(i, Vector2(x, CARD_Y), is_selected, is_hover)
	# Hint text
	var hint_col := Color(0.5, 0.55, 0.7, _appear_t * 0.8)
	draw_string(title_font, Vector2(ss.x / 2.0 - 200.0, 640.0), "Selection persists across runs. P2 in co-op is always Zerp.", HORIZONTAL_ALIGNMENT_CENTER, 400, 14, hint_col)


func _draw_card(idx: int, pos: Vector2, selected: bool, hover: bool) -> void:
	var profile: Dictionary = CharacterSelectManager.get_character_profile(idx)
	var name_str: String = profile.get("name", "???")
	var desc: String = profile.get("desc", "")
	var color: Color = profile.get("color", Color.WHITE)
	var icon: String = profile.get("icon", "●")
	# Card background
	var card_rect := Rect2(pos, Vector2(CARD_W, CARD_H))
	var card_bg := Color(0.08, 0.10, 0.18, 0.95 * _appear_t)
	if selected:
		card_bg = Color(0.15, 0.20, 0.30, 0.97 * _appear_t)
	draw_rect(card_rect, card_bg, true)
	# Border
	var border_col := color if selected else Color(0.4, 0.45, 0.55, _appear_t * 0.7)
	var border_w: float = 4.0 if selected else 2.0
	draw_rect(card_rect, Color(border_col.r, border_col.g, border_col.b, border_col.a), false, border_w)
	if hover and not selected:
		draw_rect(card_rect.grow(4.0), Color(1.0, 1.0, 1.0, 0.15 * _appear_t), false, 2.0)
	# Character avatar — large colored circle with the icon
	var avatar_center := pos + Vector2(CARD_W / 2.0, 110.0)
	var avatar_r: float = 60.0
	if selected:
		# Pulsing glow ring on selected
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
		draw_circle(avatar_center, avatar_r + 12.0, Color(color.r, color.g, color.b, 0.25 * pulse * _appear_t))
	draw_circle(avatar_center, avatar_r, Color(color.r, color.g, color.b, 0.9 * _appear_t))
	# Inner highlight
	draw_circle(avatar_center - Vector2(15.0, 15.0), avatar_r * 0.4, Color(1.0, 1.0, 1.0, 0.18 * _appear_t))
	# Icon
	var font := get_theme_default_font()
	draw_string(font, avatar_center + Vector2(-20.0, 20.0), icon, HORIZONTAL_ALIGNMENT_CENTER, 40, 40, Color(1.0, 1.0, 1.0, _appear_t))
	# Name
	draw_string(font, pos + Vector2(CARD_W / 2.0 - 100.0, 220.0), name_str, HORIZONTAL_ALIGNMENT_CENTER, 200, 32, Color(1.0, 1.0, 1.0, _appear_t))
	# Description (wrapped manually — short string)
	_draw_wrapped_text(font, desc, pos + Vector2(20.0, 250.0), CARD_W - 40.0, 16, Color(0.75, 0.8, 0.9, _appear_t * 0.95))
	# Stat preview bars
	var stats_y: float = 320.0
	_draw_stat_bar(pos + Vector2(20.0, stats_y), CARD_W - 40.0, "HP", _stat_value(idx, "hp"), Color(0.3, 0.9, 0.3))
	_draw_stat_bar(pos + Vector2(20.0, stats_y + 30.0), CARD_W - 40.0, "Damage", _stat_value(idx, "dmg"), Color(0.95, 0.4, 0.3))
	_draw_stat_bar(pos + Vector2(20.0, stats_y + 60.0), CARD_W - 40.0, "Dash", _stat_value(idx, "dash"), Color(0.4, 0.7, 1.0))
	_draw_stat_bar(pos + Vector2(20.0, stats_y + 90.0), CARD_W - 40.0, "Speed", _stat_value(idx, "speed"), Color(1.0, 0.85, 0.3))
	# Selected indicator
	if selected:
		var check_col := Color(0.4, 1.0, 0.6, _appear_t)
		draw_string(font, pos + Vector2(CARD_W / 2.0 - 80.0, CARD_H - 20.0), "✓ SELECTED", HORIZONTAL_ALIGNMENT_CENTER, 160, 18, check_col)


# Convert profile stat to a 0..1 bar value (relative to baseline Zorp = 0.5)
func _stat_value(idx: int, stat: String) -> float:
	var p: Dictionary = CharacterSelectManager.get_character_profile(idx)
	match stat:
		"hp":
			var hp: int = GameConstants.PLAYER_START_HP + int(p.get("hp_bonus", 0))
			return clampf(float(hp) / 160.0, 0.1, 1.0)
		"dmg":
			return clampf(float(p.get("damage_mult", 1.0)) / 1.2, 0.1, 1.0)
		"dash":
			return clampf(float(p.get("dash_speed_mult", 1.0)) / 1.2, 0.1, 1.0)
		"speed":
			return clampf(float(p.get("speed_mult", 1.0)) / 1.2, 0.1, 1.0)
	return 0.5


func _draw_stat_bar(pos: Vector2, w: float, label: String, value: float, col: Color) -> void:
	var font := get_theme_default_font()
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, 80, 14, Color(0.8, 0.85, 0.95, _appear_t))
	# Bar background
	var bar_x: float = 90.0
	var bar_rect := Rect2(pos + Vector2(bar_x, -10.0), Vector2(w - bar_x, 12.0))
	draw_rect(bar_rect, Color(0.15, 0.18, 0.25, _appear_t * 0.8), true)
	# Bar fill
	var fill_rect := Rect2(bar_rect.position, Vector2(bar_rect.size.x * value, bar_rect.size.y))
	draw_rect(fill_rect, Color(col.r, col.g, col.b, _appear_t), true)


func _draw_wrapped_text(font: Font, text: String, pos: Vector2, max_w: float, size: int, col: Color) -> void:
	# Simple word-wrap
	var words: PackedStringArray = text.split(" ", false)
	var line: String = ""
	var y: float = pos.y
	for w in words:
		var test_line: String = line + ("" if line.is_empty() else " ") + w
		if font.get_string_size(test_line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w and not line.is_empty():
			draw_string(font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, max_w, size, col)
			y += size + 4
			line = w
		else:
			line = test_line
	if not line.is_empty():
		draw_string(font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, max_w, size, col)