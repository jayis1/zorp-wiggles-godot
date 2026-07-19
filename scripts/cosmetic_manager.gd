## Zorp Wiggles — Cosmetic Manager (Phase 30: Visual & Audio Polish)
## Autoload singleton that manages player-selected cosmetics:
##   - Skins: recolor Zorp's body + emission + rim tint (pure visual, no gameplay effect)
##   - Dash trail customization: color + particle style for the dash afterimage
##
## Skins unlock via milestones tracked in Statistics / ProgressionSystem /
## AchievementPopup. The player picks one active skin and one active trail
## configuration. Selections persist to `user://zorp_cosmetics.json`.
##
## Public API:
##   get_active_skin() / set_skin(id) / cycle_skin()
##   is_skin_unlocked(id) / get_unlock_progress(id)
##   get_active_trail_style() / set_trail_style(id) / cycle_trail_style()
##   get_active_trail_color() / set_trail_color_index(idx) / cycle_trail_color()
##   get_trail_params() -> Dictionary  (used by player.gd when spawning afterimages)
##   refresh_unlocks()  (re-check all unlock criteria)
##
## Signals:
##   skin_changed(skin_id)            — active skin changed
##   trail_style_changed(style_id)    — active trail style changed
##   trail_color_changed(color_index) — active trail color changed
##   skin_unlocked(skin_id)           — a skin just became unlocked

extends Node

# ─── Signals ──────────────────────────────────────────────────────────────────
signal skin_changed(skin_id: int)
signal trail_style_changed(style_id: int)
signal trail_color_changed(color_index: int)
signal skin_unlocked(skin_id: int)

const SAVE_PATH: String = "user://zorp_cosmetics.json"

# ─── Runtime State ────────────────────────────────────────────────────────────
var _active_skin: int = 0                      # GameConstants.PlayerSkin.DEFAULT
var _active_trail_style: int = 0               # GameConstants.TrailStyle.CLASSIC
var _active_trail_color_index: int = 0         # Index into GameConstants.TRAIL_COLORS
var _unlocked_skins: Dictionary = {}           # skin_id (int) -> true
var _rainbow_phase: float = 0.0                # Phase accumulator for RAINBOW skin


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load()
	# Default skin is always unlocked
	_unlocked_skins[GameConstants.PlayerSkin.DEFAULT] = true
	refresh_unlocks()
	# Re-check unlocks periodically as the player earns stats. We connect to
	# Statistics.stats_updated so unlocks fire as soon as criteria are met.
	if Statistics:
		Statistics.stats_updated.connect(refresh_unlocks)
	if ProgressionSystem:
		ProgressionSystem.prestige_changed.connect(refresh_unlocks)
	if GameManager:
		GameManager.level_up.connect(_on_level_up)
		GameManager.game_restarted.connect(_on_game_restarted)


func _process(delta: float) -> void:
	# Advance the rainbow phase for the RAINBOW skin's cycling color
	if _active_skin == GameConstants.PlayerSkin.RAINBOW:
		_rainbow_phase += delta * 0.6  # 0.6 rad/s hue cycle


func _exit_tree() -> void:
	_save()


# ─── Persistence ──────────────────────────────────────────────────────────────

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var text: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	_active_skin = int(data.get("active_skin", GameConstants.PlayerSkin.DEFAULT))
	_active_trail_style = int(data.get("active_trail_style", GameConstants.TrailStyle.CLASSIC))
	_active_trail_color_index = int(data.get("active_trail_color", 0))
	# Clamp to valid ranges (defensive against stale saves after enum changes)
	_active_skin = clampi(_active_skin, 0, GameConstants.PlayerSkin.size() - 1)
	_active_trail_style = clampi(_active_trail_style, 0, GameConstants.TrailStyle.size() - 1)
	_active_trail_color_index = clampi(_active_trail_color_index, 0, GameConstants.TRAIL_COLORS.size() - 1)
	# Restore unlock state
	var unlocked: Dictionary = data.get("unlocked_skins", {})
	for key in unlocked.keys():
		_unlocked_skins[int(key)] = true
	print("[Cosmetics] Loaded — skin: %s, trail: %s/%s, unlocked: %d" % [
		GameConstants.SKIN_NAMES[_active_skin],
		GameConstants.TRAIL_STYLE_NAMES[_active_trail_style],
		GameConstants.TRAIL_COLOR_NAMES[_active_trail_color_index],
		_unlocked_skins.size(),
	])


func _save() -> void:
	var data: Dictionary = {
		"active_skin": _active_skin,
		"active_trail_style": _active_trail_style,
		"active_trail_color": _active_trail_color_index,
		"unlocked_skins": _unlocked_skins,
	}
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		push_warning("[CosmeticManager] Could not write save file.")
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()


# ─── Skin API ──────────────────────────────────────────────────────────────────

func get_active_skin() -> int:
	return _active_skin


func set_skin(skin_id: int) -> void:
	if skin_id < 0 or skin_id >= GameConstants.PlayerSkin.size():
		return
	if not is_skin_unlocked(skin_id):
		push_warning("[CosmeticManager] Skin %d is not unlocked." % skin_id)
		return
	if skin_id == _active_skin:
		return
	_active_skin = skin_id
	_save()
	skin_changed.emit(_active_skin)
	print("[Cosmetics] Skin set to: %s" % GameConstants.SKIN_NAMES[_active_skin])


func cycle_skin() -> int:
	# Cycle to the next UNLOCKED skin (skips locked ones)
	var count: int = GameConstants.PlayerSkin.size()
	for i in range(1, count + 1):
		var next: int = (_active_skin + i) % count
		if is_skin_unlocked(next):
			set_skin(next)
			return next
	return _active_skin


func is_skin_unlocked(skin_id: int) -> bool:
	return _unlocked_skins.has(skin_id)


func get_unlocked_skins() -> Array[int]:
	var out: Array[int] = []
	for key in _unlocked_skins.keys():
		out.append(int(key))
	out.sort()
	return out


## Returns a Dictionary with {unlocked: bool, current: int, target: int, label: String}
## describing the unlock state for the given skin. Used by the cosmetics UI.
func get_unlock_progress(skin_id: int) -> Dictionary:
	if skin_id < 0 or skin_id >= GameConstants.SKIN_UNLOCK_CRITERIA.size():
		return {"unlocked": false, "current": 0, "target": 0, "label": "???"}
	if _unlocked_skins.has(skin_id):
		return {"unlocked": true, "current": 0, "target": 0, "label": "Unlocked"}
	var criteria: Dictionary = GameConstants.SKIN_UNLOCK_CRITERIA[skin_id]
	if criteria.is_empty():
		return {"unlocked": true, "current": 0, "target": 0, "label": "Unlocked"}
	var stat: String = criteria.get("stat", "")
	var target: int = int(criteria.get("value", 0))
	var current: int = _query_stat(stat)
	return {
		"unlocked": false,
		"current": current,
		"target": target,
		"label": _unlock_label(stat, target),
	}


## Get the effective body color for the active skin. For RAINBOW, this cycles
## through the hue wheel over time so the player shimmers with all colors.
func get_active_skin_color() -> Color:
	if _active_skin == GameConstants.PlayerSkin.RAINBOW:
		# HSV hue cycle, full saturation, bright value
		var c: Color = Color.from_hsv(fmod(_rainbow_phase, 1.0), 0.75, 1.0)
		return c
	return GameConstants.SKIN_COLORS[_active_skin]


func get_active_skin_emission_mult() -> float:
	return GameConstants.SKIN_EMISSION_MULT[_active_skin]


# ─── Trail API ─────────────────────────────────────────────────────────────────

func get_active_trail_style() -> int:
	return _active_trail_style


func set_trail_style(style_id: int) -> void:
	if style_id < 0 or style_id >= GameConstants.TrailStyle.size():
		return
	if style_id == _active_trail_style:
		return
	_active_trail_style = style_id
	_save()
	trail_style_changed.emit(_active_trail_style)


func cycle_trail_style() -> int:
	var next: int = (_active_trail_style + 1) % GameConstants.TrailStyle.size()
	set_trail_style(next)
	return next


func get_active_trail_color_index() -> int:
	return _active_trail_color_index


func set_trail_color_index(idx: int) -> void:
	if idx < 0 or idx >= GameConstants.TRAIL_COLORS.size():
		return
	if idx == _active_trail_color_index:
		return
	_active_trail_color_index = idx
	_save()
	trail_color_changed.emit(_active_trail_color_index)


func cycle_trail_color() -> int:
	var next: int = (_active_trail_color_index + 1) % GameConstants.TRAIL_COLORS.size()
	set_trail_color_index(next)
	return next


func get_active_trail_color() -> Color:
	return GameConstants.TRAIL_COLORS[_active_trail_color_index]


## Returns the full parameter bundle the player uses when spawning a dash
## afterimage ghost. This is read every AFTERIMAGE_INTERVAL by player.gd.
func get_trail_params() -> Dictionary:
	var style_params: Dictionary = GameConstants.TRAIL_STYLE_PARAMS[_active_trail_style]
	return {
		"alpha": float(style_params.get("alpha", 0.5)),
		"life_mult": float(style_params.get("life", 1.0)),
		"scale_mult": float(style_params.get("scale", 1.0)),
		"mesh_type": int(style_params.get("mesh", 0)),
		"jitter": float(style_params.get("jitter", 0.0)),
		"color": get_active_trail_color(),
	}


# ─── Unlock Logic ──────────────────────────────────────────────────────────────

## Re-checks all skin unlock criteria. Emits skin_unlocked for any newly unlocked
## skins. Safe to call repeatedly — only fires signals for newly-unlocked skins.
func refresh_unlocks() -> void:
	for skin_id in range(GameConstants.PlayerSkin.size()):
		if _unlocked_skins.has(skin_id):
			continue
		var criteria: Dictionary = GameConstants.SKIN_UNLOCK_CRITERIA[skin_id]
		if criteria.is_empty():
			_unlocked_skins[skin_id] = true
			skin_unlocked.emit(skin_id)
			continue
		var stat: String = criteria.get("stat", "")
		var target: int = int(criteria.get("value", 0))
		var current: int = _query_stat(stat)
		if current >= target:
			_unlocked_skins[skin_id] = true
			skin_unlocked.emit(skin_id)
			_save()
			print("[Cosmetics] Skin unlocked: %s" % GameConstants.SKIN_NAMES[skin_id])
			if GameManager:
				GameManager.add_message("🎨 Skin unlocked: %s!" % GameConstants.SKIN_NAMES[skin_id])


func _on_level_up(level: int) -> void:
	refresh_unlocks()


func _on_game_restarted() -> void:
	# Cosmetics persist across runs — nothing to reset. Just re-check unlocks.
	refresh_unlocks()


## Queries the current value of a given unlock stat. Returns 0 if unknown.
func _query_stat(stat: String) -> int:
	match stat:
		"prestige":
			if ProgressionSystem:
				return ProgressionSystem.get_prestige_level()
			return 0
		"level":
			if Statistics:
				return int(Statistics.get_lifetime_stat("best_level"))
			return 0
		"achievements":
			# Read the AchievementPopup autoload node (added by HUD)
			var ap: Node = get_tree().get_first_node_in_group("achievement_popup")
			if ap and ap.has_method("get_unlocked_count"):
				return ap.get_unlocked_count()
			return 0
		"kills_void_leviathan":
			if Statistics:
				var d: Dictionary = Statistics.get_enemies_by_type()
				return int(d.get("Void Leviathan", 0))
			return 0
		"biome_visits_crystal_caverns":
			return _biome_visit_count(GameConstants.Biome.CRYSTAL_CAVERNS)
		"biome_visits_volcano_core":
			return _biome_visit_count(GameConstants.Biome.VOLCANO_CORE)
		"biome_visits_sky_citadel":
			return _biome_visit_count(GameConstants.Biome.SKY_CITADEL)
		_:
			return 0


## Approximates "visits" by counting the number of separate 10-second+ sessions
## spent in the biome (using biome_time). Each 10s counts as one "visit".
func _biome_visit_count(biome_id: int) -> int:
	if not Statistics:
		return 0
	var seconds: float = Statistics.get_biome_time(biome_id)
	return int(seconds / 10.0)


## Builds a human-readable unlock condition label for the cosmetics UI.
func _unlock_label(stat: String, target: int) -> String:
	match stat:
		"prestige":
			return "Prestige %d" % target
		"level":
			return "Reach level %d" % target
		"achievements":
			return "Unlock %d achievements" % target
		"kills_void_leviathan":
			return "Defeat %d Void Leviathans" % target
		"biome_visits_crystal_caverns":
			return "Visit Crystal Caverns %d times" % target
		"biome_visits_volcano_core":
			return "Visit Volcano Core %d times" % target
		"biome_visits_sky_citadel":
			return "Visit Sky Citadel %d times" % target
		_:
			return "???"


# ─── Reset (for testing / settings menu) ───────────────────────────────────────

func reset_to_defaults() -> void:
	_active_skin = GameConstants.PlayerSkin.DEFAULT
	_active_trail_style = GameConstants.TrailStyle.CLASSIC
	_active_trail_color_index = 0
	_unlocked_skins = {GameConstants.PlayerSkin.DEFAULT: true}
	_save()
	skin_changed.emit(_active_skin)
	trail_style_changed.emit(_active_trail_style)
	trail_color_changed.emit(_active_trail_color_index)