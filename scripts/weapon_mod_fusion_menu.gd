## Zorp Wiggles — Weapon Mod Fusion Menu UI (Phase 33: Procedural Content)
##
## Full-screen overlay (child of the crafting menu) for fusing two discovered
## weapon mods into a procedurally-generated fused mod. See weapon_mod_fusion.gd
## for the fusion logic and persistence.
##
## Layout:
##   - Title + cost hint
##   - Left: scrollable list of discovered mods (click to select up to 2)
##   - Right: existing fused mods with equip/unequip + delete buttons
##   - Bottom: Fuse button + Close button
##
## Opened from the crafting menu via the "⚗ Fuse Mods" button.
extends Control

class_name WeaponModFusionMenu

var _bg_panel: Panel
var _selected: Array[int] = []  # Up to 2 selected parent mod IDs
var _selected_buttons: Dictionary = {}  # mod_id -> Button (for highlight refresh)
var _fused_list_container: VBoxContainer
var _cost_label: Label
var _result_label: Label
var _fuse_button: Button

const PANEL_BG_COLOR: Color = Color(0.05, 0.03, 0.12, 0.97)
const PANEL_BORDER_COLOR: Color = Color(0.7, 0.4, 1.0, 0.7)
const SELECTED_COLOR: Color = Color(0.4, 0.2, 0.7, 0.6)
const NORMAL_COLOR: Color = Color(0.15, 0.1, 0.25, 0.6)

func _ready() -> void:
	_build_ui()
	visible = false
	if WeaponModFusion:
		WeaponModFusion.fusion_created.connect(_on_fusion_changed)
		WeaponModFusion.fusion_removed.connect(_on_fusion_changed)
		WeaponModFusion.fusion_equipped.connect(_on_fusion_changed)

func _build_ui() -> void:
	_bg_panel = Panel.new()
	_bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG_COLOR
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = PANEL_BORDER_COLOR
	_bg_panel.add_theme_stylebox_override("panel", sb)
	add_child(_bg_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_CENTER)
	main_vbox.offset_left = -440
	main_vbox.offset_top = -340
	main_vbox.offset_right = 440
	main_vbox.offset_bottom = 340
	main_vbox.add_theme_constant_override("separation", 8)
	_bg_panel.add_child(main_vbox)

	# Title
	var title := Label.new()
	title.text = "⚗ WEAPON MOD FUSION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
	title.add_theme_font_size_override("font_size", 26)
	main_vbox.add_child(title)

	# Cost hint
	_cost_label = Label.new()
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.85))
	_cost_label.add_theme_font_size_override("font_size", 13)
	main_vbox.add_child(_cost_label)

	# Selected mods display
	var selected_label := Label.new()
	selected_label.text = "Select 2 discovered mods to fuse:"
	selected_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	selected_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(selected_label)

	# Two-column layout
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	main_vbox.add_child(columns)

	# Left: discovered mods (clickable to select)
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 4)
	columns.add_child(left_vbox)

	var left_title := Label.new()
	left_title.text = "Discovered Mods"
	left_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	left_title.add_theme_font_size_override("font_size", 16)
	left_vbox.add_child(left_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll)

	var mods_list := VBoxContainer.new()
	mods_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mods_list.add_theme_constant_override("separation", 3)
	scroll.add_child(mods_list)

	# Build a button for each discovered mod (skip NONE)
	for mod_id in WeaponModSystem.get_discovered_mods():
		if mod_id == GameConstants.WeaponMod.NONE:
			continue
		var btn := Button.new()
		var mod_name: String = GameConstants.WEAPON_MOD_NAMES[mod_id]
		var mod_color: Color = GameConstants.WEAPON_MOD_COLORS[mod_id]
		btn.text = " %s" % mod_name
		btn.custom_minimum_size = Vector2(220, 32)
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", mod_color)
		btn.pressed.connect(_on_mod_selected.bind(mod_id))
		mods_list.add_child(btn)
		_selected_buttons[mod_id] = btn

	# Right: existing fused mods
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 4)
	columns.add_child(right_vbox)

	var right_title := Label.new()
	right_title.text = "Fused Mods"
	right_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	right_title.add_theme_font_size_override("font_size", 16)
	right_vbox.add_child(right_title)

	var scroll2 := ScrollContainer.new()
	scroll2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(scroll2)

	_fused_list_container = VBoxContainer.new()
	_fused_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fused_list_container.add_theme_constant_override("separation", 4)
	scroll2.add_child(_fused_list_container)

	# Fuse + close buttons
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(btn_hbox)

	_fuse_button = Button.new()
	_fuse_button.text = "⚗ Fuse Selected"
	_fuse_button.custom_minimum_size = Vector2(180, 38)
	_fuse_button.add_theme_font_size_override("font_size", 15)
	_fuse_button.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
	_fuse_button.disabled = true
	_fuse_button.pressed.connect(_on_fuse_pressed)
	btn_hbox.add_child(_fuse_button)

	var clear_btn := Button.new()
	clear_btn.text = "Clear Selection"
	clear_btn.custom_minimum_size = Vector2(150, 38)
	clear_btn.pressed.connect(_on_clear_pressed)
	btn_hbox.add_child(clear_btn)

	var close_btn := Button.new()
	close_btn.text = "Close (Esc)"
	close_btn.custom_minimum_size = Vector2(140, 38)
	close_btn.pressed.connect(hide_menu)
	btn_hbox.add_child(close_btn)

	# Result label
	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(_result_label)

# ─── Public API ───────────────────────────────────────────────────────────────

func show_menu() -> void:
	visible = true
	_refresh_cost_label()
	_refresh_fused_list()
	_refresh_selection_highlights()
	_update_fuse_button_state()

func hide_menu() -> void:
	visible = false
	_selected.clear()
	if _fuse_button:
		_fuse_button.disabled = true
	_refresh_selection_highlights()

# ─── Selection ───────────────────────────────────────────────────────────────

func _on_mod_selected(mod_id: int) -> void:
	if mod_id in _selected:
		# Deselect
		_selected.erase(mod_id)
	else:
		if _selected.size() >= 2:
			# Replace the oldest selection
			_selected.pop_front()
		_selected.append(mod_id)
	# Play a subtle click sound
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_SHOOT)
	_refresh_selection_highlights()
	_update_fuse_button_state()
	_result_label.text = ""

func _on_clear_pressed() -> void:
	_selected.clear()
	_refresh_selection_highlights()
	_update_fuse_button_state()
	_result_label.text = ""

func _refresh_selection_highlights() -> void:
	for mod_id in _selected_buttons.keys():
		var btn: Button = _selected_buttons[mod_id]
		if mod_id in _selected:
			btn.add_theme_stylebox_override("normal", _make_stylebox(SELECTED_COLOR, 1, Color(0.8, 0.6, 1.0)))
		else:
			btn.remove_theme_stylebox_override("normal")

func _make_stylebox(bg: Color, border_width: int, border_color: Color) -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = border_width
	sb.border_width_right = border_width
	sb.border_width_top = border_width
	sb.border_width_bottom = border_width
	sb.border_color = border_color
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb

func _update_fuse_button_state() -> void:
	if _fuse_button:
		_fuse_button.disabled = _selected.size() != 2

# ─── Fusion Action ────────────────────────────────────────────────────────────

func _on_fuse_pressed() -> void:
	if _selected.size() != 2:
		_result_label.text = "Select exactly 2 mods to fuse."
		_result_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		return
	# Check affordability
	if not WeaponModFusion.can_afford_fusion():
		_result_label.text = "Insufficient materials! Need %d Space Gloop + %d %s." % [
			WeaponModFusion.FUSION_SPACE_GLOOP_COST,
			WeaponModFusion.FUSION_RARE_MAT_COST,
			GameConstants.RARE_MATERIAL_NAMES[WeaponModFusion.FUSION_RARE_MAT_ID] if GameConstants.RARE_MATERIAL_NAMES.size() > WeaponModFusion.FUSION_RARE_MAT_ID else "Rare Material",
		]
		_result_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		return
	var parent_a: int = _selected[0]
	var parent_b: int = _selected[1]
	var new_id: int = WeaponModFusion.fuse_mods(parent_a, parent_b)
	if new_id < 0:
		_result_label.text = "Fusion failed."
		_result_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		return
	var fm = WeaponModFusion.get_fused_mod(new_id)
	if fm:
		_result_label.text = "✦ Created: %s (+%.0f%% bonus)" % [fm.name, fm.bonus * 100.0]
		_result_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
	_selected.clear()
	_refresh_selection_highlights()
	_update_fuse_button_state()
	_refresh_cost_label()
	_refresh_fused_list()

# ─── Fused Mods List ──────────────────────────────────────────────────────────

func _refresh_fused_list() -> void:
	if not _fused_list_container:
		return
	# Clear existing children
	for child in _fused_list_container.get_children():
		child.queue_free()
	var equipped_id: int = WeaponModFusion.get_equipped_fused_id()
	for fm in WeaponModFusion.get_all_fused_mods():
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 4)
		_fused_list_container.add_child(entry)
		# Color swatch + name
		var name_btn := Button.new()
		name_btn.text = " %s" % fm.name
		name_btn.custom_minimum_size = Vector2(180, 30)
		name_btn.add_theme_font_size_override("font_size", 12)
		name_btn.add_theme_color_override("font_color", fm.color)
		name_btn.tooltip_text = fm.description
		entry.add_child(name_btn)
		# Equip/Unequip button
		var equip_btn := Button.new()
		if fm.id == equipped_id:
			equip_btn.text = "Equipped"
			equip_btn.disabled = true
		else:
			equip_btn.text = "Equip"
			equip_btn.pressed.connect(_on_equip_fused.bind(fm.id))
		equip_btn.custom_minimum_size = Vector2(80, 30)
		equip_btn.add_theme_font_size_override("font_size", 11)
		entry.add_child(equip_btn)
		# Delete button
		var del_btn := Button.new()
		del_btn.text = "✕"
		del_btn.custom_minimum_size = Vector2(36, 30)
		del_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		del_btn.pressed.connect(_on_delete_fused.bind(fm.id))
		entry.add_child(del_btn)
	# Empty state
	if WeaponModFusion.get_fused_count() == 0:
		var empty := Label.new()
		empty.text = "No fused mods yet — fuse 2 discovered mods above."
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		empty.add_theme_font_size_override("font_size", 12)
		_fused_list_container.add_child(empty)

func _on_equip_fused(fused_id: int) -> void:
	WeaponModFusion.equip_fused(fused_id)
	_refresh_fused_list()

func _on_delete_fused(fused_id: int) -> void:
	# Unequip if equipped, then remove from registry
	if WeaponModFusion.get_equipped_fused_id() == fused_id:
		WeaponModFusion.unequip_fused()
	# Use the internal remove by calling a public helper
	# We need a public delete method — add one if missing
	if WeaponModFusion.has_method("delete_fused"):
		WeaponModFusion.delete_fused(fused_id)
	_refresh_fused_list()

func _on_fusion_changed(_a = null, _b = null, _c = null) -> void:
	_refresh_fused_list()
	_refresh_cost_label()

# ─── Cost Label ───────────────────────────────────────────────────────────────

func _refresh_cost_label() -> void:
	if not _cost_label:
		return
	var cost: Dictionary = WeaponModFusion.get_fusion_cost()
	var gloop_count: int = 0
	if WeaponModSystem:
		gloop_count = WeaponModSystem.get_material_count(GameConstants.CollectibleType.SPACE_GLOOP)
	var rare_count: int = 0
	if EquipmentSystem:
		rare_count = EquipmentSystem.get_rare_material_count(cost.rare_mat_id)
	var rare_name: String = "Rare Material"
	if GameConstants.RARE_MATERIAL_NAMES.size() > cost.rare_mat_id:
		rare_name = GameConstants.RARE_MATERIAL_NAMES[cost.rare_mat_id]
	_cost_label.text = "Cost: %d Space Gloop (have %d) + %d %s (have %d)  |  Fused: %d/%d" % [
		cost.space_gloop, gloop_count,
		cost.rare_mat_count, rare_name, rare_count,
		WeaponModFusion.get_fused_count(), WeaponModFusion.MAX_FUSED_MODS,
	]

# ─── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_menu()
		get_viewport().set_input_as_handled()