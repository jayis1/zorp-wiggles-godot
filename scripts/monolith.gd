## Zorp Wiggles — Alien Monolith
## A mysterious ancient structure that grants temporary buffs when the player approaches.
## Found in crystal and snow biomes.
## Ported from the AlienMonolith class in Ursina game.py.
## All colors use Godot 0-1 range.

extends Area3D

signal buff_activated(buff_type: String, duration: float)

# ─── Buff types ──────────────────────────────────────────────────────────────
enum BuffType { SPEED, DAMAGE, XP }

const BUFF_NAMES: Dictionary = {
	BuffType.SPEED: "Speed Surge",
	BuffType.DAMAGE: "Power Surge",
	BuffType.XP: "Wisdom Aura",
}

const BUFF_COLORS: Dictionary = {
	BuffType.SPEED: Color(50.0 / 255.0, 1.0, 50.0 / 255.0),
	BuffType.DAMAGE: Color(1.0, 100.0 / 255.0, 50.0 / 255.0),
	BuffType.XP: Color(100.0 / 255.0, 200.0 / 255.0, 1.0),
}

# ─── State ───────────────────────────────────────────────────────────────────
var cooldown: float = 0.0
var _bob_offset: float = 0.0
var _glow_phase: float = 0.0
var _active_buff: int = -1
var _time: float = 0.0

# ─── Child nodes ─────────────────────────────────────────────────────────────
var _body: MeshInstance3D
var _cap: MeshInstance3D
var _ring: MeshInstance3D
var _ground_glow: MeshInstance3D
var _runes: Array[MeshInstance3D] = []

func _ready() -> void:
	_bob_offset = randf() * TAU
	_glow_phase = randf() * TAU
	_build_visuals()

	# Collision shape is provided by the scene (MonolithCollision) — no need to create a duplicate.
	body_entered.connect(_on_body_entered)

func _build_visuals() -> void:
	# Main monolith body — tall thin structure
	_body = _create_box(
		Vector3(0, 3.0, 0),
		Vector3(0.8, 6.0, 0.8),
		GameConstants.MONOLITH_BODY_COLOR
	)
	add_child(_body)

	# Top crystal cap — prism shape (use sphere for now as diamond proxy)
	_cap = _create_sphere(
		Vector3(0, 6.5, 0),
		1.2,
		GameConstants.MONOLITH_CAP_COLOR
	)
	add_child(_cap)

	# Floating ring around the monolith
	_ring = _create_ring(
		Vector3(0, 4.0, 0),
		3.0,
		Color(150.0 / 255.0, 100.0 / 255.0, 1.0, 80.0 / 255.0)
	)
	add_child(_ring)

	# Ground glow disc
	_ground_glow = _create_ground_disc(
		Vector3(0, 0.1, 0),
		4.0,
		Color(150.0 / 255.0, 100.0 / 255.0, 1.0, 30.0 / 255.0)
	)
	add_child(_ground_glow)

	# Side rune panels — decorative markings on 4 sides
	for angle_deg in [0, 90, 180, 270]:
		var rad: float = deg_to_rad(angle_deg)
		var rune := _create_box(
			Vector3(cos(rad) * 0.5, 3.0, sin(rad) * 0.5),
			Vector3(0.6, 2.5, 0.05),
			Color(180.0 / 255.0, 140.0 / 255.0, 220.0 / 255.0)
		)
		# Rotate rune to face outward
		rune.rotate_y(rad)
		_runes.append(rune)
		add_child(rune)

func _process(delta: float) -> void:
	_time += delta

	# Pulse the cap crystal
	if _cap:
		var pulse: float = 0.8 + 0.4 * sin(_time * 3.0 + _glow_phase)
		_cap.scale = Vector3(pulse, pulse, pulse)

	# Rotate ring
	if _ring:
		_ring.rotate_y(deg_to_rad(90.0 * delta))

	# Update cooldown and visuals
	if cooldown > 0.0:
		cooldown -= delta
		# Dimmed state
		var dim_alpha: float = (40.0 + 20.0 * sin(_time * 2.0)) / 255.0
		if _cap:
			var mat: StandardMaterial3D = _cap.material_override
			if mat:
				mat.albedo_color = Color(80.0 / 255.0, 60.0 / 255.0, 100.0 / 255.0)
		if _ring:
			var mat2: StandardMaterial3D = _ring.material_override
			if mat2:
				mat2.albedo_color = Color(80.0 / 255.0, 60.0 / 255.0, 100.0 / 255.0, dim_alpha)
		if _ground_glow:
			var mat3: StandardMaterial3D = _ground_glow.material_override
			if mat3:
				mat3.albedo_color = Color(80.0 / 255.0, 60.0 / 255.0, 100.0 / 255.0, 15.0 / 255.0)
		# If we have an active buff, blend body color toward buff color (dimmed)
		if _active_buff >= 0:
			var bc: Color = BUFF_COLORS.get(_active_buff, GameConstants.MONOLITH_BODY_COLOR)
			var dim_bc: Color = Color(bc.r * 0.4, bc.g * 0.4, bc.b * 0.4)
			if _body:
				var mat4: StandardMaterial3D = _body.material_override
				if mat4:
					mat4.albedo_color = dim_bc
		else:
			if _body:
				var mat5: StandardMaterial3D = _body.material_override
				if mat5:
					mat5.albedo_color = Color(60.0 / 255.0, 45.0 / 255.0, 80.0 / 255.0)
	else:
		# Active/ready state — glowing
		if _active_buff >= 0:
			var bc: Color = BUFF_COLORS.get(_active_buff, GameConstants.MONOLITH_CAP_COLOR)
			var glow_a: float = (100.0 + 50.0 * sin(_time * 4.0)) / 255.0
			if _cap:
				var mat: StandardMaterial3D = _cap.material_override
				if mat:
					mat.albedo_color = bc
			if _ring:
				var mat2: StandardMaterial3D = _ring.material_override
				if mat2:
					mat2.albedo_color = Color(bc.r, bc.g, bc.b, glow_a)
			if _ground_glow:
				var mat3: StandardMaterial3D = _ground_glow.material_override
				if mat3:
					mat3.albedo_color = Color(bc.r, bc.g, bc.b, 40.0 / 255.0)
		else:
			# Default purple glow
			var bright_a: float = (80.0 + 40.0 * sin(_time * 3.0)) / 255.0
			if _cap:
				var mat: StandardMaterial3D = _cap.material_override
				if mat:
					mat.albedo_color = Color(180.0 / 255.0, 140.0 / 255.0, 1.0)
			if _ring:
				var mat2: StandardMaterial3D = _ring.material_override
				if mat2:
					mat2.albedo_color = Color(150.0 / 255.0, 100.0 / 255.0, 1.0, bright_a)
			if _ground_glow:
				var mat3: StandardMaterial3D = _ground_glow.material_override
				if mat3:
					mat3.albedo_color = Color(150.0 / 255.0, 100.0 / 255.0, 1.0, 30.0 / 255.0)
			if _body:
				var mat4: StandardMaterial3D = _body.material_override
				if mat4:
					mat4.albedo_color = GameConstants.MONOLITH_BODY_COLOR

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if cooldown > 0.0:
		return

	# Check if player already has all buffs active
	if GameConstants.MONOLITH_SKIP_IF_ALL_BUFFS_ACTIVE:
		if GameManager.active_buffs.has("speed") and \
		   GameManager.active_buffs.has("damage") and \
		   GameManager.active_buffs.has("xp"):
			return  # Don't waste a cooldown

	# Activate a random buff
	var buff: int = randi() % 3
	_active_buff = buff
	cooldown = GameConstants.MONOLITH_COOLDOWN

	var buff_name: String = BUFF_NAMES[buff]
	var buff_key: String = ["speed", "damage", "xp"][buff]
	var buff_color: Color = BUFF_COLORS[buff]
	GameManager.add_message("🔮 Monolith activated: %s! (+%ds)" % [buff_name, int(GameConstants.MONOLITH_BUFF_DURATION)])

	# Audio feedback — warm chime for buff activation.
	AudioManager.play_sfx(AudioManager.SFX_HEAL)

	# Apply buff to GameManager
	GameManager.active_buffs[buff_key] = GameConstants.MONOLITH_BUFF_DURATION

	# Flash body with buff color
	if _body:
		var mat: StandardMaterial3D = _body.material_override
		if mat:
			mat.albedo_color = buff_color

	# ── Phase 7: Buff activation visual effect ──
	# Spawn an upward beam of particles in the buff color + light flash
	_spawn_buff_activation_effect(buff_color)

	# Apply buff to player if the method exists
	if body.has_method("apply_monolith_buff"):
		body.apply_monolith_buff(buff_key, GameConstants.MONOLITH_BUFF_DURATION)

	buff_activated.emit(buff_key, GameConstants.MONOLITH_BUFF_DURATION)

	# Screen shake
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.15)

func _spawn_buff_activation_effect(color: Color) -> void:
	# Upward beam of buff-colored particles
	var particles := GPUParticles3D.new()
	particles.amount = 40
	particles.lifetime = 1.2
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 0.8
	particles.local_coords = false

	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 25.0
	pmat.gravity = Vector3(0, -3.0, 0)
	pmat.initial_velocity_min = 6.0
	pmat.initial_velocity_max = 12.0
	pmat.scale_min = 0.15
	pmat.scale_max = 0.35
	pmat.color = color
	particles.process_material = pmat

	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	var smat := StandardMaterial3D.new()
	smat.albedo_color = color
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.emission_enabled = true
	smat.emission = color * 0.8
	sphere.material = smat
	particles.draw_pass_1 = sphere

	add_child(particles)
	particles.global_position = global_position + Vector3(0, 1, 0)

	# Auto-free after particles expire
	var tree := get_tree()
	if tree:
		tree.create_timer(2.0).timeout.connect(particles.queue_free)

	# Brief light flash in buff color
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = 8.0
	add_child(light)
	light.global_position = global_position + Vector3(0, 4, 0)
	var light_tween := create_tween()
	light_tween.tween_property(light, "light_energy", 0.0, 1.0).set_ease(Tween.EASE_OUT)
	light_tween.parallel().tween_property(light, "omni_range", 2.0, 1.0).set_ease(Tween.EASE_IN)
	light_tween.tween_callback(light.queue_free)

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