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
	GameConstants.EnemyType.SWARM_MITE,  # Enhancement: Swarm Mites in easy tier
]
const MEDIUM_TYPES: Array[int] = [
	GameConstants.EnemyType.BLOB,
	GameConstants.EnemyType.GRAVITON,
	GameConstants.EnemyType.BOMBER,
	GameConstants.EnemyType.SENTINEL,
	GameConstants.EnemyType.SPITTER,
	GameConstants.EnemyType.WISP,
	GameConstants.EnemyType.SWARM_MITE,  # Enhancement: Mites also in medium
	GameConstants.EnemyType.PHASE_SHIFTER,  # Enhancement: Phase Shifter in medium
]
const HARD_TYPES: Array[int] = [
	GameConstants.EnemyType.SERPENT,
	GameConstants.EnemyType.GRAVITON,
	GameConstants.EnemyType.BOMBER,
	GameConstants.EnemyType.SENTINEL,
	GameConstants.EnemyType.SPITTER,
	GameConstants.EnemyType.DRAKE,
	GameConstants.EnemyType.CRYSTAL_GUARDIAN,  # Enhancement: Guardian in hard tier
	GameConstants.EnemyType.PHASE_SHIFTER,     # Enhancement: Phase Shifter also in hard
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
	# Enhancement: New enemy types
	GameConstants.EnemyType.SWARM_MITE: "res://scenes/entities/enemy_swarm_mite.tscn",
	GameConstants.EnemyType.CRYSTAL_GUARDIAN: "res://scenes/entities/enemy_crystal_guardian.tscn",
	GameConstants.EnemyType.PHASE_SHIFTER: "res://scenes/entities/enemy_phase_shifter.tscn",
}

# Enemy type enum → name string (for looking up type data from EnemyTypeData)
const ENEMY_TYPE_NAMES: Dictionary = {
	GameConstants.EnemyType.BLOB: "Slime Blob",
	GameConstants.EnemyType.SERPENT: "Plasma Serpent",
	GameConstants.EnemyType.GRAVITON: "Graviton",
	GameConstants.EnemyType.WISP: "Void Wisp",
	GameConstants.EnemyType.SENTINEL: "Starburst Sentinel",
	GameConstants.EnemyType.BOMBER: "Void Bomber",
	GameConstants.EnemyType.SPITTER: "Spore Spitter",
	GameConstants.EnemyType.DRAKE: "Plasma Drake",
	# Enhancement: New enemy types
	GameConstants.EnemyType.SWARM_MITE: "Swarm Mite",
	GameConstants.EnemyType.CRYSTAL_GUARDIAN: "Crystal Guardian",
	GameConstants.EnemyType.PHASE_SHIFTER: "Phase Shifter",
}

func _ready() -> void:
	spawn_timer = 2.0  # Initial delay before first spawn

func _process(delta: float) -> void:
	if GameManager.is_paused:
		return
	# ── Phase 19: Co-op — keep spawning if either player is alive ──
	if not GameManager.player_is_alive and not CoOpManager.p2_active:
		return
	if not GameManager.player_is_alive and CoOpManager.p2_active and CoOpManager.p2_is_downed:
		return  # Both players downed — stop spawning

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
	# ── Phase 19: Co-op increases spawn cap ──
	var spawn_cap: int = GameConstants.MAX_ACTIVE_ENEMIES + CoOpManager.get_max_enemies_bonus()
	if alive_count + pending_spawns.size() >= spawn_cap:
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

	# Enhancement: Swarm Mite pack spawning — when a mite is picked,
	# there's a chance to spawn additional mites nearby as a pack.
	# This creates the "swarm" feel — multiple mites rushing from one direction.
	if enemy_type == GameConstants.EnemyType.SWARM_MITE:
		if randf() < GameConstants.SWARM_MITE_PACK_SPAWN_CHANCE:
			var pack_size: int = randi_range(
				GameConstants.SWARM_MITE_PACK_SIZE_MIN,
				GameConstants.SWARM_MITE_PACK_SIZE_MAX
			)
			for i in range(1, pack_size):  # i=0 is the original mite already queued
				var pack_angle: float = angle + randf_range(-0.6, 0.6)
				var pack_dist: float = dist + randf_range(-3.0, 3.0)
				var pack_pos: Vector3 = player.global_position + Vector3(
					cos(pack_angle) * pack_dist, 1.0, sin(pack_angle) * pack_dist
				)
				pack_pos.x = clampf(pack_pos.x, -extent, extent)
				pack_pos.z = clampf(pack_pos.z, -extent, extent)
				pending_spawns.append({
					"pos": pack_pos,
					"type": enemy_type,
					"timer": GameConstants.ENEMY_SPAWN_WARNING_DURATION + randf_range(0.0, 0.5),
				})

	# Create visual warning ring
	var warning_scene: PackedScene = load("res://scenes/entities/spawn_warning.tscn")
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

	var scene: PackedScene = load(scene_path)
	if not scene:
		print("[EnemySpawner] Failed to load enemy scene: %s" % scene_path)
		return

	var enemy: CharacterBody3D = scene.instantiate()
	# Set position BEFORE add_child so _ready() sees the correct global_position.
	# This is important for enemies like the Plasma Serpent whose _ready()
	# initializes segment positions from global_position.
	enemy.position = pos
	get_parent().add_child(enemy)
	GameManager.enemies.append(enemy)

	# Override enemy_name with the proper type name from EnemyTypeData so
	# the kill feed and boss bar show the correct name. The scene defaults
	# may have a generic name (e.g. "Space Blob") but the type-specific name
	# (e.g. "Slime Blob") is more descriptive. We set this AFTER add_child
	# so _ready() has already run with the scene's defaults.
	var type_name: String = ENEMY_TYPE_NAMES.get(enemy_type, "")
	if not type_name.is_empty() and "enemy_name" in enemy:
		enemy.enemy_name = type_name

	# ── Phase 11: Spawn materialization particles ──
	# Energy coalescing effect at the spawn point
	var enemy_base: EnemyBase = enemy as EnemyBase
	if enemy_base:
		ParticleEffects.spawn_materialization(get_parent(), pos, enemy_base.base_color)

	# Emit spawn direction signal for HUD arrows
	GameManager.enemy_spawned_near.emit(pos, enemy_type)

	# Scale enemy to player level
	_scale_enemy_to_player_level(enemy)

func _pick_enemy_type(distance_from_center: float) -> int:
	var tier: int = min(int(distance_from_center / GameConstants.DIFFICULTY_SCALE_DISTANCE), 2)
	var pool: Array[int]
	match tier:
		0:
			pool = EASY_TYPES.duplicate()
		1:
			pool = MEDIUM_TYPES.duplicate()
		_:
			pool = HARD_TYPES.duplicate()
	# ── Phase 17: Weather-dependent spawning — bonus-weighted enemies ──
	# During special weather, certain enemy types get extra entries in the pool,
	# making them more likely to spawn (e.g. Void Wisps during thunderstorms).
	var bonus_types: Array = WeatherSystem.get_weather_spawn_bonus_types()
	for bt in bonus_types:
		# Add the bonus type up to 2 extra times if it's already in the pool,
		# or 1 time if it's not (so weather can introduce out-of-tier enemies).
		if bt in pool:
			pool.append(bt)
			pool.append(bt)
		else:
			pool.append(bt)
	return pool[randi() % pool.size()]

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
			var new_dmg: int = int(enemy.damage * dmg_mult)
			# ── Phase 19: Co-op enemy scaling — 2x HP, 1.5x damage ──
			new_hp = int(new_hp * CoOpManager.get_enemy_hp_mult())
			new_dmg = int(new_dmg * CoOpManager.get_enemy_damage_mult())
			enemy.max_hp = new_hp
			enemy.hp = new_hp
			enemy.damage = new_dmg

func _reset_spawn_timer() -> void:
	# Base interval decreases with player level
	var level_tiers: int = (GameManager.player_level - 1) / GameConstants.PLAYER_LEVEL_DIFFICULTY_INTERVAL
	var interval: float = max(
		GameConstants.MIN_SPAWN_INTERVAL,
		GameConstants.ENEMY_SPAWN_INTERVAL - level_tiers * GameConstants.ENEMY_SPAWN_INTERVAL_LEVEL_DECAY
	)
	# ── Phase 19: Co-op — 30% faster spawns ──
	interval /= CoOpManager.get_spawn_rate_mult()

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
			interval /= GameConstants.SPAWN_DENSITY_SLOWDOWN  # SLOWER (longer interval)

	spawn_timer = interval