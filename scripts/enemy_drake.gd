## Zorp Wiggles — Plasma Drake (Boss)
## Multi-phase boss with enrage, fire breath, and charge attacks.
## Phase 1 (>25% HP): normal chase + fire breath
## Phase 2 (<25% HP): enrage — faster, stronger, charges at player

extends EnemyBase

class_name EnemyDrake

# class_name is REQUIRED for Godot 4.4 class resolution. Without it, the
# script is not registered in the global class registry and `extends
# EnemyBase` fails to resolve when the script is loaded via preload() in
# autoload scripts (BossArena, GameModeManager, EndgameManager) before
# enemy_base.gd has been loaded through the resource system. boss_arena.gd
# uses boss.get("enemy_type") instead of `is EnemyDrake`.

# ─── Drake State ──────────────────────────────────────────────────────────────
var is_enraged: bool = false
var fire_breath_timer: float = 5.0
var charge_timer: float = 8.0
var is_charging: bool = false
var charge_dir: Vector3 = Vector3.ZERO
var charge_duration: float = 0.0

# Preloaded projectile scene — shared across all fire-breath volleys so the
# resource loader isn't hit on every attack (the Drake fires 5 bolts per cone).
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/entities/enemy_projectile.tscn")

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
	if not is_enraged and max_hp > 0 and float(hp) / float(max_hp) < GameConstants.DRAKE_ENRAGE_HP_THRESHOLD:
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
			Color(1.0, 0.2, 0.0), 0.5) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		base_color = Color(1.0, 0.2, 0.0)
	# Keep current_color in sync with base_color so systems that save/restore
	# it (mind control, variant tinting) use the enraged color, not the
	# pre-enrage color that current_color was initialised with.
	current_color = base_color
	# Audio — dedicated boss enrage roar for the enrage phase.
	AudioManager.play_sfx(AudioManager.SFX_BOSS_ENRAGE)
	# ── Enhancement Pack 38: Boss phase transition screen flash ──
	GameManager.boss_phase_changed.emit(Color(1.0, 0.2, 0.0, 1.0))
	GameManager.add_message("Plasma Drake is enraged!")

func _update_boss_attacks(delta: float) -> void:
	# In co-op, target the nearest valid player (base class logic handles this
	# for normal AI, but boss attacks have their own targeting)
	# Use _cached_player from the base class (populated via super._physics_process)
	# instead of a fresh scene-tree group scan every physics frame.
	var player: Node3D = _cached_player
	if CoOpManager.is_coop_active() and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
		var p1_dist: float = global_position.distance_to(player.global_position) if player else 99999.0
		var p2_dist: float = global_position.distance_to(CoOpManager.p2_node.global_position)
		# Prefer the closer player, but skip downed players
		if GameManager.player_is_downed:
			p1_dist = 99999.0
		if CoOpManager.p2_is_downed:
			p2_dist = 99999.0
		if p2_dist < p1_dist:
			player = CoOpManager.p2_node
	if not player:
		return

	var dist_to_player: float = global_position.distance_to(player.global_position)

	# Charge attack
	if is_charging:
		charge_duration -= delta
		velocity = charge_dir * GameConstants.DRAKE_CHARGE_SPEED
		# Check collision with player — route to correct player in co-op
		if dist_to_player < 2.0:
			# In co-op, determine which player the drake is charging at
			# by checking if the target from _update_ai was P2. Since we
			# don't have that here, check P2 distance if active.
			if CoOpManager.is_coop_active() and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
				var p2_dist: float = global_position.distance_to(CoOpManager.p2_node.global_position)
				if p2_dist < 2.0 and p2_dist < dist_to_player:
					CoOpManager.p2_take_damage(GameConstants.DRAKE_CHARGE_DAMAGE, global_position)
				else:
					GameManager.take_damage(GameConstants.DRAKE_CHARGE_DAMAGE, global_position)
			else:
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
		# Charge start SFX — reuse SFX_ENEMY_LUNGE (a descending impact whoosh)
		# at a lower pitch for the boss's charge. The lunge SFX already conveys
		# a committed forward lunge; at 0.5× pitch it reads as a massive boss
		# version of the same motion. Previously the Drake's charge attack had
		# no audio at the start — the boss silently accelerated toward the player.
		AudioManager.play_sfx_pitched(AudioManager.SFX_ENEMY_LUNGE, 0.5)
		return

	# Fire breath
	fire_breath_timer -= delta
	if fire_breath_timer <= 0 and dist_to_player < GameConstants.DRAKE_FIRE_BREATH_RANGE:
		_fire_breath(player)
		fire_breath_timer = GameConstants.DRAKE_FIRE_BREATH_COOLDOWN

func _fire_breath(player: Node3D) -> void:
	# Fire breath SFX — a fiery roaring whoosh for the Drake's signature attack.
	# Previously this was the only boss cone attack in the game with no audio.
	AudioManager.play_sfx(AudioManager.SFX_DRAGON_BREATH)
	# Fire multiple projectiles in a cone toward the player
	var base_dir: Vector3 = (player.global_position - global_position).normalized()
	base_dir.y = 0

	for i in range(5):
		var angle_offset: float = (i - 2) * 10.0  # -20, -10, 0, 10, 20 degrees
		var angled_dir := base_dir.rotated(Vector3.UP, deg_to_rad(angle_offset))
		var proj: Area3D = ENEMY_PROJECTILE_SCENE.instantiate()
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
	# Suppress the base class generic death SFX — the Drake plays its own
	# dedicated SFX_DRAKE_DEATH below.
	_suppress_base_death_sfx = true
	# Play a dedicated death SFX — a deep, sustained dragon roar collapse
	# (descending 200→60 Hz, 0.35s, 0.32 vol). Deeper than regular enemies
	# since the Drake is a boss, but not as deep as the Void Leviathan.
	AudioManager.play_sfx_pitched_volume(AudioManager.SFX_DRAKE_DEATH, 0.8, 0.6)
	# Boss death — extra rewards and notification
	GameManager.add_message("Plasma Drake defeated!")
	# Only emit boss_defeated / clear_current_boss here if NOT a world boss.
	# World bosses are handled by super._die() (EnemyBase._die checks is_world_boss
	# and emits boss_defeated there). Without this guard, a Drake promoted to world
	# boss would emit boss_defeated twice — once here and once in super._die() —
	# causing double loot showers, double stats recording, and double messages.
	if not is_world_boss:
		GameManager.boss_defeated.emit(self)
		GameManager.clear_current_boss()
	# ── Phase 11: Boss death spectacle — mega particle cascade ──
	ParticleEffects.spawn_boss_death_spectacle(get_parent(), global_position,
		Color(1.0, 0.0, 1.0), 3.0)
	super._die()