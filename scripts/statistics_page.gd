## Zorp Wiggles — Statistics Page UI (Phase 25: Progression & Meta-Systems)
## Full-screen overlay showing lifetime and session statistics.
## Press F2 (the "stats_page" input action) to toggle.
## Draws a tabbed panel with:
##   Tab 1: Session — current run stats
##   Tab 2: Lifetime — all-time stats (persisted)
##   Tab 3: Combat — kill breakdowns by enemy type, boss kills
##   Tab 4: Exploration — biome time, distance, items collected
## Uses _draw() for custom rendering — no scene file needed.

extends Control

class_name StatisticsPage

var _visible_flag: bool = false
var _fade_alpha: float = 0.0
var _current_tab: int = 0
const TAB_NAMES: Array[String] = ["Session", "Lifetime", "Combat", "Exploration"]
const TAB_ICONS: Array[String] = ["📊", "♾", "⚔", "🧭"]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Refresh when stats update
	if Statistics:
		Statistics.stats_updated.connect(_on_stats_updated)

func _on_stats_updated() -> void:
	if _fade_alpha > 0.01 or _visible_flag:
		queue_redraw()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("stats_page"):
		_visible_flag = not _visible_flag
		if _visible_flag:
			AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	# Tab switching with 1-4 keys when visible
	if _visible_flag:
		if Input.is_key_pressed(KEY_1): _current_tab = 0
		elif Input.is_key_pressed(KEY_2): _current_tab = 1
		elif Input.is_key_pressed(KEY_3): _current_tab = 2
		elif Input.is_key_pressed(KEY_4): _current_tab = 3
	# Smooth fade
	var target: float = 1.0 if _visible_flag else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 6.0)
	if _fade_alpha > 0.01 or _visible_flag:
		queue_redraw()

func _draw() -> void:
	if _fade_alpha < 0.01:
		return
	var font := get_theme_default_font()
	if not font:
		return
	var a: float = _fade_alpha
	var screen := size
	# Full-screen dim background
	var bg := Color(0.02, 0.03, 0.08, 0.88 * a)
	draw_rect(Rect2(Vector2.ZERO, screen), bg, true)
	# Main panel
	var panel_x: float = 100.0
	var panel_y: float = 60.0
	var panel_w: float = screen.x - 200.0
	var panel_h: float = screen.y - 120.0
	if panel_w < 400: panel_w = 400
	if panel_h < 300: panel_h = 300
	var panel_rect := Rect2(panel_x, panel_y, panel_w, panel_h)
	var panel_bg := Color(0.05, 0.06, 0.12, 0.95 * a)
	draw_rect(panel_rect, panel_bg, true)
	# Border
	var border := Color(0.3, 0.6, 1.0, 0.6 * a)
	draw_rect(panel_rect, border, false, 2.0)
	# Title
	var title_y: float = panel_y + 35
	_draw_centered_text(font, "📊 STATISTICS", Vector2(screen.x / 2.0, title_y), 28,
		Color(0.4, 0.8, 1.0, a))
	# Tab bar
	var tab_y: float = panel_y + 60
	var tab_w: float = (panel_w - 40) / float(TAB_NAMES.size())
	for i in range(TAB_NAMES.size()):
		var tx: float = panel_x + 20 + i * tab_w
		var tab_rect := Rect2(tx, tab_y, tab_w - 4, 36)
		var tab_bg: Color
		if i == _current_tab:
			tab_bg = Color(0.2, 0.4, 0.7, 0.6 * a)
		else:
			tab_bg = Color(0.1, 0.12, 0.2, 0.4 * a)
		draw_rect(tab_rect, tab_bg, true)
		draw_rect(tab_rect, Color(0.3, 0.5, 0.8, 0.4 * a), false, 1.0)
		var label: String = "%s  %s" % [TAB_ICONS[i], TAB_NAMES[i]]
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		font.draw_string(get_canvas_item(),
			Vector2(tx + (tab_w - 4) / 2.0 - label_size.x / 2.0, tab_y + 24),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color(1.0, 1.0, 1.0, a))
	# Content area
	var content_y: float = tab_y + 50
	var content_h: float = panel_y + panel_h - content_y - 20
	var content_rect := Rect2(panel_x + 20, content_y, panel_w - 40, content_h)
	# Clip content
	# (Godot 4 _draw doesn't have easy clipping; we just render within bounds)
	match _current_tab:
		0: _draw_session_tab(font, content_rect, a)
		1: _draw_lifetime_tab(font, content_rect, a)
		2: _draw_combat_tab(font, content_rect, a)
		3: _draw_exploration_tab(font, content_rect, a)
	# Footer hint
	_draw_centered_text(font, "[1-4] Switch Tabs  |  [F2] Close",
		Vector2(screen.x / 2.0, panel_y + panel_h - 15), 13,
		Color(0.5, 0.55, 0.7, 0.7 * a))

# ─── Tab Renderers ────────────────────────────────────────────────────────────

func _draw_session_tab(font, rect: Rect2, a: float) -> void:
	var s: Dictionary = Statistics.get_session()
	var y: float = rect.position.y + 10
	var line_h: float = 28
	var col_x: float = rect.position.x + 30
	var val_x: float = rect.position.x + rect.size.x - 200
	_draw_section_header(font, "Current Run", rect.position.x + 20, y, a)
	y += 35
	var lines: Array = [
		["Time Survived", Statistics.format_time(float(s.get("time_played", 0.0)))],
		["Score", str(int(s.get("max_score", 0)))],
		["Level", str(GameManager.player_level)],
		["Kills", str(int(s.get("kills", 0)))],
		["Best Combo", "x%d" % int(s.get("max_combo", 0))],
		["Distance Traveled", Statistics.format_distance(float(s.get("distance_traveled", 0.0)))],
		["Shots Fired", str(int(s.get("shots_fired", 0)))],
		["Dashes", str(int(s.get("dashes", 0)))],
		["Pulse Waves", str(int(s.get("pulse_waves", 0)))],
		["Items Collected", str(int(s.get("items_collected", 0)))],
		["Bosses Defeated", str(int(s.get("bosses_defeated", 0)))],
		["Mods Crafted", str(int(s.get("mods_crafted", 0)))],
		["Weather Events", str(int(s.get("weather_events", 0)))],
	]
	for line in lines:
		_draw_stat_line(font, line[0], line[1], col_x, y, val_x, a)
		y += line_h

func _draw_lifetime_tab(font, rect: Rect2, a: float) -> void:
	var l: Dictionary = Statistics.get_lifetime()
	var y: float = rect.position.y + 10
	var line_h: float = 28
	var col_x: float = rect.position.x + 30
	var val_x: float = rect.position.x + rect.size.x - 200
	_draw_section_header(font, "All-Time Stats", rect.position.x + 20, y, a)
	y += 35
	var lines: Array = [
		["Total Runs", str(int(l.get("total_runs", 0)))],
		["Total Kills", str(int(l.get("total_kills", 0)))],
		["Total Deaths", str(int(l.get("total_deaths", 0)))],
		["Total Time Played", Statistics.format_time(float(l.get("time_played", 0.0)))],
		["Total Distance", Statistics.format_distance(float(l.get("distance_traveled", 0.0)))],
		["Total Shots Fired", str(int(l.get("shots_fired", 0)))],
		["Total Dashes", str(int(l.get("dashes", 0)))],
		["Total Pulse Waves", str(int(l.get("pulse_waves", 0)))],
		["Total Items Collected", str(int(l.get("items_collected", 0)))],
		["Total Bosses Defeated", str(int(l.get("bosses_defeated", 0)))],
		["Total Mods Crafted", str(int(l.get("mods_crafted", 0)))],
		["Pet Feedings", str(int(l.get("pet_feedings", 0)))],
		["Rifts Entered", str(int(l.get("rifts_entered", 0)))],
		["Revives", str(int(l.get("revives", 0)))],
	]
	for line in lines:
		_draw_stat_line(font, line[0], line[1], col_x, y, val_x, a)
		y += line_h
	# Best records section
	y += 10
	_draw_section_header(font, "Best Records", rect.position.x + 20, y, a)
	y += 35
	var best_lines: Array = [
		["Best Score", str(int(l.get("best_score", 0)))],
		["Best Combo", "x%d" % int(l.get("best_combo", 0))],
		["Best Level", str(int(l.get("best_level", 1)))],
		["Best Survival Time", Statistics.format_time(float(l.get("best_survival_time", 0.0)))],
	]
	for line in best_lines:
		_draw_stat_line(font, line[0], line[1], col_x, y, val_x, a)
		y += line_h

func _draw_combat_tab(font, rect: Rect2, a: float) -> void:
	var y: float = rect.position.y + 10
	var col_x: float = rect.position.x + 30
	var val_x: float = rect.position.x + rect.size.x - 200
	_draw_section_header(font, "Enemies Killed (Lifetime)", rect.position.x + 20, y, a)
	y += 35
	var enemies: Dictionary = Statistics.get_enemies_by_type()
	if enemies.is_empty():
		_draw_stat_line(font, "No kills yet", "—", col_x, y, val_x, a)
		y += 28
	else:
		# Sort by count descending
		var sorted_keys: Array = enemies.keys()
		sorted_keys.sort_custom(func(a_key, b_key): return int(enemies[a_key]) > int(enemies[b_key]))
		for enemy_name in sorted_keys:
			_draw_stat_line(font, str(enemy_name), str(int(enemies[enemy_name])), col_x, y, val_x, a)
			y += 26
			if y > rect.position.y + rect.size.y - 80:
				break
	# Boss kills section
	y += 10
	_draw_section_header(font, "Bosses Defeated (Lifetime)", rect.position.x + 20, y, a)
	y += 35
	var bosses: Dictionary = Statistics.get_bosses_by_type()
	if bosses.is_empty():
		_draw_stat_line(font, "No bosses defeated", "—", col_x, y, val_x, a)
	else:
		for boss_name in bosses.keys():
			_draw_stat_line(font, str(boss_name), str(int(bosses[boss_name])), col_x, y, val_x, a)
			y += 26

func _draw_exploration_tab(font, rect: Rect2, a: float) -> void:
	var y: float = rect.position.y + 10
	var col_x: float = rect.position.x + 30
	var val_x: float = rect.position.x + rect.size.x - 200
	_draw_section_header(font, "Biome Time (Lifetime)", rect.position.x + 20, y, a)
	y += 35
	var biome_time: Dictionary = Statistics.get_lifetime().get("biome_time", {})
	if biome_time.is_empty():
		_draw_stat_line(font, "No biome data yet", "—", col_x, y, val_x, a)
		y += 28
	else:
		# Sort by time descending
		var sorted_keys: Array = biome_time.keys()
		sorted_keys.sort_custom(func(a_key, b_key): return float(biome_time[a_key]) > float(biome_time[b_key]))
		for biome_key in sorted_keys:
			var biome_id: int = int(biome_key)
			var biome_name: String = _get_biome_name(biome_id)
			var time_str: String = Statistics.format_time(float(biome_time[biome_key]))
			_draw_stat_line(font, biome_name, time_str, col_x, y, val_x, a)
			y += 26
			if y > rect.position.y + rect.size.y - 120:
				break
	# Items collected section
	y += 10
	_draw_section_header(font, "Items Collected (Lifetime)", rect.position.x + 20, y, a)
	y += 35
	var items: Dictionary = Statistics.get_items_by_type()
	if items.is_empty():
		_draw_stat_line(font, "No items collected", "—", col_x, y, val_x, a)
	else:
		for item_key in items.keys():
			var item_name: String = _get_collectible_name(int(item_key))
			_draw_stat_line(font, item_name, str(int(items[item_key])), col_x, y, val_x, a)
			y += 26
			if y > rect.position.y + rect.size.y - 20:
				break

# ─── Drawing Helpers ──────────────────────────────────────────────────────────

func _draw_section_header(font, text: String, x: float, y: float, a: float) -> void:
	font.draw_string(get_canvas_item(), Vector2(x, y + 18), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.5, 0.8, 1.0, a))
	# Underline
	draw_line(Vector2(x, y + 24), Vector2(x + 300, y + 24),
		Color(0.3, 0.5, 0.8, 0.4 * a), 1.0)

func _draw_stat_line(font, label: String, value: String, col_x: float, y: float, val_x: float, a: float) -> void:
	font.draw_string(get_canvas_item(), Vector2(col_x, y + 18), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.75, 0.78, 0.85, a))
	font.draw_string(get_canvas_item(), Vector2(val_x, y + 18), value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.9, 0.4, a))

func _draw_centered_text(font, text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	font.draw_string(get_canvas_item(),
		Vector2(pos.x - text_size.x / 2.0, pos.y + text_size.y / 2.0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _get_biome_name(biome_id: int) -> String:
	# Map biome enum to display name
	var names: Dictionary = {
		0: "Grass", 1: "Desert", 2: "Water", 3: "Lava", 4: "Forest",
		5: "Crystal", 6: "Snow", 7: "Swamp", 8: "Alien", 9: "Mushroom",
		10: "Floating Islands", 11: "Toxic Bog",
		12: "Deep Ocean", 13: "Volcano Core", 14: "Sky Citadel",
		15: "Digital Grid", 16: "Crystal Caverns", 17: "Ancient Ruins",
		18: "Underground",
	}
	return names.get(biome_id, "Biome %d" % biome_id)

func _get_collectible_name(type_id: int) -> String:
	var names: Dictionary = {
		0: "Star Fruit", 1: "Meteor Shard", 2: "Quantum Fuzz",
		3: "Nebula Dust", 4: "Space Gloop", 5: "XP Orb",
		6: "Health Fragment", 7: "Shield Crystal", 8: "Fireball Scroll",
		9: "Regen Crystal", 10: "Magnet Core", 11: "Toxic Extract",
	}
	return names.get(type_id, "Item %d" % type_id)