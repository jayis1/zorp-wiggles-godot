## Zorp Wiggles — Pet Evolution Stone Inventory (Phase 27)
## A lightweight autoload singleton that tracks how many of each evolution
## stone the player is carrying. Stones are picked up like normal collectibles
## (see collectible.gd) but are also recorded here so the player can choose
## when to feed one to their pet to lock in an elemental evolution path.
##
## Public API:
##   add_stone(type: int, amount: int)                — pick up stones
##   get_stone_count(type: int) -> int                — query inventory
##   get_total_stones() -> int                         — total stones carried
##   consume_stone(type: int) -> bool                  — use one (returns false if empty)
##   get_inventory() -> Dictionary                     — {stone_type: count, ...}
##   reset()                                           — clear on game restart
##
## Signals:
##   stone_added(type: int, total: int)                — a stone was picked up
##   stone_consumed(type: int, remaining: int)         — a stone was used

extends Node

# class_name omitted — this is an autoload singleton named PetStoneInventory;
# declaring class_name with the same name causes a "hides autoload singleton"
# parse error in Godot 4.4.

signal stone_added(type: int, total: int)
signal stone_consumed(type: int, remaining: int)

# {CollectibleType.EMBER_STONE: 3, ...}
var _inventory: Dictionary = {}

# All valid stone types (cached for fast iteration)
const _STONE_TYPES: Array[int] = [
	GameConstants.CollectibleType.EMBER_STONE,
	GameConstants.CollectibleType.FROST_STONE,
	GameConstants.CollectibleType.SPARK_STONE,
	GameConstants.CollectibleType.VOID_STONE,
	GameConstants.CollectibleType.LEAF_STONE,
]


func _ready() -> void:
	# Reset on game restart so we don't carry stones across runs.
	if GameManager and not GameManager.game_restarted.is_connected(_on_game_restarted):
		GameManager.game_restarted.connect(_on_game_restarted)
	# Also clear on player death — single-run items.
	if GameManager and not GameManager.player_died.is_connected(_on_player_died):
		GameManager.player_died.connect(_on_player_died)


func add_stone(type: int, amount: int = 1) -> void:
	if not _is_stone(type):
		return
	_inventory[type] = int(_inventory.get(type, 0)) + amount
	stone_added.emit(type, _inventory[type])


func get_stone_count(type: int) -> int:
	if not _is_stone(type):
		return 0
	return int(_inventory.get(type, 0))


func get_total_stones() -> int:
	var total: int = 0
	for type in _STONE_TYPES:
		total += int(_inventory.get(type, 0))
	return total


func consume_stone(type: int) -> bool:
	if not _is_stone(type):
		return false
	var count: int = int(_inventory.get(type, 0))
	if count <= 0:
		return false
	_inventory[type] = count - 1
	stone_consumed.emit(type, _inventory[type])
	return true


func get_inventory() -> Dictionary:
	# Return a copy so callers can't mutate our internal dict.
	return _inventory.duplicate()


func has_any_stone() -> bool:
	return get_total_stones() > 0


## Returns the first stone type the player has (in a fixed order), or -1.
func get_first_stone_type() -> int:
	for type in _STONE_TYPES:
		if int(_inventory.get(type, 0)) > 0:
			return type
	return -1


## Returns a human-readable summary string for HUD use, e.g. "Ember ×2, Leaf ×1".
func get_summary() -> String:
	var parts: Array[String] = []
	for type in _STONE_TYPES:
		var count: int = int(_inventory.get(type, 0))
		if count > 0:
			var idx: int = _STONE_TYPES.find(type)
			# PET_STONE_NAMES index = path index = stone index + 1
			# Ember/Frost/Spark/Void/Leaf → paths 1..5
			var path_idx: int = idx + 1
			var name: String = GameConstants.PET_STONE_NAMES[path_idx]
			parts.append("%s ×%d" % [name, count])
	return ", ".join(parts)


func reset() -> void:
	_inventory.clear()


func _is_stone(type: int) -> bool:
	return GameConstants.PET_STONE_TO_PATH.has(type)


func _on_game_restarted() -> void:
	reset()


func _on_player_died() -> void:
	reset()