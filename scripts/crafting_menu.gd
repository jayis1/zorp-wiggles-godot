## Zorp Wiggles — Crafting Menu UI (Phase 16)
## Full-screen overlay that lets the player combine crafting materials into weapon mods.
## Press C to open/close. Click material buttons to select them (max 3).
## When 2+ materials are selected, the "Craft" button tries the combination.
## Discovered mods appear in a side panel and can be equipped with one click.

extends Control

# ─── Layout Constants ─────────────────────────────────────────────────────────
const PANEL_BG_COLOR: Color = Color(0.05, 0.02, 0.12, 0.92)
const PANEL_BORDER_COLOR: Color = Color(0.4, 0.3, 0.7, 1.0)
const TITLE_COLOR: Color = Color(0.7, 0.5, 1.0)
const MATERIAL_SELECTED_COLOR: Color = Color(0.3, 0.8, 0.4, 0.6)
const MATERIAL_UNSELECTED_COLOR: Color = Color(0.15, 0.1, 0.25, 0.8)
const CRAFT_BUTTON_COLOR: Color = Color(0.4, 0.2, 0.7, 1.0)
const CRAFT_BUTTON_DISABLED_COLOR: Color = Color(0.3, 0.3, 0.3, 0.5)
const EQUIPPED_LABEL_COLOR: Color = Color(0.2, 1.0, 0.4)
const DISCOVERED_NAME_COLOR: Color = Color(0.8, 0.7, 1.0)

# ─── Internal State ───────────────────────────────────────────────────────────
var _selected_materials: Array[int] = []  # CollectibleType values selected for crafting
var _is_open: bool = false
# Set true by _on_mod_crafted when a NEW mod is discovered during a craft_mod()
# call. _on_craft_pressed resets this before calling craft_mod() so it can tell
# whether the craft produced a new discovery (signal fired) or a re-craft (no
# signal). Without this, is_mod_discovered() is always true after craft_mod()
# returns (craft_mod adds the mod before returning), so the "already known"
# text would overwrite the "NEW MOD DISCOVERED" message for genuine discoveries.
var _mod_was_newly_crafted: bool = false

# ─── UI Node References ───────────────────────────────────────────────────────
var _bg_panel: Panel
var _title_label: Label
var _subtitle_label: Label
var _material_grid: GridContainer
var _selected_label: Label
var _craft_button: Button
var _clear_button: Button
var _close_button: Button
var _result_label: Label
var _discovered_panel: Panel
var _discovered_list: VBoxContainer
var _material_buttons: Dictionary = {}  # CollectibleType → Button
var _equipped_name_label: Label

# Track hover tweens so we can kill them before starting a new one (avoid jitter).
# Matches the hover-juice pattern used in main_menu, pause_menu, and death_screen
# so all Button-based menus share a cohesive feel: buttons grow ~6% on hover with
# a quick ease-out quad, and play a subtle UI click sound on enter (not exit).
var _hover_tweens: Dictionary = {}  # button -> Tween

func _ready() -> void:
	# Build the entire UI programmatically (no .tscn needed)
	_build_ui()
	
	# Start hidden
	visible = false
	_is_open = false
	
	# Connect signals
	WeaponModSystem.inventory_changed.connect(_update_inventory_display)
	WeaponModSystem.mod_equipped.connect(_on_mod_equipped)
	WeaponModSystem.mod_crafted.connect(_on_mod_crafted)
	WeaponModSystem.crafting_menu_toggled.connect(_on_menu_toggled)
	
	# Initial inventory display
	_update_inventory_display()

func _build_ui() -> void:
	# Full-screen background panel
	_bg_panel = Panel.new()
	_bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_panel.add_theme_stylebox_override("panel", _make_stylebox(PANEL_BG_COLOR, 2, PANEL_BORDER_COLOR))
	add_child(_bg_panel)
	
	# Main container (centered)
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_CENTER)
	main_vbox.offset_left = -420
	main_vbox.offset_top = -320
	main_vbox.offset_right = 420
	main_vbox.offset_bottom = 320
	main_vbox.add_theme_constant_override("separation", 8)
	_bg_panel.add_child(main_vbox)
	
	# Title
	_title_label = Label.new()
	_title_label.text = "🔧 WEAPON MOD CRAFTING"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	_title_label.add_theme_font_size_override("font_size", 26)
	main_vbox.add_child(_title_label)
	
	# Subtitle (instructions)
	_subtitle_label = Label.new()
	_subtitle_label.text = "Select 2 materials to combine (3 for mega mods). Press C or Esc to close."
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_subtitle_label.add_theme_font_size_override("font_size", 13)
	main_vbox.add_child(_subtitle_label)
	
	# Currently equipped display
	_equipped_name_label = Label.new()
	_equipped_name_label.text = "Equipped: Standard Laser"
	_equipped_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_equipped_name_label.add_theme_color_override("font_color", EQUIPPED_LABEL_COLOR)
	_equipped_name_label.add_theme_font_size_override("font_size", 15)
	main_vbox.add_child(_equipped_name_label)
	
	# Two-column layout: materials (left) + discovered mods (right)
	var columns_hbox := HBoxContainer.new()
	columns_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(columns_hbox)
	
	# Left column: Materials
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 6)
	columns_hbox.add_child(left_vbox)
	
	var mats_title := Label.new()
	mats_title.text = "Materials"
	mats_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	mats_title.add_theme_font_size_override("font_size", 16)
	left_vbox.add_child(mats_title)
	
	# Material grid (2 columns)
	_material_grid = GridContainer.new()
	_material_grid.columns = 2
	_material_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_material_grid.add_theme_constant_override("h_separation", 6)
	_material_grid.add_theme_constant_override("v_separation", 6)
	left_vbox.add_child(_material_grid)
	
	# Build a button for each crafting material type
	for mat_type in GameConstants.CRAFTING_MATERIALS:
		var btn := Button.new()
		var mat_name: String = GameConstants.COLLECTIBLE_TYPE_NAMES.get(mat_type, "???")
		btn.text = "%s\n(x0)" % mat_name.replace("_", " ").capitalize()
		btn.custom_minimum_size = Vector2(180, 50)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_material_button_pressed.bind(mat_type))
		# Hover juice — material buttons get the same scale-up + click-sound
		# treatment as the action buttons for a cohesive feel.
		btn.mouse_entered.connect(_on_button_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_button_hover.bind(btn, false))
		_material_grid.add_child(btn)
		_material_buttons[mat_type] = btn
	
	# Selected materials display
	_selected_label = Label.new()
	_selected_label.text = "Selected: (none)"
	_selected_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	_selected_label.add_theme_font_size_override("font_size", 14)
	left_vbox.add_child(_selected_label)
	
	# Buttons row
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 8)
	left_vbox.add_child(btn_hbox)
	
	_craft_button = Button.new()
	_craft_button.text = " Craft Mod"
	_craft_button.custom_minimum_size = Vector2(140, 36)
	_craft_button.add_theme_font_size_override("font_size", 15)
	_craft_button.disabled = true
	_craft_button.pressed.connect(_on_craft_pressed)
	btn_hbox.add_child(_craft_button)
	
	_clear_button = Button.new()
	_clear_button.text = "Clear"
	_clear_button.custom_minimum_size = Vector2(100, 36)
	_clear_button.pressed.connect(_on_clear_pressed)
	btn_hbox.add_child(_clear_button)

	# ── Phase 33: Weapon Mod Fusion — button to open the fusion sub-menu ──
	var fuse_btn := Button.new()
	fuse_btn.text = "⚗ Fuse Mods"
	fuse_btn.custom_minimum_size = Vector2(130, 36)
	fuse_btn.add_theme_font_size_override("font_size", 14)
	fuse_btn.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
	fuse_btn.pressed.connect(_on_open_fusion_menu)
	btn_hbox.add_child(fuse_btn)
	fuse_btn.mouse_entered.connect(_on_button_hover.bind(fuse_btn, true))
	fuse_btn.mouse_exited.connect(_on_button_hover.bind(fuse_btn, false))
	
	# Result label (shows craft success/failure)
	_result_label = Label.new()
	_result_label.text = ""
	_result_label.add_theme_font_size_override("font_size", 14)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(_result_label)
	
	# Close button
	_close_button = Button.new()
	_close_button.text = "Close (C/Esc)"
	_close_button.custom_minimum_size = Vector2(160, 32)
	_close_button.pressed.connect(_on_close_pressed)
	left_vbox.add_child(_close_button)
	
	# Connect hover signals for the action buttons (craft, clear, close) so
	# they get the same scale-up + click-sound juice as the main/pause menus.
	for btn in [_craft_button, _clear_button, _close_button]:
		btn.mouse_entered.connect(_on_button_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_button_hover.bind(btn, false))
	
	# Right column: Discovered mods
	_discovered_panel = Panel.new()
	_discovered_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_discovered_panel.add_theme_stylebox_override("panel", _make_stylebox(Color(0.08, 0.05, 0.15, 0.6), 1, Color(0.3, 0.2, 0.5, 0.6)))
	columns_hbox.add_child(_discovered_panel)
	
	var disc_vbox := VBoxContainer.new()
	disc_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	disc_vbox.offset_left = 6
	disc_vbox.offset_top = 6
	disc_vbox.offset_right = -6
	disc_vbox.offset_bottom = -6
	disc_vbox.add_theme_constant_override("separation", 4)
	_discovered_panel.add_child(disc_vbox)
	
	var disc_title := Label.new()
	disc_title.text = "Discovered Mods"
	disc_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	disc_title.add_theme_font_size_override("font_size", 16)
	disc_vbox.add_child(disc_title)
	
	# Scrollable list of discovered mods
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	disc_vbox.add_child(scroll)
	
	_discovered_list = VBoxContainer.new()
	_discovered_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_discovered_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_discovered_list)

func _make_stylebox(bg: Color, border_width: int, border_color: Color) -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = border_width
	sb.border_width_right = border_width
	sb.border_width_top = border_width
	sb.border_width_bottom = border_width
	sb.border_color = border_color
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	return sb

# ─── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("crafting"):
		WeaponModSystem.toggle_crafting_menu()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _is_open:
			WeaponModSystem.close_crafting_menu()
			get_viewport().set_input_as_handled()

# ─── Signal Handlers ──────────────────────────────────────────────────────────

func _on_menu_toggled(is_open: bool) -> void:
	_is_open = is_open
	visible = is_open
	if is_open:
		_update_inventory_display()
		_update_discovered_list()
		_update_equipped_label()
		_clear_selection()
		_result_label.text = ""
		# ── Phase 31: Tutorial — first crafting menu open ──
		if TutorialManager and TutorialManager.has_method("notify_crafting_opened"):
			TutorialManager.notify_crafting_opened()
		# Entrance animation: the background panel fades in + scales up from
		# 0.92 with a gentle overshoot. Matches the pause menu's slide-in feel
		# so all overlay menus share a cohesive "juice" language. The panel's
		# pivot is set to center so the scale grows from the middle.
		if _bg_panel:
			_bg_panel.pivot_offset = Vector2(_bg_panel.size.x * 0.5, _bg_panel.size.y * 0.5)
			_bg_panel.modulate.a = 0.0
			_bg_panel.scale = Vector2(0.92, 0.92)
			var tween := create_tween()
			tween.tween_property(_bg_panel, "modulate:a", 1.0, 0.18) \
				.set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(_bg_panel, "scale", Vector2.ONE, 0.28) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Pause game when menu is open (but not if player is dead)
	if GameManager.player_is_alive:
		GameManager.is_paused = is_open
		get_tree().paused = is_open

func _on_mod_equipped(mod_id: int) -> void:
	_update_equipped_label()
	_update_discovered_list()
	var mod_name: String = GameConstants.WEAPON_MOD_NAMES[mod_id]
	_result_label.text = "✓ Equipped: %s" % mod_name
	_result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	if GameManager:
		GameManager.add_message("🔫 Weapon mod equipped: %s" % mod_name)

func _on_mod_crafted(mod_id: int) -> void:
	var mod_name: String = GameConstants.WEAPON_MOD_NAMES[mod_id]
	_result_label.text = "★ NEW MOD DISCOVERED: %s!" % mod_name
	_result_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	# Flag so _on_craft_pressed knows this was a new discovery (not a re-craft).
	# The signal fires synchronously inside craft_mod() before it returns, so
	# _on_craft_pressed can read this flag immediately after the call.
	_mod_was_newly_crafted = true
	if GameManager:
		GameManager.add_message("★ New weapon mod discovered: %s!" % mod_name)

# ─── UI Update Functions ──────────────────────────────────────────────────────

func _update_inventory_display() -> void:
	for mat_type in _material_buttons:
		var btn: Button = _material_buttons[mat_type]
		var count: int = WeaponModSystem.get_material_count(mat_type)
		var mat_name: String = GameConstants.COLLECTIBLE_TYPE_NAMES.get(mat_type, "???")
		var display_name: String = mat_name.replace("_", " ").capitalize()
		btn.text = "%s\n(x%d)" % [display_name, count]
		# Disable button if no materials of this type
		btn.disabled = count <= 0 and not _selected_materials.has(mat_type)
		# Highlight if selected
		if _selected_materials.has(mat_type):
			btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		else:
			btn.remove_theme_color_override("font_color")
	
	# Update selected label
	if _selected_materials.is_empty():
		_selected_label.text = "Selected: (none)"
	else:
		var names: Array[String] = []
		for t in _selected_materials:
			names.append(GameConstants.COLLECTIBLE_TYPE_NAMES.get(t, "???").replace("_", " ").capitalize())
		_selected_label.text = "Selected: %s" % ", ".join(names)
	
	# Enable craft button when 2+ materials are selected
	_craft_button.disabled = _selected_materials.size() < 2

func _update_equipped_label() -> void:
	var mod_name: String = WeaponModSystem.get_equipped_name()
	_equipped_name_label.text = "Equipped: %s" % mod_name

func _update_discovered_list() -> void:
	# Clear existing
	for child in _discovered_list.get_children():
		child.queue_free()
	
	var discovered: Array[int] = WeaponModSystem.get_discovered_mods()
	var equipped: int = WeaponModSystem.get_equipped_mod()
	
	for mod_id in discovered:
		var mod_name: String = GameConstants.WEAPON_MOD_NAMES[mod_id]
		var mod_desc: String = GameConstants.WEAPON_MOD_DESCRIPTIONS[mod_id]
		var mod_color: Color = GameConstants.WEAPON_MOD_COLORS[mod_id]
		
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 6)
		_discovered_list.add_child(entry)
		
		# Color swatch
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.color = mod_color
		entry.add_child(swatch)
		
		# Info label
		var info := Label.new()
		info.text = mod_name
		info.add_theme_color_override("font_color", DISCOVERED_NAME_COLOR)
		info.add_theme_font_size_override("font_size", 13)
		info.tooltip_text = mod_desc
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_child(info)
		
		# Equipped indicator or equip button
		if mod_id == equipped:
			var eq_label := Label.new()
			eq_label.text = "[EQUIPPED]"
			eq_label.add_theme_color_override("font_color", EQUIPPED_LABEL_COLOR)
			eq_label.add_theme_font_size_override("font_size", 11)
			entry.add_child(eq_label)
		else:
			var equip_btn := Button.new()
			equip_btn.text = "Equip"
			equip_btn.custom_minimum_size = Vector2(60, 24)
			equip_btn.add_theme_font_size_override("font_size", 11)
			equip_btn.pressed.connect(_on_equip_mod_pressed.bind(mod_id))
			# Hover juice on dynamically-created equip buttons too.
			equip_btn.mouse_entered.connect(_on_button_hover.bind(equip_btn, true))
			equip_btn.mouse_exited.connect(_on_button_hover.bind(equip_btn, false))
			entry.add_child(equip_btn)

# ─── Button Handlers ──────────────────────────────────────────────────────────

## Hover effect: buttons grow slightly (~6%) on hover and shrink back on exit.
## Mirrors the main/pause/death-screen hover juice so all Button-based menus
## share a cohesive feel. Uses a kill-and-recreate tween pattern to avoid jitter
## from overlapping tweens. Plays a subtle UI click sound on enter only (not exit,
## to avoid sound spam). Disabled buttons are skipped so they don't feel
## interactive. The _hover_tweens dict is cleaned of freed entries opportunistically
## — equip buttons are freed/recreated when the discovered list refreshes, so
## stale entries would otherwise accumulate.
func _on_button_hover(btn: Button, is_hovering: bool) -> void:
	if not is_instance_valid(btn):
		return
	# Skip the grow effect for disabled buttons, but still allow the shrink
	# (exit) to run so a button that was scaled up before being disabled
	# (e.g. a material button that ran out of stock mid-hover) resets cleanly.
	if btn.disabled and is_hovering:
		return
	# Kill any existing hover tween on this button
	if _hover_tweens.has(btn):
		var existing: Tween = _hover_tweens[btn]
		if is_instance_valid(existing):
			existing.kill()
		_hover_tweens.erase(btn)
	# Opportunistic cleanup: drop entries for freed buttons (equip buttons get
	# recreated on each _update_discovered_list call).
	for key in _hover_tweens.keys():
		if not is_instance_valid(key):
			_hover_tweens.erase(key)
	var tween := create_tween()
	var target_scale := Vector2(1.06, 1.06) if is_hovering else Vector2.ONE
	tween.tween_property(btn, "scale", target_scale, 0.12) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_hover_tweens[btn] = tween
	if is_hovering and not btn.disabled:
		AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)

func _on_material_button_pressed(mat_type: int) -> void:
	if _selected_materials.has(mat_type):
		# Deselect
		_selected_materials.erase(mat_type)
	else:
		# Don't select more than 3
		if _selected_materials.size() >= 3:
			return
		# Don't select the same type twice (recipes use different materials)
		_selected_materials.append(mat_type)
	_update_inventory_display()

func _on_craft_pressed() -> void:
	if _selected_materials.size() < 2:
		return
	# Reset the new-discovery flag before crafting. _on_mod_crafted (fired
	# synchronously inside craft_mod when a NEW mod is discovered) sets this
	# to true. We can't use is_mod_discovered() after the call because
	# craft_mod() adds the mod to _discovered_mods before returning, so it
	# would always be true and we couldn't tell new discoveries from re-crafts.
	_mod_was_newly_crafted = false
	var result: int = WeaponModSystem.craft_mod(_selected_materials.duplicate())
	if result >= 0:
		# Success
		# Phase 20: Audio — craft SFX
		AudioManager.play_sfx(AudioManager.SFX_CRAFT)
		var mod_name: String = GameConstants.WEAPON_MOD_NAMES[result]
		# For new discoveries, _on_mod_crafted already set the result label
		# to "★ NEW MOD DISCOVERED" — don't overwrite it. For re-crafts (mod
		# was already known), show the "already known" confirmation.
		if not _mod_was_newly_crafted:
			_result_label.text = "✓ Crafted: %s (already known)" % mod_name
			_result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		_clear_selection()
	else:
		_result_label.text = "✗ Invalid combination! Try another mix."
		_result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_update_inventory_display()

func _on_clear_pressed() -> void:
	_clear_selection()
	_result_label.text = ""
	_update_inventory_display()

func _on_close_pressed() -> void:
	WeaponModSystem.close_crafting_menu()

# ── Phase 33: Weapon Mod Fusion — open the fusion sub-menu ──
# Lazily instantiates the WeaponModFusionMenu Control and opens it. The
# fusion menu is a separate overlay that sits on top of the crafting menu.
var _fusion_menu: Control = null
func _on_open_fusion_menu() -> void:
	if not _fusion_menu:
		_fusion_menu = preload("res://scripts/weapon_mod_fusion_menu.gd").new()
		_fusion_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fusion_menu.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_fusion_menu)
	_fusion_menu.show_menu()

func _on_equip_mod_pressed(mod_id: int) -> void:
	WeaponModSystem.equip_mod(mod_id)

func _clear_selection() -> void:
	_selected_materials.clear()

# ─── Process ──────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	# Keep the inventory display fresh in case materials are collected while open
	if _is_open:
		_update_inventory_display()