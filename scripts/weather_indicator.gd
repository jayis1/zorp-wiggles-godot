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
# Tracked tween for the combo label entrance/exit so rapid combo changes don't
# stack overlapping tweens. The label slides in from below + fades in when a
# combo starts, and slides back down + fades out when it ends — matching the
# dimension indicator's entrance/exit language.
var _combo_tween: Tween = null
const _COMBO_SLIDE_OFFSET: float = -16.0  # Start 16px above resting position

# ── Icon pop animation ── When the weather changes, the icon used to just
#    snap-swap its text and color. Now it does a quick scale-pop (shrink to
#    0.6, then overshoot back to 1.0 with an elastic settle) so the change
#    reads as a deliberate "shift" rather than a silent text replace. The
#    tween is tracked and killed before starting a new one so rapid weather
#    changes don't stack. The icon's pivot is set to its center in _ready
#    so the scale grows from the middle, not the top-left corner.
var _icon_pop_tween: Tween = null

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
	# Center the pivot so the weather-change scale-pop grows from the middle
	# of the icon, not the top-left corner. The icon rect is 40×30, so the
	# center is at (20, 15) in local coordinates.
	_icon_label.pivot_offset = Vector2(20.0, 15.0)
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
	_combo_label.visible = false
	_combo_label.modulate.a = 0.0
	_combo_label.scale = Vector2.ONE
	_combo_label.pivot_offset = Vector2(80.0, 9.0)  # Center of the 160x18 label
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
	_play_icon_pop()

func _on_transition_started(new_weather: int) -> void:
	_transition_timer = GameConstants.WEATHER_TRANSITION_DURATION

func _on_transition_ended(weather: int) -> void:
	_transition_timer = 0.0
	if _transition_label:
		_transition_label.text = ""
	_update_display(weather)
	_play_icon_pop()

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
		# ── Smooth label color transition ── The weather name label's
		#    color used to snap instantly on weather change (e.g.
		#    Clear yellow → Storm blue in one frame). Now we tween the
		#    font_color override over 0.4s with ease-out quad so the
		#    color eases through the transition, mirroring the smooth
		#    bar color lerp. A tracked tween is killed before starting
		#    a new one so rapid weather changes (combo transitions)
		#    don't stack into jitter.
		if _label.has_meta("_color_tween") and is_instance_valid(_label.get_meta("_color_tween") as Tween):
			(_label.get_meta("_color_tween") as Tween).kill()
		var prev_label_col: Color = _label.get_theme_color("font_color") if _label.has_theme_color_override("font_color") else Color(1, 1, 1)
		var label_color_tween := create_tween()
		label_color_tween.tween_method(
			func(c: Color):
				_label.add_theme_color_override("font_color", c),
			prev_label_col, col, 0.4
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_label.set_meta("_color_tween", label_color_tween)
	if _icon_label:
		_icon_label.text = icon
		# ── Smooth icon color transition ── Same treatment as the
		#    label: tween the icon's font_color from the previous
		#    weather color to the new one over 0.4s, so the icon
		#    color shifts alongside the label rather than snapping.
		if _icon_label.has_meta("_color_tween") and is_instance_valid(_icon_label.get_meta("_color_tween") as Tween):
			(_icon_label.get_meta("_color_tween") as Tween).kill()
		var prev_icon_col: Color = _icon_label.get_theme_color("font_color") if _icon_label.has_theme_color_override("font_color") else Color(1, 1, 1)
		var icon_color_tween := create_tween()
		icon_color_tween.tween_method(
			func(c: Color):
				_icon_label.add_theme_color_override("font_color", c),
			prev_icon_col, col, 0.4
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_icon_label.set_meta("_color_tween", icon_color_tween)
	if _timer_bar:
		var c: Color = col
		c.a = 0.9
		_timer_bar.color = c

## Play a quick scale-pop on the weather icon so a weather change reads as
## a deliberate visual "shift" rather than a silent text swap. The icon
## shrinks to 0.6 (a small "wind-up"), then overshoots back to 1.0 with an
## elastic settle — the same juice language used on combo text and level-up
## popups. The tween is tracked and killed before starting a new one so
## rapid weather changes (e.g. combo transitions) don't stack into jitter.
## Skipped if the icon node is missing or being freed.
func _play_icon_pop() -> void:
	if not _icon_label or not is_instance_valid(_icon_label):
		return
	if _icon_pop_tween and _icon_pop_tween.is_valid():
		_icon_pop_tween.kill()
	_icon_pop_tween = create_tween()
	# Quick shrink to 0.6 in 60ms — the "wind-up" before the pop.
	_icon_pop_tween.tween_property(_icon_label, "scale", Vector2(0.6, 0.6), 0.06) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# Overshoot back to 1.0 with an elastic settle for a bouncy, juicy return.
	_icon_pop_tween.tween_property(_icon_label, "scale", Vector2.ONE, 0.22) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

# ── Phase 28: Weather combo indicator handlers ──
func _on_combo_started(combo_weather: int, _primary_weather: int) -> void:
	if not _combo_label:
		return
	var info: Dictionary = GameConstants.WEATHER_INFO.get(combo_weather, {"name": "?"})
	var combo_name: String = info.get("name", "?")
	_combo_label.text = "✦ + %s" % combo_name
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.9))
	# ── Entrance animation: slide down from above + fade in ── The combo
	#    label used to appear instantly, which felt flat for a combo — a
	#    layered weather event is dramatic and the UI should match. Now the
	#    label slides in from 16px above with an ease-out-back overshoot and
	#    fades in modulate.a, matching the dimension indicator's entrance
	#    language. A tracked tween ensures a re-combo mid-exit doesn't stack.
	if _combo_tween and _combo_tween.is_valid():
		_combo_tween.kill()
	var rest_top: float = 56.0
	_combo_label.visible = true
	_combo_label.modulate.a = 0.0
	_combo_label.offset_top = rest_top + _COMBO_SLIDE_OFFSET
	_combo_tween = create_tween()
	_combo_tween.set_parallel(true)
	_combo_tween.tween_property(_combo_label, "modulate:a", 1.0, 0.30) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_combo_tween.tween_property(_combo_label, "offset_top", rest_top, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_combo_ended(_combo_weather: int) -> void:
	if not _combo_label:
		return
	# ── Exit animation: slide back up + fade out ── The combo label slides
	#    back up and fades out over 0.25s, then hides. This is the reverse of
	#    the entrance — a clean, smooth departure rather than a hard cut.
	if _combo_tween and _combo_tween.is_valid():
		_combo_tween.kill()
	# If already hidden (e.g. combo ended twice rapidly), nothing to do.
	if not _combo_label.visible:
		return
	var rest_top: float = 56.0
	_combo_tween = create_tween()
	_combo_tween.set_parallel(true)
	_combo_tween.tween_property(_combo_label, "modulate:a", 0.0, 0.25) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_combo_tween.tween_property(_combo_label, "offset_top",
		rest_top + _COMBO_SLIDE_OFFSET, 0.25) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_combo_tween.chain().tween_callback(_hide_combo_label)

func _hide_combo_label() -> void:
	if _combo_label:
		_combo_label.visible = false
		_combo_label.modulate.a = 1.0
		_combo_label.offset_top = 56.0