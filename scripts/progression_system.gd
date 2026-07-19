## Zorp Wiggles — Progression System (Phase 25: Progression & Meta-Systems)
## Autoload singleton managing the meta-progression layer:
##   1. Skill Tree — 3 branches (Combat, Survival, Exploration), spend skill points
##   2. Permanent Upgrades — persist across runs (+HP, +damage, +speed, +XP)
##   3. Prestige System — reset level for a permanent multiplier + cosmetic unlocks
##
## Skill points are earned by leveling up (1 SP per level) and by prestiging
## (bonus SP based on prestige level). Points are spent in the skill tree UI
## (press K). Permanent upgrades are the passive bonuses from invested skill
## points — they apply automatically at the start of each run.
##
## Prestige: once the player reaches level 20+, they can prestige. This resets
## their level to 1 but grants prestige XP multipliers and a cosmetic aura.
## Each prestige level increases the XP multiplier by 10% and grants 5 bonus SP.

extends Node

# ─── Signals ──────────────────────────────────────────────────────────────────
signal skill_points_changed(sp: int)
signal skill_purchased(branch: int, node_id: int, level: int)
signal prestige_changed(prestige_level: int)
signal progression_loaded()

# ─── Skill Tree Branches ──────────────────────────────────────────────────────
enum Branch {
	COMBAT,      # Damage, crit, fire rate, multishot
	SURVIVAL,    # HP, regen, shield, revive
	EXPLORATION, # Speed, XP gain, loot, biome bonuses
}

const BRANCH_NAMES: Array[String] = ["Combat", "Survival", "Exploration"]
const BRANCH_ICONS: Array[String] = ["⚔", "🛡", "🧭"]
const BRANCH_COLORS: Array[Color] = [
	Color(1.0, 0.35, 0.25),   # Combat — red-orange
	Color(0.35, 0.8, 0.45),   # Survival — green
	Color(0.4, 0.7, 1.0),     # Exploration — blue
]

# ─── Skill Node IDs (per branch) ──────────────────────────────────────────────
# Each branch has 5 skill nodes, each with 5 ranks. Total 75 possible ranks.
enum CombatSkill { DAMAGE, CRIT_CHANCE, FIRE_RATE, MULTISHOT, BOSS_DAMAGE }
enum SurvivalSkill { MAX_HP, HP_REGEN, SHIELD, REVIVE, DAMAGE_REDUCTION }
enum ExplorationSkill { SPEED, XP_GAIN, LOOT_CHANCE, BIOME_BONUS, DASH_COOLDOWN }

const MAX_RANK: int = 5  # Max ranks per skill node

# ─── Skill Definitions ───────────────────────────────────────────────────────
# Each skill: { name, description, icon, per_rank_bonus, max_rank, branch }
# The per_rank_bonus is the incremental effect per rank invested.
const SKILL_DEFS: Dictionary = {
	# Combat branch
	"combat_damage":       {"name": "Power Strike",    "desc": "+8% damage per rank",         "icon": "💥", "per_rank": 0.08, "branch": Branch.COMBAT},
	"combat_crit":         {"name": "Keen Eye",         "desc": "+3% crit chance per rank",   "icon": "🎯", "per_rank": 0.03, "branch": Branch.COMBAT},
	"combat_fire_rate":    {"name": "Rapid Fire",       "desc": "+5% fire rate per rank",     "icon": "⚡", "per_rank": 0.05, "branch": Branch.COMBAT},
	"combat_multishot":    {"name": "Extra Bolts",      "desc": "+1 projectile per 2 ranks",   "icon": "🔥", "per_rank": 0.5,  "branch": Branch.COMBAT},
	"combat_boss_damage":  {"name": "Giant Slayer",    "desc": "+15% boss damage per rank",  "icon": "☠",  "per_rank": 0.15, "branch": Branch.COMBAT},
	# Survival branch
	"survival_max_hp":     {"name": "Vitality",         "desc": "+20 max HP per rank",        "icon": "❤",  "per_rank": 20.0, "branch": Branch.SURVIVAL},
	"survival_hp_regen":   {"name": "Regeneration",     "desc": "+1 HP/sec per rank",         "icon": "✨", "per_rank": 1.0,  "branch": Branch.SURVIVAL},
	"survival_shield":     {"name": "Energy Shield",    "desc": "+5% damage reduction per rank", "icon": "🛡", "per_rank": 0.05, "branch": Branch.SURVIVAL},
	"survival_revive":     {"name": "Second Wind",      "desc": "Auto-revive once per rank per run", "icon": "🔄", "per_rank": 1.0, "branch": Branch.SURVIVAL},
	"survival_dmg_reduce": {"name": "Toughness",        "desc": "+3% damage reduction per rank", "icon": "💪", "per_rank": 0.03, "branch": Branch.SURVIVAL},
	# Exploration branch
	"exploration_speed":   {"name": "Swift Stride",     "desc": "+4% move speed per rank",    "icon": "🏃", "per_rank": 0.04, "branch": Branch.EXPLORATION},
	"exploration_xp_gain": {"name": "Quick Learner",   "desc": "+10% XP gain per rank",      "icon": "📚", "per_rank": 0.10, "branch": Branch.EXPLORATION},
	"exploration_loot":    {"name": "Lucky Find",       "desc": "+5% loot drop chance per rank", "icon": "🍀", "per_rank": 0.05, "branch": Branch.EXPLORATION},
	"exploration_biome":   {"name": "Biome Adaptation", "desc": "+5% stat bonus per biome visited", "icon": "🌍", "per_rank": 0.05, "branch": Branch.EXPLORATION},
	"exploration_dash_cd": {"name": "Fluid Motion",     "desc": "-6% dash cooldown per rank", "icon": "💨", "per_rank": 0.06, "branch": Branch.EXPLORATION},
}

# Ordered skill keys per branch (for UI rendering)
const COMBAT_SKILLS: Array[String] = ["combat_damage", "combat_crit", "combat_fire_rate", "combat_multishot", "combat_boss_damage"]
const SURVIVAL_SKILLS: Array[String] = ["survival_max_hp", "survival_hp_regen", "survival_shield", "survival_revive", "survival_dmg_reduce"]
const EXPLORATION_SKILLS: Array[String] = ["exploration_speed", "exploration_xp_gain", "exploration_loot", "exploration_biome", "exploration_dash_cd"]

# ─── State (persisted) ────────────────────────────────────────────────────────
var _skill_ranks: Dictionary = {}  # skill_key → current rank (0..MAX_RANK)
var _skill_points: int = 0         # Unspent skill points
var _prestige_level: int = 0       # Prestige level (0 = never prestiged)
var _total_skill_points_earned: int = 0  # Lifetime SP earned (for stats)

const SAVE_PATH: String = "user://zorp_progression.json"
const PRESTIGE_MIN_LEVEL: int = 20  # Must reach level 20 to prestige
const PRESTIGE_BONUS_SP: int = 5   # Bonus SP per prestige level
const PRESTIGE_XP_MULT_PER_LEVEL: float = 0.10  # +10% XP per prestige level

# ─── Public API ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load()
	if GameManager:
		GameManager.level_up.connect(_on_level_up)
		GameManager.game_restarted.connect(_on_game_restarted)
		GameManager.player_died.connect(_on_player_died)
	# Initialize any missing skills to rank 0
	for key in SKILL_DEFS.keys():
		if not _skill_ranks.has(key):
			_skill_ranks[key] = 0
	progression_loaded.emit()

func _exit_tree() -> void:
	_save()

# ─── Save/Load ────────────────────────────────────────────────────────────────

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[Progression] Save file corrupt — using defaults.")
		return
	_skill_ranks = parsed.get("skill_ranks", {})
	_skill_points = int(parsed.get("skill_points", 0))
	_prestige_level = int(parsed.get("prestige_level", 0))
	_total_skill_points_earned = int(parsed.get("total_sp_earned", 0))
	print("[Progression] Loaded — SP: %d, Prestige: %d, Total earned: %d" % [
		_skill_points, _prestige_level, _total_skill_points_earned
	])

func _save() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_warning("[Progression] Could not write save file.")
		return
	var data: Dictionary = {
		"skill_ranks": _skill_ranks,
		"skill_points": _skill_points,
		"prestige_level": _prestige_level,
		"total_sp_earned": _total_skill_points_earned,
	}
	file.store_string(JSON.stringify(data, "  "))
	file.close()

# ─── Skill Points ──────────────────────────────────────────────────────────────

func get_skill_points() -> int:
	return _skill_points

func get_total_sp_earned() -> int:
	return _total_skill_points_earned

# ── Phase 31: Save/Load setters (called by SaveSystem) ──
## Get a copy of all skill ranks { skill_key: rank } for serialization.
func get_all_skill_ranks() -> Dictionary:
	return _skill_ranks.duplicate()

## Replace all skill ranks from a save file (used by SaveSystem).
func set_all_skill_ranks(ranks: Dictionary) -> void:
	_skill_ranks = ranks.duplicate()
	_save()

## Set the unspent skill-point count from a save file.
func set_skill_points(amount: int) -> void:
	_skill_points = max(0, amount)
	skill_points_changed.emit(_skill_points)
	_save()

## Set the prestige level from a save file.
func set_prestige_level(level: int) -> void:
	_prestige_level = max(0, level)
	_save()

func _on_level_up(level: int) -> void:
	# 1 SP per level, +1 bonus every 5 levels
	var sp_gain: int = 1
	if level % 5 == 0:
		sp_gain += 1
	_skill_points += sp_gain
	_total_skill_points_earned += sp_gain
	skill_points_changed.emit(_skill_points)
	_save()
	GameManager.add_message("⭐ Skill Point gained! (%d available — press K)" % _skill_points)

func _on_game_restarted() -> void:
	# Save progression on restart
	_save()

func _on_player_died() -> void:
	_save()

# ─── Skill Purchasing ──────────────────────────────────────────────────────────

func get_skill_rank(skill_key: String) -> int:
	return int(_skill_ranks.get(skill_key, 0))

func can_purchase_skill(skill_key: String) -> bool:
	if not SKILL_DEFS.has(skill_key):
		return false
	if _skill_points <= 0:
		return false
	var rank: int = get_skill_rank(skill_key)
	if rank >= MAX_RANK:
		return false
	return true

func purchase_skill(skill_key: String) -> bool:
	if not can_purchase_skill(skill_key):
		return false
	_skill_ranks[skill_key] = get_skill_rank(skill_key) + 1
	_skill_points -= 1
	var def: Dictionary = SKILL_DEFS[skill_key]
	skill_purchased.emit(def["branch"], _branch_skill_index(skill_key), _skill_ranks[skill_key])
	skill_points_changed.emit(_skill_points)
	_save()
	GameManager.add_message("⬆ Skill upgraded: %s → Rank %d" % [def["name"], _skill_ranks[skill_key]])
	return true

func _branch_skill_index(skill_key: String) -> int:
	if COMBAT_SKILLS.has(skill_key):
		return COMBAT_SKILLS.find(skill_key)
	if SURVIVAL_SKILLS.has(skill_key):
		return SURVIVAL_SKILLS.find(skill_key)
	if EXPLORATION_SKILLS.has(skill_key):
		return EXPLORATION_SKILLS.find(skill_key)
	return -1

# ─── Permanent Upgrade Multipliers (queried by player.gd, game_manager.gd) ────
# These aggregate the invested skill ranks into stat bonuses applied each run.

func get_damage_mult() -> float:
	# Combat: Power Strike (+8% per rank)
	return 1.0 + get_skill_rank("combat_damage") * SKILL_DEFS["combat_damage"]["per_rank"]

func get_crit_chance_bonus() -> float:
	# Combat: Keen Eye (+3% per rank)
	return get_skill_rank("combat_crit") * SKILL_DEFS["combat_crit"]["per_rank"]

func get_fire_rate_mult() -> float:
	# Combat: Rapid Fire (+5% per rank) — returns a multiplier < 1.0 (faster)
	return 1.0 - get_skill_rank("combat_fire_rate") * SKILL_DEFS["combat_fire_rate"]["per_rank"]

func get_extra_projectiles() -> int:
	# Combat: Extra Bolts (+1 per 2 ranks)
	return int(get_skill_rank("combat_multishot") * SKILL_DEFS["combat_multishot"]["per_rank"])

func get_boss_damage_mult() -> float:
	# Combat: Giant Slayer (+15% per rank)
	return 1.0 + get_skill_rank("combat_boss_damage") * SKILL_DEFS["combat_boss_damage"]["per_rank"]

func get_max_hp_bonus() -> int:
	# Survival: Vitality (+20 per rank)
	return int(get_skill_rank("survival_max_hp") * SKILL_DEFS["survival_max_hp"]["per_rank"])

func get_hp_regen_per_sec() -> float:
	# Survival: Regeneration (+1 HP/sec per rank)
	return get_skill_rank("survival_hp_regen") * SKILL_DEFS["survival_hp_regen"]["per_rank"]

func get_damage_reduction() -> float:
	# Survival: Energy Shield + Toughness (stacking, capped at 0.75)
	var shield: float = get_skill_rank("survival_shield") * SKILL_DEFS["survival_shield"]["per_rank"]
	var tough: float = get_skill_rank("survival_dmg_reduce") * SKILL_DEFS["survival_dmg_reduce"]["per_rank"]
	return minf(0.75, shield + tough)

func get_revive_charges() -> int:
	# Survival: Second Wind (auto-revive charges per run)
	return get_skill_rank("survival_revive")

func get_speed_mult() -> float:
	# Exploration: Swift Stride (+4% per rank)
	return 1.0 + get_skill_rank("exploration_speed") * SKILL_DEFS["exploration_speed"]["per_rank"]

func get_xp_gain_mult() -> float:
	# Exploration: Quick Learner (+10% per rank) + prestige bonus
	var base: float = 1.0 + get_skill_rank("exploration_xp_gain") * SKILL_DEFS["exploration_xp_gain"]["per_rank"]
	base *= (1.0 + _prestige_level * PRESTIGE_XP_MULT_PER_LEVEL)
	return base

func get_loot_chance_bonus() -> float:
	# Exploration: Lucky Find (+5% per rank)
	return get_skill_rank("exploration_loot") * SKILL_DEFS["exploration_loot"]["per_rank"]

func get_biome_bonus_mult() -> float:
	# Exploration: Biome Adaptation (+5% per biome visited per rank)
	return get_skill_rank("exploration_biome") * SKILL_DEFS["exploration_biome"]["per_rank"]

func get_dash_cooldown_mult() -> float:
	# Exploration: Fluid Motion (-6% per rank) — returns multiplier < 1.0
	return 1.0 - get_skill_rank("exploration_dash_cd") * SKILL_DEFS["exploration_dash_cd"]["per_rank"]

# ─── Prestige System ──────────────────────────────────────────────────────────

func get_prestige_level() -> int:
	return _prestige_level

func can_prestige() -> bool:
	return GameManager.player_level >= PRESTIGE_MIN_LEVEL

func prestige() -> bool:
	if not can_prestige():
		return false
	_prestige_level += 1
	# Grant bonus SP
	var bonus_sp: int = PRESTIGE_BONUS_SP * _prestige_level
	_skill_points += bonus_sp
	_total_skill_points_earned += bonus_sp
	prestige_changed.emit(_prestige_level)
	skill_points_changed.emit(_skill_points)
	_save()
	GameManager.add_message("🌟 PRESTIGE! Level %d — +%d SP, +%.0f%% XP multiplier" % [
		_prestige_level, bonus_sp, _prestige_level * PRESTIGE_XP_MULT_PER_LEVEL * 100.0
	])
	return true

func get_prestige_xp_mult() -> float:
	return 1.0 + _prestige_level * PRESTIGE_XP_MULT_PER_LEVEL

func get_prestige_cosmetic_color() -> Color:
	# Each prestige level adds a golden aura tint
	return Color(1.0, 0.85, 0.3, 0.3 + minf(0.5, _prestige_level * 0.1))

# ─── Apply Permanent Upgrades (called on game start) ──────────────────────────

func apply_permanent_upgrades() -> void:
	# Called by GameManager._start_game() to apply permanent stat bonuses
	if not GameManager:
		return
	# Max HP bonus
	var hp_bonus: int = get_max_hp_bonus()
	if hp_bonus > 0:
		GameManager.player_max_hp += hp_bonus
		GameManager.player_hp = GameManager.player_max_hp
		GameManager.hp_changed.emit(GameManager.player_hp, GameManager.player_max_hp)
	# Reset revive charges for this run
	_revives_used_this_run = 0

var _revives_used_this_run: int = 0

func try_auto_revive() -> bool:
	# Called by GameManager._die() when the player is about to die. Returns true
	# if auto-revive kicks in (consuming a revive charge) instead of dying.
	# NOTE: At call time, player_is_alive is still true (death hasn't been applied
	# yet). We must NOT gate on player_is_alive == false — that would never be true
	# here. The caller has already decided the player should die; we just decide
	# whether to override that with a revive.
	var charges: int = get_revive_charges()
	if charges > _revives_used_this_run:
		_revives_used_this_run += 1
		GameManager.player_is_alive = true
		GameManager.player_is_downed = false
		GameManager.player_hp = int(GameManager.player_max_hp * 0.5)
		GameManager.player_invuln_timer = 3.0
		GameManager.hp_changed.emit(GameManager.player_hp, GameManager.player_max_hp)
		GameManager.add_message("🔄 Second Wind! Auto-revive activated (%d/%d remaining)" % [
			charges - _revives_used_this_run, charges
		])
		if GameManager.player and is_instance_valid(GameManager.player):
			ParticleEffects.spawn_levelup_burst(GameManager.player.get_parent(), GameManager.player.global_position)
		return true
	return false

# ─── Helpers ──────────────────────────────────────────────────────────────────

func get_branch_skills(branch: int) -> Array[String]:
	match branch:
		Branch.COMBAT: return COMBAT_SKILLS
		Branch.SURVIVAL: return SURVIVAL_SKILLS
		Branch.EXPLORATION: return EXPLORATION_SKILLS
		_: return []

func get_total_ranks_invested() -> int:
	var total: int = 0
	for key in _skill_ranks.keys():
		total += int(_skill_ranks[key])
	return total

func get_ranks_in_branch(branch: int) -> int:
	var total: int = 0
	for key in get_branch_skills(branch):
		total += get_skill_rank(key)
	return total

func reset_all_skills() -> bool:
	# Refund all skill points (admin/debug function — not exposed in normal UI)
	var total_ranks: int = get_total_ranks_invested()
	if total_ranks == 0:
		return false
	for key in _skill_ranks.keys():
		_skill_ranks[key] = 0
	_skill_points += total_ranks
	skill_points_changed.emit(_skill_points)
	_save()
	return true