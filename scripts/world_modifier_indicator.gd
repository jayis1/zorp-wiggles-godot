## Zorp Wiggles — World Modifier Indicator HUD (Phase 33: Procedural Content)
##
## Persistent on-screen display of active world modifiers for normal gameplay.
## Shows each modifier's icon, name, and color in a compact vertical list on the
## left side of the screen, below the HP bar. Fades in when modifiers are rolled
## and fades out when cleared (game restart, no modifiers rolled).
##
## The Daily Challenge and Weekly Challenge HUDs already show their modifiers
## inline — this indicator is for NORMAL mode runs where world modifiers are
## active but the player has no other persistent reminder of which rules apply.
## Challenge mode HUDs suppress this indicator to avoid duplicate display.
##
## Created dynamically by HUD.gd (no .tscn needed).
extends Control

# ─── Internal State ───────────────────────────────────────────────────────────
var _panel: Panel = null
var _modifier_labels: Array[Label] = []
var _icon_labels: Array[Label] = []
var _bg_rects: Array[ColorRect] = []
var _visible: bool = false
var _transition_tween: Tween = null

# ── Entrance/exit slide offsets ── The indicator slides in from the left
#    when modifiers are first rolled, and slides out when cleared. Matches
#    the dimension indicator's slide-in language for consistency.
const _SLIDE_OFFSET: float = -24.0
const _ENTRANCE_DURATION: float = 0.4
const _EXIT_DURATION: float = 0.3

# ── Layout constants ──
const _PANEL_WIDTH: float = 210.0
const _ENTRY_HEIGHT: float = 26.0
const _PANEL_PADDING: float = 6.0
const _ICON_WIDTH: float = 30.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Panel background — left side, below HP bar
	_panel = Panel.new()
	_panel.offset_left = 8.0
	_panel.offset_top = 90.0
	_panel.offset_right = 8.0 + _PANEL_WIDTH
	_panel.offset_bottom = 90.0
	_panel.visible = false
	add_child(_panel)

	# Connect to WorldModifierSystem signals
	if WorldModifierSystem:
		if not WorldModifierSystem.modifiers_rolled.is_connected(_on_modifiers_rolled):
			WorldModifierSystem.modifiers_rolled.connect(_on_modifiers_rolled)
		if not WorldModifierSystem.modifier_added.is_connected(_on_modifier_added):
			WorldModifierSystem.modifier_added.connect(_on_modifier_added)
		if not WorldModifierSystem.modifier_removed.is_connected(_on_modifier_removed):
			WorldModifierSystem.modifier_removed.connect(_on_modifier_removed)

	# Connect to game restart for clean reset
	if GameManager:
		if not GameManager.game_restarted.is_connected(_on_game_restarted):
			GameManager.game_restarted.connect(_on_game_restarted)

	# Build initial display if modifiers are already rolled
	if WorldModifierSystem and WorldModifierSystem.is_initialized():
		_rebuild_display(WorldModifierSystem.get_active_modifiers())

func _process(_delta: float) -> void:
	# In challenge modes (Daily/Weekly), the challenge HUDs already show
	# modifiers — hide this indicator to avoid duplicate display.
	if _visible:
		if _should_suppress():
			_hide()

func _should_suppress() -> bool:
	if GameModeManager:
		if GameModeManager.is_daily_challenge() or GameModeManager.is_weekly_challenge():
			return true
	return false

func _on_modifiers_rolled(modifier_ids: Array) -> void:
	_rebuild_display(modifier_ids)

func _on_modifier_added(modifier_id: int) -> void:
	# Rebuild from the full active list to ensure correct ordering
	if WorldModifierSystem:
		_rebuild_display(WorldModifierSystem.get_active_modifiers())

func _on_modifier_removed(_modifier_id: int) -> void:
	if WorldModifierSystem:
		_rebuild_display(WorldModifierSystem.get_active_modifiers())

func _on_game_restarted() -> void:
	_clear_display()

func _rebuild_display(modifier_ids: Array) -> void:
	_clear_display()
	if modifier_ids.is_empty():
		return
	if _should_suppress():
		return

	# Build entries for each modifier
	var entry_count: int = modifier_ids.size()
	var panel_height: float = _PANEL_PADDING * 2.0 + entry_count * _ENTRY_HEIGHT
	_panel.offset_bottom = 90.0 + panel_height
	_panel.visible = true

	for i in range(entry_count):
		var mod_id: int = modifier_ids[i]
		var mod_color: Color = WorldModifierSystem.get_modifier_color(mod_id)
		var mod_icon: String = WorldModifierSystem.get_modifier_icon(mod_id)
		var mod_name: String = WorldModifierSystem.get_modifier_name(mod_id)

		# Background tint per modifier
		var bg := ColorRect.new()
		bg.offset_left = _PANEL_PADDING
		bg.offset_top = _PANEL_PADDING + i * _ENTRY_HEIGHT
		bg.offset_right = _PANEL_WIDTH - _PANEL_PADDING
		bg.offset_bottom = _PANEL_PADDING + (i + 1) * _ENTRY_HEIGHT - 2.0
		bg.color = Color(mod_color.r, mod_color.g, mod_color.b, 0.15)
		_panel.add_child(bg)
		_bg_rects.append(bg)

		# Icon label
		var icon_lbl := Label.new()
		icon_lbl.offset_left = _PANEL_PADDING + 2.0
		icon_lbl.offset_top = _PANEL_PADDING + i * _ENTRY_HEIGHT + 1.0
		icon_lbl.offset_right = _PANEL_PADDING + _ICON_WIDTH
		icon_lbl.offset_bottom = _PANEL_PADDING + (i + 1) * _ENTRY_HEIGHT - 1.0
		icon_lbl.text = mod_icon
		icon_lbl.add_theme_font_size_override("font_size", 16)
		icon_lbl.add_theme_color_override("font_color", mod_color)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_panel.add_child(icon_lbl)
		_icon_labels.append(icon_lbl)

		# Name label
		var name_lbl := Label.new()
		name_lbl.offset_left = _PANEL_PADDING + _ICON_WIDTH + 2.0
		name_lbl.offset_top = _PANEL_PADDING + i * _ENTRY_HEIGHT + 1.0
		name_lbl.offset_right = _PANEL_WIDTH - _PANEL_PADDING - 2.0
		name_lbl.offset_bottom = _PANEL_PADDING + (i + 1) * _ENTRY_HEIGHT - 1.0
		name_lbl.text = mod_name
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_panel.add_child(name_lbl)
		_modifier_labels.append(name_lbl)

	_show()

func _clear_display() -> void:
	for lbl in _modifier_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	for lbl in _icon_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	for bg in _bg_rects:
		if is_instance_valid(bg):
			bg.queue_free()
	_modifier_labels.clear()
	_icon_labels.clear()
	_bg_rects.clear()
	_panel.visible = false
	_visible = false

func _show() -> void:
	if _visible:
		return
	_visible = true
	_panel.visible = true
	# Slide-in animation from the left
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	_panel.modulate.a = 0.0
	_panel.offset_left = 8.0 + _SLIDE_OFFSET
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.tween_property(_panel, "modulate:a", 1.0, _ENTRANCE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_transition_tween.tween_property(_panel, "offset_left", 8.0, _ENTRANCE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _hide() -> void:
	if not _visible:
		return
	_visible = false
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.tween_property(_panel, "modulate:a", 0.0, _EXIT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_transition_tween.tween_property(_panel, "offset_left", 8.0 + _SLIDE_OFFSET, _EXIT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_transition_tween.chain().tween_callback(func(): _panel.visible = false)