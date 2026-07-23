## Zorp Wiggles — Crystal Wraith (Phase 23: New Enemy Type)
## On death, shatters into 3-5 crystal shards that fly outward. Each shard then
## reforms into a mini-wraith (low HP, fast, low damage) that continues attacking
## the player. This creates a "hydra" feel — killing the wraith spawns more
## enemies, so the player must be ready to deal with the mini-wraiths. The wraith
## itself is medium-tier: moderate HP, fast, melee.
##
## Architecture:
##   - The wraith is a normal EnemyBase subclass (takes damage, has AI).
##   - On death, we spawn 3-5 RigidBody3D shard "fragments" that fly outward
##     with an initial impulse (physics-driven scatter). After a short delay
##     (CRYSTAL_WRAITH_SHARD_REFORM_DELAY), each shard transforms into a
##     mini-wraith — we spawn a mini-wraith enemy at the shard's position and
##     free the shard.
##   - Mini-wraiths are spawned from the blob scene with overridden stats
##     (low HP, fast, low damage, small scale, ice-blue color). They're full
##     enemies in the "enemies" group, tracked by GameManager, and use the
##     base AI.

extends EnemyBase

class_name EnemyCrystalWraith

# Reuse the blob scene for mini-wraiths (simple melee chaser)
const MINI_WRAITH_SCENE := preload("res://scenes/entities/enemy_blob.tscn")

func _ready() -> void:
	enemy_name = "Crystal Wraith"
	enemy_type = GameConstants.EnemyType.CRYSTAL_WRAITH
	max_hp = GameConstants.CRYSTAL_WRAITH_HP
	speed = GameConstants.CRYSTAL_WRAITH_SPEED
	damage = GameConstants.CRYSTAL_WRAITH_DAMAGE
	base_scale = GameConstants.CRYSTAL_WRAITH_SCALE
	detect_range = GameConstants.CRYSTAL_WRAITH_DETECT_RANGE
	attack_range = GameConstants.CRYSTAL_WRAITH_ATTACK_RANGE
	attack_cooldown = GameConstants.CRYSTAL_WRAITH_ATTACK_COOLDOWN
	xp_reward = GameConstants.CRYSTAL_WRAITH_XP
	score_reward = GameConstants.CRYSTAL_WRAITH_SCORE
	base_color = GameConstants.CRYSTAL_WRAITH_COLOR
	# Smart AI enabled — flanking makes the wraith harder to pin down, and
	# retreat at low HP is fine (it doesn't reduce the shard count on death).
	use_smart_ai = true
	super._ready()

	# Crystalline material — shiny, high metallic, low roughness, strong rim
	# for an "ice crystal" look. The wraith should feel sharp and cold.
	if _material:
		_material.metallic = 0.5
		_material.roughness = 0.25
		_material.emission = base_color * 0.3
		_material.emission_energy_multiplier = 1.3
		_material.rim = 1.0
		_material.rim_tint = 0.9

func _die() -> void:
	# Shatter into crystal shards before calling super (which frees the node)
	_shatter_into_shards()
	# Extra crystal-shatter particle burst
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		GameConstants.CRYSTAL_WRAITH_COLOR, 28, 0.6)
	# Shield-break shatter effect for sharp fragment visuals
	ParticleEffects.spawn_shield_break_shatter(get_parent(), global_position,
		GameConstants.CRYSTAL_WRAITH_COLOR)
	# Audio cue — crystal shatter sound (uses breakable SFX for a crystal-crack feel)
	AudioManager.play_sfx(AudioManager.SFX_BREAKABLE)
	super._die()

## Spawn 3-5 RigidBody3D crystal shards that fly outward, then reform into
## mini-wraiths after a short delay. Each shard is a small physics body with
## an initial impulse in a random outward direction. After
## CRYSTAL_WRAITH_SHARD_REFORM_DELAY seconds, the shard transforms: we spawn a
## mini-wraith enemy at the shard's settled position and free the shard.
func _shatter_into_shards() -> void:
	var parent_node: Node = get_parent()
	if not parent_node:
		return
	var shard_count: int = randi_range(
		GameConstants.CRYSTAL_WRAITH_SHARD_COUNT_MIN,
		GameConstants.CRYSTAL_WRAITH_SHARD_COUNT_MAX
	)
	for i in range(shard_count):
		_spawn_shard(parent_node)

## Spawn a single crystal shard that flies outward, settles, then reforms into
## a mini-wraith. The shard is a RigidBody3D with a small sphere collision shape
## and a translucent ice-blue mesh. After the reform delay, we spawn a
## mini-wraith at the shard's position and free the shard.
func _spawn_shard(parent_node: Node) -> void:
	# Create the RigidBody3D shard
	var shard := RigidBody3D.new()
	shard.global_position = global_position + Vector3(0, 0.5, 0)
	shard.collision_layer = 0  # Don't collide with player/enemies
	shard.collision_mask = 1   # Only collide with world geometry (layer 1)

	# Collision shape — small sphere
	var col_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	col_shape.shape = sphere
	shard.add_child(col_shape)

	# Visual mesh — small ice-blue crystal shard
	var shard_mesh := MeshInstance3D.new()
	var shard_sphere := SphereMesh.new()
	shard_sphere.radius = 0.25
	shard_sphere.height = 0.5
	shard_sphere.radial_segments = 8
	shard_sphere.rings = 4
	shard_mesh.mesh = shard_sphere
	var shard_mat := StandardMaterial3D.new()
	shard_mat.albedo_color = GameConstants.CRYSTAL_WRAITH_COLOR
	shard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shard_mat.emission_enabled = true
	shard_mat.emission = GameConstants.CRYSTAL_WRAITH_COLOR * 0.5
	shard_mat.emission_energy_multiplier = 1.5
	shard_mat.rim_enabled = true
	shard_mat.rim = 0.8
	shard_mesh.material_override = shard_mat
	shard.add_child(shard_mesh)

	# Physics material with bounce for a lively scatter
	var phys_mat := PhysicsMaterial.new()
	phys_mat.bounce = 0.4
	phys_mat.friction = 0.5
	shard.physics_material_override = phys_mat

	# Add to scene
	parent_node.add_child(shard)

	# Initial impulse — random outward direction + upward component
	var outward_angle: float = randf() * TAU
	var outward_dir: Vector3 = Vector3(
		cos(outward_angle), 0.4, sin(outward_angle)
	).normalized()
	shard.apply_central_impulse(outward_dir * GameConstants.CRYSTAL_WRAITH_SHARD_SCATTER_SPEED)
	# Random angular velocity for tumbling
	shard.angular_velocity = Vector3(
		randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)
	)

	# Small light flash on the shard for visibility in dark biomes
	var shard_light := OmniLight3D.new()
	shard_light.light_color = GameConstants.CRYSTAL_WRAITH_COLOR
	shard_light.light_energy = 1.0
	shard_light.omni_range = 2.0
	shard_light.omni_attenuation = 1.5
	shard.add_child(shard_light)

	# After the reform delay, transform the shard into a mini-wraith.
	# We use a one-shot Timer on the shard itself. When it fires, we spawn a
	# mini-wraith at the shard's current position (which has settled by then)
	# and free the shard.
	var reform_timer := Timer.new()
	reform_timer.wait_time = GameConstants.CRYSTAL_WRAITH_SHARD_REFORM_DELAY
	reform_timer.one_shot = true
	reform_timer.autostart = true
	shard.add_child(reform_timer)

	# Capture the shard reference in the closure (avoid late-access issues)
	var shard_ref: RigidBody3D = shard
	reform_timer.timeout.connect(func() -> void:
		if not is_instance_valid(shard_ref):
			return
		var spawn_pos: Vector3 = shard_ref.global_position
		# Fade the shard out as it "reforms" into the mini-wraith
		if is_instance_valid(shard_mat):
			var fade_tween := shard_ref.create_tween()
			fade_tween.tween_property(shard_mat, "albedo_color:a", 0.0, 0.2) \
				.set_ease(Tween.EASE_IN)
			fade_tween.tween_callback(shard_ref.queue_free)
		else:
			shard_ref.queue_free()
		# Spawn the mini-wraith at the shard's position
		_spawn_mini_wraith(spawn_pos)
	)

## Spawn a mini-wraith enemy at the given position. The mini-wraith is a
## blob-scene enemy with overridden stats: low HP, fast, low damage, small
## scale, ice-blue color. It's a full enemy in the "enemies" group, tracked by
## GameManager, and uses the base AI.
func _spawn_mini_wraith(pos: Vector3) -> void:
	var mini: CharacterBody3D = MINI_WRAITH_SCENE.instantiate()
	# Configure BEFORE adding to scene tree so _ready() picks up overrides
	mini.set("max_hp", GameConstants.CRYSTAL_WRAITH_MINI_HP)
	mini.set("hp", GameConstants.CRYSTAL_WRAITH_MINI_HP)
	mini.set("damage", GameConstants.CRYSTAL_WRAITH_MINI_DAMAGE)
	mini.set("speed", GameConstants.CRYSTAL_WRAITH_MINI_SPEED)
	mini.set("base_scale", GameConstants.CRYSTAL_WRAITH_MINI_SCALE)
	mini.set("enemy_name", "Crystal Shardling")
	mini.set("enemy_type", GameConstants.EnemyType.CRYSTAL_WRAITH)  # Same type for loot tables
	mini.set("xp_reward", GameConstants.CRYSTAL_WRAITH_MINI_XP)
	mini.set("score_reward", GameConstants.CRYSTAL_WRAITH_MINI_SCORE)
	mini.set("base_color", GameConstants.CRYSTAL_WRAITH_MINI_COLOR)
	mini.set("use_smart_ai", false)  # Mini-wraiths are simple rushers
	get_parent().add_child(mini)
	mini.global_position = pos
	# Track the mini-wraith so it's cleaned up on restart and counted by the spawner
	GameManager.enemies.append(mini)
	# Materialization particle burst for the "reform" effect
	ParticleEffects.spawn_materialization(get_parent(), pos,
		GameConstants.CRYSTAL_WRAITH_MINI_COLOR)
	# Audio cue — soft materialization chime for the shard reforming
	AudioManager.play_sfx(AudioManager.SFX_PET)  # Reuse soft blip (same as pet materialize)