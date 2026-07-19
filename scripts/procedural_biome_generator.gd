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

# ─── Public API ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("procedural_biome_generator")
	call_deferred("_generate_zones")

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

func _process(_delta: float) -> void:
	if _zones.is_empty():
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
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
		_player_in_zone = new_zone
		if new_zone >= 0:
			var z2: Dictionary = _zones[new_zone]
			z2.entered = true
			anomalous_zone_entered.emit(new_zone, z2.traits)
			GameManager.add_message("✦ Entering %s" % z2.name)

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