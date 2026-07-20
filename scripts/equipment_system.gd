## Zorp Wiggles — Equipment System (Phase 29: Crafting & Equipment Expansion)
## Autoload singleton managing the player's equipment inventory, equipped
## pieces (head/body/accessory slots), set bonuses, rare material inventory,
## consumable inventory, material refinement, and equipment crafting.
##
## Design:
##   - Equipment pieces are crafted from common materials (WeaponModSystem
##     inventory) + rare materials (this system's inventory).
##   - Wearing matching pieces of a set grants a set bonus (2-piece and 3-piece).
##   - Equipment pieces can be upgraded to +1/+2/+3 with materials (+20% stats/level).
##   - Consumables are single-use items crafted from materials; use with keys 1-5.
##   - Rare materials drop from bosses, weather-specific sources, and biome-specific
##     sources (see enemy_base.gd _drop_rare_material).
##   - Refinement: 3 common materials → 1 rare material (no other cost).
##
## Integration points:
##   - player.gd: speed_mult, fire_rate, damage
##   - game_manager.gd: max_hp, damage_reduction, xp gain, loot chance
##   - projectile.gd: crit_chance, damage
##   - enemy_base.gd: rare material drops
##   - equipment_menu.gd: UI for all of this

extends Node

# ─── Signals ──────────────────────────────────────────────────────────────────
signal equipment_changed()                      # Equipped pieces changed
signal rare_material_changed()                  # Rare material inventory changed
signal consumable_changed()                     # Consumable inventory changed
signal piece_crafted(piece_id: int)             # New equipment piece crafted
signal piece_equipped(slot: int, piece_id: int) # Piece equipped to a slot
signal piece_unequipped(slot: int)              # Piece removed from a slot
signal piece_upgraded(piece_id: int, new_level: int)  # Piece upgraded
signal consumable_used(consumable_id: int)      # Consumable consumed
signal consumable_effect_started(consumable_id: int, duration: float)  # Temporary effect active
signal consumable_effect_ended(consumable_id: int)    # Temporary effect expired
signal material_refined(rare_material_id: int)  # Rare material created via refinement
signal equipment_menu_toggled(is_open: bool)    # Menu open/close

# ─── State ─────────────────────────────────────────────────────────────────────
# Rare material inventory: maps RareMaterial enum int → count
var _rare_materials: Dictionary = {}

# Consumable inventory: maps Consumable enum int → count (stacked)
var _consumables: Dictionary = {}

# Crafted equipment pieces: maps EquipPiece enum int → upgrade_level (0-3)
# A piece is "owned" if it's in this dict. Upgrade level 0 = base stats.
var _owned_pieces: Dictionary = {}

# Equipped pieces: maps slot (0=head, 1=body, 2=accessory) → EquipPiece enum int
# Value -1 means nothing equipped in that slot.
var _equipped: Array[int] = [-1, -1, -1]

# Active consumable effects: maps Consumable enum int → remaining time (seconds)
# Only one effect of each type active at a time (refreshing extends duration).
var _active_effects: Dictionary = {}

# Whether the equipment menu is currently open
var _menu_open: bool = false

# ─── Public API: Rare Materials ────────────────────────────────────────────────

## How many of a given rare material the player currently holds.
func get_rare_material_count(type: int) -> int:
	return _rare_materials.get(type, 0)

## The full rare material inventory as a Dictionary { RareMaterial: count }.
func get_rare_material_inventory() -> Dictionary:
	return _rare_materials.duplicate()

## Add a rare material to inventory. Called when a rare material collectible is picked up.
func add_rare_material(type: int, amount: int = 1) -> void:
	_rare_materials[type] = _rare_materials.get(type, 0) + amount
	rare_material_changed.emit()

## Remove rare materials from inventory. Returns true if successful, false if not enough.
func remove_rare_materials(types: Dictionary) -> bool:
	# Check we have enough of each
	for type in types:
		if _rare_materials.get(type, 0) < types[type]:
			return false
	# Remove them
	for type in types:
		_rare_materials[type] -= types[type]
		if _rare_materials[type] <= 0:
			_rare_materials.erase(type)
	rare_material_changed.emit()
	return true

## Consume a single rare material type (convenience wrapper). Returns true on success.
func consume_rare_material(type: int, amount: int = 1) -> bool:
	if _rare_materials.get(type, 0) < amount:
		return false
	_rare_materials[type] -= amount
	if _rare_materials[type] <= 0:
		_rare_materials.erase(type)
	rare_material_changed.emit()
	return true

# ─── Public API: Consumables ──────────────────────────────────────────────────

## How many of a given consumable the player currently holds.
func get_consumable_count(type: int) -> int:
	return _consumables.get(type, 0)

## The full consumable inventory as a Dictionary { Consumable: count }.
func get_consumable_inventory() -> Dictionary:
	return _consumables.duplicate()

## Add a consumable to inventory (respects max stack size). Returns true on success.
func add_consumable(type: int, amount: int = 1) -> bool:
	var current: int = _consumables.get(type, 0)
	if current + amount > GameConstants.CONSUMABLE_MAX_STACK:
		GameManager.add_message("⚠ %s stack full (%d/%d)" % [
			GameConstants.CONSUMABLE_NAMES[type], current, GameConstants.CONSUMABLE_MAX_STACK
		])
		return false
	_consumables[type] = current + amount
	consumable_changed.emit()
	return true

## Use a consumable (called by hotkey 1-5). Returns true if consumed.
func use_consumable(type: int) -> bool:
	if _consumables.get(type, 0) <= 0:
		GameManager.add_message("⚠ No %s left!" % GameConstants.CONSUMABLE_NAMES[type])
		return false
	# Don't allow use if already at max effect of the same type
	var duration: float = GameConstants.CONSUMABLE_EFFECT_DURATION[type]
	var value: float = GameConstants.CONSUMABLE_EFFECT_VALUE[type]
	# Consume the item
	_consumables[type] -= 1
	if _consumables[type] <= 0:
		_consumables.erase(type)
	consumable_changed.emit()
	consumable_used.emit(type)
	# ── Phase 29: Statistics tracking ──
	if Statistics and Statistics.has_method("record_consumable_used"):
		Statistics.record_consumable_used(type)
	# Apply the effect
	match type:
		GameConstants.Consumable.HEALTH_POTION:
			# Instant heal
			# ── Phase 34: Survival mode — no healing ──
			GameManager.block_heal_next_call()
			GameManager.heal(int(value))
			if GameModeManager and GameModeManager.is_survival():
				GameManager.add_message("☠ Survival: Healing suppressed!")
			else:
				GameManager.add_message("🧪 Healed %d HP!" % int(value))
		GameConstants.Consumable.SPEED_POTION:
			_active_effects[type] = duration
			consumable_effect_started.emit(type, duration)
			GameManager.add_message("💨 Speed boost for %.0fs!" % duration)
		GameConstants.Consumable.SHIELD_POTION:
			_active_effects[type] = duration
			consumable_effect_started.emit(type, duration)
			GameManager.add_message("🛡 Shield boost for %.0fs!" % duration)
		GameConstants.Consumable.POWER_POTION:
			_active_effects[type] = duration
			consumable_effect_started.emit(type, duration)
			GameManager.add_message("💪 Power boost for %.0fs!" % duration)
		GameConstants.Consumable.VOID_BOMB:
			# Instant AoE explosion at player position
			_detonate_void_bomb()
			GameManager.add_message("💥 Void Bomb!")
	# Play SFX
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_LEVEL_UP)  # Reuse a positive SFX
	return true

## Detonate a Void Bomb at the player's position, damaging all enemies in radius.
func _detonate_void_bomb() -> void:
	if not GameManager.player or not is_instance_valid(GameManager.player):
		return
	var center: Vector3 = GameManager.player.global_position
	var radius: float = GameConstants.CONSUMABLE_AOE_RADIUS
	var damage: int = int(GameConstants.CONSUMABLE_EFFECT_VALUE[GameConstants.Consumable.VOID_BOMB])
	# Damage all enemies in radius
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_method("take_damage_from"):
			continue
		var dist: float = enemy.global_position.distance_to(center)
		if dist <= radius:
			# Falloff: full damage at center, 50% at edge
			var falloff: float = 1.0 - 0.5 * (dist / radius)
			var dmg: int = int(damage * falloff)
			enemy.take_damage_from(dmg, center)
	# Visual: spawn a big explosion + camera shake
	if GameManager.player and is_instance_valid(GameManager.player):
		var parent: Node = GameManager.player.get_parent()
		if parent:
			ParticleEffects.spawn_mega_explosion(parent, center)
	# Camera shake
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.5)

# ─── Public API: Equipment Pieces ──────────────────────────────────────────────

## Does the player own this equipment piece?
func owns_piece(piece_id: int) -> bool:
	return _owned_pieces.has(piece_id)

## Get the upgrade level of a piece (0 if not owned, 0-3 if owned).
func get_piece_upgrade_level(piece_id: int) -> int:
	return _owned_pieces.get(piece_id, 0)

## Get all owned piece IDs.
func get_owned_pieces() -> Array:
	return _owned_pieces.keys()

## Get the full owned-pieces dictionary { piece_id: upgrade_level }.
## Used by SaveSystem to serialize both ownership and upgrade state.
func get_owned_pieces_dict() -> Dictionary:
	return _owned_pieces.duplicate()

## What's equipped in the given slot? Returns EquipPiece enum int or -1.
func get_equipped_piece(slot: int) -> int:
	if slot < 0 or slot >= GameConstants.EQUIP_SLOT_COUNT:
		return -1
	return _equipped[slot]

# ── Phase 31: Save/Load setters (called by SaveSystem) ──
## Replace the rare-material inventory from a save file.
func set_rare_material_inventory(inv: Dictionary) -> void:
	_rare_materials = inv.duplicate()
	rare_material_changed.emit()

## Replace the consumable inventory from a save file.
func set_consumable_inventory(inv: Dictionary) -> void:
	_consumables = inv.duplicate()
	consumable_changed.emit()

## Replace the owned-pieces dictionary { piece_id: upgrade_level } from a save.
func set_owned_pieces(pieces: Dictionary) -> void:
	_owned_pieces = pieces.duplicate()
	equipment_changed.emit()

## Force-set all three equipped slots from a save (bypasses ownership check).
func set_equipped_pieces(eq: Array) -> void:
	for i in range(min(3, eq.size())):
		_equipped[i] = int(eq[i])
	equipment_changed.emit()

## Equip a piece to its slot. Returns true on success.
func equip_piece(piece_id: int) -> bool:
	if not owns_piece(piece_id):
		GameManager.add_message("⚠ Don't own %s" % GameConstants.EQUIP_PIECE_NAMES[piece_id])
		return false
	var slot: int = GameConstants.EQUIP_PIECE_SLOT[piece_id]
	var old: int = _equipped[slot]
	_equipped[slot] = piece_id
	piece_equipped.emit(slot, piece_id)
	equipment_changed.emit()
	if old != piece_id and old >= 0:
		GameManager.add_message("👕 Equipped %s" % GameConstants.EQUIP_PIECE_NAMES[piece_id])
	return true

## Unequip whatever is in the given slot.
func unequip_slot(slot: int) -> void:
	if slot < 0 or slot >= GameConstants.EQUIP_SLOT_COUNT:
		return
	if _equipped[slot] < 0:
		return
	var old: int = _equipped[slot]
	_equipped[slot] = -1
	piece_unequipped.emit(slot)
	equipment_changed.emit()
	GameManager.add_message("👕 Unequipped %s" % GameConstants.EQUIP_PIECE_NAMES[old])

## Craft an equipment piece. Consumes materials from both inventories.
## Returns true on success.
func craft_piece(piece_id: int) -> bool:
	var recipe: Dictionary = GameConstants.EQUIP_CRAFT_RECIPES.get(piece_id, {})
	if recipe.is_empty():
		return false
	# Check common materials (WeaponModSystem inventory)
	var common_cost: Dictionary = recipe.get("common", {})
	if not _check_common_materials(common_cost):
		GameManager.add_message("⚠ Not enough common materials for %s" % GameConstants.EQUIP_PIECE_NAMES[piece_id])
		return false
	# Check rare materials (this system's inventory)
	var rare_cost: Dictionary = recipe.get("rare", {})
	if not _check_rare_materials(rare_cost):
		GameManager.add_message("⚠ Not enough rare materials for %s" % GameConstants.EQUIP_PIECE_NAMES[piece_id])
		return false
	# Consume common materials
	if not _consume_common_materials(common_cost):
		return false
	# Consume rare materials
	if not remove_rare_materials(rare_cost):
		# Refund common materials if rare consumption failed (shouldn't happen after check)
		_refund_common_materials(common_cost)
		return false
	# Add the piece to owned inventory at upgrade level 0
	_owned_pieces[piece_id] = 0
	piece_crafted.emit(piece_id)
	equipment_changed.emit()
	GameManager.add_message("✨ Crafted %s!" % GameConstants.EQUIP_PIECE_NAMES[piece_id])
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_LEVEL_UP)
	# ── Phase 29: Statistics tracking ──
	if Statistics and Statistics.has_method("record_equipment_crafted"):
		Statistics.record_equipment_crafted(piece_id)
	return true

## Check if the player has enough common materials (in WeaponModSystem inventory).
func _check_common_materials(cost: Dictionary) -> bool:
	if not WeaponModSystem:
		return cost.is_empty()
	for type in cost:
		if WeaponModSystem.get_material_count(type) < cost[type]:
			return false
	return true

## Check if the player has enough rare materials (in this system's inventory).
func _check_rare_materials(cost: Dictionary) -> bool:
	for type in cost:
		if get_rare_material_count(type) < cost[type]:
			return false
	return true

## Consume common materials from WeaponModSystem inventory.
func _consume_common_materials(cost: Dictionary) -> bool:
	if cost.is_empty():
		return true
	if not WeaponModSystem:
		return false
	# Build the array of material types (with repeats for count)
	var types: Array = []
	for type in cost:
		for i in range(cost[type]):
			types.append(type)
	return WeaponModSystem.remove_materials(types)

## Refund common materials to WeaponModSystem inventory (error recovery).
func _refund_common_materials(cost: Dictionary) -> void:
	if not WeaponModSystem:
		return
	for type in cost:
		WeaponModSystem.add_material(type, cost[type])

## Upgrade an owned equipment piece by one level. Returns true on success.
func upgrade_piece(piece_id: int) -> bool:
	if not owns_piece(piece_id):
		GameManager.add_message("⚠ Don't own %s" % GameConstants.EQUIP_PIECE_NAMES[piece_id])
		return false
	var current_level: int = _owned_pieces[piece_id]
	if current_level >= GameConstants.EQUIP_MAX_UPGRADE_LEVEL:
		GameManager.add_message("⚠ %s already at max upgrade (+%d)" % [
			GameConstants.EQUIP_PIECE_NAMES[piece_id], current_level
		])
		return false
	# Compute upgrade cost: base * scale^current_level, using the piece's theme material
	var cost_type: int = _get_upgrade_material_type(piece_id)
	var cost_count: int = int(GameConstants.EQUIP_UPGRADE_BASE_COST * pow(GameConstants.EQUIP_UPGRADE_COST_SCALE, current_level))
	var cost: Dictionary = {cost_type: cost_count}
	# Check and consume
	if not WeaponModSystem or WeaponModSystem.get_material_count(cost_type) < cost_count:
		GameManager.add_message("⚠ Need %d %s to upgrade %s" % [
			cost_count, GameConstants.COLLECTIBLE_TYPE_NAMES.get(cost_type, "material"),
			GameConstants.EQUIP_PIECE_NAMES[piece_id]
		])
		return false
	var types: Array = []
	for i in range(cost_count):
		types.append(cost_type)
	if not WeaponModSystem.remove_materials(types):
		return false
	# Increase upgrade level
	_owned_pieces[piece_id] = current_level + 1
	piece_upgraded.emit(piece_id, current_level + 1)
	equipment_changed.emit()
	GameManager.add_message("⬆ %s upgraded to +%d!" % [GameConstants.EQUIP_PIECE_NAMES[piece_id], current_level + 1])
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_LEVEL_UP)
	return true

## Get the "theme" material type for a piece (used for upgrade costs).
## Uses the first common material in the piece's craft recipe.
func _get_upgrade_material_type(piece_id: int) -> int:
	var recipe: Dictionary = GameConstants.EQUIP_CRAFT_RECIPES.get(piece_id, {})
	var common: Dictionary = recipe.get("common", {})
	if common.is_empty():
		return GameConstants.CollectibleType.SPACE_GLOOP  # Fallback
	return common.keys()[0]

# ─── Public API: Refinement ────────────────────────────────────────────────────

## Refine common materials into a rare material (single-input recipe).
## Returns true on success.
func refine_material(rare_id: int) -> bool:
	# Check single-input recipes first
	if GameConstants.REFINEMENT_RECIPES.has(rare_id):
		var recipe: Dictionary = GameConstants.REFINEMENT_RECIPES[rare_id]
		var mat_type: int = recipe["mat"]
		var count: int = recipe["count"]
		if not WeaponModSystem or WeaponModSystem.get_material_count(mat_type) < count:
			GameManager.add_message("⚠ Need %d %s to refine" % [
				count, GameConstants.COLLECTIBLE_TYPE_NAMES.get(mat_type, "material")
			])
			return false
		var types: Array = []
		for i in range(count):
			types.append(mat_type)
		if not WeaponModSystem.remove_materials(types):
			return false
		add_rare_material(rare_id, 1)
		material_refined.emit(rare_id)
		GameManager.add_message("🔬 Refined %d %s → 1 %s" % [
			count, GameConstants.COLLECTIBLE_TYPE_NAMES.get(mat_type, "material"),
			GameConstants.RARE_MATERIAL_NAMES[rare_id]
		])
		return true
	# Check dual-input recipes
	if GameConstants.REFINEMENT_RECIPES_DUAL.has(rare_id):
		var recipe: Dictionary = GameConstants.REFINEMENT_RECIPES_DUAL[rare_id]
		var mat_types: Array = recipe["mats"]
		var count: int = recipe["count"]
		# Check both materials
		for mt in mat_types:
			if not WeaponModSystem or WeaponModSystem.get_material_count(mt) < count:
				GameManager.add_message("⚠ Need %d of each: %s + %s to refine" % [
					count,
					GameConstants.COLLECTIBLE_TYPE_NAMES.get(mat_types[0], "mat1"),
					GameConstants.COLLECTIBLE_TYPE_NAMES.get(mat_types[1], "mat2")
				])
				return false
		# Consume both
		var types: Array = []
		for mt in mat_types:
			for i in range(count):
				types.append(mt)
		if not WeaponModSystem.remove_materials(types):
			return false
		add_rare_material(rare_id, 1)
		material_refined.emit(rare_id)
		GameManager.add_message("🔬 Refined %d %s + %d %s → 1 %s" % [
			count, GameConstants.COLLECTIBLE_TYPE_NAMES.get(mat_types[0], "mat1"),
			count, GameConstants.COLLECTIBLE_TYPE_NAMES.get(mat_types[1], "mat2"),
			GameConstants.RARE_MATERIAL_NAMES[rare_id]
		])
		return true
	GameManager.add_message("⚠ No refinement recipe for %s" % GameConstants.RARE_MATERIAL_NAMES[rare_id])
	return false

# ─── Public API: Consumable Crafting ───────────────────────────────────────────

## Craft a consumable. Consumes materials from both inventories.
func craft_consumable(consumable_id: int) -> bool:
	var recipe: Dictionary = GameConstants.CONSUMABLE_CRAFT_RECIPES.get(consumable_id, {})
	if recipe.is_empty():
		return false
	var common_cost: Dictionary = recipe.get("common", {})
	var rare_cost: Dictionary = recipe.get("rare", {})
	if not _check_common_materials(common_cost):
		GameManager.add_message("⚠ Not enough materials for %s" % GameConstants.CONSUMABLE_NAMES[consumable_id])
		return false
	if not _check_rare_materials(rare_cost):
		GameManager.add_message("⚠ Not enough rare materials for %s" % GameConstants.CONSUMABLE_NAMES[consumable_id])
		return false
	if not _consume_common_materials(common_cost):
		return false
	if not remove_rare_materials(rare_cost):
		_refund_common_materials(common_cost)
		return false
	add_consumable(consumable_id, 1)
	GameManager.add_message("🧪 Crafted %s!" % GameConstants.CONSUMABLE_NAMES[consumable_id])
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_PICKUP)
	return true

# ─── Public API: Stat Bonuses ─────────────────────────────────────────────────
## These are queried by player.gd, game_manager.gd, and projectile.gd to apply
## equipment bonuses. They aggregate the stats of all equipped pieces (with
## upgrade multipliers) plus active set bonuses plus active consumable effects.

## Get the aggregate stat bonus for a given stat key (e.g. "damage_mult").
## Returns the total additive bonus (e.g. 0.15 = +15%).
func get_stat_bonus(stat_key: String) -> float:
	var total: float = 0.0
	# Sum equipped piece stats (with upgrade multipliers)
	for slot in range(GameConstants.EQUIP_SLOT_COUNT):
		var piece_id: int = _equipped[slot]
		if piece_id < 0:
			continue
		var base_stats: Dictionary = GameConstants.EQUIP_PIECE_STATS[piece_id]
		if not base_stats.has(stat_key):
			continue
		var base_val: float = base_stats[stat_key]
		var upgrade_level: int = _owned_pieces.get(piece_id, 0)
		var upgrade_mult: float = 1.0 + upgrade_level * GameConstants.EQUIP_UPGRADE_MULT_PER_LEVEL
		total += base_val * upgrade_mult
	# Add set bonuses
	for set_id in _get_active_set_bonuses():
		var bonuses: Dictionary = _get_set_bonus_dict(set_id)
		if bonuses.has(stat_key):
			total += bonuses[stat_key]
	# Add consumable effect bonuses
	total += _get_consumable_stat_bonus(stat_key)
	return total

## Get the active set bonuses (returns dict of set_id → piece_count).
func _get_active_set_bonuses() -> Dictionary:
	var active: Dictionary = {}
	for set_id in GameConstants.EQUIP_SET_PIECES.keys():
		var pieces: Array = GameConstants.EQUIP_SET_PIECES[set_id]
		var count: int = 0
		for piece_id in pieces:
			# Check if this piece is equipped in its slot
			var slot: int = GameConstants.EQUIP_PIECE_SLOT[piece_id]
			if _equipped[slot] == piece_id:
				count += 1
		if count >= 2:  # 2-piece bonus minimum
			active[set_id] = count
	return active

## Get the set bonus dict for the active set (combines 2-piece and 3-piece bonuses).
func _get_set_bonus_dict(set_id: int) -> Dictionary:
	var bonuses: Dictionary = GameConstants.EQUIP_SET_BONUSES.get(set_id, {})
	var result: Dictionary = {}
	# 2-piece bonus
	if bonuses.has(2):
		for key in bonuses[2]:
			result[key] = result.get(key, 0.0) + bonuses[2][key]
	# 3-piece bonus (added on top if 3 pieces equipped)
	var active: Dictionary = _get_active_set_bonuses()
	if active.get(set_id, 0) >= 3 and bonuses.has(3):
		for key in bonuses[3]:
			result[key] = result.get(key, 0.0) + bonuses[3][key]
	return result

## Get the consumable stat bonus for a given stat key.
func _get_consumable_stat_bonus(stat_key: String) -> float:
	var total: float = 0.0
	# Speed potion
	if _active_effects.has(GameConstants.Consumable.SPEED_POTION):
		if stat_key == "speed_mult":
			total += GameConstants.CONSUMABLE_EFFECT_VALUE[GameConstants.Consumable.SPEED_POTION]
	# Shield potion
	if _active_effects.has(GameConstants.Consumable.SHIELD_POTION):
		if stat_key == "damage_reduction":
			total += GameConstants.CONSUMABLE_EFFECT_VALUE[GameConstants.Consumable.SHIELD_POTION]
	# Power potion
	if _active_effects.has(GameConstants.Consumable.POWER_POTION):
		if stat_key == "damage_mult":
			total += GameConstants.CONSUMABLE_EFFECT_VALUE[GameConstants.Consumable.POWER_POTION]
	return total

## Convenience: total max HP bonus from equipment + sets.
func get_max_hp_bonus() -> int:
	return int(get_stat_bonus("max_hp"))

## Convenience: total damage multiplier bonus (additive, e.g. 0.15 = +15%).
func get_damage_mult_bonus() -> float:
	return get_stat_bonus("damage_mult")

## Convenience: total speed multiplier bonus (additive).
func get_speed_mult_bonus() -> float:
	return get_stat_bonus("speed_mult")

## Convenience: total crit chance bonus (additive, e.g. 0.08 = +8%).
func get_crit_chance_bonus() -> float:
	return get_stat_bonus("crit_chance")

## Convenience: total damage reduction bonus (additive, capped at 0.8).
func get_damage_reduction_bonus() -> float:
	return minf(0.8, get_stat_bonus("damage_reduction"))

## Convenience: total XP multiplier bonus (additive).
func get_xp_mult_bonus() -> float:
	return get_stat_bonus("xp_mult")

## Convenience: total loot chance bonus (additive).
func get_loot_mult_bonus() -> float:
	return get_stat_bonus("loot_mult")

## Convenience: total fire rate multiplier bonus (additive — reduces cooldown).
func get_fire_rate_mult_bonus() -> float:
	return get_stat_bonus("fire_rate_mult")

## Get the active set name (for HUD display). Returns "None" if no set active.
func get_active_set_name() -> String:
	var active: Dictionary = _get_active_set_bonuses()
	if active.is_empty():
		return "None"
	# Return the first active set (priority: legendary > epic > rare > uncommon)
	var best: int = GameConstants.EquipSet.NONE
	for set_id in active:
		if set_id > best:
			best = set_id
	if best == GameConstants.EquipSet.NONE:
		return "None"
	var count: int = active[best]
	return "%s (%dpc)" % [GameConstants.EQUIP_SET_NAMES[best], count]

# ─── Public API: Menu ──────────────────────────────────────────────────────────

func toggle_menu() -> bool:
	_menu_open = not _menu_open
	equipment_menu_toggled.emit(_menu_open)
	return _menu_open

func close_menu() -> void:
	if _menu_open:
		_menu_open = false
		equipment_menu_toggled.emit(false)

func is_menu_open() -> bool:
	return _menu_open

# ─── Processing ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Tick active consumable effects
	if not _active_effects.is_empty():
		var expired: Array = []
		for consumable_id in _active_effects:
			_active_effects[consumable_id] -= delta
			if _active_effects[consumable_id] <= 0:
				expired.append(consumable_id)
		for consumable_id in expired:
			_active_effects.erase(consumable_id)
			consumable_effect_ended.emit(consumable_id)
			GameManager.add_message("%s effect ended" % GameConstants.CONSUMABLE_NAMES[consumable_id])

# ─── Reset (on game restart) ───────────────────────────────────────────────────

func reset() -> void:
	_rare_materials.clear()
	_consumables.clear()
	_owned_pieces.clear()
	_equipped = [-1, -1, -1]
	_active_effects.clear()
	_menu_open = false
	rare_material_changed.emit()
	consumable_changed.emit()
	equipment_changed.emit()

func _ready() -> void:
	# Connect to game restart to reset state
	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)
		GameManager.player_died.connect(_on_player_died)

func _on_game_restarted() -> void:
	reset()

func _on_player_died() -> void:
	close_menu()
	# Clear active consumable effects on death
	_active_effects.clear()