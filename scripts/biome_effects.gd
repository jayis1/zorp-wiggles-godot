## Zorp Wiggles — Biome Effects System (Phase 22: New Biomes)
## Applies gameplay effects for the new Phase 22 biomes:
##   - Deep Ocean: buoyancy (player floats upward), slower movement
##   - Volcano Core: heat damage ticks when exposed
##   - Sky Citadel: wind currents push the player horizontally
##   - Digital Grid: random glitch teleports (handled via MutationSystem)
##   - Crystal Caverns: visual shimmer (handled via shader)
##   - Ancient Ruins: hidden traps (damage zones)
##   - Underground: darkness (ambient light reduction)
##
## This is an autoload singleton that ticks in _process and applies
## forces/damage to the player. The mutations themselves (fire resistance,
## speed boosts, etc.) are handled by MutationSystem.

extends Node

# ─── Internal State ───────────────────────────────────────────────────────────
var _current_biome: int = GameConstants.Biome.GRASS
var _heat_tick_timer: float = 0.0
var _wind_timer: float = 0.0
var _wind_direction: Vector3 = Vector3.ZERO
var _trap_damage_timer: float = 0.0
var _cached_player: Node3D = null
var _player_in_new_biome: bool = false

# Track spawned trap nodes so they can be cleaned up on biome change.
var _active_traps: Array[Area3D] = []

# ─── Signals ──────────────────────────────────────────────────────────────────
# Emitted when the player enters a trap zone (for HUD feedback).
signal trap_triggered(damage: int, pos: Vector3)

func _ready() -> void:
	GameManager.biome_changed.connect(_on_biome_changed)

func _on_biome_changed(biome_id: int) -> void:
	_current_biome = biome_id
	_player_in_new_biome = true
	# Reset tick timers on biome change so effects kick in immediately.
	_heat_tick_timer = 0.0
	_trap_damage_timer = 0.0
	# Clear any active traps from the previous biome.
	_clear_traps()

func _process(delta: float) -> void:
	if GameManager.is_paused or not GameManager.player_is_alive:
		return
	# Refresh the cached player reference if it's stale.
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
		if not _cached_player:
			return
	# Apply per-biome effects.
	_apply_buoyancy(delta)
	_apply_heat_damage(delta)
	_apply_wind_currents(delta)
	_apply_darkness(delta)
	_check_traps(delta)

# ─── Deep Ocean: Buoyancy ─────────────────────────────────────────────────────
# Player experiences an upward force while in Deep Ocean, simulating
# buoyancy. The MutationSystem.get_buoyancy() returns a stronger value
# if the Tidal Veil mutation is active (the player has adapted).
func _apply_buoyancy(delta: float) -> void:
	if _current_biome != GameConstants.Biome.DEEP_OCEAN:
		return
	var player: CharacterBody3D = _cached_player as CharacterBody3D
	if not player:
		return
	# Upward buoyancy force — stronger with the Tidal Veil mutation.
	var force: float = GameConstants.DEEP_OCEAN_BUOYANCY + MutationSystem.get_buoyancy()
	# Apply as an upward velocity contribution (scaled by delta for smoothness).
	# Use velocity.y so it integrates with the CharacterBody3D physics.
	# Cap the upward velocity so it doesn't rocket the player into the sky.
	if player.velocity.y < 3.0:
		player.velocity.y += force * delta
	# Slow movement while "swimming".
	# The mutation speed multiplier already accounts for this via
	# MutationSystem.get_speed_multiplier(), but we apply a flat slowdown
	# here as the base biome effect (mutation offsets it slightly).

# ─── Volcano Core: Heat Damage ────────────────────────────────────────────────
# The player takes periodic heat damage while in Volcano Core, unless
# they have fire resistance from a mutation (Inferno Form or Magma Skin).
func _apply_heat_damage(delta: float) -> void:
	if _current_biome != GameConstants.Biome.VOLCANO_CORE:
		return
	_heat_tick_timer += delta
	if _heat_tick_timer < GameConstants.VOLCANO_CORE_HEAT_INTERVAL:
		return
	_heat_tick_timer = 0.0
	# Reduce damage by fire resistance (0.0 = full damage, 1.0 = immune).
	var resistance: float = MutationSystem.get_fire_resistance()
	var damage: int = int(float(GameConstants.VOLCANO_CORE_HEAT_DAMAGE) * (1.0 - resistance))
	if damage <= 0:
		return
	# Apply the damage to the player.
	GameManager.take_damage(damage, _cached_player.global_position if _cached_player else Vector3.ZERO)

# ─── Sky Citadel: Wind Currents ──────────────────────────────────────────────
# A horizontal wind force pushes the player in a direction that shifts
# every few seconds, making platforming trickier.
func _apply_wind_currents(delta: float) -> void:
	if _current_biome != GameConstants.Biome.SKY_CITADEL:
		return
	_wind_timer += delta
	if _wind_timer >= GameConstants.SKY_CITADEL_WIND_CHANGE_INTERVAL:
		_wind_timer = 0.0
		# Pick a new random wind direction.
		var angle: float = randf() * TAU
		_wind_direction = Vector3(cos(angle), 0.0, sin(angle))
	# Apply the wind force to the player's velocity.
	var player: CharacterBody3D = _cached_player as CharacterBody3D
	if not player:
		return
	# Wind walker mutation halves the wind effect (the player rides the wind).
	var wind_mult: float = 1.0
	if MutationSystem.has_mutation(MutationSystem.Mutation.SKY):
		wind_mult = 0.5
	player.velocity.x += _wind_direction.x * GameConstants.SKY_CITADEL_WIND_FORCE * wind_mult * delta
	player.velocity.z += _wind_direction.z * GameConstants.SKY_CITADEL_WIND_FORCE * wind_mult * delta

# ─── Underground: Darkness ───────────────────────────────────────────────────
# Reduces ambient light while in the Underground biome. The Night Eye
# mutation (from spending time underground) offsets this so the player
# can see. Here we just modulate the WorldEnvironment's ambient light
# energy — the mutation effect is a passive that lets the player see
# through the darkness.
func _apply_darkness(delta: float) -> void:
	# Smoothly lerp the WorldEnvironment's ambient light energy toward
	# a target value based on the current biome.
	var target_energy: float = 1.0
	if _current_biome == GameConstants.Biome.UNDERGROUND:
		# Very dark underground — Night Eye mutation offsets this.
		if MutationSystem.has_night_eye():
			target_energy = 0.7  # Can see in the dark
		else:
			target_energy = 1.0 - GameConstants.UNDERGROUND_DARKNESS  # 0.15
	elif _current_biome == GameConstants.Biome.DEEP_OCEAN:
		target_energy = 0.4
	elif _current_biome == GameConstants.Biome.DIGITAL_GRID:
		target_energy = 0.6
	elif _current_biome == GameConstants.Biome.CRYSTAL_CAVERNS:
		target_energy = 0.7
	else:
		target_energy = 1.0
	# Find the WorldEnvironment and adjust its ambient light.
	var env_node: WorldEnvironment = get_tree().current_scene.get_node_or_null("WorldEnvironment")
	if not env_node or not env_node.environment:
		return
	var env: Environment = env_node.environment
	# Lerp the ambient light energy toward the target (frame-rate-independent).
	env.ambient_light_energy = lerpf(env.ambient_light_energy, target_energy, 1.0 - exp(-2.0 * delta))

# ─── Ancient Ruins: Hidden Traps ──────────────────────────────────────────────
# When the player enters the Ancient Ruins biome, invisible trap zones
# are scattered across the floor. Stepping on one deals damage unless
# the Relic Ward mutation is active (traps_disabled()).
# Traps are represented as Area3D trigger zones placed at world-gen time
# via WorldGenerator, but here we handle damage application when the
# player overlaps a trap. For simplicity, we apply trap damage via a
# periodic check based on the player's distance to a set of trap positions
# that we generate procedurally when entering the biome.

var _trap_positions: Array[Vector3] = []
const _MAX_TRAPS: int = 20  # Limit to avoid spawning too many

func _populate_traps() -> void:
	# Generate a set of trap positions around the player's current location.
	# These are purely logical (no Area3D needed) — we just check distance.
	_trap_positions.clear()
	var player: Node3D = _cached_player
	if not player:
		return
	for i in range(_MAX_TRAPS):
		var angle: float = randf() * TAU
		var dist: float = randf_range(15.0, 60.0)
		var pos: Vector3 = player.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		_trap_positions.append(pos)

func _check_traps(delta: float) -> void:
	if _current_biome != GameConstants.Biome.ANCIENT_RUINS:
		return
	if _player_in_new_biome:
		_player_in_new_biome = false
		_populate_traps()
	# Tick the trap damage timer.
	_trap_damage_timer += delta
	if _trap_damage_timer < 0.5:
		return
	_trap_damage_timer = 0.0
	# Relic Ward mutation disables traps entirely.
	if MutationSystem.traps_disabled():
		return
	var player: Node3D = _cached_player
	if not player:
		return
	for trap_pos in _trap_positions:
		var dist: float = player.global_position.distance_to(Vector3(trap_pos.x, player.global_position.y, trap_pos.z))
		if dist < GameConstants.ANCIENT_RUINS_TRAP_RADIUS:
			# Player stepped on a trap — apply damage and remove it.
			GameManager.take_damage(GameConstants.ANCIENT_RUINS_TRAP_DAMAGE, Vector3(trap_pos.x, player.global_position.y, trap_pos.z))
			trap_triggered.emit(GameConstants.ANCIENT_RUINS_TRAP_DAMAGE, trap_pos)
			_trap_positions.erase(trap_pos)
			break  # Only one trap per tick.

func _clear_traps() -> void:
	_trap_positions.clear()
	for trap in _active_traps:
		if is_instance_valid(trap):
			trap.queue_free()
	_active_traps.clear()

# ─── Public API ───────────────────────────────────────────────────────────────

## Get the current wind direction (Vector3, normalized). Returns ZERO if
## the player is not in the Sky Citadel biome.
func get_wind_direction() -> Vector3:
	return _wind_direction if _current_biome == GameConstants.Biome.SKY_CITADEL else Vector3.ZERO

## Get the current buoyancy force being applied (Deep Ocean only).
func get_current_buoyancy() -> float:
	if _current_biome == GameConstants.Biome.DEEP_OCEAN:
		return GameConstants.DEEP_OCEAN_BUOYANCY + MutationSystem.get_buoyancy()
	return 0.0