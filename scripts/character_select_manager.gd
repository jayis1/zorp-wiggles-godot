## Zorp Wiggles — Character Select Manager (Phase 30: Visual & Audio Polish)
## Autoload singleton that stores the player's character selection from the
## main-menu character-select screen. The selection drives which controller
## script + base stats + color the in-game Player node uses for SOLO runs.
##
## In co-op, P1 is always Zorp and P2 is always Zerp (the existing CoOpManager
## flow), so this selection only affects solo play. If the player picks Zerp
## for solo, the in-game Player node swaps its base color, base HP, damage
## multiplier, and dash speed to Zerp's profile — a distinctly faster, frailer
## playstyle versus Zorp's tankier default.
##
## The selection persists to user://zorp_character.json so it survives across
## sessions. The character_select.gd UI reads/writes this singleton.
##
## Public API:
##   get_selected_character() -> int         (Character enum)
##   set_character(id)                       (also persists + emits signal)
##   get_character_name(id) -> String
##   get_character_color(id) -> Color
##   get_character_profile(id) -> Dictionary (hp, dmg_mult, dash_mult, color, name, desc)
##   get_active_profile() -> Dictionary       (profile for the currently selected character)
##
## Signals:
##   character_changed(id)

extends Node

signal character_changed(id: int)

enum Character {
	ZORP,  # 0 — Default tanky alien green
	ZERP,  # 1 — Faster, frailer magenta-purple
}

const SAVE_PATH: String = "user://zorp_character.json"

# Per-character profile. These multipliers are applied on top of the base
# constants (PLAYER_START_HP, etc.) in player.gd at _ready time.
const PROFILES: Array[Dictionary] = [
	{
		"id": Character.ZORP,
		"name": "Zorp",
		"color": Color(0.30, 0.85, 0.30),       # alien green
		"emission": Color(0.12, 0.34, 0.12),
		"hp_bonus": 0,                           # base 120
		"damage_mult": 1.0,
		"dash_speed_mult": 1.0,
		"speed_mult": 1.0,
		"desc": "Tanky all-rounder. Balanced HP, damage, and mobility.",
		"icon": "🟢",
	},
	{
		"id": Character.ZERP,
		"name": "Zerp",
		"color": Color(0.85, 0.25, 0.85),       # magenta-purple
		"emission": Color(0.34, 0.10, 0.34),
		"hp_bonus": -20,                         # 100 HP — frailer
		"damage_mult": 0.9,                      # slightly weaker shots
		"dash_speed_mult": 1.1,                  # snappier dash
		"speed_mult": 1.08,                      # faster walk
		"desc": "Fast and fragile. Quick dash, higher speed, lower HP and damage.",
		"icon": "🟣",
	},
]

var _selected: int = Character.ZORP


func _ready() -> void:
	_load()


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
	_selected = int(data.get("character", Character.ZORP))
	_selected = clampi(_selected, 0, Character.size() - 1)
	print("[CharacterSelect] Loaded — character: %s" % get_character_name(_selected))


func _save() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		return
	var data: Dictionary = {"character": _selected}
	f.store_string(JSON.stringify(data))
	f.close()


# ─── Public API ────────────────────────────────────────────────────────────────

func get_selected_character() -> int:
	return _selected


func set_character(id: int) -> void:
	if id < 0 or id >= Character.size():
		return
	if id == _selected:
		return
	_selected = id
	_save()
	character_changed.emit(_selected)
	print("[CharacterSelect] Character set to: %s" % get_character_name(_selected))


func get_character_name(id: int) -> String:
	if id < 0 or id >= PROFILES.size():
		return "???"
	return PROFILES[id].get("name", "???")


func get_character_color(id: int) -> Color:
	if id < 0 or id >= PROFILES.size():
		return Color.WHITE
	return PROFILES[id].get("color", Color.WHITE)


func get_character_profile(id: int) -> Dictionary:
	if id < 0 or id >= PROFILES.size():
		return PROFILES[0]
	return PROFILES[id]


func get_active_profile() -> Dictionary:
	return get_character_profile(_selected)


func is_zerp_selected() -> bool:
	return _selected == Character.ZERP