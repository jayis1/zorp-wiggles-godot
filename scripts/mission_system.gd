## Zorp Wiggles — Mission System (Phase 7: Missions & Progression)
## Tracks and completes missions for the player. Missions include:
## - Collect X items of a type
## - Kill Y enemies of a type
## - Explore Z biomes
## - Reach a certain level
## - Achieve a combo milestone
## Missions grant XP and score rewards on completion.

extends Node

# ─── Mission Definition ───────────────────────────────────────────────────────
class Mission:
	var id: String
	var title: String
	var description: String
	var type: int  # MissionType enum
	var target_count: int
	var current_count: int
	var reward_xp: int
	var reward_score: int
	var completed: bool
	var collectible_type: int = -1  # For collect missions
	var enemy_type: int = -1        # For kill missions

enum MissionType {
	COLLECT,
	KILL,
	EXPLORE,
	LEVEL,
	COMBO,
	SURVIVE,
}

# ─── State ────────────────────────────────────────────────────────────────────
var _active_missions: Array[Mission] = []
var _completed_missions: Array[Mission] = []
var _visited_biomes: Dictionary = {}

signal mission_completed(mission: Mission)
signal mission_progress_updated(mission: Mission)

func _ready() -> void:
	# Connect to relevant signals
	GameManager.boss_spawned.connect(_on_boss_spawned)
	GameManager.boss_defeated.connect(_on_boss_defeated)
	GameManager.combo_milestone.connect(_on_combo_milestone)
	GameManager.level_up.connect(_on_level_up)
	GameManager.biome_changed.connect(_on_biome_changed)
	GameManager.enemy_killed.connect(_on_enemy_killed)

	# Generate initial missions
	_generate_initial_missions()

func _generate_initial_missions() -> void:
	# Mission 1: Collect 10 items
	var m1 := Mission.new()
	m1.id = "collect_10"
	m1.title = "Gatherer"
	m1.description = "Collect 10 items"
	m1.type = MissionType.COLLECT
	m1.target_count = 10
	m1.current_count = 0
	m1.reward_xp = 50
	m1.reward_score = 200
	m1.completed = false
	_active_missions.append(m1)

	# Mission 2: Kill 15 enemies
	var m2 := Mission.new()
	m2.id = "kill_15"
	m2.title = "Hunter"
	m2.description = "Defeat 15 enemies"
	m2.type = MissionType.KILL
	m2.target_count = 15
	m2.current_count = 0
	m2.reward_xp = 80
	m2.reward_score = 300
	m2.completed = false
	_active_missions.append(m2)

	# Mission 3: Explore 3 biomes
	var m3 := Mission.new()
	m3.id = "explore_3"
	m3.title = "Trailblazer"
	m3.description = "Visit 3 different biomes"
	m3.type = MissionType.EXPLORE
	m3.target_count = 3
	m3.current_count = 0
	m3.reward_xp = 60
	m3.reward_score = 250
	m3.completed = false
	_active_missions.append(m3)

	# Mission 4: Reach level 5
	var m4 := Mission.new()
	m4.id = "level_5"
	m4.title = "Rising Star"
	m4.description = "Reach level 5"
	m4.type = MissionType.LEVEL
	m4.target_count = 5
	m4.current_count = 1
	m4.reward_xp = 100
	m4.reward_score = 400
	m4.completed = false
	_active_missions.append(m4)

	# Mission 5: Achieve x10 combo
	var m5 := Mission.new()
	m5.id = "combo_10"
	m5.title = "On Fire"
	m5.description = "Achieve a x10 combo"
	m5.type = MissionType.COMBO
	m5.target_count = 10
	m5.current_count = 0
	m5.reward_xp = 75
	m5.reward_score = 350
	m5.completed = false
	_active_missions.append(m5)

func _process(_delta: float) -> void:
	# Check COLLECT missions — track via GameManager.player_kills + pickup streaks
	# We'll check collect missions via the pickup streak counter
	for mission in _active_missions:
		if mission.completed:
			continue
		match mission.type:
			MissionType.COLLECT:
				# Track total pickups via GameManager's max pickup streak + total
				# We use player_kills as a proxy for kill count, and for collect
				# we track via the pickup streak milestone events
				pass  # Updated via _on_pickup_streak_milestone
			MissionType.KILL:
				mission.current_count = GameManager.player_kills
			MissionType.LEVEL:
				mission.current_count = GameManager.player_level
			MissionType.COMBO:
				mission.current_count = GameManager.player_best_combo
			MissionType.EXPLORE:
				mission.current_count = _visited_biomes.size()

		# Check completion
		if mission.current_count >= mission.target_count and not mission.completed:
			_complete_mission(mission)

func _complete_mission(mission: Mission) -> void:
	mission.completed = true
	_active_missions.erase(mission)
	_completed_missions.append(mission)

	# Grant rewards
	GameManager.gain_xp(mission.reward_xp)
	GameManager.add_score(mission.reward_score)

	mission_completed.emit(mission)
	GameManager.add_message("✓ MISSION COMPLETE: %s (+%d XP, +%d score)" % [mission.title, mission.reward_xp, mission.reward_score])

	# Generate a new replacement mission
	_generate_random_mission()

func _generate_random_mission() -> void:
	if _active_missions.size() >= 5:
		return  # Cap at 5 active missions

	var roll: float = randf()
	var m := Mission.new()
	m.completed = false

	if roll < 0.3:
		# Kill mission
		var count: int = 20 + GameManager.player_level * 5
		m.id = "kill_%d" % count
		m.title = "Exterminator"
		m.description = "Defeat %d enemies" % count
		m.type = MissionType.KILL
		m.target_count = count
		m.current_count = GameManager.player_kills
		m.reward_xp = 80 + count * 2
		m.reward_score = 300 + count * 10
	elif roll < 0.6:
		# Collect mission
		var count: int = 15 + GameManager.player_level * 3
		m.id = "collect_%d" % count
		m.title = "Collector"
		m.description = "Collect %d items" % count
		m.type = MissionType.COLLECT
		m.target_count = count
		m.current_count = 0
		m.reward_xp = 60 + count * 3
		m.reward_score = 250 + count * 8
	elif roll < 0.8:
		# Combo mission
		var count: int = 15 + (GameManager.player_level / 2) * 5
		m.id = "combo_%d" % count
		m.title = "Killing Machine"
		m.description = "Achieve a x%d combo" % count
		m.type = MissionType.COMBO
		m.target_count = count
		m.current_count = GameManager.player_best_combo
		m.reward_xp = 100 + count * 5
		m.reward_score = 400 + count * 15
	else:
		# Level mission
		var target: int = GameManager.player_level + 3
		m.id = "level_%d" % target
		m.title = "Ascendant"
		m.description = "Reach level %d" % target
		m.type = MissionType.LEVEL
		m.target_count = target
		m.current_count = GameManager.player_level
		m.reward_xp = 150 + target * 10
		m.reward_score = 500 + target * 20

	_active_missions.append(m)
	GameManager.add_message("✦ New Mission: %s" % m.title)

# ─── Signal Handlers ──────────────────────────────────────────────────────────
func _on_enemy_killed(_enemy_name: String, _killer_name: String) -> void:
	# Kill missions are tracked via _process using GameManager.player_kills
	pass

func _on_boss_spawned(_boss: Node) -> void:
	pass

func _on_boss_defeated(_boss: Node) -> void:
	# Bonus: complete any active kill mission on boss defeat
	for mission in _active_missions:
		if mission.type == MissionType.KILL and not mission.completed:
			mission.current_count = GameManager.player_kills

func _on_combo_milestone(_combo: int, _tier: int, _color: Color) -> void:
	# Combo missions tracked via _process using player_best_combo
	pass

func _on_level_up(_level: int) -> void:
	# Level missions tracked via _process
	pass

func _on_biome_changed(biome_id: int) -> void:
	_visited_biomes[biome_id] = true

# ─── Public API ───────────────────────────────────────────────────────────────
func get_active_missions() -> Array[Mission]:
	return _active_missions

func get_completed_count() -> int:
	return _completed_missions.size()

func get_total_pickups() -> int:
	# Track total pickups using the max pickup streak as a proxy
	# TODO: Add a dedicated player_total_pickups counter to GameManager
	return GameManager.player_max_pickup_streak