## Zorp Wiggles — Toxic Spore (Phase 23: New Enemy Type)
## On death, explodes into a lingering poison cloud that damages any entity
## (player or enemy) standing inside it. The cloud persists for several seconds,
## creating a temporary hazard zone. The spore itself is slow and weak in melee,
## but the player is incentivized to kill it at range so the cloud spawns far
## away. Enemies caught in the cloud take damage too — friendly-fire pressure.
##
## Behavior: Slow chase toward the player. Low melee damage. The real threat is
## the death effect — a translucent green cloud that ticks damage on anything
## inside it. The cloud is a StaticBody3D-free Area3D + visual mesh; it applies
## damage on a timer to any entity within its radius.

extends EnemyBase

class_name EnemyToxicSpore

# ─── Cloud Scene (spawned on death) ───────────────────────────────────────────
# We build the cloud as a self-contained Node3D at runtime rather than a .tscn
# so we don't need a separate scene file. The cloud handles its own lifecycle.
const CLOUD_PARENT_REF := "res://scripts/enemy_toxic_spore.gd"

func _ready() -> void:
	enemy_name = "Toxic Spore"
	enemy_type = GameConstants.EnemyType.TOXIC_SPORE
	max_hp = GameConstants.TOXIC_SPORE_HP
	speed = GameConstants.TOXIC_SPORE_SPEED
	damage = GameConstants.TOXIC_SPORE_DAMAGE
	base_scale = GameConstants.TOXIC_SPORE_SCALE
	detect_range = GameConstants.TOXIC_SPORE_DETECT_RANGE
	attack_range = GameConstants.TOXIC_SPORE_ATTACK_RANGE
	attack_cooldown = GameConstants.TOXIC_SPORE_ATTACK_COOLDOWN
	xp_reward = GameConstants.TOXIC_SPORE_XP
	score_reward = GameConstants.TOXIC_SPORE_SCORE
	base_color = GameConstants.TOXIC_SPORE_COLOR
	# Smart AI disabled — spores are simple slow chasers. Their threat is the
	# death cloud, not their movement. Disabling smart AI also makes them
	# cheaper to process when several are active.
	use_smart_ai = false
	super._ready()

	# Emissive sickly-green material with strong emission for a "glowing spore" look
	if _material:
		_material.emission = base_color * 0.5
		_material.emission_energy_multiplier = 1.6
		_material.rim = 0.9
		_material.rim_tint = 0.8

func _die() -> void:
	# Spawn the poison cloud at the spore's death position BEFORE calling super
	# (super frees the node via queue_free after a short delay).
	_spawn_poison_cloud()
	# Extra toxic burst particles for flavor
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		GameConstants.TOXIC_SPORE_CLOUD_COLOR, 24, 0.6)
	super._die()

## Spawn a lingering poison cloud at the given position. The cloud is a
## self-contained Node3D with an Area3D (for overlap detection), a visual
## translucent sphere mesh, and a timer that ticks damage on entities inside.
## The cloud auto-frees after TOXIC_SPORE_CLOUD_DURATION seconds.
func _spawn_poison_cloud() -> void:
	var parent_node: Node = get_parent()
	if not parent_node:
		return

	var cloud := Node3D.new()
	cloud.name = "PoisonCloud"
	cloud.global_position = global_position
	parent_node.add_child(cloud)

	# Visual: translucent green sphere that pulses and fades over the duration
	var cloud_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = GameConstants.TOXIC_SPORE_CLOUD_RADIUS
	sphere.height = GameConstants.TOXIC_SPORE_CLOUD_RADIUS * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	cloud_mesh.mesh = sphere
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = GameConstants.TOXIC_SPORE_CLOUD_COLOR
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.emission_enabled = true
	cloud_mat.emission = GameConstants.TOXIC_SPORE_CLOUD_COLOR * 0.6
	cloud_mat.emission_energy_multiplier = 1.2
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.no_depth_test = true  # Cloud renders on top for visibility
	cloud_mesh.material_override = cloud_mat
	cloud.add_child(cloud_mesh)
	# Flat on the ground
	cloud_mesh.position.y = 0.5

	# Soft green point light for ambient glow
	var cloud_light := OmniLight3D.new()
	cloud_light.light_color = GameConstants.TOXIC_SPORE_CLOUD_COLOR
	cloud_light.light_energy = 1.5
	cloud_light.omni_range = GameConstants.TOXIC_SPORE_CLOUD_RADIUS * 1.5
	cloud_light.omni_attenuation = 1.5
	cloud.add_child(cloud_light)

	# Damage tick timer — damages entities within radius on each tick
	var tick_timer := Timer.new()
	tick_timer.wait_time = GameConstants.TOXIC_SPORE_CLOUD_TICK_INTERVAL
	tick_timer.autostart = true
	tick_timer.one_shot = false
	cloud.add_child(tick_timer)

	# Lifetime timer — auto-frees the cloud after duration
	var life_timer := Timer.new()
	life_timer.wait_time = GameConstants.TOXIC_SPORE_CLOUD_DURATION
	life_timer.autostart = true
	life_timer.one_shot = true
	cloud.add_child(life_timer)

	# State for the tick callback (closure captures these)
	var cloud_age: float = 0.0
	var damaged_entities: Dictionary = {}  # Track last-damage time per entity to avoid per-frame double-damage

	# Tick: damage all entities within radius
	tick_timer.timeout.connect(func() -> void:
		if not is_instance_valid(cloud):
			return
		cloud_age += GameConstants.TOXIC_SPORE_CLOUD_TICK_INTERVAL
		# Damage players
		var p1: Node3D = cloud.get_tree().get_first_node_in_group("player")
		if p1 and is_instance_valid(p1) and GameManager.player_is_alive and not GameManager.player_is_downed:
			var d1: float = cloud.global_position.distance_to(p1.global_position)
			if d1 < GameConstants.TOXIC_SPORE_CLOUD_RADIUS:
				GameManager.take_damage(GameConstants.TOXIC_SPORE_CLOUD_DAMAGE_PER_TICK, cloud.global_position)
		# Co-op: damage P2
		if CoOpManager.is_coop_active() and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
			if not CoOpManager.p2_is_downed:
				var d2: float = cloud.global_position.distance_to(CoOpManager.p2_node.global_position)
				if d2 < GameConstants.TOXIC_SPORE_CLOUD_RADIUS:
					CoOpManager.p2_take_damage(GameConstants.TOXIC_SPORE_CLOUD_DAMAGE_PER_TICK, cloud.global_position)
		# Damage enemies (friendly fire — reduced)
		for enemy in cloud.get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			var eb: EnemyBase = enemy as EnemyBase
			if eb == null or eb.is_dead:
				continue
			var ed: float = cloud.global_position.distance_to(eb.global_position)
			if ed < GameConstants.TOXIC_SPORE_CLOUD_RADIUS:
				var enemy_dmg: int = int(GameConstants.TOXIC_SPORE_CLOUD_DAMAGE_PER_TICK * GameConstants.TOXIC_SPORE_CLOUD_ENEMY_DAMAGE_MULT)
				eb.take_damage_from(enemy_dmg, cloud.global_position)
	)

	# Lifetime expiry: fade out the cloud then free it
	life_timer.timeout.connect(func() -> void:
		if not is_instance_valid(cloud):
			return
		tick_timer.stop()
		# Fade the cloud mesh + light out over 0.5s
		if cloud_mesh and is_instance_valid(cloud_mat):
			var fade_tween := cloud.create_tween()
			fade_tween.set_parallel(true)
			fade_tween.tween_property(cloud_mat, "albedo_color:a", 0.0, 0.5) \
				.set_ease(Tween.EASE_IN)
			fade_tween.tween_property(cloud_mat, "emission_energy_multiplier", 0.0, 0.5) \
				.set_ease(Tween.EASE_IN)
			if cloud_light:
				fade_tween.tween_property(cloud_light, "light_energy", 0.0, 0.5) \
					.set_ease(Tween.EASE_IN)
			fade_tween.chain().tween_callback(cloud.queue_free)
		else:
			cloud.queue_free()
	)

	# Subtle pulsing animation while the cloud is alive
	if cloud_mesh and cloud_mat:
		var pulse_tween := cloud.create_tween()
		pulse_tween.set_loops()
		pulse_tween.tween_property(cloud_mat, "emission_energy_multiplier", 0.7, 0.8) \
			.set_ease(Tween.EASE_IN_OUT)
		pulse_tween.tween_property(cloud_mat, "emission_energy_multiplier", 1.2, 0.8) \
			.set_ease(Tween.EASE_IN_OUT)
		# Stop the pulse when the lifetime ends (life_timer callback frees the cloud)
		life_timer.timeout.connect(func() -> void:
			if is_instance_valid(pulse_tween):
				pulse_tween.kill()
		)