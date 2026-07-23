## Zorp Wiggles — Player Damage Flash (Phase 6: Particle Effects & Juice)
## Red model flash + screen vignette when the player takes damage.
## Attaches to the HUD as a full-screen ColorRect overlay that flashes red on damage.

extends Control

class_name DamageFlash

# ─── Internal State ───────────────────────────────────────────────────────────
var _flash_alpha: float = 0.0
var _flash_color: Color = Color(1.0, 0.1, 0.1, 0.0)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Connect to damage signal
	GameManager.damage_taken_from.connect(_on_damage_taken)

func _on_damage_taken(_source_pos: Vector3) -> void:
	# Flash red on damage — intensity scales with how low HP is so a hit
	# at critical HP feels more urgent than a hit at full HP. The vignette
	# at full HP is 0.4 (a gentle red pulse); at <25% HP it reaches 0.7
	# (a strong crimson wash) so the player viscerally feels the danger.
	var hp_ratio: float = 1.0
	if GameManager.player_max_hp > 0:
		hp_ratio = float(GameManager.player_hp) / float(GameManager.player_max_hp)
	# Quadratic ramp: starts gentle, intensifies sharply as HP drops
	var danger_factor: float = clampf(1.0 - hp_ratio, 0.0, 1.0)
	danger_factor = danger_factor * danger_factor  # ease-in quadratic
	_flash_alpha = 0.4 + danger_factor * 0.3  # 0.4 at full → 0.7 at empty

func _process(delta: float) -> void:
	if _flash_alpha > 0.01:
		# Frame-rate-independent exponential decay (matches the pattern used
		# everywhere else in the codebase: weight = 1 - exp(-rate * delta)).
		# The previous `lerpf(a, 0, 6*delta)` was frame-rate-dependent — at
		# 30 FPS it decayed at 0.2/frame, at 144 FPS at 0.042/frame, so the
		# flash lasted ~2.3× longer on a 30 FPS display than on a 144 FPS
		# one. The exponential form gives identical perceived decay time
		# regardless of refresh rate. Rate 6.0 ≈ ~95% gone in 0.5s.
		_flash_alpha = lerpf(_flash_alpha, 0.0, 1.0 - exp(-6.0 * delta))
		queue_redraw()
	elif _flash_alpha != 0.0:
		_flash_alpha = 0.0
		queue_redraw()

func _draw() -> void:
	if _flash_alpha < 0.01:
		return

	# Draw a red vignette around the screen edges
	var screen_size := size
	var center := screen_size / 2.0
	var max_dim: float = max(screen_size.x, screen_size.y)

	# Concentric rectangles fading from edge to center
	var layers: int = 6
	for i in range(layers):
		var frac: float = float(i) / float(layers)
		var inset: float = frac * max_dim * 0.3
		var rect := Rect2(inset, inset, screen_size.x - inset * 2, screen_size.y - inset * 2)
		var layer_alpha: float = _flash_alpha * (1.0 - frac) * 0.6
		var c := Color(_flash_color.r, _flash_color.g, _flash_color.b, layer_alpha)
		draw_rect(rect, c, false, max_dim * 0.03)

	# Full-screen tint at low alpha
	var tint := Color(_flash_color.r, _flash_color.g, _flash_color.b, _flash_alpha * 0.08)
	draw_rect(Rect2(Vector2.ZERO, screen_size), tint, true)