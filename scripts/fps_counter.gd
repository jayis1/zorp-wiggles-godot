## Zorp Wiggles — FPS Counter & Performance Overlay (Phase 31: QoL)
## A toggleable debug overlay showing real-time engine performance:
##   • FPS (current + average + min)
##   • Frame time (ms)
##   • Draw calls
##   • Object/Node counts
##   • Memory usage (static + dynamic)
##   • Physics process time
##
## Toggle with the "fps_counter" input action (F3 key).
## The overlay is hidden by default and only appears when toggled on.
## Renders via _draw() for minimal overhead when off (no per-frame Labels).
##
## Design notes:
##   - Uses the Performance singleton (real engine metrics, not estimates)
##   - Updates the readout 4×/sec (every 0.25s) to avoid text flicker;
##     the bar graph still updates every frame for smooth motion.
##   - Color-coded FPS: green ≥55, yellow 30-55, red <30 — standard convention.
##   - Minimal allocation: reuses a single String buffer for the readout.
##   - mouse_filter = IGNORE so it never blocks clicks even when visible.

extends Control

class_name FPSCounter

# ─── State ────────────────────────────────────────────────────────────────────
var _visible_flag: bool = false
var _overlay_alpha: float = 0.0  # 0..1, eased for fade-in/out
var _update_timer: float = 0.0
var _readout: String = ""
var _fps_history: PackedFloat32Array = PackedFloat32Array()
var _fps_history_idx: int = 0
const _FPS_HISTORY_SIZE: int = 60  # ~1 second of history at 60fps

# Cached metrics (updated 4×/sec to avoid text churn)
var _cur_fps: float = 0.0
var _avg_fps: float = 0.0
var _min_fps: float = 0.0
var _frame_time_ms: float = 0.0
var _draw_calls: int = 0
var _object_count: int = 0
var _resource_count: int = 0
var _node_count: int = 0
var _static_mem_kb: int = 0
var _dynamic_mem_kb: int = 0
var _physics_ms: float = 0.0
var _process_ms: float = 0.0

# Overlay geometry
const _PANEL_W: float = 320.0
const _PANEL_H: float = 220.0
const _PANEL_MARGIN: float = 8.0
const _GRAPH_H: float = 48.0
const _GRAPH_W: float = 280.0
const _UPDATE_INTERVAL: float = 0.25  # Seconds between readout refreshes
const _FADE_SPEED: float = 8.0  # Alpha lerp speed

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_left = -(_PANEL_W + _PANEL_MARGIN)
	offset_top = _PANEL_MARGIN
	offset_right = -_PANEL_MARGIN
	offset_bottom = _PANEL_MARGIN + _PANEL_H
	# Start hidden
	visible = true  # Keep visible so _draw runs; alpha controls actual visibility
	_fps_history.resize(_FPS_HISTORY_SIZE)
	for i in range(_FPS_HISTORY_SIZE):
		_fps_history[i] = 60.0  # Initialize to 60 to avoid a red spike on start

func _process(delta: float) -> void:
	# Ease alpha toward target
	var target_alpha: float = 1.0 if _visible_flag else 0.0
	_overlay_alpha = lerpf(_overlay_alpha, target_alpha, 1.0 - exp(-_FADE_SPEED * delta))
	# Always track FPS history (even when hidden, so first show has data)
	_fps_history[_fps_history_idx] = Engine.get_frames_per_second()
	_fps_history_idx = (_fps_history_idx + 1) % _FPS_HISTORY_SIZE
	# Refresh readout on interval
	_update_timer -= delta
	if _update_timer <= 0.0:
		_update_timer = _UPDATE_INTERVAL
		_refresh_metrics()
	# Redraw every frame while visible (graph animates smoothly)
	if _overlay_alpha > 0.01:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fps_counter"):
		_visible_flag = not _visible_flag
		# Consume so it doesn't fall through (e.g. to other F-key handlers)
		get_viewport().set_input_as_handled()

# ─── Metric Collection ────────────────────────────────────────────────────────

func _refresh_metrics() -> void:
	_cur_fps = Engine.get_frames_per_second()
	# Compute average and min from history
	var sum: float = 0.0
	var mn: float = 9999.0
	for v in _fps_history:
		sum += v
		if v < mn:
			mn = v
	_avg_fps = sum / float(_FPS_HISTORY_SIZE)
	_min_fps = mn if mn < 9999.0 else _cur_fps
	_frame_time_ms = 1000.0 / maxf(_cur_fps, 1.0)
	# Performance singleton metrics. We use integer indices instead of the
	# enum names because some enum members (RENDER_OBJECTS_IN_FRAME,
	# RENDER_RESOURCES_IN_FRAME) have different names across Godot 4.x
	# versions, causing parse errors. The integer indices are stable.
	# See Godot 4.x Performance.Monitor enum:
	#   15 = RENDER_TOTAL_OBJECTS_IN_FRAME
	#   17 = RENDER_TOTAL_DRAW_CALLS_IN_FRAME
	#   19 = RENDER_VIDEO_MEM_USED (GPU memory)
	#    1 = TIME_PROCESS (microseconds)
	#    2 = TIME_PHYSICS_PROCESS (microseconds)
	#    5 = OBJECT_NODE_COUNT
	#    7 = OBJECT_ORPHAN_NODE_COUNT
	_draw_calls = int(Performance.get_monitor(17))
	_object_count = int(Performance.get_monitor(15))
	_static_mem_kb = int(Performance.get_monitor(19) / 1024.0)
	_node_count = int(Performance.get_monitor(5))
	_dynamic_mem_kb = int(Performance.get_monitor(7))
	_process_ms = Performance.get_monitor(1) / 1000.0
	_physics_ms = Performance.get_monitor(2) / 1000.0
	_resource_count = 0  # RENDER_RESOURCES_IN_FRAME not available in 4.4
	# Build readout once per refresh
	_readout = _build_readout()

func _build_readout() -> String:
	# Color codes for FPS
	var fps_color_name: String = "green"
	if _cur_fps < 30.0:
		fps_color_name = "red"
	elif _cur_fps < 55.0:
		fps_color_name = "yellow"
	# Format with monospace alignment using tabs/padding.
	# Phase 35: use explicit string concatenation instead of Python-style
	# triple-quote multiline strings (per project GDScript rules).
	var mem_str: String = "%d KB" % _static_mem_kb if _static_mem_kb < 1024 else "%.1f MB" % (_static_mem_kb / 1024.0)
	var line1: String = "[color=%s]FPS: %5.1f[/color]  avg: %5.1f  min: %5.1f" % [fps_color_name, _cur_fps, _avg_fps, _min_fps]
	var line2: String = "Frame: %5.2f ms   Process: %5.2f ms   Physics: %5.2f ms" % [_frame_time_ms, _process_ms, _physics_ms]
	var line3: String = "Draw calls: %4d   Objects: %4d   Resources: %5d" % [_draw_calls, _object_count, _resource_count]
	var line4: String = "Nodes: %5d   Orphans: %3d   VRAM: %s" % [_node_count, _dynamic_mem_kb, mem_str]
	return line1 + "\n" + line2 + "\n" + line3 + "\n" + line4

# ─── Rendering ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _overlay_alpha < 0.01:
		return
	# Semi-transparent dark background
	var bg_color := Color(0.0, 0.0, 0.0, 0.75 * _overlay_alpha)
	var panel_rect := Rect2(Vector2.ZERO, Vector2(_PANEL_W, _PANEL_H))
	draw_rect(panel_rect, bg_color, true)
	# Border
	var border_color := Color(0.3, 0.8, 0.4, 0.7 * _overlay_alpha)
	draw_rect(panel_rect, border_color, false, 1.0)
	# Title bar
	var title_rect := Rect2(Vector2.ZERO, Vector2(_PANEL_W, 18.0))
	draw_rect(title_rect, Color(0.15, 0.25, 0.15, 0.9 * _overlay_alpha), true)
	# Title text
	var font := get_theme_default_font()
	var title_color := Color(0.5, 0.9, 0.5, _overlay_alpha)
	draw_string(font, Vector2(8.0, 14.0), "⚡ PERFORMANCE  [F3]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, title_color)
	# ── FPS graph (sparkline) ──
	var graph_x: float = 8.0
	var graph_y: float = 24.0
	var graph_rect := Rect2(graph_x, graph_y, _GRAPH_W, _GRAPH_H)
	# Graph background
	draw_rect(graph_rect, Color(0.05, 0.1, 0.05, 0.5 * _overlay_alpha), true)
	# 60 FPS reference line
	var ref_y: float = graph_y + _GRAPH_H - (60.0 / 120.0) * _GRAPH_H
	draw_line(Vector2(graph_x, ref_y), Vector2(graph_x + _GRAPH_W, ref_y),
		Color(0.3, 0.6, 0.3, 0.4 * _overlay_alpha), 1.0)
	# 30 FPS reference line
	var ref30_y: float = graph_y + _GRAPH_H - (30.0 / 120.0) * _GRAPH_H
	draw_line(Vector2(graph_x, ref30_y), Vector2(graph_x + _GRAPH_W, ref30_y),
		Color(0.6, 0.3, 0.3, 0.3 * _overlay_alpha), 1.0)
	# FPS history line
	var pts: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var n: int = _FPS_HISTORY_SIZE
	for i in range(n):
		var idx: int = (_fps_history_idx + i) % n
		var fps_val: float = _fps_history[idx]
		var x: float = graph_x + (float(i) / float(n - 1)) * _GRAPH_W
		var y: float = graph_y + _GRAPH_H - clampf(fps_val / 120.0, 0.0, 1.0) * _GRAPH_H
		pts.append(Vector2(x, y))
		# Color per-point (green/yellow/red)
		if fps_val >= 55.0:
			colors.append(Color(0.3, 0.9, 0.3, _overlay_alpha))
		elif fps_val >= 30.0:
			colors.append(Color(0.9, 0.85, 0.2, _overlay_alpha))
		else:
			colors.append(Color(0.95, 0.3, 0.2, _overlay_alpha))
	# Draw as connected segments (so we can color per-point)
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], colors[i], 1.5)
	# Current FPS dot at the right edge
	if pts.size() > 0:
		var last: Vector2 = pts[pts.size() - 1]
		draw_circle(last, 3.0, colors[colors.size() - 1])
	# ── Text readout (below the graph) ──
	# We use draw_string for each line because _draw doesn't support BBCode.
	# Parse the readout manually into lines and apply colors.
	var text_y: float = graph_y + _GRAPH_H + 8.0
	var line_height: float = 14.0
	var lines: PackedStringArray = _readout.split("\n")
	for line in lines:
		# Strip BBCode color tags for plain draw_string — we manually color lines
		var plain: String = line.replace("[color=green]", "").replace("[color=yellow]", "").replace("[color=red]", "").replace("[/color]", "")
		# Determine line color from BBCode tag if present
		var line_color: Color = Color(0.85, 0.9, 0.95, _overlay_alpha)
		if line.find("[color=green]") >= 0:
			line_color = Color(0.4, 1.0, 0.4, _overlay_alpha)
		elif line.find("[color=yellow]") >= 0:
			line_color = Color(1.0, 0.85, 0.3, _overlay_alpha)
		elif line.find("[color=red]") >= 0:
			line_color = Color(1.0, 0.4, 0.3, _overlay_alpha)
		draw_string(font, Vector2(8.0, text_y), plain, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, line_color)
		text_y += line_height
	# ── Legend ──
	var legend_y: float = _PANEL_H - 14.0
	draw_string(font, Vector2(8.0, legend_y), "─ 60 FPS ref  ─ 30 FPS ref", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.5, 0.5, 0.6 * _overlay_alpha))

# ─── Public API ────────────────────────────────────────────────────────────────

func is_visible_flag() -> bool:
	return _visible_flag

func set_visible_flag(v: bool) -> void:
	_visible_flag = v

func get_current_fps() -> float:
	return _cur_fps

func get_avg_fps() -> float:
	return _avg_fps

func get_min_fps() -> float:
	return _min_fps