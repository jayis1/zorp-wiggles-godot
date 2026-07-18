## Zorp Wiggles — Dialogue Panel (Phase 26: World Life)
## A CanvasLayer HUD overlay that displays NPC dialogue. Shows the NPC name,
## a typewriter-effect text line, and advances on interact key (T) or auto-
## advances after DIALOGUE_LINE_DISPLAY_TIME seconds. When all lines are
## shown, calls end_dialogue() on the source NPC and hides the panel.
##
## Registered as an autoload singleton so any script can call
## DialoguePanel.show_dialogue(npc_name, lines, npc_node).

extends CanvasLayer

# ─── State ───────────────────────────────────────────────────────────────────
var _npc: Node = null
var _lines: Array = []
var _line_index: int = 0
var _displayed_chars: int = 0
var _char_timer: float = 0.0
var _auto_timer: float = 0.0
var _is_active: bool = false
var _fully_revealed: bool = false

# ─── UI nodes ────────────────────────────────────────────────────────────────
var _panel: Panel
var _name_label: Label
var _text_label: RichTextLabel
var _hint_label: Label
var _bg: ColorRect

func _ready() -> void:
	layer = 90  # Above most UI but below pause menu
	_build_ui()
	_set_visible(false)

func _build_ui() -> void:
	# Semi-transparent full-screen dim backdrop (click-through).
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.35)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# Panel at the bottom-center of the screen.
	_panel = Panel.new()
	var pw: float = GameConstants.DIALOGUE_PANEL_WIDTH
	var ph: float = GameConstants.DIALOGUE_PANEL_HEIGHT
	_panel.size = Vector2(pw, ph)
	_panel.position = Vector2((1280.0 - pw) * 0.5, 720.0 - ph - 40.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Dark semi-transparent style.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.1, 0.92)
	sb.border_color = Color(0.8, 0.7, 0.3, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	# NPC name label (top of panel).
	_name_label = Label.new()
	_name_label.text = ""
	_name_label.position = Vector2(12, 8)
	_name_label.size = Vector2(pw - 24, 28)
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_panel.add_child(_name_label)

	# Dialogue text (middle of panel, supports wrapping).
	_text_label = RichTextLabel.new()
	_text_label.position = Vector2(12, 40)
	_text_label.size = Vector2(pw - 24, ph - 80)
	_text_label.bbcode_enabled = true
	_text_label.fit_content = false
	_text_label.scroll_active = false
	_text_label.add_theme_font_size_override("normal_font_size", 18)
	_text_label.add_theme_color_override("default_color", Color(0.95, 0.95, 1.0))
	_panel.add_child(_text_label)

	# Hint label (bottom of panel).
	_hint_label = Label.new()
	_hint_label.text = "[T] Advance   [Esc] Skip"
	_hint_label.position = Vector2(12, ph - 28)
	_hint_label.size = Vector2(pw - 24, 20)
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_hint_label)

func _process(delta: float) -> void:
	if not _is_active:
		return
	# Typewriter effect.
	if not _fully_revealed:
		_char_timer += delta
		var chars_per_sec: float = GameConstants.DIALOGUE_TEXT_SPEED
		var target_chars: int = int(_char_timer * chars_per_sec)
		if target_chars > _displayed_chars:
			_displayed_chars = target_chars
			_update_text_display()
			if _displayed_chars >= _current_line_length():
				_fully_revealed = true
				_auto_timer = 0.0
	else:
		# Auto-advance timer.
		if GameConstants.DIALOGUE_LINE_DISPLAY_TIME > 0:
			_auto_timer += delta
			if _auto_timer >= GameConstants.DIALOGUE_LINE_DISPLAY_TIME:
				_advance()

func _current_line_length() -> int:
	if _line_index < _lines.size():
		return String(_lines[_line_index]).length()
	return 0

func _update_text_display() -> void:
	if _line_index >= _lines.size():
		return
	var full: String = String(_lines[_line_index])
	var shown: String = full.substr(0, _displayed_chars)
	# Use BBCode with a blinking cursor for the typewriter feel.
	_text_label.text = shown + "[wave amp=10 freq=5][color=yellow]▌[/color][/wave]"

func _set_visible(v: bool) -> void:
	_bg.visible = v
	_panel.visible = v

# ─── Public API ──────────────────────────────────────────────────────────────

func show_dialogue(npc_name: String, lines: Array, npc_node: Node) -> void:
	_npc = npc_node
	_lines = lines
	_line_index = 0
	_displayed_chars = 0
	_char_timer = 0.0
	_auto_timer = 0.0
	_fully_revealed = false
	_is_active = true
	_name_label.text = npc_name
	_set_visible(true)
	_update_text_display()

func is_active() -> bool:
	return _is_active

func _advance() -> void:
	_line_index += 1
	if _line_index >= _lines.size():
		_end()
		return
	_displayed_chars = 0
	_char_timer = 0.0
	_auto_timer = 0.0
	_fully_revealed = false
	_update_text_display()

func _end() -> void:
	_is_active = false
	_set_visible(false)
	if _npc and is_instance_valid(_npc) and _npc.has_method("end_dialogue"):
		_npc.end_dialogue()
	_npc = null
	_lines = []

func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return
	if event.is_action_pressed("interact"):
		# If the current line isn't fully revealed, reveal it instantly.
		if not _fully_revealed:
			_displayed_chars = _current_line_length()
			_update_text_display()
			_fully_revealed = true
			_auto_timer = 0.0
		else:
			_advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		# Skip the entire dialogue.
		_end()
		get_viewport().set_input_as_handled()