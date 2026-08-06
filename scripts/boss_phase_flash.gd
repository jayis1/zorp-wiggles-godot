## Zorp Wiggles — Boss Phase Transition Screen-Edge Flash
## Enhancement Pack 38: A brief colored screen-edge glow that flashes when a
## boss enters a new phase (e.g. Drake enrage, Void Leviathan stage 2/3,
## Ancient Sentinel enrage). The flash color matches the boss's phase color
## (red-orange for Drake, purple for Void, crystal-blue for Sentinel) so the
## player gets a visual cue of the phase shift even if they're not looking at
## the boss's model. The flash is a vignette-style overlay — bright at the
## screen edges, transparent in the center — that fades in quickly (0.05s)
## and fades out over 0.35s.
##
## The flash is triggered via GameManager.boss_phase_changed(color: Color),
## which boss scripts emit on phase transitions. A cooldown of 0.3s prevents
## rapid phase changes (e.g. Ancient Sentinel's enrage overlapping with phase
## cycle) from stacking the flash into a persistent glow.
##
## The vignette is drawn via _draw() (matching DamageFlash's pattern) using
## concentric rectangles fading from edge to center, so it's GPU-cheap — no
## shader material, no per-frame ColorRect property writes.

extends Control

# ── State ────────────────────────────────────────────────────────────────────
var _flash_alpha: float = 0.0
var _flash_color: Color = Color(1.0, 0.3, 0.1, 0.0)
var _cooldown: float = 0.0
const COOLDOWN_TIME: float = 0.3
const MAX_ALPHA: float = 0.28
const FADE_RATE: float = 5.0  # Exponential decay rate (~95% gone in 0.6s)

# Default boss-phase colors, used if the signal doesn't provide one
const PHASE_COLOR_DRAKE: Color = Color(1.0, 0.2, 0.0, 1.0)
const PHASE_COLOR_VOID: Color = Color(0.4, 0.1, 0.6, 1.0)
const PHASE_COLOR_SENTINEL: Color = Color(0.2, 0.5, 0.8, 1.0)
const PHASE_COLOR_GENERIC: Color = Color(1.0, 0.3, 0.1, 1.0)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Connect to the boss phase change signal
	if GameManager:
		GameManager.boss_phase_changed.connect(_on_boss_phase_changed)
		GameManager.game_restarted.connect(_on_game_restarted)

func _on_boss_phase_changed(color: Color) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = COOLDOWN_TIME
	_flash_color = color
	# Sharp onset — snap to max alpha, then exponential decay in _process
	_flash_alpha = MAX_ALPHA
	queue_redraw()

func _on_game_restarted() -> void:
	_flash_alpha = 0.0
	_cooldown = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if _flash_alpha > 0.01:
		# Frame-rate-independent exponential decay (matches DamageFlash pattern)
		_flash_alpha = lerpf(_flash_alpha, 0.0, 1.0 - exp(-FADE_RATE * delta))
		queue_redraw()
	elif _flash_alpha != 0.0:
		_flash_alpha = 0.0
		queue_redraw()

func _draw() -> void:
	if _flash_alpha < 0.01:
		return

	# Draw a colored vignette around the screen edges (same pattern as
	# DamageFlash — concentric rectangles fading from edge to center)
	var screen_size := size
	var max_dim: float = max(screen_size.x, screen_size.y)
	var layers: int = 6
	for i in range(layers):
		var frac: float = float(i) / float(layers)
		var inset: float = frac * max_dim * 0.3
		var rect: Rect2 = Rect2(
			inset, inset,
			screen_size.x - inset * 2.0,
			screen_size.y - inset * 2.0
		)
		var edge_alpha: float = _flash_alpha * (1.0 - frac)
		draw_rect(rect, Color(_flash_color.r, _flash_color.g, _flash_color.b, edge_alpha), false, 3.0)