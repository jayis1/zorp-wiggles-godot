## Zorp Wiggles — Kill Feed (Phase 5: HUD Polish)
## A scrolling list of recent kills shown on the right side of the HUD.
## Each entry shows "Zorp ▸ EnemyName" and fades out after KILL_FEED_LIFETIME.
## Maximum KILL_FEED_MAX_ENTRIES shown at once.

extends Control

class_name KillFeed

# ─── Kill Entry ───────────────────────────────────────────────────────────────
class KillEntry:
	var text: String
	var timer: float
	var alpha: float
	var y_offset: float

# ─── Internal State ───────────────────────────────────────────────────────────
var _entries: Array[KillEntry] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_left = -300
	offset_top = 80
	offset_right = -10
	offset_bottom = 250
	# Connect to kill feed signal
	GameManager.enemy_killed.connect(_on_enemy_killed)

func _on_enemy_killed(enemy_name: String, killer_name: String) -> void:
	var entry := KillEntry.new()
	entry.text = "%s ▸ %s" % [killer_name, enemy_name]
	entry.timer = GameConstants.KILL_FEED_LIFETIME
	entry.alpha = 1.0
	entry.y_offset = -20.0  # Slide in from above
	_entries.append(entry)
	# Cap max entries (remove oldest)
	while _entries.size() > GameConstants.KILL_FEED_MAX_ENTRIES:
		_entries.pop_front()

func _process(delta: float) -> void:
	if _entries.is_empty():
		return

	var needs_redraw: bool = false
	for entry in _entries:
		entry.timer -= delta
		# Fade out in the last second
		if entry.timer < 1.0:
			entry.alpha = clampf(entry.timer, 0.0, 1.0)
		# Slide down to position
		entry.y_offset = lerpf(entry.y_offset, 0.0, 8.0 * delta)
		needs_redraw = true

	# Remove expired entries
	for i in range(_entries.size() - 1, -1, -1):
		if _entries[i].timer <= 0:
			_entries.remove_at(i)

	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	if _entries.is_empty():
		return

	var font := get_theme_default_font()
	if not font:
		return

	var font_size: int = 16
	var line_height: float = 22
	var y: float = 0

	for i in range(_entries.size()):
		var entry: KillEntry = _entries[i]
		var text_size := font.get_string_size(entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

		# Right-align the text
		var x: float = size.x - text_size.x - 10

		# Draw shadow
		var shadow_color := Color(0, 0, 0, entry.alpha * 0.5)
		font.draw_string(get_canvas_item(),
			Vector2(x + 2, y + text_size.y + 2 + entry.y_offset),
			entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow_color)

		# Draw text with kill feed color
		var color := Color(GameConstants.KILL_FEED_COLOR.r,
			GameConstants.KILL_FEED_COLOR.g,
			GameConstants.KILL_FEED_COLOR.b,
			GameConstants.KILL_FEED_COLOR.a * entry.alpha)
		font.draw_string(get_canvas_item(),
			Vector2(x, y + text_size.y + entry.y_offset),
			entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

		y += line_height