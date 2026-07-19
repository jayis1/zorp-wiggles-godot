## Zorp Wiggles — Endgame Manager (Phase 34)
## Coordinates endgame content:
##   - NG+ / NG++ tiers (difficulty multipliers + rule changes unlocked by level)
##   - Survival Mode (no healing, no shops, one life)
##   - Gauntlet Mode (sequential biome challenges with a running timer)
##   - Boss Gauntlet (every boss in sequence, escalating, no heal between)
##   - Loot Cave (hidden area with rare loot guarded by elite enemies)
##   - Ancient Vault (puzzle-locked area with legendary loot, requires lore stones)
##
## NG+ tiers stack on top of the active game mode — a player could play
## "Endless NG+" or "Speedrun NG++". Survival/Gauntlet/Boss Gauntlet are
## independent modes selected from the mode selector.
##
## All colors use Godot 0-1 range.

extends Node

# ─── Signals ────────────────────────────────────────────────────────────────────
signal ng_tier_changed(tier: int)
signal survival_score_tick(score: int)
signal gauntlet_biome_changed(index: int, biome_id: int)
signal gauntlet_completed(total_time: float)
signal boss_gauntlet_progress(index: int, total: int)
signal boss_gauntlet_completed(total_time: float)
signal loot_cave_discovered(cave_id: int)
signal ancient_vault_unlocked()

# ─── State ─────────────────────────────────────────────────────────────────────
var _ng_tier: int = GameConstants.NGTier.NORMAL
var _ng_unlocked: Array[bool] = [true, false, false]
var _survival_active: bool = false
var _survival_time: float = 0.0
var _survival_next_boss_time: float = 0.0
var _gauntlet_active: bool = false
var _gauntlet_index: int = 0
var _gauntlet_biome_timer: float = 0.0
var _gauntlet_kills_this_biome: int = 0
var _gauntlet_total_time: float = 0.0
var _gauntlet_completed: bool = false
var _boss_gauntlet_active: bool = false
var _boss_gauntlet_index: int = 0
var _boss_gauntlet_intermission: float = 0.0
var _boss_gauntlet_total_time: float = 0.0
var _boss_gauntlet_completed: bool = false
var _loot_caves: Array[Dictionary] = []
var _ancient_vault: Dictionary = {}
var _ancient_vault_unlocked: bool = false
var _rng := RandomNumberGenerator.new()

# ─── Persistence ─────────────────────────────────────────────────────────────────
const SAVE_PATH: String = "user://zorp_endgame.json"

# ─── Public API ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("endgame_manager")
	_load_unlocks()
	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)
		GameManager.player_died.connect(_on_player_died)
		GameManager.boss_defeated.connect(_on_boss_defeated)
		GameManager.boss_spawned.connect(_on_boss_spawned)
	if Statistics:
		Statistics.stats_updated.connect(_check_unlocks)

func _exit_tree() -> void:
	_save_unlocks()

# ─── NG+ Tier System ────────────────────────────────────────────────────────────

func get_ng_tier() -> int:
	return _ng_tier

func set_ng_tier(tier: int) -> void:
	if tier < 0 or tier > GameConstants.NGTier.NG_PLUS_PLUS:
		return
	if not _ng_unlocked[tier]:
		push_warning("[Endgame] NG tier %d not unlocked." % tier)
		return
	_ng_tier = tier
	ng_tier_changed.emit(tier)
	print("[Endgame] NG tier set to: %s" % GameConstants.NG_TIER_NAMES[tier])

func cycle_ng_tier() -> void:
	# Cycle to the next unlocked tier (wraps to NORMAL).
	for i in range(1, GameConstants.NGTier.size() + 1):
		var next: int = (_ng_tier + i) % GameConstants.NGTier.size()
		if _ng_unlocked[next]:
			set_ng_tier(next)
			return

func is_ng_plus() -> bool:
	return _ng_tier >= GameConstants.NGTier.NG_PLUS

func is_ng_plus_plus() -> bool:
	return _ng_tier == GameConstants.NGTier.NG_PLUS_PLUS

func get_enemy_hp_mult() -> float:
	return GameConstants.NG_TIER_ENEMY_HP_MULT[_ng_tier]

func get_enemy_damage_mult() -> float:
	return GameConstants.NG_TIER_ENEMY_DAMAGE_MULT[_ng_tier]

func get_enemy_speed_mult() -> float:
	return GameConstants.NG_TIER_ENEMY_SPEED_MULT[_ng_tier]

func is_loot_rare_only() -> bool:
	return GameConstants.NG_TIER_LOOT_RARE_ONLY[_ng_tier]

func do_bosses_roam() -> bool:
	return GameConstants.NG_TIER_BOSSES_ROAM[_ng_tier]

func is_minimap_disabled() -> bool:
	return GameConstants.NG_TIER_NO_MINIMAP[_ng_tier]

func is_permadeath_option() -> bool:
	return GameConstants.NG_TIER_PERMADEATH_OPTION[_ng_tier]

func _check_unlocks() -> void:
	# Unlock NG+ at player level 25, NG++ at 40.
	if not _ng_unlocked[GameConstants.NGTier.NG_PLUS]:
		if GameManager.player_level >= GameConstants.NG_TIER_UNLOCK_LEVEL:
			_ng_unlocked[GameConstants.NGTier.NG_PLUS] = true
			GameManager.add_message("🔥 NG+ UNLOCKED! Tougher enemies, rare-only loot.")
	if not _ng_unlocked[GameConstants.NGTier.NG_PLUS_PLUS]:
		if GameManager.player_level >= GameConstants.NG_PLUS_PLUS_UNLOCK_LEVEL:
			_ng_unlocked[GameConstants.NGTier.NG_PLUS_PLUS] = true
			GameManager.add_message("💀 NG++ UNLOCKED! All bosses roam, no minimap, permadeath option.")

# ─── Survival Mode ──────────────────────────────────────────────────────────────

func is_survival_active() -> bool:
	return _survival_active

func get_survival_time() -> float:
	return _survival_time

func start_survival() -> void:
	_survival_active = true
	_survival_time = 0.0
	_survival_next_boss_time = GameConstants.SURVIVAL_MODE_BOSS_INTERVAL
	GameManager.add_message("☠ SURVIVAL MODE — No healing, no shops, one life. Survive!")
	# Reduce starting HP to the survival baseline.
	if GameConstants.SURVIVAL_MODE_NO_HEALING:
		GameManager.player_max_hp = GameConstants.SURVIVAL_MODE_START_HP
		GameManager.player_hp = GameConstants.SURVIVAL_MODE_START_HP
		GameManager.hp_changed.emit(GameManager.player_hp, GameManager.player_max_hp)

func _update_survival(delta: float) -> void:
	_survival_time += delta
	# Passive survival score (reward for staying alive).
	var new_score: int = int(_survival_time * GameConstants.SURVIVAL_MODE_SCORE_PER_SEC)
	GameManager.player_score += new_score
	survival_score_tick.emit(GameManager.player_score)
	# Periodic boss spawn.
	_survival_next_boss_time -= delta
	if _survival_next_boss_time <= 0:
		_survival_next_boss_time = GameConstants.SURVIVAL_MODE_BOSS_INTERVAL
		_spawn_survival_boss()

func _spawn_survival_boss() -> void:
	# Pick a random boss from the existing roster.
	var boss_types: Array[int] = [
		GameConstants.EnemyType.DRAKE,
		GameConstants.EnemyType.SERPENT,
		GameConstants.EnemyType.GRAVITON,
		GameConstants.EnemyType.VOID_LEVIATHAN,
		GameConstants.EnemyType.ANCIENT_SENTINEL,
	]
	var bt: int = boss_types[_rng.randi() % boss_types.size()]
	var scene_path := _boss_scene_path(bt)
	var scene: PackedScene = load(scene_path)
	if not scene:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
	var angle: float = _rng.randf() * TAU
	var pos: Vector3 = player.global_position + Vector3(cos(angle) * 18.0, 1.5, sin(angle) * 18.0)
	var boss := scene.instantiate()
	boss.position = pos
	get_tree().current_scene.add_child(boss)
	if "enemies" in GameManager:
		GameManager.enemies.append(boss)
	if boss is EnemyBase:
		var hp_mult: float = GameConstants.SURVIVAL_MODE_ENEMY_MULT
		boss.max_hp = int(boss.max_hp * hp_mult)
		boss.hp = boss.max_hp
		boss.is_arena_boss = true
	GameManager.boss_spawned.emit(boss)
	GameManager.add_message("☠ Survival boss incoming!")

# ─── Gauntlet Mode ─────────────────────────────────────────────────────────────

func is_gauntlet_active() -> bool:
	return _gauntlet_active

func get_gauntlet_index() -> int:
	return _gauntlet_index

func get_gauntlet_total_time() -> float:
	return _gauntlet_total_time

func start_gauntlet() -> void:
	_gauntlet_active = true
	_gauntlet_index = 0
	_gauntlet_biome_timer = GameConstants.GAUNTLET_TIME_PER_BIOME
	_gauntlet_kills_this_biome = 0
	_gauntlet_total_time = 0.0
	_gauntlet_completed = false
	_advance_gauntlet_biome()
	GameManager.add_message("⚔ GAUNTLET MODE — %d biome challenges back-to-back!" % GameConstants.GAUNTLET_BIOME_COUNT)

func _advance_gauntlet_biome() -> void:
	if _gauntlet_index >= GameConstants.GAUNTLET_BIOME_COUNT:
		_finish_gauntlet()
		return
	# Pick a random biome for this challenge.
	var biome_pool: Array[int] = [
		GameConstants.Biome.GRASS, GameConstants.Biome.DESERT,
		GameConstants.Biome.FOREST, GameConstants.Biome.SNOW,
		GameConstants.Biome.CRYSTAL, GameConstants.Biome.MUSHROOM,
		GameConstants.Biome.ALIEN, GameConstants.Biome.VOLCANO_CORE,
	]
	var biome_id: int = biome_pool[_rng.randi() % biome_pool.size()]
	_gauntlet_biome_timer = GameConstants.GAUNTLET_TIME_PER_BIOME
	_gauntlet_kills_this_biome = 0
	gauntlet_biome_changed.emit(_gauntlet_index, biome_id)
	GameManager.add_message("⚔ Gauntlet %d/%d: %s — Kill %d enemies in %ds!" % [
		_gauntlet_index + 1, GameConstants.GAUNTLET_BIOME_COUNT,
		GameConstants.BIOME_NAMES.get(biome_id, "Unknown"),
		GameConstants.GAUNTLET_KILLS_PER_BIOME, int(GameConstants.GAUNTLET_TIME_PER_BIOME)
	])

func _update_gauntlet(delta: float) -> void:
	if _gauntlet_completed:
		return
	_gauntlet_total_time += delta
	_gauntlet_biome_timer -= delta
	if _gauntlet_biome_timer <= 0 or _gauntlet_kills_this_biome >= GameConstants.GAUNTLET_KILLS_PER_BIOME:
		var success: bool = _gauntlet_kills_this_biome >= GameConstants.GAUNTLET_KILLS_PER_BIOME
		if not success:
			GameManager.add_message("✦ Gauntlet %d failed — moving on." % (_gauntlet_index + 1))
		else:
			GameManager.gain_xp(80)
			GameManager.add_message("✦ Gauntlet %d cleared! +80 XP" % (_gauntlet_index + 1))
		_gauntlet_index += 1
		_advance_gauntlet_biome()

func _finish_gauntlet() -> void:
	_gauntlet_completed = true
	_gauntlet_active = false
	gauntlet_completed.emit(_gauntlet_total_time)
	GameManager.add_message("🏆 GAUNTLET COMPLETE! Total time: %.1fs" % _gauntlet_total_time)
	if Statistics:
		Statistics.set_lifetime_max("gauntlet_pb_time", _gauntlet_total_time)

func notify_gauntlet_kill() -> void:
	if not _gauntlet_active:
		return
	_gauntlet_kills_this_biome += 1

# ─── Boss Gauntlet Mode ────────────────────────────────────────────────────────

func is_boss_gauntlet_active() -> bool:
	return _boss_gauntlet_active

func get_boss_gauntlet_index() -> int:
	return _boss_gauntlet_index

func get_boss_gauntlet_total_time() -> float:
	return _boss_gauntlet_total_time

func start_boss_gauntlet() -> void:
	_boss_gauntlet_active = true
	_boss_gauntlet_index = 0
	_boss_gauntlet_intermission = 2.0
	_boss_gauntlet_total_time = 0.0
	_boss_gauntlet_completed = false
	GameManager.add_message("☠ BOSS GAUNTLET — Every boss in sequence, escalating, NO HEALING!")

func _update_boss_gauntlet(delta: float) -> void:
	if _boss_gauntlet_completed:
		return
	_boss_gauntlet_total_time += delta
	if _boss_gauntlet_intermission > 0:
		_boss_gauntlet_intermission -= delta
		if _boss_gauntlet_intermission <= 0:
			_spawn_boss_gauntlet_next()
		return
	# No boss active → previous one defeated.
	if GameManager.current_boss == null or not is_instance_valid(GameManager.current_boss):
		_boss_gauntlet_index += 1
		if _boss_gauntlet_index >= GameConstants.BOSS_GAUNTLET_QUEUE.size():
			_finish_boss_gauntlet()
			return
		_boss_gauntlet_intermission = GameConstants.BOSS_GAUNTLET_INTERMISSION
		GameManager.add_message("✦ Boss down! Next in %.0fs..." % _boss_gauntlet_intermission)

func _spawn_boss_gauntlet_next() -> void:
	if _boss_gauntlet_index >= GameConstants.BOSS_GAUNTLET_QUEUE.size():
		_finish_boss_gauntlet()
		return
	var idx: int = _boss_gauntlet_index
	var bt: int = GameConstants.BOSS_GAUNTLET_QUEUE[idx]
	var scene_path := _boss_scene_path(bt)
	var scene: PackedScene = load(scene_path)
	if not scene:
		# Skip missing boss scenes.
		_boss_gauntlet_index += 1
		_boss_gauntlet_intermission = 0.5
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		_boss_gauntlet_intermission = 0.5
		return
	var angle: float = _rng.randf() * TAU
	var pos: Vector3 = player.global_position + Vector3(cos(angle) * 18.0, 1.5, sin(angle) * 18.0)
	var boss := scene.instantiate()
	boss.position = pos
	get_tree().current_scene.add_child(boss)
	if "enemies" in GameManager:
		GameManager.enemies.append(boss)
	# Escalating HP / damage / speed per index.
	var hp_mult: float = 1.0 + idx * GameConstants.BOSS_GAUNTLET_HP_MULT_PER_INDEX
	var dmg_mult: float = 1.0 + idx * GameConstants.BOSS_GAUNTLET_DAMAGE_MULT_PER_INDEX
	var spd_mult: float = 1.0 + idx * GameConstants.BOSS_GAUNTLET_SPEED_MULT_PER_INDEX
	if boss is EnemyBase:
		boss.max_hp = int(boss.max_hp * hp_mult)
		boss.hp = boss.max_hp
		boss.damage = int(boss.damage * dmg_mult)
		if "speed" in boss:
			boss.speed *= spd_mult
		boss.is_arena_boss = true
	GameManager.boss_spawned.emit(boss)
	boss_gauntlet_progress.emit(_boss_gauntlet_index, GameConstants.BOSS_GAUNTLET_QUEUE.size())
	GameManager.add_message("☠ Boss Gauntlet %d/%d" % [_boss_gauntlet_index + 1, GameConstants.BOSS_GAUNTLET_QUEUE.size()])

func _finish_boss_gauntlet() -> void:
	_boss_gauntlet_completed = true
	_boss_gauntlet_active = false
	boss_gauntlet_completed.emit(_boss_gauntlet_total_time)
	GameManager.add_message("🏆 BOSS GAUNTLET COMPLETE! Total time: %.1fs" % _boss_gauntlet_total_time)
	if Statistics:
		Statistics.set_lifetime_max("boss_gauntlet_pb_time", _boss_gauntlet_total_time)

# ─── Loot Cave ──────────────────────────────────────────────────────────────────

func get_loot_caves() -> Array[Dictionary]:
	return _loot_caves

func generate_loot_caves() -> void:
	# Spawn 2 loot caves per world, far from spawn.
	_rng.seed = GameManager.world_seed if GameManager else randi()
	_loot_caves.clear()
	for i in 2:
		var angle: float = _rng.randf() * TAU
		var dist: float = _rng.randf_range(GameConstants.LOOT_CAVE_MIN_DISTANCE, GameConstants.LOOT_CAVE_MAX_DISTANCE)
		var pos := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var cave := {
			"id": i,
			"position": pos,
			"discovered": false,
			"cleared": false,
		}
		_loot_caves.append(cave)
		_build_loot_cave_entrance(cave)
	print("[Endgame] Generated %d loot caves" % _loot_caves.size())

func _build_loot_cave_entrance(cave: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "LootCaveEntrance_%d" % cave.id
	root.position = cave.position
	root.set_meta("loot_cave_id", cave.id)
	root.add_to_group("loot_cave_entrance")
	# Glowing golden entrance.
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 2.0
	ring_mesh.bottom_radius = 2.0
	ring_mesh.height = 0.2
	ring.mesh = ring_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.2)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	ring.position = Vector3(0, 0.1, 0)
	root.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.2)
	light.light_energy = 3.0
	light.omni_range = 12.0
	light.position = Vector3(0, 1.5, 0)
	root.add_child(light)
	var label := Label3D.new()
	label.text = "💎 LOOT CAVE"
	label.font_size = 28
	label.position = Vector3(0, 4.5, 0)
	label.modulate = Color(1.0, 0.85, 0.2)
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	root.add_child(label)
	# Interaction area.
	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 3.0
	shape.height = 4.0
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(_on_loot_cave_entered.bind(cave.id))
	root.add_child(area)
	# Attach to the scene.
	get_tree().current_scene.add_child(root)

func _on_loot_cave_entered(body: Node, cave_id: int) -> void:
	if not body.is_in_group("player"):
		return
	enter_loot_cave(cave_id)

func enter_loot_cave(cave_id: int) -> void:
	if cave_id < 0 or cave_id >= _loot_caves.size():
		return
	var cave: Dictionary = _loot_caves[cave_id]
	if cave.cleared:
		GameManager.add_message("This loot cave has already been cleared.")
		return
	if not cave.discovered:
		cave.discovered = true
		loot_cave_discovered.emit(cave_id)
		GameManager.add_message("💎 Discovered a Loot Cave!")
	_spawn_loot_cave_interior(cave)

func _spawn_loot_cave_interior(cave: Dictionary) -> void:
	# Build a small interior below the surface — a single round room.
	var root := Node3D.new()
	root.name = "LootCaveInterior_%d" % cave.id
	root.position = Vector3(cave.position.x, GameConstants.LOOT_CAVE_DEPTH, cave.position.z)
	get_tree().current_scene.add_child(root)
	# Floor.
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GameConstants.LOOT_CAVE_RADIUS * 2.0, GameConstants.LOOT_CAVE_RADIUS * 2.0)
	floor_mesh.mesh = plane
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.2, 0.15, 0.1)
	floor_mesh.material_override = fmat
	root.add_child(floor_mesh)
	# Walls — a ring of static bodies.
	var wall_segments: int = 12
	for i in wall_segments:
		var angle: float = (float(i) / wall_segments) * TAU
		var wall := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.0, 4.0, 0.5)
		col.shape = shape
		wall.add_child(col)
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = shape.size
		mesh_inst.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.1, 0.08)
		mesh_inst.material_override = mat
		wall.add_child(mesh_inst)
		wall.position = Vector3(cos(angle) * GameConstants.LOOT_CAVE_RADIUS, 2.0, sin(angle) * GameConstants.LOOT_CAVE_RADIUS)
		wall.look_at(Vector3(0, 2.0, 0))
		root.add_child(wall)
	# Light.
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.2)
	light.light_energy = 3.0
	light.omni_range = 18.0
	light.position = Vector3(0, 4.0, 0)
	root.add_child(light)
	# Spawn elite guards.
	_spawn_loot_cave_elites(root, cave)
	# Spawn rare collectibles.
	_spawn_loot_cave_rewards(root, cave)
	# Move the player into the cave.
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		player.global_position = root.global_position + Vector3(0, 1.5, 0)
	GameManager.add_message("💎 Loot Cave entered — defeat the elite guardians!")

func _spawn_loot_cave_elites(root: Node3D, _cave: Dictionary) -> void:
	var elite_pool: Array[int] = [
		GameConstants.EnemyType.ECHO_KNIGHT,
		GameConstants.EnemyType.GRAVITY_ELEMENTAL,
		GameConstants.EnemyType.TIME_WARDEN,
	]
	for i in GameConstants.LOOT_CAVE_ELITE_COUNT:
		var bt: int = elite_pool[_rng.randi() % elite_pool.size()]
		var scene_path := _boss_scene_path(bt)
		if scene_path.is_empty():
			scene_path = "res://scenes/entities/enemy_blob.tscn"
		var scene: PackedScene = load(scene_path)
		if not scene:
			continue
		var elite := scene.instantiate()
		var angle: float = (float(i) / GameConstants.LOOT_CAVE_ELITE_COUNT) * TAU
		var pos: Vector3 = root.global_position + Vector3(cos(angle) * 6.0, 1.5, sin(angle) * 6.0)
		elite.position = pos
		get_tree().current_scene.add_child(elite)
		if "enemies" in GameManager:
			GameManager.enemies.append(elite)
		if elite is EnemyBase:
			elite.max_hp = int(elite.max_hp * GameConstants.LOOT_CAVE_ELITE_HP_MULT)
			elite.hp = elite.max_hp
			elite.damage = int(elite.damage * GameConstants.LOOT_CAVE_ELITE_DAMAGE_MULT)
	# Mark the last elite's death to clear the cave — connect to boss_defeated
	# via a flag on the cave.
	# We track via remaining-enemy count: when all elite guards are dead, the
	# cave is cleared. The _on_boss_defeated handler checks this.

func _spawn_loot_cave_rewards(root: Node3D, cave: Dictionary) -> void:
	# Spawn rare collectibles in a circle at the center of the cave.
	var collectible_scene: PackedScene = load("res://scenes/entities/collectible.tscn")
	if not collectible_scene:
		return
	var rare_types: Array[int] = [
		GameConstants.CollectibleType.METEOR_SHARD,
		GameConstants.CollectibleType.QUANTUM_FUZZ,
		GameConstants.CollectibleType.NEBULA_DUST,
	]
	for i in GameConstants.LOOT_CAVE_RARE_ITEM_COUNT:
		var type: int = rare_types[_rng.randi() % rare_types.size()]
		var item := collectible_scene.instantiate()
		var angle: float = (float(i) / GameConstants.LOOT_CAVE_RARE_ITEM_COUNT) * TAU
		var pos: Vector3 = root.global_position + Vector3(cos(angle) * 3.0, 0.5, sin(angle) * 3.0)
		item.position = pos
		get_tree().current_scene.add_child(item)
		if item.has_method("set_type"):
			item.set_type(type)
		elif "collectible_type" in item:
			item.collectible_type = type
		if "collectibles" in GameManager:
			GameManager.collectibles.append(item)
	# Mark that these items are tied to the cave (used for clear check).
	cave.set("reward_count", GameConstants.LOOT_CAVE_RARE_ITEM_COUNT)

# ─── Ancient Vault ──────────────────────────────────────────────────────────────

func is_ancient_vault_unlocked() -> bool:
	return _ancient_vault_unlocked

func get_ancient_vault() -> Dictionary:
	return _ancient_vault

func generate_ancient_vault() -> void:
	_rng.seed = GameManager.world_seed if GameManager else randi()
	var angle: float = _rng.randf() * TAU
	var pos := Vector3(cos(angle) * GameConstants.ANCIENT_VAULT_DISTANCE, 0.0, sin(angle) * GameConstants.ANCIENT_VAULT_DISTANCE)
	_ancient_vault = {
		"position": pos,
		"unlocked": false,
		"opened": false,
		"puzzle_steps_completed": 0,
	}
	_build_vault_entrance()
	print("[Endgame] Generated ancient vault at %s" % str(pos))

func _build_vault_entrance() -> void:
	var root := Node3D.new()
	root.name = "AncientVaultEntrance"
	root.position = _ancient_vault.position
	root.set_meta("ancient_vault", true)
	root.add_to_group("ancient_vault_entrance")
	# Large stone archway.
	var arch := MeshInstance3D.new()
	var arch_mesh := BoxMesh.new()
	arch_mesh.size = Vector3(6.0, 8.0, 1.0)
	arch.mesh = arch_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.35, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.6, 0.3)
	mat.emission_energy_multiplier = 0.5
	arch.material_override = mat
	root.add_child(arch)
	var light := OmniLight3D.new()
	light.light_color = Color(0.8, 0.6, 0.3)
	light.light_energy = 3.0
	light.omni_range = 15.0
	light.position = Vector3(0, 4.0, 0)
	root.add_child(light)
	# Locked indicator.
	var label := Label3D.new()
	label.text = "🔒 ANCIENT VAULT (Lore Stones: 0/%d)" % GameConstants.ANCIENT_VAULT_LORE_STONES_REQUIRED
	label.font_size = 28
	label.position = Vector3(0, 9.5, 0)
	label.modulate = Color(0.9, 0.7, 0.3)
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	root.add_child(label)
	root.set_meta("label", label)
	# Interaction area.
	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 4.0
	shape.height = 6.0
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(_on_vault_entered.bind(root))
	root.add_child(area)
	get_tree().current_scene.add_child(root)

func _on_vault_entered(body: Node, root: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	try_open_vault(root)

func try_open_vault(root: Node) -> void:
	if _ancient_vault.is_empty():
		return
	if _ancient_vault.get("opened", false):
		GameManager.add_message("The Ancient Vault has already been plundered.")
		return
	# Check lore stone count from Statistics.
	var lore_count: int = 0
	if Statistics:
		var v: Variant = Statistics.get_lifetime_stat("lore_stones_read")
		if v != null:
			lore_count = int(v)
	if lore_count < GameConstants.ANCIENT_VAULT_LORE_STONES_REQUIRED:
		GameManager.add_message("🔒 The vault is sealed. Read %d more lore stones to unlock." % (GameConstants.ANCIENT_VAULT_LORE_STONES_REQUIRED - lore_count))
		return
	# Unlock the vault.
	_ancient_vault.unlocked = true
	_ancient_vault_unlocked = true
	ancient_vault_unlocked.emit()
	# Solve the puzzle (procedural: walk to N glowing runes in order).
	_spawn_vault_puzzle(root)
	GameManager.add_message("✦ Ancient Vault unlocked! Solve the rune puzzle to claim the legendary loot.")

func _spawn_vault_puzzle(root: Node) -> void:
	# Spawn ANCIENT_VAULT_PUZZLE_STEPS runes around the vault that the player
	# must touch in order. This is a simple "Simon says" puzzle.
	for i in GameConstants.ANCIENT_VAULT_PUZZLE_STEPS:
		var rune := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.0
		mesh.bottom_radius = 1.0
		mesh.height = 0.1
		rune.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.4, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.6, 0.3)
		mat.emission_energy_multiplier = 1.5
		rune.material_override = mat
		var angle: float = (float(i) / GameConstants.ANCIENT_VAULT_PUZZLE_STEPS) * TAU
		rune.position = Vector3(cos(angle) * 5.0, 0.05, sin(angle) * 5.0)
		rune.set_meta("puzzle_index", i)
		rune.set_meta("puzzle_activated", false)
		rune.add_to_group("vault_puzzle_rune")
		root.add_child(rune)
	# Order is stored on the vault manager.
	var order: Array[int] = []
	for i in GameConstants.ANCIENT_VAULT_PUZZLE_STEPS:
		order.append(i)
	order.shuffle()
	_ancient_vault["puzzle_order"] = order
	_ancient_vault["puzzle_progress"] = 0
	GameManager.add_message("Touch the glowing runes in order.")

func notify_puzzle_rune_touched(rune: Node) -> void:
	if _ancient_vault.is_empty() or not _ancient_vault.get("unlocked", false):
		return
	if _ancient_vault.get("opened", false):
		return
	var order: Array = _ancient_vault.get("puzzle_order", [])
	var progress: int = _ancient_vault.get("puzzle_progress", 0)
	var idx: int = rune.get_meta("puzzle_index")
	if idx == order[progress]:
		# Correct — light up the rune.
		rune.set_meta("puzzle_activated", true)
		if rune is MeshInstance3D and rune.material_override:
			rune.material_override.emission_energy_multiplier = 4.0
		progress += 1
		_ancient_vault["puzzle_progress"] = progress
		AudioManager.play_sfx(AudioManager.SFX_LEVEL_UP)
		if progress >= order.size():
			_complete_vault_puzzle()
		else:
			GameManager.add_message("✦ Rune %d/%d correct!" % [progress, order.size()])
	else:
		# Wrong — reset progress.
		_ancient_vault["puzzle_progress"] = 0
		# Reset all runes.
		for r in get_tree().get_nodes_in_group("vault_puzzle_rune"):
			if r is MeshInstance3D and r.material_override:
				r.material_override.emission_energy_multiplier = 1.5
				r.set_meta("puzzle_activated", false)
		GameManager.add_message("✗ Wrong rune! Puzzle reset.")

func _complete_vault_puzzle() -> void:
	_ancient_vault["opened"] = true
	# Spawn the vault guardian.
	_spawn_vault_guardian()
	# Spawn legendary loot (only after the guardian is defeated — see _on_boss_defeated).
	GameManager.add_message("🏆 Puzzle solved! The Vault Guardian awakens...")

func _spawn_vault_guardian() -> void:
	var scene: PackedScene = load("res://scenes/entities/enemy_drake.tscn")
	if not scene:
		return
	var guardian := scene.instantiate()
	var pos: Vector3 = _ancient_vault.position + Vector3(0, 1.5, 0)
	guardian.position = pos
	get_tree().current_scene.add_child(guardian)
	if "enemies" in GameManager:
		GameManager.enemies.append(guardian)
	if guardian is EnemyBase:
		guardian.enemy_name = "Ancient Vault Guardian"
		guardian.max_hp = GameConstants.ANCIENT_VAULT_GUARDIAN_HP
		guardian.hp = guardian.max_hp
		guardian.damage = GameConstants.ANCIENT_VAULT_GUARDIAN_DAMAGE
		guardian.speed = GameConstants.ANCIENT_VAULT_GUARDIAN_SPEED
		guardian.is_arena_boss = true
		guardian.set_meta("vault_guardian", true)
	GameManager.boss_spawned.emit(guardian)
	guardian.connect("enemy_died", _on_vault_guardian_died)

func _on_vault_guardian_died(_enemy: Node) -> void:
	# Spawn legendary loot at the vault entrance.
	var collectible_scene: PackedScene = load("res://scenes/entities/collectible.tscn")
	if not collectible_scene:
		return
	var legendary_types: Array[int] = [
		GameConstants.CollectibleType.METEOR_SHARD,
		GameConstants.CollectibleType.QUANTUM_FUZZ,
		GameConstants.CollectibleType.NEBULA_DUST,
	]
	for i in GameConstants.ANCIENT_VAULT_LEGENDARY_ITEM_COUNT:
		var type: int = legendary_types[i % legendary_types.size()]
		var item := collectible_scene.instantiate()
		var angle: float = (float(i) / GameConstants.ANCIENT_VAULT_LEGENDARY_ITEM_COUNT) * TAU
		item.position = _ancient_vault.position + Vector3(cos(angle) * 3.0, 0.5, sin(angle) * 3.0)
		get_tree().current_scene.add_child(item)
		if item.has_method("set_type"):
			item.set_type(type)
		elif "collectible_type" in item:
			item.collectible_type = type
		if "collectibles" in GameManager:
			GameManager.collectibles.append(item)
	GameManager.add_message("🏆 Ancient Vault Guardian defeated! Legendary loot claimed!")
	GameManager.gain_xp(500)
	GameManager.player_score += 2000
	if Statistics:
		Statistics.set_lifetime_max("ancient_vault_cleared", 1)

# ─── Per-Frame Update ─────────────────────────────────────────────────────────────

func update(delta: float) -> void:
	if GameManager.is_paused or not GameManager.player_is_alive:
		return
	if _survival_active:
		_update_survival(delta)
	if _gauntlet_active and not _gauntlet_completed:
		_update_gauntlet(delta)
	if _boss_gauntlet_active and not _boss_gauntlet_completed:
		_update_boss_gauntlet(delta)

# ─── Signal Handlers ───────────────────────────────────────────────────────────

func _on_game_restarted() -> void:
	# Reset mode-driven state, keep NG tier + unlocks.
	_survival_active = false
	_survival_time = 0.0
	_gauntlet_active = false
	_gauntlet_completed = false
	_boss_gauntlet_active = false
	_boss_gauntlet_completed = false
	# Regenerate loot caves + vault for the new world.
	call_deferred("generate_loot_caves")
	call_deferred("generate_ancient_vault")

func _on_player_died() -> void:
	# Stop all active modes on death.
	_survival_active = false
	_gauntlet_active = false
	_boss_gauntlet_active = false
	# Permadeath (NG++ option): clear the autosave so the run can't be reloaded.
	if is_permadeath_option() and SaveSystem:
		SaveSystem.delete_save()
		GameManager.add_message("💀 PERMADEATH — Save deleted.")

func _on_boss_defeated(boss: Node) -> void:
	# Check if this was a vault guardian.
	if boss and boss.has_meta("vault_guardian"):
		_on_vault_guardian_died(boss)
	# Check if all loot cave elites are dead (clear the first active cave).
	_check_loot_cave_clear()

func _on_boss_spawned(_boss: Node) -> void:
	pass

func _check_loot_cave_clear() -> void:
	for cave in _loot_caves:
		if cave.cleared:
			continue
		if not cave.discovered:
			continue
		# Count remaining enemies near the cave.
		var cave_pos: Vector3 = cave.position
		var remaining: int = 0
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.is_dead:
				continue
			if e.global_position.distance_to(Vector3(cave_pos.x, GameConstants.LOOT_CAVE_DEPTH, cave_pos.z)) < 25.0:
				remaining += 1
		if remaining == 0:
			cave.cleared = true
			GameManager.add_message("💎 Loot Cave cleared! Bonus +200 score.")
			GameManager.player_score += 200

# ─── Persistence ─────────────────────────────────────────────────────────────────

func _load_unlocks() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var unlocks: Array = parsed.get("unlocks", [true, false, false])
	for i in min(unlocks.size(), _ng_unlocked.size()):
		_ng_unlocked[i] = bool(unlocks[i])
	_ng_tier = int(parsed.get("tier", 0))
	_ng_tier = clampi(_ng_tier, 0, GameConstants.NGTier.size() - 1)

func _save_unlocks() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	var data: Dictionary = {
		"unlocks": _ng_unlocked,
		"tier": _ng_tier,
	}
	file.store_string(JSON.stringify(data, "  "))
	file.close()

# ─── Helpers ────────────────────────────────────────────────────────────────────

func _boss_scene_path(boss_type: int) -> String:
	match boss_type:
		GameConstants.EnemyType.DRAKE:
			return "res://scenes/entities/enemy_drake.tscn"
		GameConstants.EnemyType.SERPENT:
			return "res://scenes/entities/enemy_serpent.tscn"
		GameConstants.EnemyType.GRAVITON:
			return "res://scenes/entities/enemy_graviton.tscn"
		GameConstants.EnemyType.VOID_LEVIATHAN:
			return "res://scenes/entities/enemy_void_leviathan.tscn"
		GameConstants.EnemyType.ANCIENT_SENTINEL:
			return "res://scenes/entities/enemy_ancient_sentinel.tscn"
		GameConstants.EnemyType.GRAVITY_ELEMENTAL:
			return "res://scenes/entities/enemy_gravity_elemental.tscn"
		GameConstants.EnemyType.ECHO_KNIGHT:
			return "res://scenes/entities/enemy_echo_knight.tscn"
		GameConstants.EnemyType.TIME_WARDEN:
			return "res://scenes/entities/enemy_time_warden.tscn"
		GameConstants.EnemyType.BLOB:
			return "res://scenes/entities/enemy_blob.tscn"
		_:
			return ""