## Zorp Wiggles — Destructible Object (Phase 8: Physics & Interaction)
## A StaticBody3D that takes damage from projectiles/dash and shatters into
## RigidBody3D physics fragments on destruction. Used for crates, crystal chunks,
## and other breakable props placed across biomes.
##
## Architecture: StaticBody3D root (immovable until broken) + MeshInstance3D visual
## + Area3D hit zone. On shatter, spawns N RigidBody3D fragments with bounce material
## and impulse, then frees itself.

extends StaticBody3D

class_name Destructible

signal destroyed(pos: Vector3)

# ─── Config (set by spawner) ───────────────────────────────────────────────────
@export var prop_name: String = "Crate"
@export var hp: int = GameConstants.DESTRUCTIBLE_HP
@export var fragment_color: Color = GameConstants.DESTRUCTIBLE_CRATE_COLOR
@export var reward_score: int = GameConstants.DESTRUCTIBLE_REWARD_SCORE
@export var reward_xp: int = GameConstants.DESTRUCTIBLE_REWARD_XP
@export var shatter_count: int = GameConstants.DESTRUCTIBLE_SHATTER_COUNT
@export var is_crystal: bool = false  # Crystal = purple, gives slightly more XP

# ─── Node refs ────────────────────────────────────────────────────────────────
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var hit_area: Area3D = $HitArea

var _is_broken: bool = false
var _hit_flash_timer: float = 0.0
var _mat: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("destructibles")
	if hit_area:
		hit_area.body_entered.connect(_on_body_entered)
		hit_area.area_entered.connect(_on_area_entered)
	# Setup material with flash capability
	if mesh_instance:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = fragment_color
		_mat.roughness = 0.5
		_mat.emission_enabled = true
		_mat.emission = fragment_color * 0.15
		mesh_instance.material_override = _mat

# ─── Damage ───────────────────────────────────────────────────────────────────
func take_damage_from(amount: int, _source_pos: Vector3 = Vector3.ZERO) -> void:
	if _is_broken:
		return
	hp -= amount
	_hit_flash_timer = 0.12
	if _mat:
		_mat.albedo_color = Color.WHITE
		var flash_tween := create_tween()
		flash_tween.tween_property(_mat, "albedo_color", fragment_color, 0.12)
	if hp <= 0:
		_shatter()

func take_damage(amount: int) -> void:
	take_damage_from(amount)

# ─── Collision entry (projectiles are Area3D, enemies/player are bodies) ───────
func _on_body_entered(body: Node3D) -> void:
	if _is_broken:
		return
	# Player dashing into a destructible smashes it instantly
	if body.is_in_group("player"):
		var player_script = body
		if player_script.get("is_dashing") == true:
			_shatter()
			return

func _on_area_entered(area: Area3D) -> void:
	if _is_broken:
		return
	# Projectiles are Area3D — they call take_damage_from directly, but if they
	# don't (e.g. generic area), apply a small hit
	if area.is_in_group("player_projectiles") or area.is_in_group("projectiles"):
		take_damage_from(GameConstants.PROJECTILE_BASE_DAMAGE, area.global_position)

# ─── Shatter into physics fragments ───────────────────────────────────────────
func _shatter() -> void:
	if _is_broken:
		return
	_is_broken = true
	destroyed.emit(global_position)

	# Reward the player
	GameManager.add_score(reward_score)
	GameManager.gain_xp(reward_xp)

	# Particle burst
	ParticleEffects.spawn_explosion(get_parent(), global_position, fragment_color, 25, 0.6)

	# Spawn RigidBody3D fragments
	for i in range(shatter_count):
		_spawn_fragment(i)

	# Camera shake
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.15)

	# Hide self and free after a tiny delay (so signal completes)
	mesh_instance.visible = false
	queue_free()

func _spawn_fragment(index: int) -> void:
	var frag := RigidBody3D.new()
	frag.mass = 0.2
	frag.gravity_scale = 1.0
	frag.linear_damp = 0.5
	frag.angular_damp = 0.5

	# Collision shape — small box
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 0.2, 0.2)
	col.shape = shape
	frag.add_child(col)

	# Visual — random small box or shard
	var mesh_inst := MeshInstance3D.new()
	var frag_mesh := BoxMesh.new()
	frag_mesh.size = Vector3(0.18, 0.18, 0.18)
	mesh_inst.mesh = frag_mesh
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = fragment_color
	fmat.roughness = 0.4
	fmat.emission_enabled = true
	fmat.emission = fragment_color * 0.2
	mesh_inst.material_override = fmat
	frag.add_child(mesh_inst)

	# Physics material with bounce
	var phys_mat := PhysicsMaterial.new()
	phys_mat.bounce = 0.4
	phys_mat.friction = 0.6
	frag.physics_material_override = phys_mat

	get_parent().add_child(frag)
	frag.global_position = global_position + Vector3(
		randf_range(-0.4, 0.4),
		randf_range(0.2, 0.8),
		randf_range(-0.4, 0.4)
	)

	# Random outward impulse + upward pop
	var impulse_dir := Vector3(
		randf_range(-1, 1),
		randf_range(0.5, 1.5),
		randf_range(-1, 1)
	).normalized()
	frag.apply_central_impulse(impulse_dir * GameConstants.DESTRUCTIBLE_SHATTER_IMPULSE)
	frag.apply_torque_impulse(Vector3(
		randf_range(-3, 3),
		randf_range(-3, 3),
		randf_range(-3, 3)
	))

	# Auto-free fragment after lifetime
	var timer := get_tree().create_timer(GameConstants.DESTRUCTIBLE_SHATTER_LIFETIME)
	timer.timeout.connect(frag.queue_free)