## Zorp Wiggles — Void Bomber
## Kamikaze enemy that rushes the player and explodes in an AoE.
## When in range, a fuse activates (with warning ring), then detonates.
## Explosion damages player and nearby enemies.

extends EnemyBase

class_name EnemyBomber

# ─── Bomber State ─────────────────────────────────────────────────────────────
var fuse_active: bool = false
var fuse_timer: float = 0.0
var has_exploded: bool = false

# ─── Visual ───────────────────────────────────────────────────────────────────
var warning_ring: MeshInstance3D = null

func _ready() -> void:
	enemy_name = "Void Bomber"
	enemy_type = GameConstants.EnemyType.BOMBER
	max_hp = 50
	speed = 3.5
	damage = 15
	base_scale = 1.1
	detect_range = 28.0
	xp_reward = 25
	score_reward = 100
	base_color = Color(80.0 / 255.0, 0.0, 40.0 / 255.0)  # Dark purple-red
	super._ready()

	# Create explosion warning ring
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = GameConstants.VOID_BOMBER_EXPLOSION_RADIUS
	ring_mesh.bottom_radius = GameConstants.VOID_BOMBER_EXPLOSION_RADIUS
	ring_mesh.height = 0.05
	warning_ring = MeshInstance3D.new()
	warning_ring.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.2, 0.0, 0.0)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.2, 0.0) * 0.5
	warning_ring.material_override = ring_mat
	add_child(warning_ring)
	warning_ring.position = Vector3(0, -0.5, 0)
	warning_ring.visible = false

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_paused:
		return
	
	# ── Phase 14: Apply dimension time scale for fuse-specific timers ──
	# (The base class also scales delta, so we pass the original to super
	#  to avoid double-scaling the movement/AI delta.)
	var scaled_delta: float = delta * _time_scale
	
	# Spawn grace period — decrement timer ourselves since we return before super
	if spawn_grace_timer > 0:
		spawn_grace_timer -= scaled_delta
		_update_spawn_visuals(scaled_delta)
		return
	
	# If fuse is active, handle fuse logic but skip normal AI movement
	if fuse_active:
		fuse_timer -= scaled_delta
		# Pulse the warning ring faster as fuse counts down
		if warning_ring and warning_ring.visible:
			var pulse_speed: float = 10.0 + (1.0 - fuse_timer / GameConstants.VOID_BOMBER_FUSE_DURATION) * 20.0
			var pulse: float = 0.5 + 0.5 * sin(GameManager.game_time * pulse_speed)
			var mat := warning_ring.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color.a = 0.2 + pulse * 0.3
		
		# Keep still while fuse counts down
		velocity = Vector3.ZERO
		move_and_slide()
		
		if fuse_timer <= 0:
			_explode()
		return
	
	# Normal AI behavior via base class (handles detection, movement, timers)
	# Pass the original delta — the base class applies _time_scale internally.
	super._physics_process(delta)
	
	# Check if close enough to trigger fuse (after AI has updated is_alerted)
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and is_alerted:
		var dist: float = global_position.distance_to(player.global_position)
		if dist < GameConstants.VOID_BOMBER_FUSE_TRIGGER_RANGE:
			_activate_fuse()

func _activate_fuse() -> void:
	fuse_active = true
	fuse_timer = GameConstants.VOID_BOMBER_FUSE_DURATION
	if warning_ring:
		warning_ring.visible = true
	# Stop moving during fuse
	velocity = Vector3.ZERO

func _explode() -> void:
	if has_exploded:
		return
	has_exploded = true

	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		var dist: float = global_position.distance_to(player.global_position)
		if dist < GameConstants.VOID_BOMBER_EXPLOSION_RADIUS:
			GameManager.take_damage(GameConstants.VOID_BOMBER_EXPLOSION_DAMAGE, global_position)

	# Damage nearby enemies too
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		if enemy.has_method("take_damage_from") or enemy.has_method("take_damage"):
			var edist: float = global_position.distance_to(enemy.global_position)
			if edist < GameConstants.VOID_BOMBER_EXPLOSION_RADIUS:
				if enemy.has_method("take_damage_from"):
					enemy.take_damage_from(GameConstants.VOID_BOMBER_EXPLOSION_DAMAGE / 2, global_position)
				else:
					enemy.take_damage(GameConstants.VOID_BOMBER_EXPLOSION_DAMAGE / 2)

	# Visual explosion effect — flash and scale
	if _material:
		_material.albedo_color = Color(1.0, 0.6, 0.0)
	# Explosion light flash — a brief orange burst that illuminates nearby geometry
	var boom_light := OmniLight3D.new()
	boom_light.light_color = Color(1.0, 0.5, 0.1)
	boom_light.light_energy = 5.0
	boom_light.omni_range = GameConstants.VOID_BOMBER_EXPLOSION_RADIUS * 1.5
	boom_light.omni_attenuation = 1.5
	add_child(boom_light)
	var boom_tween := create_tween()
	boom_tween.set_parallel(true)
	boom_tween.tween_property(self, "scale",
		Vector3.ONE * base_scale * 3.0, 0.15)
	if _material:
		boom_tween.tween_property(_material, "albedo_color:a", 0.0, 0.15)
	# Light fades out fast for a snappy flash
	boom_tween.tween_property(boom_light, "light_energy", 0.0, 0.2) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	boom_tween.chain().tween_callback(queue_free)

	# Camera shake on explosion
	_trigger_camera_trauma(0.4)

	# Mark as dead for game logic
	is_dead = true
	GameManager.register_kill()
	GameManager.gain_xp(xp_reward)
	GameManager.add_score(score_reward)
	enemy_died.emit(self)
	# Phase 5: Kill feed signal (must emit here since _die() is overridden)
	GameManager.enemy_killed.emit(enemy_name, "Zorp")
	# Remove from GameManager's enemy list (not calling super._die() so erase here)
	GameManager.enemies.erase(self)
	# Clean up AI controller
	if ai_controller:
		ai_controller.cleanup()
		ai_controller = null

func _die() -> void:
	# Override: if not already exploded, do normal death
	if has_exploded:
		return
	super._die()