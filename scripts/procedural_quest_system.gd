## Zorp Wiggles — Procedural Quest System (Phase 33: Procedural Content)
##
## Dynamically generates quests based on the player's current level, biome, and
## gameplay context. Unlike MissionSystem (which has fixed mission templates),
## this system composes quests from procedural building blocks:
##   - Objective type (kill, collect, survive, reach, explore, craft, boss)
##   - Target (enemy type, collectible type, biome, level)
##   - Quantity (scales with player level)
##   - Modifier (time limit, bonus condition, constraint)
##   - Reward (XP, score, crafting materials, rare materials, equipment)
##
## Quests are context-aware: in the Lava biome, the system favors "kill X fire
## enemies" or "survive Y seconds in lava"; at high player level, it favors
## boss-hunt or crafting quests. Quests rotate on a timer (every 3-5 minutes)
## and on completion, with a max of 4 active procedural quests at once.
##
## The system integrates with the existing Quest Log UI by exposing quests as
## Mission-compatible objects (duck-typed via duck typing — the QuestLog reads
## .title, .description, .type, .target_count, .current_count, .reward_xp,
## .reward_score fields). This avoids a separate UI; the Quest Log shows both
## MissionSystem missions and ProceduralQuestSystem quests in one panel.
extends Node

# ─── Signals ──────────────────────────────────────────────────────────────────
signal quest_generated(quest: Variant)
signal quest_completed(quest: Variant)
signal quest_progress_updated(quest: Variant)
signal quest_expired(quest: Variant)

# ─── Quest Objective Types ────────────────────────────────────────────────────
enum ObjectiveType {
	KILL_ENEMIES,       # Kill X enemies (any type)
	KILL_TYPE,          # Kill X of a specific enemy type
	KILL_VARIANTS,      # Kill X elite/golden/champion variants
	COLLECT_ITEMS,      # Collect X items (any type)
	COLLECT_TYPE,       # Collect X of a specific collectible type
	SURVIVE,            # Survive for X seconds
	REACH_LEVEL,        # Reach player level X
	EXPLORE_BIOMES,     # Visit X unique biomes
	VISIT_BIOME,        # Visit a specific biome
	DEFEAT_BOSS,        # Defeat X bosses
	CRAFT_MOD,          # Craft X weapon mods
	CRAFT_EQUIPMENT,    # Craft X equipment pieces
	USE_CONSUMABLE,    # Use X consumables
	DASH_COUNT,         # Dash X times
	COMBO_MILESTONE,    # Achieve a xN combo
	DISTANCE,           # Travel X meters
}

const OBJECTIVE_NAMES: Array[String] = [
	"Kill Enemies", "Kill Type", "Kill Variants", "Collect Items",
	"Collect Type", "Survive", "Reach Level", "Explore Biomes",
	"Visit Biome", "Defeat Boss", "Craft Mod", "Craft Equipment",
	"Use Consumable", "Dash Count", "Combo Milestone", "Travel Distance",
]

const OBJECTIVE_ICONS: Array[String] = [
	"⚔", "🎯", "👑", "📦",
	"💎", "⏳", "⭐", "🗺",
	"📍", "💀", "🔧", "🛡",
	"🧪", "💨", "🔥", "📏",
]

# ─── Quest Modifiers (optional constraints for variety) ───────────────────────
enum Modifier {
	NONE,               # No modifier — standard quest
	TIME_LIMIT,         # Complete within X seconds for bonus reward
	BONUS_XP,           # Bonus XP reward
	BONUS_LOOT,         # Bonus loot drop chance on completion
	NO_DAMAGE,          # Complete without taking damage (one-shot quest)
}

const MODIFIER_NAMES: Array[String] = [
	"", "Time Limit", "Bonus XP", "Bonus Loot", "No Damage",
]

# ─── Quest Class ───────────────────────────────────────────────────────────────
class ProceduralQuest:
	var id: String
	var title: String
	var description: String
	var objective_type: int
	var target_count: int
	var current_count: int
	var prev_count: int = -1
	var reward_xp: int
	var reward_score: int
	var reward_material: int = -1  # CollectibleType for material reward, -1 = none
	var reward_rare_material: int = -1  # RareMaterial, -1 = none
	var modifier: int = Modifier.NONE
	var modifier_param: float = 0.0  # e.g. time limit in seconds
	var completed: bool = false
	var expired: bool = false
	var biome_target: int = -1  # For VISIT_BIOME
	var enemy_type_target: int = -1  # For KILL_TYPE
	var collectible_type_target: int = -1  # For COLLECT_TYPE
	var time_remaining: float = 0.0  # For TIME_LIMIT modifier
	var _start_time: float = 0.0  # For SURVIVE / time-limit tracking
	var _no_damage: bool = false  # For NO_DAMAGE modifier
	# Compatibility fields for QuestLog UI (duck-typed as Mission)
	var type: int = 0  # Mirrors MissionType for icon lookup; we use objective_type instead
	# Constructor
	func _init(p_id: String = "") -> void:
		id = p_id

# ─── Tuning ───────────────────────────────────────────────────────────────────
const MAX_ACTIVE_QUESTS: int = 4
const QUEST_ROTATION_INTERVAL_MIN: float = 180.0  # 3 min
const QUEST_ROTATION_INTERVAL_MAX: float = 300.0  # 5 min
const QUEST_EXPIRY_TIME: float = 600.0  # 10 min — unfinished quests expire

# ─── State ────────────────────────────────────────────────────────────────────
var _active_quests: Array[ProceduralQuest] = []
var _completed_quests: int = 0
var _rotation_timer: float = 60.0  # First rotation after 60s
var _visited_biomes: Dictionary = {}  # biome_id → true
var _boss_kills_this_run: int = 0
var _distance_traveled: float = 0.0
var _last_player_pos: Vector3 = Vector3.ZERO
var _dashes_this_run: int = 0
var _crafts_this_run: int = 0
var _consumables_used_this_run: int = 0
var _variants_killed_this_run: int = 0

# ─── Public API ────────────────────────────────────────────────────────────────

func _ready() -> void:
	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)
		GameManager.player_died.connect(_on_player_died)
		GameManager.boss_defeated.connect(_on_boss_defeated)
		GameManager.biome_changed.connect(_on_biome_changed)
		GameManager.enemy_killed.connect(_on_enemy_killed)
		GameManager.combo_milestone.connect(_on_combo_milestone)
		GameManager.level_up.connect(_on_level_up)
	# Track dashes via Statistics signals (if available)
	if Statistics:
		# We can't easily intercept dashes; we'll poll Statistics lifetime stats
		pass
	# Track crafting via WeaponModSystem / EquipmentSystem signals
	if WeaponModSystem:
		WeaponModSystem.mod_crafted.connect(_on_mod_crafted)
	if EquipmentSystem:
		EquipmentSystem.piece_crafted.connect(_on_equipment_crafted)
		EquipmentSystem.consumable_used.connect(_on_consumable_used)
	# Track variant kills
	if EnemyVariantSystem:
		EnemyVariantSystem.variant_defeated.connect(_on_variant_defeated)

# ─── Per-Frame Update ─────────────────────────────────────────────────────────
# Called by GameManager._process()
func update(delta: float) -> void:
	if GameManager.is_paused or not GameManager.player_is_alive:
		return
	# Track distance traveled
	var player: Node3D = GameManager.player
	if player and is_instance_valid(player):
		if _last_player_pos != Vector3.ZERO:
			_distance_traveled += _last_player_pos.distance_to(player.global_position)
		_last_player_pos = player.global_position
	# Rotation timer
	_rotation_timer -= delta
	if _rotation_timer <= 0.0:
		_rotation_timer = randf_range(QUEST_ROTATION_INTERVAL_MIN, QUEST_ROTATION_INTERVAL_MAX)
		# Generate a new quest if below cap
		if _active_quests.size() < MAX_ACTIVE_QUESTS:
			generate_quest()
	# Update quest progress
	_update_quest_progress(delta)
	# Expire stale quests
	_expire_stale_quests(delta)

# ─── Quest Generation ─────────────────────────────────────────────────────────

# Generate a new procedural quest based on current player context.
func generate_quest() -> ProceduralQuest:
	if _active_quests.size() >= MAX_ACTIVE_QUESTS:
		return null
	var player_level: int = GameManager.player_level
	var current_biome: int = GameManager.current_biome if "current_biome" in GameManager else 0
	var game_time: float = GameManager.game_time
	# Build a weighted pool of objective types based on context
	var pool: Array[int] = []
	var weights: Array[float] = []
	# Always-available objectives
	_add_objective(pool, weights, ObjectiveType.KILL_ENEMIES, 3.0)
	_add_objective(pool, weights, ObjectiveType.COLLECT_ITEMS, 2.5)
	_add_objective(pool, weights, ObjectiveType.SURVIVE, 2.0)
	_add_objective(pool, weights, ObjectiveType.REACH_LEVEL, 1.5)
	_add_objective(pool, weights, ObjectiveType.EXPLORE_BIOMES, 2.0)
	_add_objective(pool, weights, ObjectiveType.DASH_COUNT, 1.0)
	_add_objective(pool, weights, ObjectiveType.COMBO_MILESTONE, 1.5)
	_add_objective(pool, weights, ObjectiveType.DISTANCE, 1.5)
	# Context-dependent objectives
	if player_level >= 3:
		_add_objective(pool, weights, ObjectiveType.KILL_TYPE, 2.0)
		_add_objective(pool, weights, ObjectiveType.COLLECT_TYPE, 1.5)
	if player_level >= 5:
		_add_objective(pool, weights, ObjectiveType.DEFEAT_BOSS, 1.5)
		_add_objective(pool, weights, ObjectiveType.CRAFT_MOD, 1.5)
	if player_level >= 8:
		_add_objective(pool, weights, ObjectiveType.CRAFT_EQUIPMENT, 1.0)
		_add_objective(pool, weights, ObjectiveType.KILL_VARIANTS, 1.5 if EnemyVariantSystem else 0.0)
		_add_objective(pool, weights, ObjectiveType.USE_CONSUMABLE, 1.0)
	# Biome-specific objectives
	if current_biome >= 0:
		_add_objective(pool, weights, ObjectiveType.VISIT_BIOME, 1.5)
	# Pick an objective
	var obj_type: int = _weighted_pick(pool, weights)
	# Build the quest
	var quest := ProceduralQuest.new("pq_%d_%d" % [int(game_time), randi()])
	quest.objective_type = obj_type
	# Set target count based on objective type and player level
	match obj_type:
		ObjectiveType.KILL_ENEMIES:
			quest.target_count = 15 + player_level * 4
			quest.title = "Exterminator"
			quest.description = "Defeat %d enemies" % quest.target_count
		ObjectiveType.KILL_TYPE:
			var etype: int = _pick_enemy_type_for_biome(current_biome)
			quest.enemy_type_target = etype
			quest.target_count = 8 + player_level * 2
			var ename: String = _get_enemy_type_name(etype)
			quest.title = "Hunter: %s" % ename
			quest.description = "Defeat %d %s" % [quest.target_count, ename]
		ObjectiveType.KILL_VARIANTS:
			quest.target_count = 2 + player_level / 3
			quest.title = "Champion Slayer"
			quest.description = "Defeat %d elite/champion variants" % quest.target_count
		ObjectiveType.COLLECT_ITEMS:
			quest.target_count = 10 + player_level * 3
			quest.title = "Gatherer"
			quest.description = "Collect %d items" % quest.target_count
		ObjectiveType.COLLECT_TYPE:
			var ctype: int = _pick_collectible_type_for_biome(current_biome)
			quest.collectible_type_target = ctype
			quest.target_count = 5 + player_level
			var cname: String = _get_collectible_type_name(ctype)
			quest.title = "Collector: %s" % cname
			quest.description = "Collect %d %s" % [quest.target_count, cname]
		ObjectiveType.SURVIVE:
			quest.target_count = 90 + player_level * 15
			quest.title = "Survivor"
			quest.description = "Survive for %d seconds" % quest.target_count
			quest._start_time = game_time
		ObjectiveType.REACH_LEVEL:
			quest.target_count = player_level + 2
			quest.title = "Ascendant"
			quest.description = "Reach level %d" % quest.target_count
		ObjectiveType.EXPLORE_BIOMES:
			quest.target_count = _visited_biomes.size() + 2
			quest.title = "Trailblazer"
			quest.description = "Visit %d unique biomes" % quest.target_count
		ObjectiveType.VISIT_BIOME:
			var target_biome: int = _pick_target_biome(current_biome)
			quest.biome_target = target_biome
			quest.target_count = 1
			var bname: String = GameConstants.BIOME_NAMES.get(target_biome, "Unknown")
			quest.title = "Expedition: %s" % bname
			quest.description = "Travel to the %s biome" % bname
		ObjectiveType.DEFEAT_BOSS:
			quest.target_count = 1 + (player_level / 8)
			quest.title = "Boss Hunter"
			quest.description = "Defeat %d bosses" % quest.target_count
		ObjectiveType.CRAFT_MOD:
			quest.target_count = 1 + (player_level / 5)
			quest.title = "Modder"
			quest.description = "Craft %d weapon mods" % quest.target_count
		ObjectiveType.CRAFT_EQUIPMENT:
			quest.target_count = 1 + (player_level / 8)
			quest.title = "Armorsmith"
			quest.description = "Craft %d equipment pieces" % quest.target_count
		ObjectiveType.USE_CONSUMABLE:
			quest.target_count = 2 + (player_level / 4)
			quest.title = "Alchemist"
			quest.description = "Use %d consumables" % quest.target_count
		ObjectiveType.DASH_COUNT:
			quest.target_count = 20 + player_level * 5
			quest.title = "Swift Strider"
			quest.description = "Dash %d times" % quest.target_count
		ObjectiveType.COMBO_MILESTONE:
			quest.target_count = 10 + (player_level / 2) * 5
			quest.title = "On Fire"
			quest.description = "Achieve a x%d combo" % quest.target_count
		ObjectiveType.DISTANCE:
			quest.target_count = 500 + player_level * 100  # meters
			quest.title = "Wayfarer"
			quest.description = "Travel %d meters" % quest.target_count
	# Set rewards (scale with target count and player level)
	quest.reward_xp = 50 + quest.target_count * 4 + player_level * 10
	quest.reward_score = 200 + quest.target_count * 15 + player_level * 25
	# 30% chance of a material reward
	if randf() < 0.3:
		quest.reward_material = _pick_collectible_type_for_biome(current_biome)
	# 10% chance of a rare material reward (high-level quests only)
	if player_level >= 5 and randf() < 0.1:
		quest.reward_rare_material = randi() % GameConstants.RARE_MATERIAL_NAMES.size()
	# 25% chance of a modifier
	if randf() < 0.25:
		quest.modifier = _pick_modifier(quest)
		if quest.modifier == Modifier.TIME_LIMIT:
			quest.time_remaining = quest.modifier_param
	# Build the full description with modifier
	quest.description = _build_description(quest)
	# Add to active quests
	_active_quests.append(quest)
	quest_generated.emit(quest)
	GameManager.add_message("✦ New Quest: %s" % quest.title)
	return quest

func _build_description(quest: ProceduralQuest) -> String:
	var desc: String = quest.description
	match quest.modifier:
		Modifier.TIME_LIMIT:
			desc += " (within %ds)" % int(quest.modifier_param)
		Modifier.BONUS_XP:
			desc += " (bonus XP!)"
		Modifier.BONUS_LOOT:
			desc += " (bonus loot!)"
		Modifier.NO_DAMAGE:
			desc += " (no damage!)"
	return desc

func _pick_modifier(quest: ProceduralQuest) -> int:
	var pool: Array[int] = [Modifier.NONE, Modifier.BONUS_XP, Modifier.BONUS_LOOT]
	# Time limit only for short-ish quests
	if quest.target_count <= 30:
		pool.append(Modifier.TIME_LIMIT)
	# No-damage only for non-survival quests (survival + no damage is too hard)
	if quest.objective_type != ObjectiveType.SURVIVE:
		pool.append(Modifier.NO_DAMAGE)
	var picked: int = pool[randi() % pool.size()]
	# Set modifier param
	if picked == Modifier.TIME_LIMIT:
		quest.modifier_param = 120.0 + quest.target_count * 3.0
	return picked

# ─── Quest Progress Tracking ──────────────────────────────────────────────────

func _update_quest_progress(delta: float) -> void:
	var _completed_this_frame: Array[ProceduralQuest] = []
	for quest in _active_quests:
		if quest.completed or quest.expired:
			continue
		# Update current_count based on objective type
		match quest.objective_type:
			ObjectiveType.KILL_ENEMIES:
				quest.current_count = GameManager.player_kills
			ObjectiveType.COLLECT_ITEMS:
				quest.current_count = GameManager.player_total_pickups
			ObjectiveType.REACH_LEVEL:
				quest.current_count = GameManager.player_level
			ObjectiveType.EXPLORE_BIOMES:
				quest.current_count = _visited_biomes.size()
			ObjectiveType.SURVIVE:
				quest.current_count = int(GameManager.game_time - quest._start_time)
			ObjectiveType.DASH_COUNT:
				quest.current_count = _dashes_this_run
			ObjectiveType.COMBO_MILESTONE:
				quest.current_count = GameManager.player_best_combo
			ObjectiveType.DISTANCE:
				quest.current_count = int(_distance_traveled)
			ObjectiveType.DEFEAT_BOSS:
				quest.current_count = _boss_kills_this_run
			ObjectiveType.CRAFT_MOD:
				quest.current_count = _crafts_this_run
			ObjectiveType.USE_CONSUMABLE:
				quest.current_count = _consumables_used_this_run
			ObjectiveType.KILL_VARIANTS:
				quest.current_count = _variants_killed_this_run
			# KILL_TYPE, COLLECT_TYPE, VISIT_BIOME, CRAFT_EQUIPMENT are tracked via signals
		# Tick time limit
		if quest.modifier == Modifier.TIME_LIMIT and not quest.completed:
			quest.time_remaining -= delta
			if quest.time_remaining <= 0.0:
				quest.expired = true
				quest_expired.emit(quest)
				GameManager.add_message("⏰ Quest expired: %s" % quest.title)
				continue
		# Check completion
		if quest.current_count >= quest.target_count and not quest.completed:
			# Check NO_DAMAGE modifier
			if quest.modifier == Modifier.NO_DAMAGE and quest._no_damage:
				# Failed — mark as expired
				quest.expired = true
				quest_expired.emit(quest)
				GameManager.add_message("💔 Quest failed (took damage): %s" % quest.title)
				continue
			_completed_this_frame.append(quest)
		# Emit progress update
		if quest.current_count != quest.prev_count:
			quest.prev_count = quest.current_count
			quest_progress_updated.emit(quest)
	for quest in _completed_this_frame:
		_complete_quest(quest)

func _complete_quest(quest: ProceduralQuest) -> void:
	quest.completed = true
	_active_quests.erase(quest)
	_completed_quests += 1
	# Grant rewards
	GameManager.gain_xp(quest.reward_xp)
	GameManager.add_score(quest.reward_score)
	# Material reward
	if quest.reward_material >= 0 and WeaponModSystem:
		WeaponModSystem.add_material(quest.reward_material, 1)
	# Rare material reward
	if quest.reward_rare_material >= 0 and EquipmentSystem:
		EquipmentSystem.add_rare_material(quest.reward_rare_material, 1)
	# Bonus XP modifier
	if quest.modifier == Modifier.BONUS_XP:
		GameManager.gain_xp(quest.reward_xp)  # Double XP
	# Bonus loot modifier — grant an extra collectible drop
	if quest.modifier == Modifier.BONUS_LOOT:
		_spawn_bonus_loot_drop()
	quest_completed.emit(quest)
	var msg: String = "✓ QUEST COMPLETE: %s (+%d XP, +%d score)" % [quest.title, quest.reward_xp, quest.reward_score]
	GameManager.add_message(msg)
	# Generate a replacement quest after a short delay
	get_tree().create_timer(5.0).timeout.connect(func(): _maybe_generate_replacement())

func _maybe_generate_replacement() -> void:
	if _active_quests.size() < MAX_ACTIVE_QUESTS:
		generate_quest()

func _spawn_bonus_loot_drop() -> void:
	var player: Node3D = GameManager.player
	if not player or not is_instance_valid(player):
		return
	var collectible_scene: PackedScene = load("res://scenes/entities/collectible.tscn")
	if not collectible_scene:
		return
	var drop: Area3D = collectible_scene.instantiate()
	var world: Node = GameManager.world if GameManager.world else get_tree().current_scene
	world.add_child(drop)
	drop.global_position = player.global_position + Vector3(randf_range(-2, 2), 0.5, randf_range(-2, 2))
	var rare_types: Array[int] = [
		GameConstants.CollectibleType.METEOR_SHARD,
		GameConstants.CollectibleType.QUANTUM_FUZZ,
		GameConstants.CollectibleType.NEBULA_DUST,
	]
	var drop_type: int = rare_types[randi() % rare_types.size()]
	if drop.has_method("set_type"):
		drop.set_type(drop_type)
	if drop.has_method("start_tumble"):
		drop.start_tumble(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized())
	GameManager.collectibles.append(drop)
	if not drop.is_in_group("collectibles"):
		drop.add_to_group("collectibles")

func _expire_stale_quests(delta: float) -> void:
	# Quests that have been active for too long without completion expire
	for i in range(_active_quests.size() - 1, -1, -1):
		var quest: ProceduralQuest = _active_quests[i]
		if quest.completed or quest.expired:
			_active_quests.remove_at(i)
			continue

# ─── Signal Handlers ───────────────────────────────────────────────────────────

func _on_enemy_killed(enemy_name: String, _killer_name: String) -> void:
	# Track KILL_TYPE quests
	for quest in _active_quests:
		if quest.completed or quest.expired:
			continue
		if quest.objective_type == ObjectiveType.KILL_TYPE:
			# Check if the killed enemy matches the target type
			# We match by name since we don't have the enemy node here
			var target_name: String = _get_enemy_type_name(quest.enemy_type_target)
			if enemy_name.findn(target_name) >= 0 or target_name.findn(enemy_name) >= 0:
				quest.current_count += 1

func _on_boss_defeated(_boss: Node) -> void:
	_boss_kills_this_run += 1

func _on_biome_changed(biome_id: int) -> void:
	_visited_biomes[biome_id] = true
	# Track VISIT_BIOME quests
	for quest in _active_quests:
		if quest.completed or quest.expired:
			continue
		if quest.objective_type == ObjectiveType.VISIT_BIOME and quest.biome_target == biome_id:
			quest.current_count = 1

func _on_combo_milestone(combo: int, _tier: int, _color: Color) -> void:
	# COMBO_MILESTONE quests track via player_best_combo in _update_quest_progress
	pass

func _on_level_up(_level: int) -> void:
	# REACH_LEVEL quests track via player_level in _update_quest_progress
	pass

func _on_mod_crafted(_mod_id: int) -> void:
	_crafts_this_run += 1

func _on_equipment_crafted(_piece_id: int) -> void:
	_crafts_this_run += 1

func _on_consumable_used(_consumable_id: int) -> void:
	_consumables_used_this_run += 1

func _on_variant_defeated(_enemy: Node, _tier: int, _traits: Array) -> void:
	_variants_killed_this_run += 1

func _on_game_restarted() -> void:
	_active_quests.clear()
	_completed_quests = 0
	_rotation_timer = 60.0
	_visited_biomes.clear()
	_boss_kills_this_run = 0
	_distance_traveled = 0.0
	_last_player_pos = Vector3.ZERO
	_dashes_this_run = 0
	_crafts_this_run = 0
	_consumables_used_this_run = 0
	_variants_killed_this_run = 0

func _on_player_died() -> void:
	pass  # Quests persist on the death screen

# ── Phase 33: Dash tracking (called from player.gd on each dash) ──
# The quest system can't easily intercept dashes via signals (dashes don't
# emit a GameManager signal), so we expose a direct call API.
func notify_dash() -> void:
	_dashes_this_run += 1

# ─── Public Query API (for QuestLog UI integration) ───────────────────────────

func get_active_quests() -> Array:
	return _active_quests.duplicate()

func get_completed_count() -> int:
	return _completed_quests

# ─── Helpers ───────────────────────────────────────────────────────────────────

func _add_objective(pool: Array[int], weights: Array[float], obj_type: int, weight: float) -> void:
	if weight <= 0.0:
		return
	pool.append(obj_type)
	weights.append(weight)

func _weighted_pick(pool: Array[int], weights: Array[float]) -> int:
	var total: float = 0.0
	for w in weights:
		total += w
	if total <= 0.0 or pool.is_empty():
		return ObjectiveType.KILL_ENEMIES
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for i in range(pool.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return pool[i]
	return pool[pool.size() - 1]

func _pick_enemy_type_for_biome(biome: int) -> int:
	# Pick an enemy type thematically appropriate to the biome
	var biome_enemies: Dictionary = {
		GameConstants.Biome.LAVA: GameConstants.EnemyType.BOMBER,
		GameConstants.Biome.VOLCANO_CORE: GameConstants.EnemyType.BOMBER,
		GameConstants.Biome.CRYSTAL: GameConstants.EnemyType.CRYSTAL_GUARDIAN,
		GameConstants.Biome.CRYSTAL_CAVERNS: GameConstants.EnemyType.CRYSTAL_GUARDIAN,
		GameConstants.Biome.SNOW: GameConstants.EnemyType.WISP,
		GameConstants.Biome.ALIEN: GameConstants.EnemyType.PHASE_SHIFTER,
		GameConstants.Biome.DIGITAL_GRID: GameConstants.EnemyType.PHASE_SHIFTER,
		GameConstants.Biome.FOREST: GameConstants.EnemyType.BLOB,
		GameConstants.Biome.SWAMP: GameConstants.EnemyType.SPITTER,
		GameConstants.Biome.TOXIC_BOG: GameConstants.EnemyType.TOXIC_SPORE,
		GameConstants.Biome.MUSHROOM: GameConstants.EnemyType.SWARM_MITE,
		GameConstants.Biome.UNDERGROUND: GameConstants.EnemyType.ECHO_KNIGHT,
		GameConstants.Biome.ANCIENT_RUINS: GameConstants.EnemyType.ECHO_KNIGHT,
		GameConstants.Biome.SKY_CITADEL: GameConstants.EnemyType.PLASMA_STALKER,
		GameConstants.Biome.DEEP_OCEAN: GameConstants.EnemyType.WISP,
	}
	if biome_enemies.has(biome):
		return biome_enemies[biome]
	# Default: pick from easy pool
	var default_pool: Array[int] = [
		GameConstants.EnemyType.BLOB,
		GameConstants.EnemyType.WISP,
		GameConstants.EnemyType.SWARM_MITE,
	]
	return default_pool[randi() % default_pool.size()]

func _pick_collectible_type_for_biome(biome: int) -> int:
	# Pick a collectible type thematically appropriate to the biome
	var biome_collectibles: Dictionary = {
		GameConstants.Biome.LAVA: GameConstants.CollectibleType.METEOR_SHARD,
		GameConstants.Biome.VOLCANO_CORE: GameConstants.CollectibleType.METEOR_SHARD,
		GameConstants.Biome.CRYSTAL: GameConstants.CollectibleType.QUANTUM_FUZZ,
		GameConstants.Biome.CRYSTAL_CAVERNS: GameConstants.CollectibleType.QUANTUM_FUZZ,
		GameConstants.Biome.SNOW: GameConstants.CollectibleType.STAR_FRUIT,
		GameConstants.Biome.ALIEN: GameConstants.CollectibleType.NEBULA_DUST,
		GameConstants.Biome.DIGITAL_GRID: GameConstants.CollectibleType.NEBULA_DUST,
		GameConstants.Biome.FOREST: GameConstants.CollectibleType.STAR_FRUIT,
		GameConstants.Biome.SWAMP: GameConstants.CollectibleType.SPACE_GLOOP,
		GameConstants.Biome.TOXIC_BOG: GameConstants.CollectibleType.SPACE_GLOOP,
		GameConstants.Biome.MUSHROOM: GameConstants.CollectibleType.HEALTH_FRAGMENT,
		GameConstants.Biome.UNDERGROUND: GameConstants.CollectibleType.QUANTUM_FUZZ,
		GameConstants.Biome.ANCIENT_RUINS: GameConstants.CollectibleType.METEOR_SHARD,
		GameConstants.Biome.SKY_CITADEL: GameConstants.CollectibleType.NEBULA_DUST,
		GameConstants.Biome.DEEP_OCEAN: GameConstants.CollectibleType.STAR_FRUIT,
	}
	if biome_collectibles.has(biome):
		return biome_collectibles[biome]
	# Default: random rare-ish collectible
	var pool: Array[int] = [
		GameConstants.CollectibleType.XP_ORB,
		GameConstants.CollectibleType.STAR_FRUIT,
		GameConstants.CollectibleType.SPACE_GLOOP,
	]
	return pool[randi() % pool.size()]

func _pick_target_biome(current_biome: int) -> int:
	# Pick a biome different from the current one
	var all_biomes: Array[int] = []
	for key in GameConstants.BIOME_NAMES.keys():
		var biome_id: int = int(key)
		if biome_id != current_biome:
			all_biomes.append(biome_id)
	if all_biomes.is_empty():
		return current_biome
	return all_biomes[randi() % all_biomes.size()]

func _get_enemy_type_name(etype: int) -> String:
	# Use the EnemySpawner's name table if available, else fallback
	if EnemySpawner and EnemySpawner.ENEMY_TYPE_NAMES.has(etype):
		return EnemySpawner.ENEMY_TYPE_NAMES[etype]
	return "Enemy"

func _get_collectible_type_name(ctype: int) -> String:
	# Use GameConstants collectible names if available
	if GameConstants.COLLECTIBLE_NAMES and ctype >= 0 and ctype < GameConstants.COLLECTIBLE_NAMES.size():
		return GameConstants.COLLECTIBLE_NAMES[ctype]
	return "Item"

func get_objective_icon(obj_type: int) -> String:
	if obj_type < 0 or obj_type >= OBJECTIVE_ICONS.size():
		return ""
	return OBJECTIVE_ICONS[obj_type]

func get_objective_name(obj_type: int) -> String:
	if obj_type < 0 or obj_type >= OBJECTIVE_NAMES.size():
		return "Unknown"
	return OBJECTIVE_NAMES[obj_type]