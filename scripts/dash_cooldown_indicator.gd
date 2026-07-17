## Zorp Wiggles — Dash Cooldown Indicator (Phase 5: HUD Polish)
## A circular ring icon in the bottom-left HUD area that shows dash cooldown
## progress. Ring fills up as cooldown progresses; turns green when ready.
## Includes a small "⚡" lightning icon in the center.

extends Control

class_name DashCooldownIndicator

# ─── Internal State ───────────────────────────────────────────────────────────
var _cooldown_ratio: float = 0.0  # 0 = just used, 1 = ready
var _is_ready: bool = true
var _pulse_time: float = 0.0

# ─── Geometry ─────────────────────────────────────────────────────────────────
var _center: Vector2 = Vector2.ZERO
var _radius: float = GameConstants.DASH_COOLDOWN_RING_RADIUS

func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Position in bottom-left, above the HP bar area
	offset_left = 20
	offset_top = -80
	offset_right = 70
	offset_bottom = -30
	_center = Vector2(25, 25)  # Local center within the 50x50 control

func _process(delta: float) -> void:
	_pulse_time += delta
	# Calculate cooldown ratio
	var cd_timer: float = GameManager.player_dash_cooldown_timer
	var cd_max: float = GameConstants.PLAYER_DASH_COOLDOWN
	if cd_timer > 0:
		_cooldown_ratio = 1.0 - (cd_timer / cd_max)
		_is_ready = false
	else:
		_cooldown_ratio = 1.0
		_is_ready = true
	queue_redraw()

func _draw() -> void:
	# Draw background circle (dark)
	draw_circle(_center, _radius, Color(0.05, 0.05, 0.1, 0.7))

	# Draw the cooldown arc
	if _cooldown_ratio < 1.0:
		# Still charging — draw gray arc
		var color := GameConstants.DASH_COOLDOWN_CHARGING_COLOR
		_draw_arc(_center, _radius, _cooldown_ratio, color)
	else:
		# Ready — draw full green ring with pulse
		var pulse: float = 0.7 + 0.3 * sin(_pulse_time * 4.0)
		var color := Color(GameConstants.DASH_COOLDOWN_READY_COLOR.r,
			GameConstants.DASH_COOLDOWN_READY_COLOR.g,
			GameConstants.DASH_COOLDOWN_READY_COLOR.b,
			GameConstants.DASH_COOLDOWN_READY_COLOR.a * pulse)
		_draw_arc(_center, _radius, 1.0, color)

	# Draw outer ring border
	draw_arc(_center, _radius, 0, TAU, 32, Color(0.3, 0.4, 0.5, 0.6), 1.5)

	# Draw ⚡ icon in center
	var icon_color: Color
	if _is_ready:
		var pulse: float = 0.7 + 0.3 * sin(_pulse_time * 4.0)
		icon_color = Color(GameConstants.DASH_COOLDOWN_ICON_COLOR.r,
			GameConstants.DASH_COOLDOWN_ICON_COLOR.g,
			GameConstants.DASH_COOLDOWN_ICON_COLOR.b, pulse)
	else:
		icon_color = Color(0.4, 0.4, 0.4, 0.5)

	var font := get_theme_default_font()
	if font:
		var icon := "⚡"
		var icon_size: int = 20
		var ts := font.get_string_size(icon, HORIZONTAL_ALIGNMENT_LEFT, -1, icon_size)
		font.draw_string(get_canvas_item(),
			Vector2(_center.x - ts.x / 2.0, _center.y + ts.y / 2.0),
			icon, HORIZONTAL_ALIGNMENT_LEFT, -1, icon_size, icon_color)

	# Draw "SPACE" label below
	if font:
		var label := "SPACE"
		var label_size: int = 10
		var ts2 := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size)
		font.draw_string(get_canvas_item(),
			Vector2(_center.x - ts2.x / 2.0, _center.y + _radius + 12),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size,
			Color(0.5, 0.5, 0.6, 0.7))

func _draw_arc(center: Vector2, radius: float, fill_ratio: float, color: Color) -> void:
	# Draw a thick arc representing fill_ratio of the circle
	# Start from top (-PI/2) and go clockwise
	var segments: int = 32
	var angle_start: float = -PI / 2.0
	var angle_end: float = angle_start + TAU * fill_ratio

	# Draw as a series of connected lines (thick arc)
	var points := PackedVector2Array()
	var count: int = maxi(int(segments * fill_ratio), 1)
	for i in range(count + 1):
		var t: float = float(i) / float(count)
		var angle: float = lerpf(angle_start, angle_end, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	if points.size() >= 2:
		draw_polyline(points, color, GameConstants.DASH_COOLDOWN_RING_THICKNESS, false)