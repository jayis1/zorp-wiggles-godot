## Zorp Wiggles — Weapon Mod Crafting System (Phase 16)
## Autoload singleton that manages the player's inventory of crafting materials,
## discovered weapon mods, and the currently equipped mod.
##
## Players collect crafting materials from enemy drops. Press C to open the
## crafting menu, select 2 (or 3) materials to combine into a weapon mod.
## Only 1 mod can be equipped at a time, but discovered mods can be swapped freely.
##
## 20 weapon mods change laser behavior: homing, chain lightning, spread shot,
## piercing, bouncing, freeze, acid, mega blast, and more.

extends Node

# ─── Signals ──────────────────────────────────────────────────────────────────
signal inventory_changed()                          # Material counts updated
signal mod_equipped(mod_id: int)                    # New weapon mod equipped
signal mod_crafted(mod_id: int)                     # New mod discovered/crafted
signal mod_unequipped()                             # Mod removed (back to standard)
signal crafting_menu_toggled(is_open: bool)         # Menu open/close

# ─── State ─────────────────────────────────────────────────────────────────────
# Inventory: maps CollectibleType → count of materials held
var _inventory: Dictionary = {}

# All discovered mods (by WeaponMod enum int). Start with NONE (standard laser).
var _discovered_mods: Array[int] = [GameConstants.WeaponMod.NONE]

# Currently equipped mod (starts as NONE = standard laser)
var _equipped_mod: int = GameConstants.WeaponMod.NONE

# Whether the crafting menu is currently open
var _menu_open: bool = false

# ─── Public API ────────────────────────────────────────────────────────────────

## How many of a given material type the player currently holds.
func get_material_count(type: int) -> int:
	return _inventory.get(type, 0)

## The full inventory as a Dictionary { CollectibleType: count }.
func get_inventory() -> Dictionary:
	return _inventory.duplicate()

## Add a material to inventory. Called when a crafting-material collectible is picked up.
func add_material(type: int, amount: int = 1) -> void:
	if not GameConstants.CRAFTING_MATERIALS.has(type):
		return
	_inventory[type] = _inventory.get(type, 0) + amount
	inventory_changed.emit()

## Remove materials from inventory. Returns true if successful, false if not enough.
func remove_materials(types: Array) -> bool:
	# First check we have enough of each
	var needed: Dictionary = {}
	for t in types:
		needed[t] = needed.get(t, 0) + 1
	for type in needed:
		if _inventory.get(type, 0) < needed[type]:
			return false
	# Remove them
	for type in needed:
		_inventory[type] -= needed[type]
		if _inventory[type] <= 0:
			_inventory.erase(type)
	inventory_changed.emit()
	return true

## The currently equipped weapon mod ID (GameConstants.WeaponMod enum).
func get_equipped_mod() -> int:
	return _equipped_mod

## Equip a previously discovered mod. Returns true on success.
func equip_mod(mod_id: int) -> bool:
	if not _discovered_mods.has(mod_id):
		return false
	# ── Phase 33: Weapon Mod Fusion — unequip any fused mod first ──
	# Equipping a base mod takes precedence over a fused mod.
	if WeaponModFusion and WeaponModFusion.is_fused_equipped():
		WeaponModFusion.unequip_fused()
	var old_mod: int = _equipped_mod
	_equipped_mod = mod_id
	if old_mod != mod_id:
		mod_equipped.emit(mod_id)
	return true

## Unequip current mod (revert to standard laser).
func unequip_mod() -> void:
	if _equipped_mod != GameConstants.WeaponMod.NONE:
		_equipped_mod = GameConstants.WeaponMod.NONE
		mod_unequipped.emit()

## Has the player discovered this mod?
func is_mod_discovered(mod_id: int) -> bool:
	return _discovered_mods.has(mod_id)

## Get all discovered mod IDs.
func get_discovered_mods() -> Array[int]:
	return _discovered_mods.duplicate()

# ── Phase 31: Save/Load setters (called by SaveSystem) ──
## Replace the entire material inventory from a save file.
func set_inventory(inv: Dictionary) -> void:
	_inventory = inv.duplicate()
	inventory_changed.emit()

## Replace the discovered mods list from a save file.
func set_discovered_mods(mods: Array) -> void:
	_discovered_mods.clear()
	for m in mods:
		_discovered_mods.append(int(m))
	if not _discovered_mods.has(GameConstants.WeaponMod.NONE):
		_discovered_mods.append(GameConstants.WeaponMod.NONE)

## Force-set the equipped mod (used by save/load — bypasses the discovered check).
func set_equipped_mod(mod_id: int) -> void:
	_equipped_mod = mod_id
	mod_equipped.emit(mod_id)

## Attempt to craft a weapon mod from a list of material types.
## Returns the crafted mod ID on success, or -1 if no recipe matched / not enough materials.
func craft_mod(material_types: Array) -> int:
	# Need at least 2 materials
	if material_types.size() < 2:
		return -1
	# Check we have the materials
	if not remove_materials(material_types):
		return -1
	# Build the recipe key (sorted type names joined by comma)
	var mod_id: int = _lookup_recipe(material_types)
	if mod_id == GameConstants.WeaponMod.NONE:
		# Unknown combination — materials consumed but no mod created (discovery failure)
		# In a more punishing design this is a risk; here we refund half the materials.
		_refund_half(material_types)
		return -1
	# Mark as discovered
	if not _discovered_mods.has(mod_id):
		_discovered_mods.append(mod_id)
		mod_crafted.emit(mod_id)
	# Auto-equip the newly crafted mod
	equip_mod(mod_id)
	return mod_id

## Look up the recipe key from material types. Returns WeaponMod.NONE if no match.
func _lookup_recipe(material_types: Array) -> int:
	# Convert types to names, sort, join with comma
	var names: Array[String] = []
	for t in material_types:
		var name: String = GameConstants.COLLECTIBLE_TYPE_NAMES.get(t, "")
		if name == "":
			return GameConstants.WeaponMod.NONE
		names.append(name)
	names.sort()
	var key: String = ",".join(names)
	return GameConstants.CRAFTING_RECIPES.get(key, GameConstants.WeaponMod.NONE)

## Refund half the materials (rounded down) when a bad combo is attempted.
func _refund_half(material_types: Array) -> void:
	var needed: Dictionary = {}
	for t in material_types:
		needed[t] = needed.get(t, 0) + 1
	for type in needed:
		var refund: int = int(needed[type] / 2.0)
		if refund > 0:
			_inventory[type] = _inventory.get(type, 0) + refund
	inventory_changed.emit()

## Toggle the crafting menu open/closed. Returns the new state.
func toggle_crafting_menu() -> bool:
	_menu_open = not _menu_open
	crafting_menu_toggled.emit(_menu_open)
	return _menu_open

## Close the crafting menu if it's open.
func close_crafting_menu() -> void:
	if _menu_open:
		_menu_open = false
		crafting_menu_toggled.emit(false)

## Is the crafting menu currently open?
func is_menu_open() -> bool:
	return _menu_open

# ─── Mod Behavior Properties ──────────────────────────────────────────────────
## These are queried by the player/projectile to modify laser behavior.

func get_equipped_damage_mult() -> float:
	return GameConstants.WEAPON_MOD_DAMAGE_MULT[_equipped_mod]

func get_equipped_fire_rate_mult() -> float:
	return GameConstants.WEAPON_MOD_FIRE_RATE_MULT[_equipped_mod]

func get_equipped_speed_mult() -> float:
	return GameConstants.WEAPON_MOD_SPEED_MULT[_equipped_mod]

func get_equipped_color() -> Color:
	return GameConstants.WEAPON_MOD_COLORS[_equipped_mod]

func get_equipped_name() -> String:
	return GameConstants.WEAPON_MOD_NAMES[_equipped_mod]

func get_equipped_description() -> String:
	return GameConstants.WEAPON_MOD_DESCRIPTIONS[_equipped_mod]

# ─── Reset (on game restart) ───────────────────────────────────────────────────

func reset() -> void:
	_inventory.clear()
	_discovered_mods = [GameConstants.WeaponMod.NONE]
	_equipped_mod = GameConstants.WeaponMod.NONE
	_menu_open = false
	inventory_changed.emit()
	mod_unequipped.emit()

func _ready() -> void:
	# Connect to game restart to reset state
	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)
	# Connect to player death to close menu
	if GameManager:
		GameManager.player_died.connect(_on_player_died)

func _on_game_restarted() -> void:
	reset()

func _on_player_died() -> void:
	close_crafting_menu()