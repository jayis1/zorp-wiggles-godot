## Zorp Wiggles — World Generator
## Procedurally generates the 3D open world with biomes, terrain, and decorations.
## Ported from the terrain/decoration building logic in Ursina game.py.

extends Node3D

const TILE_SIZE: float = GameConstants.TILE_SCALE
const GRID_SIZE: int = GameConstants.WORLD_SIZE
const HALF_WORLD: float = GameConstants.WORLD_SIZE * GameConstants.TILE_SCALE / 2.0

# ─── Biome Colors (0-1 normalized for Godot) ─────────────────────────────────
const BIOME_COLORS: Dictionary = {
	GameConstants.Biome.GRASS: Color(0.35, 0.65, 0.25),
	GameConstants.Biome.DESERT: Color(0.85, 0.75, 0.45),
	GameConstants.Biome.WATER: Color(0.2, 0.4, 0.8),
	GameConstants.Biome.LAVA: Color(0.8, 0.2, 0.05),
	GameConstants.Biome.FOREST: Color(0.15, 0.5, 0.15),
	GameConstants.Biome.CRYSTAL: Color(0.7, 0.4, 0.9),
	GameConstants.Biome.SNOW: Color(0.92, 0.95, 1.0),
	GameConstants.Biome.SWAMP: Color(0.35, 0.5, 0.25),
	GameConstants.Biome.ALIEN: Color(0.6, 0.2, 0.7),
	GameConstants.Biome.MUSHROOM: Color(0.9, 0.45, 0.65),
	GameConstants.Biome.FLOATING_ISLANDS: Color(0.7, 0.65, 0.85),
	GameConstants.Biome.TOXIC_BOG: Color(0.5, 0.75, 0.15),
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
	
	print("[WorldGenerator] World generation complete!")

func _generate_biome_grid() -> void:
	"""Use noise-based biome assignment matching the original Ursina logic."""
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
	"""Classify a tile into a biome based on noise values."""
	# Water/low elevation
	if elevation < -0.3:
		if temperature > 0.3:
			return GameConstants.Biome.LAVA
		return GameConstants.Biome.WATER
	
	# Very high elevation → floating islands
	if elevation > 0.5:
		return GameConstants.Biome.FLOATING_ISLANDS
	
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
		return GameConstants.Biome.CRYSTAL
	
	# Random rare biomes
	var roll := randf()
	if roll < 0.03:
		return GameConstants.Biome.ALIEN
	if roll < 0.06:
		return GameConstants.Biome.MUSHROOM
	if roll < 0.09:
		return GameConstants.Biome.TOXIC_BOG
	
	return GameConstants.Biome.GRASS

func _build_terrain_mesh() -> void:
	"""Build a single merged terrain mesh with vertex colors for biomes."""
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
	"""Create unlit material for terrain (matching Ursina's unlit_with_fog_shader)."""
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	return mat

func _get_tile_height(biome: int, x: int, z: int) -> float:
	"""Return height offset for a tile based on biome type."""
	match biome:
		GameConstants.Biome.WATER:
			return -0.3
		GameConstants.Biome.LAVA:
			return -0.2
		GameConstants.Biome.FLOATING_ISLANDS:
			return 2.0 + randf() * 3.0
		GameConstants.Biome.SNOW:
			return 0.1 + randf() * 0.3
		_:
			return 0.0

func _build_ground_collision() -> void:
	"""Create a single flat collision plane for the entire world."""
	ground_collision = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GRID_SIZE * TILE_SIZE, 0.5, GRID_SIZE * TILE_SIZE)
	shape.shape = box
	shape.position = Vector3(0, -0.25, 0)
	ground_collision.add_child(shape)
	add_child(ground_collision)

func _spawn_decorations() -> void:
	"""Spawn biome-appropriate decorations (trees, crystals, mushrooms, etc.)."""
	# This will be expanded by the builder cron job
	pass

func _spawn_initial_enemies() -> void:
	"""Spawn initial wave of enemies across the world."""
	var spawn_count := 15 + GameManager.player_level * 2
	for i in range(spawn_count):
		var pos := _random_world_position()
		var enemy_type := _random_enemy_type()
		_spawn_enemy_at(enemy_type, pos)

func _spawn_collectibles() -> void:
	"""Spawn collectible items across the world."""
	var spawn_count := 25
	for i in range(spawn_count):
		var pos := _random_world_position()
		var type := _random_collectible_type()
		_spawn_collectible_at(type, pos)

func _spawn_structures() -> void:
	"""Spawn monoliths, traders, and portals."""
	# Will be expanded by builder cron job
	pass

func _random_world_position() -> Vector3:
	"""Random position within the world bounds."""
	var x := randf_range(-HALF_WORLD + 10, HALF_WORLD - 10)
	var z := randf_range(-HALF_WORLD + 10, HALF_WORLD - 10)
	return Vector3(x, 0.5, z)

func _random_enemy_type() -> int:
	"""Pick a random enemy type based on difficulty progression."""
	var roll := randf()
	if GameManager.player_level >= 5 and roll < 0.1:
		return GameConstants.EnemyType.DRAKE
	if GameManager.player_level >= 3 and roll < 0.25:
		return GameConstants.EnemyType.SENTINEL
	if roll < 0.15:
		return GameConstants.EnemyType.SERPENT
	if roll < 0.25:
		return GameConstants.EnemyType.GRAVITON
	if roll < 0.35:
		return GameConstants.EnemyType.WISP
	if roll < 0.50:
		return GameConstants.EnemyType.BOMBER
	if roll < 0.70:
		return GameConstants.EnemyType.SPITTER
	return GameConstants.EnemyType.BLOB

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

func _spawn_enemy_at(type: int, pos: Vector3) -> void:
	"""Spawn an enemy of the given type at the given position."""
	var scene_path: String = EnemySpawner.ENEMY_SCENES.get(type, "")
	if scene_path.is_empty():
		# Fallback to blob
		scene_path = "res://scenes/entities/enemy_blob.tscn"
	var enemy_scene: PackedScene = load(scene_path)
	if not enemy_scene:
		enemy_scene = preload("res://scenes/entities/enemy_blob.tscn")
	var enemy: Node3D = enemy_scene.instantiate()
	enemy.global_position = pos
	add_child(enemy)
	GameManager.enemies.append(enemy)

func _spawn_collectible_at(type: int, pos: Vector3) -> void:
	"""Spawn a collectible of the given type at the given position."""
	var collectible_scene := preload("res://scenes/entities/collectible.tscn")
	var collectible := collectible_scene.instantiate()
	collectible.global_position = pos
	collectible.set_type(type)
	add_child(collectible)
	GameManager.collectibles.append(collectible)

func get_biome_at(world_pos: Vector3) -> int:
	"""Get the biome type at a world position."""
	var x := int((world_pos.x / TILE_SIZE) + GRID_SIZE / 2.0)
	var z := int((world_pos.z / TILE_SIZE) + GRID_SIZE / 2.0)
	x = clampi(x, 0, GRID_SIZE - 1)
	z = clampi(z, 0, GRID_SIZE - 1)
	return grid[x * GRID_SIZE + z]