## Zorp Wiggles — Game Manager (Autoload Singleton)
## Manages game state, player data, and coordinates all systems.
## Ported from the Game class in Ursina game.py.

extends Node

signal hp_changed(new_hp: int, max_hp: int)
signal xp_changed(new_xp: int, xp_to_next: int)
signal level_up(level: int)
signal combo_changed(count: int)
signal score_changed(new_score: int)
signal player_died()
signal game_restarted()
signal boss_spawned(boss: Node)
signal boss_defeated(boss: Node)
signal message_added(text: String)

# ─── Player State ─────────────────────────────────────────────────────────────
var player_hp: int = GameConstants.PLAYER_START_HP
var player_max_hp: int = GameConstants.PLAYER_START_HP
var player_xp: int = 0
var player_xp_to_next: int = GameConstants.PLAYER_START_XP
var player_level: int = 1
var player_score: int = 0
var player_kills: int = 0
var player_combo: int = 0
var player_combo_timer: float = 0.0
var player_best_combo: int = 0
var player_last_combo_milestone: int = 0  # Last milestone reached (for milestone detection)
var player_pickup_streak: int = 0
var player_pickup_streak_timer: float = 0.0
var player_max_pickup_streak: int = 0
var player_last_pickup_milestone: int = 0  # Last pickup milestone reached
var player_total_pickups: int = 0  # Total items collected (for collect missions)
var player_crit_chain: int = 0
var player_crit_chain_timer: float = 0.0
var player_invuln_timer: float = 0.0
var player_dash_cooldown_timer: float = 0.0
var player_is_dashing: bool = false
var player_dash_timer: float = 0.0
var player_is_paused: bool = false
var player_is_alive: bool = true
# ── Phase 19: Co-op — P1 downed state (can be revived by P2) ──
var player_is_downed: bool = false
var p1_downed_timer: float = 0.0
var p1_revive_progress: float = 0.0

# ─── Combo Milestone Signal ───────────────────────────────────────────────────
signal combo_milestone(combo: int, tier: int, color: Color)
signal pickup_streak_milestone(streak: int, xp_bonus: int)
signal crit_chain_activated(chain: int)
signal enemy_spawned_near(pos: Vector3, enemy_type: int)
signal damage_taken_from(source_pos: Vector3)  # Phase 5: damage direction indicator
signal enemy_killed(enemy_name: String, killer_name: String)  # Phase 5: kill feed
signal biome_changed(biome_id: int)  # Phase 5: biome indicator
signal p1_downed()  # Phase 19: P1 downed in co-op (can be revived by P2)

# ─── World State ──────────────────────────────────────────────────────────────
var world_seed: int = 0
var current_biome: int = GameConstants.Biome.GRASS
var enemies: Array[Node3D] = []
var collectibles: Array[Node3D] = []
var projectiles: Array[Node3D] = []
var missions: Array = []
var active_buffs: Dictionary = {}
var current_boss: Node = null
var messages: Array[String] = []

# ─── Game State ────────────────────────────────────────────────────────────────
var game_time: float = 0.0
var is_paused: bool = false

# ── Phase 10: Smart Enemy AI — global enrage warning throttle ──
var _last_enrage_warning_time: float = -100.0

# ─── References (lazily populated — autoload _ready runs before main scene) ──
var world: Node3D = null
var player: CharacterBody3D = null
var camera_rig: Node3D = null
var hud: CanvasLayer = null

func _ready() -> void:
	world_seed = randi()
	print("[ZorpWiggles] Game initialized — seed: %d" % world_seed)
	# Defer scene node lookup — autoload is ready before the main scene exists
	call_deferred("_resolve_scene_refs")
	_start_game()

func _resolve_scene_refs() -> void:
	var main: Node = get_tree().current_scene
	if not main:
		return
	world = main.get_node_or_null("World")
	player = main.get_node_or_null("World/Player")
	camera_rig = main.get_node_or_null("CameraRig")
	hud = main.get_node_or_null("HUD")

var _last_difficulty_tier: int = 0

func _process(delta: float) -> void:
	if is_paused:
		return
	if not player_is_alive:
		# ── Phase 19: Co-op — tick P1 downed state ──
		if player_is_downed:
			_update_p1_downed(delta)
		return
	
	game_time += delta
	_update_timers(delta)
	_update_biome_tracking()
	_check_difficulty_tier_change()

func _check_difficulty_tier_change() -> void:
	var current_tier: int = get_time_difficulty_tier()
	if current_tier > _last_difficulty_tier:
		_last_difficulty_tier = current_tier
		if current_tier > 0:
			add_message("⚠ Difficulty Up! Tier %d — Enemies growing stronger..." % current_tier)
			# Screen shake to emphasize the shift
			_trigger_camera_trauma(0.2)

# ── Phase 19: P1 downed state (co-op revive) ──
func _update_p1_downed(delta: float) -> void:
	p1_downed_timer -= delta
	if p1_downed_timer <= 0:
		# Bleed out — die for real
		player_is_downed = false
		_die()
		return
	# Check if P2 is close enough and holding revive key
	if CoOpManager.p2_active and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
		if player and is_instance_valid(player):
			var dist: float = CoOpManager.p2_node.global_position.distance_to(player.global_position)
			if dist <= GameConstants.COOP_REVIVE_RANGE and Input.is_action_pressed("p2_revive"):
				p1_revive_progress += GameConstants.COOP_DOWNED_REVIVE_PROGRESS_TICK * 60.0 * delta
				if p1_revive_progress >= 1.0:
					_revive_p1()
			else:
				p1_revive_progress = max(0.0, p1_revive_progress - delta * 0.5)

func _revive_p1() -> void:
	player_is_alive = true
	player_is_downed = false
	player_hp = GameConstants.COOP_REVIVE_HP_RESTORE
	player_invuln_timer = GameConstants.COOP_REVIVE_INVULN_DURATION
	p1_downed_timer = 0.0
	p1_revive_progress = 0.0
	hp_changed.emit(player_hp, player_max_hp)
	add_message("✨ Zorp revived by %s! Back in action!" % GameConstants.P2_NAME)
	# Reset player mesh visibility/position
	if player and is_instance_valid(player):
		var mesh_node: MeshInstance3D = player.get_node_or_null("BodyMesh")
		if mesh_node:
			mesh_node.visible = true
			mesh_node.position.y = 0.0
		ParticleEffects.spawn_levelup_burst(player.get_parent(), player.global_position)
	# Track co-op revive
	CoOpManager._coop_revives += 1
	CoOpManager._check_coop_milestones()

func _update_timers(delta: float) -> void:
	# Invulnerability timer
	if player_invuln_timer > 0:
		player_invuln_timer -= delta

	# Dash cooldown is now ticked by the player's _physics_process so it can
	# detect the exact frame the cooldown expires and start coyote time.
	# (Previously ticked here — moved to player.gd for coyote-time support.)

	# Combo timer
	if player_combo_timer > 0:
		player_combo_timer -= delta
		if player_combo_timer <= 0:
			player_combo = 0
			player_last_combo_milestone = 0
			combo_changed.emit(player_combo)
	
	# Pickup streak timer
	if player_pickup_streak_timer > 0:
		player_pickup_streak_timer -= delta
		if player_pickup_streak_timer <= 0:
			player_pickup_streak = 0
			player_last_pickup_milestone = 0
	
	# Crit chain timer
	if player_crit_chain_timer > 0:
		player_crit_chain_timer -= delta
		if player_crit_chain_timer <= 0:
			player_crit_chain = 0
	
	# Active buff timers (monolith buffs)
	var buff_keys: Array = active_buffs.keys()
	var expired_buffs: Array[String] = []
	for buff_key in buff_keys:
		active_buffs[buff_key] -= delta
		if active_buffs[buff_key] <= 0:
			expired_buffs.append(buff_key)
	for key in expired_buffs:
		active_buffs.erase(key)
		add_message("%s expired" % key.capitalize())
		# ── Phase 6: Shield break shatter effect on buff expiration ──
		# Spawn a fragment burst at the player's position when a buff expires,
		# color-matched to the buff type for visual feedback.
		if player and is_instance_valid(player):
			var break_color: Color = Color(0.5, 0.5, 0.5)
			match key:
				"speed": break_color = Color(50.0 / 255.0, 1.0, 50.0 / 255.0)
				"damage": break_color = Color(1.0, 100.0 / 255.0, 50.0 / 255.0)
				"xp": break_color = Color(100.0 / 255.0, 200.0 / 255.0, 1.0)
			ParticleEffects.spawn_shield_break_shatter(player.get_parent(), player.global_position, break_color)

func _update_biome_tracking() -> void:
	# Phase 5: Detect biome changes and emit signal for biome indicator
	if not player or not is_instance_valid(player):
		return
	if not world or not world.has_method("get_biome_at"):
		return
	var new_biome: int = world.get_biome_at(player.global_position)
	if new_biome != current_biome:
		current_biome = new_biome
		biome_changed.emit(new_biome)

func _start_game() -> void:
	player_hp = GameConstants.PLAYER_START_HP
	player_max_hp = GameConstants.PLAYER_START_HP
	player_xp = 0
	player_xp_to_next = GameConstants.PLAYER_START_XP
	player_level = 1
	player_score = 0
	player_kills = 0
	player_combo = 0
	player_combo_timer = 0.0
	player_best_combo = 0
	player_last_combo_milestone = 0
	player_pickup_streak = 0
	player_pickup_streak_timer = 0.0
	player_max_pickup_streak = 0
	player_last_pickup_milestone = 0
	player_total_pickups = 0
	player_crit_chain = 0
	player_crit_chain_timer = 0.0
	player_invuln_timer = 0.0
	player_dash_cooldown_timer = 0.0
	player_is_dashing = false
	player_dash_timer = 0.0
	player_is_paused = false
	player_is_alive = true
	player_is_downed = false
	p1_downed_timer = 0.0
	p1_revive_progress = 0.0
	game_time = 0.0
	is_paused = false
	_last_difficulty_tier = 0
	active_buffs.clear()
	current_boss = null
	hp_changed.emit(player_hp, player_max_hp)
	xp_changed.emit(player_xp, player_xp_to_next)

func take_damage(amount: int, source_pos: Vector3 = Vector3.ZERO) -> void:
	if player_invuln_timer > 0 or player_is_dashing or not player_is_alive:
		return
	# ── Phase 13: Apply mutation damage reduction ──
	var actual_amount: int = amount
	if MutationSystem:
		# Ice armor (Snow mutation) reduces all damage
		var dmg_reduction: float = MutationSystem.get_damage_reduction()
		if dmg_reduction > 0:
			actual_amount = int(actual_amount * (1.0 - dmg_reduction))
	# ── Phase 15: Adult companion pet shields Zorp ──
	if player and is_instance_valid(player) and "pet" in player:
		var pet: Node = player.pet
		if pet and is_instance_valid(pet) and pet.has_method("get_shield_reduction"):
			var pet_shield: float = pet.get_shield_reduction()
			if pet_shield > 0:
				actual_amount = int(actual_amount * (1.0 - pet_shield))
	# ── Phase 16: Reflective Shield weapon mod reduces incoming damage ──
	if WeaponModSystem and WeaponModSystem.get_equipped_mod() == GameConstants.WeaponMod.REFLECTIVE_SHIELD:
		actual_amount = int(actual_amount * 0.6)  # 40% damage reduction
	player_hp = max(0, player_hp - actual_amount)
	player_invuln_timer = GameConstants.PLAYER_INVULN_DURATION
	hp_changed.emit(player_hp, player_max_hp)
	# Phase 20: Audio — damage SFX
	AudioManager.play_sfx(AudioManager.SFX_DAMAGE)
	# Camera shake on taking damage — biased toward the damage source so
	# the shake direction matches the hit direction, reinforcing the
	# damage direction indicator. The bias makes the camera lurch away
	# from the attacker for a visceral "hit from the left" feel.
	var shake_dir: Vector3 = Vector3.ZERO
	if source_pos != Vector3.ZERO and player and is_instance_valid(player):
		shake_dir = (player.global_position - source_pos).normalized()
	_trigger_camera_trauma(0.35, shake_dir)
	# Phase 5: Emit damage direction signal (if source_pos is non-zero)
	if source_pos != Vector3.ZERO:
		damage_taken_from.emit(source_pos)
	if player_hp <= 0:
		_die()

func _trigger_camera_trauma(amount: float, bias_dir: Vector3 = Vector3.ZERO) -> void:
	var cam_rig: Node3D = camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(amount, bias_dir)

func heal(amount: int) -> void:
	player_hp = min(player_max_hp, player_hp + amount)
	hp_changed.emit(player_hp, player_max_hp)
	# Phase 20: Audio — heal SFX
	AudioManager.play_sfx(AudioManager.SFX_HEAL)

func gain_xp(amount: int) -> void:
	# Enhancement: Aurora weather boosts XP gain by 50%
	var actual_amount: int = amount
	if WeatherSystem:
		var xp_mult: float = WeatherSystem.get_xp_multiplier()
		if xp_mult != 1.0:
			actual_amount = int(amount * xp_mult)
	# ── Phase 7: Monolith XP buff (Wisdom Aura) ──
	actual_amount = int(actual_amount * get_xp_buff_mult())
	player_xp += actual_amount
	while player_xp >= player_xp_to_next:
		player_xp -= player_xp_to_next
		_level_up()
	xp_changed.emit(player_xp, player_xp_to_next)

func _level_up() -> void:
	player_level += 1
	# ── Phase 7: XP curve and level-up stat scaling ──
	# HP scales with base bonus + tier bonus every 5 levels
	var tier: int = (player_level - 1) / GameConstants.PLAYER_LEVEL_DIFFICULTY_INTERVAL
	var hp_bonus: int = GameConstants.PLAYER_LEVEL_HP_BONUS + tier * GameConstants.PLAYER_LEVEL_HP_TIER_BONUS
	player_max_hp += hp_bonus
	# Heal on level up: base amount or percentage of max HP, whichever is higher
	var heal_amount: int = max(40, int(player_max_hp * GameConstants.PLAYER_LEVEL_HEAL_PERCENT))
	player_hp = min(player_max_hp, player_hp + heal_amount)
	# XP curve: exponential growth using the curve exponent
	player_xp_to_next = int(GameConstants.PLAYER_LEVEL_XP_CURVE_BASE * pow(GameConstants.PLAYER_LEVEL_XP_CURVE_EXP, player_level - 1))
	level_up.emit(player_level)
	# Inform player of stat increases
	GameManager.add_message("⬆ Level %d! HP: %d (+%d) | DMG: +%d | Speed: +%.1f" % [
		player_level, player_max_hp, hp_bonus,
		GameConstants.PLAYER_LEVEL_DMG_BONUS + tier * GameConstants.PLAYER_LEVEL_DMG_TIER_BONUS,
		tier * GameConstants.PLAYER_LEVEL_SPEED_TIER_BONUS
	])
	print("[ZorpWiggles] Level up! Now level %d (HP: %d, XP next: %d)" % [player_level, player_max_hp, player_xp_to_next])
	# Phase 6: Level-up shockwave + particle burst
	if player and is_instance_valid(player):
		ParticleEffects.spawn_levelup_burst(player.get_parent(), player.global_position)
		ParticleEffects.spawn_levelup_shockwave(player.get_parent(), player.global_position)

func add_score(amount: int) -> void:
	player_score += amount
	score_changed.emit(player_score)

func register_kill(enemy_name: String = "", killer_name: String = "Zorp") -> void:
	player_kills += 1
	player_combo += 1
	# ── Phase 19: Co-op shared combo — longer window when P2 is active ──
	player_combo_timer = GameConstants.COMBO_TIMEOUT + CoOpManager.get_combo_window_bonus()
	# ── Phase 19: Track co-op kills ──
	CoOpManager.register_coop_kill(killer_name != GameConstants.P2_NAME)
	if player_combo > player_best_combo:
		player_best_combo = player_combo
	combo_changed.emit(player_combo)
	add_score(100)
	enemy_killed.emit(enemy_name, killer_name)
	
	# Combo milestone check (every COMBO_MILESTONE_INTERVAL kills)
	if player_combo > 0 and player_combo % GameConstants.COMBO_MILESTONE_INTERVAL == 0:
		if player_combo > player_last_combo_milestone:
			player_last_combo_milestone = player_combo
			_check_combo_milestone(player_combo)

func _die() -> void:
	# ── Phase 19: Co-op — P1 goes down instead of dying if P2 is active ──
	if CoOpManager.p2_active and not player_is_downed:
		player_is_downed = true
		player_is_alive = false  # Stops normal processing but doesn't emit player_died
		p1_downed_timer = GameConstants.COOP_DOWNED_TIMER_MAX
		p1_revive_progress = 0.0
		p1_downed.emit()
		add_message("💔 Zorp is down! %s can revive with [.] key!" % GameConstants.P2_NAME)
		print("[GameManager] P1 downed in co-op — awaiting revive")
		return
	# If already downed and bleed-out timer expired, or no co-op partner → actual death
	player_is_alive = false
	player_is_downed = false
	player_died.emit()
	print("[ZorpWiggles] Zorp died! Score: %d, Kills: %d, Best Combo: %d" % [player_score, player_kills, player_best_combo])

func restart_game() -> void:
	# Clear enemies, collectibles, projectiles
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	for collectible in collectibles:
		if is_instance_valid(collectible):
			collectible.queue_free()
	for proj in projectiles:
		if is_instance_valid(proj):
			proj.queue_free()
	enemies.clear()
	collectibles.clear()
	projectiles.clear()
	# ── Phase 19: Reset co-op state ──
	player_is_downed = false
	p1_downed_timer = 0.0
	p1_revive_progress = 0.0
	CoOpManager.reset()
	_start_game()
	game_restarted.emit()

func add_combo() -> void:
	player_combo += 1
	# ── Phase 19: Co-op shared combo — longer window ──
	player_combo_timer = GameConstants.COMBO_TIMEOUT + CoOpManager.get_combo_window_bonus()
	if player_combo > player_best_combo:
		player_best_combo = player_combo
	combo_changed.emit(player_combo)
	# Combo milestone check
	if player_combo > 0 and player_combo % GameConstants.COMBO_MILESTONE_INTERVAL == 0:
		if player_combo > player_last_combo_milestone:
			player_last_combo_milestone = player_combo
			_check_combo_milestone(player_combo)

func _check_combo_milestone(combo: int) -> void:
	# Tier = combo / interval (x5 = tier 1, x10 = tier 2, etc.)
	var tier: int = combo / GameConstants.COMBO_MILESTONE_INTERVAL
	var color_idx: int = (tier - 1) % GameConstants.COMBO_MILESTONE_FLASH_COLORS.size()
	var flash_color: Color = GameConstants.COMBO_MILESTONE_FLASH_COLORS[color_idx]

	# XP bonus: base + per-tier extra
	var xp_bonus: int = GameConstants.COMBO_MILESTONE_XP_BASE + (tier - 1) * GameConstants.COMBO_MILESTONE_XP_PER_TIER
	gain_xp(xp_bonus)

	# Emit milestone signal for HUD flash + message
	combo_milestone.emit(combo, tier, flash_color)
	add_message("★ COMBO MILESTONE x%d! +%d XP" % [combo, xp_bonus])

	# Phase 6: Combo milestone fireworks
	if player and is_instance_valid(player):
		ParticleEffects.spawn_combo_fireworks(player.get_parent(), player.global_position, tier)

func add_pickup_streak() -> void:
	player_pickup_streak += 1
	player_total_pickups += 1
	player_pickup_streak_timer = GameConstants.PICKUP_STREAK_WINDOW
	if player_pickup_streak > player_max_pickup_streak:
		player_max_pickup_streak = player_pickup_streak
	
	# Pickup streak milestone check
	if player_pickup_streak > 0 and player_pickup_streak % GameConstants.PICKUP_STREAK_MILESTONE_INTERVAL == 0:
		if player_pickup_streak > player_last_pickup_milestone:
			player_last_pickup_milestone = player_pickup_streak
			var xp_bonus: int = GameConstants.PICKUP_STREAK_XP_PER_MILESTONE
			gain_xp(xp_bonus)
			pickup_streak_milestone.emit(player_pickup_streak, xp_bonus)
			add_message("✦ PICKUP STREAK x%d! +%d XP" % [player_pickup_streak, xp_bonus])

func add_message(text: String) -> void:
	messages.append(text)
	message_added.emit(text)
	print("[ZorpWiggles] %s" % text)

# ── Phase 18: Boss Arena — track current boss ──
func set_current_boss(boss: Node) -> void:
	current_boss = boss

func clear_current_boss() -> void:
	current_boss = null

# ── Phase 7: Monolith buff multiplier queries ──
# These let player.gd, projectile.gd, and gain_xp() apply active monolith buffs
# without each system needing to know the buff dictionary structure.

func get_speed_buff_mult() -> float:
	if active_buffs.has("speed"):
		return GameConstants.MONOLITH_SPEED_MULT
	return 1.0

func get_damage_buff_mult() -> float:
	if active_buffs.has("damage"):
		return GameConstants.MONOLITH_DAMAGE_MULT
	return 1.0

func get_xp_buff_mult() -> float:
	if active_buffs.has("xp"):
		return GameConstants.MONOLITH_XP_MULT
	return 1.0

# ── Phase 7: Difficulty scaling over time ──
# Returns the current time-based difficulty tier (0-based, capped at MAX_TIER).
# Each tier = DIFFICULTY_TIME_INTERVAL seconds survived.
func get_time_difficulty_tier() -> int:
	return int(min(GameConstants.DIFFICULTY_TIME_MAX_TIER, game_time / GameConstants.DIFFICULTY_TIME_INTERVAL))

# Time-based enemy HP multiplier (1.0 + tier * HP_SCALE)
func get_time_enemy_hp_mult() -> float:
	return 1.0 + get_time_difficulty_tier() * GameConstants.DIFFICULTY_TIME_HP_SCALE

# Time-based enemy damage multiplier
func get_time_enemy_damage_mult() -> float:
	return 1.0 + get_time_difficulty_tier() * GameConstants.DIFFICULTY_TIME_DAMAGE_SCALE

# Time-based enemy speed multiplier
func get_time_enemy_speed_mult() -> float:
	return 1.0 + get_time_difficulty_tier() * GameConstants.DIFFICULTY_TIME_SPEED_SCALE

# Time-based spawn interval multiplier (< 1.0 = faster spawns)
func get_time_spawn_interval_mult() -> float:
	return max(0.3, 1.0 - get_time_difficulty_tier() * GameConstants.DIFFICULTY_TIME_SPAWN_ACCEL)

# Time-based max enemy count bonus
func get_time_max_enemy_bonus() -> int:
	var tier: int = get_time_difficulty_tier()
	return int(float(tier) / float(GameConstants.DIFFICULTY_TIME_MAX_TIER) * GameConstants.DIFFICULTY_TIME_MAX_ENEMY_BONUS)