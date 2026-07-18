## Zorp Wiggles — Ambient Biome Particles (Phase 6 + Phase 11)
## Spawns continuous ambient particle effects around the player based on the
## current biome: snowflakes (snow), embers (lava), spores (mushroom/swamp),
## bubbles (water), dust (desert), floating pollen (forest), fireflies (grass/alien).
## Uses GPUParticles3D attached to a node that follows the player.
## Phase 11: Added atmosphere particles (dust motes, pollen, fireflies) layered
## on top of the biome weather particles for richer ambient feel.

extends Node3D

# ─── Internal State ───────────────────────────────────────────────────────────
var _current_particles: GPUParticles3D = null
var _atmosphere_particles: GPUParticles3D = null
var _current_biome: int = -1
var _check_timer: float = 0.0
const BIOME_CHECK_INTERVAL: float = 0.5

# ─── Biome → Particle Type Mapping (weather) ──────────────────────────────────
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
	# ── Phase 22: New biome particles ──
	GameConstants.Biome.DEEP_OCEAN: "bubbles",
	GameConstants.Biome.VOLCANO_CORE: "embers",
	GameConstants.Biome.SKY_CITADEL: "dust",
	GameConstants.Biome.DIGITAL_GRID: "spores",
	GameConstants.Biome.CRYSTAL_CAVERNS: "dust",
	GameConstants.Biome.ANCIENT_RUINS: "dust",
	GameConstants.Biome.UNDERGROUND: "spores",
}

# ─── Phase 11: Biome → Atmosphere Particle Type ───────────────────────────────
# Atmosphere particles are subtle, always-on ambient effects that give each
# biome a sense of "air" — floating dust motes, drifting pollen, or glowing
# fireflies. They're separate from the weather particles above.
const BIOME_ATMOSPHERE_MAP: Dictionary = {
	GameConstants.Biome.SNOW: "dust",
	GameConstants.Biome.LAVA: "fireflies",
	GameConstants.Biome.MUSHROOM: "pollen",
	GameConstants.Biome.SWAMP: "pollen",
	GameConstants.Biome.WATER: "dust",
	GameConstants.Biome.DESERT: "dust",
	GameConstants.Biome.FOREST: "pollen",
	GameConstants.Biome.GRASS: "pollen",
	GameConstants.Biome.ALIEN: "fireflies",
	GameConstants.Biome.CRYSTAL: "fireflies",
	GameConstants.Biome.FLOATING_ISLANDS: "dust",
	GameConstants.Biome.TOXIC_BOG: "pollen",
	# ── Phase 22: New biome atmosphere ──
	GameConstants.Biome.DEEP_OCEAN: "fireflies",
	GameConstants.Biome.VOLCANO_CORE: "fireflies",
	GameConstants.Biome.SKY_CITADEL: "dust",
	GameConstants.Biome.DIGITAL_GRID: "fireflies",
	GameConstants.Biome.CRYSTAL_CAVERNS: "fireflies",
	GameConstants.Biome.ANCIENT_RUINS: "dust",
	GameConstants.Biome.UNDERGROUND: "fireflies",
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
	# Remove existing weather particles
	if _current_particles and is_instance_valid(_current_particles):
		_current_particles.queue_free()
		_current_particles = null

	# ── Phase 11: Remove existing atmosphere particles ──
	if _atmosphere_particles and is_instance_valid(_atmosphere_particles):
		_atmosphere_particles.queue_free()
		_atmosphere_particles = null

	var particle_type: String = BIOME_PARTICLE_MAP.get(biome_id, "dust")
	if not particle_type.is_empty():
		# Create new ambient weather particles
		_current_particles = ParticleEffects.create_ambient_particles(Vector3.ZERO, particle_type)
		add_child(_current_particles)
		_current_particles.position = Vector3(0, 0, 0)

	# ── Phase 11: Spawn atmosphere particles (dust motes, pollen, fireflies) ──
	var atmo_type: String = BIOME_ATMOSPHERE_MAP.get(biome_id, "dust")
	if not atmo_type.is_empty():
		_atmosphere_particles = ParticleEffects.spawn_atmosphere(self, Vector3.ZERO, atmo_type)
		# Atmosphere particles follow the AmbientParticles node (which follows the player)