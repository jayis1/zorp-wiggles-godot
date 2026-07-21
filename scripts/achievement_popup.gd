## Zorp Wiggles — Achievement Popup System (Phase 5: HUD Polish + Phase 25 Expansion)
## Displays achievement popups that slide in from the right side when unlocked.
## Phase 25: Expanded to 50+ achievements with progress bar tracking.
## Achievements are grouped into categories: Combat, Survival, Exploration,
## Collection, Progression, Special. Each has a target and current progress.
## Progress-based achievements unlock when current >= target.
## One-shot achievements (no progress bar) unlock on a specific event.
## Lifetime progress is persisted via the Statistics autoload.

extends Control

class_name AchievementPopup

# ─── Achievement Definition ───────────────────────────────────────────────────
class Achievement:
	var id: String
	var title: String
	var description: String
	var icon: String       # Unicode symbol
	var category: String   # Category for grouping
	var target: float      # Target value (0 = one-shot, no progress bar)
	var progress_key: String  # Statistics lifetime key for progress tracking ("" = manual)

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
var _progress: Dictionary = {}  # id -> current progress value (for progress-bar achievements)

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
	GameManager.enemy_killed.connect(_on_enemy_killed)
	# Phase 25: Connect to new systems for progress-based achievements
	if WeaponModSystem:
		WeaponModSystem.mod_crafted.connect(_on_mod_crafted)
	if ProgressionSystem:
		ProgressionSystem.prestige_changed.connect(_on_prestige_changed)
	if Statistics:
		Statistics.stats_updated.connect(_on_stats_updated)
	# ── Phase 27: Pet Questline achievements ──
	if PetQuestline:
		PetQuestline.quest_completed.connect(_on_pet_quest_completed)
	# ── Phase 27: Multi-pet slot unlock achievement ──
	# slot_unlocked is a signal on MultiPetSystem, NOT PetQuestline.
	if MultiPetSystem:
		MultiPetSystem.slot_unlocked.connect(_on_pet_slot_unlocked)
	# Define all achievements
	_define_achievements()

func _define_achievements() -> void:
	# Format: {id, title, desc, icon, category, target, progress_key}
	# target=0 means one-shot (no progress bar). progress_key links to a Statistics lifetime key.
	var defs := [
		# ── Combat: One-shot milestones ──
		{"id": "first_kill", "title": "First Blood", "desc": "Defeat your first enemy", "icon": "⚔", "category": "Combat", "target": 0, "progress_key": ""},
		{"id": "combo_5", "title": "On a Roll", "desc": "Reach a x5 combo", "icon": "★", "category": "Combat", "target": 0, "progress_key": ""},
		{"id": "combo_10", "title": "Killing Spree", "desc": "Reach a x10 combo", "icon": "★★", "category": "Combat", "target": 0, "progress_key": ""},
		{"id": "combo_20", "title": "Unstoppable", "desc": "Reach a x20 combo", "icon": "★★★", "category": "Combat", "target": 0, "progress_key": ""},
		{"id": "combo_50", "title": "Legend", "desc": "Reach a x50 combo", "icon": "★★★★", "category": "Combat", "target": 0, "progress_key": ""},
		{"id": "boss_kill", "title": "Giant Slayer", "desc": "Defeat a boss", "icon": "☠", "category": "Combat", "target": 0, "progress_key": ""},
		{"id": "boss_kill_5", "title": "Boss Hunter", "desc": "Defeat 5 bosses", "icon": "☠☠", "category": "Combat", "target": 5, "progress_key": "bosses_defeated"},
		{"id": "boss_kill_20", "title": "Boss Exterminator", "desc": "Defeat 20 bosses", "icon": "☠☠☠", "category": "Combat", "target": 20, "progress_key": "bosses_defeated"},
		# ── Combat: Progress-based (lifetime kills) ──
		{"id": "kills_100", "title": "Centurion", "desc": "Defeat 100 enemies total", "icon": "💀", "category": "Combat", "target": 100, "progress_key": "total_kills"},
		{"id": "kills_500", "title": "Exterminator", "desc": "Defeat 500 enemies total", "icon": "💀💀", "category": "Combat", "target": 500, "progress_key": "total_kills"},
		{"id": "kills_1000", "title": "Warlord", "desc": "Defeat 1,000 enemies total", "icon": "💀💀💀", "category": "Combat", "target": 1000, "progress_key": "total_kills"},
		{"id": "kills_5000", "title": "Conqueror", "desc": "Defeat 5,000 enemies total", "icon": "👑", "category": "Combat", "target": 5000, "progress_key": "total_kills"},
		# ── Combat: Weapon mastery ──
		{"id": "mod_craft_1", "title": "Tinkerer", "desc": "Craft your first weapon mod", "icon": "🔧", "category": "Combat", "target": 0, "progress_key": ""},
		{"id": "mod_craft_10", "title": "Engineer", "desc": "Craft 10 weapon mods total", "icon": "🔧🔧", "category": "Combat", "target": 10, "progress_key": "mods_crafted"},
		{"id": "mod_craft_30", "title": "Master Artificer", "desc": "Craft 30 weapon mods total", "icon": "⚙", "category": "Combat", "target": 30, "progress_key": "mods_crafted"},
		# ── Survival: Level milestones ──
		{"id": "level_5", "title": "Getting Stronger", "desc": "Reach level 5", "icon": "↑", "category": "Progression", "target": 0, "progress_key": ""},
		{"id": "level_10", "title": "Power Surge", "desc": "Reach level 10", "icon": "↑↑", "category": "Progression", "target": 0, "progress_key": ""},
		{"id": "level_20", "title": "Ascendant", "desc": "Reach level 20", "icon": "↑↑↑", "category": "Progression", "target": 0, "progress_key": ""},
		{"id": "level_30", "title": "Transcendent", "desc": "Reach level 30", "icon": "🌟", "category": "Progression", "target": 0, "progress_key": ""},
		# ── Survival: Run count ──
		{"id": "runs_10", "title": "Persistent", "desc": "Complete 10 runs", "icon": "🔄", "category": "Progression", "target": 10, "progress_key": "total_runs"},
		{"id": "runs_50", "title": "Dedicated", "desc": "Complete 50 runs", "icon": "🔄🔄", "category": "Progression", "target": 50, "progress_key": "total_runs"},
		{"id": "runs_100", "title": "Veteran", "desc": "Complete 100 runs", "icon": "🎖", "category": "Progression", "target": 100, "progress_key": "total_runs"},
		# ── Survival: Best records ──
		{"id": "best_score_5k", "title": "High Scorer", "desc": "Score 5,000 in a single run", "icon": "💯", "category": "Progression", "target": 5000, "progress_key": "best_score"},
		{"id": "best_score_25k", "title": "Score Master", "desc": "Score 25,000 in a single run", "icon": "💯💯", "category": "Progression", "target": 25000, "progress_key": "best_score"},
		{"id": "best_combo_30", "title": "Combo King", "desc": "Achieve a x30 combo", "icon": "🔥", "category": "Combat", "target": 30, "progress_key": "best_combo"},
		{"id": "best_survival_300", "title": "Survivor", "desc": "Survive 5 minutes in a single run", "icon": "⏱", "category": "Survival", "target": 300.0, "progress_key": "best_survival_time"},
		{"id": "best_survival_600", "title": "Endurance", "desc": "Survive 10 minutes in a single run", "icon": "⏱⏱", "category": "Survival", "target": 600.0, "progress_key": "best_survival_time"},
		# ── Exploration: Biome explorer ──
		{"id": "biome_explorer_3", "title": "Explorer", "desc": "Visit 3 different biomes", "icon": "◆", "category": "Exploration", "target": 0, "progress_key": ""},
		{"id": "biome_explorer_6", "title": "Wanderer", "desc": "Visit 6 different biomes", "icon": "◆◆", "category": "Exploration", "target": 0, "progress_key": ""},
		{"id": "biome_explorer_12", "title": "Cartographer", "desc": "Visit all 12 biomes", "icon": "◆◆◆", "category": "Exploration", "target": 0, "progress_key": ""},
		{"id": "biome_explorer_19", "title": "World Walker", "desc": "Visit all 19 biomes", "icon": "🗺", "category": "Exploration", "target": 0, "progress_key": ""},
		# ── Exploration: Distance ──
		{"id": "distance_1km", "title": "Walker", "desc": "Travel 1 km total", "icon": "👣", "category": "Exploration", "target": 1000.0, "progress_key": "distance_traveled"},
		{"id": "distance_10km", "title": "Marathoner", "desc": "Travel 10 km total", "icon": "🏃", "category": "Exploration", "target": 10000.0, "progress_key": "distance_traveled"},
		{"id": "distance_50km", "title": "Globetrotter", "desc": "Travel 50 km total", "icon": "🌍", "category": "Exploration", "target": 50000.0, "progress_key": "distance_traveled"},
		# ── Exploration: Time played ──
		{"id": "time_1h", "title": "First Hour", "desc": "Play for 1 hour total", "icon": "🕐", "category": "Exploration", "target": 3600.0, "progress_key": "time_played"},
		{"id": "time_5h", "title": "Dedicated Player", "desc": "Play for 5 hours total", "icon": "🕔", "category": "Exploration", "target": 18000.0, "progress_key": "time_played"},
		{"id": "time_24h", "title": "Addicted", "desc": "Play for 24 hours total", "icon": "🕘", "category": "Exploration", "target": 86400.0, "progress_key": "time_played"},
		# ── Collection: Pickup streaks ──
		{"id": "pickup_10", "title": "Collector", "desc": "10-pickup streak", "icon": "✦", "category": "Collection", "target": 0, "progress_key": ""},
		{"id": "pickup_20", "title": "Treasure Hunter", "desc": "20-pickup streak", "icon": "✦✦", "category": "Collection", "target": 0, "progress_key": ""},
		{"id": "pickup_50", "title": "Magpie", "desc": "50-pickup streak", "icon": "✦✦✦", "category": "Collection", "target": 0, "progress_key": ""},
		# ── Collection: Lifetime items ──
		{"id": "items_100", "title": "Gatherer", "desc": "Collect 100 items total", "icon": "📦", "category": "Collection", "target": 100, "progress_key": "items_collected"},
		{"id": "items_1000", "title": "Hoarder", "desc": "Collect 1,000 items total", "icon": "📦📦", "category": "Collection", "target": 1000, "progress_key": "items_collected"},
		{"id": "items_5000", "title": "Treasure Vault", "desc": "Collect 5,000 items total", "icon": "💎", "category": "Collection", "target": 5000, "progress_key": "items_collected"},
		# ── Collection: Shots fired ──
		{"id": "shots_500", "title": "Trigger Happy", "desc": "Fire 500 shots total", "icon": "🔫", "category": "Combat", "target": 500, "progress_key": "shots_fired"},
		{"id": "shots_5000", "title": "Sharpshooter", "desc": "Fire 5,000 shots total", "icon": "🎯", "category": "Combat", "target": 5000, "progress_key": "shots_fired"},
		# ── Collection: Dashes ──
		{"id": "dashes_100", "title": "Dasher", "desc": "Dash 100 times total", "icon": "💨", "category": "Survival", "target": 100, "progress_key": "dashes"},
		{"id": "dashes_1000", "title": "Speed Demon", "desc": "Dash 1,000 times total", "icon": "💨💨", "category": "Survival", "target": 1000, "progress_key": "dashes"},
		# ── Special: Pet ──
		{"id": "pet_feed_10", "title": "Pet Owner", "desc": "Feed your pet 10 times", "icon": "🐾", "category": "Special", "target": 10, "progress_key": "pet_feedings"},
		{"id": "pet_feed_50", "title": "Pet Whisperer", "desc": "Feed your pet 50 times", "icon": "🐾🐾", "category": "Special", "target": 50, "progress_key": "pet_feedings"},
		# ── Special: Rifts ──
		{"id": "rifts_5", "title": "Dimensional Traveler", "desc": "Enter 5 dimensional rifts", "icon": "🌀", "category": "Special", "target": 5, "progress_key": "rifts_entered"},
		{"id": "rifts_25", "title": "Rift Walker", "desc": "Enter 25 dimensional rifts", "icon": "🌀🌀", "category": "Special", "target": 25, "progress_key": "rifts_entered"},
		# ── Special: Weather ──
		{"id": "weather_10", "title": "Storm Chaser", "desc": "Survive 10 weather events", "icon": "⛈", "category": "Special", "target": 10, "progress_key": "weather_events"},
		{"id": "weather_50", "title": "Storm Veteran", "desc": "Survive 50 weather events", "icon": "🌩", "category": "Special", "target": 50, "progress_key": "weather_events"},
		# ── Special: Revives ──
		{"id": "revive_1", "title": "Guardian Angel", "desc": "Revive your partner once", "icon": "✚", "category": "Special", "target": 1, "progress_key": "revives"},
		{"id": "revive_10", "title": "Medic", "desc": "Revive your partner 10 times", "icon": "✚✚", "category": "Special", "target": 10, "progress_key": "revives"},
		# ── Special: Prestige ──
		{"id": "prestige_1", "title": "Reborn", "desc": "Prestige for the first time", "icon": "🌟", "category": "Progression", "target": 0, "progress_key": ""},
		{"id": "prestige_5", "title": "Eternal", "desc": "Reach prestige level 5", "icon": "🌟🌟", "category": "Progression", "target": 0, "progress_key": ""},
		# ── Phase 26: World Life — lore stones, treasure chests, wildlife ──
		{"id": "lore_1", "title": "Lore Seeker", "desc": "Read your first lore stone", "icon": "📜", "category": "Exploration", "target": 1, "progress_key": "lore_stones_read"},
		{"id": "lore_10", "title": "Lore Keeper", "desc": "Read 10 lore stones", "icon": "📜📜", "category": "Exploration", "target": 10, "progress_key": "lore_stones_read"},
		{"id": "lore_30", "title": "Loremaster", "desc": "Read all 30 lore stones", "icon": "📚", "category": "Exploration", "target": 30, "progress_key": "lore_stones_read"},
		{"id": "chest_1", "title": "Treasure Finder", "desc": "Open your first treasure chest", "icon": "🗝", "category": "Collection", "target": 1, "progress_key": "treasure_chests_opened"},
		{"id": "chest_10", "title": "Treasure Hunter", "desc": "Open 10 treasure chests", "icon": "🗝🗝", "category": "Collection", "target": 10, "progress_key": "treasure_chests_opened"},
		{"id": "chest_25", "title": "Treasure Hoarder", "desc": "Open 25 treasure chests", "icon": "💰", "category": "Collection", "target": 25, "progress_key": "treasure_chests_opened"},
		{"id": "wildlife_1", "title": "Critter Catcher", "desc": "Catch your first wildlife", "icon": "🦌", "category": "Collection", "target": 1, "progress_key": "wildlife_caught"},
		{"id": "wildlife_25", "title": "Wildlife Wrangler", "desc": "Catch 25 wildlife", "icon": "🦌🦌", "category": "Collection", "target": 25, "progress_key": "wildlife_caught"},
		{"id": "wildlife_100", "title": "Beast Master", "desc": "Catch 100 wildlife", "icon": "🐾", "category": "Collection", "target": 100, "progress_key": "wildlife_caught"},
		# ── Phase 26: World Life — wandering merchants, world bosses, fast travel ──
		{"id": "merchant_1", "title": "Rare Customer", "desc": "Trade with a wandering merchant", "icon": "🛍", "category": "Collection", "target": 1, "progress_key": "merchant_trades"},
		{"id": "merchant_10", "title": "Merchant Regular", "desc": "Trade with wandering merchants 10 times", "icon": "🛍🛍", "category": "Collection", "target": 10, "progress_key": "merchant_trades"},
		{"id": "world_boss_1", "title": "World Slayer", "desc": "Defeat your first world boss", "icon": "🌍", "category": "Combat", "target": 1, "progress_key": "world_bosses_defeated"},
		{"id": "world_boss_5", "title": "Apex Predator", "desc": "Defeat 5 world bosses", "icon": "🌍🌍", "category": "Combat", "target": 5, "progress_key": "world_bosses_defeated"},
		{"id": "fast_travel_1", "title": "Pathfinder", "desc": "Activate your first fast travel waypoint", "icon": "🧭", "category": "Exploration", "target": 1, "progress_key": "waypoints_activated"},
		{"id": "fast_travel_6", "title": "Navigator", "desc": "Activate 6 fast travel waypoints", "icon": "🧭🧭", "category": "Exploration", "target": 6, "progress_key": "waypoints_activated"},
		{"id": "fast_travel_12", "title": "Cartographer Supreme", "desc": "Activate all 12 fast travel waypoints", "icon": "🗺", "category": "Exploration", "target": 12, "progress_key": "waypoints_activated"},
		# ── Phase 27: Pet Questline ──
		{"id": "pet_quest_1", "title": "First Bond", "desc": "Complete the first pet questline quest", "icon": "🐾", "category": "Special", "target": 0, "progress_key": ""},
		{"id": "pet_quest_all", "title": "Companion Master", "desc": "Complete all pet questline quests", "icon": "🏆", "category": "Special", "target": 0, "progress_key": ""},
		{"id": "multi_pet_2", "title": "Twin Companions", "desc": "Unlock a second pet slot", "icon": "🐾🐾", "category": "Special", "target": 0, "progress_key": ""},
		{"id": "multi_pet_3", "title": "Triple Threat", "desc": "Unlock a third pet slot", "icon": "🐾🐾🐾", "category": "Special", "target": 0, "progress_key": ""},
	]
	for def in defs:
		var ach := Achievement.new()
		ach.id = def["id"]
		ach.title = def["title"]
		ach.description = def["desc"]
		ach.icon = def["icon"]
		ach.category = def["category"]
		ach.target = float(def["target"])
		ach.progress_key = def["progress_key"]
		_all_achievements.append(ach)

# ─── Tracking State ───────────────────────────────────────────────────────────
var _visited_biomes: Dictionary = {}  # biome_id -> true

# ─── Signal Handlers ──────────────────────────────────────────────────────────
func _on_enemy_killed(_enemy_name: String, _killer_name: String) -> void:
	_unlock("first_kill")
	_check_progress_achievements()

func _on_combo_milestone(combo: int, _tier: int, _color: Color) -> void:
	if combo >= 5:
		_unlock("combo_5")
	if combo >= 10:
		_unlock("combo_10")
	if combo >= 20:
		_unlock("combo_20")
	if combo >= 50:
		_unlock("combo_50")

func _on_level_up(level: int) -> void:
	if level >= 5:
		_unlock("level_5")
	if level >= 10:
		_unlock("level_10")
	if level >= 20:
		_unlock("level_20")
	if level >= 30:
		_unlock("level_30")

func _on_pickup_streak_milestone(streak: int, _xp: int) -> void:
	if streak >= 10:
		_unlock("pickup_10")
	if streak >= 20:
		_unlock("pickup_20")
	if streak >= 50:
		_unlock("pickup_50")

func _on_boss_defeated(_boss: Node) -> void:
	_unlock("boss_kill")
	_check_progress_achievements()

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
	if count >= 19:
		_unlock("biome_explorer_19")

func _on_mod_crafted(_mod_id: int) -> void:
	_unlock("mod_craft_1")
	_check_progress_achievements()

func _on_prestige_changed(level: int) -> void:
	_unlock("prestige_1")
	if level >= 5:
		_unlock("prestige_5")

func _on_stats_updated() -> void:
	# Periodically check progress-based achievements against lifetime stats
	_check_progress_achievements()


# ── Phase 27: Pet Questline achievements ──
func _on_pet_quest_completed(idx: int, _title: String) -> void:
	if idx == 0:
		_unlock("pet_quest_1")
	if PetQuestline and PetQuestline.is_all_completed():
		_unlock("pet_quest_all")

func _on_pet_slot_unlocked(slot: int) -> void:
	if slot == 1:
		_unlock("multi_pet_2")
	elif slot == 2:
		_unlock("multi_pet_3")

# ─── Progress-based Achievement Checking ───────────────────────────────────────
# For achievements with a progress_key, we query the Statistics autoload for the
# current lifetime value and unlock if current >= target.
func _check_progress_achievements() -> void:
	if not Statistics:
		return
	for ach in _all_achievements:
		if ach.target <= 0 or ach.progress_key.is_empty():
			continue  # One-shot achievement — skip
		if _unlocked.has(ach.id):
			continue  # Already unlocked
		# Statistics.get_lifetime_stat returns a Variant that may be null (key
		# not yet set) or a Dictionary (for composite stats like biome_time).
		# float() cannot convert null or Dictionary, so guard those cases.
		var raw: Variant = Statistics.get_lifetime_stat(ach.progress_key)
		var current: float = 0.0
		if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
			current = float(raw)
		_progress[ach.id] = current
		if current >= ach.target:
			_unlock(ach.id)

# ─── Public API ────────────────────────────────────────────────────────────────
func get_unlocked_count() -> int:
	return _unlocked.size()

func get_total_count() -> int:
	return _all_achievements.size()

func get_progress(achievement_id: String) -> float:
	return float(_progress.get(achievement_id, 0.0))

func get_achievement_by_id(achievement_id: String) -> Achievement:
	for a in _all_achievements:
		if a.id == achievement_id:
			return a
	return null

func get_all_achievements() -> Array[Achievement]:
	return _all_achievements

func get_unlocked_dict() -> Dictionary:
	return _unlocked.duplicate()

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

# Phase 26: Public unlock entry point so external systems (WorldBossManager,
# FastTravelNetwork, WanderingMerchant) can trigger one-shot achievements
# without duplicating the popup logic. Safe to call with an unknown id.
func unlock(achievement_id: String) -> void:
	_unlock(achievement_id)

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