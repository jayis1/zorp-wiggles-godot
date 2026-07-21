## Zorp Wiggles — Control Rebinding Menu (Phase 31: QoL)
## Full-screen overlay that lists all rebindable actions with their current
## key bindings. Click an action to put it in "listening" mode — the next
## key or mouse button pressed becomes the new binding. Press Esc to cancel
## listening or close the menu.
##
## Accessed from the Settings menu (a "Rebind Controls" button opens this).
## The menu is a Control node added as a child of the settings menu's parent.

extends Control

class_name ControlRebindMenu

var _bg: ColorRect
var _panel: Panel
var _title: Label
var _scroll: ScrollContainer
var _list_vbox: VBoxContainer
var _reset_btn: Button
var _back_btn: Button
var _hint_label: Label

# The action currently waiting for a key press ("" = not listening)
var _listening_action: String = ""
# UI element for the listening action (so we can update its text)
var _listening_label: Label = null
# Track hover tweens for buttons
var _hover_tweens: Dictionary = {}
# Track entrance tween
var _entrance_tween: Tween = null
var _animating_out: bool = false

# Each row: { action: String, name_label: Label, key_label: Label, btn: Button }


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.02, 0.0, 0.05, 0.85)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	_panel = Panel.new()
	_panel.offset_left = 240.0
	_panel.offset_top = 60.0
	_panel.offset_right = 1040.0
	_panel.offset_bottom = 720.0
	_panel.pivot_offset = Vector2(400.0, 330.0)
	add_child(_panel)

	_title = Label.new()
	_title.offset_left = 260.0
	_title.offset_top = 80.0
	_title.offset_right = 1020.0
	_title.offset_bottom = 130.0
	_title.text = "⌨  Control Rebinding"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	add_child(_title)

	# Scrollable list of actions
	_scroll = ScrollContainer.new()
	_scroll.offset_left = 280.0
	_scroll.offset_top = 150.0
	_scroll.offset_right = 1000.0
	_scroll.offset_bottom = 600.0
	add_child(_scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list_vbox)

	# Populate the list
	_populate_list()

	# Hint label
	_hint_label = Label.new()
	_hint_label.offset_left = 280.0
	_hint_label.offset_top = 610.0
	_hint_label.offset_right = 1000.0
	_hint_label.offset_bottom = 640.0
	_hint_label.text = "Click a key to rebind  |  Esc to cancel  |  Press a key or mouse button"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.8))
	add_child(_hint_label)

	# Reset button
	_reset_btn = Button.new()
	_reset_btn.offset_left = 380.0
	_reset_btn.offset_top = 650.0
	_reset_btn.offset_right = 580.0
	_reset_btn.offset_bottom = 700.0
	_reset_btn.text = "↺  Reset to Defaults"
	_reset_btn.add_theme_font_size_override("font_size", 16)
	add_child(_reset_btn)
	_reset_btn.pressed.connect(_on_reset)

	# Back button
	_back_btn = Button.new()
	_back_btn.offset_left = 620.0
	_back_btn.offset_top = 650.0
	_back_btn.offset_right = 820.0
	_back_btn.offset_bottom = 700.0
	_back_btn.text = "←  Back"
	_back_btn.add_theme_font_size_override("font_size", 16)
	add_child(_back_btn)
	_back_btn.pressed.connect(_on_back)

	for btn in [_reset_btn, _back_btn]:
		btn.mouse_entered.connect(_on_button_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_button_hover.bind(btn, false))


func _populate_list() -> void:
	# Clear existing rows
	for child in _list_vbox.get_children():
		child.queue_free()
	# Add a row for each rebindable action
	for action in ControlRebind.REBINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)

		var name_lbl := Label.new()
		name_lbl.text = ControlRebind.get_action_display_name(action)
		name_lbl.custom_minimum_size = Vector2(300, 30)
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.95))
		row.add_child(name_lbl)

		var key_btn := Button.new()
		key_btn.text = ControlRebind.get_action_binding_display(action)
		key_btn.custom_minimum_size = Vector2(200, 30)
		key_btn.add_theme_font_size_override("font_size", 14)
		key_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Connect with the action name bound so we know which one was clicked
		key_btn.pressed.connect(_on_key_clicked.bind(action, key_btn))
		key_btn.mouse_entered.connect(_on_button_hover.bind(key_btn, true))
		key_btn.mouse_exited.connect(_on_button_hover.bind(key_btn, false))
		row.add_child(key_btn)

		_list_vbox.add_child(row)


func show_menu() -> void:
	visible = true
	_animating_out = false
	_listening_action = ""
	_listening_label = null
	# Refresh the list to show current bindings
	_populate_list()
	# Entrance animation
	if _entrance_tween and is_instance_valid(_entrance_tween):
		_entrance_tween.kill()
	_bg.modulate.a = 0.0
	_panel.scale = Vector2(0.88, 0.88)
	_panel.modulate.a = 0.0
	_title.modulate.a = 0.0
	_hint_label.modulate.a = 0.0
	for btn in [_reset_btn, _back_btn]:
		btn.modulate.a = 0.0
	_entrance_tween = create_tween()
	_entrance_tween.tween_property(_bg, "modulate:a", 1.0, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_entrance_tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.12)
	_entrance_tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_entrance_tween.tween_property(_title, "modulate:a", 1.0, 0.15) \
		.set_ease(Tween.EASE_OUT)
	_entrance_tween.parallel().tween_property(_hint_label, "modulate:a", 1.0, 0.15)
	for btn in [_reset_btn, _back_btn]:
		_entrance_tween.parallel().tween_property(btn, "modulate:a", 1.0, 0.15)


func _on_key_clicked(action: String, btn: Button) -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	# Enter listening mode for this action
	_listening_action = action
	_listening_label = null  # We update the button text directly
	btn.text = "Press a key..."
	btn.modulate = Color(1.0, 0.95, 0.6)  # Highlight (warm yellow, clamped to 0-1)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# Esc cancels listening or closes the menu
	if event.is_action_pressed("pause") or (event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE):
		if _listening_action != "":
			_listening_action = ""
			_populate_list()  # Refresh to restore original key display
		else:
			_on_back()
		get_viewport().set_input_as_handled()
		return
	# If listening, capture the next key/mouse press as the new binding
	if _listening_action != "" and event is InputEvent and event.is_pressed() and not event.is_echo():
		# Only accept key presses and mouse button presses
		if event is InputEventKey:
			var ke: InputEventKey = event as InputEventKey
			# Ignore pure modifier presses (they're part of a combo, not a binding)
			if ke.keycode == KEY_SHIFT or ke.keycode == KEY_CTRL or ke.keycode == KEY_ALT:
				return
			ControlRebind.rebind_action(_listening_action, ke)
			_listening_action = ""
			_populate_list()
			AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			ControlRebind.rebind_action(_listening_action, event)
			_listening_action = ""
			_populate_list()
			AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
			get_viewport().set_input_as_handled()


func _on_reset() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	ControlRebind.reset_to_defaults()
	_populate_list()


func _on_back() -> void:
	if _animating_out:
		return
	_animating_out = true
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	if _entrance_tween and is_instance_valid(_entrance_tween):
		_entrance_tween.kill()
	_entrance_tween = create_tween()
	_entrance_tween.tween_property(_bg, "modulate:a", 0.0, 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_entrance_tween.parallel().tween_property(_panel, "modulate:a", 0.0, 0.15) \
		.set_ease(Tween.EASE_IN)
	_entrance_tween.parallel().tween_property(_panel, "scale", Vector2(0.9, 0.9), 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_entrance_tween.parallel().tween_property(_title, "modulate:a", 0.0, 0.12)
	_entrance_tween.parallel().tween_property(_hint_label, "modulate:a", 0.0, 0.12)
	for btn in [_reset_btn, _back_btn]:
		_entrance_tween.parallel().tween_property(btn, "modulate:a", 0.0, 0.12)
	_entrance_tween.tween_callback(func():
		visible = false
		_animating_out = false
		_bg.modulate.a = 1.0
		_panel.modulate.a = 1.0
		_panel.scale = Vector2.ONE
		_title.modulate.a = 1.0
		_hint_label.modulate.a = 1.0
		for btn in [_reset_btn, _back_btn]:
			btn.modulate.a = 1.0
			btn.scale = Vector2.ONE
	)


func _on_button_hover(btn: Button, is_hovering: bool) -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	if _hover_tweens.has(btn):
		var existing: Tween = _hover_tweens[btn]
		if is_instance_valid(existing):
			existing.kill()
		_hover_tweens.erase(btn)
	for key in _hover_tweens.keys():
		if not is_instance_valid(key):
			_hover_tweens.erase(key)
	var target_scale := Vector2(1.06, 1.06) if is_hovering else Vector2.ONE
	var tween: Tween = create_tween()
	tween.tween_property(btn, "scale", target_scale, 0.12) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_hover_tweens[btn] = tween
	if is_hovering:
		AudioManager.play_sfx(AudioManager.SFX_UI_HOVER)
