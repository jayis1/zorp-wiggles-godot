## Zorp Wiggles — Pet Fusion System (Phase 27)
## Combines two Adult-stage companion pets of different elemental paths into a
## unique Fusion Pet that inherits both paths' abilities at a boosted level.
## The fusion pet is permanent for the run and replaces both donor pets.
##
## Because the game only supports one active pet at a time, the fusion workflow
## is:
##   1. Player has an active pet at Adult stage on path A.
##   2. Player presses Shift+F to "bank" the current pet as donor 1.
##      The pet is dismissed and stored in this system.
##   3. Player summons a new pet, feeds it to Adult on path B (different path).
##   4. Player presses Shift+F again to bank it as donor 2.
##   5. When both donors are banked and meet the criteria, the player presses
##      Shift+F to confirm the fusion (consumes 1 PRISM_HEART rare material).
##   6. A fusion pet is spawned, combining both donors' abilities.
##
## Only one fusion pet per run. The fusion pet cannot be fused again.
##
## Public API:
##   bank_current_pet() -> bool                — store active pet as next donor
##   can_fuse() -> bool                         — both donors ready + material available
##   try_fuse() -> bool                         — execute the fusion, spawns fusion pet
##   get_donor_count() -> int                   — 0, 1, or 2
##   get_donor_path(slot: int) -> int           — path of donor 0 or 1
##   get_fusion_type() -> int                   — predicted PetFusionType or NONE
##   has_fusion_pet() -> bool                   — is a fusion pet currently active?
##   reset() -> void                            — clear on game restart / death
##
## Signals:
##   donor_banked(slot: int, path: int)
##   fusion_ready(fusion_type: int)
##   fusion_completed(fusion_type: int)
##   fusion_failed(reason: String)

extends Node

signal donor_banked(slot: int, path: int)
signal fusion_ready(fusion_type: int)
signal fusion_completed(fusion_type: int)
signal fusion_failed(reason: String)

# Donor info: path + stage (must be Adult). We store path+stage, not the node.
var _donors: Array[Dictionary] = []  # [{path: int}, ...]
var _fusion_pet_active: bool = false
var _active_fusion_type: int = GameConstants.PetFusionType.NONE


func _ready() -> void:
	if GameManager and not GameManager.game_restarted.is_connected(_on_game_restarted):
		GameManager.game_restarted.connect(_on_game_restarted)
	if GameManager and not GameManager.player_died.is_connected(_on_player_died):
		GameManager.player_died.connect(_on_player_died)


func get_donor_count() -> int:
	return _donors.size()


func get_donor_path(slot: int) -> int:
	if slot < 0 or slot >= _donors.size():
		return GameConstants.PetPath.PRISMATIC
	return _donors[slot].get("path", GameConstants.PetPath.PRISMATIC)


## Predict the PetFusionType from the current donors. Returns NONE if not ready.
func get_fusion_type() -> int:
	if _donors.size() < 2:
		return GameConstants.PetFusionType.NONE
	var p1: int = _donors[0].get("path", 0)
	var p2: int = _donors[1].get("path", 0)
	if p1 == p2:
		return GameConstants.PetFusionType.NONE  # Same path can't fuse
	var lo: int = mini(p1, p2)
	var hi: int = maxi(p1, p2)
	var key: String = "%d,%d" % [lo, hi]
	return GameConstants.PET_FUSION_PAIR_MAP.get(key, GameConstants.PetFusionType.NONE)


func has_fusion_pet() -> bool:
	return _fusion_pet_active


func get_active_fusion_type() -> int:
	return _active_fusion_type


## Bank the currently active pet as the next donor. Returns true on success.
func bank_current_pet() -> bool:
	if _fusion_pet_active:
		GameManager.add_message("A fusion pet is already active — can't bank.")
		return false
	if _donors.size() >= 2:
		GameManager.add_message("Both donors ready! Press Shift+F to fuse.")
		return false
	var pet: Node3D = get_tree().get_first_node_in_group("companion_pet")
	if not pet or not is_instance_valid(pet):
		GameManager.add_message("No active pet to bank! Summon one first (F key).")
		return false
	# Check the pet is at Adult stage
	if pet.get("stage") != GameConstants.PetStage.ADULT:
		GameManager.add_message("Pet must be Adult stage to fuse! Feed it more collectibles.")
		return false
	# Check the pet is on a non-PRISMATIC path
	var path: int = pet.get("evolution_path") if "evolution_path" in pet else 0
	if path == GameConstants.PetPath.PRISMATIC:
		GameManager.add_message("Pet needs an elemental path (use an evolution stone) before fusing!")
		return false
	# Check we don't already have a donor with the same path
	for d in _donors:
		if d.get("path", -1) == path:
			GameManager.add_message("Already have a donor on the %s path. Fuse with a DIFFERENT path." % GameConstants.PET_PATH_NAMES[path])
			return false
	# Bank it: store path + stage, then dismiss the pet
	_donors.append({"path": path})
	donor_banked.emit(_donors.size() - 1, path)
	# Dismiss the pet
	ParticleEffects.spawn_death_poof(pet.get_parent(), pet.global_position, Color(0.8, 0.6, 1.0), 1.0)
	pet.queue_free()
	GameManager.add_message("🔮 Banked %s-path donor (%d/2). Summon a different path next." % [
		GameConstants.PET_PATH_NAMES[path], _donors.size()
	])
	AudioManager.play_sfx(AudioManager.SFX_PET)
	if _donors.size() == 2:
		var ft: int = get_fusion_type()
		if ft != GameConstants.PetFusionType.NONE:
			fusion_ready.emit(ft)
			GameManager.add_message("✨ Fusion ready! Press Shift+F to create a %s!" % GameConstants.PET_FUSION_NAMES[ft])
	return true


func can_fuse() -> bool:
	if _donors.size() < 2:
		return false
	if _fusion_pet_active:
		return false
	if get_fusion_type() == GameConstants.PetFusionType.NONE:
		return false
	# Need 1 PRISM_HEART rare material
	if not EquipmentSystem or EquipmentSystem.get_rare_material_count(GameConstants.RareMaterial.PRISM_HEART) < 1:
		return false
	return true


## Execute the fusion. Consumes 1 PRISM_HEART, dismisses any active pet,
## spawns a fusion pet with the combined type.
func try_fuse() -> bool:
	if _donors.size() < 2:
		GameManager.add_message("Need 2 banked donors to fuse! Press Shift+F to bank your pet.")
		return false
	if _fusion_pet_active:
		GameManager.add_message("A fusion pet is already active!")
		return false
	var ft: int = get_fusion_type()
	if ft == GameConstants.PetFusionType.NONE:
		GameManager.add_message("Donors have the same path — can't fuse. Bank a different path.")
		fusion_failed.emit("Same path donors")
		return false
	# Consume PRISM_HEART
	if not EquipmentSystem or not EquipmentSystem.consume_rare_material(GameConstants.RareMaterial.PRISM_HEART, 1):
		GameManager.add_message("Need 1 Prism Heart rare material to fuse! Boss drops provide these.")
		fusion_failed.emit("No Prism Heart")
		return false
	# Dismiss any currently active pet
	var old_pet: Node3D = get_tree().get_first_node_in_group("companion_pet")
	if old_pet and is_instance_valid(old_pet):
		ParticleEffects.spawn_death_poof(old_pet.get_parent(), old_pet.global_position, Color(0.8, 0.6, 1.0), 1.0)
		old_pet.queue_free()
	# Spawn the fusion pet
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		fusion_failed.emit("No player")
		return false
	var fusion_pet := preload("res://scenes/entities/companion_pet.tscn").instantiate() as CharacterBody3D
	player.get_parent().add_child(fusion_pet)
	fusion_pet.global_position = player.global_position + GameConstants.PET_SPAWN_OFFSET
	# Configure the fusion pet: set to Adult stage with fusion stats
	if "stage" in fusion_pet:
		fusion_pet.stage = GameConstants.PetStage.ADULT
	if "evolution_path" in fusion_pet:
		# We use a meta flag to mark this as a fusion pet; the path is set to the
		# first donor's path so existing path-ability code runs, but the fusion
		# abilities layer on top.
		fusion_pet.evolution_path = _donors[0].get("path", 0)
	fusion_pet.set_meta("is_fusion_pet", true)
	fusion_pet.set_meta("fusion_type", ft)
	fusion_pet.set_meta("fusion_paths", [_donors[0].get("path", 0), _donors[1].get("path", 0)])
	# Apply fusion colors/stats by overriding stage config via meta
	fusion_pet.set_meta("fusion_color", GameConstants.PET_FUSION_COLORS[ft])
	fusion_pet.set_meta("fusion_emission", GameConstants.PET_FUSION_EMISSIONS[ft])
	fusion_pet.set_meta("fusion_hp", GameConstants.PET_FUSION_HP)
	fusion_pet.set_meta("fusion_damage", GameConstants.PET_FUSION_ATTACK_DAMAGE)
	fusion_pet.set_meta("fusion_range", GameConstants.PET_FUSION_ATTACK_RANGE)
	fusion_pet.set_meta("fusion_cooldown", GameConstants.PET_FUSION_ATTACK_COOLDOWN)
	fusion_pet.set_meta("fusion_speed", GameConstants.PET_FUSION_SPEED)
	fusion_pet.set_meta("fusion_collect_radius", GameConstants.PET_FUSION_COLLECT_RADIUS)
	fusion_pet.set_meta("fusion_shield_reduction", GameConstants.PET_FUSION_SHIELD_REDUCTION)
	fusion_pet.set_meta("fusion_scale", GameConstants.PET_FUSION_SCALE)
	# Big fusion spawn effect
	ParticleEffects.spawn_combo_fireworks(player.get_parent(), fusion_pet.global_position, 4)
	ParticleEffects.spawn_explosion(player.get_parent(), fusion_pet.global_position, GameConstants.PET_FUSION_COLORS[ft], 40, 0.8)
	_fusion_pet_active = true
	_active_fusion_type = ft
	# Clear donors
	_donors.clear()
	fusion_completed.emit(ft)
	GameManager.add_message("✨ Fused a %s! A legendary companion is born!" % GameConstants.PET_FUSION_NAMES[ft])
	AudioManager.play_sfx(AudioManager.SFX_PET)
	# Tutorial notification
	if TutorialManager and TutorialManager.has_method("notify_pet_summoned"):
		TutorialManager.notify_pet_summoned()
	print("[PetFusion] Created fusion pet type %d (%s)" % [ft, GameConstants.PET_FUSION_NAMES[ft]])
	return true


## Called by companion_pet.gd to check if it's a fusion pet and get override stats.
func get_fusion_override(pet: Node3D) -> Dictionary:
	if not pet or not is_instance_valid(pet):
		return {}
	if not pet.has_meta("is_fusion_pet"):
		return {}
	return {
		"color": pet.get_meta("fusion_color", Color(0.5, 0.5, 0.5)),
		"emission": pet.get_meta("fusion_emission", Color(0.3, 0.3, 0.3)),
		"hp": int(pet.get_meta("fusion_hp", 150)),
		"attack_damage": int(pet.get_meta("fusion_damage", 22)),
		"attack_range": float(pet.get_meta("fusion_range", 9.0)),
		"attack_cooldown": float(pet.get_meta("fusion_cooldown", 0.7)),
		"speed": float(pet.get_meta("fusion_speed", 16.0)),
		"collect_radius": float(pet.get_meta("fusion_collect_radius", 20.0)),
		"shield_reduction": float(pet.get_meta("fusion_shield_reduction", 0.30)),
		"scale": float(pet.get_meta("fusion_scale", 0.85)),
		"fusion_type": int(pet.get_meta("fusion_type", 0)),
		"fusion_paths": pet.get_meta("fusion_paths", []),
	}


## Check if a pet node is a fusion pet.
func is_fusion_pet(pet: Node3D) -> bool:
	return pet != null and is_instance_valid(pet) and pet.has_meta("is_fusion_pet")


## Called when the fusion pet dies — we can't respawn it (it's permanent for the
## run, but death is permanent). The player loses the fusion pet.
func on_fusion_pet_died() -> void:
	_fusion_pet_active = false
	_active_fusion_type = GameConstants.PetFusionType.NONE


func reset() -> void:
	_donors.clear()
	_fusion_pet_active = false
	_active_fusion_type = GameConstants.PetFusionType.NONE


func _on_game_restarted() -> void:
	reset()


func _on_player_died() -> void:
	reset()