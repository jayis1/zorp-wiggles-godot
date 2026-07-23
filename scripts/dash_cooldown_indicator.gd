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

# ── Dash cooldown ready feedback ── When the dash transitions from "charging"
#    to "ready", we fire a one-shot audio chime + a brief ring scale pop so the
#    player *feels* the cooldown complete without staring at the icon. The edge
#    detector (_was_ready) ensures the chime only fires once per cycle — it
#    resets to false while charging and flips true on the first ready frame.
var _was_ready: bool = true  # Start true so the initial game state doesn't chime
var _ready_ping_tween: Tween = null  # Tracked so rapid re-readies don't stack
var _ready_ring_scale: float = 1.0  # Extra scale for the ready ping pop

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
		_was_ready = false  # Reset edge detector while charging
	else:
		_cooldown_ratio = 1.0
		_is_ready = true
		# ── Ready edge detection ── Fire the ready chime + ring pop only on the
		# first frame the cooldown completes, not every frame while idle. The
		# _was_ready flag is reset to false during charging, so the transition
		# from charging → ready is a clean single-fire edge. Skip the initial
		# game start (_was_ready starts true so there's no phantom chime).
		if not _was_ready:
			_was_ready = true
			# Audio: bright two-note "ding" chime
			AudioManager.play_sfx(AudioManager.SFX_DASH_READY)
			# Visual: brief ring scale pop from 1.0 → 1.35 → 1.0 with ease-out
			# back so the ring briefly overshoots and settles, drawing the eye
			# to the now-ready icon. Tracked tween so rapid re-readies kill
			# any in-progress pop cleanly.
			if _ready_ping_tween and _ready_ping_tween.is_valid():
				_ready_ping_tween.kill()
			_ready_ring_scale = 1.35
			_ready_ping_tween = create_tween()
			_ready_ping_tween.tween_property(self, "_ready_ring_scale", 1.0, 0.25) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Ease the ready ring scale toward 1.0 (the tween handles the main pop,
	# but we also have a gentle frame-rate-independent safety net so the
	# scale never gets stuck if the tween is killed early).
	_ready_ring_scale = lerpf(_ready_ring_scale, 1.0, 1.0 - exp(-10.0 * delta))
	queue_redraw()

func _draw() -> void:
	# Draw background circle (dark)
	draw_circle(_center, _radius, Color(0.05, 0.05, 0.1, 0.7))

	# Pre-declare shared variables (GDScript has function-level scoping)
	var icon_color: Color
	var font := get_theme_default_font()

	# Draw the cooldown arc
	if _cooldown_ratio < 1.0:
		# Still charging — draw gray arc
		var color := GameConstants.DASH_COOLDOWN_CHARGING_COLOR
		_draw_arc(_center, _radius, _cooldown_ratio, color)
		# Draw outer ring border (charging path)
		draw_arc(_center, _radius, 0, TAU, 32, Color(0.3, 0.4, 0.5, 0.6), 1.5)
		# Dimmed icon (charging)
		icon_color = Color(0.4, 0.4, 0.4, 0.5)
	else:
		# Ready — draw full green ring with pulse.
		# The ring scale is boosted by _ready_ring_scale on the first ready
		# frame for a "pop" effect that settles back to 1.0. This is the
		# visual counterpart to the ready chime — the ring briefly overshoots
		# its resting size and bounces back, drawing the eye to the icon.
		var pulse: float = 0.7 + 0.3 * sin(_pulse_time * 4.0)
		var ready_color := Color(GameConstants.DASH_COOLDOWN_READY_COLOR.r,
			GameConstants.DASH_COOLDOWN_READY_COLOR.g,
			GameConstants.DASH_COOLDOWN_READY_COLOR.b,
			GameConstants.DASH_COOLDOWN_READY_COLOR.a * pulse)
		var ready_r: float = _radius * _ready_ring_scale
		_draw_arc(_center, ready_r, 1.0, ready_color)
		# Outer border also scales with the pop
		draw_arc(_center, ready_r, 0, TAU, 32, Color(0.3, 0.4, 0.5, 0.6), 1.5)
		# Bright pulsing icon (ready)
		var icon_pulse: float = 0.7 + 0.3 * sin(_pulse_time * 4.0)
		icon_color = Color(GameConstants.DASH_COOLDOWN_ICON_COLOR.r,
			GameConstants.DASH_COOLDOWN_ICON_COLOR.g,
			GameConstants.DASH_COOLDOWN_ICON_COLOR.b, icon_pulse)

	# Draw ⚡ icon in center (shared by both paths)
	if font:
		var icon := "⚡"
		var icon_size: int = 20
		var ts := font.get_string_size(icon, HORIZONTAL_ALIGNMENT_LEFT, -1, icon_size)
		font.draw_string(get_canvas_item(),
			Vector2(_center.x - ts.x / 2.0, _center.y + ts.y / 2.0),
			icon, HORIZONTAL_ALIGNMENT_LEFT, -1, icon_size, icon_color)

		# Draw "SPACE" label below
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