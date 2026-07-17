## Zorp Wiggles — Dimension Indicator (Phase 14)
## Shows the current dimension name and remaining time when in a rift.
## Displays at the top-center of the screen when active.

extends Control

var _label: Label = null
var _timer_bar: ColorRect = null
var _timer_bar_bg: ColorRect = null
var _visible: bool = false

const BAR_WIDTH: float = 300.0
const BAR_HEIGHT: float = 6.0

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
		_label.visible = false
		_timer_bar_bg.visible = false
		_timer_bar.visible = false
	else:
		_visible = true
		_label.visible = true
		_timer_bar_bg.visible = true
		_timer_bar.visible = true
		var dim_name: String = GameConstants.DIMENSION_NAMES.get(new_dim, "Unknown")
		var dim_color: Color = GameConstants.DIMENSION_COLORS.get(new_dim, Color.WHITE)
		_label.text = "🌀 %s" % dim_name
		_label.add_theme_color_override("font_color", dim_color)
		_timer_bar.color = dim_color

func _on_dimension_timer_changed(time_remaining: float) -> void:
	if not _visible:
		return
	# Update timer bar width
	var ratio: float = clampf(time_remaining / GameConstants.DIMENSION_DURATION, 0.0, 1.0)
	var fill_width: float = (BAR_WIDTH - 4.0) * ratio
	_timer_bar.offset_right = 542.0 + fill_width