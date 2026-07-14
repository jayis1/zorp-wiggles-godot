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
var player_pickup_streak: int = 0
var player_pickup_streak_timer: float = 0.0
var player_max_pickup_streak: int = 0
var player_crit_chain: int = 0
var player_crit_chain_timer: float = 0.0
var player_invuln_timer: float = 0.0
var player_dash_cooldown_timer: float = 0.0
var player_is_dashing: bool = false
var player_dash_timer: float = 0.0
var player_is_paused: bool = false
var player_is_alive: bool = true

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

# ─── References ───────────────────────────────────────────────────────────────
@onready var world: Node3D = $World
@onready var player: CharacterBody3D = $World/Player
@onready var camera_rig: Node3D = $CameraRig
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	world_seed = randi()
	print("[ZorpWiggles] Game initialized — seed: %d" % world_seed)
	_start_game()

func _process(delta: float) -> void:
	if is_paused or not player_is_alive:
		return
	
	game_time += delta
	_update_timers(delta)

func _update_timers(delta: float) -> void:
	# Invulnerability timer
	if player_invuln_timer > 0:
		player_invuln_timer -= delta
	
	# Dash cooldown
	if player_dash_cooldown_timer > 0:
		player_dash_cooldown_timer -= delta
	
	# Combo timer
	if player_combo_timer > 0:
		player_combo_timer -= delta
		if player_combo_timer <= 0:
			player_combo = 0
			combo_changed.emit(player_combo)
	
	# Pickup streak timer
	if player_pickup_streak_timer > 0:
		player_pickup_streak_timer -= delta
		if player_pickup_streak_timer <= 0:
			player_pickup_streak = 0
	
	# Crit chain timer
	if player_crit_chain_timer > 0:
		player_crit_chain_timer -= delta
		if player_crit_chain_timer <= 0:
			player_crit_chain = 0

func _start_game() -> void:
	player_hp = GameConstants.PLAYER_START_HP
	player_max_hp = GameConstants.PLAYER_START_HP
	player_xp = 0
	player_xp_to_next = GameConstants.PLAYER_START_XP
	player_level = 1
	player_score = 0
	player_kills = 0
	player_combo = 0
	player_best_combo = 0
	player_pickup_streak = 0
	player_max_pickup_streak = 0
	player_crit_chain = 0
	player_invuln_timer = 0.0
	player_is_alive = true
	game_time = 0.0
	is_paused = false
	hp_changed.emit(player_hp, player_max_hp)
	xp_changed.emit(player_xp, player_xp_to_next)

func take_damage(amount: int) -> void:
	if player_invuln_timer > 0 or player_is_dashing or not player_is_alive:
		return
	player_hp = max(0, player_hp - amount)
	player_invuln_timer = GameConstants.PLAYER_INVULN_DURATION
	hp_changed.emit(player_hp, player_max_hp)
	if player_hp <= 0:
		_die()

func heal(amount: int) -> void:
	player_hp = min(player_max_hp, player_hp + amount)
	hp_changed.emit(player_hp, player_max_hp)

func gain_xp(amount: int) -> void:
	player_xp += amount
	while player_xp >= player_xp_to_next:
		player_xp -= player_xp_to_next
		_level_up()
	xp_changed.emit(player_xp, player_xp_to_next)

func _level_up() -> void:
	player_level += 1
	player_max_hp += GameConstants.PLAYER_LEVEL_HP_BONUS
	player_hp = player_max_hp  # Full heal on level up
	player_xp_to_next = int(player_xp_to_next * GameConstants.PLAYER_LEVEL_XP_MULT)
	level_up.emit(player_level)
	print("[ZorpWiggles] Level up! Now level %d" % player_level)

func add_score(amount: int) -> void:
	player_score += amount
	score_changed.emit(player_score)

func register_kill() -> void:
	player_kills += 1
	player_combo += 1
	player_combo_timer = 3.0
	if player_combo > player_best_combo:
		player_best_combo = player_combo
	combo_changed.emit(player_combo)
	add_score(100)

func _die() -> void:
	player_is_alive = false
	player_died.emit()
	print("[ZorpWiggles] Zorp died! Score: %d, Kills: %d, Best Combo: %d" % [player_score, player_kills, player_best_combo])

func restart_game() -> void:
	# Clear enemies, collectibles, projectiles
	for enemy in enemies:
		enemy.queue_free()
	for collectible in collectibles:
		collectible.queue_free()
	for proj in projectiles:
		proj.queue_free()
	enemies.clear()
	collectibles.clear()
	projectiles.clear()
	_start_game()
	game_restarted.emit()

func add_combo() -> void:
	player_combo += 1
	player_combo_timer = 3.0
	if player_combo > player_best_combo:
		player_best_combo = player_combo
	combo_changed.emit(player_combo)

func add_pickup_streak() -> void:
	player_pickup_streak += 1
	player_pickup_streak_timer = 3.0
	if player_pickup_streak > player_max_pickup_streak:
		player_max_pickup_streak = player_pickup_streak

func add_message(text: String) -> void:
	messages.append(text)
	message_added.emit(text)
	print("[ZorpWiggles] %s" % text)