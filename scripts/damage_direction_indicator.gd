## Zorp Wiggles — Damage Direction Indicator (Phase 5: HUD Polish)
## Shows red arrows around the screen center pointing toward the source of
## incoming damage. Arrows fade out over DAMAGE_INDICATOR_DURATION seconds.
## Inspired by the damage direction system in Ursina game.py.

extends Control

class_name DamageDirectionIndicator

# ─── Active Indicator ─────────────────────────────────────────────────────────
var _angle: float = 0.0       # Radians, 0 = up
var _timer: float = 0.0       # Remaining lifetime
var _alpha: float = 0.0       # Current alpha
# ── Punch-in scale ── The arrow now pops in from 1.6x scale and eases down
#    to 1.0x over the first ~120ms of its life, giving the indicator a
#    urgent "stab" feel rather than a flat fade. The scale envelope is a
#    decaying exponential so it punches in on the hit frame and settles
#    smoothly. Driven in _process and applied in _draw.
var _scale_pop: float = 1.0  # Current draw scale (1.0 = resting)
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
	# atan2(x, z) gives 0 when source is directly "north" (+Z forward)
	# We want 0 = source is "up" on screen (away from camera, -Z in Godot)
	# Camera looks down -Z, so "up" on screen = -Z direction
	# atan2(dx, -dz) gives angle with 0 = source directly ahead (-Z)
	_angle = atan2(dx, -dz)
	_timer = GameConstants.DAMAGE_INDICATOR_DURATION
	_alpha = GameConstants.DAMAGE_INDICATOR_MAX_ALPHA
	# Trigger the punch-in scale pop on each new hit
	_scale_pop = SCALE_POP_PEAK

func _process(delta: float) -> void:
	if _timer > 0:
		_timer -= delta
		# Fade out over duration
		var life_frac: float = _timer / GameConstants.DAMAGE_INDICATOR_DURATION
		life_frac = clampf(life_frac, 0.0, 1.0)
		_alpha = life_frac * GameConstants.DAMAGE_INDICATOR_MAX_ALPHA
		# ── Scale pop decay ── Ease the scale from the peak back to 1.0
		# over SCALE_POP_DURATION. Uses ease-out cubic so the pop is sharp
		# on the hit frame and settles gently. Only active during the pop
		# window (first 120ms); after that the scale stays at 1.0.
		var pop_elapsed: float = GameConstants.DAMAGE_INDICATOR_DURATION - _timer
		if pop_elapsed < SCALE_POP_DURATION:
			var pop_t: float = clampf(pop_elapsed / SCALE_POP_DURATION, 0.0, 1.0)
			# Ease-out cubic: 1 - (1-t)^3 — sharp onset, gentle landing
			var eased: float = 1.0 - pow(1.0 - pop_t, 3.0)
			_scale_pop = lerpf(SCALE_POP_PEAK, 1.0, eased)
		else:
			_scale_pop = 1.0
		queue_redraw()
	elif _alpha > 0.01:
		_alpha = 0.0
		_scale_pop = 1.0
		queue_redraw()

func _draw() -> void:
	if _alpha < 0.01:
		return

	var center := size / 2.0
	var dist := GameConstants.DAMAGE_INDICATOR_DISTANCE
	# Arrow position: offset from center in direction of _angle
	# _angle = 0 means up (0, -dist), pi/2 means right (dist, 0)
	var ax: float = center.x + sin(_angle) * dist
	var ay: float = center.y - cos(_angle) * dist

	var color := Color(GameConstants.DAMAGE_INDICATOR_COLOR.r,
		GameConstants.DAMAGE_INDICATOR_COLOR.g,
		GameConstants.DAMAGE_INDICATOR_COLOR.b,
		_alpha)

	# Draw a triangular arrow pointing outward from center.
	# The arrow_size scales with _scale_pop so the arrow punches in large
	# on the hit frame and eases down to its resting size. This gives the
	# indicator an urgent "stab" feel that grabs the player's attention.
	var arrow_size: float = 14.0 * _scale_pop
	# Direction vector from center to arrow
	var dir := Vector2(sin(_angle), -cos(_angle)).normalized()
	# Perpendicular vector
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
	draw_polyline(points, Color(color.r, color.g, color.b, _alpha * 0.5), 1.0, true)