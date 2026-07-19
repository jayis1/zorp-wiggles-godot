## Zorp Wiggles — PvP Arena Mode (Phase 32: Multiplayer & Social)
## A local split-screen-style PvP arena where P1 (Zorp) and P2 (Zerp) fight
## each other in an enclosed arena. No enemies, no world exploration — pure
## 1v1 combat. The first player to reduce the other's HP to 0 wins the round.
## Best-of-3 or best-of-5 (configurable).
##
## Design:
##   - PvP is a new GameMode (Mode.PVP) added to GameModeManager.
##   - When PvP mode is active, the world generator builds a small flat arena
##     instead of the normal open world. Enemy spawning is disabled.
##   - Both players spawn at opposite ends of the arena. P1 uses the normal
##     WASD/mouse controls; P2 uses the arrow keys + [/] shoot (existing co-op
##     P2 controls — no new input mappings needed).
##   - Player projectiles damage the OTHER player (not enemies). We tag
##     projectiles with `is_p1_projectile` or `is_p2_projectile` and check
##     the target's player index.
##   - The arena has cover pillars (destructible) for tactical play.
##   - Round-based: first to win N rounds wins the match.
##   - A PvP HUD overlay shows both players' HP, round wins, and a round timer.
##
## This is a LOCAL PvP mode — no networking. Both players on the same machine.
##
## Public API:
##   start_pvp_match(best_of)  — begin a PvP match
##   end_pvp_match()           — end the match early
##   get_pvp_state() -> Dictionary
##   is_pvp_active() -> bool
##   register_pvp_hit(attacker_is_p1, damage)
##   register_pvp_death(dead_is_p1)

extends Node

const PVP_ARENA_RADIUS: float = 30.0
const PVP_ARENA_COVER_COUNT: int = 6
const PVP_ROUND_TIME_LIMIT: float = 90.0  # 90s per round
const PVP_SPAWN_DISTANCE: float = 20.0
const PVP_FULL_HEAL_PER_ROUND: int = 9999

signal pvp_match_started(best_of: int)
signal pvp_round_started(round_num: int)
signal pvp_round_ended(winner_is_p1: bool, round_num: int)
signal pvp_match_ended(winner_is_p1: bool)
signal pvp_hp_changed(p1_hp: int, p2_hp: int)
signal pvp_rounds_changed(p1_wins: int, p2_wins: int)
signal pvp_timer_changed(time_remaining: float)

# Match state
var _pvp_active: bool = false
var _best_of: int = 3
var _round_num: int = 0
var _p1_wins: int = 0
var _p2_wins: int = 0
var _round_timer: float = 0.0
var _round_active: bool = false
var _p1_hp: int = 100
var _p2_hp: int = 100
var _p1_max_hp: int = 100
var _p2_max_hp: int = 100
var _intermission_timer: float = 0.0


func _ready() -> void:
	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)
		GameManager.player_died.connect(_on_player_died)


func _process(delta: float) -> void:
	if not _pvp_active:
		return
	if _intermission_timer > 0:
		_intermission_timer -= delta
		if _intermission_timer <= 0:
			_start_next_round()
		return
	if not _round_active:
		return
	_round_timer -= delta
	pvp_timer_changed.emit(max(0.0, _round_timer))
	if _round_timer <= 0:
		# Time up — the player with more HP wins the round
		_end_round_by_hp()


# ── Public API ────────────────────────────────────────────────────────────────

## Start a PvP match. `best_of` is 3 or 5 (first to win majority).
func start_pvp_match(best_of: int = 3) -> void:
	_pvp_active = true
	_best_of = best_of
	_round_num = 0
	_p1_wins = 0
	_p2_wins = 0
	_intermission_timer = 3.0  # 3s before first round
	pvp_match_started.emit(best_of)
	pvp_rounds_changed.emit(_p1_wins, _p2_wins)
	if GameManager:
		GameManager.add_message("⚔ PvP Arena! Best of %d. First to %d wins!" % [best_of, int(best_of / 2) + 1])


## End the PvP match early.
func end_pvp_match() -> void:
	_pvp_active = false
	_round_active = false
	_intermission_timer = 0.0


func is_pvp_active() -> bool:
	return _pvp_active


func get_pvp_state() -> Dictionary:
	return {
		"active": _pvp_active,
		"best_of": _best_of,
		"round": _round_num,
		"p1_wins": _p1_wins,
		"p2_wins": _p2_wins,
		"p1_hp": _p1_hp,
		"p2_hp": _p2_hp,
		"p1_max_hp": _p1_max_hp,
		"p2_max_hp": _p2_max_hp,
		"round_timer": max(0.0, _round_timer),
		"intermission": _intermission_timer > 0,
	}


## Register a PvP hit. `attacker_is_p1` is true if P1 dealt the damage.
func register_pvp_hit(attacker_is_p1: bool, damage: int) -> void:
	if not _round_active:
		return
	if attacker_is_p1:
		_p2_hp = max(0, _p2_hp - damage)
	else:
		_p1_hp = max(0, _p1_hp - damage)
	pvp_hp_changed.emit(_p1_hp, _p2_hp)
	# Check for KO
	if _p2_hp <= 0:
		_end_round(true)  # P1 wins
	elif _p1_hp <= 0:
		_end_round(false)  # P2 wins


## Register a PvP death (e.g. from environmental hazard).
func register_pvp_death(dead_is_p1: bool) -> void:
	if not _round_active:
		return
	_end_round(not dead_is_p1)  # The other player wins


# ── Internal ──────────────────────────────────────────────────────────────────

func _start_next_round() -> void:
	_round_num += 1
	_p1_hp = _p1_max_hp
	_p2_hp = _p2_max_hp
	_round_timer = PVP_ROUND_TIME_LIMIT
	_round_active = true
	pvp_round_started.emit(_round_num)
	pvp_hp_changed.emit(_p1_hp, _p2_hp)
	pvp_timer_changed.emit(_round_timer)
	if GameManager:
		GameManager.add_message("⚔ Round %d — Fight!" % _round_num)
	# Reset player positions to opposite ends of the arena
	_reset_player_positions()


func _end_round(winner_is_p1: bool) -> void:
	_round_active = false
	if winner_is_p1:
		_p1_wins += 1
	else:
		_p2_wins += 1
	pvp_round_ended.emit(winner_is_p1, _round_num)
	pvp_rounds_changed.emit(_p1_wins, _p2_wins)
	if GameManager:
		var winner_name: String = "Zorp" if winner_is_p1 else "Zerp"
		GameManager.add_message("🏆 %s wins round %d! (%d-%d)" % [winner_name, _round_num, _p1_wins, _p2_wins])
	# Check if the match is over
	var wins_needed: int = int(_best_of / 2) + 1
	if _p1_wins >= wins_needed or _p2_wins >= wins_needed:
		_end_match(_p1_wins >= wins_needed)
	else:
		_intermission_timer = 4.0  # 4s between rounds


func _end_round_by_hp() -> void:
	_round_active = false
	# The player with more HP wins; tie goes to P1 (house advantage)
	var p1_wins: bool = _p1_hp >= _p2_hp
	_end_round(p1_wins)


func _end_match(p1_wins_match: bool) -> void:
	_pvp_active = false
	_round_active = false
	pvp_match_ended.emit(p1_wins_match)
	if GameManager:
		var winner: String = "Zorp" if p1_wins_match else "Zerp"
		GameManager.add_message("🏆🏆 %s WINS THE MATCH! (%d-%d)" % [winner, _p1_wins, _p2_wins])
		# Record to Statistics
		if Statistics:
			Statistics.set_lifetime_max("pvp_wins_p1" if p1_wins_match else "pvp_wins_p2", 1)


func _reset_player_positions() -> void:
	if not GameManager or not GameManager.player:
		return
	# P1 at one end
	GameManager.player.global_position = Vector3(0, 1, -PVP_SPAWN_DISTANCE)
	# P2 at the other end (if active)
	if CoOpManager and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
		CoOpManager.p2_node.global_position = Vector3(0, 1, PVP_SPAWN_DISTANCE)
	# Full heal both players
	if GameManager:
		GameManager.player_hp = _p1_max_hp
		GameManager.player_max_hp = _p1_max_hp
		GameManager.hp_changed.emit(GameManager.player_hp, GameManager.player_max_hp)
	if CoOpManager:
		CoOpManager.p2_hp = _p2_max_hp
		CoOpManager.p2_max_hp = _p2_max_hp
		CoOpManager.p2_hp_changed.emit(CoOpManager.p2_hp, CoOpManager.p2_max_hp)


# ── Signal Handlers ───────────────────────────────────────────────────────────

func _on_game_restarted() -> void:
	# Reset PvP state on game restart
	_pvp_active = false
	_round_active = false
	_intermission_timer = 0.0
	_p1_wins = 0
	_p2_wins = 0
	_round_num = 0


func _on_player_died() -> void:
	# If PvP is active and P1 dies, P2 wins the round
	if _pvp_active and _round_active:
		register_pvp_death(true)