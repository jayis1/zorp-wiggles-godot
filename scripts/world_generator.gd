## Zorp Wiggles — World Generator
## Procedurally generates the 3D open world with biomes, terrain, and decorations.
## Ported from the terrain/decoration building logic in Ursina game.py.

extends Node3D

const TILE_SIZE: float = GameConstants.TILE_SCALE
const GRID_SIZE: int = GameConstants.WORLD_SIZE
const HALF_WORLD: float = GameConstants.WORLD_SIZE * GameConstants.TILE_SCALE / 2.0

# ─── Biome Colors (0-1 normalized for Godot — converted from Ursina color.rgb 0-255) ─
const BIOME_COLORS: Dictionary = {
	GameConstants.Biome.GRASS: Color(10.0 / 255.0, 180.0 / 255.0, 80.0 / 255.0),
	GameConstants.Biome.DESERT: Color(210.0 / 255.0, 170.0 / 255.0, 80.0 / 255.0),
	GameConstants.Biome.WATER: Color(20.0 / 255.0, 60.0 / 255.0, 180.0 / 255.0),
	GameConstants.Biome.LAVA: Color(255.0 / 255.0, 80.0 / 255.0, 20.0 / 255.0),
	GameConstants.Biome.FOREST: Color(0.0, 60.0 / 255.0, 30.0 / 255.0),
	GameConstants.Biome.CRYSTAL: Color(0.0, 240.0 / 255.0, 255.0 / 255.0),
	GameConstants.Biome.SNOW: Color(200.0 / 255.0, 210.0 / 255.0, 240.0 / 255.0),
	GameConstants.Biome.SWAMP: Color(50.0 / 255.0, 80.0 / 255.0, 30.0 / 255.0),
	GameConstants.Biome.ALIEN: Color(0.0, 230.0 / 255.0, 70.0 / 255.0),
	GameConstants.Biome.MUSHROOM: Color(200.0 / 255.0, 40.0 / 255.0, 120.0 / 255.0),
	GameConstants.Biome.FLOATING_ISLANDS: Color(160.0 / 255.0, 120.0 / 255.0, 220.0 / 255.0),
	GameConstants.Biome.TOXIC_BOG: Color(80.0 / 255.0, 120.0 / 255.0, 20.0 / 255.0),
	# ── Phase 22: New biome colors ──
	GameConstants.Biome.DEEP_OCEAN: Color(10.0 / 255.0, 60.0 / 255.0, 130.0 / 255.0),
	GameConstants.Biome.VOLCANO_CORE: Color(120.0 / 255.0, 30.0 / 255.0, 10.0 / 255.0),
	GameConstants.Biome.SKY_CITADEL: Color(200.0 / 255.0, 220.0 / 255.0, 240.0 / 255.0),
	GameConstants.Biome.DIGITAL_GRID: Color(20.0 / 255.0, 40.0 / 255.0, 60.0 / 255.0),
	GameConstants.Biome.CRYSTAL_CAVERNS: Color(60.0 / 255.0, 130.0 / 255.0, 180.0 / 255.0),
	GameConstants.Biome.ANCIENT_RUINS: Color(140.0 / 255.0, 120.0 / 255.0, 80.0 / 255.0),
	GameConstants.Biome.UNDERGROUND: Color(40.0 / 255.0, 35.0 / 255.0, 30.0 / 255.0),
}

# ─── State ────────────────────────────────────────────────────────────────────
var terrain_mesh: MeshInstance3D = null
var grid: Array[int] = []  # Flattened 2D array of biome types
var decorations: Array[Node3D] = []
var ground_collision: StaticBody3D = null

func _ready() -> void:
	_generate_world()

func _generate_world() -> void:
	print("[WorldGenerator] Generating %dx%d world..." % [GRID_SIZE, GRID_SIZE])
	
	# Generate biome grid using noise
	_generate_biome_grid()
	
	# Build terrain mesh
	_build_terrain_mesh()
	
	# Build ground collision
	_build_ground_collision()
	
	# Spawn decorations
	_spawn_decorations()
	
	# Spawn initial enemies
	_spawn_initial_enemies()
	
	# Spawn collectibles
	_spawn_collectibles()
	
	# Spawn special structures (monoliths, traders, portals)
	_spawn_structures()
	
	# ── Phase 10: Build navigation mesh AFTER all static colliders exist ──
	# This allows enemies to use NavigationAgent3D for pathfinding around
	# obstacles (decorations, destructibles, monoliths, portals, etc.).
	call_deferred("_build_nav_mesh")
	
	print("[WorldGenerator] World generation complete!")

# ── Phase 10: Build the navigation mesh after the world is fully populated ──
# Uses call_deferred so all StaticBody3D colliders are in the scene tree first.
func _build_nav_mesh() -> void:
	if NavigationManager:
		NavigationManager.build_nav_region(self)

func _generate_biome_grid() -> void:
	# Use noise-based biome assignment matching the original Ursina logic.
	grid.resize(GRID_SIZE * GRID_SIZE)
	
	# Simplex-like noise for biome distribution
	# Using Godot's FastNoiseLite for terrain generation
	var noise := FastNoiseLite.new()
	noise.seed = GameManager.world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	
	var moisture_noise := FastNoiseLite.new()
	moisture_noise.seed = GameManager.world_seed + 100
	moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moisture_noise.frequency = 0.03
	
	var temperature_noise := FastNoiseLite.new()
	temperature_noise.seed = GameManager.world_seed + 200
	temperature_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	temperature_noise.frequency = 0.025
	
	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var idx := x * GRID_SIZE + z
			var elevation := noise.get_noise_2d(x, z)
			var moisture := moisture_noise.get_noise_2d(x, z)
			var temperature := temperature_noise.get_noise_2d(x, z)
			
			# Biome assignment logic (simplified from original)
			var biome: int = _classify_biome(elevation, moisture, temperature)
			grid[idx] = biome

func _classify_biome(elevation: float, moisture: float, temperature: float) -> int:
	# Classify a tile into a biome based on noise values.
	# Water/low elevation
	if elevation < -0.3:
		if temperature > 0.3:
			return GameConstants.Biome.LAVA
		# Phase 22: Very deep water → Deep Ocean; regular low → Water
		if elevation < -0.45:
			return GameConstants.Biome.DEEP_OCEAN
		return GameConstants.Biome.WATER

	# Extremely deep (caverns / underground)
	if elevation < -0.2 and moisture > 0.2:
		return GameConstants.Biome.UNDERGROUND

	# Very high elevation → floating islands or sky citadel
	if elevation > 0.5:
		# Phase 22: Highest peaks → Sky Citadel (above the floating islands)
		if elevation > 0.65 and temperature < 0.0:
			return GameConstants.Biome.SKY_CITADEL
		return GameConstants.Biome.FLOATING_ISLANDS

	# Hot + very dry + high elevation → Volcano Core (Phase 22)
	if elevation > 0.25 and temperature > 0.45 and moisture < -0.1:
		return GameConstants.Biome.VOLCANO_CORE

	# Temperature-based
	if temperature < -0.3:
		return GameConstants.Biome.SNOW
	if temperature > 0.4:
		if moisture < -0.2:
			return GameConstants.Biome.DESERT
		if moisture > 0.3:
			return GameConstants.Biome.SWAMP
		return GameConstants.Biome.GRASS

	# Moisture-based
	if moisture > 0.4:
		return GameConstants.Biome.FOREST
	if moisture < -0.4:
		# Phase 22: Very low moisture + moderate temp → Crystal Caverns
		if temperature < 0.1 and elevation < 0.1:
			return GameConstants.Biome.CRYSTAL_CAVERNS
		return GameConstants.Biome.CRYSTAL

	# Random rare biomes
	var roll := randf()
	if roll < 0.03:
		return GameConstants.Biome.ALIEN
	if roll < 0.06:
		return GameConstants.Biome.MUSHROOM
	if roll < 0.09:
		return GameConstants.Biome.TOXIC_BOG
	# Phase 22: Very rare new biomes
	if roll < 0.105:
		return GameConstants.Biome.DIGITAL_GRID
	if roll < 0.115:
		return GameConstants.Biome.ANCIENT_RUINS

	return GameConstants.Biome.GRASS

func _build_terrain_mesh() -> void:
	# Build a single merged terrain mesh with vertex colors for biomes.
	# Using ArrayMesh for efficient terrain rendering
	# Each tile is a quad with the biome color as vertex color
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var idx := x * GRID_SIZE + z
			var biome: int = grid[idx]
			var tile_color: Color = BIOME_COLORS.get(biome, Color.GREEN)
			
			# World position of this tile's center
			var wx: float = (x - GRID_SIZE / 2.0) * TILE_SIZE
			var wz: float = (z - GRID_SIZE / 2.0) * TILE_SIZE
			var half_tile: float = TILE_SIZE / 2.0
			
			# Height variation based on biome
			var height: float = _get_tile_height(biome, x, z)
			
			# Quad vertices (two triangles)
			var v0 := Vector3(wx - half_tile, height, wz - half_tile)
			var v1 := Vector3(wx + half_tile, height, wz - half_tile)
			var v2 := Vector3(wx + half_tile, height, wz + half_tile)
			var v3 := Vector3(wx - half_tile, height, wz + half_tile)
			
			# Add vertices with biome color
			surface_tool.set_color(tile_color)
			surface_tool.add_vertex(v0)
			surface_tool.add_vertex(v1)
			surface_tool.add_vertex(v2)
			
			surface_tool.add_vertex(v0)
			surface_tool.add_vertex(v2)
			surface_tool.add_vertex(v3)
	
	surface_tool.generate_normals()
	var mesh := surface_tool.commit()
	
	terrain_mesh = MeshInstance3D.new()
	terrain_mesh.mesh = mesh
	terrain_mesh.material_override = _create_terrain_material()
	add_child(terrain_mesh)

func _create_terrain_material() -> Material:
	# Create unlit material for terrain (matching Ursina's unlit_with_fog_shader).
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	return mat

func _get_tile_height(biome: int, x: int, z: int) -> float:
	# Return height offset for a tile based on biome type.
	match biome:
		GameConstants.Biome.WATER:
			return -0.3
		GameConstants.Biome.LAVA:
			return -0.2
		GameConstants.Biome.FLOATING_ISLANDS:
			return 2.0 + randf() * 3.0
		GameConstants.Biome.SNOW:
			return 0.1 + randf() * 0.3
		# ── Phase 22: New biome heights ──
		GameConstants.Biome.DEEP_OCEAN:
			return GameConstants.DEEP_OCEAN_DEPTH
		GameConstants.Biome.VOLCANO_CORE:
			return GameConstants.VOLCANO_CORE_HEIGHT + randf_range(-0.2, 0.4)
		GameConstants.Biome.SKY_CITADEL:
			return GameConstants.SKY_CITADEL_HEIGHT + randf_range(-0.5, 0.5)
		GameConstants.Biome.DIGITAL_GRID:
			return 0.0
		GameConstants.Biome.CRYSTAL_CAVERNS:
			return GameConstants.CRYSTAL_CAVERNS_HEIGHT
		GameConstants.Biome.ANCIENT_RUINS:
			return GameConstants.ANCIENT_RUINS_HEIGHT + randf_range(-0.1, 0.15)
		GameConstants.Biome.UNDERGROUND:
			return GameConstants.UNDERGROUND_HEIGHT
		_:
			return 0.0

func _build_ground_collision() -> void:
	# Create a single flat collision plane for the entire world.
	ground_collision = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GRID_SIZE * TILE_SIZE, 0.5, GRID_SIZE * TILE_SIZE)
	shape.shape = box
	shape.position = Vector3(0, -0.25, 0)
	ground_collision.add_child(shape)
	add_child(ground_collision)

func _spawn_decorations() -> void:
	# Spawn biome-appropriate decorations (trees, crystals, mushrooms, etc.).
	var deco_node := DecorationSystem.new()
	deco_node.name = "Decorations"
	deco_node.spawn_all_decorations(grid, GRID_SIZE, TILE_SIZE)
	add_child(deco_node)
	print("[WorldGenerator] Spawned %d decorations" % deco_node.get_decoration_count())

func _spawn_initial_enemies() -> void:
	# Spawn initial wave of enemies across the world.
	var spawn_count := 15 + GameManager.player_level * 2
	for i in range(spawn_count):
		var pos := _random_world_position()
		var enemy_type := _random_enemy_type()
		_spawn_enemy_at(enemy_type, pos)

func _spawn_collectibles() -> void:
	# Spawn collectible items across the world.
	var spawn_count := 25
	for i in range(spawn_count):
		var pos := _random_world_position()
		var type := _random_collectible_type()
		_spawn_collectible_at(type, pos)

func _spawn_structures() -> void:
	# Spawn monoliths, traders, portals, healing shrines, and destructibles.
	_spawn_portal_pairs()
	_spawn_initial_traders()
	_spawn_monoliths()
	_spawn_healing_shrines()
	_spawn_destructibles()  # Phase 8: breakable props
	# ── Phase 26: World Life — lore stones, treasure chests, wildlife ──
	_spawn_lore_stones()
	_spawn_treasure_chests()
	_spawn_wildlife()
	# ── Phase 26: World Life — dialogue NPCs, environmental hazards, interactive objects ──
	_spawn_dialogue_npcs()
	_spawn_environmental_hazards()
	_spawn_interactive_objects()

# ── Phase 8: Spawn destructible crates & crystals across biomes ────────────────
func _spawn_destructibles() -> void:
	var destructible_scene := preload("res://scenes/entities/destructible.tscn")
	var half_grid: float = GRID_SIZE / 2.0
	var count: int = 0
	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var idx: int = x * GRID_SIZE + z
			var biome: int = grid[idx]
			# Skip water/lava/floating islands — destructibles need solid ground
			if not _is_biome_walkable(biome) or biome == GameConstants.Biome.FLOATING_ISLANDS:
				continue
			if randf() < GameConstants.DESTRUCTIBLE_SPAWN_CHANCE:
				var wx: float = (x - half_grid) * TILE_SIZE + randf_range(-1.0, 1.0)
				var wz: float = (z - half_grid) * TILE_SIZE + randf_range(-1.0, 1.0)
				var prop := destructible_scene.instantiate()
				# Set properties BEFORE add_child so _ready() sees the correct values.
				# _ready() uses fragment_color to create the material, so it must be
				# set before the node enters the scene tree.
				prop.global_position = Vector3(wx, 0.0, wz)
				# Crystal biome → crystal destructibles (more XP), others → crates
				if biome == GameConstants.Biome.CRYSTAL:
					prop.is_crystal = true
					prop.fragment_color = GameConstants.DESTRUCTIBLE_CRYSTAL_COLOR
					prop.reward_xp = GameConstants.DESTRUCTIBLE_REWARD_XP * 2
					prop.prop_name = "Crystal Cluster"
				else:
					prop.is_crystal = false
					prop.fragment_color = GameConstants.DESTRUCTIBLE_CRATE_COLOR
					prop.prop_name = "Crate"
				add_child(prop)
				count += 1
	print("[WorldGenerator] Spawned %d destructibles" % count)

func _spawn_portal_pairs() -> void:
	# Create linked portal pairs at walkable locations around the world.
	var spawn_center: float = GRID_SIZE / 2.0 * TILE_SIZE
	var portal_scene := preload("res://scenes/entities/portal.tscn")

	for i in range(GameConstants.PORTAL_COUNT):
		for _attempt in range(50):
			var angle1: float = randf() * TAU
			var dist1: float = randf_range(30, GRID_SIZE * TILE_SIZE * 0.4)
			var x1: float = spawn_center + cos(angle1) * dist1 - HALF_WORLD
			var z1: float = spawn_center + sin(angle1) * dist1 - HALF_WORLD
			x1 = clamp(x1, -HALF_WORLD + 10, HALF_WORLD - 10)
			z1 = clamp(z1, -HALF_WORLD + 10, HALF_WORLD - 10)

			# Partner portal on the opposite side
			var angle2: float = angle1 + PI + randf_range(-0.5, 0.5)
			var dist2: float = randf_range(30, GRID_SIZE * TILE_SIZE * 0.4)
			var x2: float = spawn_center + cos(angle2) * dist2 - HALF_WORLD
			var z2: float = spawn_center + sin(angle2) * dist2 - HALF_WORLD
			x2 = clamp(x2, -HALF_WORLD + 10, HALF_WORLD - 10)
			z2 = clamp(z2, -HALF_WORLD + 10, HALF_WORLD - 10)

			# Check both positions are walkable (not water/lava)
			var biome1: int = get_biome_at(Vector3(x1, 0, z1))
			var biome2: int = get_biome_at(Vector3(x2, 0, z2))
			if _is_biome_walkable(biome1) and _is_biome_walkable(biome2):
				var d1: float = Vector2(x1, z1).distance_to(Vector2(0, 0))
				var d2: float = Vector2(x2, z2).distance_to(Vector2(0, 0))
				if d1 > 30 and d2 > 30:
					# Create portal A
					var portal_a := portal_scene.instantiate()
					add_child(portal_a)
					portal_a.global_position = Vector3(x1, 0, z1)
					portal_a.partner_position = Vector3(x2, 0, z2)
					portal_a.portal_id = i
					# Create portal B
					var portal_b := portal_scene.instantiate()
					add_child(portal_b)
					portal_b.global_position = Vector3(x2, 0, z2)
					portal_b.partner_position = Vector3(x1, 0, z1)
					portal_b.portal_id = i
					break

func _spawn_initial_traders() -> void:
	# Spawn initial wandering traders at walkable locations.
	var trader_scene := preload("res://scenes/entities/trader.tscn")
	for _i in range(GameConstants.TRADER_INITIAL_COUNT):
		for _attempt in range(50):
			var angle: float = randf() * TAU
			var dist: float = randf_range(40, 120)
			var tx: float = cos(angle) * dist
			var tz: float = sin(angle) * dist
			tx = clamp(tx, -HALF_WORLD + 10, HALF_WORLD - 10)
			tz = clamp(tz, -HALF_WORLD + 10, HALF_WORLD - 10)
			var biome: int = get_biome_at(Vector3(tx, 0, tz))
			if _is_biome_walkable(biome):
				var trader := trader_scene.instantiate()
				# Set trader_name BEFORE add_child so _ready() sees the correct name.
				trader.trader_name = GameConstants.TRADER_NAMES[randi() % GameConstants.TRADER_NAMES.size()]
				add_child(trader)
				trader.global_position = Vector3(tx, 1, tz)
				break

func _spawn_monoliths() -> void:
	# Spawn Alien Monoliths in crystal and snow biomes.
	var monolith_scene := preload("res://scenes/entities/monolith.tscn")
	var half_grid: float = GRID_SIZE / 2.0

	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var idx: int = x * GRID_SIZE + z
			var biome: int = grid[idx]
			var wx: float = (x - half_grid) * TILE_SIZE
			var wz: float = (z - half_grid) * TILE_SIZE
			var dist_from_spawn: float = Vector2(wx, wz).length()

			if dist_from_spawn < 60:
				continue

			if biome == GameConstants.Biome.CRYSTAL and randf() < GameConstants.MONOLITH_SPAWN_CHANCE_CRYSTAL:
				var monolith := monolith_scene.instantiate()
				add_child(monolith)
				monolith.global_position = Vector3(wx, 0, wz)
			elif biome == GameConstants.Biome.SNOW and randf() < GameConstants.MONOLITH_SPAWN_CHANCE_SNOW:
				var monolith := monolith_scene.instantiate()
				add_child(monolith)
				monolith.global_position = Vector3(wx, 0, wz)

func _spawn_healing_shrines() -> void:
	# Spawn Healing Crystal Shrines in mushroom and swamp biomes.
	var shrine_scene := preload("res://scenes/entities/healing_shrine.tscn")
	var half_grid: float = GRID_SIZE / 2.0

	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var idx: int = x * GRID_SIZE + z
			var biome: int = grid[idx]
			var wx: float = (x - half_grid) * TILE_SIZE
			var wz: float = (z - half_grid) * TILE_SIZE
			var dist_from_spawn: float = Vector2(wx, wz).length()

			if dist_from_spawn < 50:
				continue

			if biome == GameConstants.Biome.MUSHROOM and randf() < GameConstants.SHRINE_SPAWN_CHANCE_MUSHROOM:
				var shrine := shrine_scene.instantiate()
				add_child(shrine)
				shrine.global_position = Vector3(wx, 0, wz)
			elif biome == GameConstants.Biome.SWAMP and randf() < GameConstants.SHRINE_SPAWN_CHANCE_SWAMP:
				var shrine := shrine_scene.instantiate()
				add_child(shrine)
				shrine.global_position = Vector3(wx, 0, wz)

func _is_biome_walkable(biome: int) -> bool:
	# Check if a biome type is walkable (not water or lava).
	# Phase 22: Deep Ocean, Volcano Core, Crystal Caverns and Underground are
	# considered walkable for spawning purposes — the player can traverse them
	# (with buoyancy/heat effects applied via the biome system). Only surface
	# water and lava are treated as unwalkable liquid tiles.
	match biome:
		GameConstants.Biome.WATER:
			return false
		GameConstants.Biome.LAVA:
			return false
		_:
			return true

func _random_world_position() -> Vector3:
	# Random position within the world bounds.
	var x := randf_range(-HALF_WORLD + 10, HALF_WORLD - 10)
	var z := randf_range(-HALF_WORLD + 10, HALF_WORLD - 10)
	return Vector3(x, 0.5, z)

func _random_enemy_type() -> String:
	# Pick a random enemy type based on distance from spawn (difficulty scaling).
	# Use player position for distance-based difficulty
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var dist := 0.0
	if player:
		dist = abs(player.global_position.x) + abs(player.global_position.z)
	return EnemyTypeData.pick_type_by_distance(dist, GameConstants.DIFFICULTY_SCALE_DISTANCE)

func _random_collectible_type() -> int:
	var roll := randf()
	if roll < 0.30:
		return GameConstants.CollectibleType.XP_ORB
	if roll < 0.50:
		return GameConstants.CollectibleType.SPACE_GLOOP
	if roll < 0.65:
		return GameConstants.CollectibleType.STAR_FRUIT
	if roll < 0.75:
		return GameConstants.CollectibleType.HEALTH_FRAGMENT
	if roll < 0.85:
		return GameConstants.CollectibleType.METEOR_SHARD
	if roll < 0.92:
		return GameConstants.CollectibleType.QUANTUM_FUZZ
	return GameConstants.CollectibleType.NEBULA_DUST

func _spawn_enemy_at(type_name: String, pos: Vector3) -> void:
	# Spawn an enemy of the given type at the given position.
	var type_data: Dictionary = EnemyTypeData.get_type(type_name)
	# Map enemy names to their specialized scenes
	var scene_map: Dictionary = {
		"Slime Blob": "res://scenes/entities/enemy_blob.tscn",
		"Space Beetle": "res://scenes/entities/enemy_blob.tscn",
		"Void Wraith": "res://scenes/entities/enemy_blob.tscn",
		"Lava Crawler": "res://scenes/entities/enemy_blob.tscn",
		"Crystal Guardian": "res://scenes/entities/enemy_blob.tscn",
		"Plasma Drake": "res://scenes/entities/enemy_drake.tscn",
		"Phase Shifter": "res://scenes/entities/enemy_blob.tscn",
		"Spore Spitter": "res://scenes/entities/enemy_spitter.tscn",
		"Swarm Mite": "res://scenes/entities/enemy_blob.tscn",
		"Void Bomber": "res://scenes/entities/enemy_bomber.tscn",
		"Nebula Phantom": "res://scenes/entities/enemy_blob.tscn",
		"Starburst Sentinel": "res://scenes/entities/enemy_sentinel.tscn",
		"Cosmic Leech": "res://scenes/entities/enemy_blob.tscn",
		"Void Stalker": "res://scenes/entities/enemy_blob.tscn",
		"Plasma Serpent": "res://scenes/entities/enemy_serpent.tscn",
		"Graviton": "res://scenes/entities/enemy_graviton.tscn",
		"Void Wisp": "res://scenes/entities/enemy_wisp.tscn",
		"Echo Wraith": "res://scenes/entities/enemy_blob.tscn",
		"Shard Golem": "res://scenes/entities/enemy_blob.tscn",
	}
	var scene_path: String = scene_map.get(type_name, "res://scenes/entities/enemy_blob.tscn")
	var enemy_scene: PackedScene = load(scene_path)
	var enemy: CharacterBody3D = enemy_scene.instantiate()
	enemy.global_position = pos
	# Configure enemy with type data
	enemy.enemy_name = type_name
	enemy.max_hp = type_data["hp"]
	enemy.hp = type_data["hp"]
	enemy.speed = type_data["speed"]
	enemy.damage = type_data["damage"]
	enemy.base_scale = type_data["scale"]
	enemy.detect_range = type_data.get("detect", GameConstants.ENEMY_DETECT_RANGE)
	# Set color
	enemy.base_color = type_data["color"]
	add_child(enemy)
	GameManager.enemies.append(enemy)

func _spawn_collectible_at(type: int, pos: Vector3) -> void:
	# Spawn a collectible of the given type at the given position.
	var collectible_scene := preload("res://scenes/entities/collectible.tscn")
	var collectible := collectible_scene.instantiate()
	add_child(collectible)
	collectible.global_position = pos
	collectible.set_type(type)
	GameManager.collectibles.append(collectible)
	if not collectible.is_in_group("collectibles"):
		collectible.add_to_group("collectibles")

func get_biome_at(world_pos: Vector3) -> int:
	# Get the biome type at a world position.
	var x := int((world_pos.x / TILE_SIZE) + GRID_SIZE / 2.0)
	var z := int((world_pos.z / TILE_SIZE) + GRID_SIZE / 2.0)
	x = clampi(x, 0, GRID_SIZE - 1)
	z = clampi(z, 0, GRID_SIZE - 1)
	return grid[x * GRID_SIZE + z]

# ── Phase 26: World Life — lore stones, treasure chests, wildlife ──────────────
# These are scattered across walkable biomes. Lore stones reveal lore text when
# the player approaches. Treasure chests are hidden (glow when close) and
# contain rare loot (some are trapped). Wildlife are non-hostile creatures that
# flee from the player and drop loot when caught.

func _spawn_lore_stones() -> void:
	# Scatter lore stones across walkable biomes. Each stone picks a lore
	# fragment from the LORE_FRAGMENTS list. Stones near spawn are skipped so
	# the player isn't immediately reading lore before they've started playing.
	var stone_scene := preload("res://scenes/entities/lore_stone.tscn")
	var half_grid: float = GRID_SIZE / 2.0
	var count: int = 0
	var fragment_idx: int = 0
	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var idx: int = x * GRID_SIZE + z
			var biome: int = grid[idx]
			if not _is_biome_walkable(biome):
				continue
			if randf() < GameConstants.LORE_STONE_SPAWN_CHANCE:
				var wx: float = (x - half_grid) * TILE_SIZE + randf_range(-1.5, 1.5)
				var wz: float = (z - half_grid) * TILE_SIZE + randf_range(-1.5, 1.5)
				# Skip if too close to spawn (let the player explore first).
				if Vector2(wx, wz).length() < 50:
					continue
				var stone := stone_scene.instantiate()
				# Set fragment_index BEFORE add_child so _ready() doesn't auto-pick
				# a random fragment (the spawner assigns them sequentially).
				stone.fragment_index = fragment_idx % GameConstants.LORE_FRAGMENTS.size()
				fragment_idx += 1
				add_child(stone)
				stone.global_position = Vector3(wx, 0, wz)
				count += 1
	print("[WorldGenerator] Spawned %d lore stones" % count)

func _spawn_treasure_chests() -> void:
	# Scatter hidden treasure chests across walkable biomes. Skipped near spawn.
	var chest_scene := preload("res://scenes/entities/treasure_chest.tscn")
	var half_grid: float = GRID_SIZE / 2.0
	var count: int = 0
	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var idx: int = x * GRID_SIZE + z
			var biome: int = grid[idx]
			if not _is_biome_walkable(biome):
				continue
			if randf() < GameConstants.TREASURE_CHEST_SPAWN_CHANCE:
				var wx: float = (x - half_grid) * TILE_SIZE + randf_range(-1.5, 1.5)
				var wz: float = (z - half_grid) * TILE_SIZE + randf_range(-1.5, 1.5)
				if Vector2(wx, wz).length() < 60:
					continue
				var chest := chest_scene.instantiate()
				add_child(chest)
				chest.global_position = Vector3(wx, 0, wz)
				count += 1
	print("[WorldGenerator] Spawned %d treasure chests" % count)

func _spawn_wildlife() -> void:
	# Spawn biome-appropriate wildlife. Each species only spawns in its
	# preferred biomes (see WILDLIFE_SPECIES in game_constants.gd), creating
	# biome-specific fauna. Skipped near spawn so the player doesn't
	# immediately trample them.
	var wildlife_scene := preload("res://scenes/entities/wildlife.tscn")
	var half_grid: float = GRID_SIZE / 2.0
	var count: int = 0
	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var idx: int = x * GRID_SIZE + z
			var biome: int = grid[idx]
			if not _is_biome_walkable(biome):
				continue
			if randf() < GameConstants.WILDLIFE_SPAWN_CHANCE:
				var wx: float = (x - half_grid) * TILE_SIZE + randf_range(-1.5, 1.5)
				var wz: float = (z - half_grid) * TILE_SIZE + randf_range(-1.5, 1.5)
				if Vector2(wx, wz).length() < 30:
					continue
				# Pick a species that prefers this biome.
				var species: Dictionary = _pick_wildlife_species_for_biome(biome)
				if species.is_empty():
					continue  # No species for this biome — skip.
				var creature := wildlife_scene.instantiate()
				# Set export properties BEFORE add_child so _ready() sees the correct
				# species (visuals, scale, and color are all picked in _ready).
				creature.species_name = species.get("name", "Unknown")
				creature.species_color = species.get("color", Color(0.9, 0.8, 0.3))
				creature.species_scale = species.get("scale", 0.5)
				add_child(creature)
				creature.global_position = Vector3(wx, 0.5, wz)
				count += 1
	print("[WorldGenerator] Spawned %d wildlife" % count)

func _pick_wildlife_species_for_biome(biome: int) -> Dictionary:
	# Return a random species from WILDLIFE_SPECIES that prefers the given
	# biome. Returns an empty Dictionary if no species prefers this biome.
	var candidates: Array[Dictionary] = []
	for species in GameConstants.WILDLIFE_SPECIES:
		var biomes: Array = species.get("biomes", [])
		if biome in biomes:
			candidates.append(species)
	if candidates.is_empty():
		return {}
	return candidates[randi() % candidates.size()]

# ── Phase 26: Dialogue NPCs, Environmental Hazards, Interactive Objects ──────

func _spawn_dialogue_npcs() -> void:
	# Spawn a small number of dialogue NPCs across walkable biomes. Villagers
	# cluster in friendly biomes (grass, forest, mushroom), elders in ancient
	# ruins, and holograms in the digital grid. The player presses T to talk.
	var npc_scene := preload("res://scenes/entities/dialogue_npc.tscn")
	var half_grid: float = GRID_SIZE / 2.0
	var count: int = 0
	# Map archetypes to their preferred biomes.
	var archetype_biomes: Dictionary = {
		"villager": [GameConstants.Biome.GRASS, GameConstants.Biome.FOREST,
			GameConstants.Biome.MUSHROOM, GameConstants.Biome.SWAMP,
			GameConstants.Biome.FLOATING_ISLANDS, GameConstants.Biome.SKY_CITADEL],
		"elder": [GameConstants.Biome.ANCIENT_RUINS, GameConstants.Biome.CRYSTAL,
			GameConstants.Biome.CRYSTAL_CAVERNS, GameConstants.Biome.UNDERGROUND],
		"hologram": [GameConstants.Biome.DIGITAL_GRID, GameConstants.Biome.ALIEN],
	}
	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var idx: int = x * GRID_SIZE + z
			var biome: int = grid[idx]
			if not _is_biome_walkable(biome):
				continue
			# Sparse spawn — about 0.3% per tile to keep NPC count low.
			if randf() > 0.003:
				continue
			# Pick an archetype that prefers this biome.
			var archetype: String = ""
			for a in archetype_biomes.keys():
				if biome in archetype_biomes[a]:
					archetype = a
					break
			if archetype == "":
				continue
			var wx: float = (x - half_grid) * TILE_SIZE + randf_range(-1.5, 1.5)
			var wz: float = (z - half_grid) * TILE_SIZE + randf_range(-1.5, 1.5)
			# Skip near spawn.
			if Vector2(wx, wz).length() < 40:
				continue
			var npc := npc_scene.instantiate()
			# Set export properties BEFORE add_child so _ready() sees the correct
			# archetype (visuals, name pool, and config are all picked in _ready).
			npc.archetype = archetype
			add_child(npc)
			npc.global_position = Vector3(wx, 0.5, wz)
			count += 1
	print("[WorldGenerator] Spawned %d dialogue NPCs" % count)

func _spawn_environmental_hazards() -> void:
	# Spawn environmental hazards in their preferred biomes. Each hazard type
	# only spawns in biomes listed in ENV_HAZARD_TYPES. Hazards cycle through
	# telegraph → active → cooldown indefinitely.
	var hazard_scene := preload("res://scenes/entities/environmental_hazard.tscn")
	var half_grid: float = GRID_SIZE / 2.0
	var count: int = 0
	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var idx: int = x * GRID_SIZE + z
			var biome: int = grid[idx]
			# Pick a hazard type that prefers this biome.
			var hazard_type_name: String = ""
			var hazard_damage: int = GameConstants.ENV_HAZARD_DAMAGE
			for entry in GameConstants.ENV_HAZARD_TYPES:
				var biomes: Array = entry.get("biomes", [])
				if biome in biomes:
					hazard_type_name = entry.get("type", "")
					hazard_damage = int(entry.get("damage", hazard_damage))
					break
			if hazard_type_name == "":
				continue
			if randf() > GameConstants.ENV_HAZARD_SPAWN_CHANCE:
				continue
			var wx: float = (x - half_grid) * TILE_SIZE + randf_range(-1.5, 1.5)
			var wz: float = (z - half_grid) * TILE_SIZE + randf_range(-1.5, 1.5)
			# Skip near spawn.
			if Vector2(wx, wz).length() < 35:
				continue
			var hazard := hazard_scene.instantiate()
			# Set export properties BEFORE add_child so _ready() sees the correct
			# hazard type (visuals, damage, and config are all picked in _ready).
			hazard.hazard_type_name = hazard_type_name
			hazard.damage = hazard_damage
			add_child(hazard)
			hazard.global_position = Vector3(wx, 0, wz)
			count += 1
	print("[WorldGenerator] Spawned %d environmental hazards" % count)

func _spawn_interactive_objects() -> void:
	# Spawn interactive objects (switches, doors, breakable walls, hidden
	# passages) across walkable biomes. Switches and doors are spawned in
	# linked pairs — a switch with linked_id "A" toggles a door with linked_id
	# "A". Breakable walls and hidden passages are standalone.
	var obj_scene := preload("res://scenes/entities/interactive_object.tscn")
	var half_grid: float = GRID_SIZE / 2.0
	var count: int = 0
	var link_counter: int = 0
	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var idx: int = x * GRID_SIZE + z
			var biome: int = grid[idx]
			if not _is_biome_walkable(biome):
				continue
			if randf() > GameConstants.INTERACTIVE_SPAWN_CHANCE:
				continue
			var wx: float = (x - half_grid) * TILE_SIZE + randf_range(-1.5, 1.5)
			var wz: float = (z - half_grid) * TILE_SIZE + randf_range(-1.5, 1.5)
			# Skip near spawn.
			if Vector2(wx, wz).length() < 45:
				continue
			# Pick an object type. 40% switch, 30% door, 20% breakable wall,
			# 10% hidden passage. Switches and doors are spawned in pairs.
			var roll: float = randf()
			var obj_type: String = ""
			if roll < 0.4:
				obj_type = "switch"
			elif roll < 0.7:
				obj_type = "door"
			elif roll < 0.9:
				obj_type = "breakable_wall"
			else:
				obj_type = "hidden_passage"
			var obj := obj_scene.instantiate()
			# Set export properties BEFORE add_child so _ready() sees the correct
			# object type (visuals, HP, collision, and config are all picked in _ready).
			obj.object_type = obj_type
			# Assign a linked_id so switches pair with nearby doors/passages.
			if obj_type == "switch" or obj_type == "door" or obj_type == "hidden_passage":
				obj.linked_id = "link_%d" % (link_counter / 2)
				link_counter += 1
			add_child(obj)
			obj.global_position = Vector3(wx, 0, wz)
			count += 1
	print("[WorldGenerator] Spawned %d interactive objects" % count)