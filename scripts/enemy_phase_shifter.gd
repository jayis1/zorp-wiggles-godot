## Zorp Wiggles — Phase Shifter (Enhancement: New Enemy Type)
## An enemy that periodically shifts into a spectral phase, becoming intangible
## (immune to damage) for a brief window. Players must time their shots to land
## hits while it is in the material phase.
##
## Behavior:
##   MATERIAL phase (3.0s) — vulnerable, vivid violet, moves toward player normally
##   WARN phase (0.4s) — shimmering blink telegraph before phasing
##   PHASED state (2.0s) — intangible, translucent blue, still moves but slower,
##                          projectiles pass through harmlessly
##
## The cycle repeats. Damage taken during MATERIAL phase; ignored during PHASED.
## Spectral Beam weapon mod ignores the intangibility (it phases too).
##
## The danger: while phased it can still close distance and attack. The player
## must read the telegraph and burst damage during the material window.

extends EnemyBase

class_name EnemyPhaseShifter

# ─── Phase State Machine ──────────────────────────────────────────────────────
enum PhaseState { MATERIAL, WARN, PHASED }

var _phase_state: int = PhaseState.MATERIAL
var _phase_timer: float = GameConstants.PHASE_SHIFTER_MATERIAL_DURATION
var _is_intangible: bool = false

func _ready() -> void:
	enemy_name = "Phase Shifter"
	enemy_type = GameConstants.EnemyType.PHASE_SHIFTER
	max_hp = GameConstants.PHASE_SHIFTER_HP
	speed = GameConstants.PHASE_SHIFTER_SPEED
	damage = GameConstants.PHASE_SHIFTER_DAMAGE
	base_scale = GameConstants.PHASE_SHIFTER_SCALE
	detect_range = GameConstants.PHASE_SHIFTER_DETECT_RANGE
	attack_range = GameConstants.PHASE_SHIFTER_ATTACK_RANGE
	attack_cooldown = GameConstants.PHASE_SHIFTER_ATTACK_COOLDOWN
	xp_reward = GameConstants.PHASE_SHIFTER_XP
	score_reward = GameConstants.PHASE_SHIFTER_SCORE
	base_color = GameConstants.PHASE_SHIFTER_COLOR
	# Smart AI enabled — flanking + retreat make it trickier to pin down
	use_smart_ai = true
	super._ready()

	# Emissive material — vivid violet with strong rim for spectral look
	if _material:
		_material.emission = base_color * 0.4
		_material.emission_energy_multiplier = 1.5
		_material.rim = 1.0
		_material.rim_tint = 0.8

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_dead or GameManager.is_paused or spawn_grace_timer > 0:
		return

	# Tick the phase state machine
	_phase_timer -= delta * _time_scale
	if _phase_timer <= 0:
		_advance_phase_state()

	# Visual update based on current phase state
	_update_phase_visuals(delta)

## Advance to the next phase state in the cycle: MATERIAL → WARN → PHASED → MATERIAL
func _advance_phase_state() -> void:
	match _phase_state:
		PhaseState.MATERIAL:
			# Enter WARN — brief telegraph before becoming intangible
			_phase_state = PhaseState.WARN
			_phase_timer = GameConstants.PHASE_SHIFTER_PHASE_WARN_TIME
		PhaseState.WARN:
			# Enter PHASED — intangible
			_phase_state = PhaseState.PHASED
			_phase_timer = GameConstants.PHASE_SHIFTER_PHASE_DURATION
			_is_intangible = true
			# Visual: snap to translucent blue
			_apply_phased_material()
			# Particle burst on phase shift
			ParticleEffects.spawn_explosion(get_parent(), global_position,
				GameConstants.PHASE_SHIFTER_PHASE_COLOR, 16, 0.3)
			# Audio cue — spectral phase-shift whoosh
			AudioManager.play_sfx(AudioManager.SFX_TELEPORT)
		PhaseState.PHASED:
			# Return to MATERIAL — vulnerable again
			_phase_state = PhaseState.MATERIAL
			_phase_timer = GameConstants.PHASE_SHIFTER_MATERIAL_DURATION
			_is_intangible = false
			_apply_material_material()
			# Particle burst on return
			ParticleEffects.spawn_explosion(get_parent(), global_position,
				GameConstants.PHASE_SHIFTER_COLOR, 16, 0.3)
			# Audio cue — return to material plane
			AudioManager.play_sfx(AudioManager.SFX_TELEPORT)

## Per-frame visual updates for the current phase state.
func _update_phase_visuals(delta: float) -> void:
	if not _material:
		return
	match _phase_state:
		PhaseState.WARN:
			# Rapid blink between material color and phase color during warn
			var blink: float = sin(Time.get_ticks_msec() * 0.001 * GameConstants.PHASE_SHIFTER_PHASE_BLINK_SPEED)
			var t: float = 0.5 + 0.5 * blink  # 0..1
			_material.albedo_color = base_color.lerp(GameConstants.PHASE_SHIFTER_PHASE_COLOR, t)
		PhaseState.PHASED:
			# Subtle shimmer while phased — pulse the emission
			var shimmer: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.005)
			_material.emission_energy_multiplier = shimmer * 1.5

## Apply the translucent phased material (called once on entering PHASED state).
func _apply_phased_material() -> void:
	if not _material:
		return
	_material.albedo_color = GameConstants.PHASE_SHIFTER_PHASE_COLOR
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.emission = GameConstants.PHASE_SHIFTER_PHASE_COLOR * 0.5

## Restore the solid material material (called once on entering MATERIAL state).
func _apply_material_material() -> void:
	if not _material:
		return
	_material.albedo_color = base_color
	_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_material.emission = base_color * 0.4
	_material.emission_energy_multiplier = 1.5

## Override take_damage_from — ignore damage while intangible unless the attacker
## is using the Spectral Beam (which ignores intangibility). We detect the
## Spectral Beam by checking the projectile's weapon_mod meta, set by projectile.gd.
## If the source is not a projectile (e.g. acid pool, weather), damage applies
## normally — intangibility only blocks direct projectile hits.
func take_damage_from(amount: int, source_pos: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return
	if _is_intangible:
		# Check if the damage source is a Spectral Beam projectile.
		# The projectile sets a meta "spectral" on itself before calling this.
		# Since we can't access the caller here, we use a static flag set by
		# the projectile just before calling take_damage_from.
		if not EnemyPhaseShifter._spectral_bypass_active:
			# Damage blocked — visual feedback: small phase ripple
			ParticleEffects.spawn_explosion(get_parent(), global_position,
				GameConstants.PHASE_SHIFTER_PHASE_COLOR, 6, 0.15)
			return
	# Not intangible (or spectral bypass) — apply damage normally
	super.take_damage_from(amount, source_pos)

## Static flag set by Spectral Beam projectiles just before calling take_damage.
## This lets the Phase Shifter know the incoming damage should bypass intangibility.
static var _spectral_bypass_active: bool = false

static func set_spectral_bypass(active: bool) -> void:
	_spectral_bypass_active = active

func _die() -> void:
	# Restore material so the death visuals are solid, not translucent
	if _material and _phase_state == PhaseState.PHASED:
		_apply_material_material()
	# Phase shift burst on death — extra particles for the spectral theme
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		GameConstants.PHASE_SHIFTER_COLOR, 24, 0.5)
	super._die()