## Zorp Wiggles — Spawn Warning Ring
## Visual warning that appears on the ground before an enemy materializes.
## Expands and pulses, then disappears when the enemy spawns.

extends Node3D

class_name SpawnWarningRing

var age: float = 0.0
var duration: float = 1.2
var _material: StandardMaterial3D = null

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	if mesh:
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color(1.0, 0.3, 0.3, 0.5)
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.emission_enabled = true
		_material.emission = Color(1.0, 0.2, 0.2) * 0.5
		mesh.material_override = _material

func _process(delta: float) -> void:
	age += delta
	# Pulse and expand
	if _material:
		var progress: float = age / duration
		var pulse: float = 0.5 + 0.5 * sin(age * 15.0)
		_material.albedo_color.a = 0.5 * (1.0 - progress) * pulse

	# Scale up slightly
	var s: float = 1.0 + age * 0.5
	scale = Vector3.ONE * s

	if age >= duration:
		queue_free()