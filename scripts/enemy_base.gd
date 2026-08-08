## Zorp Wiggles — Enemy Base Class
## All enemy types inherit from this. Handles AI, pathfinding, HP, attacks.
## Ported from the Enemy class in Ursina game.py.

extends CharacterBody3D

class_name EnemyBase

signal enemy_died(enemy: EnemyBase)
signal enemy_hit(enemy: EnemyBase, damage: int)

# ─── Enemy Configuration (override in subclasses) ────────────────────────────
@export var enemy_name: String = "Unknown"
@export var max_hp: int = 50
@export var speed: float = 4.0
@export var damage: int = 10
@export var attack_range: float = GameConstants.ENEMY_ATTACK_RANGE
@export var detect_range: float = GameConstants.ENEMY_DETECT_RANGE
@export var attack_cooldown: float = GameConstants.ENEMY_ATTACK_COOLDOWN
@export var xp_reward: int = 25
@export var score_reward: int = 100
@export var enemy_type: int = GameConstants.EnemyType.BLOB

# ── Phase 18: Boss Arena — flag for arena-promoted bosses ──
# Set by BossArena when auto-spawning a non-Drake enemy as a boss.
# When true, _die() emits boss_defeated so the arena dissolves.
var is_arena_boss: bool = false

# ── Phase 26: World Bosses — flag for roaming open-world bosses ──
# Set by WorldBossManager when promoting a boss-type enemy to a world boss.
# When true, _die() emits boss_defeated so the WorldBossManager drops the
# loot shower and clears its active-world-boss reference. Distinct from
# is_arena_boss because world bosses do NOT seal the player in an arena
# and should NOT call GameManager.clear_current_boss() (no arena to clear).
var is_world_boss: bool = false

# ─── State ────────────────────────────────────────────────────────────────────
var hp: int = 50
var is_alerted: bool = false
var is_attacking: bool = false
var attack_cooldown_timer: float = 0.0
var is_dead: bool = false
var spawn_grace_timer: float = GameConstants.ENEMY_SPAWN_GRACE_PERIOD
var alert_indicator_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var is_windup: bool = false
# ── Windup emission tween ── Tracks the emission-energy ramp tween so a new
#    windup (or a hit-flash during windup) can kill the in-flight emission
#    tween cleanly. Without this, the windup emission ramp could fight the
#    hit-flash emission spike or stack across rapid re-attacks.
var _windup_emit_tween: Tween = null
# ── Windup scale tween ── Tracks the squash-down scale tween of the attack
#    windup so it can be killed cleanly when the windup is interrupted by
#    taking damage (stagger). Without this, the interrupted windup's scale
#    tween would keep running and call _execute_attack after the stagger.
var _windup_scale_tween: Tween = null
# Cached pre-windup emission energy so _execute_attack can restore it exactly,
# even if the windup was interrupted by a hit-flash that also touches
# emission_energy_multiplier.
var _windup_prev_emission: float = 1.0
# ── Hit squash tween ── Tracks the body_mesh hit squash tween so the idle
#    breathing code can check if it's still running (the elastic rebound
#    lasts longer than _hit_flash_timer, so without this check the idle
#    breathing would overwrite the scale mid-rebound, causing a pop).
var _hit_squash_tween: Tween = null
var knockback_vel: Vector3 = Vector3.ZERO
var _spawn_target_alpha: float = 1.0

# ── First-hit aggro flash ── When an enemy is hit for the first time
#    (transitions from full HP to damaged), a brief "aggro ping" — a
#    small expanding ring at the enemy's position in the enemy's color —
#    fires once to visually communicate "this enemy is now in combat."
#    This is separate from the existing alert indicator ("!") which
#    fires on detection; the aggro flash fires on the first actual hit,
#    giving the player a "I connected" feedback moment that also signals
#    the enemy's transition from idle/wandering to active combat.
var _first_hit_triggered: bool = false

# ─── Wandering ────────────────────────────────────────────────────────────────
var wander_dir: Vector3 = Vector3.ZERO
var wander_timer: float = 3.0

# ─── Visual ──────────────────────────────────────────────────────────────────
@export var base_color: Color = Color.RED
var current_color: Color = Color.RED
@export var base_scale: float = 1.0
var _material: StandardMaterial3D = null

# ── Phase 12: Walk cycle animation ──
# Per-enemy random phase/freq/amp so groups of enemies don't bob in sync.
var _walk_phase: float = 0.0
var _walk_freq: float = 6.0   # Bob frequency (rad/s)
var _walk_amp: float = 0.08   # Bob amplitude (meters)

# ── Idle breathing ── When stationary, enemies have no animation and look
#    frozen/dead. A subtle breathing scale pulse + vertical bob gives them
#    life, mirroring the player's idle breathing. Each enemy gets a random
#    phase AND a slightly randomized frequency so groups of idle enemies
#    don't pulse in mechanical lockstep — even with random phases, a shared
#    frequency makes a cluster visibly breathe at the same rate, which
#    reads as synchronized rather than organic. The frequency varies ±20%
#    around the base (2.0–3.0 rad/s) so each enemy has its own breathing
#    rhythm. The amplitude is small (±4% scale, ±0.02m bob) so it reads as
#    organic life, not a mechanical throb. Skipped during
#    windup/attacking/hit-flash (those own mesh.scale) and death.
var _idle_breath_phase: float = 0.0
var _idle_breath_speed: float = 2.5  # Per-enemy randomized breathing rate (rad/s)
const _IDLE_BREATH_SPEED_BASE: float = 2.5  # Center of the random range
const _IDLE_BREATH_SCALE_AMP: float = 0.04  # ±4% scale pulse
const _IDLE_BREATH_Y_AMP: float = 0.02  # ±2cm vertical bob

# ─── Movement Smoothing ──────────────────────────────────────────────────────
## Higher = snappier velocity changes. ~8 = smooth organic, ~20 = tight.
@export var velocity_smoothing: float = 8.0
var _cached_player: Node3D = null

# ── Phase 10: Smart Enemy AI ──────────────────────────────────────────────────
# The AI controller handles advanced behaviors: LOS, flanking, retreat, ambush,
# pack behavior, call-for-help, enrage, and near-death shudder.
# Subclasses can disable specific behaviors by setting these flags to false
# in their _ready() before calling super._ready().
@export var use_smart_ai: bool = true
var ai_controller: EnemyAIController = null

# Navigation agent for pathfinding around obstacles (Phase 10).
# Lazily created when the nav mesh is ready and the enemy needs to path.
var _nav_agent: NavigationAgent3D = null
var _nav_path_timer: float = 0.0  # Time until next repath

# ── Phase 14: Dimensional Rifts — time scale (Time-Slow dimension) ──
var _time_scale: float = 1.0

# ── Phase 19: Co-op — track which player killed this enemy ──
var _killed_by_p2: bool = false

# ── Phase 24: Mind Control — when controlled, enemy fights for the player ──
# The controlled enemy retargets to attack other enemies instead of the player.
# Other enemies will also target the controlled enemy. Lasts MIND_CONTROL_DURATION.
var is_mind_controlled: bool = false
var _mind_control_timer: float = 0.0
var _mind_control_original_color: Color = Color.RED
var _mind_control_target: Node3D = null  # Current enemy being chased/attacked

# ─── Node References ─────────────────────────────────────────────────────────
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var alert_indicator: Label3D = $AlertIndicator

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")

	# ── Phase 35: Register for LOD management ──
	# Enemies have particles (aura, death poof) and lights (emission glow).
	# The PerformanceOptimizer adjusts these based on distance to player,
	# reducing particle counts and dimming lights for far enemies.
	if PerformanceOptimizer:
		PerformanceOptimizer.register_lod_target(self)

	# ── Phase 10: Create AI controller for advanced behaviors ──
	if use_smart_ai:
		ai_controller = EnemyAIController.new()
		ai_controller.setup(self)

	# ── Phase 12: Random walk cycle parameters ──
	_walk_phase = randf_range(0.0, TAU)
	_walk_freq = randf_range(4.0, 8.0)
	_walk_amp = randf_range(0.05, 0.12) * base_scale
	# Random idle breath phase so groups don't pulse in sync
	_idle_breath_phase = randf_range(0.0, TAU)
	# Per-enemy breathing frequency — ±20% around the base so a cluster of
	# idle enemies each breathes at their own rhythm, not in lockstep.
	_idle_breath_speed = _IDLE_BREATH_SPEED_BASE * randf_range(0.8, 1.2)

	# Spawn grace period — enemy can't detect player for a bit
	spawn_grace_timer = GameConstants.ENEMY_SPAWN_GRACE_PERIOD

	# Random wander direction
	wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	wander_timer = randf_range(2.0, 5.0)

	# Set up material with base color
	# Sync current_color to base_color so systems that read/restore it
	# (mind control, variant tinting) use the actual enemy color, not
	# the default Color.RED that the var was initialised with.
	current_color = base_color
	if body_mesh:
		_material = StandardMaterial3D.new()
		_material.albedo_color = base_color
		_material.roughness = 0.55
		_material.metallic = 0.15
		_material.emission_enabled = true
		_material.emission = base_color * 0.15
		# Rim lighting — gives enemies a glowing edge that makes them pop
		# against the dark alien terrain. Rim adds a fresnel-style highlight
		# at grazing angles, improving silhouette readability.
		_material.rim_enabled = true
		_material.rim = 0.6       # Rim intensity
		_material.rim_tint = 0.8  # Tint toward albedo color for cohesive look
		# Enable transparency for spawn fade-in (alpha=1 is fully opaque, no perf cost)
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_spawn_target_alpha = base_color.a
		_material.albedo_color.a = 0.0
		body_mesh.material_override = _material

	# Spawn animation — scale up from small
	scale = Vector3.ONE * 0.3
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * base_scale, 0.5) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)

	# ── Spawn emission discharge ── A brief emission energy spike at spawn
	# so enemies read as "materializing" rather than just fading in. The
	# emission energy jumps to 4x and eases back to 1.0 over 0.5s, synced
	# with the scale-up tween. This gives each spawn a quick "energy flare"
	# that sells the teleport-in effect — the enemy is arriving, not just
	# becoming visible. The discharge fades naturally into the idle emission
	# so there's no hard transition.
	if _material:
		_material.emission_energy_multiplier = 4.0
		var spawn_emit_tween := create_tween()
		spawn_emit_tween.tween_property(_material, "emission_energy_multiplier",
			1.0, 0.5) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Hide alert indicator
	if alert_indicator:
		alert_indicator.visible = false

func _physics_process(delta: float) -> void:
	if GameManager.is_paused or is_dead:
		return

	# ── Phase 35: AI throttling for distant enemies ──
	# Enemies far from the player don't need full AI updates every physics
	# frame. We track distance and skip AI/timer/visual updates on alternate
	# frames for mid-distance enemies, and every 3rd frame for far enemies.
	# Movement still happens every frame (so enemies approach smoothly),
	# but the expensive AI logic (pathfinding, LOS checks, pack updates) is
	# throttled. This can cut enemy CPU cost by 30-50% when many are active.
	var _ai_skip: bool = false
	if PerformanceOptimizer and GameManager.player and is_instance_valid(GameManager.player):
		var _dist_to_player: float = global_position.distance_to(GameManager.player.global_position)
		if _dist_to_player > 80.0:
			# Far enemies: only run AI every 3rd frame
			if Engine.get_physics_frames() % 3 != 0:
				_ai_skip = true
		elif _dist_to_player > 40.0:
			# Mid-distance: skip every other frame
			if Engine.get_physics_frames() % 2 != 0:
				_ai_skip = true

	# ── Phase 14: Apply dimension time scale (Time-Slow dimension) ──
	delta *= _time_scale

	# Spawn grace period
	if spawn_grace_timer > 0:
		spawn_grace_timer -= delta
		_update_spawn_visuals(delta)
		# ── Spawn ground ring when materialize completes ── The frame the
		#    grace timer expires is the moment the enemy becomes "active" —
		#    it can now detect and chase the player. A flat expanding ground
		#    ring (the spawn counterpart to the death shockwave) sells this
		#    transition as a "teleport-in complete" energy discharge, giving
		#    the player a clear audiovisual cue that the enemy is now a
		#    threat. The ring uses the enemy's color and is sized to the
		#    enemy's scale. We fire it on the exact transition frame (the
		#    timer just hit ≤0) so it plays exactly once.
		if spawn_grace_timer <= 0:
			ParticleEffects.spawn_spawn_ring(
				get_parent(), global_position, current_color,
				2.5 + base_scale * 0.5)
			# ── Activation SFX ── A subtle materialization-complete cue
			# when the enemy becomes active (grace period ends). The spawn
			# SFX (descending 220→110 Hz) already plays at spawn time via
			# the spawner, but the grace period lasts 2s — by the time it
			# ends, the player has forgotten the spawn sound. A short
			# reprise here (pitched by size) gives the ground-ring visual
			# an audio partner that says "this enemy is NOW a threat."
			# Pitch scales with enemy size: small = high chirp, large =
			# deeper thrum. Low volume so mass spawns don't overwhelm.
			# ── Distance attenuation ── Volume scales with distance to the
			# player so enemies materializing far off-screen don't play at
			# full volume. Within 15m → full volume, at 60m+ → ~15% volume,
			# smoothstep in between. This keeps nearby activations audible
			# while distant ones read as a subtle ambient cue rather than a
			# disorienting loud warp from an unseen direction.
			var activate_pitch: float = clampf(1.5 - base_scale * 0.2, 0.7, 1.5)
			var activate_vol: float = 1.0
			# Use GameManager.player (already used everywhere else in this file
			# for distance checks) instead of a scene-tree group scan.
			if GameManager.player and is_instance_valid(GameManager.player):
				var _act_dist: float = global_position.distance_to(GameManager.player.global_position)
				var _act_dist_t: float = clampf((_act_dist - 15.0) / 45.0, 0.0, 1.0)
				_act_dist_t = 1.0 - _act_dist_t * _act_dist_t * (3.0 - 2.0 * _act_dist_t)
				activate_vol = lerpf(0.15, 1.0, _act_dist_t)
			AudioManager.play_sfx_pitched_volume(AudioManager.SFX_SPAWN_IN, activate_pitch, activate_vol)
		return

	# Check if player is alive
	if not GameManager.player_is_alive:
		return

	if not _ai_skip:
		_update_ai(delta)
		_update_timers(delta)
	_update_visuals(delta)

	# ── Phase 10: Update smart AI controller (LOS, enrage, shudder, pack, etc.) ──
	if not _ai_skip and ai_controller:
		ai_controller.update(delta, self)

	# ── Phase 8: Apply knockback velocity (impulse-style, decays over time)
	if knockback_vel.length_squared() > 0.01:
		global_position += knockback_vel * delta
		knockback_vel = knockback_vel.move_toward(Vector3.ZERO, GameConstants.KNOCKBACK_DAMPING * delta)

	# ── Phase 8: Enemy-to-enemy separation (soft push so they don't overlap)
	_apply_enemy_separation(delta)

	move_and_slide()


# ── Phase 8: Enemy separation ─────────────────────────────────────────────────
# Pushes nearby same-group enemies apart so they don't stack on top of each other.
# Uses distance-based force (no full physics engine needed — simple velocity offset).
# Uses distance_squared_to to avoid the sqrt cost per pair — important because this
# runs O(n²) every physics frame across all enemies.
# ── Distance culling ── Enemies far from the player (>60m) are skipped entirely
#    in the separation pass. A far cluster of enemies the player can't see doesn't
#    need to maintain perfect spacing — they're off-screen and will naturally
#    spread out as they approach. This skips the O(n²) inner loop for distant
#    enemies, which can cut the separation cost by 40-60% when many enemies are
#    spread across a large world (common in open-world exploration phases).
#    The cull distance (60m) matches the PerformanceOptimizer's far-LOD threshold
#    and the SFX distance attenuation boundary, so it's consistent with the
#    existing "far = simplified" model.
const SEPARATION_CULL_DISTANCE: float = 60.0
const SEPARATION_CULL_DISTANCE_SQ: float = 60.0 * 60.0
func _apply_enemy_separation(delta: float) -> void:
	if is_dead:
		return
	# ── Distance cull ── Skip the O(n²) separation pass for enemies far from
	#    the player. The separation force is only visible at close range —
	#    distant enemies spreading apart is imperceptible to the player.
	#    This is the single biggest perf win for the separation system since
	#    it short-circuits the inner loop for the majority of enemies in a
	#    large world.
	if GameManager.player and is_instance_valid(GameManager.player):
		var dist_to_player_sq: float = global_position.distance_squared_to(GameManager.player.global_position)
		if dist_to_player_sq > SEPARATION_CULL_DISTANCE_SQ:
			return
	var sep_radius: float = GameConstants.ENEMY_SEPARATION_RADIUS + base_scale * 0.5
	var sep_radius_sq: float = sep_radius * sep_radius
	for other in GameManager.enemies:
		if other == self or not is_instance_valid(other):
			continue
		var other_base: EnemyBase = other as EnemyBase
		if other_base == null or other_base.is_dead:
			continue
		var diff: Vector3 = global_position - other.global_position
		var dist_sq: float = diff.length_squared()
		if dist_sq < sep_radius_sq and dist_sq > 0.0001:
			var d: float = sqrt(dist_sq)
			# Direction from other → me, push me away
			var push_dir: Vector3 = diff / d  # normalized
			push_dir.y = 0
			# Stronger when closer (inverse-linear falloff)
			var strength: float = GameConstants.ENEMY_SEPARATION_FORCE * (1.0 - d / sep_radius)
			global_position += push_dir * strength * delta

func _update_ai(delta: float) -> void:
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	if not _cached_player:
		return
	
	# ── Phase 24: Mind Control — controlled enemy fights for the player ──
	# When mind-controlled, retarget to the nearest non-controlled enemy.
	# The controlled enemy chases and attacks other enemies, not the player.
	if is_mind_controlled:
		_update_mind_control_ai(delta)
		return
	
	# ── Phase 19: Co-op — target the nearest player ──
	var player: Node3D = _cached_player
	if CoOpManager.is_coop_active():
		var p1: Node3D = _cached_player
		var p2: Node3D = CoOpManager.p2_node
		# Target the closest valid player. Downed players are deprioritized.
		var p1_dist: float = global_position.distance_to(p1.global_position) if is_instance_valid(p1) else 99999.0
		var p2_dist: float = global_position.distance_to(p2.global_position) if is_instance_valid(p2) else 99999.0
		# If P1 is downed, prefer P2 (and vice versa)
		if GameManager.player_is_downed:
			p1_dist = 99999.0
		if CoOpManager.p2_is_downed:
			p2_dist = 99999.0
		if p2_dist < p1_dist:
			player = p2
		else:
			player = p1
	var dist_to_player := global_position.distance_to(player.global_position)
	
	# ── Phase 24: Mind Control — target nearby mind-controlled enemies ──
	# Normal enemies prioritize attacking mind-controlled traitors over the
	# player if one is within detection range. This makes mind control a
	# double-edged sword: the controlled enemy fights for you, but it also
	# draws aggro from other enemies (both spreading damage and protecting
	# the player). We check for the nearest MC enemy within detect_range.
	var mc_target: Node3D = _find_nearest_mind_controlled_enemy()
	if mc_target:
		var mc_dist: float = global_position.distance_to(mc_target.global_position)
		# Use default ambush mult (1.0) here — the ambush multiplier is
		# computed later in this function, but for the mind-control target
		# check we want the base detect range without ambush reduction.
		if mc_dist < effective_detect_range_for(1.0):
			# Override: chase and attack the mind-controlled enemy
			player = mc_target
			dist_to_player = mc_dist
			if not is_alerted:
				is_alerted = true
				alert_indicator_timer = GameConstants.ENEMY_ALERT_INDICATOR_DURATION
				# ── Distance attenuation ── The alert SFX plays at full volume
				# for close enemies (≤15m) and attenuates to 15% at 60m+,
				# matching the spawn SFX distance model. Previously the alert
				# blip played at full volume regardless of distance — an enemy
				# spotting the player from 50m away was just as loud as one
				# right next to them, which was disorienting during large
				# encounters with many simultaneous alerts.
				var _mc_alert_vol: float = _compute_dist_atten(mc_dist)
				AudioManager.play_sfx_volume(AudioManager.SFX_ENEMY_ALERT, _mc_alert_vol)
				if alert_indicator:
					# Kill any in-progress exit fade so the pop-in doesn't fight it
					if alert_indicator.has_meta("_alert_exit_tween") and is_instance_valid(alert_indicator.get_meta("_alert_exit_tween") as Tween):
						(alert_indicator.get_meta("_alert_exit_tween") as Tween).kill()
						alert_indicator.remove_meta("_alert_exit_tween")
					alert_indicator.visible = true
					alert_indicator.modulate.a = 1.0
					alert_indicator.text = "!"
					alert_indicator.scale = Vector3(0.001, 0.001, 0.001)
					var alert_tween := create_tween()
					alert_tween.tween_property(alert_indicator, "scale",
						Vector3.ONE * GameConstants.ENEMY_ALERT_INDICATOR_SCALE, 0.12) \
						.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
					alert_tween.tween_property(alert_indicator, "scale",
						Vector3.ONE, 0.1) \
						.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# ── Phase 10: Ambush behavior ──
	# If the AI controller is in ambush mode, it overrides velocity to zero
	# and uses a reduced detection range until the player gets close.
	var ambush_detect_mult: float = 1.0
	if ai_controller:
		ambush_detect_mult = ai_controller.get_ambush_detect_mult()

	# Detection — line-of-sight aware (Phase 10)
	# If we have LOS check enabled and don't currently have LOS, we only detect
	# at half range (heard but not seen). With LOS, full detection range applies.
	var effective_detect_range: float = detect_range * ambush_detect_mult
	if ai_controller and ai_controller.enable_los:
		if not ai_controller.has_los:
			effective_detect_range *= 0.5  # Reduced detection without visual
	# Phase 17: Fog weather reduces enemy detection range (stealth opportunity)
	effective_detect_range *= WeatherSystem.get_detect_range_multiplier()

	if not is_alerted and dist_to_player < effective_detect_range:
		is_alerted = true
		alert_indicator_timer = GameConstants.ENEMY_ALERT_INDICATOR_DURATION
		# ── Distance attenuation ── same model as the MC alert above.
		var _alert_vol: float = _compute_dist_atten(dist_to_player)
		AudioManager.play_sfx_volume(AudioManager.SFX_ENEMY_ALERT, _alert_vol)
		if alert_indicator:
			# Kill any in-progress exit fade so the pop-in doesn't fight it
			if alert_indicator.has_meta("_alert_exit_tween") and is_instance_valid(alert_indicator.get_meta("_alert_exit_tween") as Tween):
				(alert_indicator.get_meta("_alert_exit_tween") as Tween).kill()
				alert_indicator.remove_meta("_alert_exit_tween")
			alert_indicator.visible = true
			alert_indicator.modulate.a = 1.0
			alert_indicator.text = "!"
			# Pop-in bounce: scale from 0 → 1.4 → 1.0 for a juicy "!" appearance.
			# Kills any prior tween so repeated alerts don't stack.
			alert_indicator.scale = Vector3(0.001, 0.001, 0.001)
			var alert_tween := create_tween()
			alert_tween.tween_property(alert_indicator, "scale",
				Vector3.ONE * GameConstants.ENEMY_ALERT_INDICATOR_SCALE, 0.12) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			alert_tween.tween_property(alert_indicator, "scale",
				Vector3.ONE, 0.1) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		# ── Phase 10: Try to start flanking when first alerted ──
		if ai_controller:
			ai_controller.try_start_flank()

	# Alert indicator fade
	if alert_indicator_timer > 0:
		alert_indicator_timer -= delta
		if alert_indicator_timer <= 0 and alert_indicator:
			# ── Alert indicator exit fade ── Instead of a hard visible=false
			#    cut, the "!" quickly shrinks and fades out over 0.15s. This
			#    mirrors the pop-in bounce's energy in reverse — the indicator
			#    "deflates" rather than vanishing, giving the player a smooth
			#    visual cue that the alert state has ended. A tracked tween
			#    ensures a re-alert can kill the in-progress fade and restart
			#    the pop-in cleanly without stacking.
			if not alert_indicator.has_meta("_alert_exit_tween") or not is_instance_valid(alert_indicator.get_meta("_alert_exit_tween") as Tween):
				var alert_exit := create_tween()
				alert_exit.set_parallel(true)
				alert_exit.tween_property(alert_indicator, "scale",
					Vector3(0.001, 0.001, 0.001), 0.15) \
					.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
				alert_exit.tween_property(alert_indicator, "modulate:a",
					0.0, 0.15) \
					.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				alert_exit.tween_callback(func():
					alert_indicator.visible = false
					alert_indicator.modulate.a = 1.0
					alert_indicator.scale = Vector3.ONE
				)
				alert_indicator.set_meta("_alert_exit_tween", alert_exit)
			else:
				alert_indicator.visible = false

	# ── Phase 10: Retreat check ──
	# If the enemy is at low HP, it may retreat instead of attacking
	if ai_controller:
		ai_controller.check_retreat(self)
		if ai_controller.is_fleeing():
			var flee_dir: Vector3 = ai_controller.get_retreat_direction(self, player)
			var flee_speed: float = speed * GameConstants.AI_RETREAT_SPEED_MULT
			var flee_weight: float = 1.0 - exp(-velocity_smoothing * delta)
			velocity = velocity.lerp(flee_dir * flee_speed, flee_weight)
			velocity.y = 0
			return

	# ── Phase 10: Ambush overrides movement ──
	if ai_controller and ai_controller.is_ambushing:
		velocity = Vector3.ZERO
		return

	# Compute effective speed with enrage + frenzy + ambush rush multipliers
	var effective_speed: float = speed
	if ai_controller:
		effective_speed *= ai_controller.get_enrage_speed_mult()
		effective_speed *= ai_controller.get_frenzy_speed_mult()
		effective_speed *= ai_controller.get_ambush_speed_mult()
	# Phase 17: Weather affects enemy speed — snow storm slows, sandstorm speeds up
	# Enhancement: Use enemy-specific multiplier (sandstorm boosts enemies, not slows)
	effective_speed *= WeatherSystem.get_enemy_speed_multiplier()

	# Movement toward player — compute desired velocity, then smoothly approach
	# it via exponential lerp for organic acceleration/deceleration.
	var desired_velocity: Vector3 = Vector3.ZERO
	if is_alerted and dist_to_player > attack_range:
		# ── Phase 10: Flanking behavior ──
		# If the enemy is flanking, use a circular approach direction instead
		# of a direct line to the player. This makes enemies harder to predict.
		var move_dir: Vector3
		if ai_controller and ai_controller.should_flank():
			move_dir = ai_controller.get_flank_direction(self, player)
			if move_dir == Vector3.ZERO:
				move_dir = (player.global_position - global_position).normalized()
		else:
			move_dir = (player.global_position - global_position).normalized()
		move_dir.y = 0
		move_dir = move_dir.normalized()

		# ── Phase 10: Pack surround behavior ──
		# If in a pack with a surround slot, adjust direction to approach from
		# an angular offset so pack members don't all converge on the same point.
		if ai_controller and ai_controller._pack_slot_index >= 0:
			var pack_count: int = ai_controller.pack_allies.size() + 1
			var slot_angle: float = (float(ai_controller._pack_slot_index) / float(pack_count)) * TAU
			var surround_offset: Vector3 = Vector3(cos(slot_angle), 0, sin(slot_angle)) * GameConstants.AI_PACK_SURROUND_SPACING
			var surround_target: Vector3 = player.global_position + surround_offset
			var to_surround: Vector3 = surround_target - global_position
			to_surround.y = 0
			if to_surround.length() > 0.5:
				move_dir = to_surround.normalized()

		# ── Phase 10: Navigation-based pathfinding ──
		# If the nav mesh is ready, use it to avoid obstacles instead of
		# walking in a straight line. We query the next waypoint and steer
		# toward it. This is especially useful when LOS is blocked.
		if NavigationManager.is_ready():
			var nav_dir: Vector3 = _get_nav_direction(player.global_position, delta)
			if nav_dir != Vector3.ZERO:
				move_dir = nav_dir

		desired_velocity = move_dir * effective_speed
	elif is_alerted and dist_to_player <= attack_range:
		desired_velocity = Vector3.ZERO
		_try_attack(player)
	else:
		# Wander behavior
		_wander(delta)
		return  # _wander sets velocity directly

	# Frame-rate independent smoothing
	var weight: float = 1.0 - exp(-velocity_smoothing * delta)
	velocity = velocity.lerp(desired_velocity, weight)
	velocity.y = 0

# ── Phase 10: Navigation-based pathfinding ────────────────────────────────────
# Queries the NavigationManager for a path to the target and returns the
# direction to the next waypoint. Falls back to direct line if no path.
func _get_nav_direction(target_pos: Vector3, delta: float) -> Vector3:
	# Repath periodically
	_nav_path_timer -= delta
	if _nav_path_timer <= 0:
		_nav_path_timer = GameConstants.AI_NAV_PATH_UPDATE_INTERVAL
		var next_pos: Vector3 = NavigationManager.get_next_position(global_position, target_pos)
		# Store as a member by using the navigation agent if we have one,
		# or just return the direction directly
		var dir: Vector3 = (next_pos - global_position)
		dir.y = 0
		if dir.length() > 0.1:
			return dir.normalized()
	return Vector3.ZERO  # No new path this frame; rely on direct line

func _wander(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0:
		wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		wander_timer = randf_range(2.0, 5.0)
	velocity = wander_dir * speed * 0.3

# ── Phase 24: Mind Control — AI for controlled enemies ──────────────────────
# The controlled enemy finds the nearest non-controlled enemy and attacks it.
# If no enemies are nearby, it wanders. Other enemies can also target the
# controlled enemy (they see it as a traitor). The controlled enemy's attack
# calls take_damage on other enemies instead of the player.
func _update_mind_control_ai(delta: float) -> void:
	# Tick down the mind control timer
	_mind_control_timer -= delta
	if _mind_control_timer <= 0:
		_end_mind_control()
		return
	
	# Find or validate the current target
	if not _mind_control_target or not is_instance_valid(_mind_control_target):
		_mind_control_target = _find_nearest_enemy_for_mc()
	if _mind_control_target and is_instance_valid(_mind_control_target):
		var dist_to_target: float = global_position.distance_to(_mind_control_target.global_position)
		var mc_speed: float = speed * GameConstants.MIND_CONTROL_SPEED_MULT
		# Weather speed multiplier also applies to controlled enemies
		mc_speed *= WeatherSystem.get_enemy_speed_multiplier()
		if dist_to_target > attack_range:
			# Chase the target enemy
			var move_dir: Vector3 = (_mind_control_target.global_position - global_position).normalized()
			move_dir.y = 0
			move_dir = move_dir.normalized()
			# Use navigation if available
			if NavigationManager.is_ready():
				var nav_dir: Vector3 = _get_nav_direction(_mind_control_target.global_position, delta)
				if nav_dir != Vector3.ZERO:
					move_dir = nav_dir
			var desired_velocity: Vector3 = move_dir * mc_speed
			var weight: float = 1.0 - exp(-velocity_smoothing * delta)
			velocity = velocity.lerp(desired_velocity, weight)
			velocity.y = 0
		else:
			# In range — attack the target enemy
			velocity = Vector3.ZERO
			_try_attack_enemy(_mind_control_target)
	else:
		# No targets — wander
		_wander(delta)

## Find the nearest non-controlled, non-dead enemy for the controlled enemy to fight
func _find_nearest_enemy_for_mc() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist: float = 99999.0
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy == self:
			continue
		if not enemy.is_in_group("enemies"):
			continue
		if enemy.is_dead:
			continue
		if enemy.is_mind_controlled:
			continue  # Don't attack other controlled enemies
		var d: float = global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	return nearest

## Find the nearest mind-controlled enemy (for normal enemies to target as traitors)
func _find_nearest_mind_controlled_enemy() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist: float = 99999.0
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy == self:
			continue
		if not enemy.is_in_group("enemies"):
			continue
		if enemy.is_dead:
			continue
		if not enemy.is_mind_controlled:
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	return nearest

## Compute effective detect range (mirrors the logic below, usable before the variable is set)
func effective_detect_range_for(ambush_mult: float) -> float:
	var r: float = detect_range * ambush_mult
	if ai_controller and ai_controller.enable_los and not ai_controller.has_los:
		r *= 0.5
	r *= WeatherSystem.get_detect_range_multiplier()
	return r

## Attack an enemy target (instead of the player) while mind-controlled
func _try_attack_enemy(target: Node3D) -> void:
	if attack_cooldown_timer > 0:
		return
	if is_attacking:
		return
	is_attacking = true
	attack_cooldown_timer = attack_cooldown
	# Windup telegraph — ease-out cubic so the squash decelerates as it
	# gathers, reading as an organic "winding up" motion rather than a
	# mechanical linear shrink. The deceleration sells the gathering of
	# force before the lunge release.
	is_windup = true
	_windup_scale_tween = create_tween()
	_windup_scale_tween.tween_property(self, "scale",
		Vector3.ONE * base_scale * (1.0 - GameConstants.ENEMY_ATTACK_WINDUP_SQUASH),
		GameConstants.ENEMY_ATTACK_WINDUP_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_windup_scale_tween.tween_callback(_execute_attack_on_enemy.bind(target))
	# ── Windup emission ramp ── Brighten the enemy's emission during windup
	# so the charge-up is readable as a glow, not just a silhouette squash.
	# Uses the ENEMY_ATTACK_WINDUP_BRIGHTNESS constant (previously unused) as
	# the peak multiplier. Restored in _execute_attack_on_enemy().
	_ramp_windup_emission()

## Execute the attack on an enemy (mind control version)
func _execute_attack_on_enemy(target: Node3D) -> void:
	is_windup = false
	_windup_scale_tween = null  # Tween completed, clear reference
	_restore_windup_emission()
	if not target or not is_instance_valid(target):
		get_tree().create_timer(0.1).timeout.connect(_reset_attack_flag)
		return
	# Deal damage to the enemy target
	if target.has_method("take_damage_from"):
		target.take_damage_from(damage, global_position)
	elif target.has_method("take_damage"):
		target.take_damage(damage)
	# Lunge toward the target — set velocity so move_and_slide() handles the
	# movement. Previously this used a tween on global_position which fought
	# move_and_slide() (the physics step moved the enemy by decaying velocity
	# while the tween also set position, causing jerky/shortened lunges).
	# Using velocity integrates cleanly with the physics system and the
	# separation/knockback forces that also run in _physics_process.
	var lunge_dir := (target.global_position - global_position).normalized()
	lunge_dir.y = 0
	var lunge_mult := clampf(base_scale / GameConstants.ENEMY_ATTACK_LUNGE_SIZE_BASE,
		GameConstants.ENEMY_ATTACK_LUNGE_SIZE_MULT_MIN, 1.0)
	var lunge_dist := GameConstants.ENEMY_ATTACK_LUNGE_DISTANCE * lunge_mult
	velocity = lunge_dir * (lunge_dist / GameConstants.ENEMY_ATTACK_LUNGE_DURATION)
	velocity.y = 0
	# Lunge stretch
	if body_mesh:
		var stretch_scale := Vector3(1.0 - 0.15, 1.0 + 0.3, 1.0 - 0.15)
		var lunge_stretch := create_tween()
		lunge_stretch.tween_property(body_mesh, "scale",
			Vector3.ONE * base_scale * stretch_scale, 0.06) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		lunge_stretch.tween_property(body_mesh, "scale",
			Vector3.ONE * base_scale, 0.18) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	# ── Lunge trail particle ── A small color-tinted particle burst at the
	#    lunge origin gives the attack a visible motion trail, making the
	#    enemy's committed lunge read as a burst of speed rather than a
	#    silent glide. Skipped for small enemies (base_scale < 0.8) since
	#    their lunges are too short for a trail to be visible.
	if base_scale >= 0.8:
		ParticleEffects.spawn_dash_trail(get_parent(), global_position, current_color)
	# Restore scale — ease-out cubic so the enemy settles back to base size
	# with a decelerating curve, reading as a natural recovery from the lunge
	# rather than a mechanical linear snap.
	var restore_tween := create_tween()
	restore_tween.tween_property(self, "scale", Vector3.ONE * base_scale, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	get_tree().create_timer(0.1).timeout.connect(_reset_attack_flag)

## Begin mind control on this enemy
func start_mind_control() -> void:
	if is_mind_controlled:
		# Refresh timer
		_mind_control_timer = GameConstants.MIND_CONTROL_DURATION
		return
	is_mind_controlled = true
	_mind_control_timer = GameConstants.MIND_CONTROL_DURATION
	_mind_control_original_color = current_color
	_mind_control_target = null
	# Visual: shift to magenta-pink hypnosis color with bright emission.
	# Sync current_color so _flash_hit() restores to the mind-control color
	# (not base_color) when the enemy takes damage while controlled.
	current_color = GameConstants.MIND_CONTROL_COLOR
	if _material:
		_material.albedo_color = GameConstants.MIND_CONTROL_COLOR
		_material.emission = GameConstants.MIND_CONTROL_COLOR * 0.4
		_material.emission_energy_multiplier = 2.0
	# Particle burst on mind control
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		GameConstants.MIND_CONTROL_COLOR, 16, 0.4)
	# Add a pulsing magenta light
	var mc_light := OmniLight3D.new()
	mc_light.light_color = GameConstants.MIND_CONTROL_COLOR
	mc_light.light_energy = 2.0
	mc_light.omni_range = 5.0
	add_child(mc_light)
	mc_light.name = "MCMindLight"
	# Pulse the light — ease in/out sine for an organic, breathing glow
	# rather than a mechanical linear brightness ramp. The sine curve gives
	# the mind-control aura a hypnotic, "alive" feel that matches the
	# magenta-pink hypnosis visual.
	var light_tw := mc_light.create_tween()
	light_tw.set_loops()
	light_tw.tween_property(mc_light, "light_energy", 0.8, 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	light_tw.tween_property(mc_light, "light_energy", 2.0, 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# Alert the enemy so it starts seeking targets immediately
	is_alerted = true

## End mind control — restore the enemy to normal behavior
func _end_mind_control() -> void:
	is_mind_controlled = false
	_mind_control_timer = 0.0
	_mind_control_target = null
	# Restore color + sync current_color so subsequent hit-flashes restore
	# to the original color, not the mind-control color.
	current_color = _mind_control_original_color
	if _material:
		_material.albedo_color = _mind_control_original_color
		_material.emission = _mind_control_original_color * 0.15
		_material.emission_energy_multiplier = 1.0
	# Remove the mind control light
	var mc_light := get_node_or_null("MCMindLight")
	if mc_light:
		mc_light.queue_free()
	# Shatter effect
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		GameConstants.MIND_CONTROL_COLOR, 12, 0.3)

func _try_attack(player: Node3D) -> void:
	if attack_cooldown_timer > 0:
		return
	if is_attacking:
		return

	# ── Phase 14: Mirror dimension — enemies are passive, don't attack ──
	if DimensionSystem.enemies_passive():
		return
	# ── Phase 13: Forest mutation — enemies passive in forest biome ──
	if MutationSystem.enemies_passive():
		return

	is_attacking = true
	attack_cooldown_timer = attack_cooldown

	# Attack windup telegraph — ease-out cubic for organic decelerating squash
	is_windup = true
	_windup_scale_tween = create_tween()
	_windup_scale_tween.tween_property(self, "scale",
		Vector3.ONE * base_scale * (1.0 - GameConstants.ENEMY_ATTACK_WINDUP_SQUASH),
		GameConstants.ENEMY_ATTACK_WINDUP_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_windup_scale_tween.tween_callback(_execute_attack.bind(player))
	# ── Windup emission ramp ── Brighten the enemy's emission during windup
	# so the charge-up is readable as a glow, not just a silhouette squash.
	# Restored in _execute_attack().
	_ramp_windup_emission()

func _execute_attack(player: Node3D) -> void:
	is_windup = false
	_windup_scale_tween = null  # Tween completed, clear reference
	_restore_windup_emission()
	# The windup tween calls this via tween_callback after ENEMY_ATTACK_WINDUP_TIME.
	# The bound `player` reference may have been freed during that delay (especially
	# P2 in co-op, who can drop out or bleed out mid-windup). Bail out safely.
	if not player or not is_instance_valid(player):
		# Still reset the attack flag so the enemy can attack again later
		get_tree().create_timer(0.1).timeout.connect(_reset_attack_flag)
		return
	# ── Phase 24: Mind Control — if the target is a mind-controlled enemy (in the
	# "enemies" group, not "player" group), damage it directly instead of the player ──
	if player.is_in_group("enemies") and not player.is_in_group("player"):
		# Attacking a mind-controlled traitor — deal damage to the enemy
		if player.has_method("take_damage_from"):
			player.take_damage_from(damage, global_position)
		elif player.has_method("take_damage"):
			player.take_damage(damage)
		# Skip player-damage routing and variant on-player-hit effects
		# Lunge toward the target — set velocity so move_and_slide() handles
		# the movement (avoids fighting the physics step's position writes).
		var lunge_dir_mc := (player.global_position - global_position).normalized()
		lunge_dir_mc.y = 0
		var lunge_mult_mc := clampf(base_scale / GameConstants.ENEMY_ATTACK_LUNGE_SIZE_BASE,
			GameConstants.ENEMY_ATTACK_LUNGE_SIZE_MULT_MIN, 1.0)
		var lunge_dist_mc := GameConstants.ENEMY_ATTACK_LUNGE_DISTANCE * lunge_mult_mc
		velocity = lunge_dir_mc * (lunge_dist_mc / GameConstants.ENEMY_ATTACK_LUNGE_DURATION)
		velocity.y = 0
		if body_mesh:
			var stretch_scale_mc := Vector3(1.0 - 0.15, 1.0 + 0.3, 1.0 - 0.15)
			var lunge_stretch_mc := create_tween()
			lunge_stretch_mc.tween_property(body_mesh, "scale",
				Vector3.ONE * base_scale * stretch_scale_mc, 0.06) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			lunge_stretch_mc.tween_property(body_mesh, "scale",
				Vector3.ONE * base_scale, 0.18) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
				var restore_tween_mc := create_tween()
				restore_tween_mc.tween_property(self, "scale", Vector3.ONE * base_scale, 0.15) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
				get_tree().create_timer(0.1).timeout.connect(_reset_attack_flag)
		return
	# ── Phase 19: Co-op — damage the correct player ──
	# Check if the target is P2 (Zerp) by checking if it's in the player2 group
	if player.is_in_group("player2"):
		CoOpManager.p2_take_damage(damage, global_position)
	else:
		# Deal damage to P1 (pass enemy position for damage direction indicator)
		GameManager.take_damage(damage, global_position)

	# ── Phase 33: Enemy Variant System — apply on-hit trait effects ──
	# LIFESTEAL heals the enemy, VENOMOUS applies a slow to the player.
	if EnemyVariantSystem:
		EnemyVariantSystem.on_player_hit(self, player)

	# Camera shake on player hit — biased toward the enemy's attack direction
	# so the camera lurches away from the attacker, reinforcing the hit feel.
	var attack_dir: Vector3 = (player.global_position - global_position).normalized()
	attack_dir.y = 0
	_trigger_camera_trauma(0.2, attack_dir)
	# ── Enemy melee hit-stop ── A micro freeze (20ms @ 0.3x) when an enemy
	#    melee attack lands on the player. The player's own damage squash,
	#    the camera shake, and the invuln blink all fire — but without a
	#    hit-stop the impact reads as a soft nudge rather than a real hit.
	#    This tiny freeze gives enemy melee the same weighty "thud" language
	#    as crits and boss kills, just at the lightest tier (same as the
	#    normal-kill hit-stop). It's routed through HitStopCoordinator so
	#    it composes correctly with any simultaneous projectile crit/kill
	#    freezes — the strongest wins, no stacking. The freeze is short
	#    enough (20ms) that rapid enemy swarms don't stutter the game.
	HitStopCoordinator.request_freeze(0.3, 0.02)

	# Forward lunge — set velocity so move_and_slide() handles the movement.
	# Previously used a tween on global_position which fought the physics step
	# (move_and_slide moved the enemy by decaying velocity while the tween
	# also set position, causing jerky/shortened lunges). Using velocity
	# integrates cleanly with knockback, separation, and other physics forces.
	var lunge_dir := (player.global_position - global_position).normalized()
	lunge_dir.y = 0
	var lunge_mult := clampf(base_scale / GameConstants.ENEMY_ATTACK_LUNGE_SIZE_BASE,
		GameConstants.ENEMY_ATTACK_LUNGE_SIZE_MULT_MIN, 1.0)
	var lunge_dist := GameConstants.ENEMY_ATTACK_LUNGE_DISTANCE * lunge_mult
	velocity = lunge_dir * (lunge_dist / GameConstants.ENEMY_ATTACK_LUNGE_DURATION)
	velocity.y = 0

	# ── Lunge stretch: stretch the body mesh along the lunge direction for a
	# committed, forceful attack read. The windup compressed the enemy (squash);
	# the lunge stretches it (stretch) — classic squash-and-stretch juice.
	# Uses body_mesh.scale (local) so it doesn't conflict with self.scale
	# (which the windup/restore tweens control). Snaps to the stretched pose
	# then eases back to base with an elastic rebound for a wobbly recovery.
	if body_mesh:
		# Stretch on Y (vertical) and squash X/Z equally so it reads as a
		# "coiled spring" lunge regardless of the horizontal lunge angle.
		var stretch_scale := Vector3(
			1.0 - 0.15,  # narrow perpendicular (X)
			1.0 + 0.3,   # tall along motion (Y)
			1.0 - 0.15)  # narrow perpendicular (Z)
		var lunge_stretch := create_tween()
		lunge_stretch.tween_property(body_mesh, "scale",
			Vector3.ONE * base_scale * stretch_scale, 0.06) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		lunge_stretch.tween_property(body_mesh, "scale",
			Vector3.ONE * base_scale, 0.18) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

	# ── Lunge trail particle ── A small color-tinted particle burst at the
	#    lunge origin gives the attack a visible motion trail, making the
	#    enemy's committed lunge read as a burst of speed rather than a
	#    silent glide. Skipped for small enemies (base_scale < 0.8) since
	#    their lunges are too short for a trail to be visible, and for
	#    mind-controlled enemies attacking other enemies (the MC color
	#    trail would be confusing — the particle color wouldn't match the
	#    target's attacker in the kill feed).
	if base_scale >= 0.8 and not player.is_in_group("enemies"):
		ParticleEffects.spawn_dash_trail(get_parent(), global_position, current_color)

	# Restore scale — ease-out cubic so the enemy settles back to base size
	# with a decelerating curve, reading as a natural recovery from the lunge
	# rather than a mechanical linear snap.
	var restore_tween := create_tween()
	restore_tween.tween_property(self, "scale", Vector3.ONE * base_scale, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Cooldown before next attack
	get_tree().create_timer(0.1).timeout.connect(_reset_attack_flag)

func _reset_attack_flag() -> void:
	if is_instance_valid(self) and not is_dead:
		is_attacking = false

# ── Windup emission ramp ── Brightens the enemy's emission during the attack
#    windup so the charge-up reads as a glow (visible in all biomes, even when
#    the silhouette squash is hard to see). The ramp eases from the current
#    emission energy to ENEMY_ATTACK_WINDUP_BRIGHTNESS (default 0.5, i.e. +50%
#    above baseline 1.0 → peak 1.5) over the windup duration. The previous
#    emission is cached so _restore_windup_emission() can put it back exactly,
#    even if a hit-flash (which also touches emission_energy_multiplier)
#    fired during the windup. The tween is tracked so a new windup or a
#    hit-flash can kill it cleanly.
func _ramp_windup_emission() -> void:
	if not _material:
		return
	# Kill any in-flight windup emission tween so rapid re-attacks don't stack.
	if _windup_emit_tween and _windup_emit_tween.is_valid():
		_windup_emit_tween.kill()
	_windup_prev_emission = _material.emission_energy_multiplier
	_windup_emit_tween = create_tween()
	_windup_emit_tween.tween_property(
		_material, "emission_energy_multiplier",
		1.0 + GameConstants.ENEMY_ATTACK_WINDUP_BRIGHTNESS,
		GameConstants.ENEMY_ATTACK_WINDUP_TIME
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

## Restore emission energy to the pre-windup value. Called at the start of
## _execute_attack / _execute_attack_on_enemy. Uses the cached value rather
## than a hardcoded 1.0 so the restore is correct even if the enemy was
## mind-controlled (emission 2.0) or enraging when the windup began.
func _restore_windup_emission() -> void:
	if _windup_emit_tween and _windup_emit_tween.is_valid():
		_windup_emit_tween.kill()
		_windup_emit_tween = null
	if _material:
		_material.emission_energy_multiplier = _windup_prev_emission

func take_damage(amount: int) -> void:
	take_damage_from(amount, Vector3.ZERO)

# Phase 8: Damage with knockback direction (called by projectiles that know the hit direction)
func take_damage_from(amount: int, source_pos: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return
	# ── Phase 33: Enemy Variant System — evasive dodge + shielded reduction ──
	# Variants can dodge incoming damage entirely (EVASIVE) or reduce it
	# (SHIELDED). The system returns a dict with the modified damage and a
	# "dodged" flag. If dodged, we skip the rest of the hit logic entirely.
	if EnemyVariantSystem:
		var result: Dictionary = EnemyVariantSystem.on_enemy_take_damage(self, amount)
		if result.get("dodged", false):
			# Show a "DODGE" message above the enemy for feedback
			if has_node("AlertIndicator"):
				var alert: Label3D = $AlertIndicator
				alert.text = "DODGE"
				alert.modulate = Color(0.9, 0.9, 0.9, 1.0)
				alert.visible = true
				var dodge_tween := create_tween()
				dodge_tween.tween_property(alert, "modulate:a", 0.0, 0.4) \
					.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				dodge_tween.tween_callback(func(): alert.visible = false)
			# ── Enhancement Pack 16: Dodge whoosh SFX ── a quick lateral
			# air-distortion sound so the player HEARS the dodge, not just
			# sees the "DODGE" text. Without this, an Evasive variant's
			# dodge reads as "my shot vanished" rather than "the enemy
			# sidestepped it" — the audio communicates the evasion.
			AudioManager.play_sfx(AudioManager.SFX_DODGE)
			return
		amount = int(result.get("damage", amount))
		# ── Shielded variant: blue shield flash on hit ── When a SHIELDED
		# variant absorbs damage, a brief blue emission pulse plays on the
		# hit frame so the player sees the shield working. Without this,
		# the 20% damage reduction is invisible — the player can't tell
		# why this enemy is tankier. The flash sets the emission COLOR to
		# the Shielded trait's signature blue (0.4, 0.6, 1.0) and tweens
		# it back to the enemy's base emission color. The emission ENERGY
		# is left to the hit-flash below (which spikes it to 4.0 and eases
		# back), so the two effects compose cleanly: blue-tinted bright
		# flash → white hit flash → normal. A quick shield-ring scale pop
		# on the body_mesh (biased outward) reinforces the deflector read.
		if result.get("shielded", false) and _material:
			var _shield_prev_emission_color: Color = _material.emission
			_material.emission = Color(0.4, 0.6, 1.0)
			var shield_color_tween := create_tween()
			shield_color_tween.tween_property(_material, "emission",
				_shield_prev_emission_color, 0.22) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			# ── Shield ring pop ── A quick scale pulse on the body_mesh
			# so it reads as a shield deflector bulge rather than a generic
			# hit squash. Runs before the hit squash below — the hit squash
			# will override scale with its own pop, which is fine (the
			# shield pop is 0.05s, the squash starts after).
			if body_mesh and not is_windup and not is_dead:
				var shield_scale_tween := create_tween()
				shield_scale_tween.tween_property(body_mesh, "scale",
					Vector3.ONE * base_scale * 1.18, 0.05) \
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# ── Phase 19: Co-op — mark if this is a P2 projectile hit ──
	# The projectile sets a meta flag on itself; we check via get_meta on the
	# caller. Since we can't access the caller here, P2 projectiles call
	# set_p2_hit() before take_damage_from().
	hp -= amount
	# ── First-hit aggro flash ── Fires once, the first time the enemy
	#    takes damage (transitions from full HP to damaged). Spawns a
	#    small expanding ring in the enemy's color at the enemy's position,
	#    communicating "this enemy is now in combat." Uses the existing
	#    spawn_spawn_ring helper from ParticleEffects for visual consistency
	#    with the spawn materialization ring. Skipped for enemies that
	#    spawn already damaged (HP < max_hp at first hit check).
	if not _first_hit_triggered and hp < max_hp:
		_first_hit_triggered = true
		if ParticleEffects and get_parent():
			ParticleEffects.spawn_spawn_ring(
				get_parent(), global_position,
				base_color, clampf(base_scale * 1.5, 1.5, 3.5))
		# Brief emission brighten on first aggro — the enemy "wakes up"
		if _material:
			var prev_emi: float = _material.emission_energy_multiplier
			_material.emission_energy_multiplier = prev_emi * 2.5
			var aggro_tween := create_tween()
			aggro_tween.tween_property(_material, "emission_energy_multiplier",
				prev_emi, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	enemy_hit.emit(self, amount)
	# Phase 20: Audio — enemy hit SFX
	# ── Size-based pitch: larger enemies get deeper hit sounds so a
	#    Sentinel's hit reads as a heavy thud while a Blob's reads as
	#    a light pop. base_scale ~0.8 (small) → pitch 1.15, ~1.0
	#    (normal) → pitch 1.0, ~2.0+ (boss) → pitch 0.7. The mapping
	#    is a simple inverse scale with clamping.
	var hit_pitch: float = clampf(1.3 - base_scale * 0.2, 0.6, 1.3)
	# ── Distance attenuation ── Hit SFX scales with distance to the player
	#    so far-off combat doesn't play at full volume. Uses the same
	#    smoothstep model as the alert SFX. Close hits (≤15m) are full
	#    volume; distant hits (60m+) are 15% volume.
	var _hit_dist: float = 0.0
	if GameManager.player and is_instance_valid(GameManager.player):
		_hit_dist = global_position.distance_to(GameManager.player.global_position)
	var _hit_vol: float = _compute_dist_atten(_hit_dist)
	AudioManager.play_sfx_pitched_volume(AudioManager.SFX_ENEMY_HIT, hit_pitch, _hit_vol)

	# Hit flash — white albedo + emission spike for a punchy combat read.
	# The albedo snaps to white and the emission energy kicks up, then both
	# ease back over 0.15s. The combined effect is a bright "strobed" flash
	# that reads even in dark biomes.
	# NOTE: Preserve the original alpha (_spawn_target_alpha) so semi-transparent
	# enemies (Void Wisp, etc.) don't briefly become fully opaque during the flash.
	_hit_flash_timer = 0.15
	if _material:
		# Kill any in-flight windup emission tween so the hit-flash owns the
		# emission_energy_multiplier exclusively during its 0.15s window.
		# Without this, the windup ramp and the flash restore would both
		# tween the same property and fight each other. The windup restore
		# (_restore_windup_emission in _execute_attack) will put the cached
		# pre-windup value back after the flash settles.
		if _windup_emit_tween and _windup_emit_tween.is_valid():
			_windup_emit_tween.kill()
			_windup_emit_tween = null
		_material.albedo_color = Color(1.0, 1.0, 1.0, _spawn_target_alpha)
		var _prev_emission_energy: float = _material.emission_energy_multiplier
		_material.emission_energy_multiplier = 4.0
		var flash_tween := create_tween()
		flash_tween.set_parallel(true)
		# Restore to current_color (not base_color) so mind-controlled enemies
		# flash back to their MC color, enraged enemies to their enraged color, etc.
		flash_tween.tween_property(_material, "albedo_color",
			Color(current_color.r, current_color.g, current_color.b, _spawn_target_alpha), 0.15)
		flash_tween.tween_property(_material, "emission_energy_multiplier",
			_prev_emission_energy, 0.15) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_QUAD)

	# Alert on hit
	is_alerted = true

	# ── Hit spark particle burst ── A small directional spray of sparks that
	#    shoot from the hit point back toward the shooter, complementing the
	#    hit flash + squash with a classic Vlambeer-style "spark spray".
	#    The sparks are tinted to the enemy's base color so they read as
	#    "bits of the enemy flying off". Skipped on kills — the death poof
	#    and death light flash already provide the burst, and double-spawning
	#    on the kill frame would clutter the death spectacle.
	if hp > 0 and source_pos != Vector3.ZERO:
		ParticleEffects.spawn_hit_spark(
			get_parent(),
			global_position + Vector3(0, 0.5, 0),
			current_color,
			source_pos
		)

	# ── Hit squash pulse — quick body_mesh scale pop on the hit frame for an
	# extra layer of juicy feedback alongside the color flash. Skipped during
	# windup (the windup tween controls scale and would conflict) and during
	# death (the death tween owns scale). Uses TRANS_ELASTIC rebound so the
	# enemy bounces back to base_scale with a satisfying wobble.
	# ── Directional bias ── The squash is biased toward the hit direction
	#    (source→enemy axis) so the enemy visibly recoils in the direction
	#    it was struck. A hit from the left stretches the enemy to the right,
	#    reinforcing the impact direction. We compute the axis-aligned bias
	#    from the normalized hit direction and lerp the stretch from 1.25
	#    (perpendicular) to 1.45 (along the hit axis) so the squash reads as
	#    directional rather than a uniform inflation. Falls back to the
	#    uniform 1.25 squash if no source position is provided.
	if body_mesh and not is_windup and not is_dead:
		var _hit_bx: float = 1.25
		var _hit_bz: float = 1.25
		if source_pos != Vector3.ZERO:
			var _hit_dir: Vector3 = (global_position - source_pos)
			_hit_dir.y = 0.0
			if _hit_dir.length_squared() > 0.01:
				_hit_dir = _hit_dir.normalized()
				_hit_bx = lerpf(1.25, 1.45, absf(_hit_dir.x))
				_hit_bz = lerpf(1.25, 1.45, absf(_hit_dir.z))
			# Kill any in-flight hit squash tween so rapid hits restart the pop
			# cleanly instead of stacking (multiple projectiles in the same frame).
			if _hit_squash_tween and _hit_squash_tween.is_valid():
				_hit_squash_tween.kill()
			var hit_tween := create_tween()
			_hit_squash_tween = hit_tween
			hit_tween.tween_property(body_mesh, "scale",
				Vector3(_hit_bx, base_scale * 1.25, _hit_bz), 0.04) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			hit_tween.tween_property(body_mesh, "scale",
				Vector3.ONE * base_scale, 0.14) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

	# ── Attack windup interruption (stagger) ── When an enemy takes damage
	#    during its attack windup, the windup is cancelled — the attack
	#    doesn't fire. This rewards aggressive play: hitting an enemy
	#    while it's charging up prevents the attack entirely instead of
	#    just racing the windup timer. The enemy plays a brief "stagger"
	#    visual (recoil scale wobble + scale restore) and SFX so the
	#    player sees and hears that they interrupted the attack. The
	#    windup scale tween and emission tween are both killed cleanly
	#    so neither lingers. is_attacking is reset after a short delay
	#    so the enemy can't immediately re-attack (prevents stagger →
	#    instant re-windup loops). Bosses (max_hp >= 200) are immune to
	#    stagger — their attacks can't be interrupted, only damaged.
	if is_windup and max_hp < 200:
		is_windup = false
		# Kill the windup scale tween so _execute_attack is never called
		if _windup_scale_tween and _windup_scale_tween.is_valid():
			_windup_scale_tween.kill()
			_windup_scale_tween = null
		# Restore windup emission immediately
		_restore_windup_emission()
		# Stagger visual — a quick recoil scale wobble (snap small →
		# bounce back with elastic) distinct from the hit squash. The
		# body_mesh briefly squashes horizontally and stretches
		# vertically as if knocked backward, then wobbles to rest.
		if body_mesh:
			var stagger_scale := Vector3(1.0 + 0.2, 1.0 - 0.15, 1.0 + 0.2)
			var stagger_tween := create_tween()
			stagger_tween.tween_property(body_mesh, "scale",
				Vector3.ONE * base_scale * stagger_scale, 0.06) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			stagger_tween.tween_property(body_mesh, "scale",
				Vector3.ONE * base_scale, 0.22) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		# Restore self.scale from the windup squash
		var restore_scale_tween := create_tween()
		restore_scale_tween.tween_property(self, "scale",
			Vector3.ONE * base_scale, 0.15) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		# Stagger SFX — metallic recoil ping
		AudioManager.play_sfx_pitched(AudioManager.SFX_STAGGER,
			clampf(1.2 - base_scale * 0.15, 0.7, 1.4))
		# Reset attack flag after a short delay (prevents instant re-windup)
		get_tree().create_timer(0.3).timeout.connect(_reset_attack_flag)

	# ── Phase 8: Apply knockback impulse from the hit direction
	if source_pos != Vector3.ZERO:
		var hit_dir: Vector3 = (global_position - source_pos).normalized()
		hit_dir.y = 0
		apply_knockback(hit_dir, GameConstants.KNOCKBACK_FORCE_HIT)

	if hp <= 0:
		_die()

func apply_knockback(direction: Vector3, force: float) -> void:
	# ── Phase 33: Enemy Variant System — KNOCKBACK_IMMUNE trait ──
	# Variants with this trait ignore all knockback impulses.
	if EnemyVariantSystem and EnemyVariantSystem.should_cancel_knockback(self):
		return
	knockback_vel = direction.normalized() * force

# ── Phase 14: Dimension time scale (Time-Slow dimension) ──
func set_time_scale(scale: float) -> void:
	_time_scale = scale

# ── Phase 19: Co-op — mark this enemy as hit by P2 ──
func set_p2_hit() -> void:
	_killed_by_p2 = true

func _die() -> void:
	is_dead = true
	# ── Kill any in-flight hit squash tween so it doesn't reference the
	#    body_mesh after it's hidden/freed. The tween auto-frees on
	#    completion but may still be running the elastic rebound when
	#    death fires (e.g. the killing blow's squash tween).
	if _hit_squash_tween and _hit_squash_tween.is_valid():
		_hit_squash_tween.kill()
		_hit_squash_tween = null
	# ── Phase 24: Clean up mind control state on death ──
	if is_mind_controlled:
		is_mind_controlled = false
		_mind_control_timer = 0.0
		_mind_control_target = null
		var mc_light := get_node_or_null("MCMindLight")
		if mc_light:
			mc_light.queue_free()
	# ── Phase 35: Unregister from LOD management ──
	if PerformanceOptimizer:
		PerformanceOptimizer.unregister_lod_target(self)
	var killer_name: String = GameConstants.P2_NAME if _killed_by_p2 else "Zorp"
	GameManager.register_kill(enemy_name, killer_name)
	GameManager.gain_xp(xp_reward)
	if _killed_by_p2:
		CoOpManager.p2_add_score(score_reward)
	else:
		GameManager.add_score(score_reward)
	# ── Phase 34: Gauntlet mode — notify EndgameManager of each kill ──
	if EndgameManager:
		EndgameManager.notify_gauntlet_kill()
	enemy_died.emit(self)
	# Phase 20: Audio — enemy death SFX
	# ── Size-based pitch: larger enemies get deeper death sounds so a
	#    Drake's death is a weighty boom while a Blob's is a light pop.
	#    Bosses (base_scale >= 2.0) get an even deeper pitch (0.55) so
	#    their death sounds like a major event, not just another kill.
	#    The mapping mirrors the hit SFX but with a wider range so the
	#    death pitch drop is more dramatic than the hit pitch drop —
	#    deaths are lower stakes per-hit but the pitch shift makes
	#    the audio hierarchy clear (small = ping, large = BOOM).
	var death_pitch: float = clampf(1.35 - base_scale * 0.25, 0.5, 1.35)
	# ── Distance attenuation ── Death SFX also scales with distance so
	#    off-screen kills don't play at full volume. The death distance
	#    is already computed below for the camera trauma, but we need it
	#    here before the trauma call. Compute it inline for the SFX.
	var _death_dist: float = 0.0
	if GameManager.player and is_instance_valid(GameManager.player):
		_death_dist = global_position.distance_to(GameManager.player.global_position)
	var _death_vol: float = _compute_dist_atten(_death_dist)
	AudioManager.play_sfx_pitched_volume(AudioManager.SFX_ENEMY_DEATH, death_pitch, _death_vol)
	# ── Phase 18: Boss Arena — emit boss_defeated for arena-promoted bosses ──
	if is_arena_boss:
		GameManager.boss_defeated.emit(self)
		GameManager.clear_current_boss()
	# ── Phase 26: World Bosses — emit boss_defeated so WorldBossManager drops
	# the loot shower and clears its active-world-boss reference. World bosses
	# are NOT arena-bound, so we do NOT call clear_current_boss() here. ──
	if is_world_boss:
		GameManager.boss_defeated.emit(self)
	# ── Boss death spectacle for arena-promoted and world bosses ──
	# Dedicated boss scripts (Drake, Void Leviathan, Ancient Sentinel, Shadow
	# Clone) call spawn_boss_death_spectacle() in their own _die() override.
	# But arena-promoted regular enemies and world bosses fall through to this
	# base _die(), so they only got the standard death poof + shockwave — a
	# flat finale for such a climactic kill. Now ALL boss-tier deaths get the
	# full spectacle: mega explosion + sky beam + 200-particle ring shockwave,
	# a heavy 0.6 camera trauma (vs 0.35 cap for normal enemies), and a 90ms
	# hit-stop freeze (0.04x time scale) so the killing blow lands with real
	# weight. The hit-stop uses the same scene-tree timer + ignore_time_scale
	# pattern as the projectile's _trigger_hitstop so it survives the enemy's
	# queue_free and restores Engine.time_scale to 1.0 exactly on time.
	var _is_promoted_boss: bool = is_arena_boss or is_world_boss
	if _is_promoted_boss:
		ParticleEffects.spawn_boss_death_spectacle(
			get_parent(), global_position, base_color, base_scale)
		# Override the normal death camera trauma with a heavier boss shake.
		# The normal _trigger_camera_trauma call below still runs, but
		# add_trauma() accumulates so we just add the boss delta on top.
		_trigger_camera_trauma(0.6)
		# Boss-kill hit-stop — 90ms near-stop freeze for weighty kill blow.
		# Routed through HitStopCoordinator for correct overlap composition.
		HitStopCoordinator.request_freeze(0.04, 0.09)
	# Remove from GameManager's enemy list to prevent the array from growing
	# with invalid references over time (performance leak).
	GameManager.enemies.erase(self)

	# ── Phase 16: Drop crafting materials on death ──
	_drop_crafting_material()

	# ── Phase 27: Drop pet evolution stones on death ──
	_drop_pet_stone()

	# ── Phase 29: Drop rare crafting materials on death ──
	# Rare materials drop from bosses (always), during matching weather (+6%),
	# and in matching biomes (+4%). Normal enemies have a 4% base chance.
	_drop_rare_material()

	# ── Phase 33: Enemy Variant System — variant death hook ──
	# Triggers the Exploding trait AoE, bonus loot drop for Champions, and
	# Statistics tracking. Must be called BEFORE the node is freed; we call it
	# here while the enemy is still valid and positioned.
	if EnemyVariantSystem:
		EnemyVariantSystem.on_variant_death(self)

	# ── Phase 10: Clean up AI controller ──
	if ai_controller:
		ai_controller.cleanup()
		ai_controller = null

	# Camera shake on enemy death (bigger for larger enemies)
	# ── Distance attenuation ── The shake is scaled by how far the enemy is
	#    from the player. A point-blank kill shakes the camera fully; a kill
	#    at 60+ meters barely registers. This prevents off-screen kills from
	#    shaking the camera as hard as close-range ones, which felt
	#    disorienting — the player sees the screen shake but doesn't see
	#    what caused it. The attenuation uses a smoothstep so close kills
	#    (≤15m) get full shake and far kills (≥60m) get ~10% shake.
	var death_trauma_base: float = clampf(base_scale * 0.15, 0.08, 0.35)
	var death_dist_mult: float = 1.0
	if GameManager.player and is_instance_valid(GameManager.player):
		var death_dist: float = global_position.distance_to(GameManager.player.global_position)
		# Smoothstep: 15m → 1.0 (full), 60m → 0.1 (minimal), smooth S-curve
		var dist_t: float = clampf((death_dist - 15.0) / 45.0, 0.0, 1.0)
		dist_t = 1.0 - dist_t * dist_t * (3.0 - 2.0 * dist_t)  # Inverted smoothstep
		death_dist_mult = lerpf(0.1, 1.0, dist_t)
	# ── Directional death shake bias ── The camera should recoil *away*
	# from the kill, as if the enemy's death explosion pushed the camera
	# back. Without a bias, the shake is a centered wobble that doesn't
	# convey where the kill happened — the player feels a generic rumble
	# instead of a directional impact. We compute the direction from the
	# enemy to the player (horizontal only) and pass it as the bias so the
	# shake kicks the camera toward the player, away from the explosion.
	var death_bias: Vector3 = Vector3.ZERO
	if GameManager.player and is_instance_valid(GameManager.player):
		death_bias = GameManager.player.global_position - global_position
		death_bias.y = 0.0
		if death_bias.length_squared() > 0.01:
			death_bias = death_bias.normalized()
	_trigger_camera_trauma(death_trauma_base * death_dist_mult, death_bias)

	# Phase 6: Death poof particles
	ParticleEffects.spawn_death_poof(get_parent(), global_position, base_color, base_scale)

	# ── Death shockwave ring for large enemies — a flat expanding ring that
	#    gives bigger enemies a weighty, cinematic death impact. Small enemies
	#    (Blobs, Wisps, Swarm Mites) just get the poof; larger foes (Sentinels,
	#    Drakes, Crystal Guardians, Bombers) get the ring too. Ring radius
	#    scales with enemy size so a Drake gets a bigger shockwave than a Bomber.
	if base_scale >= 1.5:
		var shockwave_radius: float = clampf(base_scale * 3.5, 4.0, 12.0)
		ParticleEffects.spawn_death_shockwave(get_parent(), global_position, base_color, shockwave_radius)

	# ── Death light flash ── A brief OmniLight3D that flashes the enemy's
	#    color at the death point, then fades. Gives extra punch in dark biomes
	#    where the particle burst alone can be hard to see. Intensity scales
	#    with enemy size so a Drake gets a bigger flash than a Blob.
	#    POOLING: Uses the PerformanceOptimizer transient light pool instead
	#    of creating/freeing a new OmniLight3D per death. The pool handles
	#    the light lifecycle — we just tween the energy and the pool
	#    auto-reclaims it after the duration.
	var death_flash_energy: float = 3.0 + base_scale * 2.0
	var death_flash_range: float = 4.0 + base_scale * 3.0
	if PerformanceOptimizer:
		var death_light := PerformanceOptimizer.acquire_transient_light(
			global_position + Vector3(0, 0.5, 0),
			base_color,
			death_flash_energy,
			0.35,
			death_flash_range,
			1.2
		)
		if death_light:
			var light_tween := death_light.create_tween()
			light_tween.tween_property(death_light, "light_energy", 0.0, 0.3) \
				.set_ease(Tween.EASE_OUT) \
				.set_trans(Tween.TRANS_QUAD)
	else:
		# Fallback: create a standalone light (non-pooled path)
		var death_light := OmniLight3D.new()
		death_light.light_color = base_color
		death_light.light_energy = death_flash_energy
		death_light.omni_range = death_flash_range
		death_light.omni_attenuation = 1.2
		get_parent().add_child(death_light)
		death_light.global_position = global_position + Vector3(0, 0.5, 0)
		var light_tween := death_light.create_tween()
		light_tween.tween_property(death_light, "light_energy", 0.0, 0.3) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_QUAD)
		light_tween.tween_callback(death_light.queue_free)

	# ── Phase 8: Enemy corpse physics ── Spawn a RigidBody3D proxy corpse
	#    that tumbles and settles realistically before fading out and freeing.
	#    The corpse uses a simple sphere or box RigidBody3D matching the enemy's
	#    shape, with an initial impulse based on the last knockback/velocity
	#    direction for a physics-driven death tumble. The original enemy node
	#    hides immediately (no tween scale-down) while the corpse handles the
	#    visual death animation via physics + a fade-out timer.
	_spawn_physics_corpse()

	# ── Death emission burst ── A brief white-hot emission spike on the
	#    death frame so the enemy reads as releasing its energy before the
	#    body vanishes and the corpse takes over. Without this, the enemy
	#    goes from hit-flash → invisible in one frame — the death reads as
	#    a "pop out of existence" rather than an "energy discharge." The
	#    spike is a quick white-hot emission energy ramp (→ 6.0) that eases
	#    back to 0 over 0.2s, overlapping with the death poof particles and
	#    death light flash so all three fire together for a cohesive
	#    spectacle. The emission also briefly shifts to white-hot (lerp
	#    current_color → white at 70%) so the death flash is a bright
	#    "overload" read rather than just the enemy's color getting brighter.
	#    The tween is on the _material (not self) so it survives the
	#    immediate `visible = false` below — the material's emission is
	#    visible through the corpse mesh's own material, not the enemy's.
	#    Skipped if the material was already freed (safety on scene teardown).
	if _material:
		_material.emission = current_color.lerp(Color(1.0, 1.0, 1.0), 0.7)
		_material.emission_energy_multiplier = 6.0
		var death_emit_tween := create_tween()
		death_emit_tween.tween_property(_material, "emission_energy_multiplier",
			0.0, 0.2) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Hide the original enemy immediately — the corpse takes over visually
	visible = false
	# Free the enemy node shortly after (let signals/cleanup finish first)
	var tree := get_tree()
	if tree:
		tree.create_timer(0.1).timeout.connect(queue_free)

## ── Phase 26: Public despawn fade for world bosses ──
## Called by WorldBossManager when a world boss despawns without dying (player
## fled or player died). Marks the enemy dead so the normal death sequence is
## skipped, then fades the body out + shrinks it before queue_free(). This
## encapsulates the private _material/body_mesh access so external systems
## don't reach into enemy internals.
func despawn_fade(duration: float = 0.8) -> void:
	is_dead = true  # Prevent normal death sequence from running.
	GameManager.enemies.erase(self)
	if ai_controller:
		ai_controller.cleanup()
		ai_controller = null
	if _material and body_mesh:
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(_material, "albedo_color:a", 0.0, duration)
		t.tween_property(body_mesh, "scale", Vector3(0.01, 0.01, 0.01), duration) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		t.chain().tween_callback(queue_free)
	else:
		queue_free()

## ── Phase 8: Enemy corpse physics ──────────────────────────────────────────────
## Spawns a RigidBody3D proxy corpse that tumbles and settles on the ground
## using the physics engine, then fades out and frees itself after a few seconds.
## The corpse shape mirrors the enemy's body mesh (sphere for most, box for
## angular enemies). An initial angular velocity + linear impulse gives a
## physics-driven death tumble that looks more natural than a scripted tween.
func _spawn_physics_corpse() -> void:
	var parent_node: Node = get_parent()
	if not parent_node:
		return

	# Create the RigidBody3D corpse
	var corpse := RigidBody3D.new()
	corpse.global_position = global_position + Vector3(0, 0.3, 0)
	corpse.collision_layer = 0  # Don't collide with player/enemies
	corpse.collision_mask = 1   # Only collide with world geometry (layer 1)

	# Collision shape — sphere scaled to enemy size
	var col_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5 * base_scale
	col_shape.shape = sphere
	corpse.add_child(col_shape)

	# Visual mesh — semi-transparent copy of the enemy's color
	# Uses the shared sphere mesh (scaled per-corpse via the node's scale)
	# to avoid allocating a new SphereMesh on every kill.
	_ensure_corpse_shared_resources()
	var corpse_mesh := MeshInstance3D.new()
	corpse_mesh.mesh = _shared_corpse_mesh
	corpse_mesh.scale = Vector3.ONE * base_scale  # Scale the shared mesh
	# Duplicate the shared base material instead of creating one from scratch.
	# The base already has shading_mode, emission_enabled, and transparency
	# pre-configured — we only need to set the per-corpse color + emission.
	var corpse_mat := _shared_corpse_mat_base.duplicate() as StandardMaterial3D
	corpse_mat.albedo_color = Color(base_color.r, base_color.g, base_color.b, 0.7)
	corpse_mat.emission = base_color * 0.1
	corpse_mesh.material_override = corpse_mat
	# ── Corpse spawn emission flash ── The corpse appears the instant the
	#    enemy hides (visible = false). Without a visual bridge, the death
	#    reads as "enemy vanishes → ragdoll appears" — a body swap rather
	#    than a death. A brief emission flash on the corpse's material
	#    (spiking to 3× the base color, easing back over 0.25s) sells the
	#    transition as an "energy discharge" — the enemy's death releases
	#    its remaining energy into the corpse, which flares then dims to
	#    the corpse's dim emission baseline. This composes with the death
	#    emission burst on the enemy's _material (which fires before
	#    visible=false) and the death light flash (which illuminates the
	#    area), creating a three-stage spectacle: enemy flashes → corpse
	#    flashes → ambient light fades. The flash uses the corpse's own
	#    material so it survives the enemy's queue_free.
	var corpse_flash_tween := corpse.create_tween()
	corpse_mat.emission_energy_multiplier = 3.0
	corpse_flash_tween.tween_property(corpse_mat, "emission_energy_multiplier",
		1.0, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	corpse.add_child(corpse_mesh)

	# Physics material with bounce for a lively tumble (shared resource)
	corpse.physics_material_override = _shared_corpse_phys_mat

	# Add to scene
	parent_node.add_child(corpse)
	# ── Phase 23: Tag the corpse so the Gravity Elemental can find and fling it ──
	corpse.add_to_group("physics_corpse")

	# Initial impulse — use current velocity + knockback for direction
	var impulse_dir: Vector3 = velocity.normalized() if velocity.length_squared() > 0.01 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	corpse.apply_central_impulse(impulse_dir * 3.0 * base_scale + Vector3(0, 2.0, 0))
	# Random angular velocity for tumbling
	corpse.angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))

	# Disable sleeping so the corpse keeps tumbling until it settles
	corpse.can_sleep = true

	# Fade out and free after 3 seconds (settle + fade)
	var tree := get_tree()
	if tree:
		# Start fading after 2s, complete by 3s
		var fade_timer := tree.create_timer(2.0)
		fade_timer.timeout.connect(func():
			if is_instance_valid(corpse):
				var fade_tween := corpse.create_tween()
				fade_tween.tween_property(corpse_mat, "albedo_color:a", 0.0, 1.0) \
					.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				fade_tween.tween_callback(corpse.queue_free)
		)
		# Safety free after 4s in case fade tween fails
		var safety_timer := tree.create_timer(4.0)
		safety_timer.timeout.connect(func():
			if is_instance_valid(corpse):
				corpse.queue_free()
		)

func _update_timers(delta: float) -> void:
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	if _hit_flash_timer > 0:
		_hit_flash_timer -= delta

func _update_spawn_visuals(delta: float) -> void:
	# Material fade-in during spawn grace period (quadratic ease-in for smooth appearance)
	if not _material:
		return
	var progress: float = 1.0 - (spawn_grace_timer / GameConstants.ENEMY_SPAWN_GRACE_PERIOD)
	progress = clampf(progress, 0.0, 1.0)
	var eased: float = progress * progress  # quadratic ease-in
	_material.albedo_color.a = _spawn_target_alpha * eased
	# ── Spawn grace "?" anticipation indicator ── During the grace period,
	#    show a pulsing "?" above the enemy to communicate "materializing,
	#    not yet active." This gives new players a clear visual cue that
	#    the enemy is still spawning and can't attack yet — the "?" reads
	#    as "unknown threat / incoming" while the later "!" reads as
	#    "spotted you / attacking." The "?" pulses with a slow breathing
	#    sine and fades in alongside the materialize effect. When the
	#    grace period ends, the "?" is hidden so the activation ground
	#    ring and the subsequent "!" (when the enemy detects the player)
	#    own the indicator. The pulse uses the Label3D's modulate alpha
	#    so it doesn't fight the visible toggle.
	if alert_indicator and not is_dead:
		if progress < 1.0:
			# Still spawning — show pulsing "?"
			if alert_indicator.text != "?":
				alert_indicator.text = "?"
				alert_indicator.modulate = Color(1.0, 0.8, 0.2, 0.0)  # amber, start invisible
			alert_indicator.visible = true
			# Pulse: alpha breathes 0.3..0.7 with a 2 Hz sine, scaled by
			# materialize progress so the "?" fades in as the enemy appears.
			var pulse_alpha: float = (0.3 + 0.4 * absf(sin(progress * PI * 4.0))) * eased
			alert_indicator.modulate.a = pulse_alpha
			# Subtle scale breathing (1.0 → 1.1 → 1.0) synced to the alpha pulse
			var pulse_scale_val: float = 1.0 + 0.1 * absf(sin(progress * PI * 4.0))
			alert_indicator.scale = Vector3.ONE * pulse_scale_val
		else:
			# Grace period just ended — hide the "?" if it's still showing
			if alert_indicator.text == "?":
				alert_indicator.visible = false
				alert_indicator.modulate.a = 1.0
				alert_indicator.scale = Vector3.ONE
	# ── Spawn anticipation pulse ── In the final 25% of the grace period,
	# the enemy does a quick scale pulse to telegraph "about to attack."
	# This is classic anticipation — the enemy visibly "winds up" before
	# becoming active, giving the player a brief window to react. The
	# pulse ramps from base_scale to 1.15x and back, driven by a sine
	# envelope over the last 25% of the grace period. Skipped during the
	# initial spawn tween (which already animates scale from 0.3 → 1.0)
	# to avoid conflicts — we only pulse after the spawn-in tween settles.
	if progress > 0.75 and not is_dead:
		var pulse_progress: float = (progress - 0.75) / 0.25  # 0→1 in last 25%
		# Two quick pulses using a doubled sine frequency
		var pulse_env: float = sin(pulse_progress * PI * 2.0) * 0.5 + 0.5
		var pulse_scale: float = base_scale * (1.0 + 0.15 * pulse_env)
		# Only apply if the spawn-in tween has settled (scale near base)
		# to avoid fighting the initial scale-up animation.
		if scale.length() > base_scale * 0.9:
			scale = Vector3.ONE * pulse_scale

func _update_visuals(delta: float) -> void:
	# Update HP bar color based on HP ratio
	var ratio: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0

	# ── Phase 12: Enemy walk cycle bob ──
	# Subtle vertical bob + sway while moving, giving enemies a more organic feel.
	# Each enemy gets a random phase so groups don't sync.
	if not is_windup and not is_attacking and velocity.length() > 0.5:
		_walk_phase += delta * _walk_freq
		if body_mesh:
			var bob_y: float = sin(_walk_phase) * _walk_amp
			body_mesh.position.y = 0.5 + bob_y
			# Sway: Z sway (side-to-side) + X sway (forward-back) using a
			# 90° phase offset so the two axes create a circular wobble —
			# the enemy "swims" through the air rather than just tilting
			# on one axis. The X sway is smaller (0.5× the Z amplitude) so
			# the dominant read is side-to-side with a subtle forward-back
			# undulation underneath. This gives the walk cycle a more
			# organic, three-dimensional feel.
			var sway: float = sin(_walk_phase * 0.5) * 0.08
			var sway_x: float = sin(_walk_phase * 0.5 + PI * 0.5) * 0.04
			body_mesh.rotation.z = sway
			body_mesh.rotation.y = sway_x
			# ── Forward lean: tilt the mesh ~5° toward the movement direction ──
			# Gives enemies a sense of momentum and urgency when chasing the
			# player. Smoothed via exponential lerp so the lean eases in/out
			# rather than snapping. Only applies on the X axis (pitch) so it
			# reads as a forward lean, not a sideways tilt. The lean direction
			# is derived from the horizontal velocity.
			var horiz_vel := Vector2(velocity.x, velocity.z)
			if horiz_vel.length() > 1.0:
				var speed_frac: float = clampf(horiz_vel.length() / speed, 0.0, 1.0)
				var target_pitch: float = -speed_frac * 0.09  # ~5° forward tilt
				body_mesh.rotation.x = lerpf(body_mesh.rotation.x, target_pitch,
					1.0 - exp(-8.0 * delta))
			else:
				body_mesh.rotation.x = lerpf(body_mesh.rotation.x, 0.0,
					1.0 - exp(-6.0 * delta))
	elif body_mesh and not is_windup:
		# Settle to rest position when not moving.
		# Uses frame-rate-independent exponential lerp (1 - exp(-k*delta))
		# instead of move_toward with a fixed delta-scaled step. The old
		# move_toward(... delta * 3.0) was frame-rate dependent — at 144Hz
		# the settle rate per real second was 2.4x slower than at 60Hz,
		# making the rest pose ease-in feel sluggish on high-refresh
		# displays. Exponential lerp converges at the same real-time rate
		# regardless of FPS, matching the lean/bob smoothing above.
		var settle_w: float = 1.0 - exp(-6.0 * delta)
		body_mesh.position.y = lerpf(body_mesh.position.y, 0.5, settle_w)
		body_mesh.rotation.z = lerpf(body_mesh.rotation.z, 0.0, settle_w)
		body_mesh.rotation.x = lerpf(body_mesh.rotation.x, 0.0, settle_w)
		body_mesh.rotation.y = lerpf(body_mesh.rotation.y, 0.0, settle_w)
		# ── Idle breathing ── When stationary, add a subtle breathing
		#    scale pulse + Y bob so the enemy feels alive rather than
		#    frozen. Skipped during hit-flash (tween controls albedo),
		#    death, and attacking (those own mesh.scale). The pulse is
		#    tiny (±4% scale, ±2cm bob) so it reads as organic life.
		#    ── Hit squash guard ── Also skip while the hit squash tween
		#    is still running. The hit squash uses TRANS_ELASTIC (0.18s
		#    total) but _hit_flash_timer is only 0.15s — so for ~0.03s
		#    the squash tween is still animating body_mesh.scale AFTER
		#    the flash timer expired. Without this guard, the idle
		#    breathing code would overwrite body_mesh.scale during that
		#    window, causing a visible pop as the elastic rebound is
		#    cut short. The tracked tween reference is checked for
		#    validity so completed tweens (which auto-free) don't block.
		if not is_dead and not is_attacking and _hit_flash_timer <= 0 \
				and not (_hit_squash_tween and _hit_squash_tween.is_valid()):
			_idle_breath_phase += delta * _idle_breath_speed
			var breath_y: float = sin(_idle_breath_phase) * _IDLE_BREATH_Y_AMP
			body_mesh.position.y = 0.5 + breath_y
			var breath_scale: float = 1.0 + sin(_idle_breath_phase) * _IDLE_BREATH_SCALE_AMP
			# Only apply if no external tween is controlling scale (avoid
			# fighting the spawn-in scale tween, which runs during the
			# grace period and sets self.scale, not body_mesh.scale).
			if spawn_grace_timer <= 0:
				body_mesh.scale = Vector3.ONE * base_scale * breath_scale

	# Low-HP warning pulse — only when not currently being hit-flashed
	# (hit flash tween controls _material.albedo_color during its 0.15s duration)
	# ── Phase 10: Skip if the AI controller is managing enrage color ──
	var enrage_active: bool = false
	if ai_controller and ai_controller.is_enraged:
		enrage_active = true
	if ratio < 0.25 and ratio > 0 and _material and not is_windup and _hit_flash_timer <= 0 and not enrage_active:
		# Don't override while a hit-flash tween is active
		if _material.albedo_color != Color.WHITE:
			var pulse := 0.5 + 0.5 * sin(GameManager.game_time * 8.0)
			var warning_color := Color(1.0, 0.1, 0.1).lerp(Color.WHITE, pulse * 0.3)
			# Preserve the original alpha (e.g. Void Wisp is semi-transparent)
			warning_color.a = _spawn_target_alpha
			_material.albedo_color = warning_color
			# ── Low-HP emission pulse ── The albedo was pulsing red-white but
			#    the emission energy was flat, so in dark biomes the low-HP
			#    warning was invisible — the enemy silhouette pulsed but
			#    didn't *glow* danger. Now the emission energy pulses in sync
			#    with the albedo (peaking at 2.5x baseline) so low-HP enemies
			#    radiate a threatening red glow that's visible against any
			#    background. The emission color shifts toward red on the
			#    pulse peak, reinforcing the danger read even further.
			_material.emission_energy_multiplier = 1.0 + pulse * 1.5
			_material.emission = current_color.lerp(Color(1.0, 0.05, 0.05), pulse * 0.6) * 0.4

func _trigger_camera_trauma(amount: float, bias_dir: Vector3 = Vector3.ZERO) -> void:
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(amount, bias_dir)

# ── Distance attenuation helper ── Returns a volume multiplier (0.15–1.0)
#    based on distance to the player. Uses the same smoothstep model as the
#    spawn SFX distance attenuation: 15m = full volume (1.0), 60m+ = 15%.
#    Shared by the alert SFX and any other enemy-originated sound that
#    should be quieter when the source is far from the player.
func _compute_dist_atten(dist: float) -> float:
	var dist_t: float = clampf((dist - 15.0) / 45.0, 0.0, 1.0)
	dist_t = 1.0 - dist_t * dist_t * (3.0 - 2.0 * dist_t)  # Inverted smoothstep
	return lerpf(0.15, 1.0, dist_t)

# ─── Phase 16: Weapon Mod Crafting — material drops ───────────────────────────

## The Collectible scene, used for spawning material drops.
const COLLECTIBLE_DROP_SCENE := preload("res://scenes/entities/collectible.tscn")

# ── Shared corpse resources ── The physics corpse spawned on enemy death
# creates a SphereMesh, PhysicsMaterial, and SphereShape3D per kill. The
# mesh and physics material are identical across all corpses (only the
# scale and color differ, which are set on the node, not the resource), so
# we share them to eliminate per-kill GPU/physics resource allocation.
# The per-corpse StandardMaterial3D is still created per instance because
# the fade-out tween writes its alpha independently.
static var _shared_corpse_mesh: SphereMesh = null
static var _shared_corpse_phys_mat: PhysicsMaterial = null
# ── Shared base corpse material ── Creating a StandardMaterial3D from scratch
#    per kill (6+ property assignments) is wasteful when the only per-instance
#    variation is the color (base_color) and the alpha fade tween. We create a
#    single base material once and duplicate() it per corpse — duplicate() is
#    a single-shot copy of all pre-configured properties, which is measurably
#    cheaper than 6+ individual property sets. The duplicate still gets its
#    own albedo_color and emission overwritten per-corpse, and the alpha tween
#    writes to the duplicate's albedo_color.a independently.
static var _shared_corpse_mat_base: StandardMaterial3D = null

static func _ensure_corpse_shared_resources() -> void:
	if _shared_corpse_mesh == null:
		_shared_corpse_mesh = SphereMesh.new()
		_shared_corpse_mesh.radius = 0.5
		_shared_corpse_mesh.height = 1.0
		_shared_corpse_mesh.radial_segments = 8
		_shared_corpse_mesh.rings = 4
	if _shared_corpse_phys_mat == null:
		_shared_corpse_phys_mat = PhysicsMaterial.new()
		_shared_corpse_phys_mat.bounce = 0.3
		_shared_corpse_phys_mat.friction = 0.6
	if _shared_corpse_mat_base == null:
		_shared_corpse_mat_base = StandardMaterial3D.new()
		_shared_corpse_mat_base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_corpse_mat_base.emission_enabled = true
		_shared_corpse_mat_base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# albedo_color and emission are overwritten per-corpse after duplicate()

## Drop a crafting material when the enemy dies. Chance depends on enemy type
## (normal enemies have 12% chance, bosses always drop).
## Material type is chosen via a weighted loot table (rarity tiers), with bosses
## using a rarity-biased table so their drops feel more rewarding.
func _drop_crafting_material() -> void:
	var drop_chance: float = GameConstants.CRAFTING_MATERIAL_DROP_CHANCE
	# Bosses (Drake, Sentinel) always drop a material
	var is_boss: bool = base_scale >= 2.0 or max_hp >= 200
	if is_boss:
		drop_chance = GameConstants.CRAFTING_MATERIAL_DROP_CHANCE_BOSS
	# ── Phase 25: Progression System loot chance bonus (Exploration branch) ──
	if ProgressionSystem:
		drop_chance = minf(1.0, drop_chance + ProgressionSystem.get_loot_chance_bonus())
	# ── Phase 29: Equipment loot chance bonus (accessory + set bonuses) ──
	if EquipmentSystem:
		drop_chance = minf(1.0, drop_chance + EquipmentSystem.get_loot_mult_bonus())
	# ── Phase 28: Blood Moon weather — 3x loot chance (high risk, high reward) ──
	# Also applies the weather combo loot bonus if a combo is active.
	drop_chance = minf(1.0, drop_chance * WeatherSystem.get_loot_multiplier())
	# ── Phase 33: World Modifier System — Extra Loot / Famine modifiers ──
	if WorldModifierSystem and WorldModifierSystem.is_initialized():
		drop_chance = minf(1.0, drop_chance * WorldModifierSystem.get_loot_chance_mult())
	# ── Phase 33: Enemy Variant System — variant tier loot multiplier ──
	# Golden variants get 3× loot, Champions 5×. Applied after weather/modifier
	# multipliers so all bonuses compound.
	if EnemyVariantSystem and EnemyVariantSystem.is_variant(self):
		drop_chance = minf(1.0, drop_chance * EnemyVariantSystem.get_variant_loot_mult(self))
	# ── Phase 27: Pet Accessory Lucky Bow loot bonus (only while pet is alive) ──
	if PetAccessorySystem:
		var pet_loot_mult: float = PetAccessorySystem.get_stat_bonus("player_loot_mult")
		if pet_loot_mult > 0.0:
			var pet: Node3D = get_tree().get_first_node_in_group("companion_pet")
			if pet and is_instance_valid(pet) and not (pet.get("is_dead") if "is_dead" in pet else false):
				drop_chance = minf(1.0, drop_chance * (1.0 + pet_loot_mult))
	# ── Phase 33: Crystal Shard anomalous zone — +25% loot bonus ──
	if ProceduralBiomeGenerator:
		drop_chance = minf(1.0, drop_chance * (1.0 + ProceduralBiomeGenerator.get_crystal_shard_loot_bonus()))
	if randf() > drop_chance:
		return
	# Pick a crafting material via the weighted loot table.
	# Bosses use the rarity-biased table (shifts weight toward rare mats).
	var table: Dictionary = GameConstants.CRAFTING_LOOT_TABLE_BOSS_BIAS if is_boss \
		else GameConstants.CRAFTING_LOOT_TABLE
	# ── Phase 34: NG+ / NG++ rare-only loot ──
	# When the active NG tier has NG_TIER_LOOT_RARE_ONLY, replace the standard
	# table with the rare-only table (no common mats drop).
	if EndgameManager and EndgameManager.is_loot_rare_only():
		table = GameConstants.CRAFTING_LOOT_TABLE_RARE_ONLY
	var drop_type: int = _weighted_pick(table)
	# Spawn a collectible at the enemy's position
	var drop: Area3D = COLLECTIBLE_DROP_SCENE.instantiate()
	get_parent().add_child(drop)
	drop.global_position = global_position + Vector3(0, 0.5, 0)
	# Small random scatter so drops don't stack
	drop.global_position.x += randf_range(-1.0, 1.0)
	drop.global_position.z += randf_range(-1.0, 1.0)
	if drop.has_method("set_type"):
		drop.set_type(drop_type)
	# ── Phase 8: Collectible bounce and tumble — physics-driven drop ──
	if drop.has_method("start_tumble"):
		var scatter_dir: Vector3 = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		drop.start_tumble(scatter_dir)
	# Add to GameManager's collectibles list
	GameManager.collectibles.append(drop)
	# Add to collectibles group
	if not drop.is_in_group("collectibles"):
		drop.add_to_group("collectibles")
	# ── Enhancement Pack 23: Visual + audio feedback for crafting material drops ──
	# Crafting materials are common (12% drop rate) so the feedback is subtle —
	# a quiet blip + small sparkle at the enemy's position. This gives the
	# player a subconscious "something shiny dropped" cue without being noisy
	# during heavy combat where multiple materials can drop in quick succession.
	# Boss drops get a slightly louder pitch since they're always guaranteed.
	if AudioManager:
		if is_boss:
			AudioManager.play_sfx_pitched(AudioManager.SFX_CRAFT_DROP, 0.9)
		else:
			AudioManager.play_sfx(AudioManager.SFX_CRAFT_DROP)
	if ParticleEffects and drop.get("TYPE_CONFIG") is Dictionary:
		var drop_config: Dictionary = drop.TYPE_CONFIG.get(drop_type, {})
		if drop_config.has("color"):
			ParticleEffects.spawn_pickup_sparkle(
				get_parent(), global_position + Vector3(0, 0.8, 0), drop_config["color"])


## Weighted random pick from a {type: weight} dictionary. Returns a random key
## with probability proportional to its weight. Falls back to uniform random
## from the keys if all weights are zero (degenerate edge case).
static func _weighted_pick(table: Dictionary) -> int:
	var total_weight: float = 0.0
	for w in table.values():
		total_weight += w
	if total_weight <= 0.0:
		var keys: Array = table.keys()
		return keys[randi() % keys.size()] if not keys.is_empty() else GameConstants.CollectibleType.SPACE_GLOOP
	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for key in table.keys():
		cumulative += table[key]
		if roll <= cumulative:
			return key
	# Fallback (shouldn't reach here due to float rounding)
	var keys: Array = table.keys()
	return keys[keys.size() - 1]


# ─── Phase 27: Pet Evolution Stone Drops ──────────────────────────────────────

## Drop a pet evolution stone when the enemy dies. Normal enemies have a 1.5%
## chance (plus biome bonus); bosses always drop one. The stone type is chosen
## via a weighted table that biases toward the current biome's thematic path
## (e.g. Lava → Ember Stone, Snow → Frost Stone).
func _drop_pet_stone() -> void:
	var is_boss: bool = base_scale >= 2.0 or max_hp >= 200 or is_arena_boss or is_world_boss
	var drop_chance: float = GameConstants.PET_STONE_BOSS_DROP_CHANCE if is_boss \
		else GameConstants.PET_STONE_DROP_CHANCE
	# Biome bonus — adds to the drop chance based on current biome
	var biome: int = GameManager.current_biome if "current_biome" in GameManager else -1
	if biome >= 0 and GameConstants.PET_STONE_DROP_BIOME_BONUS.has(biome):
		drop_chance += GameConstants.PET_STONE_DROP_BIOME_BONUS[biome]
	# Clamp for normal enemies (bosses can exceed 1.0 — always drops)
	if not is_boss:
		drop_chance = minf(1.0, drop_chance)
	if randf() > drop_chance:
		return
	# Pick a stone type via a weighted table biased by current biome.
	var stone_type: int = _pick_pet_stone_type(biome)
	# Spawn a collectible at the enemy's position
	var drop: Area3D = COLLECTIBLE_DROP_SCENE.instantiate()
	get_parent().add_child(drop)
	drop.global_position = global_position + Vector3(0, 0.5, 0)
	# Small random scatter so drops don't stack with crafting mats
	drop.global_position.x += randf_range(-1.2, 1.2)
	drop.global_position.z += randf_range(-1.2, 1.2)
	if drop.has_method("set_type"):
		drop.set_type(stone_type)
	# Tumble physics for a satisfying drop
	if drop.has_method("start_tumble"):
		var scatter_dir: Vector3 = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		drop.start_tumble(scatter_dir)
	# Add to GameManager's collectibles list
	GameManager.collectibles.append(drop)
	if not drop.is_in_group("collectibles"):
		drop.add_to_group("collectibles")
	# ── Enhancement Pack 23: Visual + audio feedback for pet stone drops ──
	# Pet stones are rare (1.5% normal, 100% boss) and the player should know
	# immediately when one drops so they can spot the collectible on the ground.
	# A color-matched sparkle burst + dedicated SFX draws the player's attention
	# to the drop location. The stone color comes from PET_STONE_COLORS indexed
	# by the PetPath that the stone maps to.
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_PET_STONE_DROP)
	if ParticleEffects and GameConstants.PET_STONE_TO_PATH.has(stone_type):
		var stone_path_idx: int = GameConstants.PET_STONE_TO_PATH[stone_type]
		if stone_path_idx < GameConstants.PET_STONE_COLORS.size():
			var stone_color: Color = GameConstants.PET_STONE_COLORS[stone_path_idx]
			ParticleEffects.spawn_pickup_sparkle(
				get_parent(), global_position + Vector3(0, 1.0, 0), stone_color)


## Pick a pet stone type via a weighted table. The current biome biases the
## selection toward its thematic path (e.g. Lava → Ember Stone). Falls back
## to a uniform random pick if the biome has no bias.
func _pick_pet_stone_type(biome: int) -> int:
	# Base equal-weight table for all 5 stones
	var base_weights: Dictionary = {
		GameConstants.CollectibleType.EMBER_STONE: 1.0,
		GameConstants.CollectibleType.FROST_STONE: 1.0,
		GameConstants.CollectibleType.SPARK_STONE: 1.0,
		GameConstants.CollectibleType.VOID_STONE: 1.0,
		GameConstants.CollectibleType.LEAF_STONE: 1.0,
	}
	# Biome biases — add extra weight to the thematic stone
	var biome_bias: Dictionary = {
		GameConstants.Biome.LAVA: GameConstants.CollectibleType.EMBER_STONE,
		GameConstants.Biome.VOLCANO_CORE: GameConstants.CollectibleType.EMBER_STONE,
		GameConstants.Biome.SNOW: GameConstants.CollectibleType.FROST_STONE,
		GameConstants.Biome.CRYSTAL_CAVERNS: GameConstants.CollectibleType.FROST_STONE,
		GameConstants.Biome.DEEP_OCEAN: GameConstants.CollectibleType.FROST_STONE,
		GameConstants.Biome.ALIEN: GameConstants.CollectibleType.SPARK_STONE,
		GameConstants.Biome.DIGITAL_GRID: GameConstants.CollectibleType.SPARK_STONE,
		GameConstants.Biome.UNDERGROUND: GameConstants.CollectibleType.VOID_STONE,
		GameConstants.Biome.CRYSTAL: GameConstants.CollectibleType.VOID_STONE,
		GameConstants.Biome.FOREST: GameConstants.CollectibleType.LEAF_STONE,
		GameConstants.Biome.MUSHROOM: GameConstants.CollectibleType.LEAF_STONE,
		GameConstants.Biome.SWAMP: GameConstants.CollectibleType.LEAF_STONE,
	}
	if biome_bias.has(biome):
		var favored: int = biome_bias[biome]
		base_weights[favored] = base_weights[favored] + 2.0  # +2 weight for the biome's stone
	return _weighted_pick(base_weights)


# ─── Phase 29: Rare Material Drops ────────────────────────────────────────────

## Drop a rare crafting material when the enemy dies. Rare materials are used
## for equipment crafting and refinement. They drop from:
##   - Bosses (always — 100% chance, biased toward VOID_CORE/PRISM_HEART)
##   - Normal enemies (4% base chance, +6% during matching weather, +4% in matching biome)
## The rare material is added directly to the EquipmentSystem inventory (no
## physical collectible drop — rare materials are abstracted as inventory entries
## to avoid spawning yet another collectible type that the player has to chase).
## This keeps the gameplay loop clean: kill enemies → check Equipment menu → craft.
func _drop_rare_material() -> void:
	if not EquipmentSystem:
		return
	var is_boss: bool = base_scale >= 2.0 or max_hp >= 200 or is_arena_boss or is_world_boss
	# ── Phase 35: Balance pass — level-scaled rare material drop chance ──
	# Late-game players get a subtle bonus so they aren't starved of rare mats.
	var drop_chance: float
	if BalanceManager and BalanceManager.is_initialized():
		drop_chance = BalanceManager.get_rare_material_drop_chance(GameManager.player_level, is_boss)
	else:
		drop_chance = GameConstants.RARE_MATERIAL_DROP_CHANCE_BOSS if is_boss \
			else GameConstants.RARE_MATERIAL_DROP_CHANCE
	# Weather bonus — adds to drop chance during matching weather
	var current_weather: int = -1
	if WeatherSystem and WeatherSystem.has_method("get_current_weather"):
		current_weather = WeatherSystem.get_current_weather()
	if current_weather >= 0 and GameConstants.RARE_MATERIAL_WEATHER_DROPS.has(current_weather):
		drop_chance += GameConstants.RARE_MATERIAL_WEATHER_BONUS
	# Biome bonus — adds to drop chance in matching biome
	var biome: int = GameManager.current_biome if "current_biome" in GameManager else -1
	if biome >= 0 and GameConstants.RARE_MATERIAL_BIOME_DROPS.has(biome):
		drop_chance += GameConstants.RARE_MATERIAL_BIOME_BONUS
	# Clamp for normal enemies (bosses can exceed 1.0 — always drops)
	if not is_boss:
		drop_chance = minf(1.0, drop_chance)
	# ── Phase 28: Blood Moon weather — 3x loot chance applies to rare mats too ──
	drop_chance = minf(1.0, drop_chance * WeatherSystem.get_loot_multiplier())
	if randf() > drop_chance:
		return
	# Pick the rare material type
	var rm_type: int = _pick_rare_material_type(is_boss, current_weather, biome)
	# Add directly to the EquipmentSystem inventory (no physical collectible)
	EquipmentSystem.add_rare_material(rm_type, 1)
	# Show a HUD message for the rare drop (so the player knows what they got)
	var rm_name: String = GameConstants.RARE_MATERIAL_NAMES[rm_type]
	var rarity_color: Color = GameConstants.RARE_MATERIAL_COLORS[rm_type]
	if is_boss:
		GameManager.add_message("💎 %s dropped %s!" % [enemy_name, rm_name])
	else:
		GameManager.add_message("💎 Rare drop: %s" % rm_name)
	# ── Enhancement Pack 23: Visual + audio feedback for rare material drops ──
	# Rare materials are added directly to inventory (no physical collectible),
	# so previously the only feedback was a text message — easy to miss during
	# combat. Now we play a dedicated SFX + spawn a color-matched particle burst
	# + brief OmniLight flash at the enemy's position so the player sees and
	# hears exactly where the rare drop happened.
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_RARE_DROP)
	if ParticleEffects:
		ParticleEffects.spawn_pickup_sparkle(
			get_parent(), global_position + Vector3(0, 1.0, 0), rarity_color)
	# Brief color-matched light flash for visibility in dark biomes
	var _rm_light := OmniLight3D.new()
	_rm_light.light_color = rarity_color
	_rm_light.light_energy = 4.0
	_rm_light.omni_range = 6.0
	_rm_light.omni_attenuation = 1.5
	get_parent().add_child(_rm_light)
	_rm_light.global_position = global_position + Vector3(0, 1.0, 0)
	var _rm_light_tween := _rm_light.create_tween()
	_rm_light_tween.tween_property(_rm_light, "light_energy", 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_rm_light_tween.tween_callback(_rm_light.queue_free)
	# Statistics tracking
	if Statistics and Statistics.has_method("record_rare_material_drop"):
		Statistics.record_rare_material_drop(rm_type)

## Pick a rare material type via a weighted table. Bosses bias toward
## VOID_CORE/PRISM_HEART. Weather and biome biases add weight to their
## thematic materials. Falls back to a uniform random pick if no biases apply.
func _pick_rare_material_type(is_boss: bool, current_weather: int, biome: int) -> int:
	# Base equal-weight table for all 12 rare materials
	var base_weights: Dictionary = {}
	for i in range(GameConstants.RARE_MATERIAL_NAMES.size()):
		base_weights[i] = 1.0
	# Boss bias — heavily favor VOID_CORE and PRISM_HEART
	if is_boss:
		for rm_id in GameConstants.RARE_MATERIAL_BOSS_DROPS:
			base_weights[rm_id] = base_weights[rm_id] + 4.0
	# Weather bias — favor the weather's thematic material
	if current_weather >= 0 and GameConstants.RARE_MATERIAL_WEATHER_DROPS.has(current_weather):
		var favored: int = GameConstants.RARE_MATERIAL_WEATHER_DROPS[current_weather]
		base_weights[favored] = base_weights[favored] + 3.0
	# Biome bias — favor the biome's thematic material
	if biome >= 0 and GameConstants.RARE_MATERIAL_BIOME_DROPS.has(biome):
		var favored_b: int = GameConstants.RARE_MATERIAL_BIOME_DROPS[biome]
		base_weights[favored_b] = base_weights[favored_b] + 2.0
	return _weighted_pick(base_weights)