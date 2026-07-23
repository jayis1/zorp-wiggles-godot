## Zorp Wiggles — Void Leviathan (Phase 23: Boss)
## A giant serpentine boss that "swims" through terrain. Multi-stage fight:
##   Stage 1 (>66% HP): slow chase + void breath (cone of dark projectiles)
##   Stage 2 (33-66% HP): faster, summons Void Wisps, tail sweep attack
##   Stage 3 (<33% HP): enraged — very fast, vacuum pull, rapid void breath volleys
##
## The leviathan has a segmented body (like the Plasma Serpent but much larger).
## Body segments damage the player on contact (tail swipe). On death the body
## collapses segment-by-segment with cascading particle bursts.
##
## Architecture:
##   - The head is a CharacterBody3D in the "enemies" group (takes damage).
##   - Body segments are MeshInstance3D children that follow the head's trail
##     (no physics, no collision — purely visual + a contact-damage Area3D).
##   - Stage transitions are driven by HP thresholds; each stage adds new
##     attack patterns on top of the previous ones.
##   - The vacuum pull (stage 3) applies a continuous force toward the head
##     when the player is within VACUUM_RADIUS, creating a "sucked into the
##     maw" effect. The player must dash out of the radius to escape.

extends EnemyBase

class_name EnemyVoidLeviathan

# ─── Stage State ──────────────────────────────────────────────────────────────
enum Stage { STAGE_1, STAGE_2, STAGE_3 }
var _current_stage: int = Stage.STAGE_1
var _is_enraged: bool = false

# ─── Segmented Body ───────────────────────────────────────────────────────────
var _segment_nodes: Array[MeshInstance3D] = []
var _segment_positions: Array[Vector3] = []
var _segment_colliders: Array[Area3D] = []  # Contact-damage areas per segment
var _segment_lights: Array[OmniLight3D] = []

# ─── Attack Timers ────────────────────────────────────────────────────────────
var _breath_timer: float = 3.0
var _summon_timer: float = 5.0
var _vacuum_timer: float = 6.0
var _is_vacuuming: bool = false
var _vacuum_duration_left: float = 0.0

# Reuse the enemy projectile scene for void breath bolts
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/entities/enemy_projectile.tscn")
# Reuse the Void Wisp scene for summons
const WISP_SCENE_PATH := "res://scenes/entities/enemy_wisp.tscn"

func _ready() -> void:
	enemy_name = "Void Leviathan"
	enemy_type = GameConstants.EnemyType.VOID_LEVIATHAN
	max_hp = GameConstants.VOID_LEVIATHAN_HP
	speed = GameConstants.VOID_LEVIATHAN_SPEED
	damage = GameConstants.VOID_LEVIATHAN_DAMAGE
	base_scale = GameConstants.VOID_LEVIATHAN_SCALE
	detect_range = GameConstants.VOID_LEVIATHAN_DETECT_RANGE
	attack_range = GameConstants.VOID_LEVIATHAN_ATTACK_RANGE
	attack_cooldown = GameConstants.VOID_LEVIATHAN_ATTACK_COOLDOWN
	xp_reward = GameConstants.VOID_LEVIATHAN_XP
	score_reward = GameConstants.VOID_LEVIATHAN_SCORE
	base_color = GameConstants.VOID_LEVIATHAN_COLOR
	# Boss has its own AI — disable flanking/retreat/ambush but keep enrage.
	use_smart_ai = true
	super._ready()
	if ai_controller:
		ai_controller.enable_flanking = false
		ai_controller.enable_retreat = false
		ai_controller.enable_ambush = false

	# Strong emissive material — deep void purple with a glowing maw
	if _material:
		_material.emission = base_color * 0.5
		_material.emission_energy_multiplier = 1.8
		_material.rim = 1.0
		_material.rim_tint = 1.0
		_material.metallic = 0.4
		_material.roughness = 0.3

	# Initialize segment trail history
	for i in range(GameConstants.VOID_LEVIATHAN_SEGMENTS + 1):
		_segment_positions.append(global_position)
	# Build the segmented body
	_create_body_segments()

	# Boss HP bar on HUD
	GameManager.boss_spawned.emit(self)

## Create the segmented body behind the head. Each segment is a large
## MeshInstance3D (decreasing in size toward the tail) with a contact-damage
## Area3D so the body damages the player on touch (tail swipe).
func _create_body_segments() -> void:
	for i in range(GameConstants.VOID_LEVIATHAN_SEGMENTS):
		var seg_scale: float = max(0.6, base_scale * 0.85 - i * 0.18)
		var seg_mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = seg_scale * 0.6
		sphere.height = seg_scale * 1.2
		sphere.radial_segments = 14
		sphere.rings = 7
		seg_mesh.mesh = sphere
		var seg_mat := StandardMaterial3D.new()
		# Gradient from head color to slightly darker tail
		var t: float = float(i) / float(GameConstants.VOID_LEVIATHAN_SEGMENTS)
		var seg_color: Color = base_color.lerp(Color(0.05, 0.0, 0.2), t * 0.6)
		seg_mat.albedo_color = seg_color
		seg_mat.emission_enabled = true
		seg_mat.emission = seg_color * 0.4
		seg_mat.emission_energy_multiplier = 1.2
		seg_mat.rim_enabled = true
		seg_mat.rim = 0.8
		seg_mat.rim_tint = 1.0
		seg_mat.metallic = 0.4
		seg_mat.roughness = 0.3
		seg_mesh.material_override = seg_mat
		add_child(seg_mesh)
		seg_mesh.global_position = global_position
		_segment_nodes.append(seg_mesh)

		# Soft void glow per segment
		var seg_light := OmniLight3D.new()
		seg_light.light_color = Color(0.4, 0.1, 0.7)
		seg_light.light_energy = 0.6
		seg_light.omni_range = 3.0
		seg_light.omni_attenuation = 1.8
		add_child(seg_light)
		seg_light.position = Vector3(0, 0.5, 0)
		_segment_lights.append(seg_light)

		# Contact-damage Area3D — tail swipe damage on touch
		var collider := Area3D.new()
		var col_shape := CollisionShape3D.new()
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = seg_scale * 0.7
		col_shape.shape = sphere_shape
		collider.add_child(col_shape)
		add_child(collider)
		collider.global_position = global_position
		# Use a per-segment callable to avoid the lambda capturing a loop variable
		# incorrectly — we bind the segment index.
		collider.body_entered.connect(_on_segment_body_entered.bind(i))
		_segment_colliders.append(collider)

## Per-segment contact damage — the body "tail swipes" the player on touch.
## Damage is only applied once per second per segment (cooldown via meta).
func _on_segment_body_entered(body: Node, _seg_index: int) -> void:
	if is_dead or GameManager.is_paused:
		return
	if not (body.is_in_group("player") or body.is_in_group("player2")):
		return
	# Cooldown per segment — use a meta tag on the collider
	var collider: Area3D = null
	if _seg_index < _segment_colliders.size():
		collider = _segment_colliders[_seg_index]
	if not collider or not is_instance_valid(collider):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var last: float = float(collider.get_meta("last_tail_damage", 0.0))
	if now - last < 1.0:  # 1s cooldown per segment
		return
	collider.set_meta("last_tail_damage", now)
	var sweep_dmg: int = GameConstants.VOID_LEVIATHAN_TAIL_SWEEP_DAMAGE
	if body.is_in_group("player2"):
		CoOpManager.p2_take_damage(sweep_dmg, collider.global_position)
	else:
		GameManager.take_damage(sweep_dmg, collider.global_position)
	# Small particle burst on the segment that hit
	ParticleEffects.spawn_explosion(get_parent(), collider.global_position,
		GameConstants.VOID_LEVIATHAN_COLOR, 10, 0.3)

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_paused:
		return
	# Apply dimension time scale for boss-specific timers
	var scaled_delta: float = delta * _time_scale

	# Spawn grace period
	if spawn_grace_timer > 0:
		spawn_grace_timer -= scaled_delta
		_update_spawn_visuals(scaled_delta)
		return

	# Check stage transitions
	_check_stage_transition()

	# Handle boss attacks
	if is_alerted and not is_dead:
		_update_boss_attacks(scaled_delta)

	# Vacuum pull (stage 3) — apply continuous force toward the head
	if _is_vacuuming:
		_update_vacuum_pull(scaled_delta)

	# Normal AI via base class (handles detection, movement, move_and_slide)
	# Pass the original delta — the base class applies _time_scale internally.
	super._physics_process(delta)

	# Update segmented body to follow the head
	_update_body_segments(delta)

## Check HP thresholds and advance the stage when crossed. Each stage adds new
## attack patterns; the enraged stage boosts speed and damage.
func _check_stage_transition() -> void:
	if max_hp <= 0:
		return
	var hp_frac: float = float(hp) / float(max_hp)
	if _current_stage == Stage.STAGE_1 and hp_frac < GameConstants.VOID_LEVIATHAN_STAGE2_THRESHOLD:
		_enter_stage_2()
	elif _current_stage == Stage.STAGE_2 and hp_frac < GameConstants.VOID_LEVIATHAN_STAGE3_THRESHOLD:
		_enter_stage_3()

func _enter_stage_2() -> void:
	_current_stage = Stage.STAGE_2
	speed *= 1.3
	GameManager.add_message("Void Leviathan stirs — the maw hungers!")
	# Particle burst to telegraph the stage change
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		GameConstants.VOID_LEVIATHAN_COLOR, 30, 0.6)
	if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
		GameManager.camera_rig.add_trauma(0.3)

func _enter_stage_3() -> void:
	_current_stage = Stage.STAGE_3
	_is_enraged = true
	speed *= GameConstants.VOID_LEVIATHAN_ENRAGE_SPEED_MULT
	damage = int(damage * GameConstants.VOID_LEVIATHAN_ENRAGE_DAMAGE_MULT)
	# Visual: shift to enraged color
	if _material:
		var enrage_tween := create_tween()
		enrage_tween.tween_property(_material, "albedo_color",
			GameConstants.VOID_LEVIATHAN_ENRAGE_COLOR, 0.6)
		base_color = GameConstants.VOID_LEVIATHAN_ENRAGE_COLOR
	GameManager.add_message("Void Leviathan is ENRAGED!")
	ParticleEffects.spawn_mega_explosion(get_parent(), global_position,
		GameConstants.VOID_LEVIATHAN_ENRAGE_COLOR)
	if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
		GameManager.camera_rig.add_trauma(0.5)

## Update all boss attack timers and trigger attacks when ready.
func _update_boss_attacks(delta: float) -> void:
	# Void breath — all stages, faster in stage 3
	_breath_timer -= delta
	if _breath_timer <= 0:
		_fire_void_breath()
		_breath_timer = GameConstants.VOID_LEVIATHAN_BREATH_COOLDOWN
		if _current_stage == Stage.STAGE_3:
			_breath_timer *= 0.5  # Rapid volleys when enraged

	# Wisp summon — stage 2+
	if _current_stage >= Stage.STAGE_2:
		_summon_timer -= delta
		if _summon_timer <= 0:
			_summon_wisps()
			_summon_timer = GameConstants.VOID_LEVIATHAN_SUMMON_INTERVAL

	# Vacuum pull — stage 3 only
	if _current_stage == Stage.STAGE_3:
		_vacuum_timer -= delta
		if _vacuum_timer <= 0 and not _is_vacuuming:
			_start_vacuum_pull()
			_vacuum_timer = GameConstants.VOID_LEVIATHAN_VACUUM_COOLDOWN

## Void breath — fires a cone of dark projectiles toward the player.
func _fire_void_breath() -> void:
	var player: Node3D = _get_target_player()
	if not player:
		return
	var base_dir: Vector3 = (player.global_position - global_position).normalized()
	base_dir.y = 0
	var bolt_count: int = GameConstants.VOID_LEVIATHAN_BREATH_BOLTS
	var cone_rad: float = deg_to_rad(GameConstants.VOID_LEVIATHAN_BREATH_CONE_DEGREES)
	for i in range(bolt_count):
		# Spread bolts across the cone
		var t: float = (float(i) / float(bolt_count - 1)) * 2.0 - 1.0  # -1..1
		var angle: float = t * cone_rad
		var angled_dir := base_dir.rotated(Vector3.UP, angle)
		var proj: Area3D = ENEMY_PROJECTILE_SCENE.instantiate()
		proj.set("direction", angled_dir)
		proj.set("speed", GameConstants.VOID_LEVIATHAN_BREATH_PROJECTILE_SPEED)
		proj.set("damage", GameConstants.VOID_LEVIATHAN_BREATH_DAMAGE)
		proj.set("lifetime", 2.5)
		proj.set("projectile_color", Color(0.5, 0.1, 0.8))
		get_parent().add_child(proj)
		proj.global_position = global_position + Vector3(0, 1.5, 0)
	# Muzzle flash
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.6, 0.1, 0.9)
	flash.light_energy = 6.0
	flash.omni_range = 8.0
	get_parent().add_child(flash)
	flash.global_position = global_position + Vector3(0, 1.5, 0)
	var flash_tw := flash.create_tween()
	flash_tw.tween_property(flash, "light_energy", 0.0, 0.3)
	flash_tw.tween_callback(flash.queue_free)
	# Audio cue — deep void breath (uses rumble for a massive boss attack)
	AudioManager.play_sfx(AudioManager.SFX_ARENA)

## Summon Void Wisps around the leviathan (stage 2+).
func _summon_wisps() -> void:
	var wisp_scene: PackedScene = load(WISP_SCENE_PATH)
	if not wisp_scene:
		return
	# Respect the global enemy cap
	var alive_enemies: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.is_dead:
			alive_enemies += 1
	var spawn_cap: int = GameConstants.MAX_ACTIVE_ENEMIES + CoOpManager.get_max_enemies_bonus() + GameManager.get_time_max_enemy_bonus()
	if alive_enemies >= spawn_cap:
		return
	var count: int = GameConstants.VOID_LEVIATHAN_SUMMON_COUNT
	for i in range(count):
		var angle: float = randf() * TAU
		var dist: float = randf_range(3.0, 6.0)
		var spawn_pos: Vector3 = global_position + Vector3(
			cos(angle) * dist, 1.0, sin(angle) * dist
		)
		var wisp: CharacterBody3D = wisp_scene.instantiate()
		wisp.position = spawn_pos
		get_parent().add_child(wisp)
		GameManager.enemies.append(wisp)
		ParticleEffects.spawn_materialization(get_parent(), spawn_pos,
			Color(0.4, 1.0, 0.8, 0.6))
	GameManager.add_message("Void Leviathan summons wisps!")

## Start the vacuum pull — sucks the player toward the maw for VACUUM_DURATION.
func _start_vacuum_pull() -> void:
	_is_vacuuming = true
	_vacuum_duration_left = GameConstants.VOID_LEVIATHAN_VACUUM_DURATION
	GameManager.add_message("Void Leviathan inhales — RUN!")
	# Visual: growing dark vortex at the maw
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		GameConstants.VOID_LEVIATHAN_ENRAGE_COLOR, 40, 0.8)
	if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
		GameManager.camera_rig.add_trauma(0.35)

## Apply continuous vacuum pull force toward the head while active.
func _update_vacuum_pull(delta: float) -> void:
	_vacuum_duration_left -= delta
	if _vacuum_duration_left <= 0:
		_is_vacuuming = false
		return
	var player: Node3D = _get_target_player()
	if not player:
		return
	var dist: float = global_position.distance_to(player.global_position)
	if dist < GameConstants.VOID_LEVIATHAN_VACUUM_RADIUS and dist > 1.0:
		var pull_dir: Vector3 = (global_position - player.global_position).normalized()
		pull_dir.y = 0
		pull_dir = pull_dir.normalized()
		# Apply force — CharacterBody3D players expose velocity for direct manipulation
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity += pull_dir * GameConstants.VOID_LEVIATHAN_VACUUM_FORCE * delta
		# Co-op: also pull P2
		if CoOpManager.is_coop_active() and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
			var p2: Node3D = CoOpManager.p2_node
			var p2_dist: float = global_position.distance_to(p2.global_position)
			if p2_dist < GameConstants.VOID_LEVIATHAN_VACUUM_RADIUS and p2_dist > 1.0:
				var p2_pull: Vector3 = (global_position - p2.global_position).normalized()
				p2_pull.y = 0
				p2_pull = p2_pull.normalized()
				if p2 is CharacterBody3D:
					(p2 as CharacterBody3D).velocity += p2_pull * GameConstants.VOID_LEVIATHAN_VACUUM_FORCE * delta

## Get the target player (nearest valid, co-op aware).
func _get_target_player() -> Node3D:
	var p1: Node3D = get_tree().get_first_node_in_group("player")
	if CoOpManager.is_coop_active() and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
		var p1_dist: float = global_position.distance_to(p1.global_position) if p1 else 99999.0
		var p2_dist: float = global_position.distance_to(CoOpManager.p2_node.global_position)
		if GameManager.player_is_downed:
			p1_dist = 99999.0
		if CoOpManager.p2_is_downed:
			p2_dist = 99999.0
		if p2_dist < p1_dist:
			return CoOpManager.p2_node
	return p1

## Update the segmented body to follow the head's trail.
func _update_body_segments(delta: float) -> void:
	# Record head position
	_segment_positions[0] = global_position
	# Each segment follows the one ahead at fixed spacing
	for i in range(GameConstants.VOID_LEVIATHAN_SEGMENTS):
		var target_pos: Vector3 = _segment_positions[i]
		var current_pos: Vector3 = _segment_positions[i + 1]
		var diff: Vector3 = target_pos - current_pos
		var dist: float = diff.length()
		if dist > GameConstants.VOID_LEVIATHAN_SEGMENT_SPACING:
			var move_amount: float = dist - GameConstants.VOID_LEVIATHAN_SEGMENT_SPACING
			_segment_positions[i + 1] = current_pos + diff.normalized() * move_amount
		# Update visual + collider positions
		if i < _segment_nodes.size() and is_instance_valid(_segment_nodes[i]):
			_segment_nodes[i].global_position = _segment_positions[i + 1]
		if i < _segment_colliders.size() and is_instance_valid(_segment_colliders[i]):
			_segment_colliders[i].global_position = _segment_positions[i + 1]
		if i < _segment_lights.size() and is_instance_valid(_segment_lights[i]):
			_segment_lights[i].global_position = _segment_positions[i + 1] + Vector3(0, 0.5, 0)
	# Pulse segment lights for a "void energy" feel
	var pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.003)
	for sl in _segment_lights:
		if is_instance_valid(sl):
			sl.light_energy = 0.4 + 0.3 * pulse

func _die() -> void:
	# Collapse the body segment-by-segment with cascading particle bursts
	for i in range(_segment_nodes.size()):
		var seg: MeshInstance3D = _segment_nodes[i]
		if is_instance_valid(seg):
			# Stagger the collapse for a dramatic death
			var delay: float = i * 0.08
			var collapse_tween := seg.create_tween()
			collapse_tween.tween_interval(delay)
			collapse_tween.tween_property(seg, "scale", Vector3.ZERO, 0.3) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
			collapse_tween.tween_callback(seg.queue_free)
			# Particle burst at the segment position (scheduled via tween callback)
			var seg_pos: Vector3 = seg.global_position
			collapse_tween.tween_callback(func():
				ParticleEffects.spawn_explosion(get_parent(), seg_pos,
					GameConstants.VOID_LEVIATHAN_COLOR, 16, 0.4)
			)
	_segment_nodes.clear()
	# Fade out segment lights
	for sl in _segment_lights:
		if is_instance_valid(sl):
			var fade_tw := sl.create_tween()
			fade_tw.tween_property(sl, "light_energy", 0.0, 0.4)
			fade_tw.tween_callback(sl.queue_free)
	_segment_lights.clear()
	# Free segment colliders
	for collider in _segment_colliders:
		if is_instance_valid(collider):
			collider.queue_free()
	_segment_colliders.clear()
	# Stop vacuum
	_is_vacuuming = false
	# Boss death spectacle
	GameManager.add_message("Void Leviathan defeated!")
	GameManager.boss_defeated.emit(self)
	GameManager.clear_current_boss()
	ParticleEffects.spawn_boss_death_spectacle(get_parent(), global_position,
		GameConstants.VOID_LEVIATHAN_ENRAGE_COLOR, 4.0)
	super._die()