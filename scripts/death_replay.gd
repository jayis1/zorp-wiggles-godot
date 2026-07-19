## Zorp Wiggles — Death Replay System (Phase 30: Visual & Audio Polish)
## Records the last ~5 seconds of the player's transform (position + rotation +
## camera yaw/pitch) into a ring buffer. On player death, plays back the
## recording in slow-motion (0.25× time scale) as a "death cam" replay before
## the death screen appears.
##
## This is a lightweight, gameplay-only replay — it records the player's
## transform, not the entire world state. During playback the player mesh is
## moved along the recorded path while the world continues to update (enemies
## keep moving at the slow time scale, giving a cinematic "freeze frame" feel).
##
## The replay is rendered by teleporting the player node back along the
## recorded path. To avoid disrupting gameplay systems that read the player's
## position, playback only runs AFTER player_is_alive = false (the player is
## already dead — no further gameplay reads matter).
##
## Public API:
##   record_frame(player)         — call every _physics_process from player.gd
##   start_replay(player)         — call on player_died signal
##   is_playing() -> bool
##   stop_replay()                — cancel and restore normal time
##
## Signals:
##   replay_started()
##   replay_finished()

extends Node

signal replay_started()
signal replay_finished()

const BUFFER_SECONDS: float = 5.0
const REPLAY_TIME_SCALE: float = 0.25  # Slow-mo
const RECORD_HZ: float = 60.0          # Sample rate (matches physics tick)
const REPLAY_HZ: float = 60.0          # Playback rate (samples per real second)

# Ring buffer of transform samples
var _samples: Array[Dictionary] = []
var _max_samples: int = int(BUFFER_SECONDS * RECORD_HZ)
var _sample_accum: float = 0.0
const SAMPLE_DT: float = 1.0 / RECORD_HZ

# Playback state
var _playing: bool = false
var _play_idx: int = 0
var _play_accum: float = 0.0
var _saved_time_scale: float = 1.0
var _player_ref: CharacterBody3D = null
var _saved_mesh_rot: Vector3 = Vector3.ZERO
var _saved_pos: Vector3 = Vector3.ZERO
var _saved_yaw: float = 0.0
var _saved_pitch: float = 0.0


func _ready() -> void:
	_samples.resize(_max_samples)
	_samples.clear()
	_samples.resize(_max_samples)
	# Pre-fill with empty dicts so the ring buffer is safe to write
	for i in _max_samples:
		_samples[i] = {}
	if GameManager:
		GameManager.player_died.connect(_on_player_died)
		GameManager.game_restarted.connect(_on_game_restarted)


func _on_player_died() -> void:
	# Start the replay using the player node reference
	var p: CharacterBody3D = GameManager.player
	if p and is_instance_valid(p):
		start_replay(p)


func _on_game_restarted() -> void:
	stop_replay()
	_samples.clear()
	_samples.resize(_max_samples)
	for i in _max_samples:
		_samples[i] = {}
	_sample_accum = 0.0


# ─── Recording ──────────────────────────────────────────────────────────────────

## Called from player.gd _physics_process every frame. Samples the player's
## transform at RECORD_HZ into the ring buffer. Cheap enough to run every
## frame even though we only keep ~300 samples.
func record_frame(player: CharacterBody3D) -> void:
	if _playing:
		return  # Don't record during playback
	if not is_instance_valid(player):
		return
	_sample_accum += SAMPLE_DT  # Approximate — uses physics delta implicitly
	# We sample at a fixed rate independent of actual frame timing. Since
	# _physics_process runs at ~60Hz by default in Godot, this is close enough.
	# The accumulator approach smooths over minor frame-rate jitter.
	if _sample_accum < SAMPLE_DT:
		return
	_sample_accum = 0.0
	# Defensive mesh access — the player may not have a mesh during early init
	var mesh_rot: Vector3 = Vector3.ZERO
	if player.get("mesh") and is_instance_valid(player.get("mesh")):
		mesh_rot = player.mesh.rotation
	var sample: Dictionary = {
		"pos": player.global_position,
		"mesh_rot": mesh_rot,
		"yaw": player.camera_yaw,
		"pitch": player.camera_pitch,
		"t": Time.get_ticks_msec() / 1000.0,
	}
	# Ring buffer: append + keep last _max_samples
	_samples.append(sample)
	if _samples.size() > _max_samples:
		_samples.pop_front()


# ─── Playback ───────────────────────────────────────────────────────────────────

## Begin slow-mo replay. Captures the player's current state for restoration
## (though on death the player is about to be reset anyway, so restoration is
## mostly a safety net).
func start_replay(player: CharacterBody3D) -> void:
	if _playing:
		return
	if _samples.size() < 10:
		return  # Not enough recorded data to bother
	if not is_instance_valid(player):
		return  # Defensive: no player to replay with
	_playing = true
	_play_idx = 0
	_play_accum = 0.0
	_player_ref = player
	_saved_time_scale = Engine.time_scale
	_saved_pos = player.global_position
	var m: Variant = player.get("mesh")
	_saved_mesh_rot = m.rotation if (m and is_instance_valid(m)) else Vector3.ZERO
	_saved_yaw = player.camera_yaw
	_saved_pitch = player.camera_pitch
	Engine.time_scale = REPLAY_TIME_SCALE
	replay_started.emit()
	print("[DeathReplay] Starting slow-mo replay (%d samples)" % _samples.size())


func _process(delta: float) -> void:
	if not _playing:
		return
	if not is_instance_valid(_player_ref):
		_finish_replay()
		return
	# Advance playback using REAL delta (not scaled — we want consistent
	# playback speed regardless of the time scale we just set)
	_play_accum += delta * REPLAY_HZ
	while _play_accum >= 1.0 and _play_idx < _samples.size():
		_play_accum -= 1.0
		_play_idx += 1
	if _play_idx >= _samples.size():
		_finish_replay()
		return
	# Apply the current sample to the player
	var s: Dictionary = _samples[_play_idx]
	if s.is_empty():
		_finish_replay()
		return
	_player_ref.global_position = s.get("pos", _saved_pos)
	# Defensive mesh access
	var mr: Variant = _player_ref.get("mesh")
	if mr and is_instance_valid(mr):
		mr.rotation = s.get("mesh_rot", _saved_mesh_rot)
	_player_ref.camera_yaw = s.get("yaw", _saved_yaw)
	_player_ref.camera_pitch = s.get("pitch", _saved_pitch)


func _finish_replay() -> void:
	_playing = false
	Engine.time_scale = _saved_time_scale
	# Restore the player's pre-replay transform (safety net — restart will
	# reset everything anyway, but this prevents a one-frame visual glitch if
	# the death screen reads the player position before restart clears it).
	if is_instance_valid(_player_ref):
		_player_ref.global_position = _saved_pos
		var m: Variant = _player_ref.get("mesh")
		if m and is_instance_valid(m):
			m.rotation = _saved_mesh_rot
	replay_finished.emit()
	print("[DeathReplay] Replay finished")


func is_playing() -> bool:
	return _playing


func stop_replay() -> void:
	if not _playing:
		return
	_finish_replay()


func get_progress() -> float:
	if not _playing or _samples.is_empty():
		return 0.0
	return clampf(float(_play_idx) / float(_samples.size()), 0.0, 1.0)