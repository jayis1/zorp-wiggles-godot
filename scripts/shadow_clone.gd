## Zorp Wiggles — Void Shadow Clone (Phase 14: Void Dimension)
## A dark clone of Zorp that appears in the Void dimension as a mini-boss.
## It mimics the player's movement patterns and shoots dark projectiles.
## Uses silhouette-only visuals (pure black with purple rim glow).

extends CharacterBody3D

# ─── Stats ────────────────────────────────────────────────────────────────────
var enemy_name: String = "Void Shadow Clone"
var hp: int = 80
var max_hp: int = 80
var damage: int = 12
var is_dead: bool = false

# ─── AI State ─────────────────────────────────────────────────────────────────
var _cached_player: Node3D = null
var _attack_cooldown: float = 2.0
var _move_speed: float = 8.0
var _strafe_dir: float = 1.0
var _strafe_timer: float = 0.0
var _time_scale: float = 1.0

# ─── Visuals ──────────────────────────────────────────────────────────────────
var _mesh: MeshInstance3D = null
var _mat: StandardMaterial3D = null
var _alert_indicator: Label3D = null

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("void_clone")

	# Create the shadow clone visual — pure black sphere with purple rim
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	sphere.radial_segments = 12
	sphere.rings = 8
	_mesh.mesh = sphere
	_mesh.position.y = 0.6
	add_child(_mesh)

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.02, 0.0, 0.05)
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.emission_enabled = true
	_mat.emission = Color(0.3, 0.0, 0.5) * 0.3
	_mat.emission_energy_multiplier = 0.5
	_mat.rim_enabled = true
	_mat.rim = 1.0
	_mat.rim_tint = 1.0
	_mesh.material_override = _mat

	# Collision shape
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	col.shape = shape
	add_child(col)

	# Alert indicator "🌑" above head
	_alert_indicator = Label3D.new()
	_alert_indicator.text = "🌑"
	_alert_indicator.font_size = 48
	_alert_indicator.position.y = 2.0
	_alert_indicator.no_depth_test = true
	_alert_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_alert_indicator)

	# Spawn particle effect
	ParticleEffects.spawn_materialization(get_parent(), global_position, Color(0.3, 0.0, 0.5))

	# Emit boss spawn signal so HUD shows boss bar
	GameManager.boss_spawned.emit(self)

	# Fade in animation
	_mesh.scale = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(_mesh, "scale", Vector3.ONE, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

func set_time_scale(scale: float) -> void:
	_time_scale = scale

func _physics_process(delta: float) -> void:
	if GameManager.is_paused or is_dead:
		return

	delta *= _time_scale

	# Cache player reference
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
		return

	var player: Node3D = _cached_player
	var to_player: Vector3 = player.global_position - global_position
	var dist: float = to_player.length()

	# Strafe behavior — circle the player at medium range
	_strafe_timer -= delta
	if _strafe_timer <= 0:
		_strafe_dir = -_strafe_dir
		_strafe_timer = randf_range(2.0, 4.0)

	var desired_pos: Vector3
	if dist > 10.0:
		# Move closer
		desired_pos = player.global_position + to_player.normalized() * 8.0
	else:
		# Strafe around
		var perp := Vector3(-to_player.z, 0, to_player.x).normalized()
		desired_pos = player.global_position + to_player.normalized() * 6.0 + perp * _strafe_dir * 3.0

	var move_dir: Vector3 = (desired_pos - global_position).normalized()
	velocity = move_dir * _move_speed
	velocity.y = 0
	move_and_slide()

	# Attack — shoot dark projectiles at the player
	_attack_cooldown -= delta
	if _attack_cooldown <= 0 and dist < 20.0:
		_attack_cooldown = 1.5
		_shoot_dark_projectile(player)

func _shoot_dark_projectile(player: Node3D) -> void:
	var dir: Vector3 = (player.global_position - global_position).normalized()
	dir.y = 0

	# Use the enemy projectile scene
	var proj_scene: PackedScene = load("res://scenes/entities/enemy_projectile.tscn")
	if not proj_scene:
		return

	var proj: Area3D = proj_scene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position + Vector3(0, 0.5, 0) + dir * 0.8
	proj.set("direction", dir)
	proj.set("damage", damage)
	proj.set("speed", 18.0)
	proj.set("lifetime", 4.0)

	# Make the projectile look void-themed (dark purple)
	if proj.has_node("MeshInstance3D"):
		var mesh_inst: MeshInstance3D = proj.get_node("MeshInstance3D")
		if mesh_inst and mesh_inst.material_override is StandardMaterial3D:
			var mat := mesh_inst.material_override as StandardMaterial3D
			mat.albedo_color = Color(0.2, 0.0, 0.3)
			mat.emission = Color(0.4, 0.0, 0.6) * 0.5

	# Shoot scale pulse
	if _mesh:
		var pulse_tween := create_tween()
		pulse_tween.tween_property(_mesh, "scale", Vector3.ONE * 1.15, 0.06) \
			.set_ease(Tween.EASE_OUT)
		pulse_tween.tween_property(_mesh, "scale", Vector3.ONE, 0.1) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

func take_damage_from(amount: int, source_pos: Vector3) -> void:
	if is_dead:
		return
	hp -= amount

	# Hit flash — brighten to dark purple briefly
	if _mat:
		_mat.emission_energy_multiplier = 2.0
		var tween := create_tween()
		tween.tween_property(_mat, "emission_energy_multiplier", 0.5, 0.2) \
			.set_ease(Tween.EASE_OUT)

	# Knockback
	var push_dir: Vector3 = (global_position - source_pos).normalized()
	push_dir.y = 0
	global_position += push_dir * 0.3

	# Damage number
	DamageNumber.spawn(get_parent(), global_position + Vector3(0, 1, 0), amount, false, false)

	if hp <= 0:
		_die()

func take_damage(amount: int) -> void:
	take_damage_from(amount, global_position)

func apply_knockback(dir: Vector3, force: float) -> void:
	global_position += dir * force * 0.05

func _die() -> void:
	is_dead = true

	# Big death effect
	ParticleEffects.spawn_boss_death_spectacle(get_parent(), global_position, Color(0.3, 0.0, 0.5))

	# Boss defeated signal
	GameManager.boss_defeated.emit(self)
	GameManager.clear_current_boss()
	GameManager.register_kill()
	GameManager.add_score(500)
	GameManager.add_message("🌑 Shadow Clone defeated! +500 score")

	# Remove from enemies list
	GameManager.enemies.erase(self)

	# Death animation
	if _mesh:
		var death_tween := create_tween()
		death_tween.tween_property(_mesh, "scale", Vector3.ZERO, 0.4) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		death_tween.tween_callback(queue_free)
	else:
		queue_free()