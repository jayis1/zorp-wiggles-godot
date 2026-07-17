## Zorp Wiggles — Ambient Biome Particles (Phase 6: Particle Effects & Juice)
## Spawns continuous ambient particle effects around the player based on the
## current biome: snowflakes (snow), embers (lava), spores (mushroom/swamp),
## bubbles (water), dust (desert), floating pollen (forest), fireflies (grass/alien).
## Uses GPUParticles3D attached to a node that follows the player.

extends Node3D

# ─── Internal State ───────────────────────────────────────────────────────────
var _current_particles: GPUParticles3D = null
var _current_biome: int = -1
var _check_timer: float = 0.0
const BIOME_CHECK_INTERVAL: float = 0.5

# ─── Biome → Particle Type Mapping ────────────────────────────────────────────
const BIOME_PARTICLE_MAP: Dictionary = {
	GameConstants.Biome.SNOW: "snow",
	GameConstants.Biome.LAVA: "embers",
	GameConstants.Biome.MUSHROOM: "spores",
	GameConstants.Biome.SWAMP: "spores",
	GameConstants.Biome.WATER: "bubbles",
	GameConstants.Biome.DESERT: "dust",
	GameConstants.Biome.FOREST: "dust",
	GameConstants.Biome.GRASS: "dust",
	GameConstants.Biome.ALIEN: "spores",
	GameConstants.Biome.CRYSTAL: "dust",
	GameConstants.Biome.FLOATING_ISLANDS: "dust",
	GameConstants.Biome.TOXIC_BOG: "spores",
}

func _ready() -> void:
	# Connect to biome change signal
	GameManager.biome_changed.connect(_on_biome_changed)

func _on_biome_changed(biome_id: int) -> void:
	_current_biome = biome_id
	_spawn_biome_particles(biome_id)

func _process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer <= 0:
		_check_timer = BIOME_CHECK_INTERVAL
		# Follow the player
		var player: Node3D = get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player):
			global_position = player.global_position + Vector3(0, 5, 0)
		# Check biome if not yet set
		if _current_biome == -1:
			_current_biome = GameManager.current_biome
			_spawn_biome_particles(_current_biome)

func _spawn_biome_particles(biome_id: int) -> void:
	# Remove existing particles
	if _current_particles and is_instance_valid(_current_particles):
		_current_particles.queue_free()
		_current_particles = null

	var particle_type: String = BIOME_PARTICLE_MAP.get(biome_id, "dust")
	if particle_type.is_empty():
		return

	# Create new ambient particles
	_current_particles = ParticleEffects.create_ambient_particles(Vector3.ZERO, particle_type)
	add_child(_current_particles)

	# Position the particles around the player area
	_current_particles.position = Vector3(0, 0, 0)