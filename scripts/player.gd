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

# ── Phase 9: Dash afterimage (ghost trail) ──
# Spawns semi-transparent mesh copies at intervals during dash that fade
# out quickly, creating a ghost trail / afterimage effect.
var _afterimage_timer: float = 0.0
const AFTERIMAGE_INTERVAL: float = 0.03  # Spawn a ghost every 30ms during dash
const AFTERIMAGE_LIFETIME: float = 0.35  # Each ghost lives 350ms
const AFTERIMAGE_MAX_ALPHA: float = 0.5  # Starting transparency

# ── Phase 8: Physics-based dash slide ─────────────────────────────────────────
var is_sliding: bool = false
var slide_velocity: Vector3 = Vector3.ZERO

# ── Landing effect: tracks whether Zorp is airborne (reverse-gravity, bounce
#    pad, etc.) so we can play a landing squash + dust puff on touchdown.
var _was_airborne: bool = false

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

# ── Coyote time for dash: if the dash cooldown expired very recently (within
#    this window), a dash press fires immediately even if pressed a hair too
#    early. This bridges the gap between the player's perception of "cooldown
#    is basically done" and the actual timer, making dash feel snappier when
#    spamming it in combat. The window is short (80ms) so it doesn't trivialize
#    the cooldown — it just rounds up the last few frames.
var _dash_coyote_timer: float = 0.0
const DASH_COYOTE_WINDOW: float = 0.08  # Grace period after cooldown ends

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

# ── Phase 6: Idle regen sparkle aura ──
# Ambient green sparkles that orbit Zorp when standing still and healthy.
# Conveys a sense of regeneration and calm — the player feels safe.
var _idle_aura: GPUParticles3D = null
var _idle_aura_timer: float = 0.0
const _IDLE_AURA_HP_THRESHOLD: float = 0.8  # Only show when HP > 80%
const _IDLE_AURA_SPEED_THRESHOLD: float = 1.5  # Only when moving < 1.5 m/s

# ── Low-HP heartbeat: when HP drops below 25%, Zorp's mesh pulses with a
#    rhythmic "thump-thump" scale animation synced to a heartbeat interval.
#    This communicates danger through motion — the player feels the urgency
#    without needing to look at the HP bar. The emission also pulses red-ish
#    on each beat for a visceral "danger" read. Skipped during dash/slide
#    (their tweens own mesh.scale) and invuln-blinking (toggles visibility).
var _heartbeat_phase: float = 0.0
const _HEARTBEAT_BPM: float = 90.0       # Heartbeat tempo (faster = more urgent)
const _HEARTBEAT_HP_THRESHOLD: float = 0.25  # Start heartbeat below 25% HP
const _HEARTBEAT_SCALE_AMP: float = 0.06     # Scale pulse amplitude (subtle)

# ── Movement lean: Zorp's mesh tilts subtly toward the direction of motion,
#    giving a sense of weight and momentum. The lean is smoothed via exponential
#    lerp so it eases in/out rather than snapping. Skipped during dash/slide
#    (those have their own scale tweens that would conflict with rotation).
var _lean_current: Vector3 = Vector3.ZERO  # Current lean rotation (radians)
const _LEAN_MAX_ANGLE: float = 0.12        # Max tilt ~7° in any direction
const _LEAN_SMOOTHING: float = 10.0        # How fast lean eases (higher = snappier)

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
	# ── Phase 25: Prestige cosmetic aura — a golden light for prestiged players ──
	# Each prestige level adds a subtle golden OmniLight around Zorp, visible
	# as a warm halo. The light intensity scales with prestige level.
	if ProgressionSystem and ProgressionSystem.get_prestige_level() > 0:
		var prestige_light := OmniLight3D.new()
		prestige_light.light_color = ProgressionSystem.get_prestige_cosmetic_color()
		prestige_light.light_energy = 0.5 + minf(2.0, ProgressionSystem.get_prestige_level() * 0.3)
		prestige_light.omni_range = 4.0 + ProgressionSystem.get_prestige_level() * 0.5
		prestige_light.omni_attenuation = 1.5
		add_child(prestige_light)
	# ── Damage impact reaction ── Connect to GameManager's damage signal so
	# the player mesh squashes and flashes red when hit, giving visceral
	# feedback beyond the camera shake and invuln blink. The squash is
	# skipped during dash/slide (their tweens own mesh.scale) to avoid
	# conflicts. The signal fires only when damage actually lands (after
	# invuln/dash checks in GameManager.take_damage), so this won't trigger
	# on blocked hits.
	GameManager.damage_taken_from.connect(_on_player_damaged)

func _physics_process(delta: float) -> void:
	if GameManager.is_paused:
		return
	if not GameManager.player_is_alive:
		# ── Phase 19: Co-op — if downed, still blink but don't move ──
		if GameManager.player_is_downed and mesh:
			# Show downed state — semi-transparent blinking
			var blink_phase = fmod(Time.get_ticks_msec() * 0.005, 1.0)
			mesh.visible = blink_phase < 0.7
			mesh.position.y = -0.2  # Slumped down
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
		# Track that we're airborne so we can play a landing effect on return
		_was_airborne = true
	else:
		# Return to ground level when not in reverse gravity
		if mesh and abs(mesh.rotation.x) > 0.01:
			mesh.rotation.x = lerpf(mesh.rotation.x, 0.0, 1.0 - exp(-5.0 * delta))
		# Gravity pulls back to ground if we were on ceiling
		if global_position.y > 2.0:
			global_position.y = lerpf(global_position.y, 0.5, 1.0 - exp(-8.0 * delta))
			_was_airborne = true
		elif _was_airborne and global_position.y <= 0.8:
			# Just landed — play landing squash + dust puff
			_was_airborne = false
			_play_landing_effect()
	
	# Cooldowns
	if shoot_cooldown_timer > 0:
		shoot_cooldown_timer -= delta
	if pulse_wave_cooldown_timer > 0:
		pulse_wave_cooldown_timer -= delta

	# ── Coyote time: track the brief window after dash cooldown expires.
	#    While _dash_coyote_timer > 0, a dash press fires even if the cooldown
	#    timer just barely hit zero — eliminating the frustration of pressing
	#    dash a frame too early and having it silently dropped.
	if GameManager.player_dash_cooldown_timer > 0:
		GameManager.player_dash_cooldown_timer -= delta
		if GameManager.player_dash_cooldown_timer <= 0:
			# Cooldown just expired — start the coyote grace window
			_dash_coyote_timer = DASH_COYOTE_WINDOW
	elif _dash_coyote_timer > 0:
		_dash_coyote_timer -= delta

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
	_update_movement_lean(delta)
	_update_low_hp_heartbeat(delta)
	_update_idle_aura(delta)

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

# ── Low-HP heartbeat: when HP is below the threshold, Zorp's mesh throbs with
#    a double-pulse "lub-dub" heartbeat pattern. The pulse uses a phase
#    accumulator driven by BPM, with two Gaussian-style bumps per beat (the
#    first louder, the second softer). Scale pulses outward; emission shifts
#    toward red on each beat. Skipped during dash/slide (tween conflict) and
#    invuln-blinking (visibility toggle conflict). This adds visceral tension
#    without requiring the player to watch the HP bar.
func _update_low_hp_heartbeat(delta: float) -> void:
	var hp_ratio: float = float(GameManager.player_hp) / float(GameManager.player_max_hp) \
		if GameManager.player_max_hp > 0 else 1.0
	if hp_ratio > _HEARTBEAT_HP_THRESHOLD or hp_ratio <= 0.0:
		# Not in danger — ensure mesh scale is at rest (if it was pulsing)
		if mesh and not is_dashing and not is_sliding and not is_invuln_blinking:
			# Ease scale back to ONE only if it was offset by heartbeat
			mesh.scale = mesh.scale.lerp(Vector3.ONE, 1.0 - exp(-12.0 * delta))
		return
	if is_dashing or is_sliding or is_invuln_blinking:
		return  # Other systems own mesh.scale/visibility right now

	# Advance heartbeat phase (BPM → rad/s)
	_heartbeat_phase += delta * (_HEARTBEAT_BPM / 60.0) * TAU
	var beat_phase: float = fmod(_heartbeat_phase, TAU)  # 0..TAU per beat

	# Double-pulse "lub-dub": two Gaussian bumps, first at phase 0, second at ~0.35*TAU
	# The first pulse is stronger (the "lub"), the second is softer (the "dub").
	var pulse1: float = exp(-pow((beat_phase - 0.0) * 2.5, 2.0))       # First beat
	var pulse2: float = exp(-pow((beat_phase - TAU * 0.32) * 3.5, 2.0)) * 0.6  # Second beat (softer)
	var heartbeat: float = pulse1 + pulse2  # 0..~1.6

	# Apply scale pulse — grows outward on each beat, returns to 1.0 between beats
	if mesh:
		var pulse_scale: float = 1.0 + _HEARTBEAT_SCALE_AMP * heartbeat
		# Smooth toward the target so the pulse eases rather than snaps
		mesh.scale = mesh.scale.lerp(Vector3.ONE * pulse_scale, 1.0 - exp(-20.0 * delta))

	# Emission pulses red on each beat for a "danger" visual cue
	if _player_material and heartbeat > 0.01:
		var danger_blend: float = clampf(heartbeat * 0.4, 0.0, 0.5)
		var danger_color: Color = base_color.lerp(Color(1.0, 0.2, 0.15), danger_blend)
		_player_material.emission = danger_color * 0.4
		_player_material.emission_energy_multiplier = 1.0 + heartbeat * 0.8
	elif _player_material:
		# Between beats, ease emission back to the idle color
		var idle_emission: Color = base_color * 0.4
		_player_material.emission = _player_material.emission.lerp(idle_emission, 1.0 - exp(-8.0 * delta))

# ── Phase 6: Idle regen sparkle aura ──
# When the player is standing still and has high HP, spawn gentle green
# sparkles that float around them. When they start moving or take damage,
# the aura fades and is removed. Gives a calm "safe moment" visual.
func _update_idle_aura(delta: float) -> void:
	if is_dashing or is_sliding or is_invuln_blinking:
		_dismiss_idle_aura()
		return
	var hp_ratio: float = float(GameManager.player_hp) / float(GameManager.player_max_hp) \
		if GameManager.player_max_hp > 0 else 1.0
	var speed: float = velocity.length()
	var should_show: bool = hp_ratio >= _IDLE_AURA_HP_THRESHOLD and speed < _IDLE_AURA_SPEED_THRESHOLD
	if should_show:
		_idle_aura_timer += delta
		# Only spawn after being idle for 1.5 seconds (avoid flicker on brief stops)
		if _idle_aura_timer > 1.5 and not _idle_aura:
			var parent_node: Node = get_parent()
			if parent_node:
				_idle_aura = ParticleEffects.spawn_idle_regen_aura(parent_node, global_position)
		# Follow the player
		if _idle_aura and is_instance_valid(_idle_aura):
			_idle_aura.global_position = global_position
	else:
		_dismiss_idle_aura()

func _dismiss_idle_aura() -> void:
	if _idle_aura and is_instance_valid(_idle_aura):
		_idle_aura.emitting = false
		var aura: GPUParticles3D = _idle_aura
		_idle_aura = null
		# Let existing particles finish, then free
		var tree := get_tree()
		if tree:
			tree.create_timer(3.0).timeout.connect(aura.queue_free)
	_idle_aura_timer = 0.0

# ── Movement lean: tilts Zorp's mesh toward the velocity direction for a
#    sense of weight and momentum. The tilt is proportional to speed and
#    smoothed via exponential lerp. Skipped during dash/slide (their tweens
#    control mesh.scale and would conflict with rotation writes).
func _update_movement_lean(delta: float) -> void:
	# Skip lean during reverse-gravity dimension (mesh is flipped 180° on X)
	if DimensionSystem.gravity_reversed():
		return
	if is_dashing or is_sliding:
		# Ease back to upright when dash/slide starts
		var weight: float = 1.0 - exp(-_LEAN_SMOOTHING * delta)
		_lean_current = _lean_current.lerp(Vector3.ZERO, weight)
		if mesh:
			mesh.rotation.x = _lean_current.x
			mesh.rotation.z = _lean_current.z
		return

	# Desired lean: tilt around X (forward/back) and Z (left/right) based on
	# the horizontal velocity relative to the player's facing.
	# We use the *camera-relative* velocity so the lean matches what the
	# player sees, not world-space directions.
	var vel_horiz := Vector2(velocity.x, velocity.z)
	var speed_frac: float = clampf(vel_horiz.length() / GameConstants.PLAYER_SPEED, 0.0, 1.0)

	# Get camera right and forward on XZ plane for camera-relative lean
	var cam: Camera3D = get_viewport().get_camera_3d()
	var target_x: float = 0.0
	var target_z: float = 0.0
	if cam and speed_frac > 0.01:
		var fwd := -cam.global_basis.z
		fwd.y = 0
		fwd = fwd.normalized()
		var right := cam.global_basis.x
		right.y = 0
		right = right.normalized()
		# Project velocity onto camera axes
		var vel_xz := Vector3(velocity.x, 0, velocity.z)
		var forward_component: float = vel_xz.dot(fwd) / GameConstants.PLAYER_SPEED
		var right_component: float = vel_xz.dot(right) / GameConstants.PLAYER_SPEED
		# Tilt forward when moving forward (negative X rotation = lean forward)
		# Tilt sideways when strafing (positive Z rotation = lean right)
		target_x = -forward_component * _LEAN_MAX_ANGLE
		target_z = -right_component * _LEAN_MAX_ANGLE

	var w: float = 1.0 - exp(-_LEAN_SMOOTHING * delta)
	_lean_current.x = lerpf(_lean_current.x, target_x, w)
	_lean_current.z = lerpf(_lean_current.z, target_z, w)

	if mesh:
		mesh.rotation.x = _lean_current.x
		mesh.rotation.z = _lean_current.z

# ── Landing squash + dust puff: plays when Zorp touches down after being
#    airborne (reverse-gravity exit, bounce pad, etc.). The mesh squashes
#    flat then bounces back with elastic easing — the same juice language
#    as the dash squash — and a small dust burst + camera nudge sells the
#    impact. Skipped during dash/slide (their tweens own mesh.scale).
func _play_landing_effect() -> void:
	if is_dashing or is_sliding:
		return
	if mesh:
		var land_tween := create_tween()
		# Squash flat: wide and short (impact frame)
		land_tween.tween_property(mesh, "scale", Vector3(1.5, 0.4, 1.5), 0.08) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_CUBIC)
		# Bounce back to normal with elastic overshoot for a juicy recovery
		land_tween.tween_property(mesh, "scale", Vector3.ONE, 0.22) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_ELASTIC)
	# Dust puff at Zorp's feet — uses the death poof with a neutral dust color
	ParticleEffects.spawn_death_poof(get_parent(), global_position + Vector3(0, 0.1, 0),
		Color(0.7, 0.65, 0.55), 0.6)
	# Small camera shake on landing for weight
	_trigger_camera_trauma(0.12)

# ── Damage impact reaction ── When the player takes damage, Zorp's mesh
#    squashes flat (compressed vertically, stretched horizontally) and the
#    emission flashes red, then bounces back with elastic easing. This gives
#    a visceral "I got hit" read that complements the camera shake and
#    invuln blink — the player feels the impact through the mesh itself,
#    not just the screen. Skipped during dash/slide (their tweens own
#    mesh.scale) and uses a tracked tween so repeated hits don't stack.
#    The squash direction is biased away from the damage source so Zorp
#    visibly recoils from the attacker.
var _dmg_squash_tween: Tween = null
func _on_player_damaged(source_pos: Vector3) -> void:
	# Skip if dash/slide tweens own mesh.scale — we'd fight them.
	if is_dashing or is_sliding:
		return
	if not mesh:
		return
	# Kill any in-progress damage squash so the new hit restarts the pop
	if _dmg_squash_tween and _dmg_squash_tween.is_valid():
		_dmg_squash_tween.kill()
	# Determine recoil direction (horizontal, away from source). If no
	# source position, default to a uniform squash.
	var recoil_dir: Vector3 = Vector3.ZERO
	if source_pos != Vector3.ZERO:
		recoil_dir = (global_position - source_pos)
		recoil_dir.y = 0
		if recoil_dir.length_squared() > 0.01:
			recoil_dir = recoil_dir.normalized()
	# Squash: compress vertically, stretch horizontally. The stretch is
	# biased slightly toward the recoil direction so Zorp "flinches" away
	# from the hit. This is the same juice language as the dash/landing
	# squash but tuned for a hit (faster, sharper, less overshoot).
	_dmg_squash_tween = create_tween()
	# Impact frame: flat squash in 50ms (sharp, almost a freeze-frame)
	_dmg_squash_tween.tween_property(mesh, "scale",
		Vector3(1.35, 0.55, 1.35), 0.05) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# Recoil bounce back with elastic for a wobbly recovery
	_dmg_squash_tween.tween_property(mesh, "scale", Vector3.ONE, 0.28) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	# Emission flash red on the hit frame — a brief red glow that fades
	# back to the idle/base color. This sells the "pain" read even in dark
	# biomes where the silhouette squash might be hard to see. We tween
	# emission_energy_multiplier down from a spike; the color is set
	# directly to red and eased back by the idle/heartbeat systems.
	if _player_material:
		_player_material.emission = Color(1.0, 0.15, 0.1)
		_player_material.emission_energy_multiplier = 3.0
		var emit_tween := create_tween()
		emit_tween.tween_property(_player_material, "emission_energy_multiplier",
			1.0, 0.3) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		# Emission color eases back to base_color * 0.4 (the idle emission)
		emit_tween.parallel().tween_property(_player_material, "emission",
			base_color * 0.4, 0.35) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

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
	# ── Phase 17: Dynamic Weather — snow storm slows movement ──
	speed_mult *= WeatherSystem.get_speed_multiplier()
	# ── Phase 7: Monolith Speed Surge buff ──
	speed_mult *= GameManager.get_speed_buff_mult()
	# ── Phase 23: Time Warden slow field — player slowed inside the field ──
	# The warden's slow field is a positional effect; we query the static
	# registry for the strongest overlapping field at the player's position.
	# This is applied AFTER the other multipliers so it compounds with weather
	# and dimension effects (a Time Warden in a Time-Slow dimension is brutal).
	if EnemyTimeWarden:
		speed_mult *= EnemyTimeWarden.get_player_slow_mult(global_position)
	# ── Phase 25: Progression System speed bonus (skill tree) ──
	if ProgressionSystem:
		speed_mult *= ProgressionSystem.get_speed_mult()
	# ── Phase 7: Tier-based speed bonus (+0.5 m/s per 5 levels) ──
	var tier: int = (GameManager.player_level - 1) / GameConstants.PLAYER_LEVEL_DIFFICULTY_INTERVAL
	var base_speed: float = GameConstants.PLAYER_SPEED + tier * GameConstants.PLAYER_LEVEL_SPEED_TIER_BONUS
	if move_direction.length_squared() > 0.01:
		velocity_target = move_direction * base_speed * speed_mult
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
		# ── Phase 9: Dash afterimage — spawn ghost copies at intervals ──
		_afterimage_timer -= delta
		if _afterimage_timer <= 0.0:
			_spawn_dash_afterimage()
			_afterimage_timer = AFTERIMAGE_INTERVAL
		if dash_timer <= 0:
			is_dashing = false
			GameManager.player_is_dashing = false
			dash_ended.emit()
			# ── Phase 8: Transition into physics slide (carry dash momentum)
			_start_slide(dash_direction * GameConstants.PLAYER_DASH_SPEED)
		return

	# Consume buffered dash if cooldown is ready (or coyote window is active)
	var can_dash: bool = GameManager.player_dash_cooldown_timer <= 0 or _dash_coyote_timer > 0
	if _dash_buffer_timer > 0 and can_dash:
		_dash_buffer_timer = 0.0
		_dash_coyote_timer = 0.0  # Consume coyote window
		_start_dash()
	elif Input.is_action_just_pressed("dash"):
		if can_dash:
			_dash_coyote_timer = 0.0  # Consume coyote window
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
	# Phase 17: Snow Storm reduces friction → slidey surfaces (slide lasts longer)
	var friction_base: float = GameConstants.DASH_SLIDE_FRICTION
	friction_base = pow(friction_base, WeatherSystem.get_friction_multiplier())
	var friction_factor: float = pow(friction_base, delta * 60.0)
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
		# Small camera shake on wall bump — biased toward the wall normal
		_trigger_camera_trauma(0.1, normal)
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

	# ── Phase 9: Dash afterimage during slide — spawn ghosts while sliding fast
	if slide_velocity.length() > GameConstants.DASH_SLIDE_MIN_SPEED * 2.0:
		_afterimage_timer -= delta
		if _afterimage_timer <= 0.0:
			_spawn_dash_afterimage()
			_afterimage_timer = AFTERIMAGE_INTERVAL * 1.5  # Slightly slower during slide

func _start_dash() -> void:
	is_dashing = true
	dash_timer = GameConstants.PLAYER_DASH_DURATION
	dash_direction = move_direction if move_direction.length_squared() > 0.01 else get_forward_dir_fallback()
	# ── Phase 25: Progression System dash cooldown multiplier (skill tree) ──
	var dash_cd: float = GameConstants.PLAYER_DASH_COOLDOWN
	if ProgressionSystem:
		dash_cd *= ProgressionSystem.get_dash_cooldown_mult()
	GameManager.player_dash_cooldown_timer = dash_cd
	GameManager.player_invuln_timer = max(GameManager.player_invuln_timer, GameConstants.PLAYER_DASH_INVULN_DURATION)
	GameManager.player_is_dashing = true
	dash_started.emit()
	# ── Phase 25: Statistics tracking ──
	if Statistics:
		Statistics.record_dash()

	# Camera shake on dash for punch
	_trigger_camera_trauma(0.15)

	# FOV kick — briefly widen the camera FOV for a speed sensation. The camera
	# eases the FOV back to default in _process, so this is a one-shot nudge.
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("kick_fov"):
		cam_rig.kick_fov(GameConstants.CAMERA_DASH_FOV_KICK)

	# Phase 6: Dash trail particles
	ParticleEffects.spawn_dash_trail(get_parent(), global_position, base_color)
	# Phase 20: Audio — dash SFX
	AudioManager.play_sfx(AudioManager.SFX_DASH)

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

# ── Phase 9: Dash afterimage (ghost trail) ─────────────────────────────────────
## Spawns a semi-transparent mesh copy at the player's current position that
## fades out over AFTERIMAGE_LIFETIME seconds. The ghost uses the player's
## base color with decreasing alpha, creating a trailing afterimage effect
## during dash. Each ghost is a simple MeshInstance3D with an unlit material
## that tweens alpha to 0, then queue_free()s itself.
func _spawn_dash_afterimage() -> void:
	var parent_node: Node = get_parent()
	if not parent_node:
		return

	# Create the ghost mesh — a sphere matching the player's approximate shape
	var ghost := MeshInstance3D.new()
	var ghost_sphere := SphereMesh.new()
	ghost_sphere.radius = 0.5
	ghost_sphere.height = 1.0
	ghost_sphere.radial_segments = 8
	ghost_sphere.rings = 4
	ghost.mesh = ghost_sphere

	# Unlit transparent material in the player's color
	var ghost_mat := StandardMaterial3D.new()
	ghost_mat.albedo_color = Color(base_color.r, base_color.g, base_color.b, AFTERIMAGE_MAX_ALPHA)
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.emission_enabled = true
	ghost_mat.emission = base_color * 0.3
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost.material_override = ghost_mat

	# Position at player's current location, matching scale
	parent_node.add_child(ghost)
	ghost.global_position = global_position
	ghost.global_rotation = global_rotation
	ghost.scale = mesh.scale if mesh else Vector3.ONE

	# Fade out + slight scale up for a "dissipating energy" look
	# Tween the material alpha directly (tween_property on the Resource works
	# because StandardMaterial3D.albedo_color is a Color and we can write its
	# 'a' component via a property path). We also scale the ghost up slightly
	# for a dispersing energy effect.
	var fade_tween := ghost.create_tween()
	fade_tween.set_parallel(true)
	# Tween alpha: Color.a is a sub-property of albedo_color on the material
	fade_tween.tween_property(ghost_mat, "albedo_color:a", 0.0, AFTERIMAGE_LIFETIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Slightly scale up as it fades (energy dispersing)
	fade_tween.tween_property(ghost, "scale",
		ghost.scale * 1.3, AFTERIMAGE_LIFETIME
	).set_ease(Tween.EASE_OUT)
	# Free after fade completes
	fade_tween.chain().tween_callback(ghost.queue_free)

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
				# Phase 20: Audio — dash bump SFX
				AudioManager.play_sfx(AudioManager.SFX_DASH_BUMP)

# ── Phase 8: Smash destructibles in dash path ──────────────────────────────────
func _dash_smash_destructibles() -> void:
	for prop in get_tree().get_nodes_in_group("destructibles"):
		if not is_instance_valid(prop):
			continue
		if global_position.distance_to(prop.global_position) < 2.0:
			if prop.has_method("take_damage_from"):
				prop.take_damage_from(999, global_position)  # Instant smash
	# ── Phase 26: Breakable walls take dash damage ──
	for obj in get_tree().get_nodes_in_group("interactive_object"):
		if not is_instance_valid(obj):
			continue
		if "object_type" in obj and obj.object_type == "breakable_wall":
			if global_position.distance_to(obj.global_position) < 2.5:
				if obj.has_method("dash_hit"):
					obj.dash_hit()

func get_forward_dir_fallback() -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam:
		var fwd := -cam.global_basis.z
		fwd.y = 0
		return fwd.normalized()
	return Vector3.FORWARD

func _handle_invuln_blink(delta: float) -> void:
	if GameManager.player_invuln_timer > 0:
		is_invuln_blinking = true
		# ── Phase 4: Dash invulnerability blink effect polish ──
		# Instead of a crude 50/50 visibility toggle, use a smooth sinusoidal
		# blink that eases in/out, plus an emission flash on the mesh material
		# for a "phasing through danger" shimmer effect.
		var blink_phase: float = fmod(GameManager.player_invuln_timer * GameConstants.PLAYER_BLINK_RATE, 1.0)
		# Smooth sine-wave blink: visible most of the time, brief dips to ~20% opacity
		var blink_t: float = 0.5 + 0.5 * sin(blink_phase * TAU)
		blink_visible = blink_t > 0.15

		if mesh:
			mesh.visible = blink_visible
			# Emission flash during invuln — pulsing white-cyan shimmer
			if _player_material:
				var flash_intensity: float = 0.5 + 0.5 * sin(blink_phase * TAU * 2.0)
				_player_material.emission_energy_multiplier = 1.0 + flash_intensity * 2.5
				# Tint emission slightly cyan during invuln
				_player_material.emission = Color(0.6, 1.0, 1.0)
	else:
		is_invuln_blinking = false
		if mesh:
			mesh.visible = true
		# Reset emission to normal (match the idle emission intensity used
		# everywhere else — base_color * 0.4, NOT raw base_color, which would
		# be 2.5× brighter and cause a visible emission pop when blink ends).
		# IMPORTANT: if a biome mutation is active, the player's albedo+emission
		# are tinted toward the mutation color (see _update_mutation_material).
		# Hardcoding base_color * 0.4 here would wipe the mutation tint, causing
		# Zorp to flash back to plain green for the rest of the mutation. Instead
		# we delegate to _update_mutation_material(), which restores the correct
		# blended color (or base_color if no mutation is active). This keeps the
		# invuln-blink reset consistent with the mutation system's color state.
		if _player_material:
			_player_material.emission_energy_multiplier = 1.0
			_update_mutation_material()

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
	
	# Pause toggle is handled by the PauseMenu node (Phase 20)
	
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

	# ── Phase 26: Interact key (T) — talk to NPCs, activate switches ──
	if event.is_action_pressed("interact") and not GameManager.is_paused and GameManager.player_is_alive:
		_try_interact()

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
	# Phase 16: Apply weapon mod fire rate multiplier
	var cooldown: float = GameConstants.SHOOT_COOLDOWN
	if WeaponModSystem:
		cooldown *= WeaponModSystem.get_equipped_fire_rate_mult()
	# Phase 17: Solar Flare weather boosts fire rate
	cooldown *= WeatherSystem.get_fire_rate_multiplier()
	# ── Phase 25: Progression System fire rate bonus (skill tree) ──
	if ProgressionSystem:
		cooldown *= ProgressionSystem.get_fire_rate_mult()
	shoot_cooldown_timer = cooldown
	_spawn_projectile()
	# ── Phase 25: Statistics tracking ──
	if Statistics:
		Statistics.record_shot()

## Try to shoot; if on cooldown, buffer the input so it fires as soon as ready.
## This prevents dropped clicks during rapid fire and makes shooting feel snappy.
func _try_shoot_or_buffer() -> void:
	if shoot_cooldown_timer > 0:
		# Buffer the shot — it will fire when cooldown expires (if within window)
		_shoot_buffer_timer = SHOOT_BUFFER_WINDOW
		return
	_shoot_buffer_timer = 0.0
	# Phase 16: Apply weapon mod fire rate multiplier
	var cooldown: float = GameConstants.SHOOT_COOLDOWN
	if WeaponModSystem:
		cooldown *= WeaponModSystem.get_equipped_fire_rate_mult()
	# Phase 17: Solar Flare weather boosts fire rate
	cooldown *= WeatherSystem.get_fire_rate_multiplier()
	# ── Phase 25: Progression System fire rate bonus (skill tree) ──
	if ProgressionSystem:
		cooldown *= ProgressionSystem.get_fire_rate_mult()
	shoot_cooldown_timer = cooldown
	_spawn_projectile()
	# ── Phase 25: Statistics tracking ──
	if Statistics:
		Statistics.record_shot()

func _spawn_projectile() -> void:
	var shoot_dir := get_shoot_direction()
	# ── Phase 16: Weapon Mod Crafting — apply mod to projectile spawning ──
	# The equipped mod changes damage, fire rate, projectile speed, color, and behavior.
	var mod_id: int = GameConstants.WeaponMod.NONE
	var mod_color: Color = Color(0.2, 1.0, 0.8)
	var mod_dmg_mult: float = 1.0
	var mod_speed_mult: float = 1.0
	if WeaponModSystem:
		mod_id = WeaponModSystem.get_equipped_mod()
		mod_color = WeaponModSystem.get_equipped_color()
		mod_dmg_mult = WeaponModSystem.get_equipped_damage_mult()
		mod_speed_mult = WeaponModSystem.get_equipped_speed_mult()
	
	# Base damage scales with player level (matches original Ursina: level * bonus)
	# ── Phase 7: Tier-based damage scaling (+1 per 5 levels) ──
	var tier: int = (GameManager.player_level - 1) / GameConstants.PLAYER_LEVEL_DIFFICULTY_INTERVAL
	var level_dmg: int = GameManager.player_level * GameConstants.PROJECTILE_LEVEL_DAMAGE_BONUS + tier * GameConstants.PLAYER_LEVEL_DMG_TIER_BONUS
	var base_dmg: int = GameConstants.PROJECTILE_BASE_DAMAGE + level_dmg
	# ── Phase 7: Monolith Power Surge damage buff ──
	base_dmg = int(base_dmg * GameManager.get_damage_buff_mult())
	# ── Phase 25: Progression System damage multiplier (skill tree) ──
	if ProgressionSystem:
		base_dmg = int(base_dmg * ProgressionSystem.get_damage_mult())
	var mod_dmg: int = int(base_dmg * mod_dmg_mult)
	var mod_speed: float = GameConstants.PROJECTILE_SPEED * mod_speed_mult
	
	# Spawn projectiles based on the equipped mod's behavior pattern
	# ── Phase 25: Extra projectiles from Multishot skill (Combat branch) ──
	var extra_bolts: int = 0
	if ProgressionSystem:
		extra_bolts = ProgressionSystem.get_extra_projectiles()
	match mod_id:
		GameConstants.WeaponMod.SPREAD_SHOT:
			# Three bolts in a fan pattern
			_spawn_single_projectile(shoot_dir, mod_dmg, mod_speed, mod_color)
			_spawn_single_projectile(shoot_dir.rotated(Vector3.UP, 0.2), mod_dmg, mod_speed, mod_color)
			_spawn_single_projectile(shoot_dir.rotated(Vector3.UP, -0.2), mod_dmg, mod_speed, mod_color)
			# Extra bolts from skill tree — add tighter fan bolts
			for i in range(extra_bolts):
				var angle: float = 0.1 * (1 if i % 2 == 0 else -1) * ((i / 2) + 1)
				_spawn_single_projectile(shoot_dir.rotated(Vector3.UP, angle), mod_dmg, mod_speed, mod_color)
		GameConstants.WeaponMod.QUANTUM_OVERDRIVE:
			# Triple-bolt with homing + chain (mega mod)
			_spawn_single_projectile(shoot_dir, mod_dmg, mod_speed, mod_color, mod_id)
			_spawn_single_projectile(shoot_dir.rotated(Vector3.UP, 0.15), mod_dmg, mod_speed, mod_color, mod_id)
			_spawn_single_projectile(shoot_dir.rotated(Vector3.UP, -0.15), mod_dmg, mod_speed, mod_color, mod_id)
			# Extra bolts from skill tree
			for i in range(extra_bolts):
				var angle: float = 0.08 * (1 if i % 2 == 0 else -1) * ((i / 2) + 1)
				_spawn_single_projectile(shoot_dir.rotated(Vector3.UP, angle), mod_dmg, mod_speed, mod_color, mod_id)
		_:
			# All other mods fire a single projectile (behavior is handled by the projectile itself)
			_spawn_single_projectile(shoot_dir, mod_dmg, mod_speed, mod_color, mod_id)
			# Extra bolts from skill tree — add side-firing bolts at tight angles
			for i in range(extra_bolts):
				var angle: float = 0.12 * (1 if i % 2 == 0 else -1) * ((i / 2) + 1)
				_spawn_single_projectile(shoot_dir.rotated(Vector3.UP, angle), mod_dmg, mod_speed, mod_color, mod_id)

	# ── Phase 20: Audio — shoot SFX (played ONCE per shot, not per bolt) ──
	# Multi-bolt mods (Spread Shot, Quantum Overdrive, Multishot skill) all fire
	# from _spawn_single_projectile, but the SFX must only play once per trigger
	# pull — otherwise 3+ identical SFX_SHOOT samples layer on the same frame
	# into a muddy, over-loud "chunk". Playing it here (after the match) means
	# every shot — single, spread, or multishot — has identical perceived volume
	# and timbre, so rapid fire stays crisp and distinct.
	AudioManager.play_sfx(AudioManager.SFX_SHOOT)

## Spawn a single projectile with the given parameters. The mod_id is passed to
## the projectile so it can apply behavior-specific logic (homing, bouncing, etc.).
func _spawn_single_projectile(shoot_dir: Vector3, dmg: int, spd: float, col: Color, mod_id: int = GameConstants.WeaponMod.NONE) -> void:
	var proj: Area3D = PROJECTILE_SCENE.instantiate()
	# Set properties BEFORE adding to tree so _ready() picks them up.
	# This is critical for set_weapon_mod() — _ready() checks _weapon_mod
	# and _mod_color to decide whether to create a per-projectile material
	# with the mod color. If we set these after add_child(), _ready() runs
	# with defaults (NONE / cyan) and the mod color is never applied to the
	# projectile's visual material.
	proj.set("direction", shoot_dir)
	proj.set("damage", dmg)
	proj.set("speed", spd)
	# Phase 24: Black Hole Launcher has a shorter lifetime so it auto-collapses
	# at the configured distance (the bolt travels forward then collapses).
	if mod_id == GameConstants.WeaponMod.BLACK_HOLE_LAUNCHER:
		proj.set("lifetime", GameConstants.BLACK_HOLE_LAUNCHER_LIFETIME)
	if proj.has_method("set_weapon_mod"):
		proj.set_weapon_mod(mod_id, col)
	get_parent().add_child(proj)
	proj.global_position = global_position + Vector3(0, 0.5, 0)

	# NOTE: Shoot SFX is played once per shot in _spawn_projectile(), not here.
	# Multi-bolt mods (Spread Shot fires 3, Quantum Overdrive fires 3+) used
	# to play SFX_SHOOT once per bolt, layering 3+ identical shots on the same
	# frame into a muddy, over-loud "chunk". Playing it once per shot keeps
	# every shot — single or spread — at the same perceived volume and timbre,
	# so rapid fire stays crisp and distinct.
	# Quick scale pulse on shoot for juicy feedback (skip if dashing to avoid tween conflict)
	if mesh and not is_dashing:
		var pulse_tween := create_tween()
		pulse_tween.tween_property(mesh, "scale", Vector3.ONE * 1.12, 0.04) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_CUBIC)
		pulse_tween.tween_property(mesh, "scale", Vector3.ONE, 0.07) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_ELASTIC)

	# ── Muzzle flash: a brief OmniLight3D at the shoot origin that flares the
	#    projectile's color, then fades in ~60ms. This adds a punchy light burst
	#    at the gun tip that sells the shot in dark biomes and gives shooting a
	#    visceral "pop" — even a tiny light kick reads as energy discharge. The
	#    light is added to the parent (not the projectile) so it stays at the
	#    muzzle position instead of traveling with the bolt. Color matches the
	#    equipped weapon mod for cohesive visual language.
	var muzzle_light := OmniLight3D.new()
	muzzle_light.light_color = col if mod_id != GameConstants.WeaponMod.NONE else Color(0.2, 1.0, 0.8)
	muzzle_light.light_energy = 4.0
	muzzle_light.omni_range = 3.5
	muzzle_light.omni_attenuation = 1.5
	get_parent().add_child(muzzle_light)
	muzzle_light.global_position = global_position + Vector3(0, 0.5, 0)
	var muzzle_tween := muzzle_light.create_tween()
	muzzle_tween.tween_property(muzzle_light, "light_energy", 0.0, 0.06) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	muzzle_tween.tween_callback(muzzle_light.queue_free)

	# Subtle camera micro-recoil on each shot — a tiny trauma kick that makes
	# shooting feel punchy without being distracting. At ~9 shots/sec this stays
	# well below the shake decay threshold so it never accumulates into a wobble.
	# Dash already triggers a larger 0.15 trauma, so this 0.015 is a feather-touch.
	_trigger_camera_trauma(0.015)

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
	# ── Phase 19: Co-op — report pulse wave for mega pulse sync ──
	CoOpManager.report_pulse_wave(true, global_position)
	# Spawn pulse wave at player position
	var pulse: Node3D = PULSE_WAVE_SCENE.instantiate()
	get_parent().add_child(pulse)
	pulse.global_position = global_position
	# Camera shake on pulse wave
	_trigger_camera_trauma(0.25)
	# Phase 20: Audio — pulse wave SFX
	AudioManager.play_sfx(AudioManager.SFX_PULSE_WAVE)
	# ── Phase 25: Statistics tracking ──
	if Statistics:
		Statistics.record_pulse_wave()

## Try to fire the pulse wave; if on cooldown, buffer the input so it fires
## as soon as ready. Mirrors the dash and shoot buffering pattern so all three
## player actions feel equally responsive.
func _try_pulse_wave_or_buffer() -> void:
	if pulse_wave_cooldown_timer > 0:
		_pulse_buffer_timer = PULSE_BUFFER_WINDOW
		return
	_pulse_buffer_timer = 0.0
	_use_pulse_wave()

func _trigger_camera_trauma(amount: float, bias_dir: Vector3 = Vector3.ZERO) -> void:
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(amount, bias_dir)

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

# ── Phase 26: Interact — talk to NPCs, activate switches ──
## Find the nearest interactable NPC or switch within range and activate it.
## Prioritizes dialogue NPCs, then interactive objects (switches).
func _try_interact() -> void:
	# If a dialogue panel is active, the panel handles the interact key itself.
	if DialoguePanel and DialoguePanel.is_active():
		return
	var best_npc: Node = null
	var best_npc_dist: float = GameConstants.DIALOGUE_INTERACT_RANGE
	for npc in get_tree().get_nodes_in_group("dialogue_npc"):
		if not is_instance_valid(npc):
			continue
		if not npc.has_method("can_interact") or not npc.can_interact():
			continue
		var d: float = global_position.distance_to(npc.global_position)
		if d < best_npc_dist:
			best_npc_dist = d
			best_npc = npc
	if best_npc:
		best_npc.interact()
		return
	# Otherwise, try interactive objects (switches).
	var best_switch: Node = null
	var best_switch_dist: float = GameConstants.INTERACTIVE_INTERACT_RANGE
	for obj in get_tree().get_nodes_in_group("interactive_object"):
		if not is_instance_valid(obj):
			continue
		if not obj.has_method("can_interact") or not obj.can_interact():
			continue
		var d2: float = global_position.distance_to(obj.global_position)
		if d2 < best_switch_dist:
			best_switch_dist = d2
			best_switch = obj
	if best_switch:
		best_switch.interact()

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
		# Phase 20: Audio — pet summon SFX
		AudioManager.play_sfx(AudioManager.SFX_PET)
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