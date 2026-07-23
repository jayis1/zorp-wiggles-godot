## Zorp Wiggles — Plasma Stalker (Phase 23: New Enemy Type)
## An ambusher that periodically turns nearly invisible. While cloaked the mesh
## is almost fully transparent — the only tell is a particle trail of plasma
## sparks that drift behind it. The player must spot the trail to track the
## stalker and burst it down during the brief visible window. Fast, low-HP,
## high-damage — a glass-cannon ambusher.
##
## Behavior:
##   VISIBLE phase (2.5s) — solid mesh, normal speed, vulnerable
##   WARN phase (0.35s) — shimmering blink telegraph before cloaking
##   CLOAKED phase (4.0s) — near-invisible mesh, 1.3x speed, still attacks
##
## The cycle repeats. While cloaked the stalker is HARDER to hit (the player
## must aim at the particle trail) but it is NOT intangible — projectiles
## still connect. The cloak is a visual stealth mechanic, not a damage shield.
## A particle trail of plasma sparks emits continuously while cloaked, giving
## the player a visual cue to track and target the stalker.
##
## The danger: while cloaked it closes distance fast and attacks from
## unexpected angles. The player must watch for the spark trail and pre-fire
## at it during the visible window.

extends EnemyBase

class_name EnemyPlasmaStalker

# ─── Cloak State Machine ─────────────────────────────────────────────────────
enum CloakState { VISIBLE, WARN, CLOAKED }

var _cloak_state: int = CloakState.VISIBLE
var _cloak_timer: float = GameConstants.PLASMA_STALKER_VISIBLE_DURATION
var _trail_timer: float = 0.0  # Accumulator for trail spark emission

func _ready() -> void:
	enemy_name = "Plasma Stalker"
	enemy_type = GameConstants.EnemyType.PLASMA_STALKER
	max_hp = GameConstants.PLASMA_STALKER_HP
	speed = GameConstants.PLASMA_STALKER_SPEED
	damage = GameConstants.PLASMA_STALKER_DAMAGE
	base_scale = GameConstants.PLASMA_STALKER_SCALE
	detect_range = GameConstants.PLASMA_STALKER_DETECT_RANGE
	attack_range = GameConstants.PLASMA_STALKER_ATTACK_RANGE
	attack_cooldown = GameConstants.PLASMA_STALKER_ATTACK_COOLDOWN
	xp_reward = GameConstants.PLASMA_STALKER_XP
	score_reward = GameConstants.PLASMA_STALKER_SCORE
	base_color = GameConstants.PLASMA_STALKER_COLOR
	# Smart AI enabled — flanking + retreat make it a trickier ambusher
	use_smart_ai = true
	super._ready()

	# Emissive material — hot pink-magenta with strong rim for a plasma look
	if _material:
		_material.emission = base_color * 0.5
		_material.emission_energy_multiplier = 1.6
		_material.rim = 1.0
		_material.rim_tint = 1.0
		# Slightly metallic for a glossy energy-surface feel
		_material.metallic = 0.4
		_material.roughness = 0.3

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_dead or GameManager.is_paused or spawn_grace_timer > 0:
		return

	# Tick the cloak state machine
	_cloak_timer -= delta * _time_scale
	if _cloak_timer <= 0:
		_advance_cloak_state()

	# Update visuals for current cloak state
	_update_cloak_visuals(delta)

	# Emit particle trail while cloaked — the player's only visual cue
	if _cloak_state == CloakState.CLOAKED:
		_trail_timer -= delta * _time_scale
		if _trail_timer <= 0:
			_emit_trail_sparks()
			_trail_timer = GameConstants.PLASMA_STALKER_TRAIL_INTERVAL

## Advance to the next cloak state in the cycle: VISIBLE → WARN → CLOAKED → VISIBLE
func _advance_cloak_state() -> void:
	match _cloak_state:
		CloakState.VISIBLE:
			# Enter WARN — brief telegraph before cloaking
			_cloak_state = CloakState.WARN
			_cloak_timer = GameConstants.PLASMA_STALKER_CLOAK_WARN_TIME
		CloakState.WARN:
			# Enter CLOAKED — near-invisible
			_cloak_state = CloakState.CLOAKED
			_cloak_timer = GameConstants.PLASMA_STALKER_CLOAK_DURATION
			_apply_cloaked_material()
			# Particle burst on cloak activation
			ParticleEffects.spawn_explosion(get_parent(), global_position,
				GameConstants.PLASMA_STALKER_COLOR, 14, 0.3)
			# Audio cue — soft ethereal cloak chime
			AudioManager.play_sfx(AudioManager.SFX_CLOAK)
		CloakState.CLOAKED:
			# Return to VISIBLE — solid again
			_cloak_state = CloakState.VISIBLE
			_cloak_timer = GameConstants.PLASMA_STALKER_VISIBLE_DURATION
			_apply_visible_material()
			# Particle burst on decloak
			ParticleEffects.spawn_explosion(get_parent(), global_position,
				GameConstants.PLASMA_STALKER_COLOR, 14, 0.3)
			# Audio cue — decloak shimmer
			AudioManager.play_sfx(AudioManager.SFX_CLOAK)

## Per-frame visual updates for the current cloak state.
func _update_cloak_visuals(delta: float) -> void:
	if not _material:
		return
	match _cloak_state:
		CloakState.WARN:
			# Rapid blink between visible color and cloak color during warn
			var blink: float = sin(Time.get_ticks_msec() * 0.001 * GameConstants.PLASMA_STALKER_CLOAK_BLINK_SPEED)
			var t: float = 0.5 + 0.5 * blink  # 0..1
			var target_a: float = lerpf(base_color.a, GameConstants.PLASMA_STALKER_CLOAK_COLOR.a, t)
			_material.albedo_color = Color(
				base_color.r, base_color.g, base_color.b, target_a)
			# Also pulse emission down as it blinks toward cloak
			_material.emission_energy_multiplier = lerpf(1.6, 0.3, t)
		CloakState.CLOAKED:
			# Subtle shimmer while cloaked — pulse the faint emission
			var shimmer: float = 0.2 + 0.15 * sin(Time.get_ticks_msec() * 0.006)
			_material.emission_energy_multiplier = shimmer

## Apply the near-invisible cloaked material (called once on entering CLOAKED state).
func _apply_cloaked_material() -> void:
	if not _material:
		return
	_material.albedo_color = GameConstants.PLASMA_STALKER_CLOAK_COLOR
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.emission = base_color * 0.15
	_material.emission_energy_multiplier = 0.3

## Restore the solid visible material (called once on entering VISIBLE state).
func _apply_visible_material() -> void:
	if not _material:
		return
	_material.albedo_color = base_color
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.emission = base_color * 0.5
	_material.emission_energy_multiplier = 1.6

## Emit a small burst of plasma spark particles at the stalker's current position.
## This is the player's primary visual cue for tracking a cloaked stalker.
## The sparks use the stalker's color so the trail is identifiable.
func _emit_trail_sparks() -> void:
	if not is_instance_valid(get_parent()):
		return
	# Spawn a tiny particle burst slightly behind the stalker (based on velocity)
	var trail_offset: Vector3 = Vector3.ZERO
	if velocity.length_squared() > 1.0:
		trail_offset = -velocity.normalized() * 0.5
	ParticleEffects.spawn_explosion(
		get_parent(),
		global_position + trail_offset + Vector3(0, 0.5, 0),
		GameConstants.PLASMA_STALKER_COLOR,
		GameConstants.PLASMA_STALKER_TRAIL_SPARK_COUNT,
		0.4
	)

## Override _update_ai to apply the cloak speed boost. While cloaked the stalker
## moves faster (ambush speed), making it harder to track and more threatening.
## We apply the boost by scaling the effective speed before the base AI runs.
## Since the base _update_ai reads `speed` directly, we temporarily swap it.
func _update_ai(delta: float) -> void:
	var original_speed: float = speed
	if _cloak_state == CloakState.CLOAKED:
		speed *= GameConstants.PLASMA_STALKER_SPEED_BOOST_CLOAK
	super._update_ai(delta)
	speed = original_speed

func _die() -> void:
	# Restore visible material so the death visuals are solid, not near-invisible
	if _material and _cloak_state == CloakState.CLOAKED:
		_apply_visible_material()
	# Plasma burst on death — extra particles for the plasma theme
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		GameConstants.PLASMA_STALKER_COLOR, 22, 0.5)
	super._die()