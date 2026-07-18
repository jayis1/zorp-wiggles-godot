## Zorp Wiggles — Power-up Timer Display (Phase 5: HUD Polish)
## Shows active buffs (from monoliths) as small panels with timer bars on the
## left side of the HUD, below the XP bar. Each panel shows the buff name and
## a shrinking bar representing remaining duration.

extends Control

class_name PowerUpTimerDisplay

# ─── Internal State ───────────────────────────────────────────────────────────
var _buff_labels: Dictionary = {}  # buff_key -> Label
var _buff_bars: Dictionary = {}    # buff_key -> ColorRect
var _buff_containers: Dictionary = {}  # buff_key -> Panel
var _max_duration: Dictionary = {}  # buff_key -> max duration for bar calc

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_left = 20
	offset_top = 80
	offset_right = 250
	offset_bottom = 250

func _process(_delta: float) -> void:
	# Check active buffs in GameManager
	var active_buffs: Dictionary = GameManager.active_buffs
	var current_keys: Array = active_buffs.keys()

	# Add panels for new buffs
	for key in current_keys:
		if not _buff_containers.has(key):
			_create_buff_panel(key)

	# Remove panels for expired buffs
	var panel_keys: Array = _buff_containers.keys()
	for key in panel_keys:
		if not active_buffs.has(key):
			_remove_buff_panel(key)

	# Update timers and bars
	var y_offset: float = 0
	for key in current_keys:
		var remaining: float = active_buffs[key]
		if _buff_labels.has(key):
			var label: Label = _buff_labels[key]
			label.text = "%s (%.1fs)" % [_format_buff_name(key), remaining]
		if _buff_bars.has(key):
			var bar: ColorRect = _buff_bars[key]
			var max_dur: float = _max_duration.get(key, 10.0)
			var ratio: float = clampf(remaining / max_dur, 0.0, 1.0)
			# Fill width = bar_bg width (210px = 215-5) × remaining ratio.
			# bar_bg is a sibling ColorRect at offset_left=5..offset_right=215.
			# Using a constant avoids a feedback loop where bar.size.x shrinks
			# each frame and then gets used as the basis for the next frame's size.
			bar.size.x = 210.0 * ratio
			# Color: green → yellow → red
			if ratio > 0.5:
				bar.color = Color(1.0 - (ratio - 0.5) * 2.0, 1.0, 0.0)
			else:
				bar.color = Color(1.0, ratio * 2.0, 0.0)
		# Position container
		if _buff_containers.has(key):
			var panel: Panel = _buff_containers[key]
			panel.offset_top = y_offset
			y_offset += 30

func _create_buff_panel(key: String) -> void:
	var panel := Panel.new()
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 220
	panel.offset_bottom = 26
	# Start hidden + offset for the slide-in animation
	panel.modulate.a = 0.0
	panel.offset_left = -30.0
	add_child(panel)

	var label := Label.new()
	label.offset_left = 5
	label.offset_top = 2
	label.offset_right = 215
	label.offset_bottom = 16
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	panel.add_child(label)

	var bar_bg := ColorRect.new()
	bar_bg.offset_left = 5
	bar_bg.offset_top = 17
	bar_bg.offset_right = 215
	bar_bg.offset_bottom = 23
	bar_bg.color = Color(0.2, 0.1, 0.1)
	panel.add_child(bar_bg)

	var bar := ColorRect.new()
	bar.offset_left = 5
	bar.offset_top = 17
	bar.offset_right = 215
	bar.offset_bottom = 23
	bar.color = Color(0.2, 0.9, 0.2)
	panel.add_child(bar)

	_buff_containers[key] = panel
	_buff_labels[key] = label
	_buff_bars[key] = bar
	_max_duration[key] = GameConstants.MONOLITH_BUFF_DURATION

	# Slide-in + fade-in animation: the panel eases in from the left with a
	# short fade so buffs don't pop in abruptly when a monolith is activated.
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.25) \
		.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "offset_left", 0.0, 0.30) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _remove_buff_panel(key: String) -> void:
	if _buff_containers.has(key):
		var panel: Panel = _buff_containers[key]
		# Fade-out + slide-left animation before freeing. This avoids the
		# abrupt disappearance when a buff expires. The tween calls queue_free
		# on completion so the panel is cleaned up after the animation.
		var tween := panel.create_tween()
		tween.tween_property(panel, "modulate:a", 0.0, 0.20) \
			.set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(panel, "offset_left", -30.0, 0.22) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tween.tween_callback(panel.queue_free)
		_buff_containers.erase(key)
	else:
		# Defensive: erase the other entries so stale refs don't linger
		pass
	if _buff_labels.has(key):
		_buff_labels.erase(key)
	if _buff_bars.has(key):
		_buff_bars.erase(key)
	_max_duration.erase(key)

func _format_buff_name(key: String) -> String:
	# Buff keys from monolith.gd: "speed", "damage", "xp"
	match key:
		"speed":
			return "⚡ Speed Surge"
		"damage":
			return "⚔ Power Surge"
		"xp":
			return "★ Wisdom Aura"
		_:
			return key.capitalize()