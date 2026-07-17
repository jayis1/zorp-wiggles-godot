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

# ─── State ────────────────────────────────────────────────────────────────────
var hp: int = 50
var is_alerted: bool = false
var is_attacking: bool = false
var attack_cooldown_timer: float = 0.0
var is_dead: bool = false
var spawn_grace_timer: float = GameConstants.ENEMY_SPAWN_GRACE_PERIOD
var alert_indicator_timer: float = 0.0
var hit_flinch_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var is_windup: bool = false
var knockback_vel: Vector3 = Vector3.ZERO
var _spawn_target_alpha: float = 1.0

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

# ─── Node References ─────────────────────────────────────────────────────────
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var alert_indicator: Label3D = $AlertIndicator

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")

	# ── Phase 10: Create AI controller for advanced behaviors ──
	if use_smart_ai:
		ai_controller = EnemyAIController.new()
		ai_controller.setup(self)

	# ── Phase 12: Random walk cycle parameters ──
	_walk_phase = randf_range(0.0, TAU)
	_walk_freq = randf_range(4.0, 8.0)
	_walk_amp = randf_range(0.05, 0.12) * base_scale

	# Spawn grace period — enemy can't detect player for a bit
	spawn_grace_timer = GameConstants.ENEMY_SPAWN_GRACE_PERIOD

	# Random wander direction
	wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	wander_timer = randf_range(2.0, 5.0)

	# Set up material with base color
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

	# Hide alert indicator
	if alert_indicator:
		alert_indicator.visible = false

func _physics_process(delta: float) -> void:
	if GameManager.is_paused or is_dead:
		return

	# ── Phase 14: Apply dimension time scale (Time-Slow dimension) ──
	delta *= _time_scale

	# Spawn grace period
	if spawn_grace_timer > 0:
		spawn_grace_timer -= delta
		_update_spawn_visuals(delta)
		return

	# Check if player is alive
	if not GameManager.player_is_alive:
		return

	_update_ai(delta)
	_update_timers(delta)
	_update_visuals(delta)

	# ── Phase 10: Update smart AI controller (LOS, enrage, shudder, pack, etc.)
	if ai_controller:
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
func _apply_enemy_separation(delta: float) -> void:
	if is_dead:
		return
	var sep_radius: float = GameConstants.ENEMY_SEPARATION_RADIUS + base_scale * 0.5
	for other in GameManager.enemies:
		if other == self or not is_instance_valid(other):
			continue
		var other_base: EnemyBase = other as EnemyBase
		if other_base == null or other_base.is_dead:
			continue
		var d: float = global_position.distance_to(other.global_position)
		if d < sep_radius and d > 0.001:
			# Direction from other → me, push me away
			var push_dir: Vector3 = (global_position - other.global_position).normalized()
			push_dir.y = 0
			# Stronger when closer (inverse-linear falloff)
			var strength: float = GameConstants.ENEMY_SEPARATION_FORCE * (1.0 - d / sep_radius)
			global_position += push_dir * strength * delta

func _update_ai(delta: float) -> void:
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	if not _cached_player:
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
		if alert_indicator:
			alert_indicator.visible = true
			alert_indicator.text = "!"
			# Pop-in bounce: scale from 0 → 1.4 → 1.0 for a juicy "!" appearance.
			# Kills any prior tween so repeated alerts don't stack.
			alert_indicator.scale = Vector3.ZERO
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

	# Attack windup telegraph
	is_windup = true
	var windup_tween := create_tween()
	windup_tween.tween_property(self, "scale",
		Vector3.ONE * base_scale * (1.0 - GameConstants.ENEMY_ATTACK_WINDUP_SQUASH),
		GameConstants.ENEMY_ATTACK_WINDUP_TIME)
	windup_tween.tween_callback(_execute_attack.bind(player))

func _execute_attack(player: Node3D) -> void:
	is_windup = false
	# ── Phase 19: Co-op — damage the correct player ──
	# Check if the target is P2 (Zerp) by checking if it's in the player2 group
	if player and is_instance_valid(player) and player.is_in_group("player2"):
		CoOpManager.p2_take_damage(damage, global_position)
	else:
		# Deal damage to P1 (pass enemy position for damage direction indicator)
		GameManager.take_damage(damage, global_position)

	# Camera shake on player hit — biased toward the enemy's attack direction
	# so the camera lurches away from the attacker, reinforcing the hit feel.
	var attack_dir: Vector3 = Vector3.ZERO
	if player and is_instance_valid(player):
		attack_dir = (player.global_position - global_position).normalized()
		attack_dir.y = 0
	_trigger_camera_trauma(0.2, attack_dir)

	# Forward lunge
	var lunge_dir := (player.global_position - global_position).normalized()
	lunge_dir.y = 0
	var lunge_mult := clampf(base_scale / GameConstants.ENEMY_ATTACK_LUNGE_SIZE_BASE,
		GameConstants.ENEMY_ATTACK_LUNGE_SIZE_MULT_MIN, 1.0)
	var lunge_dist := GameConstants.ENEMY_ATTACK_LUNGE_DISTANCE * lunge_mult

	var lunge_tween := create_tween()
	lunge_tween.tween_property(self, "global_position",
		global_position + lunge_dir * lunge_dist,
		GameConstants.ENEMY_ATTACK_LUNGE_DURATION)

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

	# Restore scale
	var restore_tween := create_tween()
	restore_tween.tween_property(self, "scale", Vector3.ONE * base_scale, 0.15)

	# Cooldown before next attack
	get_tree().create_timer(0.1).timeout.connect(_reset_attack_flag)

func _reset_attack_flag() -> void:
	if is_instance_valid(self) and not is_dead:
		is_attacking = false

func take_damage(amount: int) -> void:
	take_damage_from(amount, Vector3.ZERO)

# Phase 8: Damage with knockback direction (called by projectiles that know the hit direction)
func take_damage_from(amount: int, source_pos: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return
	# ── Phase 19: Co-op — mark if this is a P2 projectile hit ──
	# The projectile sets a meta flag on itself; we check via get_meta on the
	# caller. Since we can't access the caller here, P2 projectiles call
	# set_p2_hit() before take_damage_from().
	hp -= amount
	enemy_hit.emit(self, amount)
	# Phase 20: Audio — enemy hit SFX
	AudioManager.play_sfx(AudioManager.SFX_ENEMY_HIT)

	# Hit flash — white albedo + emission spike for a punchy combat read.
	# The albedo snaps to white and the emission energy kicks up, then both
	# ease back over 0.15s. The combined effect is a bright "strobed" flash
	# that reads even in dark biomes.
	_hit_flash_timer = 0.15
	if _material:
		_material.albedo_color = Color.WHITE
		var _prev_emission_energy: float = _material.emission_energy_multiplier
		_material.emission_energy_multiplier = 4.0
		var flash_tween := create_tween()
		flash_tween.set_parallel(true)
		flash_tween.tween_property(_material, "albedo_color", base_color, 0.15)
		flash_tween.tween_property(_material, "emission_energy_multiplier",
			_prev_emission_energy, 0.15) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_QUAD)

	# Alert on hit
	is_alerted = true

	# ── Hit squash pulse — quick body_mesh scale pop on the hit frame for an
	# extra layer of juicy feedback alongside the color flash. Skipped during
	# windup (the windup tween controls scale and would conflict) and during
	# death (the death tween owns scale). Uses TRANS_ELASTIC rebound so the
	# enemy bounces back to base_scale with a satisfying wobble.
	if body_mesh and not is_windup and not is_dead:
		var hit_tween := create_tween()
		hit_tween.tween_property(body_mesh, "scale",
			Vector3.ONE * base_scale * 1.25, 0.04) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		hit_tween.tween_property(body_mesh, "scale",
			Vector3.ONE * base_scale, 0.14) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

	# ── Phase 8: Apply knockback impulse from the hit direction
	if source_pos != Vector3.ZERO:
		var hit_dir: Vector3 = (global_position - source_pos).normalized()
		hit_dir.y = 0
		apply_knockback(hit_dir, GameConstants.KNOCKBACK_FORCE_HIT)

	if hp <= 0:
		_die()

func apply_knockback(direction: Vector3, force: float) -> void:
	knockback_vel = direction.normalized() * force

# ── Phase 14: Dimension time scale (Time-Slow dimension) ──
func set_time_scale(scale: float) -> void:
	_time_scale = scale

# ── Phase 19: Co-op — mark this enemy as hit by P2 ──
func set_p2_hit() -> void:
	_killed_by_p2 = true

func _die() -> void:
	is_dead = true
	var killer_name: String = GameConstants.P2_NAME if _killed_by_p2 else "Zorp"
	GameManager.register_kill(enemy_name, killer_name)
	GameManager.gain_xp(xp_reward)
	if _killed_by_p2:
		CoOpManager.p2_add_score(score_reward)
	else:
		GameManager.add_score(score_reward)
	enemy_died.emit(self)
	# Phase 20: Audio — enemy death SFX
	AudioManager.play_sfx(AudioManager.SFX_ENEMY_DEATH)
	# ── Phase 18: Boss Arena — emit boss_defeated for arena-promoted bosses ──
	if is_arena_boss:
		GameManager.boss_defeated.emit(self)
		GameManager.clear_current_boss()
	# Remove from GameManager's enemy list to prevent the array from growing
	# with invalid references over time (performance leak).
	GameManager.enemies.erase(self)

	# ── Phase 16: Drop crafting materials on death ──
	_drop_crafting_material()

	# ── Phase 10: Clean up AI controller ──
	if ai_controller:
		ai_controller.cleanup()
		ai_controller = null

	# Camera shake on enemy death (bigger for larger enemies)
	_trigger_camera_trauma(clampf(base_scale * 0.15, 0.08, 0.35))

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
	# color at the death point, then fades. Gives extra punch in dark biomes
	# where the particle burst alone can be hard to see. Intensity scales
	# with enemy size so a Drake gets a bigger flash than a Blob.
	var death_light := OmniLight3D.new()
	death_light.light_color = base_color
	death_light.light_energy = 3.0 + base_scale * 2.0
	death_light.omni_range = 4.0 + base_scale * 3.0
	death_light.omni_attenuation = 1.2
	get_parent().add_child(death_light)
	death_light.global_position = global_position + Vector3(0, 0.5, 0)
	var light_tween := death_light.create_tween()
	light_tween.tween_property(death_light, "light_energy", 0.0, 0.3) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	light_tween.tween_callback(death_light.queue_free)

	# Death animation — scale down with bounce, rise, then free
	var death_tween := create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(self, "scale", Vector3.ZERO, 0.4) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_CUBIC)
	death_tween.tween_property(self, "global_position:y", global_position.y + 1.0, 0.4) \
		.set_ease(Tween.EASE_OUT)
	# Quick spin on death for flair
	death_tween.tween_property(self, "rotation:y", rotation.y + PI, 0.4) \
		.set_ease(Tween.EASE_OUT)
	death_tween.chain().tween_callback(queue_free)

func _update_timers(delta: float) -> void:
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	if hit_flinch_timer > 0:
		hit_flinch_timer -= delta
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
			# Slight Z sway
			var sway: float = sin(_walk_phase * 0.5) * 0.08
			body_mesh.rotation.z = sway
	elif body_mesh and not is_windup:
		# Settle to rest position when not moving
		body_mesh.position.y = move_toward(body_mesh.position.y, 0.5, delta * 3.0)
		body_mesh.rotation.z = move_toward(body_mesh.rotation.z, 0.0, delta * 3.0)

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

func _trigger_camera_trauma(amount: float, bias_dir: Vector3 = Vector3.ZERO) -> void:
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(amount, bias_dir)

# ─── Phase 16: Weapon Mod Crafting — material drops ───────────────────────────

## The Collectible scene, used for spawning material drops.
const COLLECTIBLE_DROP_SCENE := preload("res://scenes/entities/collectible.tscn")

## Drop a crafting material when the enemy dies. Chance depends on enemy type
## (normal enemies have 12% chance, bosses always drop).
func _drop_crafting_material() -> void:
	var drop_chance: float = GameConstants.CRAFTING_MATERIAL_DROP_CHANCE
	# Bosses (Drake, Sentinel) always drop a material
	if base_scale >= 2.0 or max_hp >= 200:
		drop_chance = GameConstants.CRAFTING_MATERIAL_DROP_CHANCE_BOSS
	if randf() > drop_chance:
		return
	# Pick a random crafting material type to drop
	var material_types: Array[int] = GameConstants.CRAFTING_MATERIALS.duplicate()
	material_types.shuffle()
	var drop_type: int = material_types[0]
	# Spawn a collectible at the enemy's position
	var drop: Area3D = COLLECTIBLE_DROP_SCENE.instantiate()
	get_parent().add_child(drop)
	drop.global_position = global_position + Vector3(0, 0.5, 0)
	# Small random scatter so drops don't stack
	drop.global_position.x += randf_range(-1.0, 1.0)
	drop.global_position.z += randf_range(-1.0, 1.0)
	if drop.has_method("set_type"):
		drop.set_type(drop_type)
	# Add to GameManager's collectibles list
	GameManager.collectibles.append(drop)
	# Add to collectibles group
	if not drop.is_in_group("collectibles"):
		drop.add_to_group("collectibles")