## Zorp Wiggles — Pulse Wave (Q Ability)
## Expanding ring of energy that damages all nearby enemies.
## Ported from pulse wave logic in Ursina game.py.

extends Node3D

var radius: float = 0.0
var max_radius: float = GameConstants.PULSE_WAVE_RADIUS
var damage: int = GameConstants.PULSE_WAVE_DAMAGE
var expand_speed: float = 30.0
var has_hit: Dictionary = {}  # Track which enemies we've already hit
var _light: OmniLight3D = null

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

	# Center light flash — illuminates the area as the wave fires, fading as it expands
	_light = OmniLight3D.new()
	_light.light_color = Color(0.3, 0.8, 1.0)
	_light.light_energy = 3.0
	_light.omni_range = 8.0
	_light.omni_attenuation = 1.5
	add_child(_light)

func _physics_process(delta: float) -> void:
	if GameManager.is_paused:
		return
	
	# Expand — use an ease-out curve so the ring bursts outward quickly and
	# decelerates as it reaches max radius. This feels more energetic than a
	# linear expansion and matches the visual "shockwave" shape players expect.
	var progress: float = radius / max_radius if max_radius > 0.0 else 0.0
	progress = clampf(progress, 0.0, 1.0)
	# Ease-out quadratic: fast start, gentle finish
	var speed_mult: float = 1.0 - 0.65 * progress
	radius += expand_speed * speed_mult * delta
	
	# Update ring visual
	if ring_mesh:
		var scale_val := radius * 2.0
		# Use a smoothed scale so the ring doesn't pop on the first frame
		ring_mesh.scale = ring_mesh.scale.lerp(Vector3(scale_val, scale_val, 1.0), 1.0 - exp(-12.0 * delta))
		# Fade out as it expands — ease-in so it stays visible early then fades fast
		var alpha := 1.0 - progress
		alpha = alpha * alpha  # Quadratic fade for a sharper disappear at the edge
		mat_override_albedo_alpha(alpha)

	# Fade the center light as the wave expands (punchy flash → gentle glow → off)
	if _light:
		_light.light_energy = 3.0 * (1.0 - progress)
	
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