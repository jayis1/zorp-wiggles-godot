## Zorp Wiggles — Impact Burst Effect
## Quick expanding + fading sphere that plays on projectile hit.
## Uses a tween for smooth scale-up and fade-out, then queue_free.

extends Node3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _material: StandardMaterial3D = null

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
	tween.chain().tween_callback(queue_free)