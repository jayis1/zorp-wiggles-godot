## Zorp Wiggles — Pet Accessory System (Phase 27)
## Manages owned pet accessories, equipped slots, and crafting. Accessories
## are small equippable items that grant passive bonuses to the companion pet
## and the player while the pet is alive. Only one accessory per slot.
##
## Public API:
##   craft_accessory(id: int) -> bool          — craft from common materials
##   owns_accessory(id: int) -> bool            — has this accessory been crafted?
##   equip_accessory(id: int) -> bool           — equip into its slot (replaces prev)
##   unequip_slot(slot: int) -> void            — remove whatever is in this slot
##   get_equipped_in_slot(slot: int) -> int     — accessory ID or NONE
##   get_all_equipped() -> Array[int]           — one per slot (NONE if empty)
##   get_accessory_slot(id: int) -> int         — slot index or -1
##   get_stat_bonus(stat: String) -> float      — aggregated bonus from all equipped
##   reset()                                    — clear on game restart / death
##
## Signals:
##   accessory_crafted(id: int)
##   accessory_equipped(id: int, slot: int)
##   accessory_unequipped(slot: int)
##   accessories_changed()                      — general refresh signal
##
## Stat keys queried by get_stat_bonus():
##   "pet_speed_mult"     — float multiplier (1.0 + 0.20 × collar_speed)
##   "pet_hp_mult"        — float multiplier (1.0 + 0.30 × collar_hp)
##   "pet_collect_radius" — flat bonus to collect radius (meters)
##   "pet_damage_reduction"— 0..1 incoming damage reduction to the pet
##   "pet_attack_damage"  — flat bonus to pet attack damage
##   "pet_attack_range"   — flat bonus to pet attack range (meters)
##   "pet_attack_cooldown_mult" — multiplier for attack cooldown (1.0 × 0.8 for adept crown)
##   "player_loot_mult"   — float multiplier for player loot chance
##   "player_xp_mult"     — float multiplier for player XP gain
##   "hover_collect_while_dash" — bool flag (1.0 if Hover Wings equipped, 0.0 otherwise)

extends Node

signal accessory_crafted(id: int)
signal accessory_equipped(id: int, slot: int)
signal accessory_unequipped(slot: int)
signal accessories_changed()

# Owned accessory IDs (set)
var _owned: Dictionary = {}  # {id: true}
# Equipped accessory per slot index → accessory ID (or NONE)
var _equipped: Array[int] = [
	GameConstants.PetAccessory.NONE,
	GameConstants.PetAccessory.NONE,
	GameConstants.PetAccessory.NONE,
	GameConstants.PetAccessory.NONE,
	GameConstants.PetAccessory.NONE,
]


func _ready() -> void:
	if GameManager and not GameManager.game_restarted.is_connected(_on_game_restarted):
		GameManager.game_restarted.connect(_on_game_restarted)
	if GameManager and not GameManager.player_died.is_connected(_on_player_died):
		GameManager.player_died.connect(_on_player_died)


func craft_accessory(id: int) -> bool:
	if id <= GameConstants.PetAccessory.NONE or id >= GameConstants.PET_ACCESSORY_COUNT:
		return false
	if _owned.has(id):
		return false  # Already owned
	var cost: Array = GameConstants.PET_ACCESSORY_CRAFT_COST[id]
	if cost.is_empty():
		return false
	# Check materials via WeaponModSystem
	if not WeaponModSystem:
		return false
	if not WeaponModSystem.remove_materials(cost):
		GameManager.add_message("Not enough materials to craft %s!" % GameConstants.PET_ACCESSORY_NAMES[id])
		return false
	_owned[id] = true
	accessory_crafted.emit(id)
	accessories_changed.emit()
	GameManager.add_message("🎀 Crafted %s!" % GameConstants.PET_ACCESSORY_NAMES[id])
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	return true


func owns_accessory(id: int) -> bool:
	return _owned.has(id)


func can_craft(id: int) -> bool:
	if id <= GameConstants.PetAccessory.NONE or id >= GameConstants.PET_ACCESSORY_COUNT:
		return false
	if _owned.has(id):
		return false
	var cost: Array = GameConstants.PET_ACCESSORY_CRAFT_COST[id]
	if cost.is_empty():
		return false
	if not WeaponModSystem:
		return false
	# Check we have enough of each material
	var needed: Dictionary = {}
	for t in cost:
		needed[t] = needed.get(t, 0) + 1
	for type in needed:
		if WeaponModSystem.get_material_count(type) < needed[type]:
			return false
	return true


func equip_accessory(id: int) -> bool:
	if not _owned.has(id):
		return false
	var slot: int = GameConstants.PET_ACCESSORY_SLOT[id]
	if slot < 0 or slot >= GameConstants.PET_ACCESSORY_SLOT_COUNT:
		return false
	_equipped[slot] = id
	accessory_equipped.emit(id, slot)
	accessories_changed.emit()
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	return true


func unequip_slot(slot: int) -> void:
	if slot < 0 or slot >= GameConstants.PET_ACCESSORY_SLOT_COUNT:
		return
	if _equipped[slot] != GameConstants.PetAccessory.NONE:
		_equipped[slot] = GameConstants.PetAccessory.NONE
		accessory_unequipped.emit(slot)
		accessories_changed.emit()


func get_equipped_in_slot(slot: int) -> int:
	if slot < 0 or slot >= GameConstants.PET_ACCESSORY_SLOT_COUNT:
		return GameConstants.PetAccessory.NONE
	return _equipped[slot]


func get_all_equipped() -> Array[int]:
	return _equipped.duplicate()


func get_accessory_slot(id: int) -> int:
	if id < 0 or id >= GameConstants.PET_ACCESSORY_COUNT:
		return -1
	return GameConstants.PET_ACCESSORY_SLOT[id]


## Aggregated stat bonus from all currently-equipped accessories.
func get_stat_bonus(stat: String) -> float:
	var val: float = 0.0
	for slot_id in _equipped:
		if slot_id == GameConstants.PetAccessory.NONE:
			continue
		match stat:
			"pet_speed_mult":
				if slot_id == GameConstants.PetAccessory.COLLAR_SPEED:
					val += 0.20
			"pet_hp_mult":
				if slot_id == GameConstants.PetAccessory.COLLAR_HP:
					val += 0.30
			"pet_collect_radius":
				if slot_id == GameConstants.PetAccessory.WINGS_GLIDER:
					val += 2.0
			"pet_damage_reduction":
				if slot_id == GameConstants.PetAccessory.ARMOR_PLATED:
					val += 0.25
			"pet_attack_damage":
				if slot_id == GameConstants.PetAccessory.CROWN_REGAL:
					val += 1.0
			"pet_attack_range":
				if slot_id == GameConstants.PetAccessory.CROWN_REGAL:
					val += 0.5
			"pet_attack_cooldown_mult":
				if slot_id == GameConstants.PetAccessory.CROWN_ADEPT:
					# Multiplicative — only one crown slot, so set directly.
					# 0.8 means the pet attacks 20% faster (cooldown × 0.8).
					val = 0.8
			"player_loot_mult":
				if slot_id == GameConstants.PetAccessory.BOW_LUCK:
					val += 0.15
			"player_xp_mult":
				if slot_id == GameConstants.PetAccessory.BOW_CHARM:
					val += 0.10
			"hover_collect_while_dash":
				if slot_id == GameConstants.PetAccessory.WINGS_HOVER:
					val = 1.0
			"spiked_armor":
				if slot_id == GameConstants.PetAccessory.ARMOR_SPIKED:
					val += 1.0
	# Default multiplier stats should return 1.0 baseline if no bonus
	match stat:
		"pet_speed_mult", "pet_hp_mult", "pet_attack_cooldown_mult":
			if val == 0.0:
				val = 1.0
			elif stat == "pet_attack_cooldown_mult" and val == 0.0:
				val = 1.0
	return val


## Does any equipped accessory grant spiked armor reflect?
func has_spiked_armor() -> bool:
	return get_stat_bonus("spiked_armor") > 0.0


## Returns a human-readable summary of equipped accessories for HUD display.
func get_equipped_summary() -> String:
	var parts: Array[String] = []
	for slot_id in _equipped:
		if slot_id != GameConstants.PetAccessory.NONE:
			parts.append(GameConstants.PET_ACCESSORY_ICONS[slot_id])
	if parts.is_empty():
		return ""
	return " ".join(parts)


func get_owned_ids() -> Array:
	return _owned.keys()


func reset() -> void:
	_owned.clear()
	for i in range(GameConstants.PET_ACCESSORY_SLOT_COUNT):
		_equipped[i] = GameConstants.PetAccessory.NONE
	accessories_changed.emit()


func _on_game_restarted() -> void:
	reset()


func _on_player_died() -> void:
	reset()