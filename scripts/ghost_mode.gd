## Zorp Wiggles — Ghost Mode (Phase 32: Multiplayer & Social)
## Race against a translucent "ghost" of your best run. The ghost replays your
## personal-best path alongside the live player, so you can see where you're
## ahead or behind. This is a local/offline feature — no server required.
##
## Design:
##   - Ghost mode uses the ReplaySystem to record the player's best run.
##   - When the player starts a new run with the same world seed as their PB,
##     the ghost automatically spawns and plays back the PB path.
##   - A small "ghost delta" indicator shows whether the player is ahead
##     (green) or behind (red) the ghost at the same timestamp.
##   - The ghost is purely visual — no collision, no gameplay effect.
##   - Ghost mode can be toggled on/off from the settings menu or via the
##     `toggle_ghost` input action (G key is already used for pet fetch, so
##     we use the F11 key instead).
##
## What "best run" means:
##   - For Speedrun mode: the run with the lowest total time (the PB).
##   - For Endless mode: the run that reached the highest wave.
##   - For Normal/Boss Rush: the run with the highest score.
##   - The ghost only activates if the new run uses the SAME world seed as
##     the best run — otherwise the path wouldn't make sense.
##
## Public API:
##   toggle_ghost() -> bool      — toggle ghost mode on/off
##   set_ghost_enabled(bool)    — set explicitly
##   is_ghost_enabled() -> bool
##   get_ghost_delta() -> float  — seconds ahead (+) or behind (-) the ghost
##   is_ghost_active() -> bool   — is a ghost currently playing?

extends Node

const SAVE_PATH: String = "user://zorp_ghost.json"
const GHOST_DELTA_UPDATE_INTERVAL: float = 0.5  # Update delta indicator every 0.5s

signal ghost_enabled_changed(enabled: bool)
signal ghost_spawned()
signal ghost_despawned()
signal ghost_delta_changed(delta: float)

# Settings
var _ghost_enabled: bool = true
# The replay ID of the best run for the current mode+seed
var _best_replay_id: String = ""
# The ghost's "time offset" — how far into the replay the ghost is
var _ghost_time: float = 0.0
# The player's current run time
var _player_time: float = 0.0
# Delta update timer
var _delta_timer: float = 0.0
# Whether a ghost is currently active
var _ghost_active: bool = false


func _ready() -> void:
	_load_settings()
	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)
		GameManager.player_died.connect(_on_player_died)
	if ReplaySystem:
		ReplaySystem.playback_started.connect(_on_playback_started)
		ReplaySystem.playback_finished.connect(_on_playback_finished)


func _process(delta: float) -> void:
	if not _ghost_active or not GameManager or not GameManager.player_is_alive:
		return
	_player_time += delta
	_delta_timer += delta
	if _delta_timer >= GHOST_DELTA_UPDATE_INTERVAL:
		_delta_timer = 0.0
		_update_ghost_delta()


# ── Public API ────────────────────────────────────────────────────────────────

func toggle_ghost() -> bool:
	_ghost_enabled = not _ghost_enabled
	_save_settings()
	ghost_enabled_changed.emit(_ghost_enabled)
	if not _ghost_enabled:
		stop_ghost()
	return _ghost_enabled


func set_ghost_enabled(enabled: bool) -> void:
	if _ghost_enabled == enabled:
		return
	_ghost_enabled = enabled
	_save_settings()
	ghost_enabled_changed.emit(enabled)
	if not _ghost_enabled:
		stop_ghost()


func is_ghost_enabled() -> bool:
	return _ghost_enabled


## Try to start the ghost for the current run. Called on game start.
func try_start_ghost() -> void:
	if not _ghost_enabled:
		return
	if not ReplaySystem:
		return
	_best_replay_id = _find_best_replay()
	if _best_replay_id.is_empty():
		return
	# Start playback — the ghost will follow the recorded path
	if ReplaySystem.play_replay(_best_replay_id):
		_ghost_active = true
		_player_time = 0.0
		_last_delta_sign = 0  # Reset change detector for the new ghost
		ghost_spawned.emit()
		GameManager.add_message("👻 Ghost mode — race against your best run!")


## Stop the ghost if it's playing.
func stop_ghost() -> void:
	if not _ghost_active:
		return
	if ReplaySystem and ReplaySystem.is_playing():
		ReplaySystem.stop_playback()
	_ghost_active = false
	_best_replay_id = ""
	ghost_despawned.emit()


func is_ghost_active() -> bool:
	return _ghost_active


## Returns the time delta: positive = player is ahead, negative = behind.
func get_ghost_delta() -> float:
	if not _ghost_active:
		return 0.0
	return _player_time - _ghost_time


# ── Internal ──────────────────────────────────────────────────────────────────

## Find the best replay for the current game mode + world seed.
func _find_best_replay() -> String:
	if not ReplaySystem:
		return ""
	var replays: Array[Dictionary] = ReplaySystem.get_replay_list()
	if replays.is_empty():
		return ""
	var current_seed: int = GameManager.world_seed if GameManager else 0
	var current_mode: String = GameModeManager.get_mode_name() if GameModeManager else "Normal"
	var best_id: String = ""
	var best_score: float = -INF
	var best_time: float = INF
	var best_wave: int = -1
	for entry in replays:
		# Must match the same world seed
		if int(entry.get("seed", -1)) != current_seed:
			continue
		var mode: String = String(entry.get("mode", "Normal"))
		if mode != current_mode:
			continue
		if current_mode == "Speedrun":
			# Lowest duration wins
			var dur: float = float(entry.get("duration", INF))
			if dur < best_time:
				best_time = dur
				best_id = String(entry.get("id", ""))
		elif current_mode == "Endless":
			# Highest wave wins (stored in "kills" as a proxy — or we'd need
			# to store wave in metadata; for now use score as the tiebreaker)
			var score: int = int(entry.get("score", 0))
			if score > best_score:
				best_score = score
				best_id = String(entry.get("id", ""))
		else:
			# Normal / Boss Rush — highest score wins
			var score: int = int(entry.get("score", 0))
			if score > best_score:
				best_score = score
				best_id = String(entry.get("id", ""))
	return best_id


var _last_delta_sign: int = 0  # -1 behind, 0 even, 1 ahead — for change detection

func _update_ghost_delta() -> void:
	if not ReplaySystem or not ReplaySystem.is_playing():
		return
	# The ghost's "time" is how far into the replay it is
	_ghost_time = ReplaySystem.get_playback_progress() * _get_replay_duration()
	var delta: float = get_ghost_delta()
	ghost_delta_changed.emit(delta)
	# Only post a message when the delta CROSSES zero (ahead ↔ behind),
	# not every 0.5s — otherwise the message log gets spammed with a
	# stream of "Ahead by 3.2s / Ahead by 3.3s / ..." messages.
	var sign: int = 1 if delta > 0 else (-1 if delta < -0.5 else 0)
	if sign != _last_delta_sign:
		_last_delta_sign = sign
		if sign > 0:
			GameManager.add_message("👻 Ahead of your ghost — keep it up!")
		elif sign < 0:
			GameManager.add_message("👻 Falling behind your ghost!")


func _get_replay_duration() -> float:
	# We don't store the duration separately; estimate from sample count
	# For now, just use a rough estimate from the replay list
	if not ReplaySystem or _best_replay_id.is_empty():
		return 60.0  # Default estimate
	var replays: Array[Dictionary] = ReplaySystem.get_replay_list()
	for entry in replays:
		if String(entry.get("id", "")) == _best_replay_id:
			return float(entry.get("duration", 60.0))
	return 60.0


# ── Signal Handlers ───────────────────────────────────────────────────────────

func _on_game_restarted() -> void:
	_player_time = 0.0
	# Try to start the ghost after a short delay (let the world load first).
	# But skip if a ghost is already active — GameManager._start_game()
	# (which runs just before this signal fires) already called
	# try_start_ghost(), so a deferred re-call would stop and restart the
	# ghost, causing a visual flicker.
	if not _ghost_active:
		call_deferred("try_start_ghost")


func _on_player_died() -> void:
	stop_ghost()


func _on_playback_started(_replay_id: String) -> void:
	# The ghost started playing — nothing extra to do here
	pass


func _on_playback_finished() -> void:
	_ghost_active = false
	ghost_despawned.emit()
	GameManager.add_message("👻 Ghost finished — you outlasted your past self!")


# ── Persistence ───────────────────────────────────────────────────────────────

func _load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var text: String = f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY:
		_ghost_enabled = bool(data.get("enabled", true))


func _save_settings() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		return
	var data: Dictionary = {"enabled": _ghost_enabled}
	f.store_string(JSON.stringify(data, "  "))
	f.close()