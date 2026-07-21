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

## ── Low-HP tension zoom ── When the player's HP drops below the threshold,
## the camera subtly zooms in (reduces orbit distance) to frame Zorp tighter
## and heighten the sense of danger. This pairs with the player's heartbeat
## pulse and the red damage vignette — the camera itself communicates "you
## are in trouble" by pulling closer, the way a horror film tightens on the
## protagonist in peril. The zoom is SMALL (~2.5m closer at full danger) so
## it doesn't hurt visibility — the player still sees incoming threats.
## Priority: co-op dynamic zoom > boss zoom > low-HP zoom > normal orbit.
## The low-HP zoom only affects the non-co-op, non-boss path so it never
## fights the existing dynamic zoom systems.
@export var low_hp_zoom_threshold: float = 0.25   # HP ratio below which tension zoom engages
@export var low_hp_zoom_distance: float = 14.0    # Pulled-in distance during critical HP (vs ~20 default)
@export var low_hp_zoom_smoothing: float = 2.0    # How fast the tension zoom eases in/out
var _low_hp_zoom_active: bool = false

## Dynamic speed FOV — the camera FOV subtly widens as the player moves faster,
## giving a sense of momentum and acceleration (the Doom/Sunset Overdrive trick).
## The effect is capped at speed_fov_max degrees above default and only engages
## when the player is above the speed threshold, so standing still and slow
## walking read as calm while sprinting feels expansive. The target is eased
## frame-rate-independently so the FOV "breathes" with the player's speed
## rather than snapping. Dash's FOV kick stacks on top (it writes directly to
## camera.fov), and this system only nudges the eased return target so the
## dash pop still punches and the speed FOV settles in underneath it.
@export var speed_fov_max: float = 3.5          # Max degrees added at full speed
@export var speed_fov_threshold: float = 8.0   # Speed (m/s) where FOV starts widening
@export var speed_fov_smoothing: float = 3.0   # How fast the speed FOV eases
var _speed_fov_current: float = 0.0            # Current speed-FOV offset (eased)

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

# ── Directional shake bias ── When trauma is added with a direction (e.g. from
#    a hit on the player's left), the shake offset is biased slightly toward
#    that direction. This makes impacts feel directional — a hit from the right
#    pushes the camera right, reinforcing the damage direction indicator.
#    The bias decays with trauma so the shake returns to centered noise.
var _shake_bias_dir: Vector3 = Vector3.ZERO  # Normalized horizontal direction
var _shake_bias_strength: float = 0.0        # 0..1, how much bias to apply

func _ready() -> void:
	# Add to "camera_rig" group so PhotoMode can find and pause the rig
	add_to_group("camera_rig")
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
		# ── Low-HP tension zoom ── Below boss zoom priority but above the
		# normal orbit distance, the camera pulls in slightly when the
		# player is in critical HP. This only runs in the non-co-op, non-
		# boss path — if a boss is active (_target_zoom_distance already
		# set to boss_zoom_distance by _on_boss_spawned), the boss zoom
		# wins so the player can still see the telegraphed attacks. We
		# detect "boss active" by comparing _target_zoom_distance to
		# boss_zoom_distance (set on spawn, restored on defeat). This
		# avoids needing a separate boss-active flag.
		var boss_zoom_active: bool = absf(_target_zoom_distance - boss_zoom_distance) < 0.01
		if not boss_zoom_active:
			var hp_ratio: float = float(GameManager.player_hp) / float(GameManager.player_max_hp) \
				if GameManager.player_max_hp > 0 else 1.0
			var should_be_active: bool = hp_ratio > 0.0 and hp_ratio <= low_hp_zoom_threshold
			if should_be_active != _low_hp_zoom_active:
				_low_hp_zoom_active = should_be_active
				_target_zoom_distance = low_hp_zoom_distance if _low_hp_zoom_active else orbit_distance
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
	# this eases it back for a natural "settle" feel). The speed-FOV offset is
	# added on top of default_fov so the eased target becomes
	# default_fov + _speed_fov_current — the dash pop still punches because it
	# writes directly to camera.fov, and this lerp chases the speed-adjusted
	# baseline underneath it.
	var speed_fov_target: float = 0.0
	if _target_node and is_instance_valid(_target_node):
		var spd: float = 0.0
		if _target_node is CharacterBody3D:
			var v := (_target_node as CharacterBody3D).velocity
			spd = Vector2(v.x, v.z).length()
		# Map speed → FOV offset with a smoothstep so the onset is gentle
		if spd > speed_fov_threshold:
			var t: float = clampf((spd - speed_fov_threshold) / (GameConstants.PLAYER_SPEED - speed_fov_threshold), 0.0, 1.0)
			# Smoothstep for a soft S-curve (ease-in then ease-out)
			t = t * t * (3.0 - 2.0 * t)
			speed_fov_target = t * speed_fov_max
	var sf_weight: float = 1.0 - exp(-speed_fov_smoothing * delta)
	_speed_fov_current = lerpf(_speed_fov_current, speed_fov_target, sf_weight)
	var fov_baseline: float = default_fov + _speed_fov_current
	if abs(camera.fov - fov_baseline) > 0.01:
		var fov_weight: float = 1.0 - exp(-fov_return_speed * delta)
		camera.fov = lerpf(camera.fov, fov_baseline, fov_weight)

func _apply_screen_shake(delta: float) -> void:
	# Decay trauma
	if _trauma > 0.0:
		_trauma = max(0.0, _trauma - shake_decay_rate * delta)

	# Trauma² gives a more organic shake feel (small hits are subtle, big hits punch)
	var shake_amount: float = _trauma * _trauma

	if shake_amount > 0.001:
		# Multi-octave pseudo-noise for shake. A single sine has visible
		# periodicity — the shake looks mechanical and rhythmic rather than
		# chaotic. Adding a high-frequency second octave (3.7x faster, lower
		# amplitude) breaks up the pattern into organic, non-repeating noise
		# that better resembles a physical camera impact. A third sub-octave
		# (0.37x) adds a slow drift so heavy shakes have weighty sway on top
		# of the rattle. This is the standard "1/f-ish noise" trick used in
		# Vlambeer-style juice.
		var t: float = Time.get_ticks_msec() * 0.05
		var noise_x: float = (
			sin(t + _shake_seed.x) * 0.65
			+ sin(t * 3.7 + _shake_seed.x * 1.7) * 0.25
			+ sin(t * 0.37 + _shake_seed.x * 0.5) * 0.10
		) * max_shake_offset * shake_amount
		var noise_y: float = (
			sin(t * 1.3 + _shake_seed.y) * 0.65
			+ sin(t * 4.1 + _shake_seed.y * 2.3) * 0.25
			+ sin(t * 0.51 + _shake_seed.y * 0.6) * 0.10
		) * max_shake_offset * shake_amount
		var rot_z: float = (
			sin(t * 0.9 + _shake_seed.z) * 0.65
			+ sin(t * 3.3 + _shake_seed.z * 1.9) * 0.25
			+ sin(t * 0.43 + _shake_seed.z * 0.4) * 0.10
		) * max_shake_rotation * shake_amount

		# Directional bias: blend the noise with a directional offset that
		# pushes the camera toward the impact source. The bias fades with
		# trauma so the early frames of the shake are directional (punchy
		# directional kick) and later frames are pure noise (organic rattle).
		# This makes hits feel like they come *from* somewhere rather than
		# being a generic screen wobble.
		var bias_amt: float = _shake_bias_strength * shake_amount * max_shake_offset * 0.5
		var bias_x: float = _shake_bias_dir.x * bias_amt
		var bias_z: float = _shake_bias_dir.z * bias_amt  # Z bias affects Y in camera local space via rig pitch
		# Also add a slight Y bias for vertical feel (e.g. explosions below push down)
		var bias_y: float = _shake_bias_dir.z * bias_amt * 0.3

		camera.position.x = noise_x + bias_x
		camera.position.y = noise_y + bias_y
		camera.position.z = _current_zoom_distance  # Preserve zoom distance
		# Rotation bias: tilt the camera roll slightly toward the hit direction
		var bias_rot: float = _shake_bias_dir.x * _shake_bias_strength * shake_amount * max_shake_rotation * 0.3
		camera.rotation_degrees.z = rot_z + bias_rot
	else:
		# Restore camera local transform (keep zoom distance)
		camera.position.x = 0.0
		camera.position.y = 0.0
		camera.position.z = _current_zoom_distance
		camera.rotation_degrees.z = 0.0

## Add screen shake trauma (0..1). Clamps to 1.0. Multiple calls stack additively.
## Optional `bias_dir` (world-space horizontal direction) biases the shake offset
## toward the impact source so hits feel directional. The bias strength is set
## to the trauma amount (bigger hits = more directional kick).
func add_trauma(amount: float, bias_dir: Vector3 = Vector3.ZERO) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)
	# Set directional bias if provided. Horizontal-only (y=0) since the camera
	# shake operates on the X/Y local plane.
	if bias_dir.length_squared() > 0.01:
		var horiz := Vector3(bias_dir.x, 0.0, bias_dir.z).normalized()
		_shake_bias_dir = horiz
		_shake_bias_strength = clampf(amount, 0.0, 1.0)
	else:
		# No direction → decay any existing bias so it returns to centered noise
		_shake_bias_strength = maxf(_shake_bias_strength * 0.5, 0.0)

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
	# Reset the low-HP zoom flag so the boss zoom takes full ownership of
	# _target_zoom_distance. When the boss dies and _on_boss_defeated
	# restores orbit_distance, the low-HP check in _process will re-
	# evaluate and re-engage the tension zoom if the player is still
	# critical. Without this reset, the flag would stay true and the
	# "should_be_active != _low_hp_zoom_active" guard would skip the
	# _target_zoom_distance update, leaving the camera at orbit_distance
	# instead of low_hp_zoom_distance after the boss dies.
	_low_hp_zoom_active = false

func _on_boss_defeated(_boss: Node) -> void:
	_target_zoom_distance = orbit_distance
	# The _process low-HP check will re-engage the tension zoom next frame
	# if the player is still at critical HP. No need to set it here —
	# setting _low_hp_zoom_active = false would cause a one-frame flash
	# at orbit_distance before the tension zoom eases back in, which
	# reads worse than a smooth ease from boss_zoom → low_hp_zoom.