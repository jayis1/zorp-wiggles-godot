## Zorp Wiggles — Statistics Tracker (Phase 25: Progression & Meta-Systems)
## Autoload singleton that tracks both session and lifetime statistics.
## Lifetime stats persist across runs via a JSON file in user://.
##
## Tracked stats include:
##   - Lifetime kills, deaths, distance traveled, time played
##   - Per-biome time spent (lifetime)
##   - Items collected (by type, lifetime)
##   - Enemies killed (by type, lifetime)
##   - Bosses defeated (by type, lifetime)
##   - Best combo, best score, best level, best survival time
##   - Total runs, total dashes, total pulse waves, total shots fired
##   - Pet feedings, rifts entered, mods crafted, weather events survived
##
## Other systems query Statistics to populate the statistics page UI.
## Hooks into GameManager signals for automatic tracking — no manual calls needed.

extends Node

# ─── Signals ──────────────────────────────────────────────────────────────────
signal stats_updated()              # Emitted whenever a stat changes (for UI refresh)
signal lifetime_stat_unlocked(key: String, value: float)  # For achievement checks

# ─── Lifetime Stats (persisted) ──────────────────────────────────────────────
# Stored as a Dictionary in user://zorp_stats.json. Loaded on _ready, saved on
# _exit_tree and whenever a significant stat changes (batched — not every frame).
var _lifetime: Dictionary = {}

# ─── Session Stats (reset each run) ───────────────────────────────────────────
# Not persisted — lives only for the current run.
var _session: Dictionary = {}

# ─── Internal ──────────────────────────────────────────────────────────────────
const SAVE_PATH: String = "user://zorp_stats.json"
var _dirty: bool = false  # Pending unsaved changes
var _save_timer: float = 0.0  # Debounce timer for batched saves
const SAVE_DEBOUNCE: float = 5.0  # Save at most every 5 seconds

# Distance tracking — needs the player's previous position to compute delta.
var _last_player_pos: Vector3 = Vector3.ZERO
var _player_pos_initialized: bool = false

# ─── Public API ───────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_lifetime()
	_init_session()
	# Connect to GameManager signals for automatic tracking
	if GameManager:
		GameManager.enemy_killed.connect(_on_enemy_killed)
		GameManager.boss_defeated.connect(_on_boss_defeated)
		GameManager.boss_spawned.connect(_on_boss_spawned)
		GameManager.player_died.connect(_on_player_died)
		GameManager.game_restarted.connect(_on_game_restarted)
		GameManager.level_up.connect(_on_level_up)
		GameManager.combo_changed.connect(_on_combo_changed)
		GameManager.score_changed.connect(_on_score_changed)
		GameManager.biome_changed.connect(_on_biome_changed)
		GameManager.pickup_streak_milestone.connect(_on_pickup_milestone)
		GameManager.combo_milestone.connect(_on_combo_milestone)
	# Weapon mod crafting
	if WeaponModSystem:
		WeaponModSystem.mod_crafted.connect(_on_mod_crafted)
	# Weather
	if WeatherSystem:
		WeatherSystem.weather_transition_started.connect(_on_weather_changed)

func _process(delta: float) -> void:
	# Track distance traveled (needs player position)
	if GameManager and GameManager.player and GameManager.player_is_alive:
		var pos: Vector3 = GameManager.player.global_position
		if not _player_pos_initialized:
			_last_player_pos = pos
			_player_pos_initialized = true
		else:
			var d: float = _last_player_pos.distance_to(pos)
			if d < 50.0:  # Sanity cap — avoid teleport/dimension-shift spikes
				_add_session("distance_traveled", d)
				_add_lifetime("distance_traveled", d)
			_last_player_pos = pos
	# Track session time
	if GameManager and GameManager.player_is_alive and not GameManager.is_paused:
		_add_session("time_played", delta)
		_add_lifetime("time_played", delta)
	# Batched save
	if _dirty:
		_save_timer += delta
		if _save_timer >= SAVE_DEBOUNCE:
			_save_lifetime()
			_save_timer = 0.0
			_dirty = false

func _exit_tree() -> void:
	_save_lifetime()

# ─── Session Management ───────────────────────────────────────────────────────

func _init_session() -> void:
	_session = {
		"kills": 0,
		"deaths": 0,
		"distance_traveled": 0.0,
		"time_played": 0.0,
		"max_combo": 0,
		"max_score": 0,
		"max_level": 1,
		"shots_fired": 0,
		"dashes": 0,
		"pulse_waves": 0,
		"items_collected": 0,
		"bosses_defeated": 0,
		"biomes_visited": {},
		"enemies_by_type": {},
		"items_by_type": {},
		"bosses_by_type": {},
		"mods_crafted": 0,
		"weather_events": 0,
	}

func reset_session() -> void:
	_init_session()
	_player_pos_initialized = false
	stats_updated.emit()

# ─── Lifetime Save/Load ───────────────────────────────────────────────────────

func _load_lifetime() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_lifetime = _default_lifetime()
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("[Statistics] Could not open save file — using defaults.")
		_lifetime = _default_lifetime()
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[Statistics] Save file corrupt — using defaults.")
		_lifetime = _default_lifetime()
		return
	_lifetime = _default_lifetime()
	# Merge saved values over defaults (so new fields get defaults if missing)
	for key in parsed.keys():
		_lifetime[key] = parsed[key]
	print("[Statistics] Lifetime stats loaded — runs: %d, kills: %d" % [
		int(_lifetime.get("total_runs", 0)),
		int(_lifetime.get("total_kills", 0))
	])

func _save_lifetime() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_warning("[Statistics] Could not write save file.")
		return
	file.store_string(JSON.stringify(_lifetime, "  "))
	file.close()

func _default_lifetime() -> Dictionary:
	return {
		"total_kills": 0,
		"total_deaths": 0,
		"total_runs": 0,
		"distance_traveled": 0.0,
		"time_played": 0.0,
		"best_combo": 0,
		"best_score": 0,
		"best_level": 1,
		"best_survival_time": 0.0,
		"shots_fired": 0,
		"dashes": 0,
		"pulse_waves": 0,
		"items_collected": 0,
		"bosses_defeated": 0,
		"mods_crafted": 0,
		"weather_events": 0,
		"biome_time": {},      # biome_id (as string) → seconds
		"enemies_by_type": {}, # enemy_name → count
		"items_by_type": {},   # collectible_type (as string) → count
		"bosses_by_type": {},  # boss_name → count
		"pet_feedings": 0,
		"rifts_entered": 0,
		"revives": 0,
	}

# ─── Stat Mutators ────────────────────────────────────────────────────────────

func _add_session(key: String, amount: float) -> void:
	_session[key] = float(_session.get(key, 0.0)) + amount

func _add_lifetime(key: String, amount: float) -> void:
	var old: float = float(_lifetime.get(key, 0.0))
	_lifetime[key] = old + amount
	_dirty = true

func _set_lifetime_max(key: String, value: float) -> void:
	var old: float = float(_lifetime.get(key, 0.0))
	if value > old:
		_lifetime[key] = value
		_dirty = true
		lifetime_stat_unlocked.emit(key, value)

func _inc_dict_session(dict_key: String, sub_key: String, amount: int = 1) -> void:
	var d: Dictionary = _session.get(dict_key, {})
	d[sub_key] = int(d.get(sub_key, 0)) + amount
	_session[dict_key] = d

func _inc_dict_lifetime(dict_key: String, sub_key: String, amount: int = 1) -> void:
	var d: Dictionary = _lifetime.get(dict_key, {})
	d[sub_key] = int(d.get(sub_key, 0)) + amount
	_lifetime[dict_key] = d
	_dirty = true

# ─── Signal Handlers ──────────────────────────────────────────────────────────

func _on_enemy_killed(enemy_name: String, _killer_name: String) -> void:
	_add_session("kills", 1.0)
	_add_lifetime("total_kills", 1.0)
	_inc_dict_session("enemies_by_type", enemy_name)
	_inc_dict_lifetime("enemies_by_type", enemy_name)
	stats_updated.emit()

func _on_boss_spawned(_boss: Node) -> void:
	pass  # Tracked on defeat

func _on_boss_defeated(boss: Node) -> void:
	_add_session("bosses_defeated", 1.0)
	_add_lifetime("bosses_defeated", 1.0)
	var bname: String = "Boss"
	if "enemy_name" in boss:
		bname = boss.enemy_name
	_inc_dict_session("bosses_by_type", bname)
	_inc_dict_lifetime("bosses_by_type", bname)
	stats_updated.emit()

func _on_player_died() -> void:
	_add_session("deaths", 1.0)
	_add_lifetime("total_deaths", 1.0)
	_add_lifetime("total_runs", 1.0)
	# Record best stats from this run
	_set_lifetime_max("best_combo", float(GameManager.player_best_combo))
	_set_lifetime_max("best_score", float(GameManager.player_score))
	_set_lifetime_max("best_level", float(GameManager.player_level))
	_set_lifetime_max("best_survival_time", GameManager.game_time)
	stats_updated.emit()

func _on_game_restarted() -> void:
	# Carry over session bests to lifetime before reset
	_set_lifetime_max("best_combo", float(GameManager.player_best_combo))
	_set_lifetime_max("best_score", float(GameManager.player_score))
	_set_lifetime_max("best_level", float(GameManager.player_level))
	_set_lifetime_max("best_survival_time", GameManager.game_time)
	reset_session()

func _on_level_up(level: int) -> void:
	if level > int(_session.get("max_level", 1)):
		_session["max_level"] = level
	_set_lifetime_max("best_level", float(level))
	stats_updated.emit()

func _on_combo_changed(count: int) -> void:
	if count > int(_session.get("max_combo", 0)):
		_session["max_combo"] = count

func _on_score_changed(new_score: int) -> void:
	if new_score > int(_session.get("max_score", 0)):
		_session["max_score"] = new_score

func _on_biome_changed(biome_id: int) -> void:
	var key: String = str(biome_id)
	_inc_dict_session("biomes_visited", key)
	stats_updated.emit()

func _on_pickup_milestone(_streak: int, _xp: int) -> void:
	stats_updated.emit()

func _on_combo_milestone(_combo: int, _tier: int, _color: Color) -> void:
	stats_updated.emit()

func _on_mod_crafted(_mod_id: int) -> void:
	_add_session("mods_crafted", 1.0)
	_add_lifetime("mods_crafted", 1.0)
	stats_updated.emit()

func _on_weather_changed(_new_weather: int) -> void:
	_add_session("weather_events", 1.0)
	_add_lifetime("weather_events", 1.0)

# ─── Manual Stat Hooks (called by other systems) ──────────────────────────────

func record_shot() -> void:
	_add_session("shots_fired", 1.0)
	_add_lifetime("shots_fired", 1.0)

func record_dash() -> void:
	_add_session("dashes", 1.0)
	_add_lifetime("dashes", 1.0)

func record_pulse_wave() -> void:
	_add_session("pulse_waves", 1.0)
	_add_lifetime("pulse_waves", 1.0)

func record_item_collected(collectible_type: int) -> void:
	_add_session("items_collected", 1.0)
	_add_lifetime("items_collected", 1.0)
	var key: String = str(collectible_type)
	_inc_dict_session("items_by_type", key)
	_inc_dict_lifetime("items_by_type", key)
	stats_updated.emit()

func record_pet_feeding() -> void:
	_add_lifetime("pet_feedings", 1.0)
	_dirty = true

func record_rift_entered() -> void:
	_add_lifetime("rifts_entered", 1.0)
	_dirty = true

func record_revive() -> void:
	_add_lifetime("revives", 1.0)
	_dirty = true

# ── Phase 26: World Life — lore stones, treasure chests, wildlife ──
func record_lore_stone_read() -> void:
	_add_lifetime("lore_stones_read", 1.0)
	_add_session("lore_stones_read", 1.0)
	stats_updated.emit()

func record_treasure_chest_opened(trapped: bool = false) -> void:
	_add_lifetime("treasure_chests_opened", 1.0)
	_add_session("treasure_chests_opened", 1.0)
	if trapped:
		_add_lifetime("trapped_chests_triggered", 1.0)
		_add_session("trapped_chests_triggered", 1.0)
	stats_updated.emit()

func record_wildlife_caught(species_name: String = "Unknown") -> void:
	_add_lifetime("wildlife_caught", 1.0)
	_add_session("wildlife_caught", 1.0)
	_inc_dict_lifetime("wildlife_by_type", species_name)
	_inc_dict_session("wildlife_by_type", species_name)
	stats_updated.emit()

# ── Phase 26: World Life — wandering merchants, world bosses, fast travel ──
func record_merchant_trade() -> void:
	_add_lifetime("merchant_trades", 1.0)
	_add_session("merchant_trades", 1.0)
	stats_updated.emit()

func record_world_boss_defeated(boss_name: String = "Unknown") -> void:
	_add_lifetime("world_bosses_defeated", 1.0)
	_add_session("world_bosses_defeated", 1.0)
	_inc_dict_lifetime("world_bosses_by_type", boss_name)
	_inc_dict_session("world_bosses_by_type", boss_name)
	stats_updated.emit()

func record_waypoint_activated(waypoint_name: String = "Unknown") -> void:
	_add_lifetime("waypoints_activated", 1.0)
	_add_session("waypoints_activated", 1.0)
	_inc_dict_lifetime("waypoints_by_name", waypoint_name)
	_inc_dict_session("waypoints_by_name", waypoint_name)
	stats_updated.emit()

func record_fast_travel(waypoint_name: String = "Unknown") -> void:
	_add_lifetime("fast_travels", 1.0)
	_add_session("fast_travels", 1.0)
	_inc_dict_lifetime("fast_travels_by_destination", waypoint_name)
	_inc_dict_session("fast_travels_by_destination", waypoint_name)
	stats_updated.emit()

# ── Phase 29: Equipment & rare material tracking ──
func record_rare_material_drop(rare_material_id: int) -> void:
	_add_lifetime("rare_materials_dropped", 1.0)
	_add_session("rare_materials_dropped", 1.0)
	var rm_name: String = GameConstants.RARE_MATERIAL_NAMES[rare_material_id] if rare_material_id < GameConstants.RARE_MATERIAL_NAMES.size() else "Unknown"
	_inc_dict_lifetime("rare_materials_by_type", rm_name)
	_inc_dict_session("rare_materials_by_type", rm_name)
	stats_updated.emit()

func record_equipment_crafted(piece_id: int) -> void:
	_add_lifetime("equipment_crafted", 1.0)
	_add_session("equipment_crafted", 1.0)
	var piece_name: String = GameConstants.EQUIP_PIECE_NAMES[piece_id] if piece_id < GameConstants.EQUIP_PIECE_NAMES.size() else "Unknown"
	_inc_dict_lifetime("equipment_by_piece", piece_name)
	_inc_dict_session("equipment_by_piece", piece_name)
	stats_updated.emit()

func record_consumable_used(consumable_id: int) -> void:
	_add_lifetime("consumables_used", 1.0)
	_add_session("consumables_used", 1.0)
	var cons_name: String = GameConstants.CONSUMABLE_NAMES[consumable_id] if consumable_id < GameConstants.CONSUMABLE_NAMES.size() else "Unknown"
	_inc_dict_lifetime("consumables_by_type", cons_name)
	_inc_dict_session("consumables_by_type", cons_name)
	stats_updated.emit()

func add_biome_time(biome_id: int, seconds: float) -> void:
	# Called periodically by BiomeEffects or GameManager for per-biome time tracking
	var key: String = str(biome_id)
	var d: Dictionary = _lifetime.get("biome_time", {})
	d[key] = float(d.get(key, 0.0)) + seconds
	_lifetime["biome_time"] = d
	_dirty = true

# ─── Public Getters ────────────────────────────────────────────────────────────

func get_session_stat(key: String) -> Variant:
	return _session.get(key, null)

func get_lifetime_stat(key: String) -> Variant:
	return _lifetime.get(key, null)

func get_session() -> Dictionary:
	return _session.duplicate(true)

func get_lifetime() -> Dictionary:
	return _lifetime.duplicate(true)

func get_biome_time(biome_id: int) -> float:
	var d: Dictionary = _lifetime.get("biome_time", {})
	return float(d.get(str(biome_id), 0.0))

func get_enemies_by_type() -> Dictionary:
	return _lifetime.get("enemies_by_type", {})

func get_items_by_type() -> Dictionary:
	return _lifetime.get("items_by_type", {})

func get_bosses_by_type() -> Dictionary:
	return _lifetime.get("bosses_by_type", {})

# ── Phase 25: Public lifetime setters (for GameModeManager personal bests) ──
# These let external systems (Boss Rush, Speedrun) persist best-time records
# without reaching into the private _lifetime dictionary.

func set_lifetime_max(key: String, value: float) -> void:
	# Public wrapper around _set_lifetime_max — only updates if the new value
	# exceeds the existing one (used for "best" stats where higher is better).
	_set_lifetime_max(key, value)

func add_lifetime(key: String, amount: float) -> void:
	# Public wrapper around _add_lifetime — increments a cumulative counter
	# (used for "total" stats like pvp_wins_p1 where each event adds 1).
	_add_lifetime(key, amount)

func set_lifetime_stat(key: String, value: Variant) -> void:
	# Direct write (overwrites). Used for split dictionaries and any stat
	# where the caller has already computed the "best" externally.
	_lifetime[key] = value
	_dirty = true
	lifetime_stat_unlocked.emit(key, float(value) if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT else 0.0)

func format_time(seconds: float) -> String:
	var s: int = int(seconds)
	var h: int = s / 3600
	var m: int = (s % 3600) / 60
	var sec: int = s % 60
	if h > 0:
		return "%dh %02dm %02ds" % [h, m, sec]
	elif m > 0:
		return "%dm %02ds" % [m, sec]
	else:
		return "%ds" % sec

func format_distance(meters: float) -> String:
	if meters >= 1000.0:
		return "%.1f km" % (meters / 1000.0)
	return "%d m" % int(meters)