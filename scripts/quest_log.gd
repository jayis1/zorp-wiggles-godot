## Zorp Wiggles — Quest Log / Mission Board UI (Phase 7)
## A toggleable panel showing active and completed missions.
## Press Tab (the "missions" input action) to toggle.
## Draws a semi-transparent panel with mission names, descriptions, progress bars,
## and rewards. Uses _draw() for custom rendering — no scene file needed.

extends Control

class_name QuestLog

var _visible_flag: bool = false
var _fade_alpha: float = 0.0  # 0 = hidden, 1 = fully visible
var _completed_count: int = 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Connect to mission system signals for real-time updates
	if MissionSystem:
		MissionSystem.mission_completed.connect(_on_mission_completed)
		MissionSystem.mission_progress_updated.connect(_on_mission_progress_updated)
	# ── Phase 33: Procedural Quest System integration ──
	# Procedural quests are duck-typed (same fields as Mission), so we can render
	# them with the same drawing code. Connect to the quest system's signals to
	# trigger redraws on generation, progress, and completion.
	if ProceduralQuestSystem:
		ProceduralQuestSystem.quest_generated.connect(_on_quest_changed)
		ProceduralQuestSystem.quest_progress_updated.connect(_on_quest_changed)
		ProceduralQuestSystem.quest_completed.connect(_on_quest_changed)
		ProceduralQuestSystem.quest_expired.connect(_on_quest_changed)

func _on_mission_completed(_mission) -> void:
	_completed_count = MissionSystem.get_completed_count()
	queue_redraw()

func _on_mission_progress_updated(_mission) -> void:
	queue_redraw()

# ── Phase 33: Procedural quest signal handlers ──
func _on_quest_changed(_quest) -> void:
	queue_redraw()

func _process(delta: float) -> void:
	# Toggle visibility on Tab key
	if Input.is_action_just_pressed("missions"):
		_visible_flag = not _visible_flag

	# Smooth fade in/out
	var target: float = 1.0 if _visible_flag else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 6.0)

	# Only redraw when visible or transitioning
	if _fade_alpha > 0.01 or _visible_flag:
		queue_redraw()

func _draw() -> void:
	if _fade_alpha < 0.01:
		return

	var font := get_theme_default_font()
	if not font:
		return

	# Ease the fade alpha for a smoother feel — linear move_toward feels
	# mechanical. ease_out_cubic makes the panel snap in quickly then settle,
	# and ease_in_cubic makes it accelerate out on close. This matches the
	# tween-based easing used by the Button-based menus.
	var eased: float
	if _visible_flag:
		eased = 1.0 - pow(1.0 - _fade_alpha, 3.0)  # ease_out_cubic
	else:
		eased = _fade_alpha * _fade_alpha * _fade_alpha  # ease_in_cubic
	var a: float = eased
	var panel_x: float = 200.0
	var panel_y: float = 100.0
	var panel_w: float = 520.0
	var panel_h: float = 500.0

	# ── Panel background ──
	var bg := Color(0.03, 0.04, 0.10, 0.92 * a)
	draw_rect(Rect2(panel_x, panel_y, panel_w, panel_h), bg, true)

	# ── Border (cyan-teal) ──
	var border_col := Color(0.2, 0.8, 0.9, 0.6 * a)
	draw_rect(Rect2(panel_x, panel_y, panel_w, panel_h), border_col, false, 2.0)

	# ── Title ──
	var title_y: float = panel_y + 30
	font.draw_string(get_canvas_item(),
		Vector2(panel_x + 20, title_y),
		"📋 MISSION BOARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
		Color(0.3, 0.9, 1.0, a))

	# Completed count
	font.draw_string(get_canvas_item(),
		Vector2(panel_x + panel_w - 120, title_y),
		"Done: %d" % _completed_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0.6, 0.8, 0.7, 0.8 * a))

	# Divider line
	draw_line(Vector2(panel_x + 15, title_y + 10), Vector2(panel_x + panel_w - 15, title_y + 10),
		Color(0.2, 0.8, 0.9, 0.3 * a), 1.0)

	# ── Active missions ──
	var missions: Array = MissionSystem.get_active_missions()
	var y: float = title_y + 35

	if missions.is_empty() and (not ProceduralQuestSystem or ProceduralQuestSystem.get_active_quests().is_empty()):
		font.draw_string(get_canvas_item(),
			Vector2(panel_x + 20, y + 20),
			"No active missions — checking for new ones...", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(0.5, 0.5, 0.6, 0.7 * a))
	else:
		for mission in missions:
			if y > panel_y + panel_h - 20:
				break  # Don't overflow panel
			var icon: String = _get_mission_icon(mission.type)
			y = _draw_quest_entry(font, panel_x, y, panel_w, a,
				"%s %s" % [icon, mission.title],
				mission.description,
				mission.current_count, mission.target_count,
				mission.reward_xp, mission.reward_score)

	# ── Phase 33: Procedural Quests section ──
	# ProceduralQuestSystem quests are duck-typed to share the Mission fields,
	# but they use a separate objective_type enum and may carry a modifier
	# (Time Limit, Bonus XP, etc.) we display as a suffix on the description.
	if ProceduralQuestSystem:
		var pquests: Array = ProceduralQuestSystem.get_active_quests()
		if not pquests.is_empty() and y < panel_y + panel_h - 40:
			# Section divider
			y += 8
			font.draw_string(get_canvas_item(),
				Vector2(panel_x + 20, y),
				"✦ PROCEDURAL QUESTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
				Color(0.9, 0.7, 1.0, a))
			draw_line(Vector2(panel_x + 15, y + 6),
				Vector2(panel_x + panel_w - 15, y + 6),
				Color(0.6, 0.4, 0.9, 0.3 * a), 1.0)
			y += 20
			for quest in pquests:
				if y > panel_y + panel_h - 20:
					break
				# Use the quest's objective_type for the icon (mapped via the
				# procedural system's own icon table). Fall back to "?".
				var pq_icon: String = "?"
				if ProceduralQuestSystem.OBJECTIVE_ICONS.size() > quest.objective_type:
					pq_icon = ProceduralQuestSystem.OBJECTIVE_ICONS[quest.objective_type]
				# Modifier badge text
				var mod_badge: String = ""
				if quest.modifier != 0 and ProceduralQuestSystem.MODIFIER_NAMES.size() > quest.modifier:
					var mname: String = ProceduralQuestSystem.MODIFIER_NAMES[quest.modifier]
					if mname != "":
						mod_badge = "  [" + mname + "]"
				y = _draw_quest_entry(font, panel_x, y, panel_w, a,
					"%s %s" % [pq_icon, quest.title],
					quest.description + mod_badge,
					quest.current_count, quest.target_count,
					quest.reward_xp, quest.reward_score)

	# ── Footer hint ──
	font.draw_string(get_canvas_item(),
		Vector2(panel_x + 20, panel_y + panel_h - 15),
		"[Tab] Close", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.4, 0.5, 0.6, 0.6 * a))

# ── Phase 33: Shared quest/mission drawing helper ──
# Draws a single quest entry (title, description, progress bar, reward) and
# returns the y-position for the next entry. Used for both MissionSystem
# missions and ProceduralQuestSystem quests (duck-typed).
func _draw_quest_entry(font, panel_x: float, y: float, panel_w: float, a: float,
		title_text: String, description: String,
		current_count: int, target_count: int,
		reward_xp: int, reward_score: int) -> float:
	# Title
	font.draw_string(get_canvas_item(),
		Vector2(panel_x + 20, y),
		title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		Color(1.0, 1.0, 1.0, a))
	# Description
	font.draw_string(get_canvas_item(),
		Vector2(panel_x + 20, y + 20),
		description, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(0.6, 0.7, 0.8, 0.8 * a))
	# Progress bar
	var bar_x: float = panel_x + 20
	var bar_y: float = y + 32
	var bar_w: float = panel_w - 120
	var bar_h: float = 8.0
	var progress: float = float(current_count) / float(max(1, target_count))
	progress = clampf(progress, 0.0, 1.0)
	# Bar background
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.15, 0.15, 0.2, 0.8 * a), true)
	# Bar fill (green-teal, gold when complete)
	var fill_col := Color(0.2, 0.9, 0.5, 0.85 * a)
	if progress >= 1.0:
		fill_col = Color(1.0, 0.85, 0.2, 0.9 * a)
	draw_rect(Rect2(bar_x, bar_y, bar_w * progress, bar_h), fill_col, true)
	# Bar border
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.3, 0.5, 0.5, 0.4 * a), false, 1.0)
	# Progress text
	font.draw_string(get_canvas_item(),
		Vector2(panel_x + bar_w + 30, y + 30),
		"%d / %d" % [current_count, target_count],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(0.8, 0.9, 1.0, 0.9 * a))
	# Reward text
	font.draw_string(get_canvas_item(),
		Vector2(panel_x + 20, y + 55),
		"Reward: +%d XP  +%d Score" % [reward_xp, reward_score],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(1.0, 0.8, 0.3, 0.7 * a))
	return y + 80

func _get_mission_icon(type: int) -> String:
	match type:
		0: return "📦"  # COLLECT
		1: return "⚔"   # KILL
		2: return "◆"   # EXPLORE
		3: return "⬆"   # LEVEL
		4: return "★"   # COMBO
		5: return "⏱"   # SURVIVE
		_:  return "?"

func _get_mission_type_name(type: int) -> String:
	match type:
		0: return "Collect"
		1: return "Kill"
		2: return "Explore"
		3: return "Level"
		4: return "Combo"
		5: return "Survive"
		_:  return "Unknown"