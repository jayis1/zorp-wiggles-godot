## Zorp Wiggles — Healing Crystal Shrine
## A glowing crystal shrine that heals the player when approached.
## Found in mushroom and swamp biomes — a safe haven in dangerous territory.
## Ported from the HealingCrystalShrine class in Ursina game.py.
## All colors use Godot 0-1 range.

extends Area3D

signal heal_activated(amount: int)

# ─── State ───────────────────────────────────────────────────────────────────
var cooldown: float = 0.0
var _bob_offset: float = 0.0
var _glow_phase: float = 0.0
var _time: float = 0.0

# ─── Child nodes ─────────────────────────────────────────────────────────────
var _base: MeshInstance3D
var _crystal: MeshInstance3D
var _ring: MeshInstance3D
var _ground_glow: MeshInstance3D
var _corner_crystals: Array[MeshInstance3D] = []
var _light: OmniLight3D

func _ready() -> void:
	_bob_offset = randf() * TAU
	_glow_phase = randf() * TAU
	_build_visuals()

	# Collision for activation detection
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 5.0, 4.0)
	col_shape.shape = box
	col_shape.position = Vector3(0, 2.5, 0)
	add_child(col_shape)

	body_entered.connect(_on_body_entered)

func _build_visuals() -> void:
	# Base platform — short stone-like cube
	_base = _create_box(
		Vector3(0, 0.5, 0),
		Vector3(2.0, 1.0, 2.0),
		Color(60.0 / 255.0, 80.0 / 255.0, 60.0 / 255.0)
	)
	add_child(_base)

	# Central healing crystal — tall glowing green crystal (prism shape proxy)
	_crystal = _create_sphere(
		Vector3(0, 3.0, 0),
		1.5,
		GameConstants.SHRINE_CRYSTAL_COLOR
	)
	add_child(_crystal)

	# Floating ring around the shrine
	_ring = _create_ring(
		Vector3(0, 2.5, 0),
		3.5,
		Color(100.0 / 255.0, 1.0, 150.0 / 255.0, 60.0 / 255.0)
	)
	add_child(_ring)

	# Ground glow disc — soft green light
	_ground_glow = _create_ground_disc(
		Vector3(0, 0.05, 0),
		5.0,
		Color(100.0 / 255.0, 1.0, 150.0 / 255.0, 30.0 / 255.0)
	)
	add_child(_ground_glow)

	# Four small corner crystals for decoration
	for angle_deg in [45, 135, 225, 315]:
		var rad: float = deg_to_rad(angle_deg)
		var cc := _create_sphere(
			Vector3(cos(rad) * 1.5, 1.2, sin(rad) * 1.5),
			0.6,
			Color(120.0 / 255.0, 220.0 / 255.0, 160.0 / 255.0)
		)
		_corner_crystals.append(cc)
		add_child(cc)

	# OmniLight for green glow
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 3.0, 0)
	_light.omni_range = 8.0
	_light.light_color = GameConstants.SHRINE_CRYSTAL_COLOR
	_light.light_energy = 1.0
	add_child(_light)

func _process(delta: float) -> void:
	_time += delta

	# Pulse the central crystal
	if _crystal:
		var pulse: float = 0.9 + 0.3 * sin(_time * 2.5 + _glow_phase)
		_crystal.scale = Vector3(pulse, pulse, pulse)

	# Rotate ring slowly
	if _ring:
		_ring.rotate_y(deg_to_rad(45.0 * delta))

	# Update cooldown and visuals
	if cooldown > 0.0:
		cooldown -= delta
		# Dimmed state — dormant, gray-green
		if _crystal:
			var mat: StandardMaterial3D = _crystal.material_override
			if mat:
				mat.albedo_color = Color(60.0 / 255.0, 100.0 / 255.0, 70.0 / 255.0)
		if _ring:
			var mat2: StandardMaterial3D = _ring.material_override
			if mat2:
				mat2.albedo_color = Color(60.0 / 255.0, 100.0 / 255.0, 70.0 / 255.0, 20.0 / 255.0)
		if _ground_glow:
			var mat3: StandardMaterial3D = _ground_glow.material_override
			if mat3:
				mat3.albedo_color = Color(60.0 / 255.0, 100.0 / 255.0, 70.0 / 255.0, 10.0 / 255.0)
		if _light:
			_light.light_energy = 0.3
	else:
		# Active/ready state — vibrant green glow
		var glow_a: float = (80.0 + 40.0 * sin(_time * 3.0)) / 255.0
		if _crystal:
			var mat: StandardMaterial3D = _crystal.material_override
			if mat:
				mat.albedo_color = Color(100.0 / 255.0, 1.0, 150.0 / 255.0)
		if _ring:
			var mat2: StandardMaterial3D = _ring.material_override
			if mat2:
				mat2.albedo_color = Color(100.0 / 255.0, 1.0, 150.0 / 255.0, glow_a)
		if _ground_glow:
			var mat3: StandardMaterial3D = _ground_glow.material_override
			if mat3:
				mat3.albedo_color = Color(100.0 / 255.0, 1.0, 150.0 / 255.0, 30.0 / 255.0)
		if _light:
			_light.light_energy = 1.0 + 0.3 * sin(_time * 3.0)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if cooldown > 0.0:
		return

	# Heal the player
	cooldown = GameConstants.SHRINE_COOLDOWN
	GameManager.heal(GameConstants.SHRINE_HEAL_AMOUNT)
	GameManager.add_message("Healing Shrine! +%d HP" % GameConstants.SHRINE_HEAL_AMOUNT)
	heal_activated.emit(GameConstants.SHRINE_HEAL_AMOUNT)

	# Screen shake
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.1)

# ─── Mesh helpers ────────────────────────────────────────────────────────────

func _create_box(pos: Vector3, scale: Vector3, col: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = scale
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi

func _create_sphere(pos: Vector3, radius: float, col: Color) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi

func _create_ring(pos: Vector3, size: float, col: Color) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi

func _create_ground_disc(pos: Vector3, size: float, col: Color) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi