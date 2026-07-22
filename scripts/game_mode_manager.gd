## Zorp Wiggles — Game Mode Manager (Phase 25: Progression & Meta-Systems)
## Autoload singleton that selects and governs alternate game modes:
##   NORMAL     — default open-world exploration (the existing game)
##   ENDLESS    — wave-based escalation, no exploration goals, pure combat
##   BOSS_RUSH  — fight every boss type back-to-back with a running timer
##   SPEEDRUN   — open-world run with a visible timer + biome split tracking
##
## The mode is chosen on the main menu (Mode Select screen) before starting
## the game. It persists to user://zorp_gamemode.json so the last selection
## is remembered. During a run, GameModeManager exposes queries that other
## systems (EnemySpawner, BossArena, HUD) use to adjust their behavior.
##
## Endless Mode: EnemySpawner spawns faster and ignores the world-center
## distance tier (all enemies come from the hard pool sooner); a wave counter
## ticks up every 30s and amplifies difficulty on top of the time-based tier.
## World exploration structures (traders, lore stones, treasure chests) are
## de-emphasized — they still exist but the player is encouraged to fight.
##
## Boss Rush Mode: EnemySpawner normal spawning is disabled; BossArena's
## auto-spawn is replaced by a sequential queue of every boss type. Between
## bosses the player is fully healed. A running timer tracks total time;
## defeating all bosses triggers a victory screen with the final time.
##
## Speedrun Mode: A timer HUD (SpeedrunTimer) shows the total run time and
## records a split each time the player enters a new biome. Personal bests
## per biome count and total run time are persisted via Statistics.

extends Node

# ─── Signals ──────────────────────────────────────────────────────────────────
signal mode_changed(new_mode: int)
signal wave_changed(wave: int)
signal boss_rush_boss_index(index: int, total: int)  # 0-based index of current boss
signal boss_rush_completed(total_time: float)
signal speedrun_split(biome_id: int, split_time: float)
signal speedrun_completed(total_time: float)

# ─── Game Modes ───────────────────────────────────────────────────────────────
enum Mode {
	NORMAL,      # Default open-world exploration
	ENDLESS,     # Wave-based escalation, pure combat
	BOSS_RUSH,   # Fight all bosses back-to-back, timer
	SPEEDRUN,    # Open-world with timer + biome splits
	PVP,         # Phase 32: Local 1v1 PvP arena
	SURVIVAL,    # Phase 34: No healing, no shops, one life
	GAUNTLET,    # Phase 34: Sequential biome challenges, no breaks, timer
	BOSS_GAUNTLET, # Phase 34: Every boss in sequence, escalating, no healing
	DAILY_CHALLENGE, # Phase 25: Seed-based daily challenge, one attempt per day
	WEEKLY_CHALLENGE, # Phase 25: Seed-based weekly challenge, 3 attempts per week
}

const MODE_NAMES: Array[String] = ["Normal", "Endless", "Boss Rush", "Speedrun", "PvP", "Survival", "Gauntlet", "Boss Gauntlet", "Daily", "Weekly"]
const MODE_ICONS: Array[String] = ["🌍", "♾", "💀", "⏱", "⚔", "☠", "⚔", "☠", "📅", "🗓"]
const MODE_DESCRIPTIONS: Array[String] = [
	"Default open-world adventure. Explore 19 biomes, complete missions, find loot, fight bosses, raise a pet.",
	"Wave-based survival escalation. No exploration goals — pure combat. Each wave amps difficulty. How long can you last?",
	"Fight every boss type back-to-back with no healing between except a top-up after each kill. Timer runs. Beat them all!",
	"Open-world run with a visible timer. Each new biome records a split time. Set a personal best for total run time.",
	"Local 1v1 PvP arena. Zorp vs Zerp — first to win the majority of rounds wins the match. Best of 3 or 5.",
	"Phase 34 — No healing, no shops, one life. Every 3 minutes a boss spawns. Survive as long as you can. Passive score per second.",
	"Phase 34 — Sequential biome challenges with no breaks. Each biome: kill 15 enemies in 90 seconds. Timer runs across all 5.",
	"Phase 34 — Every boss type in sequence with escalating HP/damage/speed. NO healing between bosses. How far can you get?",
	"Phase 25 — Daily Challenge: a deterministic seed + fixed modifiers for today. One attempt per day. Compare scores with friends!",
	"Phase 25 — Weekly Challenge: a deterministic seed + 4-5 modifiers for this week. Up to 3 attempts. Best score counts. More chaos!",
]
const MODE_COLORS: Array[Color] = [
	Color(0.5, 0.9, 0.6),   # Normal — green
	Color(1.0, 0.6, 0.2),   # Endless — orange
	Color(1.0, 0.25, 0.25), # Boss Rush — red
	Color(0.4, 0.8, 1.0),   # Speedrun — cyan
	Color(0.9, 0.4, 0.8),   # PvP — magenta
	Color(0.8, 0.2, 0.2),   # Survival — blood red
	Color(0.9, 0.6, 0.2),   # Gauntlet — amber
	Color(0.3, 0.1, 0.2),   # Boss Gauntlet — dark crimson
	Color(0.95, 0.75, 0.3), # Daily — gold
	Color(0.6, 0.4, 0.9),   # Weekly — purple
]

# ─── Endless Mode Tuning ──────────────────────────────────────────────────────
const ENDLESS_WAVE_INTERVAL: float = 30.0       # Seconds per wave
const ENDLESS_WAVE_SPAWN_ACCEL: float = 0.08     # Each wave: -8% spawn interval
const ENDLESS_WAVE_HP_SCALE: float = 0.10       # Each wave: +10% enemy HP
const ENDLESS_WAVE_DAMAGE_SCALE: float = 0.06   # Each wave: +6% enemy damage
const ENDLESS_WAVE_SPEED_SCALE: float = 0.03     # Each wave: +3% enemy speed
const ENDLESS_MAX_WAVE: int = 999                # Effectively uncapped

# ─── Boss Rush Mode Tuning ────────────────────────────────────────────────────
# Ordered list of boss enemy types to fight in sequence. Each is loaded from its
# scene and scaled to the player's level. The fight is sealed in a BossArena.
const BOSS_RUSH_QUEUE: Array[int] = [
	GameConstants.EnemyType.DRAKE,
	GameConstants.EnemyType.SERPENT,
	GameConstants.EnemyType.GRAVITON,
	GameConstants.EnemyType.VOID_LEVIATHAN,
	GameConstants.EnemyType.ANCIENT_SENTINEL,
]
const BOSS_RUSH_HEAL_BETWEEN: int = 9999  # Full heal between bosses (capped by max HP)
const BOSS_RUSH_INTERMISSION: float = 4.0  # Seconds between boss death and next spawn
const BOSS_RUSH_SPAWN_DISTANCE: float = 18.0  # Distance from player to spawn next boss

# ─── Speedrun Mode Tuning ─────────────────────────────────────────────────────
const SPEEDRUN_SPLIT_BIOME_COUNT: int = 8  # Number of unique biomes to visit for "completion"
const SPEEDRUN_SPLIT_BONUS_XP: int = 50    # XP bonus per new biome split

# ─── State ────────────────────────────────────────────────────────────────────
var _current_mode: int = Mode.NORMAL
var _wave: int = 0
var _wave_timer: float = 0.0
var _boss_rush_index: int = 0  # 0-based index into BOSS_RUSH_QUEUE
var _boss_rush_active: bool = false
var _boss_rush_intermission_timer: float = 0.0
var _boss_rush_total_time: float = 0.0
var _boss_rush_completed: bool = false
var _speedrun_total_time: float = 0.0
var _speedrun_splits: Dictionary = {}  # biome_id → split time (seconds)
var _speedrun_visited_biomes: Array[int] = []
var _speedrun_finished: bool = false

# Persisted personal bests (loaded from Statistics lifetime stats)
const SPEEDRUN_PB_KEY: String = "speedrun_pb_total"
const SPEEDRUN_PB_SPLITS_KEY: String = "speedrun_pb_splits"

const SAVE_PATH: String = "user://zorp_gamemode.json"

# ─── Public API ────────────────────────────────────────────────────────────────

func _init() -> void:
	# Load the persisted mode selection in _init() (not _ready()) so the mode
	# is available before any other autoload's _ready() calls start_run().
	# Autoloads are instantiated in order; _init() runs at construction time,
	# before the node enters the tree. This guarantees _current_mode is set
	# before GameManager._ready() → _start_game() → start_run() runs.
	_load()

func _ready() -> void:
	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)
		GameManager.player_died.connect(_on_player_died)
		GameManager.boss_defeated.connect(_on_boss_defeated)
		GameManager.boss_spawned.connect(_on_boss_spawned)
		GameManager.biome_changed.connect(_on_biome_changed)

func _exit_tree() -> void:
	_save()

# ─── Save/Load (mode selection only — run state is ephemeral) ─────────────────

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_current_mode = int(parsed.get("mode", Mode.NORMAL))
	_current_mode = clampi(_current_mode, 0, MODE_NAMES.size() - 1)
	print("[GameMode] Loaded — mode: %s" % MODE_NAMES[_current_mode])

func _save() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_warning("[GameMode] Could not write save file.")
		return
	var data: Dictionary = {"mode": _current_mode}
	file.store_string(JSON.stringify(data, "  "))
	file.close()

# ─── Mode Selection ───────────────────────────────────────────────────────────

func get_current_mode() -> int:
	return _current_mode

func get_mode_name() -> String:
	return MODE_NAMES[_current_mode]

func get_mode_icon() -> String:
	return MODE_ICONS[_current_mode]

func set_mode(mode: int) -> void:
	if mode < 0 or mode >= MODE_NAMES.size():
		return
	if mode == _current_mode:
		return
	_current_mode = mode
	_save()
	mode_changed.emit(_current_mode)
	print("[GameMode] Mode set to: %s" % MODE_NAMES[_current_mode])

func cycle_mode() -> void:
	set_mode((_current_mode + 1) % MODE_NAMES.size())

# ─── Per-Mode Queries (used by other systems) ─────────────────────────────────

func is_normal() -> bool:
	return _current_mode == Mode.NORMAL

func is_endless() -> bool:
	return _current_mode == Mode.ENDLESS

func is_boss_rush() -> bool:
	return _current_mode == Mode.BOSS_RUSH

func is_speedrun() -> bool:
	return _current_mode == Mode.SPEEDRUN

func is_pvp() -> bool:
	return _current_mode == Mode.PVP

func is_survival() -> bool:
	return _current_mode == Mode.SURVIVAL

func is_gauntlet() -> bool:
	return _current_mode == Mode.GAUNTLET

func is_boss_gauntlet() -> bool:
	return _current_mode == Mode.BOSS_GAUNTLET

func is_daily_challenge() -> bool:
	return _current_mode == Mode.DAILY_CHALLENGE

func is_weekly_challenge() -> bool:
	return _current_mode == Mode.WEEKLY_CHALLENGE

# Endless Mode: wave-based difficulty multipliers (on top of time-based tier)
func get_endless_wave() -> int:
	return _wave

func get_endless_wave_timer() -> float:
	# Time remaining in the current wave (for HUD progress bar)
	return _wave_timer

func get_endless_wave_hp_mult() -> float:
	if not is_endless():
		return 1.0
	return 1.0 + _wave * ENDLESS_WAVE_HP_SCALE

func get_endless_wave_damage_mult() -> float:
	if not is_endless():
		return 1.0
	return 1.0 + _wave * ENDLESS_WAVE_DAMAGE_SCALE

func get_endless_wave_speed_mult() -> float:
	if not is_endless():
		return 1.0
	return 1.0 + _wave * ENDLESS_WAVE_SPEED_SCALE

func get_endless_wave_spawn_interval_mult() -> float:
	if not is_endless():
		return 1.0
	# Each wave reduces spawn interval (faster spawns). Clamped to 0.3 minimum.
	return maxf(0.3, 1.0 - _wave * ENDLESS_WAVE_SPAWN_ACCEL)

# Boss Rush Mode: disable normal spawning, drive sequential boss spawns
func is_boss_rush_active() -> bool:
	return _boss_rush_active

func get_boss_rush_index() -> int:
	return _boss_rush_index

func get_boss_rush_total() -> int:
	return BOSS_RUSH_QUEUE.size()

func get_boss_rush_total_time() -> float:
	return _boss_rush_total_time

func is_boss_rush_completed() -> bool:
	return _boss_rush_completed

# Speedrun Mode: timer + splits
func get_speedrun_time() -> float:
	return _speedrun_total_time

func get_speedrun_splits() -> Dictionary:
	return _speedrun_splits.duplicate()

func get_speedrun_visited_count() -> int:
	return _speedrun_visited_biomes.size()

func is_speedrun_finished() -> bool:
	return _speedrun_finished

# Personal best helpers (read from Statistics lifetime stats)
func get_speedrun_pb() -> float:
	if not Statistics:
		return 0.0
	var v: Variant = Statistics.get_lifetime_stat(SPEEDRUN_PB_KEY)
	if v == null:
		return 0.0
	return float(v)

func get_speedrun_pb_splits() -> Dictionary:
	if not Statistics:
		return {}
	var v: Variant = Statistics.get_lifetime_stat(SPEEDRUN_PB_SPLITS_KEY)
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	return v

# ─── Run Lifecycle ────────────────────────────────────────────────────────────
# Called by GameManager._start_game() to reset mode-specific run state.

func start_run() -> void:
	_wave = 0
	_wave_timer = ENDLESS_WAVE_INTERVAL
	_boss_rush_index = 0
	_boss_rush_active = false
	_boss_rush_intermission_timer = 0.0
	_boss_rush_total_time = 0.0
	_boss_rush_completed = false
	_speedrun_total_time = 0.0
	_speedrun_splits.clear()
	_speedrun_visited_biomes.clear()
	_speedrun_finished = false
	mode_changed.emit(_current_mode)
	if is_endless():
		wave_changed.emit(_wave)
		GameManager.add_message("♾ Endless Mode — Wave 1 begins! Survive as long as you can.")
	elif is_boss_rush():
		GameManager.add_message("💀 Boss Rush! Defeat all %d bosses as fast as possible!" % BOSS_RUSH_QUEUE.size())
		# Start the first boss after a short delay so the player can orient
		_boss_rush_active = true
		_boss_rush_intermission_timer = 2.0
		boss_rush_boss_index.emit(_boss_rush_index, BOSS_RUSH_QUEUE.size())
	elif is_speedrun():
		GameManager.add_message("⏱ Speedrun! Visit %d unique biomes as fast as possible!" % SPEEDRUN_SPLIT_BIOME_COUNT)
	elif is_pvp():
		# Phase 32: Start a PvP match — force P2 to join and begin the match
		if CoOpManager and not CoOpManager.p2_active:
			CoOpManager.drop_in_p2()
		if PvpArena:
			PvpArena.start_pvp_match(3)  # Best of 3 by default
		GameManager.add_message("⚔ PvP Arena! Zorp vs Zerp — first to 2 round wins!")
	elif is_survival():
		# Phase 34: Survival mode — EndgameManager drives the rules.
		if EndgameManager:
			EndgameManager.start_survival()
	elif is_gauntlet():
		# Phase 34: Gauntlet mode — sequential biome challenges.
		if EndgameManager:
			EndgameManager.start_gauntlet()
	elif is_boss_gauntlet():
		# Phase 34: Boss Gauntlet — every boss in sequence, escalating.
		if EndgameManager:
			EndgameManager.start_boss_gauntlet()
	elif is_daily_challenge():
		# Phase 25: Daily Challenge — start the attempt via DailyChallengeSystem.
		if DailyChallengeSystem:
			if not DailyChallengeSystem.start_daily_attempt():
				# Already attempted today — revert to Normal mode and inform the player.
				GameManager.add_message("📅 Daily Challenge already attempted today — starting Normal mode instead.")
				set_mode(Mode.NORMAL)
			else:
				GameManager.add_message("📅 Daily Challenge started! Seed: %s" % DailyChallengeSystem.get_today_seed_string())
				if DailyChallengeSystem.get_today_modifiers().size() > 0:
					GameManager.add_message("🎲 Today's modifiers: %s" % DailyChallengeSystem.get_today_modifier_names())
	elif is_weekly_challenge():
		# Phase 25: Weekly Challenge — start the attempt via WeeklyChallengeSystem.
		if WeeklyChallengeSystem:
			if not WeeklyChallengeSystem.start_weekly_attempt():
				# No attempts remaining this week — revert to Normal mode
				GameManager.add_message("🗓 Weekly Challenge: no attempts remaining this week — starting Normal mode instead.")
				set_mode(Mode.NORMAL)
			else:
				GameManager.add_message("🗓 Weekly Challenge started! Seed: %s  (Attempt %d/%d)" % [
					WeeklyChallengeSystem.get_week_seed_string(),
					WeeklyChallengeSystem.get_attempts_remaining() > 0 and (WeeklyChallengeSystem.WEEKLY_MAX_ATTEMPTS - WeeklyChallengeSystem.get_attempts_remaining() + 1) or WeeklyChallengeSystem.WEEKLY_MAX_ATTEMPTS,
					WeeklyChallengeSystem.WEEKLY_MAX_ATTEMPTS
				])
				if WeeklyChallengeSystem.get_week_modifiers().size() > 0:
					GameManager.add_message("🎲 This week's modifiers: %s" % WeeklyChallengeSystem.get_week_modifier_names())

# ─── Per-Frame Update ─────────────────────────────────────────────────────────
# Called by GameManager._process() (so it pauses with the game).

func update(delta: float) -> void:
	if GameManager.is_paused or not GameManager.player_is_alive:
		return
	if is_endless():
		_update_endless(delta)
	elif is_boss_rush():
		_update_boss_rush(delta)
	elif is_speedrun():
		_update_speedrun(delta)
	# Phase 34: EndgameManager handles Survival / Gauntlet / Boss Gauntlet
	# per-frame logic independently of the base mode dispatcher.
	if EndgameManager:
		EndgameManager.update(delta)

func _update_endless(delta: float) -> void:
	_wave_timer -= delta
	if _wave_timer <= 0:
		_wave += 1
		_wave_timer = ENDLESS_WAVE_INTERVAL
		wave_changed.emit(_wave)
		GameManager.add_message("♾ Wave %d! Enemies grow stronger..." % _wave)
		# Small camera shake to mark the wave transition
		if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
			GameManager.camera_rig.add_trauma(0.25)
		AudioManager.play_sfx(AudioManager.SFX_COMBO_MILESTONE)

func _update_boss_rush(delta: float) -> void:
	if _boss_rush_completed:
		return
	_boss_rush_total_time += delta
	# If between bosses, count down the intermission then spawn the next
	if _boss_rush_intermission_timer > 0:
		_boss_rush_intermission_timer -= delta
		if _boss_rush_intermission_timer <= 0:
			_spawn_next_boss_rush_boss()
		return
	# If no boss is active and we're not in intermission, the previous boss
	# was defeated — start the intermission (heal + delay before next).
	if GameManager.current_boss == null or not is_instance_valid(GameManager.current_boss):
		# Make sure we don't double-trigger: only start intermission if we
		# were actively fighting (index points at the just-defeated boss).
		if _boss_rush_index >= BOSS_RUSH_QUEUE.size():
			_finish_boss_rush()
			return
		_start_boss_rush_intermission()

func _update_speedrun(delta: float) -> void:
	if _speedrun_finished:
		return
	_speedrun_total_time += delta

# ─── Boss Rush: spawn next boss in the queue ──────────────────────────────────

func _spawn_next_boss_rush_boss() -> void:
	if _boss_rush_index >= BOSS_RUSH_QUEUE.size():
		_finish_boss_rush()
		return
	var boss_type: int = BOSS_RUSH_QUEUE[_boss_rush_index]
	var scene_path: String = _boss_rush_scene_path(boss_type)
	var scene: PackedScene = load(scene_path)
	if not scene:
		push_warning("[GameMode] Boss Rush: could not load boss scene %s — skipping." % scene_path)
		_boss_rush_index += 1
		_boss_rush_intermission_timer = 1.0
		return
	var player: Node3D = GameManager.player
	if not player or not is_instance_valid(player):
		# Player not resolved yet — retry shortly. This can happen if the
		# scene refs haven't been resolved by the time the first intermission
		# expires (rare, but safe to handle).
		_boss_rush_intermission_timer = 0.5
		return
	var boss: CharacterBody3D = scene.instantiate()
	var angle: float = randf() * TAU
	var spawn_pos: Vector3 = player.global_position + Vector3(
		cos(angle) * BOSS_RUSH_SPAWN_DISTANCE, 1.0, sin(angle) * BOSS_RUSH_SPAWN_DISTANCE
	)
	boss.position = spawn_pos
	# Add to the world node (parent of the spawner). GameManager.world is the
	# WorldGenerator; adding the boss there matches normal enemy spawning.
	var world: Node = GameManager.world if GameManager.world else get_tree().current_scene
	world.add_child(boss)
	GameManager.enemies.append(boss)
	# Scale boss to player level + Boss Rush bonus toughness
	if boss is EnemyBase:
		var hp_mult: float = 1.0 + (GameManager.player_level - 1) * 0.1
		var new_hp: int = int(boss.max_hp * hp_mult)
		boss.max_hp = new_hp
		boss.hp = new_hp
		# Non-Drake / non-new bosses need the arena-boss flag to emit boss_defeated
		var is_new_boss: bool = boss_type == GameConstants.EnemyType.VOID_LEVIATHAN or \
			boss_type == GameConstants.EnemyType.ANCIENT_SENTINEL
		if boss_type != GameConstants.EnemyType.DRAKE and not is_new_boss:
			boss.is_arena_boss = true
	# Emit boss_spawned so BossArena seals the player in and the HUD shows the bar
	GameManager.boss_spawned.emit(boss)
	boss_rush_boss_index.emit(_boss_rush_index, BOSS_RUSH_QUEUE.size())
	var bname: String = "Boss"
	if "enemy_name" in boss:
		bname = boss.enemy_name
	GameManager.add_message("💀 Boss %d/%d: %s" % [_boss_rush_index + 1, BOSS_RUSH_QUEUE.size(), bname])

func _boss_rush_scene_path(boss_type: int) -> String:
	match boss_type:
		GameConstants.EnemyType.DRAKE:
			return "res://scenes/entities/enemy_drake.tscn"
		GameConstants.EnemyType.SERPENT:
			return "res://scenes/entities/enemy_serpent.tscn"
		GameConstants.EnemyType.GRAVITON:
			return "res://scenes/entities/enemy_graviton.tscn"
		GameConstants.EnemyType.VOID_LEVIATHAN:
			return "res://scenes/entities/enemy_void_leviathan.tscn"
		GameConstants.EnemyType.ANCIENT_SENTINEL:
			return "res://scenes/entities/enemy_ancient_sentinel.tscn"
		_:
			return "res://scenes/entities/enemy_drake.tscn"

func _start_boss_rush_intermission() -> void:
	# Heal the player between bosses
	if GameManager.player_is_alive:
		GameManager.heal(BOSS_RUSH_HEAL_BETWEEN)
	GameManager.add_message("✦ Boss down! Next boss in %.0fs..." % BOSS_RUSH_INTERMISSION)
	_boss_rush_intermission_timer = BOSS_RUSH_INTERMISSION
	_boss_rush_index += 1
	if _boss_rush_index >= BOSS_RUSH_QUEUE.size():
		_finish_boss_rush()

func _finish_boss_rush() -> void:
	_boss_rush_completed = true
	_boss_rush_active = false
	boss_rush_completed.emit(_boss_rush_total_time)
	GameManager.add_message("🏆 BOSS RUSH COMPLETE! Total time: %s" % _format_time(_boss_rush_total_time))
	# Record personal best for boss rush total time
	if Statistics:
		Statistics.set_lifetime_max("boss_rush_pb_time", _boss_rush_total_time)
	AudioManager.play_sfx(AudioManager.SFX_LEVEL_UP)

# ─── Speedrun: biome split tracking ───────────────────────────────────────────

func _on_biome_changed(biome_id: int) -> void:
	if not is_speedrun() or _speedrun_finished:
		return
	if biome_id in _speedrun_visited_biomes:
		return  # Only split on FIRST visit to each biome
	_speedrun_visited_biomes.append(biome_id)
	_speedrun_splits[biome_id] = _speedrun_total_time
	speedrun_split.emit(biome_id, _speedrun_total_time)
	GameManager.add_message("⏱ Biome split %d/%d: %s — %s" % [
		_speedrun_visited_biomes.size(),
		SPEEDRUN_SPLIT_BIOME_COUNT,
		GameConstants.BIOME_NAMES.get(biome_id, "Unknown"),
		_format_time(_speedrun_total_time)
	])
	# Bonus XP for finding a new biome
	GameManager.gain_xp(SPEEDRUN_SPLIT_BONUS_XP)
	AudioManager.play_sfx(AudioManager.SFX_LEVEL_UP)
	if _speedrun_visited_biomes.size() >= SPEEDRUN_SPLIT_BIOME_COUNT:
		_finish_speedrun()

func _finish_speedrun() -> void:
	_speedrun_finished = true
	speedrun_completed.emit(_speedrun_total_time)
	GameManager.add_message("🏆 SPEEDRUN COMPLETE! Total time: %s" % _format_time(_speedrun_total_time))
	# Persist personal best (lowest time wins)
	if Statistics:
		var prev_pb: float = get_speedrun_pb()
		if prev_pb <= 0.0 or _speedrun_total_time < prev_pb:
			Statistics.set_lifetime_stat(SPEEDRUN_PB_KEY, _speedrun_total_time)
			Statistics.set_lifetime_stat(SPEEDRUN_PB_SPLITS_KEY, _speedrun_splits)
			GameManager.add_message("🏆 NEW PERSONAL BEST!")
	AudioManager.play_sfx(AudioManager.SFX_LEVEL_UP)

# ─── Signal Handlers ───────────────────────────────────────────────────────────

func _on_game_restarted() -> void:
	# Reset run state but keep the selected mode
	start_run()

func _on_player_died() -> void:
	# Stop active timers; the death screen handles the rest
	_boss_rush_active = false
	_speedrun_finished = true  # Stops the timer counting up

func _on_boss_spawned(_boss: Node) -> void:
	pass  # Boss Rush tracks boss death, not spawn

func _on_boss_defeated(_boss: Node) -> void:
	# In Boss Rush, the intermission is started by _update_boss_rush when it
	# notices current_boss is null. We just need to make sure the boss arena
	# doesn't auto-spawn another boss (handled by the spawner override below).
	pass

# ─── Helpers ───────────────────────────────────────────────────────────────────

func _format_time(seconds: float) -> String:
	var s: float = seconds
	var h: int = int(s) / 3600
	var m: int = (int(s) % 3600) / 60
	var sec: int = int(s) % 60
	var ms: int = int(fmod(s, 1.0) * 100.0)
	if h > 0:
		return "%dh %02dm %02ds.%02d" % [h, m, sec, ms]
	elif m > 0:
		return "%dm %02ds.%02d" % [m, sec, ms]
	else:
		return "%ds.%02d" % [sec, ms]