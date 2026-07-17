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
	particles.draw_pass_1 = mesh

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
	# CylinderMesh axis is along Y; with height=0.1 it's already a flat disc
	# lying on the XZ plane. No rotation needed.
	parent.add_child(ring)
	ring.global_position = pos

	var ring_tween := ring.create_tween()
	# Scale X and Z (the radius in the XZ plane), keep Y (thickness) at 1
	ring_tween.tween_property(ring, "scale", Vector3(8, 1, 8), 0.5) \
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
	particles.draw_pass_1 = mesh

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
	particles.draw_pass_1 = mesh

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
	particles.draw_pass_1 = mesh

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
	particles.draw_pass_1 = mesh

	parent.add_child(particles)
	particles.global_position = pos
	_free_after_lifetime(particles, 0.9)

## Spawn a flat expanding shockwave ring on large enemy deaths. This is a
## purely visual effect (no gameplay Area3D) — a quick ring that expands
## outward from the death point and fades, giving large enemies a weighty
## death impact. Scale determines the ring's max radius. Used by enemies
## with base_scale >= 1.5 (Sentinels, Drakes, Crystal Guardians, Bombers).
static func spawn_death_shockwave(parent: Node, pos: Vector3, color: Color = Color(1.0, 0.5, 0.2),
		max_radius: float = 6.0) -> void:
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 1.0
	ring_mesh.bottom_radius = 1.0
	ring_mesh.height = 0.08
	ring_mesh.radial_segments = 24
	ring_mesh.rings = 2
	ring.mesh = ring_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.7)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color * 0.6
	mat.emission_energy_multiplier = 2.0
	ring.material_override = mat
	# CylinderMesh axis is along Y; with height=0.08 it's already a flat disc
	# lying on the XZ plane. No rotation needed.
	parent.add_child(ring)
	ring.global_position = pos + Vector3(0, 0.05, 0)
	ring.scale = Vector3.ONE * 0.3

	# Expand + fade with ease-out for a sharp burst that decelerates
	var ring_tween := ring.create_tween()
	ring_tween.set_parallel(true)
	# Scale X and Z (radius in XZ plane), keep Y (thickness) at 1
	ring_tween.tween_property(ring, "scale", Vector3(max_radius, 1.0, max_radius), 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ring_tween.tween_property(mat, "albedo_color:a", 0.0, 0.4) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	ring_tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.4) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	ring_tween.chain().tween_callback(ring.queue_free)

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
	particles.draw_pass_1 = mesh

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
	particles.draw_pass_1 = mesh

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
	particles.draw_pass_1 = mesh

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


# ─── Phase 11: GPU Particles — New Effects ────────────────────────────────────

## Spawn a mega explosion with 1000+ particles for boss deaths and big events.
## Multi-layered: core flash + expanding ring + debris + smoke + sparks.
static func spawn_mega_explosion(parent: Node, pos: Vector3,
		color: Color = Color(1.0, 0.4, 0.1), scale: float = 1.0) -> void:
	# Layer 1: Core flash — bright, fast, many particles
	var core := GPUParticles3D.new()
	core.amount = int(400 * scale)
	core.lifetime = 0.4
	core.one_shot = true
	core.emitting = true
	core.explosiveness = 1.0
	core.local_coords = false
	var core_mat := ParticleProcessMaterial.new()
	core_mat.direction = Vector3(0, 1, 0)
	core_mat.spread = 180.0
	core_mat.gravity = Vector3(0, -8, 0)
	core_mat.initial_velocity_min = 10.0
	core_mat.initial_velocity_max = 30.0
	core_mat.scale_min = 0.5
	core_mat.scale_max = 2.0
	core_mat.color = Color.WHITE
	core_mat.color_ramp = _create_fade_ramp(Color.WHITE, color)
	core.process_material = core_mat
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.3
	core_mesh.height = 0.6
	core_mesh.radial_segments = 6
	core_mesh.rings = 3
	var core_mat3d := StandardMaterial3D.new()
	core_mat3d.albedo_color = Color.WHITE
	core_mat3d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat3d.emission_enabled = true
	core_mat3d.emission = color
	core_mat3d.emission_energy_multiplier = 3.0
	core_mesh.material = core_mat3d
	core.draw_pass_1 = core_mesh
	parent.add_child(core)
	core.global_position = pos
	_free_after_lifetime(core, 1.0)

	# Layer 2: Expanding debris — chunks flying outward with gravity
	var debris := GPUParticles3D.new()
	debris.amount = int(300 * scale)
	debris.lifetime = 1.5
	debris.one_shot = true
	debris.emitting = true
	debris.explosiveness = 0.95
	debris.local_coords = false
	var deb_mat := ParticleProcessMaterial.new()
	deb_mat.direction = Vector3(0, 1, 0)
	deb_mat.spread = 45.0
	deb_mat.gravity = Vector3(0, -15, 0)
	deb_mat.initial_velocity_min = 15.0
	deb_mat.initial_velocity_max = 40.0
	deb_mat.scale_min = 0.3
	deb_mat.scale_max = 1.5
	deb_mat.color = color
	deb_mat.color_ramp = _create_fade_ramp(color, color * 0.2)
	debris.process_material = deb_mat
	var deb_mesh := BoxMesh.new()
	deb_mesh.size = Vector3(0.3, 0.3, 0.3)
	var deb_mat3d := StandardMaterial3D.new()
	deb_mat3d.albedo_color = color
	deb_mat3d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	deb_mat3d.emission_enabled = true
	deb_mat3d.emission = color * 0.5
	deb_mesh.material = deb_mat3d
	debris.draw_pass_1 = deb_mesh
	parent.add_child(debris)
	debris.global_position = pos
	_free_after_lifetime(debris, 2.0)

	# Layer 3: Rising smoke — dark, slow, expanding
	var smoke := GPUParticles3D.new()
	smoke.amount = int(200 * scale)
	smoke.lifetime = 3.0
	smoke.one_shot = true
	smoke.emitting = true
	smoke.explosiveness = 0.3
	smoke.local_coords = false
	var smoke_mat := ParticleProcessMaterial.new()
	smoke_mat.direction = Vector3(0, 1, 0)
	smoke_mat.spread = 30.0
	smoke_mat.gravity = Vector3(0, 3, 0)
	smoke_mat.initial_velocity_min = 2.0
	smoke_mat.initial_velocity_max = 6.0
	smoke_mat.scale_min = 1.0
	smoke_mat.scale_max = 4.0
	smoke_mat.color = Color(0.2, 0.15, 0.1, 0.6)
	smoke_mat.color_ramp = _create_fade_ramp(
		Color(0.3, 0.2, 0.15, 0.6), Color(0.1, 0.08, 0.05, 0.0))
	smoke.process_material = smoke_mat
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.8
	smoke_mesh.height = 1.6
	smoke_mesh.radial_segments = 6
	smoke_mesh.rings = 3
	var smoke_mat3d := StandardMaterial3D.new()
	smoke_mat3d.albedo_color = Color(0.3, 0.2, 0.15, 0.5)
	smoke_mat3d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat3d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mesh.material = smoke_mat3d
	smoke.draw_pass_1 = smoke_mesh
	parent.add_child(smoke)
	smoke.global_position = pos
	_free_after_lifetime(smoke, 3.5)

	# Layer 4: Sparks — small, fast, bright trails
	var sparks := GPUParticles3D.new()
	sparks.amount = int(150 * scale)
	sparks.lifetime = 0.8
	sparks.one_shot = true
	sparks.emitting = true
	sparks.explosiveness = 0.9
	sparks.local_coords = false
	var spark_mat := ParticleProcessMaterial.new()
	spark_mat.direction = Vector3(0, 1, 0)
	spark_mat.spread = 180.0
	spark_mat.gravity = Vector3(0, -12, 0)
	spark_mat.initial_velocity_min = 20.0
	spark_mat.initial_velocity_max = 50.0
	spark_mat.scale_min = 0.05
	spark_mat.scale_max = 0.15
	spark_mat.color = Color(1.0, 0.8, 0.3)
	spark_mat.color_ramp = _create_fade_ramp(Color(1.0, 0.9, 0.4), Color(1.0, 0.3, 0.0, 0.0))
	spark_mat.trail_size_min = 0.5
	spark_mat.trail_size_max = 1.5
	sparks.process_material = spark_mat
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.06
	spark_mesh.height = 0.12
	spark_mesh.radial_segments = 4
	spark_mesh.rings = 2
	var spark_mat3d := StandardMaterial3D.new()
	spark_mat3d.albedo_color = Color(1.0, 0.9, 0.4)
	spark_mat3d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat3d.emission_enabled = true
	spark_mat3d.emission = Color(1.0, 0.8, 0.3)
	spark_mat3d.emission_energy_multiplier = 2.0
	spark_mesh.material = spark_mat3d
	sparks.draw_pass_1 = spark_mesh
	parent.add_child(sparks)
	sparks.global_position = pos
	_free_after_lifetime(sparks, 1.2)


## Spawn boss death spectacle — the ultimate particle cascade.
## Combines mega explosion + sky beam + ring shockwave + slow-motion debris.
static func spawn_boss_death_spectacle(parent: Node, pos: Vector3,
		color: Color = Color(1.0, 0.0, 1.0), scale: float = 3.0) -> void:
	# Main mega explosion
	spawn_mega_explosion(parent, pos, color, scale)

	# Sky beam — vertical light column
	spawn_sky_beam(parent, pos, color)

	# Expanding ring shockwave (flat disc that grows)
	var ring := GPUParticles3D.new()
	ring.amount = 200
	ring.lifetime = 1.5
	ring.one_shot = true
	ring.emitting = true
	ring.explosiveness = 1.0
	ring.local_coords = false
	var ring_mat := ParticleProcessMaterial.new()
	ring_mat.direction = Vector3(1, 0, 1)
	ring_mat.spread = 0.0
	ring_mat.gravity = Vector3.ZERO
	ring_mat.initial_velocity_min = 15.0 * scale
	ring_mat.initial_velocity_max = 20.0 * scale
	ring_mat.scale_min = 2.0
	ring_mat.scale_max = 4.0
	ring_mat.color = color
	ring_mat.color_ramp = _create_fade_ramp(color, Color(color.r, color.g, color.b, 0.0))
	ring.process_material = ring_mat
	var ring_mesh := SphereMesh.new()
	ring_mesh.radius = 0.5
	ring_mesh.height = 0.1
	ring_mesh.radial_segments = 8
	ring_mesh.rings = 2
	var ring_mat3d := StandardMaterial3D.new()
	ring_mat3d.albedo_color = color
	ring_mat3d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat3d.emission_enabled = true
	ring_mat3d.emission = color
	ring_mat3d.emission_energy_multiplier = 2.0
	ring_mesh.material = ring_mat3d
	ring.draw_pass_1 = ring_mesh
	parent.add_child(ring)
	ring.global_position = pos
	_free_after_lifetime(ring, 2.0)


## Spawn enemy spawn materialization particles — energy coalescing into form.
## Particles converge from outside toward the spawn point.
static func spawn_materialization(parent: Node, pos: Vector3,
		color: Color = Color(0.5, 1.0, 0.8)) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 80
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 0.8
	particles.local_coords = false

	var mat := ParticleProcessMaterial.new()
	# Particles converge inward — negative velocity toward center
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.gravity = Vector3(0, -5, 0)
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.scale_min = 0.1
	mat.scale_max = 0.3
	mat.color = color
	mat.color_ramp = _create_fade_ramp(
		Color(color.r, color.g, color.b, 0.0), color)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat3d := StandardMaterial3D.new()
	mat3d.albedo_color = color
	mat3d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat3d.emission_enabled = true
	mat3d.emission = color * 0.8
	mat3d.emission_energy_multiplier = 2.0
	mesh.material = mat3d
	particles.draw_pass_1 = mesh

	parent.add_child(particles)
	particles.global_position = pos + Vector3(0, 1, 0)
	_free_after_lifetime(particles, 1.2)


## Spawn atmosphere particles — continuous ambient dust motes, pollen, or fireflies.
## Returns a GPUParticles3D that stays alive (caller manages lifecycle).
static func spawn_atmosphere(parent: Node, pos: Vector3, type: String) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 40
	particles.lifetime = 8.0
	particles.one_shot = false
	particles.emitting = true
	particles.local_coords = false

	var mat := ParticleProcessMaterial.new()
	var color: Color = Color(1, 1, 1, 0.3)
	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	mesh.radial_segments = 4
	mesh.rings = 2

	match type:
		"dust":
			mat.direction = Vector3(0, 0, 0)
			mat.spread = 180.0
			mat.gravity = Vector3.ZERO
			mat.initial_velocity_min = 0.1
			mat.initial_velocity_max = 0.3
			mat.turbulence_enabled = true
			mat.turbulence_noise_scale = 0.5
			mat.turbulence_influence_min = 0.2
			mat.turbulence_influence_max = 0.5
			color = Color(1.0, 0.95, 0.8, 0.2)
		"pollen":
			mat.direction = Vector3(0, 1, 0)
			mat.spread = 180.0
			mat.gravity = Vector3(0, 0.2, 0)
			mat.initial_velocity_min = 0.3
			mat.initial_velocity_max = 0.8
			mat.turbulence_enabled = true
			mat.turbulence_noise_scale = 1.0
			mat.turbulence_influence_min = 0.3
			mat.turbulence_influence_max = 0.6
			color = Color(1.0, 0.9, 0.3, 0.4)
			mesh.radius = 0.06
			mesh.height = 0.12
		"fireflies":
			mat.direction = Vector3(0, 0, 0)
			mat.spread = 180.0
			mat.gravity = Vector3.ZERO
			mat.initial_velocity_min = 0.5
			mat.initial_velocity_max = 1.5
			mat.turbulence_enabled = true
			mat.turbulence_noise_scale = 0.8
			mat.turbulence_influence_min = 0.5
			mat.turbulence_influence_max = 1.0
			color = Color(0.6, 1.0, 0.3, 0.8)
			mesh.radius = 0.08
			mesh.height = 0.16
		_:
			mat.direction = Vector3(0, 0, 0)
			mat.spread = 180.0
			mat.gravity = Vector3.ZERO
			mat.initial_velocity_min = 0.1
			mat.initial_velocity_max = 0.3

	mat.color = color
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	particles.process_material = mat

	var mat3d := StandardMaterial3D.new()
	mat3d.albedo_color = color
	mat3d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat3d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat3d.emission_enabled = true
	mat3d.emission = color * 0.5
	if type == "fireflies":
		mat3d.emission_energy_multiplier = 2.0
	mesh.material = mat3d
	particles.draw_pass_1 = mesh

	parent.add_child(particles)
	particles.global_position = pos
	return particles


## Spawn a projectile trail effect — continuous small particles behind a moving projectile.
## Returns a GPUParticles3D that the caller can reparent to the projectile.
static func spawn_projectile_trail(parent: Node, pos: Vector3,
		color: Color = Color(0.3, 1.0, 0.8)) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 30
	particles.lifetime = 0.3
	particles.one_shot = false
	particles.emitting = true
	particles.local_coords = false

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 10.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 0.0
	mat.initial_velocity_max = 0.5
	mat.scale_min = 0.1
	mat.scale_max = 0.2
	mat.color = color
	mat.color_ramp = _create_fade_ramp(color, Color(color.r, color.g, color.b, 0.0))
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat3d := StandardMaterial3D.new()
	mat3d.albedo_color = color
	mat3d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat3d.emission_enabled = true
	mat3d.emission = color * 0.6
	mesh.material = mat3d
	particles.draw_pass_1 = mesh

	parent.add_child(particles)
	particles.global_position = pos
	return particles


## Spawn a level-up shockwave ring — expanding golden ring + upward sparkles.
## This is the Phase 11 enhanced version using more particles.
static func spawn_levelup_shockwave(parent: Node, pos: Vector3) -> void:
	# Expanding ring
	var ring := GPUParticles3D.new()
	ring.amount = 100
	ring.lifetime = 0.8
	ring.one_shot = true
	ring.emitting = true
	ring.explosiveness = 1.0
	ring.local_coords = false
	var ring_mat := ParticleProcessMaterial.new()
	ring_mat.direction = Vector3(1, 0, 1)
	ring_mat.spread = 0.0
	ring_mat.gravity = Vector3.ZERO
	ring_mat.initial_velocity_min = 10.0
	ring_mat.initial_velocity_max = 15.0
	ring_mat.scale_min = 1.0
	ring_mat.scale_max = 2.0
	ring_mat.color = Color(1.0, 0.9, 0.3)
	ring_mat.color_ramp = _create_fade_ramp(
		Color(1.0, 0.9, 0.3), Color(1.0, 0.6, 0.0, 0.0))
	ring.process_material = ring_mat
	var ring_mesh := SphereMesh.new()
	ring_mesh.radius = 0.3
	ring_mesh.height = 0.1
	ring_mesh.radial_segments = 6
	ring_mesh.rings = 2
	var ring_mat3d := StandardMaterial3D.new()
	ring_mat3d.albedo_color = Color(1.0, 0.9, 0.3)
	ring_mat3d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat3d.emission_enabled = true
	ring_mat3d.emission = Color(1.0, 0.8, 0.2)
	ring_mat3d.emission_energy_multiplier = 2.0
	ring_mesh.material = ring_mat3d
	ring.draw_pass_1 = ring_mesh
	parent.add_child(ring)
	ring.global_position = pos
	_free_after_lifetime(ring, 1.0)

	# Upward sparkles
	var sparkles := GPUParticles3D.new()
	sparkles.amount = 80
	sparkles.lifetime = 1.2
	sparkles.one_shot = true
	sparkles.emitting = true
	sparkles.explosiveness = 0.8
	sparkles.local_coords = false
	var sp_mat := ParticleProcessMaterial.new()
	sp_mat.direction = Vector3(0, 1, 0)
	sp_mat.spread = 30.0
	sp_mat.gravity = Vector3(0, -5, 0)
	sp_mat.initial_velocity_min = 8.0
	sp_mat.initial_velocity_max = 20.0
	sp_mat.scale_min = 0.1
	sp_mat.scale_max = 0.3
	sp_mat.color = Color(1.0, 0.95, 0.5)
	sp_mat.color_ramp = _create_fade_ramp(
		Color(1.0, 0.95, 0.5), Color(1.0, 0.7, 0.1, 0.0))
	sparkles.process_material = sp_mat
	var sp_mesh := SphereMesh.new()
	sp_mesh.radius = 0.1
	sp_mesh.height = 0.2
	sp_mesh.radial_segments = 4
	sp_mesh.rings = 2
	var sp_mat3d := StandardMaterial3D.new()
	sp_mat3d.albedo_color = Color(1.0, 0.95, 0.5)
	sp_mat3d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sp_mat3d.emission_enabled = true
	sp_mat3d.emission = Color(1.0, 0.9, 0.3)
	sp_mat3d.emission_energy_multiplier = 2.5
	sp_mesh.material = sp_mat3d
	sparkles.draw_pass_1 = sp_mesh
	parent.add_child(sparkles)
	sparkles.global_position = pos
	_free_after_lifetime(sparkles, 1.5)

## ── Phase 6: Idle regen sparkle stream ──
## Ambient sparkles that orbit the player when idle and healthy.
## Returns the GPUParticles3D node so the caller can position it each frame.
## The caller should move it to follow the player and free it when done.
static func spawn_idle_regen_aura(parent: Node, pos: Vector3) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 12
	particles.lifetime = 2.5
	particles.one_shot = false
	particles.emitting = true
	particles.explosiveness = 0.0
	particles.randomness = 0.8
	particles.local_coords = false

	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 30.0
	pmat.gravity = Vector3(0, -1.0, 0)  # Gentle float
	pmat.initial_velocity_min = 0.3
	pmat.initial_velocity_max = 0.8
	pmat.scale_min = 0.08
	pmat.scale_max = 0.18
	pmat.angular_velocity_min = 2.0
	pmat.angular_velocity_max = 5.0
	pmat.color = Color(0.4, 1.0, 0.6, 0.7)
	# Fade in and out via color ramp
	var ramp := Gradient.new()
	ramp.add_point(0.0, Color(0.4, 1.0, 0.6, 0.0))
	ramp.add_point(0.3, Color(0.4, 1.0, 0.6, 0.8))
	ramp.add_point(0.7, Color(0.6, 1.0, 0.8, 0.6))
	ramp.add_point(1.0, Color(0.4, 1.0, 0.6, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pmat.color_ramp = ramp_tex
	particles.process_material = pmat

	# Small glowing sphere particles
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 6
	mesh.rings = 3
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.4, 1.0, 0.6)
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.emission_enabled = true
	smat.emission = Color(0.3, 1.0, 0.5)
	smat.emission_energy_multiplier = 2.0
	mesh.material = smat
	particles.draw_pass_1 = mesh

	parent.add_child(particles)
	particles.global_position = pos
	return particles

## ── Phase 6: Shield break shatter effect ──
## Fragment burst when a shield buff is broken — larger and more dramatic
## than the existing spawn_shield_break. Spawns sharp box fragments that
## fly outward and tumble, plus a bright light flash.
static func spawn_shield_break_shatter(parent: Node, pos: Vector3, color: Color = Color(0.3, 0.8, 1.0)) -> void:
	# Main fragment burst — 40 shards flying outward with tumble
	var particles := GPUParticles3D.new()
	particles.amount = 40
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 1.0
	particles.randomness = 0.5
	particles.local_coords = false

	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 0, 0)
	pmat.spread = 180.0
	pmat.gravity = Vector3(0, -8, 0)
	pmat.initial_velocity_min = 10.0
	pmat.initial_velocity_max = 22.0
	pmat.scale_min = 0.15
	pmat.scale_max = 0.45
	pmat.angular_velocity_min = 15.0
	pmat.angular_velocity_max = 30.0
	pmat.color = color
	# Fade out via ramp
	var ramp := Gradient.new()
	ramp.add_point(0.0, Color(color.r, color.g, color.b, 1.0))
	ramp.add_point(0.6, Color(color.r, color.g, color.b, 0.7))
	ramp.add_point(1.0, Color(0.1, 0.1, 0.15, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pmat.color_ramp = ramp_tex
	particles.process_material = pmat

	# Sharp box fragments
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.2, 0.2)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = color
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.emission_enabled = true
	smat.emission = color * 0.8
	smat.emission_energy_multiplier = 2.0
	mesh.material = smat
	particles.draw_pass_1 = mesh

	parent.add_child(particles)
	particles.global_position = pos
	_free_after_lifetime(particles, 1.5)

	# Bright light flash
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 6.0
	light.omni_range = 10.0
	parent.add_child(light)
	light.global_position = pos
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.4).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(light, "omni_range", 1.0, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_callback(light.queue_free)