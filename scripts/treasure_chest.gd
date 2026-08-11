## Zorp Wiggles — Treasure Chest (Phase 26: World Life)
## A hidden container buried across the world. It's low-profile (partly
## buried) and only emits a faint golden glimmer when the player is within
## TREASURE_CHEST_GLOW_RANGE. Walking into it opens it, granting rare loot
## (collectibles) + XP. 25% of chests are trapped — they deal damage and
## spawn a small enemy (Swarm Mite) before yielding the loot, for risk/reward.
##
## All colors use Godot 0-1 range.

extends Area3D

signal chest_opened(chest: Node, trapped: bool)

# ─── State ───────────────────────────────────────────────────────────────────
var _opened: bool = false
var _trapped: bool = false
var _time: float = 0.0
var _glow_phase: float = 0.0
var _cached_player: Node3D = null
var _prompt_shown: bool = false

# ─── Child nodes (built in _ready) ───────────────────────────────────────────
var _base: MeshInstance3D
var _lid: MeshInstance3D
var _ground_glow: MeshInstance3D
var _light: OmniLight3D
var _lock: MeshInstance3D  # Small glowing lock on the front

func _ready() -> void:
	add_to_group("treasure_chest")
	_trapped = randf() < GameConstants.TREASURE_CHEST_TRAP_CHANCE
	_glow_phase = randf() * TAU
	_build_visuals()
	# Collision shape is provided by the scene (ChestCollision).
	body_entered.connect(_on_body_entered)
	# Spawn-in animation: chest rises from the ground with a scale pop.
	# Disable collision during the rise so the player can't trigger it mid-spawn.
	# (Collision shape is on the scene root; we monitor body_entered via signal.)
	scale = Vector3.ZERO
	global_position.y -= 0.6
	var spawn_tween := create_tween()
	spawn_tween.tween_property(self, "global_position:y",
		global_position.y + 0.6, 0.45) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	spawn_tween.parallel().tween_property(self, "scale", Vector3.ONE, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _build_visuals() -> void:
	# Base — wide flat box (the chest body), partly sunk into the ground.
	_base = _create_box(
		Vector3(0, 0.4, 0),
		Vector3(1.2, 0.8, 0.8),
		GameConstants.TREASURE_CHEST_COLOR
	)
	add_child(_base)

	# Lid — slightly smaller box on top, tilted back slightly (closed).
	_lid = _create_box(
		Vector3(0, 0.95, 0),
		Vector3(1.2, 0.3, 0.8),
		GameConstants.TREASURE_CHEST_COLOR
	)
	add_child(_lid)

	# Lock — small glowing golden cube on the front of the lid.
	_lock = _create_box(
		Vector3(0, 0.95, -0.45),
		Vector3(0.2, 0.2, 0.1),
		GameConstants.TREASURE_CHEST_GLOW_COLOR
	)
	if _lock.material_override:
		_lock.material_override.emission_enabled = true
		_lock.material_override.emission = GameConstants.TREASURE_CHEST_GLOW_COLOR
		_lock.material_override.emission_energy_multiplier = 1.5
	add_child(_lock)

	# Ground glow disc — soft golden halo (only visible when close).
	_ground_glow = _create_ground_disc(
		Vector3(0, 0.05, 0),
		2.0,
		Color(
			GameConstants.TREASURE_CHEST_GLOW_COLOR.r,
			GameConstants.TREASURE_CHEST_GLOW_COLOR.g,
			GameConstants.TREASURE_CHEST_GLOW_COLOR.b,
			0.0  # Starts invisible — fades in when player is near.
		)
	)
	add_child(_ground_glow)

	# OmniLight — starts dim, brightens when player approaches.
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 1.0, 0)
	_light.omni_range = 4.0
	_light.light_color = GameConstants.TREASURE_CHEST_GLOW_COLOR
	_light.light_energy = 0.0
	add_child(_light)

func _process(delta: float) -> void:
	if _opened:
		return
	_time += delta
	# Pulse the lock emission.
	var pulse: float = 0.6 + 0.4 * sin(_time * 2.5 + _glow_phase)
	if _lock and _lock.material_override:
		_lock.material_override.emission_energy_multiplier = pulse * 1.8

	# Check player proximity — fade in the glimmer when close.
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	if _cached_player:
		var dist: float = global_position.distance_to(_cached_player.global_position)
		# Glimmer intensity: 0 far away, 1 when within glow range.
		var glimmer: float = 1.0 - clampf(dist / GameConstants.TREASURE_CHEST_GLOW_RANGE, 0.0, 1.0)
		glimmer = clampf(glimmer * 1.5, 0.0, 1.0)
		if _ground_glow and _ground_glow.material_override:
			var mat: StandardMaterial3D = _ground_glow.material_override
			mat.albedo_color.a = glimmer * 0.35
		if _light:
			_light.light_energy = glimmer * 1.2
		# Show a one-time prompt when the player first gets close.
		if dist <= GameConstants.TREASURE_CHEST_OPEN_RANGE + 1.5 and not _prompt_shown:
			_prompt_shown = true
			GameManager.add_message("🗝️ Treasure chest nearby — walk into it to open")

func _on_body_entered(body: Node3D) -> void:
	if _opened:
		return
	if not body.is_in_group("player"):
		return
	_open_chest()

func _open_chest() -> void:
	_opened = true
	# Statistics tracking.
	if Statistics:
		Statistics.record_treasure_chest_opened(_trapped)
	# Animate the lid opening (rotate back).
	if _lid:
		var lid_tween := create_tween()
		lid_tween.tween_property(_lid, "rotation_degrees:x", -65.0, 0.35) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Spawn loot + XP.
	_spawn_loot()
	GameManager.gain_xp(GameConstants.TREASURE_CHEST_XP_REWARD)
	GameManager.add_message("✨ Treasure! +%d XP" % GameConstants.TREASURE_CHEST_XP_REWARD)
	# Audio feedback — different sound for trapped vs normal chests.
	if _trapped:
		AudioManager.play_sfx(AudioManager.SFX_CHEST_TRAP)
	else:
		AudioManager.play_sfx(AudioManager.SFX_CHEST_OPEN)
	# Camera shake.
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.2)
	# ── Open light burst ── A brief golden light flash that spikes to 4.0
	# energy on the open frame then eases back to the proximity glow level
	# over 0.4s. Without this, the chest opening has no light feedback —
	# the light stays at its proximity level (0–1.2) and the lid animation
	# + particle burst are the only "treasure!" cues. The flash gives the
	# opening a luminous "ta-da!" moment, especially impactful in dark
	# biomes (Underground, Eclipse) where the chest's golden glow is the
	# primary light source. Uses ease-out cubic for a decisive flash that
	# settles smoothly, matching the treasure-related visual language.
	if _light:
		_light.light_energy = 4.0
		var open_light_tween := create_tween()
		open_light_tween.tween_property(_light, "light_energy", 0.8, 0.4) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		# Widen the range briefly so the flash illuminates a larger area.
		_light.omni_range = 8.0
		var range_tween := create_tween()
		range_tween.tween_property(_light, "omni_range", 4.0, 0.5) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Trapped chests: telegraph flash, then deal damage + spawn a Swarm Mite.
	if _trapped:
		_trigger_trap()
	# Particle burst (golden).
	var parent: Node = get_parent()
	if parent and ParticleEffects:
		ParticleEffects.spawn_combo_fireworks(parent, global_position + Vector3(0, 1, 0), 2)
	# Fade out + sink, then queue_free.
	var fade_tween := create_tween()
	fade_tween.tween_interval(0.5)  # Let the lid animation play first.
	fade_tween.chain().tween_property(self, "global_position:y", global_position.y - 1.0, 0.6) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	fade_tween.parallel().tween_property(self, "scale", Vector3.ZERO, 0.6) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	fade_tween.tween_callback(queue_free)
	chest_opened.emit(self, _trapped)

func _spawn_loot() -> void:
	# Spawn TREASURE_CHEST_LOOT_COUNT collectibles around the chest.
	# Bias toward rare materials (chests are valuable).
	var parent: Node = get_parent()
	if not parent:
		return
	var collectible_scene := preload("res://scenes/entities/collectible.tscn")
	# Weighted loot table: bias toward rare crafting materials.
	# 30% Meteor Shard, 25% Quantum Fuzz, 20% Nebula Dust, 15% Star Fruit, 10% Health Fragment.
	var loot_table: Array[int] = [
		GameConstants.CollectibleType.METEOR_SHARD,
		GameConstants.CollectibleType.METEOR_SHARD,
		GameConstants.CollectibleType.METEOR_SHARD,
		GameConstants.CollectibleType.QUANTUM_FUZZ,
		GameConstants.CollectibleType.QUANTUM_FUZZ,
		GameConstants.CollectibleType.QUANTUM_FUZZ,
		GameConstants.CollectibleType.QUANTUM_FUZZ,
		GameConstants.CollectibleType.QUANTUM_FUZZ,
		GameConstants.CollectibleType.NEBULA_DUST,
		GameConstants.CollectibleType.NEBULA_DUST,
		GameConstants.CollectibleType.NEBULA_DUST,
		GameConstants.CollectibleType.NEBULA_DUST,
		GameConstants.CollectibleType.STAR_FRUIT,
		GameConstants.CollectibleType.STAR_FRUIT,
		GameConstants.CollectibleType.STAR_FRUIT,
		GameConstants.CollectibleType.HEALTH_FRAGMENT,
		GameConstants.CollectibleType.HEALTH_FRAGMENT,
	]
	for i in range(GameConstants.TREASURE_CHEST_LOOT_COUNT):
		var loot_type: int = loot_table[randi() % loot_table.size()]
		var collectible := collectible_scene.instantiate()
		var angle: float = (float(i) / float(GameConstants.TREASURE_CHEST_LOOT_COUNT)) * TAU
		var offset: Vector3 = Vector3(cos(angle), 0, sin(angle)) * 1.5
		parent.add_child(collectible)
		collectible.global_position = global_position + offset + Vector3(0, 1.0, 0)
		collectible.set_type(loot_type)
		GameManager.collectibles.append(collectible)
		if not collectible.is_in_group("collectibles"):
			collectible.add_to_group("collectibles")
		# Give the collectible a little tumble for a "burst out" feel.
		if collectible.has_method("start_tumble"):
			collectible.start_tumble(Vector3(cos(angle), 0.5, sin(angle)))

func _trigger_trap() -> void:
	# Telegraph: brief red flash on the lid + lock so the player sees the trap
	# trigger a fraction of a second before damage lands. Feels fairer than
	# instant damage out of nowhere.
	var flash_col: Color = Color(1.0, 0.15, 0.15)
	if _lid and _lid.material_override:
		var lid_mat: StandardMaterial3D = _lid.material_override
		var prev_albedo: Color = lid_mat.albedo_color
		var prev_emi: Color = lid_mat.emission
		var prev_emi_e: float = lid_mat.emission_energy_multiplier
		lid_mat.albedo_color = flash_col
		lid_mat.emission = flash_col
		lid_mat.emission_energy_multiplier = 3.0
		var flash_tween := create_tween()
		flash_tween.tween_interval(0.18)  # Brief red hold.
		flash_tween.tween_property(lid_mat, "albedo_color", prev_albedo, 0.25) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		flash_tween.parallel().tween_property(lid_mat, "emission", prev_emi, 0.25) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		flash_tween.parallel().tween_property(lid_mat, "emission_energy_multiplier",
			prev_emi_e, 0.25) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if _lock and _lock.material_override:
		var lock_mat: StandardMaterial3D = _lock.material_override
		lock_mat.emission = flash_col
		lock_mat.emission_energy_multiplier = 4.0
	# Small camera shake on the telegraph to sell the "uh oh" moment.
	var cam_pre: Node3D = GameManager.camera_rig
	if cam_pre and cam_pre.has_method("add_trauma"):
		cam_pre.add_trauma(0.1)
	# Deal damage to the player (after the brief telegraph flash).
	GameManager.take_damage(GameConstants.TREASURE_CHEST_TRAP_DAMAGE, global_position)
	GameManager.add_message("💥 It's a trap! The chest was rigged!")
	# Spawn a "Chest Mimic" enemy. We use the blob scene (EnemyBase) rather than
	# the Swarm Mite scene because SwarmMite._ready() overwrites enemy_name,
	# max_hp, speed, damage, base_scale, and base_color with its own constants —
	# which would discard the custom "mimic" stats below. EnemyBase._ready() does
	# NOT overwrite those fields (they come from the scene's export values), so
	# pre-add_child assignments survive. `hp` is set by EnemyBase._ready() to
	# `max_hp`, so we set max_hp before add_child and then clamp hp after.
	var parent: Node = get_parent()
	if not parent:
		return
	var mimic_scene_path := "res://scenes/entities/enemy_blob.tscn"
	if not ResourceLoader.exists(mimic_scene_path):
		return  # No enemy scene available — skip the trap spawn.
	var enemy_scene: PackedScene = load(mimic_scene_path)
	var enemy: CharacterBody3D = enemy_scene.instantiate()
	# Configure as a basic trap enemy (low HP, low damage — it's a nuisance).
	# These must be set BEFORE add_child so EnemyBase._ready() picks them up
	# (it reads base_color/base_scale to build the material and spawn tween).
	enemy.enemy_name = "Chest Mimic"
	enemy.max_hp = 20
	enemy.speed = 5.0
	enemy.damage = 8
	enemy.base_scale = 0.5
	enemy.base_color = GameConstants.TREASURE_CHEST_COLOR
	parent.add_child(enemy)
	enemy.global_position = global_position + Vector3(0, 0.5, 0)
	# EnemyBase._ready() sets hp = max_hp, so hp is already 20 here. Set again
	# explicitly for clarity / safety in case a subclass overrides _ready.
	enemy.hp = 20
	GameManager.enemies.append(enemy)
	# Materialization particle burst.
	if ParticleEffects:
		ParticleEffects.spawn_materialization(parent, enemy.global_position)
	# Spawn-in SFX for the mimic ambush
	AudioManager.play_sfx(AudioManager.SFX_SPAWN_IN)

# ─── Mesh helpers ────────────────────────────────────────────────────────────

func _create_box(pos: Vector3, sz: Vector3, col: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(sz.x, sz.y, sz.x)
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.position = pos
	# BoxMesh depth equals width, so scale Z to match sz.z when it differs.
	if sz.x > 0.0 and sz.z != sz.x:
		mi.scale.z = sz.z / sz.x
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Subtle emission so the chest body + lid are visible in dark biomes
	# (Underground, Eclipse). Without emission, the unlit box faces are
	# lit only by ambient light — in a dark biome they read as black
	# silhouettes. Only the tiny lock glows, making the chest's structure
	# invisible from afar. A low emission (0.25×) keeps the body darker
	# than the glowing lock so the lock still reads as the focal point
	# while the chest's silhouette is visible. Matches the monolith and
	# portal pillar emission pattern.
	mat.emission_enabled = true
	mat.emission = col * 0.25
	mat.emission_energy_multiplier = 0.4
	mi.material_override = mat
	return mi

func _create_ground_disc(pos: Vector3, sz: float, col: Color) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(sz, sz)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Emission so the golden ground glow is visible in dark biomes —
	# matches the lore stone, monolith, healing shrine, and portal
	# ground glow which all add emission for dark-biome visibility.
	# Without it, the transparent disc is invisible against dark terrain
	# until the player is very close, reducing the chest's discoverability.
	mat.emission_enabled = true
	mat.emission = col * 0.4
	mat.emission_energy_multiplier = 0.5
	mi.material_override = mat
	return mi