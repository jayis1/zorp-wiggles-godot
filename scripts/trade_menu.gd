## Zorp Wiggles — Trader Trade Menu UI (Phase 7)
## A toggleable panel for trading Space Gloop for rare items with Trader NPCs.
## Opens when player presses E near a trader. Shows available items, their cost,
## and the player's Space Gloop balance. Click an item to buy it.
## Uses _draw() for custom rendering and handles click input directly.

extends Control

class_name TradeMenu

var _is_open: bool = false
var _fade_alpha: float = 0.0
var _trader: Node = null  # Reference to the trader we're trading with

# Trade item pool — maps item name to CollectibleType enum value and cost in Space Gloop
const TRADE_ITEMS: Array[Dictionary] = [
	{"name": "Meteor Shard", "type": GameConstants.CollectibleType.METEOR_SHARD, "cost": 5, "icon": "☄"},
	{"name": "Quantum Fuzz", "type": GameConstants.CollectibleType.QUANTUM_FUZZ, "cost": 5, "icon": "✦"},
	{"name": "Nebula Dust", "type": GameConstants.CollectibleType.NEBULA_DUST, "cost": 5, "icon": "🌌"},
	{"name": "Shield Crystal", "type": GameConstants.CollectibleType.SHIELD_CRYSTAL, "cost": 5, "icon": "🛡"},
	{"name": "Fireball Scroll", "type": GameConstants.CollectibleType.FIREBALL_SCROLL, "cost": 5, "icon": "🔥"},
	{"name": "Regen Crystal", "type": GameConstants.CollectibleType.REGEN_CRYSTAL, "cost": 5, "icon": "💚"},
	{"name": "Magnet Core", "type": GameConstants.CollectibleType.MAGNET_CORE, "cost": 5, "icon": "🧲"},
	{"name": "Toxic Extract", "type": GameConstants.CollectibleType.TOXIC_EXTRACT, "cost": 5, "icon": "☠"},
]

# Click hitboxes for each item (updated each draw frame)
var _item_rects: Array[Rect2] = []
var _close_rect: Rect2 = Rect2()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # Capture clicks when visible
	visible = true  # Always visible for drawing, uses alpha for fade

func open(trader: Node) -> void:
	if _is_open:
		return
	_trader = trader
	_is_open = true
	GameManager.is_paused = true

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_trader = null
	GameManager.is_paused = false

func _process(delta: float) -> void:
	var target: float = 1.0 if _is_open else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 8.0)
	if _fade_alpha > 0.01 or _is_open:
		queue_redraw()
	# Close on escape or trade key
	if _is_open and (Input.is_action_just_pressed("missions") or Input.is_action_just_pressed("pause")):
		close()

func _gui_click(position: Vector2) -> void:
	if not _is_open:
		return
	# Check close button
	if _close_rect.has_point(position):
		close()
		return
	# Check item clicks
	for i in range(_item_rects.size()):
		if _item_rects[i].has_point(position):
			_buy_item(i)
			return

func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_gui_click(event.position)

func _buy_item(index: int) -> void:
	if index < 0 or index >= TRADE_ITEMS.size():
		return
	var item: Dictionary = TRADE_ITEMS[index]
	var cost: int = item["cost"]
	# Check Space Gloop balance
	var gloop: int = WeaponModSystem.get_material_count(GameConstants.CollectibleType.SPACE_GLOOP)
	if gloop < cost:
		GameManager.add_message("Not enough Space Gloop! Need %d, have %d" % [cost, gloop])
		return
	# Deduct Space Gloop
	WeaponModSystem.remove_materials({GameConstants.CollectibleType.SPACE_GLOOP: cost})
	# Add the item to inventory
	WeaponModSystem.add_material(item["type"], 1)
	GameManager.add_message("🛒 Traded %d Space Gloop for %s!" % [cost, item["name"]])
	# Camera shake
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.08)
	# Audio
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_PICKUP)

func _draw() -> void:
	if _fade_alpha < 0.01:
		return

	var font := get_theme_default_font()
	if not font:
		return

	var a: float = _fade_alpha
	var panel_x: float = 340.0
	var panel_y: float = 120.0
	var panel_w: float = 600.0
	var panel_h: float = 480.0

	# ── Dim background ──
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0, 0, 0, 0.5 * a), true)

	# ── Panel background ──
	var bg := Color(0.05, 0.06, 0.14, 0.95 * a)
	draw_rect(Rect2(panel_x, panel_y, panel_w, panel_h), bg, true)

	# ── Border (warm orange — trader color) ──
	var border_col := Color(1.0, 200.0 / 255.0, 100.0 / 255.0, 0.6 * a)
	draw_rect(Rect2(panel_x, panel_y, panel_w, panel_h), border_col, false, 2.0)

	# ── Title ──
	var trader_name: String = "Trader"
	if _trader and is_instance_valid(_trader) and "trader_name" in _trader:
		trader_name = _trader.trader_name
	font.draw_string(get_canvas_item(),
		Vector2(panel_x + 20, panel_y + 30),
		"🛒 %s's Trade Post" % trader_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
		border_col)

	# Space Gloop balance
	var gloop: int = WeaponModSystem.get_material_count(GameConstants.CollectibleType.SPACE_GLOOP)
	font.draw_string(get_canvas_item(),
		Vector2(panel_x + panel_w - 180, panel_y + 30),
		"Space Gloop: %d 🟢" % gloop, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		Color(0.4, 1.0, 0.4, a))

	# Divider
	draw_line(Vector2(panel_x + 15, panel_y + 45), Vector2(panel_x + panel_w - 15, panel_y + 45),
		Color(1.0, 200.0 / 255.0, 100.0 / 255.0, 0.3 * a), 1.0)

	# ── Items grid ──
	_item_rects.clear()
	var cols: int = 2
	var item_w: float = (panel_w - 50) / cols
	var item_h: float = 70.0
	var start_y: float = panel_y + 60

	for i in range(TRADE_ITEMS.size()):
		var col: int = i % cols
		var row: int = i / cols
		var ix: float = panel_x + 20 + col * (item_w + 10)
		var iy: float = start_y + row * (item_h + 8)

		if iy + item_h > panel_y + panel_h - 40:
			break

		var item: Dictionary = TRADE_ITEMS[i]
		var rect := Rect2(ix, iy, item_w, item_h)
		_item_rects.append(rect)

		# Item background
		var can_afford: bool = gloop >= item["cost"]
		var item_bg_col := Color(0.1, 0.12, 0.22, 0.7 * a)
		if not can_afford:
			item_bg_col = Color(0.15, 0.08, 0.08, 0.5 * a)
		draw_rect(rect, item_bg_col, true)

		# Item border
		var item_border := Color(1.0, 200.0 / 255.0, 100.0 / 255.0, 0.3 * a)
		if can_afford:
			item_border = Color(0.4, 1.0, 0.5, 0.4 * a)
		draw_rect(rect, item_border, false, 1.0)

		# Item icon
		font.draw_string(get_canvas_item(),
			Vector2(ix + 10, iy + 25),
			item["icon"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
			Color(1.0, 0.9, 0.5, a if can_afford else 0.4 * a))

		# Item name
		font.draw_string(get_canvas_item(),
			Vector2(ix + 45, iy + 22),
			item["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
			Color(1.0, 1.0, 1.0, a if can_afford else 0.4 * a))

		# Cost
		font.draw_string(get_canvas_item(),
			Vector2(ix + 45, iy + 42),
			"Cost: %d Space Gloop" % item["cost"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.4, 1.0, 0.4, a if can_afford else 0.5 * a))

		# Buy hint
		font.draw_string(get_canvas_item(),
			Vector2(ix + item_w - 70, iy + 42),
			"[Click to Buy]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.6, 0.7, 0.9, 0.6 * a if can_afford else 0.2 * a))

	# ── Close button ──
	var close_x: float = panel_x + panel_w - 80
	var close_y: float = panel_y + panel_h - 30
	_close_rect = Rect2(close_x, close_y, 70, 22)
	draw_rect(_close_rect, Color(0.3, 0.15, 0.1, 0.8 * a), true)
	draw_rect(_close_rect, border_col, false, 1.0)
	font.draw_string(get_canvas_item(),
		Vector2(close_x + 15, close_y + 16),
		"[Esc] Close", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.8, 0.7, 0.6, a))