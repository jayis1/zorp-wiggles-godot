## Zorp Wiggles — Starburst Sentinel
## Stationary turret enemy that fires expanding shockwave rings.
## Doesn't move — stands still and periodically emits AoE shockwaves.

extends EnemyBase

class_name EnemySentinel

# ─── Sentinel State ───────────────────────────────────────────────────────────
var shockwave_timer: float = 4.0

# Preloaded shockwave scene — shared across all shockwave attacks.
const SHOCKWAVE_SCENE := preload("res://scenes/entities/shockwave.tscn")

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
	base_color = Color(1.0, 0.784, 0.196)  # Gold-orange
	# ── Phase 10: Stationary turret — disable movement-based AI behaviors
	use_smart_ai = false  # Sentinel doesn't move, so AI behaviors are irrelevant
	super._ready()

	shockwave_timer = randf_range(
		GameConstants.STARBURST_SHOCKWAVE_INTERVAL_MIN,
		GameConstants.STARBURST_SHOCKWAVE_INTERVAL_MAX
	)

func _update_ai(delta: float) -> void:
	# Cached player reference — the Sentinel overrides _update_ai without
	# calling super, so the base class _cached_player is never populated.
	# Use the same lazy-scan pattern to avoid a per-physics-frame group scan.
	# Matches the pattern used by enemy_spitter.gd (Enhancement Pack 32).
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	var player: Node3D = _cached_player
	if not player:
		return
	if CoOpManager.is_coop_active() and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
		var p1_dist: float = global_position.distance_to(player.global_position)
		var p2_dist: float = global_position.distance_to(CoOpManager.p2_node.global_position)
		if GameManager.player_is_downed:
			p1_dist = 99999.0
		if CoOpManager.p2_is_downed:
			p2_dist = 99999.0
		if p2_dist < p1_dist:
			player = CoOpManager.p2_node

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
	# Enhancement Pack 26: SFX on shockwave fire — previously the sentinel's
	# shockwave attack was completely silent, despite having visual particles
	# + a light flash. The SFX_RIFT whoosh conveys a seismic energy ripple.
	AudioManager.play_sfx(AudioManager.SFX_RIFT)
	# Create expanding shockwave ring — preloaded const so repeated attacks
	# don't hit the resource loader.
	var shockwave: Area3D = SHOCKWAVE_SCENE.instantiate()
	get_parent().add_child(shockwave)
	shockwave.global_position = global_position
	shockwave.set("damage", GameConstants.STARBURST_SHOCKWAVE_DAMAGE)
	shockwave.set("max_radius", GameConstants.STARBURST_SHOCKWAVE_MAX_RADIUS)
	shockwave.set("expand_speed", GameConstants.STARBURST_SHOCKWAVE_EXPAND_SPEED)