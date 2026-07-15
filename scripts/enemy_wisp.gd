## Zorp Wiggles — Void Wisp
## Tiny, fast, semi-transparent enemy that teleports behind the player when hit.
## Low HP but elusive — 50% chance to teleport on hit, with cooldown.

extends EnemyBase

class_name EnemyWisp

# ─── Wisp State ───────────────────────────────────────────────────────────────
var teleport_cooldown: float = 0.0

func _ready() -> void:
	enemy_name = "Void Wisp"
	enemy_type = GameConstants.EnemyType.WISP
	max_hp = 18
	speed = 8.0
	damage = 5
	base_scale = 0.4
	detect_range = 26.0
	xp_reward = 10
	score_reward = 40
	base_color = Color(100.0 / 255.0, 1.0, 200.0 / 255.0, 160.0 / 255.0)
	super._ready()

	# Semi-transparent material
	if _material:
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.emission = base_color * 0.3
		# _spawn_target_alpha was already set from base_color.a in super._ready()
		# Just restore the correct albedo color (alpha will be driven by spawn fade)
		_material.albedo_color = Color(base_color.r, base_color.g, base_color.b, 0.0)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_dead or GameManager.is_paused or spawn_grace_timer > 0:
		return

	if teleport_cooldown > 0:
		teleport_cooldown -= delta

func take_damage(amount: int) -> void:
	if is_dead:
		return
	super.take_damage(amount)

	# Teleport chance on hit
	if not is_dead and teleport_cooldown <= 0:
		if randf() < GameConstants.VOID_WISP_TELEPORT_CHANCE:
			_teleport_behind_player()

func _teleport_behind_player() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Determine player's facing direction from the camera, since the player
	# CharacterBody3D itself never rotates (camera-relative movement).
	var camera_3d: Camera3D = get_viewport().get_camera_3d()
	var facing_dir: Vector3
	if camera_3d:
		facing_dir = -camera_3d.global_basis.z
	else:
		facing_dir = -player.global_basis.z
	facing_dir.y = 0
	facing_dir = facing_dir.normalized()

	# Teleport behind the player (opposite of facing direction)
	var behind_dir: Vector3 = -facing_dir
	var tp_dist: float = randf_range(
		GameConstants.VOID_WISP_TELEPORT_RANGE * 0.5,
		GameConstants.VOID_WISP_TELEPORT_RANGE
	)
	var new_pos: Vector3 = player.global_position + behind_dir * tp_dist
	new_pos.y = global_position.y

	# Teleport visual — quick fade out and in
	if _material:
		_material.albedo_color.a = 0.0
		global_position = new_pos
		var fade_tween := create_tween()
		fade_tween.tween_property(_material, "albedo_color:a",
			160.0 / 255.0, 0.3)

	teleport_cooldown = GameConstants.VOID_WISP_TELEPORT_COOLDOWN
	is_alerted = true