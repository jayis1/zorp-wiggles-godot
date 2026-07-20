## Zorp Wiggles — Pet Accessory Menu UI (Phase 27)
## Full-screen overlay showing owned accessories, equipped slots, and crafting.
## Press F6 (the "pet_accessories" input action) to toggle.
## Uses _draw() for rendering + _gui_input() for click detection.

extends Control

class_name PetAccessoryMenuUI

var _visible_flag: bool = false
var _fade_alpha: float = 0.0
var _hovered_accessory: int = -1
var _hovered_slot: int = -1

# Clickable regions
var _craft_rects: Dictionary = {}   # accessory_id → Rect2
var _equip_rects: Dictionary = {}   # accessory_id → Rect2
var _unequip_rects: Dictionary = {} # slot → Rect2
var _close_btn_rect: Rect2 = Rect2()
var _tab_rect: Rect2 = Rect2()

const PANEL_COLOR: Color = Color(0.08, 0.06, 0.12, 0.92)
const BORDER_COLOR: Color = Color(0.4, 0.3, 0.6, 0.8)
const TEXT_COLOR: Color = Color(0.85, 0.85, 0.95)
const HOVER_COLOR: Color = Color(0.2, 0.15, 0.3, 0.8)
const BTN_COLOR: Color = Color(0.25, 0.2, 0.4, 0.9)
const BTN_HOVER_COLOR: Color = Color(0.35, 0.3, 0.5, 1.0)
const GOLD_COLOR: Color = Color(1.0, 0.85, 0.3)
const GREEN_COLOR: Color = Color(0.3, 0.9, 0.4)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if PetAccessorySystem:
		PetAccessorySystem.accessories_changed.connect(_on_changed)
		PetAccessorySystem.accessory_crafted.connect(_on_changed)
		PetAccessorySystem.accessory_equipped.connect(_on_changed)
		PetAccessorySystem.accessory_unequipped.connect(_on_changed)


func _on_changed(_a = null, _b = null) -> void:
	if _fade_alpha > 0.01 or _visible_flag:
		queue_redraw()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pet_accessories"):
		if GameManager and not GameManager.is_paused and GameManager.player_is_alive:
			_visible_flag = not _visible_flag
			AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	# Also close on Esc
	if _visible_flag and Input.is_action_just_pressed("pause"):
		_visible_flag = false
	var target: float = 1.0 if _visible_flag else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 6.0)
	mouse_filter = Control.MOUSE_FILTER_STOP if _fade_alpha > 0.5 else Control.MOUSE_FILTER_IGNORE
	if _fade_alpha > 0.01 or _visible_flag:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not _visible_flag or _fade_alpha < 0.5:
		return
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = event.position
		_hovered_accessory = -1
		_hovered_slot = -1
		for id in _craft_rects:
			if _craft_rects[id].has_point(mouse_pos):
				_hovered_accessory = id
		for id in _equip_rects:
			if _equip_rects[id].has_point(mouse_pos):
				_hovered_accessory = id
		for slot in _unequip_rects:
			if _unequip_rects[slot].has_point(mouse_pos):
				_hovered_slot = slot
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var mouse_pos: Vector2 = event.position
		if _close_btn_rect.has_point(mouse_pos):
			_visible_flag = false
			AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
			return
		# Craft buttons
		for id in _craft_rects:
			if _craft_rects[id].has_point(mouse_pos):
				PetAccessorySystem.craft_accessory(id)
				return
		# Equip buttons
		for id in _equip_rects:
			if _equip_rects[id].has_point(mouse_pos):
				PetAccessorySystem.equip_accessory(id)
				return
		# Unequip buttons
		for slot in _unequip_rects:
			if _unequip_rects[slot].has_point(mouse_pos):
				PetAccessorySystem.unequip_slot(slot)
				return


func _draw() -> void:
	if _fade_alpha < 0.01:
		return
	var alpha: float = _fade_alpha
	var screen_size: Vector2 = get_rect().size
	if screen_size.x < 10:
		screen_size = Vector2(1280, 720)

	# Dim background
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0, 0, 0, 0.7 * alpha))

	var panel_w: float = 800.0
	var panel_h: float = 600.0
	var panel_pos: Vector2 = Vector2((screen_size.x - panel_w) / 2, (screen_size.y - panel_h) / 2)
	var panel_rect: Rect2 = Rect2(panel_pos, Vector2(panel_w, panel_h))
	draw_rect(panel_rect, Color(PANEL_COLOR.r, PANEL_COLOR.g, PANEL_COLOR.b, PANEL_COLOR.a * alpha))
	_draw_border(panel_rect, BORDER_COLOR * alpha)

	# Title
	draw_string(ThemeDB.fallback_font, panel_pos + Vector2(20, 36), "🎀 PET ACCESSORIES",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, TEXT_COLOR * alpha)

	# Close button
	_close_btn_rect = Rect2(panel_pos + Vector2(panel_w - 40, 10), Vector2(30, 30))
	draw_rect(_close_btn_rect, Color(BTN_COLOR.r, BTN_COLOR.g, BTN_COLOR.b, BTN_COLOR.a * alpha))
	draw_string(ThemeDB.fallback_font, _close_btn_rect.position + Vector2(8, 22), "✕",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT_COLOR * alpha)

	var y: float = panel_pos.y + 56

	# ── Equipped slots section ──
	draw_string(ThemeDB.fallback_font, panel_pos + Vector2(20, y + 16), "EQUIPPED:",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD_COLOR * alpha)
	y += 28
	_unequip_rects.clear()
	for slot in range(GameConstants.PET_ACCESSORY_SLOT_COUNT):
		var slot_x: float = panel_pos.x + 20 + float(slot) * 145
		var equipped_id: int = PetAccessorySystem.get_equipped_in_slot(slot)
		var slot_rect: Rect2 = Rect2(Vector2(slot_x, y), Vector2(135, 50))
		var bg_col: Color = Color(0.15, 0.12, 0.2, 0.8 * alpha)
		if _hovered_slot == slot:
			bg_col = HOVER_COLOR * alpha
		draw_rect(slot_rect, bg_col)
		_draw_border(slot_rect, BORDER_COLOR * alpha)
		var slot_name: String = GameConstants.PET_ACCESSORY_SLOT_NAMES[slot]
		if equipped_id != GameConstants.PetAccessory.NONE:
			draw_string(ThemeDB.fallback_font, Vector2(slot_x + 8, y + 18),
				"%s %s" % [GameConstants.PET_ACCESSORY_ICONS[equipped_id], GameConstants.PET_ACCESSORY_NAMES[equipped_id]],
				HORIZONTAL_ALIGNMENT_LEFT, 119, 13, TEXT_COLOR * alpha)
			_unequip_rects[slot] = Rect2(Vector2(slot_x + 8, y + 28), Vector2(119, 16))
			draw_string(ThemeDB.fallback_font, Vector2(slot_x + 8, y + 42),
				"[click to remove]", HORIZONTAL_ALIGNMENT_LEFT, 119, 11,
				Color(0.8, 0.4, 0.4, alpha))
		else:
			draw_string(ThemeDB.fallback_font, Vector2(slot_x + 8, y + 22),
				"%s: empty" % slot_name, HORIZONTAL_ALIGNMENT_LEFT, 119, 14,
				Color(0.5, 0.5, 0.55, alpha))
	y += 60

	# ── Available accessories ──
	draw_string(ThemeDB.fallback_font, panel_pos + Vector2(20, y + 16), "CRAFT & EQUIP:",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD_COLOR * alpha)
	y += 28

	_craft_rects.clear()
	_equip_rects.clear()
	var col_x: float = panel_pos.x + 20
	var entry_w: float = 370.0
	var entry_h: float = 50.0
	var gap: float = 6.0
	var cols: int = 2
	for id in range(1, GameConstants.PET_ACCESSORY_COUNT):
		var col: int = (id - 1) % cols
		var row: int = int(floor(float(id - 1) / float(cols)))
		var ex: float = col_x + float(col) * (entry_w + gap)
		var ey: float = y + float(row) * (entry_h + gap)
		var entry_rect: Rect2 = Rect2(Vector2(ex, ey), Vector2(entry_w, entry_h))
		var owned: bool = PetAccessorySystem.owns_accessory(id)
		var can_craft: bool = PetAccessorySystem.can_craft(id)
		var equipped: bool = false
		for slot_id in PetAccessorySystem.get_all_equipped():
			if slot_id == id:
				equipped = true
				break
		var bg: Color = Color(0.12, 0.1, 0.18, 0.8 * alpha)
		if _hovered_accessory == id:
			bg = HOVER_COLOR * alpha
		draw_rect(entry_rect, bg)
		_draw_border(entry_rect, BORDER_COLOR * alpha)
		# Icon + name
		var icon: String = GameConstants.PET_ACCESSORY_ICONS[id]
		var name: String = GameConstants.PET_ACCESSORY_NAMES[id]
		draw_string(ThemeDB.fallback_font, Vector2(ex + 8, ey + 18),
			"%s %s" % [icon, name], HORIZONTAL_ALIGNMENT_LEFT, entry_w - 16, 14,
			TEXT_COLOR * alpha)
		# Description
		draw_string(ThemeDB.fallback_font, Vector2(ex + 8, ey + 33),
			GameConstants.PET_ACCESSORY_DESCS[id], HORIZONTAL_ALIGNMENT_LEFT,
			entry_w - 100, 11, Color(0.6, 0.6, 0.7, alpha))
		# Button: Craft / Equip / Equipped
		var btn_rect: Rect2 = Rect2(Vector2(ex + entry_w - 90, ey + 10), Vector2(80, 30))
		if equipped:
			draw_rect(btn_rect, Color(0.15, 0.35, 0.2, 0.9 * alpha))
			draw_string(ThemeDB.fallback_font, btn_rect.position + Vector2(18, 20),
				"EQUIPPED", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GREEN_COLOR * alpha)
		elif owned:
			_equip_rects[id] = btn_rect
			var btn_col: Color = BTN_COLOR * alpha
			if _hovered_accessory == id:
				btn_col = BTN_HOVER_COLOR * alpha
			draw_rect(btn_rect, btn_col)
			draw_string(ThemeDB.fallback_font, btn_rect.position + Vector2(22, 20),
				"EQUIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT_COLOR * alpha)
		elif can_craft:
			_craft_rects[id] = btn_rect
			var craft_col: Color = Color(0.3, 0.25, 0.15, 0.9 * alpha)
			if _hovered_accessory == id:
				craft_col = Color(0.4, 0.35, 0.2, 1.0 * alpha)
			draw_rect(btn_rect, craft_col)
			draw_string(ThemeDB.fallback_font, btn_rect.position + Vector2(16, 20),
				"CRAFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD_COLOR * alpha)
		else:
			draw_rect(btn_rect, Color(0.2, 0.15, 0.15, 0.6 * alpha))
			draw_string(ThemeDB.fallback_font, btn_rect.position + Vector2(14, 20),
				"LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.4, 0.4, alpha))

	# Footer hint
	draw_string(ThemeDB.fallback_font, panel_pos + Vector2(20, panel_pos.y + panel_h - 24),
		"F6 to close | Craft with common materials | One per slot",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.5, 0.6, alpha))


func _draw_border(rect: Rect2, color: Color) -> void:
	var w: float = 2.0
	draw_rect(rect, color, false, w)