## Zorp Wiggles — Tooltip Manager (Phase 31: QoL)
## Autoload singleton that provides hover tooltips for in-game entities.
## When the player's crosshair hovers over a collectible, weapon mod in the
## crafting menu, or enemy, a small info panel appears near the cursor with
## the entity's name, description, and relevant stats.
##
## Design:
##   - A single Tooltip Control node is added to the HUD canvas layer. It
##     follows the mouse cursor and shows/hides based on what's under the
##     crosshair.
##   - `show_tooltip(title, desc, stats)` / `hide_tooltip()` are the public
##     API. Other systems (collectible, enemy_base, crafting_menu) call
##     these when the player hovers over them.
##   - The tooltip auto-positions to avoid going off-screen edges.
##   - A short delay (0.4s) before showing prevents flicker when the cursor
##     sweeps across many entities quickly.
##
## What shows tooltips:
##   - Collectibles: name + XP value + rarity (when the player is within
##     a few meters and looking at them).
##   - Enemies: name + HP + damage (when the player is within detection
##     range and looking at them).
##   - Crafting menu materials: name + description + count.
##   - Weapon mod list entries: name + description + stats.
##
## The tooltip is intentionally lightweight — it's a single Panel with two
## Labels (title + body), positioned via offset_left/offset_top. No complex
## layout because it needs to update every frame as the cursor moves.

extends Node

const TOOLTIP_DELAY: float = 0.4  # seconds before tooltip appears
const TOOLTIP_OFFSET: Vector2 = Vector2(16, 16)  # offset from cursor
const TOOLTIP_MAX_WIDTH: float = 320.0
const TOOLTIP_PADDING: float = 8.0
const MAX_CREATE_RETRIES: int = 30  # Max attempts to find HUD (5s at 6/sec)

# The tooltip Control node (added to HUD)
var _tooltip: Control = null
var _panel: Panel = null
var _title_label: Label = null
var _body_label: Label = null

# Current tooltip content (empty = hidden)
var _current_title: String = ""
var _current_body: String = ""
# Timer for the show delay
var _delay_timer: float = 0.0
var _has_pending: bool = false
# Whether the tooltip is currently visible
var _is_visible: bool = false
# Retry counter for HUD creation
var _create_retries: int = 0


func _ready() -> void:
	# Defer UI creation until the HUD exists
	call_deferred("_create_tooltip_ui")


func _process(delta: float) -> void:
	if not _tooltip:
		return
	# Handle the show delay
	if _has_pending:
		_delay_timer += delta
		if _delay_timer >= TOOLTIP_DELAY:
			_has_pending = false
			_show()
	# Position the tooltip near the cursor (if visible)
	if _is_visible:
		_position_at_cursor()


# ── Public API ──────────────────────────────────────────────────────────────

## Request to show a tooltip with the given title and body text.
## The tooltip appears after TOOLTIP_DELAY seconds (to avoid flicker).
## If a tooltip is already showing, it updates immediately.
func show_tooltip(title: String, body: String) -> void:
	if _current_title == title and _current_body == body and _is_visible:
		return  # No change — don't reset the timer
	_current_title = title
	_current_body = body
	if _is_visible:
		# Already visible — update content immediately
		_update_content()
	else:
		# Start the delay timer
		_has_pending = true
		_delay_timer = 0.0


## Immediately show the tooltip (bypassing the delay). Used by UI elements
## like the crafting menu where the hover is already intentional.
func show_tooltip_immediate(title: String, body: String) -> void:
	_current_title = title
	_current_body = body
	_has_pending = false
	_delay_timer = 0.0
	_show()


## Hide the tooltip and cancel any pending show.
func hide_tooltip() -> void:
	_has_pending = false
	_delay_timer = 0.0
	if _is_visible:
		_is_visible = false
		if _tooltip:
			_tooltip.visible = false


## Is the tooltip currently visible?
func is_visible() -> bool:
	return _is_visible


# ── Tooltip UI ───────────────────────────────────────────────────────────────

func _create_tooltip_ui() -> void:
	var hud: CanvasLayer = null
	var main: Node = get_tree().current_scene
	if main:
		hud = main.get_node_or_null("HUD")
	if not hud:
		_create_retries += 1
		if _create_retries < MAX_CREATE_RETRIES:
			call_deferred("_create_tooltip_ui")
		return
	_create_retries = 0
	_tooltip = Control.new()
	_tooltip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	hud.add_child(_tooltip)
	_build_tooltip()


func _build_tooltip() -> void:
	if not _tooltip:
		return
	_panel = Panel.new()
	_panel.offset_left = 0.0
	_panel.offset_top = 0.0
	_panel.offset_right = TOOLTIP_MAX_WIDTH
	_panel.offset_bottom = 100.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(_panel)

	_title_label = Label.new()
	_title_label.offset_left = TOOLTIP_PADDING
	_title_label.offset_top = TOOLTIP_PADDING
	_title_label.offset_right = TOOLTIP_MAX_WIDTH - TOOLTIP_PADDING
	_title_label.offset_bottom = TOOLTIP_PADDING + 28.0
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_title_label)

	_body_label = Label.new()
	_body_label.offset_left = TOOLTIP_PADDING
	_body_label.offset_top = TOOLTIP_PADDING + 30.0
	_body_label.offset_right = TOOLTIP_MAX_WIDTH - TOOLTIP_PADDING
	_body_label.offset_bottom = 100.0 - TOOLTIP_PADDING
	_body_label.add_theme_font_size_override("font_size", 13)
	_body_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_body_label)


func _show() -> void:
	if not _tooltip or _current_title.is_empty():
		return
	_update_content()
	_tooltip.visible = true
	_is_visible = true
	_position_at_cursor()


func _update_content() -> void:
	if _title_label:
		_title_label.text = _current_title
	if _body_label:
		_body_label.text = _current_body
	# Auto-size the panel height based on the body text length
	# Simple heuristic: 20px per line, estimate lines from text length
	if _body_label and _panel:
		var body_lines: int = _current_body.count("\n") + 1
		# Also account for word-wrap (rough estimate: ~40 chars per line at our width)
		var wrap_lines: int = ceil(float(_current_body.length()) / 42.0)
		var total_lines: int = max(body_lines, wrap_lines)
		var panel_height: float = TOOLTIP_PADDING + 28.0 + float(total_lines) * 18.0 + TOOLTIP_PADDING
		_panel.offset_bottom = panel_height


func _position_at_cursor() -> void:
	if not _tooltip or not _panel:
		return
	var mouse_pos: Vector2 = _tooltip.get_global_mouse_position()
	var viewport_size: Vector2 = _tooltip.get_viewport_rect().size
	var x: float = mouse_pos.x + TOOLTIP_OFFSET.x
	var y: float = mouse_pos.y + TOOLTIP_OFFSET.y
	# Keep the tooltip on-screen
	var panel_width: float = _panel.offset_right - _panel.offset_left
	var panel_height: float = _panel.offset_bottom - _panel.offset_top
	if x + panel_width > viewport_size.x:
		x = mouse_pos.x - panel_width - TOOLTIP_OFFSET.x
	if y + panel_height > viewport_size.y:
		y = mouse_pos.y - panel_height - TOOLTIP_OFFSET.y
	_panel.offset_left = x
	_panel.offset_top = y
	_panel.offset_right = x + panel_width
	_panel.offset_bottom = y + panel_height