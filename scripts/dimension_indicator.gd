## Zorp Wiggles — Dimension Indicator (Phase 14)
## Shows the current dimension name and remaining time when in a rift.
## Displays at the top-center of the screen when active.

extends Control

var _label: Label = null
var _timer_bar: ColorRect = null
var _timer_bar_bg: ColorRect = null
# ── Cached base dimension color ── The urgency pulse lerps the timer bar
#    color toward warm amber, but it must lerp from the dimension's base
#    color (not the previous frame's already-shifted color) so the blend
#    doesn't compound toward warm over many frames. Set when the dimension
#    changes and used as the lerp source in the urgency pulse.
var _timer_bar_base_color: Color = Color(0.8, 0.9, 1.0)
var _visible: bool = false

# ── Entrance/exit animation ── The indicator used to snap in/out when a
#    dimension rift opened/closed. Now it slides down from above + fades in
#    on open, and slides back up + fades out on close, matching the boss HP
#    bar's "drop in with weight" feel. A tracked tween is killed before
#    starting a new one so a re-open mid-fade-out doesn't stack.
var _transition_tween: Tween = null
# Resting Y offset of the label (cached so the slide tween animates relative
# to the home position, not whatever Y the previous tween left it at).
var _label_rest_top: float = 55.0
var _bar_bg_rest_top: float = 88.0
var _bar_rest_top: float = 89.0

const BAR_WIDTH: float = 300.0
const BAR_HEIGHT: float = 6.0
# How far above the resting position the indicator starts/ends its slide.
const _SLIDE_OFFSET: float = -24.0
const _ENTRANCE_DURATION: float = 0.4
const _EXIT_DURATION: float = 0.3

func _ready() -> void:
	# Dimension name label (top-center)
	_label = Label.new()
	_label.offset_left = 490.0
	_label.offset_top = 55.0
	_label.offset_right = 790.0
	_label.offset_bottom = 85.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.visible = false
	add_child(_label)

	# Timer bar background
	_timer_bar_bg = ColorRect.new()
	_timer_bar_bg.offset_left = 540.0
	_timer_bar_bg.offset_top = 88.0
	_timer_bar_bg.offset_right = 540.0 + BAR_WIDTH
	_timer_bar_bg.offset_bottom = 88.0 + BAR_HEIGHT
	_timer_bar_bg.color = Color(0.2, 0.2, 0.25, 0.8)
	_timer_bar_bg.visible = false
	add_child(_timer_bar_bg)

	# Timer bar fill
	_timer_bar = ColorRect.new()
	_timer_bar.offset_left = 542.0
	_timer_bar.offset_top = 89.0
	_timer_bar.offset_right = 542.0 + BAR_WIDTH - 4.0
	_timer_bar.offset_bottom = 89.0 + BAR_HEIGHT - 2.0
	_timer_bar.color = Color(0.8, 0.9, 1.0)
	_timer_bar.visible = false
	add_child(_timer_bar)

	# Connect dimension signals
	DimensionSystem.dimension_changed.connect(_on_dimension_changed)
	DimensionSystem.dimension_timer_changed.connect(_on_dimension_timer_changed)

func _on_dimension_changed(new_dim: int, _old_dim: int) -> void:
	if new_dim == GameConstants.Dimension.NORMAL:
		_visible = false
		_play_exit_animation()
	else:
		var dim_name: String = GameConstants.DIMENSION_NAMES.get(new_dim, "Unknown")
		var dim_color: Color = GameConstants.DIMENSION_COLORS.get(new_dim, Color.WHITE)
		_label.text = "🌀 %s" % dim_name
		_label.add_theme_color_override("font_color", dim_color)
		_timer_bar.color = dim_color
		_timer_bar_base_color = dim_color  # Cache for the urgency pulse lerp
		_visible = true
		_play_entrance_animation()

## Entrance: slide down from above + fade in. The indicator starts fully
## transparent and offset above its resting position, then eases into place
## with an ease-out-back curve for a subtle overshoot — the same "drop in
## with weight" feel as the boss HP bar. All three elements (label, bar bg,
## bar fill) animate together so the whole indicator arrives as one unit.
func _play_entrance_animation() -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	# Make visible at the off-screen start position BEFORE creating the
	# tween so the first tween frame reads the correct initial values.
	_label.visible = true
	_timer_bar_bg.visible = true
	_timer_bar.visible = true
	_label.modulate.a = 0.0
	_timer_bar_bg.modulate.a = 0.0
	_timer_bar.modulate.a = 0.0
	_label.offset_top = _label_rest_top + _SLIDE_OFFSET
	_timer_bar_bg.offset_top = _bar_bg_rest_top + _SLIDE_OFFSET
	_timer_bar.offset_top = _bar_rest_top + _SLIDE_OFFSET
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.tween_property(_label, "modulate:a", 1.0, _ENTRANCE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_transition_tween.tween_property(_timer_bar_bg, "modulate:a", 1.0, _ENTRANCE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_transition_tween.tween_property(_timer_bar, "modulate:a", 1.0, _ENTRANCE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Slide down with ease-out-back for a subtle overshoot "drop in" feel.
	_transition_tween.tween_property(_label, "offset_top", _label_rest_top, _ENTRANCE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_transition_tween.tween_property(_timer_bar_bg, "offset_top", _bar_bg_rest_top, _ENTRANCE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_transition_tween.tween_property(_timer_bar, "offset_top", _bar_rest_top, _ENTRANCE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

## Exit: slide back up + fade out, then hide. The fade is slightly faster
## than the entrance so the indicator leaves briskly — a lingering exit
## would feel sluggish during a dimension transition. Visibility is toggled
## off via a chain callback after the tween completes so the indicator
## doesn't hard-cut mid-fade.
func _play_exit_animation() -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	# If already hidden (e.g. dimension changed twice rapidly), nothing to do.
	if not _label.visible:
		return
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.tween_property(_label, "modulate:a", 0.0, _EXIT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_transition_tween.tween_property(_timer_bar_bg, "modulate:a", 0.0, _EXIT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_transition_tween.tween_property(_timer_bar, "modulate:a", 0.0, _EXIT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_transition_tween.tween_property(_label, "offset_top", _label_rest_top + _SLIDE_OFFSET, _EXIT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_transition_tween.tween_property(_timer_bar_bg, "offset_top", _bar_bg_rest_top + _SLIDE_OFFSET, _EXIT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_transition_tween.tween_property(_timer_bar, "offset_top", _bar_rest_top + _SLIDE_OFFSET, _EXIT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_transition_tween.chain().tween_callback(func():
		_label.visible = false
		_timer_bar_bg.visible = false
		_timer_bar.visible = false
		# Restore resting positions + opacity so the next entrance starts clean.
		_label.modulate.a = 1.0
		_timer_bar_bg.modulate.a = 1.0
		_timer_bar.modulate.a = 1.0
		_label.offset_top = _label_rest_top
		_timer_bar_bg.offset_top = _bar_bg_rest_top
		_timer_bar.offset_top = _bar_rest_top
	)

func _on_dimension_timer_changed(time_remaining: float) -> void:
	if not _visible:
		return
	# Update timer bar width
	var ratio: float = clampf(time_remaining / GameConstants.DIMENSION_DURATION, 0.0, 1.0)
	var fill_width: float = (BAR_WIDTH - 4.0) * ratio
	_timer_bar.offset_right = 542.0 + fill_width
	# ── Urgency pulse in the final 25% ── When the dimension rift is about
	#    to end (ratio < 0.25), the timer bar pulses in height + alpha so
	#    the player gets a clear "hurry up / about to end" cue — mirroring
	#    the combo timer bar's urgency pulse. The pulse uses a high-frequency
	#    sine (12 Hz) so it reads as an urgent flicker rather than a gentle
	#    breath. The pulse intensity ramps from 0 at ratio=0.25 to full at
	#    ratio=0.0, so the urgency builds as time runs out. The bar also
	#    shifts toward a warm amber tint (lerp from the dimension's color
	#    toward orange-red) so the color language matches the urgency:
	#    calm dimension color → warm "ending soon" warning. Above 25%, the
	#    bar rests at its base dimension color and full opacity.
	if ratio < 0.25:
		var urgency: float = (0.25 - ratio) / 0.25  # 0→1 as ratio→0
		var pulse_env: float = sin(time_remaining * 12.0) * 0.5 + 0.5
		# Height pulse: up to +3px on top of the base 6px height
		var height_pulse: float = 3.0 * urgency * pulse_env
		_timer_bar.offset_bottom = 89.0 + BAR_HEIGHT - 2.0 + height_pulse
		# Alpha flicker: dips slightly on each pulse trough (clamped so it
		# never fully disappears)
		_timer_bar.modulate.a = lerpf(0.6, 1.0, pulse_env) * (1.0 - urgency * 0.2)
		# Color shift toward warm amber as urgency builds. Lerps from the
		# cached base dimension color (not the previous frame's shifted
		# color) so the blend doesn't compound toward warm over time.
		var warm_color: Color = Color(1.0, 0.6, 0.2)
		var blend_t: float = urgency * 0.5  # Max 50% blend toward warm
		_timer_bar.color = _timer_bar_base_color.lerp(warm_color, blend_t * (0.5 + 0.5 * pulse_env))
	else:
		# Restore resting state — the entrance animation sets modulate.a to
		# 1.0 and the dimension color; we undo the urgency overrides (height,
		# alpha, and color) so the bar returns to its calm dimension color.
		_timer_bar.offset_bottom = 89.0 + BAR_HEIGHT - 2.0
		_timer_bar.modulate.a = 1.0
		_timer_bar.color = _timer_bar_base_color