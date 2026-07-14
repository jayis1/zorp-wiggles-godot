## Zorp Wiggles — Enemy Spawner
## Dynamically spawns enemies around the player with difficulty scaling.
## Spawn interval decreases with player level. Throttles when too many nearby.
## Enemy type selection based on distance from center (farther = harder).
## Ported from the spawn logic in Ursina game.py game_update().

extends Node3D

class_name EnemySpawner

# ─── Spawn State ──────────────────────────────────────────────────────────────
var spawn_timer: float = 0.0
var spawn_warning_timer: float = 0.0
var pending_spawns: Array[Dictionary] = []

# ─── Enemy Type Tiers ─────────────────────────────────────────────────────────
# Maps to enemy scenes by difficulty tier (easy/medium/hard)
const EASY_TYPES: Array[int] = [
	GameConstants.EnemyType.BLOB,
	GameConstants.EnemyType.WISP,
]
const MEDIUM_TYPES: Array[int] = [
	GameConstants.EnemyType.BLOB,
	GameConstants.EnemyType.GRAVITON,
	GameConstants.EnemyType.BOMBER,
	GameConstants.EnemyType.SENTINEL,
	GameConstants.EnemyType.SPITTER,
	GameConstants.EnemyType.WISP,
]
const HARD_TYPES: Array[int] = [
	GameConstants.EnemyType.SERPENT,
	GameConstants.EnemyType.GRAVITON,
	GameConstants.EnemyType.BOMBER,
	GameConstants.EnemyType.SENTINEL,
	GameConstants.EnemyType.SPITTER,
	GameConstants.EnemyType.DRAKE,
]

# Enemy scene paths by type
const ENEMY_SCENES: Dictionary = {
	GameConstants.EnemyType.BLOB: "res://scenes/entities/enemy_blob.tscn",
	GameConstants.EnemyType.SERPENT: "res://scenes/entities/enemy_serpent.tscn",
	GameConstants.EnemyType.GRAVITON: "res://scenes/entities/enemy_graviton.tscn",
	GameConstants.EnemyType.WISP: "res://scenes/entities/enemy_wisp.tscn",
	GameConstants.EnemyType.SENTINEL: "res://scenes/entities/enemy_sentinel.tscn",
	GameConstants.EnemyType.BOMBER: "res://scenes/entities/enemy_bomber.tscn",
	GameConstants.EnemyType.SPITTER: "res://scenes/entities/enemy_spitter.tscn",
	GameConstants.EnemyType.DRAKE: "res://scenes/entities/enemy_drake.tscn",
}

func _ready() -> void:
	spawn_timer = 2.0  # Initial delay before first spawn

func _process(delta: float) -> void:
	if GameManager.is_paused or not GameManager.player_is_alive:
		return

	# Update pending spawns (spawn warnings)
	_update_pending_spawns(delta)

	# Spawn timer
	spawn_timer -= delta
	if spawn_timer <= 0:
		_try_spawn()
		_reset_spawn_timer()

func _update_pending_spawns(delta: float) -> void:
	for i in range(pending_spawns.size() - 1, -1, -1):
		var ps: Dictionary = pending_spawns[i]
		ps["timer"] -= delta
		if ps["timer"] <= 0:
			_materialize_enemy(ps)
			pending_spawns.remove_at(i)

func _try_spawn() -> void:
	# Count active enemies
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var alive_count: int = 0
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead:
			alive_count += 1

	# Check spawn cap (alive + pending)
	if alive_count + pending_spawns.size() >= GameConstants.MAX_ACTIVE_ENEMIES:
		return

	# Check nearby density throttle
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var nearby_count: int = 0
	for e in enemies:
		if not is_instance_valid(e) or e.is_dead:
			continue
		if player.global_position.distance_to(e.global_position) < GameConstants.SPAWN_DENSITY_NEAR_RADIUS:
			nearby_count += 1
			if nearby_count >= GameConstants.SPAWN_DENSITY_NEAR_THRESHOLD:
				return  # Too many nearby, skip this spawn

	# Pick spawn position around player
	var angle: float = randf() * TAU
	var dist: float = randf_range(
		GameConstants.ENEMY_SPAWN_DISTANCE_MIN,
		GameConstants.ENEMY_SPAWN_DISTANCE_MAX
	)
	var spawn_pos: Vector3 = player.global_position + Vector3(
		cos(angle) * dist, 1.0, sin(angle) * dist
	)

	# Clamp to world bounds
	var extent: float = GameConstants.WORLD_EXTENT - 5.0
	spawn_pos.x = clampf(spawn_pos.x, -extent, extent)
	spawn_pos.z = clampf(spawn_pos.z, -extent, extent)

	# Pick enemy type based on distance from world center
	var world_center: Vector3 = Vector3.ZERO
	var dist_from_center: float = spawn_pos.distance_to(world_center)
	var enemy_type: int = _pick_enemy_type(dist_from_center)

	# Create spawn warning, then materialize after delay
	pending_spawns.append({
		"pos": spawn_pos,
		"type": enemy_type,
		"timer": GameConstants.ENEMY_SPAWN_WARNING_DURATION,
	})

	# Create visual warning ring
	var warning_scene := load("res://scenes/entities/spawn_warning.tscn")
	if warning_scene:
		var warning: Node3D = warning_scene.instantiate()
		get_parent().add_child(warning)
		warning.global_position = spawn_pos
		warning.set("duration", GameConstants.ENEMY_SPAWN_WARNING_DURATION)

func _materialize_enemy(spawn_data: Dictionary) -> void:
	var enemy_type: int = spawn_data["type"]
	var pos: Vector3 = spawn_data["pos"]

	var scene_path: String = ENEMY_SCENES.get(enemy_type, "")
	if scene_path.is_empty():
		return

	var scene := load(scene_path)
	if not scene:
		print("[EnemySpawner] Failed to load enemy scene: %s" % scene_path)
		return

	var enemy: CharacterBody3D = scene.instantiate()
	get_parent().add_child(enemy)
	enemy.global_position = pos

	# Scale enemy to player level
	_scale_enemy_to_player_level(enemy)

func _pick_enemy_type(distance_from_center: float) -> int:
	var tier: int = min(int(distance_from_center / GameConstants.DIFFICULTY_SCALE_DISTANCE), 2)
	match tier:
		0:
			return EASY_TYPES[randi() % EASY_TYPES.size()]
		1:
			return MEDIUM_TYPES[randi() % MEDIUM_TYPES.size()]
		_:
			# Hard tier — small chance for Drake boss
			if randf() < 0.05:
				return GameConstants.EnemyType.DRAKE
			return HARD_TYPES[randi() % HARD_TYPES.size()]

func _scale_enemy_to_player_level(enemy: Node3D) -> void:
	var player_level: int = GameManager.player_level
	var raw_tier: float = max(0.0, float(player_level - 1) / GameConstants.PLAYER_LEVEL_DIFFICULTY_INTERVAL)
	var tier_floor: int = int(raw_tier)
	var tier_frac: float = raw_tier - tier_floor

	if tier_floor > 0 or tier_frac > 0:
		var hp_mult_current: float = 1.0 + tier_floor * GameConstants.ENEMY_HP_SCALE_PER_TIER
		var hp_mult_next: float = 1.0 + (tier_floor + 1) * GameConstants.ENEMY_HP_SCALE_PER_TIER
		var hp_mult: float = lerpf(hp_mult_current, hp_mult_next, tier_frac)

		var dmg_mult_current: float = 1.0 + tier_floor * GameConstants.ENEMY_DAMAGE_SCALE_PER_TIER
		var dmg_mult_next: float = 1.0 + (tier_floor + 1) * GameConstants.ENEMY_DAMAGE_SCALE_PER_TIER
		var dmg_mult: float = lerpf(dmg_mult_current, dmg_mult_next, tier_frac)

		if enemy is EnemyBase:
			var new_hp: int = int(enemy.max_hp * hp_mult)
			enemy.max_hp = new_hp
			enemy.hp = new_hp
			enemy.damage = int(enemy.damage * dmg_mult)

func _reset_spawn_timer() -> void:
	# Base interval decreases with player level
	var level_tiers: int = (GameManager.player_level - 1) / GameConstants.PLAYER_LEVEL_DIFFICULTY_INTERVAL
	var interval: float = max(
		GameConstants.MIN_SPAWN_INTERVAL,
		GameConstants.ENEMY_SPAWN_INTERVAL - level_tiers * GameConstants.ENEMY_SPAWN_INTERVAL_LEVEL_DECAY
	)

	# Throttle if too many nearby enemies
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		var nearby: int = 0
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.is_dead:
				continue
			if player.global_position.distance_to(e.global_position) < GameConstants.SPAWN_DENSITY_NEAR_RADIUS:
				nearby += 1
		if nearby >= GameConstants.SPAWN_DENSITY_NEAR_THRESHOLD:
			interval /= GameConstants.SPAWN_DENSITY_SLOWDOWN

	spawn_timer = interval