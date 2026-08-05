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

# ─── Precached Enemy Scenes ──────────────────────────────────────────────────
# PackedScenes are loaded once at _ready and reused for every materialize call.
# The previous code called load() on every spawn — a resource lookup that hits
# the filesystem cache but still allocates a String-keyed lookup and does a
# ref-count dance each time. Precaching eliminates that per-spawn cost entirely,
# which matters during heavy combat (swarm packs, endless mode, double-trouble
# modifier) where spawns fire multiple times per second.
static var _cached_scenes: Dictionary = {}  # { enemy_type: PackedScene }

static func _get_cached_scene(enemy_type: int) -> PackedScene:
	if _cached_scenes.has(enemy_type):
		return _cached_scenes[enemy_type]
	var scene_path: String = ENEMY_SCENES.get(enemy_type, "")
	if scene_path.is_empty():
		return null
	var scene: PackedScene = load(scene_path)
	if scene:
		_cached_scenes[enemy_type] = scene
	return scene

# ─── Nearby enemy count (shared between _try_spawn and _reset_spawn_timer) ───
# _try_spawn already counts nearby enemies during its single-pass loop. Previously
# _reset_spawn_timer re-iterated the entire enemy group to count them again — a
# redundant O(n) scan every spawn cycle. We cache the count from _try_spawn so
# _reset_spawn_timer can reuse it without a second pass.
var _last_nearby_count: int = 0

# Precached spawn-warning scene (loaded once, reused for every spawn).
static var _cached_spawn_warning: PackedScene = null

# ─── Enemy Type Tiers ─────────────────────────────────────────────────────────
# Maps to enemy scenes by difficulty tier (easy/medium/hard)
const EASY_TYPES: Array[int] = [
	GameConstants.EnemyType.BLOB,
	GameConstants.EnemyType.WISP,
	GameConstants.EnemyType.SWARM_MITE,  # Enhancement: Swarm Mites in easy tier
	GameConstants.EnemyType.TOXIC_SPORE, # Phase 23: Toxic Spore in easy tier
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
	GameConstants.EnemyType.TOXIC_SPORE,     # Phase 23: Toxic Spore also in medium
	GameConstants.EnemyType.CRYSTAL_WRAITH,  # Phase 23: Crystal Wraith in medium
	GameConstants.EnemyType.ECHO_KNIGHT,     # Phase 23: Echo Knight in medium
	GameConstants.EnemyType.PLASMA_STALKER,  # Phase 23: Plasma Stalker in medium
	GameConstants.EnemyType.MIRROR_MIMIC,    # Phase 23: Mirror Mimic in medium
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
	GameConstants.EnemyType.SWARM_QUEEN,       # Phase 23: Swarm Queen in hard tier
	GameConstants.EnemyType.CRYSTAL_WRAITH,    # Phase 23: Crystal Wraith also in hard
	GameConstants.EnemyType.ECHO_KNIGHT,        # Phase 23: Echo Knight also in hard
	GameConstants.EnemyType.PLASMA_STALKER,    # Phase 23: Plasma Stalker also in hard
	GameConstants.EnemyType.TIME_WARDEN,       # Phase 23: Time Warden in hard tier
	GameConstants.EnemyType.MIRROR_MIMIC,      # Phase 23: Mirror Mimic also in hard
	GameConstants.EnemyType.GRAVITY_ELEMENTAL, # Phase 23: Gravity Elemental in hard tier
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
	# Phase 23: New enemy types
	GameConstants.EnemyType.TOXIC_SPORE: "res://scenes/entities/enemy_toxic_spore.tscn",
	GameConstants.EnemyType.SWARM_QUEEN: "res://scenes/entities/enemy_swarm_queen.tscn",
	GameConstants.EnemyType.CRYSTAL_WRAITH: "res://scenes/entities/enemy_crystal_wraith.tscn",
	GameConstants.EnemyType.ECHO_KNIGHT: "res://scenes/entities/enemy_echo_knight.tscn",
	# Phase 23: New enemy types (batch 2)
	GameConstants.EnemyType.PLASMA_STALKER: "res://scenes/entities/enemy_plasma_stalker.tscn",
	GameConstants.EnemyType.TIME_WARDEN: "res://scenes/entities/enemy_time_warden.tscn",
	GameConstants.EnemyType.MIRROR_MIMIC: "res://scenes/entities/enemy_mirror_mimic.tscn",
	# Phase 23: New enemy types (batch 3 — bosses & elites)
	GameConstants.EnemyType.VOID_LEVIATHAN: "res://scenes/entities/enemy_void_leviathan.tscn",
	GameConstants.EnemyType.ANCIENT_SENTINEL: "res://scenes/entities/enemy_ancient_sentinel.tscn",
	GameConstants.EnemyType.GRAVITY_ELEMENTAL: "res://scenes/entities/enemy_gravity_elemental.tscn",
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
	# Phase 23: New enemy types
	GameConstants.EnemyType.TOXIC_SPORE: "Toxic Spore",
	GameConstants.EnemyType.SWARM_QUEEN: "Swarm Queen",
	GameConstants.EnemyType.CRYSTAL_WRAITH: "Crystal Wraith",
	GameConstants.EnemyType.ECHO_KNIGHT: "Echo Knight",
	# Phase 23: New enemy types (batch 2)
	GameConstants.EnemyType.PLASMA_STALKER: "Plasma Stalker",
	GameConstants.EnemyType.TIME_WARDEN: "Time Warden",
	GameConstants.EnemyType.MIRROR_MIMIC: "Mirror Mimic",
	# Phase 23: New enemy types (batch 3 — bosses & elites)
	GameConstants.EnemyType.VOID_LEVIATHAN: "Void Leviathan",
	GameConstants.EnemyType.ANCIENT_SENTINEL: "Ancient Sentinel",
	GameConstants.EnemyType.GRAVITY_ELEMENTAL: "Gravity Elemental",
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
	# ── Phase 25: Boss Rush mode — normal spawning is disabled; the
	# GameModeManager drives sequential boss spawns instead. ──
	if GameModeManager and GameModeManager.is_boss_rush():
		return
	# ── Phase 32: PvP mode — no enemies, just the two players ──
	if GameModeManager and GameModeManager.is_pvp():
		return
	# ── Phase 34: Boss Gauntlet — no normal enemies, only the boss queue ──
	if GameModeManager and GameModeManager.is_boss_gauntlet():
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
	# Count active enemies and nearby density in a SINGLE pass over the
	# GameManager.enemies array. This avoids a scene-tree group scan
	# (get_nodes_in_group) on every spawn tick — the GameManager.enemies
	# array is already maintained (append on materialize, erase on death)
	# and is the canonical enemy list. Matches the optimization pattern
	# from poison_cloud.gd (Enhancement Pack 30) and pulse_wave.gd
	# (Enhancement Pack 31).
	var enemies: Array[Node3D] = GameManager.enemies
	var alive_count: int = 0
	var nearby_count: int = 0

	# Check spawn cap (alive + pending)
	# ── Phase 19: Co-op increases spawn cap ──
	# ── Phase 7: Time-based difficulty increases max enemies ──
	var spawn_cap: int = GameConstants.MAX_ACTIVE_ENEMIES + CoOpManager.get_max_enemies_bonus() + GameManager.get_time_max_enemy_bonus()
	# Fast early exit: if pending spawns alone fill the cap, no point
	# counting alive enemies at all (we can't spawn regardless).
	if pending_spawns.size() >= spawn_cap:
		return

	# Check nearby density throttle
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Single-pass: count both alive and nearby in one loop. We bail early
	# from inside the loop if either threshold (spawn cap or nearby density)
	# is exceeded, avoiding a full iteration when possible.
	for e in enemies:
		if not is_instance_valid(e) or e.is_dead:
			continue
		alive_count += 1
		if alive_count + pending_spawns.size() >= spawn_cap:
			_last_nearby_count = nearby_count
			return  # Spawn cap reached
		if player.global_position.distance_to(e.global_position) < GameConstants.SPAWN_DENSITY_NEAR_RADIUS:
			nearby_count += 1
			if nearby_count >= GameConstants.SPAWN_DENSITY_NEAR_THRESHOLD:
				_last_nearby_count = nearby_count
				return  # Too many nearby, skip this spawn
	# Cache the nearby count so _reset_spawn_timer can reuse it without
	# re-iterating the entire enemy group (eliminates a redundant O(n) scan).
	_last_nearby_count = nearby_count

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

	# Create visual warning ring — use the precached scene if available.
	# load() is called here every spawn tick; precaching avoids the repeated
	# resource lookup. The scene is tiny but the lookup still costs a String
	# hash + dictionary probe per spawn.
	var warning_scene: PackedScene = _cached_spawn_warning
	if warning_scene == null:
		warning_scene = load("res://scenes/entities/spawn_warning.tscn")
		if warning_scene:
			_cached_spawn_warning = warning_scene
	if warning_scene:
		var warning: Node3D = warning_scene.instantiate()
		get_parent().add_child(warning)
		warning.global_position = spawn_pos
		warning.set("duration", GameConstants.ENEMY_SPAWN_WARNING_DURATION)
		# ── Tier-colored warning ring ── Pass the enemy type so the ring
		# can color-code the threat: yellow (easy) / orange (medium) /
		# red (hard). This gives the player an instant visual cue about
		# what's materializing before the enemy appears.
		if warning.has_method("set_tier_color"):
			warning.set_tier_color(enemy_type)

func _materialize_enemy(spawn_data: Dictionary) -> void:
	var enemy_type: int = spawn_data["type"]
	var pos: Vector3 = spawn_data["pos"]

	# Use the precached PackedScene (loaded once at first use, reused for
	# every subsequent spawn of this type). Avoids a per-spawn load() lookup.
	var scene: PackedScene = _get_cached_scene(enemy_type)
	if not scene:
		print_verbose("[EnemySpawner] Failed to load enemy scene for type %d" % enemy_type)
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
		# ── Spawn ground ring (initial materialization) ── A quick, small
		# ground ring at the exact spawn point, fired at the moment the enemy
		# materializes — before the 2s grace period fade-in. This is the
		# "energy arriving" visual; the enemy_base.gd activation ring (fired
		# when the grace period ends) is the "entity activated" visual. The
		# two rings create a two-stage materialization that reads as the
		# enemy assembling from raw energy → becoming a threat. This initial
		# ring is smaller and faster (max_radius 2-4, 0.35s) than the
		# activation ring (2.5+scale*0.5, same timing) to distinguish the stages.
		var _spawn_ring_radius: float = clampf(1.5 + enemy_base.base_scale * 1.0, 1.5, 4.0)
		ParticleEffects.spawn_spawn_ring(get_parent(), pos, enemy_base.base_color, _spawn_ring_radius)
		# Materialization SFX — a subtle descending blip that gives the
		# coalescing particles an audio identity. Low volume so it doesn't
		# overwhelm during heavy waves where several enemies materialize
		# in quick succession. Skipped for bosses (boss_spawn SFX covers it).
		if not enemy_base.is_arena_boss and not enemy_base.is_world_boss:
			AudioManager.play_sfx(AudioManager.SFX_SPAWN_IN)

	# Emit spawn direction signal for HUD arrows
	GameManager.enemy_spawned_near.emit(pos, enemy_type)

	# Scale enemy to player level
	_scale_enemy_to_player_level(enemy)

	# ── Phase 33: World Modifier System — apply per-run enemy multipliers ──
	# These stack on top of the level/time/weather scaling above.
	if WorldModifierSystem and WorldModifierSystem.is_initialized():
		if enemy is EnemyBase:
			var eb: EnemyBase = enemy as EnemyBase
			var wm_hp_mult: float = WorldModifierSystem.get_enemy_hp_mult()
			var wm_dmg_mult: float = WorldModifierSystem.get_enemy_damage_mult()
			var wm_speed_mult: float = WorldModifierSystem.get_enemy_speed_mult()
			var wm_scale_mult: float = WorldModifierSystem.get_enemy_scale_mult()
			if wm_hp_mult != 1.0:
				eb.max_hp = int(eb.max_hp * wm_hp_mult)
				eb.hp = eb.max_hp
			if wm_dmg_mult != 1.0:
				eb.damage = int(eb.damage * wm_dmg_mult)
			if wm_speed_mult != 1.0:
				eb.speed *= wm_speed_mult
			if wm_scale_mult != 1.0:
				eb.base_scale *= wm_scale_mult
				# Re-apply the scale tween so the visual matches
				if eb.body_mesh:
					var scale_tween := eb.create_tween()
					scale_tween.tween_property(eb, "scale",
						Vector3.ONE * eb.base_scale, 0.3) \
						.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# ── Phase 33: Enemy Variant System — promote to elite/golden/champion ──
	# Roll after scaling so the variant multipliers stack on top of the
	# already-scaled stats. Skips bosses (handled separately).
	if EnemyVariantSystem:
		EnemyVariantSystem.try_promote_enemy(enemy)

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
	# ── Phase 22: Biome-specific enemy variants for new biomes ──
	# New biomes bias the spawn pool toward thematic enemy types, making
	# each new biome feel distinct in its enemy population.
	var current_biome: int = GameManager.current_biome
	match current_biome:
		GameConstants.Biome.DEEP_OCEAN:
			# Aquatic-themed: gravitons (gravity wells in water), wisps (ghostly),
			# toxic spores (drifting spores in water)
			pool.append(GameConstants.EnemyType.GRAVITON)
			pool.append(GameConstants.EnemyType.WISP)
			pool.append(GameConstants.EnemyType.TOXIC_SPORE)
		GameConstants.Biome.VOLCANO_CORE:
			# Fire-themed: bombers (explosive), plasma stalkers (heat shimmer),
			# swarm mites (heat-agitated insects)
			pool.append(GameConstants.EnemyType.BOMBER)
			pool.append(GameConstants.EnemyType.PLASMA_STALKER)
			pool.append(GameConstants.EnemyType.SWARM_MITE)
		GameConstants.Biome.SKY_CITADEL:
			# Aerial-themed: wisps (floating), crystal guardians (defending the citadel),
			# echo knights (phantom guardians)
			pool.append(GameConstants.EnemyType.WISP)
			pool.append(GameConstants.EnemyType.CRYSTAL_GUARDIAN)
			pool.append(GameConstants.EnemyType.ECHO_KNIGHT)
		GameConstants.Biome.DIGITAL_GRID:
			# Cyber-themed: mirror mimics (copying data), phase shifters (glitching),
			# time wardens (temporal anomalies)
			pool.append(GameConstants.EnemyType.MIRROR_MIMIC)
			pool.append(GameConstants.EnemyType.PHASE_SHIFTER)
			pool.append(GameConstants.EnemyType.TIME_WARDEN)
		GameConstants.Biome.UNDERGROUND:
			# Subterranean: sentinels (stationary guards), crystal wraiths (cave crystals),
			# swarm queens (nest mothers)
			pool.append(GameConstants.EnemyType.SENTINEL)
			pool.append(GameConstants.EnemyType.CRYSTAL_WRAITH)
			pool.append(GameConstants.EnemyType.SWARM_QUEEN)
		GameConstants.Biome.CRYSTAL_CAVERNS:
			# Crystal-themed: crystal wraiths, crystal guardians, echo knights
			pool.append(GameConstants.EnemyType.CRYSTAL_WRAITH)
			pool.append(GameConstants.EnemyType.CRYSTAL_GUARDIAN)
			pool.append(GameConstants.EnemyType.ECHO_KNIGHT)
		GameConstants.Biome.ANCIENT_RUINS:
			# Ancient-themed: sentinels (ancient guardians), time wardens (temporal locks),
			# gravity elementals (ruin magic)
			pool.append(GameConstants.EnemyType.SENTINEL)
			pool.append(GameConstants.EnemyType.TIME_WARDEN)
			pool.append(GameConstants.EnemyType.GRAVITY_ELEMENTAL)
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
			# ── Phase 7: Time-based difficulty scaling — stronger enemies over time ──
			new_hp = int(new_hp * GameManager.get_time_enemy_hp_mult())
			new_dmg = int(new_dmg * GameManager.get_time_enemy_damage_mult())
			# ── Phase 28: Blood Moon weather — enemies empowered ──
			new_hp = int(new_hp * WeatherSystem.get_enemy_hp_multiplier())
			new_dmg = int(new_dmg * WeatherSystem.get_enemy_damage_multiplier())
			# ── Phase 25: Endless Mode — wave-based difficulty escalation ──
			if GameModeManager and GameModeManager.is_endless():
				new_hp = int(new_hp * GameModeManager.get_endless_wave_hp_mult())
				new_dmg = int(new_dmg * GameModeManager.get_endless_wave_damage_mult())
			# ── Phase 34: NG+ / NG++ tier multipliers ──
			if EndgameManager:
				new_hp = int(new_hp * EndgameManager.get_enemy_hp_mult())
				new_dmg = int(new_dmg * EndgameManager.get_enemy_damage_mult())
			# ── Phase 34: Survival mode — tougher enemies ──
			if GameModeManager and GameModeManager.is_survival():
				new_hp = int(new_hp * GameConstants.SURVIVAL_MODE_ENEMY_MULT)
				new_dmg = int(new_dmg * GameConstants.SURVIVAL_MODE_ENEMY_MULT)
			# ── Phase 34: Gauntlet mode — tougher enemies ──
			if GameModeManager and GameModeManager.is_gauntlet():
				new_hp = int(new_hp * GameConstants.GAUNTLET_ENEMY_MULT)
				new_dmg = int(new_dmg * GameConstants.GAUNTLET_ENEMY_MULT)
			enemy.max_hp = new_hp
			enemy.hp = new_hp
			enemy.damage = new_dmg
			if "speed" in enemy:
				enemy.speed *= GameManager.get_time_enemy_speed_mult()
				# ── Phase 28: Blood Moon weather — enemies faster ──
				if WeatherSystem.get_current_weather() == GameConstants.Weather.BLOOD_MOON:
					enemy.speed *= GameConstants.BLOOD_MOON_ENEMY_SPEED_MULT
				# ── Phase 25: Endless Mode — wave-based speed escalation ──
				if GameModeManager and GameModeManager.is_endless():
					enemy.speed *= GameModeManager.get_endless_wave_speed_mult()
				# ── Phase 34: NG+ / NG++ speed multiplier ──
				if EndgameManager:
					enemy.speed *= EndgameManager.get_enemy_speed_mult()

func _reset_spawn_timer() -> void:
	# Base interval decreases with player level
	var level_tiers: int = (GameManager.player_level - 1) / GameConstants.PLAYER_LEVEL_DIFFICULTY_INTERVAL
	var interval: float = max(
		GameConstants.MIN_SPAWN_INTERVAL,
		GameConstants.ENEMY_SPAWN_INTERVAL - level_tiers * GameConstants.ENEMY_SPAWN_INTERVAL_LEVEL_DECAY
	)
	# ── Phase 19: Co-op — 30% faster spawns ──
	interval /= CoOpManager.get_spawn_rate_mult()
	# ── Phase 7: Time-based difficulty — faster spawns over time ──
	interval *= GameManager.get_time_spawn_interval_mult()
	# ── Phase 25: Endless Mode — wave-based spawn acceleration ──
	if GameModeManager and GameModeManager.is_endless():
		interval *= GameModeManager.get_endless_wave_spawn_interval_mult()
	# ── Phase 33: World Modifier System — per-run spawn rate multiplier ──
	# DOUBLE_TROUBLE modifier doubles the spawn rate (halves the interval).
	if WorldModifierSystem and WorldModifierSystem.is_initialized():
		var spawn_mult: float = WorldModifierSystem.get_enemy_spawn_mult()
		if spawn_mult > 0.0:
			interval /= spawn_mult

	# Throttle if too many nearby enemies — reuse the count from _try_spawn's
	# single-pass loop instead of re-iterating the entire enemy group.
	# _last_nearby_count is set every spawn cycle by _try_spawn; if no spawn
	# cycle ran (e.g. first frame), it defaults to 0 which is correct (no
	# throttle). This eliminates a redundant O(n) enemy-group scan per
	# spawn cycle — meaningful when 50+ enemies are active.
	if _last_nearby_count >= GameConstants.SPAWN_DENSITY_NEAR_THRESHOLD:
		interval /= GameConstants.SPAWN_DENSITY_SLOWDOWN  # SLOWER (longer interval)

	spawn_timer = interval