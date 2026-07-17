## Zorp Wiggles — Shockwave Ring
## Expanding ring AoE fired by Starburst Sentinel.
## Grows outward, damages player if caught in the ring.
## Polished: correct radius scaling, center light flash, shared resources.

extends Area3D

class_name ShockwaveRing

@export var damage: int = 15
@export var max_radius: float = 8.0
@export var expand_speed: float = 15.0

var current_radius: float = 0.0
var age: float = 0.0
var _material: StandardMaterial3D = null
var _has_hit_player: bool = false
var _light: OmniLight3D = null

@onready var mesh: MeshInstance3D = $MeshInstance3D

# ─── Shared Resources ──────────────────────────────────────────────────────────
# Shockwaves are fired repeatedly by Sentinels. Share the mesh geometry
# to avoid per-shot allocation. Material is per-instance (alpha/emission tween).
static var _shared_mesh: CylinderMesh = null

static func _ensure_shared_mesh() -> void:
	if _shared_mesh == null:
		_shared_mesh = CylinderMesh.new()
		# Base radius of 0.5m — the ring is then scaled by current_radius / 0.5
		# to reach the actual desired radius. This gives a smooth, visible ring
		# at all sizes without changing the mesh.
		_shared_mesh.top_radius = 0.5
		_shared_mesh.bottom_radius = 0.5
		_shared_mesh.height = 0.1
		_shared_mesh.radial_segments = 24
		_shared_mesh.rings = 2

## The base mesh radius — used to compute the correct scale factor.
const _BASE_MESH_RADIUS: float = 0.5

func _ready() -> void:
	# Set up material
	if mesh:
		_ensure_shared_mesh()
		mesh.mesh = _shared_mesh
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color(1.0, 200.0 / 255.0, 50.0 / 255.0, 0.6)
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.emission_enabled = true
		_material.emission = Color(1.0, 0.8, 0.2) * 0.5
		_material.emission_energy_multiplier = 1.5
		mesh.material_override = _material

	# Center light flash — illuminates the Sentinel's area as the shockwave
	# fires, fading as the ring expands. Matches the pulse wave's light flash
	# for a consistent shockwave visual language.
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.8, 0.2)
	_light.light_energy = 2.5
	_light.omni_range = 6.0
	_light.omni_attenuation = 1.5
	add_child(_light)

func _physics_process(delta: float) -> void:
	age += delta
	# Ease-out expansion — fast burst, gentle deceleration. Matches the pulse
	# wave's feel so both expanding-ring effects share a consistent visual
	# language. Feels more energetic than a constant linear growth.
	var progress: float = current_radius / max_radius if max_radius > 0.0 else 0.0
	progress = clampf(progress, 0.0, 1.0)
	var speed_mult: float = 1.0 - 0.6 * progress
	current_radius += expand_speed * speed_mult * delta

	# Scale the shockwave ring to the actual current radius.
	# The base mesh has radius 0.5m, so we scale by current_radius / 0.5
	# to reach the desired physical size. Previously this scaled by the
	# ratio (0→1), making the ring only 0.5m at max — nearly invisible.
	var ring_scale: float = current_radius / _BASE_MESH_RADIUS
	# CylinderMesh axis is along Y; radius is in the XZ plane.
	# Scale X and Z to expand the ring radius; keep Y (thickness) at 1.
	var target_scale := Vector3(ring_scale, 1.0, ring_scale)
	scale = scale.lerp(target_scale, 1.0 - exp(-12.0 * delta))

	# Check player hit — damage once when ring passes through
	# In co-op, check both players — the ring can hit either one
	if not _has_hit_player:
		var player: Node3D = get_tree().get_first_node_in_group("player")
		if player and GameManager.player_is_alive and not GameManager.player_is_downed:
			var dist: float = global_position.distance_to(player.global_position)
			# Hit when player is near the ring edge
			if abs(dist - current_radius) < 1.0:
				GameManager.take_damage(damage, global_position)
				_has_hit_player = true
		# ── Phase 19: Co-op — check P2 ──
		if not _has_hit_player and CoOpManager.is_coop_active() and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
			if not CoOpManager.p2_is_downed:
				var p2_dist: float = global_position.distance_to(CoOpManager.p2_node.global_position)
				if abs(p2_dist - current_radius) < 1.0:
					CoOpManager.p2_take_damage(damage, global_position)
					_has_hit_player = true

	# Fade out as it reaches max radius — quadratic fade for a sharper disappear
	var fade: float = 1.0 - progress
	if _material:
		_material.albedo_color.a = 0.6 * fade * fade
		# Emission fades alongside alpha for a coherent dissipating glow
		_material.emission_energy_multiplier = 1.5 * fade * fade

	# Fade the center light as the ring expands (punchy flash → off)
	if _light:
		_light.light_energy = 2.5 * fade

	# Destroy when fully expanded
	if current_radius >= max_radius:
		queue_free()