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

	var player: Node3D = _cached_player
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

	if not is_alerted and dist_to_player < effective_detect_range:
		is_alerted = true
		alert_indicator_timer = GameConstants.ENEMY_ALERT_INDICATOR_DURATION
		if alert_indicator:
			alert_indicator.visible = true
			alert_indicator.text = "!"
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
	# Deal damage (pass enemy position for damage direction indicator)
	GameManager.take_damage(damage, global_position)

	# Camera shake on player hit
	_trigger_camera_trauma(0.2)

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
	hp -= amount
	enemy_hit.emit(self, amount)

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

	# ── Phase 8: Apply knockback impulse from the hit direction
	if source_pos != Vector3.ZERO:
		var hit_dir: Vector3 = (global_position - source_pos).normalized()
		hit_dir.y = 0
		apply_knockback(hit_dir, GameConstants.KNOCKBACK_FORCE_HIT)

	if hp <= 0:
		_die()

func apply_knockback(direction: Vector3, force: float) -> void:
	knockback_vel = direction.normalized() * force

func _die() -> void:
	is_dead = true
	GameManager.register_kill()
	GameManager.gain_xp(xp_reward)
	GameManager.add_score(score_reward)
	enemy_died.emit(self)
	# Phase 5: Kill feed signal
	GameManager.enemy_killed.emit(enemy_name, "Zorp")

	# ── Phase 10: Clean up AI controller ──
	if ai_controller:
		ai_controller.cleanup()
		ai_controller = null

	# Camera shake on enemy death (bigger for larger enemies)
	_trigger_camera_trauma(clampf(base_scale * 0.15, 0.08, 0.35))

	# Phase 6: Death poof particles
	ParticleEffects.spawn_death_poof(get_parent(), global_position, base_color, base_scale)

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

func _trigger_camera_trauma(amount: float) -> void:
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(amount)