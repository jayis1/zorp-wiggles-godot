## Zorp Wiggles — Crystal Guardian (Enhancement: New Enemy Type)
## Slow, high-HP, ranged enemy that fires crystal shard projectiles.
## Tanky but predictable — the counter-strategy is to kite and dodge
## its telegraphed shots. High XP and score reward makes it a priority target.
##
## Behavior: Stationary-ish (very slow), fires crystal shards at the player
## with a charge-up telegraph (like the Spore Spitter). The shards are
## faster but travel in a straight line — dodgeable with dash.

extends EnemyBase

class_name EnemyCrystalGuardian

# ─── Ranged Attack State ──────────────────────────────────────────────────────
var _is_charging: bool = false
var _charge_timer: float = 0.0
const CHARGE_TIME: float = 0.8        # Telegraph time before firing
const CHARGE_SCALE_AMOUNT: float = 0.2  # How much it grows while charging

# Reuse the enemy projectile scene for crystal shards
const SHARD_SCENE := preload("res://scenes/entities/enemy_projectile.tscn")

func _ready() -> void:
	enemy_name = "Crystal Guardian"
	enemy_type = GameConstants.EnemyType.CRYSTAL_GUARDIAN
	max_hp = GameConstants.CRYSTAL_GUARDIAN_HP
	speed = GameConstants.CRYSTAL_GUARDIAN_SPEED
	damage = GameConstants.CRYSTAL_GUARDIAN_DAMAGE
	base_scale = GameConstants.CRYSTAL_GUARDIAN_SCALE
	detect_range = GameConstants.CRYSTAL_GUARDIAN_DETECT_RANGE
	attack_range = GameConstants.CRYSTAL_GUARDIAN_ATTACK_RANGE
	attack_cooldown = GameConstants.CRYSTAL_GUARDIAN_ATTACK_COOLDOWN
	xp_reward = GameConstants.CRYSTAL_GUARDIAN_XP
	score_reward = GameConstants.CRYSTAL_GUARDIAN_SCORE
	base_color = GameConstants.CRYSTAL_GUARDIAN_COLOR
	# Smart AI enabled but flanking disabled — guardians are slow and should
	# hold position at range, not circle around the player.
	use_smart_ai = true
	super._ready()

	# Crystalline material — shiny, high metallic, low roughness
	if _material:
		_material.metallic = 0.6
		_material.roughness = 0.2
		_material.emission = base_color * 0.2
		_material.rim = 1.0  # Strong rim for crystal edge glow

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_dead or GameManager.is_paused or spawn_grace_timer > 0:
		return

	# Handle ranged attack charging
	if _is_charging:
		_charge_timer -= delta * _time_scale
		# Visual: grow slightly while charging (telegraph)
		if body_mesh and is_windup:
			var charge_progress: float = 1.0 - (_charge_timer / CHARGE_TIME)
			var grow: float = 1.0 + charge_progress * CHARGE_SCALE_AMOUNT
			body_mesh.scale = Vector3.ONE * base_scale * grow
		if _charge_timer <= 0:
			_is_charging = false
			_fire_crystal_shard()

func _try_attack(player: Node3D) -> void:
	if attack_cooldown_timer > 0:
		return
	if is_attacking:
		return
	# Mirror dimension / forest mutation — enemies passive
	if DimensionSystem.enemies_passive():
		return
	if MutationSystem.enemies_passive():
		return

	# Don't charge if already charging
	if _is_charging:
		return

	is_attacking = true
	attack_cooldown_timer = attack_cooldown
	_is_charging = true
	_charge_timer = CHARGE_TIME
	is_windup = true  # Prevents walk cycle from overriding scale

	# Telegraph: brighten + grow as it charges
	if _material:
		_material.emission_energy_multiplier = 5.0
		var tw := create_tween()
		tw.tween_property(_material, "emission_energy_multiplier", 1.5, CHARGE_TIME) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Reset attack flag after a delay (don't need lunge for ranged)
	get_tree().create_timer(0.2).timeout.connect(_reset_attack_flag)

func _fire_crystal_shard() -> void:
	is_windup = false
	# Restore mesh scale
	if body_mesh:
		body_mesh.scale = Vector3.ONE * base_scale

	var player: Node3D = null
	if _cached_player and is_instance_valid(_cached_player):
		player = _cached_player
	else:
		player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dir: Vector3 = (player.global_position - global_position).normalized()
	dir.y = 0
	dir = dir.normalized()

	# Spawn the crystal shard projectile
	var shard: Area3D = SHARD_SCENE.instantiate()
	# Set properties before adding to tree (enemy_projectile uses @export projectile_color)
	shard.set("direction", dir)
	shard.set("speed", GameConstants.CRYSTAL_GUARDIAN_SHARD_SPEED)
	shard.set("damage", GameConstants.CRYSTAL_GUARDIAN_SHARD_DAMAGE)
	shard.set("lifetime", GameConstants.CRYSTAL_GUARDIAN_SHARD_LIFETIME)
	shard.set("projectile_color", GameConstants.CRYSTAL_GUARDIAN_SHARD_COLOR)
	get_parent().add_child(shard)
	shard.global_position = global_position + Vector3(0, 1.0, 0) + dir * 0.8

	# Small particle burst on firing
	ParticleEffects.spawn_explosion(get_parent(), global_position + Vector3(0, 1, 0),
		GameConstants.CRYSTAL_GUARDIAN_SHARD_COLOR, 10, 0.3)

	# Audio: crystalline chime for the shard projectile (was generic enemy-hit)
	AudioManager.play_sfx(AudioManager.SFX_SHOOT_FREEZE)  # Ice-chime fits crystal theme

func _die() -> void:
	# Crystal Guardians shatter into crystal fragment particles on death
	# (extra visual flavor — more particles than a normal death poof)
	super._die()