## Zorp Wiggles — Deployable Weapon Mod System (Phase 24)
## Autoload singleton that manages the 4 deployable weapon mods:
##   - Shield Bubble (player-attached shield that absorbs damage + reflects projectiles)
##   - Turret Deploy (stationary turret that auto-fires at nearest enemy)
##   - Gravity Flip Field (area that launches enemies upward, then they take fall damage)
##   - Void Rift Cutter (persistent rift that damages enemies passing through)
##
## These mods are triggered by the deploy_ability input (V key) when equipped.
## They don't fire a traditional projectile — instead they spawn a deployable
## effect at/near the player. Each has its own duration and behavior.
##
## The system tracks active deployables and cleans them up on game restart.

extends Node

# ─── Signals ──────────────────────────────────────────────────────────────────
signal deployable_activated(mod_id: int)
signal deployable_expired(mod_id: int)
signal shield_bubble_changed(current_hp: int, max_hp: int)

# ─── State ─────────────────────────────────────────────────────────────────────
# Currently active deployable nodes (keyed by mod_id for one-per-type enforcement)
var _active_deployables: Dictionary = {}  # { mod_id: Node }

# Shield bubble state (tracked here for damage absorption queries)
var _shield_bubble_hp: int = 0
var _shield_bubble_max_hp: int = 0
var _shield_bubble_active: bool = false

# ─── Public API ────────────────────────────────────────────────────────────────

## Returns true if a deployable of the given mod type is currently active.
func is_deployable_active(mod_id: int) -> bool:
	return _active_deployables.has(mod_id)

## Returns the active shield bubble HP (0 if no bubble active).
func get_shield_bubble_hp() -> int:
	return _shield_bubble_hp

## Returns the max shield bubble HP (0 if no bubble active).
func get_shield_bubble_max_hp() -> int:
	return _shield_bubble_max_hp

## Returns true if the shield bubble is currently active.
func is_shield_bubble_active() -> bool:
	return _shield_bubble_active

## Try to activate the equipped deployable weapon mod. Called by player when the
## deploy_ability input is pressed. Returns true if a deployable was activated.
func try_activate_deployable(mod_id: int, player: Node3D) -> bool:
	if not player or not is_instance_valid(player):
		return false
	# Only the 4 deployable mods can be activated this way
	match mod_id:
		GameConstants.WeaponMod.SHIELD_BUBBLE:
			return _activate_shield_bubble(player)
		GameConstants.WeaponMod.TURRET_DEPLOY:
			return _activate_turret_deploy(player)
		GameConstants.WeaponMod.GRAVITY_FLIP_FIELD:
			return _activate_gravity_flip_field(player)
		GameConstants.WeaponMod.VOID_RIFT_CUTTER:
			return _activate_void_rift_cutter(player)
		_:
			return false  # Not a deployable mod

## Apply damage to the shield bubble (if active). Returns the remaining damage
## that should pass through to the player after the bubble absorbs what it can.
## Called by GameManager.take_damage() before applying damage to the player.
func absorb_damage(amount: int) -> int:
	if not _shield_bubble_active or _shield_bubble_hp <= 0:
		return amount
	var absorbed: int = min(amount, _shield_bubble_hp)
	_shield_bubble_hp -= absorbed
	shield_bubble_changed.emit(_shield_bubble_hp, _shield_bubble_max_hp)
	if _shield_bubble_hp <= 0:
		_break_shield_bubble()
	return amount - absorbed

## Returns the damage reduction fraction (0-1) that the shield bubble provides
## for damage that passes through after absorption. Called by GameManager.
func get_shield_bubble_damage_reduction() -> float:
	if not _shield_bubble_active:
		return 0.0
	return GameConstants.SHIELD_BUBBLE_DAMAGE_REDUCTION

## Called by enemy_projectile when it enters the shield bubble's Area3D.
## Returns true if the projectile was reflected (should be redirected by the caller).
func reflect_enemy_projectile(proj: Node, player_pos: Vector3) -> bool:
	if not _shield_bubble_active:
		return false
	if not proj or not is_instance_valid(proj):
		return false
	# Only reflect EnemyProjectile nodes
	if not (proj is EnemyProjectile) and not proj.is_in_group("enemy_projectiles"):
		return false
	# Find the shooter (nearest enemy to the projectile) to reflect back at
	var reflect_target: Vector3 = _find_nearest_enemy_to(proj.global_position)
	if reflect_target == Vector3.ZERO:
		# No enemy found — reflect back toward the projectile's origin direction (reverse)
		reflect_target = proj.global_position - proj.direction * 10.0
	# Set the projectile's direction toward the target
	var new_dir: Vector3 = (reflect_target - proj.global_position).normalized()
	new_dir.y = 0.0
	new_dir = new_dir.normalized()
	proj.direction = new_dir
	# Increase speed
	if "speed" in proj:
		proj.speed *= GameConstants.SHIELD_BUBBLE_REFLECT_SPEED_MULT
	# Reduce damage (reflected bolts are less lethal)
	if "damage" in proj:
		proj.damage = int(proj.damage * GameConstants.SHIELD_BUBBLE_REFLECT_DAMAGE_MULT)
	# Move the projectile outside the bubble to prevent re-triggering
	proj.global_position = player_pos + new_dir * (GameConstants.SHIELD_BUBBLE_RADIUS + 0.5)
	# Visual: reflection flash
	ParticleEffects.spawn_explosion(proj.get_parent(), proj.global_position,
		GameConstants.WEAPON_MOD_COLORS[GameConstants.WeaponMod.SHIELD_BUBBLE], 10, 0.25)
	return true

# ─── Shield Bubble ────────────────────────────────────────────────────────────

func _activate_shield_bubble(player: Node3D) -> bool:
	# Only one bubble at a time — refresh if already active
	if _shield_bubble_active:
		_shield_bubble_hp = _shield_bubble_max_hp
		shield_bubble_changed.emit(_shield_bubble_hp, _shield_bubble_max_hp)
		deployable_activated.emit(GameConstants.WeaponMod.SHIELD_BUBBLE)
		return true
	# Remove any existing shield bubble node
	_remove_deployable(GameConstants.WeaponMod.SHIELD_BUBBLE)
	_shield_bubble_max_hp = GameConstants.SHIELD_BUBBLE_HP
	_shield_bubble_hp = _shield_bubble_max_hp
	_shield_bubble_active = true
	# Create the bubble visual + Area3D for projectile reflection
	var bubble := Area3D.new()
	bubble.name = "ShieldBubble"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = GameConstants.SHIELD_BUBBLE_RADIUS
	shape.shape = sphere
	bubble.add_child(shape)
	# Visual: translucent blue sphere
	var bubble_mesh := MeshInstance3D.new()
	var bubble_sphere := SphereMesh.new()
	bubble_sphere.radius = GameConstants.SHIELD_BUBBLE_RADIUS
	bubble_sphere.height = GameConstants.SHIELD_BUBBLE_RADIUS * 2.0
	bubble_sphere.radial_segments = 20
	bubble_sphere.rings = 10
	bubble_mesh.mesh = bubble_sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.7, 1.0, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.7, 1.0) * 0.5
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.rim_enabled = true
	mat.rim = 1.0
	mat.rim_tint = 1.0
	bubble_mesh.material_override = mat
	bubble.add_child(bubble_mesh)
	# Pulsing light
	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 0.7, 1.0)
	light.light_energy = 1.5
	light.omni_range = GameConstants.SHIELD_BUBBLE_RADIUS * 2.0
	bubble.add_child(light)
	# Connect the body_entered signal for enemy projectile reflection
	bubble.body_entered.connect(_on_shield_bubble_body_entered.bind(bubble))
	# Attach to player so it follows them
	player.add_child(bubble)
	bubble.position = Vector3(0, 0.5, 0)
	_active_deployables[GameConstants.WeaponMod.SHIELD_BUBBLE] = bubble
	# Pulsing animation
	var pulse_tw := bubble.create_tween().set_loops()
	pulse_tw.tween_property(mat, "emission_energy_multiplier", 2.5, 0.5).set_ease(Tween.EASE_IN_OUT)
	pulse_tw.tween_property(mat, "emission_energy_multiplier", 1.0, 0.5).set_ease(Tween.EASE_IN_OUT)
	# Auto-expire after duration
	var tree := get_tree()
	if tree:
		var timer := tree.create_timer(GameConstants.SHIELD_BUBBLE_DURATION, true, false, true)
		timer.timeout.connect(_on_shield_bubble_expired)
	shield_bubble_changed.emit(_shield_bubble_hp, _shield_bubble_max_hp)
	deployable_activated.emit(GameConstants.WeaponMod.SHIELD_BUBBLE)
	# Statistics tracking
	if Statistics:
		Statistics.record_shot()  # Count as a deployable use
	# Audio feedback
	AudioManager.play_sfx(AudioManager.SFX_SHIELD)
	return true

func _on_shield_bubble_body_entered(body: Node3D, bubble: Area3D) -> void:
	# Reflect enemy projectiles that enter the bubble
	if not _shield_bubble_active:
		return
	if body.is_in_group("enemy_projectiles"):
		var player: Node3D = get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player):
			reflect_enemy_projectile(body, player.global_position)

func _on_shield_bubble_expired() -> void:
	if not _shield_bubble_active:
		return
	_break_shield_bubble()

func _break_shield_bubble() -> void:
	_shield_bubble_active = false
	_shield_bubble_hp = 0
	# Shatter effect
	var bubble: Node = _active_deployables.get(GameConstants.WeaponMod.SHIELD_BUBBLE)
	if bubble and is_instance_valid(bubble):
		var player: Node3D = get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player):
			ParticleEffects.spawn_shield_break_shatter(player.get_parent(),
				player.global_position, Color(0.3, 0.7, 1.0))
		bubble.queue_free()
	_active_deployables.erase(GameConstants.WeaponMod.SHIELD_BUBBLE)
	shield_bubble_changed.emit(0, 0)
	deployable_expired.emit(GameConstants.WeaponMod.SHIELD_BUBBLE)

# ─── Turret Deploy ────────────────────────────────────────────────────────────

func _activate_turret_deploy(player: Node3D) -> bool:
	# Remove any existing turret (one at a time)
	_remove_deployable(GameConstants.WeaponMod.TURRET_DEPLOY)
	var turret := TurretDeploy.new()
	turret.setup(player.global_position)
	# Add to the player's parent (the main world node) so it's not attached to the player
	player.get_parent().add_child(turret)
	_active_deployables[GameConstants.WeaponMod.TURRET_DEPLOY] = turret
	deployable_activated.emit(GameConstants.WeaponMod.TURRET_DEPLOY)
	AudioManager.play_sfx(AudioManager.SFX_SHOOT)
	return true

# ─── Gravity Flip Field ───────────────────────────────────────────────────────

func _activate_gravity_flip_field(player: Node3D) -> bool:
	# Remove any existing field
	_remove_deployable(GameConstants.WeaponMod.GRAVITY_FLIP_FIELD)
	var field := GravityFlipField.new()
	field.setup(player.global_position)
	player.get_parent().add_child(field)
	_active_deployables[GameConstants.WeaponMod.GRAVITY_FLIP_FIELD] = field
	deployable_activated.emit(GameConstants.WeaponMod.GRAVITY_FLIP_FIELD)
	AudioManager.play_sfx(AudioManager.SFX_PULSE_WAVE)
	return true

# ─── Void Rift Cutter ────────────────────────────────────────────────────────

func _activate_void_rift_cutter(player: Node3D) -> bool:
	# Remove any existing rift
	_remove_deployable(GameConstants.WeaponMod.VOID_RIFT_CUTTER)
	var rift := VoidRiftCutter.new()
	rift.setup(player.global_position)
	player.get_parent().add_child(rift)
	_active_deployables[GameConstants.WeaponMod.VOID_RIFT_CUTTER] = rift
	deployable_activated.emit(GameConstants.WeaponMod.VOID_RIFT_CUTTER)
	AudioManager.play_sfx(AudioManager.SFX_EXPLOSION)
	return true

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _remove_deployable(mod_id: int) -> void:
	var node: Node = _active_deployables.get(mod_id)
	if node and is_instance_valid(node):
		node.queue_free()
	_active_deployables.erase(mod_id)

func _find_nearest_enemy_to(pos: Vector3) -> Vector3:
	var nearest_pos: Vector3 = Vector3.ZERO
	var nearest_dist: float = 30.0
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.is_in_group("enemies"):
			continue
		var d: float = pos.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest_pos = enemy.global_position
	return nearest_pos

# ─── Reset (on game restart) ──────────────────────────────────────────────────

func reset() -> void:
	for mod_id in _active_deployables.keys():
		_remove_deployable(mod_id)
	_active_deployables.clear()
	_shield_bubble_active = false
	_shield_bubble_hp = 0
	_shield_bubble_max_hp = 0
	shield_bubble_changed.emit(0, 0)

func _ready() -> void:
	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)
		GameManager.player_died.connect(_on_player_died)

func _on_game_restarted() -> void:
	reset()

func _on_player_died() -> void:
	# Clean up deployables when the player dies
	for mod_id in _active_deployables.keys():
		_remove_deployable(mod_id)
	_active_deployables.clear()
	_shield_bubble_active = false
	_shield_bubble_hp = 0
	_shield_bubble_max_hp = 0
	shield_bubble_changed.emit(0, 0)


# ─── TurretDeploy (inner class) ──────────────────────────────────────────────
## Stationary turret that auto-fires at the nearest enemy. Has its own HP and
## can be destroyed by enemies. Lasts for a fixed duration.

class TurretDeploy extends Node3D:
	var _hp: int = 0
	var _fire_timer: float = 0.0
	var _duration_timer: float = 0.0
	var _base: MeshInstance3D = null
	var _head: MeshInstance3D = null
	var _barrel: MeshInstance3D = null
	var _light: OmniLight3D = null
	var _target: Node3D = null
	var _repath_timer: float = 0.0
	var _material: StandardMaterial3D = null

	func setup(pos: Vector3) -> void:
		global_position = pos
		_hp = GameConstants.TURRET_DEPLOY_HP

	func _ready() -> void:
		# Base (cylinder)
		_base = MeshInstance3D.new()
		var base_mesh := CylinderMesh.new()
		base_mesh.top_radius = 0.6
		base_mesh.bottom_radius = 0.8
		base_mesh.height = 1.0
		base_mesh.radial_segments = 12
		_base.mesh = base_mesh
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color(0.4, 0.5, 0.3)
		_material.emission_enabled = true
		_material.emission = Color(0.5, 0.7, 0.3) * 0.3
		_material.metallic = 0.6
		_material.roughness = 0.4
		_base.material_override = _material
		add_child(_base)
		_base.position = Vector3(0, 0.5, 0)
		# Head (sphere that rotates to track targets)
		_head = MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.4
		head_mesh.height = 0.8
		head_mesh.radial_segments = 10
		_head.mesh = head_mesh
		var head_mat := StandardMaterial3D.new()
		head_mat.albedo_color = Color(0.7, 0.85, 0.3)
		head_mat.emission_enabled = true
		head_mat.emission = Color(0.7, 0.85, 0.3) * 0.5
		head_mat.emission_energy_multiplier = 1.5
		head_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_head.material_override = head_mat
		add_child(_head)
		_head.position = Vector3(0, 1.2, 0)
		# Barrel (cylinder pointing forward)
		_barrel = MeshInstance3D.new()
		var barrel_mesh := CylinderMesh.new()
		barrel_mesh.top_radius = 0.1
		barrel_mesh.bottom_radius = 0.15
		barrel_mesh.height = 1.0
		_barrel.mesh = barrel_mesh
		var barrel_mat := StandardMaterial3D.new()
		barrel_mat.albedo_color = Color(0.5, 0.6, 0.3)
		barrel_mat.metallic = 0.7
		barrel_mat.roughness = 0.3
		_barrel.material_override = barrel_mat
		_head.add_child(_barrel)
		_barrel.rotation_degrees.x = 90.0
		_barrel.position = Vector3(0, 0, 0.6)
		# Light
		_light = OmniLight3D.new()
		_light.light_color = Color(0.7, 0.85, 0.3)
		_light.light_energy = 1.5
		_light.omni_range = 5.0
		add_child(_light)
		_light.position = Vector3(0, 1.2, 0)
		add_to_group("deployable_turret")
		# Spawn materialization effect
		ParticleEffects.spawn_materialization(get_parent(), global_position + Vector3(0, 1.0, 0))

	func _physics_process(delta: float) -> void:
		_duration_timer += delta
		if _duration_timer >= GameConstants.TURRET_DEPLOY_DURATION:
			_expire()
			return
		# Find/refresh target
		_repath_timer -= delta
		if _repath_timer <= 0 or not is_instance_valid(_target):
			_repath_timer = 0.5
			_target = _find_nearest_enemy()
		# Rotate head toward target
		if _target and is_instance_valid(_target):
			var to_target: Vector3 = (_target.global_position - _head.global_position).normalized()
			var target_angle: float = atan2(to_target.x, to_target.z)
			_head.rotation.y = lerp_angle(_head.rotation.y, target_angle,
				1.0 - exp(-GameConstants.TURRET_DEPLOY_ROTATE_SPEED * delta))
		# Fire timer
		_fire_timer -= delta
		if _fire_timer <= 0 and _target and is_instance_valid(_target):
			_fire_timer = GameConstants.TURRET_DEPLOY_FIRE_RATE
			_fire_at_target()

	func _find_nearest_enemy() -> Node3D:
		var nearest: Node3D = null
		var nearest_dist: float = GameConstants.TURRET_DEPLOY_RANGE
		for enemy in GameManager.enemies:
			if not is_instance_valid(enemy):
				continue
			if not enemy.is_in_group("enemies"):
				continue
			var d: float = global_position.distance_to(enemy.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = enemy
		return nearest

	func _fire_at_target() -> void:
		if not _target or not is_instance_valid(_target):
			return
		var dir: Vector3 = (_target.global_position - _head.global_position).normalized()
		dir.y = 0.0
		dir = dir.normalized()
		# Spawn a simple projectile (reuse enemy_projectile visual but it's a player bolt)
		var bolt := Area3D.new()
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.2
		shape.shape = sphere
		bolt.add_child(shape)
		var bolt_mesh := MeshInstance3D.new()
		var bolt_sphere := SphereMesh.new()
		bolt_sphere.radius = 0.2
		bolt_sphere.height = 0.4
		bolt_sphere.radial_segments = 8
		bolt_mesh.mesh = bolt_sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.7, 0.85, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(0.7, 0.85, 0.3) * 0.8
		mat.emission_energy_multiplier = 2.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bolt_mesh.material_override = mat
		bolt.add_child(bolt_mesh)
		var bolt_light := OmniLight3D.new()
		bolt_light.light_color = Color(0.7, 0.85, 0.3)
		bolt_light.light_energy = 1.5
		bolt_light.omni_range = 3.0
		bolt.add_child(bolt_light)
		get_parent().add_child(bolt)
		bolt.global_position = _head.global_position + dir * 0.8
		# Store damage for the body_entered callback
		bolt.set_meta("damage", GameConstants.TURRET_DEPLOY_DAMAGE)
		bolt.set_meta("is_turret_bolt", true)
		# Connect body_entered to damage enemies
		bolt.body_entered.connect(_on_bolt_hit_enemy.bind(bolt))
		# Move the bolt via tween (the bolt flies forward until its lifetime expires)
		var bolt_lifetime: float = 3.0
		var travel_dist: float = GameConstants.TURRET_DEPLOY_PROJECTILE_SPEED * bolt_lifetime
		var end_pos: Vector3 = bolt.global_position + dir * travel_dist
		var move_tw := bolt.create_tween()
		move_tw.tween_property(bolt, "global_position", end_pos, bolt_lifetime)
		move_tw.tween_callback(bolt.queue_free)
		# Muzzle flash
		var flash := OmniLight3D.new()
		flash.light_color = Color(0.7, 0.85, 0.3)
		flash.light_energy = 4.0
		flash.omni_range = 3.0
		get_parent().add_child(flash)
		flash.global_position = _head.global_position + dir * 0.8
		var flash_tw := flash.create_tween()
		flash_tw.tween_property(flash, "light_energy", 0.0, 0.08)
		flash_tw.tween_callback(flash.queue_free)
		AudioManager.play_sfx(AudioManager.SFX_SHOOT)

	func _on_bolt_hit_enemy(body: Node3D, bolt: Area3D) -> void:
		if not bolt or not is_instance_valid(bolt):
			return
		if body.is_in_group("enemies"):
			var dmg: int = bolt.get_meta("damage", 18)
			if body.has_method("take_damage_from"):
				body.take_damage_from(dmg, bolt.global_position)
			elif body.has_method("take_damage"):
				body.take_damage(dmg)
			DamageNumber.spawn(bolt.get_parent(), body.global_position, dmg, false, false)
			ParticleEffects.spawn_explosion(bolt.get_parent(), bolt.global_position,
				Color(0.7, 0.85, 0.3), 8, 0.2)
			bolt.queue_free()
		elif not body.is_in_group("player") and not body.is_in_group("deployable_turret"):
			# Hit terrain
			ParticleEffects.spawn_explosion(bolt.get_parent(), bolt.global_position,
				Color(0.7, 0.85, 0.3), 6, 0.15)
			bolt.queue_free()

	func take_damage(amount: int) -> void:
		_hp -= amount
		# Flash on hit
		if _material:
			_material.emission_energy_multiplier = 4.0
			var tw := create_tween()
			tw.tween_property(_material, "emission_energy_multiplier", 1.0, 0.15)
		if _hp <= 0:
			_expire()

	func _expire() -> void:
		# Death poof
		ParticleEffects.spawn_explosion(get_parent(), global_position + Vector3(0, 1.0, 0),
			Color(0.7, 0.85, 0.3), 20, 0.4)
		# Light flash
		if _light:
			var flash_tw := create_tween()
			flash_tw.tween_property(_light, "light_energy", 0.0, 0.3)
		# Shrink + fade
		if _base:
			var shrink_tw := create_tween()
			shrink_tw.tween_property(self, "scale", Vector3.ZERO, 0.3).set_ease(Tween.EASE_IN)
		# Schedule free (deferred so tweens can finish)
		var tree := get_tree()
		if tree:
			var timer := tree.create_timer(0.35, true, false, true)
			timer.timeout.connect(queue_free)
		else:
			queue_free()


# ─── GravityFlipField (inner class) ───────────────────────────────────────────
## Cylindrical field that launches enemies upward. When the field expires, enemies
## that were launched take fall damage on landing. The player is unaffected.

class GravityFlipField extends Node3D:
	var _duration_timer: float = 0.0
	var _tick_timer: float = 0.0
	var _launched_enemies: Dictionary = {}  # { enemy: float launch_height }
	var _field_mesh: MeshInstance3D = null
	var _field_mat: StandardMaterial3D = null
	var _light: OmniLight3D = null

	func setup(pos: Vector3) -> void:
		global_position = pos

	func _ready() -> void:
		# Visual: translucent purple cylinder
		_field_mesh = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = GameConstants.GRAVITY_FLIP_FIELD_RADIUS
		cyl.bottom_radius = GameConstants.GRAVITY_FLIP_FIELD_RADIUS
		cyl.height = GameConstants.GRAVITY_FLIP_FIELD_HEIGHT
		cyl.radial_segments = 24
		_field_mesh.mesh = cyl
		_field_mat = StandardMaterial3D.new()
		_field_mat.albedo_color = Color(0.6, 0.4, 1.0, 0.15)
		_field_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_field_mat.emission_enabled = true
		_field_mat.emission = Color(0.6, 0.4, 1.0) * 0.4
		_field_mat.emission_energy_multiplier = 1.5
		_field_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_field_mat.no_depth_test = true
		_field_mesh.material_override = _field_mat
		add_child(_field_mesh)
		_field_mesh.position = Vector3(0, GameConstants.GRAVITY_FLIP_FIELD_HEIGHT * 0.5, 0)
		# Light
		_light = OmniLight3D.new()
		_light.light_color = Color(0.6, 0.4, 1.0)
		_light.light_energy = 2.0
		_light.omni_range = GameConstants.GRAVITY_FLIP_FIELD_RADIUS * 1.5
		add_child(_light)
		_light.position = Vector3(0, 3.0, 0)
		# Pulsing animation
		var pulse_tw := create_tween().set_loops()
		pulse_tw.tween_property(_field_mat, "emission_energy_multiplier", 2.5, 0.4).set_ease(Tween.EASE_IN_OUT)
		pulse_tw.tween_property(_field_mat, "emission_energy_multiplier", 1.0, 0.4).set_ease(Tween.EASE_IN_OUT)
		# Spawn particles
		ParticleEffects.spawn_explosion(get_parent(), global_position,
			Color(0.6, 0.4, 1.0), 30, 0.5)
		add_to_group("deployable_gravity_field")

	func _physics_process(delta: float) -> void:
		_duration_timer += delta
		if _duration_timer >= GameConstants.GRAVITY_FLIP_FIELD_DURATION:
			_expire()
			return
		# Tick: apply upward force to enemies in the field
		_tick_timer -= delta
		if _tick_timer <= 0:
			_tick_timer = GameConstants.GRAVITY_FLIP_FIELD_TICK_INTERVAL
			_apply_upward_force()

	func _apply_upward_force() -> void:
		for enemy in GameManager.enemies:
			if not is_instance_valid(enemy):
				continue
			if not enemy.is_in_group("enemies"):
				continue
			var d: float = global_position.distance_to(enemy.global_position)
			if d < GameConstants.GRAVITY_FLIP_FIELD_RADIUS:
				# Launch the enemy upward by directly moving their position
				# (enemies are CharacterBody3D, so we manipulate global_position)
				enemy.global_position.y += GameConstants.GRAVITY_FLIP_FIELD_UPWARD_FORCE * GameConstants.GRAVITY_FLIP_FIELD_TICK_INTERVAL
				# Track the launch height for fall damage on expiry
				var launch_y: float = enemy.global_position.y - 0.5  # approximate ground level
				if launch_y > _launched_enemies.get(enemy, 0.0):
					_launched_enemies[enemy] = launch_y
				# Visual: purple particles trail
				ParticleEffects.spawn_explosion(get_parent(), enemy.global_position,
					Color(0.6, 0.4, 1.0), 4, 0.1)

	func _expire() -> void:
		# Apply fall damage to launched enemies
		for enemy in _launched_enemies.keys():
			if not is_instance_valid(enemy):
				continue
			if not enemy.is_in_group("enemies"):
				continue
			# Drop the enemy back down
			var drop_tw: Tween = enemy.create_tween()
			var target_y: float = 0.5  # ground level
			drop_tw.tween_property(enemy, "global_position:y", target_y, 0.5).set_ease(Tween.EASE_IN)
			# Apply fall damage after the drop
			drop_tw.tween_callback(func():
				if is_instance_valid(enemy) and enemy.is_in_group("enemies"):
					if enemy.has_method("take_damage_from"):
						enemy.take_damage_from(GameConstants.GRAVITY_FLIP_FIELD_FALL_DAMAGE, global_position)
					elif enemy.has_method("take_damage"):
						enemy.take_damage(GameConstants.GRAVITY_FLIP_FIELD_FALL_DAMAGE)
					DamageNumber.spawn(enemy.get_parent(), enemy.global_position,
						GameConstants.GRAVITY_FLIP_FIELD_FALL_DAMAGE, false, false)
					ParticleEffects.spawn_explosion(enemy.get_parent(), enemy.global_position,
						Color(0.6, 0.4, 1.0), 12, 0.3)
			)
		_launched_enemies.clear()
		# Fade out the field
		if _field_mat:
			var fade_tw := create_tween()
			fade_tw.tween_property(_field_mat, "albedo_color:a", 0.0, 0.3)
			fade_tw.tween_property(_light, "light_energy", 0.0, 0.3)
		# Big particle burst on collapse
		ParticleEffects.spawn_mega_explosion(get_parent(), global_position, Color(0.6, 0.4, 1.0))
		# Camera shake
		if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
			GameManager.camera_rig.add_trauma(0.3)
		# Schedule free
		var tree := get_tree()
		if tree:
			var timer := tree.create_timer(0.4, true, false, true)
			timer.timeout.connect(queue_free)
		else:
			queue_free()


# ─── VoidRiftCutter (inner class) ─────────────────────────────────────────────
## A planar rift that damages enemies passing through it. Persists for a duration,
## slowly rotates, and emits void particles. Per-enemy damage cooldown prevents
## melting a single enemy in one pass.

class VoidRiftCutter extends Node3D:
	var _duration_timer: float = 0.0
	var _tick_timer: float = 0.0
	var _enemy_cooldowns: Dictionary = {}  # { enemy: float time_until_next_damage }
	var _rift_mesh: MeshInstance3D = null
	var _rift_mat: StandardMaterial3D = null
	var _light: OmniLight3D = null

	func setup(pos: Vector3) -> void:
		global_position = pos

	func _ready() -> void:
		# Visual: a tall thin plane (the rift slice through space)
		_rift_mesh = MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(GameConstants.VOID_RIFT_CUTTER_LENGTH, 4.0)
		plane.orientation = PlaneMesh.FACE_Y
		_rift_mesh.mesh = plane
		_rift_mat = StandardMaterial3D.new()
		_rift_mat.albedo_color = Color(0.3, 0.1, 0.5, 0.5)
		_rift_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_rift_mat.emission_enabled = true
		_rift_mat.emission = Color(0.5, 0.2, 0.8) * 0.8
		_rift_mat.emission_energy_multiplier = 2.5
		_rift_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_rift_mat.no_depth_test = true
		_rift_mat.rim_enabled = true
		_rift_mat.rim = 1.0
		_rift_mat.rim_tint = 1.0
		_rift_mesh.material_override = _rift_mat
		add_child(_rift_mesh)
		_rift_mesh.position = Vector3(0, 1.5, 0)
		# Light
		_light = OmniLight3D.new()
		_light.light_color = Color(0.5, 0.2, 0.8)
		_light.light_energy = 3.0
		_light.omni_range = 6.0
		add_child(_light)
		_light.position = Vector3(0, 1.5, 0)
		# Pulsing animation
		var pulse_tw := create_tween().set_loops()
		pulse_tw.tween_property(_rift_mat, "emission_energy_multiplier", 4.0, 0.3).set_ease(Tween.EASE_IN_OUT)
		pulse_tw.tween_property(_rift_mat, "emission_energy_multiplier", 1.5, 0.3).set_ease(Tween.EASE_IN_OUT)
		# Spawn particles
		ParticleEffects.spawn_explosion(get_parent(), global_position,
			Color(0.5, 0.2, 0.8), 30, 0.5)
		add_to_group("deployable_void_rift")

	func _physics_process(delta: float) -> void:
		_duration_timer += delta
		if _duration_timer >= GameConstants.VOID_RIFT_CUTTER_DURATION:
			_expire()
			return
		# Rotate the rift slowly
		rotate_y(GameConstants.VOID_RIFT_CUTTER_ROTATE_SPEED * delta)
		# Tick: damage enemies within the rift's area
		_tick_timer -= delta
		if _tick_timer <= 0:
			_tick_timer = 0.1  # Check every 0.1s
			_damage_enemies_in_rift(delta)

	func _damage_enemies_in_rift(delta: float) -> void:
		# Update per-enemy cooldowns
		for enemy in _enemy_cooldowns.keys():
			if not is_instance_valid(enemy):
				_enemy_cooldowns.erase(enemy)
				continue
			_enemy_cooldowns[enemy] -= delta * 10.0  # Approximate (0.1s tick)
		# Check each enemy for rift intersection
		for enemy in GameManager.enemies:
			if not is_instance_valid(enemy):
				continue
			if not enemy.is_in_group("enemies"):
				continue
			# Cooldown check
			if _enemy_cooldowns.has(enemy) and _enemy_cooldowns[enemy] > 0.0:
				continue
			# Distance check: is the enemy within the rift's length and close to the rift plane?
			var to_enemy: Vector3 = enemy.global_position - global_position
			to_enemy.y = 0.0
			var dist: float = to_enemy.length()
			if dist > GameConstants.VOID_RIFT_CUTTER_LENGTH * 0.5:
				continue
			# Project onto the rift's local XZ plane to check "closeness" to the plane
			var local_pos: Vector3 = to_enemy.rotated(Vector3.UP, -rotation.y)
			if abs(local_pos.z) < GameConstants.VOID_RIFT_CUTTER_WIDTH:
				# Enemy is passing through the rift — damage them
				if enemy.has_method("take_damage_from"):
					enemy.take_damage_from(GameConstants.VOID_RIFT_CUTTER_DAMAGE, global_position)
				elif enemy.has_method("take_damage"):
					enemy.take_damage(GameConstants.VOID_RIFT_CUTTER_DAMAGE)
				DamageNumber.spawn(enemy.get_parent(), enemy.global_position,
					GameConstants.VOID_RIFT_CUTTER_DAMAGE, false, false)
				# Void particle burst at the hit point
				ParticleEffects.spawn_explosion(get_parent(), enemy.global_position,
					Color(0.5, 0.2, 0.8), 10, 0.25)
				# Set cooldown
				_enemy_cooldowns[enemy] = GameConstants.VOID_RIFT_CUTTER_TICK_INTERVAL

	func _expire() -> void:
		# Close the rift with a collapse effect
		if _rift_mat:
			var fade_tw := create_tween()
			fade_tw.tween_property(_rift_mat, "albedo_color:a", 0.0, 0.4)
			fade_tw.parallel().tween_property(_rift_mat, "emission_energy_multiplier", 0.0, 0.4)
			fade_tw.parallel().tween_property(_light, "light_energy", 0.0, 0.4)
		# Particle burst
		ParticleEffects.spawn_mega_explosion(get_parent(), global_position, Color(0.5, 0.2, 0.8))
		# Camera shake
		if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
			GameManager.camera_rig.add_trauma(0.25)
		# Schedule free
		var tree := get_tree()
		if tree:
			var timer := tree.create_timer(0.5, true, false, true)
			timer.timeout.connect(queue_free)
		else:
			queue_free()