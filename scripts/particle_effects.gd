## Zorp Wiggles — GPU Particle Effects System (Phase 6: Particle Effects & Juice)
## Provides static factory methods for spawning GPU-based particle effects.
## All effects use GPUParticles3D for performance (not individual Node3D spawning).
## Effects: explosion, level-up shockwave, combo fireworks, pickup sparkle,
## enemy death poof, movement trail, ambient biome particles, sky beam,
## shield break, damage flash.

extends Node

class_name ParticleEffects

# ─── Particle Presets ─────────────────────────────────────────────────────────

## Spawn an explosion particle burst at the given position.
## Uses GPUParticles3D with a sphere emission shape and gravity.
static func spawn_explosion(parent: Node, pos: Vector3, color: Color = Color(1.0, 0.5, 0.1),
		particle_count: int = 30, lifetime: float = 0.8) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = particle_count
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 0.9
	particles.randomness = 0.3
	particles.local_coords = false  # World space so particles stay after free

	# Process material — explosion with gravity
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 35.0
	mat.gravity = Vector3(0, -5, 0)
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.scale_min = 0.3
	mat.scale_max = 1.0
	mat.color = color
	# Fade out over lifetime
	mat.color_ramp = _create_fade_ramp(color, color * 0.3)
	particles.process_material = mat

	# Mesh — small spheres
	var mesh := SphereMesh.new()
	mesh.radius = 0.15
	mesh.height = 0.3
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat3d := StandardMaterial3D.new()
	mat3d.albedo_color = color
	mat3d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat3d.emission_enabled = true
	mat3d.emission = color * 0.8
	mat3d.emission_energy_multiplier = 1.5
	mesh.material = mat3d
	particles.mesh = mesh

	parent.add_child(particles)
	particles.global_position = pos

	# Auto-free after particles finish
	_free_after_lifetime(particles, lifetime + 0.5)
	return particles

## Spawn a level-up shockwave: expanding ring + upward sparkle particles.
static func spawn_levelup_burst(parent: Node, pos: Vector3) -> void:
	# Expanding ring (tween-based)
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.0
	ring_mesh.bottom_radius = 1.0
	ring_mesh.height = 0.1
	ring_mesh.radial_segments = 32
	ring_mesh.rings = 2
	ring.mesh = ring_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 215.0 / 255.0, 0.0, 0.8)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.0) * 0.5
	ring.material_override = mat
	ring.rotate_x(deg_to_rad(90))  # Lay flat
	parent.add_child(ring)
	ring.global_position = pos

	var ring_tween := ring.create_tween()
	ring_tween.tween_property(ring, "scale", Vector3(8, 8, 1), 0.5) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_CUBIC)
	ring_tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.5)
	ring_tween.chain().tween_callback(ring.queue_free)

	# Upward sparkle particles
	var particles := GPUParticles3D.new()
	particles.amount = 40
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 0.8
	particles.local_coords = false

	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 15.0
	pmat.gravity = Vector3(0, -3, 0)
	pmat.initial_velocity_min = 8.0
	pmat.initial_velocity_max = 15.0
	pmat.scale_min = 0.2
	pmat.scale_max = 0.5
	pmat.color = Color(1.0, 0.9, 0.3)
	pmat.color_ramp = _create_fade_ramp(Color(1.0, 0.9, 0.3), Color(1.0, 0.4, 0.0))
	particles.process_material = pmat

	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	mesh.radial_segments = 4
	mesh.rings = 2
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(1.0, 0.9, 0.3)
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.9, 0.3) * 0.6
	mesh.material = smat
	particles.mesh = mesh

	parent.add_child(particles)
	particles.global_position = pos
	_free_after_lifetime(particles, 1.5)

## Spawn combo milestone fireworks: 6-color particle burst.
static func spawn_combo_fireworks(parent: Node, pos: Vector3, tier: int = 1) -> void:
	var colors := [
		Color(1.0, 60.0 / 255.0, 60.0 / 255.0),
		Color(60.0 / 255.0, 200.0 / 255.0, 1.0),
		Color(1.0, 215.0 / 255.0, 50.0 / 255.0),
		Color(200.0 / 255.0, 80.0 / 255.0, 1.0),
		Color(60.0 / 255.0, 1.0, 80.0 / 255.0),
		Color(255.0 / 255.0, 150.0 / 255.0, 220.0 / 255.0),
	]
	var color: Color = colors[(tier - 1) % colors.size()]

	var particles := GPUParticles3D.new()
	particles.amount = 50
	particles.lifetime = 1.2
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 1.0
	particles.randomness = 0.5
	particles.local_coords = false

	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 180.0  # Full sphere burst
	pmat.gravity = Vector3(0, -8, 0)
	pmat.initial_velocity_min = 10.0
	pmat.initial_velocity_max = 20.0
	pmat.scale_min = 0.15
	pmat.scale_max = 0.4
	pmat.color = color
	pmat.color_ramp = _create_fade_ramp(color, Color(color.r * 0.2, color.g * 0.2, color.b * 0.2))
	particles.process_material = pmat

	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 4
	mesh.rings = 2
	var smat := StandardMaterial3D.new()
	smat.albedo_color = color
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.emission_enabled = true
	smat.emission = color * 0.8
	mesh.material = smat
	particles.mesh = mesh

	parent.add_child(particles)
	particles.global_position = pos + Vector3(0, 1, 0)
	_free_after_lifetime(particles, 1.8)

## Spawn pickup sparkle burst — small upward sparkles when collecting an item.
static func spawn_pickup_sparkle(parent: Node, pos: Vector3, color: Color = Color(0.4, 1.0, 0.6)) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 15
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 0.8
	particles.local_coords = false

	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 30.0
	pmat.gravity = Vector3(0, -2, 0)
	pmat.initial_velocity_min = 3.0
	pmat.initial_velocity_max = 8.0
	pmat.scale_min = 0.1
	pmat.scale_max = 0.25
	pmat.color = color
	pmat.color_ramp = _create_fade_ramp(color, Color(color.r * 0.3, color.g * 0.3, color.b * 0.3))
	particles.process_material = pmat

	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	mesh.radial_segments = 4
	mesh.rings = 2
	var smat := StandardMaterial3D.new()
	smat.albedo_color = color
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.emission_enabled = true
	smat.emission = color * 0.6
	mesh.material = smat
	particles.mesh = mesh

	parent.add_child(particles)
	particles.global_position = pos
	_free_after_lifetime(particles, 1.0)

## Spawn enemy death poof — dark smoke that expands and fades.
static func spawn_death_poof(parent: Node, pos: Vector3, color: Color = Color(0.8, 0.2, 0.2),
		scale: float = 1.0) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = int(25 * scale)
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 0.9
	particles.local_coords = false

	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 60.0
	pmat.gravity = Vector3(0, -1, 0)
	pmat.initial_velocity_min = 3.0 * scale
	pmat.initial_velocity_max = 8.0 * scale
	pmat.scale_min = 0.3 * scale
	pmat.scale_max = 0.8 * scale
	pmat.color = color
	pmat.color_ramp = _create_fade_ramp(color, Color(0.1, 0.1, 0.1, 0.0))
	particles.process_material = pmat

	var mesh := SphereMesh.new()
	mesh.radius = 0.2 * scale
	mesh.height = 0.4 * scale
	mesh.radial_segments = 6
	mesh.rings = 3
	var smat := StandardMaterial3D.new()
	smat.albedo_color = color
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.emission_enabled = true
	smat.emission = color * 0.4
	mesh.material = smat
	particles.mesh = mesh

	parent.add_child(particles)
	particles.global_position = pos
	_free_after_lifetime(particles, 0.9)

## Spawn a vertical sky beam — tall light column for rare pickups.
static func spawn_sky_beam(parent: Node, pos: Vector3, color: Color = Color(1.0, 0.9, 0.3),
		height: float = 30.0) -> void:
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.5
	cyl.height = height
	cyl.radial_segments = 12
	cyl.rings = 2
	beam.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.4)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color * 0.8
	mat.emission_energy_multiplier = 2.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = mat
	parent.add_child(beam)
	beam.global_position = pos + Vector3(0, height / 2.0, 0)

	# Animate: fade in fast, hold, fade out
	var tween := beam.create_tween()
	mat.albedo_color.a = 0.0
	tween.tween_property(mat, "albedo_color:a", 0.6, 0.15)
	tween.tween_interval(0.4)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tween.tween_callback(beam.queue_free)

	# Add sparkle particles at base
	spawn_pickup_sparkle(parent, pos, color)

## Spawn shield break shatter — fragment burst when a shield/invuln breaks.
static func spawn_shield_break(parent: Node, pos: Vector3, color: Color = Color(0.3, 0.8, 1.0)) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 30
	particles.lifetime = 0.7
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 1.0
	particles.randomness = 0.4
	particles.local_coords = false

	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 0, 0)
	pmat.spread = 180.0
	pmat.gravity = Vector3(0, -6, 0)
	pmat.initial_velocity_min = 8.0
	pmat.initial_velocity_max = 16.0
	pmat.scale_min = 0.2
	pmat.scale_max = 0.5
	pmat.angular_velocity_min = 10.0
	pmat.angular_velocity_max = 20.0
	pmat.color = color
	pmat.color_ramp = _create_fade_ramp(color, Color(0.1, 0.1, 0.2, 0.0))
	particles.process_material = pmat

	# Use box mesh for "shard" fragments
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.15, 0.15)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = color
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.emission_enabled = true
	smat.emission = color * 0.5
	mesh.material = smat
	particles.mesh = mesh

	parent.add_child(particles)
	particles.global_position = pos
	_free_after_lifetime(particles, 1.2)

## Spawn movement trail particles — speed lines behind Zorp while dashing.
static func spawn_dash_trail(parent: Node, pos: Vector3, color: Color = Color(0.3, 0.85, 0.3)) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 8
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 0.5
	particles.local_coords = false

	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 0, 0)
	pmat.spread = 10.0
	pmat.gravity = Vector3.ZERO
	pmat.initial_velocity_min = 0.0
	pmat.initial_velocity_max = 1.0
	pmat.scale_min = 0.2
	pmat.scale_max = 0.4
	pmat.color = color
	pmat.color_ramp = _create_fade_ramp(Color(color.r, color.g, color.b, 0.6),
		Color(color.r, color.g, color.b, 0.0))
	particles.process_material = pmat

	var mesh := SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.6
	mesh.radial_segments = 6
	mesh.rings = 3
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(color.r, color.g, color.b, 0.5)
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.emission_enabled = true
	smat.emission = color * 0.4
	mesh.material = smat
	particles.mesh = mesh

	parent.add_child(particles)
	particles.global_position = pos
	_free_after_lifetime(particles, 0.5)

## Spawn ambient biome particles — continuous weather/ambient effect.
## type: "snow", "embers", "spores", "bubbles", "dust"
static func create_ambient_particles(pos: Vector3, type: String) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 60
	particles.lifetime = 4.0
	particles.one_shot = false
	particles.emitting = true
	particles.local_coords = false

	var pmat := ParticleProcessMaterial.new()
	var color: Color = Color(1, 1, 1)
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 4
	mesh.rings = 2

	match type:
		"snow":
			pmat.direction = Vector3(0, -1, 0)
			pmat.spread = 5.0
			pmat.gravity = Vector3(0, -1, 0)
			pmat.initial_velocity_min = 1.0
			pmat.initial_velocity_max = 2.0
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_scale = 0.3
			color = Color(0.9, 0.95, 1.0, 0.8)
		"embers":
			pmat.direction = Vector3(0, 1, 0)
			pmat.spread = 20.0
			pmat.gravity = Vector3(0, 2, 0)
			pmat.initial_velocity_min = 1.0
			pmat.initial_velocity_max = 3.0
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_scale = 0.5
			color = Color(1.0, 0.5, 0.1, 0.7)
			mesh.radius = 0.03
			mesh.height = 0.06
		"spores":
			pmat.direction = Vector3(0, 0, 0)
			pmat.spread = 180.0
			pmat.gravity = Vector3(0, 0.3, 0)
			pmat.initial_velocity_min = 0.5
			pmat.initial_velocity_max = 1.5
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_scale = 0.8
			color = Color(0.7, 1.0, 0.3, 0.6)
		"bubbles":
			pmat.direction = Vector3(0, 1, 0)
			pmat.spread = 30.0
			pmat.gravity = Vector3(0, 1.5, 0)
			pmat.initial_velocity_min = 1.0
			pmat.initial_velocity_max = 3.0
			color = Color(0.3, 0.6, 1.0, 0.5)
		"dust":
			pmat.direction = Vector3(0, 0, 0)
			pmat.spread = 180.0
			pmat.gravity = Vector3.ZERO
			pmat.initial_velocity_min = 0.1
			pmat.initial_velocity_max = 0.5
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_scale = 0.2
			color = Color(0.6, 0.5, 0.4, 0.3)
		_:
			pmat.direction = Vector3(0, 1, 0)
			pmat.spread = 30.0
			pmat.gravity = Vector3.ZERO

	pmat.color = color
	pmat.scale_min = 0.5
	pmat.scale_max = 1.5
	particles.process_material = pmat

	var smat := StandardMaterial3D.new()
	smat.albedo_color = color
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.emission_enabled = true
	smat.emission = color * 0.3
	mesh.material = smat
	particles.mesh = mesh

	particles.global_position = pos
	return particles

# ─── Helpers ──────────────────────────────────────────────────────────────────

## Create a GradientTexture1D for particle color ramp (fade from start to end).
## ParticleProcessMaterial.color_ramp expects a Texture2D, not a bare Gradient.
static func _create_fade_ramp(start_color: Color, end_color: Color) -> GradientTexture1D:
	var ramp := Gradient.new()
	ramp.set_color(0, start_color)
	ramp.set_color(1, end_color)
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	return tex

## Auto-free a node after a delay (using a timer).
static func _free_after_lifetime(node: Node, delay: float) -> void:
	var timer := node.get_tree().create_timer(delay)
	timer.timeout.connect(node.queue_free)