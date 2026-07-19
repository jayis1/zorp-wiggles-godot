## Zorp Wiggles — Local Leaderboards (Phase 32: Multiplayer & Social)
## Offline/local high-score leaderboards persisted to disk. No server required —
## all scores are from this machine, organized by game mode. Provides a
## "Challenge Friends" seed-sharing mechanism via shareable seed strings.
##
## Design:
##   - `submit_score(entry)` adds a score to the leaderboard for the current
##     game mode. Entries are sorted by score (descending) for Normal/Endless/
##     Boss Rush, or by time (ascending) for Speedrun.
##   - `get_leaderboard(mode) -> Array[Dictionary]` returns the sorted entries.
##   - Each entry: { name, score, kills, level, time, wave, biome, timestamp,
##     seed, mode }
##   - The top N entries per mode are kept (default 20).
##   - `get_share_seed() -> String` generates a shareable seed string that
##     friends can input to play the same world. `apply_share_seed(str)` sets
##     the world seed from a shared string.
##   - `generate_challenge_seed() -> String` creates a random challenge seed
##     with a checksum for validation.
##
## Public API:
##   submit_score(entry) -> bool
##   get_leaderboard(mode) -> Array[Dictionary]
##   get_top_score(mode) -> Dictionary
##   get_rank(mode, score) -> int
##   get_share_seed() -> String
##   apply_share_seed(s) -> bool
##   generate_challenge_seed() -> String
##   get_total_entries() -> int

extends Node

const SAVE_PATH: String = "user://zorp_leaderboards.json"
const MAX_ENTRIES_PER_MODE: int = 20
const LEADERBOARD_MODES: Array[String] = ["Normal", "Endless", "Boss Rush", "Speedrun"]

signal score_submitted(mode: String, rank: int, entry: Dictionary)
signal new_record(mode: String, entry: Dictionary)


func _ready() -> void:
	if GameManager:
		GameManager.player_died.connect(_on_player_died)


# ── Public API ────────────────────────────────────────────────────────────────

## Submit a score to the leaderboard. Returns true if the entry was added.
func submit_score(entry: Dictionary) -> bool:
	var mode: String = String(entry.get("mode", "Normal"))
	if not LEADERBOARD_MODES.has(mode):
		push_warning("[Leaderboards] Unknown mode: %s" % mode)
		return false
	var data: Dictionary = _load()
	if not data.has(mode):
		data[mode] = []
	var entries: Array = data[mode]
	entries.append(entry)
	# Sort: descending by score for most modes, ascending by time for Speedrun
	if mode == "Speedrun":
		entries.sort_custom(func(a, b): return float(a.get("time", INF)) < float(b.get("time", INF)))
	else:
		entries.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	# Trim to max entries
	if entries.size() > MAX_ENTRIES_PER_MODE:
		entries = entries.slice(0, MAX_ENTRIES_PER_MODE)
	data[mode] = entries
	_save(data)
	# Find the rank of the submitted entry
	var rank: int = entries.find(entry) + 1
	# Check if it's a new top record
	if rank == 1:
		new_record.emit(mode, entry)
	score_submitted.emit(mode, rank, entry)
	print("[Leaderboards] Submitted %s score: rank %d/%d" % [mode, rank, entries.size()])
	return true


## Get the leaderboard for a given mode (sorted, top entries first).
func get_leaderboard(mode: String) -> Array[Dictionary]:
	var data: Dictionary = _load()
	if not data.has(mode):
		return []
	var entries: Array = data[mode]
	var result: Array[Dictionary] = []
	for e in entries:
		if typeof(e) == TYPE_DICTIONARY:
			result.append(e)
	return result


## Get the top score entry for a mode (or empty dict if none).
func get_top_score(mode: String) -> Dictionary:
	var entries: Array[Dictionary] = get_leaderboard(mode)
	if entries.is_empty():
		return {}
	return entries[0]


## Get the rank a score would achieve (1-based, or -1 if not in top N).
func get_rank(mode: String, score: int) -> int:
	var entries: Array[Dictionary] = get_leaderboard(mode)
	for i in entries.size():
		if int(entries[i].get("score", 0)) <= score:
			return i + 1
	return entries.size() + 1


## Get the total number of entries across all modes.
func get_total_entries() -> int:
	var data: Dictionary = _load()
	var total: int = 0
	for mode in LEADERBOARD_MODES:
		if data.has(mode):
			total += (data[mode] as Array).size()
	return total


# ── Challenge Seeds (share with friends) ──────────────────────────────────────

## Generate a shareable challenge seed string. Format: "ZW-<seed>-<checksum>"
## The checksum is a simple sum of digits mod 100, so friends can verify they
## typed it correctly.
func generate_challenge_seed() -> String:
	var seed: int = randi() % 1000000
	var checksum: int = _seed_checksum(seed)
	return "ZW-%06d-%02d" % [seed, checksum]


## Apply a shared challenge seed. Returns true if the seed is valid.
func apply_share_seed(s: String) -> bool:
	var parts: PackedStringArray = s.split("-", false)
	if parts.size() != 3 or parts[0] != "ZW":
		push_warning("[Leaderboards] Invalid challenge seed format: %s" % s)
		return false
	var seed: int = int(parts[1])
	var checksum: int = int(parts[2])
	if _seed_checksum(seed) != checksum:
		push_warning("[Leaderboards] Challenge seed checksum mismatch: %s" % s)
		return false
	if GameManager:
		GameManager.world_seed = seed
		GameManager.add_message("🎯 Challenge seed applied: %s" % s)
	return true


## Get the current world seed as a shareable string.
func get_share_seed() -> String:
	var seed: int = GameManager.world_seed if GameManager else 0
	var checksum: int = _seed_checksum(seed)
	return "ZW-%06d-%02d" % [seed, checksum]


# ── Internal ──────────────────────────────────────────────────────────────────

func _seed_checksum(seed: int) -> int:
	var s: String = str(seed)
	var sum: int = 0
	for c in s:
		sum += int(c)
	return sum % 100


func _load() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


func _save(data: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		push_warning("[Leaderboards] Could not write leaderboard file")
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()


# ── Signal Handlers ───────────────────────────────────────────────────────────

func _on_player_died() -> void:
	# Submit the final score to the leaderboard
	if not GameManager:
		return
	var mode: String = "Normal"
	if GameModeManager:
		mode = GameModeManager.get_mode_name()
	var entry: Dictionary = {
		"name": _get_player_name(),
		"score": GameManager.player_score,
		"kills": GameManager.player_kills,
		"level": GameManager.player_level,
		"time": GameManager.game_time,
		"wave": GameModeManager.get_endless_wave() if GameModeManager and GameModeManager.is_endless() else 0,
		"biome": GameManager.current_biome,
		"seed": GameManager.world_seed,
		"mode": mode,
		"timestamp": Time.get_datetime_string_from_system(false, true),
	}
	submit_score(entry)


func _get_player_name() -> String:
	# Use the selected character name if available
	if CharacterSelectManager:
		return CharacterSelectManager.get_character_name(CharacterSelectManager.get_selected_character())
	return "Zorp"