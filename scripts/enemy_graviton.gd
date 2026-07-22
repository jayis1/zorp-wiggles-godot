## Zorp Wiggles — Graviton
## Floating enemy that periodically pulls the player toward it with gravity force.
## While pulling, deals damage-per-second to the player if caught in range.
## Ported from Graviton logic in Ursina game.py.

extends EnemyBase

class_name EnemyGraviton

# ─── Graviton State ───────────────────────────────────────────────────────────
var pull_active: bool = false
var pull_timer: float = 0.0
var cooldown_timer: float = 5.0
var pull_damage_accum: float = 0.0

# ── Phase 8: Area3D gravity well (affects RigidBody3D fragments, collectibles) ──
var gravity_well: Area3D = null

# ─── Visual ───────────────────────────────────────────────────────────────────
var pull_ring: MeshInstance3D = null

func _ready() -> void:
	enemy_name = "Graviton"
	enemy_type = GameConstants.EnemyType.GRAVITON
	max_hp = 75
	speed = 2.8
	damage = 10
	base_scale = 1.5
	detect_range = 30.0
	xp_reward = 40
	score_reward = 150
	base_color = Color(180.0 / 255.0, 0.0, 1.0)  # Purple
	super._ready()

	cooldown_timer = randf_range(
		GameConstants.GRAVITON_PULL_COOLDOWN_MIN,
		GameConstants.GRAVITON_PULL_COOLDOWN_MAX
	)

	# Create gravity pull indicator ring (flat disc on ground)
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = GameConstants.GRAVITON_PULL_RADIUS
	ring_mesh.bottom_radius = GameConstants.GRAVITON_PULL_RADIUS
	ring_mesh.height = 0.05
	pull_ring = MeshInstance3D.new()
	pull_ring.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(180.0 / 255.0, 0.0, 1.0, 0.0)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pull_ring.material_override = ring_mat
	add_child(pull_ring)
	pull_ring.position = Vector3(0, -0.5, 0)
	pull_ring.visible = false

	# ── Phase 8: Create Area3D gravity well for actual physics force on RigidBodies
	gravity_well = Area3D.new()
	gravity_well.gravity_point = true
	gravity_well.gravity_point_center = Vector3.ZERO  # Center = this Area3D's origin
	gravity_well.gravity = GameConstants.GRAVITON_AREA_GRAVITY
	gravity_well.gravity_point_unit_distance = 1.0  # Falloff reference distance
	# Collision shape = sphere matching the pull radius
	var well_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = GameConstants.GRAVITON_PULL_RADIUS
	well_shape.shape = sphere
	gravity_well.add_child(well_shape)
	# Mask: only affect physics bodies (fragments, collectibles), not player/enemies
	gravity_well.collision_mask = 0b0001  # Layer 1 — physics objects
	gravity_well.space_override = Area3D.SPACE_OVERRIDE_COMBINE_REPLACE
	gravity_well.monitoring = false  # Don't fire body_entered (we only want the gravity effect)
	add_child(gravity_well)
	gravity_well.visible = false  # Hide the area gizmo in-game (it's invisible anyway)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_dead or GameManager.is_paused or spawn_grace_timer > 0:
		return

	# ── Phase 14: Apply dimension time scale for graviton-specific timers ──
	# (The base class also scales delta, so we pass the original to super
	#  to avoid double-scaling the movement/AI delta.)
	var scaled_delta: float = delta * _time_scale

	# Target nearest valid player — in co-op, the graviton should pull
	# whichever player is closest, not always P1.
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return
	if CoOpManager.is_coop_active() and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
		var p1_dist: float = global_position.distance_to(player.global_position)
		var p2_dist: float = global_position.distance_to(CoOpManager.p2_node.global_position)
		if GameManager.player_is_downed:
			p1_dist = 99999.0
		if CoOpManager.p2_is_downed:
			p2_dist = 99999.0
		if p2_dist < p1_dist:
			player = CoOpManager.p2_node

	var dist_to_player: float = global_position.distance_to(player.global_position)

	if pull_active:
		pull_timer -= scaled_delta
		# Pull player toward this enemy (CharacterBody3D — manual pull, not Area3D gravity)
		if dist_to_player > 1.0 and dist_to_player < GameConstants.GRAVITON_PULL_RADIUS:
			var pull_dir: Vector3 = (global_position - player.global_position).normalized()
			pull_dir.y = 0
			var pull_strength: float = GameConstants.GRAVITON_PULL_FORCE * \
				(1.0 - dist_to_player / GameConstants.GRAVITON_PULL_RADIUS)
			player.global_position += pull_dir * pull_strength * delta

			# Damage per second while in pull range — route to correct player
			pull_damage_accum += GameConstants.GRAVITON_PULL_DAMAGE * delta
			if pull_damage_accum >= 1.0:
				if player.is_in_group("player2"):
					CoOpManager.p2_take_damage(int(pull_damage_accum), global_position)
				else:
					GameManager.take_damage(int(pull_damage_accum), global_position)
				pull_damage_accum = 0.0

		# Animate pull ring pulse
		if pull_ring and pull_ring.visible:
			var pulse_scale: float = 0.8 + 0.2 * sin(GameManager.game_time * 5.0)
			pull_ring.scale = Vector3.ONE * pulse_scale

		if pull_timer <= 0:
			pull_active = false
			cooldown_timer = randf_range(
				GameConstants.GRAVITON_PULL_COOLDOWN_MIN,
				GameConstants.GRAVITON_PULL_COOLDOWN_MAX
			)
			if pull_ring:
				pull_ring.visible = false
			# ── Phase 8: Disable gravity well when pull ends
			if gravity_well:
				gravity_well.gravity = 0.0
	else:
		cooldown_timer -= scaled_delta
		# Show warning ring when about to pull
		if cooldown_timer < 1.5 and dist_to_player < GameConstants.GRAVITON_PULL_RADIUS:
			if pull_ring and not pull_ring.visible:
				pull_ring.visible = true
				var mat := pull_ring.material_override as StandardMaterial3D
				if mat:
					mat.albedo_color = Color(180.0 / 255.0, 0.0, 1.0, 0.15)

		# Activate pull
		if cooldown_timer <= 0 and is_alerted and dist_to_player < GameConstants.GRAVITON_PULL_RADIUS:
			pull_active = true
			pull_timer = GameConstants.GRAVITON_PULL_DURATION
			if pull_ring:
				pull_ring.visible = true
				var mat := pull_ring.material_override as StandardMaterial3D
				if mat:
					mat.albedo_color = Color(180.0 / 255.0, 0.0, 1.0, 0.3)
			# ── Phase 8: Enable the Area3D gravity well for RigidBody physics objects
			if gravity_well:
				gravity_well.gravity = GameConstants.GRAVITON_AREA_GRAVITY