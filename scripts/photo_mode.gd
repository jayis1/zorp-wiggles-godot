## Zorp Wiggles — Photo Mode (Phase 30: Visual & Audio Polish)
## Freezes the game and lets the player fly a free-look camera around the world
## to compose screenshots. Activated with the F9 key. While active:
##   - The game tree is paused (enemies, weather, spawners all freeze)
##   - A dedicated free-look Camera3D takes over the viewport
##   - WASD moves the camera, Space/Shift move up/down, mouse drag orbits
##   - Scroll wheel adjusts FOV (zoom)
##   - F captures a screenshot to user://screenshots/
##   - C cycles the active color filter (so you can compose with different moods)
##   - Esc or F9 exits photo mode, restoring the main camera and unpausing
##
## Screenshots are saved as PNG with a timestamp filename. A HUD message
## confirms the save path. The free-look camera starts at the player's current
## position so the player doesn't have to fly across the world to frame their shot.

extends Node

# ─── State ────────────────────────────────────────────────────────────────────
var _active: bool = false
var _free_camera: Camera3D = null
var _main_camera: Camera3D = null
var _camera_rig: Node3D = null
var _saved_orbit_distance: float = 0.0
var _yaw: float = 0.0
var _pitch: float = -45.0
var _move_speed: float = 12.0
var _is_dragging: bool = false
var _filter_cycle_index: int = 0
var _hud_label: Label = null
var _hud_panel: Panel = null

# ─── Tuning ───────────────────────────────────────────────────────────────────
const FREE_CAMERA_NAME: String = "PhotoModeFreeCamera"
const SCREENSHOT_DIR: String = "user://screenshots/"
const MOVE_SPEED_MIN: float = 2.0
const MOVE_SPEED_MAX: float = 60.0
const FOV_MIN: float = 30.0
const FOV_MAX: float = 110.0
const FOV_STEP: float = 3.0
const PITCH_LIMIT: float = 88.0  # Degrees from horizon — prevents flipping


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep running while game is paused
	# Create the HUD overlay (instructions panel) — hidden until photo mode activates
	_hud_panel = Panel.new()
	_hud_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hud_panel.offset_left = -360.0
	_hud_panel.offset_top = -160.0
	_hud_panel.offset_right = -10.0
	_hud_panel.offset_bottom = -10.0
	_hud_panel.visible = false
	_hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Add to the HUD canvas layer so it renders above the game world
	var hud: CanvasLayer = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.add_child(_hud_panel)
	else:
		add_child(_hud_panel)
	_hud_label = Label.new()
	_hud_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_label.offset_left = 8.0
	_hud_label.offset_top = 8.0
	_hud_label.offset_right = -8.0
	_hud_label.offset_bottom = -8.0
	_hud_label.text = _help_text()
	_hud_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_hud_label.add_theme_font_size_override("font_size", 13)
	_hud_panel.add_child(_hud_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("photo_mode"):
		if _active:
			exit_photo_mode()
		else:
			enter_photo_mode()
		get_viewport().set_input_as_handled()
		return
	if not _active:
		return
	# Handle photo mode inputs
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_adjust_fov(-FOV_STEP)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_adjust_fov(FOV_STEP)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_dragging and _free_camera:
		_yaw -= event.relative.x * 0.25
		_pitch = clampf(_pitch - event.relative.y * 0.25, -PITCH_LIMIT, PITCH_LIMIT)
		_apply_camera_rotation()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				exit_photo_mode()
				get_viewport().set_input_as_handled()
			KEY_F:
				_capture_screenshot()
				get_viewport().set_input_as_handled()
			KEY_C:
				_cycle_filter()
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _active or not _free_camera:
		return
	# WASD + Space/Shift movement in camera-local space
	var input_dir: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	if Input.is_key_pressed(KEY_SPACE):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_SHIFT):
		input_dir.y -= 1
	# Speed boost with Ctrl
	var speed: float = _move_speed
	if Input.is_key_pressed(KEY_CTRL):
		speed *= 3.0
	# Transform input direction by the camera's basis (so W = forward relative to view)
	var basis: Basis = _free_camera.global_transform.basis
	var move: Vector3 = (basis * input_dir).normalized() * speed * delta
	_free_camera.global_position += move


# ─── Public API ───────────────────────────────────────────────────────────────

func enter_photo_mode() -> void:
	if _active:
		return
	_active = true
	# Find the main camera
	_main_camera = get_viewport().get_camera_3d()
	_camera_rig = get_tree().get_first_node_in_group("camera_rig")
	# If no camera_rig group, search by node name
	if not _camera_rig:
		_camera_rig = get_tree().current_scene.get_node_or_null("CameraRig")
	# Create the free-look camera at the main camera's current position
	_free_camera = Camera3D.new()
	_free_camera.name = FREE_CAMERA_NAME
	_free_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	_free_camera.fov = _main_camera.fov if _main_camera else 70.0
	if _main_camera:
		_free_camera.global_transform = _main_camera.global_transform
		_free_camera.global_position = _main_camera.global_position
		# Initialize yaw/pitch from the current rotation
		var euler: Vector3 = _main_camera.global_transform.basis.get_euler()
		_yaw = rad_to_deg(euler.y)
		_pitch = rad_to_deg(euler.x)
	else:
		# Fallback: start at the player's position
		var player: Node3D = get_tree().get_first_node_in_group("player")
		if player:
			_free_camera.global_position = player.global_position + Vector3(0, 5, -10)
		_yaw = 0.0
		_pitch = -45.0
	get_tree().current_scene.add_child(_free_camera)
	_free_camera.make_current()
	_apply_camera_rotation()
	# Pause the game tree so enemies/weather/spawners freeze. The free camera
	# and this script use PROCESS_MODE_ALWAYS so they keep running.
	get_tree().paused = true
	if GameManager:
		GameManager.is_paused = true
	# Show the help panel
	if _hud_panel:
		_hud_panel.visible = true
	if GameManager:
		GameManager.add_message("📷 Photo Mode — F9 to exit, F to capture, C cycle filter, WASD/Space/Shift move, drag to orbit, scroll to zoom")
	print("[PhotoMode] Entered — free camera at %s" % _free_camera.global_position)


func exit_photo_mode() -> void:
	if not _active:
		return
	_active = false
	# Restore the main camera
	if _main_camera and is_instance_valid(_main_camera):
		_main_camera.make_current()
	# Remove the free-look camera
	if _free_camera and is_instance_valid(_free_camera):
		_free_camera.queue_free()
	_free_camera = null
	# Unpause
	get_tree().paused = false
	if GameManager:
		GameManager.is_paused = false
	# Hide the help panel
	if _hud_panel:
		_hud_panel.visible = false
	if GameManager:
		GameManager.add_message("📷 Photo Mode exited")
	print("[PhotoMode] Exited")


func is_active() -> bool:
	return _active


# ─── Internal ─────────────────────────────────────────────────────────────────

func _apply_camera_rotation() -> void:
	if not _free_camera:
		return
	_free_camera.rotation_degrees = Vector3(_pitch, _yaw, 0)


func _adjust_fov(delta_fov: float) -> void:
	if not _free_camera:
		return
	_free_camera.fov = clampf(_free_camera.fov + delta_fov, FOV_MIN, FOV_MAX)
	if GameManager:
		GameManager.add_message("📷 FOV: %.0f°" % _free_camera.fov)


func _cycle_filter() -> void:
	if not AccessibilityManager:
		return
	var mode: int = AccessibilityManager.cycle_filter()
	GameManager.add_message("📷 Filter: " + AccessibilityManager.FILTER_NAMES[mode])


func _capture_screenshot() -> void:
	# Ensure the screenshots directory exists
	DirAccess.make_dir_recursive_absolute(SCREENSHOT_DIR)
	# Build a timestamped filename
	var timestamp: String = Time.get_datetime_string_from_system(false, true).replace(":", "-")
	var filepath: String = SCREENSHOT_DIR + "zorp_%s.png" % timestamp
	# Capture the viewport texture and save as PNG
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		GameManager.add_message("📷 Screenshot failed — could not capture viewport")
		push_warning("[PhotoMode] Could not capture viewport image")
		return
	var err: int = img.save_png(filepath)
	if err == OK:
		GameManager.add_message("📷 Screenshot saved: %s" % filepath)
		print("[PhotoMode] Screenshot saved: %s" % filepath)
		# Flash the screen briefly as capture feedback
		_flash_capture()
	else:
		GameManager.add_message("📷 Screenshot failed to save (error %d)" % err)
		push_warning("[PhotoMode] save_png failed with error %d" % err)


func _flash_capture() -> void:
	# Brief white flash overlay to confirm the capture (like a camera shutter)
	var flash: ColorRect = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0.8)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Add to the HUD layer so it renders above the game world
	var hud: CanvasLayer = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.add_child(flash)
	else:
		get_tree().current_scene.add_child(flash)
	var t: Tween = flash.create_tween()
	t.tween_property(flash, "color:a", 0.0, 0.2).set_ease(Tween.EASE_OUT)
	t.tween_callback(flash.queue_free)


func _help_text() -> String:
	return "📷 PHOTO MODE\n" + \
		"WASD — Move camera\n" + \
		"Space / Shift — Up / Down\n" + \
		"Ctrl — Speed boost\n" + \
		"Left-drag — Orbit\n" + \
		"Scroll — FOV zoom\n" + \
		"F — Capture screenshot\n" + \
		"C — Cycle color filter\n" + \
		"Esc / F9 — Exit photo mode"