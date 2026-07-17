## Zorp Wiggles — Pulse Wave (Q Ability)
## Expanding ring of energy that damages all nearby enemies.
## Ported from pulse wave logic in Ursina game.py.

extends Node3D

var radius: float = 0.0
var max_radius: float = GameConstants.PULSE_WAVE_RADIUS
var damage: int = GameConstants.PULSE_WAVE_DAMAGE
var expand_speed: float = 30.0
var has_hit: Dictionary = {}  # Track which enemies we've already hit

@onready var ring_mesh: MeshInstance3D = $RingMesh

func _ready() -> void:
	# Create expanding ring visual
	if ring_mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.8, 1.0, 0.6)  # Cyan ring
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.8, 1.0) * 0.5
		ring_mesh.material_override = mat

func _physics_process(delta: float) -> void:
	if GameManager.is_paused:
		return
	
	# Expand
	radius += expand_speed * delta
	
	# Update ring visual
	if ring_mesh:
		var scale_val := radius * 2.0
		ring_mesh.scale = Vector3(scale_val, scale_val, 1.0)
		# Fade out as it expands
		var progress := radius / max_radius
		var alpha := 1.0 - progress
		mat_override_albedo_alpha(alpha)
	
	# Damage enemies in ring
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_node: Node3D = enemy
		if not enemy_node.is_in_group("enemies"):
			continue
		if not has_hit.has(enemy_node.get_instance_id()):
			var dist := global_position.distance_to(enemy_node.global_position)
			# Only hit enemies within the ring's current band
			if dist <= radius and dist >= radius - 2.0:
				has_hit[enemy_node.get_instance_id()] = true
				if enemy_node.has_method("take_damage_from"):
					enemy_node.take_damage_from(damage, global_position)
				elif enemy_node.has_method("take_damage"):
					enemy_node.take_damage(damage)
				# Knockback
				if enemy_node.has_method("apply_knockback"):
					var knock_dir: Vector3 = (enemy_node.global_position - global_position).normalized()
					knock_dir.y = 0
					enemy_node.apply_knockback(knock_dir, GameConstants.KNOCKBACK_FORCE_EXPLOSION)
	
	# Remove when fully expanded
	if radius >= max_radius:
		queue_free()

func mat_override_albedo_alpha(alpha: float) -> void:
	if ring_mesh and ring_mesh.material_override:
		var mat := ring_mesh.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = alpha