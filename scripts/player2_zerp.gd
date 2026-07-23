## Zorp Wiggles — Player 2 "Zerp" Controller
## Phase 19: Local Co-op — P2 uses arrow keys + numpad.
## Distinct magenta-purple color, slightly different stats.
## Shares combo with P1, can revive and be revived.

extends CharacterBody3D

signal p2_shoot_fired(direction: Vector3)
signal p2_pulse_fired()

# ─── Node References ──────────────────────────────────────────────────────────
@onready var mesh: MeshInstance3D = $BodyMesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var shoot_origin: Marker3D = $ShootOrigin

# ─── Movement ─────────────────────────────────────────────────────────────────
var move_direction: Vector3 = Vector3.ZERO
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var is_sliding: bool = false
var slide_velocity: Vector3 = Vector3.ZERO

# ─── Input Buffering ──────────────────────────────────────────────────────────
var _dash_buffer_timer: float = 0.0
const DASH_BUFFER_WINDOW: float = 0.15
var _shoot_buffer_timer: float = 0.0
const SHOOT_BUFFER_WINDOW: float = 0.12
# ── Hold-to-auto-fire ── P2's shoot key (period/`.` by default) auto-fires
#    when held, mirroring P1's hold-to-fire. There's no X-key pin toggle for
#    P2 (co-op is a more active, shared-screen context where a pin would be
#    confusing), but holding the shoot key gives the same finger-saving QoL.
var _shoot_held: bool = false
var _pulse_buffer_timer: float = 0.0
const PULSE_BUFFER_WINDOW: float = 0.18

# ─── Visual ───────────────────────────────────────────────────────────────────
var base_color: Color = GameConstants.P2_BASE_COLOR
var is_invuln: bool = false
var invuln_timer: float = 0.0
var _material: StandardMaterial3D = null
var _idle_phase: float = 0.0
const _IDLE_BOB_AMPLITUDE: float = 0.04
const _IDLE_BOB_SPEED: float = 2.5
# ── Dash afterimage timer (shared by dash + slide, matching P1's pattern) ──
var _afterimage_timer: float = 0.0
const AFTERIMAGE_INTERVAL: float = 0.03

# ─── Combat ───────────────────────────────────────────────────────────────────
var shoot_cooldown_timer: float = 0.0
var pulse_wave_cooldown_timer: float = 0.0
const PROJECTILE_SCENE := preload("res://scenes/entities/projectile.tscn")
const PULSE_WAVE_SCENE := preload("res://scenes/entities/pulse_wave.tscn")

# ─── Camera (shared with P1, so P2 reads P1's camera) ─────────────────────────
var _cached_camera: Camera3D = null

func _ready() -> void:
	if collision_shape and not collision_shape.shape:
		var shape = SphereShape3D.new()
		shape.radius = 0.5
		collision_shape.shape = shape
	add_to_group("player")
	add_to_group("player2")
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create P2 material — magenta-purple emissive
	if mesh:
		_material = StandardMaterial3D.new()
		_material.albedo_color = base_color
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.emission_enabled = true
		_material.emission = GameConstants.P2_EMISSION_COLOR
		_material.emission_energy_multiplier = 1.0
		_material.rim_enabled = true
		_material.rim = 0.7
		_material.rim_tint = 0.9
		mesh.material_override = _material

func _physics_process(delta: float) -> void:
	if CoOpManager.p2_is_downed or not CoOpManager.p2_active:
		# Downed — can't move, but still tick invuln
		if invuln_timer > 0:
			invuln_timer -= delta
		return
	if GameManager.is_paused:
		return

	# Reverse gravity dimension
	if DimensionSystem.gravity_reversed():
		var ceiling_y: float = GameConstants.REVERSE_GRAVITY_HEIGHT
		global_position.y = lerpf(global_position.y, ceiling_y, 1.0 - exp(-8.0 * delta))
		if mesh:
			mesh.rotation.x = lerpf(mesh.rotation.x, deg_to_rad(180), 1.0 - exp(-5.0 * delta))
	else:
		if mesh and abs(mesh.rotation.x) > 0.01:
			mesh.rotation.x = lerpf(mesh.rotation.x, 0.0, 1.0 - exp(-5.0 * delta))
		if global_position.y > 2.0:
			global_position.y = lerpf(global_position.y, 0.5, 1.0 - exp(-8.0 * delta))

	# Cooldowns
	if shoot_cooldown_timer > 0:
		shoot_cooldown_timer -= delta
	if pulse_wave_cooldown_timer > 0:
		pulse_wave_cooldown_timer -= delta
	if invuln_timer > 0:
		invuln_timer -= delta
		is_invuln = invuln_timer > 0

	# Input buffers
	if _dash_buffer_timer > 0:
		_dash_buffer_timer -= delta
	if _shoot_buffer_timer > 0:
		_shoot_buffer_timer -= delta
		if shoot_cooldown_timer <= 0 and _shoot_buffer_timer > 0:
			_shoot_buffer_timer = 0.0
			_try_shoot()
	# ── Hold-to-auto-fire: while P2's shoot key is held, fire whenever the
	#    cooldown is ready. Composes with the buffer above (a buffered press
	#    fires first, then held-fire takes over). Skipped while paused or
	#    downed so P2 doesn't fire into a paused game or while out of action.
	if _shoot_held and not GameManager.is_paused and CoOpManager.p2_active and not CoOpManager.p2_is_downed:
		if shoot_cooldown_timer <= 0:
			_try_shoot()
	if _pulse_buffer_timer > 0:
		_pulse_buffer_timer -= delta
		if pulse_wave_cooldown_timer <= 0 and _pulse_buffer_timer > 0:
			_pulse_buffer_timer = 0.0
			_use_pulse_wave()

	# Movement
	if is_sliding:
		_update_slide(delta)
		_update_invuln_blink()
		return

	_handle_movement(delta)
	_handle_dash(delta)
	_update_idle_breathing(delta)
	_update_movement_lean(delta)
	_update_invuln_blink()
	# ── Phase 28: Gravity Anomaly weather — apply vertical force to P2 ──
	var p2_grav_force: float = WeatherSystem.get_gravity_anomaly_force()
	if p2_grav_force != 0.0 and not is_dashing and not is_sliding:
		velocity.y = p2_grav_force
	elif velocity.y != 0 and not DimensionSystem.gravity_reversed():
		velocity.y = 0
	move_and_slide()

	# ── Phase 35: World border clamp (same as P1) ──
	var border: float = GameConstants.WORLD_EXTENT - 2.0
	var pos: Vector3 = global_position
	if abs(pos.x) > border or abs(pos.z) > border:
		global_position = Vector3(
			clampf(pos.x, -border, border),
			pos.y,
			clampf(pos.z, -border, border)
		)
		velocity.x = 0.0
		velocity.z = 0.0

func _get_camera() -> Camera3D:
	if _cached_camera and is_instance_valid(_cached_camera):
		return _cached_camera
	_cached_camera = get_viewport().get_camera_3d()
	return _cached_camera

func _handle_movement(delta: float) -> void:
	# Read P2 input (arrow keys)
	var input_dir := Input.get_vector("p2_move_left", "p2_move_right", "p2_move_up", "p2_move_down")

	# Camera-relative movement (same as P1)
	var camera_3d: Camera3D = _get_camera()
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
		velocity = dash_direction * GameConstants.PLAYER_DASH_SPEED * GameConstants.P2_DASH_MULT
		return

	if is_sliding:
		return

	# Apply speed multipliers (weather, dimension, progression, equipment, world modifier)
	var speed_mult: float = DimensionSystem.get_player_time_scale()
	speed_mult *= WeatherSystem.get_speed_multiplier()
	speed_mult *= GameConstants.P2_SPEED_MULT
	# ── Phase 25: ProgressionSystem skill tree — P2 also benefits from skills ──
	if ProgressionSystem:
		speed_mult *= ProgressionSystem.get_speed_mult()
	# ── Phase 29: EquipmentSystem — P2 also benefits from equipment bonuses ──
	if EquipmentSystem:
		speed_mult *= (1.0 + EquipmentSystem.get_speed_mult_bonus())
	# ── Phase 33: WorldModifierSystem — P2 also affected by world modifiers ──
	if WorldModifierSystem and WorldModifierSystem.is_initialized():
		speed_mult *= WorldModifierSystem.get_player_speed_mult()
	# ── Phase 23: Time Warden slow field — P2 also slowed inside the field ──
	if EnemyTimeWarden:
		speed_mult *= EnemyTimeWarden.get_player_slow_mult(global_position)

	if move_direction.length_squared() > 0.01:
		velocity = move_direction * GameConstants.PLAYER_SPEED * speed_mult
		velocity.y = 0
	else:
		velocity = velocity.move_toward(Vector3.ZERO, GameConstants.PLAYER_DECELERATION * delta)
		velocity.y = 0

func _handle_dash(delta: float) -> void:
	if is_sliding:
		_update_slide(delta)
		return

	if is_dashing:
		dash_timer -= delta
		# ── Dash afterimage — spawn ghost copies at intervals during dash (matches P1) ──
		_afterimage_timer -= delta
		if _afterimage_timer <= 0.0:
			_spawn_dash_afterimage()
			_afterimage_timer = AFTERIMAGE_INTERVAL
		if dash_timer <= 0:
			is_dashing = false
			dash_ended()
			_start_slide(dash_direction * GameConstants.PLAYER_DASH_SPEED * GameConstants.P2_DASH_MULT)
		return

	# Buffer or fire dash
	# P2 dash has no cooldown (design choice for co-op accessibility), so we
	# only need to check the buffer timer. (P1 uses GameManager.player_dash_cooldown_timer
	# here, but P2 doesn't track dash cooldown in GameManager.)
	# ── Phase 28: Magnetic Storm EMP — dashing temporarily disabled for P2 too ──
	# ── Phase 33: WorldModifierSystem "No Dash" modifier also disables P2 dash ──
	var p2_can_dash: bool = WeatherSystem.get_emp_dash_disable_remaining() <= 0
	if WorldModifierSystem and WorldModifierSystem.is_initialized() and WorldModifierSystem.is_dash_disabled():
		p2_can_dash = false
	if _dash_buffer_timer > 0 and p2_can_dash:
		_dash_buffer_timer = 0.0
		_start_dash()
	elif Input.is_action_just_pressed("p2_dash") and p2_can_dash:
		_start_dash()

func _start_dash() -> void:
	is_dashing = true
	dash_timer = GameConstants.PLAYER_DASH_DURATION
	dash_direction = move_direction if move_direction.length_squared() > 0.01 else _get_forward_fallback()
	# P2 gets invuln during dash
	invuln_timer = max(invuln_timer, GameConstants.PLAYER_DASH_INVULN_DURATION)
	is_invuln = true
	# Camera shake
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.15)
	if cam_rig and cam_rig.has_method("kick_fov"):
		cam_rig.kick_fov(GameConstants.CAMERA_DASH_FOV_KICK)
	# Dash trail
	ParticleEffects.spawn_dash_trail(get_parent(), global_position, base_color)
	# ── Dash afterimage — P2 also gets ghost copies during dash for visual parity with P1 ──
	_spawn_dash_afterimage()
	# Squash-and-stretch
	if mesh:
		var t := create_tween()
		t.tween_property(mesh, "scale", Vector3(1.4, 0.6, 1.4), 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(mesh, "scale", Vector3.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	# Dash bump enemies
	_dash_bump_enemies()
	# ── Smash destructibles & breakable walls on dash (matches P1) ──
	_dash_smash_destructibles()

func dash_ended() -> void:
	pass

func _start_slide(initial_vel: Vector3) -> void:
	is_sliding = true
	slide_velocity = initial_vel
	invuln_timer = max(invuln_timer, 0.1)
	is_invuln = true

func _update_slide(delta: float) -> void:
	var friction_base: float = GameConstants.DASH_SLIDE_FRICTION
	friction_base = pow(friction_base, WeatherSystem.get_friction_multiplier())
	var friction_factor: float = pow(friction_base, delta * 60.0)
	slide_velocity *= friction_factor
	velocity = slide_velocity
	velocity.y = 0
	move_and_slide()

	var collision := get_last_slide_collision()
	if collision and collision.get_collider():
		var normal: Vector3 = collision.get_normal()
		normal.y = 0
		normal = normal.normalized()
		slide_velocity = slide_velocity.bounce(normal) * GameConstants.DASH_BOUNCE_RESTITUTION
		var cam_rig: Node3D = GameManager.camera_rig
		if cam_rig and cam_rig.has_method("add_trauma"):
			cam_rig.add_trauma(0.1)
		ParticleEffects.spawn_dash_trail(get_parent(), global_position, Color(0.5, 0.8, 1.0))

	if slide_velocity.length() < GameConstants.DASH_SLIDE_MIN_SPEED:
		is_sliding = false
		slide_velocity = Vector3.ZERO
		velocity = Vector3.ZERO

	if randf() < 0.3:
		ParticleEffects.spawn_dash_trail(get_parent(), global_position, base_color)

	# ── Dash afterimage during slide — spawn ghosts while sliding fast (matches P1) ──
	if slide_velocity.length() > GameConstants.DASH_SLIDE_MIN_SPEED * 2.0:
		_afterimage_timer -= delta
		if _afterimage_timer <= 0.0:
			_spawn_dash_afterimage()
			_afterimage_timer = AFTERIMAGE_INTERVAL * 1.5  # Slightly slower during slide

func _get_forward_fallback() -> Vector3:
	var cam: Camera3D = _get_camera()
	if cam:
		var fwd := -cam.global_basis.z
		fwd.y = 0
		return fwd.normalized()
	return Vector3.FORWARD

func _update_idle_breathing(delta: float) -> void:
	if is_dashing or is_sliding:
		if mesh:
			mesh.position.y = 0.0
		return
	_idle_phase += delta * _IDLE_BOB_SPEED
	if mesh and not is_invuln:
		mesh.position.y = sin(_idle_phase) * _IDLE_BOB_AMPLITUDE
	if _material:
		var pulse: float = 0.5 + 0.5 * sin(_idle_phase)
		_material.emission_energy_multiplier = lerpf(0.8, 1.3, pulse)

func _update_invuln_blink() -> void:
	if invuln_timer > 0:
		var blink_phase = fmod(invuln_timer * GameConstants.PLAYER_BLINK_RATE, 1.0)
		if mesh:
			mesh.visible = blink_phase < 0.5
	else:
		if mesh:
			mesh.visible = true
		is_invuln = false

func _unhandled_input(event: InputEvent) -> void:
	# P2 shoot — track held state for hold-to-auto-fire. A press fires
	# immediately (or buffers if on cooldown); a release clears the held
	# flag so auto-fire stops. The held flag is only consulted in
	# _physics_process when the cooldown is ready, so this never fires
	# extra shots on its own.
	if event.is_action_pressed("p2_shoot") and not GameManager.is_paused and CoOpManager.p2_active and not CoOpManager.p2_is_downed:
		_shoot_held = true
		_try_shoot_or_buffer()
	elif event.is_action_released("p2_shoot"):
		_shoot_held = false
	# P2 pulse wave
	if event.is_action_pressed("p2_pulse_wave") and not GameManager.is_paused and CoOpManager.p2_active and not CoOpManager.p2_is_downed:
		_try_pulse_wave_or_buffer()

func _compute_shoot_cooldown() -> float:
	var cooldown: float = GameConstants.SHOOT_COOLDOWN
	if WeaponModSystem:
		cooldown *= WeaponModSystem.get_equipped_fire_rate_mult()
	# ── Phase 33: WeaponModFusion — fused mods use their own fire-rate mult ──
	if WeaponModFusion and WeaponModFusion.is_fused_equipped():
		cooldown *= WeaponModFusion.get_equipped_fire_rate_mult()
	cooldown *= WeatherSystem.get_fire_rate_multiplier()
	# ── Phase 25/29: ProgressionSystem + EquipmentSystem — P2 benefits from skills & equipment ──
	if ProgressionSystem:
		cooldown *= ProgressionSystem.get_fire_rate_mult()
	if EquipmentSystem:
		cooldown *= (1.0 - EquipmentSystem.get_fire_rate_mult_bonus())
	return cooldown

## Fire a shot immediately. Assumes the caller has already verified the
## cooldown is ready (the buffered-shot consumer pre-checks before calling).
func _try_shoot() -> void:
	shoot_cooldown_timer = _compute_shoot_cooldown()
	_spawn_projectile()

func _try_shoot_or_buffer() -> void:
	if shoot_cooldown_timer > 0:
		_shoot_buffer_timer = SHOOT_BUFFER_WINDOW
		return
	_shoot_buffer_timer = 0.0
	shoot_cooldown_timer = _compute_shoot_cooldown()
	_spawn_projectile()

func _spawn_projectile() -> void:
	var shoot_dir := _get_shoot_direction()
	# Weapon mod integration (P2 shares P1's equipped mod)
	var mod_id: int = GameConstants.WeaponMod.NONE
	var mod_color: Color = Color(0.85, 0.3, 0.9)
	var mod_dmg_mult: float = 1.0
	var mod_speed_mult: float = 1.0
	if WeaponModSystem:
		mod_id = WeaponModSystem.get_equipped_mod()
		mod_color = WeaponModSystem.get_equipped_color()
		mod_dmg_mult = WeaponModSystem.get_equipped_damage_mult()
		mod_speed_mult = WeaponModSystem.get_equipped_speed_mult()
	# ── Phase 33: WeaponModFusion — fused mods override stats + alternate parent behavior ──
	if WeaponModFusion and WeaponModFusion.is_fused_equipped():
		mod_id = WeaponModFusion.get_shot_parent_mod()
		mod_color = WeaponModFusion.get_equipped_color()
		mod_dmg_mult = WeaponModFusion.get_equipped_damage_mult()
		mod_speed_mult = WeaponModFusion.get_equipped_speed_mult()

	# P2 damage multiplier
	mod_dmg_mult *= GameConstants.P2_DAMAGE_MULT
	# ── Phase 25: ProgressionSystem skill tree — P2 also benefits from damage skills ──
	if ProgressionSystem:
		mod_dmg_mult *= ProgressionSystem.get_damage_mult()
	# ── Phase 29: EquipmentSystem — P2 also benefits from equipment damage bonuses ──
	if EquipmentSystem:
		mod_dmg_mult *= (1.0 + EquipmentSystem.get_damage_mult_bonus())
	# ── Phase 33: WorldModifierSystem — P2 also affected by world modifier damage mult ──
	if WorldModifierSystem and WorldModifierSystem.is_initialized():
		mod_dmg_mult *= WorldModifierSystem.get_player_damage_mult()
		mod_dmg_mult *= WorldModifierSystem.get_berserker_damage_mult()

	var base_dmg: int = GameConstants.PROJECTILE_BASE_DAMAGE + GameManager.player_level * GameConstants.PROJECTILE_LEVEL_DAMAGE_BONUS
	var mod_dmg: int = int(base_dmg * mod_dmg_mult)
	var mod_speed: float = GameConstants.PROJECTILE_SPEED * mod_speed_mult

	# Use P2 base color if no mod equipped, otherwise mod color
	var proj_color: Color = mod_color if mod_id != GameConstants.WeaponMod.NONE else base_color

	match mod_id:
		GameConstants.WeaponMod.SPREAD_SHOT:
			_spawn_single_projectile(shoot_dir, mod_dmg, mod_speed, proj_color)
			_spawn_single_projectile(shoot_dir.rotated(Vector3.UP, 0.2), mod_dmg, mod_speed, proj_color)
			_spawn_single_projectile(shoot_dir.rotated(Vector3.UP, -0.2), mod_dmg, mod_speed, proj_color)
		GameConstants.WeaponMod.QUANTUM_OVERDRIVE:
			_spawn_single_projectile(shoot_dir, mod_dmg, mod_speed, proj_color, mod_id)
			_spawn_single_projectile(shoot_dir.rotated(Vector3.UP, 0.15), mod_dmg, mod_speed, proj_color, mod_id)
			_spawn_single_projectile(shoot_dir.rotated(Vector3.UP, -0.15), mod_dmg, mod_speed, proj_color, mod_id)
		_:
			_spawn_single_projectile(shoot_dir, mod_dmg, mod_speed, proj_color, mod_id)

	p2_shoot_fired.emit(shoot_dir)
	# ── Phase 25: Extra Bolts skill — P2 also gets extra projectiles from the skill tree ──
	if ProgressionSystem:
		var extra: int = ProgressionSystem.get_extra_projectiles()
		if extra > 0:
			var spread_step: float = 0.12
			for i in range(extra):
				var angle: float = spread_step * float(i + 1) * (1.0 if i % 2 == 0 else -1.0)
				_spawn_single_projectile(shoot_dir.rotated(Vector3.UP, angle), mod_dmg, mod_speed, proj_color, mod_id)
	# ── Phase 30: Adaptive shoot SFX — P2 also gets per-mod shoot sounds ──
	# P2 shares P1's equipped mod, so the same adaptive SFX mapping applies.
	AudioManager.play_shoot_sfx(mod_id)
	# Scale pulse on shoot
	if mesh and not is_dashing:
		var t := create_tween()
		t.tween_property(mesh, "scale", Vector3.ONE * 1.12, 0.04).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(mesh, "scale", Vector3.ONE, 0.07).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	# Camera micro-recoil
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.015)

func _spawn_single_projectile(shoot_dir: Vector3, dmg: int, spd: float, col: Color, mod_id: int = GameConstants.WeaponMod.NONE) -> void:
	var proj: Area3D = PROJECTILE_SCENE.instantiate()
	proj.set("direction", shoot_dir)
	proj.set("damage", dmg)
	proj.set("speed", spd)
	if proj.has_method("set_weapon_mod"):
		proj.set_weapon_mod(mod_id, col)
	# Tag projectile as P2 so kills register correctly
	proj.set_meta("is_p2_projectile", true)
	get_parent().add_child(proj)
	proj.global_position = global_position + Vector3(0, 0.5, 0)

func _get_shoot_direction() -> Vector3:
	# P2 shoots in their movement direction, or forward if not moving
	var dir: Vector3 = move_direction
	if dir.length_squared() < 0.01:
		dir = _get_forward_fallback()
	dir.y = 0
	return dir.normalized()

func _use_pulse_wave() -> void:
	if pulse_wave_cooldown_timer > 0:
		return
	pulse_wave_cooldown_timer = GameConstants.PULSE_WAVE_COOLDOWN
	# Report to CoOpManager for mega pulse sync
	CoOpManager.report_pulse_wave(false, global_position)
	# Only spawn the normal pulse if mega pulse doesn't trigger
	# We need to wait a frame to see if P1 also fires. For simplicity,
	# we always spawn the pulse here — the mega pulse is a bonus on top.
	var pulse: Node3D = PULSE_WAVE_SCENE.instantiate()
	get_parent().add_child(pulse)
	pulse.global_position = global_position
	p2_pulse_fired.emit()
	# Camera shake
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.25)

func _try_pulse_wave_or_buffer() -> void:
	if pulse_wave_cooldown_timer > 0:
		_pulse_buffer_timer = PULSE_BUFFER_WINDOW
		return
	_pulse_buffer_timer = 0.0
	_use_pulse_wave()

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
			if enemy.has_method("take_damage_from"):
				enemy.take_damage_from(5, global_position)

# ── Smash destructibles & breakable walls on dash (matches P1) ──
func _dash_smash_destructibles() -> void:
	for prop in get_tree().get_nodes_in_group("destructibles"):
		if not is_instance_valid(prop):
			continue
		if global_position.distance_to(prop.global_position) < 2.0:
			if prop.has_method("take_damage_from"):
				prop.take_damage_from(999, global_position)  # Instant smash
	for obj in get_tree().get_nodes_in_group("interactive_object"):
		if not is_instance_valid(obj):
			continue
		if "object_type" in obj and obj.object_type == "breakable_wall":
			if global_position.distance_to(obj.global_position) < 2.5:
				if obj.has_method("dash_hit"):
					obj.dash_hit()

# ── Dash afterimage — translucent ghost copies during dash, matching P1's visual ──
func _spawn_dash_afterimage() -> void:
	var parent_node: Node = get_parent()
	if not parent_node:
		return
	var ghost := MeshInstance3D.new()
	var ghost_sphere := SphereMesh.new()
	ghost_sphere.radius = 0.5
	ghost_sphere.height = 1.0
	ghost_sphere.radial_segments = 8
	ghost_sphere.rings = 4
	ghost.mesh = ghost_sphere
	# Unlit transparent material in P2's magenta-purple color
	var ghost_mat := StandardMaterial3D.new()
	ghost_mat.albedo_color = Color(base_color.r, base_color.g, base_color.b, 0.5)
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.emission_enabled = true
	ghost_mat.emission = base_color * 0.3
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost.material_override = ghost_mat
	parent_node.add_child(ghost)
	ghost.global_position = global_position
	ghost.global_rotation = global_rotation
	ghost.scale = mesh.scale if mesh else Vector3.ONE
	# Fade out + slight scale up for dissipating energy look
	var fade_tween := ghost.create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(ghost_mat, "albedo_color:a", 0.0, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	fade_tween.tween_property(ghost, "scale", ghost.scale * 1.3, 0.35) \
		.set_ease(Tween.EASE_OUT)
	fade_tween.chain().tween_callback(ghost.queue_free)

# ── Movement lean — P2 mesh tilts toward movement direction like P1 ──
func _update_movement_lean(delta: float) -> void:
	if not mesh:
		return
	if is_dashing or is_sliding:
		# Reset lean during dash/slide (their tweens control mesh.scale)
		var lr := mesh.rotation
		mesh.rotation = Vector3(lerpf(lr.x, 0.0, 1.0 - exp(-10.0 * delta)), lr.y, lerpf(lr.z, 0.0, 1.0 - exp(-10.0 * delta)))
		return
	if DimensionSystem.gravity_reversed():
		return  # Mesh is flipped 180°, skip lean
	var speed_frac: float = clampf(velocity.length() / GameConstants.PLAYER_SPEED, 0.0, 1.0)
	if speed_frac < 0.05:
		# Ease back to upright when standing still
		var lr2 := mesh.rotation
		mesh.rotation = Vector3(lerpf(lr2.x, 0.0, 1.0 - exp(-10.0 * delta)), lr2.y, lerpf(lr2.z, 0.0, 1.0 - exp(-10.0 * delta)))
		return
	# Camera-relative lean: tilt forward/back + strafe
	var cam: Camera3D = _get_camera()
	if not cam:
		return
	var cam_forward := -cam.global_basis.z
	cam_forward.y = 0
	cam_forward = cam_forward.normalized()
	var cam_right := cam.global_basis.x
	cam_right.y = 0
	cam_right = cam_right.normalized()
	var move_dot: float = velocity.normalized().dot(cam_forward)
	var strafe_dot: float = velocity.normalized().dot(cam_right)
	var max_lean: float = deg_to_rad(7.0)
	var target_pitch: float = -move_dot * max_lean * speed_frac
	var target_roll: float = strafe_dot * max_lean * speed_frac
	var cur := mesh.rotation
	mesh.rotation = Vector3(
		lerpf(cur.x, target_pitch, 1.0 - exp(-10.0 * delta)),
		cur.y,
		lerpf(cur.z, target_roll, 1.0 - exp(-10.0 * delta))
	)

## Set invulnerability timer (called by CoOpManager on revive).
func set_invuln(duration: float) -> void:
	invuln_timer = duration
	is_invuln = true