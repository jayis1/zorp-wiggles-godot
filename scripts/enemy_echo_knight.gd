## Zorp Wiggles — Echo Knight (Phase 23: New Enemy Type)
## Creates 2 shadow copies of itself at fixed offsets. All three entities share
## the same movement and attack in sync — when the real knight attacks, all
## copies attack simultaneously in the same pattern. Copies are intangible
## (can't be damaged) and fade when the real knight dies. The player must
## identify the real knight (slightly brighter / has a subtle aura) and focus
## it down; the copies are a constant threat that can't be removed any other way.
##
## Architecture:
##   - The real knight is a CharacterBody3D in the "enemies" group (takes damage).
##   - Each copy is a MeshInstance3D child of the real knight, NOT a separate
##     CharacterBody3D. This keeps them lightweight (no physics, no AI) and
##     guarantees they move in perfect sync with the real knight.
##   - When the real knight attacks (lunge), each copy also "lunges" visually
##     (a quick position offset tween in the same direction).
##   - Copies deal damage via a short-lived Area3D overlap check when the real
##     knight attacks, scaled by ECHO_KNIGHT_COPY_DAMAGE_MULT.
##   - The real knight is visually distinct: brighter color + a subtle pulsing
##     aura light. Copies are translucent (alpha 0.45) and slightly darker.

extends EnemyBase

class_name EnemyEchoKnight

# ─── Copy State ───────────────────────────────────────────────────────────────
var _copies: Array[MeshInstance3D] = []
var _copy_lights: Array[OmniLight3D] = []
var _copy_offsets: Array[Vector3] = []  # Relative offset from the real knight
var _real_aura_light: OmniLight3D = null

func _ready() -> void:
	enemy_name = "Echo Knight"
	enemy_type = GameConstants.EnemyType.ECHO_KNIGHT
	max_hp = GameConstants.ECHO_KNIGHT_HP
	speed = GameConstants.ECHO_KNIGHT_SPEED
	damage = GameConstants.ECHO_KNIGHT_DAMAGE
	base_scale = GameConstants.ECHO_KNIGHT_SCALE
	detect_range = GameConstants.ECHO_KNIGHT_DETECT_RANGE
	attack_range = GameConstants.ECHO_KNIGHT_ATTACK_RANGE
	attack_cooldown = GameConstants.ECHO_KNIGHT_ATTACK_COOLDOWN
	xp_reward = GameConstants.ECHO_KNIGHT_XP
	score_reward = GameConstants.ECHO_KNIGHT_SCORE
	# The real knight uses the brighter "real" color so the player can identify it
	base_color = GameConstants.ECHO_KNIGHT_REAL_COLOR
	# Smart AI enabled — flanking makes the copies spread out, harder to tell
	# which is the real one. Retreat is fine (the knight backing off pulls
	# copies with it, creating pressure waves).
	use_smart_ai = true
	super._ready()

	# Real knight: bright material with strong emission + rim for a "real" look
	if _material:
		_material.emission = base_color * 0.3
		_material.emission_energy_multiplier = 1.4
		_material.rim = 1.0
		_material.rim_tint = 0.9

	# Subtle pulsing aura light on the real knight — the visual cue that
	# distinguishes it from the copies. The player learns "the glowing one
	# is the real one".
	_real_aura_light = OmniLight3D.new()
	_real_aura_light.light_color = Color(0.7, 0.7, 1.0)
	_real_aura_light.light_energy = 1.2
	_real_aura_light.omni_range = 3.0
	_real_aura_light.omni_attenuation = 1.5
	add_child(_real_aura_light)
	_real_aura_light.position = Vector3(0, 0.8, 0)

	# Create the shadow copies as MeshInstance3D children of this knight.
	# They are NOT in the "enemies" group and have no collision — they're
	# purely visual + deal damage when the real knight attacks.
	_create_copies()

func _create_copies() -> void:
	# Generate offset positions for each copy. We spread them around the knight
	# at fixed angles so they don't overlap with each other or the real knight.
	for i in range(GameConstants.ECHO_KNIGHT_COPY_COUNT):
		var angle: float = (float(i) / float(GameConstants.ECHO_KNIGHT_COPY_COUNT)) * TAU + PI / 2.0
		var offset: Vector3 = Vector3(
			cos(angle) * GameConstants.ECHO_KNIGHT_COPY_OFFSET,
			0,
			sin(angle) * GameConstants.ECHO_KNIGHT_COPY_OFFSET
		)
		_copy_offsets.append(offset)

		# Create the copy mesh — a translucent, darker version of the knight
		var copy_mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.55 * base_scale
		sphere.height = 1.1 * base_scale
		sphere.radial_segments = 12
		sphere.rings = 6
		copy_mesh.mesh = sphere
		var copy_mat := StandardMaterial3D.new()
		copy_mat.albedo_color = Color(
			GameConstants.ECHO_KNIGHT_COLOR.r,
			GameConstants.ECHO_KNIGHT_COLOR.g,
			GameConstants.ECHO_KNIGHT_COLOR.b,
			GameConstants.ECHO_KNIGHT_COPY_ALPHA
		)
		copy_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		copy_mat.emission_enabled = true
		copy_mat.emission = GameConstants.ECHO_KNIGHT_COLOR * 0.2
		copy_mat.emission_energy_multiplier = 0.6
		copy_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		copy_mat.no_depth_test = true  # Copies render on top so they're always visible
		copy_mesh.material_override = copy_mat
		add_child(copy_mesh)
		copy_mesh.position = offset + Vector3(0, 0.5, 0)
		_copies.append(copy_mesh)

		# Soft dim light on each copy for a ghostly glow
		var copy_light := OmniLight3D.new()
		copy_light.light_color = Color(0.4, 0.4, 0.6)
		copy_light.light_energy = 0.4
		copy_light.omni_range = 2.0
		copy_light.omni_attenuation = 1.5
		add_child(copy_light)
		copy_light.position = offset + Vector3(0, 0.8, 0)
		_copy_lights.append(copy_light)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_dead or GameManager.is_paused or spawn_grace_timer > 0:
		return
	# Pulse the real knight's aura light so it's visually distinct
	if _real_aura_light:
		_real_aura_light.light_energy = 1.0 + 0.4 * sin(Time.get_ticks_msec() * 0.004)
	# Pulse the copies' emission subtly — they "shimmer" to feel less solid
	for cm in _copies:
		if is_instance_valid(cm):
			var mat: StandardMaterial3D = cm.material_override as StandardMaterial3D
			if mat:
				mat.emission_energy_multiplier = 0.4 + 0.3 * sin(Time.get_ticks_msec() * 0.003)

## Override the attack execution to also deal damage from each copy's position.
## The real knight's lunge + damage is handled by the base class; we add the
## copy damage on top. Copies deal reduced damage (ECHO_KNIGHT_COPY_DAMAGE_MULT).
func _execute_attack(player: Node3D) -> void:
	# Let the base class handle the real knight's attack (damage + lunge + visuals)
	super._execute_attack(player)

	# Now deal damage from each copy's position. A copy "hits" if the player is
	# within attack_range of the copy's current world position. We use the same
	# attack_range as the real knight for simplicity.
	if not player or not is_instance_valid(player):
		return
	var copy_damage: int = int(damage * GameConstants.ECHO_KNIGHT_COPY_DAMAGE_MULT)
	for offset in _copy_offsets:
		var copy_world_pos: Vector3 = global_position + offset
		var dist: float = copy_world_pos.distance_to(player.global_position)
		if dist < attack_range + 0.5:  # Small tolerance for the sync hit
			# Route to the correct player in co-op
			if player.is_in_group("player2"):
				CoOpManager.p2_take_damage(copy_damage, copy_world_pos)
			else:
				GameManager.take_damage(copy_damage, copy_world_pos)
			# Visual: small particle burst at the copy's position to telegraph
			# that the copy also "hit" the player
			ParticleEffects.spawn_explosion(get_parent(), copy_world_pos,
				GameConstants.ECHO_KNIGHT_COLOR, 8, 0.25)
			# Only one copy can hit per attack cycle (they're in sync, so the
			# closest one to the player lands the hit). This prevents all copies
			# from stacking damage on a single attack.
			break

	# Lunge each copy visually in the same direction as the real knight's lunge
	# (a quick position offset tween). The copies don't move the real knight,
	# they just animate their local position outward and back.
	var lunge_dir: Vector3 = (player.global_position - global_position).normalized()
	lunge_dir.y = 0
	for i in range(_copies.size()):
		var cm: MeshInstance3D = _copies[i]
		if not is_instance_valid(cm):
			continue
		var base_offset: Vector3 = _copy_offsets[i] + Vector3(0, 0.5, 0)
		var lunge_offset: Vector3 = base_offset + lunge_dir * 0.6
		var lunge_tween := cm.create_tween()
		lunge_tween.tween_property(cm, "position", lunge_offset, 0.08) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		lunge_tween.tween_property(cm, "position", base_offset, 0.18) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

func _die() -> void:
	# Fade out all copies when the real knight dies
	for cm in _copies:
		if is_instance_valid(cm):
			var mat: StandardMaterial3D = cm.material_override as StandardMaterial3D
			if mat:
				var fade_tween := cm.create_tween()
				fade_tween.tween_property(mat, "albedo_color:a", 0.0, 0.4) \
					.set_ease(Tween.EASE_IN)
				fade_tween.tween_callback(cm.queue_free)
			else:
				cm.queue_free()
	_copies.clear()
	# Fade out copy lights
	for cl in _copy_lights:
		if is_instance_valid(cl):
			var fade_tween := cl.create_tween()
			fade_tween.tween_property(cl, "light_energy", 0.0, 0.3) \
				.set_ease(Tween.EASE_IN)
			fade_tween.tween_callback(cl.queue_free)
	_copy_lights.clear()
	# Extra shadowy particle burst on death
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		GameConstants.ECHO_KNIGHT_COLOR, 20, 0.5)
	super._die()