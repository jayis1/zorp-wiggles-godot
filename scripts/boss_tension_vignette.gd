## Zorp Wiggles — Boss Tension Vignette (Phase 5: HUD Polish)
## A pulsing red screen-edge vignette that appears when a boss is active and
## nearby. Intensity scales with proximity to the boss. Subtle at far range,
## intense and fast-pulsing when close.

extends Control

class_name BossTensionVignette

# ─── Internal State ───────────────────────────────────────────────────────────
var _vignette_color: Color = Color(0, 0, 0, 0)
var _pulse_time: float = 0.0
var _has_boss: bool = false
var _boss_ref: Node3D = null
# Cached player reference — avoids per-frame group scan in _process.
var _cached_player: Node3D = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_color = GameConstants.BOSS_VIGNETTE_COLOR
	# Connect to boss signals
	GameManager.boss_spawned.connect(_on_boss_spawned)
	GameManager.boss_defeated.connect(_on_boss_defeated)

func _on_boss_spawned(boss: Node) -> void:
	_has_boss = true
	_boss_ref = boss as Node3D

func _on_boss_defeated(_boss: Node) -> void:
	_has_boss = false
	_boss_ref = null

# Lazily cache the player node — only re-scan when the cache is stale.
func _get_player() -> Node3D:
	if _cached_player and is_instance_valid(_cached_player):
		return _cached_player
	_cached_player = get_tree().get_first_node_in_group("player")
	return _cached_player

func _process(delta: float) -> void:
	_pulse_time += delta

	if not _has_boss or not _boss_ref or not is_instance_valid(_boss_ref):
		# Fade out (frame-rate-independent exponential decay)
		if _vignette_color.a > 0.01:
			_vignette_color.a = lerpf(_vignette_color.a, 0.0, 1.0 - exp(-5.0 * delta))
			queue_redraw()
		return

	var player: Node3D = _get_player()
	if not player:
		return

	# Calculate proximity to boss (0 = far, 1 = close)
	var dist: float = player.global_position.distance_to(_boss_ref.global_position)
	var proximity: float = 1.0 - clampf(dist / GameConstants.BOSS_VIGNETTE_PROXIMITY_RANGE, 0.0, 1.0)

	# Pulse intensity
	var pulse: float = 0.5 + 0.5 * sin(_pulse_time * GameConstants.BOSS_VIGNETTE_PULSE_SPEED)
	var base_alpha: float = lerpf(GameConstants.BOSS_VIGNETTE_BASE_ALPHA,
		GameConstants.BOSS_VIGNETTE_MAX_ALPHA, proximity)
	var target_alpha: float = base_alpha * (0.5 + pulse * 0.5 * proximity)

	# Frame-rate-independent exponential approach
	_vignette_color.a = lerpf(_vignette_color.a, target_alpha, 1.0 - exp(-4.0 * delta))
	queue_redraw()

func _draw() -> void:
	if _vignette_color.a < 0.01:
		return

	# Draw a vignette: full-screen rect with radial gradient (simulated with
	# multiple concentric rect outlines fading from edge to center).
	# ── Smoothstep falloff ── Previously used 8 layers with linear alpha
	#    falloff (1.0 - frac), which created a blocky, stepped appearance —
	#    the discrete layers were visible as bands rather than a smooth
	#    gradient. Now we use 16 layers with a smoothstep alpha curve
	#    (t² * (3-2t)) so the vignette fades organically from edge to
	#    center, reading as a proper radial gradient rather than nested
	#    rectangles. The doubled layer count + smoothstep eliminates the
	#    visible banding, giving the danger vignette a cinematic quality.
	var screen_size := size
	var center := screen_size / 2.0
	var max_dim: float = max(screen_size.x, screen_size.y)

	# Draw concentric rectangles from outside in, fading alpha
	var layers: int = 16
	for i in range(layers):
		var frac: float = float(i) / float(layers)
		# Smoothstep: t² * (3-2t) — smooth S-curve instead of linear
		var smooth: float = frac * frac * (3.0 - 2.0 * frac)
		var inset: float = smooth * max_dim * 0.28
		var rect := Rect2(inset, inset, screen_size.x - inset * 2, screen_size.y - inset * 2)
		# Alpha falls off with smoothstep so layers blend seamlessly
		var layer_alpha: float = _vignette_color.a * (1.0 - smooth)
		var c := Color(_vignette_color.r, _vignette_color.g, _vignette_color.b, layer_alpha)
		draw_rect(rect, c, false, max_dim * 0.025)

	# Also draw a soft full-screen tint at very low alpha
	var tint := Color(_vignette_color.r, _vignette_color.g, _vignette_color.b, _vignette_color.a * 0.15)
	draw_rect(Rect2(Vector2.ZERO, screen_size), tint, true)