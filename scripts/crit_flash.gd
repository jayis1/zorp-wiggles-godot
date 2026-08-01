## Zorp Wiggles — Critical Hit Screen-Edge Flash
## Enhancement Pack 20: A brief gold-colored screen-edge glow that flashes
## when a critical hit lands. The flash is a vignette-style overlay — bright
## at the screen edges, transparent in the center — that fades in quickly
## (0.05s) and fades out over 0.25s. This gives crits a visual punch beyond
## the gold damage number + hit-stop freeze, reinforcing the "that was a
## good hit" feedback loop.
##
## The flash color is a blend of gold (the crit color) and the weapon mod's
## color, so the flash has thematic variety: fire mods flash orange, ice
## mods flash cyan, void mods flash purple, etc. The blend is 60% gold +
## 40% mod color so crits always read as "golden" regardless of the weapon.
##
## A cooldown of 0.08s prevents rapid-fire crits from stacking the flash
## into a persistent glow — the first crit flashes, subsequent crits within
## the cooldown refresh the timer but don't re-trigger the animation.

extends Control

# ── Visual elements ───────────────────────────────────────────────────────────
var _flash_rect: ColorRect = null

# ── State ────────────────────────────────────────────────────────────────────
var _flash_timer: float = 0.0
var _flash_duration: float = 0.30
var _cooldown: float = 0.0
const COOLDOWN_TIME: float = 0.08

# Colors
const CRIT_GOLD: Color = Color(1.0, 0.85, 0.3, 0.0)  # Gold, alpha animated
const MAX_EDGE_ALPHA: float = 0.22  # Max flash intensity at screen edges

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create the flash overlay — a full-screen ColorRect whose alpha we animate.
	# The color is set dynamically on each crit (blended gold + mod color).
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1.0, 0.85, 0.3, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)

	# Connect to the critical_hit signal
	if GameManager:
		GameManager.critical_hit.connect(_on_critical_hit)
		GameManager.game_restarted.connect(_on_game_restarted)

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_timer = 0.0
			if _flash_rect:
				var c: Color = _flash_rect.color
				c.a = 0.0
				_flash_rect.color = c
		else:
			# Animate the flash alpha — sharp onset (ease-out) then gentle fade.
			# The flash curve is: 0→MAX_ALPHA in the first 15% of the duration,
			# then MAX_ALPHA→0 over the remaining 85% with an ease-in-cubic so
			# the fade reads as a "lingering glow" rather than a linear drain.
			var progress: float = 1.0 - (_flash_timer / _flash_duration)
			var alpha: float = 0.0
			if progress < 0.15:
				# Fast onset — ease-out quadratic
				var t: float = progress / 0.15
				alpha = MAX_EDGE_ALPHA * (1.0 - pow(1.0 - t, 2.0))
			else:
				# Fade out — ease-in cubic
				var t: float = (progress - 0.15) / 0.85
				alpha = MAX_EDGE_ALPHA * (1.0 - pow(t, 3.0))
			if _flash_rect:
				var c: Color = _flash_rect.color
				c.a = alpha
				_flash_rect.color = c

func _on_critical_hit(mod_color: Color) -> void:
	# Cooldown check — don't re-trigger if a flash is very recent
	if _cooldown > 0.0:
		return
	_cooldown = COOLDOWN_TIME
	# Blend gold (60%) with the weapon mod's color (40%) so crits always
	# read as "golden" while still showing the weapon's thematic color.
	var blended: Color = CRIT_GOLD.lerp(mod_color, 0.4)
	blended.a = 0.0  # Alpha is animated separately
	if _flash_rect:
		_flash_rect.color = blended
	_flash_timer = _flash_duration

func _on_game_restarted() -> void:
	_flash_timer = 0.0
	_cooldown = 0.0
	if _flash_rect:
		var c: Color = _flash_rect.color
		c.a = 0.0
		_flash_rect.color = c