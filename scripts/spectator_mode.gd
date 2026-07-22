## Zorp Wiggles — Spectator Mode (Phase 32: Multiplayer & Social)
##
## An offline replay-based spectator mode. The player can watch any saved
## replay as a spectator with a free-look camera — no server required.
## This is the offline equivalent of "watching another player's run."
##
## How it works:
##   - The player picks a replay from the Replay Browser (F11) and presses
##     'S' to spectate instead of just playing the ghost alongside the
##     live player.
##   - Spectator mode pauses the live game, spawns the replay ghost, and
##     gives the spectator a free-look camera that follows the ghost
##     by default (chase cam) but can be detached for free-look.
##   - Controls: WASD move the free camera, mouse drag orbits, scroll
##     adjusts FOV, Space toggles chase-cam on/off, Esc exits spectator.
##   - A small HUD overlay shows the replay metadata (score, kills, time,
##     mode, biome) and playback progress bar.
##   - The spectator can also cycle through replays with left/right arrows
##     without exiting spectator mode.
##
## Public API:
##   start_spectating(replay_id) -> bool
##   stop_spectating() -> void
##   is_spectating() -> bool
##   get_current_replay_info() -> Dictionary
##   cycle_next_replay() -> void
##   cycle_prev_replay() -> void
##
## The spectator camera uses PROCESS_MODE_ALWAYS so it works even while
## the game tree is paused.

extends Node

const SPEC_HUD_LAYER: int = 55  # Above ShaderManager (50) but below HUD (100)

# Spectator camera
var _spec_camera: Camera3D = null
var _spec_hud: Control = null
var _spectating: bool = false
var _chase_cam: bool = true  # True = camera follows ghost, False = free-look
var _replay_id: String = ""
var _replay_info: Dictionary = {}

# Free-look camera state
var _cam_pos: Vector3 = Vector3.ZERO
var _cam_yaw: float = 0.0
var _cam_pitch: float = -0.8  # Looking down slightly
var _cam_fov: float = 70.0
var _cam_speed: float = 12.0

# Mouse look
var _mouse_captured: bool = false

signal spectating_started(replay_id: String)
signal spectating_stopped()

# ─── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_process_mode(Node.PROCESS_MODE_ALWAYS)

func _process(delta: float) -> void:
	if not _spectating:
		return
	# Handle free-look camera movement
	if not _chase_cam and _spec_camera and is_instance_valid(_spec_camera):
		var move_dir: Vector3 = Vector3.ZERO
		if Input.is_action_pressed("move_up"):
			move_dir.z -= 1.0
		if Input.is_action_pressed("move_down"):
			move_dir.z += 1.0
		if Input.is_action_pressed("move_left"):
			move_dir.x -= 1.0
		if Input.is_action_pressed("move_right"):
			move_dir.x += 1.0
		# Up/down with jump/crouch actions
		if Input.is_action_pressed("jump"):
			move_dir.y += 1.0
		if Input.is_action_pressed("crouch"):
			move_dir.y -= 1.0
		# Speed boost with dash
		var speed: float = _cam_speed
		if Input.is_action_pressed("dash"):
			speed *= 3.0
		# Transform direction by camera yaw
		var forward: Vector3 = Vector3(sin(_cam_yaw), 0.0, cos(_cam_yaw))
		var right: Vector3 = Vector3(cos(_cam_yaw), 0.0, -sin(_cam_yaw))
		var velocity: Vector3 = (forward * -move_dir.z + right * move_dir.x + Vector3.UP * move_dir.y) * speed * delta
		_cam_pos += velocity
		_apply_free_cam_transform()
	# Update HUD
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if not _spectating:
		return
	if event is InputEventKey and event.pressed:
		var ke: InputEventKey = event as InputEventKey
		match ke.keycode:
			KEY_ESCAPE:
				stop_spectating()
				get_viewport().set_input_as_handled()
			KEY_SPACE:
				_chase_cam = not _chase_cam
				if not _chase_cam:
					# Initialize free cam at current camera position
					if _spec_camera and is_instance_valid(_spec_camera):
						_cam_pos = _spec_camera.global_position
						_cam_yaw = _spec_camera.rotation.y
						_cam_pitch = _spec_camera.rotation.x
				_show_hud_message("Chase cam: %s" % ("ON" if _chase_cam else "OFF (free-look)"))
				get_viewport().set_input_as_handled()
			KEY_LEFT:
				cycle_prev_replay()
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				cycle_next_replay()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_mouse_captured = not _mouse_captured
			if _mouse_captured:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_cam_fov = clampf(_cam_fov - 5.0, 30.0, 110.0)
			if _spec_camera and is_instance_valid(_spec_camera):
				_spec_camera.fov = _cam_fov
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_cam_fov = clampf(_cam_fov + 5.0, 30.0, 110.0)
			if _spec_camera and is_instance_valid(_spec_camera):
				_spec_camera.fov = _cam_fov
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mouse_captured and not _chase_cam:
		var motion: Vector2 = event.relative
		_cam_yaw -= motion.x * 0.003
		_cam_pitch = clampf(_cam_pitch - motion.y * 0.003, -1.5, 1.5)
		_apply_free_cam_transform()

# ─── Public API ────────────────────────────────────────────────────────────────

func is_spectating() -> bool:
	return _spectating

func get_current_replay_info() -> Dictionary:
	return _replay_info

func start_spectating(replay_id: String) -> bool:
	if _spectating:
		stop_spectating()
	if not ReplaySystem:
		push_warning("[Spectator] ReplaySystem not available.")
		return false
	# Pause the game tree so the live game doesn't interfere
	get_tree().paused = true
	# Start replay playback
	if not ReplaySystem.play_replay(replay_id):
		get_tree().paused = false
		push_warning("[Spectator] Could not start replay: %s" % replay_id)
		return false
	_replay_id = replay_id
	_spectating = true
	_chase_cam = true
	# Get replay metadata from the manifest
	_replay_info = _find_replay_in_manifest(replay_id)
	# Create the spectator camera
	_create_spectator_camera()
	# Create the HUD overlay
	_create_hud()
	spectating_started.emit(replay_id)
	print("[Spectator] Spectating replay: %s" % replay_id)
	return true

func stop_spectating() -> void:
	if not _spectating:
		return
	# Stop replay playback
	if ReplaySystem:
		ReplaySystem.stop_playback()
	# Remove spectator camera
	if _spec_camera and is_instance_valid(_spec_camera):
		_spec_camera.queue_free()
	_spec_camera = null
	# Remove HUD
	if _spec_hud and is_instance_valid(_spec_hud):
		_spec_hud.queue_free()
	_spec_hud = null
	# Restore mouse
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Unpause the game tree
	get_tree().paused = false
	_spectating = false
	_replay_id = ""
	_replay_info = {}
	spectating_stopped.emit()
	print("[Spectator] Stopped spectating")

func cycle_next_replay() -> void:
	if not _spectating or not ReplaySystem:
		return
	var list: Array[Dictionary] = ReplaySystem.get_replay_list()
	if list.is_empty():
		return
	var current_idx: int = -1
	for i in list.size():
		if String(list[i].get("id", "")) == _replay_id:
			current_idx = i
			break
	var next_idx: int = (current_idx + 1) % list.size()
	var next_id: String = String(list[next_idx].get("id", ""))
	if next_id != _replay_id and not next_id.is_empty():
		_start_new_replay(next_id)

func cycle_prev_replay() -> void:
	if not _spectating or not ReplaySystem:
		return
	var list: Array[Dictionary] = ReplaySystem.get_replay_list()
	if list.is_empty():
		return
	var current_idx: int = -1
	for i in list.size():
		if String(list[i].get("id", "")) == _replay_id:
			current_idx = i
			break
	var prev_idx: int = (current_idx - 1 + list.size()) % list.size()
	var prev_id: String = String(list[prev_idx].get("id", ""))
	if prev_id != _replay_id and not prev_id.is_empty():
		_start_new_replay(prev_id)

func _start_new_replay(replay_id: String) -> void:
	if ReplaySystem:
		ReplaySystem.stop_playback()
		ReplaySystem.play_replay(replay_id)
	_replay_id = replay_id
	_replay_info = _find_replay_in_manifest(replay_id)
	_chase_cam = true
	_show_hud_message("Now spectating: %s" % _replay_info.get("mode", "Unknown"))

# ─── Internal ──────────────────────────────────────────────────────────────────

func _create_spectator_camera() -> void:
	if _spec_camera and is_instance_valid(_spec_camera):
		_spec_camera.queue_free()
	_spec_camera = Camera3D.new()
	_spec_camera.name = "SpectatorCamera"
	_spec_camera.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	_spec_camera.fov = _cam_fov
	_spec_camera.cull_mask = 0x7FFFFFFF  # Render everything
	# Start at the main camera's position
	var main_cam: Camera3D = get_viewport().get_camera_3d()
	if main_cam:
		_spec_camera.global_position = main_cam.global_position
		_spec_camera.rotation = main_cam.rotation
		_cam_pos = _spec_camera.global_position
		_cam_yaw = _spec_camera.rotation.y
		_cam_pitch = _spec_camera.rotation.x
	else:
		_spec_camera.global_position = Vector3(0, 15, 15)
		_cam_pos = _spec_camera.global_position
	# Make it the active camera
	_spec_camera.current = true
	# Add to the scene
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		scene_root.add_child(_spec_camera)
	else:
		add_child(_spec_camera)

func _apply_free_cam_transform() -> void:
	if not _spec_camera or not is_instance_valid(_spec_camera):
		return
	_spec_camera.global_position = _cam_pos
	# Build rotation from yaw + pitch
	_spec_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)

func _create_hud() -> void:
	if _spec_hud and is_instance_valid(_spec_hud):
		_spec_hud.queue_free()
	_spec_hud = Control.new()
	_spec_hud.name = "SpectatorHUD"
	_spec_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spec_hud.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	_spec_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spec_hud.visible = true
	# Add to a high canvas layer so it renders above the game
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = SPEC_HUD_LAYER
	canvas.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	canvas.add_child(_spec_hud)
	get_tree().root.add_child(canvas)

func _update_hud() -> void:
	if not _spec_hud or not is_instance_valid(_spec_hud):
		return
	_spec_hud.queue_redraw()

func _show_hud_message(msg: String) -> void:
	# Simple: print to console + could show on HUD
	print("[Spectator] %s" % msg)

func _find_replay_in_manifest(replay_id: String) -> Dictionary:
	if not ReplaySystem:
		return {}
	var list: Array[Dictionary] = ReplaySystem.get_replay_list()
	for entry in list:
		if String(entry.get("id", "")) == replay_id:
			return entry
	return {}

# ─── HUD Drawing ───────────────────────────────────────────────────────────────

# The HUD is a custom _draw Control. We set it up via a class.
class SpectatorHudControl:
	extends Control
	var _spectator: Node = null

	func _init(spec: Node) -> void:
		_spectator = spec

	func _draw() -> void:
		if not _spectator or not _spectator.is_spectating():
			return
		var font := get_theme_default_font()
		if not font:
			return
		var screen := size
		var info: Dictionary = _spectator.get_current_replay_info()
		# Top bar background
		var bar_rect := Rect2(0, 0, screen.x, 50)
		draw_rect(bar_rect, Color(0.05, 0.03, 0.08, 0.8), true)
		draw_rect(bar_rect, Color(0.5, 0.4, 0.9, 0.4), false, 1.0)
		# Title
		_draw_text(font, "👁 SPECTATOR MODE", 16, 8, 18, Color(0.7, 0.5, 1.0))
		# Replay info
		var mode_str: String = String(info.get("mode", "Unknown"))
		var score_str: String = "Score: %d" % int(info.get("score", 0))
		var kills_str: String = "Kills: %d" % int(info.get("kills", 0))
		var dur_str: String = "Duration: %.1fs" % float(info.get("duration", 0.0))
		var idx_x: float = 200
		_draw_text(font, mode_str, idx_x, 8, 14, Color(0.8, 0.75, 0.9))
		_draw_text(font, score_str, idx_x + 120, 8, 14, Color(0.8, 0.75, 0.9))
		_draw_text(font, kills_str, idx_x + 250, 8, 14, Color(0.8, 0.75, 0.9))
		_draw_text(font, dur_str, idx_x + 370, 8, 14, Color(0.8, 0.75, 0.9))
		# Playback progress bar
		if ReplaySystem and ReplaySystem.is_playing():
			var progress: float = ReplaySystem.get_playback_progress()
			var bar_w: float = screen.x - 32
			var bar_y: float = 38
			draw_rect(Rect2(16, bar_y, bar_w, 4), Color(0.2, 0.2, 0.3, 0.6), true)
			draw_rect(Rect2(16, bar_y, bar_w * progress, 4), Color(0.6, 0.4, 0.9, 0.9), true)
		# Bottom help bar
		var bottom_rect := Rect2(0, screen.y - 30, screen.x, 30)
		draw_rect(bottom_rect, Color(0.03, 0.03, 0.06, 0.75), true)
		var help_text: String = "[Space] Chase/Free  |  [WASD] Move  |  [Click] Look  |  [Wheel] FOV  |  [←→] Switch Replay  |  [Esc] Exit"
		_draw_text(font, help_text, 16, screen.y - 18, 12, Color(0.5, 0.55, 0.7))

	func _draw_text(font, text: String, x: float, y: float, size: int, color: Color) -> void:
		font.draw_string(get_canvas_item(), Vector2(x, y + size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)