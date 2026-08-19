## Zorp Wiggles — Fast Travel Menu UI (Phase 26: World Life)
## A toggleable panel listing all activated waypoints. The player opens it with
## the "fast_travel" input action (H key), clicks a destination, and teleports
## there for a small Space Gloop cost. Undiscovered waypoints are not shown.
## Uses _draw() for custom rendering and handles click input directly.

extends Control

class_name FastTravelMenu

var _is_open: bool = false
var _fade_alpha: float = 0.0
var _item_rects: Array[Rect2] = []
var _close_rect: Rect2 = Rect2()
# ── Hover state ── Tracks which waypoint the mouse is over so _draw() can
#    highlight it and play a hover SFX on enter, matching the trade menu and
#    the Button-based menus. -1 = no item hovered.
var _hovered_item: int = -1
var _hover_pulse: float = 0.0  # 0..1 eased hover glow

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE when closed so mouse clicks pass through to the player's
	# _unhandled_input (shooting, fetch mode). Switched to STOP in open()
	# so the menu captures clicks for waypoint selection. Keeping STOP
	# always-on (like the existing TradeMenu) would block all mouse input
	# even when the menu is invisible.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true  # Always visible for drawing, uses alpha for fade

func open() -> void:
	if _is_open:
		return
	_is_open = true
	GameManager.is_paused = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Open SFX — confirming click for menu opening.
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	GameManager.is_paused = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hovered_item = -1  # Clear hover so reopening doesn't start with a stale highlight
	# Close SFX — slightly lower pitch matching the open/close audio
	# language used across all UI panels.
	if AudioManager:
		AudioManager.play_sfx_pitched(AudioManager.SFX_UI_CLICK, 0.85)

# Public accessor so the player toggle can check state without touching the
# private _is_open variable directly.
func is_open() -> bool:
	return _is_open

func _process(delta: float) -> void:
	var target: float = 1.0 if _is_open else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 8.0)
	# ── Hover pulse ease ── Smooth 0→1 glow when an item is hovered, eased
	#    back to 0 on exit. Matches the trade menu's hover pulse timing.
	var hover_target: float = 1.0 if _hovered_item >= 0 else 0.0
	var hover_weight: float = 1.0 - exp(-12.0 * delta)
	_hover_pulse = lerpf(_hover_pulse, hover_target, hover_weight)
	if _fade_alpha > 0.01 or _is_open:
		queue_redraw()
	# Close on escape or the missions key (the fast_travel key is handled by
	# the player's _toggle_fast_travel_menu, which toggles open/close — adding
	# it here would close the menu on the same frame it was opened).
	if _is_open and (Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("missions")):
		close()

func _gui_click(position: Vector2) -> void:
	if not _is_open:
		return
	if _close_rect.has_point(position):
		close()
		return
	for i in range(_item_rects.size()):
		if _item_rects[i].has_point(position):
			_select_waypoint(i)
			return

func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_gui_click(event.position)
	elif event is InputEventMouseMotion:
		_update_hover(event.position)

## Track which waypoint the mouse is hovering over so _draw() can highlight it.
## Plays a UI hover SFX on enter (not on every motion), mirroring the trade
## menu and Button-based menus. _item_rects are populated by _draw() each
## frame; we check against the previous frame's rects which is fine since
## the layout is static while the menu is open.
func _update_hover(mouse_pos: Vector2) -> void:
	var new_hover: int = -1
	for i in range(_item_rects.size()):
		if _item_rects[i].has_point(mouse_pos):
			new_hover = i
			break
	if new_hover != _hovered_item:
		_hovered_item = new_hover
		if new_hover >= 0:
			AudioManager.play_sfx(AudioManager.SFX_UI_HOVER)
		queue_redraw()

func _select_waypoint(index: int) -> void:
	if not FastTravelNetwork:
		return
	var waypoints: Array = FastTravelNetwork.get_activated_waypoints()
	if index < 0 or index >= waypoints.size():
		return
	var wp: Node = waypoints[index]
	if FastTravelNetwork.teleport_to(wp):
		close()

func _draw() -> void:
	if _fade_alpha < 0.01:
		return
	var font := get_theme_default_font()
	if not font:
		return
	# Ease the fade alpha for a smoother feel — linear move_toward feels
	# mechanical. ease_out_cubic on open, ease_in_cubic on close, matching
	# the quest_log/trade_menu and the tween-based easing used by Button menus.
	var eased: float
	if _is_open:
		eased = 1.0 - pow(1.0 - _fade_alpha, 3.0)  # ease_out_cubic
	else:
		eased = _fade_alpha * _fade_alpha * _fade_alpha  # ease_in_cubic
	var a: float = eased
	# ── Panel pop-in entrance ── The Button-based menus scale up from ~0.92
	#    with an overshoot ease for a satisfying "pop-in". This _draw()-based
	#    menu only faded, which felt flat by comparison. We derive a scale
	#    factor from the existing eased alpha (no new state) so the panel
	#    scales 0.96→1.0 in sync with the fade. The dim background is drawn at
	#    full size; only the panel and its contents scale around the panel's
	#    center so the click hitboxes (computed from panel_x/y/w/h) scale
	#    with the visual during the entrance, matching Button menus.
	var _panel_pop: float = lerpf(0.96, 1.0, eased)
	var _base_panel_w: float = 400.0
	var _base_panel_h: float = 480.0
	var _base_panel_cx: float = 440.0 + _base_panel_w / 2.0
	var _base_panel_cy: float = 120.0 + _base_panel_h / 2.0
	var panel_w: float = _base_panel_w * _panel_pop
	var panel_h: float = _base_panel_h * _panel_pop
	var panel_x: float = _base_panel_cx - panel_w / 2.0
	var panel_y: float = _base_panel_cy - panel_h / 2.0

	# Dim background.
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0, 0, 0, 0.5 * a), true)
	# Panel.
	var bg := Color(0.04, 0.1, 0.12, 0.95 * a)
	draw_rect(Rect2(panel_x, panel_y, panel_w, panel_h), bg, true)
	# Teal border.
	var border_col := Color(0.3, 1.0, 0.7, 0.6 * a)
	draw_rect(Rect2(panel_x, panel_y, panel_w, panel_h), border_col, false, 2.0)

	# Title.
	font.draw_string(get_canvas_item(),
		Vector2(panel_x + 20, panel_y + 30),
		"🧭 Fast Travel Network", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, border_col)

	# Space Gloop balance.
	var gloop: int = 0
	if WeaponModSystem:
		gloop = WeaponModSystem.get_material_count(GameConstants.CollectibleType.SPACE_GLOOP)
	font.draw_string(get_canvas_item(),
		Vector2(panel_x + panel_w - 180, panel_y + 30),
		"Space Gloop: %d 🟢" % gloop, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		Color(0.4, 1.0, 0.4, a))

	# Divider.
	draw_line(Vector2(panel_x + 15, panel_y + 45), Vector2(panel_x + panel_w - 15, panel_y + 45),
		Color(0.3, 1.0, 0.7, 0.3 * a), 1.0)

	# Waypoint list.
	_item_rects.clear()
	var waypoints: Array = []
	if FastTravelNetwork:
		waypoints = FastTravelNetwork.get_activated_waypoints()
	var start_y: float = panel_y + 60
	var item_h: float = 50.0
	var cost: int = GameConstants.FAST_TRAVEL_TELEPORT_COST

	if waypoints.is_empty():
		font.draw_string(get_canvas_item(),
			Vector2(panel_x + 20, start_y + 20),
			"No waypoints activated yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color(0.6, 0.6, 0.65, a))
		font.draw_string(get_canvas_item(),
			Vector2(panel_x + 20, start_y + 45),
			"Explore the world to find teal waypoint pillars.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(0.5, 0.5, 0.55, a))
	else:
		var _drawn_index: int = 0  # Tracks only valid, drawn waypoints so
		                            # _item_rects indices match _select_waypoint.
		for i in range(waypoints.size()):
			var wp: Node = waypoints[i]
			if not is_instance_valid(wp):
				continue
			var iy: float = start_y + _drawn_index * (item_h + 6)
			_drawn_index += 1
			if iy + item_h > panel_y + panel_h - 40:
				break
			var rect := Rect2(panel_x + 15, iy, panel_w - 30, item_h)
			_item_rects.append(rect)
			# Array index of this row in _item_rects (for hover matching).
			# _drawn_index is 1 ahead because it's incremented before the append.
			var item_idx: int = _item_rects.size() - 1
			var can_afford: bool = gloop >= cost
			# ── Hover highlight ── Brighten background + thicken border on the
			#    hovered row so the list feels interactive. The eased _hover_pulse
			#    gives a soft glow instead of a hard snap.
			var is_hovered: bool = (item_idx == _hovered_item)
			var hover_glow: float = _hover_pulse if is_hovered else 0.0
			var item_bg := Color(0.05, 0.15, 0.18, 0.7 * a)
			if not can_afford:
				item_bg = Color(0.15, 0.08, 0.08, 0.5 * a)
			if hover_glow > 0.01:
				var hover_bg := Color(0.1, 0.25, 0.22, 0.85 * a)
				item_bg = item_bg.lerp(hover_bg, hover_glow)
			draw_rect(rect, item_bg, true)
			var item_border := Color(0.3, 1.0, 0.7, 0.3 * a)
			if can_afford:
				item_border = Color(0.4, 1.0, 0.5, 0.4 * a)
			if hover_glow > 0.01:
				var hover_border := Color(0.3, 1.0, 0.7, 0.9 * a)
				item_border = item_border.lerp(hover_border, hover_glow)
			var border_width: float = 1.0 + hover_glow * 1.0
			draw_rect(rect, item_border, false, border_width)
			# Icon.
			font.draw_string(get_canvas_item(),
				Vector2(rect.position.x + 10, rect.position.y + 22),
				"🧭", HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
				Color(0.3, 1.0, 0.7, a if can_afford else 0.4 * a))
			# Name.
			var wp_name: String = "Unknown"
			if "waypoint_name" in wp:
				wp_name = wp.waypoint_name
			font.draw_string(get_canvas_item(),
				Vector2(rect.position.x + 40, rect.position.y + 22),
				wp_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
				Color(1.0, 1.0, 1.0, a if can_afford else 0.4 * a))
			# Cost.
			font.draw_string(get_canvas_item(),
				Vector2(rect.position.x + 40, rect.position.y + 40),
				"Cost: %d Space Gloop" % cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				Color(0.4, 1.0, 0.4, a if can_afford else 0.5 * a))
			# Teleport hint.
			font.draw_string(get_canvas_item(),
				Vector2(rect.position.x + rect.size.x - 90, rect.position.y + 40),
				"[Click to Travel]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color(0.6, 0.7, 0.9, 0.6 * a if can_afford else 0.2 * a))

	# Close button.
	var close_x: float = panel_x + panel_w - 80
	var close_y: float = panel_y + panel_h - 30
	_close_rect = Rect2(close_x, close_y, 70, 22)
	draw_rect(_close_rect, Color(0.1, 0.2, 0.18, 0.8 * a), true)
	draw_rect(_close_rect, border_col, false, 1.0)
	font.draw_string(get_canvas_item(),
		Vector2(close_x + 15, close_y + 16),
		"[Esc] Close", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.8, 0.9, 0.85, a))