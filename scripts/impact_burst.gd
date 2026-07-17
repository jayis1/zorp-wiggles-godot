## Zorp Wiggles — Impact Burst Effect
## Quick expanding + fading sphere that plays on projectile hit.
## Uses a tween for smooth scale-up and fade-out, then queue_free.
## Includes a brief OmniLight3D flash for a punchy real-time hit feel.

extends Node3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

# ─── Shared Resources ──────────────────────────────────────────────────────────
# Impact bursts are spawned on every projectile hit (~9/sec during combat).
# Sharing the mesh and material eliminates per-hit GPU resource allocation.
# The material is duplicated per-instance because the alpha tweens independently.
static var _shared_mesh: SphereMesh = null
static var _shared_material_base: StandardMaterial3D = null

static func _ensure_shared_resources() -> void:
	if _shared_mesh == null:
		_shared_mesh = SphereMesh.new()
		_shared_mesh.radius = 0.2
		_shared_mesh.height = 0.4
		_shared_mesh.radial_segments = 8
		_shared_mesh.rings = 4
	if _shared_material_base == null:
		_shared_material_base = StandardMaterial3D.new()
		_shared_material_base.albedo_color = Color(0.2, 1.0, 0.8, 0.8)
		_shared_material_base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_material_base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shared_material_base.emission_enabled = true
		_shared_material_base.emission = Color(0.2, 1.0, 0.8) * 0.6

var _material: StandardMaterial3D = null
var _light: OmniLight3D = null

func _ready() -> void:
	_ensure_shared_resources()
	if mesh_instance:
		mesh_instance.mesh = _shared_mesh
		# Duplicate the base material so this instance can tween alpha independently
		_material = _shared_material_base.duplicate() as StandardMaterial3D
		mesh_instance.material_override = _material

	# Point light flash — snaps to full intensity, then fades out quickly.
	# This makes hits feel punchy in dark biomes without a full particle system.
	_light = OmniLight3D.new()
	_light.light_color = Color(0.2, 1.0, 0.8)
	_light.light_energy = 2.5
	_light.omni_range = 4.0
	_light.omni_attenuation = 1.2
	add_child(_light)

	# Animate: scale up + fade out, then free
	scale = Vector3.ONE * 0.3
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 2.0, 0.25) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_CUBIC)
	if _material:
		tween.tween_property(_material, "albedo_color:a", 0.0, 0.25) \
			.set_ease(Tween.EASE_IN)
	# Light fades faster than the sphere for a snappy flash
	tween.tween_property(_light, "light_energy", 0.0, 0.12) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(queue_free)