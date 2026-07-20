## Zorp Wiggles — Projectile (Player Laser)
## Tentacle laser projectile that flies forward and damages enemies.
## Features: emission glow, trail particles, impact burst, point light.
## Ported from Projectile class in Ursina game.py.

extends Area3D

var direction: Vector3 = Vector3.FORWARD
var damage: int = GameConstants.PROJECTILE_BASE_DAMAGE
var lifetime: float = GameConstants.PROJECTILE_LIFETIME
var speed: float = GameConstants.PROJECTILE_SPEED

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# ─── Phase 16: Weapon Mod Crafting ────────────────────────────────────────────
var _weapon_mod: int = GameConstants.WeaponMod.NONE
var _mod_color: Color = Color(0.2, 1.0, 0.8)
var _bounce_count: int = 0          # For Bouncing Bolt
var _pierce_count: int = 0          # For Piercing Beam
var _max_bounces: int = 3
var _max_pierces: int = 3
var _homing_strength: float = 8.0   # For Homing Laser
var _tesla_zap_timer: float = 0.0  # For Tesla Coil periodic zap
var _has_hit_enemies: Array[Node3D] = []  # Track hit enemies for pierce/chain (prevent double-hit)
# ── Homing target cache ── Re-evaluating the nearest enemy every frame is
# expensive (iterates the full enemy list). We cache the current homing target
# and only re-pick every HOMING_REPATH_INTERVAL seconds, or when the cached
# target dies / goes out of range. This keeps homing responsive without the
# per-frame O(n) scan.
var _homing_target: Node3D = null
var _homing_repath_timer: float = 0.0
const HOMING_REPATH_INTERVAL: float = 0.15  # Re-pick target 6.7x/sec
# True once this projectile has been consumed (queue_free called). Prevents
# double-hit when two body_entered signals fire on the same frame (overlapping
# enemies/colliders) — the second signal would otherwise damage a second target
# before the deferred queue_free() takes effect, letting a single non-piercing
# bolt hit multiple enemies.
var _is_consumed: bool = false
var _light: OmniLight3D = null
var _mod_material: StandardMaterial3D = null  # Per-projectile material for mod color

# ── Hit-stop (freeze frame) ────────────────────────────────────────────────────
# A brief global time-scale dip on heavy hits makes impacts feel weighty —
# a classic "juice" technique. We use a static cooldown so multiple crits in
# the same frame don't stack into a long freeze. The freeze is short (45ms)
# so gameplay isn't disrupted, only punctuated.
#
# Boss kills get a longer, deeper freeze (90ms at 0.04x) so slaying a major
# foe feels like a cinematic moment rather than just another enemy pop. The
# cooldown is skipped for boss kills so the freeze always lands on the kill
# blow even during rapid fire.
static var _hitstop_cooldown: float = 0.0
const HITSTOP_DURATION: float = 0.045   # Seconds the world freezes (normal)
const HITSTOP_TIME_SCALE: float = 0.08  # Target time scale during freeze (normal)
const HITSTOP_COOLDOWN: float = 0.12    # Min seconds between freeze triggers
const HITSTOP_BOSS_DURATION: float = 0.09   # Boss kill freeze (90ms — weighty)
const HITSTOP_BOSS_TIME_SCALE: float = 0.04 # Boss kill freeze (near-stop)

# ── Elite kill hit-stop ────────────────────────────────────────────────────────
# Large-but-not-boss enemies (Sentinels, Bombers, Crystal Guardians — anything
# with base_scale >= 1.5) get a lighter freeze than a boss kill but still more
# punch than a normal mook death. This sits between the normal crit hit-stop
# (45ms @ 0.08x) and the boss kill (90ms @ 0.04x): 65ms at 0.06x. The cooldown
# is shared with the normal hit-stop cooldown so rapid elite clears don't
# stack into a stutter — the first elite kill freezes, subsequent ones in
# the cooldown window just use the existing crit/normal path.
const HITSTOP_ELITE_DURATION: float = 0.065
const HITSTOP_ELITE_TIME_SCALE: float = 0.06

# ─── Shared Resources ──────────────────────────────────────────────────────────
# Projectiles are spawned at ~9/sec during combat. Creating a new
# StandardMaterial3D per shot causes unnecessary GPU resource allocation
# and GC pressure. These static materials are created once and reused.
static var _shared_mesh: SphereMesh = null
static var _shared_material: StandardMaterial3D = null
static var _shared_trail_mesh: SphereMesh = null
static var _shared_trail_material: StandardMaterial3D = null

static func _ensure_shared_resources() -> void:
	if _shared_mesh == null:
		_shared_mesh = SphereMesh.new()
		_shared_mesh.radius = 0.15
		_shared_mesh.height = 0.3
		_shared_mesh.radial_segments = 6
		_shared_mesh.rings = 3
	if _shared_material == null:
		_shared_material = StandardMaterial3D.new()
		_shared_material.albedo_color = Color(0.2, 1.0, 0.8)  # Cyan laser
		_shared_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_material.emission_enabled = true
		_shared_material.emission = Color(0.2, 1.0, 0.8) * 0.8
		_shared_material.emission_energy_multiplier = 1.5
	if _shared_trail_mesh == null:
		_shared_trail_mesh = SphereMesh.new()
		_shared_trail_mesh.radius = 0.1
		_shared_trail_mesh.height = 0.2
		_shared_trail_mesh.radial_segments = 4
		_shared_trail_mesh.rings = 2
	if _shared_trail_material == null:
		_shared_trail_material = StandardMaterial3D.new()
		_shared_trail_material.albedo_color = Color(0.2, 1.0, 0.8, 0.5)
		_shared_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shared_trail_material.emission_enabled = true
		_shared_trail_material.emission = Color(0.2, 1.0, 0.8) * 0.3

# ─── Trail ────────────────────────────────────────────────────────────────────
var _trail_positions: Array[Vector3] = []
const TRAIL_MAX_POINTS: int = 6
const TRAIL_INTERVAL: float = 0.02
var _trail_timer: float = 0.0
var _trail_meshes: Array[MeshInstance3D] = []
var _trail_materials: Array[StandardMaterial3D] = []  # Per-trail-node mat for alpha fade

# ─── Impact Effect ────────────────────────────────────────────────────────────
const IMPACT_SCENE := preload("res://scenes/entities/impact_burst.tscn")
const PROJECTILE_SCENE := preload("res://scenes/entities/projectile.tscn")  # Phase 16: Splitter

func _ready() -> void:
	# Connect body_entered signal — fires when a PhysicsBody3D (enemy) enters
	body_entered.connect(_on_body_entered)

	# Use shared mesh + material (created once, reused across all projectiles)
	_ensure_shared_resources()
	if mesh_instance:
		mesh_instance.mesh = _shared_mesh
		# Phase 16: If a weapon mod is set, use a per-projectile material with the mod color
		if _weapon_mod != GameConstants.WeaponMod.NONE:
			_mod_material = _shared_material.duplicate() as StandardMaterial3D
			_mod_material.albedo_color = _mod_color
			_mod_material.emission = _mod_color * 0.8
			mesh_instance.material_override = _mod_material
		else:
			mesh_instance.material_override = _shared_material

	# Add a small point light for real-time glow (color matches mod)
	_light = OmniLight3D.new()
	_light.light_color = _mod_color
	_light.light_energy = 0.8
	_light.omni_range = 3.0
	_light.omni_attenuation = 1.5
	add_child(_light)

## Phase 16: Set the weapon mod ID and color. Called by player when spawning.
func set_weapon_mod(mod_id: int, col: Color) -> void:
	_weapon_mod = mod_id
	_mod_color = col

func _physics_process(delta: float) -> void:
	if GameManager.is_paused:
		return

	# ── Hit-stop cooldown tick (static, so any projectile instance can trigger) ──
	if _hitstop_cooldown > 0.0:
		_hitstop_cooldown -= delta

	# ── Phase 16: Weapon mod behavior in flight ──
	_apply_mod_flight_behavior(delta)

	# Move forward
	global_position += direction * speed * delta

	# Orient and stretch the bolt toward its travel direction — gives a fast
	# laser-bolt silhouette instead of a static drifting sphere. The mesh's
	# local -Z (forward) is aligned with `direction` via look_at, then the Z
	# scale is stretched so the bolt reads as a streak of energy. A safe up
	# vector is used when direction is nearly vertical (homing mods) so
	# look_at doesn't error on a parallel up vector.
	if mesh_instance and direction.length_squared() > 0.01:
		var up_vec := Vector3.UP
		if absf(direction.dot(Vector3.UP)) > 0.98:
			up_vec = Vector3.FORWARD
		mesh_instance.look_at(global_position + direction * 2.0, up_vec)
		mesh_instance.scale = Vector3(0.75, 0.75, 2.4)

	# Energy flicker — the point light pulses subtly so the bolt feels like
	# crackling energy rather than a static glow. Uses wall-clock time so the
	# flicker rate is consistent regardless of time-scale (hit-stop, Time-Slow).
	if _light:
		_light.light_energy = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.03)

	# Update trail
	_trail_timer -= delta
	if _trail_timer <= 0:
		_trail_timer = TRAIL_INTERVAL
		_record_trail_point(global_position)

	_update_trail_visuals(delta)

	# Lifetime countdown
	lifetime -= delta
	if lifetime <= 0:
		# Phase 24: Black Hole Launcher auto-collapses on lifetime expiry (if not already consumed)
		if not _is_consumed and _weapon_mod == GameConstants.WeaponMod.BLACK_HOLE_LAUNCHER:
			_spawn_black_hole_launcher_collapse(damage)
			_is_consumed = true
		# Phase 24: Meteor Strike calls the meteor on lifetime expiry (if not already consumed)
		elif not _is_consumed and _weapon_mod == GameConstants.WeaponMod.METEOR_STRIKE:
			_call_meteor_strike(damage)
			_is_consumed = true
		# Phase 24: Poison Nova triggers on lifetime expiry (if not already consumed)
		elif not _is_consumed and _weapon_mod == GameConstants.WeaponMod.POISON_NOVA:
			_spawn_poison_nova(damage)
			_is_consumed = true
		queue_free()

## Hit-stop: briefly dip `Engine.time_scale` to make heavy hits feel weighty.
## Uses a static cooldown so rapid crits don't stack into a long freeze.
## The restore is scheduled via a scene-tree Timer (not a tween on self) because
## the projectile may queue_free() immediately after triggering hit-stop — a
## self-bound tween would be killed and time_scale would stay frozen forever.
## We restore to 1.0 (not a saved value) because DimensionSystem uses per-node
## `_time_scale` multipliers, so Engine.time_scale should always be 1.0.
##
## IMPORTANT: `SceneTree.create_timer()` respects `Engine.time_scale` by
## default. If we set time_scale=0.08 and then schedule a 0.045s restore
## timer without `ignore_time_scale`, the timer fires in SCALED time — i.e.
## after 0.045/0.08 ≈ 0.56s of real time. The freeze would last ~12x longer
## than intended, making crits feel like the game is stuttering instead of
## delivering a punchy 45ms freeze. Passing `ignore_time_scale=true` makes the
## timer count real-time seconds regardless of the current time scale, so
## the freeze restores exactly when intended.
func _trigger_hitstop(is_boss_kill: bool = false) -> void:
	# Boss kills bypass the cooldown so the freeze always lands on the kill
	# blow, even during rapid fire. Normal crits/hits respect the cooldown to
	# avoid stacking into a long stutter.
	if not is_boss_kill and _hitstop_cooldown > 0.0:
		return
	_hitstop_cooldown = HITSTOP_COOLDOWN
	var freeze_duration: float = HITSTOP_BOSS_DURATION if is_boss_kill else HITSTOP_DURATION
	var freeze_scale: float = HITSTOP_BOSS_TIME_SCALE if is_boss_kill else HITSTOP_TIME_SCALE
	Engine.time_scale = freeze_scale
	# Schedule restore on the scene tree — survives self queue_free().
	# `ignore_time_scale=true` is critical: without it the restore timer
	# ticks at the freeze speed, so the "brief" freeze would last many
	# times longer than intended (e.g. 0.09s / 0.04 = 2.25s for a boss kill).
	var timer := get_tree().create_timer(freeze_duration, true, false, true)
	timer.timeout.connect(func():
		Engine.time_scale = 1.0
	)

## Elite kill hit-stop: a lighter freeze for large-but-not-boss enemies. Shares
## the normal hit-stop cooldown so rapid elite clears don't stack into a long
## stutter. The freeze is scheduled the same way as _trigger_hitstop (scene-tree
## timer with ignore_time_scale=true) so it survives the projectile's
## queue_free() and restores Engine.time_scale to 1.0 exactly on time.
func _trigger_elite_hitstop() -> void:
	if _hitstop_cooldown > 0.0:
		return
	_hitstop_cooldown = HITSTOP_COOLDOWN
	Engine.time_scale = HITSTOP_ELITE_TIME_SCALE
	var timer := get_tree().create_timer(HITSTOP_ELITE_DURATION, true, false, true)
	timer.timeout.connect(func():
		Engine.time_scale = 1.0
	)

## Phase 16: Apply weapon mod behavior while the projectile is in flight.
func _apply_mod_flight_behavior(delta: float) -> void:
	match _weapon_mod:
		GameConstants.WeaponMod.HOMING_LASER, GameConstants.WeaponMod.QUANTUM_OVERDRIVE:
			# Homing: steer toward the nearest enemy (cached, re-picked periodically)
			var target: Node3D = _get_cached_homing_target(delta)
			if target:
				var to_target: Vector3 = (target.global_position - global_position).normalized()
				var current_dir: Vector3 = direction.normalized()
				# Steer toward target with a limited turn rate
				var new_dir: Vector3 = current_dir.lerp(to_target, _homing_strength * delta).normalized()
				direction = new_dir
		GameConstants.WeaponMod.GRAVITY_WELL_LASER:
			# Gravity Well: pull nearby enemies toward the projectile's path
			_pull_nearby_enemies(delta)
		GameConstants.WeaponMod.TESLA_COIL:
			# Tesla: periodically zap nearby enemies with electric arcs
			_tesla_zap_timer -= delta
			if _tesla_zap_timer <= 0:
				_tesla_zap_timer = 0.15
				_tesla_zap_nearby()
		# Enhancement: Black Hole Beam — pull enemies toward the bolt in flight
		GameConstants.WeaponMod.BLACK_HOLE_BEAM:
			_pull_nearby_enemies(delta)
			# Extra-strong pull radius for black hole
			var bh_pull_radius: float = 12.0
			for enemy in GameManager.enemies:
				if not is_instance_valid(enemy):
					continue
				if not enemy.is_in_group("enemies"):
					continue
				var d: float = global_position.distance_to(enemy.global_position)
				if d < bh_pull_radius and d > 0.5:
					var pull_dir: Vector3 = (global_position - enemy.global_position).normalized()
					var pull_strength: float = 20.0 * (1.0 - d / bh_pull_radius)
					enemy.global_position += pull_dir * pull_strength * delta
		# Enhancement: Magnet Mine — strong homing toward nearest enemy (cached)
		GameConstants.WeaponMod.MAGNET_MINE:
			var mine_target: Node3D = _get_cached_homing_target(delta, 12.0)
			if mine_target:
				var to_target: Vector3 = (mine_target.global_position - global_position).normalized()
				var current_dir: Vector3 = direction.normalized()
				# Strong homing — mines are designed to seek targets.
				# Frame-rate-independent exponential approach so the turn rate is
				# consistent regardless of refresh rate.
				var new_dir: Vector3 = current_dir.lerp(to_target, 1.0 - exp(-12.0 * delta)).normalized()
				direction = new_dir
		# Phase 24: Black Hole Launcher — extra-strong pull in flight + auto-collapse
		GameConstants.WeaponMod.BLACK_HOLE_LAUNCHER:
			# Pull enemies toward the bolt with a large radius (stronger than Black Hole Beam)
			var bh_pull_radius: float = GameConstants.BLACK_HOLE_LAUNCHER_PULL_RADIUS
			for enemy in GameManager.enemies:
				if not is_instance_valid(enemy):
					continue
				if not enemy.is_in_group("enemies"):
					continue
				var d: float = global_position.distance_to(enemy.global_position)
				if d < bh_pull_radius and d > 0.5:
					var pull_dir: Vector3 = (global_position - enemy.global_position).normalized()
					var pull_strength: float = GameConstants.BLACK_HOLE_LAUNCHER_PULL_FORCE * (1.0 - d / bh_pull_radius)
					enemy.global_position += pull_dir * pull_strength * delta

## Cached homing target lookup. Re-picks the nearest enemy every
## HOMING_REPATH_INTERVAL seconds, or immediately if the cached target is
## no longer valid. This avoids scanning the full enemy list every frame for
## every homing projectile — a meaningful perf win when several homing bolts
## are in flight at once.
func _get_cached_homing_target(delta: float, max_range: float = 30.0) -> Node3D:
	_homing_repath_timer -= delta
	# Re-pick if the timer expired or the cached target is no longer valid
	var need_repath: bool = _homing_repath_timer <= 0.0
	if _homing_target and not is_instance_valid(_homing_target):
		_homing_target = null
		need_repath = true
	if not need_repath and _homing_target:
		# Also repath if the target moved out of homing range
		if global_position.distance_to(_homing_target.global_position) > max_range:
			need_repath = true
	if need_repath:
		_homing_repath_timer = HOMING_REPATH_INTERVAL
		_homing_target = _find_nearest_enemy(max_range)
	return _homing_target

## Find the nearest enemy to the projectile (for homing).
## Optional max_range overrides the default homing range (used by Magnet Mine).
func _find_nearest_enemy(max_range: float = 30.0) -> Node3D:
	var nearest: Node3D = null
	var nearest_dist: float = max_range  # Max homing range
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.is_in_group("enemies"):
			continue
		if _has_hit_enemies.has(enemy):
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	return nearest

## Gravity Well: pull nearby enemies toward the projectile.
func _pull_nearby_enemies(delta: float) -> void:
	var pull_radius: float = 8.0
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.is_in_group("enemies"):
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < pull_radius and d > 0.5:
			var pull_dir: Vector3 = (global_position - enemy.global_position).normalized()
			var pull_strength: float = 10.0 * (1.0 - d / pull_radius)
			enemy.global_position += pull_dir * pull_strength * delta

## Tesla Coil: zap nearby enemies with small damage.
func _tesla_zap_nearby() -> void:
	var zap_radius: float = 5.0
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.is_in_group("enemies"):
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < zap_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(int(damage * 0.3))
			# Visual: small spark particle
			ParticleEffects.spawn_explosion(get_parent(), enemy.global_position, Color(0.5, 0.9, 1.0), 6, 0.2)

func _record_trail_point(pos: Vector3) -> void:
	_trail_positions.push_front(pos)
	if _trail_positions.size() > TRAIL_MAX_POINTS:
		_trail_positions.pop_back()

func _update_trail_visuals(delta: float) -> void:
	# Lazily create trail mesh instances (using shared mesh + per-node material clones)
	# Each trail node gets its own material clone so we can fade alpha independently.
	# The mesh itself is shared (static geometry) to save GPU memory.
	while _trail_meshes.size() < TRAIL_MAX_POINTS:
		var m := MeshInstance3D.new()
		_ensure_shared_resources()
		m.mesh = _shared_trail_mesh
		# Clone the shared trail material so each trail node can fade independently
		var mat := _shared_trail_material.duplicate() as StandardMaterial3D
		m.material_override = mat
		_trail_materials.append(mat)
		add_child(m)
		m.visible = false
		_trail_meshes.append(m)

	# Position and fade trail meshes behind the projectile
	for i in range(_trail_meshes.size()):
		var tm: MeshInstance3D = _trail_meshes[i]
		if i < _trail_positions.size():
			tm.visible = true
			# Position trail point relative to projectile parent (trail is in local space)
			tm.global_position = _trail_positions[i]
			# Fade and shrink with distance from head
			var fade: float = 1.0 - float(i) / float(TRAIL_MAX_POINTS)
			var mat: StandardMaterial3D = _trail_materials[i]
			if mat:
				mat.albedo_color.a = fade * 0.5
			tm.scale = Vector3.ONE * fade
		else:
			tm.visible = false

func _on_body_entered(body: Node3D) -> void:
	# If this projectile is already consumed (queued for free from a prior
	# hit this frame), ignore further collisions. Without this guard, a fast
	# projectile overlapping two enemies on the same frame would fire
	# body_entered twice — _hit_enemy calls queue_free() (deferred to end of
	# frame), so the second signal would still execute and damage the second
	# enemy, letting a single non-piercing bolt hit multiple targets.
	if _is_consumed:
		return
	# ── Phase 32: PvP — projectiles can hit the other player ──
	if PvpArena and PvpArena.is_pvp_active():
		var hit_p1: bool = body.is_in_group("player") and has_meta("is_p2_projectile")
		var hit_p2: bool = body == CoOpManager.p2_node if (CoOpManager and CoOpManager.p2_node) else false
		if hit_p2 and not has_meta("is_p2_projectile"):
			# P1's projectile hit P2
			PvpArena.register_pvp_hit(false, damage)  # P1 attacked
			_impact_effect()
			_is_consumed = true
			queue_free()
			return
		if hit_p1:
			# P2's projectile hit P1
			PvpArena.register_pvp_hit(true, damage)  # P2 attacked
			_impact_effect()
			_is_consumed = true
			queue_free()
			return
	# Check if it's an enemy
	if body.is_in_group("enemies"):
		# Don't hit the same enemy twice (for piercing/chain)
		if _has_hit_enemies.has(body):
			return
		_hit_enemy(body)
	elif body.is_in_group("destructibles"):
		# Hit a destructible prop — damage it
		if body.has_method("take_damage_from"):
			body.take_damage_from(damage, global_position)
		_impact_effect()
		_is_consumed = true
		queue_free()
	elif body.is_in_group("interactive_object"):
		# ── Phase 26: Breakable walls take damage from projectiles ──
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		_impact_effect()
		_is_consumed = true
		queue_free()
	else:
		# Hit terrain/wall
		# Enhancement: Spectral Beam — phases through walls and terrain, never blocked
		if _weapon_mod == GameConstants.WeaponMod.SPECTRAL_BEAM:
			# Pass through terrain — small visual ripple but don't stop
			ParticleEffects.spawn_explosion(get_parent(), global_position, _mod_color, 4, 0.1)
			return
		# Phase 16: Bouncing Bolt bounces off walls
		if _weapon_mod == GameConstants.WeaponMod.BOUNCING_BOLT and _bounce_count < _max_bounces:
			_bounce_off_wall(body)
			return
		# Phase 24: Meteor Strike — terrain hit triggers the meteor at the impact point
		if _weapon_mod == GameConstants.WeaponMod.METEOR_STRIKE:
			_call_meteor_strike(damage)
		# Phase 24: Poison Nova — terrain hit triggers the nova at the impact point
		elif _weapon_mod == GameConstants.WeaponMod.POISON_NOVA:
			_spawn_poison_nova(damage)
		# Phase 24: Black Hole Launcher — terrain hit triggers the collapse
		elif _weapon_mod == GameConstants.WeaponMod.BLACK_HOLE_LAUNCHER:
			_spawn_black_hole_launcher_collapse(damage)
		_impact_effect()
		_is_consumed = true
		queue_free()

## Phase 16: Bounce off a wall — reflect direction using the surface normal.
## Area3D doesn't provide collision normals directly, so we use the physics
## direct space state's intersect_ray (no node creation needed) to find the
## wall's surface normal, then reflect the direction around it. This produces
## physically-correct ricochets (e.g. hitting a wall at 45° bounces off at 45°)
## instead of the old "reverse direction" hack which sent the bolt back toward
## the shooter regardless of impact angle. Falls back to the old reverse if the
## raycast misses (e.g. glancing hit on a thin collider).
func _bounce_off_wall(_body: Node3D) -> void:
	_bounce_count += 1
	# Try to find the surface normal via a short raycast from just behind the
	# impact point back along the travel direction. Uses the physics direct
	# space state (no node creation) so this is cheap even for rapid bounces.
	var normal: Vector3 = Vector3.ZERO
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ray_origin: Vector3 = global_position - direction * 0.5
	var ray_end: Vector3 = global_position + direction * 1.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 1)  # mask 1 = world
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty() and hit.has("normal"):
		normal = hit["normal"]
	if normal.length_squared() > 0.01:
		# Reflect direction around the surface normal
		direction = direction.bounce(normal)
		# Ensure the bolt moves away from the wall (dot > 0)
		if direction.dot(normal) < 0:
			direction = -direction
		direction = direction.normalized()
	else:
		# Fallback: reverse direction with a slight upward bias
		direction = (-direction + Vector3(0, 0.3, 0)).normalized()
	# Small visual feedback
	ParticleEffects.spawn_explosion(get_parent(), global_position, _mod_color, 8, 0.2)

func _hit_enemy(enemy: Node3D) -> void:
	# damage already includes level bonus and mod multiplier (set by player.gd on spawn)
	var total_damage := damage
	# ── Phase 35: Balance pass — weapon mod damage normalization ──
	# Nudges outlier mods (Mega Blast, Sniper Beam, Shrink Beam) toward the
	# mean so no single mod dominates. Returns 1.0 for unlisted mods.
	if BalanceManager and BalanceManager.is_initialized():
		total_damage = int(total_damage * BalanceManager.get_mod_damage_adjustment(_weapon_mod))
	# Phase 24: Meteor Strike — the bolt is just a marker; the meteor is the
	# main damage. Reduce the bolt's direct hit damage so the bulk comes from
	# the meteor impact (called later in this function).
	if _weapon_mod == GameConstants.WeaponMod.METEOR_STRIKE:
		total_damage = GameConstants.METEOR_STRIKE_BOLT_DAMAGE

	# ── Phase 25: Progression System boss damage bonus (Combat branch) ──
	# Giant Slayer skill increases damage against bosses (high HP / large scale)
	var is_target_boss: bool = false
	if "max_hp" in enemy and "base_scale" in enemy:
		var e_max_hp: int = int(enemy.get("max_hp"))
		var e_scale: float = float(enemy.get("base_scale"))
		is_target_boss = e_max_hp >= 200 or e_scale >= 2.0
	if is_target_boss and ProgressionSystem:
		total_damage = int(total_damage * ProgressionSystem.get_boss_damage_mult())

	# Crit check
	var crit_chance := GameConstants.CRIT_BASE_CHANCE
	# ── Phase 25: Progression System crit chance bonus (Combat branch) ──
	if ProgressionSystem:
		crit_chance += ProgressionSystem.get_crit_chance_bonus()
	# ── Phase 29: Equipment crit chance bonus (armor/accessory + set bonuses) ──
	if EquipmentSystem:
		crit_chance += EquipmentSystem.get_crit_chance_bonus()
	var is_crit := randf() < crit_chance
	if is_crit:
		# Crit chain bonus
		GameManager.player_crit_chain += 1
		GameManager.player_crit_chain_timer = GameConstants.CRIT_CHAIN_WINDOW
		var crit_mult := GameConstants.CRIT_BASE_MULT
		if GameManager.player_crit_chain >= GameConstants.CRIT_CHAIN_THRESHOLD:
			crit_mult = GameConstants.CRIT_CHAIN_MULT  # Chain crit bonus: 3x
		total_damage = int(total_damage * crit_mult)
		# ── Hit-stop: briefly slow the world on a crit for a weighty impact ──
		_trigger_hitstop()

	# Check if this will be a kill before applying damage
	var will_kill: bool = false
	var is_boss_kill: bool = false
	var is_elite_kill: bool = false  # Large-but-not-boss enemies get a lighter freeze
	if enemy.has_method("take_damage_from") or enemy.has_method("take_damage"):
		if "hp" in enemy and "max_hp" in enemy:
			will_kill = total_damage >= enemy.hp
		# ── Hit-stop on kill blows: even heftier freeze for the killing hit ──
		# Boss kills (high max_hp or large base_scale) get the longer, deeper
		# freeze so the moment reads as a cinematic beat, not just another pop.
		if will_kill:
			var enemy_max_hp: int = int(enemy.get("max_hp")) if "max_hp" in enemy else 0
			var enemy_base_scale: float = float(enemy.get("base_scale")) if "base_scale" in enemy else 1.0
			is_boss_kill = enemy_max_hp >= 200 or enemy_base_scale >= 2.0
			# Elite kills (Sentinels, Bombers, Crystal Guardians — big but not bosses)
			# get a lighter freeze than bosses but still more than a normal mook,
			# so downing a significant foe feels weighty without becoming a slog
			# when clearing a room of them. The threshold matches the death
			# shockwave threshold (base_scale >= 1.5) so visual + freeze agree.
			is_elite_kill = not is_boss_kill and enemy_base_scale >= 1.5
			if is_boss_kill:
				_trigger_hitstop(true)
			elif is_elite_kill:
				_trigger_elite_hitstop()
		# ── Phase 19: Co-op — mark enemy as hit by P2 if this is a P2 projectile ──
		if has_meta("is_p2_projectile") and enemy.has_method("set_p2_hit"):
			enemy.set_p2_hit()
		# Enhancement: Spectral Beam — set the bypass flag so Phase Shifter
		# enemies take damage even while intangible. The flag is reset after
		# the hit is processed (in the pierce section below or before queue_free).
		if _weapon_mod == GameConstants.WeaponMod.SPECTRAL_BEAM:
			EnemyPhaseShifter.set_spectral_bypass(true)
		# Phase 8: Use the directional damage variant so enemies get knocked back
		if enemy.has_method("take_damage_from"):
			enemy.take_damage_from(total_damage, global_position)
		else:
			enemy.take_damage(total_damage)

	# Damage number popup — boss kills get a distinct "BOSS SLAIN!" variant
	DamageNumber.spawn(get_parent(), global_position, total_damage, is_crit, will_kill, is_boss_kill)

	# ── Subtle camera kick on every landed hit ── A tiny trauma pulse on each
	# shot that connects, so the camera nudges with the impact. This is much
	# smaller than the death/crit shakes (which already exist) — just enough
	# to give a tactile "I hit something" read on normal hits. Scaled by
	# enemy size so a Sentinel hit kicks harder than a Blob hit, and skipped
	# for crits/kills (those already get the bigger hit-stop + death shake, so
	# adding this on top would double-dip). The bias direction points from the
	# enemy toward the player so the camera nudges "backward" as if recoiling
	# from the impact — reinforcing the shot's direction.
	if not is_crit and not will_kill:
		var e_scale: float = float(enemy.get("base_scale")) if "base_scale" in enemy else 1.0
		var hit_trauma: float = clampf(0.03 + e_scale * 0.02, 0.03, 0.10)
		var bias: Vector3 = Vector3.ZERO
		if GameManager.player and is_instance_valid(GameManager.player):
			bias = (GameManager.player.global_position - enemy.global_position)
			bias.y = 0
			if bias.length_squared() > 0.01:
				bias = bias.normalized()
		if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
			GameManager.camera_rig.add_trauma(hit_trauma, bias)

	# ── Phase 16: Weapon mod on-hit effects ──
	_apply_mod_on_hit(enemy, total_damage)

	# Track this enemy as hit (for pierce/chain)
	_has_hit_enemies.append(enemy)

	# Phase 16: Piercing Beam — pass through enemies without being destroyed
	if _weapon_mod == GameConstants.WeaponMod.PIERCING_BEAM and _pierce_count < _max_pierces:
		_pierce_count += 1
		_impact_effect(_crit_impact_color(is_crit, will_kill))
		return  # Don't free — continue flying

	# Enhancement: Photon Beam — pierces through up to 5 enemies (more than Piercing Beam)
	if _weapon_mod == GameConstants.WeaponMod.PHOTON_BEAM and _pierce_count < 5:
		_pierce_count += 1
		_impact_effect(_crit_impact_color(is_crit, will_kill))
		return  # Don't free — continue flying

	# Enhancement: Spectral Beam — pierces through up to 4 enemies and phases
	# through walls. The spectral bypass flag was already set before calling
	# take_damage_from above, so Phase Shifter enemies take damage even when
	# intangible. Reset the flag after the hit.
	if _weapon_mod == GameConstants.WeaponMod.SPECTRAL_BEAM and _pierce_count < 4:
		_pierce_count += 1
		EnemyPhaseShifter.set_spectral_bypass(false)
		_impact_effect(_crit_impact_color(is_crit, will_kill))
		return  # Don't free — continue flying and phasing

	# Reset spectral bypass flag if it was set (non-pierce spectral hit)
	if _weapon_mod == GameConstants.WeaponMod.SPECTRAL_BEAM:
		EnemyPhaseShifter.set_spectral_bypass(false)

	# Phase 16: Splitter Laser — spawn two angled projectiles on hit
	if _weapon_mod == GameConstants.WeaponMod.SPLITTER_LASER:
		_spawn_splitter_projectiles(enemy)

	# Phase 16: Mega Blast / Plasma Nova — AoE explosion on impact
	if _weapon_mod == GameConstants.WeaponMod.MEGA_BLAST:
		_aoe_explosion(8.0, total_damage, Color(1.0, 0.3, 0.3))
	elif _weapon_mod == GameConstants.WeaponMod.PLASMA_NOVA:
		_aoe_explosion(6.0, total_damage, Color(1.0, 0.6, 0.9))
	elif _weapon_mod == GameConstants.WeaponMod.SHRAPNEL_BURST:
		_shrapnel_burst(total_damage)
	elif _weapon_mod == GameConstants.WeaponMod.ACID_TRAIL:
		_spawn_acid_pool(total_damage)
	# Enhancement: Black Hole Beam — create a singularity that sucks enemies in then collapses
	elif _weapon_mod == GameConstants.WeaponMod.BLACK_HOLE_BEAM:
		_spawn_black_hole(total_damage)
	# Enhancement: Magnet Mine — big AoE detonation on impact, pulls enemies in first
	elif _weapon_mod == GameConstants.WeaponMod.MAGNET_MINE:
		_spawn_magnet_mine_detonation(total_damage)
	# Phase 24: Black Hole Launcher — portable singularity collapse (bigger than Black Hole Beam)
	elif _weapon_mod == GameConstants.WeaponMod.BLACK_HOLE_LAUNCHER:
		_spawn_black_hole_launcher_collapse(total_damage)
	# Phase 24: Meteor Strike — call down a meteor at the impact point
	# Pass the original projectile damage (not the reduced bolt damage) so the
	# meteor's impact scales with the full mod damage.
	elif _weapon_mod == GameConstants.WeaponMod.METEOR_STRIKE:
		_call_meteor_strike(damage)
	# Phase 24: Poison Nova — expanding ring of poison + lingering cloud
	elif _weapon_mod == GameConstants.WeaponMod.POISON_NOVA:
		_spawn_poison_nova(total_damage)

	# Impact effect — crits and kills get a gold-tinted burst so they
	# read as distinct from normal cyan hits. The gold matches the crit
	# damage number color for a consistent color language. Kill blows
	# get a slightly warmer gold (more orange) to distinguish from crits.
	var impact_color: Color = Color(0.0, 0.0, 0.0, -1.0)  # Default: no override
	if is_boss_kill:
		# Boss kills get a magenta burst matching the "BOSS SLAIN!" popup
		impact_color = Color(1.0, 0.2, 0.8, 1.0)
	elif will_kill:
		# Kill blows get a warm gold-orange to distinguish from crits
		impact_color = Color(1.0, 0.7, 0.15, 1.0)
	elif is_crit:
		# Crits get bright gold matching the crit damage number
		impact_color = Color(1.0, 0.85, 0.2, 1.0)
	_impact_effect(impact_color)
	_is_consumed = true
	queue_free()

## Phase 16: Apply on-hit weapon mod effects (chain lightning, freeze, vampire, etc.)
func _apply_mod_on_hit(enemy: Node3D, dmg: int) -> void:
	match _weapon_mod:
		GameConstants.WeaponMod.CHAIN_LIGHTNING, GameConstants.WeaponMod.QUANTUM_OVERDRIVE:
			# Chain to nearby enemies
			_chain_lightning(enemy, dmg)
		GameConstants.WeaponMod.FREEZE_RAY:
			# Slow the enemy
			_freeze_enemy(enemy)
		GameConstants.WeaponMod.VAMPIRE_BEAM:
			# Heal Zorp for a portion of damage dealt
			var heal_amount: int = max(1, int(dmg * 0.25))
			GameManager.heal(heal_amount)
		GameConstants.WeaponMod.RICOCHET_PULSE:
			# Ricochet to nearest other enemy
			_ricochet_to_next(enemy, dmg)
		GameConstants.WeaponMod.BLAZE_TRAIL:
			# Set enemy on fire (burn damage over time)
			_set_enemy_on_fire(enemy, dmg)
		GameConstants.WeaponMod.VOID_RAY:
			# Slow + energy drain (reduce enemy speed)
			_freeze_enemy(enemy)
		GameConstants.WeaponMod.REFLECTIVE_SHIELD:
			# Defensive: no special on-hit, but the mod reduces incoming damage
			pass
		# Phase 24: Time Freeze Ray — freeze the enemy in time
		GameConstants.WeaponMod.TIME_FREEZE_RAY:
			_freeze_enemy_time(enemy)
		# Phase 24: Shrink Beam — shrink the enemy
		GameConstants.WeaponMod.SHRINK_BEAM:
			_shrink_enemy(enemy)
		# Phase 24: Lightning Storm — chain to many nearby enemies
		GameConstants.WeaponMod.LIGHTNING_STORM:
			_lightning_storm(enemy, dmg)

## Phase 16: Chain lightning — hit jumps to nearby enemies.
func _chain_lightning(source_enemy: Node3D, dmg: int) -> void:
	var chain_range: float = 8.0
	var chain_targets: int = 3
	var chained: Array[Node3D] = [source_enemy]
	var current: Node3D = source_enemy
	for i in range(chain_targets):
		var next: Node3D = null
		var next_dist: float = chain_range
		for enemy in GameManager.enemies:
			if not is_instance_valid(enemy):
				continue
			if not enemy.is_in_group("enemies"):
				continue
			if chained.has(enemy):
				continue
			var d: float = current.global_position.distance_to(enemy.global_position)
			if d < next_dist:
				next_dist = d
				next = enemy
		if next == null:
			break
		var chain_dmg: int = int(dmg * (0.6 - i * 0.15))  # Each jump does less
		if next.has_method("take_damage_from"):
			next.take_damage_from(chain_dmg, current.global_position)
		else:
			next.take_damage(chain_dmg)
		DamageNumber.spawn(get_parent(), next.global_position, chain_dmg, false, false)
		# Small lightning particle
		ParticleEffects.spawn_explosion(get_parent(), next.global_position, Color(0.6, 0.8, 1.0), 10, 0.25)
		chained.append(next)
		current = next

## Phase 16: Freeze an enemy (slow them down for 2 seconds).
func _freeze_enemy(enemy: Node3D) -> void:
	# Use the public set_time_scale() method (EnemyBase and ShadowClone both have it).
	# The private variable is _time_scale, so we must use the setter, not set("time_scale").
	if enemy.has_method("set_time_scale"):
		enemy.set_time_scale(0.3)
		# Schedule the unfreeze on the SceneTree (ignore_time_scale=true) so the
		# restore survives this projectile's queue_free() the same frame. A tween
		# bound to `self` would be killed on free and leave the enemy frozen at
		# 0.3× speed forever — the same class of bug we already fixed for hit-stop.
		var tree := get_tree()
		if tree:
			var timer := tree.create_timer(2.0, true, false, true)
			timer.timeout.connect(func():
				if is_instance_valid(enemy) and enemy.has_method("set_time_scale"):
					enemy.set_time_scale(1.0)
			)
	# Visual: ice particles
	ParticleEffects.spawn_explosion(get_parent(), enemy.global_position, Color(0.3, 0.9, 1.0), 12, 0.3)

## Phase 16: Ricochet — bounce damage to the next nearest enemy.
func _ricochet_to_next(source: Node3D, dmg: int) -> void:
	var nearest: Node3D = null
	var nearest_dist: float = 12.0
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.is_in_group("enemies"):
			continue
		if enemy == source:
			continue
		var d: float = source.global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	if nearest:
		var ricochet_dmg: int = int(dmg * 0.5)
		if nearest.has_method("take_damage_from"):
			nearest.take_damage_from(ricochet_dmg, source.global_position)
		else:
			nearest.take_damage(ricochet_dmg)
		DamageNumber.spawn(get_parent(), nearest.global_position, ricochet_dmg, false, false)

## Phase 16: Set enemy on fire (burn damage over 3 seconds).
func _set_enemy_on_fire(enemy: Node3D, dmg: int) -> void:
	var burn_dmg: int = max(2, int(dmg * 0.2))
	var burns_remaining: int = 3
	# Bind the burn tween to the enemy (not `self`) — this projectile queue_free()s
	# the same frame for non-piercing mods, which would kill a self-bound tween
	# and the burn would never tick. Tying it to the enemy also means the burn
	# continues correctly if the projectile is freed mid-pierce.
	if not is_instance_valid(enemy):
		return
	var tw := enemy.create_tween()
	tw.tween_interval(1.0)
	for _i in range(burns_remaining):
		tw.tween_callback(func():
			if is_instance_valid(enemy) and enemy.has_method("take_damage"):
				enemy.take_damage(burn_dmg)
				ParticleEffects.spawn_explosion(enemy.get_parent(), enemy.global_position, Color(1.0, 0.5, 0.2), 8, 0.2)
		)
		tw.tween_interval(1.0)

## Phase 16: AoE explosion — damage all enemies within radius.
func _aoe_explosion(radius: float, dmg: int, col: Color) -> void:
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.is_in_group("enemies"):
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < radius:
			var falloff: float = 1.0 - (d / radius) * 0.5  # 100% at center, 50% at edge
			var aoe_dmg: int = int(dmg * falloff * 0.6)
			if enemy.has_method("take_damage_from"):
				enemy.take_damage_from(aoe_dmg, global_position)
			else:
				enemy.take_damage(aoe_dmg)
	# Big explosion visual
	ParticleEffects.spawn_mega_explosion(get_parent(), global_position, col)
	# Light flash
	var flash := OmniLight3D.new()
	flash.light_color = col
	flash.light_energy = 5.0
	flash.omni_range = radius * 2.0
	get_parent().add_child(flash)
	var fade_tween := flash.create_tween()
	fade_tween.tween_property(flash, "light_energy", 0.0, 0.3)
	fade_tween.tween_callback(flash.queue_free)

## Phase 16: Shrapnel burst — spawn small fragment projectiles in all directions.
func _shrapnel_burst(base_dmg: int) -> void:
	var frag_count: int = 6
	for i in range(frag_count):
		var angle: float = (TAU * i) / frag_count
		var frag_dir: Vector3 = Vector3(cos(angle), 0.0, sin(angle)).normalized()
		# Create a small short-lived projectile (simplified — just damage nearby)
		var frag_dmg: int = int(base_dmg * 0.3)
		# Apply damage to enemies in the fragment direction
		for enemy in GameManager.enemies:
			if not is_instance_valid(enemy):
				continue
			if not enemy.is_in_group("enemies"):
				continue
			var to_enemy: Vector3 = (enemy.global_position - global_position).normalized()
			if frag_dir.dot(to_enemy) > 0.7:  # Within ~45° of fragment direction
				var d: float = global_position.distance_to(enemy.global_position)
				if d < 5.0 and not _has_hit_enemies.has(enemy):
					if enemy.has_method("take_damage"):
						enemy.take_damage(frag_dmg)
	# Shrapnel particle effect
	ParticleEffects.spawn_explosion(get_parent(), global_position, Color(0.7, 0.5, 0.2), 20, 0.4)

## Phase 16: Splitter — spawn two angled child projectiles on hit.
func _spawn_splitter_projectiles(_hit_enemy: Node3D) -> void:
	# Spawn two small angled projectiles
	for angle in [0.3, -0.3]:
		var split_dir: Vector3 = direction.rotated(Vector3.UP, angle)
		var proj: Area3D = PROJECTILE_SCENE.instantiate()
		# Set properties BEFORE adding to tree so _ready() picks them up.
		# set_weapon_mod must be called before _ready() so the per-projectile
		# material is created with the correct mod color.
		proj.set("direction", split_dir)
		proj.set("damage", int(damage * 0.6))
		proj.set("speed", speed)
		# Don't make splitter projectiles split again (avoid infinite recursion)
		# They use the same mod color but NONE behavior
		if proj.has_method("set_weapon_mod"):
			proj.set_weapon_mod(GameConstants.WeaponMod.NONE, _mod_color)
		get_parent().add_child(proj)
		proj.global_position = global_position

## Phase 16: Acid Trail — spawn a lingering acid pool that damages enemies over time.
func _spawn_acid_pool(base_dmg: int) -> void:
	# Create an Area3D that damages enemies within it for 3 seconds
	var pool := Area3D.new()
	var pool_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.5
	pool_shape.shape = sphere
	pool.add_child(pool_shape)
	get_parent().add_child(pool)
	pool.global_position = global_position
	# Visual: green translucent sphere
	var pool_mesh := MeshInstance3D.new()
	var pool_sphere_mesh := SphereMesh.new()
	pool_sphere_mesh.radius = 2.5
	pool_sphere_mesh.height = 0.5  # Flat pool
	pool_sphere_mesh.radial_segments = 12
	pool_mesh.mesh = pool_sphere_mesh
	var pool_mat := StandardMaterial3D.new()
	pool_mat.albedo_color = Color(0.4, 0.8, 0.2, 0.4)
	pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_mat.emission_enabled = true
	pool_mat.emission = Color(0.3, 0.6, 0.1)
	pool_mat.emission_energy_multiplier = 0.8
	pool_mesh.material_override = pool_mat
	pool.add_child(pool_mesh)
	# Damage over time: check every 0.5s for 3s
	var ticks: int = 6
	var tick_dmg: int = max(3, int(base_dmg * 0.2))
	var tw := pool.create_tween()
	for _i in range(ticks):
		tw.tween_callback(func():
			if not is_instance_valid(pool):
				return
			for enemy in GameManager.enemies:
				if not is_instance_valid(enemy):
					continue
				if not enemy.is_in_group("enemies"):
					continue
				if pool.global_position.distance_to(enemy.global_position) < 2.5:
					if enemy.has_method("take_damage"):
						enemy.take_damage(tick_dmg)
			# Spawn small acid bubble particles
			ParticleEffects.spawn_explosion(pool.get_parent(), pool.global_position, Color(0.4, 0.8, 0.2), 5, 0.15)
		)
		tw.tween_interval(0.5)
	# Fade out and free
	tw.tween_property(pool_mat, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(pool.queue_free)

## Returns the impact burst color for a hit based on crit/kill status.
## Crits → gold, kills → warm gold-orange, boss kills → magenta, normal → cyan.
## Used by pierce-type mods that call _impact_effect() on each pierced enemy.
func _crit_impact_color(is_crit: bool, is_kill: bool) -> Color:
	if is_kill:
		return Color(1.0, 0.7, 0.15, 1.0)
	elif is_crit:
		return Color(1.0, 0.85, 0.2, 1.0)
	return Color(0.0, 0.0, 0.0, -1.0)  # Default: no override (cyan)

func _impact_effect(override_color: Color = Color(0.0, 0.0, 0.0, -1.0)) -> void:
	# Spawn impact burst effect
	if IMPACT_SCENE:
		var burst: Node3D = IMPACT_SCENE.instantiate()
		get_parent().add_child(burst)
		burst.global_position = global_position
		# ── Crit / kill color override ── A crit or kill gets a gold-tinted
		# impact burst instead of the default cyan, so critical hits are
		# visually distinct at the impact point — the player sees a gold
		# flash on crits and a cyan flash on normal hits. This reinforces
		# the gold crit damage number and gives crits a consistent color
		# language across UI + world effects.
		if override_color.a >= 0.0 and burst.has_method("set") and "impact_color" in burst:
			burst.set("impact_color", override_color)
	# Phase 6: Small explosion particles on impact — tinted to match the
	# override color (gold for crits, cyan for normal hits) so the particle
	# burst and the impact sphere share the same color identity.
	var particle_color: Color = override_color if override_color.a >= 0.0 else Color(0.2, 1.0, 0.8)
	ParticleEffects.spawn_explosion(get_parent(), global_position, particle_color, 12, 0.4)
	# Phase 20: Audio — explosion SFX on impact
	AudioManager.play_sfx(AudioManager.SFX_EXPLOSION)

## Enhancement: Black Hole Beam — spawn a singularity that pulls enemies in
## over 1.5 seconds, then collapses for AoE damage. The singularity is a
## visual Area3D with a swirling dark sphere that grows, pulls enemies, then
## detonates. This is a powerful crowd-control mod — group enemies together
## then hit them with the collapse.
func _spawn_black_hole(base_dmg: int) -> void:
	var parent: Node = get_parent()
	if not parent:
		return
	# The singularity lives for 1.5s, pulling enemies toward its center
	var singularity := Area3D.new()
	var s_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0  # Collision radius (visual is larger)
	s_shape.shape = sphere
	singularity.add_child(s_shape)
	parent.add_child(singularity)
	singularity.global_position = global_position

	# Visual: dark swirling sphere with purple emission
	var bh_mesh := MeshInstance3D.new()
	var bh_sphere := SphereMesh.new()
	bh_sphere.radius = 1.5
	bh_sphere.height = 3.0
	bh_sphere.radial_segments = 16
	bh_sphere.rings = 8
	bh_mesh.mesh = bh_sphere
	var bh_mat := StandardMaterial3D.new()
	bh_mat.albedo_color = Color(0.05, 0.0, 0.1, 0.7)
	bh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bh_mat.emission_enabled = true
	bh_mat.emission = Color(0.3, 0.0, 0.5)
	bh_mat.emission_energy_multiplier = 2.0
	bh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bh_mesh.material_override = bh_mat
	singularity.add_child(bh_mesh)

	# Dark light — absorbs light around the singularity
	var bh_light := OmniLight3D.new()
	bh_light.light_color = Color(0.2, 0.0, 0.4)
	bh_light.light_energy = -2.0  # Negative = darkens surrounding area
	bh_light.omni_range = 8.0
	singularity.add_child(bh_light)

	# Pull phase: 1.2s of pulling enemies toward the center
	var pull_duration: float = 1.2
	var pull_radius: float = 10.0
	var pull_tween := singularity.create_tween()
	# Grow the visual sphere during pull phase
	pull_tween.tween_property(bh_mesh, "scale", Vector3(1.5, 1.5, 1.5), pull_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Pulsing light
	pull_tween.parallel().tween_property(bh_light, "light_energy", -4.0, pull_duration)

	# Tick pull damage every 0.2s during the pull phase
	var ticks: int = int(pull_duration / 0.2)
	var tick_tween := singularity.create_tween()
	for _i in range(ticks):
		tick_tween.tween_callback(func():
			if not is_instance_valid(singularity):
				return
			for enemy in GameManager.enemies:
				if not is_instance_valid(enemy):
					continue
				if not enemy.is_in_group("enemies"):
					continue
				var d: float = singularity.global_position.distance_to(enemy.global_position)
				if d < pull_radius and d > 0.5:
					# Strong pull toward center
					var pull_dir: Vector3 = (singularity.global_position - enemy.global_position).normalized()
					enemy.global_position += pull_dir * 8.0 * 0.2  # 8 m/s pull
					# Small tick damage
					if enemy.has_method("take_damage"):
						enemy.take_damage(max(1, int(base_dmg * 0.1)))
		)
		tick_tween.tween_interval(0.2)

	# Collapse phase: detonate for AoE damage
	tick_tween.tween_callback(func():
		if not is_instance_valid(singularity):
			return
		# Collapse explosion — damage all enemies in the pull radius
		var collapse_dmg: int = int(base_dmg * 1.5)
		for enemy in GameManager.enemies:
			if not is_instance_valid(enemy):
				continue
			if not enemy.is_in_group("enemies"):
				continue
			var d: float = singularity.global_position.distance_to(enemy.global_position)
			if d < pull_radius:
				var falloff: float = 1.0 - (d / pull_radius) * 0.5
				var collapse_hit: int = int(collapse_dmg * falloff)
				if enemy.has_method("take_damage_from"):
					enemy.take_damage_from(collapse_hit, singularity.global_position)
				elif enemy.has_method("take_damage"):
					enemy.take_damage(collapse_hit)
		# Big collapse visual
		ParticleEffects.spawn_mega_explosion(singularity.get_parent(),
			singularity.global_position, Color(0.3, 0.0, 0.5))
		# Collapse light flash
		var flash := OmniLight3D.new()
		flash.light_color = Color(0.5, 0.1, 0.8)
		flash.light_energy = 8.0
		flash.omni_range = 12.0
		singularity.get_parent().add_child(flash)
		flash.global_position = singularity.global_position
		var flash_tw := flash.create_tween()
		flash_tw.tween_property(flash, "light_energy", 0.0, 0.4)
		flash_tw.tween_callback(flash.queue_free)
		# Camera shake on collapse
		if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
			GameManager.camera_rig.add_trauma(0.4)
	)
	# Shrink and fade the singularity after collapse
	tick_tween.tween_property(bh_mesh, "scale", Vector3.ZERO, 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tick_tween.tween_property(bh_mat, "albedo_color:a", 0.0, 0.2)
	tick_tween.tween_callback(singularity.queue_free)

## Enhancement: Magnet Mine — on impact, pull nearby enemies toward the detonation
## point for 0.6s, then explode for big AoE damage. The mine homes in flight
## (handled in _apply_mod_flight_behavior), so by the time it hits an enemy it's
## likely in the middle of a group — the pull + detonation cleans up clusters.
func _spawn_magnet_mine_detonation(base_dmg: int) -> void:
	var parent: Node = get_parent()
	if not parent:
		return
	# Pull phase: 0.6s of pulling enemies toward the detonation point
	var pull_duration: float = 0.6
	var pull_radius: float = 9.0
	var mine_pos: Vector3 = global_position
	# Visual: orange-red glowing sphere that pulses during pull
	var mine_node := Area3D.new()
	parent.add_child(mine_node)
	mine_node.global_position = mine_pos
	var mine_mesh := MeshInstance3D.new()
	var mine_sphere := SphereMesh.new()
	mine_sphere.radius = 0.8
	mine_sphere.height = 1.6
	mine_sphere.radial_segments = 12
	mine_mesh.mesh = mine_sphere
	var mine_mat := StandardMaterial3D.new()
	mine_mat.albedo_color = Color(0.9, 0.4, 0.1)
	mine_mat.emission_enabled = true
	mine_mat.emission = Color(1.0, 0.5, 0.1)
	mine_mat.emission_energy_multiplier = 2.5
	mine_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mine_mesh.material_override = mine_mat
	mine_node.add_child(mine_mesh)
	# Pulsing light
	var mine_light := OmniLight3D.new()
	mine_light.light_color = Color(1.0, 0.5, 0.1)
	mine_light.light_energy = 4.0
	mine_light.omni_range = 10.0
	mine_node.add_child(mine_light)

	# Pull tween: pulse the light and grow the mesh
	var pull_tween := mine_node.create_tween()
	pull_tween.tween_property(mine_mesh, "scale", Vector3(1.8, 1.8, 1.8), pull_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	pull_tween.parallel().tween_property(mine_light, "light_energy", 8.0, pull_duration)

	# Tick pull enemies every 0.15s during the pull phase
	var ticks: int = int(pull_duration / 0.15)
	var tick_tween := mine_node.create_tween()
	for _i in range(ticks):
		tick_tween.tween_callback(func():
			if not is_instance_valid(mine_node):
				return
			for enemy in GameManager.enemies:
				if not is_instance_valid(enemy):
					continue
				if not enemy.is_in_group("enemies"):
					continue
				var d: float = mine_node.global_position.distance_to(enemy.global_position)
				if d < pull_radius and d > 0.5:
					var pull_dir: Vector3 = (mine_node.global_position - enemy.global_position).normalized()
					enemy.global_position += pull_dir * 10.0 * 0.15
		)
		tick_tween.tween_interval(0.15)

	# Detonation: big AoE damage
	tick_tween.tween_callback(func():
		if not is_instance_valid(mine_node):
			return
		var detonation_dmg: int = int(base_dmg * 1.6)
		for enemy in GameManager.enemies:
			if not is_instance_valid(enemy):
				continue
			if not enemy.is_in_group("enemies"):
				continue
			var d: float = mine_node.global_position.distance_to(enemy.global_position)
			if d < pull_radius:
				var falloff: float = 1.0 - (d / pull_radius) * 0.4
				var hit_dmg: int = int(detonation_dmg * falloff)
				if enemy.has_method("take_damage_from"):
					enemy.take_damage_from(hit_dmg, mine_node.global_position)
				elif enemy.has_method("take_damage"):
					enemy.take_damage(hit_dmg)
		# Big explosion visual
		ParticleEffects.spawn_mega_explosion(mine_node.get_parent(),
			mine_node.global_position, Color(1.0, 0.5, 0.1))
		# Detonation light flash
		var flash := OmniLight3D.new()
		flash.light_color = Color(1.0, 0.6, 0.2)
		flash.light_energy = 10.0
		flash.omni_range = 15.0
		mine_node.get_parent().add_child(flash)
		flash.global_position = mine_node.global_position
		var flash_tw := flash.create_tween()
		flash_tw.tween_property(flash, "light_energy", 0.0, 0.5)
		flash_tw.tween_callback(flash.queue_free)
		# Camera shake
		if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
			GameManager.camera_rig.add_trauma(0.45)
	)
	# Shrink and fade the mine after detonation
	tick_tween.tween_property(mine_mesh, "scale", Vector3.ZERO, 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tick_tween.tween_property(mine_mat, "albedo_color:a", 0.0, 0.2)
	tick_tween.tween_callback(mine_node.queue_free)

# ── Phase 24: New Weapon Mod Behaviors ───────────────────────────────────────

## Phase 24: Black Hole Launcher — spawn a portable singularity that collapses
## for massive AoE damage. Larger pull radius and bigger collapse than the Black
## Hole Beam. The singularity grows during a brief pull phase, then detonates.
func _spawn_black_hole_launcher_collapse(base_dmg: int) -> void:
	var parent: Node = get_parent()
	if not parent:
		return
	var singularity := Area3D.new()
	var s_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.5
	s_shape.shape = sphere
	singularity.add_child(s_shape)
	parent.add_child(singularity)
	singularity.global_position = global_position

	# Visual: dark swirling sphere with purple emission (larger than Black Hole Beam)
	var bh_mesh := MeshInstance3D.new()
	var bh_sphere := SphereMesh.new()
	bh_sphere.radius = 2.0
	bh_sphere.height = 4.0
	bh_sphere.radial_segments = 18
	bh_sphere.rings = 9
	bh_mesh.mesh = bh_sphere
	var bh_mat := StandardMaterial3D.new()
	bh_mat.albedo_color = Color(0.05, 0.0, 0.15, 0.8)
	bh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bh_mat.emission_enabled = true
	bh_mat.emission = Color(0.4, 0.0, 0.6)
	bh_mat.emission_energy_multiplier = 2.5
	bh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bh_mesh.material_override = bh_mat
	singularity.add_child(bh_mesh)

	# Dark light — absorbs surrounding light
	var bh_light := OmniLight3D.new()
	bh_light.light_color = Color(0.2, 0.0, 0.4)
	bh_light.light_energy = -3.0
	bh_light.omni_range = 12.0
	singularity.add_child(bh_light)

	# Pull phase: 0.8s of pulling enemies toward the center
	var pull_duration: float = 0.8
	var pull_radius: float = GameConstants.BLACK_HOLE_LAUNCHER_COLLAPSE_RADIUS
	var pull_tween := singularity.create_tween()
	pull_tween.tween_property(bh_mesh, "scale", Vector3(1.8, 1.8, 1.8), pull_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	pull_tween.parallel().tween_property(bh_light, "light_energy", -6.0, pull_duration)

	# Tick pull damage every 0.15s during the pull phase
	var ticks: int = int(pull_duration / 0.15)
	var tick_tween := singularity.create_tween()
	for _i in range(ticks):
		tick_tween.tween_callback(func():
			if not is_instance_valid(singularity):
				return
			for enemy in GameManager.enemies:
				if not is_instance_valid(enemy):
					continue
				if not enemy.is_in_group("enemies"):
					continue
				var d: float = singularity.global_position.distance_to(enemy.global_position)
				if d < pull_radius and d > 0.5:
					var pull_dir: Vector3 = (singularity.global_position - enemy.global_position).normalized()
					enemy.global_position += pull_dir * 12.0 * 0.15
					if enemy.has_method("take_damage"):
						enemy.take_damage(max(1, int(base_dmg * 0.08)))
		)
		tick_tween.tween_interval(0.15)

	# Collapse phase: detonate for massive AoE damage
	tick_tween.tween_callback(func():
		if not is_instance_valid(singularity):
			return
		var collapse_dmg: int = int(base_dmg * GameConstants.BLACK_HOLE_LAUNCHER_COLLAPSE_MULT)
		for enemy in GameManager.enemies:
			if not is_instance_valid(enemy):
				continue
			if not enemy.is_in_group("enemies"):
				continue
			var d: float = singularity.global_position.distance_to(enemy.global_position)
			if d < pull_radius:
				var falloff: float = 1.0 - (d / pull_radius) * 0.4
				var collapse_hit: int = int(collapse_dmg * falloff)
				if enemy.has_method("take_damage_from"):
					enemy.take_damage_from(collapse_hit, singularity.global_position)
				elif enemy.has_method("take_damage"):
					enemy.take_damage(collapse_hit)
		# Massive collapse visual
		ParticleEffects.spawn_mega_explosion(singularity.get_parent(),
			singularity.global_position, Color(0.4, 0.0, 0.6))
		# Collapse light flash
		var flash := OmniLight3D.new()
		flash.light_color = Color(0.6, 0.1, 0.9)
		flash.light_energy = 10.0
		flash.omni_range = 16.0
		singularity.get_parent().add_child(flash)
		flash.global_position = singularity.global_position
		var flash_tw := flash.create_tween()
		flash_tw.tween_property(flash, "light_energy", 0.0, 0.5)
		flash_tw.tween_callback(flash.queue_free)
		# Camera shake on collapse
		if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
			GameManager.camera_rig.add_trauma(0.5)
	)
	# Shrink and fade the singularity after collapse
	tick_tween.tween_property(bh_mesh, "scale", Vector3.ZERO, 0.25) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tick_tween.tween_property(bh_mat, "albedo_color:a", 0.0, 0.25)
	tick_tween.tween_callback(singularity.queue_free)

## Phase 24: Time Freeze Ray — freeze the enemy in time for 3 seconds. While
## frozen the enemy can't move, attack, or take damage from other sources.
## The freeze is applied via set_time_scale(0.0). A timer restores it.
func _freeze_enemy_time(enemy: Node3D) -> void:
	if not enemy or not is_instance_valid(enemy):
		return
	if not enemy.has_method("set_time_scale"):
		return
	enemy.set_time_scale(0.0)
	# Visual: ice crystals around the frozen enemy
	ParticleEffects.spawn_explosion(get_parent(), enemy.global_position,
		Color(0.6, 0.85, 1.0), 16, 0.4)
	# Schedule unfreeze — use a scene-tree timer so it survives if this projectile dies
	var tree := get_tree()
	if tree:
		var timer := tree.create_timer(GameConstants.TIME_FREEZE_RAY_DURATION, true, false, true)
		timer.timeout.connect(func():
			if is_instance_valid(enemy) and enemy.has_method("set_time_scale"):
				enemy.set_time_scale(1.0)
				# Shatter effect on unfreeze
				ParticleEffects.spawn_explosion(enemy.get_parent(), enemy.global_position,
					Color(0.6, 0.85, 1.0), 10, 0.3)
		)
	# Brief ice light on the enemy
	var ice_light := OmniLight3D.new()
	ice_light.light_color = Color(0.6, 0.85, 1.0)
	ice_light.light_energy = 2.0
	ice_light.omni_range = 4.0
	get_parent().add_child(ice_light)
	ice_light.global_position = enemy.global_position + Vector3(0, 1.0, 0)
	var light_tw := ice_light.create_tween()
	light_tw.tween_property(ice_light, "light_energy", 0.0, 0.5)
	light_tw.tween_callback(ice_light.queue_free)

## Phase 24: Shrink Beam — shrink the enemy for 5 seconds. While shrunk the
## enemy moves at SHRINK_BEAM_SPEED_MULT, deals SHRINK_BEAM_DAMAGE_MULT damage,
## and is visually scaled down. The effect is applied by reducing the enemy's
## speed and storing the original values for restoration.
func _shrink_enemy(enemy: Node3D) -> void:
	if not enemy or not is_instance_valid(enemy):
		return
	# Avoid double-shrinking — if already shrunk, just refresh the timer via meta
	if enemy.has_meta("is_shrunk") and enemy.get_meta("is_shrunk", false):
		# Refresh: reset the restore timer
		enemy.set_meta("shrink_restore_time", Time.get_ticks_msec() / 1000.0 + GameConstants.SHRINK_BEAM_DURATION)
		return
	# Store original values
	var original_speed: float = float(enemy.get("speed")) if "speed" in enemy else 1.0
	var original_damage: int = int(enemy.get("damage")) if "damage" in enemy else 10
	var original_scale: Vector3 = enemy.scale if enemy is Node3D else Vector3.ONE
	enemy.set_meta("is_shrunk", true)
	enemy.set_meta("shrink_original_speed", original_speed)
	enemy.set_meta("shrink_original_damage", original_damage)
	enemy.set_meta("shrink_original_scale", original_scale)
	enemy.set_meta("shrink_restore_time", Time.get_ticks_msec() / 1000.0 + GameConstants.SHRINK_BEAM_DURATION)
	# Apply shrink effects
	if "speed" in enemy:
		enemy.set("speed", original_speed * GameConstants.SHRINK_BEAM_SPEED_MULT)
	if "damage" in enemy:
		enemy.set("damage", int(original_damage * GameConstants.SHRINK_BEAM_DAMAGE_MULT))
	# Visual scale-down
	var shrink_scale := original_scale * GameConstants.SHRINK_BEAM_SCALE_MULT
	var shrink_tw := enemy.create_tween()
	shrink_tw.tween_property(enemy, "scale", shrink_scale, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Green aura visual
	ParticleEffects.spawn_explosion(get_parent(), enemy.global_position,
		Color(0.4, 0.9, 0.3), 14, 0.4)
	# Schedule restore — poll via a tween that checks the restore time
	var restore_tw := enemy.create_tween()
	restore_tw.tween_interval(GameConstants.SHRINK_BEAM_DURATION)
	restore_tw.tween_callback(func():
		if not is_instance_valid(enemy):
			return
		if not enemy.get_meta("is_shrunk", false):
			return  # Already restored (e.g. by another effect)
		enemy.set_meta("is_shrunk", false)
		if "speed" in enemy:
			enemy.set("speed", original_speed)
		if "damage" in enemy:
			enemy.set("damage", original_damage)
		# Restore scale (only if the enemy hasn't died and been freed)
		if is_instance_valid(enemy):
			var restore_scale_tw := enemy.create_tween()
			restore_scale_tw.tween_property(enemy, "scale", original_scale, 0.3) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
			# Green burst on restore
			ParticleEffects.spawn_explosion(enemy.get_parent(), enemy.global_position,
				Color(0.4, 0.9, 0.3), 10, 0.3)
	)

## Phase 24: Lightning Storm — chain lightning to up to 8 nearby enemies with
## damage falloff per jump. Visualized with electric arc particles between hits.
func _lightning_storm(source_enemy: Node3D, dmg: int) -> void:
	var chain_range: float = GameConstants.LIGHTNING_STORM_CHAIN_RANGE
	var max_targets: int = GameConstants.LIGHTNING_STORM_MAX_TARGETS
	var chained: Array[Node3D] = [source_enemy]
	var current: Node3D = source_enemy
	var current_dmg: int = dmg
	for i in range(max_targets):
		var next: Node3D = null
		var next_dist: float = chain_range
		for enemy in GameManager.enemies:
			if not is_instance_valid(enemy):
				continue
			if not enemy.is_in_group("enemies"):
				continue
			if chained.has(enemy):
				continue
			var d: float = current.global_position.distance_to(enemy.global_position)
			if d < next_dist:
				next_dist = d
				next = enemy
		if next == null:
			break
		# Falloff per jump
		current_dmg = int(current_dmg * (1.0 - GameConstants.LIGHTNING_STORM_FALLOFF_PER_JUMP))
		if next.has_method("take_damage_from"):
			next.take_damage_from(current_dmg, current.global_position)
		else:
			next.take_damage(current_dmg)
		DamageNumber.spawn(get_parent(), next.global_position, current_dmg, false, false)
		# Electric arc particle between current and next
		var arc_mid: Vector3 = (current.global_position + next.global_position) / 2.0
		ParticleEffects.spawn_explosion(get_parent(), arc_mid,
			Color(0.7, 0.85, 1.0), 12, 0.3)
		# Small spark at the hit enemy
		ParticleEffects.spawn_explosion(get_parent(), next.global_position,
			Color(0.7, 0.85, 1.0), 8, 0.2)
		chained.append(next)
		current = next

## Phase 24: Meteor Strike — call down a meteor at the bolt's impact point.
## The bolt itself deals small damage (METEOR_STRIKE_BOLT_DAMAGE); the meteor
## falls from the sky after a short delay, dealing massive AoE damage on impact.
func _call_meteor_strike(base_dmg: int) -> void:
	var parent: Node = get_parent()
	if not parent:
		return
	var impact_pos: Vector3 = global_position
	# Telegraph: glowing ground patch at the impact point
	var telegraph := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = GameConstants.METEOR_STRIKE_RADIUS
	disc.bottom_radius = GameConstants.METEOR_STRIKE_RADIUS
	disc.height = 0.15
	telegraph.mesh = disc
	var tg_mat := StandardMaterial3D.new()
	tg_mat.albedo_color = Color(1.0, 0.4, 0.1, 0.5)
	tg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tg_mat.emission_enabled = true
	tg_mat.emission = Color(1.0, 0.4, 0.1)
	tg_mat.emission_energy_multiplier = 1.5
	tg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tg_mat.no_depth_test = true
	telegraph.material_override = tg_mat
	parent.add_child(telegraph)
	telegraph.global_position = impact_pos + Vector3(0, 0.1, 0)
	# Pulse the telegraph during the fall time
	var tg_tween := telegraph.create_tween()
	for _i in range(4):
		tg_tween.tween_property(tg_mat, "emission_energy_multiplier", 0.5, 0.1)
		tg_tween.tween_property(tg_mat, "emission_energy_multiplier", 2.5, 0.1)
	# Spawn the falling meteor visual
	var meteor := MeshInstance3D.new()
	var meteor_mesh := SphereMesh.new()
	meteor_mesh.radius = 1.5
	meteor_mesh.height = 3.0
	meteor_mesh.radial_segments = 12
	meteor_mesh.rings = 6
	meteor.mesh = meteor_mesh
	var m_mat := StandardMaterial3D.new()
	m_mat.albedo_color = Color(1.0, 0.4, 0.1)
	m_mat.emission_enabled = true
	m_mat.emission = Color(1.0, 0.5, 0.1)
	m_mat.emission_energy_multiplier = 3.0
	m_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	meteor.material_override = m_mat
	parent.add_child(meteor)
	meteor.global_position = impact_pos + Vector3(0, GameConstants.METEOR_STRIKE_FALL_HEIGHT, 0)
	# Trail light on the meteor
	var meteor_light := OmniLight3D.new()
	meteor_light.light_color = Color(1.0, 0.5, 0.1)
	meteor_light.light_energy = 5.0
	meteor_light.omni_range = 8.0
	meteor.add_child(meteor_light)
	# Drop the meteor via tween
	var drop_tw := meteor.create_tween()
	drop_tw.tween_property(meteor, "global_position:y",
		impact_pos.y + 1.0, GameConstants.METEOR_STRIKE_FALL_TIME) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# Spin the meteor as it falls
	drop_tw.parallel().tween_property(meteor, "rotation_degrees:y",
		720.0, GameConstants.METEOR_STRIKE_FALL_TIME)
	# On impact: massive AoE damage + explosion + camera shake
	drop_tw.tween_callback(func():
		if not is_instance_valid(meteor):
			return
		# AoE damage
		var impact_dmg: int = int(base_dmg * GameConstants.METEOR_STRIKE_IMPACT_MULT)
		for enemy in GameManager.enemies:
			if not is_instance_valid(enemy):
				continue
			if not enemy.is_in_group("enemies"):
				continue
			var d: float = meteor.global_position.distance_to(enemy.global_position)
			if d < GameConstants.METEOR_STRIKE_RADIUS:
				var falloff: float = 1.0 - (d / GameConstants.METEOR_STRIKE_RADIUS) * 0.4
				var hit_dmg: int = int(impact_dmg * falloff)
				if enemy.has_method("take_damage_from"):
					enemy.take_damage_from(hit_dmg, meteor.global_position)
				elif enemy.has_method("take_damage"):
					enemy.take_damage(hit_dmg)
		# Massive explosion visual
		ParticleEffects.spawn_mega_explosion(meteor.get_parent(),
			meteor.global_position, Color(1.0, 0.4, 0.1))
		# Impact light flash
		var flash := OmniLight3D.new()
		flash.light_color = Color(1.0, 0.5, 0.1)
		flash.light_energy = 12.0
		flash.omni_range = 18.0
		meteor.get_parent().add_child(flash)
		flash.global_position = meteor.global_position
		var flash_tw := flash.create_tween()
		flash_tw.tween_property(flash, "light_energy", 0.0, 0.5)
		flash_tw.tween_callback(flash.queue_free)
		# Camera shake
		if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
			GameManager.camera_rig.add_trauma(0.6)
		# Remove the meteor + telegraph
		meteor.queue_free()
		if is_instance_valid(telegraph):
			telegraph.queue_free()
	)

## Phase 24: Poison Nova — expanding ring of poison that damages all enemies it
## touches, plus a lingering poison cloud at the impact point for DoT.
func _spawn_poison_nova(base_dmg: int) -> void:
	var parent: Node = get_parent()
	if not parent:
		return
	var nova_pos: Vector3 = global_position
	# Expanding ring visual
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.5
	ring_mesh.bottom_radius = 0.5
	ring_mesh.height = 0.3
	ring_mesh.radial_segments = 24
	ring_mesh.rings = 2
	ring.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.5, 0.9, 0.2, 0.7)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.5, 0.9, 0.2) * 0.6
	ring_mat.emission_energy_multiplier = 2.0
	ring_mat.no_depth_test = true
	ring.material_override = ring_mat
	parent.add_child(ring)
	ring.global_position = nova_pos + Vector3(0, 0.3, 0)
	# Light flash
	var nova_light := OmniLight3D.new()
	nova_light.light_color = Color(0.5, 0.9, 0.2)
	nova_light.light_energy = 4.0
	nova_light.omni_range = 8.0
	parent.add_child(nova_light)
	nova_light.global_position = nova_pos + Vector3(0, 1.0, 0)
	# Track which enemies the ring has already hit (each enemy hit once)
	var hit_enemies: Array[Node3D] = []
	# Expand the ring via a manual tween (we need per-frame hit detection)
	var expand_duration: float = GameConstants.POISON_NOVA_RADIUS / GameConstants.POISON_NOVA_EXPAND_SPEED
	var expand_tw := ring.create_tween()
	# Use tween_method to update the ring each frame
	expand_tw.tween_method(func(t: float):
		if not is_instance_valid(ring):
			return
		var current_radius: float = t * GameConstants.POISON_NOVA_RADIUS
		# Scale the ring (base mesh radius is 0.5)
		var ring_scale_v := Vector3(current_radius / 0.5, 1.0, current_radius / 0.5)
		ring.scale = ring_scale_v
		# Fade as it expands
		var fade: float = 1.0 - t
		ring_mat.albedo_color.a = 0.7 * fade
		ring_mat.emission_energy_multiplier = 2.0 * fade
		nova_light.light_energy = 4.0 * fade
		# Hit detection — damage enemies near the ring edge
		for enemy in GameManager.enemies:
			if not is_instance_valid(enemy):
				continue
			if not enemy.is_in_group("enemies"):
				continue
			if hit_enemies.has(enemy):
				continue
			var d: float = ring.global_position.distance_to(enemy.global_position)
			if abs(d - current_radius) < 1.5:
				if enemy.has_method("take_damage_from"):
					enemy.take_damage_from(GameConstants.POISON_NOVA_RING_DAMAGE, ring.global_position)
				elif enemy.has_method("take_damage"):
					enemy.take_damage(GameConstants.POISON_NOVA_RING_DAMAGE)
				hit_enemies.append(enemy)
	, 0.0, 1.0, expand_duration)
	expand_tw.tween_callback(ring.queue_free)
	# Fade the light
	var light_tw := nova_light.create_tween()
	light_tw.tween_property(nova_light, "light_energy", 0.0, expand_duration + 0.2)
	light_tw.tween_callback(nova_light.queue_free)
	# Spawn the lingering poison cloud at the impact point
	_spawn_poison_nova_cloud(nova_pos, base_dmg)

## Spawn a lingering poison cloud at the nova's impact point for DoT.
func _spawn_poison_nova_cloud(cloud_pos: Vector3, base_dmg: int) -> void:
	var parent: Node = get_parent()
	if not parent:
		return
	var cloud := Area3D.new()
	var cloud_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = GameConstants.POISON_NOVA_CLOUD_RADIUS
	cloud_shape.shape = sphere
	cloud.add_child(cloud_shape)
	parent.add_child(cloud)
	cloud.global_position = cloud_pos
	# Visual: green translucent sphere
	var cloud_mesh := MeshInstance3D.new()
	var cloud_sphere := SphereMesh.new()
	cloud_sphere.radius = GameConstants.POISON_NOVA_CLOUD_RADIUS
	cloud_sphere.height = 1.0  # Flat pool
	cloud_sphere.radial_segments = 14
	cloud_mesh.mesh = cloud_sphere
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(0.5, 0.9, 0.2, 0.4)
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.emission_enabled = true
	cloud_mat.emission = Color(0.4, 0.7, 0.1)
	cloud_mat.emission_energy_multiplier = 1.0
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.no_depth_test = true
	cloud_mesh.material_override = cloud_mat
	cloud.add_child(cloud_mesh)
	# Cloud light
	var cloud_light := OmniLight3D.new()
	cloud_light.light_color = Color(0.5, 0.9, 0.2)
	cloud_light.light_energy = 1.5
	cloud_light.omni_range = GameConstants.POISON_NOVA_CLOUD_RADIUS
	cloud.add_child(cloud_light)
	# DoT ticks
	var ticks: int = int(GameConstants.POISON_NOVA_CLOUD_DURATION / GameConstants.POISON_NOVA_CLOUD_TICK_INTERVAL)
	var tick_dmg: int = GameConstants.POISON_NOVA_CLOUD_DAMAGE_PER_TICK
	var tw := cloud.create_tween()
	for _i in range(ticks):
		tw.tween_callback(func():
			if not is_instance_valid(cloud):
				return
			for enemy in GameManager.enemies:
				if not is_instance_valid(enemy):
					continue
				if not enemy.is_in_group("enemies"):
					continue
				if cloud.global_position.distance_to(enemy.global_position) < GameConstants.POISON_NOVA_CLOUD_RADIUS:
					if enemy.has_method("take_damage"):
						enemy.take_damage(tick_dmg)
			# Small bubble particles
			ParticleEffects.spawn_explosion(cloud.get_parent(), cloud.global_position,
				Color(0.5, 0.9, 0.2), 5, 0.15)
		)
		tw.tween_interval(GameConstants.POISON_NOVA_CLOUD_TICK_INTERVAL)
	# Fade out and free
	tw.tween_property(cloud_mat, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(cloud.queue_free)