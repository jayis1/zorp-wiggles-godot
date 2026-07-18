## Zorp Wiggles — Time Warden (Phase 23: New Enemy Type)
## A temporal controller that projects a slowing field around itself. Players
## inside the field move and attack slower; the Warden itself moves faster.
## Periodically teleports behind the player for a surprise attack. Tanky and
## disruptive — the counter is to stay outside its AoE and burst it from range.
##
## Behavior:
##   - Projects a TIME_WARDEN_FIELD_RADIUS slowing field around itself. Any
##     player inside the field has their speed multiplied by
##     TIME_WARDEN_PLAYER_SLOW_MULT. The field is visualized as a translucent
##     blue sphere that pulses.
##   - The Warden itself moves at TIME_WARDEN_SELF_SPEED_MULT (always faster).
##   - Every TIME_WARDEN_TELEPORT_INTERVAL seconds, teleports behind the player
##     at TIME_WARDEN_TELEPORT_DISTANCE. A blink telegraph
##     (TIME_WARDEN_TELEPORT_WARN_TIME) precedes the teleport so the player
##     has a chance to react.
##
## The slow field uses a static registry — each active Time Warden registers
## its position, and the player reads the registry to compute its effective
## speed multiplier. This mirrors how DimensionSystem handles time scales and
## keeps the slow field decoupled from the player's internal speed logic.

extends EnemyBase

class_name EnemyTimeWarden

# ─── Slow Field Registry (static) ────────────────────────────────────────────
## All active Time Wardens register their global_position here each frame.
## The player reads this list via get_player_slow_mult() to compute its
## effective speed multiplier (the product of all overlapping fields).
## We use a static dict keyed by instance_id so wardens can cleanly add/remove
## themselves without array scan/erase issues on death.
static var _active_wardens: Dictionary = {}  # {instance_id: Vector3}

## Returns the player's combined speed multiplier from all active Time Warden
## slow fields. 1.0 if no fields overlap the player. The multiplier is the
## MINIMUM of all overlapping fields (most intense slow wins), not the product
## — stacking multiple wardens is oppressive otherwise.
static func get_player_slow_mult(player_pos: Vector3) -> float:
	if _active_wardens.is_empty():
		return 1.0
	var mult: float = 1.0
	for warden_pos in _active_wardens.values():
		var dist: float = player_pos.distance_to(warden_pos)
		if dist < GameConstants.TIME_WARDEN_FIELD_RADIUS:
			# Smooth falloff at the edge — full slow at center, no slow at edge
			var t: float = 1.0 - (dist / GameConstants.TIME_WARDEN_FIELD_RADIUS)
			var field_mult: float = lerpf(1.0, GameConstants.TIME_WARDEN_PLAYER_SLOW_MULT, t)
			# Take the strongest (lowest) slow
			if field_mult < mult:
				mult = field_mult
	return mult

## Clear the registry (called on game restart / scene change).
static func clear_registry() -> void:
	_active_wardens.clear()

# ─── Teleport State Machine ───────────────────────────────────────────────────
enum TeleportState { NORMAL, WARN, TELEPORTING }

var _teleport_state: int = TeleportState.NORMAL
var _teleport_timer: float = GameConstants.TIME_WARDEN_TELEPORT_INTERVAL
var _is_teleporting: bool = false

# ─── Slow Field Visual ───────────────────────────────────────────────────────
var _field_mesh: MeshInstance3D = null
var _field_material: StandardMaterial3D = null
var _field_light: OmniLight3D = null

# ─── Slow Field Tick ─────────────────────────────────────────────────────────
var _field_tick_timer: float = 0.0

func _ready() -> void:
	enemy_name = "Time Warden"
	enemy_type = GameConstants.EnemyType.TIME_WARDEN
	max_hp = GameConstants.TIME_WARDEN_HP
	speed = GameConstants.TIME_WARDEN_SPEED
	damage = GameConstants.TIME_WARDEN_DAMAGE
	base_scale = GameConstants.TIME_WARDEN_SCALE
	detect_range = GameConstants.TIME_WARDEN_DETECT_RANGE
	attack_range = GameConstants.TIME_WARDEN_ATTACK_RANGE
	attack_cooldown = GameConstants.TIME_WARDEN_ATTACK_COOLDOWN
	xp_reward = GameConstants.TIME_WARDEN_XP
	score_reward = GameConstants.TIME_WARDEN_SCORE
	base_color = GameConstants.TIME_WARDEN_COLOR
	# Smart AI enabled — flanking + retreat make it a trickier kiter
	use_smart_ai = true
	super._ready()

	# Emissive material — cool temporal blue with strong rim
	if _material:
		_material.emission = base_color * 0.4
		_material.emission_energy_multiplier = 1.5
		_material.rim = 1.0
		_material.rim_tint = 1.0
		_material.metallic = 0.3
		_material.roughness = 0.35

	# Create the slow field visual — a translucent sphere around the warden
	_create_field_visual()

	# Register this warden in the static slow-field registry
	_active_wardens[get_instance_id()] = global_position

## Create the translucent slow-field sphere + light that surrounds the warden.
func _create_field_visual() -> void:
	# Translucent sphere mesh
	_field_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = GameConstants.TIME_WARDEN_FIELD_RADIUS
	sphere.height = GameConstants.TIME_WARDEN_FIELD_RADIUS * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	_field_mesh.mesh = sphere
	_field_material = StandardMaterial3D.new()
	_field_material.albedo_color = GameConstants.TIME_WARDEN_FIELD_COLOR
	_field_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_field_material.emission_enabled = true
	_field_material.emission = GameConstants.TIME_WARDEN_FIELD_COLOR * 0.3
	_field_material.emission_energy_multiplier = 0.6
	_field_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_field_material.no_depth_test = true  # Render on top so it's always visible
	_field_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from inside
	_field_mesh.material_override = _field_material
	add_child(_field_mesh)
	# The field is centered on the warden, at ground level
	_field_mesh.position = Vector3(0, 0.5, 0)

	# Soft blue light to illuminate the field area
	_field_light = OmniLight3D.new()
	_field_light.light_color = GameConstants.TIME_WARDEN_COLOR
	_field_light.light_energy = 0.8
	_field_light.omni_range = GameConstants.TIME_WARDEN_FIELD_RADIUS
	_field_light.omni_attenuation = 2.0
	add_child(_field_light)
	_field_light.position = Vector3(0, 1.0, 0)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_dead or GameManager.is_paused or spawn_grace_timer > 0:
		return

	# Update our position in the slow-field registry
	_active_wardens[get_instance_id()] = global_position

	# Tick the teleport state machine
	_teleport_timer -= delta * _time_scale
	if _teleport_timer <= 0 and _teleport_state == TeleportState.NORMAL:
		_advance_teleport_state()

	# Update teleport visuals
	_update_teleport_visuals(delta)

	# Pulse the slow field visual
	_update_field_visual(delta)

## Advance the teleport state machine: NORMAL → WARN → TELEPORTING → NORMAL
func _advance_teleport_state() -> void:
	match _teleport_state:
		TeleportState.NORMAL:
			_teleport_state = TeleportState.WARN
			_teleport_timer = GameConstants.TIME_WARDEN_TELEPORT_WARN_TIME
		TeleportState.WARN:
			_teleport_state = TeleportState.TELEPORTING
			_teleport_timer = 0.1  # Brief teleporting state
			_execute_teleport()
		TeleportState.TELEPORTING:
			_teleport_state = TeleportState.NORMAL
			_teleport_timer = GameConstants.TIME_WARDEN_TELEPORT_INTERVAL

## Per-frame visual updates for the teleport telegraph.
func _update_teleport_visuals(delta: float) -> void:
	if not _material:
		return
	match _teleport_state:
		TeleportState.WARN:
			# Rapid blink between base color and white during warn
			var blink: float = sin(Time.get_ticks_msec() * 0.001 * GameConstants.TIME_WARDEN_TELEPORT_BLINK_SPEED)
			var t: float = 0.5 + 0.5 * blink
			_material.albedo_color = base_color.lerp(Color.WHITE, t * 0.5)
			_material.emission_energy_multiplier = 1.5 + t * 1.5
		TeleportState.TELEPORTING:
			# Bright flash during the teleport itself
			_material.albedo_color = Color.WHITE
			_material.emission_energy_multiplier = 4.0
		TeleportState.NORMAL:
			# Restore base emission if we just came out of a teleport
			if _material.emission_energy_multiplier > 2.0:
				_material.albedo_color = base_color
				_material.emission_energy_multiplier = 1.5

## Execute the teleport — move to behind the player at TIME_WARDEN_TELEPORT_DISTANCE.
## Adds a particle burst at both the departure and arrival points for visual feedback.
func _execute_teleport() -> void:
	if not _cached_player or not is_instance_valid(_cached_player):
		# No player — just reset to normal state
		_teleport_state = TeleportState.NORMAL
		_teleport_timer = GameConstants.TIME_WARDEN_TELEPORT_INTERVAL
		return
	# Departure particle burst
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		GameConstants.TIME_WARDEN_COLOR, 20, 0.4)
	# Compute teleport position: behind the player relative to their facing.
	# "Behind" = opposite of the direction from player to warden, at the
	# configured distance. This puts the warden behind the player's current
	# view of the warden, creating a surprise repositioning.
	var to_warden: Vector3 = (global_position - _cached_player.global_position).normalized()
	var behind_dir: Vector3 = -to_warden
	behind_dir.y = 0
	behind_dir = behind_dir.normalized()
	var teleport_pos: Vector3 = _cached_player.global_position + behind_dir * GameConstants.TIME_WARDEN_TELEPORT_DISTANCE
	# Clamp to world bounds
	var extent: float = GameConstants.WORLD_EXTENT - 5.0
	teleport_pos.x = clampf(teleport_pos.x, -extent, extent)
	teleport_pos.z = clampf(teleport_pos.z, -extent, extent)
	teleport_pos.y = 1.0
	global_position = teleport_pos
	# Arrival particle burst
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		GameConstants.TIME_WARDEN_COLOR, 20, 0.4)
	# Camera shake on teleport — disorienting temporal jump
	_trigger_camera_trauma(0.25)
	# Audio cue
	AudioManager.play_sfx(AudioManager.SFX_ENEMY_HIT)

## Pulse the slow field visual — gentle breathing animation.
func _update_field_visual(delta: float) -> void:
	if not _field_material or not _field_light:
		return
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.003)
	_field_material.emission_energy_multiplier = 0.4 + 0.3 * pulse
	_field_material.albedo_color.a = GameConstants.TIME_WARDEN_FIELD_COLOR.a * (0.7 + 0.3 * pulse)
	_field_light.light_energy = 0.6 + 0.3 * pulse

## Override _update_ai to apply the Warden's self-speed boost. The Warden is
## always faster than its base speed (TIME_WARDEN_SELF_SPEED_MULT), making it
## a persistent threat that's hard to kite.
func _update_ai(delta: float) -> void:
	var original_speed: float = speed
	speed *= GameConstants.TIME_WARDEN_SELF_SPEED_MULT
	super._update_ai(delta)
	speed = original_speed

func _die() -> void:
	# Remove from the slow-field registry
	_active_wardens.erase(get_instance_id())
	# Fade out the field visual
	if _field_mesh:
		var fade_tween := _field_mesh.create_tween()
		fade_tween.tween_property(_field_material, "albedo_color:a", 0.0, 0.3) \
			.set_ease(Tween.EASE_OUT)
		fade_tween.tween_callback(_field_mesh.queue_free)
		_field_mesh = null
	if _field_light:
		var light_tween := _field_light.create_tween()
		light_tween.tween_property(_field_light, "light_energy", 0.0, 0.3) \
			.set_ease(Tween.EASE_OUT)
		light_tween.tween_callback(_field_light.queue_free)
		_field_light = null
	# Temporal burst on death — extra particles for the time theme
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		GameConstants.TIME_WARDEN_COLOR, 28, 0.6)
	super._die()

func _exit_tree() -> void:
	# Ensure we're removed from the registry when the node is freed
	_active_wardens.erase(get_instance_id())