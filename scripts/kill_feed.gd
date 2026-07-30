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
	var entrance_t: float  # 0..1 eased entrance progress
	# ── Exit slide ── When an entry is about to expire (last 0.35s), it
	#    slides right off-screen with an accelerating ease-in curve, mirroring
	#    the entrance slide-down in reverse. This reads as the kill "leaving"
	#    the feed rather than just fading to nothing. The exit slide_x goes
	#    from 0 (resting) to +120px (fully off the right edge). Combined with
	#    the alpha fade, the exit feels like a deliberate "dismiss" rather
	#    than a passive fadeout.
	var exit_slide_x: float = 0.0
	const EXIT_SLIDE_DISTANCE: float = 120.0
	const EXIT_SLIDE_DURATION: float = 0.35

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
	entry.alpha = 0.0  # Start at 0 and ease in for a soft entrance
	entry.y_offset = -20.0  # Slide in from above
	entry.entrance_t = 0.0
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
		# ── Entrance animation: ease the alpha in over ~0.25s with an
		#    ease-out-cubic curve so new kills fade in softly rather than
		#    snapping to full opacity. The slide-down y_offset is already
		#    eased; this adds the matching alpha ease. Matches the
		#    achievement-popup and boss-bar entrance language.
		if entry.entrance_t < 1.0:
			entry.entrance_t = minf(entry.entrance_t + delta / 0.25, 1.0)
			var eased: float = 1.0 - pow(1.0 - entry.entrance_t, 3.0)
			entry.alpha = eased
		# Fade out in the last second (overrides the entrance alpha)
		if entry.timer < 1.0:
			entry.alpha = clampf(entry.timer, 0.0, 1.0)
		# ── Exit slide: in the final EXIT_SLIDE_DURATION, accelerate the
		#    entry rightward off-screen. Uses ease-in cubic (t³) so the
		#    slide starts slow (still readable) and accelerates out, giving
		#    the exit a "whoosh" feel that mirrors the entrance's soft
		#    slide-down. The slide is applied as an x-offset in _draw.
		if entry.timer < entry.EXIT_SLIDE_DURATION:
			var exit_t: float = 1.0 - (entry.timer / entry.EXIT_SLIDE_DURATION)
			exit_t = clampf(exit_t, 0.0, 1.0)
			var eased_exit: float = exit_t * exit_t * exit_t  # ease-in cubic
			entry.exit_slide_x = entry.EXIT_SLIDE_DISTANCE * eased_exit
		else:
			entry.exit_slide_x = 0.0
		# Slide down to position (frame-rate-independent exponential decay)
		entry.y_offset = lerpf(entry.y_offset, 0.0, 1.0 - exp(-8.0 * delta))
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

		# Right-align the text, offset by the exit slide so the entry
		# accelerates off the right edge as it expires.
		var x: float = size.x - text_size.x - 10 + entry.exit_slide_x

		# Skip drawing if the entry has fully slid off-screen
		if entry.exit_slide_x >= entry.EXIT_SLIDE_DISTANCE and entry.alpha < 0.01:
			y += line_height
			continue

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