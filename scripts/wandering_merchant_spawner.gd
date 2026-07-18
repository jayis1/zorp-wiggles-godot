## Zorp Wiggles — Wandering Merchant Spawner (Phase 26: World Life)
## An autoload singleton that periodically spawns a wandering merchant near the
## player. Only one wandering merchant is alive at a time. The merchant despawns
## after its lifetime or if the player wanders too far (handled in the merchant
## script itself). This spawner just handles the periodic arrival timing.

extends Node

# class_name omitted — this is an autoload singleton named WanderingMerchantSpawner;
# declaring class_name with the same name causes a "hides autoload singleton"
# parse error in Godot 4.4.

var _spawn_timer: float = 0.0
var _next_spawn_time: float = 0.0

func _ready() -> void:
	_schedule_next_spawn()
	if not GameManager.game_restarted.is_connected(_on_game_restarted):
		GameManager.game_restarted.connect(_on_game_restarted)

func _on_game_restarted() -> void:
	# Despawn any lingering wandering merchants so they don't survive a
	# restart. GameManager.restart_game() clears enemies/collectibles/
	# projectiles but wandering merchants are non-hostile and not in the
	# "enemies" group, so they would otherwise persist into the new run.
	for merchant in get_tree().get_nodes_in_group("wandering_merchant"):
		if is_instance_valid(merchant):
			merchant.queue_free()
	_spawn_timer = 0.0
	_schedule_next_spawn()

func _schedule_next_spawn() -> void:
	_next_spawn_time = randf_range(
		GameConstants.WANDERING_MERCHANT_SPAWN_INTERVAL_MIN,
		GameConstants.WANDERING_MERCHANT_SPAWN_INTERVAL_MAX
	)
	_spawn_timer = 0.0

func _process(delta: float) -> void:
	if GameManager.is_paused:
		return
	if not GameManager.player_is_alive and not CoOpManager.p2_active:
		return
	# Only one wandering merchant at a time.
	var existing: int = get_tree().get_nodes_in_group("wandering_merchant").size()
	if existing >= GameConstants.WANDERING_MERCHANT_MAX_ALIVE:
		return
	_spawn_timer += delta
	if _spawn_timer >= _next_spawn_time:
		_spawn_merchant()
		_schedule_next_spawn()

func _spawn_merchant() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var scene: PackedScene = load("res://scenes/entities/wandering_merchant.tscn")
	if not scene:
		print("[WanderingMerchantSpawner] Failed to load merchant scene")
		return
	# Spawn near the player but not on top of them.
	var angle: float = randf() * TAU
	var dist: float = GameConstants.WANDERING_MERCHANT_SPAWN_DISTANCE
	var spawn_pos: Vector3 = player.global_position + Vector3(cos(angle) * dist, 1.0, sin(angle) * dist)
	var extent: float = GameConstants.WORLD_EXTENT - 8.0
	spawn_pos.x = clampf(spawn_pos.x, -extent, extent)
	spawn_pos.z = clampf(spawn_pos.z, -extent, extent)
	var merchant: CharacterBody3D = scene.instantiate()
	get_tree().current_scene.add_child(merchant)
	merchant.global_position = spawn_pos
	# Arrival particles + message.
	ParticleEffects.spawn_materialization(get_tree().current_scene, spawn_pos, GameConstants.WANDERING_MERCHANT_BODY_COLOR)
	GameManager.add_message("🛍 A wandering merchant has arrived nearby! Look for the magenta canopy.")