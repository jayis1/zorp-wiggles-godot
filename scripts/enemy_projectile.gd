## Zorp Wiggles — Enemy Projectile
## Projectile fired by Spore Spitter and Plasma Drake.
## Travels in a straight line, damages player on hit, has lifetime.
## Polished: shared resources, point light glow, velocity-aligned stretch,
## cached player reference, impact burst on hit, energy flicker.

extends Area3D

class_name EnemyProjectile

@export var speed: float = 20.0
@export var damage: int = 12
@export var lifetime: float = 3.0
@export var projectile_color: Color = Color(1.0, 120.0 / 255.0, 20.0 / 255.0)

var direction: Vector3 = Vector3.FORWARD
var age: float = 0.0
var _material: StandardMaterial3D = null
var _time_scale: float = 1.0  # Phase 14: Time-Slow dimension
var _light: OmniLight3D = null
var _cached_player: Node3D = null
# Guard against double-hit: the distance check in _physics_process and the
# body_entered Area3D signal can both fire on the same frame. Without this
# flag, _on_hit_player would run twice (queue_free is deferred), dealing
# double damage to the player from a single enemy projectile.
var _has_already_hit: bool = false

@onready var mesh: MeshInstance3D = $MeshInstance3D

# ─── Shared Resources ──────────────────────────────────────────────────────────
# Enemy projectiles are fired frequently by Spore Spitters and Drakes.
# Sharing the mesh eliminates per-shot geometry allocation. The material is
# per-instance so each projectile can pulse its emission independently.
static var _shared_mesh: SphereMesh = null

static func _ensure_shared_resources() -> void:
	if _shared_mesh == null:
		_shared_mesh = SphereMesh.new()
		_shared_mesh.radius = 0.2
		_shared_mesh.height = 0.4
		_shared_mesh.radial_segments = 8
		_shared_mesh.rings = 4

const IMPACT_SCENE := preload("res://scenes/entities/impact_burst.tscn")

func _ready() -> void:
	# Connect collision signal
	body_entered.connect(_on_body_entered)

	_ensure_shared_resources()

	# Set up material — per-instance so emission can pulse independently
	if mesh:
		mesh.mesh = _shared_mesh
		_material = StandardMaterial3D.new()
		_material.albedo_color = projectile_color
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.emission_enabled = true
		_material.emission = projectile_color * 0.6
		_material.emission_energy_multiplier = 1.2
		# Rim lighting for silhouette pop against dark terrain
		_material.rim_enabled = true
		_material.rim = 0.7
		_material.rim_tint = 0.9
		mesh.material_override = _material

	# Point light for real-time glow — makes the projectile visible and
	# threatening in dark biomes, casting light on nearby terrain.
	_light = OmniLight3D.new()
	_light.light_color = projectile_color
	_light.light_energy = 1.2
	_light.omni_range = 4.0
	_light.omni_attenuation = 1.5
	add_child(_light)

	# Add to group for tracking
	add_to_group("enemy_projectiles")

func _physics_process(delta: float) -> void:
	# ── Phase 14: Apply dimension time scale ──
	delta *= _time_scale
	age += delta
	if age >= lifetime:
		_fizzle_out()
		return

	# Move projectile
	global_position += direction * speed * delta

	# Orient and stretch the bolt toward its travel direction — gives a
	# fast energy-bolt silhouette instead of a static drifting sphere.
	# Same technique as player projectiles for visual consistency.
	if mesh and direction.length_squared() > 0.01:
		var up_vec := Vector3.UP
		if absf(direction.dot(Vector3.UP)) > 0.98:
			up_vec = Vector3.FORWARD
		mesh.look_at(global_position + direction * 2.0, up_vec)
		mesh.scale = Vector3(0.7, 0.7, 2.2)

	# Energy flicker — the point light pulses so the bolt feels like crackling
	# energy. Uses wall-clock time so flicker is consistent regardless of
	# time-scale (Time-Slow dimension won't slow the visual crackle).
	if _light:
		_light.light_energy = 1.0 + 0.4 * sin(Time.get_ticks_msec() * 0.025)

	# Aura pulse on emission
	if _material:
		var pulse: float = 0.8 + 0.4 * sin(age * GameConstants.ENEMY_PROJECTILE_AURA_PULSE_SPEED)
		_material.emission_energy_multiplier = pulse

	# Check distance to player (cached reference, refreshed if stale)
	# In co-op, check both P1 and P2 so the projectile hits whoever is closest
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	if _cached_player and GameManager.player_is_alive:
		var dist: float = global_position.distance_to(_cached_player.global_position)
		if dist < GameConstants.ENEMY_PROJECTILE_HIT_RADIUS:
			_on_hit_player(_cached_player)
			return  # _on_hit_player freed this projectile; stop processing
	# ── Phase 19: Co-op — also check P2 if active ──
	# Only check P2 if we didn't already hit P1 (above returns on hit, so
	# reaching here means P1 was not in range). Without the early return above,
	# a single projectile could damage BOTH players in co-op if they were
	# both within ENEMY_PROJECTILE_HIT_RADIUS of the bolt on the same frame
	# — _on_hit_player calls queue_free() (deferred to end of frame), so the
	# second check would still run and damage P2 after P1 was already hit.
	if CoOpManager.is_coop_active() and not CoOpManager.p2_is_downed:
		if CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
			var p2_dist: float = global_position.distance_to(CoOpManager.p2_node.global_position)
			if p2_dist < GameConstants.ENEMY_PROJECTILE_HIT_RADIUS:
				_on_hit_player(CoOpManager.p2_node)
				return  # _on_hit_player freed this projectile

# ── Phase 14: Set time scale (called by DimensionSystem) ──
func set_time_scale(scale: float) -> void:
	_time_scale = scale

func _on_body_entered(body: Node3D) -> void:
	if _has_already_hit:
		return  # Already hit a player this frame; don't double-damage
	if body.is_in_group("player"):
		_on_hit_player(body)
	elif not body.is_in_group("enemies"):
		# Hit terrain/wall — small impact flash, no damage
		_spawn_impact(projectile_color)
		queue_free()

## Hit a player — route damage to the correct player in co-op.
## `target` is the CharacterBody3D that was hit (P1 or P2).
## Sets a guard flag so the distance-check in _physics_process and the
## body_entered signal can't both fire _on_hit_player on the same frame
## (which would double-damage the player — queue_free is deferred so the
## second call would still execute before the node is actually freed).
func _on_hit_player(target: Node3D = null) -> void:
	if _has_already_hit:
		return  # Prevent double-hit from distance check + body_entered
	_has_already_hit = true
	# Default to P1 if no target specified (backward compatibility)
	if target and target.is_in_group("player2"):
		CoOpManager.p2_take_damage(damage, global_position)
	else:
		GameManager.take_damage(damage, global_position)
	_spawn_impact(projectile_color)
	queue_free()

## Spawn an impact burst effect at the projectile's position.
## Uses the shared impact_burst scene, retinted to the projectile's color.
func _spawn_impact(col: Color) -> void:
	if IMPACT_SCENE:
		var burst: Node3D = IMPACT_SCENE.instantiate()
		# Set the impact color BEFORE adding to the tree so _ready() picks
		# it up and retints the material + light to match this projectile.
		burst.set("impact_color", col)
		get_parent().add_child(burst)
		burst.global_position = global_position

## Fizzle out when lifetime expires — small particle puff + fade, not a
## hard queue_free. Gives the player a visual cue that the threat ended.
func _fizzle_out() -> void:
	# Quick fade on the light + mesh before freeing
	if _light:
		var fade_tween := create_tween()
		fade_tween.tween_property(_light, "light_energy", 0.0, 0.15) \
			.set_ease(Tween.EASE_OUT)
	if _material:
		_material.albedo_color.a = 0.0
	# Small fizzle particle puff
	ParticleEffects.spawn_explosion(get_parent(), global_position, projectile_color, 6, 0.15)
	# Free after a tiny delay so the fade is visible
	get_tree().create_timer(0.05).timeout.connect(queue_free)