## Zorp Wiggles — Enemy Projectile
## Projectile fired by Spore Spitter and Plasma Drake.
## Travels in a straight line, damages player on hit, has lifetime.
## Polished: shared resources, point light glow, velocity-aligned stretch,
## cached player reference, impact burst on hit, energy flicker.

extends Area3D

class_name EnemyProjectile

@export var speed: float = 20.0
@export var damage: int = 12
@export var lifetime: float = 3.0
@export var projectile_color: Color = Color(1.0, 0.471, 0.078)

var direction: Vector3 = Vector3.FORWARD
var age: float = 0.0
var _material: StandardMaterial3D = null
var _time_scale: float = 1.0  # Phase 14: Time-Slow dimension
var _light: OmniLight3D = null
var _cached_player: Node3D = null
# Guard against double-hit: the distance check in _physics_process and the
# body_entered Area3D signal can both fire on the same frame. Without this
# flag, _on_hit_player would run twice (queue_free is deferred), dealing
# double damage to the player from a single enemy projectile.
var _has_already_hit: bool = false
# ── Enhancement Pack 20: Near-miss graze ── Each projectile can only graze
# the player once. When the projectile passes within GRAZE_RADIUS but outside
# HIT_RADIUS, a subtle whoosh SFX plays. This flag prevents repeated graze
# SFX from the same projectile lingering near the player.
var _has_grazed: bool = false
# Guard against _fizzle_out() re-entrancy: when age >= lifetime, _physics_process
# calls _fizzle_out() which schedules queue_free via a 0.18s timer. Until the
# node is actually freed, _physics_process keeps running and calling
# _fizzle_out() every frame, creating duplicate fade tweens, duplicate particle
# bursts, and multiple queue_free timer callbacks. This flag ensures it only
# fires once.
var _is_fizzling: bool = false

# ── Spawn flash timer ── Counts down during the muzzle-flash spawn tween
#    so the per-frame mesh.scale set in _physics_process doesn't override
#    the spawn scale animation. When > 0, the tween owns mesh.scale.
var _spawn_flash_timer: float = 0.0

# ── Trail particles ── A short-lived GPUParticles3D that emits colored sparks
#    behind the bolt as it flies. The trail uses world-space coordinates
#    (local_coords = false) so particles stay where they're emitted instead of
#    following the projectile, creating a proper "exhaust stream" trail.
#    The process material is duplicated from the shared base so each
#    projectile's trail matches its own color. The mesh is shared (no
#    per-instance variation needed since the material handles the color).
var _trail_particles: GPUParticles3D = null

@onready var mesh: MeshInstance3D = $MeshInstance3D

# ─── Shared Resources ──────────────────────────────────────────────────────────
# Enemy projectiles are fired frequently by Spore Spitters and Drakes.
# Sharing the mesh eliminates per-shot geometry allocation. The material is
# per-instance so each projectile can pulse its emission independently.
static var _shared_mesh: SphereMesh = null

# ── Shared base material ── Duplicated per shot so each projectile can tween
#    its emission independently without creating a full StandardMaterial3D
#    from scratch and setting 7+ properties per spawn. Duplicate copies the
#    pre-configured property block (unlit, emission, rim lighting) in one
#    shot — cheaper than new + configure. The albedo_color and emission are
#    overwritten per instance to match the projectile_color. Mirrors the
#    shared-base-material pattern used by shockwave.gd and impact_burst.gd.
static var _shared_material_base: StandardMaterial3D = null

# ── Shared trail resources ── A lightweight GPUParticles3D trail follows each
#    enemy bolt, leaving a short stream of colored sparks so the projectile's
#    trajectory is readable even in dark biomes (Underground, Eclipse, Digital
#    Grid). Player projectiles already have a 6-point mesh trail; enemy bolts
#    had only a point light + stretch but no trail, making them harder to track
#    in darkness. The trail uses shared process material + mesh (duplicated per
#    instance only for color) so the per-shot allocation cost is minimal.
static var _shared_trail_process_mat: ParticleProcessMaterial = null
static var _shared_trail_mesh: SphereMesh = null
# ── Shared trail fade ramp ── A single white→transparent gradient shared
# across ALL enemy projectile trails. Since the ParticleProcessMaterial's
# `color` property already sets the per-projectile base color, the
# color_ramp only needs to control the alpha fade (1 → 0). White(1,1,1,a)
# multiplied by the projectile color yields (r,g,b,a) — the correct
# colored fade. This eliminates per-shot Gradient + GradientTexture1D
# allocation during heavy projectile combat.
static var _shared_trail_fade_ramp: GradientTexture1D = null

static func _ensure_shared_resources() -> void:
	if _shared_mesh == null:
		_shared_mesh = SphereMesh.new()
		_shared_mesh.radius = 0.2
		_shared_mesh.height = 0.4
		_shared_mesh.radial_segments = 8
		_shared_mesh.rings = 4
	if _shared_material_base == null:
		_shared_material_base = StandardMaterial3D.new()
		_shared_material_base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_material_base.emission_enabled = true
		_shared_material_base.emission_energy_multiplier = 1.2
		# Rim lighting for silhouette pop against dark terrain
		_shared_material_base.rim_enabled = true
		_shared_material_base.rim = 0.7
		_shared_material_base.rim_tint = 0.9
	if _shared_trail_process_mat == null:
		_shared_trail_process_mat = ParticleProcessMaterial.new()
		_shared_trail_process_mat.direction = Vector3.ZERO
		_shared_trail_process_mat.spread = 8.0
		_shared_trail_process_mat.gravity = Vector3.ZERO
		_shared_trail_process_mat.initial_velocity_min = 0.0
		_shared_trail_process_mat.initial_velocity_max = 0.3
		_shared_trail_process_mat.scale_min = 0.1
		_shared_trail_process_mat.scale_max = 0.25
	if _shared_trail_mesh == null:
		_shared_trail_mesh = SphereMesh.new()
		_shared_trail_mesh.radius = 0.06
		_shared_trail_mesh.height = 0.12
		_shared_trail_mesh.radial_segments = 4
		_shared_trail_mesh.rings = 2
	if _shared_trail_fade_ramp == null:
		# White → transparent. The GPU multiplies this ramp's RGB by the
		# per-projectile color, so white(1,1,1,a) × color = (r,g,b,a).
		var fade_grad := Gradient.new()
		fade_grad.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
		fade_grad.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
		_shared_trail_fade_ramp = GradientTexture1D.new()
		_shared_trail_fade_ramp.gradient = fade_grad

const IMPACT_SCENE := preload("res://scenes/entities/impact_burst.tscn")

func _ready() -> void:
	# Connect collision signal
	body_entered.connect(_on_body_entered)

	# Set up material — duplicate the shared base so each projectile can
	# pulse its emission independently. The base pre-configures unlit
	# shading, emission, and rim lighting; we only overwrite albedo_color
	# and emission per instance to match projectile_color. Cheaper than
	# creating a new StandardMaterial3D and setting 7+ properties per shot.
	_ensure_shared_resources()
	if mesh:
		mesh.mesh = _shared_mesh
		_material = _shared_material_base.duplicate() as StandardMaterial3D
		_material.albedo_color = projectile_color
		_material.emission = projectile_color * 0.6
		mesh.material_override = _material

	# Point light for real-time glow — makes the projectile visible and
	# threatening in dark biomes, casting light on nearby terrain.
	_light = OmniLight3D.new()
	_light.light_color = projectile_color
	_light.light_energy = 1.2
	_light.omni_range = 4.0
	_light.omni_attenuation = 1.5
	add_child(_light)

	# ── Muzzle spawn flash ── On the first frame, the bolt's emission and
	#    light spike to a bright value then ease back to their steady-state
	#    levels over ~0.12s. This gives newly-fired bolts a "muzzle flash"
	#    pop that draws the player's attention to the incoming threat —
	#    without it, a bolt simply appears at its cruising brightness and
	#    can go unnoticed in a busy combat scene. The flash is purely
	#    additive on top of the normal flicker/pulse systems (those run in
	#    _physics_process and will resume ownership once the tween ends).
	#    The mesh also briefly scales up (1.6×) then settles to its normal
	#    stretched shape, so the bolt "bursts" into existence rather than
	#    silently appearing.
	if _material:
		_material.emission_energy_multiplier = 4.0
		var spawn_flash_tween := create_tween()
		spawn_flash_tween.tween_property(_material, "emission_energy_multiplier",
			1.2, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if _light:
		var light_spawn_tween := create_tween()
		light_spawn_tween.tween_property(_light, "light_energy",
			1.2, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if mesh:
		mesh.scale = Vector3(1.2, 1.2, 3.0)
		_spawn_flash_timer = 0.1
		var mesh_spawn_tween := create_tween()
		mesh_spawn_tween.tween_property(mesh, "scale",
			Vector3(0.7, 0.7, 2.2), 0.1) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# ── Trail particles ── A short spark trail that follows the bolt's path,
	#    making enemy projectiles readable in dark biomes where the point light
	#    alone isn't enough to track trajectory. The trail uses a small number
	#    of particles (12) with a short lifetime (0.25s) so it's a subtle
	#    stream, not a dense cloud. World-space coordinates (local_coords =
	#    false) ensure particles stay where emitted, creating a proper exhaust
	#    trail. The process material is duplicated from the shared base and
	#    tinted to match the projectile's color. The draw mesh is shared.
	#    Performance: 12 particles × ~3s lifetime = ~36 active particles per
	#    bolt, negligible vs. the existing 500-particle weather systems.
	var trail_mat: ParticleProcessMaterial = _shared_trail_process_mat.duplicate() as ParticleProcessMaterial
	trail_mat.color = projectile_color
	# ── Shared fade ramp ── The trail's color_ramp was previously allocated
	# per shot: a new Gradient + GradientTexture1D, both with the
	# projectile's color at 1.0 alpha and the same color at 0.0 alpha. Since
	# ParticleProcessMaterial.color already sets the particle's base color,
	# the ramp only needs to control the alpha fade (1 → 0). A single
	# shared white→transparent ramp works with any color — the GPU
	# multiplies the ramp's RGB by the particle color, so white(1,1,1,a)
	# × projectile_color = projectile_color with alpha a. This eliminates
	# the per-shot Gradient + GradientTexture1D allocation (2 objects ×
	# every enemy projectile fired), reducing GC churn during heavy
	# projectile combat (Spore Spitters, Crystal Guardians, Drakes).
	trail_mat.color_ramp = _shared_trail_fade_ramp
	_trail_particles = GPUParticles3D.new()
	_trail_particles.amount = 12
	_trail_particles.lifetime = 0.25
	_trail_particles.one_shot = false
	_trail_particles.emitting = true
	_trail_particles.local_coords = false
	_trail_particles.process_material = trail_mat
	_trail_particles.draw_pass_1 = _shared_trail_mesh
	add_child(_trail_particles)

	# Add to group for tracking
	add_to_group("enemy_projectiles")

func _physics_process(delta: float) -> void:
	# ── Phase 14: Apply dimension time scale ──
	var raw_delta: float = delta  # Unscaled delta for visual timers (spawn flash)
	delta *= _time_scale
	age += delta
	if age >= lifetime:
		_fizzle_out()
		return

	# Move projectile
	global_position += direction * speed * delta

	# Orient and stretch the bolt toward its travel direction — gives a
	# fast energy-bolt silhouette instead of a static drifting sphere.
	# Same technique as player projectiles for visual consistency.
	if mesh and direction.length_squared() > 0.01:
		var up_vec := Vector3.UP
		if absf(direction.dot(Vector3.UP)) > 0.98:
			up_vec = Vector3.FORWARD
		mesh.look_at(global_position + direction * 2.0, up_vec)
		# Skip the per-frame scale override while the spawn flash tween
		# owns mesh.scale — the tween animates from the spawn pop size
		# down to the cruising stretch shape. Without this guard, the
		# _physics_process scale set would instantly overwrite the tween's
		# first frame, killing the spawn pop.
		if _spawn_flash_timer > 0.0:
			_spawn_flash_timer -= raw_delta
		else:
			mesh.scale = Vector3(0.7, 0.7, 2.2)
		# ── Rifled spin ── Add a constant roll around the travel axis so the
		# bolt reads as spinning energy rather than a static stretched sphere.
		# Matches the player projectile's rifled spin for visual consistency.
		# Uses wall-clock time so the spin rate is consistent regardless of
		# time-scale (hit-stop, Time-Slow). Visual-only — the collider is on
		# the parent Area3D, not the mesh, so this doesn't affect hit detection.
		mesh.rotation.z = Time.get_ticks_msec() * 0.015

	# Energy flicker — the point light pulses so the bolt feels like crackling
	# energy. Uses wall-clock time so flicker is consistent regardless of
	# time-scale (Time-Slow dimension won't slow the visual crackle).
	if _light:
		_light.light_energy = 1.0 + 0.4 * sin(Time.get_ticks_msec() * 0.025)

	# Aura pulse on emission
	if _material:
		var pulse: float = 0.8 + 0.4 * sin(age * GameConstants.ENEMY_PROJECTILE_AURA_PULSE_SPEED)
		_material.emission_energy_multiplier = pulse

	# Check distance to player (cached reference, refreshed if stale)
	# In co-op, check both P1 and P2 so the projectile hits whoever is closest
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	if _cached_player and GameManager.player_is_alive:
		var dist: float = global_position.distance_to(_cached_player.global_position)
		if dist < GameConstants.ENEMY_PROJECTILE_HIT_RADIUS:
			_on_hit_player(_cached_player)
			return  # _on_hit_player freed this projectile; stop processing
		# ── Enhancement Pack 20: Near-miss graze ── If the projectile passes
		# close to the player without hitting (between HIT_RADIUS and
		# GRAZE_RADIUS), play a subtle whoosh SFX. This gives the player audio
		# feedback that a bolt narrowly missed — "that was close!" — adding
		# tension and awareness during projectile-heavy encounters (Spore
		# Spitters, Crystal Guardians, Drakes, Mirror Mimics). Each projectile
		# can only graze once (flagged via _has_grazed) so a bolt lingering
		# near the player doesn't replay the SFX. The SFX is very quiet (0.12
		# volume) so multiple simultaneous grazes don't stack into noise.
		if not _has_grazed and dist < GameConstants.ENEMY_PROJECTILE_GRAZE_RADIUS:
			_has_grazed = true
			if AudioManager:
				AudioManager.play_sfx(AudioManager.SFX_GRAZE)
	# ── Phase 19: Co-op — also check P2 if active ──
	# Only check P2 if we didn't already hit P1 (above returns on hit, so
	# reaching here means P1 was not in range). Without the early return above,
	# a single projectile could damage BOTH players in co-op if they were
	# both within ENEMY_PROJECTILE_HIT_RADIUS of the bolt on the same frame
	# — _on_hit_player calls queue_free() (deferred to end of frame), so the
	# second check would still run and damage P2 after P1 was already hit.
	if CoOpManager.is_coop_active() and not CoOpManager.p2_is_downed:
		if CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
			var p2_dist: float = global_position.distance_to(CoOpManager.p2_node.global_position)
			if p2_dist < GameConstants.ENEMY_PROJECTILE_HIT_RADIUS:
				_on_hit_player(CoOpManager.p2_node)
				return  # _on_hit_player freed this projectile
			# ── Enhancement Pack 20: Near-miss graze for P2 ── Same graze
			# detection for Player 2 in co-op, using the same _has_grazed
			# flag so the projectile only grazes once total (either player).
			if not _has_grazed and p2_dist < GameConstants.ENEMY_PROJECTILE_GRAZE_RADIUS:
				_has_grazed = true
				if AudioManager:
					AudioManager.play_sfx(AudioManager.SFX_GRAZE)

# ── Phase 14: Set time scale (called by DimensionSystem) ──
func set_time_scale(scale: float) -> void:
	_time_scale = scale

func _on_body_entered(body: Node3D) -> void:
	if _has_already_hit:
		return  # Already hit a player this frame; don't double-damage
	if body.is_in_group("player"):
		_on_hit_player(body)
	elif not body.is_in_group("enemies"):
		# Hit terrain/wall — small impact flash, no damage
		if _trail_particles:
			_trail_particles.emitting = false
		_spawn_impact(projectile_color)
		queue_free()

## Hit a player — route damage to the correct player in co-op.
## `target` is the CharacterBody3D that was hit (P1 or P2).
## Sets a guard flag so the distance-check in _physics_process and the
## body_entered signal can't both fire _on_hit_player on the same frame
## (which would double-damage the player — queue_free is deferred so the
## second call would still execute before the node is actually freed).
func _on_hit_player(target: Node3D = null) -> void:
	if _has_already_hit:
		return  # Prevent double-hit from distance check + body_entered
	_has_already_hit = true
	# Stop trail emission so lingering sparks fade naturally rather than
	# continuing to emit from a freed projectile's last position.
	if _trail_particles:
		_trail_particles.emitting = false
	# Impact SFX — the projectile already plays SFX_GRAZE on near-miss (a
	# whoosh sound), but the actual hit had no projectile-specific audio.
	# The player only heard the generic SFX_DAMAGE from take_damage(), which
	# fires once even when multiple projectiles hit simultaneously. A
	# dedicated impact thunk at moderate volume gives each hit a distinct
	# audio cue, especially when several bolts connect at once and the damage
	# SFX only plays once. Uses play_sfx_volume at 0.6 so it doesn't
	# overpower the damage sound or stack into noise during projectile-heavy
	# encounters (Spore Spitters, Crystal Guardians, Drakes, Mirror Mimics).
	AudioManager.play_sfx_volume(AudioManager.SFX_ENEMY_HIT, 0.6)
	# Default to P1 if no target specified (backward compatibility)
	if target and target.is_in_group("player2"):
		CoOpManager.p2_take_damage(damage, global_position)
	else:
		GameManager.take_damage(damage, global_position)
	_spawn_impact(projectile_color)
	queue_free()

## Spawn an impact burst effect at the projectile's position.
## Uses the shared impact_burst scene, retinted to the projectile's color.
## POOLING: Uses the PerformanceOptimizer pool when available to avoid
## per-hit instantiate/free churn.
func _spawn_impact(col: Color) -> void:
	if IMPACT_SCENE:
		var burst: Node3D = null
		if PerformanceOptimizer:
			burst = PerformanceOptimizer.acquire("res://scenes/entities/impact_burst.tscn", get_parent())
		else:
			burst = IMPACT_SCENE.instantiate()
		# Set the impact color BEFORE adding to the tree so _ready() picks
		# it up and retints the material + light to match this projectile.
		burst.set("impact_color", col)
		if not PerformanceOptimizer:
			get_parent().add_child(burst)
		burst.global_position = global_position
		# For pooled instances, _ready() doesn't auto-play. Call _play()
		# explicitly after setting the impact color.
		if burst.has_method("_play"):
			burst._play()

## Fizzle out when lifetime expires — small particle puff + fade, not a
## hard queue_free. Gives the player a visual cue that the threat ended.
## Both the light AND the mesh alpha tween out together so the bolt
## visibly "dissipates" instead of just vanishing.
func _fizzle_out() -> void:
	if _is_fizzling:
		return  # Already fizzling — prevent duplicate tweens/particles/timers
	_is_fizzling = true
	# Stop trail emission so the stream ends with the bolt's dissipation.
	if _trail_particles:
		_trail_particles.emitting = false
	# Tween the mesh alpha out alongside the light so the whole bolt
	# fades as a unit. Previously the light tweened but the material
	# alpha was snapped to 0.0 instantly — the mesh popped out while
	# the light was still fading, which looked like a bug.
	if _material:
		var mat_fade := create_tween()
		mat_fade.tween_property(_material, "albedo_color:a", 0.0, 0.15) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if _light:
		var fade_tween := create_tween()
		fade_tween.tween_property(_light, "light_energy", 0.0, 0.15) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Small fizzle particle puff
	ParticleEffects.spawn_explosion(get_parent(), global_position, projectile_color, 6, 0.15)
	# Free after the fade completes so the visual is fully visible
	get_tree().create_timer(0.18, true, false, true).timeout.connect(queue_free)