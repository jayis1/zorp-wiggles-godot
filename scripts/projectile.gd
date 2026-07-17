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

# ─── Trail ────────────────────────────────────────────────────────────────────
var _trail_positions: Array[Vector3] = []
const TRAIL_MAX_POINTS: int = 6
const TRAIL_INTERVAL: float = 0.02
var _trail_timer: float = 0.0
var _trail_meshes: Array[MeshInstance3D] = []

# ─── Impact Effect ────────────────────────────────────────────────────────────
const IMPACT_SCENE := preload("res://scenes/entities/impact_burst.tscn")

func _ready() -> void:
	# Connect body_entered signal — fires when a PhysicsBody3D (enemy) enters
	body_entered.connect(_on_body_entered)

	# Create projectile visual
	if mesh_instance:
		var sphere := SphereMesh.new()
		sphere.radius = 0.15
		sphere.height = 0.3
		sphere.radial_segments = 6
		sphere.rings = 3
		mesh_instance.mesh = sphere

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 1.0, 0.8)  # Cyan laser
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = Color(0.2, 1.0, 0.8) * 0.8
		mat.emission_energy_multiplier = 1.5
		mesh_instance.material_override = mat

	# Add a small point light for real-time glow
	var light := OmniLight3D.new()
	light.light_color = Color(0.2, 1.0, 0.8)
	light.light_energy = 0.8
	light.omni_range = 3.0
	light.omni_attenuation = 1.5
	add_child(light)

func _physics_process(delta: float) -> void:
	if GameManager.is_paused:
		return

	# Move forward
	global_position += direction * speed * delta

	# Subtle spin during flight — gives the laser bolt a sense of energy
	# and motion rather than a static sphere drifting forward.
	if mesh_instance:
		mesh_instance.rotate_y(delta * 12.0)

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

func _record_trail_point(pos: Vector3) -> void:
	_trail_positions.push_front(pos)
	if _trail_positions.size() > TRAIL_MAX_POINTS:
		_trail_positions.pop_back()

func _update_trail_visuals(delta: float) -> void:
	# Lazily create trail mesh instances
	while _trail_meshes.size() < TRAIL_MAX_POINTS:
		var m := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.1
		sphere.height = 0.2
		sphere.radial_segments = 4
		sphere.rings = 2
		m.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 1.0, 0.8, 0.5)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.2, 1.0, 0.8) * 0.3
		m.material_override = mat
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
			var mat := tm.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color.a = fade * 0.5
			tm.scale = Vector3.ONE * fade
		else:
			tm.visible = false

func _on_body_entered(body: Node3D) -> void:
	# Check if it's an enemy
	if body.is_in_group("enemies"):
		_hit_enemy(body)
	elif body.is_in_group("destructibles"):
		# Hit a destructible prop — damage it
		if body.has_method("take_damage_from"):
			body.take_damage_from(damage, global_position)
		_impact_effect()
		queue_free()
	else:
		# Hit terrain/wall — destroy projectile
		_impact_effect()
		queue_free()

func _hit_enemy(enemy: Node3D) -> void:
	# damage already includes level bonus (set by player.gd on spawn)
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

	# Check if this will be a kill before applying damage
	var will_kill: bool = false
	if enemy.has_method("take_damage_from") or enemy.has_method("take_damage"):
		if "hp" in enemy and "max_hp" in enemy:
			will_kill = total_damage >= enemy.hp
		# Phase 8: Use the directional damage variant so enemies get knocked back
		if enemy.has_method("take_damage_from"):
			enemy.take_damage_from(total_damage, global_position)
		else:
			enemy.take_damage(total_damage)

	# Damage number popup
	DamageNumber.spawn(get_parent(), global_position, total_damage, is_crit, will_kill)

	# Impact effect
	_impact_effect()
	queue_free()

func _impact_effect() -> void:
	# Spawn impact burst effect
	if IMPACT_SCENE:
		var burst: Node3D = IMPACT_SCENE.instantiate()
		get_parent().add_child(burst)
		burst.global_position = global_position
	# Phase 6: Small explosion particles on impact
	ParticleEffects.spawn_explosion(get_parent(), global_position, Color(0.2, 1.0, 0.8), 12, 0.4)