## Zorp Wiggles — Skill Tree UI (Phase 25: Progression & Meta-Systems)
## Full-screen overlay showing the 3-branch skill tree.
## Press K (the "skill_tree" input action) to toggle.
## Renders 3 columns (Combat, Survival, Exploration), each with 5 skill nodes.
## Click a skill node to spend 1 skill point and rank it up.
## Shows current SP, prestige level, and a prestige button when eligible.
## Uses _draw() for rendering + _gui_input() for click detection.

extends Control

class_name SkillTreeUI

var _visible_flag: bool = false
var _fade_alpha: float = 0.0
var _hovered_skill: String = ""  # Currently mouse-hovered skill key
var _skill_rects: Dictionary = {}  # skill_key → Rect2 (for click detection)
var _prestige_btn_rect: Rect2 = Rect2()
var _close_btn_rect: Rect2 = Rect2()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ProgressionSystem:
		ProgressionSystem.skill_points_changed.connect(_on_sp_changed)
		ProgressionSystem.skill_purchased.connect(_on_skill_purchased)
		ProgressionSystem.prestige_changed.connect(_on_prestige_changed)

func _on_sp_changed(_sp: int) -> void:
	if _fade_alpha > 0.01 or _visible_flag:
		queue_redraw()

func _on_skill_purchased(_branch: int, _node_id: int, _level: int) -> void:
	if _fade_alpha > 0.01 or _visible_flag:
		queue_redraw()
	AudioManager.play_sfx(AudioManager.SFX_LEVEL_UP)

func _on_prestige_changed(_level: int) -> void:
	if _fade_alpha > 0.01 or _visible_flag:
		queue_redraw()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("skill_tree"):
		_visible_flag = not _visible_flag
		if _visible_flag:
			AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	# Smooth fade
	var target: float = 1.0 if _visible_flag else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 6.0)
	# Only accept input when visible enough
	mouse_filter = Control.MOUSE_FILTER_STOP if _fade_alpha > 0.5 else Control.MOUSE_FILTER_IGNORE
	if _fade_alpha > 0.01 or _visible_flag:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not _visible_flag or _fade_alpha < 0.5:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos: Vector2 = event.position
		# Check close button
		if _close_btn_rect.has_point(mouse_pos):
			_visible_flag = false
			AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
			return
		# Check prestige button
		if _prestige_btn_rect.has_point(mouse_pos):
			if ProgressionSystem and ProgressionSystem.can_prestige():
				ProgressionSystem.prestige()
			elif ProgressionSystem:
				GameManager.add_message("🌟 Need level %d to prestige" % ProgressionSystem.PRESTIGE_MIN_LEVEL)
			return
		# Check skill nodes
		for skill_key in _skill_rects.keys():
			if _skill_rects[skill_key].has_point(mouse_pos):
				if ProgressionSystem:
					ProgressionSystem.purchase_skill(skill_key)
				return
	elif event is InputEventMouseMotion:
		var mouse_pos: Vector2 = event.position
		var new_hover: String = ""
		for skill_key in _skill_rects.keys():
			if _skill_rects[skill_key].has_point(mouse_pos):
				new_hover = skill_key
				break
		if new_hover != _hovered_skill:
			_hovered_skill = new_hover
			queue_redraw()

func _draw() -> void:
	if _fade_alpha < 0.01:
		return
	_skill_rects.clear()
	var font := get_theme_default_font()
	if not font:
		return
	var a: float = _fade_alpha
	var screen := size
	# Full-screen dim background
	var bg := Color(0.02, 0.03, 0.08, 0.90 * a)
	draw_rect(Rect2(Vector2.ZERO, screen), bg, true)
	# Main panel
	var panel_x: float = 50.0
	var panel_y: float = 40.0
	var panel_w: float = screen.x - 100.0
	var panel_h: float = screen.y - 80.0
	if panel_w < 500: panel_w = 500
	if panel_h < 400: panel_h = 400
	var panel_rect := Rect2(panel_x, panel_y, panel_w, panel_h)
	draw_rect(panel_rect, Color(0.05, 0.06, 0.12, 0.95 * a), true)
	draw_rect(panel_rect, Color(0.3, 0.6, 1.0, 0.5 * a), false, 2.0)
	# Title
	_draw_centered_text(font, "⭐ SKILL TREE", Vector2(screen.x / 2.0, panel_y + 30), 28,
		Color(1.0, 0.85, 0.3, a))
	# SP display
	var sp: int = ProgressionSystem.get_skill_points() if ProgressionSystem else 0
	var prestige: int = ProgressionSystem.get_prestige_level() if ProgressionSystem else 0
	var sp_text: String = "Skill Points: %d  |  Prestige: %d  |  Total Invested: %d" % [
		sp, prestige, ProgressionSystem.get_total_ranks_invested() if ProgressionSystem else 0
	]
	_draw_centered_text(font, sp_text, Vector2(screen.x / 2.0, panel_y + 58), 16,
		Color(0.9, 0.9, 1.0, a))
	# Close button (top-right)
	var close_w: float = 80.0
	_close_btn_rect = Rect2(panel_x + panel_w - close_w - 20, panel_y + 15, close_w, 30)
	_draw_button(font, _close_btn_rect, "✖ Close", a)
	# Prestige button (top-left, only if eligible)
	if ProgressionSystem and ProgressionSystem.can_prestige():
		_prestige_btn_rect = Rect2(panel_x + 20, panel_y + 15, 140, 30)
		_draw_button(font, _prestige_btn_rect, "🌟 Prestige!", a, Color(1.0, 0.85, 0.3))
	elif ProgressionSystem:
		_prestige_btn_rect = Rect2(panel_x + 20, panel_y + 15, 140, 30)
		var prest_color: Color = Color(0.4, 0.4, 0.4, 0.4 * a)
		draw_rect(_prestige_btn_rect, prest_color, true)
		draw_rect(_prestige_btn_rect, Color(0.5, 0.5, 0.5, 0.3 * a), false, 1.0)
		var ptxt: String = "🔒 Lv %d+" % ProgressionSystem.PRESTIGE_MIN_LEVEL
		var pts := font.get_string_size(ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		font.draw_string(get_canvas_item(),
			Vector2(_prestige_btn_rect.position.x + (_prestige_btn_rect.size.x - pts.x) / 2.0,
			        _prestige_btn_rect.position.y + 20),
			ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.6, 0.6, a))
	# Three branch columns
	var col_margin: float = 30.0
	var col_w: float = (panel_w - col_margin * 4) / 3.0
	var col_y: float = panel_y + 90
	var col_h: float = panel_h - 110
	for branch in range(3):
		var col_x: float = panel_x + col_margin + branch * (col_w + col_margin)
		_draw_branch_column(font, branch, col_x, col_y, col_w, col_h, a)
	# Footer hint
	_draw_centered_text(font, "Click a skill to spend 1 SP  |  [K] Close",
		Vector2(screen.x / 2.0, panel_y + panel_h - 18), 13,
		Color(0.5, 0.55, 0.7, 0.7 * a))

func _draw_branch_column(font, branch: int, x: float, y: float, w: float, h: float, a: float) -> void:
	var branch_name: String = ProgressionSystem.BRANCH_NAMES[branch]
	var branch_icon: String = ProgressionSystem.BRANCH_ICONS[branch]
	var branch_color: Color = ProgressionSystem.BRANCH_COLORS[branch]
	# Column background
	var col_rect := Rect2(x, y, w, h)
	draw_rect(col_rect, Color(0.08, 0.09, 0.15, 0.6 * a), true)
	draw_rect(col_rect, Color(branch_color.r, branch_color.g, branch_color.b, 0.4 * a), false, 1.5)
	# Branch header
	var header_text: String = "%s  %s" % [branch_icon, branch_name]
	_draw_centered_text(font, header_text, Vector2(x + w / 2.0, y + 25), 20,
		Color(branch_color.r, branch_color.g, branch_color.b, a))
	# Ranks invested in this branch
	var ranks: int = ProgressionSystem.get_ranks_in_branch(branch) if ProgressionSystem else 0
	var max_ranks: int = ProgressionSystem.MAX_RANK * 5  # 5 skills per branch
	_draw_centered_text(font, "%d / %d ranks" % [ranks, max_ranks],
		Vector2(x + w / 2.0, y + 48), 13,
		Color(0.6, 0.65, 0.75, a))
	# Skill nodes
	var skills: Array = ProgressionSystem.get_branch_skills(branch)
	var node_h: float = 75.0
	var node_spacing: float = 10.0
	var node_y: float = y + 70
	for skill_key in skills:
		var node_rect := Rect2(x + 15, node_y, w - 30, node_h)
		_draw_skill_node(font, skill_key, node_rect, a, branch_color)
		_skill_rects[skill_key] = node_rect
		node_y += node_h + node_spacing

func _draw_skill_node(font, skill_key: String, rect: Rect2, a: float, branch_color: Color) -> void:
	var def: Dictionary = ProgressionSystem.SKILL_DEFS[skill_key]
	var rank: int = ProgressionSystem.get_skill_rank(skill_key)
	var maxed: bool = rank >= ProgressionSystem.MAX_RANK
	var can_buy: bool = ProgressionSystem.can_purchase_skill(skill_key)
	var hovered: bool = (_hovered_skill == skill_key)
	# Background
	var bg_color: Color
	if maxed:
		bg_color = Color(0.15, 0.12, 0.05, 0.8 * a)  # Gold-tinted for maxed
	elif can_buy:
		bg_color = Color(0.1, 0.15, 0.2, 0.7 * a)
	else:
		bg_color = Color(0.06, 0.07, 0.1, 0.5 * a)
	draw_rect(rect, bg_color, true)
	# Border
	var border_color: Color
	if maxed:
		border_color = Color(1.0, 0.85, 0.3, 0.8 * a)
	elif can_buy:
		border_color = Color(branch_color.r, branch_color.g, branch_color.b, 0.7 * a)
	elif hovered:
		border_color = Color(0.5, 0.6, 0.8, 0.5 * a)
	else:
		border_color = Color(0.3, 0.35, 0.45, 0.4 * a)
	var border_width: float = 2.0 if (can_buy or maxed or hovered) else 1.0
	draw_rect(rect, border_color, false, border_width)
	# Hover highlight
	if hovered and can_buy:
		draw_rect(rect, Color(1.0, 1.0, 1.0, 0.08 * a), true)
	# Icon + name
	var icon: String = def["icon"]
	var name_text: String = def["name"]
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + 10, rect.position.y + 22),
		"%s  %s" % [icon, name_text], HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(1.0, 1.0, 1.0, a))
	# Description
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + 10, rect.position.y + 42),
		def["desc"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.65, 0.7, 0.8, 0.9 * a))
	# Rank bar (5 segments)
	var bar_x: float = rect.position.x + 10
	var bar_y: float = rect.position.y + 55
	var bar_w: float = rect.size.x - 20
	var seg_w: float = (bar_w - 4 * 4) / 5.0  # 5 segments, 4px gaps
	for i in range(5):
		var seg_rect := Rect2(bar_x + i * (seg_w + 4), bar_y, seg_w, 8)
		var seg_color: Color
		if i < rank:
			if maxed:
				seg_color = Color(1.0, 0.85, 0.3, a)
			else:
				seg_color = Color(branch_color.r, branch_color.g, branch_color.b, a)
		else:
			seg_color = Color(0.15, 0.15, 0.2, 0.5 * a)
		draw_rect(seg_rect, seg_color, true)
	# Rank text
	var rank_text: String = "Rank %d/%d" % [rank, ProgressionSystem.MAX_RANK]
	if maxed:
		rank_text = "★ MAXED ★"
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + rect.size.x - 80, rect.position.y + 22),
		rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.8, 0.85, 0.9, a) if not maxed else Color(1.0, 0.85, 0.3, a))

func _draw_button(font, rect: Rect2, text: String, a: float, color: Color = Color(0.2, 0.3, 0.5)) -> void:
	draw_rect(rect, Color(color.r, color.g, color.b, 0.6 * a), true)
	draw_rect(rect, Color(color.r + 0.2, color.g + 0.2, color.b + 0.2, 0.8 * a), false, 1.5)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + (rect.size.x - text_size.x) / 2.0,
		        rect.position.y + (rect.size.y + text_size.y) / 2.0 - 2),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(1.0, 1.0, 1.0, a))

func _draw_centered_text(font, text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	font.draw_string(get_canvas_item(),
		Vector2(pos.x - text_size.x / 2.0, pos.y + text_size.y / 2.0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)