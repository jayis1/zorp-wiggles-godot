## Zorp Wiggles — Damage Direction Indicator (Phase 5: HUD Polish)
## Shows red arrows around the screen center pointing toward the source of
## incoming damage. Arrows fade out over DAMAGE_INDICATOR_DURATION seconds.
## Inspired by the damage direction system in Ursina game.py.
##
## Multi-indicator: supports up to MAX_INDICATORS simultaneous arrows so the
## player can read damage from multiple directions at once (e.g. surrounded by
## enemies, hit from two sides on the same frame). Previously only a single
## arrow existed — a second hit would overwrite the first, making the player
## think all damage came from the latest direction. Each arrow tracks its own
## angle, lifetime, alpha, and punch-in scale, and fades out independently.

extends Control

class_name DamageDirectionIndicator

# ─── Per-indicator state ──────────────────────────────────────────────────────
# A small pool of indicators. Each entry is a Dictionary with angle, timer,
# alpha, scale_pop, and pop_elapsed. We reuse slots so we don't allocate per
# hit. The pool is small (6) — more than that would clutter the screen and
# overwhelm the player. When the pool is full, the oldest indicator is
# replaced by the newest so the freshest direction always shows.
const MAX_INDICATORS: int = 6
var _indicators: Array[Dictionary] = []

# ── Punch-in scale ── Each arrow pops in from 1.6x scale and eases down to
#    1.0x over the first ~120ms of its life, giving the indicator an
#    urgent "stab" feel rather than a flat fade. The scale envelope is a
#    decaying exponential so it punches in on the hit frame and settles
#    smoothly. Driven in _process and applied in _draw.
const SCALE_POP_PEAK: float = 1.6
const SCALE_POP_DURATION: float = 0.12

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true

	# Connect to GameManager's damage signal
	GameManager.damage_taken_from.connect(_on_damage_taken_from)

func _on_damage_taken_from(source_pos: Vector3) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
	# Calculate angle from player to damage source (in XZ plane)
	var dx: float = source_pos.x - player.global_position.x
	var dz: float = source_pos.z - player.global_position.z
	# atan2(dx, -dz) gives angle with 0 = source directly ahead (-Z)
	var angle: float = atan2(dx, -dz)
	# ── Angle refresh ── If there's already an indicator pointing in nearly
	#    the same direction (within ANGLE_REFRESH_THRESHOLD radians ≈ 30°),
	#    refresh it instead of creating a new one. This makes repeated hits
	#    from the same enemy read as escalating danger — the arrow re-punches
	#    its scale pop and resets its lifetime, so the indicator grows more
	#    urgent with each successive hit rather than being silently replaced
	#    by an identical arrow. Without this, fighting a single enemy that
	#    hits you 3× in a row would create and discard 3 arrows at the same
	#    angle, each starting from full scale-pop — it reads as flickering
	#    rather than escalating. With refresh, the arrow pulses with each
	#    hit, communicating "this direction is still a threat."
	const ANGLE_REFRESH_THRESHOLD: float = 0.52  # ~30 degrees
	for i in range(_indicators.size()):
		var existing_angle: float = _indicators[i]["angle"]
		# Compute the shortest angular delta (handles wrap-around)
		var angle_diff: float = absf(angle_difference(existing_angle, angle))
		if angle_diff < ANGLE_REFRESH_THRESHOLD:
			# Refresh: reset timer, re-punch scale, update angle to the
			# latest hit's exact direction (in case the enemy moved slightly)
			_indicators[i]["timer"] = GameConstants.DAMAGE_INDICATOR_DURATION
			_indicators[i]["alpha"] = GameConstants.DAMAGE_INDICATOR_MAX_ALPHA
			_indicators[i]["scale_pop"] = SCALE_POP_PEAK
			_indicators[i]["pop_elapsed"] = 0.0
			_indicators[i]["angle"] = angle
			return
	# No matching indicator — add a new one. If the pool is full, replace the
	# oldest (smallest timer) so the freshest direction is always visible.
	var indicator := {
		"angle": angle,
		"timer": GameConstants.DAMAGE_INDICATOR_DURATION,
		"alpha": GameConstants.DAMAGE_INDICATOR_MAX_ALPHA,
		"scale_pop": SCALE_POP_PEAK,
		"pop_elapsed": 0.0,
	}
	if _indicators.size() < MAX_INDICATORS:
		_indicators.append(indicator)
	else:
		# Replace the one with the least remaining time (about to expire)
		var oldest_idx: int = 0
		var oldest_timer: float = _indicators[0]["timer"]
		for i in range(1, _indicators.size()):
			if _indicators[i]["timer"] < oldest_timer:
				oldest_timer = _indicators[i]["timer"]
				oldest_idx = i
		_indicators[oldest_idx] = indicator

func _process(delta: float) -> void:
	if _indicators.is_empty():
		return

	var needs_redraw: bool = false
	for i in range(_indicators.size() - 1, -1, -1):
		var ind: Dictionary = _indicators[i]
		ind["timer"] = ind["timer"] - delta
		if ind["timer"] <= 0.0:
			_indicators.remove_at(i)
			needs_redraw = true
			continue
		# Fade out over duration. Uses ease-in cubic (life_frac³) so the arrow
		# holds near-full opacity for most of its life, then drops off sharply
		# at the end — the standard indicator drain that matches the game's
		# eased fade language (boss bar flash, message fade, etc.). A linear
		# fade makes the arrow visibly dim from the moment it appears, which
		# reads as "fading" too early; the cubic keeps it punchy and readable,
		# then snaps out of view.
		var life_frac: float = ind["timer"] / GameConstants.DAMAGE_INDICATOR_DURATION
		life_frac = clampf(life_frac, 0.0, 1.0)
		var eased_alpha: float = life_frac * life_frac * life_frac  # ease-in cubic
		ind["alpha"] = eased_alpha * GameConstants.DAMAGE_INDICATOR_MAX_ALPHA
		# ── Scale pop decay ── Ease the scale from the peak back to 1.0
		# over SCALE_POP_DURATION. Uses ease-out cubic so the pop is sharp
		# on the hit frame and settles gently.
		ind["pop_elapsed"] = ind["pop_elapsed"] + delta
		if ind["pop_elapsed"] < SCALE_POP_DURATION:
			var pop_t: float = clampf(ind["pop_elapsed"] / SCALE_POP_DURATION, 0.0, 1.0)
			var eased: float = 1.0 - pow(1.0 - pop_t, 3.0)
			ind["scale_pop"] = lerpf(SCALE_POP_PEAK, 1.0, eased)
		else:
			ind["scale_pop"] = 1.0
		needs_redraw = true

	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	if _indicators.is_empty():
		return

	var center := size / 2.0
	var dist := GameConstants.DAMAGE_INDICATOR_DISTANCE

	for ind in _indicators:
		var angle: float = ind["angle"]
		var alpha: float = ind["alpha"]
		if alpha < 0.01:
			continue
		var scale_pop: float = ind["scale_pop"]

		# Arrow position: offset from center in direction of angle
		var ax: float = center.x + sin(angle) * dist
		var ay: float = center.y - cos(angle) * dist

		var color := Color(GameConstants.DAMAGE_INDICATOR_COLOR.r,
			GameConstants.DAMAGE_INDICATOR_COLOR.g,
			GameConstants.DAMAGE_INDICATOR_COLOR.b,
			alpha)

		# Draw a triangular arrow pointing outward from center.
		var arrow_size: float = 14.0 * scale_pop
		var dir := Vector2(sin(angle), -cos(angle)).normalized()
		var perp := Vector2(dir.y, -dir.x)

		# Triangle vertices: tip at (ax, ay), base behind
		var tip := Vector2(ax, ay)
		var base_center := Vector2(ax - dir.x * arrow_size, ay - dir.y * arrow_size)
		var base_left := base_center + perp * arrow_size * 0.6
		var base_right := base_center - perp * arrow_size * 0.6

		# Draw filled triangle
		var points := PackedVector2Array([tip, base_left, base_right])
		draw_colored_polygon(points, color)

		# Draw a subtle outline
		draw_polyline(points, Color(color.r, color.g, color.b, alpha * 0.5), 1.0, true)