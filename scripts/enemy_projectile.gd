## Zorp Wiggles — Enemy Projectile
## Projectile fired by Spore Spitter and Plasma Drake.
## Travels in a straight line, damages player on hit, has lifetime.

extends Area3D

class_name EnemyProjectile

@export var speed: float = 20.0
@export var damage: int = 12
@export var lifetime: float = 3.0
@export var projectile_color: Color = Color(1.0, 120.0 / 255.0, 20.0 / 255.0)

var direction: Vector3 = Vector3.FORWARD
var age: float = 0.0
var _material: StandardMaterial3D = null

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	# Set up collision
	body_entered.connect(_on_body_entered)

	# Set up material
	if mesh:
		_material = StandardMaterial3D.new()
		_material.albedo_color = projectile_color
		_material.emission_enabled = true
		_material.emission = projectile_color * 0.5
		mesh.material_override = _material

	# Add to group for tracking
	add_to_group("enemy_projectiles")

func _physics_process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return

	# Move projectile
	global_position += direction * speed * delta

	# Check distance to player
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and GameManager.player_is_alive:
		var dist: float = global_position.distance_to(player.global_position)
		if dist < GameConstants.ENEMY_PROJECTILE_HIT_RADIUS:
			GameManager.take_damage(damage)
			queue_free()

	# Aura pulse
	if _material:
		var pulse: float = 0.7 + 0.3 * sin(age * GameConstants.ENEMY_PROJECTILE_AURA_PULSE_SPEED)
		_material.emission_energy_multiplier = pulse

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameManager.take_damage(damage)
		queue_free()