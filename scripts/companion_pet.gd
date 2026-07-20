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
signal pet_path_changed(path: int)            # Phase 27: elemental path locked in
signal pet_emote(emote_id: int)               # Phase 27: emote reaction fired

# ─── State ────────────────────────────────────────────────────────────────────
var stage: int = GameConstants.PetStage.BABY
var evolution_points: int = 0
var hp: int = 30
var max_hp: int = 30
var evolution_path: int = GameConstants.PetPath.PRISMATIC  # Phase 27

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

# ── Phase 27: Path ability state ──
# Per-attacker cooldowns for the Fire aura, slow aura tick timing, etc.
var _fire_aura_cooldowns: Dictionary = {}  # {enemy: cooldown_remaining}
var _ice_aura_tick_timer: float = 0.0
var _nature_regen_tick: float = 0.0
var _void_absorb_checked_this_frame: bool = false

# ── Phase 27: Emote system ──
var _emote_label: Label3D = null
var _emote_timer: float = 0.0       # Time left on current emote
var _emote_cooldown: float = 0.0     # Time before next emote allowed
var _current_emote: int = GameConstants.PetEmote.NONE

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
	_mesh.scale = Vector3(0.001, 0.001, 0.001)
	var tween := create_tween()
	tween.tween_property(_mesh, "scale", Vector3.ONE, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

	# Materialize particle burst
	ParticleEffects.spawn_materialization(get_parent(), global_position, _stage_color())

	# Connect to player death so we can vanish
	GameManager.player_died.connect(_on_player_died)

	# Cache player
	_refresh_player_cache()

	# ── Phase 27: Rebuild accessory visuals when accessories change ──
	if PetAccessorySystem:
		PetAccessorySystem.accessories_changed.connect(_on_accessories_changed)
		PetAccessorySystem.accessory_equipped.connect(_on_accessories_changed)
		PetAccessorySystem.accessory_unequipped.connect(_on_accessories_changed)

	print("[Pet] Companion pet summoned at stage %s" % GameConstants.PET_STAGE_NAMES[stage])


func _on_accessories_changed(_a = null, _b = null) -> void:
	_rebuild_accessory_visuals()


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

	# ── Phase 27: Emote label (floating text above pet's head) ──
	_emote_label = Label3D.new()
	_emote_label.text = ""
	_emote_label.font_size = 32
	_emote_label.outline_size = 8
	_emote_label.outline_modulate = Color(0, 0, 0, 0.8)
	_emote_label.pixel_size = 0.025
	_emote_label.position = Vector3(0, 1.6, 0)
	_emote_label.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_emote_label.no_depth_test = true
	_emote_label.visible = false
	add_child(_emote_label)


# ─── Stage Management ─────────────────────────────────────────────────────────

## Returns the merged stage config: base config overridden by any path-specific
## overrides for the current stage. Missing keys fall back to the base config.
## Also applies Phase 27 accessory + training + fusion stat bonuses on top.
func _stage_config() -> Dictionary:
	var base: Dictionary = GameConstants.PET_STAGE_CONFIG[stage]
	if evolution_path == GameConstants.PetPath.PRISMATIC:
		var merged: Dictionary = base.duplicate(true)
		_apply_bonus_overrides(merged)
		return merged
	# Path overrides only specify the keys they change — merge over the base.
	var path_overrides: Dictionary = GameConstants.PET_PATH_CONFIG[evolution_path][stage]
	# Duplicate the base so we don't mutate the shared constant.
	var merged2: Dictionary = base.duplicate(true)
	for key in path_overrides.keys():
		merged2[key] = path_overrides[key]
	_apply_bonus_overrides(merged2)
	return merged2


## Apply Phase 27 accessory, training, and fusion stat bonuses on top of the
## stage config dictionary (mutates it in place).
func _apply_bonus_overrides(cfg: Dictionary) -> void:
	# Accessory bonuses
	if PetAccessorySystem:
		var speed_mult: float = PetAccessorySystem.get_stat_bonus("pet_speed_mult")
		if speed_mult != 1.0 and cfg.has("speed"):
			cfg["speed"] = float(cfg["speed"]) * speed_mult
		var collect_bonus: float = PetAccessorySystem.get_stat_bonus("pet_collect_radius")
		if collect_bonus > 0.0 and cfg.has("collect_radius"):
			cfg["collect_radius"] = float(cfg["collect_radius"]) + collect_bonus
		var dmg_red: float = PetAccessorySystem.get_stat_bonus("pet_damage_reduction")
		if dmg_red > 0.0 and cfg.has("shield_reduction"):
			cfg["shield_reduction"] = float(cfg["shield_reduction"]) + dmg_red
		var atk_dmg_bonus: float = PetAccessorySystem.get_stat_bonus("pet_attack_damage")
		if atk_dmg_bonus > 0.0 and cfg.has("attack_damage"):
			cfg["attack_damage"] = int(cfg["attack_damage"]) + int(atk_dmg_bonus)
		var atk_range_bonus: float = PetAccessorySystem.get_stat_bonus("pet_attack_range")
		if atk_range_bonus > 0.0 and cfg.has("attack_range"):
			cfg["attack_range"] = float(cfg["attack_range"]) + atk_range_bonus
		var atk_cd_mult: float = PetAccessorySystem.get_stat_bonus("pet_attack_cooldown_mult")
		if atk_cd_mult != 1.0 and atk_cd_mult > 0 and cfg.has("attack_cooldown"):
			cfg["attack_cooldown"] = float(cfg["attack_cooldown"]) * atk_cd_mult
	# Training bonuses
	if PetTrainingSystem:
		var train_atk: float = PetTrainingSystem.get_stat_bonus("attack_damage")
		if train_atk > 0.0 and cfg.has("attack_damage"):
			cfg["attack_damage"] = int(cfg["attack_damage"]) + int(train_atk)
		var train_speed: float = PetTrainingSystem.get_stat_bonus("move_speed")
		if train_speed > 0.0 and cfg.has("speed"):
			cfg["speed"] = float(cfg["speed"]) + train_speed
		var train_collect: float = PetTrainingSystem.get_stat_bonus("collect_radius")
		if train_collect > 0.0 and cfg.has("collect_radius"):
			cfg["collect_radius"] = float(cfg["collect_radius"]) + train_collect

func _stage_color() -> Color:
	return _stage_config()["color"]

func _stage_emission() -> Color:
	return _stage_config()["emission"]

func _ability_name() -> String:
	var cfg: Dictionary = _stage_config()
	return cfg.get("ability_label", "")

func _apply_stage_config() -> void:
	var cfg: Dictionary = _stage_config()
	# ── Phase 27: Fusion pet override ──
	var fusion_cfg: Dictionary = {}
	if has_meta("is_fusion_pet") and PetFusionSystem:
		fusion_cfg = PetFusionSystem.get_fusion_override(self)
	# Merge fusion overrides into cfg
	if not fusion_cfg.is_empty():
		for key in fusion_cfg:
			cfg[key] = fusion_cfg[key]
	# Mesh scale
	if _mesh:
		_mesh.scale = Vector3.ONE * cfg["scale"]
	# Material colors — path overrides replace both albedo and emission
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
	# HP — with accessory + training bonuses
	var base_hp: int = cfg["hp"]
	if PetAccessorySystem:
		base_hp = int(round(float(base_hp) * PetAccessorySystem.get_stat_bonus("pet_hp_mult")))
	if PetTrainingSystem:
		base_hp += int(PetTrainingSystem.get_stat_bonus("max_hp"))
	max_hp = base_hp
	hp = min(hp, max_hp)  # Don't exceed new max
	pet_hp_changed.emit(hp, max_hp)
	# ── Phase 27: Rebuild accessory visuals on stage change ──
	_rebuild_accessory_visuals()


## Feed the pet a collectible, granting evolution points. Triggers evolution
## when the threshold for the next stage is reached. If the collectible is an
## evolution stone, the pet's elemental path is locked in (or changed).
func feed(collectible_type: int) -> void:
	# ── Phase 27: Evolution stones lock in a path before awarding points ──
	if GameConstants.PET_STONE_TO_PATH.has(collectible_type):
		var new_path: int = GameConstants.PET_STONE_TO_PATH[collectible_type]
		if evolution_path != new_path:
			_set_path(new_path)
	var value: int = GameConstants.PET_FEED_VALUES.get(collectible_type, 5)
	# ── Phase 35: Balance pass — slightly more generous pet evolution ──
	if BalanceManager and BalanceManager.is_initialized():
		value = BalanceManager.get_evolution_points(value)
	evolution_points += value
	# Heal the pet slightly per pickup
	hp = min(max_hp, hp + int(GameConstants.PET_HEAL_PER_PICKUP))
	pet_hp_changed.emit(hp, max_hp)
	_check_evolution()
	_emit_progress()
	# ── Phase 25: Statistics tracking — record pet feeding ──
	if Statistics:
		Statistics.record_pet_feeding()
	# ── Phase 27: Happy emote on feed ──
	_trigger_emote(GameConstants.PetEmote.HAPPY)


## Lock in (or change) the pet's elemental evolution path. Re-applies the
## stage config so colors/abilities update immediately. Fires the
## pet_path_changed signal and a burst of particles in the new path color.
func _set_path(new_path: int) -> void:
	evolution_path = new_path
	_apply_stage_config()
	pet_path_changed.emit(new_path)
	# Path-lock particle burst
	ParticleEffects.spawn_combo_fireworks(get_parent(), global_position, new_path + 1)
	ParticleEffects.spawn_pickup_sparkle(get_parent(), global_position + Vector3(0, 1, 0), _stage_color())
	# Evolution scale punch (same as stage evolution)
	if _mesh:
		var punch := create_tween()
		punch.tween_property(_mesh, "scale", Vector3.ONE * _stage_config()["scale"] * 1.6, 0.18) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		punch.tween_property(_mesh, "scale", Vector3.ONE * _stage_config()["scale"], 0.3) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	var path_name: String = GameConstants.PET_PATH_NAMES[new_path]
	GameManager.add_message("✨ Pet path locked: %s!" % path_name)
	# Emote: LOVE on path change (it's exciting!)
	_trigger_emote(GameConstants.PetEmote.LOVE)
	print("[Pet] Path set to %s" % path_name)


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
	GameManager.add_message("✨ Pet evolved to %s!%s" % [
		GameConstants.PET_STAGE_NAMES[stage],
		" (%s)" % GameConstants.PET_PATH_NAMES[evolution_path] if evolution_path != GameConstants.PetPath.PRISMATIC else ""
	])
	# ── Phase 27: LOVE emote on evolution ──
	_trigger_emote(GameConstants.PetEmote.LOVE)
	print("[Pet] Evolved to %s (points=%d, path=%s)" % [
		GameConstants.PET_STAGE_NAMES[stage], evolution_points,
		GameConstants.PET_PATH_NAMES[evolution_path]
	])


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
	# ── Phase 27: Path passive abilities ──
	_tick_path_abilities(delta)

	# Idle animation random trigger (only when following and idle)
	if current_state == PetState.FOLLOW:
		_idle_anim_timer -= delta
		if _idle_anim_timer <= 0:
			_idle_anim_timer = GameConstants.PET_IDLE_ANIMATION_INTERVAL + randf() * 3.0
			if randf() < 0.4:
				_start_idle_anim()

	# Visual bob + facing
	_update_visuals(delta)

	# ── Phase 27: Emote timer ──
	_update_emote(delta)


func _refresh_player_cache() -> void:
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player") as CharacterBody3D


# ─── Follow State ─────────────────────────────────────────────────────────────

func _update_follow(delta: float) -> void:
	var player: CharacterBody3D = _cached_player
	var cfg: Dictionary = _stage_config()
	var follow_dist: float = cfg["follow_distance"]
	# Position to follow: behind-right of player, at PET_HEIGHT_OFFSET
	var height_off: float = GameConstants.PET_HEIGHT_OFFSET
	# ── Phase 27: Glider Wings — pet floats higher ──
	if PetAccessorySystem and PetAccessorySystem.get_equipped_in_slot(1) == GameConstants.PetAccessory.WINGS_GLIDER:
		height_off += 2.0
	var target_pos: Vector3 = player.global_position + Vector3(2.0, height_off, 0.0)
	# If player is moving, offset toward the direction they came from (trailing)
	if player.velocity.length_squared() > 1.0:
		var trail_dir: Vector3 = -player.velocity.normalized()
		trail_dir.y = 0
		target_pos = player.global_position + trail_dir * follow_dist + Vector3(0, height_off, 0)
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
	# ── Phase 27: Fire & Void paths use ranged attacks at Adolescent+ ──
	# Move into range first, then fire a projectile instead of melee.
	var is_ranged_path: bool = (
		evolution_path == GameConstants.PetPath.FIRE
		or evolution_path == GameConstants.PetPath.VOID
	)
	var effective_range: float = cfg["attack_range"]
	if is_ranged_path:
		effective_range = cfg["attack_range"] * 0.9  # Stop a bit short to fire
	# Move toward the enemy
	if d > effective_range * 0.6:
		_move_toward(enemy.global_position + Vector3(0, 0.5, 0), cfg["speed"] * 1.2, delta)
		return
	# In range — attack
	if _attack_cooldown_timer <= 0:
		_attack_cooldown_timer = cfg["attack_cooldown"]
		var dmg: int = cfg["attack_damage"]
		# ── Phase 27: Ranged attack for Fire/Void paths ──
		if is_ranged_path:
			_fire_pet_projectile(enemy, dmg, cfg)
		else:
			# Melee attack (default + Ice shard + Electric + Nature vine)
			if enemy.has_method("take_damage_from"):
				enemy.take_damage_from(dmg, global_position)
			elif enemy.has_method("take_damage"):
				enemy.take_damage(dmg)
			# ── Phase 27: Ice shard slows the target on hit ──
			if evolution_path == GameConstants.PetPath.ICE:
				_apply_ice_shard_slow(enemy)
			# ── Phase 27: Electric chain zap on melee hit ──
			if evolution_path == GameConstants.PetPath.ELECTRIC:
				_electric_chain_zap(enemy, dmg)
			# ── Phase 27: Fusion pet — apply second path's on-hit effect too ──
			if has_meta("is_fusion_pet") and has_meta("fusion_paths"):
				var fpaths: Array = get_meta("fusion_paths", [])
				if fpaths.size() >= 2 and fpaths[1] != evolution_path:
					match fpaths[1]:
						GameConstants.PetPath.ICE:
							_apply_ice_shard_slow(enemy)
						GameConstants.PetPath.ELECTRIC:
							_electric_chain_zap(enemy, dmg)
		# Visual pop on attack
		if _mesh:
			var pop := create_tween()
			pop.tween_property(_mesh, "scale", Vector3.ONE * cfg["scale"] * 1.4, 0.1) \
				.set_ease(Tween.EASE_OUT)
			pop.tween_property(_mesh, "scale", Vector3.ONE * cfg["scale"], 0.15) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		# Small sparkle
		ParticleEffects.spawn_pickup_sparkle(get_parent(), enemy.global_position + Vector3(0, 1, 0), _stage_color())


# ── Phase 27: Ranged pet projectile (Fire fireball / Void bolt) ──
# Spawns a simple Area3D bolt that travels toward the target and deals damage
# on contact. Void bolts pierce 1 enemy; fireballs explode on impact.
func _fire_pet_projectile(target: Node3D, dmg: int, cfg: Dictionary) -> void:
	var parent: Node = get_parent()
	if not parent:
		return
	var bolt := Area3D.new()
	bolt.name = "PetProjectile"
	bolt.collision_layer = 16  # Pet projectile layer (doesn't collide with player)
	bolt.collision_mask = 2    # Hit enemies
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	col.shape = shape
	bolt.add_child(col)
	# Visual mesh
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	sphere.radial_segments = 8
	sphere.rings = 4
	mesh_inst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.albedo_color = _stage_color()
	mat.emission = _stage_emission()
	mat.emission_energy_multiplier = 2.0
	mesh_inst.material_override = mat
	bolt.add_child(mesh_inst)
	# Glow light
	var light := OmniLight3D.new()
	light.light_color = _stage_emission()
	light.light_energy = 1.5
	light.omni_range = 3.0
	bolt.add_child(light)
	parent.add_child(bolt)
	bolt.global_position = global_position + Vector3(0, 0.5, 0)
	# Aim at target
	var target_pos: Vector3 = target.global_position + Vector3(0, 0.5, 0)
	var dir: Vector3 = (target_pos - bolt.global_position).normalized()
	var speed: float = GameConstants.PET_FIREBALL_SPEED if evolution_path == GameConstants.PetPath.FIRE else 22.0
	var pierce: int = GameConstants.PET_VOID_BOLT_PIERCE if evolution_path == GameConstants.PetPath.VOID else 0
	# Store metadata for the bolt's _process
	bolt.set_meta("pet_proj_dir", dir)
	bolt.set_meta("pet_proj_speed", speed)
	bolt.set_meta("pet_proj_damage", dmg)
	bolt.set_meta("pet_proj_pierce_left", pierce)
	bolt.set_meta("pet_proj_path", evolution_path)
	bolt.set_meta("pet_proj_owner", self)
	bolt.set_meta("pet_proj_lifetime", GameConstants.PET_FIREBALL_LIFETIME)
	bolt.set_meta("pet_proj_hit_enemies", [])  # Track to avoid double-hits
	# Attach a small script-like behavior via _process on a helper node
	# We use a tween + body_entered signal for simplicity
	bolt.body_entered.connect(_on_pet_proj_body_entered.bind(bolt))
	# Movement tween — we'll drive position manually via a per-frame process
	# using a one-shot Timer + tween_method for smooth motion.
	var tween := bolt.create_tween()
	tween.set_loops(int(GameConstants.PET_FIREBALL_LIFETIME * 60))  # ~60fps for 2s
	tween.tween_method(_advance_pet_proj.bind(bolt), 0.0, 1.0, 1.0 / 60.0)
	# Lifetime expiry
	var life_timer := bolt.create_tween()
	life_timer.tween_interval(GameConstants.PET_FIREBALL_LIFETIME)
	life_timer.tween_callback(bolt.queue_free)


# Per-frame advance for pet projectile (called via tween_method)
func _advance_pet_proj(_t: float, bolt: Area3D) -> void:
	if not is_instance_valid(bolt):
		return
	var dir: Vector3 = bolt.get_meta("pet_proj_dir", Vector3.FORWARD)
	var speed: float = bolt.get_meta("pet_proj_speed", 18.0)
	bolt.global_position += dir * speed * (1.0 / 60.0)
	# Spin the mesh for visual flair
	var mesh_inst: Node = bolt.get_child_or_null(1)  # MeshInstance3D
	if mesh_inst and mesh_inst is MeshInstance3D:
		mesh_inst.rotation.y += 0.3


# Body entered callback for pet projectile
func _on_pet_proj_body_entered(body: Node3D, bolt: Area3D) -> void:
	if not is_instance_valid(bolt):
		return
	if not body.is_in_group("enemies"):
		# Hit terrain — fireball explodes, void bolt just fizzles
		if evolution_path == GameConstants.PetPath.FIRE:
			_pet_proj_explode(bolt)
		bolt.queue_free()
		return
	# Hit an enemy
	var dmg: int = bolt.get_meta("pet_proj_damage", 10)
	if body.has_method("take_damage_from"):
		body.take_damage_from(dmg, bolt.global_position)
	elif body.has_method("take_damage"):
		body.take_damage(dmg)
	# Sparkle on hit
	ParticleEffects.spawn_pickup_sparkle(get_parent(), body.global_position + Vector3(0, 1, 0), _stage_color())
	# Track hit enemies to avoid double-hits on pierce
	var hit: Array = bolt.get_meta("pet_proj_hit_enemies", [])
	if not hit.has(body):
		hit.append(body)
		bolt.set_meta("pet_proj_hit_enemies", hit)
	# Fire path: explode on impact. Void path: pierce if pierce_left > 0.
	if evolution_path == GameConstants.PetPath.FIRE:
		_pet_proj_explode(bolt)
		bolt.queue_free()
		return
	var pierce_left: int = bolt.get_meta("pet_proj_pierce_left", 0)
	if pierce_left <= 0:
		bolt.queue_free()
	else:
		bolt.set_meta("pet_proj_pierce_left", pierce_left - 1)


# Fire path explosion: small AoE damage + particles
func _pet_proj_explode(bolt: Area3D) -> void:
	if not is_instance_valid(bolt):
		return
	var pos: Vector3 = bolt.global_position
	# AoE damage to nearby enemies
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_method("take_damage_from") and not enemy.has_method("take_damage"):
			continue
		var d: float = pos.distance_to(enemy.global_position)
		if d < 3.0:
			if enemy.has_method("take_damage_from"):
				enemy.take_damage_from(int(GameConstants.PET_FIREBALL_DAMAGE * 0.5), pos)
			elif enemy.has_method("take_damage"):
				enemy.take_damage(int(GameConstants.PET_FIREBALL_DAMAGE * 0.5))
	# Explosion particles
	ParticleEffects.spawn_explosion(get_parent(), pos, _stage_color(), 20, 0.5)
	# Light flash
	var flash := OmniLight3D.new()
	flash.light_color = _stage_emission()
	flash.light_energy = 3.0
	flash.omni_range = 5.0
	get_parent().add_child(flash)
	flash.global_position = pos
	var fade := flash.create_tween()
	fade.tween_property(flash, "light_energy", 0.0, 0.2)
	fade.tween_callback(flash.queue_free)


# ── Phase 27: Ice shard slow on hit ──
func _apply_ice_shard_slow(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return
	# Apply a slow via the enemy's _time_scale if it has one, or via a meta flag
	# that enemy_base.gd checks. We use a temporary slow timer via meta.
	if "set_time_scale" in enemy:
		enemy.set_time_scale(0.5)
		# Restore after duration via a scene-tree timer (survives pet death)
		var restore_timer := get_tree().create_timer(GameConstants.PET_ICE_SHARD_SLOW_DURATION)
		restore_timer.timeout.connect(func():
			if is_instance_valid(enemy) and "set_time_scale" in enemy:
				enemy.set_time_scale(1.0)
		)
	# Small ice particle burst
	ParticleEffects.spawn_pickup_sparkle(get_parent(), enemy.global_position + Vector3(0, 1, 0), Color(0.4, 0.75, 1.0))


# ── Phase 27: Electric chain zap ──
func _electric_chain_zap(primary_target: Node3D, base_dmg: int) -> void:
	if not is_instance_valid(primary_target):
		return
	var chain_count: int = GameConstants.PET_ELECTRIC_CHAIN_COUNT
	var chain_range: float = GameConstants.PET_ELECTRIC_CHAIN_RANGE
	var chain_dmg: int = GameConstants.PET_ELECTRIC_CHAIN_DAMAGE
	var hit: Array[Node3D] = [primary_target]
	var current: Node3D = primary_target
	for i in range(chain_count):
		var next: Node3D = null
		var next_dist: float = chain_range
		for enemy in GameManager.enemies:
			if not is_instance_valid(enemy):
				continue
			if hit.has(enemy):
				continue
			if not enemy.has_method("take_damage_from") and not enemy.has_method("take_damage"):
				continue
			var d: float = current.global_position.distance_to(enemy.global_position)
			if d < next_dist:
				next_dist = d
				next = enemy
		if next == null:
			break
		# Zap the next enemy
		if next.has_method("take_damage_from"):
			next.take_damage_from(chain_dmg, current.global_position)
		elif next.has_method("take_damage"):
			next.take_damage(chain_dmg)
		# Electric arc particle between current and next
		ParticleEffects.spawn_pickup_sparkle(get_parent(), next.global_position + Vector3(0, 1, 0), Color(1.0, 0.9, 0.2))
		hit.append(next)
		current = next


# ─── Phase 27: Path Passive Abilities ──────────────────────────────────────────

## Tick per-frame path passive abilities. Called every _physics_process.
func _tick_path_abilities(delta: float) -> void:
	if evolution_path == GameConstants.PetPath.PRISMATIC:
		return
	var ability: String = _stage_config().get("ability", "")
	match ability:
		"ember_aura":
			_tick_fire_aura(delta)
		"frost_aura":
			_tick_ice_aura(delta)
		"static_field":
			pass  # Electric passive only triggers on attack (handled in _update_attack)
		"void_veil":
			pass  # Void projectile absorb is event-driven (see absorb_enemy_projectile)
		"bloom":
			_tick_nature_bloom(delta)
	# ── Phase 27: Fusion pet — tick the second donor's ability too ──
	if has_meta("is_fusion_pet") and has_meta("fusion_paths"):
		var paths: Array = get_meta("fusion_paths", [])
		if paths.size() >= 2 and paths[1] != evolution_path:
			var second_path: int = paths[1]
			match second_path:
				GameConstants.PetPath.FIRE:
					_tick_fire_aura(delta)
				GameConstants.PetPath.ICE:
					_tick_ice_aura(delta)
				GameConstants.PetPath.NATURE:
					_tick_nature_bloom(delta)
				# Electric and Void are event-driven (attack/on-hit), not per-tick
		_tick_fusion_special(delta)


# ── Phase 27: Fusion pet special ability — periodic steam/plasma AoE ──
# Fusion pets emit a small AoE pulse every ~5 seconds that damages nearby enemies.
# This represents the combined elemental energy overflowing.
func _tick_fusion_special(delta: float) -> void:
	if not has_meta("is_fusion_pet"):
		return
	if not has_meta("fusion_type"):
		return
	var ft: int = get_meta("fusion_type", 0)
	if ft == GameConstants.PetFusionType.NONE:
		return
	# Use a meta timer for the pulse cooldown
	var pulse_timer: float = get_meta("fusion_pulse_timer", 5.0)
	pulse_timer -= delta
	if pulse_timer > 0.0:
		set_meta("fusion_pulse_timer", pulse_timer)
		return
	set_meta("fusion_pulse_timer", 5.0)  # Reset to 5 second cooldown
	# Emit a small AoE pulse damaging nearby enemies within 4m
	var pulse_dmg: int = 8
	var pulse_color: Color = GameConstants.PET_FUSION_EMISSIONS[ft]
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_method("take_damage_from") and not enemy.has_method("take_damage"):
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < 4.0:
			if enemy.has_method("take_damage_from"):
				enemy.take_damage_from(pulse_dmg, global_position)
			elif enemy.has_method("take_damage"):
				enemy.take_damage(pulse_dmg)
	# Visual pulse
	ParticleEffects.spawn_explosion(get_parent(), global_position, pulse_color, 15, 0.3)


# Fire Aura: any enemy that touches the pet (within PET_FIRE_AURA_RANGE) takes
# fire damage, with a per-enemy cooldown. Also applies a burn DoT via a tween
# bound to the enemy (same pattern as Blaze Trail weapon mod).
func _tick_fire_aura(delta: float) -> void:
	# Decrement cooldowns
	var to_remove: Array = []
	for enemy in _fire_aura_cooldowns.keys():
		var cd: float = _fire_aura_cooldowns[enemy]
		cd -= delta
		if cd <= 0.0:
			to_remove.append(enemy)
		else:
			_fire_aura_cooldowns[enemy] = cd
	for enemy in to_remove:
		_fire_aura_cooldowns.erase(enemy)
	# Check enemies in range
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			_fire_aura_cooldowns.erase(enemy)
			continue
		if _fire_aura_cooldowns.has(enemy):
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < GameConstants.PET_FIRE_AURA_RANGE:
			# Apply fire damage
			if enemy.has_method("take_damage_from"):
				enemy.take_damage_from(GameConstants.PET_FIRE_AURA_DAMAGE, global_position)
			elif enemy.has_method("take_damage"):
				enemy.take_damage(GameConstants.PET_FIRE_AURA_DAMAGE)
			# Apply burn DoT via a tween bound to the enemy (survives pet death)
			_apply_burn_dot(enemy, GameConstants.PET_FIRE_AURA_DAMAGE)
			_fire_aura_cooldowns[enemy] = GameConstants.PET_FIRE_AURA_COOLDOWN
			# Small flame particle
			ParticleEffects.spawn_pickup_sparkle(get_parent(), enemy.global_position + Vector3(0, 0.5, 0), Color(1.0, 0.4, 0.1))


# Apply a burn DoT to an enemy via a tween bound to the enemy (not the pet).
# This ensures the burn continues even if the pet dies or is dismissed.
func _apply_burn_dot(enemy: Node3D, base_dmg: int) -> void:
	if not is_instance_valid(enemy):
		return
	if not enemy.has_method("take_damage") and not enemy.has_method("take_damage_from"):
		return
	var burn_dmg: int = max(1, int(base_dmg * 0.5))
	var ticks: int = int(GameConstants.PET_FIRE_AURA_DOT_DURATION)
	var tw := enemy.create_tween()
	tw.tween_interval(1.0)
	for _i in range(ticks):
		tw.tween_callback(func():
			if is_instance_valid(enemy):
				if enemy.has_method("take_damage"):
					enemy.take_damage(burn_dmg)
				elif enemy.has_method("take_damage_from"):
					enemy.take_damage_from(burn_dmg, enemy.global_position)
				ParticleEffects.spawn_explosion(enemy.get_parent(), enemy.global_position, Color(1.0, 0.5, 0.2), 6, 0.2)
		)
		tw.tween_interval(1.0)


# Ice Aura: enemies within PET_ICE_AURA_RANGE are slowed. We apply the slow
# via the enemy's _time_scale (if it has one) every tick, with a smooth
# falloff toward the aura edge.
func _tick_ice_aura(delta: float) -> void:
	_ice_aura_tick_timer -= delta
	if _ice_aura_tick_timer > 0:
		return
	_ice_aura_tick_timer = 0.2  # Re-apply every 0.2s
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		if not ("set_time_scale" in enemy):
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < GameConstants.PET_ICE_AURA_RANGE:
			# Smooth falloff: at center apply full slow, at edge apply 1.0
			var t: float = 1.0 - (d / GameConstants.PET_ICE_AURA_RANGE)
			var slow_mult: float = lerpf(1.0, GameConstants.PET_ICE_AURA_SLOW_MULT, t)
			enemy.set_time_scale(slow_mult)
		else:
			# Restore to 1.0 if outside (only if we were slowing it)
			if enemy.get_meta("pet_ice_slow_active", false):
				enemy.set_time_scale(1.0)
				enemy.set_meta("pet_ice_slow_active", false)
		# Mark enemies we're actively slowing
		if d < GameConstants.PET_ICE_AURA_RANGE:
			enemy.set_meta("pet_ice_slow_active", true)


# Nature Bloom: regenerate the player's HP when within range. Tick-based.
func _tick_nature_bloom(delta: float) -> void:
	if not _cached_player or not is_instance_valid(_cached_player):
		return
	_nature_regen_tick += delta
	if _nature_regen_tick < 1.0:  # 1 HP per second
		return
	_nature_regen_tick = 0.0
	var d: float = global_position.distance_to(_cached_player.global_position)
	if d < GameConstants.PET_NATURE_REGEN_RANGE:
		# Only regen if player is below max HP
		if GameManager.player_hp < GameManager.player_max_hp:
			GameManager.heal(int(GameConstants.PET_NATURE_REGEN_PER_SEC))
			# Small green sparkle on player
			ParticleEffects.spawn_pickup_sparkle(get_parent(), _cached_player.global_position + Vector3(0, 1.5, 0), Color(0.3, 0.8, 0.35))


# ── Phase 27: Void Veil — try to absorb an incoming enemy projectile ──
# Called by the player's take_damage path (or the enemy projectile) before
# damage is applied. Returns true if the projectile was absorbed.
func try_absorb_projectile(projectile_pos: Vector3) -> bool:
	if evolution_path != GameConstants.PetPath.VOID:
		# ── Phase 27: Fusion pet — second path might be Void ──
		if has_meta("is_fusion_pet") and has_meta("fusion_paths"):
			var fpaths: Array = get_meta("fusion_paths", [])
			if not (fpaths.size() >= 2 and fpaths[1] == GameConstants.PetPath.VOID):
				return false
		else:
			return false
	if stage < GameConstants.PetStage.ADOLESCENT:
		return false  # Void Veil only active at Adolescent+
	# Only absorb if the projectile is near the pet
	if global_position.distance_to(projectile_pos) > 3.0:
		return false
	if randf() < GameConstants.PET_VOID_VEIL_ABSORB_CHANCE:
		# Absorbed! Small void particle effect
		ParticleEffects.spawn_pickup_sparkle(get_parent(), projectile_pos, Color(0.3, 0.1, 0.45))
		return true
	return false


# ─── Phase 27: Emote System ───────────────────────────────────────────────────

## Trigger a pet emote (visual reaction). Respects cooldown so emotes don't
## spam. Emotes show as a floating Label3D above the pet's head + a small
## color flash on the pet's material.
func _trigger_emote(emote_id: int) -> void:
	if emote_id == GameConstants.PetEmote.NONE:
		return
	if _emote_cooldown > 0.0:
		return  # On cooldown
	if not _emote_label:
		return
	_current_emote = emote_id
	_emote_timer = GameConstants.PET_EMOTE_DURATION
	_emote_cooldown = GameConstants.PET_EMOTE_COOLDOWN
	# Set label text + color
	_emote_label.text = GameConstants.PET_EMOTE_TEXTS[emote_id]
	_emote_label.modulate = GameConstants.PET_EMOTE_COLORS[emote_id]
	_emote_label.visible = true
	# Pop-in scale animation
	_emote_label.scale = Vector3.ONE * 0.001
	var pop := create_tween()
	pop.tween_property(_emote_label, "scale", Vector3.ONE * GameConstants.PET_EMOTE_SCALE_POP, 0.12) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	pop.tween_property(_emote_label, "scale", Vector3.ONE, 0.18) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	# Small material flash in the emote color
	if _mat:
		var old_emission: float = _mat.emission_energy_multiplier
		_mat.emission_energy_multiplier = 3.0
		var flash := create_tween()
		flash.tween_property(_mat, "emission_energy_multiplier", old_emission, 0.3)
	# Emit signal for HUD integration
	pet_emote.emit(emote_id)


## Per-frame emote update — countdown timers and hide when expired.
func _update_emote(delta: float) -> void:
	if _emote_cooldown > 0.0:
		_emote_cooldown -= delta
	if _emote_timer > 0.0:
		_emote_timer -= delta
		if _emote_timer <= 0.0:
			# Hide the emote
			if _emote_label:
				_emote_label.visible = false
				_emote_label.text = ""
			_current_emote = GameConstants.PetEmote.NONE


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
	# ── Phase 27: Hover Wings accessory — pet continues collecting while the
	#    player dashes. Without Hover Wings, the pet pauses collection during
	#    dash (the pet is zooming along and can't vacuum effectively). ──
	if _cached_player and is_instance_valid(_cached_player):
		var player_dashing: bool = bool(_cached_player.get("is_dashing")) if "is_dashing" in _cached_player else false
		if player_dashing:
			if not PetAccessorySystem or PetAccessorySystem.get_stat_bonus("hover_collect_while_dash") < 1.0:
				return  # Pet can't collect during dash without Hover Wings
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
	# ── Phase 27: Accessory damage reduction (Plated Armor) ──
	var actual_amount: int = amount
	if PetAccessorySystem:
		var reduction: float = PetAccessorySystem.get_stat_bonus("pet_damage_reduction")
		if reduction > 0.0:
			actual_amount = int(round(float(amount) * (1.0 - reduction)))
	hp = max(0, hp - actual_amount)
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
	# ── Phase 27: Spiked Armor reflect damage ──
	if PetAccessorySystem and PetAccessorySystem.has_spiked_armor():
		# Find the nearest enemy and reflect damage
		var nearest: Node3D = null
		var nearest_dist: float = 5.0
		for enemy in GameManager.enemies:
			if not is_instance_valid(enemy):
				continue
			var d: float = global_position.distance_to(enemy.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = enemy
		if nearest and nearest.has_method("take_damage_from"):
			nearest.take_damage_from(GameConstants.PET_ACCESSORY_SPIKE_REFLECT_DAMAGE, global_position)
			ParticleEffects.spawn_pickup_sparkle(get_parent(), nearest.global_position + Vector3(0, 1, 0), Color(1.0, 0.3, 0.1))
	# ── Phase 27: SCARED emote on taking damage ──
	_trigger_emote(GameConstants.PetEmote.SCARED)
	if hp <= 0:
		_die()


func _die() -> void:
	is_dead = true
	# Death poof
	ParticleEffects.spawn_death_poof(get_parent(), global_position, _stage_color(), 1.0)
	ParticleEffects.spawn_explosion(get_parent(), global_position, _stage_color(), 30, 0.6)
	GameManager.add_message("🐾 Pet was defeated! It will respawn in 10s...")
	# ── Phase 27: Clean up path ability effects on death ──
	_cleanup_path_effects()
	# ── Phase 27: Notify fusion system if this was a fusion pet ──
	if has_meta("is_fusion_pet") and PetFusionSystem:
		PetFusionSystem.on_fusion_pet_died()
		GameManager.add_message("💀 The fusion pet is gone for this run!")
		# Fusion pets don't respawn — actually die
		queue_free()
		return
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


## Clean up any active path ability effects (ice slows on enemies, etc.)
## Called when the pet dies or is dismissed.
func _cleanup_path_effects() -> void:
	# Restore time_scale on any enemies we were slowing with the Ice aura
	if evolution_path == GameConstants.PetPath.ICE:
		for enemy in GameManager.enemies:
			if not is_instance_valid(enemy):
				continue
			if not ("set_time_scale" in enemy):
				continue
			if enemy.get_meta("pet_ice_slow_active", false):
				enemy.set_time_scale(1.0)
				enemy.set_meta("pet_ice_slow_active", false)
	# Clear fire aura cooldowns
	_fire_aura_cooldowns.clear()
	# Hide emote
	if _emote_label:
		_emote_label.visible = false
		_emote_label.text = ""
	_current_emote = GameConstants.PetEmote.NONE


func _respawn() -> void:
	# If the node has been freed or player is gone, don't respawn
	if not is_instance_valid(self):
		return
	is_dead = false
	hp = max_hp
	pet_hp_changed.emit(hp, max_hp)
	if _mesh:
		_mesh.visible = true
		_mesh.scale = Vector3(0.001, 0.001, 0.001)
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
	# ── Phase 27: Clean up path ability effects before freeing ──
	_cleanup_path_effects()
	ParticleEffects.spawn_death_poof(get_parent(), global_position, _stage_color(), 1.0)
	queue_free()


# ─── Phase 27: Pet Accessory Visuals ──────────────────────────────────────────

## Rebuild the accessory visual meshes on the pet. Called on stage change and
## when accessories are equipped/unequipped. Removes old accessory children and
## adds new ones for the currently equipped accessories.
func _rebuild_accessory_visuals() -> void:
	# Remove existing accessory visual children
	for child in get_children():
		if child is MeshInstance3D and child.get_meta("is_accessory_visual", false):
			child.queue_free()
	# If we have no mesh yet (early in _ready), skip
	if not _mesh:
		return
	# Add visuals for each equipped accessory
	if not PetAccessorySystem:
		return
	for slot_id in PetAccessorySystem.get_all_equipped():
		if slot_id == GameConstants.PetAccessory.NONE:
			continue
		var visual_kind: int = GameConstants.PET_ACCESSORY_VISUAL[slot_id]
		if visual_kind == 0:
			continue
		_add_accessory_mesh(visual_kind, slot_id)


func _add_accessory_mesh(visual_kind: int, accessory_id: int) -> void:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.set_meta("is_accessory_visual", true)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	# Color by accessory type
	var acc_color: Color = Color(0.8, 0.7, 0.3)  # default gold-ish
	if accessory_id > GameConstants.PetAccessory.NONE and accessory_id < GameConstants.PET_ACCESSORY_COUNT:
		# Use a distinct color per slot type
		match GameConstants.PET_ACCESSORY_SLOT[accessory_id]:
			0: acc_color = Color(0.7, 0.5, 0.2)  # Collar — brown/gold
			1: acc_color = Color(0.9, 0.9, 1.0)  # Wings — white
			2: acc_color = Color(0.6, 0.6, 0.7)  # Armor — steel grey
			3: acc_color = Color(0.9, 0.4, 0.6)  # Bow — pink
			4: acc_color = Color(1.0, 0.85, 0.2) # Crown — gold
	mat.albedo_color = acc_color
	mat.emission = acc_color * 0.5
	mat.emission_energy_multiplier = 0.8
	mesh_inst.material_override = mat
	match visual_kind:
		1:  # Collar — torus around neck
			var torus := TorusMesh.new()
			torus.major_radius = 0.55 * _stage_config().get("scale", 0.5)
			torus.minor_radius = 0.06
			mesh_inst.mesh = torus
			mesh_inst.position.y = 0.5
			mesh_inst.rotation.x = PI / 2
		2:  # Wings — two box meshes on the sides
			# We use a single mesh inst with a combined mesh; simpler: just two boxes
			var box := BoxMesh.new()
			box.size = Vector3(0.6, 0.3, 0.08)
			mesh_inst.mesh = box
			mesh_inst.position.y = 0.7
			mesh_inst.position.x = 0.5 * _stage_config().get("scale", 0.5)
			mesh_inst.rotation.z = deg_to_rad(20)
		3:  # Armor — cylinder shell around body
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.6 * _stage_config().get("scale", 0.5)
			cyl.bottom_radius = 0.6 * _stage_config().get("scale", 0.5)
			cyl.height = 0.5
			mesh_inst.mesh = cyl
			mesh_inst.position.y = 0.5
		4:  # Bow — small box on top
			var bow := BoxMesh.new()
			bow.size = Vector3(0.3, 0.2, 0.08)
			mesh_inst.mesh = bow
			mesh_inst.position.y = 1.0 * _stage_config().get("scale", 0.5)
		5:  # Crown — cone on top of head (cylinder with top_radius=0)
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.35 * _stage_config().get("scale", 0.5)
			cone.height = 0.25
			mesh_inst.mesh = cone
			mesh_inst.position.y = 0.9 * _stage_config().get("scale", 0.5)
	add_child(mesh_inst)


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


# ── Phase 27: Path public API ──

func get_path_name() -> String:
	return GameConstants.PET_PATH_NAMES[evolution_path]

func get_path_id() -> int:
	return evolution_path

func get_ability_name() -> String:
	return _ability_name()

## Force the pet onto a specific evolution path. Used by the player's
## "use_stone" action (consumes a stone from PetStoneInventory).
func set_path_from_stone(stone_type: int) -> bool:
	if not GameConstants.PET_STONE_TO_PATH.has(stone_type):
		return false
	var new_path: int = GameConstants.PET_STONE_TO_PATH[stone_type]
	if evolution_path == new_path:
		GameManager.add_message("🐾 Pet is already on the %s path!" % GameConstants.PET_PATH_NAMES[new_path])
		return false
	_set_path(new_path)
	return true

## Get the current emote ID (for HUD display).
func get_current_emote() -> int:
	return _current_emote

## Externally trigger an emote (e.g. from player events like biome change).
func trigger_emote(emote_id: int) -> void:
	_trigger_emote(emote_id)