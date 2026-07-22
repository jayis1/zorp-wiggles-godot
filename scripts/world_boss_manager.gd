## Zorp Wiggles — World Boss Manager (Phase 26: World Life)
## An autoload singleton that periodically spawns a roaming "world boss" — a
## buffed-up version of an existing boss-type enemy (Drake, Void Leviathan,
## Ancient Sentinel, Gravity Elemental) that wanders the open world rather
## than sealing the player in an arena. World bosses:
##   - Spawn very rarely (every 5–10 minutes) and only one at a time.
##   - Spawn far from the player (60m) with a 3s telegraph (spawn warning).
##   - Have 1.6× HP, 1.2× damage, 2× XP, 2.5× score, and drop a loot shower.
##   - Despawn if the player flees beyond 180m (they are NOT arena-bound).
##   - Are flagged `is_world_boss` on the enemy node so the HUD/minimap and
##     the death handler can treat them specially.
##
## The loot shower on death is handled here by listening to `boss_defeated`
## and checking the `is_world_boss` flag on the dead boss.

extends Node

# class_name omitted — this is an autoload singleton named WorldBossManager;
# declaring class_name with the same name causes a "hides autoload singleton"
# parse error in Godot 4.4.

signal world_boss_spawned(boss: Node, boss_display_name: String)
signal world_boss_defeated(boss: Node, boss_display_name: String)

var _spawn_timer: float = 0.0
var _next_spawn_time: float = 0.0
var _active_world_boss: Node = null
var _active_display_name: String = ""

func _ready() -> void:
	_schedule_next_spawn()
	# Listen for boss deaths so we can drop the loot shower and clear our ref.
	if GameManager.boss_defeated.is_connected(_on_boss_defeated):
		pass
	else:
		GameManager.boss_defeated.connect(_on_boss_defeated)
	# Also listen for player death so we despawn the world boss cleanly.
	if not GameManager.player_died.is_connected(_on_player_died):
		GameManager.player_died.connect(_on_player_died)
	# Listen for game restart so we reset the spawn timer and clear our ref.
	# restart_game() frees all enemies (including the active world boss), so
	# we must drop our reference and reschedule the next spawn.
	if not GameManager.game_restarted.is_connected(_on_game_restarted):
		GameManager.game_restarted.connect(_on_game_restarted)

func _on_game_restarted() -> void:
	_active_world_boss = null
	_active_display_name = ""
	_schedule_next_spawn()

func _schedule_next_spawn() -> void:
	_next_spawn_time = randf_range(
		GameConstants.WORLD_BOSS_SPAWN_INTERVAL_MIN,
		GameConstants.WORLD_BOSS_SPAWN_INTERVAL_MAX
	)
	_spawn_timer = 0.0

func _process(delta: float) -> void:
	if GameManager.is_paused:
		return
	if not GameManager.player_is_alive and not CoOpManager.p2_active:
		return
	if _active_world_boss and is_instance_valid(_active_world_boss):
		# Check despawn-on-flee.
		var player: Node3D = get_tree().get_first_node_in_group("player")
		if player:
			var d: float = _active_world_boss.global_position.distance_to(player.global_position)
			if d > GameConstants.WORLD_BOSS_DESPAWN_DISTANCE:
				_despawn_world_boss("You escaped the world boss.")
		return
	# Count existing world bosses (safety: only one at a time).
	var existing: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and "is_world_boss" in e and e.is_world_boss:
			existing += 1
	if existing >= GameConstants.WORLD_BOSS_MAX_ALIVE:
		return
	_spawn_timer += delta
	if _spawn_timer >= _next_spawn_time:
		_try_spawn_world_boss()
		_schedule_next_spawn()

func _try_spawn_world_boss() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return
	# Pick a candidate boss type.
	var boss_type: int = GameConstants.WORLD_BOSS_CANDIDATES[randi() % GameConstants.WORLD_BOSS_CANDIDATES.size()]
	var display_name: String = GameConstants.WORLD_BOSS_NAMES.get(boss_type, "World Boss")
	# Pick a spawn position far from the player.
	var angle: float = randf() * TAU
	var dist: float = GameConstants.WORLD_BOSS_SPAWN_DISTANCE
	var spawn_pos: Vector3 = player.global_position + Vector3(cos(angle) * dist, 1.0, sin(angle) * dist)
	var extent: float = GameConstants.WORLD_EXTENT - 8.0
	spawn_pos.x = clampf(spawn_pos.x, -extent, extent)
	spawn_pos.z = clampf(spawn_pos.z, -extent, extent)
	# Telegraph: spawn a warning ring so the player has time to prepare.
	var warning_scene: PackedScene = load("res://scenes/entities/spawn_warning.tscn")
	if warning_scene:
		var warning: Node3D = warning_scene.instantiate()
		get_tree().current_scene.add_child(warning)
		warning.global_position = spawn_pos
		warning.set("duration", GameConstants.WORLD_BOSS_TELEGRAPH_TIME)
	# Materialize the boss after the telegraph delay.
	var delay_tw := create_tween()
	delay_tw.tween_interval(GameConstants.WORLD_BOSS_TELEGRAPH_TIME)
	delay_tw.tween_callback(_materialize_world_boss.bind(boss_type, spawn_pos, display_name))
	# Broadcast the imminent spawn so the HUD can warn the player.
	GameManager.add_message("⚠ A %s has appeared nearby! (World Boss)" % display_name)
	# Audio — deep rumble to telegraph the world boss arrival.
	AudioManager.play_sfx(AudioManager.SFX_WORLD_BOSS)
	world_boss_spawned.emit(null, display_name)

func _materialize_world_boss(boss_type: int, spawn_pos: Vector3, display_name: String) -> void:
	# Look up the scene path from the EnemySpawner's ENEMY_SCENES table.
	var scene_path: String = EnemySpawner.ENEMY_SCENES.get(boss_type, "")
	if scene_path.is_empty():
		print("[WorldBossManager] No scene for boss type %d" % boss_type)
		return
	var scene: PackedScene = load(scene_path)
	if not scene:
		print("[WorldBossManager] Failed to load boss scene: %s" % scene_path)
		return
	var boss: CharacterBody3D = scene.instantiate()
	boss.position = spawn_pos
	get_tree().current_scene.add_child(boss)
	GameManager.enemies.append(boss)
	# Apply world-boss stat multipliers and flag.
	if boss is EnemyBase:
		var eb: EnemyBase = boss as EnemyBase
		eb.max_hp = int(eb.max_hp * GameConstants.WORLD_BOSS_HP_MULT)
		eb.hp = eb.max_hp
		eb.damage = int(eb.damage * GameConstants.WORLD_BOSS_DAMAGE_MULT)
		eb.xp_reward = int(eb.xp_reward * GameConstants.WORLD_BOSS_XP_MULT)
		eb.score_reward = int(eb.score_reward * GameConstants.WORLD_BOSS_SCORE_MULT)
		# Override the display name.
		if "enemy_name" in eb:
			eb.enemy_name = display_name
		# Flag as a world boss so _die() emits boss_defeated (loot shower) and
		# the minimap can render a distinct pulsing red ring. is_world_boss is
		# declared on EnemyBase, so direct assignment works.
		eb.is_world_boss = true
		# Big camera shake on spawn.
		var cam_rig: Node3D = GameManager.camera_rig
		if cam_rig and cam_rig.has_method("add_trauma"):
			cam_rig.add_trauma(0.5)
		# Materialization particles.
		# ParticleEffects uses static methods — call directly (no instance check).
		ParticleEffects.spawn_materialization(get_tree().current_scene, spawn_pos, eb.base_color)
	_active_world_boss = boss
	_active_display_name = display_name
	# Emit the boss_spawned signal so the HUD boss bar appears.
	GameManager.boss_spawned.emit(boss)
	world_boss_spawned.emit(boss, display_name)
	GameManager.add_message("⚔ %s has emerged!" % display_name)

func _despawn_world_boss(reason: String) -> void:
	if not _active_world_boss or not is_instance_valid(_active_world_boss):
		_active_world_boss = null
		_active_display_name = ""
		return
	GameManager.add_message("⚠ %s — %s" % [_active_display_name, reason])
	var boss: Node = _active_world_boss
	_active_world_boss = null
	_active_display_name = ""
	# Use the public despawn_fade() method on EnemyBase instead of reaching
	# into private _material/body_mesh. This keeps the fade animation logic
	# encapsulated in the enemy class where those internals are owned.
	if boss is EnemyBase:
		(boss as EnemyBase).despawn_fade(0.8)
	else:
		boss.queue_free()

func _on_boss_defeated(boss: Node) -> void:
	if not boss or not is_instance_valid(boss):
		return
	if not ("is_world_boss" in boss) or not boss.is_world_boss:
		return
	# This was our world boss — drop the loot shower.
	var display_name: String = _active_display_name
	if display_name == "" and "enemy_name" in boss:
		display_name = boss.enemy_name
	_spawn_loot_shower(boss.global_position)
	# Record stats. The AchievementPopup reads these lifetime keys via its
	# periodic _check_progress_achievements() and unlocks the world_boss_*
	# achievements automatically — no direct reference needed (AchievementPopup
	# is a HUD child node, not an autoload).
	if Statistics and Statistics.has_method("record_world_boss_defeated"):
		Statistics.record_world_boss_defeated(display_name)
	world_boss_defeated.emit(boss, display_name)
	GameManager.add_message("🏆 %s defeated! Loot shower incoming!" % display_name)
	# Big camera shake.
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.8)
	_active_world_boss = null
	_active_display_name = ""

func _on_player_died() -> void:
	# Despawn the world boss cleanly when the player dies so it doesn't linger.
	if _active_world_boss and is_instance_valid(_active_world_boss):
		_despawn_world_boss("The world boss fades as you fall.")

func _spawn_loot_shower(pos: Vector3) -> void:
	# Spawn a burst of collectibles at the boss death location.
	var collectible_scene: PackedScene = load("res://scenes/entities/collectible.tscn")
	if not collectible_scene:
		return
	# Weighted loot table — favor rare items for world bosses.
	var loot_table: Array[Dictionary] = [
		{"type": GameConstants.CollectibleType.METEOR_SHARD, "weight": 3},
		{"type": GameConstants.CollectibleType.QUANTUM_FUZZ, "weight": 3},
		{"type": GameConstants.CollectibleType.NEBULA_DUST, "weight": 2},
		{"type": GameConstants.CollectibleType.STAR_FRUIT, "weight": 2},
		{"type": GameConstants.CollectibleType.XP_ORB, "weight": 1},
		{"type": GameConstants.CollectibleType.SPACE_GLOOP, "weight": 2},
	]
	var total_weight: int = 0
	for entry in loot_table:
		total_weight += int(entry["weight"])
	for i in range(GameConstants.WORLD_BOSS_LOOT_COUNT):
		var roll: int = randi() % total_weight
		var picked_type: int = GameConstants.CollectibleType.XP_ORB
		for entry in loot_table:
			roll -= int(entry["weight"])
			if roll < 0:
				picked_type = int(entry["type"])
				break
		var item: Area3D = collectible_scene.instantiate()
		get_tree().current_scene.add_child(item)
		# Scatter around the death position.
		var offset := Vector3(randf_range(-3, 3), 2.0, randf_range(-3, 3))
		item.global_position = pos + offset
		if "collectible_type" in item:
			item.collectible_type = picked_type
	# A big particle burst for the loot shower.
	ParticleEffects.spawn_mega_explosion(get_tree().current_scene, pos, Color(1.0, 0.85, 0.3))