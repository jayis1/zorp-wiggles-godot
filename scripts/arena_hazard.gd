## Zorp Wiggles — Arena Hazard (Phase 18: Boss Arenas)
## Environmental hazards that spawn inside boss arenas.
## Three hazard types:
##   - LAVA_GEYSER: erupts from the ground after a telegraph, dealing damage + knockback
##   - FALLING_CRYSTAL: drops from above with a shadow telegraph, explodes on impact
##   - VOID_SHOCKWAVE: expands outward from a point, pushing entities away
##
## All hazards use Area3D for damage detection and GPUParticles3D for visual effects.

extends Node3D

class_name ArenaHazard

signal hazard_expired(hazard: ArenaHazard)

enum HazardType {
	LAVA_GEYSER,
	FALLING_CRYSTAL,
	VOID_SHOCKWAVE,
}

@export var hazard_type: int = HazardType.LAVA_GEYSER
@export var telegraph_time: float = GameConstants.ARENA_HAZARD_TELEGRAPH_TIME
@export var active_lifetime: float = GameConstants.ARENA_HAZARD_LIFETIME
@export var damage: int = GameConstants.ARENA_HAZARD_DAMAGE
@export var damage_radius: float = GameConstants.ARENA_HAZARD_RADIUS

# ─── State ────────────────────────────────────────────────────────────────────
enum State { TELEGRAPH, ACTIVE, FADING }
var _state: int = State.TELEGRAPH
var _timer: float = 0.0
var _has_dealt_damage: bool = false

# ─── Visual nodes ─────────────────────────────────────────────────────────────
var _telegraph_mesh: MeshInstance3D = null
var _hazard_mesh: MeshInstance3D = null
var _hazard_light: OmniLight3D = null
var _particles: GPUParticles3D = null
var _damage_area: Area3D = null
var _damage_shape: CollisionShape3D = null
var _mat: StandardMaterial3D = null
var _telegraph_mat: StandardMaterial3D = null

# Void shockwave expansion
var _shockwave_radius: float = 0.0

func _ready() -> void:
	add_to_group("arena_hazards")
	_build_visuals()
	# Start in telegraph state — telegraph mesh visible, hazard hidden
	_timer = telegraph_time

func _process(delta: float) -> void:
	if GameManager.is_paused:
		return

	match _state:
		State.TELEGRAPH:
			_update_telegraph(delta)
		State.ACTIVE:
			_update_active(delta)
		State.FADING:
			_update_fading(delta)

# ─── Telegraph Phase ──────────────────────────────────────────────────────────
func _update_telegraph(delta: float) -> void:
	_timer -= delta
	# Pulsing telegraph intensity
	if _telegraph_mat:
		var pulse: float = 0.4 + 0.3 * sin(Time.get_ticks_msec() * 0.012)
		_telegraph_mat.albedo_color.a = pulse
	# For falling crystal, drop the crystal during telegraph
	if hazard_type == HazardType.FALLING_CRYSTAL and _hazard_mesh:
		var t: float = 1.0 - (_timer / telegraph_time)
		var drop_y: float = lerpf(GameConstants.FALLING_CRYSTAL_HEIGHT, 0.5, t * t)
		_hazard_mesh.position.y = drop_y
	if _timer <= 0:
		_activate()

# ─── Active Phase ─────────────────────────────────────────────────────────────
func _activate() -> void:
	_state = State.ACTIVE
	_timer = active_lifetime
	_has_dealt_damage = false

	# Hide telegraph
	if _telegraph_mesh:
		_telegraph_mesh.visible = false

	# Show hazard visual
	if _hazard_mesh:
		_hazard_mesh.visible = true

	# Activate damage area
	if _damage_area:
		_damage_area.monitoring = true
		_damage_area.monitorable = true

	# Spawn activation particles + light
	_spawn_activation_effect()

	# Camera shake
	var cam: Node3D = GameManager.camera_rig
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.2)

	# Deal damage immediately on activation for geyser/crystal
	if hazard_type != HazardType.VOID_SHOCKWAVE:
		_deal_damage_in_radius()

func _update_active(delta: float) -> void:
	_timer -= delta

	# Void shockwave expands during active phase
	if hazard_type == HazardType.VOID_SHOCKWAVE:
		_shockwave_radius += GameConstants.VOID_SHOCKWAVE_SPEED * delta
		_shockwave_radius = min(_shockwave_radius, GameConstants.VOID_SHOCKWAVE_MAX_RADIUS)
		# Update visual scale
		if _hazard_mesh:
			_hazard_mesh.scale = Vector3(_shockwave_radius, 1.0, _shockwave_radius)
		# Update damage area
		if _damage_shape and _damage_shape.shape is CylinderShape3D:
			(_damage_shape.shape as CylinderShape3D).radius = _shockwave_radius
		# Deal damage continuously as wave expands
		_deal_damage_in_radius()

	# Lava geyser: flicker light
	if hazard_type == HazardType.LAVA_GEYSER and _hazard_light:
		_hazard_light.light_energy = 4.0 + randf() * 2.0

	if _timer <= 0:
		_state = State.FADING
		_timer = 0.5  # fade out duration

# ─── Fading Phase ─────────────────────────────────────────────────────────────
func _update_fading(delta: float) -> void:
	_timer -= delta
	var fade_frac: float = _timer / 0.5
	if _hazard_mesh and _mat:
		_mat.albedo_color.a = fade_frac
		_mat.emission_energy_multiplier = fade_frac * 2.0
	if _hazard_light:
		_hazard_light.light_energy = fade_frac * 3.0
	if _damage_area:
		_damage_area.monitoring = false
	if _timer <= 0:
		hazard_expired.emit(self)
		queue_free()

# ─── Damage ───────────────────────────────────────────────────────────────────
func _deal_damage_in_radius() -> void:
	if _has_dealt_damage and hazard_type != HazardType.VOID_SHOCKWAVE:
		return  # One-shot damage for geyser/crystal, continuous for shockwave

	var center: Vector3 = global_position

	# Damage player if within radius — check both P1 and P2 in co-op
	var player: Node3D = GameManager.player
	if player and is_instance_valid(player) and player.is_in_group("player") and not GameManager.player_is_downed:
		var dist: float = player.global_position.distance_to(center)
		if dist < damage_radius:
			# Falling crystal does extra damage
			var dmg: int = damage
			if hazard_type == HazardType.FALLING_CRYSTAL:
				dmg = GameConstants.FALLING_CRYSTAL_DAMAGE
			GameManager.take_damage(dmg, center)
			# Knockback for geyser
			if hazard_type == HazardType.LAVA_GEYSER:
				_apply_knockback(player, center, GameConstants.LAVA_GEYSER_KNOCKBACK)
			elif hazard_type == HazardType.VOID_SHOCKWAVE:
				_apply_knockback(player, center, 15.0)
			if hazard_type != HazardType.VOID_SHOCKWAVE:
				_has_dealt_damage = true
	# ── Phase 19: Co-op — damage P2 if within radius ──
	if CoOpManager.is_coop_active() and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
		if not CoOpManager.p2_is_downed:
			var p2_dist: float = CoOpManager.p2_node.global_position.distance_to(center)
			if p2_dist < damage_radius:
				var p2_dmg: int = damage
				if hazard_type == HazardType.FALLING_CRYSTAL:
					p2_dmg = GameConstants.FALLING_CRYSTAL_DAMAGE
				CoOpManager.p2_take_damage(p2_dmg, center)
				if hazard_type == HazardType.LAVA_GEYSER:
					_apply_knockback(CoOpManager.p2_node, center, GameConstants.LAVA_GEYSER_KNOCKBACK)
				elif hazard_type == HazardType.VOID_SHOCKWAVE:
					_apply_knockback(CoOpManager.p2_node, center, 15.0)

	# Damage enemies within radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var edist: float = enemy.global_position.distance_to(center)
		if edist < damage_radius:
			var dmg: int = damage
			if hazard_type == HazardType.FALLING_CRYSTAL:
				dmg = GameConstants.FALLING_CRYSTAL_DAMAGE
			if enemy.has_method("take_damage_from"):
				enemy.take_damage_from(dmg, center)
			if hazard_type == HazardType.LAVA_GEYSER:
				_apply_knockback(enemy, center, GameConstants.LAVA_GEYSER_KNOCKBACK * 0.5)
			elif hazard_type == HazardType.VOID_SHOCKWAVE:
				_apply_knockback(enemy, center, 10.0)

func _apply_knockback(target: Node3D, source: Vector3, force: float) -> void:
	var dir: Vector3 = (target.global_position - source).normalized()
	dir.y = 0.4  # Slight upward pop
	if target is CharacterBody3D:
		var cb: CharacterBody3D = target as CharacterBody3D
		cb.velocity += dir * force
	elif target.has_method("apply_knockback"):
		target.apply_knockback(dir, force)

# ─── Visual Construction ──────────────────────────────────────────────────────
func _build_visuals() -> void:
	var primary_color: Color = _get_hazard_color()
	var glow_color: Color = _get_glow_color()

	# ── Telegraph mesh — flat circle on ground showing danger zone ──
	_telegraph_mesh = MeshInstance3D.new()
	var telegraph_geom := CylinderMesh.new()
	telegraph_geom.top_radius = damage_radius
	telegraph_geom.bottom_radius = damage_radius
	telegraph_geom.height = 0.1
	telegraph_geom.radial_segments = 32
	_telegraph_mesh.mesh = telegraph_geom
	_telegraph_mat = StandardMaterial3D.new()
	_telegraph_mat.albedo_color = Color(primary_color.r, primary_color.g, primary_color.b, 0.4)
	_telegraph_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_telegraph_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_telegraph_mat.emission_enabled = true
	_telegraph_mat.emission = glow_color
	_telegraph_mat.emission_energy_multiplier = 1.5
	_telegraph_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_telegraph_mesh.material_override = _telegraph_mat
	# CylinderMesh axis is along Y; with height=0.1 it's already a flat disc
	# lying on the XZ plane. No rotation needed.
	add_child(_telegraph_mesh)
	_telegraph_mesh.position = Vector3(0, 0.06, 0)  # Slightly above ground

	# ── Hazard-specific visual ──
	_hazard_mesh = MeshInstance3D.new()
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = primary_color
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.emission_enabled = true
	_mat.emission = glow_color
	_mat.emission_energy_multiplier = 2.0
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	match hazard_type:
		HazardType.LAVA_GEYSER:
			# Tall cylinder column
			var cyl := CylinderMesh.new()
			cyl.top_radius = 1.5
			cyl.bottom_radius = 2.0
			cyl.height = GameConstants.LAVA_GEYSER_HEIGHT
			cyl.radial_segments = 16
			_hazard_mesh.mesh = cyl
			_hazard_mesh.position = Vector3(0, GameConstants.LAVA_GEYSER_HEIGHT / 2.0, 0)
		HazardType.FALLING_CRYSTAL:
			# Sharp crystal shape (cone pointing down)
			var prism := PrismMesh.new()
			prism.size = Vector3(1.5, 3.0, 1.5)
			_hazard_mesh.mesh = prism
			_hazard_mesh.position = Vector3(0, GameConstants.FALLING_CRYSTAL_HEIGHT, 0)
			# Crystal starts up high and falls during telegraph
		HazardType.VOID_SHOCKWAVE:
			# Flat expanding ring
			var ring := CylinderMesh.new()
			ring.top_radius = 0.5
			ring.bottom_radius = 0.5
			ring.height = 0.3
			ring.radial_segments = 32
			_hazard_mesh.mesh = ring
			_hazard_mesh.position = Vector3(0, 0.5, 0)
			# CylinderMesh axis is along Y; with height=0.3 it's already a flat ring
			# lying on the XZ plane. No rotation needed.

	_hazard_mesh.material_override = _mat
	_hazard_mesh.visible = false  # Hidden during telegraph (except falling crystal anim)
	add_child(_hazard_mesh)

	# For falling crystal, make it visible during telegraph (it falls)
	if hazard_type == HazardType.FALLING_CRYSTAL:
		_hazard_mesh.visible = true

	# ── Light ──
	_hazard_light = OmniLight3D.new()
	_hazard_light.light_color = glow_color
	_hazard_light.light_energy = 0.0  # Off during telegraph
	_hazard_light.omni_range = 12.0
	_hazard_light.position = Vector3(0, 2.0, 0)
	add_child(_hazard_light)

	# ── Damage Area3D ──
	_damage_area = Area3D.new()
	_damage_shape = CollisionShape3D.new()
	var shape: CollisionShape3D = _damage_shape
	match hazard_type:
		HazardType.VOID_SHOCKWAVE:
			var cyl_shape := CylinderShape3D.new()
			cyl_shape.radius = 0.5
			cyl_shape.height = 2.0
			shape.shape = cyl_shape
		_:
			var sphere := SphereShape3D.new()
			sphere.radius = damage_radius
			shape.shape = sphere
	_damage_area.add_child(_damage_shape)
	_damage_area.monitoring = false  # Activated on _activate()
	_damage_area.monitorable = false
	add_child(_damage_area)

func _spawn_activation_effect() -> void:
	var color: Color = _get_glow_color()
	match hazard_type:
		HazardType.LAVA_GEYSER:
			ParticleEffects.spawn_explosion(get_parent(), global_position, color, 40, 1.0)
			_hazard_light.light_energy = 5.0
		HazardType.FALLING_CRYSTAL:
			ParticleEffects.spawn_explosion(get_parent(), global_position, color, 35, 0.8)
			_hazard_light.light_energy = 4.0
			# Shatter effect
			ParticleEffects.spawn_shield_break(get_parent(), global_position, color)
		HazardType.VOID_SHOCKWAVE:
			ParticleEffects.spawn_explosion(get_parent(), global_position, color, 30, 0.6)
			_hazard_light.light_energy = 3.0

func _get_hazard_color() -> Color:
	match hazard_type:
		HazardType.LAVA_GEYSER:
			return GameConstants.ARENA_LAVA_COLOR
		HazardType.FALLING_CRYSTAL:
			return GameConstants.ARENA_CRYSTAL_COLOR
		HazardType.VOID_SHOCKWAVE:
			return GameConstants.ARENA_VOID_COLOR
		_:
			return Color.WHITE

func _get_glow_color() -> Color:
	match hazard_type:
		HazardType.LAVA_GEYSER:
			return GameConstants.ARENA_LAVA_GLOW
		HazardType.FALLING_CRYSTAL:
			return GameConstants.ARENA_CRYSTAL_GLOW
		HazardType.VOID_SHOCKWAVE:
			return GameConstants.ARENA_VOID_GLOW
		_:
			return Color.WHITE

## Set the hazard type before adding to scene tree.
func set_hazard_type(type: int) -> void:
	hazard_type = type