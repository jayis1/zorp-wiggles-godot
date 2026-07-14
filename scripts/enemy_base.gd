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
var is_windup: bool = false
var knockback_vel: Vector3 = Vector3.ZERO

# ─── Wandering ────────────────────────────────────────────────────────────────
var wander_dir: Vector3 = Vector3.ZERO
var wander_timer: float = 3.0

# ─── Visual ──────────────────────────────────────────────────────────────────
var base_color: Color = Color.RED
var current_color: Color = Color.RED
var base_scale: float = 1.0
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
		_material.roughness = 0.6
		_material.emission_enabled = true
		_material.emission = base_color * 0.15
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

	# Apply knockback velocity
	if knockback_vel.length_squared() > 0.01:
		global_position += knockback_vel * delta
		knockback_vel = knockback_vel.move_toward(Vector3.ZERO, 30.0 * delta)

	move_and_slide()

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
	# Deal damage
	GameManager.take_damage(damage)

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
	get_tree().create_timer(0.1).timeout.connect(func(): is_attacking = false)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	hp -= amount
	enemy_hit.emit(self, amount)

	# Hit flash
	if _material:
		_material.albedo_color = Color.WHITE
		var flash_tween := create_tween()
		flash_tween.tween_property(_material, "albedo_color", base_color, 0.15)

	# Alert on hit
	is_alerted = true

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

	# Death animation
	var death_tween := create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(self, "scale", Vector3.ZERO, 0.4).set_ease(Tween.EASE_IN)
	death_tween.tween_property(self, "global_position:y", global_position.y + 1.0, 0.4)
	death_tween.chain().tween_callback(queue_free)

func _update_timers(delta: float) -> void:
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	if hit_flinch_timer > 0:
		hit_flinch_timer -= delta

func _update_spawn_visuals(delta: float) -> void:
	# Visual fade-in during grace period — handled by the spawn scale tween
	pass

func _update_visuals(delta: float) -> void:
	# Update HP bar color based on HP ratio
	var ratio: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0

	# Low-HP warning pulse
	if ratio < 0.25 and ratio > 0 and _material:
		var pulse := 0.5 + 0.5 * sin(GameManager.game_time * 8.0)
		var warning_color := Color(1.0, 0.1, 0.1).lerp(Color.WHITE, pulse * 0.3)
		_material.albedo_color = warning_color