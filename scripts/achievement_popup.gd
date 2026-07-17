## Zorp Wiggles — Achievement Popup System (Phase 5: HUD Polish)
## Displays achievement popups that slide in from the right side when unlocked.
## Achievements are tracked for: first kill, combo milestones, biome explorer,
## level milestones, pickup streak milestones, and boss kill.
## Each popup shows an icon, title, and description, then slides out after a few seconds.

extends Control

class_name AchievementPopup

# ─── Achievement Definition ───────────────────────────────────────────────────
class Achievement:
	var id: String
	var title: String
	var description: String
	var icon: String  # Unicode symbol

# ─── Popup Entry ──────────────────────────────────────────────────────────────
class PopupEntry:
	var achievement: Achievement
	var timer: float
	var slide_x: float  # X offset for slide animation
	var alpha: float

# ─── Internal State ───────────────────────────────────────────────────────────
var _popups: Array[PopupEntry] = []
var _unlocked: Dictionary = {}  # id -> true
var _all_achievements: Array[Achievement] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_left = -340
	offset_top = 260
	offset_right = -10
	offset_bottom = 600

	# Connect to relevant signals for achievement tracking
	GameManager.combo_milestone.connect(_on_combo_milestone)
	GameManager.level_up.connect(_on_level_up)
	GameManager.pickup_streak_milestone.connect(_on_pickup_streak_milestone)
	GameManager.boss_defeated.connect(_on_boss_defeated)
	GameManager.boss_spawned.connect(_on_boss_spawned)
	GameManager.biome_changed.connect(_on_biome_changed)

	# Track first kill via enemy_killed signal
	GameManager.enemy_killed.connect(_on_enemy_killed)

	# Define all achievements
	_define_achievements()

func _define_achievements() -> void:
	var defs := [
		{"id": "first_kill", "title": "First Blood", "desc": "Defeat your first enemy", "icon": "⚔"},
		{"id": "combo_5", "title": "On a Roll", "desc": "Reach a x5 combo", "icon": "★"},
		{"id": "combo_10", "title": "Killing Spree", "desc": "Reach a x10 combo", "icon": "★★"},
		{"id": "combo_20", "title": "Unstoppable", "desc": "Reach a x20 combo", "icon": "★★★"},
		{"id": "level_5", "title": "Getting Stronger", "desc": "Reach level 5", "icon": "↑"},
		{"id": "level_10", "title": "Power Surge", "desc": "Reach level 10", "icon": "↑↑"},
		{"id": "pickup_10", "title": "Collector", "desc": "10-pickup streak", "icon": "✦"},
		{"id": "pickup_20", "title": "Treasure Hunter", "desc": "20-pickup streak", "icon": "✦✦"},
		{"id": "boss_kill", "title": "Giant Slayer", "desc": "Defeat a boss", "icon": "☠"},
		{"id": "biome_explorer_3", "title": "Explorer", "desc": "Visit 3 different biomes", "icon": "◆"},
		{"id": "biome_explorer_6", "title": "Wanderer", "desc": "Visit 6 different biomes", "icon": "◆◆"},
		{"id": "biome_explorer_12", "title": "Cartographer", "desc": "Visit all 12 biomes", "icon": "◆◆◆"},
	]
	for def in defs:
		var ach := Achievement.new()
		ach.id = def["id"]
		ach.title = def["title"]
		ach.description = def["desc"]
		ach.icon = def["icon"]
		_all_achievements.append(ach)

# ─── Tracking State ───────────────────────────────────────────────────────────
var _visited_biomes: Dictionary = {}  # biome_id -> true

# ─── Signal Handlers ──────────────────────────────────────────────────────────
func _on_enemy_killed(_enemy_name: String, _killer_name: String) -> void:
	_unlock("first_kill")

func _on_combo_milestone(combo: int, _tier: int, _color: Color) -> void:
	if combo >= 5:
		_unlock("combo_5")
	if combo >= 10:
		_unlock("combo_10")
	if combo >= 20:
		_unlock("combo_20")

func _on_level_up(level: int) -> void:
	if level >= 5:
		_unlock("level_5")
	if level >= 10:
		_unlock("level_10")

func _on_pickup_streak_milestone(streak: int, _xp: int) -> void:
	if streak >= 10:
		_unlock("pickup_10")
	if streak >= 20:
		_unlock("pickup_20")

func _on_boss_defeated(_boss: Node) -> void:
	_unlock("boss_kill")

func _on_boss_spawned(_boss: Node) -> void:
	pass  # We only care about boss kills

func _on_biome_changed(biome_id: int) -> void:
	_visited_biomes[biome_id] = true
	var count: int = _visited_biomes.size()
	if count >= 3:
		_unlock("biome_explorer_3")
	if count >= 6:
		_unlock("biome_explorer_6")
	if count >= 12:
		_unlock("biome_explorer_12")

# ─── Logic ────────────────────────────────────────────────────────────────────
func _unlock(achievement_id: String) -> void:
	if _unlocked.has(achievement_id):
		return
	# Find achievement definition
	var ach: Achievement = null
	for a in _all_achievements:
		if a.id == achievement_id:
			ach = a
			break
	if not ach:
		return
	_unlocked[achievement_id] = true
	# Create popup entry
	var entry := PopupEntry.new()
	entry.achievement = ach
	entry.timer = 4.0
	entry.slide_x = 360.0  # Start off-screen right
	entry.alpha = 0.0
	_popups.append(entry)
	# Cap at 3 simultaneous popups
	while _popups.size() > 3:
		_popups.pop_front()
	GameManager.add_message("🏆 Achievement: %s" % ach.title)

func _process(delta: float) -> void:
	if _popups.is_empty():
		return

	for entry in _popups:
		entry.timer -= delta
		# Slide in (first 0.4s), stay, then slide out (last 0.4s)
		# Uses ease-out cubic for slide-in (fast enter, decelerate) and
		# ease-in cubic for slide-out (accelerate exit) for a polished feel
		# that matches the game's juice language. Previously used linear lerp.
		if entry.timer > 3.6:
			# Sliding in — ease-out cubic: 1 - (1-t)^3
			var slide_progress: float = 1.0 - (entry.timer - 3.6) / 0.4
			var eased_in: float = 1.0 - pow(1.0 - slide_progress, 3.0)
			entry.slide_x = lerpf(360.0, 0.0, eased_in)
			entry.alpha = eased_in
		elif entry.timer > 0.4:
			# Staying
			entry.slide_x = 0.0
			entry.alpha = 1.0
		else:
			# Sliding out — ease-in cubic: t^3 (accelerate away)
			var out_progress: float = 1.0 - entry.timer / 0.4
			var eased_out: float = pow(out_progress, 3.0)
			entry.slide_x = lerpf(0.0, 360.0, eased_out)
			entry.alpha = 1.0 - eased_out

	# Remove expired
	for i in range(_popups.size() - 1, -1, -1):
		if _popups[i].timer <= 0:
			_popups.remove_at(i)

	queue_redraw()

func _draw() -> void:
	if _popups.is_empty():
		return

	var font := get_theme_default_font()
	if not font:
		return

	var panel_width: float = 330.0
	var panel_height: float = 60.0
	var y: float = 0

	for entry in _popups:
		var panel_x: float = size.x - panel_width + entry.slide_x

		# Draw panel background
		var bg := Color(0.05, 0.05, 0.12, 0.85 * entry.alpha)
		draw_rect(Rect2(panel_x, y, panel_width, panel_height), bg, true)

		# Draw gold border
		var border := Color(1.0, 215.0 / 255.0, 0.0, 0.7 * entry.alpha)
		draw_rect(Rect2(panel_x, y, panel_width, panel_height), border, false, 2.0)

		# Draw icon (large, left side)
		var icon_size: int = 28
		var icon_ts := font.get_string_size(entry.achievement.icon, HORIZONTAL_ALIGNMENT_LEFT, -1, icon_size)
		font.draw_string(get_canvas_item(),
			Vector2(panel_x + 10, y + icon_ts.y + 8),
			entry.achievement.icon, HORIZONTAL_ALIGNMENT_LEFT, -1, icon_size,
			Color(1.0, 215.0 / 255.0, 0.0, entry.alpha))

		# Draw title (bold-looking, larger)
		var title_size: int = 18
		font.draw_string(get_canvas_item(),
			Vector2(panel_x + 50, y + 22),
			entry.achievement.title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size,
			Color(1.0, 1.0, 1.0, entry.alpha))

		# Draw description (smaller, dimmer)
		var desc_size: int = 13
		font.draw_string(get_canvas_item(),
			Vector2(panel_x + 50, y + 42),
			entry.achievement.description, HORIZONTAL_ALIGNMENT_LEFT, -1, desc_size,
			Color(0.7, 0.7, 0.8, 0.8 * entry.alpha))

		# Draw "ACHIEVEMENT UNLOCKED" label (tiny, top)
		var label_size: int = 9
		font.draw_string(get_canvas_item(),
			Vector2(panel_x + 50, y + 12),
			"ACHIEVEMENT UNLOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, label_size,
			Color(1.0, 215.0 / 255.0, 0.0, 0.6 * entry.alpha))

		y += panel_height + 8