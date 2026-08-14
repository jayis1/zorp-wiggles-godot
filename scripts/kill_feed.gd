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
	var is_crit_kill: bool = false  # Enhancement Pack 54: crit kill highlighting
	# ── Scale pop-in ── The entry scales from 0.85 to 1.0 during its
	#    entrance with an ease-out-back curve, giving each kill a subtle
	#    "pop" feel that matches the damage number pop-in and achievement
	#    popup scale language. Without this, the entry only fades + slides
	#    — it reads as informational text appearing rather than a juicy kill
	#    notification. The scale drives the drawn font size so the text
	#    visibly grows as it enters.
	var scale: float = 0.85
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

func _on_enemy_killed(enemy_name: String, killer_name: String, is_crit_kill: bool = false) -> void:
	var entry := KillEntry.new()
	# ── Enhancement Pack 54: Critical kill highlighting ──
	# Crit kills get a gold ✦ prefix and are drawn in gold color so the player
	# can distinguish precision kills from regular kills at a glance. The gold
	# color matches the crit damage number and crit screen flash, creating a
	# consistent "critical hit" color language across the HUD.
	if is_crit_kill:
		entry.text = "✦ %s ▸ %s" % [killer_name, enemy_name]
	else:
		entry.text = "%s ▸ %s" % [killer_name, enemy_name]
	entry.is_crit_kill = is_crit_kill
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
		# ── Scale pop-in ── During the same entrance window, the entry's
		#    scale eases from 0.85 → 1.0 using an ease-out-back curve (slight
		#    overshoot past 1.0 then settle). This gives each kill a subtle
		#    "pop" that matches the damage number pop-in, making the feed feel
		#    like a series of juicy kill notifications rather than a passive
		#    scrolling log. The standard ease-out-back formula
		#    1 + c3*(t-1)^3 + c1*(t-1)^2 (c1=1.70158, c3=c1+1) overshoots ~7%
		#    past 1.0 then settles — the same curve used by the death screen
		#    title and achievement badge.
		if entry.entrance_t < 1.0:
			entry.entrance_t = minf(entry.entrance_t + delta / 0.25, 1.0)
			var eased: float = 1.0 - pow(1.0 - entry.entrance_t, 3.0)
			entry.alpha = eased
			# Scale pop-in via ease-out-back
			var c1: float = 1.70158
			var c3: float = c1 + 1.0
			var tm: float = entry.entrance_t - 1.0
			entry.scale = 1.0 + c3 * tm * tm * tm + c1 * tm * tm
		# Fade out in the last second (overrides the entrance alpha). Uses
		# ease-in quad (life_frac²) so the text holds near-full opacity for
		# most of its life, then fades out gently at the end — matching the
		# HUD message fade (ease-in quad) and the achievement popup exit
		# (ease-in cubic). A linear fade makes the entry visibly dim from
		# the moment the fade window starts, which reads as "dying" too
		# early; the quadratic keeps it readable, then eases out smoothly.
		if entry.timer < 1.0:
			var fade_frac: float = clampf(entry.timer, 0.0, 1.0)
			var eased_fade: float = fade_frac * fade_frac  # ease-in quad
			entry.alpha = eased_fade
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
		# ── Scaled font size ── The entry's scale (0.85 → 1.0 during
		#    entrance) drives the drawn font size so the text visibly grows
		#    as it pops in. This is the simplest way to scale text drawn
		#    via font.draw_string without a Transform2D. The font size is
		#    clamped to a minimum of 8 so very small scales don't break.
		var scaled_font_size: int = max(8, int(float(font_size) * entry.scale))
		var text_size := font.get_string_size(entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_font_size)

		# Right-align the text, offset by the exit slide so the entry
		# accelerates off the right edge as it expires.
		# The scale affects the text width, so we account for it in the
		# right-align x position: center the scaled text within the
		# original-width slot so the pop-in grows from the center outward
		# rather than anchoring to the right edge (which would make the
		# text appear to slide left as it grows).
		var unscaled_size := font.get_string_size(entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var scale_diff: float = (unscaled_size.x - text_size.x) * 0.5
		var x: float = size.x - unscaled_size.x - 10 + entry.exit_slide_x + scale_diff

		# Skip drawing if the entry has fully slid off-screen
		if entry.exit_slide_x >= entry.EXIT_SLIDE_DISTANCE and entry.alpha < 0.01:
			y += line_height
			continue

		# Draw shadow
		var shadow_color := Color(0, 0, 0, entry.alpha * 0.5)
		font.draw_string(get_canvas_item(),
			Vector2(x + 2, y + text_size.y + 2 + entry.y_offset),
			entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_font_size, shadow_color)

		# Draw text with kill feed color
		# ── Enhancement Pack 54: Crit kills in gold ──
		# Critical kill entries use a gold color matching the crit damage
		# numbers (Color(1.0, 0.85, 0.3)), so the player can instantly spot
		# their precision kills in the feed. Non-crit entries keep the
		# standard kill feed color.
		var base_feed_color: Color
		if entry.is_crit_kill:
			base_feed_color = Color(1.0, 0.85, 0.3, 1.0)  # Gold for crit kills
		else:
			base_feed_color = GameConstants.KILL_FEED_COLOR
		var color := Color(base_feed_color.r,
			base_feed_color.g,
			base_feed_color.b,
			base_feed_color.a * entry.alpha)
		font.draw_string(get_canvas_item(),
			Vector2(x, y + text_size.y + entry.y_offset),
			entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_font_size, color)

		y += line_height