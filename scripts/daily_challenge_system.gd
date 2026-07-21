## Zorp Wiggles — Daily Challenge System (Phase 25: Progression & Meta-Systems)
##
## A seed-based daily challenge run. Every real-world day a new deterministic
## world seed + modifier set is generated from the date string "YYYY-MM-DD".
## All players who play the Daily Challenge on the same calendar day get the
## exact same world, modifiers, and biome layout — making scores comparable.
##
## Rules:
##   - One attempt per day. Once you start the daily challenge, the attempt is
##     locked in. Dying ends the attempt and records the score.
##   - The world seed is derived from the date so it's deterministic and
##     shareable (two players on the same day see the same world).
##   - 3-4 world modifiers are rolled from the daily seed, so the daily
##     challenge has fixed modifiers for everyone on the same day.
##   - Best score per day is persisted. A "Daily" leaderboard tracks the
##     best daily scores across all days played.
##   - Completing the daily challenge grants a small XP bonus in the next run.
##
## Public API:
##   get_today_seed() -> int
##   get_today_seed_string() -> String
##   get_today_date_string() -> String
##   has_attempted_today() -> bool
##   can_attempt_today() -> bool
##   start_daily_attempt() -> bool
##   record_daily_result(score, kills, time, level) -> void
##   get_today_best() -> Dictionary
##   get_daily_leaderboard() -> Array[Dictionary]
##   get_today_modifiers() -> Array[int]
##   get_attempt_count() -> int
##   is_daily_active() -> bool
##
## Persistence:
##   user://zorp_daily_challenge.json — tracks the last-attempted date,
##   today's best score, and a historical leaderboard of daily results.

extends Node

# ─── Signals ──────────────────────────────────────────────────────────────────
signal daily_attempt_started(seed: int)
signal daily_attempt_finished(score: int, kills: int, time: float)
signal daily_best_updated(score: int)
signal daily_leaderboard_updated()

# ─── Constants ─────────────────────────────────────────────────────────────────
const SAVE_PATH: String = "user://zorp_daily_challenge.json"
const DAILY_MODIFIER_COUNT_MIN: int = 3
const DAILY_MODIFIER_COUNT_MAX: int = 4
const DAILY_XP_BONUS: int = 100  # Bonus XP for completing the daily
const DAILY_LEADERBOARD_MAX: int = 30

# ─── State ─────────────────────────────────────────────────────────────────────
var _last_attempt_date: String = ""  # YYYY-MM-DD of last attempt
var _today_best_score: int = 0
var _today_best_kills: int = 0
var _today_best_time: float = 0.0
var _today_best_level: int = 0
var _daily_active: bool = false  # True while a daily attempt run is in progress
var _daily_leaderboard: Array[Dictionary] = []  # Historical daily results
var _today_modifiers: Array[int] = []  # Cached modifier IDs for today
var _today_seed: int = 0  # Cached daily seed

# ─── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load()
	_refresh_today_seed()
	if GameManager:
		GameManager.player_died.connect(_on_player_died)
		GameManager.game_restarted.connect(_on_game_restarted)

func _exit_tree() -> void:
	_save()

# ─── Public API ────────────────────────────────────────────────────────────────

## Returns the deterministic seed for today's daily challenge.
func get_today_seed() -> int:
	return _today_seed

## Returns today's seed as a shareable "ZW-NNNNNN-NN" string.
func get_today_seed_string() -> String:
	return "ZW-%06d-%02d" % [_today_seed, _seed_checksum(_today_seed)]

## Returns today's date as "YYYY-MM-DD".
func get_today_date_string() -> String:
	return Time.get_datetime_string_from_system(true, false).substr(0, 10)

## True if the player has already attempted today's daily challenge.
func has_attempted_today() -> bool:
	return _last_attempt_date == get_today_date_string()

## True if the player can start a new daily attempt today.
func can_attempt_today() -> bool:
	return not has_attempted_today() and not _daily_active

## Returns the cached modifier IDs for today (3-4 modifiers).
func get_today_modifiers() -> Array[int]:
	return _today_modifiers.duplicate()

## Syncs _today_modifiers from the WorldModifierSystem's actual active
## modifiers. Called by GameManager._start_game() after roll_modifiers() so
## the daily HUD displays the SAME modifiers that are actually applied to
## gameplay. Without this, the pre-computed _today_modifiers (from a different
## RNG path in _refresh_today_seed) would diverge from the real modifiers.
func sync_modifiers_from_world_system() -> void:
	if WorldModifierSystem and WorldModifierSystem.is_initialized():
		_today_modifiers = WorldModifierSystem.get_active_modifiers()

## True while a daily challenge run is in progress.
func is_daily_active() -> bool:
	return _daily_active

## Starts a daily challenge attempt. Sets the world seed + forces the daily
## modifiers. Returns true if the attempt was successfully started.
func start_daily_attempt() -> bool:
	if not can_attempt_today():
		push_warning("[DailyChallenge] Cannot start — already attempted today or attempt in progress.")
		return false
	# Force the world seed to today's deterministic seed
	GameManager.world_seed = _today_seed
	_daily_active = true
	_last_attempt_date = get_today_date_string()
	_save()
	daily_attempt_started.emit(_today_seed)
	print("[DailyChallenge] Attempt started — seed: %d, date: %s" % [_today_seed, _last_attempt_date])
	return true

## Records the result of a daily challenge run. Called automatically on player
## death (if the daily challenge was active). Also updates today's best.
func record_daily_result(score: int, kills: int, time: float, level: int) -> void:
	if not _daily_active:
		return
	_daily_active = false
	var date_str: String = get_today_date_string()
	# Update today's best if this run beat it
	var is_new_best: bool = score > _today_best_score
	if is_new_best:
		_today_best_score = score
		_today_best_kills = kills
		_today_best_time = time
		_today_best_level = level
		daily_best_updated.emit(score)
	# Append to historical leaderboard
	var entry: Dictionary = {
		"date": date_str,
		"seed": _today_seed,
		"score": score,
		"kills": kills,
		"time": time,
		"level": level,
		"timestamp": Time.get_datetime_string_from_system(false, true),
	}
	_daily_leaderboard.append(entry)
	# Sort descending by score, trim to max
	_daily_leaderboard.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	if _daily_leaderboard.size() > DAILY_LEADERBOARD_MAX:
		_daily_leaderboard = _daily_leaderboard.slice(0, DAILY_LEADERBOARD_MAX)
	_save()
	daily_attempt_finished.emit(score, kills, time)
	daily_leaderboard_updated.emit()
	print("[DailyChallenge] Attempt recorded — score: %d, kills: %d, time: %.1fs" % [score, kills, time])
	# Grant XP bonus for next run via Statistics
	if Statistics:
		Statistics.add_lifetime("daily_challenges_completed", 1.0)

## Returns today's best result dictionary (empty if no attempt yet).
func get_today_best() -> Dictionary:
	if _last_attempt_date != get_today_date_string():
		return {}
	return {
		"score": _today_best_score,
		"kills": _today_best_kills,
		"time": _today_best_time,
		"level": _today_best_level,
	}

## Returns the historical daily challenge leaderboard (best runs across all days).
func get_daily_leaderboard() -> Array[Dictionary]:
	return _daily_leaderboard.duplicate(true)

## Returns the number of daily challenges the player has ever completed.
func get_attempt_count() -> int:
	return _daily_leaderboard.size()

## Returns a short summary string for HUD display.
func get_summary() -> String:
	var date_str: String = get_today_date_string()
	if has_attempted_today():
		return "📅 Daily: %s  |  Best: %d (kills: %d, time: %s)" % [
			date_str, _today_best_score, _today_best_kills,
			_format_time(_today_best_time)
		]
	else:
		return "📅 Daily: %s  |  Not yet attempted" % date_str

# ─── Internal ──────────────────────────────────────────────────────────────────

## Refreshes the daily seed + modifiers. Called on _ready and when the date
## changes (e.g. the game running past midnight).
func _refresh_today_seed() -> void:
	var date_str: String = get_today_date_string()
	_today_seed = _date_to_seed(date_str)
	_today_modifiers = _roll_daily_modifiers(_today_seed)
	# Reset today's best if the date has changed
	if _last_attempt_date != date_str:
		_today_best_score = 0
		_today_best_kills = 0
		_today_best_time = 0.0
		_today_best_level = 0
	print("[DailyChallenge] Today: %s — seed: %d — modifiers: %s" % [
		date_str, _today_seed, str(_today_modifiers)
	])

## Converts a "YYYY-MM-DD" date string to a deterministic int seed.
## Uses a simple hash: for each character, seed = seed * 31 + char_code.
## This ensures the same date always produces the same seed across runs.
func _date_to_seed(date_str: String) -> int:
	var seed: int = 0
	for c in date_str:
		seed = (seed * 31 + c.unicode_at(0)) & 0x7FFFFFFF
	# Ensure non-zero (zero would use randi() fallback in some systems)
	if seed == 0:
		seed = 1
	return seed

## Rolls 3-4 deterministic world modifiers from the daily seed.
## Uses the WorldModifierSystem's modifier pool to keep things consistent.
func _roll_daily_modifiers(seed: int) -> Array[int]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var count: int = rng.randi_range(DAILY_MODIFIER_COUNT_MIN, DAILY_MODIFIER_COUNT_MAX)
	# Build a pool of all valid modifier IDs (skip NONE = 0)
	var pool: Array[int] = []
	if WorldModifierSystem:
		for i in range(1, WorldModifierSystem.Modifier.size()):
			pool.append(i)
	else:
		# Fallback: use a small subset if WorldModifierSystem isn't loaded yet
		pool = [1, 2, 3, 5, 7, 8, 10, 13]
	# Pick `count` unique modifiers from the pool
	var picked: Array[int] = []
	var available: Array[int] = pool.duplicate()
	for i in range(mini(count, available.size())):
		var idx: int = rng.randi_range(0, available.size() - 1)
		picked.append(available[idx])
		available.remove_at(idx)
	return picked

## Returns the active daily modifiers as a comma-separated name string for HUD.
func get_today_modifier_names() -> String:
	if not WorldModifierSystem:
		return ""
	var names: Array[String] = []
	for mod_id in _today_modifiers:
		names.append(WorldModifierSystem.get_modifier_name(mod_id))
	return ", ".join(names)

## Returns the active daily modifiers as a list of (icon, name, description) tuples.
func get_today_modifier_info() -> Array[Dictionary]:
	var info: Array[Dictionary] = []
	if not WorldModifierSystem:
		return info
	for mod_id in _today_modifiers:
		info.append({
			"id": mod_id,
			"icon": WorldModifierSystem.get_modifier_icon(mod_id),
			"name": WorldModifierSystem.get_modifier_name(mod_id),
			"description": WorldModifierSystem.get_modifier_description(mod_id),
		})
	return info

# ─── Save/Load ─────────────────────────────────────────────────────────────────

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var text: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	_last_attempt_date = String(data.get("last_attempt_date", ""))
	_today_best_score = int(data.get("today_best_score", 0))
	_today_best_kills = int(data.get("today_best_kills", 0))
	_today_best_time = float(data.get("today_best_time", 0.0))
	_today_best_level = int(data.get("today_best_level", 0))
	var lb: Variant = data.get("leaderboard", [])
	if typeof(lb) == TYPE_ARRAY:
		_daily_leaderboard.clear()
		for e in lb:
			if typeof(e) == TYPE_DICTIONARY:
				_daily_leaderboard.append(e)

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		push_warning("[DailyChallenge] Could not write save file.")
		return
	var data: Dictionary = {
		"last_attempt_date": _last_attempt_date,
		"today_best_score": _today_best_score,
		"today_best_kills": _today_best_kills,
		"today_best_time": _today_best_time,
		"today_best_level": _today_best_level,
		"leaderboard": _daily_leaderboard,
	}
	f.store_string(JSON.stringify(data, "  "))
	f.close()

# ─── Signal Handlers ───────────────────────────────────────────────────────────

func _on_player_died() -> void:
	if not _daily_active:
		return
	# Record the result of the daily attempt
	record_daily_result(
		GameManager.player_score,
		GameManager.player_kills,
		GameManager.game_time,
		GameManager.player_level
	)

func _on_game_restarted() -> void:
	# If the player restarts mid-daily, the attempt is forfeited
	if _daily_active:
		_daily_active = false
		_save()

# ─── Helpers ───────────────────────────────────────────────────────────────────

func _seed_checksum(seed: int) -> int:
	var s: String = str(seed)
	var sum: int = 0
	for c in s:
		sum += int(c)
	return sum % 100

func _format_time(seconds: float) -> String:
	var s: int = int(seconds)
	var m: int = (s % 3600) / 60
	var sec: int = s % 60
	if m > 0:
		return "%dm %02ds" % [m, sec]
	else:
		return "%ds" % sec