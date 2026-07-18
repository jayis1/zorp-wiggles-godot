## Zorp Wiggles — Fast Travel Network (Phase 26: World Life)
## An autoload singleton that tracks all activated waypoints and provides the
## teleport API. The FastTravelMenu UI (a HUD child) reads the waypoint list
## from here and calls teleport_to() when the player selects a destination.
##
## Teleporting costs FAST_TRAVEL_TELEPORT_COST Space Gloop to discourage spam.
## The player can only teleport to ACTIVATED waypoints — undiscovered ones are
## not shown in the menu.

extends Node

# class_name omitted — this is an autoload singleton named FastTravelNetwork;
# declaring class_name with the same name causes a "hides autoload singleton"
# parse error in Godot 4.4.

signal waypoint_registered(waypoint: Node)
signal player_teleported(destination: Node)

var _waypoints: Array[Node] = []  # Activated waypoints

func _ready() -> void:
	# Clear on game restart.
	if GameManager.game_restarted.is_connected(_on_game_restarted):
		pass
	else:
		GameManager.game_restarted.connect(_on_game_restarted)

func _on_game_restarted() -> void:
	# Clear our cached list and re-register any waypoints that are still in
	# the world and already activated. Waypoint nodes persist across restarts
	# (WorldGenerator only runs once), so their _is_activated flag survives —
	# but our _waypoints array is stale after restart_game() clears entities.
	# Without re-registration, the menu would show no waypoints even though
	# the minimap still draws them as activated (inconsistent state).
	_waypoints.clear()
	for wp in get_tree().get_nodes_in_group("fast_travel_waypoint"):
		if is_instance_valid(wp) and wp.is_activated():
			_waypoints.append(wp)

func register_waypoint(waypoint: Node) -> void:
	if waypoint == null or not is_instance_valid(waypoint):
		return
	if waypoint in _waypoints:
		return
	_waypoints.append(waypoint)
	waypoint_registered.emit(waypoint)

func unregister_waypoint(waypoint: Node) -> void:
	_waypoints.erase(waypoint)

func get_activated_waypoints() -> Array:
	# Return only valid, activated waypoints.
	var result: Array = []
	for wp in _waypoints:
		if is_instance_valid(wp) and wp.is_activated():
			result.append(wp)
	return result

func get_waypoint_count() -> int:
	return get_activated_waypoints().size()

func teleport_to(waypoint: Node) -> bool:
	if not is_instance_valid(waypoint) or not waypoint.is_activated():
		return false
	# Check Space Gloop cost.
	var cost: int = GameConstants.FAST_TRAVEL_TELEPORT_COST
	var gloop: int = WeaponModSystem.get_material_count(GameConstants.CollectibleType.SPACE_GLOOP)
	if gloop < cost:
		GameManager.add_message("Need %d Space Gloop to fast travel! (have %d)" % [cost, gloop])
		return false
	# Deduct cost.
	var to_remove: Array = []
	for _i in range(cost):
		to_remove.append(GameConstants.CollectibleType.SPACE_GLOOP)
	WeaponModSystem.remove_materials(to_remove)
	# Teleport the player.
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return false
	# Fade out, move, fade in — simple instant teleport with a particle burst.
	var dest_pos: Vector3 = waypoint.global_position + Vector3(0, 1, 0)
	# Departure burst.
	ParticleEffects.spawn_death_poof(player.get_parent(), player.global_position, GameConstants.FAST_TRAVEL_COLOR, 1.0)
	player.global_position = dest_pos
	# Arrival burst.
	ParticleEffects.spawn_pickup_sparkle(player.get_parent(), dest_pos, GameConstants.FAST_TRAVEL_GLOW_COLOR)
	# Camera shake.
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.2)
	# Audio.
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_RIFT)
	# Stats.
	var wp_name: String = "Unknown"
	if "waypoint_name" in waypoint:
		wp_name = waypoint.waypoint_name
	if Statistics and Statistics.has_method("record_fast_travel"):
		Statistics.record_fast_travel(wp_name)
	GameManager.add_message("🧭 Fast traveled to %s" % wp_name)
	player_teleported.emit(waypoint)
	return true