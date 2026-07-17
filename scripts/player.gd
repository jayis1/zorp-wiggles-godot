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

# ── Phase 8: Physics-based dash slide ─────────────────────────────────────────
var is_sliding: bool = false
var slide_velocity: Vector3 = Vector3.ZERO

# ─── Input Buffering ──────────────────────────────────────────────────────────
var _dash_buffer_timer: float = 0.0  # >0 means a dash press is buffered
const DASH_BUFFER_WINDOW: float = 0.15  # Seconds to remember dash press before it expires

# ── Shoot input buffer: if the player clicks during the shoot cooldown, the
#    shot fires immediately when ready instead of being dropped. This makes
#    rapid-fire feel responsive even when clicking slightly ahead of cooldown.
var _shoot_buffer_timer: float = 0.0
const SHOOT_BUFFER_WINDOW: float = 0.12  # Seconds to remember a shoot press

# ── Pulse wave input buffer: same concept as dash/shoot buffers. If the
#    player presses Q during the pulse wave cooldown, the ability fires
#    immediately when ready. Prevents dropped inputs during tense moments.
var _pulse_buffer_timer: float = 0.0
const PULSE_BUFFER_WINDOW: float = 0.18  # Seconds to remember pulse wave press

# ─── Visual ───────────────────────────────────────────────────────────────────
var base_color: Color = Color(0.3, 0.85, 0.3)  # Alien green
var is_invuln_blinking: bool = false
var blink_visible: bool = true
var _player_material: StandardMaterial3D = null
var _idle_phase: float = 0.0  # Phase accumulator for idle breathing
const _IDLE_BOB_AMPLITUDE: float = 0.04  # Subtle vertical bob (meters)
const _IDLE_BOB_SPEED: float = 2.5       # Bob frequency (rad/s)
const _IDLE_EMISSION_MIN: float = 0.8    # Idle emission pulse min
const _IDLE_EMISSION_MAX: float = 1.3    # Idle emission pulse max

# ─── Combat ───────────────────────────────────────────────────────────────────
var shoot_cooldown_timer: float = 0.0
var pulse_wave_cooldown_timer: float = 0.0
const PROJECTILE_SCENE := preload("res://scenes/entities/projectile.tscn")
const PULSE_WAVE_SCENE := preload("res://scenes/entities/pulse_wave.tscn")

# ── Phase 15: Alien Companion Pet ─────────────────────────────────────────────
const PET_SCENE := preload("res://scenes/entities/companion_pet.tscn")
var pet: CharacterBody3D = null
var _fetch_mode: bool = false  # When true, next left-click sends pet to fetch

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
	# Use PROCESS_MODE_ALWAYS so the player can still receive input (e.g. pause toggle)
	# when the game is paused. _physics_process already checks is_paused and returns
	# early, so the player won't move while paused — only input processing continues.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# ── Set up player material (the scene ships with the default grey material)
	# We give Zorp a proper unlit-emissive look: albedo + emission tinted to base_color
	# plus rim lighting for silhouette pop. The emission pulses subtly via the idle
	# animation so Zorp feels "alive" even when standing still.
	if mesh:
		_player_material = StandardMaterial3D.new()
		_player_material.albedo_color = base_color
		_player_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_player_material.emission_enabled = true
		_player_material.emission = base_color * 0.4
		_player_material.emission_energy_multiplier = 1.0
		_player_material.rim_enabled = true
		_player_material.rim = 0.7
		_player_material.rim_tint = 0.9
		mesh.material_override = _player_material

func _physics_process(delta: float) -> void:
	if GameManager.is_paused or not GameManager.player_is_alive:
		return
	
	# ── Phase 14: Reverse Gravity dimension — walk on ceiling ──
	# Smoothly move the player to ceiling height when in reverse gravity dimension
	if DimensionSystem.gravity_reversed():
		var ceiling_y: float = GameConstants.REVERSE_GRAVITY_HEIGHT
		# Smoothly move player to ceiling
		global_position.y = lerpf(global_position.y, ceiling_y, 1.0 - exp(-8.0 * delta))
		# Flip the mesh upside down for visual effect
		if mesh:
			mesh.rotation.x = lerpf(mesh.rotation.x, deg_to_rad(180), 1.0 - exp(-5.0 * delta))
	else:
		# Return to ground level when not in reverse gravity
		if mesh and abs(mesh.rotation.x) > 0.01:
			mesh.rotation.x = lerpf(mesh.rotation.x, 0.0, 1.0 - exp(-5.0 * delta))
		# Gravity pulls back to ground if we were on ceiling
		if global_position.y > 2.0:
			global_position.y = lerpf(global_position.y, 0.5, 1.0 - exp(-8.0 * delta))
	
	# Cooldowns
	if shoot_cooldown_timer > 0:
		shoot_cooldown_timer -= delta
	if pulse_wave_cooldown_timer > 0:
		pulse_wave_cooldown_timer -= delta
	
	# Tick input buffers
	if _dash_buffer_timer > 0:
		_dash_buffer_timer -= delta
	if _shoot_buffer_timer > 0:
		_shoot_buffer_timer -= delta
		# Consume buffered shot when cooldown is ready
		if shoot_cooldown_timer <= 0 and _shoot_buffer_timer > 0:
			_shoot_buffer_timer = 0.0
			_try_shoot()
	if _pulse_buffer_timer > 0:
		_pulse_buffer_timer -= delta
		# Consume buffered pulse wave when cooldown is ready
		if pulse_wave_cooldown_timer <= 0 and _pulse_buffer_timer > 0:
			_pulse_buffer_timer = 0.0
			_use_pulse_wave()
	
	# ── Phase 8: If sliding, the slide handler does its own move_and_slide
	if is_sliding:
		_handle_dash(delta)
		_handle_invuln_blink(delta)
		return
	
	_handle_movement(delta)
	_handle_dash(delta)
	_handle_invuln_blink(delta)
	_update_idle_breathing(delta)

	move_and_slide()

# ── Idle breathing animation — a subtle vertical bob + emission pulse so Zorp
#    feels alive even when standing still. Skipped during dash (the dash tween
#    controls mesh.scale during squash-and-stretch) and when invuln-blinking
#    (which toggles mesh visibility and would conflict).
func _update_idle_breathing(delta: float) -> void:
	if is_dashing or is_sliding:
		# Reset any lingering bob offset so dash/slide tweens start from y=0
		if mesh:
			mesh.position.y = 0.0
		return
	_idle_phase += delta * _IDLE_BOB_SPEED
	# Only apply visual bob when NOT being tweened by squash/pulse/shoot feedback.
	# Those tweens set mesh.scale; we only offset y-position to avoid conflicts.
	if mesh and not is_invuln_blinking:
		mesh.position.y = sin(_idle_phase) * _IDLE_BOB_AMPLITUDE
	# Emission pulse synced to bob for a "breathing" glow
	if _player_material:
		var pulse: float = 0.5 + 0.5 * sin(_idle_phase)
		_player_material.emission_energy_multiplier = lerpf(
			_IDLE_EMISSION_MIN, _IDLE_EMISSION_MAX, pulse)

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
	
	# ── Phase 8: Skip normal movement during slide (slide handles velocity)
	if is_sliding:
		return
	
	# Acceleration/deceleration
	# ── Phase 14: Time-Slow dimension — player moves at reduced speed ──
	var speed_mult: float = DimensionSystem.get_player_time_scale()
	if move_direction.length_squared() > 0.01:
		velocity_target = move_direction * GameConstants.PLAYER_SPEED * speed_mult
		# Snap Y velocity to zero (no vertical movement)
		velocity_target.y = 0
	else:
		velocity_target = Vector3.ZERO
	
	# Smooth acceleration / deceleration
	var accel: float = GameConstants.PLAYER_ACCELERATION if velocity_target.length_squared() > 0.01 else GameConstants.PLAYER_DECELERATION
	velocity = velocity.move_toward(velocity_target, accel * delta)
	velocity.y = 0  # No vertical movement

func _handle_dash(delta: float) -> void:
	if is_sliding:
		_update_slide(delta)
		return

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			GameManager.player_is_dashing = false
			dash_ended.emit()
			# ── Phase 8: Transition into physics slide (carry dash momentum)
			_start_slide(dash_direction * GameConstants.PLAYER_DASH_SPEED)
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

# ── Phase 8: Physics slide after dash ─────────────────────────────────────────
func _start_slide(initial_vel: Vector3) -> void:
	is_sliding = true
	slide_velocity = initial_vel
	# Keep invuln during early slide for a smooth feel
	GameManager.player_invuln_timer = max(GameManager.player_invuln_timer, 0.1)

func _update_slide(delta: float) -> void:
	# Apply friction (frame-rate independent exponential decay)
	var friction_factor: float = pow(GameConstants.DASH_SLIDE_FRICTION, delta * 60.0)
	slide_velocity *= friction_factor

	# Move
	velocity = slide_velocity
	velocity.y = 0
	move_and_slide()

	# Check for wall collision (bounce) — if we hit something, reflect velocity
	var collision := get_last_slide_collision()
	if collision and collision.get_collider():
		var normal: Vector3 = collision.get_normal()
		normal.y = 0
		normal = normal.normalized()
		# Reflect slide velocity around the collision normal
		slide_velocity = slide_velocity.bounce(normal) * GameConstants.DASH_BOUNCE_RESTITUTION
		# Small camera shake on wall bump
		_trigger_camera_trauma(0.1)
		# Sparkle on bounce
		ParticleEffects.spawn_dash_trail(get_parent(), global_position, Color(0.5, 0.8, 1.0))

	# End slide when velocity is too slow
	if slide_velocity.length() < GameConstants.DASH_SLIDE_MIN_SPEED:
		is_sliding = false
		slide_velocity = Vector3.ZERO
		velocity = Vector3.ZERO

	# Dash trail particles during slide (occasional)
	if randf() < 0.3:
		ParticleEffects.spawn_dash_trail(get_parent(), global_position, base_color)

func _start_dash() -> void:
	is_dashing = true
	dash_timer = GameConstants.PLAYER_DASH_DURATION
	dash_direction = move_direction if move_direction.length_squared() > 0.01 else get_forward_dir_fallback()
	GameManager.player_dash_cooldown_timer = GameConstants.PLAYER_DASH_COOLDOWN
	GameManager.player_invuln_timer = max(GameManager.player_invuln_timer, GameConstants.PLAYER_DASH_INVULN_DURATION)
	GameManager.player_is_dashing = true
	dash_started.emit()

	# Camera shake on dash for punch
	_trigger_camera_trauma(0.15)

	# FOV kick — briefly widen the camera FOV for a speed sensation. The camera
	# eases the FOV back to default in _process, so this is a one-shot nudge.
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("kick_fov"):
		cam_rig.kick_fov(GameConstants.CAMERA_DASH_FOV_KICK)

	# Phase 6: Dash trail particles
	ParticleEffects.spawn_dash_trail(get_parent(), global_position, base_color)

	# Squash-and-stretch: compress vertically, stretch horizontally, then bounce back
	if mesh:
		var squash_tween := create_tween()
		squash_tween.tween_property(mesh, "scale", Vector3(1.4, 0.6, 1.4), 0.08) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_CUBIC)
		squash_tween.tween_property(mesh, "scale", Vector3.ONE, 0.18) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_ELASTIC)

	# ── Phase 8: Physics dash — enemies caught in dash path get knocked back
	_dash_bump_enemies()

	# ── Phase 8: Destructibles smashed by dash
	_dash_smash_destructibles()

# ── Phase 8: Knock back enemies in the dash path ───────────────────────────────
func _dash_bump_enemies() -> void:
	var bump_radius: float = 2.5
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < bump_radius:
			var push_dir: Vector3 = (enemy.global_position - global_position).normalized()
			push_dir.y = 0
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback(push_dir, GameConstants.KNOCKBACK_FORCE_DASH_BUMP)
			# Also deal a small bump damage
			if enemy.has_method("take_damage_from"):
				enemy.take_damage_from(5, global_position)

# ── Phase 8: Smash destructibles in dash path ──────────────────────────────────
func _dash_smash_destructibles() -> void:
	for prop in get_tree().get_nodes_in_group("destructibles"):
		if not is_instance_valid(prop):
			continue
		if global_position.distance_to(prop.global_position) < 2.0:
			if prop.has_method("take_damage_from"):
				prop.take_damage_from(999, global_position)  # Instant smash

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
	
	if event is InputEventMouseMotion and is_right_clicking and not GameManager.is_paused:
		camera_yaw -= event.relative.x * 0.3
		camera_pitch -= event.relative.y * 0.3
		camera_pitch = clampf(camera_pitch, -80.0, -10.0)
		_apply_camera_rotation()
	
	# Shoot on left click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not GameManager.is_paused and GameManager.player_is_alive:
			# ── Phase 15: If in fetch mode, left-click targets a collectible ──
			if _fetch_mode:
				_try_fetch_click()
				_fetch_mode = false
				return
			_try_shoot_or_buffer()
	
	# Pulse wave
	if event.is_action_pressed("pulse_wave") and GameManager.player_is_alive and not GameManager.is_paused:
		_try_pulse_wave_or_buffer()
	
	# Pause toggle
	if event.is_action_pressed("pause"):
		GameManager.is_paused = not GameManager.is_paused
		get_tree().paused = GameManager.is_paused
	
	# ── Phase 15: Summon companion pet (F key) ──
	if event.is_action_pressed("summon_pet") and not GameManager.is_paused and GameManager.player_is_alive:
		_toggle_pet()
	
	# ── Phase 15: Pet fetch command (G key) ──
	# Pressing G enters "fetch mode" — the next left-click targets a collectible
	# for the pet to fetch. Pressing G again cancels fetch mode.
	if event.is_action_pressed("pet_fetch") and not GameManager.is_paused and GameManager.player_is_alive:
		if pet and is_instance_valid(pet):
			_fetch_mode = not _fetch_mode
			if _fetch_mode:
				GameManager.add_message("🐾 Click a collectible to send pet to fetch")
			else:
				GameManager.add_message("🐾 Fetch cancelled")
		else:
			GameManager.add_message("🐾 No pet to fetch with! Press F to summon.")

func _apply_camera_rotation() -> void:
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig:
		# Use the smooth setters so the rig eases toward the new angles
		# in _process instead of snapping instantly.
		if cam_rig.has_method("set_camera_yaw"):
			cam_rig.set_camera_yaw(camera_yaw)
		if cam_rig.has_method("set_camera_pitch"):
			cam_rig.set_camera_pitch(camera_pitch)

func _try_shoot() -> void:
	if shoot_cooldown_timer > 0:
		return
	shoot_cooldown_timer = GameConstants.SHOOT_COOLDOWN
	_spawn_projectile()

## Try to shoot; if on cooldown, buffer the input so it fires as soon as ready.
## This prevents dropped clicks during rapid fire and makes shooting feel snappy.
func _try_shoot_or_buffer() -> void:
	if shoot_cooldown_timer > 0:
		# Buffer the shot — it will fire when cooldown expires (if within window)
		_shoot_buffer_timer = SHOOT_BUFFER_WINDOW
		return
	_shoot_buffer_timer = 0.0
	shoot_cooldown_timer = GameConstants.SHOOT_COOLDOWN
	_spawn_projectile()

func _spawn_projectile() -> void:
	var shoot_dir := get_shoot_direction()
	var proj: Area3D = PROJECTILE_SCENE.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position + Vector3(0, 0.5, 0)
	proj.set("direction", shoot_dir)
	# Damage scales with player level (matches original Ursina: level * bonus)
	var dmg: int = GameConstants.PROJECTILE_BASE_DAMAGE + GameManager.player_level * GameConstants.PROJECTILE_LEVEL_DAMAGE_BONUS
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

## Try to fire the pulse wave; if on cooldown, buffer the input so it fires
## as soon as ready. Mirrors the dash and shoot buffering pattern so all three
## player actions feel equally responsive.
func _try_pulse_wave_or_buffer() -> void:
	if pulse_wave_cooldown_timer > 0:
		_pulse_buffer_timer = PULSE_BUFFER_WINDOW
		return
	_pulse_buffer_timer = 0.0
	_use_pulse_wave()

func _trigger_camera_trauma(amount: float) -> void:
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(amount)

# ── Phase 13: Biome Mutation System — visual color shifts ─────────────────────
# Applied by MutationSystem when a mutation activates/deactivates.
# Each mutation shifts the player's material color slightly toward the mutation color.

var _mutation_colors: Dictionary = {}  # { mutation_id: Color }

func _apply_mutation_color(mutation: int, mut_color: Color) -> void:
	_mutation_colors[mutation] = mut_color
	_update_mutation_material()

func _remove_mutation_color(mutation: int) -> void:
	_mutation_colors.erase(mutation)
	_update_mutation_material()

func _update_mutation_material() -> void:
	if not _player_material:
		return
	if _mutation_colors.is_empty():
		# Reset to base color
		_player_material.albedo_color = base_color
		_player_material.emission = base_color * 0.4
		return
	# Blend base color with all active mutation colors (equal weight)
	var blended: Color = base_color
	for mut_color in _mutation_colors.values():
		blended = blended.lerp(mut_color, 0.3)
	_player_material.albedo_color = blended
	_player_material.emission = blended * 0.4


# ── Phase 15: Alien Companion Pet — summon/fetch logic ────────────────────────

## Toggle the pet on/off. Pressing F summons the pet if none exists, or
## dismisses it if one is already active.
func _toggle_pet() -> void:
	if pet and is_instance_valid(pet):
		# Dismiss existing pet
		ParticleEffects.spawn_death_poof(get_parent(), pet.global_position, Color(0.5, 0.7, 1.0), 0.8)
		pet.queue_free()
		pet = null
		_fetch_mode = false
		GameManager.add_message("🐾 Pet dismissed")
	else:
		# Summon a new pet
		pet = PET_SCENE.instantiate() as CharacterBody3D
		get_parent().add_child(pet)
		pet.global_position = global_position + GameConstants.PET_SPAWN_OFFSET
		GameManager.add_message("🐾 Companion pet summoned! Press F to dismiss, G to fetch.")
		print("[Player] Pet summoned at %s" % pet.global_position)


## When in fetch mode, left-click raycasts to find a collectible under the
## cursor and sends the pet to fetch it.
func _try_fetch_click() -> void:
	if not pet or not is_instance_valid(pet):
		_fetch_mode = false
		return
	# Raycast from camera through mouse to find a collectible
	var camera_3d: Camera3D = get_viewport().get_camera_3d()
	if not camera_3d:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera_3d.project_ray_origin(mouse_pos)
	var dir := camera_3d.project_ray_normal(mouse_pos)
	# Check intersection with collectibles by projecting to ground plane
	# then finding the nearest collectible within a small radius
	if abs(dir.y) > 0.001:
		var t := -from.y / dir.y
		if t > 0:
			var hit_point := from + dir * t
			# Find nearest collectible to the hit point
			var nearest: Node3D = null
			var nearest_dist: float = 5.0  # Max click radius
			for col in GameManager.collectibles:
				if not is_instance_valid(col):
					continue
				if not col.is_in_group("collectibles"):
					continue
				var d: float = hit_point.distance_to(col.global_position)
				if d < nearest_dist:
					nearest_dist = d
					nearest = col
			if nearest:
				pet.send_to_fetch(nearest)
			else:
				GameManager.add_message("🐾 No collectible found at click location")