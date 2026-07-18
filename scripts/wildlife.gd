## Zorp Wiggles — Wildlife (Phase 26: World Life)
## Non-hostile creatures that roam the world. They wander peacefully until the
## player approaches, then flee at high speed. If the player catches one (touches
## it), it drops loot (XP orb + occasional crafting material) and a small score
## bonus. They do NOT fight back — they're a light exploration reward. Hunting
## them is optional but worthwhile (especially the crafting material drops).
##
## Each wildlife instance belongs to a species (see WILDLIFE_SPECIES in
## game_constants.gd) which determines its color, scale, and preferred biome.
##
## All colors use Godot 0-1 range.

extends CharacterBody3D

signal caught(wildlife: Node, species_name: String)

# ─── Export ──────────────────────────────────────────────────────────────────
@export var species_name: String = "Glimmer Hopper"
@export var species_color: Color = Color(0.9, 0.8, 0.3)
@export var species_scale: float = 0.5

# ─── State ───────────────────────────────────────────────────────────────────
var _home: Vector3 = Vector3.ZERO
var _wander_dir: Vector3 = Vector3.ZERO
var _wander_timer: float = 0.0
var _is_fleeing: bool = false
var _flee_timer: float = 0.0
var _time: float = 0.0
var _caught: bool = false
var _cached_player: Node3D = null
var _bob_phase: float = 0.0

# ─── Child nodes (built in _ready) ───────────────────────────────────────────
var _body_mesh: MeshInstance3D
var _eye_l: MeshInstance3D
var _eye_r: MeshInstance3D
var _light: OmniLight3D
var _material: StandardMaterial3D

func _ready() -> void:
	add_to_group("wildlife")
	add_to_group("non_hostile")  # Distinguishes from enemies
	_home = global_position
	_wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	_wander_timer = randf_range(2.0, 5.0)
	_bob_phase = randf() * TAU
	_build_visuals()

func _build_visuals() -> void:
	# Body — a small sphere, species-colored, emissive for visibility.
	_body_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	_body_mesh.mesh = sphere
	_body_mesh.scale = Vector3.ONE * species_scale
	_material = StandardMaterial3D.new()
	_material.albedo_color = species_color
	_material.emission_enabled = true
	_material.emission = species_color * 0.3
	_material.emission_energy_multiplier = 1.2
	_material.rim_enabled = true
	_material.rim = 0.6
	_material.rim_tint = 0.8
	_body_mesh.material_override = _material
	add_child(_body_mesh)

	# Two small dark eyes on the front (-Z) for character.
	_eye_l = _create_eye(Vector3(-0.15 * species_scale, 0.15 * species_scale, -0.45 * species_scale))
	_eye_r = _create_eye(Vector3(0.15 * species_scale, 0.15 * species_scale, -0.45 * species_scale))
	add_child(_eye_l)
	add_child(_eye_r)

	# Soft glow light so they're visible in dark biomes.
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 0.3, 0)
	_light.omni_range = 3.0
	_light.light_color = species_color
	_light.light_energy = 0.7
	add_child(_light)

func _create_eye(pos: Vector3) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi

func _physics_process(delta: float) -> void:
	if _caught:
		return
	if GameManager.is_paused or not GameManager.player_is_alive:
		return
	_time += delta

	# Cache player reference.
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")

	# Determine behavior: flee or wander.
	_is_fleeing = false
	if _cached_player:
		var dist: float = global_position.distance_to(_cached_player.global_position)
		if dist < GameConstants.WILDLIFE_FLEE_RANGE:
			_is_fleeing = true
			# Direction away from the player.
			var flee_dir: Vector3 = (global_position - _cached_player.global_position)
			flee_dir.y = 0
			if flee_dir.length() < 0.01:
				flee_dir = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
			_wander_dir = flee_dir.normalized()
			_flee_timer = 1.5  # Keep fleeing for a bit after the player leaves range.
		elif _flee_timer > 0:
			_is_fleeing = true
			_flee_timer -= delta

	# Catch check — if the player is very close, the wildlife is caught.
	if _cached_player:
		var catch_dist: float = global_position.distance_to(_cached_player.global_position)
		if catch_dist < GameConstants.WILDLIFE_CATCH_RANGE:
			_catch()
			return

	# Movement.
	if _is_fleeing:
		velocity = _wander_dir * GameConstants.WILDLIFE_FLEE_SPEED
		# Brighten emission when fleeing (alarmed).
		if _material:
			_material.emission_energy_multiplier = 2.0
	else:
		# Wander AI — pick a new direction periodically.
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
			_wander_timer = randf_range(3.0, 6.0)
		# Steer back toward home if straying too far.
		var to_home: Vector3 = global_position - _home
		if to_home.length() > GameConstants.WILDLIFE_WANDER_RADIUS:
			_wander_dir = -to_home.normalized()
		velocity = _wander_dir * GameConstants.WILDLIFE_WANDER_SPEED
		# Calm emission.
		if _material:
			_material.emission_energy_multiplier = 1.2

	move_and_slide()

	# Face the movement direction (yaw only).
	if velocity.length() > 0.1:
		var look_target: Vector3 = global_position + velocity.normalized()
		look_at(look_target, Vector3.UP)

	# Bob animation — gentle vertical hop while moving.
	_bob_phase += delta * (8.0 if _is_fleeing else 3.0)
	if _body_mesh:
		_body_mesh.position.y = abs(sin(_bob_phase)) * 0.15

func _catch() -> void:
	_caught = true
	# Statistics tracking.
	if Statistics:
		Statistics.record_wildlife_caught(species_name)
	# XP + score rewards.
	GameManager.gain_xp(GameConstants.WILDLIFE_XP_REWARD)
	GameManager.add_score(GameConstants.WILDLIFE_SCORE_REWARD)
	GameManager.add_message("🦌 Caught a %s! +%d XP" % [species_name, GameConstants.WILDLIFE_XP_REWARD])
	# Camera shake (small).
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.06)
	# Drop loot: an XP orb collectible + chance of a crafting material.
	_drop_loot()
	# Particle burst (species-colored).
	var parent: Node = get_parent()
	if parent and ParticleEffects:
		ParticleEffects.spawn_pickup_sparkle(parent, global_position + Vector3(0, 0.5, 0), species_color)
	# Death poof (species-colored) for a satisfying "poof" catch.
	if parent and ParticleEffects:
		ParticleEffects.spawn_death_poof(parent, global_position, species_color, species_scale)
	# Fade out + shrink, then queue_free.
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.4, 0.12) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(self, "scale", Vector3.ZERO, 0.25) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(self, "global_position:y", global_position.y + 0.8, 0.3) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)
	caught.emit(self, species_name)

func _drop_loot() -> void:
	var parent: Node = get_parent()
	if not parent:
		return
	var collectible_scene := preload("res://scenes/entities/collectible.tscn")
	# Always drop an XP orb.
	var xp_drop := collectible_scene.instantiate()
	parent.add_child(xp_drop)
	xp_drop.global_position = global_position + Vector3(0, 0.5, 0)
	xp_drop.set_type(GameConstants.CollectibleType.XP_ORB)
	GameManager.collectibles.append(xp_drop)
	if not xp_drop.is_in_group("collectibles"):
		xp_drop.add_to_group("collectibles")
	if xp_drop.has_method("start_tumble"):
		xp_drop.start_tumble(Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)).normalized())
	# 30% chance to also drop a crafting material.
	if randf() < GameConstants.WILDLIFE_MATERIAL_DROP_CHANCE:
		# Pick a random crafting material (weighted toward common).
		var material_table: Array[int] = [
			GameConstants.CollectibleType.SPACE_GLOOP,
			GameConstants.CollectibleType.SPACE_GLOOP,
			GameConstants.CollectibleType.STAR_FRUIT,
			GameConstants.CollectibleType.MAGNET_CORE,
			GameConstants.CollectibleType.NEBULA_DUST,
			GameConstants.CollectibleType.TOXIC_EXTRACT,
			GameConstants.CollectibleType.REGEN_CRYSTAL,
			GameConstants.CollectibleType.FIREBALL_SCROLL,
			GameConstants.CollectibleType.SHIELD_CRYSTAL,
			GameConstants.CollectibleType.QUANTUM_FUZZ,
			GameConstants.CollectibleType.METEOR_SHARD,
		]
		var mat_type: int = material_table[randi() % material_table.size()]
		var mat_drop := collectible_scene.instantiate()
		parent.add_child(mat_drop)
		mat_drop.global_position = global_position + Vector3(0, 0.5, 0)
		mat_drop.set_type(mat_type)
		GameManager.collectibles.append(mat_drop)
		if not mat_drop.is_in_group("collectibles"):
			mat_drop.add_to_group("collectibles")
		if mat_drop.has_method("start_tumble"):
			mat_drop.start_tumble(Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)).normalized())