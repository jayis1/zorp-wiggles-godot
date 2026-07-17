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

# ─── Node References ─────────────────────────────────────────────────────────
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var alert_indicator: Label3D = $AlertIndicator

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")

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
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dist_to_player := global_position.distance_to(player.global_position)

	# Detection
	if not is_alerted and dist_to_player < detect_range:
		is_alerted = true
		alert_indicator_timer = GameConstants.ENEMY_ALERT_INDICATOR_DURATION
		if alert_indicator:
			alert_indicator.visible = true
			alert_indicator.text = "!"

	# Alert indicator fade
	if alert_indicator_timer > 0:
		alert_indicator_timer -= delta
		if alert_indicator_timer <= 0 and alert_indicator:
			alert_indicator.visible = false

	# Movement toward player
	if is_alerted and dist_to_player > attack_range:
		var dir := (player.global_position - global_position).normalized()
		dir.y = 0
		velocity = dir * speed
	elif is_alerted and dist_to_player <= attack_range:
		velocity = Vector3.ZERO
		_try_attack(player)
	else:
		# Wander behavior
		_wander(delta)

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

	# Hit flash
	_hit_flash_timer = 0.15
	if _material:
		_material.albedo_color = Color.WHITE
		var flash_tween := create_tween()
		flash_tween.tween_property(_material, "albedo_color", base_color, 0.15)

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

	# Low-HP warning pulse — only when not currently being hit-flashed
	# (hit flash tween controls _material.albedo_color during its 0.15s duration)
	if ratio < 0.25 and ratio > 0 and _material and not is_windup and _hit_flash_timer <= 0:
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