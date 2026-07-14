## Zorp Wiggles — Spore Spitter
## Ranged enemy that fires projectiles at the player with a charge-up telegraph.
## Stays at distance, charges up (swells + brightens), then spits a projectile.

extends EnemyBase

class_name EnemySpitter

# ─── Spitter State ────────────────────────────────────────────────────────────
var spit_timer: float = 3.0
var spit_charge_active: bool = false

func _ready() -> void:
	enemy_name = "Spore Spitter"
	enemy_type = GameConstants.EnemyType.SPITTER
	max_hp = 80
	speed = 3.0
	damage = 12
	base_scale = 1.4
	detect_range = GameConstants.ENEMY_DETECT_RANGE
	attack_range = 15.0  # Ranged — keeps distance
	xp_reward = 35
	score_reward = 150
	base_color = Color(200.0 / 255.0, 100.0 / 255.0, 0.0)  # Orange-brown
	super._ready()

	spit_timer = randf_range(2.0, 4.0)

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

	if is_alerted:
		# Keep distance — try to stay at range
		if dist_to_player < attack_range * 0.6:
			# Back away
			var dir := (global_position - player.global_position).normalized()
			dir.y = 0
			velocity = dir * speed
		elif dist_to_player > attack_range * 1.5:
			# Approach
			var dir := (player.global_position - global_position).normalized()
			dir.y = 0
			velocity = dir * speed
		else:
			# Strafe sideways
			velocity = Vector3.ZERO
			# Spit at player
			_update_spit(delta, player, dist_to_player)
	else:
		_wander(delta)

func _update_spit(delta: float, player: Node3D, dist_to_player: float) -> void:
	spit_timer -= delta

	# Charge-up telegraph
	if spit_timer > 0 and spit_timer <= GameConstants.SPORE_SPIT_CHARGE_TIME:
		if not spit_charge_active:
			spit_charge_active = true
		# Swell and brighten
		var charge_t: float = 1.0 - (spit_timer / GameConstants.SPORE_SPIT_CHARGE_TIME)
		var swell: float = 1.0 + GameConstants.SPORE_SPIT_CHARGE_SCALE * charge_t
		scale = Vector3.ONE * base_scale * swell
		if _material:
			var bright_color := base_color.lerp(Color(1.0, 0.6, 0.0),
				GameConstants.SPORE_SPIT_CHARGE_BRIGHTNESS * charge_t)
			_material.albedo_color = bright_color

	# Fire when timer expires
	if spit_timer <= 0 and dist_to_player < GameConstants.SPORE_SPIT_RANGE:
		_fire_spit(player)
		spit_timer = randf_range(2.5, 4.5)
		spit_charge_active = false
		# Restore scale and color
		scale = Vector3.ONE * base_scale
		if _material:
			_material.albedo_color = base_color
	elif spit_timer <= 0:
		# Player out of range — reset without firing
		spit_timer = randf_range(2.5, 4.5)
		spit_charge_active = false
		scale = Vector3.ONE * base_scale
		if _material:
			_material.albedo_color = base_color

func _fire_spit(player: Node3D) -> void:
	# Create enemy projectile
	var proj_scene: PackedScene = load("res://scenes/entities/enemy_projectile.tscn")
	if proj_scene:
		var proj: Area3D = proj_scene.instantiate()
		var dir: Vector3 = (player.global_position - global_position).normalized()
		# Set properties BEFORE adding to tree so _ready() picks them up
		proj.set("direction", dir)
		proj.set("speed", GameConstants.SPORE_SPIT_SPEED)
		proj.set("damage", GameConstants.SPORE_SPIT_DAMAGE)
		proj.set("lifetime", GameConstants.SPORE_SPIT_LIFETIME)
		get_parent().add_child(proj)
		proj.global_position = global_position + Vector3(0, 0.5, 0)
	else:
		# Fallback: instant damage
		GameManager.take_damage(GameConstants.SPORE_SPIT_DAMAGE)