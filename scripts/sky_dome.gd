## Zorp Wiggles — Sky Dome
## Creates the alien sky: gradient dome, twinkling starfield, nebula clouds, horizon glow.
## Ported from the sky/star/nebula generation in Ursina game.py.
## All colors use Godot 0-1 range.

extends Node3D

# ─── Internal star data ──────────────────────────────────────────────────────
class StarData:
	var mesh: MeshInstance3D
	var base_brightness: float
	var twinkle_speed: float
	var twinkle_offset: float
	var base_color: Color
	var base_scale: float

class NebulaData:
	var mesh: MeshInstance3D
	var drift_speed: float
	var drift_phase: float
	var base_pos: Vector3

var _stars: Array[StarData] = []
var _nebula_clouds: Array[NebulaData] = []
var _sky_quads: Array[MeshInstance3D] = []
var _horizon_glows: Array[MeshInstance3D] = []
var _time: float = 0.0

# ─── Shared resources ────────────────────────────────────────────────────────
var _unlit_mat: StandardMaterial3D
var _star_mat: StandardMaterial3D

func _ready() -> void:
	_create_materials()
	_build_sky_dome()
	_build_stars()
	_build_nebula()
	_build_horizon_glow()

func _create_materials() -> void:
	_unlit_mat = StandardMaterial3D.new()
	_unlit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_unlit_mat.vertex_color_use_as_albedo = true
	_unlit_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_star_mat = StandardMaterial3D.new()
	_star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_star_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _build_sky_dome() -> void:
	# Build 3 layers × 8 billboard quads = 24 sky panels forming a gradient dome.
	var sky_layers: Array = [
		{"t": 0.0, "y": GameConstants.SKY_HEIGHT_MAX + 20.0, "radius": GameConstants.SKY_RADIUS * 0.5},
		{"t": 0.5, "y": (GameConstants.SKY_HEIGHT_MAX + GameConstants.SKY_HEIGHT_MIN) / 2.0, "radius": GameConstants.SKY_RADIUS * 0.75},
		{"t": 1.0, "y": GameConstants.SKY_HEIGHT_MIN, "radius": GameConstants.SKY_RADIUS},
	]

	for layer in sky_layers:
		var t: float = layer["t"]
		var y_pos: float = layer["y"]
		var radius: float = layer["radius"]
		# Lerp between top and horizon colors
		var col: Color = GameConstants.SKY_TOP_COLOR.lerp(GameConstants.SKY_HORIZON_COLOR, t)

		for angle_deg in range(0, 360, 45):
			var rad: float = deg_to_rad(angle_deg)
			var qx: float = cos(rad) * radius
			var qz: float = sin(rad) * radius
			var quad := _create_billboard_quad(
				Vector3(qx, y_pos, qz),
				Vector2(GameConstants.SKY_RADIUS * 0.6, GameConstants.SKY_RADIUS * 0.5),
				col
			)
			_sky_quads.append(quad)
			add_child(quad)

func _build_stars() -> void:
	# Spawn twinkling stars with varied colors across the sky.
	for i in range(GameConstants.STAR_COUNT):
		var angle_h: float = randf() * TAU
		var angle_v: float = randf_range(0.15, PI * 0.45)
		var dist: float = randf_range(GameConstants.STAR_HEIGHT_MIN, GameConstants.STAR_HEIGHT_MAX)
		var sx: float = cos(angle_h) * cos(angle_v) * GameConstants.STAR_SPREAD
		var sy: float = abs(sin(angle_v)) * dist + GameConstants.STAR_HEIGHT_MIN
		var sz: float = sin(angle_h) * cos(angle_v) * GameConstants.STAR_SPREAD

		var brightness: float = randf_range(0.5, 1.0)
		var star_size: float = randf_range(1.0, 3.0)
		var twinkle_speed: float = randf_range(2.0, 6.0)
		var twinkle_offset: float = randf() * TAU
		var base_color: Color = GameConstants.STAR_COLORS[i % GameConstants.STAR_COLORS.size()]

		# Apply brightness to color
		var star_col: Color = Color(
			base_color.r * brightness,
			base_color.g * brightness,
			base_color.b * brightness,
			brightness
		)

		var star_mesh := _create_billboard_quad(
			Vector3(sx, sy, sz),
			Vector2(star_size, star_size),
			star_col
		)
		add_child(star_mesh)

		var data := StarData.new()
		data.mesh = star_mesh
		data.base_brightness = brightness
		data.twinkle_speed = twinkle_speed
		data.twinkle_offset = twinkle_offset
		data.base_color = base_color
		data.base_scale = star_size
		_stars.append(data)

func _build_nebula() -> void:
	# Spawn large translucent nebula clouds for atmospheric depth.
	for i in range(GameConstants.NEBULA_CLOUD_COUNT):
		var angle_h: float = randf() * TAU
		var ny: float = randf_range(GameConstants.NEBULA_HEIGHT_MIN, GameConstants.NEBULA_HEIGHT_MAX)
		var nx: float = randf_range(-GameConstants.NEBULA_SPREAD, GameConstants.NEBULA_SPREAD)
		var nz: float = randf_range(-GameConstants.NEBULA_SPREAD, GameConstants.NEBULA_SPREAD)
		var nebula_size: float = randf_range(30.0, 80.0)
		var nebula_color: Color = GameConstants.NEBULA_COLORS[i % GameConstants.NEBULA_COLORS.size()]
		# Translucent
		nebula_color.a = 25.0 / 255.0

		var cloud := _create_billboard_quad(
			Vector3(nx, ny, nz),
			Vector2(nebula_size, nebula_size),
			nebula_color
		)
		add_child(cloud)

		var data := NebulaData.new()
		data.mesh = cloud
		data.drift_speed = randf_range(0.1, 0.4)
		data.drift_phase = randf() * TAU
		data.base_pos = Vector3(nx, ny, nz)
		_nebula_clouds.append(data)

func _build_horizon_glow() -> void:
	# Spawn horizon glow band — translucent colored quads at low altitude.
	var horizon_palette: Array[Color] = GameConstants.NEBULA_COLORS  # reuse same palette

	for i in range(GameConstants.HORIZON_GLOW_COUNT):
		var angle_h: float = randf() * TAU
		var gx: float = cos(angle_h) * GameConstants.HORIZON_GLOW_SPREAD
		var gz: float = sin(angle_h) * GameConstants.HORIZON_GLOW_SPREAD
		var gy: float = randf_range(GameConstants.HORIZON_GLOW_HEIGHT_MIN, GameConstants.HORIZON_GLOW_HEIGHT_MAX)
		var glow_size: float = randf_range(60.0, 120.0)
		var glow_color: Color = horizon_palette[i % horizon_palette.size()]
		glow_color.a = GameConstants.HORIZON_GLOW_ALPHA_BASE + randf_range(-10.0, 10.0) / 255.0

		var glow := _create_billboard_quad(
			Vector3(gx, gy, gz),
			Vector2(glow_size, glow_size),
			glow_color
		)
		add_child(glow)
		_horizon_glows.append(glow)

func _create_billboard_quad(pos: Vector3, size: Vector2, col: Color) -> MeshInstance3D:
	# Create a simple billboard quad mesh at the given position with the given color.
	var quad_mesh := PlaneMesh.new()
	quad_mesh.size = size
	# Rotate to face up (for ground-lying quads) or keep vertical for billboard
	var mi := MeshInstance3D.new()
	mi.mesh = quad_mesh
	mi.position = pos

	# Use a per-instance material with vertex color
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if col.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	mi.material_override = mat

	return mi

func _process(delta: float) -> void:
	_time += delta

	# Twinkle stars
	for star in _stars:
		var twinkle: float = 0.7 + 0.3 * sin(_time * star.twinkle_speed + star.twinkle_offset)
		var col: Color = star.base_color
		col.a = star.base_brightness * twinkle
		var mat: StandardMaterial3D = star.mesh.material_override
		if mat:
			mat.albedo_color = col
		# Scale twinkle
		var s: float = star.base_scale * (0.8 + 0.2 * twinkle)
		star.mesh.scale = Vector3(s, s, s)

	# Drift nebula clouds
	for cloud in _nebula_clouds:
		var drift: float = sin(_time * cloud.drift_speed + cloud.drift_phase) * 5.0
		cloud.mesh.position = cloud.base_pos + Vector3(drift, 0.0, drift * 0.5)