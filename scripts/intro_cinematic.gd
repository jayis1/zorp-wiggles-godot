## Zorp Wiggles — Intro Cinematic (Phase 30: Visual & Audio Polish)
## Procedural landing animation shown once at the start of each run. Zorp
## descends from the sky in a pod of light, impacts the ground with a dust
## ring + camera shake, then the camera pulls back to the gameplay angle as
## the HUD fades in and gameplay begins.
##
## The cinematic is a self-contained Node3D added to the main scene. It runs
## in three phases:
##   1. DESCEND (1.8s) — Zorp falls from y=40 to y=0.5 inside a glowing light
##      column. A vertical trail of particles streams behind. The camera
##      follows from a high angle.
##   2. IMPACT (0.4s) — Dust ring expands, screen flashes, camera shakes,
##      light column dissipates. Zorp squashes on landing (reusing the
##      existing landing-squash language).
##   3. SETTLE (0.8s) — Camera eases back to the gameplay orbit angle, HUD
##      fades in, gameplay controls unlock.
##
## During the cinematic, player input is suppressed (the player can't move or
## shoot until SETTLE completes). Enemy spawning is also delayed by the
## EnemySpawner's existing spawn timer, so the world is calm for the intro.

extends Node3D

enum Phase { DESCEND, IMPACT, SETTLE, DONE }

var _phase: int = Phase.DESCEND
var _phase_t: float = 0.0
var _player: CharacterBody3D = null
var _camera_rig: Node3D = null
var _light_column: OmniLight3D = null
var _trail_particles: GPUParticles3D = null
var _dust_ring: MeshInstance3D = null
var _hud: CanvasLayer = null
var _hud_fade_rect: ColorRect = null  # Opaque overlay that hides the HUD during the cinematic
var _saved_cam_distance: float = 22.0
var _saved_cam_pitch: float = -55.0
var _saved_player_process_mode: int = 0
var _controls_unlocked: bool = false

const DESCEND_DURATION: float = 1.8
const IMPACT_DURATION: float = 0.4
const SETTLE_DURATION: float = 0.8
const START_HEIGHT: float = 40.0
const END_HEIGHT: float = 0.5
const COLUMN_COLOR: Color = Color(0.4, 1.0, 0.8, 1.0)  # Cyan-green alien light


func _ready() -> void:
	# Find player + camera + HUD
	var main: Node = get_tree().current_scene
	if not main:
		queue_free()
		return
	_player = main.get_node_or_null("World/Player")
	_camera_rig = main.get_node_or_null("CameraRig")
	_hud = main.get_node_or_null("HUD")
	if not _player or not is_instance_valid(_player):
		queue_free()
		return
	# Suppress player input during the cinematic — set process mode to
	# DISABLED so _physics_process and _unhandled_input don't fire. We
	# restore it on completion. We can't use PROCESS_MODE_ALWAYS because
	# that's needed for pause; instead we use a flag on the player.
	_saved_player_process_mode = _player.process_mode
	# We don't fully disable the player (it needs _physics_process for the
	# landing-squash animation to play). Instead we set a global flag on
	# GameManager that the player checks. We add a meta flag.
	_player.set_meta("cinematic_active", true)
	# Build the light column following the player
	_light_column = OmniLight3D.new()
	_light_column.light_color = COLUMN_COLOR
	_light_column.light_energy = 4.0
	_light_column.omni_range = 12.0
	_light_column.omni_attenuation = 1.2
	add_child(_light_column)
	# Trail particles — vertical streak falling with the player
	_trail_particles = GPUParticles3D.new()
	_trail_particles.amount = 40
	_trail_particles.lifetime = 0.6
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)  # Upward (relative to player moving down)
	mat.spread = 12.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, 0, 0)
	mat.color = COLUMN_COLOR
	mat.scale_min = 0.2
	mat.scale_max = 0.5
	_trail_particles.process_material = mat
	var trail_mesh := SphereMesh.new()
	trail_mesh.radius = 0.15
	trail_mesh.height = 0.3
	_trail_particles.draw_pass_1 = trail_mesh
	add_child(_trail_particles)
	# Place player at start height
	_player.global_position = Vector3(0, START_HEIGHT, 0)
	# Position the cinematic node at the player's XZ
	global_position = Vector3(0, 0, 0)
	# Override camera pitch for the descend (looking down at the falling Zorp)
	if _camera_rig and _camera_rig.has_method("set_camera_pitch"):
		# Save the current pitch from the rig's actual rotation (the rig eases
		# rotation_degrees.x toward _target_pitch, so rotation_degrees.x is
		# the live value). Fall back to the default -55° if something is off.
		_saved_cam_pitch = _camera_rig.rotation_degrees.x if _camera_rig else -55.0
		_camera_rig.set_camera_pitch(-75.0)  # Steeper top-down view
	# Hide HUD during cinematic — CanvasLayer has no modulate property, so we
	# create a full-screen opaque ColorRect as a child of the HUD and fade it
	# out during the SETTLE phase. This effectively "reveals" the HUD.
	if _hud:
		_hud_fade_rect = ColorRect.new()
		_hud_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_hud_fade_rect.color = Color(0.03, 0.03, 0.10, 1.0)  # Match menu bg
		_hud_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud.add_child(_hud_fade_rect)
		# Push it to the top of the HUD's draw order
		_hud.move_child(_hud_fade_rect, -1)
	# Lock controls
	_controls_unlocked = false
	print("[IntroCinematic] Starting landing sequence")


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_finish()
		return
	# If the cinematic has already finished (Phase.DONE), don't run update logic
	if _phase == Phase.DONE:
		return
	_phase_t += delta
	# Position the light column + trail at the player's location
	if is_instance_valid(_light_column):
		_light_column.global_position = _player.global_position + Vector3(0, 1, 0)
	if is_instance_valid(_trail_particles):
		_trail_particles.global_position = _player.global_position
	match _phase:
		Phase.DESCEND:
			_update_descend(delta)
		Phase.IMPACT:
			_update_impact(delta)
		Phase.SETTLE:
			_update_settle(delta)


func _update_descend(delta: float) -> void:
	var t: float = clampf(_phase_t / DESCEND_DURATION, 0.0, 1.0)
	# Ease-in acceleration (gravity-like): start slow, accelerate
	var eased: float = t * t
	var y: float = lerpf(START_HEIGHT, END_HEIGHT, eased)
	_player.global_position = Vector3(0, y, 0)
	# Spin the player slowly for visual interest
	var pm: Variant = _player.get("mesh")
	if pm and is_instance_valid(pm):
		pm.rotation.y = t * TAU * 0.5
	# Fade the light column intensity as we approach impact
	if is_instance_valid(_light_column):
		_light_column.light_energy = lerpf(4.0, 8.0, t)
	# Camera follows from above; the camera rig's existing follow logic
	# handles XZ tracking. We just rely on the pitch override set in _ready.
	if t >= 1.0:
		_enter_impact()


func _enter_impact() -> void:
	_phase = Phase.IMPACT
	_phase_t = 0.0
	# Spawn dust ring
	_dust_ring = MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.5
	ring_mesh.bottom_radius = 0.5
	ring_mesh.height = 0.1
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.7, 0.65, 0.5, 0.6)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dust_ring.material_override = ring_mat
	_dust_ring.mesh = ring_mesh
	_dust_ring.global_position = Vector3(0, 0.1, 0)
	add_child(_dust_ring)
	# Camera shake
	if _camera_rig and _camera_rig.has_method("add_trauma"):
		_camera_rig.add_trauma(0.6)
	# Play impact SFX
	AudioManager.play_sfx(AudioManager.SFX_EXPLOSION)
	# Squash the player mesh on landing (reuse the existing landing-squash
	# language — the player's _play_landing_effect handles this, but the
	# player is in cinematic mode so we do it directly here)
	var pm2: Variant = _player.get("mesh")
	if pm2 and is_instance_valid(pm2):
		var tw := create_tween()
		tw.tween_property(pm2, "scale", Vector3(1.5, 0.4, 1.5), 0.08).set_ease(Tween.EASE_OUT)
		tw.tween_property(pm2, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	# Flash the light column
	if is_instance_valid(_light_column):
		_light_column.light_energy = 15.0
	# Stop the trail
	if is_instance_valid(_trail_particles):
		_trail_particles.emitting = false


func _update_impact(delta: float) -> void:
	var t: float = clampf(_phase_t / IMPACT_DURATION, 0.0, 1.0)
	# Expand the dust ring
	if _dust_ring and is_instance_valid(_dust_ring):
		var scale_val: float = lerpf(1.0, 8.0, t)
		_dust_ring.scale = Vector3(scale_val, 1.0, scale_val)
		var mat: Material = _dust_ring.material_override
		if mat is StandardMaterial3D:
			mat.albedo_color.a = lerpf(0.6, 0.0, t)
	# Fade the light column
	if is_instance_valid(_light_column):
		_light_column.light_energy = lerpf(15.0, 0.0, t)
	if t >= 1.0:
		_enter_settle()


func _enter_settle() -> void:
	_phase = Phase.SETTLE
	_phase_t = 0.0
	# Restore camera pitch to gameplay angle
	if _camera_rig and _camera_rig.has_method("set_camera_pitch"):
		_camera_rig.set_camera_pitch(_saved_cam_pitch)
	# Fade HUD in — fade the opaque overlay out so the HUD is revealed
	if _hud and _hud_fade_rect:
		var tw := create_tween()
		tw.tween_property(_hud_fade_rect, "color:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)
	# Unlock controls
	_controls_unlocked = true
	if is_instance_valid(_player) and _player.has_meta("cinematic_active"):
		_player.remove_meta("cinematic_active")
	# Fade out the light column + dust ring
	if _light_column and is_instance_valid(_light_column):
		var tw2 := create_tween()
		tw2.tween_property(_light_column, "light_energy", 0.0, 0.5).set_ease(Tween.EASE_OUT)
	if _dust_ring and is_instance_valid(_dust_ring):
		var tw3 := create_tween()
		tw3.tween_property(_dust_ring, "scale", _dust_ring.scale * 1.5, 0.5).set_ease(Tween.EASE_OUT)
		tw3.tween_callback(_dust_ring.queue_free)


func _update_settle(delta: float) -> void:
	var t: float = clampf(_phase_t / SETTLE_DURATION, 0.0, 1.0)
	if t >= 1.0:
		_finish()


func _finish() -> void:
	# Final cleanup
	if is_instance_valid(_light_column):
		_light_column.queue_free()
	if is_instance_valid(_trail_particles):
		_trail_particles.queue_free()
	if _dust_ring and is_instance_valid(_dust_ring):
		_dust_ring.queue_free()
	# Remove the HUD fade overlay (if still present)
	if _hud_fade_rect and is_instance_valid(_hud_fade_rect):
		_hud_fade_rect.queue_free()
	# Ensure controls are unlocked
	if _player and is_instance_valid(_player) and _player.has_meta("cinematic_active"):
		_player.remove_meta("cinematic_active")
	# Restore camera pitch (safety net)
	if _camera_rig and _camera_rig.has_method("set_camera_pitch"):
		_camera_rig.set_camera_pitch(_saved_cam_pitch)
	_phase = Phase.DONE
	print("[IntroCinematic] Landing sequence complete")
	queue_free()


func is_active() -> bool:
	return _phase != Phase.DONE


func is_controls_unlocked() -> bool:
	return _controls_unlocked