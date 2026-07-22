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
	# Trapped chests: deal damage + spawn a Swarm Mite, then still give loot.
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
	# Deal damage to the player.
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

# ─── Mesh helpers ────────────────────────────────────────────────────────────

func _create_box(pos: Vector3, sz: Vector3, col: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = sz
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	mi.material_override = mat
	return mi