## Zorp Wiggles — Portal
## A linked portal pair for fast travel across the world.
## Stepping into one portal teleports the player to its linked partner.
## Ported from the Portal class in Ursina game.py.
## All colors use Godot 0-1 range.

extends Area3D

signal teleport_used(portal: Node3D, destination: Vector3)

# ─── Export properties ───────────────────────────────────────────────────────
@export var partner_position: Vector3 = Vector3.ZERO
@export var portal_id: int = 0

# ─── State ───────────────────────────────────────────────────────────────────
var cooldown: float = 0.0
var _bob_offset: float = 0.0
var _time: float = 0.0

# ─── Child nodes ─────────────────────────────────────────────────────────────
var _inner_ring: MeshInstance3D
var _outer_ring: MeshInstance3D
var _ground_glow: MeshInstance3D
var _pillars: Array[MeshInstance3D] = []

func _ready() -> void:
	_bob_offset = randf() * TAU
	_build_visuals()
	add_to_group("portals")

	# Collision shape is provided by the scene (PortalCollision) — no need to create a duplicate.
	body_entered.connect(_on_body_entered)

func _build_visuals() -> void:
	# Inner ring (cyan) — main visual, facing up
	_inner_ring = _create_ring(
		Vector3(0, 2.5, 0),
		3.0,
		GameConstants.PORTAL_INNER_COLOR
	)
	add_child(_inner_ring)

	# Outer ring (purple) — glow border
	_outer_ring = _create_ring(
		Vector3(0, 2.5, 0),
		3.5,
		GameConstants.PORTAL_OUTER_COLOR
	)
	add_child(_outer_ring)

	# Ground glow disc
	_ground_glow = _create_ground_disc(
		Vector3(0, 0.1, 0),
		4.0,
		GameConstants.PORTAL_GROUND_GLOW_COLOR
	)
	add_child(_ground_glow)

	# Four pillar markers at cardinal directions
	for angle_deg in [0, 90, 180, 270]:
		var rad: float = deg_to_rad(angle_deg)
		var pillar := _create_box(
			Vector3(cos(rad) * 1.8, 1.5, sin(rad) * 1.8),
			Vector3(0.25, 3.0, 0.25),
			GameConstants.PORTAL_PILLAR_COLOR
		)
		_pillars.append(pillar)
		add_child(pillar)

func _process(delta: float) -> void:
	_time += delta

	# Inner ring spins and pulses
	if _inner_ring:
		_inner_ring.rotate_y(deg_to_rad(120.0 * delta))
		var pulse: float = 3.0 + sin(_time * 4.0 + _bob_offset) * 0.3
		_inner_ring.scale = Vector3(pulse, pulse, pulse)

	# Outer ring counter-rotates
	if _outer_ring:
		_outer_ring.rotate_y(deg_to_rad(-80.0 * delta))
		var pulse_outer: float = 3.5 + sin(_time * 4.0 + _bob_offset) * 0.3
		_outer_ring.scale = Vector3(pulse_outer, pulse_outer, pulse_outer)

	# Ground glow pulses
	if _ground_glow:
		var ground_pulse: float = 4.0 + sin(_time * 3.0 + _bob_offset) * 0.5
		_ground_glow.scale = Vector3(ground_pulse, ground_pulse, ground_pulse)

	# Update cooldown and dim/dim visuals
	if cooldown > 0.0:
		cooldown -= delta
		# Dimmed state during cooldown
		if _inner_ring:
			var mat: StandardMaterial3D = _inner_ring.material_override
			if mat:
				mat.albedo_color = Color(0.0, 100.0 / 255.0, 100.0 / 255.0, 80.0 / 255.0)
		if _outer_ring:
			var mat2: StandardMaterial3D = _outer_ring.material_override
			if mat2:
				mat2.albedo_color = Color(50.0 / 255.0, 0.0, 100.0 / 255.0, 30.0 / 255.0)
	else:
		# Vibrant state — ready to teleport
		if _inner_ring:
			var mat: StandardMaterial3D = _inner_ring.material_override
			if mat:
				mat.albedo_color = GameConstants.PORTAL_INNER_COLOR
		if _outer_ring:
			var mat2: StandardMaterial3D = _outer_ring.material_override
			if mat2:
				mat2.albedo_color = GameConstants.PORTAL_OUTER_COLOR

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if cooldown > 0.0:
		return
	if partner_position == Vector3.ZERO:
		return

	# Teleport the player to the partner portal
	cooldown = GameConstants.PORTAL_COOLDOWN
	var player: CharacterBody3D = body as CharacterBody3D
	if player:
		# Preserve Y position offset
		player.global_position = partner_position + Vector3(0, 0.5, 0)
		teleport_used.emit(self, partner_position)
		GameManager.add_message("Portal teleport!")
		# Audio feedback — rift whoosh on teleport.
		AudioManager.play_sfx(AudioManager.SFX_RIFT)

	# Screen shake on teleport
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.2)

# ─── Mesh helpers ────────────────────────────────────────────────────────────

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