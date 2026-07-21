## Zorp Wiggles — World Modifier System (Phase 33: Procedural Content)
##
## Random rules each run that fundamentally change how the game plays.
## At the start of each run, a set of 2-4 modifiers is rolled from a pool of
## ~20 distinct modifiers. Each modifier applies a global rule for the entire
## run: double enemies, no dash, extra loot, glass cannon, slow-mo world, etc.
##
## The modifiers are exposed via getter methods that other systems query:
##   - EnemySpawner:    get_enemy_spawn_mult(), get_enemy_hp_mult()
##   - player.gd:       is_dash_disabled(), get_player_damage_mult(),
##                       get_player_speed_mult(), get_player_max_hp_mult()
##   - enemy_base.gd:   get_loot_chance_mult(), get_xp_mult(), get_enemy_damage_mult()
##   - projectile.gd:   get_player_damage_mult()
##   - WeatherSystem:   get_weather_change_mult()
##
## Modifiers are chosen at run start (GameManager._start_game → start_run()) and
## persist for the entire run. They are NOT saved with the save file — a loaded
## save re-rolls its own modifiers from the same seed so the run "remembers"
## them via the world_seed. This keeps the system deterministic for challenge
## seeds (two players sharing a seed get the same modifiers).
##
## A HUD indicator (world_modifier_indicator.gd) shows the active modifiers.
extends Node

# ─── Signals ──────────────────────────────────────────────────────────────────
signal modifiers_rolled(modifier_ids: Array)
signal modifier_added(modifier_id: int)
signal modifier_removed(modifier_id: int)

# ─── World Modifiers ──────────────────────────────────────────────────────────
enum Modifier {
	NONE,                    # Placeholder (no modifier)
	DOUBLE_TROUBLE,          # 2× enemy spawn rate, but enemies have 75% HP
	GLASS_CANNON,            # Player deals 2× damage but has 50% max HP
	NO_DASH,                 # Dashing is disabled — pure positioning challenge
	SWIFT_FOES,              # Enemies move 40% faster
	EXTRA_LOOT,             # 2.5× loot chance from enemies
	DOUBLE_XP,              # 2× XP gain
	HARDENED,               # Enemies have 1.6× HP
	PACIFIST_FOG,           # Enemy detection range halved (stealth run)
	SLOWMO_WORLD,           # All enemies move at 0.6× speed
	LIGHTWEIGHT,            # Player moves 1.25× faster, enemies 1.15× faster
	BERSERKER,              # Below 30% HP, player deals 3× damage
	REGEN_RAIN,             # Player regenerates 2 HP/sec
	FAMINE,                 # No consumable drops, no crafting material drops
	CHAMPION_ENEMIES,       # 20% of enemies spawn as elite variants (delegated to EnemyVariantSystem)
	WEATHER_CHAOS,          # Weather changes 3× more often
	BIG_HEAD_MODE,          # All enemies are 1.5× larger (visual + hitbox)
	THIN_SKIN,              # Player takes 1.5× damage
	VAMPIRE,                # Player heals 5% of damage dealt
	NO_PET,                 # Pet companion is unavailable
	DOUBLE_BOSSES,          # Boss spawns are 2× more frequent
	TREASURE_HOARDER,       # Treasure chests spawn 3× more often
}

const MODIFIER_NAMES: Array[String] = [
	"None",
	"Double Trouble",
	"Glass Cannon",
	"No Dash",
	"Swift Foes",
	"Extra Loot",
	"Double XP",
	"Hardened",
	"Pacifist Fog",
	"Slow-mo World",
	"Lightweight",
	"Berserker",
	"Regen Rain",
	"Famine",
	"Champion Enemies",
	"Weather Chaos",
	"Big Head Mode",
	"Thin Skin",
	"Vampire",
	"No Pet",
	"Double Bosses",
	"Treasure Hoarder",
]

const MODIFIER_ICONS: Array[String] = [
	"",
	"⚔⚔",
	"💥",
	"🚫",
	"💨",
	"💰",
	"✨",
	"🛡",
	"🌫",
	"⏳",
	"🏃",
	"😡",
	"💚",
	"🗑",
	"👑",
	"🌀",
	"🤯",
	"🩹",
	"🧛",
	"🐾",
	"💀💀",
	"🪙",
]

const MODIFIER_DESCRIPTIONS: Array[String] = [
	"",
	"Enemies spawn 2× faster, but have 25% less HP. A relentless onslaught.",
	"You deal 2× damage but your max HP is halved. Live fast, die hard.",
	"Dashing is disabled. Pure positioning skill — every step counts.",
	"Enemies move 40% faster. React quickly or get swarmed.",
	"2.5× loot chance from enemies. Greed is good.",
	"2× XP from all sources. Level up at double speed.",
	"Enemies have 60% more HP. Tankier foes, longer fights.",
	"Enemy detection range halved. Stealth-friendly run.",
	"All enemies move at 60% speed. Take your time.",
	"Player +25% speed, enemies +15% speed. Everyone's zippier.",
	"Below 30% HP, you deal 3× damage. Embrace the danger.",
	"Regenerate 2 HP per second. Slow and steady healing.",
	"No consumable or crafting material drops. Resources are scarce.",
	"20% of enemies spawn as elite variants. Quality over quantity.",
	"Weather changes 3× more often. Adapt constantly.",
	"All enemies are 1.5× larger. Bigger targets, bigger threats.",
	"You take 1.5× damage. Survivability is reduced.",
	"Heal 5% of damage dealt. Lifesteal for the bold.",
	"Pet companion is unavailable. Solo run only.",
	"Boss spawns are 2× more frequent. Boss hunting season.",
	"Treasure chests spawn 3× more often. Riches await.",
]

const MODIFIER_COLORS: Array[Color] = [
	Color(0.6, 0.6, 0.6),
	Color(1.0, 0.3, 0.3),    # Double Trouble — red
	Color(1.0, 0.5, 0.2),    # Glass Cannon — orange
	Color(0.8, 0.4, 0.4),    # No Dash — dark red
	Color(0.3, 0.9, 1.0),    # Swift Foes — cyan
	Color(1.0, 0.85, 0.0),   # Extra Loot — gold
	Color(0.4, 1.0, 0.5),    # Double XP — green
	Color(0.6, 0.6, 0.9),    # Hardened — steel blue
	Color(0.5, 0.6, 0.7),    # Pacifist Fog — grey-blue
	Color(0.5, 0.7, 1.0),    # Slow-mo World — light blue
	Color(0.9, 0.9, 0.4),    # Lightweight — yellow
	Color(1.0, 0.2, 0.2),    # Berserker — deep red
	Color(0.3, 1.0, 0.4),    # Regen Rain — bright green
	Color(0.5, 0.4, 0.3),    # Famine — brown
	Color(1.0, 0.8, 0.3),    # Champion Enemies — amber
	Color(0.7, 0.5, 1.0),    # Weather Chaos — purple
	Color(1.0, 0.6, 0.8),    # Big Head Mode — pink
	Color(0.9, 0.4, 0.4),    # Thin Skin — salmon
	Color(0.8, 0.2, 0.4),    # Vampire — crimson
	Color(0.4, 0.4, 0.4),    # No Pet — grey
	Color(0.9, 0.3, 0.5),    # Double Bosses — magenta
	Color(0.95, 0.75, 0.2),  # Treasure Hoarder — bronze
]

# ─── Tuning ───────────────────────────────────────────────────────────────────
const MIN_MODIFIERS: int = 2
const MAX_MODIFIERS: int = 4
const MODIFIER_CHANCE: float = 0.85  # 85% of runs get modifiers; 15% are vanilla

# Some modifiers are "rare" — they appear less frequently in the roll pool.
const RARE_MODIFIERS: Array[int] = [
	Modifier.NO_DASH,
	Modifier.FAMINE,
	Modifier.NO_PET,
	Modifier.THIN_SKIN,
]
const RARE_WEIGHT: float = 0.35  # Rare modifiers have 35% the roll weight of common ones

# ─── State ────────────────────────────────────────────────────────────────────
var _active_modifiers: Array[int] = []
var _is_initialized: bool = false

# Per-run cached multipliers (computed once at roll time for efficiency)
var _enemy_spawn_mult: float = 1.0
var _enemy_hp_mult: float = 1.0
var _enemy_damage_mult: float = 1.0
var _enemy_speed_mult: float = 1.0
var _enemy_detect_mult: float = 1.0
var _player_damage_mult: float = 1.0
var _player_speed_mult: float = 1.0
var _player_max_hp_mult: float = 1.0
var _player_damage_taken_mult: float = 1.0
var _loot_chance_mult: float = 1.0
var _xp_mult: float = 1.0
var _weather_change_mult: float = 1.0
var _boss_spawn_mult: float = 1.0
var _treasure_chest_mult: float = 1.0
var _enemy_scale_mult: float = 1.0
var _regen_per_sec: float = 0.0
var _vampire_leech_pct: float = 0.0
var _berserker_threshold: float = 0.0
var _berserker_damage_mult: float = 1.0
var _no_dash: bool = false
var _no_pet: bool = false
var _no_consumable_drops: bool = false
var _champion_chance: float = 0.0

# ─── Public API ────────────────────────────────────────────────────────────────

func _ready() -> void:
	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)
		GameManager.player_died.connect(_on_player_died)

# Roll a new set of modifiers for this run. Called by GameManager._start_game()
# via start_run(). Pass the world_seed so the roll is deterministic for shared
# challenge seeds (two players using the same seed get the same modifiers).
func roll_modifiers(world_seed: int) -> void:
	_active_modifiers.clear()
	_reset_caches()
	# Seed the RNG for deterministic rolls
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	# Daily Challenge: always 3-4 modifiers, no vanilla chance (Phase 25)
	var is_daily: bool = GameModeManager and GameModeManager.is_daily_challenge()
	if not is_daily:
		# 15% of runs are "vanilla" (no modifiers) for a baseline experience
		if rng.randf() > MODIFIER_CHANCE:
			modifiers_rolled.emit(_active_modifiers)
			_is_initialized = true
			return
	# Build weighted pool (all modifiers except NONE)
	var pool: Array[int] = []
	var weights: Array[float] = []
	for i in range(1, MODIFIER_NAMES.size()):
		pool.append(i)
		if i in RARE_MODIFIERS:
			weights.append(RARE_WEIGHT)
		else:
			weights.append(1.0)
	# Roll 2-4 unique modifiers (3-4 for daily challenge)
	var count: int = rng.randi_range(MIN_MODIFIERS, MAX_MODIFIERS)
	if is_daily:
		count = rng.randi_range(3, 4)
	for _i in range(count):
		if pool.is_empty():
			break
		# Weighted pick
		var total_weight: float = 0.0
		for w in weights:
			total_weight += w
		var roll: float = rng.randf() * total_weight
		var cumulative: float = 0.0
		var picked_idx: int = 0
		for j in range(pool.size()):
			cumulative += weights[j]
			if roll <= cumulative:
				picked_idx = j
				break
		_active_modifiers.append(pool[picked_idx])
		pool.remove_at(picked_idx)
		weights.remove_at(picked_idx)
	# Apply each modifier's effects
	for mod_id in _active_modifiers:
		_apply_modifier(mod_id)
		modifier_added.emit(mod_id)
	modifiers_rolled.emit(_active_modifiers)
	_is_initialized = true
	# Print the rolled modifiers for debugging
	print("[WorldModifiers] Rolled %d modifiers for seed %d:" % [_active_modifiers.size(), world_seed])
	for mod_id in _active_modifiers:
		print("  - %s: %s" % [MODIFIER_NAMES[mod_id], MODIFIER_DESCRIPTIONS[mod_id]])

# Apply a single modifier's effects to the cached multipliers
func _apply_modifier(mod_id: int) -> void:
	match mod_id:
		Modifier.DOUBLE_TROUBLE:
			_enemy_spawn_mult *= 2.0
			_enemy_hp_mult *= 0.75
		Modifier.GLASS_CANNON:
			_player_damage_mult *= 2.0
			_player_max_hp_mult *= 0.5
		Modifier.NO_DASH:
			_no_dash = true
		Modifier.SWIFT_FOES:
			_enemy_speed_mult *= 1.4
		Modifier.EXTRA_LOOT:
			_loot_chance_mult *= 2.5
		Modifier.DOUBLE_XP:
			_xp_mult *= 2.0
		Modifier.HARDENED:
			_enemy_hp_mult *= 1.6
		Modifier.PACIFIST_FOG:
			_enemy_detect_mult *= 0.5
		Modifier.SLOWMO_WORLD:
			_enemy_speed_mult *= 0.6
		Modifier.LIGHTWEIGHT:
			_player_speed_mult *= 1.25
			_enemy_speed_mult *= 1.15
		Modifier.BERSERKER:
			_berserker_threshold = 0.3
			_berserker_damage_mult = 3.0
		Modifier.REGEN_RAIN:
			_regen_per_sec += 2.0
		Modifier.FAMINE:
			_no_consumable_drops = true
		Modifier.CHAMPION_ENEMIES:
			_champion_chance = 0.20
		Modifier.WEATHER_CHAOS:
			_weather_change_mult *= 3.0
		Modifier.BIG_HEAD_MODE:
			_enemy_scale_mult *= 1.5
		Modifier.THIN_SKIN:
			_player_damage_taken_mult *= 1.5
		Modifier.VAMPIRE:
			_vampire_leech_pct += 0.05
		Modifier.NO_PET:
			_no_pet = true
		Modifier.DOUBLE_BOSSES:
			_boss_spawn_mult *= 2.0
		Modifier.TREASURE_HOARDER:
			_treasure_chest_mult *= 3.0
		_:
			push_warning("[WorldModifiers] Unknown modifier id: %d" % mod_id)

func _reset_caches() -> void:
	_enemy_spawn_mult = 1.0
	_enemy_hp_mult = 1.0
	_enemy_damage_mult = 1.0
	_enemy_speed_mult = 1.0
	_enemy_detect_mult = 1.0
	_player_damage_mult = 1.0
	_player_speed_mult = 1.0
	_player_max_hp_mult = 1.0
	_player_damage_taken_mult = 1.0
	_loot_chance_mult = 1.0
	_xp_mult = 1.0
	_weather_change_mult = 1.0
	_boss_spawn_mult = 1.0
	_treasure_chest_mult = 1.0
	_enemy_scale_mult = 1.0
	_regen_per_sec = 0.0
	_vampire_leech_pct = 0.0
	_berserker_threshold = 0.0
	_berserker_damage_mult = 1.0
	_no_dash = false
	_no_pet = false
	_no_consumable_drops = false
	_champion_chance = 0.0

# ─── Per-Frame Update ─────────────────────────────────────────────────────────
# Called by GameManager._process() to apply regen ticks. The GameManager's own
# regen logic handles the base 1 HP/sec; we add our modifier regen on top.
func update(delta: float) -> void:
	if not _is_initialized:
		return
	if GameManager.is_paused or not GameManager.player_is_alive:
		return
	# Regen Rain modifier — tick HP regen
	if _regen_per_sec > 0.0:
		_apply_regen(delta)

# Apply regen ticks using a fractional accumulator to handle sub-1-HP regen.
var _regen_accumulator: float = 0.0
func _apply_regen(delta: float) -> void:
	_regen_accumulator += _regen_per_sec * delta
	while _regen_accumulator >= 1.0:
		_regen_accumulator -= 1.0
		if GameManager.player_hp < GameManager.player_max_hp:
			GameManager.player_hp = min(GameManager.player_max_hp, GameManager.player_hp + 1)
			GameManager.hp_changed.emit(GameManager.player_hp, GameManager.player_max_hp)

# ─── Vampire Leech ────────────────────────────────────────────────────────────
# Called by projectile.gd when it deals damage to an enemy. Returns the amount
# the player should heal based on the Vampire modifier.
func get_vampire_heal(damage_dealt: int) -> int:
	if _vampire_leech_pct <= 0.0:
		return 0
	return int(damage_dealt * _vampire_leech_pct)

# ─── Berserker Damage ──────────────────────────────────────────────────────────
# Called by projectile.gd. Returns the damage multiplier if the Berserker
# modifier is active and the player is below the threshold HP fraction.
func get_berserker_damage_mult() -> float:
	if _berserker_threshold <= 0.0:
		return 1.0
	var hp_fraction: float = float(GameManager.player_hp) / float(GameManager.player_max_hp) if GameManager.player_max_hp > 0 else 1.0
	if hp_fraction <= _berserker_threshold:
		return _berserker_damage_mult
	return 1.0

# ─── Query API (used by other systems) ────────────────────────────────────────

func get_active_modifiers() -> Array[int]:
	return _active_modifiers.duplicate()

func get_active_modifier_count() -> int:
	return _active_modifiers.size()

func has_modifier(mod_id: int) -> bool:
	return mod_id in _active_modifiers

func get_modifier_name(mod_id: int) -> String:
	if mod_id < 0 or mod_id >= MODIFIER_NAMES.size():
		return "Unknown"
	return MODIFIER_NAMES[mod_id]

func get_modifier_icon(mod_id: int) -> String:
	if mod_id < 0 or mod_id >= MODIFIER_ICONS.size():
		return ""
	return MODIFIER_ICONS[mod_id]

func get_modifier_description(mod_id: int) -> String:
	if mod_id < 0 or mod_id >= MODIFIER_DESCRIPTIONS.size():
		return ""
	return MODIFIER_DESCRIPTIONS[mod_id]

func get_modifier_color(mod_id: int) -> Color:
	if mod_id < 0 or mod_id >= MODIFIER_COLORS.size():
		return Color(0.6, 0.6, 0.6)
	return MODIFIER_COLORS[mod_id]

# ─── Multiplier Getters ───────────────────────────────────────────────────────
# These are queried every frame by various systems, so they must be cheap.

func get_enemy_spawn_mult() -> float:
	return _enemy_spawn_mult

func get_enemy_hp_mult() -> float:
	return _enemy_hp_mult

func get_enemy_damage_mult() -> float:
	return _enemy_damage_mult

func get_enemy_speed_mult() -> float:
	return _enemy_speed_mult

func get_enemy_detect_mult() -> float:
	return _enemy_detect_mult

func get_player_damage_mult() -> float:
	return _player_damage_mult

func get_player_speed_mult() -> float:
	return _player_speed_mult

func get_player_max_hp_mult() -> float:
	return _player_max_hp_mult

func get_player_damage_taken_mult() -> float:
	return _player_damage_taken_mult

func get_loot_chance_mult() -> float:
	return _loot_chance_mult

func get_xp_mult() -> float:
	return _xp_mult

func get_weather_change_mult() -> float:
	return _weather_change_mult

func get_boss_spawn_mult() -> float:
	return _boss_spawn_mult

func get_treasure_chest_mult() -> float:
	return _treasure_chest_mult

func get_enemy_scale_mult() -> float:
	return _enemy_scale_mult

func get_champion_chance() -> float:
	return _champion_chance

func is_dash_disabled() -> bool:
	return _no_dash

func is_pet_disabled() -> bool:
	return _no_pet

func is_consumable_drops_disabled() -> bool:
	return _no_consumable_drops

func is_initialized() -> bool:
	return _is_initialized

# ─── Signal Handlers ───────────────────────────────────────────────────────────

func _on_game_restarted() -> void:
	# Don't re-roll here — GameManager._start_game() calls start_run() which
	# calls roll_modifiers() with the new world_seed. Just clear state.
	_active_modifiers.clear()
	_reset_caches()
	_is_initialized = false

func _on_player_died() -> void:
	# Keep modifiers visible on the death screen; they're cleared on restart.
	pass