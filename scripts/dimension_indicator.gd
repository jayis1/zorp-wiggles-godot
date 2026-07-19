## Zorp Wiggles — Dimension Indicator (Phase 14)
## Shows the current dimension name and remaining time when in a rift.
## Displays at the top-center of the screen when active.

extends Control

var _label: Label = null
var _timer_bar: ColorRect = null
var _timer_bar_bg: ColorRect = null
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