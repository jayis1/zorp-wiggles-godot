## Zorp Wiggles — Gravity Elemental (Phase 23: Elite Enemy)
## An elite enemy that manipulates gravity around itself. Periodically creates a
## gravity field that repels the player outward and flings nearby loose objects
## (RigidBody3D fragments, collectibles) at the player as projectiles.
##
## Behavior:
##   - Moderate-speed chase toward the player.
##   - Every GRAVITY_ELEMENTAL_FIELD_COOLDOWN seconds, charges up a gravity field
##     (warn telegraph: growing translucent sphere + brightening emission), then
##     releases a repel burst that pushes the player outward and flings nearby
##     loose physics objects at the player as projectiles.
##   - The repel field has a telegraph (FIELD_WARN_TIME) before activating,
##     giving the player time to back away.
##   - Standard melee attack when in range.
##
## The counter is to stay at range and burst it down before it can set up its
## gravity field. The repel is strong but short-range — kiting is effective.

extends EnemyBase

class_name EnemyGravityElemental

# ─── Field State ─────────────────────────────────────────────────────────────
enum FieldState { IDLE, CHARGING, ACTIVE }
var _field_state: int = FieldState.IDLE
var _field_timer: float = GameConstants.GRAVITY_ELEMENTAL_FIELD_COOLDOWN
var _field_active_timer: float = 0.0
var _field_tick_timer: float = 0.0

# ─── Field Visual ─────────────────────────────────────────────────────────────
var _field_mesh: MeshInstance3D = null
var _field_material: StandardMaterial3D = null
var _field_light: OmniLight3D = null

# Reuse the enemy projectile scene for flung-object projectiles
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/entities/enemy_projectile.tscn")

func _ready() -> void:
	enemy_name = "Gravity Elemental"
	enemy_type = GameConstants.EnemyType.GRAVITY_ELEMENTAL
	max_hp = GameConstants.GRAVITY_ELEMENTAL_HP
	speed = GameConstants.GRAVITY_ELEMENTAL_SPEED
	damage = GameConstants.GRAVITY_ELEMENTAL_DAMAGE
	base_scale = GameConstants.GRAVITY_ELEMENTAL_SCALE
	detect_range = GameConstants.GRAVITY_ELEMENTAL_DETECT_RANGE
	attack_range = GameConstants.GRAVITY_ELEMENTAL_ATTACK_RANGE
	attack_cooldown = GameConstants.GRAVITY_ELEMENTAL_ATTACK_COOLDOWN
	xp_reward = GameConstants.GRAVITY_ELEMENTAL_XP
	score_reward = GameConstants.GRAVITY_ELEMENTAL_SCORE
	base_color = GameConstants.GRAVITY_ELEMENTAL_COLOR
	# Smart AI enabled — flanking makes it harder to pin down
	use_smart_ai = true
	super._ready()

	# Gravitic blue emissive material with strong rim
	if _material:
		_material.emission = base_color * 0.4
		_material.emission_energy_multiplier = 1.4
		_material.rim = 1.0
		_material.rim_tint = 1.0
		_material.metallic = 0.5
		_material.roughness = 0.3

	# Create the gravity field visual (hidden until charging)
	_create_field_visual()

## Create the translucent gravity-field sphere + light that surrounds the elemental.
func _create_field_visual() -> void:
	_field_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = GameConstants.GRAVITY_ELEMENTAL_FIELD_RADIUS
	sphere.height = GameConstants.GRAVITY_ELEMENTAL_FIELD_RADIUS * 2.0
	sphere.radial_segments = 20
	sphere.rings = 10
	_field_mesh.mesh = sphere
	_field_material = StandardMaterial3D.new()
	_field_material.albedo_color = GameConstants.GRAVITY_ELEMENTAL_FIELD_COLOR
	_field_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_field_material.emission_enabled = true
	_field_material.emission = GameConstants.GRAVITY_ELEMENTAL_FIELD_COLOR * 0.3
	_field_material.emission_energy_multiplier = 0.0  # Hidden until charging
	_field_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_field_material.no_depth_test = true
	_field_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_field_mesh.material_override = _field_material
	add_child(_field_mesh)
	_field_mesh.position = Vector3(0, 0.5, 0)
	_field_mesh.scale = Vector3.ZERO  # Grow during charge

	# Soft blue light
	_field_light = OmniLight3D.new()
	_field_light.light_color = GameConstants.GRAVITY_ELEMENTAL_COLOR
	_field_light.light_energy = 0.0  # Hidden until charging
	_field_light.omni_range = GameConstants.GRAVITY_ELEMENTAL_FIELD_RADIUS
	_field_light.omni_attenuation = 2.0
	add_child(_field_light)
	_field_light.position = Vector3(0, 1.0, 0)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_dead or GameManager.is_paused or spawn_grace_timer > 0:
		return
	# Tick the gravity field state machine
	_update_field_state(delta)

## Update the gravity field state machine: IDLE → CHARGING → ACTIVE → IDLE.
func _update_field_state(delta: float) -> void:
	match _field_state:
		FieldState.IDLE:
			_field_timer -= delta * _time_scale
			if _field_timer <= 0:
				_start_charging()
		FieldState.CHARGING:
			# Grow the field visual during the warn telegraph
			var charge_t: float = 1.0 - max(0.0, _field_active_timer) / GameConstants.GRAVITY_ELEMENTAL_FIELD_WARN_TIME
			if _field_mesh:
				_field_mesh.scale = Vector3.ONE * charge_t
			if _field_material:
				_field_material.emission_energy_multiplier = charge_t * 1.5
			if _field_light:
				_field_light.light_energy = charge_t * 1.5
			_field_active_timer -= delta * _time_scale
			if _field_active_timer <= 0:
				_activate_field()
		FieldState.ACTIVE:
			_update_active_field(delta)

## Start charging the gravity field — warn telegraph before the repel burst.
func _start_charging() -> void:
	_field_state = FieldState.CHARGING
	_field_active_timer = GameConstants.GRAVITY_ELEMENTAL_FIELD_WARN_TIME
	# Audio cue — charging sound
	AudioManager.play_sfx(AudioManager.SFX_ENEMY_HIT)

## Activate the gravity field — repel the player outward and fling loose objects.
func _activate_field() -> void:
	_field_state = FieldState.ACTIVE
	_field_active_timer = GameConstants.GRAVITY_ELEMENTAL_FIELD_DURATION
	# Repel burst — push the player outward
	_repel_player()
	# Fling nearby loose objects at the player as projectiles
	_fling_loose_objects()
	# Visual: bright flash + particle burst
	if _field_material:
		_field_material.emission_energy_multiplier = 3.0
	if _field_light:
		_field_light.light_energy = 3.0
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		GameConstants.GRAVITY_ELEMENTAL_COLOR, 24, 0.5)
	if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
		GameManager.camera_rig.add_trauma(0.3)
	AudioManager.play_sfx(AudioManager.SFX_ENEMY_HIT)

## Update the active field — apply continuous repel force to the player.
func _update_active_field(delta: float) -> void:
	_field_active_timer -= delta * _time_scale
	# Tick repel force
	_field_tick_timer -= delta * _time_scale
	if _field_tick_timer <= 0:
		_field_tick_timer = GameConstants.GRAVITY_ELEMENTAL_FIELD_TICK_INTERVAL
		_repel_player()
	# Fade the field visual as it ends
	var fade_t: float = max(0.0, _field_active_timer) / GameConstants.GRAVITY_ELEMENTAL_FIELD_DURATION
	if _field_material:
		_field_material.emission_energy_multiplier = fade_t * 3.0
	if _field_light:
		_field_light.light_energy = fade_t * 3.0
	if _field_active_timer <= 0:
		_end_field()

## Repel the player outward from the elemental's center.
func _repel_player() -> void:
	var p1: Node3D = get_tree().get_first_node_in_group("player")
	if p1 and is_instance_valid(p1) and not GameManager.player_is_downed:
		var dist: float = global_position.distance_to(p1.global_position)
		if dist < GameConstants.GRAVITY_ELEMENTAL_FIELD_RADIUS and dist > 0.5:
			var repel_dir: Vector3 = (p1.global_position - global_position).normalized()
			repel_dir.y = 0
			repel_dir = repel_dir.normalized()
			# Smooth falloff at the edge
			var t: float = 1.0 - (dist / GameConstants.GRAVITY_ELEMENTAL_FIELD_RADIUS)
			var force: float = GameConstants.GRAVITY_ELEMENTAL_REPEL_FORCE * t
			if p1 is CharacterBody3D:
				(p1 as CharacterBody3D).velocity += repel_dir * force * GameConstants.GRAVITY_ELEMENTAL_FIELD_TICK_INTERVAL
	# Co-op: repel P2
	if CoOpManager.is_coop_active() and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
		if not CoOpManager.p2_is_downed:
			var p2_dist: float = global_position.distance_to(CoOpManager.p2_node.global_position)
			if p2_dist < GameConstants.GRAVITY_ELEMENTAL_FIELD_RADIUS and p2_dist > 0.5:
				var p2_repel: Vector3 = (CoOpManager.p2_node.global_position - global_position).normalized()
				p2_repel.y = 0
				p2_repel = p2_repel.normalized()
				var t2: float = 1.0 - (p2_dist / GameConstants.GRAVITY_ELEMENTAL_FIELD_RADIUS)
				var force2: float = GameConstants.GRAVITY_ELEMENTAL_REPEL_FORCE * t2
				if CoOpManager.p2_node is CharacterBody3D:
					(CoOpManager.p2_node as CharacterBody3D).velocity += p2_repel * force2 * GameConstants.GRAVITY_ELEMENTAL_FIELD_TICK_INTERVAL

## Fling nearby loose RigidBody3D objects at the player as projectiles. We look
## for RigidBody3D nodes (corpses, fragments, collectibles in tumble mode) within
## the field radius and launch them toward the player. Each flung object becomes
## an enemy projectile that deals damage on hit. We cap the number of flung
## objects to avoid spawning too many projectiles.
func _fling_loose_objects() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var flung: int = 0
	# Find nearby RigidBody3D nodes (corpses, fragments)
	var bodies: Array[Node] = get_tree().get_nodes_in_group("physics_corpse")
	for body in bodies:
		if flung >= GameConstants.GRAVITY_ELEMENTAL_MAX_FLUNG_OBJECTS:
			break
		if not is_instance_valid(body):
			continue
		var dist: float = global_position.distance_to(body.global_position)
		if dist < GameConstants.GRAVITY_ELEMENTAL_FIELD_RADIUS:
			# Launch the RigidBody3D toward the player with an impulse
			var launch_dir: Vector3 = (player.global_position - body.global_position).normalized()
			launch_dir.y = 0.5  # Slight upward arc
			launch_dir = launch_dir.normalized()
			if body is RigidBody3D:
				(body as RigidBody3D).apply_impulse(launch_dir * 15.0, Vector3.ZERO)
			flung += 1
	# Also spawn a few direct projectiles toward the player (visual "gravity bolts")
	var extra_bolts: int = max(0, 3 - flung)
	for i in range(extra_bolts):
		_spawn_gravity_bolt(player)

## Spawn a gravity bolt projectile toward the player.
func _spawn_gravity_bolt(player: Node3D) -> void:
	var fire_dir: Vector3 = (player.global_position - global_position).normalized()
	fire_dir.y = 0
	fire_dir = fire_dir.normalized()
	# Slight spread
	var spread_rad: float = deg_to_rad(8.0)
	fire_dir = fire_dir.rotated(Vector3.UP, randf_range(-spread_rad, spread_rad))
	var proj: Area3D = ENEMY_PROJECTILE_SCENE.instantiate()
	proj.set("direction", fire_dir)
	proj.set("speed", GameConstants.GRAVITY_ELEMENTAL_PROJECTILE_SPEED)
	proj.set("damage", GameConstants.GRAVITY_ELEMENTAL_PROJECTILE_DAMAGE)
	proj.set("lifetime", 2.5)
	proj.set("projectile_color", GameConstants.GRAVITY_ELEMENTAL_COLOR)
	get_parent().add_child(proj)
	proj.global_position = global_position + Vector3(0, 1.0, 0)

## End the field — reset state and start the cooldown.
func _end_field() -> void:
	_field_state = FieldState.IDLE
	_field_timer = GameConstants.GRAVITY_ELEMENTAL_FIELD_COOLDOWN
	if _field_mesh:
		_field_mesh.scale = Vector3.ZERO
	if _field_material:
		_field_material.emission_energy_multiplier = 0.0
	if _field_light:
		_field_light.light_energy = 0.0

func _die() -> void:
	# Clean up the field visual
	if _field_mesh:
		var fade_tw := _field_mesh.create_tween()
		fade_tw.tween_property(_field_material, "albedo_color:a", 0.0, 0.3)
		fade_tw.tween_callback(_field_mesh.queue_free)
		_field_mesh = null
	if _field_light:
		var light_tw := _field_light.create_tween()
		light_tw.tween_property(_field_light, "light_energy", 0.0, 0.3)
		light_tw.tween_callback(_field_light.queue_free)
		_field_light = null
	# Gravitic burst on death
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		GameConstants.GRAVITY_ELEMENTAL_COLOR, 24, 0.6)
	super._die()