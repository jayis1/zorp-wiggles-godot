## Zorp Wiggles — Replay System (Phase 32: Multiplayer & Social)
## Records the player's transform + key gameplay events into a full-run replay
## buffer that can be played back later. Unlike DeathReplay (which only keeps
## the last 5 seconds for the death cam), this system records the ENTIRE run
## and persists it to disk so it can be replayed later or shared.
##
## Design:
##   - `start_recording(seed)` begins capturing samples at RECORD_HZ (30 Hz —
##     half the physics tick, plenty for smooth playback without huge files).
##     Each sample is compact: position (3 floats), yaw, pitch, mesh_yaw,
##     is_dashing, is_shooting, current_biome. ~28 bytes/sample.
##   - `record_frame(player)` is called from player.gd _physics_process.
##   - `stop_recording()` finalizes and persists the replay to disk.
##   - `play_replay()` instantiates a ghost player and drives it along the
##     recorded path. The ghost is a translucent MeshInstance3D — purely
##     visual, no collision, no gameplay effect.
##   - Replays are saved to `user://zorp_replays/` as timestamped JSON files.
##     A manifest file `user://zorp_replays/manifest.json` tracks the most
##     recent replays for the replay browser.
##   - Replays auto-delete after MAX_STORED_REPLAYS to avoid disk bloat.
##
## What is recorded:
##   - Player transform (position, camera yaw/pitch, mesh rotation)
##   - Gameplay state flags (dashing, shooting) for visual sync
##   - Current biome (for color-tinting the ghost)
##   - World seed (so the world can be regenerated for faithful playback)
##   - Run metadata: score, kills, level, time, mode, timestamp
##
## What is NOT recorded:
##   - Enemy positions, collectible positions, projectiles (regenerated from
##     seed — the world is procedural, so a replay is "the same run" if the
##     seed matches and the player follows the same path)
##   - Input state (we record the OUTCOME of inputs, not the inputs themselves
##     — simpler and more robust to frame-rate differences)
##
## Public API:
##   start_recording(seed)   — begin a new recording
##   record_frame(player)     — sample the player (call from _physics_process)
##   stop_recording(metadata) — finalize + persist
##   is_recording() -> bool
##   play_replay(replay_id)   — spawn a ghost and play back
##   stop_playback()          — stop and remove the ghost
##   is_playing() -> bool
##   get_replay_list() -> Array[Dictionary]
##   delete_replay(replay_id)
##   get_playback_progress() -> float

extends Node

const REPLAY_DIR: String = "user://zorp_replays/"
const MANIFEST_PATH: String = "user://zorp_replays/manifest.json"
const MAX_STORED_REPLAYS: int = 10
const RECORD_HZ: float = 30.0
const SAMPLE_DT: float = 1.0 / RECORD_HZ
const PLAYBACK_HZ: float = 30.0  # Samples per real second during playback
const GHOST_COLOR: Color = Color(0.6, 0.8, 1.0, 0.45)  # Translucent cyan

signal recording_started(seed: int)
signal recording_stopped(replay_id: String)
signal playback_started(replay_id: String)
signal playback_finished()
signal playback_progress_changed(progress: float)

# Recording state
var _recording: bool = false
var _samples: Array[Dictionary] = []
var _sample_accum: float = 0.0
var _record_seed: int = 0
var _record_start_time: float = 0.0

# Playback state
var _playing: bool = false
var _play_replay_id: String = ""
var _play_samples: Array[Dictionary] = []
var _play_idx: int = 0
var _play_accum: float = 0.0
var _ghost: Node3D = null
var _ghost_mesh: MeshInstance3D = null
var _ghost_light: OmniLight3D = null
var _ghost_label: Label3D = null


func _ready() -> void:
	# Ensure the replay directory exists
	DirAccess.make_dir_recursive_absolute(REPLAY_DIR)
	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)
		GameManager.player_died.connect(_on_player_died)


func _process(delta: float) -> void:
	if not _playing:
		return
	# Advance playback using REAL delta (consistent regardless of time scale)
	_play_accum += delta * PLAYBACK_HZ
	while _play_accum >= 1.0 and _play_idx < _play_samples.size():
		_play_accum -= 1.0
		_play_idx += 1
	if _play_idx >= _play_samples.size():
		_finish_playback()
		return
	_apply_sample(_play_samples[_play_idx])
	playback_progress_changed.emit(get_playback_progress())


# ── Recording ─────────────────────────────────────────────────────────────────

## Begin a new recording. Called from GameManager._start_game().
func start_recording(world_seed: int) -> void:
	_recording = true
	_samples.clear()
	_sample_accum = 0.0
	_record_frame_toggle = false
	_record_seed = world_seed
	_record_start_time = Time.get_ticks_msec() / 1000.0
	recording_started.emit(world_seed)


## Sample the player's state. Called from player.gd _physics_process every frame.
## Throttles to RECORD_HZ (30 Hz) — half the physics tick — by recording every
## other frame. The original approach added SAMPLE_DT to an accumulator each
## frame and checked `< SAMPLE_DT`, but since the accumulator always reached
## SAMPLE_DT in one frame, it recorded every frame (60 Hz) instead of 30 Hz.
## A simple frame toggle correctly halves the rate.
var _record_frame_toggle: bool = false
func record_frame(player: CharacterBody3D) -> void:
	if not _recording or not is_instance_valid(player):
		return
	_record_frame_toggle = not _record_frame_toggle
	if not _record_frame_toggle:
		return  # Skip every other frame → 60 Hz / 2 = 30 Hz
	var mesh_rot_y: float = 0.0
	var m: Variant = player.get("mesh")
	if m and is_instance_valid(m):
		mesh_rot_y = m.rotation.y
	var sample: Dictionary = {
		"p": [player.global_position.x, player.global_position.y, player.global_position.z],
		"yaw": player.camera_yaw if "camera_yaw" in player else 0.0,
		"pitch": player.camera_pitch if "camera_pitch" in player else 0.0,
		"mrot": mesh_rot_y,
		"dash": bool(player.get("player_is_dashing")) if player.has_method("get") else false,
		"biome": int(GameManager.current_biome) if GameManager else 0,
	}
	_samples.append(sample)


## Finalize the recording and persist to disk. Returns the replay ID or "".
func stop_recording(metadata: Dictionary) -> String:
	if not _recording:
		return ""
	_recording = false
	if _samples.size() < 30:
		# Too short to be worth saving (< 1 second)
		_samples.clear()
		return ""
	var replay_id: String = "replay_%d" % int(Time.get_ticks_msec())
	var replay_data: Dictionary = {
		"id": replay_id,
		"seed": _record_seed,
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"sample_count": _samples.size(),
		"duration": float(_samples.size()) / RECORD_HZ,
		"metadata": metadata,
		"samples": _samples,
	}
	var path: String = REPLAY_DIR + replay_id + ".json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		push_warning("[ReplaySystem] Could not write replay file: %s" % path)
		_samples.clear()
		return ""
	f.store_string(JSON.stringify(replay_data))
	f.close()
	_samples.clear()
	_update_manifest(replay_id, metadata, replay_data)
	recording_stopped.emit(replay_id)
	print("[ReplaySystem] Saved replay %s (%d samples, %.1fs)" % [replay_id, replay_data.sample_count, replay_data.duration])
	_prune_old_replays()
	return replay_id


func is_recording() -> bool:
	return _recording


# ── Playback ──────────────────────────────────────────────────────────────────

## Play back a recorded replay. Spawns a translucent ghost player that follows
## the recorded path. Returns true on success.
func play_replay(replay_id: String) -> bool:
	if _playing:
		stop_playback()
	var path: String = REPLAY_DIR + replay_id + ".json"
	if not FileAccess.file_exists(path):
		push_warning("[ReplaySystem] Replay file not found: %s" % path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return false
	var text: String = f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("[ReplaySystem] Corrupt replay file: %s" % path)
		return false
	var samples: Array = data.get("samples", [])
	if samples.is_empty():
		return false
	_play_replay_id = replay_id
	_play_samples = samples
	_play_idx = 0
	_play_accum = 0.0
	_spawn_ghost()
	_playing = true
	playback_started.emit(replay_id)
	print("[ReplaySystem] Playing replay %s (%d samples)" % [replay_id, samples.size()])
	return true


## Stop playback and remove the ghost.
func stop_playback() -> void:
	if not _playing:
		return
	_finish_playback()


func is_playing() -> bool:
	return _playing


func get_playback_progress() -> float:
	if not _playing or _play_samples.is_empty():
		return 0.0
	return clampf(float(_play_idx) / float(_play_samples.size()), 0.0, 1.0)


func _spawn_ghost() -> void:
	_ghost = Node3D.new()
	_ghost.name = "ReplayGhost"
	# Translucent cyan sphere
	_ghost_mesh = MeshInstance3D.new()
	_ghost_mesh.mesh = SphereMesh.new()
	(_ghost_mesh.mesh as SphereMesh).radius = 0.45
	(_ghost_mesh.mesh as SphereMesh).height = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GHOST_COLOR
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.7, 1.0)
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true  # Always visible
	_ghost_mesh.material_override = mat
	_ghost.add_child(_ghost_mesh)
	# Soft glow light
	_ghost_light = OmniLight3D.new()
	_ghost_light.light_color = Color(0.5, 0.8, 1.0)
	_ghost_light.light_energy = 1.2
	_ghost_light.omni_range = 4.0
	_ghost_light.omni_attenuation = 1.5
	_ghost.add_child(_ghost_light)
	# Floating label
	_ghost_label = Label3D.new()
	_ghost_label.text = "GHOST"
	_ghost_label.font_size = 24
	_ghost_label.modulate = Color(0.7, 0.9, 1.0, 0.8)
	_ghost_label.no_depth_test = true
	_ghost_label.position = Vector3(0, 1.5, 0)
	_ghost.add_child(_ghost_label)
	# Add to the scene
	var parent: Node = get_tree().current_scene
	if parent:
		parent.add_child(_ghost)
	else:
		add_child(_ghost)


func _apply_sample(sample: Dictionary) -> void:
	if not _ghost or not is_instance_valid(_ghost):
		return
	var p: Array = sample.get("p", [0, 0, 0])
	_ghost.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	if _ghost_mesh and is_instance_valid(_ghost_mesh):
		_ghost_mesh.rotation.y = float(sample.get("mrot", 0.0))
	# Tint the ghost by biome color for visual variety
	var biome: int = int(sample.get("biome", 0))
	if _ghost_light and is_instance_valid(_ghost_light):
		var biome_color: Color = _biome_ghost_color(biome)
		_ghost_light.light_color = biome_color


func _finish_playback() -> void:
	_playing = false
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_ghost_mesh = null
	_ghost_light = null
	_ghost_label = null
	_play_samples.clear()
	_play_idx = 0
	playback_finished.emit()
	print("[ReplaySystem] Playback finished")


# ── Replay List / Manifest ────────────────────────────────────────────────────

## Get a list of saved replays (most recent first).
## Each entry: { id, timestamp, score, kills, level, duration, mode, seed }
func get_replay_list() -> Array[Dictionary]:
	var manifest: Array[Dictionary] = []
	if not FileAccess.file_exists(MANIFEST_PATH):
		return manifest
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if not f:
		return manifest
	var text: String = f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_ARRAY:
		return manifest
	for entry in data:
		if typeof(entry) == TYPE_DICTIONARY:
			manifest.append(entry)
	# Sort by timestamp descending (most recent first)
	manifest.sort_custom(func(a, b): return String(a.get("timestamp", "")) > String(b.get("timestamp", "")))
	return manifest


## Delete a replay by ID.
func delete_replay(replay_id: String) -> void:
	var path: String = REPLAY_DIR + replay_id + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	# Remove from manifest
	var list: Array[Dictionary] = get_replay_list()
	var new_list: Array[Dictionary] = []
	for entry in list:
		if String(entry.get("id", "")) != replay_id:
			new_list.append(entry)
	_save_manifest(new_list)


func _update_manifest(replay_id: String, metadata: Dictionary, replay_data: Dictionary) -> void:
	var list: Array[Dictionary] = get_replay_list()
	var entry: Dictionary = {
		"id": replay_id,
		"timestamp": replay_data.get("timestamp", ""),
		"duration": replay_data.get("duration", 0.0),
		"seed": replay_data.get("seed", 0),
		"score": int(metadata.get("score", 0)),
		"kills": int(metadata.get("kills", 0)),
		"level": int(metadata.get("level", 1)),
		"mode": String(metadata.get("mode", "Normal")),
		"biome": int(metadata.get("biome", 0)),
	}
	list.append(entry)
	_save_manifest(list)


func _save_manifest(list: Array) -> void:
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if not f:
		push_warning("[ReplaySystem] Could not write manifest file")
		return
	f.store_string(JSON.stringify(list, "  "))
	f.close()


## Remove old replays beyond MAX_STORED_REPLAYS (oldest first).
func _prune_old_replays() -> void:
	var list: Array[Dictionary] = get_replay_list()
	if list.size() <= MAX_STORED_REPLAYS:
		return
	# Sort by timestamp ascending (oldest first)
	list.sort_custom(func(a, b): return String(a.get("timestamp", "")) < String(b.get("timestamp", "")))
	var to_remove: int = list.size() - MAX_STORED_REPLAYS
	for i in to_remove:
		var entry: Dictionary = list[i]
		var rid: String = String(entry.get("id", ""))
		if not rid.is_empty():
			var path: String = REPLAY_DIR + rid + ".json"
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	# Update manifest with only the kept entries
	var kept: Array[Dictionary] = list.slice(to_remove)
	_save_manifest(kept)


# ── Signal Handlers ───────────────────────────────────────────────────────────

func _on_game_restarted() -> void:
	# Restart starts a fresh recording — but only if we aren't already
	# recording. GameManager._start_game() (which runs just before this signal
	# fires) already calls start_recording(), so re-calling here would clear
	# the first few samples for no reason. Skipping when already recording
	# preserves them. On the initial game load (_ready → _start_game with no
	# game_restarted emission), the direct call in _start_game handles it.
	if GameManager and not _recording:
		start_recording(GameManager.world_seed)


func _on_player_died() -> void:
	# Stop recording and save the replay with final stats
	if _recording and GameManager:
		var metadata: Dictionary = {
			"score": GameManager.player_score,
			"kills": GameManager.player_kills,
			"level": GameManager.player_level,
			"mode": GameModeManager.get_mode_name() if GameModeManager else "Normal",
			"biome": GameManager.current_biome,
		}
		stop_recording(metadata)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _biome_ghost_color(biome_id: int) -> Color:
	# Use biome fog colors as a quick tint reference
	if GameConstants.BIOME_FOG and biome_id >= 0 and biome_id < GameConstants.BIOME_FOG.size():
		var fog: Dictionary = GameConstants.BIOME_FOG[biome_id]
		return Color(float(fog.get("r", 0.5)), float(fog.get("g", 0.7)), float(fog.get("b", 1.0)))
	return GHOST_COLOR