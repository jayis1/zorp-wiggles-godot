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
# Track the active hit-flash tween so repeated hits don't spawn overlapping
# tweens that fight over albedo_color. Each new hit kills the previous tween
# and starts a fresh one — this prevents the "stuck on white" bug where a
# second hit lands mid-flash and the old tween's setter fights the new one.
var _flash_tween: Tween = null
# Brief hit-stop on shatter so breaking a crate feels weighty rather than
# instantaneous. The freeze is short (50ms) so it punctuates without
# disrupting flow. Mirrors the projectile hit-stop technique.
const SHATTER_HITSTOP_DURATION: float = 0.05
const SHATTER_HITSTOP_TIME_SCALE: float = 0.1

func _ready() -> void:
	add_to_group("destructibles")
	if hit_area:
		hit_area.body_entered.connect(_on_body_entered)
		# Note: area_entered is NOT connected here. Player projectiles are Area3D
		# nodes that already call take_damage_from() directly via their own
		# body_entered handler when they hit the destructible's StaticBody3D.
		# Connecting area_entered would cause double-damage (once from the
		# projectile's body_entered, once from the HitArea's area_entered).
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
		# Kill any active flash tween so the new flash starts from white
		# cleanly instead of fighting a previous tween's setter.
		if _flash_tween and _flash_tween.is_valid():
			_flash_tween.kill()
		_mat.albedo_color = Color.WHITE
		_flash_tween = create_tween()
		# Ease-out cubic so the color returns quickly at first then settles
		# — reads as a sharp snap-back rather than a slow bleed.
		_flash_tween.tween_property(_mat, "albedo_color", fragment_color, 0.12) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_QUAD)
	if hp <= 0:
		_shatter()

func take_damage(amount: int) -> void:
	take_damage_from(amount)

# ─── Collision entry (player dashing into destructible smashes it) ─────────
func _on_body_entered(body: Node3D) -> void:
	if _is_broken:
		return
	# Player dashing into a destructible smashes it instantly
	if body.is_in_group("player"):
		var player_script = body
		if player_script.get("is_dashing") == true:
			_shatter()
			return

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

	# ── Shatter light flash — a brief real-time light pop so the break
	# reads in dark biomes even without looking directly at the crate.
	# Matches the impact_burst light technique. Color is warm-tinted toward
	# white so it reads as a "break" rather than a colored magic effect.
	# POOLING: Uses the PerformanceOptimizer transient light pool.
	var shatter_color: Color = fragment_color.lerp(Color(1.0, 1.0, 0.9), 0.5)
	if PerformanceOptimizer:
		var shatter_light := PerformanceOptimizer.acquire_transient_light(
			global_position + Vector3(0, 0.5, 0),
			shatter_color,
			3.0,
			0.25,
			5.0,
			1.2
		)
		if shatter_light:
			var light_tween := shatter_light.create_tween()
			light_tween.tween_property(shatter_light, "light_energy", 0.0, 0.18) \
				.set_ease(Tween.EASE_OUT) \
				.set_trans(Tween.TRANS_QUAD)
	else:
		var shatter_light := OmniLight3D.new()
		shatter_light.light_color = shatter_color
		shatter_light.light_energy = 3.0
		shatter_light.omni_range = 5.0
		shatter_light.omni_attenuation = 1.2
		get_parent().add_child(shatter_light)
		shatter_light.global_position = global_position + Vector3(0, 0.5, 0)
		# Bind the tween to the light node, NOT to self — self is queue_free'd
		# at the end of _shatter(), so a self-bound tween would be killed
		# immediately, leaving the light stuck at full intensity (leak + visual bug).
		var light_tween := shatter_light.create_tween()
		light_tween.tween_property(shatter_light, "light_energy", 0.0, 0.18) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_QUAD)
		light_tween.chain().tween_callback(shatter_light.queue_free)

	# Spawn RigidBody3D fragments
	for i in range(shatter_count):
		_spawn_fragment(i)

	# Camera shake
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.15)

	# ── Hit-stop: brief global time-scale dip so the shatter lands with
	# weight. Uses the same Engine.time_scale technique as projectile
	# hit-stop. A scene-tree Timer restores the scale so the freeze is
	# independent of this node's lifetime (we queue_free below).
	Engine.time_scale = SHATTER_HITSTOP_TIME_SCALE
	# IMPORTANT: ignore_time_scale=true (4th arg) so the restore fires in
	# real-time seconds. Without it, the timer respects Engine.time_scale
	# (0.1 here), making the 0.05s freeze actually last ~0.5s — 10x too long
	# and a noticeable stutter instead of a snappy hit-stop beat. This
	# matches the pattern used by projectile.gd, player.gd, and co_op_manager.gd.
	# CRITICAL: Use a lambda (not self._restore_time_scale) because self is
	# queue_free'd below. A method reference on self would be disconnected when
	# the node is freed, leaving Engine.time_scale stuck at 0.1 forever.
	var restore_timer := get_tree().create_timer(SHATTER_HITSTOP_DURATION, true, false, true)
	restore_timer.timeout.connect(func(): Engine.time_scale = 1.0)

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

	# ── Scale-in pop: fragments start tiny and overshoot to full size
	# with an ease-out back curve. This makes the shatter feel explosive
	# — the shards "burst" outward rather than appearing at full size.
	# Combined with the impulse, this reads as a real break rather than
	# a spawn. The tween targets mesh_inst.scale (not frag.scale) so it
	# doesn't conflict with any physics-driven scale changes.
	mesh_inst.scale = Vector3.ONE * 0.1
	# Bind the tween to the fragment node, NOT to self — self is queue_free'd
	# at the end of _shatter(), so a self-bound tween would be killed immediately,
	# leaving fragments stuck at scale 0.1 (invisible shatter debris).
	var pop_tween := frag.create_tween()
	# TRANS_BACK gives a ~10% overshoot for a punchy "snap" exit
	pop_tween.tween_property(mesh_inst, "scale", Vector3.ONE, 0.18) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)