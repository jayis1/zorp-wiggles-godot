## Zorp Wiggles — Orbit Camera Rig
## Follows the player with smooth exponential lerp and trauma-based screen shake.
## Ported from the camera rig logic in Ursina game.py.

extends Node3D

@export var target: NodePath
@export var orbit_distance: float = GameConstants.CAMERA_DISTANCE
@export var orbit_angle: float = GameConstants.CAMERA_ANGLE
@export var rotate_speed: float = GameConstants.CAMERA_ROTATE_SPEED

## Vertical follow with a deadzone. On flat terrain the player stays at y≈0.5,
## so a small deadzone (±2m) keeps the camera anchored to the horizon — no
## jitter from minor Y drift. When the player moves significantly vertically
## (reverse-gravity dimension at y=20, or falling back down), the camera
## smoothly follows. This fixes the bug where reverse-gravity placed the
## player at y=20 but the camera stayed pinned at y=0, making the fight
## off-screen.
@export var follow_y_deadzone: float = 2.0   # Horizontal deadzone in meters
@export var follow_y_smoothing: float = 4.0  # Y lerp smoothing (lower = floatier)

## Camera look-ahead offset — the camera target shifts slightly in the
## player's movement direction so the player sees more of what they're
## walking into. Smoothed so it only activates at meaningful speed and
## eases gently when stopping.
@export var look_ahead_strength: float = 3.0  # Max offset in meters
@export var look_ahead_smoothing: float = 4.0  # How fast the offset eases
var _look_ahead_offset: Vector3 = Vector3.ZERO

## Smoothing weight (higher = snappier follow). ~5 = smooth, ~15 = tight.
@export var follow_smoothing: float = 6.0

## Dynamic zoom — camera pulls back smoothly when a boss is active to give the
## player more room to see telegraphed attacks. Distance lerps back to normal
## when the boss is defeated.
@export var boss_zoom_distance: float = 28.0  # Pulled-back distance during boss fights
@export var zoom_smoothing: float = 2.5       # How fast the zoom transitions

## Screen shake parameters
@export var max_shake_offset: float = 0.6  # Max position offset in meters
@export var max_shake_rotation: float = 4.0  # Max rotation offset in degrees
@export var shake_decay_rate: float = 1.5  # How fast trauma decays (per second)

## FOV kick — briefly widens the camera FOV on dash for a speed sensation.
## Classic "juice" technique that makes dashing feel punchy without changing
## gameplay. FOV tweens out then eases back to the default.
@export var dash_fov_kick: float = GameConstants.CAMERA_DASH_FOV_KICK
@export var default_fov: float = GameConstants.CAMERA_DEFAULT_FOV
@export var fov_return_speed: float = GameConstants.CAMERA_FOV_RETURN_SPEED

## Smooth rotation — yaw and pitch ease toward their targets instead of
## snapping instantly. This makes right-click camera dragging feel buttery
## rather than mechanical. Higher = snappier, lower = smoother.
@export var rotation_smoothing: float = 12.0

@onready var camera: Camera3D = $Camera3D

var _target_node: Node3D = null

# ─── Dynamic Zoom ─────────────────────────────────────────────────────────────
var _current_zoom_distance: float = 0.0  # Actual Z offset of the camera
var _target_zoom_distance: float = 0.0   # Desired Z offset (snaps between normal & boss)

# ─── Smooth Rotation ──────────────────────────────────────────────────────────
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0

# ─── Screen Shake (trauma-based) ──────────────────────────────────────────────
var _trauma: float = 0.0  # 0..1, decays over time
var _shake_seed: Vector3 = Vector3.ZERO  # Random seeds for noise

func _ready() -> void:
	if target:
		_target_node = get_node_or_null(target)

	# Set initial camera position
	_current_zoom_distance = orbit_distance
	_target_zoom_distance = orbit_distance
	camera.position = Vector3(0, 0, _current_zoom_distance)
	camera.fov = default_fov
	# Initialize smooth rotation targets to the resting angle
	_target_pitch = -orbit_angle
	_target_yaw = 0.0
	rotation_degrees = Vector3(_target_pitch, _target_yaw, 0)

	# Random seeds for shake noise
	_shake_seed = Vector3(randf() * 1000.0, randf() * 1000.0, randf() * 1000.0)

	# Connect boss signals so the camera automatically zooms out during boss fights.
	# CameraRig is instantiated fresh each scene load, so double-connect can't happen.
	GameManager.boss_spawned.connect(_on_boss_spawned)
	GameManager.boss_defeated.connect(_on_boss_defeated)

func _process(delta: float) -> void:
	if not _target_node or not is_instance_valid(_target_node):
		# Try to find player
		_target_node = get_tree().get_first_node_in_group("player")
		if not _target_node:
			return

	# ── Phase 19: Co-op dual-target mode ──
	# When P2 is active, the camera targets the midpoint between both players
	# and dynamically zooms out based on their spacing so both stay on-screen.
	var coop_active: bool = CoOpManager.is_coop_active()
	var target_pos: Vector3
	if coop_active:
		# Use midpoint between P1 and P2
		var p2_node: CharacterBody3D = CoOpManager.p2_node
		target_pos = (_target_node.global_position + p2_node.global_position) * 0.5
		# Dynamic zoom based on player spacing
		var spacing: float = _target_node.global_position.distance_to(p2_node.global_position)
		var zoom_frac: float = clampf(spacing / GameConstants.COOP_CAMERA_PLAYER_SPACING_THRESH, 0.0, 1.0)
		_target_zoom_distance = lerpf(
			GameConstants.COOP_CAMERA_MIN_DISTANCE,
			GameConstants.COOP_CAMERA_MAX_DISTANCE,
			zoom_frac
		)
	else:
		target_pos = _target_node.global_position
		# ── Boss zoom takes priority over normal (non-coop) distance ──
		# (Co-op zoom is handled in the coop_active branch above, and boss
		#  zoom doesn't override co-op since co-op needs to see both players)
	# ── Look-ahead: shift the follow target in the player's velocity direction
	# so the camera leads slightly, giving the player more forward visibility.
	# Only uses horizontal velocity (no Y drift from gravity/reverse-gravity).
	# The offset is smoothed so it ramps up when moving and eases to zero when
	# standing still.
	var player_vel := Vector3.ZERO
	if _target_node is CharacterBody3D:
		player_vel = (_target_node as CharacterBody3D).velocity
	var horiz_vel := Vector2(player_vel.x, player_vel.z)
	var speed_frac: float = clampf(horiz_vel.length() / GameConstants.PLAYER_SPEED, 0.0, 1.0)
	var desired_lookahead := Vector3.ZERO
	if horiz_vel.length() > 0.1:
		desired_lookahead = Vector3(player_vel.x, 0, player_vel.z).normalized() * look_ahead_strength * speed_frac
	var la_weight: float = 1.0 - exp(-look_ahead_smoothing * delta)
	_look_ahead_offset = _look_ahead_offset.lerp(desired_lookahead, la_weight)
	target_pos += _look_ahead_offset
	var weight: float = 1.0 - exp(-follow_smoothing * delta)
	# Horizontal follow (XZ) — always tracks the player
	var new_x: float = lerpf(global_position.x, target_pos.x, weight)
	var new_z: float = lerpf(global_position.z, target_pos.z, weight)
	# Vertical follow with deadzone — only move Y when the player exits the
	# deadzone band around the camera's current Y. This keeps the camera
	# horizon-stable on flat ground while still tracking large vertical
	# excursions (reverse-gravity dimension, falls, bounce pads).
	var new_y: float = global_position.y
	var y_diff: float = target_pos.y - global_position.y
	if abs(y_diff) > follow_y_deadzone:
		var y_weight: float = 1.0 - exp(-follow_y_smoothing * delta)
		new_y = lerpf(global_position.y, target_pos.y, y_weight)
	global_position = Vector3(new_x, new_y, new_z)

	# ── Dynamic zoom: smoothly lerp the camera's local Z toward the target distance
	var zoom_weight: float = 1.0 - exp(-zoom_smoothing * delta)
	_current_zoom_distance = lerpf(_current_zoom_distance, _target_zoom_distance, zoom_weight)

	# Apply screen shake offset to the camera child node (shake layers on top of zoom)
	_apply_screen_shake(delta)

	# ── Smooth rotation: ease yaw and pitch toward their targets ──
	# This makes right-click camera dragging feel buttery instead of snapping.
	# The shake system writes to camera.rotation_degrees.z separately, so we
	# only touch the rig's own x/y rotation here.
	var rot_weight: float = 1.0 - exp(-rotation_smoothing * delta)
	rotation_degrees.x = lerpf(rotation_degrees.x, _target_pitch, rot_weight)
	rotation_degrees.y = lerpf(rotation_degrees.y, _target_yaw, rot_weight)

	# Smoothly return FOV to default (the dash kick sets it above default, then
	# this eases it back for a natural "settle" feel).
	if abs(camera.fov - default_fov) > 0.01:
		var fov_weight: float = 1.0 - exp(-fov_return_speed * delta)
		camera.fov = lerpf(camera.fov, default_fov, fov_weight)

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
		camera.position.z = _current_zoom_distance  # Preserve zoom distance
		camera.rotation_degrees.z = rot_z
	else:
		# Restore camera local transform (keep zoom distance)
		camera.position.x = 0.0
		camera.position.y = 0.0
		camera.position.z = _current_zoom_distance
		camera.rotation_degrees.z = 0.0

## Add screen shake trauma (0..1). Clamps to 1.0. Multiple calls stack additively.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

## Kick the camera FOV up by `kick_amount` degrees for a speed sensation.
## Called on dash. The FOV then eases back to `default_fov` in _process.
func kick_fov(kick_amount: float) -> void:
	camera.fov = default_fov + kick_amount

func set_camera_yaw(yaw_deg: float) -> void:
	# Set the target yaw — _process eases the actual rotation toward this.
	_target_yaw = yaw_deg

## Set the target pitch (X rotation in degrees). Eased in _process.
func set_camera_pitch(pitch_deg: float) -> void:
	_target_pitch = pitch_deg

func get_forward_direction() -> Vector3:
	# Return the camera's forward direction on the XZ plane
	var fwd := -camera.global_basis.z
	fwd.y = 0
	return fwd.normalized()

func get_right_direction() -> Vector3:
	var right := camera.global_basis.x
	right.y = 0
	return right.normalized()

# ─── Dynamic Boss Zoom ────────────────────────────────────────────────────────
# When a boss spawns, smoothly pull the camera back so the player can see more
# of the arena and react to telegraphed attacks. When the boss dies, return to
# the normal orbit distance. Uses the same exponential-lerp smoothing as the
# follow logic for a seamless, frame-rate-independent transition.

func _on_boss_spawned(_boss: Node) -> void:
	_target_zoom_distance = boss_zoom_distance

func _on_boss_defeated(_boss: Node) -> void:
	_target_zoom_distance = orbit_distance