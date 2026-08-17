## Zorp Wiggles — Gauntlet Mode HUD (Phase 34: Endgame)
## Canvas overlay that shows the current gauntlet biome challenge progress.
## Only visible when EndgameManager.is_gauntlet_active() is true.
##
## Display layout (top-center, below the biome indicator):
##   ⚔ Gauntlet 3/5              ← biome index / total, orange-red
##   Crystal Caverns — 8/15 kills ← current biome name + kill progress
##   ⏱ 42s remaining              ← time left for this biome
##   ▓▓▓▓▓░░░░░░░                 ← dual progress bars (kills + time)
##
## The gauntlet mode tasks the player with killing N enemies in each of 5
## biomes within a time limit. The persistent HUD overlay gives constant
## awareness of the kill goal, time pressure, and overall gauntlet progress,
## matching the visual language of the Endless, Boss Rush, Speedrun, and
## Survival mode HUDs.

extends Control

class_name GauntletHUD

var _fade_alpha: float = 0.0
# ── Biome-change flash ── When a new gauntlet biome challenge starts,
# _biome_flash snaps to 1.0 and decays to 0 over ~0.6s. While > 0, the
# biome text is drawn larger and brighter, giving the transition a
# visible "new round" pulse — matching the wave/boss flash pattern.
var _biome_flash: float = 0.0
var _last_biome_index: int = -1

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_left = -180.0
	offset_top = 70.0
	offset_right = 180.0
	offset_bottom = 140.0
	GameManager.game_restarted.connect(_on_restarted)

func _on_restarted() -> void:
	_fade_alpha = 0.0
	_biome_flash = 0.0
	_last_biome_index = -1

func _process(delta: float) -> void:
	var should_show: bool = false
	if EndgameManager and EndgameManager.is_gauntlet_active():
		should_show = true
	var target: float = 1.0 if should_show else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 6.0)
	# Detect biome index change for flash
	if EndgameManager and EndgameManager.is_gauntlet_active():
		var cur_idx: int = EndgameManager.get_gauntlet_index()
		if cur_idx != _last_biome_index:
			_last_biome_index = cur_idx
			_biome_flash = 1.0
	# Decay the biome flash
	if _biome_flash > 0.0:
		_biome_flash = maxf(0.0, _biome_flash - delta * 1.8)
		queue_redraw()
	if _fade_alpha > 0.01:
		queue_redraw()

func _draw() -> void:
	if _fade_alpha < 0.01:
		return
	if not EndgameManager or not EndgameManager.is_gauntlet_active():
		return
	var font := get_theme_default_font()
	if not font:
		return
	var a: float = _fade_alpha
	var center_x: float = size.x / 2.0
	var flash: float = _biome_flash * _biome_flash * (3.0 - 2.0 * _biome_flash)

	# Current biome info
	var idx: int = EndgameManager.get_gauntlet_index()
	var total: int = GameConstants.GAUNTLET_BIOME_COUNT
	var biome_name: String = EndgameManager.get_gauntlet_current_biome_name()
	var kills: int = EndgameManager.get_gauntlet_kills_this_biome()
	var kill_goal: int = GameConstants.GAUNTLET_KILLS_PER_BIOME
	var biome_timer: float = EndgameManager.get_gauntlet_biome_timer()
	var total_time: float = EndgameManager.get_gauntlet_total_time()

	# Background pill
	var header_text: String = "⚔ Gauntlet %d/%d" % [idx + 1, total]
	var header_font_size: int = int(20 + flash * 5.0)
	var header_size: Vector2 = font.get_string_size(header_text, HORIZONTAL_ALIGNMENT_LEFT, -1, header_font_size)
	var pill_w: float = maxf(header_size.x, 240.0) + 50.0
	var pill_h: float = 90.0
	var pill_rect := Rect2(center_x - pill_w / 2.0, 0.0, pill_w, pill_h)
	draw_rect(pill_rect, Color(0.12, 0.04, 0.02, 0.78 * a), true)
	# Border — glows brighter during flash
	var border_color: Color = Color(
		lerpf(0.9, 1.0, flash),
		lerpf(0.4, 0.6, flash),
		lerpf(0.15, 0.25, flash),
		(0.7 + flash * 0.3) * a
	)
	draw_rect(pill_rect, border_color, false, 1.5 + flash * 1.5)

	# Header text — orange-red, brighter during flash
	var header_color: Color = Color(
		lerpf(1.0, 1.0, flash),
		lerpf(0.5, 0.65, flash),
		lerpf(0.2, 0.3, flash),
		a
	)
	font.draw_string(get_canvas_item(),
		Vector2(center_x - header_size.x / 2.0, 22.0),
		header_text, HORIZONTAL_ALIGNMENT_LEFT, -1, header_font_size,
		header_color)

	# Biome name + kill progress
	var detail_text: String = "%s — %d/%d kills" % [biome_name, kills, kill_goal]
	var detail_size: Vector2 = font.get_string_size(detail_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	font.draw_string(get_canvas_item(),
		Vector2(center_x - detail_size.x / 2.0, 42.0),
		detail_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0.9, 0.8, 0.65, 0.9 * a))

	# Time remaining
	var time_text: String = "⏱ %ds remaining" % int(ceil(biome_timer))
	var time_size: Vector2 = font.get_string_size(time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var time_color: Color
	if biome_timer < 15.0:
		time_color = Color(1.0, 0.3, 0.15, 0.95 * a)
	else:
		time_color = Color(0.85, 0.65, 0.5, 0.85 * a)
	font.draw_string(get_canvas_item(),
		Vector2(center_x - time_size.x / 2.0, 60.0),
		time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		time_color)

	# Dual progress bars — kills (top) and time (bottom)
	var bar_w: float = 220.0
	var bar_h: float = 4.0
	var bar_x: float = center_x - bar_w / 2.0

	# Kill progress bar
	var kill_frac: float = float(kills) / float(kill_goal) if kill_goal > 0 else 0.0
	kill_frac = clampf(kill_frac, 0.0, 1.0)
	draw_rect(Rect2(bar_x, 73.0, bar_w, bar_h), Color(0.15, 0.08, 0.03, 0.6 * a), true)
	if kill_frac > 0:
		draw_rect(Rect2(bar_x, 73.0, bar_w * kill_frac, bar_h), Color(0.9, 0.5, 0.15, 0.9 * a), true)

	# Time progress bar (depleting)
	var time_frac: float = biome_timer / GameConstants.GAUNTLET_TIME_PER_BIOME if GameConstants.GAUNTLET_TIME_PER_BIOME > 0 else 0.0
	time_frac = clampf(time_frac, 0.0, 1.0)
	draw_rect(Rect2(bar_x, 80.0, bar_w, bar_h), Color(0.15, 0.08, 0.03, 0.6 * a), true)
	if time_frac > 0:
		var time_bar_color: Color
		if biome_timer < 15.0:
			time_bar_color = Color(1.0, 0.3, 0.15, 0.9 * a)
		else:
			time_bar_color = Color(0.8, 0.45, 0.2, 0.8 * a)
		draw_rect(Rect2(bar_x, 80.0, bar_w * time_frac, bar_h), time_bar_color, true)