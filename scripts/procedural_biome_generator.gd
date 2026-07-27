## Zorp Wiggles — Procedural Biome Generator (Phase 33)
## Beyond the 19 fixed biomes, this generator synthesizes rare "anomalous
## zones" — small regions with a unique combination of visual traits (glowing,
## crystal shards, toxic haze, etc.) and gameplay effects. These appear as
## distinctive pockets in the world and give late-game players something new
## to discover.
##
## The generator is a pure data planner — it produces zone definitions that
## the world generator / biome effects / weather / HUD can query. Visual
## decoration is overlaid on top of the underlying biome without changing
## the terrain mesh itself (keeping the world-gen pipeline intact).
##
## All colors use Godot 0-1 range.

extends Node

class_name ProcBiomeGen

# ─── Signals ────────────────────────────────────────────────────────────────────
signal anomalous_zone_entered(zone_id: int, traits: Array)
signal anomalous_zone_left(zone_id: int)

# ─── Zone Definition ───────────────────────────────────────────────────────────
# Each zone is a Dictionary:
#   {id, center, radius, base_biome, traits, name, entered}
var _zones: Array[Dictionary] = []
var _player_in_zone: int = -1
var _rng := RandomNumberGenerator.new()

# ─── Trait effect tick timers ──────────────────────────────────────────────────
var _toxic_haze_timer: float = 0.0
var _magma_timer: float = 0.0
var _cached_player: Node3D = null

# ─── Public API ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("procedural_biome_generator")
	call_deferred("_generate_zones")
	# Clean up particles on game restart.
	if GameManager and not GameManager.game_restarted.is_connected(_on_game_restarted):
		GameManager.game_restarted.connect(_on_game_restarted)
	# Also clean up on player death.
	if GameManager and not GameManager.player_died.is_connected(_on_player_died):
		GameManager.player_died.connect(_on_player_died)

func _on_player_died() -> void:
	_clear_rain_indoor()
	# Restore music pitch in case we were in an Echo Chamber zone.
	if AudioManager and AudioManager._music_player:
		AudioManager._music_player.pitch_scale = 1.0

func _on_game_restarted() -> void:
	_clear_rain_indoor()
	_player_in_zone = -1
	_toxic_haze_timer = 0.0
	_magma_timer = 0.0
	_crystal_shard_timer = 0.0
	# Restore music pitch in case we were in an Echo Chamber zone.
	if AudioManager and AudioManager._music_player:
		AudioManager._music_player.pitch_scale = 1.0

func get_zones() -> Array[Dictionary]:
	return _zones

func get_active_zone() -> Dictionary:
	if _player_in_zone < 0 or _player_in_zone >= _zones.size():
		return {}
	return _zones[_player_in_zone]

func is_in_anomalous_zone() -> bool:
	return _player_in_zone >= 0

# ─── Generation ──────────────────────────────────────────────────────────────────

func _generate_zones() -> void:
	# Seeded by world seed for deterministic anomalous zones.
	var seed_val: int = GameManager.world_seed if GameManager else randi()
	_rng.seed = seed_val
	# Generate ~5-8 anomalous zones across the world.
	var count: int = _rng.randi_range(5, 8)
	for i in count:
		var extent: float = GameConstants.WORLD_EXTENT * 0.85
		var center := Vector3(
			_rng.randf_range(-extent, extent),
			0.0,
			_rng.randf_range(-extent, extent)
		)
		var traits := _pick_traits()
		var zone := {
			"id": i,
			"center": center,
			"radius": GameConstants.PROC_BIOME_RADIUS * _rng.randf_range(0.8, 1.3),
			"traits": traits,
			"name": _generate_name(traits),
			"entered": false,
		}
		_zones.append(zone)
	print("[ProcBiome] Generated %d anomalous zones" % _zones.size())

func _pick_traits() -> Array:
	# Pick PROC_BIOME_TRAIT_COUNT unique traits from the pool.
	var pool: Array[int] = []
	for i in GameConstants.ProcBiomeTrait.size():
		pool.append(i)
	pool.shuffle()
	var chosen: Array = []
	for i in GameConstants.PROC_BIOME_TRAIT_COUNT:
		chosen.append(pool[i])
	return chosen

func _generate_name(traits: Array) -> String:
	# Name from the dominant trait.
	var first: int = traits[0]
	var trait_name: String = GameConstants.PROC_BIOME_TRAIT_NAMES[first]
	return "Anomalous %s Zone" % trait_name

# ─── Per-Frame Player Check ─────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _zones.is_empty():
		return
	# Refresh cached player reference if stale.
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
		if not _cached_player:
			return
	var player: Node3D = _cached_player
	if not player or not is_instance_valid(player):
		return
	var ppos: Vector3 = player.global_position
	var new_zone: int = -1
	for i in _zones.size():
		var zone: Dictionary = _zones[i]
		var dist: float = Vector2(ppos.x, ppos.z).distance_to(
			Vector2(zone.center.x, zone.center.z)
		)
		if dist <= zone.radius:
			new_zone = i
			break
	if new_zone != _player_in_zone:
		if _player_in_zone >= 0:
			anomalous_zone_left.emit(_player_in_zone)
			var z: Dictionary = _zones[_player_in_zone]
			z.entered = false
			# Restore music pitch if we were in an Echo Chamber zone.
			if AudioManager and AudioManager._music_player:
				var old_zone: Dictionary = _zones[_player_in_zone]
				if GameConstants.ProcBiomeTrait.ECHO_CHAMBER in old_zone.traits:
					AudioManager._music_player.pitch_scale = 1.0
		_player_in_zone = new_zone
		if new_zone >= 0:
			var z2: Dictionary = _zones[new_zone]
			z2.entered = true
			anomalous_zone_entered.emit(new_zone, z2.traits)
			GameManager.add_message("✦ Entering %s" % z2.name)
			# Audio + camera juice for zone entry — a distinctive chime + shake.
			if AudioManager:
				AudioManager.play_sfx(AudioManager.SFX_MUTATION)
			var cam_rig: Node3D = GameManager.camera_rig
			if cam_rig and cam_rig.has_method("add_trauma"):
				cam_rig.add_trauma(0.15)
			# Reset trait tick timers on zone entry.
			_toxic_haze_timer = 0.0
			_magma_timer = 0.0
	# Tick active trait effects every frame while inside a zone.
	if _player_in_zone >= 0:
		_tick_trait_effects(delta, player)

# ─── Trait Effect Queries ──────────────────────────────────────────────────────

func get_glowing_mult() -> float:
	# Emissive terrain boost when in a zone with the GLOWING trait.
	if _player_in_zone < 0:
		return 1.0
	var zone: Dictionary = _zones[_player_in_zone]
	if GameConstants.ProcBiomeTrait.GLOWING in zone.traits:
		return 1.8
	return 1.0

func get_toxic_haze_active() -> bool:
	if _player_in_zone < 0:
		return false
	var zone: Dictionary = _zones[_player_in_zone]
	return GameConstants.ProcBiomeTrait.TOXIC_HAZE in zone.traits

func get_gravity_well_active() -> bool:
	if _player_in_zone < 0:
		return false
	var zone: Dictionary = _zones[_player_in_zone]
	return GameConstants.ProcBiomeTrait.GRAVITY_WELL in zone.traits

func get_echo_chamber_active() -> bool:
	if _player_in_zone < 0:
		return false
	var zone: Dictionary = _zones[_player_in_zone]
	return GameConstants.ProcBiomeTrait.ECHO_CHAMBER in zone.traits

func get_magma_fissures_active() -> bool:
	if _player_in_zone < 0:
		return false
	var zone: Dictionary = _zones[_player_in_zone]
	return GameConstants.ProcBiomeTrait.MAGMA_FISSURES in zone.traits

# ─── Trait Effect Ticking ─────────────────────────────────────────────────────
# Applies per-frame gameplay effects for active anomalous zone traits.
# Previously these trait query functions existed but nothing called them —
# the anomalous zones were purely cosmetic. Now they have real gameplay impact.

func _tick_trait_effects(delta: float, player: Node3D) -> void:
	if GameManager.is_paused or not GameManager.player_is_alive:
		return
	_tick_toxic_haze(delta)
	_tick_magma_fissures(delta)
	_tick_gravity_well(delta, player)
	_tick_glowing(delta)
	_tick_echo_chamber(delta)
	_tick_crystal_shard(delta, player)
	_tick_mirror_surface(delta, player)
	_tick_rain_indoor(delta, player)

# Toxic Haze: periodic poison damage to the player (reduced by fire resistance
# since it's a gas — the Inferno Form / Magma Skin mutations burn off spores).
func _tick_toxic_haze(delta: float) -> void:
	if not get_toxic_haze_active():
		return
	_toxic_haze_timer += delta
	if _toxic_haze_timer < GameConstants.PROC_BIOME_TOXIC_HAZE_INTERVAL:
		return
	_toxic_haze_timer = 0.0
	var resistance: float = MutationSystem.get_fire_resistance()
	var damage: int = int(float(GameConstants.PROC_BIOME_TOXIC_HAZE_DAMAGE) * (1.0 - resistance * 0.5))
	if damage <= 0:
		return
	GameManager.take_damage(damage, _cached_player.global_position if _cached_player else Vector3.ZERO)

# Magma Fissures: periodic heat damage (reduced by fire resistance).
func _tick_magma_fissures(delta: float) -> void:
	if not get_magma_fissures_active():
		return
	_magma_timer += delta
	if _magma_timer < GameConstants.PROC_BIOME_MAGMA_INTERVAL:
		return
	_magma_timer = 0.0
	var resistance: float = MutationSystem.get_fire_resistance()
	var damage: int = int(float(GameConstants.PROC_BIOME_MAGMA_DAMAGE) * (1.0 - resistance))
	if damage <= 0:
		return
	GameManager.take_damage(damage, _cached_player.global_position if _cached_player else Vector3.ZERO)

# Gravity Well: pulls the player toward the zone center with a gentle force.
func _tick_gravity_well(delta: float, player: Node3D) -> void:
	if not get_gravity_well_active():
		return
	if _player_in_zone < 0:
		return
	var zone: Dictionary = _zones[_player_in_zone]
	var center: Vector3 = Vector3(zone.center.x, player.global_position.y, zone.center.z)
	var to_center: Vector3 = (center - player.global_position)
	var dist: float = to_center.length()
	if dist < 1.0:
		return  # Already at center, no pull needed.
	to_center = to_center.normalized()
	# Pull strength scales with proximity (stronger near the edge, weaker at center).
	var strength: float = GameConstants.PROC_BIOME_GRAVITY_WELL_FORCE * (dist / float(zone.radius))
	var cb: CharacterBody3D = player as CharacterBody3D
	if cb:
		cb.velocity.x += to_center.x * strength * delta
		cb.velocity.z += to_center.z * strength * delta

# Glowing: boosts ambient light energy while in the zone (visual buff).
func _tick_glowing(_delta: float) -> void:
	if _player_in_zone < 0:
		return
	var zone: Dictionary = _zones[_player_in_zone]
	if not (GameConstants.ProcBiomeTrait.GLOWING in zone.traits):
		return
	# Boost the WorldEnvironment ambient light energy for better visibility.
	var env_node: WorldEnvironment = get_tree().current_scene.get_node_or_null("WorldEnvironment")
	if not env_node or not env_node.environment:
		return
	var env: Environment = env_node.environment
	var target: float = 1.0 + GameConstants.PROC_BIOME_GLOWING_LIGHT_BOOST
	# Only boost if the current energy is below the target (don't fight darkness mutations).
	if env.ambient_light_energy < target:
		env.ambient_light_energy = lerpf(env.ambient_light_energy, target, 1.0 - exp(-3.0 * _delta))

# Echo Chamber: subtle audio pitch modulation while in the zone.
func _tick_echo_chamber(_delta: float) -> void:
	if not get_echo_chamber_active():
		return
	# Apply a subtle pitch shift to the ambient music player.
	if not AudioManager:
		return
	var pitch_target: float = GameConstants.PROC_BIOME_ECHO_CHAMBER_PITCH
	# AudioManager handles music pitch via its _music_player — we nudge it.
	if AudioManager._music_player:
		var mp: AudioStreamPlayer = AudioManager._music_player
		mp.pitch_scale = lerpf(mp.pitch_scale, pitch_target, 1.0 - exp(-2.0 * _delta))

# Crystal Shard: occasional sparkle particles + bonus loot chance query.
# The loot bonus is queried by enemy_base.gd via get_crystal_shard_loot_bonus().
var _crystal_shard_timer: float = 0.0

func _tick_crystal_shard(delta: float, player: Node3D) -> void:
	if _player_in_zone < 0:
		return
	var zone: Dictionary = _zones[_player_in_zone]
	if not (GameConstants.ProcBiomeTrait.CRYSTAL_SHARD in zone.traits):
		return
	# Spawn periodic sparkle particles around the player.
	_crystal_shard_timer += delta
	if _crystal_shard_timer < 0.8:
		return
	_crystal_shard_timer = 0.0
	# ParticleEffects uses static methods (class_name, not an autoload),
	# so we call spawn_pickup_sparkle directly — no has_method check needed
	# (the method always exists on the class).
	var parent: Node = player.get_parent()
	if parent:
		ParticleEffects.spawn_pickup_sparkle(parent, player.global_position + Vector3(randf_range(-3, 3), 1, randf_range(-3, 3)), GameConstants.PROC_BIOME_TRAIT_COLORS[1])

func get_crystal_shard_loot_bonus() -> float:
	if _player_in_zone < 0:
		return 0.0
	var zone: Dictionary = _zones[_player_in_zone]
	if GameConstants.ProcBiomeTrait.CRYSTAL_SHARD in zone.traits:
		return 0.25  # +25% loot chance in crystal shard zones
	return 0.0

# Mirror Surface: reverses the player's horizontal movement controls.
# The player query function is_mirror_surface_active() is checked in player.gd.
func _tick_mirror_surface(_delta: float, _player: Node3D) -> void:
	# No per-frame ticking needed — the player reads is_mirror_surface_active()
	# each frame and reverses input direction. This function exists for future
	# visual effects (e.g. reflective floor shader).
	pass

func is_mirror_surface_active() -> bool:
	if _player_in_zone < 0:
		return false
	var zone: Dictionary = _zones[_player_in_zone]
	return GameConstants.ProcBiomeTrait.MIRROR_SURFACE in zone.traits

# Rain Indoor: spawns ambient rain particles within the zone.
var _rain_indoor_particles: GPUParticles3D = null

func _tick_rain_indoor(_delta: float, player: Node3D) -> void:
	if _player_in_zone < 0:
		_clear_rain_indoor()
		return
	var zone: Dictionary = _zones[_player_in_zone]
	if not (GameConstants.ProcBiomeTrait.RAIN_INDOOR in zone.traits):
		_clear_rain_indoor()
		return
	# Spawn rain particles following the player if not already active.
	if _rain_indoor_particles and is_instance_valid(_rain_indoor_particles):
		_rain_indoor_particles.global_position = player.global_position + Vector3(0, 15, 0)
	else:
		_create_rain_indoor_particles(player)

func _create_rain_indoor_particles(player: Node3D) -> void:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = 200
	p.lifetime = 1.5
	p.explosiveness = 0.0
	p.randomness = 1.0
	# Rain-like downward particles.
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 10.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 25.0
	mat.gravity = Vector3(0, -5, 0)
	mat.color = Color(0.4, 0.6, 1.0, 0.6)
	mat.scale_min = 0.02
	mat.scale_max = 0.05
	p.process_material = mat
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	p.draw_pass_1 = mesh
	p.global_position = player.global_position + Vector3(0, 15, 0)
	# Add to the player's parent so it's in the scene tree.
	var parent: Node = player.get_parent()
	if parent:
		parent.add_child(p)
		_rain_indoor_particles = p

func _clear_rain_indoor() -> void:
	if _rain_indoor_particles and is_instance_valid(_rain_indoor_particles):
		_rain_indoor_particles.queue_free()
		_rain_indoor_particles = null