## Zorp Wiggles — Biome Decorations
## Spawns biome-appropriate decorations: trees, crystals, mushrooms, toxic bog features,
## desert ruins, floating islands, and water/lava surface overlays.
## Ported from the decoration spawning logic in Ursina game.py _build_terrain().
## All colors use Godot 0-1 range.

class_name DecorationSystem
extends Node3D

# ─── State ───────────────────────────────────────────────────────────────────
var _decorations: Array[MeshInstance3D] = []
var _water_overlays: Array[MeshInstance3D] = []
var _lava_overlays: Array[MeshInstance3D] = []

# Mushroom cap color choices (neon alien mushrooms)
const MUSHROOM_CAP_COLORS: Array[Color] = [
	Color(1.0, 50.0 / 255.0, 120.0 / 255.0),   # neon pink
	Color(80.0 / 255.0, 1.0, 80.0 / 255.0),    # bright green
	Color(200.0 / 255.0, 50.0 / 255.0, 1.0),   # purple
	Color(1.0, 200.0 / 255.0, 0.0),            # golden
]

# Horizon glow palette for ruins walls
const RUINS_COLORS: Array[Color] = [
	Color(160.0 / 255.0, 140.0 / 255.0, 100.0 / 255.0),
	Color(140.0 / 255.0, 120.0 / 255.0, 80.0 / 255.0),
]

# ─── Public API ──────────────────────────────────────────────────────────────

func spawn_all_decorations(grid: Array[int], grid_size: int, tile_scale: float) -> void:
	# Main entry point — iterates over the biome grid and spawns decorations.
	var half_grid: float = grid_size / 2.0
	for x in range(grid_size):
		for z in range(grid_size):
			var idx: int = x * grid_size + z
			var biome: int = grid[idx]
			var wx: float = (x - half_grid) * tile_scale
			var wz: float = (z - half_grid) * tile_scale
			_spawn_tile_decorations(biome, wx, wz)

func get_decoration_count() -> int:
	return _decorations.size()

# ─── Per-biome decoration spawning ───────────────────────────────────────────

func _spawn_tile_decorations(biome: int, wx: float, wz: float) -> void:
	match biome:
		GameConstants.Biome.FOREST:
			if randf() < 0.30:
				_spawn_tree(wx, wz)
		GameConstants.Biome.CRYSTAL:
			if randf() < 0.20:
				_spawn_crystal(wx, wz)
		GameConstants.Biome.MUSHROOM:
			if randf() < 0.25:
				_spawn_mushroom(wx, wz)
		GameConstants.Biome.FLOATING_ISLANDS:
			if randf() < GameConstants.FLOATING_ISLAND_SPAWN_CHANCE:
				_spawn_floating_island(wx, wz)
		GameConstants.Biome.TOXIC_BOG:
			if randf() < 0.20:
				_spawn_toxic_bog(wx, wz)
		GameConstants.Biome.DESERT:
			if randf() < GameConstants.RUINS_PILLAR_CHANCE:
				_spawn_ruins(wx, wz)
		GameConstants.Biome.WATER:
			_spawn_water_overlay(wx, wz)
		GameConstants.Biome.LAVA:
			_spawn_lava_overlay(wx, wz)
		# ── Phase 22: New biome decorations ──
		GameConstants.Biome.DEEP_OCEAN:
			_spawn_deep_ocean_overlay(wx, wz)
			if randf() < GameConstants.DEEP_OCEAN_GLOW_CHANCE:
				_spawn_bioluminescent(wx, wz)
		GameConstants.Biome.VOLCANO_CORE:
			_spawn_volcano_overlay(wx, wz)
			if randf() < GameConstants.VOLCANO_CORE_ERUPTION_CHANCE:
				_spawn_lava_vent(wx, wz)
		GameConstants.Biome.SKY_CITADEL:
			if randf() < GameConstants.SKY_CITADEL_PLATFORM_CHANCE:
				_spawn_sky_platform(wx, wz)
		GameConstants.Biome.DIGITAL_GRID:
			if randf() < GameConstants.DIGITAL_GRID_GLITCH_CHANCE:
				_spawn_digital_glitch(wx, wz)
		GameConstants.Biome.CRYSTAL_CAVERNS:
			if randf() < GameConstants.CRYSTAL_CAVERNS_CRYSTAL_CHANCE:
				_spawn_crystal_cavern_cluster(wx, wz)
		GameConstants.Biome.ANCIENT_RUINS:
			if randf() < GameConstants.ANCIENT_RUINS_PILLAR_CHANCE:
				_spawn_ancient_pillar(wx, wz)
		GameConstants.Biome.UNDERGROUND:
			if randf() < GameConstants.UNDERGROUND_STALACTITE_CHANCE:
				_spawn_stalactite(wx, wz)
			if randf() < GameConstants.UNDERGROUND_STALAGMITE_CHANCE:
				_spawn_stalagmite(wx, wz)
			if randf() < GameConstants.UNDERGROUND_GLOW_CHANCE:
				_spawn_underground_glow(wx, wz)

# ─── Tree (Forest biome) ─────────────────────────────────────────────────────

func _spawn_tree(wx: float, wz: float) -> void:
	# Trunk — tall thin box
	var trunk := _create_box(
		Vector3(wx, 3.0, wz),
		Vector3(0.6, 6.0, 0.6),
		Color(60.0 / 255.0, 35.0 / 255.0, 15.0 / 255.0)
	)
	_decorations.append(trunk)
	add_child(trunk)

	# Canopy — green sphere on top
	var canopy := _create_sphere(
		Vector3(wx, 7.0, wz),
		3.0,
		Color(0.0, 80.0 / 255.0, 30.0 / 255.0)
	)
	_decorations.append(canopy)
	add_child(canopy)

# ─── Crystal (Crystal biome) ─────────────────────────────────────────────────

func _spawn_crystal(wx: float, wz: float) -> void:
	var height: float = randf_range(3.0, 8.0)
	var crystal := _create_box(
		Vector3(wx, height / 2.0 + 0.6, wz),
		Vector3(0.5, height, 0.5),
		Color(0.0, 240.0 / 255.0, 1.0)
	)
	_decorations.append(crystal)
	add_child(crystal)

# ─── Mushroom (Mushroom biome) ───────────────────────────────────────────────

func _spawn_mushroom(wx: float, wz: float) -> void:
	var stem_h: float = randf_range(1.5, 4.5)
	# Stem
	var stem := _create_box(
		Vector3(wx, stem_h / 2.0 + 0.5, wz),
		Vector3(0.4, stem_h, 0.4),
		Color(180.0 / 255.0, 170.0 / 255.0, 160.0 / 255.0)
	)
	_decorations.append(stem)
	add_child(stem)

	# Cap — colorful sphere
	var cap_r: float = randf_range(1.0, 2.5)
	var cap_color: Color = MUSHROOM_CAP_COLORS[randi() % MUSHROOM_CAP_COLORS.size()]
	var cap := _create_sphere(
		Vector3(wx, stem_h + 1.0, wz),
		cap_r,
		cap_color
	)
	_decorations.append(cap)
	add_child(cap)

	# Spore glow ring under cap — flat translucent quad
	var glow := _create_ground_quad(
		Vector3(wx, stem_h + 0.5, wz),
		cap_r * 1.5,
		Color(1.0, 100.0 / 255.0, 1.0, 50.0 / 255.0)
	)
	_decorations.append(glow)
	add_child(glow)

# ─── Floating Island ─────────────────────────────────────────────────────────

func _spawn_floating_island(wx: float, wz: float) -> void:
	var island_h: float = randf_range(
		GameConstants.FLOATING_ISLAND_HEIGHT_MIN,
		GameConstants.FLOATING_ISLAND_HEIGHT_MAX
	)
	var island_size: float = randf_range(1.5, 3.0)

	# The floating platform
	var island := _create_box(
		Vector3(wx, island_h, wz),
		Vector3(island_size, 0.5, island_size),
		GameConstants.FLOATING_ISLAND_COLOR
	)
	_decorations.append(island)
	add_child(island)

	# Shadow beneath
	var shadow := _create_ground_quad(
		Vector3(wx, 0.05, wz),
		island_size * 1.5,
		Color(0.0, 0.0, 0.0, 40.0 / 255.0)
	)
	_decorations.append(shadow)
	add_child(shadow)

	# Crystal on top of island
	if randf() < GameConstants.FLOATING_ISLAND_CRYSTAL_CHANCE:
		var crystal_h: float = randf_range(1.5, 4.0)
		var crystal_top := _create_box(
			Vector3(wx, island_h + crystal_h / 2.0 + 0.25, wz),
			Vector3(0.3, crystal_h, 0.3),
			Color(180.0 / 255.0, 140.0 / 255.0, 1.0)
		)
		_decorations.append(crystal_top)
		add_child(crystal_top)

# ─── Toxic Bog ───────────────────────────────────────────────────────────────

func _spawn_toxic_bog(wx: float, wz: float) -> void:
	if randf() < 0.5:
		# Toxic bubble pool — flat glowing disc
		var pool_size: float = randf_range(1.0, 2.5)
		var pool := _create_ground_quad(
			Vector3(wx, 0.06, wz),
			pool_size,
			Color(100.0 / 255.0, 200.0 / 255.0, 50.0 / 255.0, 90.0 / 255.0)
		)
		_decorations.append(pool)
		add_child(pool)

		# Occasional tall toxic spire
		if randf() < 0.3:
			var spire_h: float = randf_range(2.0, 5.0)
			var spire := _create_box(
				Vector3(wx, spire_h / 2.0 + 0.5, wz),
				Vector3(0.3, spire_h, 0.3),
				Color(80.0 / 255.0, 160.0 / 255.0, 40.0 / 255.0)
			)
			_decorations.append(spire)
			add_child(spire)
	else:
		# Twisted fungal stalk with glowing cap
		var stalk_h: float = randf_range(1.5, 3.5)
		var stalk := _create_box(
			Vector3(wx, stalk_h / 2.0 + 0.5, wz),
			Vector3(0.3, stalk_h, 0.3),
			Color(50.0 / 255.0, 100.0 / 255.0, 20.0 / 255.0)
		)
		_decorations.append(stalk)
		add_child(stalk)

		var cap := _create_sphere(
			Vector3(wx, stalk_h + 0.8, wz),
			randf_range(0.8, 1.5),
			Color(120.0 / 255.0, 220.0 / 255.0, 30.0 / 255.0)
		)
		_decorations.append(cap)
		add_child(cap)

		# Sickly glow beneath cap
		var bog_glow := _create_ground_quad(
			Vector3(wx, stalk_h + 0.3, wz),
			randf_range(1.0, 2.0),
			Color(80.0 / 255.0, 200.0 / 255.0, 20.0 / 255.0, 50.0 / 255.0)
		)
		_decorations.append(bog_glow)
		add_child(bog_glow)

# ─── Desert Ruins ────────────────────────────────────────────────────────────

func _spawn_ruins(wx: float, wz: float) -> void:
	var pillar_count: int = randi_range(1, 4)
	for _pi in range(pillar_count):
		var offset_x: float = randf_range(-2.0, 2.0)
		var offset_z: float = randf_range(-2.0, 2.0)
		var pillar_h: float = randf_range(2.0, 6.0)
		var pillar := _create_box(
			Vector3(wx + offset_x, pillar_h / 2.0 + 0.5, wz + offset_z),
			Vector3(0.4, pillar_h, 0.4),
			RUINS_COLORS[0]
		)
		_decorations.append(pillar)
		add_child(pillar)

	# Broken wall segment
	if randf() < 0.5:
		var wall_w: float = randf_range(1.0, 3.0)
		var wall_h: float = randf_range(1.5, 3.0)
		var wall := _create_box(
			Vector3(wx, wall_h / 2.0 + 0.5, wz),
			Vector3(wall_w, wall_h, 0.3),
			RUINS_COLORS[1]
		)
		_decorations.append(wall)
		add_child(wall)

# ─── Water Surface Overlay ───────────────────────────────────────────────────

func _spawn_water_overlay(wx: float, wz: float) -> void:
	var overlay := _create_ground_quad(
		Vector3(wx, -0.05, wz),
		GameConstants.TILE_SCALE,
		GameConstants.WATER_OVERLAY_COLOR
	)
	# Phase 9: Apply animated water surface shader for realistic ripples
	var water_shader: Shader = load("res://assets/shaders/water_surface.gdshader")
	if water_shader:
		var mat := ShaderMaterial.new()
		mat.shader = water_shader
		mat.set_shader_parameter("water_color", Vector3(0.1, 0.35, 0.7))
		mat.set_shader_parameter("deep_color", Vector3(0.02, 0.05, 0.2))
		mat.set_shader_parameter("transparency", 0.55)
		mat.set_shader_parameter("flow_speed", 0.6)
		mat.set_shader_parameter("wave_height", 0.04)
		mat.set_shader_parameter("wave_frequency", 5.0)
		overlay.material_override = mat
	_water_overlays.append(overlay)
	add_child(overlay)

# ─── Lava Glow Overlay ───────────────────────────────────────────────────────

func _spawn_lava_overlay(wx: float, wz: float) -> void:
	var glow := _create_ground_quad(
		Vector3(wx, 0.06, wz),
		GameConstants.TILE_SCALE * 0.9,
		GameConstants.LAVA_GLOW_COLOR
	)
	_lava_overlays.append(glow)
	add_child(glow)

# ── Phase 22: New biome decorations ───────────────────────────────────────────

# Deep Ocean — translucent dark water surface with depth gradient.
func _spawn_deep_ocean_overlay(wx: float, wz: float) -> void:
	var overlay := _create_ground_quad(
		Vector3(wx, GameConstants.DEEP_OCEAN_DEPTH + 0.1, wz),
		GameConstants.TILE_SCALE,
		Color(5.0 / 255.0, 25.0 / 255.0, 80.0 / 255.0, 130.0 / 255.0)
	)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(5.0 / 255.0, 25.0 / 255.0, 80.0 / 255.0, 0.55)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.material_override = mat
	_water_overlays.append(overlay)
	add_child(overlay)

# Bioluminescent floating orbs that glow in the deep ocean.
func _spawn_bioluminescent(wx: float, wz: float) -> void:
	var glow_colors: Array[Color] = [
		Color(0.1, 1.0, 0.8),   # Cyan
		Color(0.4, 0.6, 1.0),   # Soft blue
		Color(0.7, 0.3, 1.0),   # Violet
	]
	var col: Color = glow_colors[randi() % glow_colors.size()]
	var orb := _create_sphere(
		Vector3(wx, randf_range(-2.0, 0.5), wz),
		randf_range(0.3, 0.7),
		col
	)
	# Make it emissive so it actually glows in the dark.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb.material_override = mat
	_decorations.append(orb)
	add_child(orb)

# Volcano Core — dark basalt floor with glowing lava river overlay.
func _spawn_volcano_overlay(wx: float, wz: float) -> void:
	var overlay := _create_ground_quad(
		Vector3(wx, 0.07, wz),
		GameConstants.TILE_SCALE,
		GameConstants.VOLCANO_CORE_GLOW_COLOR
	)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GameConstants.VOLCANO_CORE_GLOW_COLOR
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.05)
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.material_override = mat
	_lava_overlays.append(overlay)
	add_child(overlay)

# Lava vent — small bright cone that pulses with heat.
func _spawn_lava_vent(wx: float, wz: float) -> void:
	var vent := _create_box(
		Vector3(wx, 1.0, wz),
		Vector3(0.8, 2.0, 0.8),
		Color(1.0, 0.3, 0.05)
	)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.1, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.05)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vent.material_override = mat
	_decorations.append(vent)
	add_child(vent)

# Sky Citadel — floating cloud platform with soft white pad.
func _spawn_sky_platform(wx: float, wz: float) -> void:
	var platform := _create_box(
		Vector3(wx, randf_range(6.0, 10.0), wz),
		Vector3(randf_range(2.0, 4.0), 0.4, randf_range(2.0, 4.0)),
		GameConstants.SKY_CITADEL_CLOUD_COLOR
	)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GameConstants.SKY_CITADEL_CLOUD_COLOR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	platform.material_override = mat
	_decorations.append(platform)
	add_child(platform)

	# Soft cloud shadow on the ground far below.
	var shadow := _create_ground_quad(
		Vector3(wx, 0.04, wz),
		2.5,
		Color(0.8, 0.85, 0.95, 40.0 / 255.0)
	)
	_decorations.append(shadow)
	add_child(shadow)

# Digital Grid — neon wireframe glitch cube.
func _spawn_digital_glitch(wx: float, wz: float) -> void:
	# Neon cube with wireframe-style material (emissive edges).
	var cube := _create_box(
		Vector3(wx, randf_range(1.0, 3.0), wz),
		Vector3(0.7, 0.7, 0.7),
		GameConstants.DIGITAL_GRID_NEON_COLOR
	)
	var mat := StandardMaterial3D.new()
	# Alternate between cyan and pink for cyberpunk duality.
	var use_pink := randf() < 0.5
	mat.albedo_color = Color(0.05, 0.05, 0.1)
	mat.emission_enabled = true
	mat.emission = GameConstants.DIGITAL_GRID_PINK_COLOR if use_pink else GameConstants.DIGITAL_GRID_NEON_COLOR
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cube.material_override = mat
	_decorations.append(cube)
	add_child(cube)

# Crystal Caverns — cluster of prism crystals cycling through rainbow colors.
func _spawn_crystal_cavern_cluster(wx: float, wz: float) -> void:
	var count: int = randi_range(2, 5)
	for _i in range(count):
		var prism_color: Color = GameConstants.CRYSTAL_CAVERNS_PRISM_COLORS[
			randi() % GameConstants.CRYSTAL_CAVERNS_PRISM_COLORS.size()
		]
		var height: float = randf_range(1.5, 4.0)
		var offset_x: float = randf_range(-1.0, 1.0)
		var offset_z: float = randf_range(-1.0, 1.0)
		var crystal := _create_box(
			Vector3(wx + offset_x, GameConstants.CRYSTAL_CAVERNS_HEIGHT + height / 2.0 + 0.5, wz + offset_z),
			Vector3(0.4, height, 0.4),
			prism_color
		)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = prism_color
		mat.emission_enabled = true
		mat.emission = prism_color
		mat.emission_energy_multiplier = 1.5
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		crystal.material_override = mat
		_decorations.append(crystal)
		add_child(crystal)

# Ancient Ruins — broken stone pillar with mossy tint.
func _spawn_ancient_pillar(wx: float, wz: float) -> void:
	var pillar_h: float = randf_range(2.5, 5.5)
	var pillar := _create_box(
		Vector3(wx, GameConstants.ANCIENT_RUINS_HEIGHT + pillar_h / 2.0 + 0.5, wz),
		Vector3(0.6, pillar_h, 0.6),
		GameConstants.ANCIENT_RUINS_STONE_COLOR
	)
	_decorations.append(pillar)
	add_child(pillar)
	# Occasional broken wall segment.
	if randf() < 0.4:
		var wall := _create_box(
			Vector3(wx, GameConstants.ANCIENT_RUINS_HEIGHT + 0.75, wz),
			Vector3(randf_range(1.5, 3.0), 1.5, 0.3),
			GameConstants.ANCIENT_RUINS_STONE_COLOR
		)
		_decorations.append(wall)
		add_child(wall)

# Underground — hanging stalactite from the ceiling.
func _spawn_stalactite(wx: float, wz: float) -> void:
	var h: float = randf_range(0.8, 2.5)
	# Position above the player's head in the cavern space.
	var stal := _create_box(
		Vector3(wx, GameConstants.UNDERGROUND_HEIGHT + 6.0 - h / 2.0, wz),
		Vector3(0.3, h, 0.3),
		Color(70.0 / 255.0, 60.0 / 255.0, 55.0 / 255.0)
	)
	_decorations.append(stal)
	add_child(stal)

# Underground — rising stalagmite from cavern floor.
func _spawn_stalagmite(wx: float, wz: float) -> void:
	var h: float = randf_range(0.6, 2.0)
	var stal := _create_box(
		Vector3(wx, GameConstants.UNDERGROUND_HEIGHT + h / 2.0 + 0.5, wz),
		Vector3(0.35, h, 0.35),
		Color(60.0 / 255.0, 55.0 / 255.0, 50.0 / 255.0)
	)
	_decorations.append(stal)
	add_child(stal)

# Underground — glowing fungus mushroom for ambient light.
func _spawn_underground_glow(wx: float, wz: float) -> void:
	var glow_colors: Array[Color] = [
		Color(0.6, 1.0, 0.3),
		Color(0.3, 0.8, 1.0),
		Color(1.0, 0.5, 0.9),
	]
	var col: Color = glow_colors[randi() % glow_colors.size()]
	var cap := _create_sphere(
		Vector3(wx, GameConstants.UNDERGROUND_HEIGHT + 0.8, wz),
		randf_range(0.4, 0.8),
		col
	)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cap.material_override = mat
	_decorations.append(cap)
	add_child(cap)

# ─── Mesh helpers ────────────────────────────────────────────────────────────

func _create_box(pos: Vector3, scale: Vector3, col: Color) -> MeshInstance3D:
	var box_mesh := BoxMesh.new()
	box_mesh.size = scale
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi

func _create_sphere(pos: Vector3, radius: float, col: Color) -> MeshInstance3D:
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = sphere_mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi

func _create_ground_quad(pos: Vector3, size: float, col: Color) -> MeshInstance3D:
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = plane_mesh
	mi.position = pos
	# PlaneMesh is already horizontal (XZ plane), perfect for ground overlays
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if col.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	mi.material_override = mat
	return mi