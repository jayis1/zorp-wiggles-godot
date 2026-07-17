## Zorp Wiggles — Impact Burst Effect
## Quick expanding + fading sphere that plays on projectile hit.
## Uses a tween for smooth scale-up and fade-out, then queue_free.
## Includes a brief OmniLight3D flash for a punchy real-time hit feel.

extends Node3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _material: StandardMaterial3D = null
var _light: OmniLight3D = null

func _ready() -> void:
	if mesh_instance:
		# Create a small sphere mesh
		var sphere := SphereMesh.new()
		sphere.radius = 0.2
		sphere.height = 0.4
		sphere.radial_segments = 8
		sphere.rings = 4
		mesh_instance.mesh = sphere

		_material = StandardMaterial3D.new()
		_material.albedo_color = Color(0.2, 1.0, 0.8, 0.8)
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.emission_enabled = true
		_material.emission = Color(0.2, 1.0, 0.8) * 0.6
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