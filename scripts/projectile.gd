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
var _light: OmniLight3D = null
var _mod_material: StandardMaterial3D = null  # Per-projectile material for mod color

# ── Hit-stop (freeze frame) ────────────────────────────────────────────────────
# A brief global time-scale dip on heavy hits makes impacts feel weighty —
# a classic "juice" technique. We use a static cooldown so multiple crits in
# the same frame don't stack into a long freeze. The freeze is short (45ms)
# so gameplay isn't disrupted, only punctuated.
static var _hitstop_cooldown: float = 0.0
const HITSTOP_DURATION: float = 0.045   # Seconds the world freezes
const HITSTOP_TIME_SCALE: float = 0.08  # Target time scale during freeze
const HITSTOP_COOLDOWN: float = 0.12    # Min seconds between freeze triggers

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
		queue_free()

## Hit-stop: briefly dip `Engine.time_scale` to make heavy hits feel weighty.
## Uses a static cooldown so rapid crits don't stack into a long freeze.
## The restore is scheduled via a scene-tree Timer (not a tween on self) because
## the projectile may queue_free() immediately after triggering hit-stop — a
## self-bound tween would be killed and time_scale would stay frozen forever.
## We restore to 1.0 (not a saved value) because DimensionSystem uses per-node
## `_time_scale` multipliers, so Engine.time_scale should always be 1.0.
func _trigger_hitstop() -> void:
	if _hitstop_cooldown > 0.0:
		return
	_hitstop_cooldown = HITSTOP_COOLDOWN
	Engine.time_scale = HITSTOP_TIME_SCALE
	# Schedule restore on the scene tree — survives self queue_free()
	var timer := get_tree().create_timer(HITSTOP_DURATION)
	timer.timeout.connect(func():
		Engine.time_scale = 1.0
	)

## Phase 16: Apply weapon mod behavior while the projectile is in flight.
func _apply_mod_flight_behavior(delta: float) -> void:
	match _weapon_mod:
		GameConstants.WeaponMod.HOMING_LASER, GameConstants.WeaponMod.QUANTUM_OVERDRIVE:
			# Homing: steer toward the nearest enemy
			var target: Node3D = _find_nearest_enemy()
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

## Find the nearest enemy to the projectile (for homing).
func _find_nearest_enemy() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist: float = 30.0  # Max homing range
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
		queue_free()
	else:
		# Hit terrain/wall
		# Phase 16: Bouncing Bolt bounces off walls
		if _weapon_mod == GameConstants.WeaponMod.BOUNCING_BOLT and _bounce_count < _max_bounces:
			_bounce_off_wall(body)
			return
		_impact_effect()
		queue_free()

## Phase 16: Bounce off a wall — reflect direction and continue.
func _bounce_off_wall(_body: Node3D) -> void:
	_bounce_count += 1
	# Simple bounce: reverse direction (more sophisticated would use normals,
	# but Area3D doesn't provide collision normals easily)
	# Try to bounce upward/away
	direction = -direction + Vector3(0, 0.3, 0)
	direction = direction.normalized()
	# Small visual feedback
	ParticleEffects.spawn_explosion(get_parent(), global_position, _mod_color, 8, 0.2)

func _hit_enemy(enemy: Node3D) -> void:
	# damage already includes level bonus and mod multiplier (set by player.gd on spawn)
	var total_damage := damage

	# Crit check
	var crit_chance := GameConstants.CRIT_BASE_CHANCE
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
	if enemy.has_method("take_damage_from") or enemy.has_method("take_damage"):
		if "hp" in enemy and "max_hp" in enemy:
			will_kill = total_damage >= enemy.hp
		# ── Hit-stop on kill blows: even heftier freeze for the killing hit ──
		if will_kill:
			_trigger_hitstop()
		# ── Phase 19: Co-op — mark enemy as hit by P2 if this is a P2 projectile ──
		if has_meta("is_p2_projectile") and enemy.has_method("set_p2_hit"):
			enemy.set_p2_hit()
		# Phase 8: Use the directional damage variant so enemies get knocked back
		if enemy.has_method("take_damage_from"):
			enemy.take_damage_from(total_damage, global_position)
		else:
			enemy.take_damage(total_damage)

	# Damage number popup
	DamageNumber.spawn(get_parent(), global_position, total_damage, is_crit, will_kill)

	# ── Phase 16: Weapon mod on-hit effects ──
	_apply_mod_on_hit(enemy, total_damage)

	# Track this enemy as hit (for pierce/chain)
	_has_hit_enemies.append(enemy)

	# Phase 16: Piercing Beam — pass through enemies without being destroyed
	if _weapon_mod == GameConstants.WeaponMod.PIERCING_BEAM and _pierce_count < _max_pierces:
		_pierce_count += 1
		_impact_effect()
		return  # Don't free — continue flying

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

	# Impact effect
	_impact_effect()
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
		# Create a timer to unfreeze
		var tw := create_tween()
		tw.tween_interval(2.0)
		tw.tween_callback(func():
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
	# Use a tween for periodic burn damage
	var tw := create_tween()
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

func _impact_effect() -> void:
	# Spawn impact burst effect
	if IMPACT_SCENE:
		var burst: Node3D = IMPACT_SCENE.instantiate()
		get_parent().add_child(burst)
		burst.global_position = global_position
	# Phase 6: Small explosion particles on impact
	ParticleEffects.spawn_explosion(get_parent(), global_position, Color(0.2, 1.0, 0.8), 12, 0.4)
	# Phase 20: Audio — explosion SFX on impact
	AudioManager.play_sfx(AudioManager.SFX_EXPLOSION)