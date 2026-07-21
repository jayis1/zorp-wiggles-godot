## Zorp Wiggles — Multi-Pet System (Phase 27)
## Allows the player to own up to 3 pets simultaneously and swap between them
## at will. Only ONE pet is active in the world at any given time — the other
## two are stored as serialized "pet profiles" in this autoload singleton.
##
## How it works:
##   - The player summons the first pet normally (F key). This is pet slot 0.
##   - Press Shift+F (the "cycle_pet" input action) to store the active pet
##     in its slot and instantiate the next slot's pet (or do nothing if the
##     next slot is empty and the player hasn't unlocked extra slots).
##   - Unlock extra slots via the Pet Questline (see pet_questline.gd):
##       Slot 1: unlocked by default
##       Slot 2: unlocked by questline milestone "Evolution Master"
##       Slot 3: unlocked by questline milestone "Grand Companion"
##   - When the active pet is dismissed via F, it is stored back into its slot
##     (not destroyed) unless the player chooses to release it.
##
## Pet profile data stored per slot:
##   - stage, evolution_points, evolution_path, hp, max_hp
##   - path abilities, accessories, and training stats are already in their
##     respective autoloads — they apply to whichever pet is active.
##
## Public API:
##   get_slot_count() -> int                  — how many slots are unlocked
##   is_slot_unlocked(slot) -> bool           — check if a slot is available
##   unlock_slot(slot) -> bool                — questline calls this
##   get_active_slot() -> int                 — which slot is currently active
##   get_slot_profile(slot) -> Dictionary     — serialized pet state
##   store_active_pet(pet_node) -> bool       — serialize + store the active pet
##   restore_pet_to_slot(slot, pet_scene) -> CharacterBody3D — instantiate from profile
##   cycle_to_next_slot(pet_scene) -> CharacterBody3D — swap active pet
##   has_pet_in_slot(slot) -> bool            — is there a pet stored in this slot?
##   release_pet(slot) -> void                — permanently discard a stored pet
##   reset()                                  — clear all slots on game restart
##
## Signals:
##   slot_unlocked(slot: int)
##   active_slot_changed(old_slot: int, new_slot: int)
##   pet_stored(slot: int)
##   pet_restored(slot: int)

extends Node

signal slot_unlocked(slot: int)
signal active_slot_changed(old_slot: int, new_slot: int)
signal pet_stored(slot: int)
signal pet_restored(slot: int)

const MAX_SLOTS: int = 3

# _unlocked[0] is always true (first pet slot is free).
# Slots 1 and 2 are unlocked via the Pet Questline.
var _unlocked: Array[bool] = [true, false, false]

# Serialized pet profiles. Each slot is either null (empty) or a Dictionary:
#   { "stage": int, "evolution_points": int, "evolution_path": int,
#     "hp": int, "max_hp": int }
var _profiles: Array = [null, null, null]

# The slot index of the currently-active pet, or -1 if no pet is active.
var _active_slot: int = -1


func _ready() -> void:
	if GameManager and not GameManager.game_restarted.is_connected(_on_game_restarted):
		GameManager.game_restarted.connect(_on_game_restarted)
	if GameManager and not GameManager.player_died.is_connected(_on_player_died):
		GameManager.player_died.connect(_on_player_died)


# ─── Slot Management ─────────────────────────────────────────────────────────

func get_slot_count() -> int:
	var count: int = 0
	for u in _unlocked:
		if u:
			count += 1
	return count


func is_slot_unlocked(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		return false
	return _unlocked[slot]


func unlock_slot(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		return false
	if _unlocked[slot]:
		return false  # Already unlocked
	_unlocked[slot] = true
	slot_unlocked.emit(slot)
	GameManager.add_message("🐾 Pet slot %d unlocked! You can now own up to %d pets." % [slot + 1, get_slot_count()])
	print("[MultiPet] Slot %d unlocked" % slot)
	return true


func get_active_slot() -> int:
	return _active_slot


func has_pet_in_slot(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		return false
	return _profiles[slot] != null


# ─── Pet Serialization ─────────────────────────────────────────────────────────

## Serialize the active pet node's state into the given slot. Called when
## cycling pets or dismissing back to storage. Returns true on success.
func store_active_pet(pet_node: CharacterBody3D) -> bool:
	if not is_instance_valid(pet_node):
		return false
	if _active_slot < 0 or _active_slot >= MAX_SLOTS:
		return false
	if not _unlocked[_active_slot]:
		return false
	_profiles[_active_slot] = {
		"stage": pet_node.stage,
		"evolution_points": pet_node.evolution_points,
		"evolution_path": pet_node.evolution_path,
		"hp": pet_node.hp,
		"max_hp": pet_node.max_hp,
	}
	pet_stored.emit(_active_slot)
	print("[MultiPet] Stored pet to slot %d (stage=%s, path=%s, hp=%d/%d)" %
		[_active_slot, pet_node.stage, pet_node.evolution_path, pet_node.hp, pet_node.max_hp])
	return true


## Instantiate a pet from the stored profile in the given slot. If the slot
## is empty, creates a fresh Baby-stage pet. Returns the new CharacterBody3D
## or null on failure.
func restore_pet_to_slot(slot: int, pet_scene: PackedScene) -> CharacterBody3D:
	if slot < 0 or slot >= MAX_SLOTS:
		return null
	if not _unlocked[slot]:
		return null
	var pet := pet_scene.instantiate() as CharacterBody3D
	if not pet:
		return null
	var profile: Dictionary = _profiles[slot]
	if profile.is_empty():
		# Fresh baby pet
		_active_slot = slot
		pet_restored.emit(slot)
		return pet
	# Apply stored state
	pet.stage = int(profile.get("stage", 0))
	pet.evolution_points = int(profile.get("evolution_points", 0))
	pet.evolution_path = int(profile.get("evolution_path", 0))
	pet.hp = int(profile.get("hp", 30))
	pet.max_hp = int(profile.get("max_hp", 30))
	_active_slot = slot
	pet_restored.emit(slot)
	print("[MultiPet] Restored pet from slot %d" % slot)
	return pet


## Cycle to the next unlocked slot that has a pet (or create a fresh one if
## the slot is empty but unlocked). Stores the current pet, dismisses it,
## and spawns the next slot's pet. Returns the new pet node, or null if
## cycling failed.
func cycle_to_next_slot(current_pet: CharacterBody3D, pet_scene: PackedScene) -> CharacterBody3D:
	# Store the current pet first
	if current_pet and is_instance_valid(current_pet):
		store_active_pet(current_pet)
		# Clean up the current pet without triggering death effects
		if current_pet.has_method("_cleanup_path_effects"):
			current_pet._cleanup_path_effects()
		ParticleEffects.spawn_death_poof(current_pet.get_parent(), current_pet.global_position, Color(0.5, 0.7, 1.0), 0.6)
		current_pet.queue_free()
	# Find next unlocked slot
	var old_slot: int = _active_slot
	var next_slot: int = _find_next_available_slot(old_slot)
	if next_slot < 0:
		# No other slot available — respawn the same pet
		next_slot = old_slot
	# Get parent from the player (the pet's parent is the main scene root)
	# We need a valid parent — try to get it from GameManager
	var parent_node: Node = null
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player) and player.get_parent():
		parent_node = player.get_parent()
	if not parent_node:
		return null
	var new_pet := restore_pet_to_slot(next_slot, pet_scene)
	if not new_pet:
		return null
	parent_node.add_child(new_pet)
	# Position near player
	if player and is_instance_valid(player):
		new_pet.global_position = player.global_position + GameConstants.PET_SPAWN_OFFSET
	active_slot_changed.emit(old_slot, next_slot)
	GameManager.add_message("🐾 Switched to pet slot %d" % (next_slot + 1))
	AudioManager.play_sfx(AudioManager.SFX_PET)
	return new_pet


## Find the next unlocked slot after the given one that either has a stored
## pet or is empty-but-unlocked (fresh pet). Returns -1 if no unlocked slot
## exists at all.
func _find_next_available_slot(current: int) -> int:
	for i in range(1, MAX_SLOTS + 1):
		var slot: int = (current + i) % MAX_SLOTS
		if _unlocked[slot]:
			return slot
	return -1


## Permanently discard the pet stored in a slot. Called when the player
## chooses to release a pet.
func release_pet(slot: int) -> void:
	if slot < 0 or slot >= MAX_SLOTS:
		return
	_profiles[slot] = null
	if _active_slot == slot:
		_active_slot = -1
	GameManager.add_message("🐾 Pet in slot %d released." % (slot + 1))


## Get the serialized profile for a slot (for HUD display).
func get_slot_profile(slot: int) -> Dictionary:
	if slot < 0 or slot >= MAX_SLOTS:
		return {}
	return _profiles[slot] if _profiles[slot] != null else {}


## Get a summary of all slots for the pet menu UI.
func get_all_slots_summary() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in MAX_SLOTS:
		var entry: Dictionary = {
			"slot": i,
			"unlocked": _unlocked[i],
			"has_pet": _profiles[i] != null,
			"is_active": _active_slot == i,
		}
		if _profiles[i] != null:
			entry["stage"] = int(_profiles[i].get("stage", 0))
			entry["path"] = int(_profiles[i].get("evolution_path", 0))
			entry["hp"] = int(_profiles[i].get("hp", 0))
			entry["max_hp"] = int(_profiles[i].get("max_hp", 0))
		result.append(entry)
	return result


# ─── Save/Load ───────────────────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	return {
		"unlocked": _unlocked.duplicate(),
		"active_slot": _active_slot,
		"profiles": _profiles.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	if data.has("unlocked"):
		var ul: Array = data["unlocked"]
		for i in range(mini(ul.size(), MAX_SLOTS)):
			_unlocked[i] = bool(ul[i])
	if data.has("active_slot"):
		_active_slot = int(data["active_slot"])
	if data.has("profiles"):
		var profiles: Array = data["profiles"]
		for i in range(mini(profiles.size(), MAX_SLOTS)):
			_profiles[i] = profiles[i] if profiles[i] != null else null


# ─── Reset ────────────────────────────────────────────────────────────────────

func reset() -> void:
	_unlocked = [true, false, false]
	_profiles = [null, null, null]
	_active_slot = -1


func _on_game_restarted() -> void:
	reset()


func _on_player_died() -> void:
	# Don't reset on death — pets persist to the save file.
	# But clear the active slot since the pet was freed.
	_active_slot = -1