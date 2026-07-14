## Zorp Wiggles — Projectile (Player Laser)
## Tentacle laser projectile that flies forward and damages enemies.
## Ported from Projectile class in Ursina game.py.

extends Area3D

var direction: Vector3 = Vector3.FORWARD
var damage: int = GameConstants.PROJECTILE_BASE_DAMAGE
var lifetime: float = GameConstants.PROJECTILE_LIFETIME
var speed: float = GameConstants.PROJECTILE_SPEED

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

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
		mat.emission = Color(0.2, 1.0, 0.8) * 0.5
		mesh_instance.material_override = mat

func _physics_process(delta: float) -> void:
	if GameManager.is_paused:
		return
	
	# Move forward
	global_position += direction * speed * delta
	
	# Lifetime countdown
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
	
	# Trail effect (small fading spheres behind projectile)
	# Will be added by builder cron job

func _on_body_entered(body: Node3D) -> void:
	# Check if it's an enemy
	if body.is_in_group("enemies"):
		_hit_enemy(body)
	else:
		# Hit terrain/wall — destroy projectile
		_impact_effect()
		queue_free()

func _hit_enemy(enemy: Node3D) -> void:
	# damage already includes level bonus (set by player.gd on spawn)
	var total_damage := damage
	
	# Crit check
	var crit_chance := 0.1  # Base 10% crit chance
	var is_crit := randf() < crit_chance
	if is_crit:
		# Crit chain bonus
		GameManager.player_crit_chain += 1
		GameManager.player_crit_chain_timer = 3.0
		var crit_mult := 2.0
		if GameManager.player_crit_chain >= 3:
			crit_mult = 3.0  # Chain crit bonus
		total_damage = int(total_damage * crit_mult)
	
	if enemy.has_method("take_damage"):
		enemy.take_damage(total_damage)
	
	# Damage number popup (will be added by builder)
	_spawn_damage_number(total_damage, is_crit)
	
	# Impact effect
	_impact_effect()
	queue_free()

func _spawn_damage_number(amount: int, is_crit: bool) -> void:
	# TODO: Spawn floating damage number at impact point
	pass

func _impact_effect() -> void:
	# TODO: Spawn small particle burst at impact point
	pass