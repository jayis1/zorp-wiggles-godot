## Zorp Wiggles — Pulse Wave (Q Ability)
## Expanding ring of energy that damages all nearby enemies.
## Ported from pulse wave logic in Ursina game.py.

extends Node3D

var radius: float = 0.0
var _prev_radius: float = 0.0  # Previous-frame radius for band-skip detection
var max_radius: float = GameConstants.PULSE_WAVE_RADIUS
var damage: int = GameConstants.PULSE_WAVE_DAMAGE
var expand_speed: float = 30.0
var has_hit: Dictionary = {}  # Track which enemies we've already hit
var _light: OmniLight3D = null
var _material: StandardMaterial3D = null

@onready var ring_mesh: MeshInstance3D = $RingMesh

# ─── Shared Ring Mesh ──────────────────────────────────────────────────────────
# The pulse wave ring mesh is the same every cast. Share it to avoid
# per-cast geometry allocation. The material is per-instance (alpha tweens).
static var _shared_ring_mesh: CylinderMesh = null

# ── Shared base material ── Duplicated per cast so each ring can tween its
#    alpha/emission independently without creating a full StandardMaterial3D
#    from scratch and setting 7+ properties every cast. Duplicate copies the
#    pre-configured property block in one shot — cheaper than new + configure.
#    Mirrors the shared-base-material pattern used by shockwave.gd and
#    impact_burst.gd.
static var _shared_material_base: StandardMaterial3D = null

# ── Ring spin ── The expanding ring is a flat cylinder that only scales X/Z.
#    Without rotation it reads as a static 2D hoop on the ground. Adding a fast
#    Y-axis spin makes the ring feel like rotating energy — a spinning shockwave
#    disk rather than a growing circle. The spin rate decays as the ring
#    expands so the energy "settles" as it dissipates, matching the ease-out
#    expansion curve. Uses wall-clock time so the spin is consistent regardless
#    of time-scale (hit-stop, Time-Slow dimension).
var _ring_spin_phase: float = 0.0
const RING_SPIN_SPEED: float = 12.0  # Rad/s at cast — decays with expansion

static func _ensure_shared_mesh() -> void:
	if _shared_ring_mesh == null:
		_shared_ring_mesh = CylinderMesh.new()
		_shared_ring_mesh.top_radius = 0.5
		_shared_ring_mesh.bottom_radius = 0.5
		_shared_ring_mesh.height = 0.1
		_shared_ring_mesh.radial_segments = 32
		_shared_ring_mesh.rings = 2
	if _shared_material_base == null:
		_shared_material_base = StandardMaterial3D.new()
		_shared_material_base.albedo_color = Color(0.3, 0.8, 1.0, 0.6)  # Cyan ring
		_shared_material_base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_material_base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shared_material_base.emission_enabled = true
		_shared_material_base.emission = Color(0.3, 0.8, 1.0) * 0.5
		_shared_material_base.emission_energy_multiplier = 1.5

func _ready() -> void:
	# Enhancement Pack 26: SFX on pulse wave fire — the player's Q ability
	# had visual particles + light flash but no audio. The SFX_PULSE_WAVE
	# is a sweeping energy wave sound that matches the expanding ring visual.
	AudioManager.play_sfx(AudioManager.SFX_PULSE_WAVE)
	# Create expanding ring visual
	if ring_mesh:
		_ensure_shared_mesh()
		ring_mesh.mesh = _shared_ring_mesh
		# Duplicate the shared base material so each cast can tween alpha/
		# emission independently. Cheaper than new + 7 property assignments.
		_material = _shared_material_base.duplicate() as StandardMaterial3D
		ring_mesh.material_override = _material

	# Center light flash — illuminates the area as the wave fires, fading as it expands
	_light = OmniLight3D.new()
	_light.light_color = Color(0.3, 0.8, 1.0)
	_light.light_energy = 3.0
	_light.omni_range = 8.0
	_light.omni_attenuation = 1.5
	add_child(_light)

# ── Phase 19: Co-op mega pulse wave — override radius/damage ──
func set_mega_params(mega_radius: float, mega_damage: int) -> void:
	max_radius = mega_radius
	damage = mega_damage
	expand_speed *= 1.3  # Slightly faster expansion for mega wave
	if _light:
		_light.light_color = Color(1.0, 0.6, 1.0)  # Magenta for mega
		_light.light_energy = 5.0
		_light.omni_range = 12.0
	if _material:
		_material.albedo_color = Color(1.0, 0.6, 1.0, 0.8)
		_material.emission = Color(1.0, 0.6, 1.0) * 0.8

func _physics_process(delta: float) -> void:
	if GameManager.is_paused:
		return
	
	# Expand — use an ease-out curve so the ring bursts outward quickly and
	# decelerates as it reaches max radius. This feels more energetic than a
	# linear expansion and matches the visual "shockwave" shape players expect.
	var progress: float = radius / max_radius if max_radius > 0.0 else 0.0
	progress = clampf(progress, 0.0, 1.0)
	# Ease-out quadratic: fast start, gentle finish
	var speed_mult: float = 1.0 - 0.65 * progress
	# Track previous radius BEFORE advancing so the enemy hit band covers
	# the full swept area this frame. Without this, a fast-expanding ring
	# (or a low-FPS physics tick) can skip past an enemy between frames —
	# the enemy is just outside the 2m band at frame N and already inside
	# (past the band) at frame N+1, so the hit is dropped. The swept band
	# catches any enemy in the ring's path, not just a thin annulus.
	_prev_radius = radius
	radius += expand_speed * speed_mult * delta
	
	# Update ring visual
	if ring_mesh:
		var scale_val := radius * 2.0
		# CylinderMesh axis is along Y — X and Z are the radius directions.
		# Scale X and Z to expand the ring. Y gets a brief vertical stretch
		# on the cast frame that eases back to 1.0, so the ring reads as a
		# 3D shockwave disk that "pops up" vertically before settling flat —
		# a flat hoop that only scales X/Z looks like a 2D circle on the
		# ground, but a Y stretch that decays gives it volume and energy.
		# The stretch peaks at cast (progress≈0) and fades to 1.0 by the
		# time the ring reaches ~30% expansion, so only the initial burst
		# has vertical lift — the trailing edge stays flat as it dissipates.
		var y_stretch: float = 1.0 + 3.0 * (1.0 - clampf(progress * 3.3, 0.0, 1.0)) ** 2
		# Use a smoothed scale so the ring doesn't pop on the first frame
		ring_mesh.scale = ring_mesh.scale.lerp(Vector3(scale_val, y_stretch, scale_val), 1.0 - exp(-12.0 * delta))
		# ── Ring spin ── Rotate the ring around Y so it reads as spinning
		#    energy rather than a static expanding hoop. The spin rate decays
		#    with expansion progress (matching the ease-out expansion curve)
		#    so the ring spins fast on cast and settles as it dissipates.
		#    Uses wall-clock time so the spin is consistent regardless of
		#    time-scale (hit-stop, Time-Slow dimension).
		var spin_decay: float = 1.0 - 0.7 * progress  # Fast at cast, slower at edge
		_ring_spin_phase += delta * RING_SPIN_SPEED * spin_decay
		ring_mesh.rotation.y = _ring_spin_phase
		# Fade out as it expands — ease-in so it stays visible early then fades fast
		var alpha := 1.0 - progress
		alpha = alpha * alpha  # Quadratic fade for a sharper disappear at the edge
		if _material:
			_material.albedo_color.a = alpha * 0.6
			# Emission energy also fades with the ring so the glow diminishes
			# naturally as the shockwave dissipates — more visually coherent than
			# keeping full emission while the ring fades to transparent.
			_material.emission_energy_multiplier = 1.5 * alpha

	# Fade the center light as the wave expands (punchy flash → gentle glow → off).
	# Use an ease-out cubic curve instead of a linear falloff so the light
	# snaps bright on the cast frame and decays smoothly — a more energetic
	# "flash → dissipate" read than a constant linear dim. The light range
	# also contracts with the same curve so the illuminated area shrinks
	# naturally as the energy disperses.
	if _light:
		var light_fade: float = 1.0 - pow(progress, 3.0)  # Ease-out cubic
		_light.light_energy = 3.0 * light_fade
		_light.omni_range = 8.0 * light_fade + 1.0  # Floor at 1m so it never fully snaps off
	
	# Damage enemies in ring — iterate the cached GameManager.enemies array
	# instead of get_nodes_in_group("enemies") to avoid the O(n) scene-tree
	# group scan every physics frame. Mirrors the optimization pattern used
	# by poison_cloud.gd (Enhancement Pack 30).
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_node: Node3D = enemy
		if not has_hit.has(enemy_node.get_instance_id()):
			var dist := global_position.distance_to(enemy_node.global_position)
			# Hit if the enemy falls within the swept band this frame —
			# between the previous radius and the current radius (plus a
			# small margin). This prevents fast-expanding rings or low-FPS
			# ticks from skipping past enemies between frames.
			if dist <= radius + 0.5 and dist >= _prev_radius - 0.5:
				has_hit[enemy_node.get_instance_id()] = true
				if enemy_node.has_method("take_damage_from"):
					enemy_node.take_damage_from(damage, global_position)
				elif enemy_node.has_method("take_damage"):
					enemy_node.take_damage(damage)
				# Knockback
				if enemy_node.has_method("apply_knockback"):
					var knock_dir: Vector3 = (enemy_node.global_position - global_position).normalized()
					knock_dir.y = 0
					enemy_node.apply_knockback(knock_dir, GameConstants.KNOCKBACK_FORCE_EXPLOSION)
				# ── Pulse wave hit spark ── A small 6-particle burst at each
				# enemy's position when the wave connects, so the player sees
				# the shockwave "punching" each enemy it reaches. The spark
				# uses the pulse wave's cyan color, matching the ring visual.
				# Without this, the wave expands silently through enemies —
				# the damage numbers + hit flash on the enemy are the only
				# feedback, which can be hard to read when multiple enemies
				# are hit simultaneously. The spark gives each hit a distinct
				# physical "impact" moment that traces the wave's expanding
				# front, making the AoE feel like a real shockwave hitting
				# each enemy in sequence rather than an invisible damage zone.
				if ParticleEffects:
					ParticleEffects.spawn_explosion(get_parent(),
						enemy_node.global_position,
						Color(0.2, 1.0, 0.8), 6, 0.15)
	
	# Remove when fully expanded
	if radius >= max_radius:
		queue_free()