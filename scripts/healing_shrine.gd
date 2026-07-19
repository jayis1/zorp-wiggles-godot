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

# ── Discharge animation ── When the player touches the shrine, the crystal
#    does a quick scale-pop and the OmniLight flashes bright before fading
#    back to its ambient glow. The _process loop drives the crystal's scale
#    every frame (a sine pulse), so a direct scale tween would be overwritten.
#    Instead we tween a multiplier (_discharge_scale_mult) that _process
#    folds into the pulse — the pop layers on top of the breathing animation
#    without fighting it. Heal particles also burst on activation.
var _discharge_scale_mult: float = 1.0
var _discharge_light_energy: float = 0.0  # Extra light energy added on top of ambient

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

	# Collision shape is provided by the scene (ShrineCollision) — no need to create a duplicate.
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
		# Fold the discharge multiplier in so the activation pop layers on
		# top of the breathing pulse without fighting the per-frame scale set.
		var s: float = pulse * _discharge_scale_mult
		_crystal.scale = Vector3(s, s, s)

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
			_light.light_energy = 0.3 + _discharge_light_energy
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
			_light.light_energy = 1.0 + 0.3 * sin(_time * 3.0) + _discharge_light_energy

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if cooldown > 0.0:
		return

	# Heal the player
	cooldown = GameConstants.SHRINE_COOLDOWN
	# ── Phase 34: Survival mode — no shrine healing ──
	GameManager.block_heal_next_call()
	GameManager.heal(GameConstants.SHRINE_HEAL_AMOUNT)
	if GameModeManager and GameModeManager.is_survival():
		GameManager.add_message("☠ Survival: Shrine healing suppressed!")
	else:
		GameManager.add_message("Healing Shrine! +%d HP" % GameConstants.SHRINE_HEAL_AMOUNT)
	heal_activated.emit(GameConstants.SHRINE_HEAL_AMOUNT)

	# Screen shake
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.1)

	# ── Discharge animation ── The crystal pops in scale and the OmniLight
	#    flashes bright, then both ease back to their ambient state. The
	#    scale pop is driven via _discharge_scale_mult (tweened here, folded
	#    into the breathing pulse by _process) so it doesn't fight the
	#    per-frame scale set. The light flash adds extra energy on top of
	#    the ambient glow, also via _process. Together they give the heal a
	#    satisfying "discharge" read — the shrine visibly expends energy.
	_play_discharge_animation()
	# Heal particles — green sparkle burst rising from the crystal.
	if ParticleEffects:
		ParticleEffects.spawn_pickup_sparkle(get_parent(), global_position + Vector3(0, 3.0, 0),
			GameConstants.SHRINE_CRYSTAL_COLOR)

## Play the activation discharge: crystal scale-pop + light flash burst.
## The scale multiplier snaps to 1.5 (a sharp "snap" to the pop peak) then
## eases back to 1.0 with an elastic settle so the crystal wobbles back to
## its breathing pulse. The light energy spikes to 4.0 then fades to 0 over
## 0.5s (ease-out-quad) so the flash is punchy then gentle. Both tweens are
## independent (no tracking needed) because the multiplier/energy are simple
## floats that _process reads each frame — a new activation while a previous
## tween is still running just restarts the values from the snap point.
func _play_discharge_animation() -> void:
	# Scale pop: snap to 1.5, elastic settle back to 1.0.
	_discharge_scale_mult = 1.5
	var scale_tween := create_tween()
	scale_tween.tween_property(self, "_discharge_scale_mult", 1.0, 0.45) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	# Light flash: spike to 4.0 extra energy, fade to 0 over 0.5s.
	_discharge_light_energy = 4.0
	var light_tween := create_tween()
	light_tween.tween_property(self, "_discharge_light_energy", 0.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

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