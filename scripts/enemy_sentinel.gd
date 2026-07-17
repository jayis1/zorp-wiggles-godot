## Zorp Wiggles — Starburst Sentinel
## Stationary turret enemy that fires expanding shockwave rings.
## Doesn't move — stands still and periodically emits AoE shockwaves.

extends EnemyBase

class_name EnemySentinel

# ─── Sentinel State ───────────────────────────────────────────────────────────
var shockwave_timer: float = 4.0

func _ready() -> void:
	enemy_name = "Starburst Sentinel"
	enemy_type = GameConstants.EnemyType.SENTINEL
	max_hp = 60
	speed = 0.0  # Stationary
	damage = 12
	base_scale = 1.5
	detect_range = 28.0
	attack_range = 0.0  # No melee — uses shockwaves
	xp_reward = 35
	score_reward = 150
	base_color = Color(1.0, 200.0 / 255.0, 50.0 / 255.0)  # Gold-orange
	# ── Phase 10: Stationary turret — disable movement-based AI behaviors
	use_smart_ai = false  # Sentinel doesn't move, so AI behaviors are irrelevant
	super._ready()

	shockwave_timer = randf_range(
		GameConstants.STARBURST_SHOCKWAVE_INTERVAL_MIN,
		GameConstants.STARBURST_SHOCKWAVE_INTERVAL_MAX
	)

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

	# No movement — stationary turret
	velocity = Vector3.ZERO

	# Fire shockwaves when alerted and player in range
	if is_alerted:
		shockwave_timer -= delta
		if shockwave_timer <= 0 and dist_to_player < GameConstants.STARBURST_SHOCKWAVE_MAX_RADIUS + 5.0:
			_fire_shockwave()
			shockwave_timer = randf_range(
				GameConstants.STARBURST_SHOCKWAVE_INTERVAL_MIN,
				GameConstants.STARBURST_SHOCKWAVE_INTERVAL_MAX
			)

func _fire_shockwave() -> void:
	# Create expanding shockwave ring
	var shockwave_scene: PackedScene = load("res://scenes/entities/shockwave.tscn")
	if shockwave_scene:
		var shockwave: Area3D = shockwave_scene.instantiate()
		get_parent().add_child(shockwave)
		shockwave.global_position = global_position
		shockwave.set("damage", GameConstants.STARBURST_SHOCKWAVE_DAMAGE)
		shockwave.set("max_radius", GameConstants.STARBURST_SHOCKWAVE_MAX_RADIUS)
		shockwave.set("expand_speed", GameConstants.STARBURST_SHOCKWAVE_EXPAND_SPEED)
	else:
		# Fallback: directly damage player if in range
		var player: Node3D = get_tree().get_first_node_in_group("player")
		if player:
			var dist: float = global_position.distance_to(player.global_position)
			if dist < GameConstants.STARBURST_SHOCKWAVE_MAX_RADIUS:
				GameManager.take_damage(GameConstants.STARBURST_SHOCKWAVE_DAMAGE, global_position)