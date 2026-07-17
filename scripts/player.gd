## Zorp Wiggles — Player Controller
## 3D character controller with WASD movement, dash, orbit camera.
## Ported from the Player class + game_update movement logic in Ursina game.py.

extends CharacterBody3D

signal shoot(direction: Vector3)
signal dash_started()
signal dash_ended()

# ─── Node References ──────────────────────────────────────────────────────────
@onready var mesh: MeshInstance3D = $BodyMesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var shoot_origin: Marker3D = $ShootOrigin
@onready var ray_cast: RayCast3D = $RayCast3D

# ─── Movement ─────────────────────────────────────────────────────────────────
var velocity_target: Vector3 = Vector3.ZERO
var current_velocity: Vector3 = Vector3.ZERO
var move_direction: Vector3 = Vector3.ZERO
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO

# ─── Input Buffering ──────────────────────────────────────────────────────────
var _dash_buffer_timer: float = 0.0  # >0 means a dash press is buffered
const DASH_BUFFER_WINDOW: float = 0.15  # Seconds to remember dash press before it expires

# ─── Visual ───────────────────────────────────────────────────────────────────
var base_color: Color = Color(0.3, 0.85, 0.3)  # Alien green
var is_invuln_blinking: bool = false
var blink_visible: bool = true

# ─── Combat ───────────────────────────────────────────────────────────────────
var shoot_cooldown_timer: float = 0.0
var pulse_wave_cooldown_timer: float = 0.0
const PROJECTILE_SCENE := preload("res://scenes/entities/projectile.tscn")
const PULSE_WAVE_SCENE := preload("res://scenes/entities/pulse_wave.tscn")

# ─── Camera ────────────────────────────────────────────────────────────────────
var camera_yaw: float = 0.0
var camera_pitch: float = -55.0  # Looking down
var is_right_clicking: bool = false

func _ready() -> void:
	# Ensure collision shape has a sphere (fallback if scene missing it)
	if collision_shape and not collision_shape.shape:
		var shape = SphereShape3D.new()
		shape.radius = 0.5
		collision_shape.shape = shape
	add_to_group("player")

func _physics_process(delta: float) -> void:
	if GameManager.is_paused or not GameManager.player_is_alive:
		return
	
	# Cooldowns
	if shoot_cooldown_timer > 0:
		shoot_cooldown_timer -= delta
	if pulse_wave_cooldown_timer > 0:
		pulse_wave_cooldown_timer -= delta
	
	# Tick input buffer
	if _dash_buffer_timer > 0:
		_dash_buffer_timer -= delta
	
	_handle_movement(delta)
	_handle_dash(delta)
	_handle_invuln_blink(delta)
	
	move_and_slide()

func _handle_movement(delta: float) -> void:
	# Read input
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Camera-relative movement direction
	var camera_3d: Camera3D = get_viewport().get_camera_3d()
	if camera_3d:
		var forward := -camera_3d.global_basis.z
		forward.y = 0
		forward = forward.normalized()
		var right := camera_3d.global_basis.x
		right.y = 0
		right = right.normalized()
		move_direction = (forward * input_dir.y + right * input_dir.x).normalized()
	else:
		move_direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	if is_dashing:
		velocity = dash_direction * GameConstants.PLAYER_DASH_SPEED
		return
	
	# Acceleration/deceleration
	if move_direction.length_squared() > 0.01:
		velocity_target = move_direction * GameConstants.PLAYER_SPEED
		# Snap Y velocity to zero (no vertical movement)
		velocity_target.y = 0
	else:
		velocity_target = Vector3.ZERO
	
	# Smooth acceleration / deceleration
	var accel: float = GameConstants.PLAYER_ACCELERATION if velocity_target.length_squared() > 0.01 else GameConstants.PLAYER_DECELERATION
	velocity = velocity.move_toward(velocity_target, accel * delta)
	velocity.y = 0  # No vertical movement

func _handle_dash(delta: float) -> void:
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			GameManager.player_is_dashing = false
			dash_ended.emit()
		return

	# Consume buffered dash if cooldown is ready
	if _dash_buffer_timer > 0 and GameManager.player_dash_cooldown_timer <= 0:
		_dash_buffer_timer = 0.0
		_start_dash()
	elif Input.is_action_just_pressed("dash"):
		if GameManager.player_dash_cooldown_timer <= 0:
			_start_dash()
		else:
			# Buffer the input — will fire when cooldown expires (if within window)
			_dash_buffer_timer = DASH_BUFFER_WINDOW

func _start_dash() -> void:
	is_dashing = true
	GameManager.player_is_dashing = true
	dash_timer = GameConstants.PLAYER_DASH_DURATION
	dash_direction = move_direction if move_direction.length_squared() > 0.01 else get_forward_dir_fallback()
	GameManager.player_dash_cooldown_timer = GameConstants.PLAYER_DASH_COOLDOWN
	GameManager.player_invuln_timer = max(GameManager.player_invuln_timer, GameConstants.PLAYER_DASH_INVULN_DURATION)
	dash_started.emit()

	# Camera shake on dash for punch
	_trigger_camera_trauma(0.15)

	# Squash-and-stretch: compress vertically, stretch horizontally, then bounce back
	if mesh:
		var squash_tween := create_tween()
		squash_tween.tween_property(mesh, "scale", Vector3(1.4, 0.6, 1.4), 0.08) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_CUBIC)
		squash_tween.tween_property(mesh, "scale", Vector3.ONE, 0.18) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_ELASTIC)

func get_forward_dir_fallback() -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam:
		var fwd := -cam.global_basis.z
		fwd.y = 0
		return fwd.normalized()
	return Vector3.FORWARD

func _handle_invuln_blink(delta: float) -> void:
	if GameManager.player_invuln_timer > 0:
		# Blink effect — toggle visibility rapidly
		var blink_phase = fmod(GameManager.player_invuln_timer * GameConstants.PLAYER_BLINK_RATE, 1.0)
		blink_visible = blink_phase < 0.5
		if mesh:
			mesh.visible = blink_visible
	else:
		if mesh:
			mesh.visible = true

func _unhandled_input(event: InputEvent) -> void:
	# Right-click camera rotation
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		is_right_clicking = event.pressed
	
	if event is InputEventMouseMotion and is_right_clicking:
		camera_yaw -= event.relative.x * 0.3
		camera_pitch -= event.relative.y * 0.3
		camera_pitch = clampf(camera_pitch, -80.0, -10.0)
		_apply_camera_rotation()
	
	# Shoot on left click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not GameManager.is_paused and GameManager.player_is_alive:
			_try_shoot()
	
	# Pulse wave
	if event.is_action_pressed("pulse_wave") and GameManager.player_is_alive:
		_use_pulse_wave()

func _apply_camera_rotation() -> void:
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("set_camera_yaw"):
		cam_rig.set_camera_yaw(camera_yaw)
	if cam_rig:
		# Apply pitch by rotating the rig on X axis
		cam_rig.rotation_degrees.x = camera_pitch

func _try_shoot() -> void:
	if shoot_cooldown_timer > 0:
		return
	shoot_cooldown_timer = GameConstants.SHOOT_COOLDOWN
	_spawn_projectile()

func _spawn_projectile() -> void:
	var shoot_dir := get_shoot_direction()
	var proj: Area3D = PROJECTILE_SCENE.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position + Vector3(0, 0.5, 0)
	proj.set("direction", shoot_dir)
	# Damage scales with player level
	var dmg: int = GameConstants.PROJECTILE_BASE_DAMAGE + (GameManager.player_level - 1) * GameConstants.PROJECTILE_LEVEL_DAMAGE_BONUS
	proj.set("damage", dmg)

	# Quick scale pulse on shoot for juicy feedback (skip if dashing to avoid tween conflict)
	if mesh and not is_dashing:
		var pulse_tween := create_tween()
		pulse_tween.tween_property(mesh, "scale", Vector3.ONE * 1.12, 0.04) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_CUBIC)
		pulse_tween.tween_property(mesh, "scale", Vector3.ONE, 0.07) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_ELASTIC)

func get_shoot_direction() -> Vector3:
	var camera_3d: Camera3D = get_viewport().get_camera_3d()
	if not camera_3d:
		return -global_basis.z
	
	# Shoot from camera toward mouse position on ground plane
	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera_3d.project_ray_origin(mouse_pos)
	var dir := camera_3d.project_ray_normal(mouse_pos)
	
	# Intersect with y=0 plane (ground)
	if abs(dir.y) > 0.001:
		var t := -from.y / dir.y
		var hit_point := from + dir * t
		var shoot_dir := (hit_point - global_position).normalized()
		shoot_dir.y = 0
		return shoot_dir
	
	return -global_basis.z

func _use_pulse_wave() -> void:
	if pulse_wave_cooldown_timer > 0:
		return
	pulse_wave_cooldown_timer = GameConstants.PULSE_WAVE_COOLDOWN
	# Spawn pulse wave at player position
	var pulse: Node3D = PULSE_WAVE_SCENE.instantiate()
	get_parent().add_child(pulse)
	pulse.global_position = global_position
	# Camera shake on pulse wave
	_trigger_camera_trauma(0.25)

func _trigger_camera_trauma(amount: float) -> void:
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(amount)