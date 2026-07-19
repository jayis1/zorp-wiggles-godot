## Zorp Wiggles — Weather Indicator HUD (Phase 17)
##
## Displays the current weather state (name + icon + color) and a countdown
## timer bar showing time until the next weather change. Positioned top-right
## below the minimap area so it doesn't overlap existing HUD elements.
##
## Created dynamically by HUD.gd (no .tscn needed).

extends Control

# ─── Internal State ───────────────────────────────────────────────────────────
var _label: Label = null
var _timer_bar_bg: ColorRect = null
var _timer_bar: ColorRect = null
var _icon_label: Label = null
var _panel: Panel = null
var _transition_label: Label = null
var _transition_timer: float = 0.0
var _current_color: Color = Color(1, 1, 0.5)
# ── Phase 28: Weather combo indicator ──
var _combo_label: Label = null

func _ready() -> void:
	# Position top-right corner (below where minimap usually sits)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Panel background
	_panel = Panel.new()
	_panel.offset_left = -220.0
	_panel.offset_top = 0.0
	_panel.offset_right = 0.0
	_panel.offset_bottom = 60.0
	add_child(_panel)

	# Icon label (emoji on the left)
	_icon_label = Label.new()
	_icon_label.offset_left = -215.0
	_icon_label.offset_top = 4.0
	_icon_label.offset_right = -175.0
	_icon_label.offset_bottom = 34.0
	_icon_label.text = "☀"
	_icon_label.add_theme_font_size_override("font_size", 22)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	add_child(_icon_label)

	# Weather name label
	_label = Label.new()
	_label.offset_left = -170.0
	_label.offset_top = 4.0
	_label.offset_right = -10.0
	_label.offset_bottom = 24.0
	_label.text = "Clear"
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(_label)

	# Timer bar background
	_timer_bar_bg = ColorRect.new()
	_timer_bar_bg.offset_left = -170.0
	_timer_bar_bg.offset_top = 28.0
	_timer_bar_bg.offset_right = -10.0
	_timer_bar_bg.offset_bottom = 36.0
	_timer_bar_bg.color = Color(0.15, 0.15, 0.15, 0.8)
	add_child(_timer_bar_bg)

	# Timer bar fill
	_timer_bar = ColorRect.new()
	_timer_bar.offset_left = -169.0
	_timer_bar.offset_top = 29.0
	_timer_bar.offset_right = -11.0
	_timer_bar.offset_bottom = 35.0
	_timer_bar.color = Color(1, 0.9, 0.5, 0.9)
	add_child(_timer_bar)

	# Transition label ("→ Fog" fade-in text)
	_transition_label = Label.new()
	_transition_label.offset_left = -170.0
	_transition_label.offset_top = 38.0
	_transition_label.offset_right = -10.0
	_transition_label.offset_bottom = 56.0
	_transition_label.text = ""
	_transition_label.add_theme_font_size_override("font_size", 11)
	_transition_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0))
	_transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_transition_label)

	# ── Phase 28: Weather combo label — shows "+ ComboName" when a combo is active ──
	_combo_label = Label.new()
	_combo_label.offset_left = -170.0
	_combo_label.offset_top = 56.0
	_combo_label.offset_right = -10.0
	_combo_label.offset_bottom = 74.0
	_combo_label.text = ""
	_combo_label.add_theme_font_size_override("font_size", 11)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.9))
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_combo_label)

	# Connect to WeatherSystem signals
	# WeatherSystem is an autoload singleton — accessed directly by name,
	# not via Engine.has_singleton() (which is for engine-registered singletons).
	WeatherSystem.weather_changed.connect(_on_weather_changed)
	WeatherSystem.weather_transition_started.connect(_on_transition_started)
	WeatherSystem.weather_transition_ended.connect(_on_transition_ended)
	WeatherSystem.weather_timer_changed.connect(_on_timer_changed)
	# ── Phase 28: Weather combo signals ──
	WeatherSystem.weather_combo_started.connect(_on_combo_started)
	WeatherSystem.weather_combo_ended.connect(_on_combo_ended)

	# Initialize display with current weather
	_update_display(WeatherSystem.get_current_weather())

func _process(delta: float) -> void:
	# Fade transition label
	if _transition_timer > 0:
		_transition_timer -= delta
		if _transition_label:
			var info: Dictionary = GameConstants.WEATHER_INFO.get(WeatherSystem.get_next_weather(), {})
			var next_name: String = info.get("name", "?")
			_transition_label.text = "→ %s" % next_name
			var a: float = clampf(_transition_timer / GameConstants.WEATHER_TRANSITION_DURATION, 0.0, 1.0)
			var c: Color = _transition_label.get_theme_color("font_color")
			c.a = a * 0.9
			_transition_label.add_theme_color_override("font_color", c)
			if _transition_timer <= 0:
				_transition_label.text = ""

func _on_weather_changed(new_weather: int, old_weather: int) -> void:
	_update_display(new_weather)

func _on_transition_started(new_weather: int) -> void:
	_transition_timer = GameConstants.WEATHER_TRANSITION_DURATION

func _on_transition_ended(weather: int) -> void:
	_transition_timer = 0.0
	if _transition_label:
		_transition_label.text = ""
	_update_display(weather)

func _on_timer_changed(time_remaining: float) -> void:
	# Update timer bar width based on remaining time
	if not _timer_bar or not _timer_bar_bg:
		return
	# Estimate total time for ratio (use midpoint of duration range)
	var total: float = (GameConstants.WEATHER_DURATION_MIN + GameConstants.WEATHER_DURATION_MAX) * 0.5
	var ratio: float = clampf(time_remaining / total, 0.0, 1.0)
	var bar_width: float = _timer_bar_bg.size.x - 2.0
	_timer_bar.offset_right = _timer_bar.offset_left + bar_width * ratio
	# Smooth color toward weather color
	var c: Color = _current_color
	c.a = 0.9
	_timer_bar.color = c

func _update_display(weather: int) -> void:
	var info: Dictionary = GameConstants.WEATHER_INFO.get(weather, {"name": "Unknown", "icon": "?", "color": Color.WHITE})
	var name: String = info.get("name", "Unknown")
	var icon: String = info.get("icon", "?")
	var col: Color = info.get("color", Color.WHITE)
	_current_color = col
	if _label:
		_label.text = name
		_label.add_theme_color_override("font_color", col)
	if _icon_label:
		_icon_label.text = icon
		_icon_label.add_theme_color_override("font_color", col)
	if _timer_bar:
		var c: Color = col
		c.a = 0.9
		_timer_bar.color = c

# ── Phase 28: Weather combo indicator handlers ──
func _on_combo_started(combo_weather: int, primary_weather: int) -> void:
	if not _combo_label:
		return
	var info: Dictionary = GameConstants.WEATHER_INFO.get(combo_weather, {"name": "?"})
	var combo_name: String = info.get("name", "?")
	_combo_label.text = "✦ + %s" % combo_name
	# Use a golden color for the combo indicator
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.9))

func _on_combo_ended(combo_weather: int) -> void:
	if _combo_label:
		_combo_label.text = ""