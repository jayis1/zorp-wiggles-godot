## Zorp Wiggles — Plasma Drake (Boss)
## Multi-phase boss with enrage, fire breath, and charge attacks.
## Phase 1 (>30% HP): normal chase + fire breath
## Phase 2 (<30% HP): enrage — faster, stronger, charges at player

extends EnemyBase

class_name EnemyDrake

# ─── Drake State ──────────────────────────────────────────────────────────────
var is_enraged: bool = false
var fire_breath_timer: float = 5.0
var charge_timer: float = 8.0
var is_charging: bool = false
var charge_dir: Vector3 = Vector3.ZERO
var charge_duration: float = 0.0

func _ready() -> void:
	enemy_name = "Plasma Drake"
	enemy_type = GameConstants.EnemyType.DRAKE
	max_hp = 350
	speed = 6.5
	damage = 45
	base_scale = 2.2
	detect_range = 40.0
	attack_range = 3.0
	xp_reward = 200
	score_reward = 1000
	base_color = Color.MAGENTA
	# ── Phase 10: Boss has its own AI — disable flanking/retreat/ambush but
	# keep enrage and pack behavior (drake can still enrage at low HP).
	super._ready()
	if ai_controller:
		ai_controller.enable_flanking = false
		ai_controller.enable_retreat = false
		ai_controller.enable_ambush = false

	fire_breath_timer = GameConstants.DRAKE_FIRE_BREATH_COOLDOWN
	charge_timer = GameConstants.DRAKE_CHARGE_COOLDOWN

	# Boss HP bar on HUD
	GameManager.boss_spawned.emit(self)

func _physics_process(delta: float) -> void:
	if is_dead or GameManager.is_paused:
		return
	
	# ── Phase 14: Apply dimension time scale for boss-specific timers ──
	# (The base class also scales delta, so we pass the original to super
	#  to avoid double-scaling the movement/AI delta.)
	var scaled_delta: float = delta * _time_scale
	
	# Spawn grace period — decrement timer ourselves since we return before super
	if spawn_grace_timer > 0:
		spawn_grace_timer -= scaled_delta
		_update_spawn_visuals(scaled_delta)
		return
	
	# Check enrage threshold
	if not is_enraged and float(hp) / float(max_hp) < GameConstants.DRAKE_ENRAGE_HP_THRESHOLD:
		_enter_enrage()
	
	# Handle boss attacks first — this may set velocity for charging
	if is_alerted and not is_dead:
		_update_boss_attacks(scaled_delta)
	
	# If charging, skip normal AI (which would overwrite velocity) but still
	# need move_and_slide to apply the charge velocity
	if is_charging:
		move_and_slide()
		return
	
	# Normal AI behavior via base class (handles detection, movement, timers, move_and_slide)
	# Pass the original delta — the base class applies _time_scale internally.
	super._physics_process(delta)

func _enter_enrage() -> void:
	is_enraged = true
	speed *= GameConstants.DRAKE_ENRAGE_SPEED_MULT
	damage = int(damage * GameConstants.DRAKE_ENRAGE_DAMAGE_MULT)
	# Visual: shift to red-orange
	if _material:
		var enrage_tween := create_tween()
		enrage_tween.tween_property(_material, "albedo_color",
			Color(1.0, 0.2, 0.0), 0.5)
		base_color = Color(1.0, 0.2, 0.0)
	GameManager.add_message("Plasma Drake is enraged!")

func _update_boss_attacks(delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dist_to_player: float = global_position.distance_to(player.global_position)

	# Charge attack
	if is_charging:
		charge_duration -= delta
		velocity = charge_dir * GameConstants.DRAKE_CHARGE_SPEED
		# Check collision with player
		if dist_to_player < 2.0:
			GameManager.take_damage(GameConstants.DRAKE_CHARGE_DAMAGE, global_position)
			is_charging = false
			charge_timer = GameConstants.DRAKE_CHARGE_COOLDOWN
		if charge_duration <= 0:
			is_charging = false
			charge_timer = GameConstants.DRAKE_CHARGE_COOLDOWN
		return

	charge_timer -= delta
	if charge_timer <= 0 and dist_to_player > 5.0:
		# Start charge
		is_charging = true
		charge_dir = (player.global_position - global_position).normalized()
		charge_dir.y = 0
		charge_duration = 0.8
		# Set charge velocity immediately so the first frame of charging moves the drake
		velocity = charge_dir * GameConstants.DRAKE_CHARGE_SPEED
		return

	# Fire breath
	fire_breath_timer -= delta
	if fire_breath_timer <= 0 and dist_to_player < GameConstants.DRAKE_FIRE_BREATH_RANGE:
		_fire_breath(player)
		fire_breath_timer = GameConstants.DRAKE_FIRE_BREATH_COOLDOWN

func _fire_breath(player: Node3D) -> void:
	# Fire multiple projectiles in a cone toward the player
	var base_dir: Vector3 = (player.global_position - global_position).normalized()
	base_dir.y = 0

	var proj_scene: PackedScene = load("res://scenes/entities/enemy_projectile.tscn")
	if not proj_scene:
		GameManager.take_damage(GameConstants.DRAKE_FIRE_BREATH_DAMAGE, global_position)
		return

	for i in range(5):
		var angle_offset: float = (i - 2) * 10.0  # -20, -10, 0, 10, 20 degrees
		var angled_dir := base_dir.rotated(Vector3.UP, deg_to_rad(angle_offset))
		var proj: Area3D = proj_scene.instantiate()
		# Set properties BEFORE adding to tree so _ready() picks them up
		proj.set("direction", angled_dir)
		proj.set("speed", GameConstants.SPORE_SPIT_SPEED * 1.2)
		proj.set("damage", GameConstants.DRAKE_FIRE_BREATH_DAMAGE)
		proj.set("lifetime", 2.0)
		# Drake projectiles are red — must be set before _ready() creates the material
		proj.set("projectile_color", Color(1.0, 0.3, 0.0))
		get_parent().add_child(proj)
		proj.global_position = global_position + Vector3(0, 1.0, 0)

func _die() -> void:
	# Boss death — extra rewards and notification
	GameManager.add_message("Plasma Drake defeated!")
	GameManager.boss_defeated.emit(self)
	GameManager.clear_current_boss()
	# ── Phase 11: Boss death spectacle — mega particle cascade ──
	ParticleEffects.spawn_boss_death_spectacle(get_parent(), global_position,
		Color(1.0, 0.0, 1.0), 3.0)
	super._die()