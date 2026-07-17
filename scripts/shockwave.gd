## Zorp Wiggles — Shockwave Ring
## Expanding ring AoE fired by Starburst Sentinel.
## Grows outward, damages player if caught in the ring.

extends Area3D

class_name ShockwaveRing

@export var damage: int = 15
@export var max_radius: float = 8.0
@export var expand_speed: float = 15.0

var current_radius: float = 0.0
var age: float = 0.0
var _material: StandardMaterial3D = null
var _has_hit_player: bool = false

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	# Set up material
	if mesh:
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color(1.0, 200.0 / 255.0, 50.0 / 255.0, 0.6)
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.emission_enabled = true
		_material.emission = Color(1.0, 0.8, 0.2) * 0.5
		mesh.material_override = _material

func _physics_process(delta: float) -> void:
	age += delta
	# Ease-out expansion — fast burst, gentle deceleration. Matches the pulse
	# wave's feel so both expanding-ring effects share a consistent visual
	# language. Feels more energetic than a constant linear growth.
	var progress: float = current_radius / max_radius if max_radius > 0.0 else 0.0
	progress = clampf(progress, 0.0, 1.0)
	var speed_mult: float = 1.0 - 0.6 * progress
	current_radius += expand_speed * speed_mult * delta

	# Scale the shockwave ring
	var ring_scale: float = current_radius / max_radius
	scale = scale.lerp(Vector3.ONE * ring_scale, 1.0 - exp(-12.0 * delta))

	# Check player hit — damage once when ring passes through
	if not _has_hit_player:
		var player: Node3D = get_tree().get_first_node_in_group("player")
		if player and GameManager.player_is_alive:
			var dist: float = global_position.distance_to(player.global_position)
			# Hit when player is near the ring edge
			if abs(dist - current_radius) < 1.0:
				GameManager.take_damage(damage, global_position)
				_has_hit_player = true

	# Fade out as it reaches max radius — quadratic fade for a sharper disappear
	if _material:
		var fade: float = 1.0 - progress
		_material.albedo_color.a = 0.6 * fade * fade

	# Destroy when fully expanded
	if current_radius >= max_radius:
		queue_free()