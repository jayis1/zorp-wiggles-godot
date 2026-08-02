## Zorp Wiggles — GPU Particle Effects System (Phase 6: Particle Effects & Juice)
## Provides static factory methods for spawning GPU-based particle effects.
## All effects use GPUParticles3D for performance (not individual Node3D spawning).
## Effects: explosion, level-up shockwave, combo fireworks, pickup sparkle,
## enemy death poof, movement trail, ambient biome particles, sky beam,
## shield break, damage flash.

extends Node

class_name ParticleEffects

# ─── Shared Resources ──────────────────────────────────────────────────────────
# Explosion particles are spawned at ~9/sec during combat (79 call sites across
# the codebase). Each spawn previously allocated a new SphereMesh +
# StandardMaterial3D + ParticleProcessMaterial + Gradient + GradientTexture1D.
# The SphereMesh geometry is identical every call — sharing it eliminates the
# per-explosion mesh allocation, the single most frequent GPU resource churn in
# the game. The template materials are duplicated per-call (cheaper than
# new+configure) so each explosion can tween its color independently.
static var _shared_explosion_mesh: SphereMesh = null
static var _shared_explosion_proc_mat_template: ParticleProcessMaterial = null
static var _shared_explosion_draw_mat_template: StandardMaterial3D = null

# Shared sparkle mesh for spawn_pickup_sparkle (called from ~14 sites, often
# during mass pickups). Same geometry every call — sharing eliminates per-spark
# SphereMesh allocation. The draw material is duplicated from the explosion
# template (same unshaded + emission setup, just recolored).
static var _shared_sparkle_mesh: SphereMesh = null

# ── Fade-ramp cache ── _create_fade_ramp is called from every spawn_* method
#    and creates a Gradient + GradientTexture1D each time. Many calls use the
#    same color pair (e.g. explosion fade always uses color → color*0.3 for a
#    given enemy type), so caching by a color-pair key eliminates the vast
#    majority of Gradient/GradientTexture1D allocations during combat.
#    The cache is keyed by a string built from the rounded color components;
#    rounding to 2 decimal places avoids floating-point key misses while still
#    deduplicating the common cases. The cache is capped to prevent unbounded
#    growth from unique colors (e.g. randomly tinted effects).
static var _fade_ramp_cache: Dictionary = {}  # key_string -> GradientTexture1D
const FADE_RAMP_CACHE_MAX: int = 64

# ── Shared mesh templates for high-frequency effects ──────────────────────────
# These effects are called on every enemy death, level-up, shield break, and
# dash. Each previously allocated a new SphereMesh/BoxMesh + StandardMaterial3D
# per call. The geometry is identical every call — only the color differs, and
# that's handled by duplicating the material template (cheaper than new +
# configure). The templates are created once on first use and reused across
# all subsequent calls, eliminating per-spawn geometry allocation for the most
# frequent particle effects in the game.
static var _shared_death_poof_mesh: SphereMesh = null
static var _shared_fireworks_mesh: SphereMesh = null
static var _shared_levelup_ring_mesh: CylinderMesh = null
static var _shared_levelup_spark_mesh: SphereMesh = null
static var _shared_shield_break_mesh: BoxMesh = null
static var _shared_dash_trail_mesh: SphereMesh = null

static func _ensure_shared_particle_meshes() -> void:
	if _shared_death_poof_mesh == null:
		_shared_death_poof_mesh = SphereMesh.new()
		_shared_death_poof_mesh.radius = 0.2
		_shared_death_poof_mesh.height = 0.4
		_shared_death_poof_mesh.radial_segments = 6
		_shared_death_poof_mesh.rings = 3
	if _shared_fireworks_mesh == null:
		_shared_fireworks_mesh = SphereMesh.new()
		_shared_fireworks_mesh.radius = 0.12
		_shared_fireworks_mesh.height = 0.24
		_shared_fireworks_mesh.radial_segments = 4
		_shared_fireworks_mesh.rings = 2
	if _shared_levelup_ring_mesh == null:
		_shared_levelup_ring_mesh = CylinderMesh.new()
		_shared_levelup_ring_mesh.top_radius = 0.0
		_shared_levelup_ring_mesh.bottom_radius = 1.0
		_shared_levelup_ring_mesh.height = 0.1
		_shared_levelup_ring_mesh.radial_segments = 32
		_shared_levelup_ring_mesh.rings = 2
	if _shared_levelup_spark_mesh == null:
		_shared_levelup_spark_mesh = SphereMesh.new()
		_shared_levelup_spark_mesh.radius = 0.1
		_shared_levelup_spark_mesh.height = 0.2
		_shared_levelup_spark_mesh.radial_segments = 4
		_shared_levelup_spark_mesh.rings = 2
	if _shared_shield_break_mesh == null:
		_shared_shield_break_mesh = BoxMesh.new()
		_shared_shield_break_mesh.size = Vector3(0.15, 0.15, 0.15)
	if _shared_dash_trail_mesh == null:
		_shared_dash_trail_mesh = SphereMesh.new()
		_shared_dash_trail_mesh.radius = 0.3
		_shared_dash_trail_mesh.height = 0.6
		_shared_dash_trail_mesh.radial_segments = 6
		_shared_dash_trail_mesh.rings = 3

static func _ensure_shared_explosion_resources() -> void:
	if _shared_explosion_mesh == null:
		_shared_explosion_mesh = SphereMesh.new()
		_shared_explosion_mesh.radius = 0.15
		_shared_explosion_mesh.height = 0.3
		_shared_explosion_mesh.radial_segments = 6
		_shared_explosion_mesh.rings = 3
	if _shared_explosion_proc_mat_template == null:
		_shared_explosion_proc_mat_template = ParticleProcessMaterial.new()
		_shared_explosion_proc_mat_template.direction = Vector3(0, 1, 0)
		_shared_explosion_proc_mat_template.spread = 35.0
		_shared_explosion_proc_mat_template.gravity = Vector3(0, -5, 0)
		_shared_explosion_proc_mat_template.initial_velocity_min = 5.0
		_shared_explosion_proc_mat_template.initial_velocity_max = 15.0
		_shared_explosion_proc_mat_template.scale_min = 0.3
		_shared_explosion_proc_mat_template.scale_max = 1.0
	if _shared_explosion_draw_mat_template == null:
		_shared_explosion_draw_mat_template = StandardMaterial3D.new()
		_shared_explosion_draw_mat_template.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_explosion_draw_mat_template.emission_enabled = true
		_shared_explosion_draw_mat_template.emission_energy_multiplier = 1.5

static func _ensure_shared_sparkle_mesh() -> void:
	if _shared_sparkle_mesh == null:
		_shared_sparkle_mesh = SphereMesh.new()
		_shared_sparkle_mesh.radius = 0.08
		_shared_sparkle_mesh.height = 0.16
		_shared_sparkle_mesh.radial_segments = 4
		_shared_sparkle_mesh.rings = 2
	# The draw material template is needed for the per-call material duplicate.
	_ensure_shared_explosion_resources()

# ─── Particle Presets ─────────────────────────────────────────────────────────

## Spawn an explosion particle burst at the given position.
## Uses GPUParticles3D with a sphere emission shape and gravity.
static func spawn_explosion(parent: Node, pos: Vector3, color: Color = Color(1.0, 0.5, 0.1),
		particle_count: int = 30, lifetime: float = 0.8) -> GPUParticles3D:
	_ensure_shared_explosion_resources()
	var particles := GPUParticles3D.new()
	particles.amount = particle_count
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 0.9
	particles.randomness = 0.3
	particles.local_coords = false  # World space so particles stay after free

	# Process material — duplicate the shared template (cheaper than new +
	# configure 8 properties) and set the per-call color + ramp.
	var mat := _shared_explosion_proc_mat_template.duplicate() as ParticleProcessMaterial
	mat.color = color
	mat.color_ramp = _create_fade_ramp(color, color * 0.3)
	particles.process_material = mat

	# Mesh — duplicate the shared SphereMesh so each explosion gets its own
	# mesh instance (the geometry arrays are shared via Resource reference-
	# counting, but the material property is per-clone). This is cheaper than
	# creating a new SphereMesh + setting 4 geometry properties from scratch.
	# The draw-pass material is duplicated from the template (cheaper than
	# new + configure) and tinted to the explosion color.
	var mesh := _shared_explosion_mesh.duplicate() as SphereMesh
	var mat3d := _shared_explosion_draw_mat_template.duplicate() as StandardMaterial3D
	mat3d.albedo_color = color
	mat3d.emission = color * 0.8
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
	# Use shared level-up ring mesh template — eliminates per-level-up
	# CylinderMesh allocation. The mesh is duplicated so the per-call material
	# is isolated. The template already has the correct cone shape (top=0,
	# bottom=1) and 32 radial segments for a smooth ring.
	_ensure_shared_particle_meshes()
	var ring_mesh := _shared_levelup_ring_mesh.duplicate() as CylinderMesh
	var mat := _shared_explosion_draw_mat_template.duplicate() as StandardMaterial3D
	mat.albedo_color = Color(1.0, 0.843, 0.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission = Color(1.0, 0.8, 0.0) * 0.5
	ring_mesh.material = mat
	ring.mesh = ring_mesh
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

	# Use shared level-up spark mesh template — eliminates per-level-up
	# SphereMesh allocation for the upward sparkle particles.
	var mesh := _shared_levelup_spark_mesh.duplicate() as SphereMesh
	var smat := _shared_explosion_draw_mat_template.duplicate() as StandardMaterial3D
	smat.albedo_color = Color(1.0, 0.9, 0.3)
	smat.emission = Color(1.0, 0.9, 0.3) * 0.6
	mesh.material = smat
	particles.draw_pass_1 = mesh

	parent.add_child(particles)
	particles.global_position = pos
	_free_after_lifetime(particles, 1.5)

## Spawn combo milestone fireworks: 6-color particle burst.
static func spawn_combo_fireworks(parent: Node, pos: Vector3, tier: int = 1) -> void:
	var colors := [
		Color(1.0, 0.235, 0.235),
		Color(0.235, 0.784, 1.0),
		Color(1.0, 0.843, 0.196),
		Color(0.784, 0.314, 1.0),
		Color(0.235, 1.0, 0.314),
		Color(1.0, 0.588, 0.863),
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

	# Use shared fireworks mesh template — eliminates per-fireworks SphereMesh
	# allocation. The mesh is duplicated so the per-call material is isolated.
	_ensure_shared_particle_meshes()
	var mesh := _shared_fireworks_mesh.duplicate() as SphereMesh
	var smat := _shared_explosion_draw_mat_template.duplicate() as StandardMaterial3D
	smat.albedo_color = color
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

	# Reuse a dedicated shared sparkle SphereMesh (same geometry every call).
	# Duplicate so the per-call draw material is isolated. The draw material
	# is duplicated from the explosion template (same unshaded + emission
	# setup) and recolored to the sparkle color.
	_ensure_shared_sparkle_mesh()
	var mesh := _shared_sparkle_mesh.duplicate() as SphereMesh
	var smat := _shared_explosion_draw_mat_template.duplicate() as StandardMaterial3D
	smat.albedo_color = color
	smat.emission = color * 0.6
	mesh.material = smat
	particles.draw_pass_1 = mesh

	parent.add_child(particles)
	particles.global_position = pos
	_free_after_lifetime(particles, 1.0)

## Spawn a directional hit-spark burst at the impact point. Fires on every
## enemy hit (~9/sec during combat) — a small, short-lived burst of tiny
## sparks that shoot outward from the hit point, biased toward the source
## direction (e.g. the player). This adds a classic Vlambeer-style "spark
## spray" on impact that complements the existing hit-flash + squash, giving
## each landed shot a tactile "I hit something" particle read.
## Uses the shared sparkle mesh (tiny spheres) for zero per-hit geometry
## allocation. The spark color matches the enemy's base color so the spray
## reads as "bits of the enemy flying off" rather than a generic white flash.
## `source_pos` biases the spray direction so sparks shoot back toward the
## shooter (away from the enemy), reinforcing the shot's direction.
static func spawn_hit_spark(parent: Node, pos: Vector3, color: Color = Color(1.0, 1.0, 0.8),
		source_pos: Vector3 = Vector3.ZERO) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 8
	particles.lifetime = 0.18
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 1.0  # All at once — instant spark burst
	particles.local_coords = false

	var pmat := ParticleProcessMaterial.new()
	# Default direction: upward. If a source position is provided, bias the
	# direction toward the source so sparks shoot back toward the shooter.
	var spark_dir := Vector3(0, 0.5, 0)  # Slight upward bias by default
	if source_pos != Vector3.ZERO:
		var bias := (source_pos - pos)
		bias.y = 0.0
		if bias.length_squared() > 0.01:
			spark_dir = bias.normalized()
			spark_dir.y = 0.3  # Slight upward component so sparks arc
	pmat.direction = spark_dir
	pmat.spread = 45.0  # Narrow-ish cone for a directional spray
	pmat.gravity = Vector3(0, -8, 0)  # Strong gravity — sparks fall fast
	pmat.initial_velocity_min = 4.0
	pmat.initial_velocity_max = 10.0
	pmat.scale_min = 0.05  # Very tiny sparks
	pmat.scale_max = 0.12
	pmat.color = color
	# Quick fade to dark so sparks twinkle out fast (sharp, not lingering)
	pmat.color_ramp = _create_fade_ramp(color, Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.0))
	particles.process_material = pmat

	# Reuse the shared sparkle mesh (tiny spheres) — same geometry every call.
	_ensure_shared_sparkle_mesh()
	var mesh := _shared_sparkle_mesh.duplicate() as SphereMesh
	var smat := _shared_explosion_draw_mat_template.duplicate() as StandardMaterial3D
	smat.albedo_color = color
	smat.emission = color * 0.8  # Bright emission so sparks glow
	mesh.material = smat
	particles.draw_pass_1 = mesh

	parent.add_child(particles)
	particles.global_position = pos
	_free_after_lifetime(particles, 0.4)  # Short — sparks die fast

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

	# Use shared death-poof mesh template — eliminates per-death SphereMesh
	# allocation. The mesh is duplicated (cheap reference-counted copy) so the
	# per-call material is isolated. Geometry is identical across all deaths.
	_ensure_shared_particle_meshes()
	var mesh := _shared_death_poof_mesh.duplicate() as SphereMesh
	# Scale the mesh radius/height for this enemy's size. duplicate() gives
	# us our own copy so we can safely mutate radius/height without affecting
	# the shared template.
	mesh.radius = 0.2 * scale
	mesh.height = 0.4 * scale
	var smat := _shared_explosion_draw_mat_template.duplicate() as StandardMaterial3D
	smat.albedo_color = color
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

## Spawn a flat expanding ring when an enemy finishes materializing (spawn
## grace period ends). This is the spawn counterpart to the death shockwave —
## a quick ground ring that expands outward from the enemy's position, selling
## the "teleport-in complete, now active" moment. The ring uses the enemy's
## color so it reads as an energy discharge from the enemy itself, not a
## generic effect. Smaller and faster than the death shockwave (spawn is a
## beginning, not a climax) — 0.35s expand vs 0.4s, max radius 3.0 vs 6.0.
static func spawn_spawn_ring(parent: Node, pos: Vector3, color: Color = Color(0.5, 1.0, 0.8),
		max_radius: float = 3.0) -> void:
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 1.0
	ring_mesh.bottom_radius = 1.0
	ring_mesh.height = 0.06
	ring_mesh.radial_segments = 20
	ring_mesh.rings = 2
	ring.mesh = ring_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.6)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color * 0.5
	mat.emission_energy_multiplier = 1.8
	ring.material_override = mat
	parent.add_child(ring)
	ring.global_position = pos + Vector3(0, 0.04, 0)
	ring.scale = Vector3.ONE * 0.2
	# Expand + fade — ease-out cubic for a sharp burst that decelerates.
	# The ring snaps out fast (teleport energy discharge) then fades gently.
	var ring_tween := ring.create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector3(max_radius, 1.0, max_radius), 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ring_tween.tween_property(mat, "albedo_color:a", 0.0, 0.35) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	ring_tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.35) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	ring_tween.chain().tween_callback(ring.queue_free)
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

	# Use shared shield-break mesh template — eliminates per-break BoxMesh
	# allocation. The mesh is duplicated so the per-call material is isolated.
	_ensure_shared_particle_meshes()
	var mesh := _shared_shield_break_mesh.duplicate() as BoxMesh
	var smat := _shared_explosion_draw_mat_template.duplicate() as StandardMaterial3D
	smat.albedo_color = color
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

	# Use shared dash-trail mesh template — eliminates per-dash SphereMesh
	# allocation. The mesh is duplicated so the per-call material is isolated.
	_ensure_shared_particle_meshes()
	var mesh := _shared_dash_trail_mesh.duplicate() as SphereMesh
	var smat := _shared_explosion_draw_mat_template.duplicate() as StandardMaterial3D
	smat.albedo_color = Color(color.r, color.g, color.b, 0.5)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
## Results are cached by color pair — many spawn_* calls use the same fade
## colors (e.g. every explosion of the same enemy type), so the cache avoids
## redundant Gradient + GradientTexture1D allocation during sustained combat.
static func _create_fade_ramp(start_color: Color, end_color: Color) -> GradientTexture1D:
	# Build a cache key from the rounded color components. Rounding to 2
	# decimal places avoids FP key misses while deduplicating common pairs.
	var key: String = "%.2f,%.2f,%.2f,%.2f|%.2f,%.2f,%.2f,%.2f" % [
		start_color.r, start_color.g, start_color.b, start_color.a,
		end_color.r, end_color.g, end_color.b, end_color.a,
	]
	if _fade_ramp_cache.has(key):
		return _fade_ramp_cache[key]
	var ramp := Gradient.new()
	ramp.set_color(0, start_color)
	ramp.set_color(1, end_color)
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	# Cap the cache to prevent unbounded growth from unique color pairs.
	if _fade_ramp_cache.size() >= FADE_RAMP_CACHE_MAX:
		# Evict the first inserted entry (FIFO eviction — simple and
		# predictable; the common pairs will be re-cached quickly).
		var first_key: Variant = _fade_ramp_cache.keys()[0]
		_fade_ramp_cache.erase(first_key)
	_fade_ramp_cache[key] = tex
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

	# ── Golden light beam ── A vertical golden light pillar at the player's
	# position that gives the level-up a "power surge" visual — the alien
	# equivalent of a level-up beam. Uses the existing spawn_sky_beam helper
	# (already used for boss deaths and rare pickups) with golden coloring
	# and a shorter height (12m vs 30m for boss deaths) so it reads as a
	# personal celebration, not a world-shaking event. Paired with the
	# OmniLight flash below for a double-layered golden column.
	spawn_sky_beam(parent, pos, Color(1.0, 0.85, 0.2), 12.0)

	# ── Golden OmniLight flash ── A brief golden light at the player's
	# position that illuminates the surroundings, making the level-up
	# visible even in dark biomes. Brighter and wider than the death flash
	# because level-up is a positive, celebratory moment.
	var gold_light := OmniLight3D.new()
	gold_light.light_color = Color(1.0, 0.85, 0.3)
	gold_light.light_energy = 6.0
	gold_light.omni_range = 12.0
	gold_light.omni_attenuation = 1.0
	parent.add_child(gold_light)
	gold_light.global_position = pos + Vector3(0, 1, 0)
	var gold_light_tween := gold_light.create_tween()
	gold_light_tween.tween_property(gold_light, "light_energy", 0.0, 0.8) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	gold_light_tween.chain().tween_callback(gold_light.queue_free)

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

	# Sharp box fragments — use shared shield-break mesh template
	_ensure_shared_particle_meshes()
	var mesh := _shared_shield_break_mesh.duplicate() as BoxMesh
	# Scale up for the larger shatter fragments
	mesh.size = Vector3(0.2, 0.2, 0.2)
	var smat := _shared_explosion_draw_mat_template.duplicate() as StandardMaterial3D
	smat.albedo_color = color
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

# ── Enhancement: Low-HP heal pulse ──
# A green expanding ring + rising sparkles that plays when the player heals
# from critical HP (below 25%). This gives healing a visible "emergency save"
# feel — the player sees a green pulse radiate outward, reinforcing that they
# were in danger and just escaped. Distinct from the level-up shockwave (gold)
# and the combo fireworks (multi-color) so the player can identify the event
# by color alone. The ring uses ease-out expansion (fast burst, gentle
# deceleration) matching the pulse wave and shockwave visual language.
static func spawn_heal_pulse(parent: Node, pos: Vector3) -> void:
	# Green expanding ring
	var ring := GPUParticles3D.new()
	ring.amount = 60
	ring.lifetime = 0.6
	ring.one_shot = true
	ring.emitting = true
	ring.explosiveness = 1.0
	ring.local_coords = false
	var ring_mat := ParticleProcessMaterial.new()
	ring_mat.direction = Vector3(1, 0, 1)
	ring_mat.spread = 0.0
	ring_mat.gravity = Vector3.ZERO
	ring_mat.initial_velocity_min = 8.0
	ring_mat.initial_velocity_max = 12.0
	ring_mat.scale_min = 0.8
	ring_mat.scale_max = 1.5
	ring_mat.color = Color(0.3, 1.0, 0.4)
	ring_mat.color_ramp = _create_fade_ramp(
		Color(0.3, 1.0, 0.4), Color(0.1, 0.6, 0.2, 0.0))
	ring.process_material = ring_mat
	var ring_mesh := SphereMesh.new()
	ring_mesh.radius = 0.25
	ring_mesh.height = 0.1
	ring_mesh.radial_segments = 6
	ring_mesh.rings = 2
	var ring_mat3d := StandardMaterial3D.new()
	ring_mat3d.albedo_color = Color(0.3, 1.0, 0.4)
	ring_mat3d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat3d.emission_enabled = true
	ring_mat3d.emission = Color(0.2, 0.9, 0.3)
	ring_mat3d.emission_energy_multiplier = 2.0
	ring_mesh.material = ring_mat3d
	ring.draw_pass_1 = ring_mesh
	parent.add_child(ring)
	ring.global_position = pos
	_free_after_lifetime(ring, 0.8)

	# Rising green sparkles
	var sparkles := GPUParticles3D.new()
	sparkles.amount = 40
	sparkles.lifetime = 0.8
	sparkles.one_shot = true
	sparkles.emitting = true
	sparkles.explosiveness = 0.8
	sparkles.local_coords = false
	var sp_mat := ParticleProcessMaterial.new()
	sp_mat.direction = Vector3(0, 1, 0)
	sp_mat.spread = 25.0
	sp_mat.gravity = Vector3(0, -3, 0)
	sp_mat.initial_velocity_min = 5.0
	sp_mat.initial_velocity_max = 12.0
	sp_mat.scale_min = 0.1
	sp_mat.scale_max = 0.25
	sp_mat.color = Color(0.4, 1.0, 0.5)
	sp_mat.color_ramp = _create_fade_ramp(
		Color(0.4, 1.0, 0.5), Color(0.1, 0.5, 0.2, 0.0))
	sparkles.process_material = sp_mat
	var sp_mesh := SphereMesh.new()
	sp_mesh.radius = 0.08
	sp_mesh.height = 0.16
	var sp_mat3d := StandardMaterial3D.new()
	sp_mat3d.albedo_color = Color(0.4, 1.0, 0.5)
	sp_mat3d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sp_mat3d.emission_enabled = true
	sp_mat3d.emission = Color(0.3, 0.9, 0.4)
	sp_mat3d.emission_energy_multiplier = 1.5
	sp_mesh.material = sp_mat3d
	sparkles.draw_pass_1 = sp_mesh
	parent.add_child(sparkles)
	sparkles.global_position = pos
	_free_after_lifetime(sparkles, 1.0)

	# Soft green light flash
	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 1.0, 0.4)
	light.light_energy = 3.0
	light.omni_range = 6.0
	parent.add_child(light)
	light.global_position = pos
	var light_tween := light.create_tween()
	light_tween.tween_property(light, "light_energy", 0.0, 0.3).set_ease(Tween.EASE_OUT)
	light_tween.parallel().tween_property(light, "omni_range", 1.0, 0.3).set_ease(Tween.EASE_IN)
	light_tween.tween_callback(light.queue_free)