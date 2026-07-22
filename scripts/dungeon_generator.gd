## Zorp Wiggles — Procedural Dungeon Generator (Phase 33)
## Generates underground dungeons scattered across the world. Each dungeon has:
##   - An entrance portal on the surface (glowing structure)
##   - A small procedurally generated layout of rooms connected by corridors
##   - Enemies in each room (theme-appropriate)
##   - Traps (reuses environmental_hazard.tscn)
##   - A mini-boss in the final room
##   - A reward chest at the very end
##
## Dungeons are seeded by the world seed for deterministic generation. The
## player interacts with the entrance portal to "descend" — the dungeon is
## built as a separate Node3D below the surface (y = DUNGEON_FLOOR_Y).
##
## All colors use Godot 0-1 range.

extends Node3D

class_name DungeonGen

# ─── Signals ────────────────────────────────────────────────────────────────────
signal dungeon_entered(dungeon_id: int, theme: int)
signal dungeon_cleared(dungeon_id: int)
signal dungeon_boss_defeated(dungeon_id: int)

# ─── State ─────────────────────────────────────────────────────────────────────
# Each dungeon is represented by a Dictionary:
#   {id, theme, position, rooms: [{center, half_extents, type}], cleared, active}
var _dungeons: Array[Dictionary] = []
var _active_dungeon_id: int = -1
var _active_root: Node3D = null  # Parent node for the live dungeon geometry
var _rng := RandomNumberGenerator.new()

# ─── Public API ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("dungeon_generator")
	# Build dungeons after the world generator finishes. We defer so the
	# scene tree is fully ready before we start adding nodes.
	call_deferred("_generate_all_dungeons")

func get_dungeons() -> Array[Dictionary]:
	return _dungeons

func get_active_dungeon_id() -> int:
	return _active_dungeon_id

func is_in_dungeon() -> bool:
	return _active_dungeon_id >= 0

# ─── World-Seeded Generation ───────────────────────────────────────────────────

func _generate_all_dungeons() -> void:
	# Seed RNG from the world seed for deterministic dungeons.
	var seed_val: int = GameManager.world_seed if GameManager else randi()
	_rng.seed = seed_val
	var count: int = GameConstants.DUNGEON_COUNT
	var min_dist: float = GameConstants.DUNGEON_MIN_DISTANCE_FROM_SPAWN
	var max_dist: float = GameConstants.DUNGEON_MAX_DISTANCE_FROM_SPAWN
	for i in count:
		var angle: float = _rng.randf() * TAU
		var dist: float = _rng.randf_range(min_dist, max_dist)
		var pos := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var theme: int = _rng.randi() % GameConstants.DungeonTheme.size()
		var rooms := _generate_room_layout(i, theme)
		var dungeon := {
			"id": i,
			"theme": theme,
			"position": pos,
			"rooms": rooms,
			"cleared": false,
			"boss_room_index": rooms.size() - 1,
		}
		_dungeons.append(dungeon)
		_build_entrance(dungeon)
	print("[DungeonGenerator] Spawned %d dungeon entrances" % _dungeons.size())

func _generate_room_layout(dungeon_id: int, _theme: int) -> Array[Dictionary]:
	# A simple linear layout: rooms connected by short corridors along the
	# X axis. The boss room is at the far end.
	var room_count: int = _rng.randi_range(
		GameConstants.DUNGEON_MIN_ROOMS,
		GameConstants.DUNGEON_MAX_ROOMS
	)
	var rooms: Array[Dictionary] = []
	var cursor_x: float = 0.0
	for i in room_count:
		var half_extent := _rng.randf_range(
			GameConstants.DUNGEON_ROOM_MIN_SIZE,
			GameConstants.DUNGEON_ROOM_MAX_SIZE
		)
		var room := {
			"center": Vector3(cursor_x + half_extent, 0.0, 0.0),
			"half_extents": Vector3(half_extent, GameConstants.DUNGEON_WALL_HEIGHT * 0.5, half_extent),
			"is_boss_room": (i == room_count - 1),
			"enemies_spawned": false,
		}
		rooms.append(room)
		# Advance cursor by room width + corridor length (corridor = 1 room diameter).
		cursor_x += half_extent * 2.0 + GameConstants.DUNGEON_CORRIDOR_WIDTH * 2.0
	return rooms

# ─── Entrance Portal ────────────────────────────────────────────────────────────

func _build_entrance(dungeon: Dictionary) -> void:
	# Surface entrance — a glowing ring + pillar structure marking the dungeon.
	var root := Node3D.new()
	root.name = "DungeonEntrance_%d" % dungeon.id
	root.position = dungeon.position
	add_child(root)
	# Mark with meta so interaction system can find it.
	root.set_meta("dungeon_id", dungeon.id)
	root.set_meta("dungeon_theme", dungeon.theme)
	root.add_to_group("dungeon_entrance")
	# Glowing ring on the ground.
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 2.0
	ring_mesh.bottom_radius = 2.0
	ring_mesh.height = 0.2
	ring.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = GameConstants.DUNGEON_ENTRANCE_GLOW_COLOR
	ring_mat.emission_enabled = true
	ring_mat.emission = GameConstants.DUNGEON_ENTRANCE_GLOW_COLOR
	ring_mat.emission_energy_multiplier = 1.5
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.no_depth_test = true
	ring.material_override = ring_mat
	ring.position = Vector3(0, 0.1, 0)
	root.add_child(ring)
	# Vertical pillar of light.
	var beam := MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.5
	beam_mesh.bottom_radius = 0.5
	beam_mesh.height = GameConstants.DUNGEON_ENTRANCE_HEIGHT
	beam.mesh = beam_mesh
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = GameConstants.DUNGEON_THEME_EMISSIVE[dungeon.theme]
	beam_mat.emission_enabled = true
	beam_mat.emission = GameConstants.DUNGEON_THEME_EMISSIVE[dungeon.theme]
	beam_mat.emission_energy_multiplier = 1.2
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.no_depth_test = true
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_color.a = 0.5
	beam.material_override = beam_mat
	beam.position = Vector3(0, GameConstants.DUNGEON_ENTRANCE_HEIGHT * 0.5, 0)
	root.add_child(beam)
	# Pulsing light.
	var light := OmniLight3D.new()
	light.light_color = GameConstants.DUNGEON_THEME_EMISSIVE[dungeon.theme]
	light.light_energy = 2.5
	light.omni_range = 12.0
	light.position = Vector3(0, 1.5, 0)
	root.add_child(light)
	# Interaction area.
	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = GameConstants.DUNGEON_ENTRANCE_RADIUS
	shape.height = 4.0
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(_on_entrance_body_entered.bind(dungeon.id))
	root.add_child(area)
	# Floating label.
	var label := Label3D.new()
	label.text = "▼ %s" % GameConstants.DUNGEON_THEME_NAMES[dungeon.theme]
	label.font_size = 28
	label.position = Vector3(0, 4.5, 0)
	label.modulate = GameConstants.DUNGEON_THEME_EMISSIVE[dungeon.theme]
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	root.add_child(label)

func _on_entrance_body_entered(body: Node, dungeon_id: int) -> void:
	if not body.is_in_group("player"):
		return
	enter_dungeon(dungeon_id)

# ─── Enter / Exit Dungeon ──────────────────────────────────────────────────────

func enter_dungeon(dungeon_id: int) -> void:
	if dungeon_id < 0 or dungeon_id >= _dungeons.size():
		return
	if _active_dungeon_id >= 0:
		return  # Already in a dungeon
	var dungeon: Dictionary = _dungeons[dungeon_id]
	if dungeon.cleared:
		GameManager.add_message("This dungeon has already been cleared.")
		return
	_active_dungeon_id = dungeon_id
	_active_root = Node3D.new()
	_active_root.name = "DungeonInterior_%d" % dungeon_id
	# Place interior below the surface at the dungeon's XZ position.
	_active_root.position = Vector3(dungeon.position.x, GameConstants.DUNGEON_FLOOR_Y, dungeon.position.z)
	get_tree().current_scene.add_child(_active_root)
	_build_interior(dungeon)
	dungeon_entered.emit(dungeon_id, dungeon.theme)
	GameManager.add_message("▼ Descending into %s..." % GameConstants.DUNGEON_THEME_NAMES[dungeon.theme])
	AudioManager.play_sfx(AudioManager.SFX_FAST_TRAVEL)
	# Move player into the first room.
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var first_room: Dictionary = dungeon.rooms[0]
		# Interior is offset to (dungeon_pos.x, FLOOR_Y, dungeon_pos.z).
		# Room centers are relative to interior root.
		player.global_position = _active_root.global_position + first_room.center + Vector3(0, 1.5, 0)

func exit_dungeon() -> void:
	if _active_dungeon_id < 0:
		return
	var dungeon: Dictionary = _dungeons[_active_dungeon_id]
	# Move player back to the surface entrance.
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		player.global_position = dungeon.position + Vector3(0, 1.5, 0)
	if _active_root and is_instance_valid(_active_root):
		_active_root.queue_free()
	_active_root = null
	_active_dungeon_id = -1
	GameManager.add_message("▲ Returning to the surface...")

# ─── Interior Construction ─────────────────────────────────────────────────────

func _build_interior(dungeon: Dictionary) -> void:
	var theme: int = dungeon.theme
	var floor_color := GameConstants.DUNGEON_THEME_COLORS[theme]
	var wall_color := floor_color * 0.7
	var emissive := GameConstants.DUNGEON_THEME_EMISSIVE[theme]
	# Build each room.
	for i in dungeon.rooms.size():
		var room: Dictionary = dungeon.rooms[i]
		_build_room(room, floor_color, wall_color, emissive, i == dungeon.rooms.size() - 1)
	# Spawn enemies for each room (deferred so the geometry exists first).
	for i in dungeon.rooms.size():
		var room: Dictionary = dungeon.rooms[i]
		if not room.enemies_spawned:
			_spawn_room_enemies(room, theme, dungeon.id)
			room.enemies_spawned = true
	# Spawn the boss in the last room.
	var boss_room: Dictionary = dungeon.rooms[dungeon.rooms.size() - 1]
	_spawn_dungeon_boss(boss_room, theme, dungeon.id)
	# Reward chest at the very end.
	_spawn_reward_chest(boss_room, dungeon.id)

func _build_room(room: Dictionary, floor_color: Color, wall_color: Color, emissive: Color, is_boss_room: bool) -> void:
	var he: Vector3 = room.half_extents
	var center: Vector3 = room.center
	# Floor.
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(he.x * 2.0, he.z * 2.0)
	floor_mesh.mesh = plane
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = floor_color
	fmat.emission_enabled = is_boss_room
	fmat.emission = emissive * 0.3
	floor_mesh.material_override = fmat
	floor_mesh.position = center + Vector3(0, 0, 0)
	_active_root.add_child(floor_mesh)
	# Ceiling.
	var ceil_mesh := MeshInstance3D.new()
	var ceil_plane := PlaneMesh.new()
	ceil_plane.size = Vector2(he.x * 2.0, he.z * 2.0)
	ceil_mesh.mesh = ceil_plane
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = wall_color * 0.5
	ceil_mesh.material_override = cmat
	ceil_mesh.position = center + Vector3(0, GameConstants.DUNGEON_WALL_HEIGHT, 0)
	ceil_mesh.rotation_degrees.x = 180.0
	_active_root.add_child(ceil_mesh)
	# Walls (4 sides).
	_build_wall(center + Vector3(he.x, GameConstants.DUNGEON_WALL_HEIGHT * 0.5, 0), Vector3(GameConstants.DUNGEON_WALL_THICKNESS, GameConstants.DUNGEON_WALL_HEIGHT, he.z), wall_color)
	_build_wall(center + Vector3(-he.x, GameConstants.DUNGEON_WALL_HEIGHT * 0.5, 0), Vector3(GameConstants.DUNGEON_WALL_THICKNESS, GameConstants.DUNGEON_WALL_HEIGHT, he.z), wall_color)
	_build_wall(center + Vector3(0, GameConstants.DUNGEON_WALL_HEIGHT * 0.5, he.z), Vector3(he.x, GameConstants.DUNGEON_WALL_HEIGHT, GameConstants.DUNGEON_WALL_THICKNESS), wall_color)
	_build_wall(center + Vector3(0, GameConstants.DUNGEON_WALL_HEIGHT * 0.5, -he.z), Vector3(he.x, GameConstants.DUNGEON_WALL_HEIGHT, GameConstants.DUNGEON_WALL_THICKNESS), wall_color)
	# Boss room gets a glow pad in the center.
	if is_boss_room:
		var pad := MeshInstance3D.new()
		var pad_mesh := CylinderMesh.new()
		pad_mesh.top_radius = 2.0
		pad_mesh.bottom_radius = 2.0
		pad_mesh.height = 0.1
		pad.mesh = pad_mesh
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = emissive
		pmat.emission_enabled = true
		pmat.emission = emissive
		pmat.emission_energy_multiplier = 1.5
		pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pad.material_override = pmat
		pad.position = center + Vector3(0, 0.05, 0)
		_active_root.add_child(pad)
		var pad_light := OmniLight3D.new()
		pad_light.light_color = emissive
		pad_light.light_energy = 3.0
		pad_light.omni_range = 15.0
		pad_light.position = center + Vector3(0, 2.0, 0)
		_active_root.add_child(pad_light)

func _build_wall(pos: Vector3, extents: Vector3, color: Color) -> void:
	var wall := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = extents
	col.shape = shape
	wall.add_child(col)
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = extents
	mesh_inst.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	wall.add_child(mesh_inst)
	wall.position = pos
	_active_root.add_child(wall)

# ─── Enemy Spawning ────────────────────────────────────────────────────────────

func _spawn_room_enemies(room: Dictionary, theme: int, _dungeon_id: int) -> void:
	# Pick theme-appropriate enemy types.
	var pool: Array[int] = _theme_enemy_pool(theme)
	var count: int = _rng.randi_range(
		GameConstants.DUNGEON_MIN_ENEMIES_PER_ROOM,
		GameConstants.DUNGEON_MAX_ENEMIES_PER_ROOM
	)
	if room.is_boss_room:
		count = 0  # Boss room only has the boss
	for i in count:
		var enemy_type: int = pool[_rng.randi() % pool.size()]
		var offset := Vector3(
			_rng.randf_range(-room.half_extents.x * 0.6, room.half_extents.x * 0.6),
			1.0,
			_rng.randf_range(-room.half_extents.z * 0.6, room.half_extents.z * 0.6)
		)
		_spawn_enemy_at(enemy_type, _active_root.global_position + room.center + offset)

func _theme_enemy_pool(theme: int) -> Array[int]:
	# Reuse existing enemy types — theme affects which pool is drawn from.
	match theme:
		GameConstants.DungeonTheme.STONE:
			return [GameConstants.EnemyType.BLOB, GameConstants.EnemyType.SERPENT, GameConstants.EnemyType.ECHO_KNIGHT]
		GameConstants.DungeonTheme.CRYSTAL:
			return [GameConstants.EnemyType.CRYSTAL_GUARDIAN, GameConstants.EnemyType.CRYSTAL_WRAITH]
		GameConstants.DungeonTheme.VOLCANIC:
			return [GameConstants.EnemyType.BOMBER, GameConstants.EnemyType.SWARM_QUEEN]
		GameConstants.DungeonTheme.VOID:
			return [GameConstants.EnemyType.WISP, GameConstants.EnemyType.PLASMA_STALKER, GameConstants.EnemyType.VOID_LEVIATHAN]
		GameConstants.DungeonTheme.DIGITAL:
			return [GameConstants.EnemyType.MIRROR_MIMIC, GameConstants.EnemyType.TIME_WARDEN]
		_:
			return [GameConstants.EnemyType.BLOB]

func _spawn_enemy_at(enemy_type: int, pos: Vector3) -> void:
	var scene_path := _enemy_scene_path(enemy_type)
	var scene: PackedScene = load(scene_path)
	if not scene:
		return
	var enemy := scene.instantiate()
	enemy.position = pos
	get_tree().current_scene.add_child(enemy)
	if "enemies" in GameManager:
		GameManager.enemies.append(enemy)
	# Scale enemy up for dungeon danger.
	if enemy is EnemyBase:
		enemy.max_hp = int(enemy.max_hp * 1.4)
		enemy.hp = enemy.max_hp
		enemy.damage = int(enemy.damage * 1.3)

func _enemy_scene_path(enemy_type: int) -> String:
	match enemy_type:
		GameConstants.EnemyType.BLOB:
			return "res://scenes/entities/enemy_blob.tscn"
		GameConstants.EnemyType.SERPENT:
			return "res://scenes/entities/enemy_serpent.tscn"
		GameConstants.EnemyType.WISP:
			return "res://scenes/entities/enemy_wisp.tscn"
		GameConstants.EnemyType.BOMBER:
			return "res://scenes/entities/enemy_bomber.tscn"
		GameConstants.EnemyType.CRYSTAL_GUARDIAN:
			return "res://scenes/entities/enemy_crystal_guardian.tscn"
		GameConstants.EnemyType.CRYSTAL_WRAITH:
			return "res://scenes/entities/enemy_crystal_wraith.tscn"
		GameConstants.EnemyType.ECHO_KNIGHT:
			return "res://scenes/entities/enemy_echo_knight.tscn"
		GameConstants.EnemyType.SWARM_QUEEN:
			return "res://scenes/entities/enemy_swarm_queen.tscn"
		GameConstants.EnemyType.PLASMA_STALKER:
			return "res://scenes/entities/enemy_plasma_stalker.tscn"
		GameConstants.EnemyType.MIRROR_MIMIC:
			return "res://scenes/entities/enemy_mirror_mimic.tscn"
		GameConstants.EnemyType.TIME_WARDEN:
			return "res://scenes/entities/enemy_time_warden.tscn"
		GameConstants.EnemyType.VOID_LEVIATHAN:
			return "res://scenes/entities/enemy_void_leviathan.tscn"
		_:
			return "res://scenes/entities/enemy_blob.tscn"

# ─── Dungeon Boss ───────────────────────────────────────────────────────────────

func _spawn_dungeon_boss(room: Dictionary, theme: int, dungeon_id: int) -> void:
	# Pick a boss type appropriate for the theme — prefer real bosses.
	var boss_type: int
	match theme:
		GameConstants.DungeonTheme.VOID:
			boss_type = GameConstants.EnemyType.VOID_LEVIATHAN
		GameConstants.DungeonTheme.VOLCANIC:
			boss_type = GameConstants.EnemyType.DRAKE
		GameConstants.DungeonTheme.CRYSTAL:
			boss_type = GameConstants.EnemyType.ANCIENT_SENTINEL
		GameConstants.DungeonTheme.DIGITAL:
			boss_type = GameConstants.EnemyType.GRAVITY_ELEMENTAL
		_:
			boss_type = GameConstants.EnemyType.DRAKE
	var scene_path := _enemy_scene_path(boss_type)
	var scene: PackedScene = load(scene_path)
	if not scene:
		return
	var boss := scene.instantiate()
	boss.position = _active_root.global_position + room.center + Vector3(0, 1.5, 0)
	get_tree().current_scene.add_child(boss)
	if "enemies" in GameManager:
		GameManager.enemies.append(boss)
	# Scale boss HP for dungeon (smaller than arena bosses but still tough).
	if boss is EnemyBase:
		var scale_factor: float = 0.7
		boss.max_hp = int(boss.max_hp * scale_factor)
		boss.hp = boss.max_hp
		# ── Don't set is_arena_boss for bosses that emit boss_defeated in their
		#    own _die() — doing so would cause double-fire of boss_defeated.
		#    Drake, Ancient Sentinel, and Void Leviathan handle boss_defeated
		#    themselves. Other boss types rely on is_arena_boss. ──
		if boss_type != GameConstants.EnemyType.DRAKE and \
		   boss_type != GameConstants.EnemyType.VOID_LEVIATHAN and \
		   boss_type != GameConstants.EnemyType.ANCIENT_SENTINEL:
			boss.is_arena_boss = true
		boss.set_meta("dungeon_id", dungeon_id)
	# Emit boss_spawned so HUD tracks it.
	GameManager.boss_spawned.emit(boss)
	# Connect to boss death to clear dungeon.
	if boss is EnemyBase:
		boss.connect("enemy_died", _on_dungeon_boss_died.bind(dungeon_id))

func _on_dungeon_boss_died(enemy: Node, _dungeon_id: int) -> void:
	# The bind() arg comes AFTER the signal's own args. enemy_died emits the
	# enemy as the first arg, so dungeon_id arrives as the second.
	var dungeon_id: int = _dungeon_id
	dungeon_boss_defeated.emit(dungeon_id)
	GameManager.add_message("✦ Dungeon boss defeated! Claim your reward.")
	AudioManager.play_sfx(AudioManager.SFX_BOSS_DEFEATED)

# ─── Reward Chest ──────────────────────────────────────────────────────────────

func _spawn_reward_chest(room: Dictionary, dungeon_id: int) -> void:
	# Use the existing treasure_chest scene for consistency.
	var chest_scene: PackedScene = load("res://scenes/entities/treasure_chest.tscn")
	if not chest_scene:
		return
	var chest := chest_scene.instantiate()
	chest.position = _active_root.global_position + room.center + Vector3(0, 0.5, 4.0)
	get_tree().current_scene.add_child(chest)
	# Mark as dungeon reward so opening it clears the dungeon.
	chest.set_meta("dungeon_reward", dungeon_id)
	if chest.has_signal("chest_opened"):
		chest.connect("chest_opened", _on_reward_chest_opened.bind(dungeon_id))

func _on_reward_chest_opened(_chest: Node, _trapped: bool, dungeon_id: int) -> void:
	if dungeon_id < 0 or dungeon_id >= _dungeons.size():
		return
	_dungeons[dungeon_id].cleared = true
	# XP + score reward.
	GameManager.gain_xp(GameConstants.DUNGEON_REWARD_XP)
	GameManager.player_score += GameConstants.DUNGEON_REWARD_SCORE
	dungeon_cleared.emit(dungeon_id)
	GameManager.add_message("🏆 Dungeon cleared! +%d XP, +%d score" % [GameConstants.DUNGEON_REWARD_XP, GameConstants.DUNGEON_REWARD_SCORE])

# ─── Per-Frame ──────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	# Allow exiting dungeon via Esc key when inside.
	if _active_dungeon_id >= 0 and Input.is_action_just_pressed("ui_cancel"):
		exit_dungeon()