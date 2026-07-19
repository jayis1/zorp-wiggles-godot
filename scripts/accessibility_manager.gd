## Zorp Wiggles — Accessibility & Visual Options Manager (Phase 30/31)
## Manages cosmetic color filters (sepia, noir, thermal, x-ray) and colorblind
## correction modes (protanopia, deuteranopia, tritanopia, achromatopsia), plus
## UI scaling for HUD readability across different screen resolutions.
##
## Architecture:
##   - A CanvasLayer (layer 60) sits above the ShaderManager (50) but below the
##     HUD (100) so filters/corrections apply to the game world without affecting
##     UI legibility. (UI text/HP bars remain crisp.)
##   - Each mode is a separate ColorRect with a ShaderMaterial. Only one filter
##     and one correction can be active at a time. Strength is persisted to disk.
##   - UI scaling works by setting the CanvasItem scale on the HUD root via the
##     `ui_scale` property — HUD elements scale around the top-left anchor.
##
## All settings persist to `user://zorp_accessibility.json` and survive restarts.

extends CanvasLayer

# ── Filter / correction mode enums ──
enum ColorFilter {
	NONE,     # 0
	SEPIA,    # 1
	NOIR,     # 2
	THERMAL,  # 3
	X_RAY,    # 4
}
enum ColorblindMode {
	NONE,            # 0
	PROTANOPIA,      # 1 (red deficiency)
	DEUTERANOPIA,    # 2 (green deficiency)
	TRITANOPIA,      # 3 (blue deficiency)
	ACHROMATOPSIA,   # 4 (full desaturation)
}

const FILTER_NAMES: Array[String] = ["Off", "Sepia", "Noir", "Thermal", "X-Ray"]
const COLORBLIND_NAMES: Array[String] = [
	"Off", "Protanopia", "Deuteranopia", "Tritanopia", "Achromatopsia"
]

# UI scale range — 0.75 (small, for 4K) to 1.5 (large, for 720p/Steam Deck)
const UI_SCALE_MIN: float = 0.75
const UI_SCALE_MAX: float = 1.5
const UI_SCALE_STEP: float = 0.05
const UI_SCALE_DEFAULT: float = 1.0

const SAVE_PATH: String = "user://zorp_accessibility.json"
const FILTER_SHADER_PATH: String = "res://assets/shaders/color_filter.gdshader"
const COLORBLIND_SHADER_PATH: String = "res://assets/shaders/colorblind.gdshader"

# ── Runtime state ──
var _filter_rect: ColorRect = null
var _colorblind_rect: ColorRect = null
var _filter_shader: Shader = null
var _colorblind_shader: Shader = null

var _current_filter: int = ColorFilter.NONE
var _current_colorblind: int = ColorblindMode.NONE
var _filter_strength: float = 0.85  # Cosmetic filters can be slightly weaker
var _colorblind_strength: float = 1.0  # Correction filters at full strength
var _ui_scale: float = UI_SCALE_DEFAULT

# ── HUD reference (set by HUD on _ready) ──
# The HUD is a CanvasLayer; we scale each top-level Control child individually
# because CanvasLayer itself has no `scale` property. Controls with
# PRESET_FULL_RECT anchors (menus, overlays) are skipped — they should always
# fill the screen regardless of UI scale. Only fixed-offset HUD elements
# (HP bar, minimap, labels) get scaled.
var _hud_layer: CanvasLayer = null
var _scaled_controls: Array[Control] = []
# We record each scaled control's original offsets so we can re-apply them
# proportionally when the scale changes.
var _control_origins: Dictionary = {}  # Control -> Dictionary of offset_*

signal filter_changed(mode: int)
signal colorblind_mode_changed(mode: int)
signal ui_scale_changed(scale: float)


func _ready() -> void:
	layer = 60  # Above ShaderManager (50), below HUD (100)
	# Load shaders
	_filter_shader = load(FILTER_SHADER_PATH)
	_colorblind_shader = load(COLORBLIND_SHADER_PATH)
	if not _filter_shader:
		push_warning("[AccessibilityManager] Failed to load color_filter shader")
	if not _colorblind_shader:
		push_warning("[AccessibilityManager] Failed to load colorblind shader")

	# Create the two overlay rects
	_filter_rect = _create_overlay_rect()
	if _filter_shader:
		var mat := ShaderMaterial.new()
		mat.shader = _filter_shader
		mat.set_shader_parameter("strength", 0.0)
		mat.set_shader_parameter("mode", 0)
		_filter_rect.material = mat
	_filter_rect.visible = false
	add_child(_filter_rect)

	_colorblind_rect = _create_overlay_rect()
	if _colorblind_shader:
		var mat2 := ShaderMaterial.new()
		mat2.shader = _colorblind_shader
		mat2.set_shader_parameter("strength", 0.0)
		mat2.set_shader_parameter("mode", 0)
		_colorblind_rect.material = mat2
	_colorblind_rect.visible = false
	add_child(_colorblind_rect)

	# Load saved settings
	_load_settings()
	_apply_filter()
	_apply_colorblind()
	_apply_ui_scale()


func _create_overlay_rect() -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(1, 1, 1, 1)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


# ── In-game keyboard shortcuts ──
# F6 cycles color filters, F7 cycles colorblind modes, F8 increases UI scale,
# Shift+F8 decreases UI scale. These work in-game (not in menus) and provide
# quick access without opening the settings menu.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F6:
		var mode: int = cycle_filter()
		GameManager.add_message("🎨 Color Filter: " + FILTER_NAMES[mode])
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F7:
		var mode: int = cycle_colorblind_mode()
		GameManager.add_message("👁 Colorblind: " + COLORBLIND_NAMES[mode])
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F8:
		if event.shift_pressed:
			var s: float = decrease_ui_scale()
			GameManager.add_message("🔤 UI Scale: %.0f%%" % (s * 100.0))
		else:
			var s: float = increase_ui_scale()
			GameManager.add_message("🔤 UI Scale: %.0f%%" % (s * 100.0))
		get_viewport().set_input_as_handled()


# ── Color Filter API ──

func set_filter(mode: int) -> void:
	if mode < 0 or mode >= ColorFilter.size():
		return
	_current_filter = mode
	_apply_filter()
	_save_settings()
	filter_changed.emit(mode)

func get_filter() -> int:
	return _current_filter

func cycle_filter() -> int:
	var next := (_current_filter + 1) % ColorFilter.size()
	set_filter(next)
	return next


func _apply_filter() -> void:
	if not _filter_rect or not _filter_rect.material is ShaderMaterial:
		return
	var mat: ShaderMaterial = _filter_rect.material as ShaderMaterial
	mat.set_shader_parameter("mode", _current_filter)
	if _current_filter == ColorFilter.NONE:
		mat.set_shader_parameter("strength", 0.0)
		_filter_rect.visible = false
	else:
		mat.set_shader_parameter("strength", _filter_strength)
		_filter_rect.visible = true


# ── Colorblind Mode API ──

func set_colorblind_mode(mode: int) -> void:
	if mode < 0 or mode >= ColorblindMode.size():
		return
	_current_colorblind = mode
	_apply_colorblind()
	_save_settings()
	colorblind_mode_changed.emit(mode)

func get_colorblind_mode() -> int:
	return _current_colorblind

func cycle_colorblind_mode() -> int:
	var next := (_current_colorblind + 1) % ColorblindMode.size()
	set_colorblind_mode(next)
	return next


func _apply_colorblind() -> void:
	if not _colorblind_rect or not _colorblind_rect.material is ShaderMaterial:
		return
	var mat: ShaderMaterial = _colorblind_rect.material as ShaderMaterial
	mat.set_shader_parameter("mode", _current_colorblind)
	if _current_colorblind == ColorblindMode.NONE:
		mat.set_shader_parameter("strength", 0.0)
		_colorblind_rect.visible = false
	else:
		mat.set_shader_parameter("strength", _colorblind_strength)
		_colorblind_rect.visible = true


# ── UI Scaling API ──

## Called by the HUD to register itself for scaling.
func register_hud(hud: CanvasLayer) -> void:
	_hud_layer = hud
	_collect_scalable_controls()
	_apply_ui_scale()

## Collect top-level Control children of the HUD that use fixed offsets (not
## full-rect anchors). These are the HUD elements we want to scale. Full-screen
## overlays (menus, death screen, etc.) are left alone.
func _collect_scalable_controls() -> void:
	_scaled_controls.clear()
	_control_origins.clear()
	if not _hud_layer:
		return
	for child in _hud_layer.get_children():
		if not (child is Control):
			continue
		var ctrl: Control = child as Control
		# Skip full-rect controls (menus, overlays) — they fill the screen
		# and shouldn't be scaled.
		var anchors := ctrl.anchors_preset
		if anchors == Control.PRESET_FULL_RECT:
			continue
		# Skip invisible-by-default controls that are menus (heuristic: large area)
		# We include all non-full-rect controls; the scale is gentle enough that
		# even minimap/labels scale proportionally.
		_scaled_controls.append(ctrl)
		var entry := {
			"left": ctrl.offset_left,
			"top": ctrl.offset_top,
			"right": ctrl.offset_right,
			"bottom": ctrl.offset_bottom,
		}
		if ctrl is Label:
			entry["font_size"] = ctrl.get_theme_font_size("font_size")
		_control_origins[ctrl] = entry

func set_ui_scale(scale: float) -> void:
	scale = clampf(scale, UI_SCALE_MIN, UI_SCALE_MAX)
	if is_equal_approx(scale, _ui_scale):
		return
	_ui_scale = scale
	_apply_ui_scale()
	_save_settings()
	ui_scale_changed.emit(_ui_scale)

func get_ui_scale() -> float:
	return _ui_scale

func increase_ui_scale() -> float:
	set_ui_scale(_ui_scale + UI_SCALE_STEP)
	return _ui_scale

func decrease_ui_scale() -> float:
	set_ui_scale(_ui_scale - UI_SCALE_STEP)
	return _ui_scale


func _apply_ui_scale() -> void:
	if not _hud_layer:
		return
	# Scale each registered control's offsets from the origin (top-left or
	# bottom-right depending on anchor). We scale relative to the screen
	# center so elements don't drift off-screen. For bottom-right anchored
	# elements (minimap), we scale the negative offsets proportionally.
	for ctrl in _scaled_controls:
		if not is_instance_valid(ctrl):
			continue
		var orig: Dictionary = _control_origins.get(ctrl, {})
		if orig.is_empty():
			continue
		var preset: int = ctrl.anchors_preset
		var s: float = _ui_scale
		if preset == Control.PRESET_BOTTOM_RIGHT:
			# Minimap: offsets are negative (distance from right/bottom edge)
			ctrl.offset_left = float(orig["left"]) * s
			ctrl.offset_top = float(orig["top"]) * s
			ctrl.offset_right = float(orig["right"]) * s
			ctrl.offset_bottom = float(orig["bottom"]) * s
		else:
			# Top-left or center anchored: scale offsets from top-left
			ctrl.offset_left = float(orig["left"]) * s
			ctrl.offset_top = float(orig["top"]) * s
			ctrl.offset_right = float(orig["right"]) * s
			ctrl.offset_bottom = float(orig["bottom"]) * s
		# Scale font sizes for readability
		if ctrl is Label:
			var orig_font: int = int(orig.get("font_size", 16))
			ctrl.add_theme_font_size_override("font_size", int(round(orig_font * s)))
		ctrl.queue_redraw()


# ── Persistence ──

func _save_settings() -> void:
	var data := {
		"filter": _current_filter,
		"colorblind": _current_colorblind,
		"filter_strength": _filter_strength,
		"colorblind_strength": _colorblind_strength,
		"ui_scale": _ui_scale,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		f.close()

func _load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	_current_filter = int(data.get("filter", ColorFilter.NONE))
	_current_colorblind = int(data.get("colorblind", ColorblindMode.NONE))
	_filter_strength = float(data.get("filter_strength", 0.85))
	_colorblind_strength = float(data.get("colorblind_strength", 1.0))
	_ui_scale = float(data.get("ui_scale", UI_SCALE_DEFAULT))


# ── Reset (for completeness) ──
func reset_to_defaults() -> void:
	_current_filter = ColorFilter.NONE
	_current_colorblind = ColorblindMode.NONE
	_ui_scale = UI_SCALE_DEFAULT
	_apply_filter()
	_apply_colorblind()
	_apply_ui_scale()
	_save_settings()
	filter_changed.emit(_current_filter)
	colorblind_mode_changed.emit(_current_colorblind)
	ui_scale_changed.emit(_ui_scale)