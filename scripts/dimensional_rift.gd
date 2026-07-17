## Zorp Wiggles — Dimensional Rift Portal (Phase 14)
## A swirling vortex portal that appears in the world. When the player
## walks into it, they're transported to an alternate dimension.
## The rift dissolves after its lifetime if not entered, or when entered.

extends Area3D

# ─── Configuration ─────────────────────────────────────────────────────────────
@export var target_dimension: int = GameConstants.Dimension.VOID
@export var lifetime: float = 60.0

# ─── State ────────────────────────────────────────────────────────────────────
var is_expired: bool = false
var _age: float = 0.0
var _pulse_phase: float = 0.0
var _mat: ShaderMaterial = null
var _cached_player: Node3D = null

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var vortex_plane: MeshInstance3D = $VortexPlane if has_node("VortexPlane") else null

func _ready() -> void:
	add_to_group("rifts")
	body_entered.connect(_on_body_entered)

	# Create the vortex visual — a flat cylinder/disc with the vortex shader
	if vortex_plane:
		var disc := CylinderMesh.new()
		disc.top_radius = 0.0
		disc.bottom_radius = 2.0
		disc.height = 0.1
		disc.radial_segments = 48
		disc.rings = 4
		vortex_plane.mesh = disc
		vortex_plane.rotate_x(deg_to_rad(90))  # Lay flat on ground

		# Apply the rift vortex shader
		var shader: Shader = load("res://assets/shaders/rift_vortex.gdshader")
		if shader:
			_mat = ShaderMaterial.new()
			_mat.shader = shader
			var dim_color: Color = GameConstants.DIMENSION_COLORS.get(target_dimension, Color(0.8, 0.9, 1.0))
			_mat.set_shader_parameter("dimension_color", dim_color)
			_mat.set_shader_parameter("strength", 1.0)
			_mat.set_shader_parameter("time_scale", 1.0)
			vortex_plane.material_override = _mat

	# Create a central sphere glow
	if mesh_instance:
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 12
		sphere.rings = 6
		mesh_instance.mesh = sphere

		var mat := StandardMaterial3D.new()
		var dim_color: Color = GameConstants.DIMENSION_COLORS.get(target_dimension, Color(0.8, 0.9, 1.0))
		mat.albedo_color = dim_color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = dim_color
		mat.emission_energy_multiplier = 1.5
		mesh_instance.material_override = mat

	# Add a point light for real-time glow
	var light := OmniLight3D.new()
	light.light_color = GameConstants.DIMENSION_COLORS.get(target_dimension, Color.WHITE)
	light.light_energy = 2.0
	light.omni_range = 8.0
	add_child(light)

	# Start with a spawn animation — scale up from 0
	scale = Vector3.ZERO
	var spawn_tween := create_tween()
	spawn_tween.tween_property(self, "scale", Vector3.ONE, 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

	# Particle effects for materialization
	ParticleEffects.spawn_materialization(get_parent(), global_position,
		GameConstants.DIMENSION_COLORS.get(target_dimension, Color(0.8, 0.9, 1.0)))

func _process(delta: float) -> void:
	if GameManager.is_paused or not GameManager.player_is_alive:
		return

	_age += delta
	_pulse_phase += delta * 3.0

	# Pulsing emission on the central sphere
	if mesh_instance and mesh_instance.material_override is StandardMaterial3D:
		var pulse: float = 0.8 + 0.4 * sin(_pulse_phase)
		(mesh_instance.material_override as StandardMaterial3D).emission_energy_multiplier = pulse

	# Spin the vortex plane
	if vortex_plane:
		vortex_plane.rotate_y(delta * 2.0)

	# Hover effect on the central sphere
	if mesh_instance:
		mesh_instance.position.y = sin(_pulse_phase * 0.7) * 0.3 + 1.0

	# Lifetime countdown
	if _age >= lifetime:
		_dissolve_and_expire()

	# Check proximity for auto-enter (if player gets close enough, enter)
	_check_player_proximity()

func _check_player_proximity() -> void:
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	var player: Node3D = _cached_player
	if not player:
		return

	var dist: float = global_position.distance_to(player.global_position)
	if dist < GameConstants.RIFT_INTERACT_RANGE:
		# Enter the rift!
		DimensionSystem.enter_dimension(target_dimension)
		_dissolve_and_expire()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		DimensionSystem.enter_dimension(target_dimension)
		_dissolve_and_expire()

func _dissolve_and_expire() -> void:
	if is_expired:
		return
	is_expired = true

	# Dissolve animation — scale down + fade
	var dissolve_tween := create_tween()
	dissolve_tween.tween_property(self, "scale", Vector3.ZERO, 0.4) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	dissolve_tween.tween_callback(queue_free)

	# Particle burst on dissolve
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		GameConstants.DIMENSION_COLORS.get(target_dimension, Color.WHITE), 30, 0.6)