## Zorp Wiggles — Ancient Sentinel (Phase 23: Mega-Boss)
## A colossal stationary mega-boss with a rotating cycle of arena-wide attacks:
##   Phase A (rotating beam): sweeps a death ray around the arena
##   Phase B (pillar barrage): summons falling crystal pillars across the arena
##   Phase C (shockwave nova): expanding ring waves that must be dodged
##   Phase D (enrage, <25% HP): all attacks at once, faster cycle
##
## The Sentinel doesn't move (speed = 0). The fight is a multi-minute endurance
## battle — the player must dodge rotating beams, avoid falling pillars, and
## jump/position around shockwave novas, all while dealing sustained DPS.
##
## Architecture:
##   - The Sentinel is a CharacterBody3D in the "enemies" group (takes damage).
##   - It overrides _update_ai to be stationary (no pathfinding/movement).
##   - Attack phases cycle on a timer; enrage (stage D) runs multiple phases
##     simultaneously and shortens the cycle.
##   - The rotating beam is a MeshInstance3D cylinder rotated around the Y axis,
##     growing from the Sentinel outward. Damage is applied per second of
##     exposure via a RayCast3D along the beam.
##   - Falling pillars reuse the arena_hazard.tscn FALLING_CRYSTAL pattern but
##     are spawned directly by the Sentinel.
##   - Shockwave novas reuse the shockwave.gd expanding-ring pattern.

extends EnemyBase

class_name EnemyAncientSentinel

# ─── Phase State ──────────────────────────────────────────────────────────────
enum AttackPhase { BEAM, PILLARS, NOVA }
var _current_phase: int = AttackPhase.BEAM
var _phase_timer: float = GameConstants.ANCIENT_SENTINEL_PHASE_DURATION
var _is_enraged: bool = false

# ─── Rotating Beam State ──────────────────────────────────────────────────────
var _beam_mesh: MeshInstance3D = null
var _beam_material: StandardMaterial3D = null
var _beam_ray: RayCast3D = null
var _beam_angle: float = 0.0  # Current rotation around Y
var _beam_active: bool = false
var _beam_warn_timer: float = 0.0
var _beam_damage_tick: float = 0.0

# ─── Pillar Barrage State ─────────────────────────────────────────────────────
var _pillar_timer: float = 0.0
var _pillars_spawned_this_phase: int = 0

# ─── Nova State ───────────────────────────────────────────────────────────────
var _nova_timer: float = 0.0
var _novas_fired_this_phase: int = 0

# Reuse the shockwave scene for nova rings
const SHOCKWAVE_SCENE := preload("res://scenes/entities/shockwave.tscn")

func _ready() -> void:
	enemy_name = "Ancient Sentinel"
	enemy_type = GameConstants.EnemyType.ANCIENT_SENTINEL
	max_hp = GameConstants.ANCIENT_SENTINEL_HP
	speed = GameConstants.ANCIENT_SENTINEL_SPEED  # 0 — stationary
	damage = GameConstants.ANCIENT_SENTINEL_DAMAGE
	base_scale = GameConstants.ANCIENT_SENTINEL_SCALE
	detect_range = GameConstants.ANCIENT_SENTINEL_DETECT_RANGE
	attack_range = GameConstants.ANCIENT_SENTINEL_ATTACK_RANGE
	attack_cooldown = GameConstants.ANCIENT_SENTINEL_ATTACK_COOLDOWN
	xp_reward = GameConstants.ANCIENT_SENTINEL_XP
	score_reward = GameConstants.ANCIENT_SENTINEL_SCORE
	base_color = GameConstants.ANCIENT_SENTINEL_COLOR
	# Stationary boss — disable all smart AI movement behaviors
	use_smart_ai = false
	super._ready()

	# Ancient gold-brown emissive material with strong rim
	if _material:
		_material.emission = base_color * 0.4
		_material.emission_energy_multiplier = 1.6
		_material.rim = 1.0
		_material.rim_tint = 1.0
		_material.metallic = 0.6
		_material.roughness = 0.25

	# Build the rotating beam visual (hidden until phase A)
	_create_beam_visual()

	# Boss HP bar on HUD
	GameManager.boss_spawned.emit(self)

## Create the rotating death-ray visual. A long thin cylinder that extends from
## the Sentinel outward, rotated around the Y axis. Hidden by default; made
## visible during the beam phase with a warn telegraph first.
func _create_beam_visual() -> void:
	_beam_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.3
	cyl.height = GameConstants.ANCIENT_SENTINEL_BEAM_LENGTH
	cyl.radial_segments = 12
	cyl.rings = 1
	_beam_mesh.mesh = cyl
	_beam_material = StandardMaterial3D.new()
	_beam_material.albedo_color = Color(1.0, 0.3, 0.1, 0.0)  # Invisible until active
	_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_material.emission_enabled = true
	_beam_material.emission = Color(1.0, 0.3, 0.1)
	_beam_material.emission_energy_multiplier = 0.0
	_beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_material.no_depth_test = true
	_beam_mesh.material_override = _beam_material
	add_child(_beam_mesh)
	# Position the beam so it extends outward from the Sentinel's center.
	# The cylinder's local Y axis is its length, so we rotate it to lie flat
	# (rotate 90° around X), then position it so one end is at the Sentinel.
	_beam_mesh.rotation_degrees.x = 90.0
	_beam_mesh.position = Vector3(0, 1.5, -GameConstants.ANCIENT_SENTINEL_BEAM_LENGTH / 2.0)
	_beam_mesh.visible = false

	# RayCast3D along the beam direction to detect player hits
	_beam_ray = RayCast3D.new()
	_beam_ray.target_position = Vector3(0, 0, -GameConstants.ANCIENT_SENTINEL_BEAM_LENGTH)
	_beam_ray.enabled = false
	add_child(_beam_ray)
	_beam_ray.position = Vector3(0, 1.5, 0)

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_paused:
		return
	var scaled_delta: float = delta * _time_scale

	# Spawn grace period
	if spawn_grace_timer > 0:
		spawn_grace_timer -= scaled_delta
		_update_spawn_visuals(scaled_delta)
		return

	# Check enrage threshold
	if not _is_enraged and float(hp) / float(max_hp) < GameConstants.ANCIENT_SENTINEL_ENRAGE_HP_THRESHOLD:
		_enter_enrage()

	# Tick the attack phase cycle
	_phase_timer -= scaled_delta
	if _phase_timer <= 0:
		_advance_phase()

	# Run the current phase's logic
	_update_current_phase(scaled_delta)

	# In enrage, also run a secondary phase simultaneously
	if _is_enraged:
		_update_enrage_extra(scaled_delta)

	# Note: we do NOT call super._physics_process(delta) because the base class
	# would move the Sentinel (it's stationary). We handle detection manually.
	# Alert the Sentinel immediately — it's a mega-boss, always aware of the player.
	if not is_alerted:
		is_alerted = true
		if alert_indicator:
			alert_indicator.visible = true
			alert_indicator.text = "!"
			alert_indicator.scale = Vector3.ONE * GameConstants.ENEMY_ALERT_INDICATOR_SCALE

## Advance to the next attack phase in the cycle (BEAM → PILLARS → NOVA → repeat).
func _advance_phase() -> void:
	# End the current phase
	_end_phase(_current_phase)
	# Pick the next phase in cycle order
	match _current_phase:
		AttackPhase.BEAM:
			_current_phase = AttackPhase.PILLARS
		AttackPhase.PILLARS:
			_current_phase = AttackPhase.NOVA
		AttackPhase.NOVA:
			_current_phase = AttackPhase.BEAM
	# Start the new phase
	_phase_timer = GameConstants.ANCIENT_SENTINEL_PHASE_DURATION
	if _is_enraged:
		_phase_timer *= 0.6  # Faster cycle when enraged
	_start_phase(_current_phase)

## Start a phase — set up visuals and state for the incoming attack.
func _start_phase(phase: int) -> void:
	match phase:
		AttackPhase.BEAM:
			_beam_active = false
			_beam_warn_timer = GameConstants.ANCIENT_SENTINEL_BEAM_WARN_TIME
			_beam_angle = randf() * TAU
			_pillars_spawned_this_phase = 0
		AttackPhase.PILLARS:
			_pillars_spawned_this_phase = 0
			_pillar_timer = 0.3  # First pillar after a short delay
		AttackPhase.NOVA:
			_novas_fired_this_phase = 0
			_nova_timer = 0.5  # First nova after a short delay

## End a phase — clean up visuals and state.
func _end_phase(phase: int) -> void:
	match phase:
		AttackPhase.BEAM:
			_beam_active = false
			if _beam_mesh:
				_beam_mesh.visible = false
			if _beam_ray:
				_beam_ray.enabled = false
			if _beam_material:
				_beam_material.albedo_color.a = 0.0
				_beam_material.emission_energy_multiplier = 0.0

## Update the current attack phase logic.
func _update_current_phase(delta: float) -> void:
	match _current_phase:
		AttackPhase.BEAM:
			_update_beam_phase(delta)
		AttackPhase.PILLARS:
			_update_pillar_phase(delta)
		AttackPhase.NOVA:
			_update_nova_phase(delta)

## Beam phase — warn, then sweep a rotating death ray around the arena.
func _update_beam_phase(delta: float) -> void:
	if not _beam_active:
		# Warn telegraph — beam grows visible (dim) before activating
		_beam_warn_timer -= delta
		if _beam_mesh:
			_beam_mesh.visible = true
			# Orient the beam to the current angle
			_apply_beam_rotation()
			# Fade in the beam during the warn
			var warn_t: float = 1.0 - max(0.0, _beam_warn_timer) / GameConstants.ANCIENT_SENTINEL_BEAM_WARN_TIME
			_beam_material.albedo_color.a = warn_t * 0.3
			_beam_material.emission_energy_multiplier = warn_t * 1.0
		if _beam_warn_timer <= 0:
			_beam_active = true
			_beam_material.albedo_color.a = 0.85
			_beam_material.emission_energy_multiplier = 3.0
			if _beam_ray:
				_beam_ray.enabled = true
			AudioManager.play_sfx(AudioManager.SFX_ENEMY_HIT)
	else:
		# Rotate the beam around the Y axis
		var rotate_speed: float = GameConstants.ANCIENT_SENTINEL_BEAM_ROTATE_SPEED
		if _is_enraged:
			rotate_speed *= 1.5
		_beam_angle += rotate_speed * delta
		_apply_beam_rotation()
		# Damage tick — apply damage per second of exposure
		_beam_damage_tick -= delta
		if _beam_damage_tick <= 0:
			_beam_damage_tick = 0.2  # Tick 5×/sec
			_check_beam_hit()

## Apply the current beam angle to the beam mesh + raycast.
func _apply_beam_rotation() -> void:
	if not _beam_mesh:
		return
	# The beam extends along local -Z (after the X rotation). Rotate around Y.
	_beam_mesh.rotation_degrees.y = rad_to_deg(_beam_angle)
	if _beam_ray:
		_beam_ray.rotation_degrees.y = rad_to_deg(_beam_angle)

## Check if the beam raycast hits the player and apply damage.
func _check_beam_hit() -> void:
	if not _beam_ray or not _beam_ray.enabled:
		return
	_beam_ray.force_raycast_update()
	var collider: Object = _beam_ray.get_collider()
	if collider and (collider.is_in_group("player") or collider.is_in_group("player2")):
		var dmg: int = int(GameConstants.ANCIENT_SENTINEL_BEAM_DAMAGE * 0.2)  # Per-tick (5×/sec)
		if collider.is_in_group("player2"):
			CoOpManager.p2_take_damage(dmg, global_position)
		else:
			GameManager.take_damage(dmg, global_position)
		# Small spark at the hit point
		ParticleEffects.spawn_explosion(get_parent(), _beam_ray.get_collision_point(),
			Color(1.0, 0.3, 0.1), 6, 0.2)

## Pillar phase — summon falling crystal pillars across the arena around the player.
func _update_pillar_phase(delta: float) -> void:
	_pillar_timer -= delta
	if _pillar_timer <= 0 and _pillars_spawned_this_phase < GameConstants.ANCIENT_SENTINEL_PILLAR_COUNT:
		_spawn_falling_pillar()
		_pillars_spawned_this_phase += 1
		# Stagger the pillars
		_pillar_timer = GameConstants.ANCIENT_SENTINEL_PHASE_DURATION / float(GameConstants.ANCIENT_SENTINEL_PILLAR_COUNT + 1)

## Spawn a single falling pillar at a random position near the player.
## The pillar telegraphs (glowing ground patch) then drops, dealing AoE damage.
func _spawn_falling_pillar() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var angle: float = randf() * TAU
	var dist: float = randf_range(5.0, 25.0)
	var target_pos: Vector3 = player.global_position + Vector3(
		cos(angle) * dist, 0, sin(angle) * dist
	)
	# Telegraph: glowing ground patch
	var telegraph := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = GameConstants.ANCIENT_SENTINEL_PILLAR_RADIUS
	disc.bottom_radius = GameConstants.ANCIENT_SENTINEL_PILLAR_RADIUS
	disc.height = 0.1
	telegraph.mesh = disc
	var tg_mat := StandardMaterial3D.new()
	tg_mat.albedo_color = Color(1.0, 0.4, 0.1, 0.5)
	tg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tg_mat.emission_enabled = true
	tg_mat.emission = Color(1.0, 0.4, 0.1)
	tg_mat.emission_energy_multiplier = 1.5
	tg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tg_mat.no_depth_test = true
	telegraph.material_override = tg_mat
	get_parent().add_child(telegraph)
	telegraph.global_position = target_pos + Vector3(0, 0.1, 0)
	# Pulse the telegraph during the warn time
	var tg_tween := telegraph.create_tween()
	for _i in range(4):
		tg_tween.tween_property(tg_mat, "emission_energy_multiplier", 0.5, 0.12)
		tg_tween.tween_property(tg_mat, "emission_energy_multiplier", 2.0, 0.12)
	# After the warn, drop the pillar and deal damage
	tg_tween.tween_callback(func():
		# Spawn the falling pillar visual
		_spawn_pillar_drop(target_pos)
		# Remove the telegraph
		telegraph.queue_free()
	)

## Spawn the falling pillar visual + apply AoE damage on impact.
func _spawn_pillar_drop(target_pos: Vector3) -> void:
	if is_dead:
		return
	# Falling crystal visual
	var pillar := MeshInstance3D.new()
	var crystal := CapsuleMesh.new()
	crystal.radius = 0.8
	crystal.height = 4.0
	pillar.mesh = crystal
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.9, 0.5, 0.2)
	p_mat.emission_enabled = true
	p_mat.emission = Color(1.0, 0.4, 0.1)
	p_mat.emission_energy_multiplier = 2.0
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pillar.material_override = p_mat
	get_parent().add_child(pillar)
	pillar.global_position = target_pos + Vector3(0, GameConstants.FALLING_CRYSTAL_HEIGHT, 0)
	# Drop the pillar via tween
	var drop_tween := pillar.create_tween()
	drop_tween.tween_property(pillar, "global_position:y",
		target_pos.y + 0.5, GameConstants.ANCIENT_SENTINEL_PILLAR_WARN_TIME) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# On impact: AoE damage + explosion + remove pillar
	drop_tween.tween_callback(func():
		if not is_instance_valid(pillar):
			return
		# AoE damage to players in radius
		_apply_aoe_damage(pillar.global_position,
			GameConstants.ANCIENT_SENTINEL_PILLAR_RADIUS,
			GameConstants.ANCIENT_SENTINEL_PILLAR_DAMAGE)
		# Explosion visual
		ParticleEffects.spawn_explosion(pillar.get_parent(), pillar.global_position,
			Color(1.0, 0.4, 0.1), 24, 0.5)
		# Light flash
		var flash := OmniLight3D.new()
		flash.light_color = Color(1.0, 0.5, 0.1)
		flash.light_energy = 6.0
		flash.omni_range = 8.0
		pillar.get_parent().add_child(flash)
		flash.global_position = pillar.global_position
		var flash_tw := flash.create_tween()
		flash_tw.tween_property(flash, "light_energy", 0.0, 0.3)
		flash_tw.tween_callback(flash.queue_free)
		# Camera shake
		if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
			GameManager.camera_rig.add_trauma(0.25)
		# Remove the pillar
		pillar.queue_free()
	)

## Nova phase — fire sequential expanding shockwave rings.
func _update_nova_phase(delta: float) -> void:
	_nova_timer -= delta
	if _nova_timer <= 0 and _novas_fired_this_phase < GameConstants.ANCIENT_SENTINEL_NOVA_COUNT:
		_fire_nova_ring()
		_novas_fired_this_phase += 1
		_nova_timer = GameConstants.ANCIENT_SENTINEL_NOVA_INTERVAL

## Fire a single expanding nova ring from the Sentinel's position.
func _fire_nova_ring() -> void:
	if not SHOCKWAVE_SCENE:
		return
	var nova: Node3D = SHOCKWAVE_SCENE.instantiate()
	get_parent().add_child(nova)
	nova.global_position = global_position + Vector3(0, 0.5, 0)
	# Configure the shockwave via its properties (if available)
	if nova.has_method("set") or nova.get("damage") != null:
		nova.set("damage", GameConstants.ANCIENT_SENTINEL_NOVA_DAMAGE)
		nova.set("max_radius", GameConstants.ANCIENT_SENTINEL_NOVA_MAX_RADIUS)
		nova.set("expand_speed", GameConstants.ANCIENT_SENTINEL_NOVA_EXPAND_SPEED)
	AudioManager.play_sfx(AudioManager.SFX_ENEMY_HIT)
	# Camera shake on nova
	if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
		GameManager.camera_rig.add_trauma(0.2)

## In enrage, run a secondary phase simultaneously for extra pressure.
## We rotate the beam (if not in beam phase) or fire extra novas (if not in
## nova phase) on top of the main phase.
func _update_enrage_extra(delta: float) -> void:
	# Extra beam rotation when not in beam phase
	if _current_phase != AttackPhase.BEAM and _beam_mesh and _beam_mesh.visible == false:
		# Periodically fire a brief sweep beam even during other phases
		if randf() < delta * 0.3:  # ~30% chance per second
			_beam_active = true
			_beam_angle = randf() * TAU
			_beam_material.albedo_color.a = 0.6
			_beam_material.emission_energy_multiplier = 2.0
			_beam_mesh.visible = true
			if _beam_ray:
				_beam_ray.enabled = true
			# Auto-end after 1.5s
			var end_tw := create_tween()
			end_tw.tween_interval(1.5)
			end_tw.tween_callback(func():
				_beam_active = false
				if _beam_mesh:
					_beam_mesh.visible = false
				if _beam_ray:
					_beam_ray.enabled = false
				if _beam_material:
					_beam_material.albedo_color.a = 0.0
					_beam_material.emission_energy_multiplier = 0.0
			)
	# Extra nova when not in nova phase
	if _current_phase != AttackPhase.NOVA:
		if randf() < delta * 0.15:  # ~15% chance per second
			_fire_nova_ring()

## Apply AoE damage to all players within radius of a position.
func _apply_aoe_damage(center: Vector3, radius: float, dmg: int) -> void:
	var p1: Node3D = get_tree().get_first_node_in_group("player")
	if p1 and is_instance_valid(p1) and not GameManager.player_is_downed:
		if global_position.distance_to(p1.global_position) < radius or \
				center.distance_to(p1.global_position) < radius:
			GameManager.take_damage(dmg, center)
	if CoOpManager.is_coop_active() and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
		if not CoOpManager.p2_is_downed and center.distance_to(CoOpManager.p2_node.global_position) < radius:
			CoOpManager.p2_take_damage(dmg, center)

## Override _update_ai to be stationary — the Sentinel doesn't move or path.
func _update_ai(delta: float) -> void:
	# No movement — the Sentinel is stationary. Detection is handled in
	# _physics_process (always alerted). We skip the base AI entirely.
	pass

## Override _try_attack to suppress the inherited melee attack. The Sentinel's
## attacks are all phase-driven (beam, pillars, novas), not melee.
func _try_attack(_player: Node3D) -> void:
	pass

func _enter_enrage() -> void:
	_is_enraged = true
	damage = int(damage * 1.4)
	if _material:
		var enrage_tween := create_tween()
		enrage_tween.tween_property(_material, "albedo_color",
			GameConstants.ANCIENT_SENTINEL_ENRAGE_COLOR, 0.6)
		base_color = GameConstants.ANCIENT_SENTINEL_ENRAGE_COLOR
	GameManager.add_message("Ancient Sentinel awakens — ENRAGE!")
	ParticleEffects.spawn_mega_explosion(get_parent(), global_position,
		GameConstants.ANCIENT_SENTINEL_ENRAGE_COLOR)
	if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
		GameManager.camera_rig.add_trauma(0.5)

func _die() -> void:
	# Clean up beam
	if _beam_mesh:
		_beam_mesh.queue_free()
		_beam_mesh = null
	if _beam_ray:
		_beam_ray.queue_free()
		_beam_ray = null
	GameManager.add_message("Ancient Sentinel destroyed!")
	GameManager.boss_defeated.emit(self)
	GameManager.clear_current_boss()
	ParticleEffects.spawn_boss_death_spectacle(get_parent(), global_position,
		GameConstants.ANCIENT_SENTINEL_ENRAGE_COLOR, 5.0)
	super._die()