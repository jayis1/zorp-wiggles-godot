## Zorp Wiggles — Alien Companion Pet (Phase 15)
## A loyal alien creature that follows Zorp, auto-collects nearby items,
## attacks small enemies at Adolescent stage, and shields Zorp at Adult stage.
## Evolves through 3 stages (Baby → Adolescent → Adult) by being fed collectibles.
##
## Usage:
##   The pet is spawned by the Player via the "summon_pet" input action (F key).
##   Once summoned, it persists until Zorp dies. Feeding is automatic — any
##   collectible the pet vacuums up grants evolution points. The player can also
##   press "pet_fetch" (G key) then click a distant item to send the pet to fetch it.
##
## Architecture:
##   - CharacterBody3D root (so it can use move_and_slide for smooth following)
##   - MeshInstance3D body (sphere, recolored per stage)
##   - OmniLight3D glow (color shifts per stage)
##   - GPUParticles3D aura (only at Adolescent/Adult)
##   - NavigationAgent3D for pathfinding around obstacles
##
## Signals:
##   pet_stage_changed(stage: int)          — Fired when the pet evolves
##   pet_evolution_progress(pct: float)      — 0..1 progress toward next stage
##   pet_hp_changed(hp: int, max_hp: int)    — Pet took damage / healed
##   pet_state_changed(state: String)        — "follow" / "fetch" / "attack" / "idle"

extends CharacterBody3D

# ─── Signals ──────────────────────────────────────────────────────────────────
signal pet_stage_changed(stage: int)
signal pet_evolution_progress(pct: float)
signal pet_hp_changed(hp: int, max_hp: int)
signal pet_state_changed(state: String)

# ─── State ────────────────────────────────────────────────────────────────────
var stage: int = GameConstants.PetStage.BABY
var evolution_points: int = 0
var hp: int = 30
var max_hp: int = 30

# Behavior state machine
enum PetState { FOLLOW, FETCH, ATTACK, IDLE_ANIM }
var current_state: int = PetState.FOLLOW
var _state_timer: float = 0.0  # General-purpose timer for idle anims
var is_dead: bool = false  # Pet is in death-respawn state

# References
var _cached_player: CharacterBody3D = null
var _fetch_target: Node3D = null  # Target collectible (for fetch command)
var _attack_target: Node3D = null  # Target enemy
var _attack_cooldown_timer: float = 0.0
var _idle_anim_timer: float = 0.0
var _idle_anim_phase: int = 0  # 0=none, 1=bounce, 2=spin, 3=tail-chase, 4=sleep

# Visuals
var _mesh: MeshInstance3D = null
var _mat: StandardMaterial3D = null
var _glow: OmniLight3D = null
var _aura: GPUParticles3D = null
var _bob_phase: float = 0.0
var _facing_dir: Vector3 = Vector3.FORWARD

# Navigation
var _nav_agent: NavigationAgent3D = null
var _nav_repath_timer: float = 0.0

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("pet")
	add_to_group("companion_pet")
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep updating even when paused (for visual idle)

	# Build visuals
	_build_visuals()

	# Navigation agent for pathfinding
	_nav_agent = NavigationAgent3D.new()
	_nav_agent.path_desired_distance = 0.5
	_nav_agent.target_desired_distance = 1.0
	add_child(_nav_agent)

	# Apply initial stage config
	_apply_stage_config()

	# Start at follow state
	_set_state(PetState.FOLLOW)

	# Spawn pop-in
	_mesh.scale = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(_mesh, "scale", Vector3.ONE, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

	# Materialize particle burst
	ParticleEffects.spawn_materialization(get_parent(), global_position, _stage_color())

	# Connect to player death so we can vanish
	GameManager.player_died.connect(_on_player_died)

	# Cache player
	_refresh_player_cache()

	print("[Pet] Companion pet summoned at stage %s" % GameConstants.PET_STAGE_NAMES[stage])


func _build_visuals() -> void:
	# Body mesh — sphere
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 8
	_mesh.mesh = sphere
	_mesh.position.y = 0.5
	add_child(_mesh)

	# Material — unlit emissive with rim
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.emission_enabled = true
	_mat.rim_enabled = true
	_mat.rim = 0.9
	_mat.rim_tint = 1.0
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh.material_override = _mat

	# Glow light
	_glow = OmniLight3D.new()
	_glow.light_energy = 1.0
	_glow.omni_range = 5.0
	_glow.omni_attenuation = 1.5
	_glow.position.y = 0.5
	add_child(_glow)

	# Aura particles (initially disabled; enabled at Adolescent+)
	_aura = GPUParticles3D.new()
	_aura.amount = 8
	_aura.lifetime = 1.2
	_aura.emitting = true
	_aura.one_shot = false
	_aura.local_coords = true
	_aura.visible = false
	_aura.position.y = 0.5

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.gravity = Vector3(0, 0, 0)
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.scale_min = 0.1
	mat.scale_max = 0.3
	mat.color = Color(0.5, 0.6, 1.0, 0.6)
	_aura.process_material = mat

	var aura_mesh := SphereMesh.new()
	aura_mesh.radius = 0.08
	aura_mesh.height = 0.16
	aura_mesh.radial_segments = 4
	aura_mesh.rings = 2
	var aura_mat := StandardMaterial3D.new()
	aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_mat.emission_enabled = true
	aura_mat.emission = Color(0.5, 0.6, 1.0)
	aura_mat.emission_energy_multiplier = 2.0
	aura_mesh.material = aura_mat
	_aura.draw_pass_1 = aura_mesh
	add_child(_aura)

	# Collision shape
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	col.shape = shape
	add_child(col)


# ─── Stage Management ─────────────────────────────────────────────────────────

func _stage_config() -> Dictionary:
	return GameConstants.PET_STAGE_CONFIG[stage]

func _stage_color() -> Color:
	return GameConstants.PET_STAGE_CONFIG[stage]["color"]

func _apply_stage_config() -> void:
	var cfg: Dictionary = _stage_config()
	# Mesh scale
	if _mesh:
		_mesh.scale = Vector3.ONE * cfg["scale"]
	# Material colors
	if _mat:
		_mat.albedo_color = cfg["color"]
		_mat.emission = cfg["emission"]
		_mat.emission_energy_multiplier = 1.2
	# Glow
	if _glow:
		_glow.light_color = cfg["emission"]
		_glow.light_energy = 1.0 + float(stage) * 0.4
		_glow.omni_range = 4.0 + float(stage) * 1.5
	# Aura — enabled at Adolescent and Adult
	if _aura:
		var count: int = GameConstants.PET_AURA_PARTICLE_COUNTS[stage]
		_aura.amount = count
		_aura.visible = count > 0
		if _aura.process_material is ParticleProcessMaterial:
			(_aura.process_material as ParticleProcessMaterial).color = Color(cfg["emission"].r, cfg["emission"].g, cfg["emission"].b, 0.6)
	# HP
	max_hp = cfg["hp"]
	hp = max_hp
	pet_hp_changed.emit(hp, max_hp)


## Feed the pet a collectible, granting evolution points. Triggers evolution
## when the threshold for the next stage is reached.
func feed(collectible_type: int) -> void:
	var value: int = GameConstants.PET_FEED_VALUES.get(collectible_type, 5)
	evolution_points += value
	# Heal the pet slightly per pickup
	hp = min(max_hp, hp + int(GameConstants.PET_HEAL_PER_PICKUP))
	pet_hp_changed.emit(hp, max_hp)
	_check_evolution()
	_emit_progress()
	# ── Phase 25: Statistics tracking — record pet feeding ──
	if Statistics:
		Statistics.record_pet_feeding()


func _check_evolution() -> void:
	if stage == GameConstants.PetStage.BABY and evolution_points >= GameConstants.PET_EVOLVE_TO_ADOLESCENT:
		_evolve_to(GameConstants.PetStage.ADOLESCENT)
	elif stage == GameConstants.PetStage.ADOLESCENT and evolution_points >= GameConstants.PET_EVOLVE_TO_ADULT:
		_evolve_to(GameConstants.PetStage.ADULT)


func _evolve_to(new_stage: int) -> void:
	stage = new_stage
	_apply_stage_config()
	pet_stage_changed.emit(stage)
	# Evolution burst — big particle pop in the new stage color
	ParticleEffects.spawn_combo_fireworks(get_parent(), global_position, stage + 1)
	ParticleEffects.spawn_pickup_sparkle(get_parent(), global_position + Vector3(0, 1, 0), _stage_color())
	# Evolution scale punch
	if _mesh:
		var punch := create_tween()
		punch.tween_property(_mesh, "scale", Vector3.ONE * _stage_config()["scale"] * 1.6, 0.18) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		punch.tween_property(_mesh, "scale", Vector3.ONE * _stage_config()["scale"], 0.3) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	GameManager.add_message("✨ Pet evolved to %s!" % GameConstants.PET_STAGE_NAMES[stage])
	print("[Pet] Evolved to %s (points=%d)" % [GameConstants.PET_STAGE_NAMES[stage], evolution_points])


func _emit_progress() -> void:
	var pct: float = 0.0
	if stage == GameConstants.PetStage.BABY:
		pct = float(evolution_points) / float(GameConstants.PET_EVOLVE_TO_ADOLESCENT)
	elif stage == GameConstants.PetStage.ADOLESCENT:
		var base: int = GameConstants.PET_EVOLVE_TO_ADOLESCENT
		var span: int = GameConstants.PET_EVOLVE_TO_ADULT - base
		pct = float(evolution_points - base) / float(span)
	else:
		pct = 1.0  # Adult is max
	pct = clampf(pct, 0.0, 1.0)
	pet_evolution_progress.emit(pct)


# ─── Player Damage Shield (Adult only) ────────────────────────────────────────

## Returns the fractional damage reduction this pet grants Zorp (0..1).
## Only Adult pets shield. Consumed by GameManager.take_damage().
func get_shield_reduction() -> float:
	return _stage_config()["shield_reduction"]


# ─── Fetch Command ────────────────────────────────────────────────────────────

## Send the pet to fetch a specific collectible. Called when the player issues
## the fetch command (G + click) targeting a collectible.
func send_to_fetch(target: Node3D) -> void:
	if not is_instance_valid(target) or not target.is_in_group("collectibles"):
		return
	if not _cached_player or not is_instance_valid(_cached_player):
		return
	var dist: float = global_position.distance_to(target.global_position)
	if dist > GameConstants.PET_FETCH_RANGE:
		GameManager.add_message("🐾 Pet can't reach that — too far!")
		return
	_fetch_target = target
	_set_state(PetState.FETCH)
	GameManager.add_message("🐾 Pet fetching item...")


# ─── Main Loop ────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if GameManager.is_paused:
		return
	if is_dead:
		return  # Waiting for respawn
	_refresh_player_cache()
	if not _cached_player or not is_instance_valid(_cached_player):
		return
	if not GameManager.player_is_alive:
		return

	# Tick cooldowns
	if _attack_cooldown_timer > 0:
		_attack_cooldown_timer -= delta

	# State machine
	match current_state:
		PetState.FOLLOW:
			_update_follow(delta)
		PetState.FETCH:
			_update_fetch(delta)
		PetState.ATTACK:
			_update_attack(delta)
		PetState.IDLE_ANIM:
			_update_idle_anim(delta)

	# Auto-collect nearby items (always active regardless of state)
	_auto_collect(delta)

	# Auto-attack nearby enemies (Adolescent+)
	if stage >= GameConstants.PetStage.ADOLESCENT:
		_auto_attack(delta)

	# Idle animation random trigger (only when following and idle)
	if current_state == PetState.FOLLOW:
		_idle_anim_timer -= delta
		if _idle_anim_timer <= 0:
			_idle_anim_timer = GameConstants.PET_IDLE_ANIMATION_INTERVAL + randf() * 3.0
			if randf() < 0.4:
				_start_idle_anim()

	# Visual bob + facing
	_update_visuals(delta)


func _refresh_player_cache() -> void:
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player") as CharacterBody3D


# ─── Follow State ─────────────────────────────────────────────────────────────

func _update_follow(delta: float) -> void:
	var player: CharacterBody3D = _cached_player
	var cfg: Dictionary = _stage_config()
	var follow_dist: float = cfg["follow_distance"]
	# Position to follow: behind-right of player, at PET_HEIGHT_OFFSET
	var target_pos: Vector3 = player.global_position + Vector3(2.0, GameConstants.PET_HEIGHT_OFFSET, 0.0)
	# If player is moving, offset toward the direction they came from (trailing)
	if player.velocity.length_squared() > 1.0:
		var trail_dir: Vector3 = -player.velocity.normalized()
		trail_dir.y = 0
		target_pos = player.global_position + trail_dir * follow_dist + Vector3(0, GameConstants.PET_HEIGHT_OFFSET, 0)
	_move_toward(target_pos, cfg["speed"], delta)


# ─── Fetch State ──────────────────────────────────────────────────────────────

func _update_fetch(delta: float) -> void:
	if not _fetch_target or not is_instance_valid(_fetch_target):
		_fetch_target = null
		_set_state(PetState.FOLLOW)
		return
	var target_pos: Vector3 = _fetch_target.global_position + Vector3(0, 0.5, 0)
	var d: float = global_position.distance_to(target_pos)
	if d < 1.5:
		# Reached the item — let auto-collect handle it, then return to follow
		_fetch_target = null
		_set_state(PetState.FOLLOW)
		return
	_move_toward(target_pos, GameConstants.PET_FETCH_SPEED, delta)


# ─── Attack State ─────────────────────────────────────────────────────────────

func _auto_attack(delta: float) -> void:
	if _attack_cooldown_timer > 0:
		return
	# Don't search for a new target if already attacking a valid one
	if _attack_target and is_instance_valid(_attack_target):
		if not ("is_dead" in _attack_target and _attack_target.is_dead):
			return
	# Find nearest enemy within attack range
	var cfg: Dictionary = _stage_config()
	var atk_range: float = cfg["attack_range"]
	if atk_range <= 0:
		return
	var nearest: Node3D = null
	var nearest_dist: float = atk_range
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("take_damage_from") == false and enemy.has_method("take_damage") == false:
			continue
		# Adolescent pets only attack small enemies (HP <= 30)
		if stage == GameConstants.PetStage.ADOLESCENT:
			var ehp: int = enemy.get("hp") if "hp" in enemy else 50
			if ehp > 30:
				continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	if nearest:
		_attack_target = nearest
		_set_state(PetState.ATTACK)


func _update_attack(delta: float) -> void:
	if not _attack_target or not is_instance_valid(_attack_target):
		_attack_target = null
		_set_state(PetState.FOLLOW)
		return
	var enemy: Node3D = _attack_target
	var cfg: Dictionary = _stage_config()
	var d: float = global_position.distance_to(enemy.global_position)
	# Move toward the enemy
	if d > cfg["attack_range"] * 0.6:
		_move_toward(enemy.global_position + Vector3(0, 0.5, 0), cfg["speed"] * 1.2, delta)
		return
	# In range — attack
	if _attack_cooldown_timer <= 0:
		_attack_cooldown_timer = cfg["attack_cooldown"]
		var dmg: int = cfg["attack_damage"]
		if enemy.has_method("take_damage_from"):
			enemy.take_damage_from(dmg, global_position)
		elif enemy.has_method("take_damage"):
			enemy.take_damage(dmg)
		# Visual pop on attack
		if _mesh:
			var pop := create_tween()
			pop.tween_property(_mesh, "scale", Vector3.ONE * cfg["scale"] * 1.4, 0.1) \
				.set_ease(Tween.EASE_OUT)
			pop.tween_property(_mesh, "scale", Vector3.ONE * cfg["scale"], 0.15) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		# Small sparkle
		ParticleEffects.spawn_pickup_sparkle(get_parent(), enemy.global_position + Vector3(0, 1, 0), _stage_color())


# ─── Idle Animations ──────────────────────────────────────────────────────────

func _start_idle_anim() -> void:
	# Pick a random idle animation: bounce, spin, tail-chase, sleep
	_idle_anim_phase = randi_range(1, 4)
	_state_timer = randf_range(1.5, 2.5)
	_set_state(PetState.IDLE_ANIM)


func _update_idle_anim(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0:
		# Reset and go back to follow
		if _mesh:
			_mesh.rotation = Vector3.ZERO
			_mesh.position.x = 0.0
			_mesh.position.z = 0.0
		_idle_anim_phase = 0
		_set_state(PetState.FOLLOW)
		return
	match _idle_anim_phase:
		1:  # Bounce
			if _mesh:
				_mesh.position.y = 0.5 + abs(sin(_state_timer * 8.0)) * 0.5
		2:  # Spin
			if _mesh:
				_mesh.rotation.y += delta * 8.0
		3:  # Tail-chase (orbit around own position)
			if _mesh:
				var angle: float = _state_timer * 6.0
				_mesh.position.x = cos(angle) * 0.4
				_mesh.position.z = sin(angle) * 0.4
		4:  # Sleep (slow bob + dim emission)
			if _mesh:
				_mesh.position.y = 0.5 + sin(_state_timer * 2.0) * 0.05
			if _mat:
				_mat.emission_energy_multiplier = 0.4 + 0.1 * sin(_state_timer * 2.0)


# ─── Auto-Collect ─────────────────────────────────────────────────────────────

func _auto_collect(delta: float) -> void:
	var cfg: Dictionary = _stage_config()
	var radius: float = cfg["collect_radius"]
	# Vacuum nearby collectibles toward the pet — they get collected when close
	for col in GameManager.collectibles:
		if not is_instance_valid(col):
			continue
		if not col.is_in_group("collectibles"):
			continue
		# Skip collectibles already in pickup-pop animation
		if "is_popping" in col and col.is_popping:
			continue
		var d: float = global_position.distance_to(col.global_position)
		if d < radius:
			# Pull toward pet
			var pull_speed: float = 14.0 * (1.0 - d / radius)
			var dir: Vector3 = (global_position + Vector3(0, 0.5, 0) - col.global_position).normalized()
			col.global_position += dir * pull_speed * delta
			# If close enough, feed pet and trigger collect
			if d < 1.2:
				_collect_via_pet(col)


func _collect_via_pet(col: Node3D) -> void:
	if not is_instance_valid(col):
		return
	# Determine collectible type
	var col_type: int = GameConstants.CollectibleType.XP_ORB
	if "collectible_type" in col:
		col_type = col.collectible_type
	# Feed pet
	feed(col_type)
	# Trigger normal collection (awards XP to player, etc.)
	# We call the private _collect via a method, but since it's private we
	# emulate by emitting the collected signal and freeing.
	# However, the collectible.gd has a `_collect()` method that handles XP,
	# health, streaks, and the pickup animation. We invoke it by calling the
	# method directly (GDScript doesn't enforce private).
	if col.has_method("_collect"):
		col._collect()
	else:
		# Fallback: just free it
		col.queue_free()


# ─── Movement ─────────────────────────────────────────────────────────────────

func _move_toward(target_pos: Vector3, speed: float, delta: float) -> void:
	# Use navigation agent if the nav mesh is baked, otherwise direct movement
	if _nav_agent and NavigationManager.is_ready():
		_nav_repath_timer -= delta
		if _nav_repath_timer <= 0:
			_nav_agent.target_position = target_pos
			_nav_repath_timer = 0.3
		if _nav_agent.is_navigation_finished():
			velocity = Vector3.ZERO
		else:
			var next_pos: Vector3 = _nav_agent.get_next_path_position()
			var dir: Vector3 = (next_pos - global_position).normalized()
			dir.y = 0
			velocity = dir * speed
			_facing_dir = dir
	else:
		var dir: Vector3 = (target_pos - global_position).normalized()
		dir.y = 0
		var dist: float = global_position.distance_to(target_pos)
		if dist < 0.5:
			velocity = velocity.move_toward(Vector3.ZERO, speed * delta)
		else:
			velocity = dir * speed
			_facing_dir = dir
	# Smooth vertical position (float at desired height)
	velocity.y = 0
	move_and_slide()
	# Float at target height with smooth lerp
	var desired_y: float = _cached_player.global_position.y + GameConstants.PET_HEIGHT_OFFSET if _cached_player else GameConstants.PET_HEIGHT_OFFSET
	global_position.y = lerpf(global_position.y, desired_y, 1.0 - exp(-GameConstants.PET_FOLLOW_LERP_SPEED * delta))


# ─── Visuals ──────────────────────────────────────────────────────────────────

func _update_visuals(delta: float) -> void:
	# Bob up/down when idle (follow state)
	if current_state == PetState.FOLLOW and _mesh:
		_bob_phase += delta * GameConstants.PET_BOB_SPEED
		# Only bob if we're not in an idle anim (which may override position)
		_mesh.position.y = 0.5 + sin(_bob_phase) * GameConstants.PET_BOB_AMPLITUDE
	# Rotate mesh to face movement direction (smooth)
	if _mesh and _facing_dir.length_squared() > 0.01:
		var target_angle: float = atan2(_facing_dir.x, _facing_dir.z)
		_mesh.rotation.y = lerp_angle(_mesh.rotation.y, target_angle, 1.0 - exp(-8.0 * delta))
	# Emission pulse for "alive" feel
	if _mat:
		var pulse: float = 0.8 + 0.4 * sin(_bob_phase * 1.5)
		_mat.emission_energy_multiplier = pulse


func _set_state(new_state: int) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	var state_name: String = "follow"
	match new_state:
		PetState.FOLLOW: state_name = "follow"
		PetState.FETCH: state_name = "fetch"
		PetState.ATTACK: state_name = "attack"
		PetState.IDLE_ANIM: state_name = "idle"
	pet_state_changed.emit(state_name)


# ─── Damage / Death ───────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	pet_hp_changed.emit(hp, max_hp)
	# Flash on hit
	if _mat:
		var old_emission: float = _mat.emission_energy_multiplier
		_mat.emission_energy_multiplier = 4.0
		_mat.albedo_color = Color.WHITE
		var tween := create_tween()
		tween.tween_property(_mat, "emission_energy_multiplier", old_emission, 0.2)
		tween.parallel().tween_property(_mat, "albedo_color", _stage_color(), 0.2)
	# Camera shake
	var cam: Node3D = GameManager.camera_rig
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.15)
	if hp <= 0:
		_die()


func _die() -> void:
	is_dead = true
	# Death poof
	ParticleEffects.spawn_death_poof(get_parent(), global_position, _stage_color(), 1.0)
	ParticleEffects.spawn_explosion(get_parent(), global_position, _stage_color(), 30, 0.6)
	GameManager.add_message("🐾 Pet was defeated! It will respawn in 10s...")
	# Respawn timer — re-summon at follow position after delay
	var respawn_tween := create_tween()
	respawn_tween.tween_interval(10.0)
	respawn_tween.tween_callback(_respawn)
	# Hide visuals while "dead"
	if _mesh:
		_mesh.visible = false
	if _glow:
		_glow.visible = false
	if _aura:
		_aura.visible = false
	_set_state(PetState.FOLLOW)


func _respawn() -> void:
	# If the node has been freed or player is gone, don't respawn
	if not is_instance_valid(self):
		return
	is_dead = false
	hp = max_hp
	pet_hp_changed.emit(hp, max_hp)
	if _mesh:
		_mesh.visible = true
		_mesh.scale = Vector3.ZERO
		var tween := create_tween()
		tween.tween_property(_mesh, "scale", Vector3.ONE * _stage_config()["scale"], 0.5) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	if _glow:
		_glow.visible = true
	if _aura:
		_aura.visible = GameConstants.PET_AURA_PARTICLE_COUNTS[stage] > 0
	# Snap to player
	if _cached_player and is_instance_valid(_cached_player):
		global_position = _cached_player.global_position + GameConstants.PET_SPAWN_OFFSET
	ParticleEffects.spawn_materialization(get_parent(), global_position, _stage_color())
	GameManager.add_message("🐾 Pet respawned!")


func _on_player_died() -> void:
	# Pet vanishes when player dies
	ParticleEffects.spawn_death_poof(get_parent(), global_position, _stage_color(), 1.0)
	queue_free()


# ─── Public API ───────────────────────────────────────────────────────────────

func get_stage_name() -> String:
	return GameConstants.PET_STAGE_NAMES[stage]

func get_evolution_pct() -> float:
	if stage == GameConstants.PetStage.BABY:
		return clampf(float(evolution_points) / float(GameConstants.PET_EVOLVE_TO_ADOLESCENT), 0.0, 1.0)
	elif stage == GameConstants.PetStage.ADOLESCENT:
		var base: int = GameConstants.PET_EVOLVE_TO_ADOLESCENT
		var span: int = GameConstants.PET_EVOLVE_TO_ADULT - base
		return clampf(float(evolution_points - base) / float(span), 0.0, 1.0)
	return 1.0