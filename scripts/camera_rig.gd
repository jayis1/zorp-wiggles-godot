## Zorp Wiggles — Orbit Camera Rig
## Follows the player with adjustable orbit distance and angle.
## Ported from the camera rig logic in Ursina game.py.

extends Node3D

@export var target: NodePath
@export var orbit_distance: float = GameConstants.CAMERA_DISTANCE
@export var orbit_angle: float = GameConstants.CAMERA_ANGLE
@export var rotate_speed: float = GameConstants.CAMERA_ROTATE_SPEED
@export var smooth_factor: float = 8.0

@onready var camera: Camera3D = $Camera3D

var _target_node: Node3D = null

func _ready() -> void:
	if target:
		_target_node = get_node_or_null(target)
	
	# Set initial camera position
	camera.position = Vector3(0, 0, orbit_distance)
	rotation_degrees = Vector3(-orbit_angle, 0, 0)

func _process(delta: float) -> void:
	if not _target_node or not is_instance_valid(_target_node):
		# Try to find player
		_target_node = get_tree().get_first_node_in_group("player")
		if not _target_node:
			return
	
	# Smoothly follow player
	var target_pos := _target_node.global_position
	global_position = global_position.move_toward(Vector3(target_pos.x, 0, target_pos.z), smooth_factor * delta)
	
	# Apply yaw from player input (right-click drag rotates camera)
	# This is handled in player.gd via right-click mouse motion
	rotate_y(deg_to_rad(0))  # Camera yaw is set externally

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