## Zorp Wiggles — Weekly Challenge System (Phase 25: Progression & Meta-Systems)
##
## A seed-based weekly challenge run. Each ISO week (year-week) generates a
## deterministic world seed + a larger set of modifiers (4-5 vs daily's 3-4)
## so the weekly challenge feels distinct from the daily. The weekly challenge
## allows up to 3 attempts per week — the best score is recorded.
##
## Rules:
##   - Up to 3 attempts per week. Starting a weekly challenge consumes an
##     attempt. Dying ends the attempt and records the best score.
##   - The world seed is derived from the ISO year-week string "YYYY-Www" so
##     it's deterministic and shareable. Two players in the same week get
##     the exact same world and modifiers.
##   - 4-5 world modifiers are rolled from the weekly seed — more chaos than
##     the daily challenge.
##   - Best score per week is persisted. A "Weekly" leaderboard tracks the
##     best weekly scores across all weeks played.
##   - Completing the weekly challenge grants a larger XP bonus than daily.
##
## Public API:
##   get_week_seed() -> int
##   get_week_seed_string() -> String
##   get_week_string() -> String
##   get_attempts_remaining() -> int
##   has_attempted_this_week() -> bool
##   can_attempt_this_week() -> bool
##   start_weekly_attempt() -> bool
##   record_weekly_result(score, kills, time, level) -> void
##   get_week_best() -> Dictionary
##   get_weekly_leaderboard() -> Array[Dictionary]
##   get_week_modifiers() -> Array[int]
##   get_week_modifier_names() -> String
##   get_week_modifier_info() -> Array[Dictionary]
##   is_weekly_active() -> bool
##   get_attempt_count() -> int
##   get_summary() -> String
##   sync_modifiers_from_world_system() -> void
##
## Persistence:
##   user://zorp_weekly_challenge.json — tracks the last-attempted week,
##   attempts used, best score, and a historical leaderboard.

extends Node

# ─── Signals ──────────────────────────────────────────────────────────────────
signal weekly_attempt_started(seed: int)
signal weekly_attempt_finished(score: int, kills: int, time: float)
signal weekly_best_updated(score: int)
signal weekly_leaderboard_updated()

# ─── Constants ─────────────────────────────────────────────────────────────────
const SAVE_PATH: String = "user://zorp_weekly_challenge.json"
const WEEKLY_MAX_ATTEMPTS: int = 3
const WEEKLY_MODIFIER_COUNT_MIN: int = 4
const WEEKLY_MODIFIER_COUNT_MAX: int = 5
const WEEKLY_XP_BONUS: int = 250  # Larger bonus for the weekly challenge
const WEEKLY_LEADERBOARD_MAX: int = 30

# ─── State ─────────────────────────────────────────────────────────────────────
var _last_attempt_week: String = ""  # "YYYY-Www" of last attempt week
var _attempts_used: int = 0          # Attempts used this week
var _week_best_score: int = 0
var _week_best_kills: int = 0
var _week_best_time: float = 0.0
var _week_best_level: int = 0
var _weekly_active: bool = false
var _weekly_leaderboard: Array[Dictionary] = []
var _week_modifiers: Array[int] = []
var _week_seed: int = 0

# ─── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load()
	_refresh_week_seed()
	if GameManager:
		GameManager.player_died.connect(_on_player_died)
		GameManager.game_restarted.connect(_on_game_restarted)

func _exit_tree() -> void:
	_save()

# ─── Public API ────────────────────────────────────────────────────────────────

func get_week_seed() -> int:
	return _week_seed

func get_week_seed_string() -> String:
	return "ZW-%06d-%02d" % [_week_seed, _seed_checksum(_week_seed)]

## Returns the current ISO week string as "YYYY-Www".
func get_week_string() -> String:
	return _get_iso_week_string()

func has_attempted_this_week() -> bool:
	return _last_attempt_week == _get_iso_week_string() and _attempts_used > 0

func can_attempt_this_week() -> bool:
	# If the week changed, reset attempts
	if _last_attempt_week != _get_iso_week_string():
		return true
	return _attempts_used < WEEKLY_MAX_ATTEMPTS and not _weekly_active

func get_attempts_remaining() -> int:
	if _last_attempt_week != _get_iso_week_string():
		return WEEKLY_MAX_ATTEMPTS
	return WEEKLY_MAX_ATTEMPTS - _attempts_used

func get_week_modifiers() -> Array[int]:
	return _week_modifiers.duplicate()

func sync_modifiers_from_world_system() -> void:
	if WorldModifierSystem and WorldModifierSystem.is_initialized():
		_week_modifiers = WorldModifierSystem.get_active_modifiers()

func is_weekly_active() -> bool:
	return _weekly_active

func start_weekly_attempt() -> bool:
	if not can_attempt_this_week():
		push_warning("[WeeklyChallenge] Cannot start — no attempts remaining or attempt in progress.")
		return false
	# Force the world seed to this week's deterministic seed
	GameManager.world_seed = _week_seed
	_weekly_active = true
	# Track the week and increment attempt count
	if _last_attempt_week != _get_iso_week_string():
		_last_attempt_week = _get_iso_week_string()
		_attempts_used = 0
		_week_best_score = 0
		_week_best_kills = 0
		_week_best_time = 0.0
		_week_best_level = 0
	_attempts_used += 1
	_save()
	weekly_attempt_started.emit(_week_seed)
	print("[WeeklyChallenge] Attempt %d/%d started — seed: %d, week: %s" % [_attempts_used, WEEKLY_MAX_ATTEMPTS, _week_seed, _last_attempt_week])
	return true

func record_weekly_result(score: int, kills: int, time: float, level: int) -> void:
	if not _weekly_active:
		return
	_weekly_active = false
	var week_str: String = _get_iso_week_string()
	var is_new_best: bool = score > _week_best_score
	if is_new_best:
		_week_best_score = score
		_week_best_kills = kills
		_week_best_time = time
		_week_best_level = level
		weekly_best_updated.emit(score)
	# Append to historical leaderboard
	var entry: Dictionary = {
		"week": week_str,
		"seed": _week_seed,
		"score": score,
		"kills": kills,
		"time": time,
		"level": level,
		"attempt": _attempts_used,
		"timestamp": Time.get_datetime_string_from_system(false, true),
	}
	_weekly_leaderboard.append(entry)
	_weekly_leaderboard.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	if _weekly_leaderboard.size() > WEEKLY_LEADERBOARD_MAX:
		_weekly_leaderboard = _weekly_leaderboard.slice(0, WEEKLY_LEADERBOARD_MAX)
	_save()
	weekly_attempt_finished.emit(score, kills, time)
	weekly_leaderboard_updated.emit()
	print("[WeeklyChallenge] Attempt %d recorded — score: %d, kills: %d, time: %.1fs" % [_attempts_used, score, kills, time])
	if Statistics:
		Statistics.add_lifetime("weekly_challenges_completed", 1.0)

func get_week_best() -> Dictionary:
	if _last_attempt_week != _get_iso_week_string():
		return {}
	return {
		"score": _week_best_score,
		"kills": _week_best_kills,
		"time": _week_best_time,
		"level": _week_best_level,
	}

func get_weekly_leaderboard() -> Array[Dictionary]:
	return _weekly_leaderboard.duplicate(true)

func get_attempt_count() -> int:
	return _weekly_leaderboard.size()

func get_week_modifier_names() -> String:
	if not WorldModifierSystem:
		return ""
	var names: Array[String] = []
	for mod_id in _week_modifiers:
		names.append(WorldModifierSystem.get_modifier_name(mod_id))
	return ", ".join(names)

func get_week_modifier_info() -> Array[Dictionary]:
	var info: Array[Dictionary] = []
	if not WorldModifierSystem:
		return info
	for mod_id in _week_modifiers:
		info.append({
			"id": mod_id,
			"icon": WorldModifierSystem.get_modifier_icon(mod_id),
			"name": WorldModifierSystem.get_modifier_name(mod_id),
			"description": WorldModifierSystem.get_modifier_description(mod_id),
		})
	return info

func get_summary() -> String:
	var week_str: String = _get_iso_week_string()
	var remaining: int = get_attempts_remaining()
	if has_attempted_this_week():
		return "📅 Weekly: %s  |  Best: %d  |  Attempts left: %d/%d" % [
			week_str, _week_best_score, remaining, WEEKLY_MAX_ATTEMPTS
		]
	else:
		return "📅 Weekly: %s  |  Not yet attempted (%d/%d)" % [week_str, remaining, WEEKLY_MAX_ATTEMPTS]

# ─── Internal ──────────────────────────────────────────────────────────────────

func _refresh_week_seed() -> void:
	var week_str: String = _get_iso_week_string()
	_week_seed = _week_to_seed(week_str)
	_week_modifiers = _roll_week_modifiers(_week_seed)
	# Reset week best if the week has changed
	if _last_attempt_week != week_str:
		_week_best_score = 0
		_week_best_kills = 0
		_week_best_time = 0.0
		_week_best_level = 0
	print("[WeeklyChallenge] Week: %s — seed: %d — modifiers: %s" % [
		week_str, _week_seed, str(_week_modifiers)
	])

## Returns the current ISO 8601 week string as "YYYY-Www".
## Godot's Time singleton doesn't give ISO week directly, so we compute it
## from the system date.
func _get_iso_week_string() -> String:
	var datetime: Dictionary = Time.get_datetime_dict_from_system(false)
	var year: int = datetime.get("year", 2025)
	var month: int = datetime.get("month", 1)
	var day: int = datetime.get("day", 1)
	var iso: Dictionary = _date_to_iso_week(year, month, day)
	return "%d-W%02d" % [iso.year, iso.week]

## Converts a (year, month, day) to an ISO 8601 (year, week) tuple.
## Uses the standard algorithm: find the day of year, adjust for ISO week
## starting on Monday, week 1 contains the first Thursday.
func _date_to_iso_week(year: int, month: int, day: int) -> Dictionary:
	# Day of year (1-based)
	var days_in_month: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	# Leap year check
	if (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0):
		days_in_month[1] = 29
	var doy: int = day
	for i in range(month - 1):
		doy += days_in_month[i]
	# ISO weekday: Jan 1 is some weekday. We need to know what day of week
	# Jan 1 was. Using Zeller's congruence for Jan 1.
	# Zeller's congruence returns 0=Saturday, 1=Sunday, 2=Monday, ..., 6=Friday
	var jan1_weekday: int = _zeller_weekday(year, 1, 1)  # 0=Saturday
	# Convert to ISO weekday (1=Monday, 7=Sunday)
	# Zeller: 0=Sat,1=Sun,2=Mon,3=Tue,4=Wed,5=Thu,6=Fri
	# ISO:    6      7      1      2      3      4      5
	# So ISO = ((zeller + 5) % 7) + 1
	var iso_jan1: int = ((jan1_weekday + 5) % 7) + 1  # 1=Monday..7=Sunday
	# ISO week 1 is the week containing the first Thursday
	# If Jan 1 is Fri(5)/Sat(6)/Sun(7), it's in the last week of prev year
	var week: int
	var iso_year: int = year
	if iso_jan1 <= 4:
		week = 1
	else:
		week = 0
	# Calculate the week number
	# Days from the first Monday of week 1 (or the Monday of last week of prev year)
	if iso_jan1 <= 4:
		# Week 1 starts on the Monday on or before Jan 1
		# If Jan 1 is Monday(1), week 1 starts Jan 1
		# If Jan 1 is Tuesday(2), week 1 starts Dec 30 (prev year)
		# etc.
		week = ((doy - 1) + (iso_jan1 - 1)) / 7 + 1
	else:
		# First week is last week of prev year; week 1 starts later
		var first_monday_doy: int = 1 + (8 - iso_jan1)  # First Monday of week 1
		if doy < first_monday_doy:
			# Belongs to last week of previous year
			iso_year = year - 1
			week = _weeks_in_year(iso_year)
		else:
			week = ((doy - first_monday_doy) / 7) + 1
	# Check year boundary at end of year
	if week > _weeks_in_year(iso_year):
		iso_year += 1
		week = 1
	return {"year": iso_year, "week": week}

func _zeller_weekday(year: int, month: int, day: int) -> int:
	# Zeller's congruence — returns 0=Saturday, 1=Sunday, ..., 6=Friday
	if month < 3:
		year -= 1
		month += 12
	var k: int = year % 100
	var j: int = year / 100
	var h: int = (day + (13 * (month + 1)) / 5 + k + k / 4 + j / 4 + 5 * j) % 7
	return h

func _weeks_in_year(year: int) -> int:
	# A year has 53 weeks if Jan 1 is Thursday (Zeller h=5), or if it's a
	# leap year and Jan 1 is Wednesday (Zeller h=4).
	var jan1: int = _zeller_weekday(year, 1, 1)  # 0=Saturday
	var is_leap: bool = (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)
	if jan1 == 5 or (is_leap and jan1 == 4):
		return 53
	return 52

func _week_to_seed(week_str: String) -> int:
	var seed: int = 0
	for c in week_str:
		seed = (seed * 31 + c.unicode_at(0)) & 0x7FFFFFFF
	if seed == 0:
		seed = 1
	return seed

func _roll_week_modifiers(seed: int) -> Array[int]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var count: int = rng.randi_range(WEEKLY_MODIFIER_COUNT_MIN, WEEKLY_MODIFIER_COUNT_MAX)
	var pool: Array[int] = []
	if WorldModifierSystem:
		for i in range(1, WorldModifierSystem.Modifier.size()):
			pool.append(i)
	else:
		pool = [1, 2, 3, 5, 7, 8, 10, 13]
	var picked: Array[int] = []
	var available: Array[int] = pool.duplicate()
	for i in range(mini(count, available.size())):
		var idx: int = rng.randi_range(0, available.size() - 1)
		picked.append(available[idx])
		available.remove_at(idx)
	return picked

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
	_last_attempt_week = String(data.get("last_attempt_week", ""))
	_attempts_used = int(data.get("attempts_used", 0))
	_week_best_score = int(data.get("week_best_score", 0))
	_week_best_kills = int(data.get("week_best_kills", 0))
	_week_best_time = float(data.get("week_best_time", 0.0))
	_week_best_level = int(data.get("week_best_level", 0))
	var lb: Variant = data.get("leaderboard", [])
	if typeof(lb) == TYPE_ARRAY:
		_weekly_leaderboard.clear()
		for e in lb:
			if typeof(e) == TYPE_DICTIONARY:
				_weekly_leaderboard.append(e)

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		push_warning("[WeeklyChallenge] Could not write save file.")
		return
	var data: Dictionary = {
		"last_attempt_week": _last_attempt_week,
		"attempts_used": _attempts_used,
		"week_best_score": _week_best_score,
		"week_best_kills": _week_best_kills,
		"week_best_time": _week_best_time,
		"week_best_level": _week_best_level,
		"leaderboard": _weekly_leaderboard,
	}
	f.store_string(JSON.stringify(data, "  "))
	f.close()

# ─── Signal Handlers ───────────────────────────────────────────────────────────

func _on_player_died() -> void:
	if not _weekly_active:
		return
	record_weekly_result(
		GameManager.player_score,
		GameManager.player_kills,
		GameManager.game_time,
		GameManager.player_level
	)

func _on_game_restarted() -> void:
	if _weekly_active:
		_weekly_active = false
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