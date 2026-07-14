## Zorp Wiggles — Orbit Camera Rig
## Follows the player with smooth exponential lerp and trauma-based screen shake.
## Ported from the camera rig logic in Ursina game.py.

extends Node3D

@export var target: NodePath
@export var orbit_distance: float = GameConstants.CAMERA_DISTANCE
@export var orbit_angle: float = GameConstants.CAMERA_ANGLE
@export var rotate_speed: float = GameConstants.CAMERA_ROTATE_SPEED

## Smoothing weight (higher = snappier follow). ~5 = smooth, ~15 = tight.
@export var follow_smoothing: float = 6.0

## Screen shake parameters
@export var max_shake_offset: float = 0.6  # Max position offset in meters
@export var max_shake_rotation: float = 4.0  # Max rotation offset in degrees
@export var shake_decay_rate: float = 1.5  # How fast trauma decays (per second)

@onready var camera: Camera3D = $Camera3D

var _target_node: Node3D = null

# ─── Screen Shake (trauma-based) ──────────────────────────────────────────────
var _trauma: float = 0.0  # 0..1, decays over time
var _shake_seed: Vector3 = Vector3.ZERO  # Random seeds for noise

func _ready() -> void:
	if target:
		_target_node = get_node_or_null(target)

	# Set initial camera position
	camera.position = Vector3(0, 0, orbit_distance)
	rotation_degrees = Vector3(-orbit_angle, 0, 0)

	# Random seeds for shake noise
	_shake_seed = Vector3(randf() * 1000.0, randf() * 1000.0, randf() * 1000.0)

func _process(delta: float) -> void:
	if not _target_node or not is_instance_valid(_target_node):
		# Try to find player
		_target_node = get_tree().get_first_node_in_group("player")
		if not _target_node:
			return

	# Smoothly follow player using exponential lerp (frame-rate independent)
	var target_pos := _target_node.global_position
	var desired := Vector3(target_pos.x, 0, target_pos.z)
	var weight: float = 1.0 - exp(-follow_smoothing * delta)
	global_position = global_position.lerp(desired, weight)

	# Apply screen shake offset to the camera child node
	_apply_screen_shake(delta)

func _apply_screen_shake(delta: float) -> void:
	# Decay trauma
	if _trauma > 0.0:
		_trauma = max(0.0, _trauma - shake_decay_rate * delta)

	# Trauma² gives a more organic shake feel (small hits are subtle, big hits punch)
	var shake_amount: float = _trauma * _trauma

	if shake_amount > 0.001:
		# Use time-based pseudo-noise for shake (sin with different frequencies)
		var t: float = Time.get_ticks_msec() * 0.05
		var offset_x: float = sin(t + _shake_seed.x) * max_shake_offset * shake_amount
		var offset_y: float = sin(t * 1.3 + _shake_seed.y) * max_shake_offset * shake_amount
		var rot_z: float = sin(t * 0.9 + _shake_seed.z) * max_shake_rotation * shake_amount

		camera.position.x = offset_x
		camera.position.y = offset_y
		camera.rotation_degrees.z = rot_z
	else:
		# Restore camera local transform (keep forward distance)
		camera.position.x = 0.0
		camera.position.y = 0.0
		camera.rotation_degrees.z = 0.0

## Add screen shake trauma (0..1). Clamps to 1.0. Multiple calls stack additively.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func set_camera_yaw(yaw_deg: float) -> void:
	rotation_degrees.y = yaw_deg

func get_forward_direction() -> Vector3:
	# Return the camera's forward direction on the XZ plane
	var fwd := -camera.global_basis.z
	fwd.y = 0
	return fwd.normalized()

func get_right_direction() -> Vector3:
	var right := camera.global_basis.x
	right.y = 0
	return right.normalized()