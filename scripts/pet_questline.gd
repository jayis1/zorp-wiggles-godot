## Zorp Wiggles — Pet Questline (Phase 27)
## A series of missions/tasks that the player completes to unlock new pet
## types and capabilities. Each quest unlocks a reward:
##   Quest 1: "First Bond" — summon a pet for the first time → grants +5 SP
##   Quest 2: "Growing Pains" — evolve pet to Adolescent stage → unlocks Pet Slot 2
##   Quest 3: "Elemental Awakening" — use any evolution stone → grants +1 Star Fruit
##   Quest 4: "Full Bloom" — evolve pet to Adult stage → unlocks "Champion" pet color
##   Quest 5: "Evolution Master" — reach Adult on 2 different elemental paths
##             → unlocks Pet Slot 3
##   Quest 6: "Grand Companion" — feed pet 50 items total → unlocks "Eternal" pet aura
##   Quest 7: "Pet Savant" — complete all pet training games once → grants +3 TP
##   Quest 8: "Fusion Pioneer" — create a fusion pet → grants cosmetic "Fusion Crown"
##
## Quests are sequential — each one unlocks when the previous is completed.
## Quest progress is tracked via existing autoload signals (PetStoneInventory,
## PetTrainingSystem, PetFusionSystem, Statistics) and the companion_pet.gd
## signals (pet_stage_changed, pet_path_changed).
##
## Public API:
##   get_quest_count() -> int
##   get_active_quest() -> int              — index of current quest, or -1 if all done
##   get_quest_info(index) -> Dictionary    — {title, description, progress, target, completed}
##   is_quest_completed(index) -> bool
##   is_all_completed() -> bool
##   get_save_data() -> Dictionary
##   load_save_data(data: Dictionary) -> void
##   reset() -> void
##
## Signals:
##   quest_completed(index: int, title: String)
##   quest_progress_updated(index: int, progress: int, target: int)
##   quest_unlocked(index: int)

extends Node

signal quest_completed(index: int, title: String)
signal quest_progress_updated(index: int, progress: int, target: int)
signal quest_unlocked(index: int)

# Quest definitions: [title, description, target_count, tracking_key]
# tracking_key is a string used to identify the quest's progress source.
const QUESTS: Array = [
	{
		"title": "First Bond",
		"description": "Summon a companion pet for the first time.",
		"target": 1,
		"key": "pet_summoned",
	},
	{
		"title": "Growing Pains",
		"description": "Evolve your pet to the Adolescent stage.",
		"target": 1,
		"key": "pet_evolved_adolescent",
	},
	{
		"title": "Elemental Awakening",
		"description": "Use an evolution stone to lock in an elemental path.",
		"target": 1,
		"key": "stone_used",
	},
	{
		"title": "Full Bloom",
		"description": "Evolve your pet to the Adult stage.",
		"target": 1,
		"key": "pet_evolved_adult",
	},
	{
		"title": "Evolution Master",
		"description": "Reach the Adult stage on 2 different elemental paths.",
		"target": 2,
		"key": "adult_paths",
	},
	{
		"title": "Grand Companion",
		"description": "Feed your pet a total of 50 items.",
		"target": 50,
		"key": "pet_feedings",
	},
	{
		"title": "Pet Savant",
		"description": "Complete all 3 pet training mini-games at least once.",
		"target": 3,
		"key": "training_games_done",
	},
	{
		"title": "Fusion Pioneer",
		"description": "Create a fused pet using the Pet Fusion System.",
		"target": 1,
		"key": "fusion_created",
	},
]

var _progress: Array[int] = []
var _completed: Array[bool] = []
var _adult_paths_reached: Array[int] = []  # PetPath IDs that reached Adult
var _training_games_completed: Array[int] = []  # TrainingGame IDs completed
var _initialized: bool = false


func _ready() -> void:
	# Initialize arrays
	for i in QUESTS.size():
		_progress.append(0)
		_completed.append(false)
	_initialized = true
	# Connect to signals from other systems
	if GameManager and not GameManager.game_restarted.is_connected(_on_game_restarted):
		GameManager.game_restarted.connect(_on_game_restarted)
	# Pet feeding tracking via Statistics
	if Statistics and not Statistics.stats_updated.is_connected(_on_stats_updated):
		Statistics.stats_updated.connect(_on_stats_updated)
	# Pet fusion created
	if PetFusionSystem and not PetFusionSystem.fusion_completed.is_connected(_on_fusion_completed):
		PetFusionSystem.fusion_completed.connect(_on_fusion_completed)
	# Pet training game completed
	if PetTrainingSystem and not PetTrainingSystem.game_completed.is_connected(_on_training_game_completed):
		PetTrainingSystem.game_completed.connect(_on_training_game_completed)


# ─── Public API ─────────────────────────────────────────────────────────────

func get_quest_count() -> int:
	return QUESTS.size()


func get_active_quest() -> int:
	for i in QUESTS.size():
		if not _completed[i]:
			return i
	return -1  # All completed


func get_quest_info(index: int) -> Dictionary:
	if index < 0 or index >= QUESTS.size():
		return {}
	var q: Dictionary = QUESTS[index]
	return {
		"title": q["title"],
		"description": q["description"],
		"progress": _progress[index],
		"target": q["target"],
		"completed": _completed[index],
		"index": index,
	}


func is_quest_completed(index: int) -> bool:
	if index < 0 or index >= QUESTS.size():
		return false
	return _completed[index]


func is_all_completed() -> bool:
	for c in _completed:
		if not c:
			return false
	return true


func get_all_quests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in QUESTS.size():
		result.append(get_quest_info(i))
	return result


# ─── Event Hooks (called from other scripts) ─────────────────────────────────

## Called from player.gd when the pet is summoned (F key).
func notify_pet_summoned() -> void:
	_advance_quest("pet_summoned", 1)


## Called from companion_pet.gd when the pet evolves to a new stage.
func notify_pet_stage_changed(new_stage: int, new_path: int) -> void:
	if new_stage == GameConstants.PetStage.ADOLESCENT:
		_advance_quest("pet_evolved_adolescent", 1)
	elif new_stage == GameConstants.PetStage.ADULT:
		_advance_quest("pet_evolved_adult", 1)
		# Track adult path for the "Evolution Master" quest
		if not _adult_paths_reached.has(new_path):
			_adult_paths_reached.append(new_path)
			_set_quest_progress("adult_paths", _adult_paths_reached.size())


## Called from player.gd when an evolution stone is used.
func notify_stone_used() -> void:
	_advance_quest("stone_used", 1)


## Called from companion_pet.gd when the pet is fed (via feed()).
func notify_pet_fed() -> void:
	var idx: int = _find_quest_by_key("pet_feedings")
	if idx < 0 or _completed[idx]:
		return
	_progress[idx] += 1
	quest_progress_updated.emit(idx, _progress[idx], QUESTS[idx]["target"])
	if _progress[idx] >= QUESTS[idx]["target"]:
		_complete_quest(idx)


## Called from pet_training_system.gd when a training game is completed.
func notify_training_game_completed(game_id: int) -> void:
	if not _training_games_completed.has(game_id):
		_training_games_completed.append(game_id)
	var idx: int = _find_quest_by_key("training_games_done")
	if idx < 0 or _completed[idx]:
		return
	_progress[idx] = _training_games_completed.size()
	quest_progress_updated.emit(idx, _progress[idx], QUESTS[idx]["target"])
	if _progress[idx] >= QUESTS[idx]["target"]:
		_complete_quest(idx)


# ─── Internal ─────────────────────────────────────────────────────────────────

var _check_training_timer: float = 0.0

func _on_training_game_completed(game_id: int, _tp: int, success: bool) -> void:
	if success:
		notify_training_game_completed(game_id)


func _advance_quest(key: String, amount: int) -> void:
	var idx: int = _find_quest_by_key(key)
	if idx < 0 or _completed[idx]:
		return
	_progress[idx] = min(_progress[idx] + amount, QUESTS[idx]["target"])
	quest_progress_updated.emit(idx, _progress[idx], QUESTS[idx]["target"])
	if _progress[idx] >= QUESTS[idx]["target"]:
		_complete_quest(idx)


func _set_quest_progress(key: String, value: int) -> void:
	var idx: int = _find_quest_by_key(key)
	if idx < 0 or _completed[idx]:
		return
	_progress[idx] = min(value, QUESTS[idx]["target"])
	quest_progress_updated.emit(idx, _progress[idx], QUESTS[idx]["target"])
	if _progress[idx] >= QUESTS[idx]["target"]:
		_complete_quest(idx)


func _find_quest_by_key(key: String) -> int:
	for i in QUESTS.size():
		if QUESTS[i]["key"] == key:
			return i
	return -1


func _complete_quest(idx: int) -> void:
	if idx < 0 or idx >= QUESTS.size():
		return
	if _completed[idx]:
		return
	_completed[idx] = true
	var title: String = QUESTS[idx]["title"]
	quest_completed.emit(idx, title)
	GameManager.add_message("🐾 Pet Questline: '%s' complete!" % title)
	# Apply rewards
	_apply_reward(idx)
	# Unlock next quest
	if idx + 1 < QUESTS.size():
		quest_unlocked.emit(idx + 1)
	print("[PetQuestline] Quest %d completed: %s" % [idx, title])


func _apply_reward(idx: int) -> void:
	match idx:
		0:  # First Bond — +5 SP
			if ProgressionSystem:
				ProgressionSystem.add_skill_points(5)
				GameManager.add_message("   ✦ Reward: +5 Skill Points!")
		1:  # Growing Pains — unlock Pet Slot 2
			if MultiPetSystem:
				MultiPetSystem.unlock_slot(1)
		2:  # Elemental Awakening — +1 Star Fruit (grant via collectible pickup XP)
			GameManager.gain_xp(100)
			GameManager.add_message("   ✦ Reward: +100 Bonus XP!")
		3:  # Full Bloom — unlock "Champion" pet aura cosmetic
			GameManager.add_message("   ✦ Reward: Champion Aura unlocked! (cosmetic)")
		4:  # Evolution Master — unlock Pet Slot 3
			if MultiPetSystem:
				MultiPetSystem.unlock_slot(2)
		5:  # Grand Companion — unlock "Eternal" pet aura
			GameManager.add_message("   ✦ Reward: Eternal Aura unlocked! (cosmetic)")
		6:  # Pet Savant — +3 TP
			if PetTrainingSystem:
				PetTrainingSystem.award_tp(3)
				GameManager.add_message("   ✦ Reward: +3 Training Points!")
		7:  # Fusion Pioneer — unlock Fusion Crown cosmetic
			GameManager.add_message("   ✦ Reward: Fusion Crown unlocked! (cosmetic)")


# ─── Signal handlers ──────────────────────────────────────────────────────────

func _on_stats_updated() -> void:
	# Check pet feedings from Statistics
	if Statistics:
		var feedings: int = Statistics.get_lifetime_stat("pet_feedings")
		if feedings > 0:
			_set_quest_progress("pet_feedings", feedings)


func _on_fusion_completed(_fusion_type: int) -> void:
	_advance_quest("fusion_created", 1)


# ─── Save/Load ────────────────────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	return {
		"progress": _progress.duplicate(),
		"completed": _completed.duplicate(),
		"adult_paths": _adult_paths_reached.duplicate(),
		"training_games": _training_games_completed.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	if data.has("progress"):
		var p: Array = data["progress"]
		for i in range(mini(p.size(), QUESTS.size())):
			_progress[i] = int(p[i])
	if data.has("completed"):
		var c: Array = data["completed"]
		for i in range(mini(c.size(), QUESTS.size())):
			_completed[i] = bool(c[i])
	if data.has("adult_paths"):
		_adult_paths_reached = []
		var ap: Array = data["adult_paths"]
		for v in ap:
			_adult_paths_reached.append(int(v))
	if data.has("training_games"):
		_training_games_completed = []
		var tg: Array = data["training_games"]
		for v in tg:
			_training_games_completed.append(int(v))


# ─── Reset ────────────────────────────────────────────────────────────────────

func reset() -> void:
	_progress.clear()
	_completed.clear()
	_adult_paths_reached.clear()
	_training_games_completed.clear()
	for i in QUESTS.size():
		_progress.append(0)
		_completed.append(false)


func _on_game_restarted() -> void:
	reset()