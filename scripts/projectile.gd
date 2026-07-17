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

func _ready() -> void:
	# Connect body_entered signal — fires when a PhysicsBody3D (enemy) enters
	body_entered.connect(_on_body_entered)

	# Use shared mesh + material (created once, reused across all projectiles)
	_ensure_shared_resources()
	if mesh_instance:
		mesh_instance.mesh = _shared_mesh
		mesh_instance.material_override = _shared_material

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