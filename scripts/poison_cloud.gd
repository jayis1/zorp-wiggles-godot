## Zorp Wiggles — Poison Cloud (Toxic Spore death effect)
## Self-contained script attached to the poison cloud Node3D spawned by
## EnemyToxicSpore on death. The spore itself is freed ~0.1s after dying
## (base _die() schedules queue_free via a timer), so the cloud CANNOT
## reference methods on the spore instance — those Callables would become
## invalid once the spore is freed, leaving the cloud orphaned (no damage
## ticks, no fade-out, no self-free → permanent node leak).
##
## This script owns the tick + expire logic so the cloud is fully independent
## of the spore's lifetime. It is attached at runtime via Node.set_script().

extends Node3D

var _cloud_mat: StandardMaterial3D = null
var _cloud_light: OmniLight3D = null
var _tick_timer: Timer = null
var _life_timer: Timer = null

## Called by EnemyToxicSpore._spawn_poison_cloud() right after set_script().
## Stores references to the visual/material/timer nodes (already children of
## this cloud node) and wires up the timer signals to local methods.
func setup(mat: StandardMaterial3D, light: OmniLight3D, tick_timer: Timer, life_timer: Timer) -> void:
	_cloud_mat = mat
	_cloud_light = light
	_tick_timer = tick_timer
	_life_timer = life_timer
	# Wire up the tick + expire signals to LOCAL methods (not the spore's).
	if _tick_timer:
		_tick_timer.timeout.connect(_on_tick)
	if _life_timer:
		_life_timer.timeout.connect(_on_expire)

## Damage tick — damages players and enemies within the cloud radius.
func _on_tick() -> void:
	# Damage P1
	var p1: Node3D = get_tree().get_first_node_in_group("player")
	if p1 and is_instance_valid(p1) and GameManager.player_is_alive and not GameManager.player_is_downed:
		var d1: float = global_position.distance_to(p1.global_position)
		if d1 < GameConstants.TOXIC_SPORE_CLOUD_RADIUS:
			GameManager.take_damage(GameConstants.TOXIC_SPORE_CLOUD_DAMAGE_PER_TICK, global_position)
	# Co-op: damage P2
	if CoOpManager.is_coop_active() and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
		if not CoOpManager.p2_is_downed:
			var d2: float = global_position.distance_to(CoOpManager.p2_node.global_position)
			if d2 < GameConstants.TOXIC_SPORE_CLOUD_RADIUS:
				CoOpManager.p2_take_damage(GameConstants.TOXIC_SPORE_CLOUD_DAMAGE_PER_TICK, global_position)
	# Damage enemies (friendly fire — reduced)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var eb: EnemyBase = enemy as EnemyBase
		if eb == null or eb.is_dead:
			continue
		var ed: float = global_position.distance_to(eb.global_position)
		if ed < GameConstants.TOXIC_SPORE_CLOUD_RADIUS:
			var enemy_dmg: int = int(GameConstants.TOXIC_SPORE_CLOUD_DAMAGE_PER_TICK * GameConstants.TOXIC_SPORE_CLOUD_ENEMY_DAMAGE_MULT)
			eb.take_damage_from(enemy_dmg, global_position)

## Lifetime expiry — fade out the cloud mesh + light, then free the node.
func _on_expire() -> void:
	if _tick_timer:
		_tick_timer.stop()
	if _cloud_mat and is_instance_valid(_cloud_mat):
		var fade_tween := create_tween()
		fade_tween.set_parallel(true)
		fade_tween.tween_property(_cloud_mat, "albedo_color:a", 0.0, 0.5) \
			.set_ease(Tween.EASE_IN)
		fade_tween.tween_property(_cloud_mat, "emission_energy_multiplier", 0.0, 0.5) \
			.set_ease(Tween.EASE_IN)
		if _cloud_light:
			fade_tween.tween_property(_cloud_light, "light_energy", 0.0, 0.5) \
				.set_ease(Tween.EASE_IN)
		fade_tween.chain().tween_callback(queue_free)
	else:
		queue_free()