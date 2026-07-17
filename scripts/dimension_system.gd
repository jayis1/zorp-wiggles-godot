## Zorp Wiggles — Dimensional Rift System (Phase 14)
## Manages 4 alternate dimensions that players can enter via rift portals.
##
## Dimensions:
##   NORMAL          — Default world state
##   VOID            — Everything is silhouettes, shadow clone boss fight
##   MIRROR          — Collectibles are hostile, enemies are friendly/passive
##   TIME_SLOW       — World at 0.3x speed, player at 0.5x (relative advantage)
##   REVERSE_GRAVITY — Walk on ceiling, collectibles fall up
##
## Rift portals spawn randomly in the world. When the player enters a rift,
## a dimension transition effect plays, and the dimension lasts for
## DIMENSION_DURATION seconds before auto-returning to Normal.
##
## The system also spawns rift-exclusive rare collectibles when the player
## exits a dimension, and emits signals for HUD and shader integration.

extends Node

# ─── Signals ──────────────────────────────────────────────────────────────────
signal dimension_changed(new_dimension: int, old_dimension: int)
signal dimension_transition_started(target_dimension: int)
signal dimension_transition_ended(dimension: int)
signal dimension_timer_changed(time_remaining: float)
signal rift_spawned(pos: Vector3, dimension: int)
signal rift_despawned(rift: Node)

# ─── State ────────────────────────────────────────────────────────────────────
var _current_dimension: int = GameConstants.Dimension.NORMAL
var _dimension_timer: float = 0.0          # Time remaining in current dimension
var _is_transitioning: bool = false        # True during screen-wipe transition
var _pending_dimension: int = GameConstants.Dimension.NORMAL  # Target during transition

# Rift spawn management
var _rift_spawn_timer: float = 15.0        # Initial delay before first rift
var _active_rifts: Array[Node] = []        # Currently active rift portals

# Time-slow tracking (for Engine.time_scale when needed)
var _world_time_scale: float = 1.0
var _player_time_scale: float = 1.0

# ─── Public API ───────────────────────────────────────────────────────────────

func get_current_dimension() -> int:
	return _current_dimension

func is_in_dimension(dim: int) -> bool:
	return _current_dimension == dim

func is_in_rift() -> bool:
	return _current_dimension != GameConstants.Dimension.NORMAL

func get_dimension_timer() -> float:
	return _dimension_timer

func get_world_time_scale() -> float:
	return _world_time_scale

func get_player_time_scale() -> float:
	return _player_time_scale

## Check if enemies should be passive (Mirror dimension).
func enemies_passive() -> bool:
	return _current_dimension == GameConstants.Dimension.MIRROR

## Check if collectibles should damage the player (Mirror dimension).
func collectibles_hostile() -> bool:
	return _current_dimension == GameConstants.Dimension.MIRROR

## Check if gravity is reversed.
func gravity_reversed() -> bool:
	return _current_dimension == GameConstants.Dimension.REVERSE_GRAVITY

## Check if we're in the Void dimension (silhouette mode).
func is_void() -> bool:
	return _current_dimension == GameConstants.Dimension.VOID

## Get the current dimension's display name.
func get_dimension_name() -> String:
	return GameConstants.DIMENSION_NAMES.get(_current_dimension, "Unknown")

## Get the current dimension's tint color.
func get_dimension_color() -> Color:
	return GameConstants.DIMENSION_COLORS.get(_current_dimension, Color.WHITE)

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	GameManager.player_died.connect(_on_player_died)
	GameManager.game_restarted.connect(_on_game_restarted)

func _process(delta: float) -> void:
	if GameManager.is_paused or not GameManager.player_is_alive:
		return

	if _is_transitioning:
		return  # Don't tick timers during transition

	# Tick dimension timer if we're in a rift
	if _current_dimension != GameConstants.Dimension.NORMAL:
		_dimension_timer -= delta
		dimension_timer_changed.emit(_dimension_timer)
		if _dimension_timer <= 0:
			_return_to_normal()

	# Tick rift spawn timer (only spawn rifts in normal dimension)
	if _current_dimension == GameConstants.Dimension.NORMAL:
		_rift_spawn_timer -= delta
		if _rift_spawn_timer <= 0:
			_try_spawn_rift()
			_reset_rift_spawn_timer()

	# Clean up expired rifts
	_update_active_rifts(delta)

# ─── Rift Spawning ────────────────────────────────────────────────────────────

func _try_spawn_rift() -> void:
	if _active_rifts.size() >= GameConstants.RIFT_MAX_ACTIVE:
		return

	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return

	# Pick a position around the player
	var angle: float = randf() * TAU
	var dist: float = randf_range(
		GameConstants.RIFT_SPAWN_DISTANCE_MIN,
		GameConstants.RIFT_SPAWN_DISTANCE_MAX
	)
	var pos: Vector3 = player.global_position + Vector3(
		cos(angle) * dist, 0, sin(angle) * dist
	)

	# Clamp to world bounds
	var extent: float = GameConstants.WORLD_EXTENT - 5.0
	pos.x = clampf(pos.x, -extent, extent)
	pos.z = clampf(pos.z, -extent, extent)

	# Pick a random dimension (not NORMAL)
	var dimensions: Array[int] = [
		GameConstants.Dimension.VOID,
		GameConstants.Dimension.MIRROR,
		GameConstants.Dimension.TIME_SLOW,
		GameConstants.Dimension.REVERSE_GRAVITY,
	]
	var target_dim: int = dimensions[randi() % dimensions.size()]

	_spawn_rift(pos, target_dim)

func _spawn_rift(pos: Vector3, target_dim: int) -> void:
	var rift_scene: PackedScene = load("res://scenes/entities/dimensional_rift.tscn")
	if not rift_scene:
		push_warning("[DimensionSystem] Failed to load dimensional_rift.tscn")
		return

	var rift: Node3D = rift_scene.instantiate()
	# Set properties BEFORE add_child so _ready() sees the correct values.
	# _ready() uses target_dimension for colors and global_position for particles.
	rift.global_position = pos
	rift.set("target_dimension", target_dim)
	rift.set("lifetime", GameConstants.RIFT_LIFETIME)
	# Find a suitable parent — the World node
	var world: Node = GameManager.world
	if not world:
		world = get_tree().current_scene
	world.add_child(rift)

	_active_rifts.append(rift)
	rift_spawned.emit(pos, target_dim)

	var dim_name: String = GameConstants.DIMENSION_NAMES.get(target_dim, "Unknown")
	GameManager.add_message("🌀 Dimensional rift opened nearby! → %s" % dim_name)

func _update_active_rifts(delta: float) -> void:
	for i in range(_active_rifts.size() - 1, -1, -1):
		var rift: Node = _active_rifts[i]
		if not is_instance_valid(rift):
			_active_rifts.remove_at(i)
			continue
		# Check if rift has expired (rift script handles its own lifetime)
		if rift.get("is_expired") == true:
			rift_despawned.emit(rift)
			_active_rifts.remove_at(i)
			rift.queue_free()

func _reset_rift_spawn_timer() -> void:
	_rift_spawn_timer = randf_range(
		GameConstants.RIFT_SPAWN_INTERVAL_MIN,
		GameConstants.RIFT_SPAWN_INTERVAL_MAX
	)

# ─── Dimension Transitions ────────────────────────────────────────────────────

## Called by a rift when the player enters it.
func enter_dimension(target_dim: int) -> void:
	if _is_transitioning or _current_dimension != GameConstants.Dimension.NORMAL:
		return  # Already in a dimension or transitioning

	_pending_dimension = target_dim
	_is_transitioning = true
	dimension_transition_started.emit(target_dim)

	var dim_name: String = GameConstants.DIMENSION_NAMES.get(target_dim, "Unknown")
	GameManager.add_message("🌀 Entering %s..." % dim_name)

	# The transition effect is handled by ShaderManager via signal.
	# After the transition duration, we actually switch.
	# Use a one-shot timer for the transition.
	var timer: SceneTreeTimer = get_tree().create_timer(GameConstants.DIMENSION_TRANSITION_DURATION)
	timer.timeout.connect(_finish_dimension_entry)

func _finish_dimension_entry() -> void:
	var old: int = _current_dimension
	_current_dimension = _pending_dimension
	_is_transitioning = false

	# Set up dimension-specific effects
	_apply_dimension_effects(_current_dimension)

	# Set the dimension timer
	_dimension_timer = GameConstants.DIMENSION_DURATION

	dimension_changed.emit(_current_dimension, old)
	dimension_transition_ended.emit(_current_dimension)

	var dim_name: String = GameConstants.DIMENSION_NAMES.get(_current_dimension, "Unknown")
	GameManager.add_message("🌀 %s active! %ds remaining" % [dim_name, int(_dimension_timer)])

	# Remove all active rifts (you've entered one, the rest dissolve)
	for rift in _active_rifts:
		if is_instance_valid(rift):
			rift.queue_free()
	_active_rifts.clear()

func _return_to_normal() -> void:
	if _is_transitioning:
		return

	_pending_dimension = GameConstants.Dimension.NORMAL
	_is_transitioning = true
	dimension_transition_started.emit(GameConstants.Dimension.NORMAL)

	GameManager.add_message("🌀 Returning to Normal Space...")

	# Spawn rift-exclusive collectibles on exit
	_spawn_exit_collectibles()

	var timer: SceneTreeTimer = get_tree().create_timer(GameConstants.DIMENSION_TRANSITION_DURATION)
	timer.timeout.connect(_finish_dimension_return)

func _finish_dimension_return() -> void:
	var old: int = _current_dimension
	# Remove dimension effects before switching
	_remove_dimension_effects(_current_dimension)

	_current_dimension = GameConstants.Dimension.NORMAL
	_is_transitioning = false
	_dimension_timer = 0.0

	# Reset time scales
	_world_time_scale = 1.0
	_player_time_scale = 1.0

	dimension_changed.emit(_current_dimension, old)
	dimension_transition_ended.emit(_current_dimension)

	GameManager.add_message("🌀 Back in Normal Space")

	# Reset rift spawn timer
	_reset_rift_spawn_timer()

# ─── Dimension Effects ────────────────────────────────────────────────────────

func _apply_dimension_effects(dim: int) -> void:
	match dim:
		GameConstants.Dimension.TIME_SLOW:
			_world_time_scale = GameConstants.TIME_SLOW_WORLD_SCALE
			_player_time_scale = GameConstants.TIME_SLOW_PLAYER_SCALE
			# Apply time scale to enemies and projectiles
			_apply_time_scale_to_entities(_world_time_scale)
		GameConstants.Dimension.REVERSE_GRAVITY:
			_reverse_gravity_for_entities()
		GameConstants.Dimension.VOID:
			_spawn_void_shadow_clone()
		GameConstants.Dimension.MIRROR:
			_swap_entity_roles()
		_:
			pass

func _remove_dimension_effects(dim: int) -> void:
	match dim:
		GameConstants.Dimension.TIME_SLOW:
			_apply_time_scale_to_entities(1.0)
		GameConstants.Dimension.REVERSE_GRAVITY:
			_restore_gravity_for_entities()
		GameConstants.Dimension.VOID:
			_despawn_void_shadow_clone()
		GameConstants.Dimension.MIRROR:
			_restore_entity_roles()
		_:
			pass

func _apply_time_scale_to_entities(scale: float) -> void:
	# Slow down all enemies and enemy projectiles
	for enemy in GameManager.enemies:
		if is_instance_valid(enemy) and enemy.has_method("set_time_scale"):
			enemy.set_time_scale(scale)
	for proj in get_tree().get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(proj) and proj.has_method("set_time_scale"):
			proj.set_time_scale(scale)

func _reverse_gravity_for_entities() -> void:
	# Flip enemies and collectibles to ceiling
	var ceiling_y: float = GameConstants.REVERSE_GRAVITY_HEIGHT
	for enemy in GameManager.enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			var tween: Tween = enemy.create_tween()
			tween.tween_property(enemy, "global_position:y", ceiling_y, 0.8) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	# Collectibles fall "up"
	for coll in GameManager.collectibles:
		if is_instance_valid(coll):
			coll.set("base_y", ceiling_y + 0.5)

func _restore_gravity_for_entities() -> void:
	# Bring everything back to ground level
	for enemy in GameManager.enemies:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			var tween: Tween = enemy.create_tween()
			tween.tween_property(enemy, "global_position:y", 1.0, 0.8) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	for coll in GameManager.collectibles:
		if is_instance_valid(coll):
			coll.set("base_y", 0.5)

func _spawn_void_shadow_clone() -> void:
	# Spawn a shadow clone "boss" near the player in the Void dimension
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var pos: Vector3 = player.global_position + Vector3(8, 1, 8)
	var clone_scene: PackedScene = load("res://scenes/entities/shadow_clone.tscn")
	if not clone_scene:
		push_warning("[DimensionSystem] shadow_clone.tscn not found")
		return

	var clone: CharacterBody3D = clone_scene.instantiate()
	var world: Node = GameManager.world
	if not world:
		world = get_tree().current_scene
	# Set position BEFORE add_child so _ready() sees the correct global_position
	# (used for particle effects and boss spawn visuals).
	clone.global_position = pos
	clone.set("hp", GameConstants.VOID_SHADOW_CLONE_HP)
	clone.set("max_hp", GameConstants.VOID_SHADOW_CLONE_HP)
	clone.set("damage", GameConstants.VOID_SHADOW_CLONE_DAMAGE)
	world.add_child(clone)
	GameManager.enemies.append(clone)

	GameManager.add_message("🌑 A shadow clone emerges from the void!")

func _despawn_void_shadow_clone() -> void:
	# Remove shadow clones when leaving Void dimension
	for enemy in GameManager.enemies:
		if is_instance_valid(enemy) and enemy.is_in_group("void_clone"):
			enemy.queue_free()

func _swap_entity_roles() -> void:
	# In Mirror dimension, collectibles become "hostile"
	# (handled by collectible.gd checking DimensionSystem.collectibles_hostile())
	# Enemies become passive (handled by enemy_base.gd checking DimensionSystem.enemies_passive())
	GameManager.add_message("🪐 Mirror dimension: enemies friendly, items treacherous!")

func _restore_entity_roles() -> void:
	# Roles are checked dynamically via DimensionSystem queries, so nothing to undo.
	pass

# ─── Exit Collectibles ────────────────────────────────────────────────────────

func _spawn_exit_collectibles() -> void:
	# When exiting a dimension, spawn rare collectibles near the player
	if randf() > GameConstants.RIFT_COLLECTIBLE_CHANCE:
		return

	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var coll_scene: PackedScene = load("res://scenes/entities/collectible.tscn")
	if not coll_scene:
		return

	var count: int = randi_range(2, 4)
	for i in count:
		var angle: float = randf() * TAU
		var dist: float = randf_range(3.0, 8.0)
		var pos: Vector3 = player.global_position + Vector3(cos(angle) * dist, 0.5, sin(angle) * dist)

		var coll: Area3D = coll_scene.instantiate()
		var world: Node = GameManager.world
		if not world:
			world = get_tree().current_scene
		# Set position BEFORE add_child so _ready() reads the correct global_position
		# for base_y (bobbing animation reference height).
		coll.global_position = pos
		world.add_child(coll)

		# Set it to a rare collectible type
		var rare_type: int = GameConstants.RIFT_COLLECTIBLE_TYPES[randi() % GameConstants.RIFT_COLLECTIBLE_TYPES.size()]
		coll.set_type(rare_type)

		GameManager.collectibles.append(coll)

	GameManager.add_message("✨ Rift rewards materialized!")

# ─── Reset ────────────────────────────────────────────────────────────────────

func _on_player_died() -> void:
	# Clean up on death
	if _current_dimension != GameConstants.Dimension.NORMAL:
		_remove_dimension_effects(_current_dimension)
	_current_dimension = GameConstants.Dimension.NORMAL
	_is_transitioning = false
	_dimension_timer = 0.0
	_world_time_scale = 1.0
	_player_time_scale = 1.0
	for rift in _active_rifts:
		if is_instance_valid(rift):
			rift.queue_free()
	_active_rifts.clear()

func _on_game_restarted() -> void:
	_current_dimension = GameConstants.Dimension.NORMAL
	_is_transitioning = false
	_pending_dimension = GameConstants.Dimension.NORMAL
	_dimension_timer = 0.0
	_world_time_scale = 1.0
	_player_time_scale = 1.0
	_rift_spawn_timer = 15.0
	_active_rifts.clear()