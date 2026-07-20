## Zorp Wiggles — Pet Training System (Phase 27)
## Mini-games that grant Training Points (TP) to permanently boost the pet's
## stats for the current run. The player initiates a mini-game via the
## PetTrainingMenu (Shift+T). TP and stat boosts persist across pet
## death/respawn within the same run, but reset on game restart.
##
## Mini-games:
##   DASH_COURSE   — Dash through 5 waypoints in order before time runs out.
##   TARGET_DODGE  — Survive 15s while 6 stationary dummies fire slow bolts.
##   FETCH_FRENZY  — Guide the pet to collect 8 dropped items within 20s.
##
## Public API:
##   start_game(game_id: int) -> bool         — start a mini-game (requires active pet)
##   cancel_game() -> void                     — abort the current mini-game
##   is_game_active() -> bool                  — is a mini-game currently running?
##   get_current_game() -> int                 — current game ID or -1
##   get_time_remaining() -> float             — seconds left in the current game
##   get_progress_text() -> String             — e.g. "Waypoints: 2/5" or ""
##   award_tp(amount: int) -> void              — grant TP (clamped to max)
##   spend_tp(stat_id: int) -> bool             — spend TP on a stat upgrade
##   get_tp() -> int                            — current TP balance
##   get_stat_level(stat_id: int) -> int        — points invested in this stat
##   get_stat_bonus(stat: String) -> float      — aggregated bonus from training
##   notify_player_dashed() -> void             — called from player.gd on dash
##   notify_item_collected() -> void            — called from collectible.gd on pickup
##   update(delta: float) -> void               — called from GameManager._process
##   reset() -> void                            — clear on game restart / death
##
## Signals:
##   tp_changed(tp: int)
##   stat_upgraded(stat_id: int, level: int)
##   game_started(game_id: int)
##   game_completed(game_id: int, tp_awarded: int, success: bool)
##   game_cancelled(game_id: int)
##   training_progress_updated(text: String)

extends Node

signal tp_changed(tp: int)
signal stat_upgraded(stat_id: int, level: int)
signal game_started(game_id: int)
signal game_completed(game_id: int, tp_awarded: int, success: bool)
signal game_cancelled(game_id: int)
signal training_progress_updated(text: String)

# TP and stat investments
var _tp: int = 0
var _stat_levels: Array[int] = [0, 0, 0, 0]  # Per stat

# Active mini-game state
var _active_game: int = -1
var _game_timer: float = 0.0
var _waypoints_hit: int = 0
var _fetch_items_collected: int = 0
var _waypoints: Array[Node3D] = []
var _dummies: Array[Node3D] = []
var _fetch_items: Array[Node3D] = []
var _dummy_bolts: Array[Node3D] = []
var _dummy_fire_timers: Array[float] = []
var _game_parent: Node = null  # Node we parent waypoints/dummies to


func _ready() -> void:
	if GameManager and not GameManager.game_restarted.is_connected(_on_game_restarted):
		GameManager.game_restarted.connect(_on_game_restarted)
	if GameManager and not GameManager.player_died.is_connected(_on_player_died):
		GameManager.player_died.connect(_on_player_died)


func get_tp() -> int:
	return _tp


func get_stat_level(stat_id: int) -> int:
	if stat_id < 0 or stat_id >= _stat_levels.size():
		return 0
	return _stat_levels[stat_id]


func award_tp(amount: int) -> void:
	_tp = mini(_tp + amount, GameConstants.PET_TRAINING_MAX_TP_PER_RUN)
	tp_changed.emit(_tp)


func spend_tp(stat_id: int) -> bool:
	if stat_id < 0 or stat_id >= _stat_levels.size():
		return false
	if _stat_levels[stat_id] >= GameConstants.PET_TRAINING_MAX_POINTS_PER_STAT:
		GameManager.add_message("Stat already maxed!")
		return false
	var cost: int = GameConstants.PET_TRAINING_STAT_COSTS[stat_id]
	if _tp < cost:
		GameManager.add_message("Need %d TP to upgrade %s!" % [cost, GameConstants.PET_TRAINING_STAT_NAMES[stat_id]])
		return false
	_tp -= cost
	_stat_levels[stat_id] += 1
	tp_changed.emit(_tp)
	stat_upgraded.emit(stat_id, _stat_levels[stat_id])
	GameManager.add_message("🎓 Trained %s → Lv%d (+%s)" % [
		GameConstants.PET_TRAINING_STAT_NAMES[stat_id],
		_stat_levels[stat_id],
		str(GameConstants.PET_TRAINING_STAT_BONUSES[stat_id]),
	])
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	return true


## Aggregated bonus from training investments.
## Stat keys: "attack_damage", "max_hp", "move_speed", "collect_radius"
func get_stat_bonus(stat: String) -> float:
	match stat:
		"attack_damage":
			return _stat_levels[0] * GameConstants.PET_TRAINING_STAT_BONUSES[0]
		"max_hp":
			return _stat_levels[1] * GameConstants.PET_TRAINING_STAT_BONUSES[1]
		"move_speed":
			return _stat_levels[2] * GameConstants.PET_TRAINING_STAT_BONUSES[2]
		"collect_radius":
			return _stat_levels[3] * GameConstants.PET_TRAINING_STAT_BONUSES[3]
	return 0.0


# ─── Mini-game lifecycle ─────────────────────────────────────────────────────

func is_game_active() -> bool:
	return _active_game >= 0


func get_current_game() -> int:
	return _active_game


func get_time_remaining() -> float:
	return maxf(0.0, _game_timer)


func get_progress_text() -> String:
	if _active_game < 0:
		return ""
	match _active_game:
		GameConstants.PetTrainingGame.DASH_COURSE:
			return "Waypoints: %d/%d" % [_waypoints_hit, GameConstants.PET_TRAINING_WAYPOINT_COUNT]
		GameConstants.PetTrainingGame.FETCH_FRENZY:
			return "Items: %d/%d" % [_fetch_items_collected, GameConstants.PET_TRAINING_FETCH_ITEM_COUNT]
		GameConstants.PetTrainingGame.TARGET_DODGE:
			return "Survive! %.1fs" % _game_timer
	return ""


func start_game(game_id: int) -> bool:
	if _active_game >= 0:
		GameManager.add_message("A training game is already in progress!")
		return false
	# Need an active pet (except target dodge which is about player survival)
	if game_id != GameConstants.PetTrainingGame.TARGET_DODGE:
		var pet: Node3D = get_tree().get_first_node_in_group("companion_pet")
		if not pet or not is_instance_valid(pet):
			GameManager.add_message("Summon a pet first (F key) before training!")
			return false
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return false
	_game_parent = player.get_parent()
	if not _game_parent:
		return false
	_active_game = game_id
	_game_timer = GameConstants.PET_TRAINING_TIME_LIMITS[game_id]
	_waypoints_hit = 0
	_fetch_items_collected = 0
	# Spawn game entities
	match game_id:
		GameConstants.PetTrainingGame.DASH_COURSE:
			_spawn_waypoints(player)
		GameConstants.PetTrainingGame.TARGET_DODGE:
			_spawn_dummies(player)
		GameConstants.PetTrainingGame.FETCH_FRENZY:
			_spawn_fetch_items(player)
	game_started.emit(game_id)
	training_progress_updated.emit(get_progress_text())
	GameManager.add_message("🎓 Training: %s! Time: %.0fs" % [
		GameConstants.PET_TRAINING_GAME_NAMES[game_id], _game_timer
	])
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	return true


func cancel_game() -> void:
	if _active_game < 0:
		return
	var gid: int = _active_game
	_cleanup_game()
	game_cancelled.emit(gid)
	GameManager.add_message("Training cancelled.")


func _cleanup_game() -> void:
	# Remove all spawned entities
	for wp in _waypoints:
		if is_instance_valid(wp):
			wp.queue_free()
	_waypoints.clear()
	for dm in _dummies:
		if is_instance_valid(dm):
			dm.queue_free()
	_dummies.clear()
	for bolt in _dummy_bolts:
		if is_instance_valid(bolt):
			bolt.queue_free()
	_dummy_bolts.clear()
	_dummy_fire_timers.clear()
	for item in _fetch_items:
		if is_instance_valid(item):
			item.queue_free()
	_fetch_items.clear()
	_active_game = -1
	_game_timer = 0.0


# ─── Entity spawning ──────────────────────────────────────────────────────────

func _spawn_waypoints(player: Node3D) -> void:
	var base_pos: Vector3 = player.global_position
	for i in range(GameConstants.PET_TRAINING_WAYPOINT_COUNT):
		var wp := Area3D.new()
		wp.name = "TrainingWaypoint%d" % i
		wp.collision_layer = 0
		wp.collision_mask = 0
		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = GameConstants.PET_TRAINING_WAYPOINT_RADIUS
		col.shape = shape
		wp.add_child(col)
		# Visual ring
		var mesh_inst := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.major_radius = GameConstants.PET_TRAINING_WAYPOINT_RADIUS * 0.8
		ring.minor_radius = 0.15
		mesh_inst.mesh = ring
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = Color(0.2, 1.0, 0.6) if i == 0 else Color(0.5, 0.5, 0.5)
		mat.emission_energy_multiplier = 2.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.2, 1.0, 0.6, 0.5) if i == 0 else Color(0.5, 0.5, 0.5, 0.3)
		mesh_inst.material_override = mat
		wp.add_child(mesh_inst)
		# Light
		var light := OmniLight3D.new()
		light.light_color = mat.emission
		light.light_energy = 1.0
		light.omni_range = 5.0
		wp.add_child(light)
		# Position in a rough circle around the player
		var angle: float = (float(i) / float(GameConstants.PET_TRAINING_WAYPOINT_COUNT)) * TAU
		var dist: float = 15.0 + randf() * 10.0
		wp.global_position = base_pos + Vector3(cos(angle) * dist, 1.0, sin(angle) * dist)
		wp.set_meta("wp_index", i)
		wp.set_meta("wp_active", i == 0)
		_game_parent.add_child(wp)
		_waypoints.append(wp)


func _spawn_dummies(player: Node3D) -> void:
	var base_pos: Vector3 = player.global_position
	for i in range(GameConstants.PET_TRAINING_DUMMY_COUNT):
		var dummy := StaticBody3D.new()
		dummy.name = "TrainingDummy%d" % i
		dummy.collision_layer = 0
		dummy.collision_mask = 0
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.5
		shape.height = 1.5
		col.shape = shape
		dummy.add_child(col)
		var mesh_inst := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.5
		cyl.height = 1.5
		mesh_inst.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.5, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(0.6, 0.3, 0.1)
		mat.emission_energy_multiplier = 0.5
		mesh_inst.material_override = mat
		mesh_inst.position.y = 0.75
		dummy.add_child(mesh_inst)
		var angle: float = (float(i) / float(GameConstants.PET_TRAINING_DUMMY_COUNT)) * TAU
		var dist: float = 10.0
		dummy.global_position = base_pos + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		_game_parent.add_child(dummy)
		_dummies.append(dummy)
		_dummy_fire_timers.append(randf() * GameConstants.PET_TRAINING_DUMMY_FIRE_INTERVAL)


func _spawn_fetch_items(player: Node3D) -> void:
	var base_pos: Vector3 = player.global_position
	var collectible_scene := preload("res://scenes/entities/collectible.tscn")
	for i in range(GameConstants.PET_TRAINING_FETCH_ITEM_COUNT):
		var item := collectible_scene.instantiate()
		_game_parent.add_child(item)
		var angle: float = randf() * TAU
		var dist: float = 8.0 + randf() * 12.0
		item.global_position = base_pos + Vector3(cos(angle) * dist, 0.5, sin(angle) * dist)
		item.set_type(GameConstants.CollectibleType.XP_ORB)
		if not item.is_in_group("collectibles"):
			item.add_to_group("collectibles")
		item.set_meta("training_fetch", true)
		_fetch_items.append(item)


# ─── Per-frame update (called from GameManager._process) ────────────────────

func update(delta: float) -> void:
	if _active_game < 0:
		return
	_game_timer -= delta
	# Check time-out
	if _game_timer <= 0.0:
		_end_game(false)
		return
	match _active_game:
		GameConstants.PetTrainingGame.DASH_COURSE:
			_update_dash_course(delta)
		GameConstants.PetTrainingGame.TARGET_DODGE:
			_update_target_dodge(delta)
		GameConstants.PetTrainingGame.FETCH_FRENZY:
			_update_fetch_frenzy(delta)
	training_progress_updated.emit(get_progress_text())


func _update_dash_course(delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		cancel_game()
		return
	# Check if the player is within touch radius of the current active waypoint
	if _waypoints_hit >= _waypoints.size():
		return
	var wp: Node3D = _waypoints[_waypoints_hit]
	if not is_instance_valid(wp):
		return
	if not wp.get_meta("wp_active", false):
		return
	var d: float = player.global_position.distance_to(wp.global_position)
	if d < GameConstants.PET_TRAINING_WAYPOINT_RADIUS:
		# Hit!
		_waypoints_hit += 1
		AudioManager.play_sfx(AudioManager.SFX_PICKUP)
		ParticleEffects.spawn_pickup_sparkle(_game_parent, wp.global_position, Color(0.2, 1.0, 0.6))
		# Deactivate this waypoint visual
		wp.set_meta("wp_active", false)
		var mesh_inst: Node = wp.get_child_or_null(1)
		if mesh_inst and mesh_inst is MeshInstance3D:
			var mat: Material = mesh_inst.material_override
			if mat and mat is StandardMaterial3D:
				(mat as StandardMaterial3D).emission = Color(0.2, 1.0, 0.6)
				(mat as StandardMaterial3D).albedo_color = Color(0.2, 1.0, 0.6, 0.15)
		# Activate the next waypoint
		if _waypoints_hit < _waypoints.size():
			var next_wp: Node3D = _waypoints[_waypoints_hit]
			next_wp.set_meta("wp_active", true)
			var next_mesh: Node = next_wp.get_child_or_null(1)
			if next_mesh and next_mesh is MeshInstance3D:
				var mat2: Material = next_mesh.material_override
				if mat2 and mat2 is StandardMaterial3D:
					(mat2 as StandardMaterial3D).emission = Color(0.2, 1.0, 0.6)
					(mat2 as StandardMaterial3D).albedo_color = Color(0.2, 1.0, 0.6, 0.5)
		# Check completion
		if _waypoints_hit >= GameConstants.PET_TRAINING_WAYPOINT_COUNT:
			_end_game(true)


func _update_target_dodge(delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		cancel_game()
		return
	# Dummies fire bolts at the player on their fire interval
	for i in range(_dummies.size()):
		_dummy_fire_timers[i] -= delta
		if _dummy_fire_timers[i] <= 0.0:
			_dummy_fire_timers[i] = GameConstants.PET_TRAINING_DUMMY_FIRE_INTERVAL
			_fire_dummy_bolt(_dummies[i], player)
	# Move existing bolts
	var to_remove: Array[Node3D] = []
	for bolt in _dummy_bolts:
		if not is_instance_valid(bolt):
			to_remove.append(bolt)
			continue
		var dir: Vector3 = bolt.get_meta("bolt_dir", Vector3.FORWARD)
		bolt.global_position += dir * GameConstants.PET_TRAINING_DUMMY_BOLT_SPEED * delta
		# Check hit on player
		if bolt.global_position.distance_to(player.global_position + Vector3(0, 1, 0)) < 1.0:
			if GameManager.player_is_alive:
				GameManager.take_damage(GameConstants.PET_TRAINING_DUMMY_BOLT_DAMAGE)
			to_remove.append(bolt)
		# Expire after 6 seconds
		var age: float = bolt.get_meta("bolt_age", 0.0) + delta
		bolt.set_meta("bolt_age", age)
		if age > 6.0:
			to_remove.append(bolt)
	for bolt in to_remove:
		if is_instance_valid(bolt):
			bolt.queue_free()
		_dummy_bolts.erase(bolt)
	# Survival game — time runs out = success
	if _game_timer <= 0.0:
		_end_game(true)


func _fire_dummy_bolt(dummy: Node3D, player: Node3D) -> void:
	if not is_instance_valid(dummy) or not is_instance_valid(player):
		return
	var bolt := Area3D.new()
	bolt.collision_layer = 0
	bolt.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.3
	col.shape = shape
	bolt.add_child(col)
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	mesh_inst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.1)
	mat.emission_energy_multiplier = 2.0
	mesh_inst.material_override = mat
	bolt.add_child(mesh_inst)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.3, 0.1)
	light.light_energy = 1.0
	light.omni_range = 3.0
	bolt.add_child(light)
	_game_parent.add_child(bolt)
	bolt.global_position = dummy.global_position + Vector3(0, 1.0, 0)
	var dir: Vector3 = (player.global_position + Vector3(0, 1, 0) - bolt.global_position).normalized()
	bolt.set_meta("bolt_dir", dir)
	bolt.set_meta("bolt_age", 0.0)
	_dummy_bolts.append(bolt)


func _update_fetch_frenzy(delta: float) -> void:
	# Count how many of the original fetch items are still alive
	var alive_count: int = 0
	for item in _fetch_items:
		if is_instance_valid(item):
			alive_count += 1
	_fetch_items_collected = _fetch_items.size() - alive_count
	# If all collected → success
	if alive_count == 0 and _fetch_items.size() > 0:
		_end_game(true)


func _end_game(success: bool) -> void:
	if _active_game < 0:
		return
	var gid: int = _active_game
	# Award TP based on performance
	var tp_awarded: int = 0
	if success:
		# Full completion = max TP
		tp_awarded = GameConstants.PET_TRAINING_TP_PER_GAME[gid]
	elif gid == GameConstants.PetTrainingGame.DASH_COURSE:
		# Partial: 1 TP per 2 waypoints hit
		tp_awarded = int(floor(float(_waypoints_hit) / 2.0))
	elif gid == GameConstants.PetTrainingGame.FETCH_FRENZY:
		# Partial: 1 TP per 3 items collected
		tp_awarded = int(floor(float(_fetch_items_collected) / 3.0))
	# Target dodge is all-or-nothing (survival)
	tp_awarded = mini(tp_awarded, GameConstants.PET_TRAINING_TP_PER_GAME[gid])
	if tp_awarded > 0:
		award_tp(tp_awarded)
	_cleanup_game()
	var msg: String = "🎓 Training complete! +%d TP" % tp_awarded if success else \
		"🎓 Training failed. +%d TP" % tp_awarded
	GameManager.add_message(msg)
	game_completed.emit(gid, tp_awarded, success)


# ─── Event hooks ──────────────────────────────────────────────────────────────

func notify_player_dashed() -> void:
	# Could be used for dash course scoring; currently waypoints use proximity
	pass


func notify_item_collected() -> void:
	# Fetch frenzy checks via alive-count instead
	pass


# ─── Reset / Save ─────────────────────────────────────────────────────────────

func reset() -> void:
	_cleanup_game()
	_tp = 0
	for i in range(_stat_levels.size()):
		_stat_levels[i] = 0
	tp_changed.emit(0)


func get_save_state() -> Dictionary:
	return {
		"tp": _tp,
		"stat_levels": _stat_levels.duplicate(),
	}


func load_save_state(data: Dictionary) -> void:
	_tp = int(data.get("tp", 0))
	var levels: Array = data.get("stat_levels", [0, 0, 0, 0])
	for i in range(mini(levels.size(), _stat_levels.size())):
		_stat_levels[i] = int(levels[i])
	tp_changed.emit(_tp)


func _on_game_restarted() -> void:
	reset()


func _on_player_died() -> void:
	_cleanup_game()
	# Keep TP/stats for the current run? No — player died ends the run.
	reset()