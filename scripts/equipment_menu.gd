## Zorp Wiggles — Equipment Menu UI (Phase 29: Crafting & Equipment Expansion)
## Full-screen overlay showing the player's equipment, rare materials, consumables,
## and crafting/refinement options. Press X (the "equipment" input action) to toggle.
##
## Tabs:
##   1. Equipment — equipped slots, owned pieces, craft/upgrade/equip buttons
##   2. Consumables — owned consumables, craft buttons, hotkey hints
##   3. Refine — refine common materials into rare materials
##   4. Materials — rare material inventory display
##
## Uses _draw() for rendering + _gui_input() for click detection (like skill_tree.gd).

extends Control

class_name EquipmentMenuUI

# ─── Tab IDs ──────────────────────────────────────────────────────────────────
const TAB_EQUIPMENT: int = 0
const TAB_CONSUMABLES: int = 1
const TAB_REFINE: int = 2
const TAB_MATERIALS: int = 3
const TAB_COUNT: int = 4
const TAB_NAMES: Array[String] = ["Equipment", "Consumables", "Refine", "Materials"]
const TAB_ICONS: Array[String] = ["🛡", "🧪", "🔬", "💎"]

# ─── Internal State ────────────────────────────────────────────────────────────
var _visible_flag: bool = false
var _fade_alpha: float = 0.0
var _current_tab: int = TAB_EQUIPMENT
var _hovered_piece: int = -1       # Hovered equipment piece ID
var _hovered_consumable: int = -1  # Hovered consumable ID
var _hovered_refine: int = -1      # Hovered refinement recipe ID
var _hovered_tab: int = -1         # Hovered tab header

# Clickable regions (populated in _draw, consumed in _gui_input)
var _tab_rects: Array[Rect2] = []
var _piece_rects: Dictionary = {}   # piece_id → Rect2
var _consumable_rects: Dictionary = {}  # consumable_id → Rect2
var _refine_rects: Dictionary = {}  # rare_material_id → Rect2
var _close_btn_rect: Rect2 = Rect2()
var _equip_btn_rects: Dictionary = {}   # piece_id → Rect2 (equip/unequip button)
var _craft_btn_rects: Dictionary = {}   # piece_id → Rect2 (craft button)
var _upgrade_btn_rects: Dictionary = {} # piece_id → Rect2 (upgrade button)
var _consumable_craft_rects: Dictionary = {}  # consumable_id → Rect2
var _refine_btn_rects: Dictionary = {}  # rare_material_id → Rect2

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Connect to EquipmentSystem signals for live updates
	if EquipmentSystem:
		EquipmentSystem.equipment_changed.connect(_on_changed)
		EquipmentSystem.rare_material_changed.connect(_on_changed)
		EquipmentSystem.consumable_changed.connect(_on_changed)
		EquipmentSystem.equipment_menu_toggled.connect(_on_menu_toggled)

func _on_changed() -> void:
	if _fade_alpha > 0.01 or _visible_flag:
		queue_redraw()

func _on_menu_toggled(is_open: bool) -> void:
	_visible_flag = is_open
	if is_open:
		AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("equipment"):
		if GameManager and not GameManager.is_paused and GameManager.player_is_alive:
			EquipmentSystem.toggle_menu()
	# Smooth fade
	var target: float = 1.0 if _visible_flag else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 6.0)
	# Only accept input when visible enough
	mouse_filter = Control.MOUSE_FILTER_STOP if _fade_alpha > 0.5 else Control.MOUSE_FILTER_IGNORE
	if _fade_alpha > 0.01 or _visible_flag:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not _visible_flag or _fade_alpha < 0.5:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos: Vector2 = event.position
		# Close button
		if _close_btn_rect.has_point(mouse_pos):
			EquipmentSystem.close_menu()
			AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
			return
		# Tab headers
		for i in range(_tab_rects.size()):
			if _tab_rects[i].has_point(mouse_pos):
				_current_tab = i
				AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
				queue_redraw()
				return
		# Tab-specific clicks
		match _current_tab:
			TAB_EQUIPMENT: _handle_equipment_click(mouse_pos)
			TAB_CONSUMABLES: _handle_consumables_click(mouse_pos)
			TAB_REFINE: _handle_refine_click(mouse_pos)
			TAB_MATERIALS: pass  # Display-only tab
	elif event is InputEventMouseMotion:
		var mouse_pos: Vector2 = event.position
		var new_hover_piece: int = -1
		var new_hover_cons: int = -1
		var new_hover_refine: int = -1
		var new_hover_tab: int = -1
		for i in range(_tab_rects.size()):
			if _tab_rects[i].has_point(mouse_pos):
				new_hover_tab = i
				break
		for piece_id in _piece_rects:
			if _piece_rects[piece_id].has_point(mouse_pos):
				new_hover_piece = piece_id
				break
		for cons_id in _consumable_rects:
			if _consumable_rects[cons_id].has_point(mouse_pos):
				new_hover_cons = cons_id
				break
		for rm_id in _refine_rects:
			if _refine_rects[rm_id].has_point(mouse_pos):
				new_hover_refine = rm_id
				break
		if new_hover_piece != _hovered_piece or new_hover_cons != _hovered_consumable \
				or new_hover_refine != _hovered_refine or new_hover_tab != _hovered_tab:
			_hovered_piece = new_hover_piece
			_hovered_consumable = new_hover_cons
			_hovered_refine = new_hover_refine
			_hovered_tab = new_hover_tab
			queue_redraw()

func _handle_equipment_click(mouse_pos: Vector2) -> void:
	# Check equip/unequip buttons
	for piece_id in _equip_btn_rects:
		if _equip_btn_rects[piece_id].has_point(mouse_pos):
			var slot: int = GameConstants.EQUIP_PIECE_SLOT[piece_id]
			if EquipmentSystem.get_equipped_piece(slot) == piece_id:
				EquipmentSystem.unequip_slot(slot)
			else:
				EquipmentSystem.equip_piece(piece_id)
			AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
			return
	# Check craft buttons
	for piece_id in _craft_btn_rects:
		if _craft_btn_rects[piece_id].has_point(mouse_pos):
			EquipmentSystem.craft_piece(piece_id)
			return
	# Check upgrade buttons
	for piece_id in _upgrade_btn_rects:
		if _upgrade_btn_rects[piece_id].has_point(mouse_pos):
			EquipmentSystem.upgrade_piece(piece_id)
			return

func _handle_consumables_click(mouse_pos: Vector2) -> void:
	# Check craft buttons
	for cons_id in _consumable_craft_rects:
		if _consumable_craft_rects[cons_id].has_point(mouse_pos):
			EquipmentSystem.craft_consumable(cons_id)
			return

func _handle_refine_click(mouse_pos: Vector2) -> void:
	# Check refine buttons
	for rm_id in _refine_btn_rects:
		if _refine_btn_rects[rm_id].has_point(mouse_pos):
			EquipmentSystem.refine_material(rm_id)
			return

# ─── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _fade_alpha < 0.01:
		return
	# Clear clickable regions
	_tab_rects.clear()
	_piece_rects.clear()
	_consumable_rects.clear()
	_refine_rects.clear()
	_equip_btn_rects.clear()
	_craft_btn_rects.clear()
	_upgrade_btn_rects.clear()
	_consumable_craft_rects.clear()
	_refine_btn_rects.clear()
	var font := get_theme_default_font()
	if not font:
		return
	var a: float = _fade_alpha
	var screen := size
	# Full-screen dim background
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.03, 0.08, 0.90 * a), true)
	# Main panel
	var panel_x: float = 40.0
	var panel_y: float = 30.0
	var panel_w: float = screen.x - 80.0
	var panel_h: float = screen.y - 60.0
	if panel_w < 600: panel_w = 600
	if panel_h < 400: panel_h = 400
	var panel_rect := Rect2(panel_x, panel_y, panel_w, panel_h)
	draw_rect(panel_rect, Color(0.05, 0.06, 0.12, 0.95 * a), true)
	draw_rect(panel_rect, Color(0.5, 0.4, 0.8, 0.5 * a), false, 2.0)
	# Title
	_draw_centered_text(font, "🛡 EQUIPMENT & CRAFTING", Vector2(screen.x / 2.0, panel_y + 28), 26,
		Color(0.8, 0.6, 1.0, a))
	# Active set name
	var set_name: String = EquipmentSystem.get_active_set_name() if EquipmentSystem else "None"
	_draw_centered_text(font, "Set: %s" % set_name, Vector2(screen.x / 2.0, panel_y + 52), 14,
		Color(0.7, 0.7, 0.9, a))
	# Close button (top-right)
	var close_w: float = 80.0
	_close_btn_rect = Rect2(panel_x + panel_w - close_w - 20, panel_y + 15, close_w, 30)
	_draw_button(font, _close_btn_rect, "✖ Close", a)
	# Tab headers
	var tab_w: float = 140.0
	var tab_h: float = 32.0
	var tab_y: float = panel_y + 70
	var tab_total_w: float = tab_w * TAB_COUNT + 20 * (TAB_COUNT - 1)
	var tab_start_x: float = panel_x + (panel_w - tab_total_w) / 2.0
	for i in range(TAB_COUNT):
		var tab_rect := Rect2(tab_start_x + i * (tab_w + 20), tab_y, tab_w, tab_h)
		_tab_rects.append(tab_rect)
		var is_current: bool = (i == _current_tab)
		var is_hovered: bool = (i == _hovered_tab)
		var bg: Color
		if is_current:
			bg = Color(0.3, 0.2, 0.5, 0.8 * a)
		elif is_hovered:
			bg = Color(0.2, 0.15, 0.35, 0.7 * a)
		else:
			bg = Color(0.1, 0.08, 0.2, 0.6 * a)
		draw_rect(tab_rect, bg, true)
		draw_rect(tab_rect, Color(0.5, 0.4, 0.8, (0.8 if is_current else 0.3) * a), false, 1.5)
		_draw_centered_text(font, "%s  %s" % [TAB_ICONS[i], TAB_NAMES[i]],
			Vector2(tab_rect.position.x + tab_rect.size.x / 2.0, tab_rect.position.y + tab_rect.size.y / 2.0),
			14, Color(1.0, 1.0, 1.0, a))
	# Tab content area
	var content_y: float = tab_y + tab_h + 15
	var content_h: float = panel_y + panel_h - content_y - 20
	var content_rect := Rect2(panel_x + 20, content_y, panel_w - 40, content_h)
	draw_rect(content_rect, Color(0.04, 0.05, 0.1, 0.5 * a), true)
	# Draw the current tab's content
	match _current_tab:
		TAB_EQUIPMENT: _draw_equipment_tab(font, content_rect, a)
		TAB_CONSUMABLES: _draw_consumables_tab(font, content_rect, a)
		TAB_REFINE: _draw_refine_tab(font, content_rect, a)
		TAB_MATERIALS: _draw_materials_tab(font, content_rect, a)
	# Footer hint
	_draw_centered_text(font, "[X] Close  |  Click tabs to switch  |  1-5 to use consumables",
		Vector2(screen.x / 2.0, panel_y + panel_h - 12), 12,
		Color(0.5, 0.55, 0.7, 0.7 * a))

# ─── Equipment Tab ────────────────────────────────────────────────────────────

func _draw_equipment_tab(font, rect: Rect2, a: float) -> void:
	# Three columns: Head, Body, Accessory
	var col_margin: float = 15.0
	var col_w: float = (rect.size.x - col_margin * 4) / 3.0
	var col_y: float = rect.position.y + 15
	var col_h: float = rect.size.y - 30
	var slot_names: Array[String] = ["Head", "Body", "Accessory"]
	for slot in range(GameConstants.EQUIP_SLOT_COUNT):
		var col_x: float = rect.position.x + col_margin + slot * (col_w + col_margin)
		_draw_equipment_column(font, slot, slot_names[slot], col_x, col_y, col_w, col_h, a)

func _draw_equipment_column(font, slot: int, slot_name: String, x: float, y: float, w: float, h: float, a: float) -> void:
	# Column background
	var col_rect := Rect2(x, y, w, h)
	draw_rect(col_rect, Color(0.08, 0.09, 0.15, 0.6 * a), true)
	draw_rect(col_rect, Color(0.4, 0.3, 0.6, 0.3 * a), false, 1.0)
	# Header
	_draw_centered_text(font, slot_name, Vector2(x + w / 2.0, y + 22), 18,
		Color(0.8, 0.7, 1.0, a))
	# Currently equipped piece
	var equipped_id: int = EquipmentSystem.get_equipped_piece(slot) if EquipmentSystem else -1
	if equipped_id >= 0:
		_draw_centered_text(font, "Equipped: %s +%d" % [
			GameConstants.EQUIP_PIECE_NAMES[equipped_id],
			EquipmentSystem.get_piece_upgrade_level(equipped_id)
		], Vector2(x + w / 2.0, y + 45), 13,
		Color(0.3, 1.0, 0.5, a))
	else:
		_draw_centered_text(font, "(empty)", Vector2(x + w / 2.0, y + 45), 13,
		Color(0.4, 0.4, 0.4, a))
	# List all pieces in this slot
	var piece_y: float = y + 70
	var piece_h: float = 95.0
	var piece_spacing: float = 8.0
	for piece_id in range(GameConstants.EQUIP_PIECE_SLOT.size()):
		if GameConstants.EQUIP_PIECE_SLOT[piece_id] != slot:
			continue
		var piece_rect := Rect2(x + 10, piece_y, w - 20, piece_h)
		_piece_rects[piece_id] = piece_rect
		_draw_piece_card(font, piece_id, piece_rect, a, equipped_id == piece_id)
		piece_y += piece_h + piece_spacing
		if piece_y + piece_h > y + h:
			break

func _draw_piece_card(font, piece_id: int, rect: Rect2, a: float, is_equipped: bool) -> void:
	var rarity: int = GameConstants.EQUIP_PIECE_RARITY[piece_id]
	var rarity_color: Color = GameConstants.EQUIP_RARITY_COLORS[rarity]
	var is_owned: bool = EquipmentSystem.owns_piece(piece_id) if EquipmentSystem else false
	var is_hovered: bool = (_hovered_piece == piece_id)
	# Background
	var bg: Color
	if is_equipped:
		bg = Color(0.15, 0.2, 0.12, 0.8 * a)
	elif is_owned:
		bg = Color(0.12, 0.1, 0.2, 0.7 * a)
	else:
		bg = Color(0.06, 0.07, 0.1, 0.5 * a)
	draw_rect(rect, bg, true)
	# Border (rarity-colored)
	var border_color: Color = rarity_color
	var border_width: float = 2.0 if (is_equipped or is_hovered) else 1.0
	draw_rect(rect, Color(border_color.r, border_color.g, border_color.b, 0.7 * a), false, border_width)
	if is_hovered:
		draw_rect(rect, Color(1.0, 1.0, 1.0, 0.08 * a), true)
	# Icon + name
	var icon: String = GameConstants.EQUIP_PIECE_ICONS[piece_id]
	var name_text: String = GameConstants.EQUIP_PIECE_NAMES[piece_id]
	var upgrade_lvl: int = EquipmentSystem.get_piece_upgrade_level(piece_id) if EquipmentSystem else 0
	if upgrade_lvl > 0:
		name_text += " +%d" % upgrade_lvl
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + 8, rect.position.y + 20),
		"%s  %s" % [icon, name_text], HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(rarity_color.r, rarity_color.g, rarity_color.b, a))
	# Rarity label
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + rect.size.x - 8, rect.position.y + 20),
		GameConstants.EQUIP_RARITY_NAMES[rarity], HORIZONTAL_ALIGNMENT_RIGHT, -1, 11,
		Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.8 * a))
	# Stats
	var stats: Dictionary = GameConstants.EQUIP_PIECE_STATS[piece_id]
	var stat_lines: Array[String] = []
	for key in stats:
		stat_lines.append("%s: +%s" % [key, _format_stat(key, stats[key])])
	var stat_text: String = ", ".join(stat_lines)
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + 8, rect.position.y + 40),
		stat_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.65, 0.7, 0.8, 0.9 * a))
	# Action button (equip/unequip, craft, or upgrade)
	var btn_w: float = 70.0
	var btn_h: float = 22.0
	var btn_rect := Rect2(rect.position.x + 8, rect.position.y + rect.size.y - btn_h - 8, btn_w, btn_h)
	if is_equipped:
		_equip_btn_rects[piece_id] = btn_rect
		_draw_button(font, btn_rect, "Unequip", a, Color(0.5, 0.3, 0.3))
	elif is_owned:
		_equip_btn_rects[piece_id] = btn_rect
		_draw_button(font, btn_rect, "Equip", a, Color(0.2, 0.4, 0.3))
		# Upgrade button (if not maxed)
		if upgrade_lvl < GameConstants.EQUIP_MAX_UPGRADE_LEVEL:
			var up_rect := Rect2(rect.position.x + btn_w + 16, rect.position.y + rect.size.y - btn_h - 8, btn_w, btn_h)
			_upgrade_btn_rects[piece_id] = up_rect
			_draw_button(font, up_rect, "Upgrade", a, Color(0.3, 0.3, 0.5))
	else:
		# Craft button (shows cost)
		_craft_btn_rects[piece_id] = btn_rect
		_draw_button(font, btn_rect, "Craft", a, Color(0.3, 0.2, 0.5))

func _format_stat(key: String, value: float) -> String:
	if key == "max_hp":
		return str(int(value))
	# Percent stats
	return "%.0f%%" % (value * 100.0)

# ─── Consumables Tab ───────────────────────────────────────────────────────────

func _draw_consumables_tab(font, rect: Rect2, a: float) -> void:
	_draw_centered_text(font, "🧪 Craft and use consumables. Press 1-5 to use in game.",
		Vector2(rect.position.x + rect.size.x / 2.0, rect.position.y + 25), 14,
		Color(0.7, 0.8, 1.0, a))
	var card_w: float = (rect.size.x - 60) / 3.0
	var card_h: float = 110.0
	var card_spacing: float = 15.0
	var start_x: float = rect.position.x + 20
	var start_y: float = rect.position.y + 55
	for i in range(5):  # 5 consumable types
		var col: int = i % 3
		var row: int = i / 3
		var card_rect := Rect2(start_x + col * (card_w + card_spacing), start_y + row * (card_h + card_spacing), card_w, card_h)
		_consumable_rects[i] = card_rect
		_draw_consumable_card(font, i, card_rect, a)

func _draw_consumable_card(font, cons_id: int, rect: Rect2, a: float) -> void:
	var color: Color = GameConstants.CONSUMABLE_COLORS[cons_id]
	var is_hovered: bool = (_hovered_consumable == cons_id)
	# Background
	draw_rect(rect, Color(0.08, 0.09, 0.15, 0.7 * a), true)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.6 * a), false, 2.0 if is_hovered else 1.0)
	if is_hovered:
		draw_rect(rect, Color(1.0, 1.0, 1.0, 0.08 * a), true)
	# Icon + name
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + 8, rect.position.y + 22),
		"%s  %s" % [GameConstants.CONSUMABLE_ICONS[cons_id], GameConstants.CONSUMABLE_NAMES[cons_id]],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(color.r, color.g, color.b, a))
	# Count
	var count: int = EquipmentSystem.get_consumable_count(cons_id) if EquipmentSystem else 0
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + rect.size.x - 8, rect.position.y + 22),
		"x%d" % count, HORIZONTAL_ALIGNMENT_RIGHT, -1, 14,
		Color(1.0, 1.0, 1.0, a))
	# Hotkey hint
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + 8, rect.position.y + 42),
		"Hotkey: %d" % (cons_id + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.6, 0.65, 0.75, a))
	# Effect description
	var dur: float = GameConstants.CONSUMABLE_EFFECT_DURATION[cons_id]
	var val: float = GameConstants.CONSUMABLE_EFFECT_VALUE[cons_id]
	var effect_text: String
	if dur > 0:
		effect_text = "+%.0f%% for %.0fs" % [val * 100.0, dur]
	elif cons_id == GameConstants.Consumable.HEALTH_POTION:
		effect_text = "Heal %d HP" % int(val)
	else:
		effect_text = "AoE %d dmg" % int(val)
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + 8, rect.position.y + 60),
		effect_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.7, 0.75, 0.85, a))
	# Craft button
	var btn_rect := Rect2(rect.position.x + 8, rect.position.y + rect.size.y - 28, 80, 22)
	_consumable_craft_rects[cons_id] = btn_rect
	_draw_button(font, btn_rect, "Craft", a, Color(0.2, 0.3, 0.5))

# ─── Refine Tab ───────────────────────────────────────────────────────────────

func _draw_refine_tab(font, rect: Rect2, a: float) -> void:
	_draw_centered_text(font, "🔬 Refine 3 common materials into 1 rare material",
		Vector2(rect.position.x + rect.size.x / 2.0, rect.position.y + 25), 14,
		Color(0.7, 0.8, 1.0, a))
	var card_w: float = (rect.size.x - 70) / 4.0
	var card_h: float = 95.0
	var card_spacing: float = 15.0
	var start_x: float = rect.position.x + 20
	var start_y: float = rect.position.y + 55
	# Show all refinement recipes (single + dual)
	var all_recipes: Array = []
	for rm_id in GameConstants.REFINEMENT_RECIPES:
		all_recipes.append(rm_id)
	for rm_id in GameConstants.REFINEMENT_RECIPES_DUAL:
		all_recipes.append(rm_id)
	for i in range(all_recipes.size()):
		var rm_id: int = all_recipes[i]
		var col: int = i % 4
		var row: int = i / 4
		var card_rect := Rect2(start_x + col * (card_w + card_spacing), start_y + row * (card_h + card_spacing), card_w, card_h)
		_refine_rects[rm_id] = card_rect
		_draw_refine_card(font, rm_id, card_rect, a)

func _draw_refine_card(font, rm_id: int, rect: Rect2, a: float) -> void:
	var color: Color = GameConstants.RARE_MATERIAL_COLORS[rm_id]
	var is_hovered: bool = (_hovered_refine == rm_id)
	# Background
	draw_rect(rect, Color(0.08, 0.09, 0.15, 0.7 * a), true)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.6 * a), false, 2.0 if is_hovered else 1.0)
	if is_hovered:
		draw_rect(rect, Color(1.0, 1.0, 1.0, 0.08 * a), true)
	# Name
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + 8, rect.position.y + 20),
		GameConstants.RARE_MATERIAL_NAMES[rm_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(color.r, color.g, color.b, a))
	# Owned count
	var count: int = EquipmentSystem.get_rare_material_count(rm_id) if EquipmentSystem else 0
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + rect.size.x - 8, rect.position.y + 20),
		"x%d" % count, HORIZONTAL_ALIGNMENT_RIGHT, -1, 13,
		Color(1.0, 1.0, 1.0, a))
	# Recipe cost
	var cost_text: String = _get_refine_cost_text(rm_id)
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + 8, rect.position.y + 42),
		cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.65, 0.7, 0.8, a))
	# Refine button
	var btn_rect := Rect2(rect.position.x + 8, rect.position.y + rect.size.y - 26, 70, 20)
	_refine_btn_rects[rm_id] = btn_rect
	_draw_button(font, btn_rect, "Refine", a, Color(0.2, 0.4, 0.5))

func _get_refine_cost_text(rm_id: int) -> String:
	if GameConstants.REFINEMENT_RECIPES.has(rm_id):
		var recipe: Dictionary = GameConstants.REFINEMENT_RECIPES[rm_id]
		var mat_name: String = GameConstants.COLLECTIBLE_TYPE_NAMES.get(recipe["mat"], "?")
		return "%d %s" % [recipe["count"], mat_name]
	if GameConstants.REFINEMENT_RECIPES_DUAL.has(rm_id):
		var recipe: Dictionary = GameConstants.REFINEMENT_RECIPES_DUAL[rm_id]
		var mats: Array = recipe["mats"]
		var m1: String = GameConstants.COLLECTIBLE_TYPE_NAMES.get(mats[0], "?")
		var m2: String = GameConstants.COLLECTIBLE_TYPE_NAMES.get(mats[1], "?")
		return "%d %s + %d %s" % [recipe["count"], m1, recipe["count"], m2]
	return "?"

# ─── Materials Tab ────────────────────────────────────────────────────────────

func _draw_materials_tab(font, rect: Rect2, a: float) -> void:
	_draw_centered_text(font, "💎 Rare Material Inventory",
		Vector2(rect.position.x + rect.size.x / 2.0, rect.position.y + 25), 16,
		Color(0.8, 0.7, 1.0, a))
	var card_w: float = (rect.size.x - 70) / 4.0
	var card_h: float = 75.0
	var card_spacing: float = 12.0
	var start_x: float = rect.position.x + 20
	var start_y: float = rect.position.y + 55
	for i in range(GameConstants.RARE_MATERIAL_NAMES.size()):
		var col: int = i % 4
		var row: int = i / 4
		var card_rect := Rect2(start_x + col * (card_w + card_spacing), start_y + row * (card_h + card_spacing), card_w, card_h)
		_draw_material_card(font, i, card_rect, a)

func _draw_material_card(font, rm_id: int, rect: Rect2, a: float) -> void:
	var color: Color = GameConstants.RARE_MATERIAL_COLORS[rm_id]
	var count: int = EquipmentSystem.get_rare_material_count(rm_id) if EquipmentSystem else 0
	# Background
	draw_rect(rect, Color(0.08, 0.09, 0.15, 0.7 * a), true)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.5 * a), false, 1.0)
	# Name
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + 8, rect.position.y + 22),
		GameConstants.RARE_MATERIAL_NAMES[rm_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(color.r, color.g, color.b, a))
	# Count (large)
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + rect.size.x - 8, rect.position.y + 22),
		"x%d" % count, HORIZONTAL_ALIGNMENT_RIGHT, -1, 16,
		Color(1.0, 1.0, 1.0, a) if count > 0 else Color(0.4, 0.4, 0.4, a))
	# Source hint
	var source: String = _get_material_source(rm_id)
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + 8, rect.position.y + 45),
		source, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.5, 0.55, 0.65, 0.7 * a))

func _get_material_source(rm_id: int) -> String:
	if GameConstants.RARE_MATERIAL_BOSS_DROPS.has(rm_id):
		return "Boss drop"
	for w in GameConstants.RARE_MATERIAL_WEATHER_DROPS.values():
		if w == rm_id:
			return "Weather drop"
	for b in GameConstants.RARE_MATERIAL_BIOME_DROPS.values():
		if b == rm_id:
			return "Biome drop"
	return "Refine"

# ─── Drawing Helpers ───────────────────────────────────────────────────────────

func _draw_button(font, rect: Rect2, text: String, a: float, color: Color = Color(0.2, 0.3, 0.5)) -> void:
	draw_rect(rect, Color(color.r, color.g, color.b, 0.6 * a), true)
	draw_rect(rect, Color(color.r + 0.2, color.g + 0.2, color.b + 0.2, 0.8 * a), false, 1.5)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + (rect.size.x - text_size.x) / 2.0,
		        rect.position.y + (rect.size.y + text_size.y) / 2.0 - 2),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(1.0, 1.0, 1.0, a))

func _draw_centered_text(font, text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	font.draw_string(get_canvas_item(),
		Vector2(pos.x - text_size.x / 2.0, pos.y + text_size.y / 2.0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)