## Zorp Wiggles — Void Wisp
## Tiny, fast, semi-transparent enemy that teleports behind the player when hit.
## Low HP but elusive — 50% chance to teleport on hit, with cooldown.

extends EnemyBase

class_name EnemyWisp

# ─── Wisp State ───────────────────────────────────────────────────────────────
var teleport_cooldown: float = 0.0
var _teleport_tween: Tween = null

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
	base_color = Color(0.392, 1.0, 0.784, 0.627)
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
		teleport_cooldown -= delta * _time_scale

func take_damage_from(amount: int, source_pos: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return
	super.take_damage_from(amount, source_pos)

	# Teleport chance on hit
	if not is_dead and teleport_cooldown <= 0:
		if randf() < GameConstants.VOID_WISP_TELEPORT_CHANCE:
			_teleport_behind_player()

func _teleport_behind_player() -> void:
	# Use the cached player reference from the base class (populated by
	# super._physics_process → _update_ai) instead of a fresh group scan.
	# The Wisp calls super._physics_process every frame, so the cache is
	# always current. Falls back to a one-shot scan only if the cache is
	# stale (null or freed) — matching the pattern used across the codebase.
	var player: Node3D = _cached_player
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
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
		# Kill any active teleport tween to avoid conflicts
		if _teleport_tween and _teleport_tween.is_valid():
			_teleport_tween.kill()
		_material.albedo_color = Color(base_color.r, base_color.g, base_color.b, 0.0)
		# Departure particle burst at the old position
		ParticleEffects.spawn_explosion(get_parent(), global_position,
			base_color, 8, 0.25)
		global_position = new_pos
		_teleport_tween = create_tween()
		_teleport_tween.tween_property(_material, "albedo_color:a",
			_spawn_target_alpha, 0.3) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		# Arrival particle burst at the new position — gives the player
		# a visual cue of where the Wisp reappeared, critical for
		# combat awareness since the Wisp teleports behind the player.
		ParticleEffects.spawn_explosion(get_parent(), new_pos,
			base_color, 8, 0.25)
		# Subtle teleport SFX — the void wisp's phase shift deserves an
		# audio cue so the player hears the repositioning even if they
		# weren't looking at the Wisp when it teleported.
		AudioManager.play_sfx_volume(AudioManager.SFX_RIFT, 0.4)

	teleport_cooldown = GameConstants.VOID_WISP_TELEPORT_COOLDOWN
	is_alerted = true

func _die() -> void:
	# Suppress the base class generic death SFX — the wisp plays its own
	# dedicated SFX_WISP_DEATH (a void teleport-out pop) since the wisp
	# doesn't truly "die" but dissolves back into the void.
	_suppress_base_death_sfx = true
	AudioManager.play_sfx_pitched_volume(AudioManager.SFX_WISP_DEATH, 1.0, 0.3)
	super._die()