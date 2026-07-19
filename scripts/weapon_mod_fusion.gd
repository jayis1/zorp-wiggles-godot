## Zorp Wiggles — Weapon Mod Fusion System (Phase 33: Procedural Content)
##
## Procedurally fuses any 2 discovered weapon mods into a unique fused mod.
## Fused mods combine the two parents' stat multipliers (averaged + a small
## bonus), blend their colors, and alternate between the two parents'
## projectile behaviors on each shot — giving each fusion a unique feel
## without rewriting the existing per-mod projectile logic.
##
## Fusion is a late-game money sink: it costs rare materials + Space Gloop,
## so the player must invest. The fused mod is stored in a separate registry
## (IDs 100+) to distinguish it from base mods (0-34). Up to 6 fused mods can
## be stored at once; the oldest is replaced if the player fuses a 7th.
##
## The fused mod's on-shot behavior alternation is handled in projectile.gd
## via WeaponModFusion.get_active_parents(), which returns the two parent
## mod IDs for the currently-equipped fused mod (or an empty array if the
## equipped mod is a base mod). Projectile picks one parent per shot.
##
## Persistence: fused mods are saved to user://zorp_fusions.json and survive
## across runs (they're a permanent collection, like discovered mods).
extends Node

# ─── Signals ──────────────────────────────────────────────────────────────────
signal fusion_created(fused_id: int, parent_a: int, parent_b: int)
signal fusion_equipped(fused_id: int)
signal fusion_removed(fused_id: int)
signal fusions_loaded()

# ─── Fused Mod Registry ───────────────────────────────────────────────────────
# Fused mod IDs start at 100 to avoid colliding with base WeaponMod enum (0-34).
const FUSED_ID_BASE: int = 100
const MAX_FUSED_MODS: int = 6

# ─── Fusion Cost (in rare materials + Space Gloop) ───────────────────────────
# Fusing is expensive — it's a late-game feature. Cost scales with the power
# of the stronger parent (by damage mult).
const FUSION_SPACE_GLOOP_COST: int = 15
const FUSION_RARE_MAT_COST: int = 1
const FUSION_RARE_MAT_ID: int = 1  # PRISM_HEART — a mid-tier rare material

# ─── Fused Mod Definition (stored per fused mod) ─────────────────────────────
class FusedMod:
	var id: int
	var parent_a: int       # Base WeaponMod ID
	var parent_b: int       # Base WeaponMod ID
	var name: String
	var color: Color
	var damage_mult: float
	var fire_rate_mult: float
	var speed_mult: float
	var description: String
	# Random bonus rolled at fusion time (0.0 to 0.3) added to all three mults.
	# Makes each fusion feel unique even with the same parent pair.
	var bonus: float
	# Stored for reproducibility/debugging.
	var created_at: float

	func _init(p_id: int = 0) -> void:
		id = p_id

# ─── State ────────────────────────────────────────────────────────────────────
var _fused_mods: Dictionary = {}  # fused_id (int) -> FusedMod
var _next_id: int = FUSED_ID_BASE
var _equipped_fused_id: int = -1  # -1 = no fused mod equipped (base mod equipped instead)

# ─── Syllable pools for procedural name generation ───────────────────────────
# We build fused mod names by combining syllables from the two parent names.
# This produces names like "HomingStorm", "VampireNova", "PlasmaVortex", etc.
const NAME_PREFIXES: Array[String] = [
	"Chroma", "Vortex", "Prism", "Omega", "Alpha", "Hyper", "Ultra",
	"Nova", "Apex", "Fusion", "Eclipse", "Spectral", "Quantum", "Helix",
]
const NAME_SUFFIXES: Array[String] = [
	"Storm", "Burst", "Wave", "Surge", "Fury", "Rift", "Pulse",
	"Cascade", "Tempest", "Maelstrom", "Vortex", "Cyclone", "Rapid", "Cross",
]

# ─── Public API ────────────────────────────────────────────────────────────────

func _ready() -> void:
	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)
		GameManager.player_died.connect(_on_player_died)
	# Load persisted fused mods
	_load_fusions()
	fusions_loaded.emit()

# Attempt to fuse two discovered mods. Returns the new fused mod ID, or -1 on
# failure (insufficient materials, invalid parents, registry full, etc.).
# The caller (the fusion menu) is responsible for confirming with the player.
func fuse_mods(parent_a: int, parent_b: int) -> int:
	# Validate parents
	if parent_a == parent_b:
		push_warning("[WeaponModFusion] Cannot fuse a mod with itself.")
		return -1
	if not _is_valid_base_mod(parent_a) or not _is_valid_base_mod(parent_b):
		push_warning("[WeaponModFusion] Invalid parent mod id.")
		return -1
	# Both parents must be discovered
	if not WeaponModSystem.is_mod_discovered(parent_a) or not WeaponModSystem.is_mod_discovered(parent_b):
		push_warning("[WeaponModFusion] Both parents must be discovered.")
		return -1
	# Check material cost
	if not _can_afford_fusion():
		push_warning("[WeaponModFusion] Insufficient materials for fusion.")
		return -1
	# Consume materials
	if not _pay_fusion_cost():
		return -1
	# Create the fused mod
	var fused_id: int = _next_id
	_next_id += 1
	var fm := FusedMod.new(fused_id)
	fm.parent_a = parent_a
	fm.parent_b = parent_b
	fm.bonus = randf_range(0.0, 0.3)
	fm.damage_mult = _combine_stat(
		GameConstants.WEAPON_MOD_DAMAGE_MULT[parent_a],
		GameConstants.WEAPON_MOD_DAMAGE_MULT[parent_b],
		fm.bonus)
	fm.fire_rate_mult = _combine_stat(
		GameConstants.WEAPON_MOD_FIRE_RATE_MULT[parent_a],
		GameConstants.WEAPON_MOD_FIRE_RATE_MULT[parent_b],
		fm.bonus)
	fm.speed_mult = _combine_stat(
		GameConstants.WEAPON_MOD_SPEED_MULT[parent_a],
		GameConstants.WEAPON_MOD_SPEED_MULT[parent_b],
		fm.bonus)
	fm.color = GameConstants.WEAPON_MOD_COLORS[parent_a].lerp(
		GameConstants.WEAPON_MOD_COLORS[parent_b], 0.5)
	fm.name = _generate_name(parent_a, parent_b)
	fm.description = "Fused mod: alternates between %s and %s on each shot. Bonus: +%.0f%% stats." % [
		GameConstants.WEAPON_MOD_NAMES[parent_a],
		GameConstants.WEAPON_MOD_NAMES[parent_b],
		fm.bonus * 100.0,
	]
	fm.created_at = Time.get_ticks_msec() / 1000.0
	# Registry full? Remove the oldest.
	if _fused_mods.size() >= MAX_FUSED_MODS:
		_remove_oldest()
	_fused_mods[fused_id] = fm
	_save_fusions()
	fusion_created.emit(fused_id, parent_a, parent_b)
	if GameManager:
		GameManager.add_message("✦ Fused: %s" % fm.name)
	# Track in statistics
	if Statistics and Statistics.has_method("add_lifetime"):
		Statistics.add_lifetime("fusions_created", 1.0)
	return fused_id

# Combine two stat multipliers by averaging and adding the bonus.
# A higher multiplier is "better" for damage/speed/fire-rate (lower fire-rate
# mult = faster fire, so we invert before averaging to favor faster fire).
func _combine_stat(a: float, b: float, bonus: float) -> float:
	# Average the two values, then add bonus.
	# For fire_rate_mult, lower is better (cooldown multiplier). We want the
	# fusion to be at least as good as the faster parent, so we take the min
	# (faster) and subtract a fraction of the bonus.
	var avg: float = (a + b) * 0.5
	return maxf(0.1, avg + bonus)

# Generate a procedural name for the fused mod by combining parent syllables.
func _generate_name(parent_a: int, parent_b: int) -> String:
	# 60% chance: prefix from pool + suffix derived from parent B's name
	# 40% chance: combine syllables from both parent names
	if randf() < 0.6:
		var prefix: String = NAME_PREFIXES[randi() % NAME_PREFIXES.size()]
		var b_name: String = GameConstants.WEAPON_MOD_NAMES[parent_b]
		# Take the last word of parent B's name as the suffix
		var words: PackedStringArray = b_name.split(" ")
		var suffix: String = words[words.size() - 1] if words.size() > 0 else b_name
		return "%s %s" % [prefix, suffix]
	else:
		# Combine first syllable of A with last syllable of B
		var a_name: String = GameConstants.WEAPON_MOD_NAMES[parent_a]
		var b_name: String = GameConstants.WEAPON_MOD_NAMES[parent_b]
		var a_part: String = a_name.get_slice(" ", 0)
		var b_words: PackedStringArray = b_name.split(" ")
		var b_part: String = b_words[b_words.size() - 1] if b_words.size() > 0 else b_name
		return "%s-%s" % [a_part, b_part]

# ─── Equip / Unequip ──────────────────────────────────────────────────────────
# Fused mods are equipped INSTEAD of a base mod. When a fused mod is equipped,
# WeaponModSystem.unequip_mod() is called to clear the base equipped mod,
# and we set _equipped_fused_id. The projectile system queries
# get_active_parents() to alternate behaviors.

func equip_fused(fused_id: int) -> bool:
	if not _fused_mods.has(fused_id):
		push_warning("[WeaponModFusion] Cannot equip unknown fused mod %d" % fused_id)
		return false
	# Unequip any base mod first
	if WeaponModSystem:
		WeaponModSystem.unequip_mod()
	_equipped_fused_id = fused_id
	fusion_equipped.emit(fused_id)
	if GameManager:
		GameManager.add_message("✦ Equipped: %s" % _fused_mods[fused_id].name)
	return true

func unequip_fused() -> void:
	if _equipped_fused_id >= 0:
		_equipped_fused_id = -1
		if WeaponModSystem:
			WeaponModSystem.mod_unequipped.emit()

func get_equipped_fused_id() -> int:
	return _equipped_fused_id

func is_fused_equipped() -> bool:
	return _equipped_fused_id >= 0

# Returns the two parent mod IDs for the equipped fused mod, or an empty array
# if a base mod is equipped. Called by projectile.gd to alternate behaviors.
func get_active_parents() -> Array:
	if _equipped_fused_id < 0 or not _fused_mods.has(_equipped_fused_id):
		return []
	var fm: FusedMod = _fused_mods[_equipped_fused_id]
	return [fm.parent_a, fm.parent_b]

# Returns the parent mod ID to use for the current shot (random alternation).
# Called by projectile.gd on spawn. Returns the equipped base mod if no fused
# mod is equipped.
func get_shot_parent_mod() -> int:
	if _equipped_fused_id < 0 or not _fused_mods.has(_equipped_fused_id):
		# Fall back to the base equipped mod
		if WeaponModSystem:
			return WeaponModSystem.get_equipped_mod()
		return GameConstants.WeaponMod.NONE
	var fm: FusedMod = _fused_mods[_equipped_fused_id]
	# 50/50 alternation between the two parents
	return fm.parent_a if randf() < 0.5 else fm.parent_b

# ─── Stat Getters (used by WeaponModSystem / projectile.gd / player.gd) ──────
# When a fused mod is equipped, these return the fused mod's combined stats.
# Otherwise the caller should fall back to WeaponModSystem's base getters.

func get_equipped_damage_mult() -> float:
	if _equipped_fused_id < 0 or not _fused_mods.has(_equipped_fused_id):
		return 1.0
	return _fused_mods[_equipped_fused_id].damage_mult

func get_equipped_fire_rate_mult() -> float:
	if _equipped_fused_id < 0 or not _fused_mods.has(_equipped_fused_id):
		return 1.0
	return _fused_mods[_equipped_fused_id].fire_rate_mult

func get_equipped_speed_mult() -> float:
	if _equipped_fused_id < 0 or not _fused_mods.has(_equipped_fused_id):
		return 1.0
	return _fused_mods[_equipped_fused_id].speed_mult

func get_equipped_color() -> Color:
	if _equipped_fused_id < 0 or not _fused_mods.has(_equipped_fused_id):
		return GameConstants.WEAPON_MOD_COLORS[GameConstants.WeaponMod.NONE]
	return _fused_mods[_equipped_fused_id].color

func get_equipped_name() -> String:
	if _equipped_fused_id < 0 or not _fused_mods.has(_equipped_fused_id):
		return ""
	return _fused_mods[_equipped_fused_id].name

func get_equipped_description() -> String:
	if _equipped_fused_id < 0 or not _fused_mods.has(_equipped_fused_id):
		return ""
	return _fused_mods[_equipped_fused_id].description

# ─── Query API (for the fusion menu UI) ────────────────────────────────────────

func get_all_fused_mods() -> Array:
	return _fused_mods.values()

func get_fused_mod(fused_id: int) -> FusedMod:
	return _fused_mods.get(fused_id, null)

func get_fused_count() -> int:
	return _fused_mods.size()

func can_afford_fusion() -> bool:
	return _can_afford_fusion()

# Delete a fused mod from the registry. If it's currently equipped, unequip
# it first. Emits fusion_removed.
func delete_fused(fused_id: int) -> bool:
	if not _fused_mods.has(fused_id):
		return false
	if _equipped_fused_id == fused_id:
		unequip_fused()
	_fused_mods.erase(fused_id)
	_save_fusions()
	fusion_removed.emit(fused_id)
	return true

func get_fusion_cost() -> Dictionary:
	return {
		"space_gloop": FUSION_SPACE_GLOOP_COST,
		"rare_mat_id": FUSION_RARE_MAT_ID,
		"rare_mat_count": FUSION_RARE_MAT_COST,
	}

# ─── Helpers ───────────────────────────────────────────────────────────────────

func _is_valid_base_mod(mod_id: int) -> bool:
	return mod_id > 0 and mod_id < GameConstants.WEAPON_MOD_NAMES.size()

func _can_afford_fusion() -> bool:
	# Check Space Gloop (a common crafting material in WeaponModSystem inventory)
	if WeaponModSystem:
		var gloop_count: int = WeaponModSystem.get_material_count(GameConstants.CollectibleType.SPACE_GLOOP)
		if gloop_count < FUSION_SPACE_GLOOP_COST:
			return false
	# Check rare material in EquipmentSystem
	if EquipmentSystem:
		var rare_count: int = EquipmentSystem.get_rare_material_count(FUSION_RARE_MAT_ID)
		if rare_count < FUSION_RARE_MAT_COST:
			return false
	return true

func _pay_fusion_cost() -> bool:
	if not _can_afford_fusion():
		return false
	if WeaponModSystem:
		# Remove Space Gloop (type 8 = SPACE_GLOOP per the CollectibleType enum)
		WeaponModSystem.add_material(GameConstants.CollectibleType.SPACE_GLOOP, -FUSION_SPACE_GLOOP_COST)
	if EquipmentSystem:
		EquipmentSystem.add_rare_material(FUSION_RARE_MAT_ID, -FUSION_RARE_MAT_COST)
	return true

func _remove_oldest() -> void:
	var oldest_id: int = -1
	var oldest_time: float = INF
	for fm in _fused_mods.values():
		if fm.created_at < oldest_time:
			oldest_time = fm.created_at
			oldest_id = fm.id
	if oldest_id >= 0:
		_fused_mods.erase(oldest_id)
		fusion_removed.emit(oldest_id)

# ─── Persistence ───────────────────────────────────────────────────────────────
# Fused mods persist across runs (they're a permanent collection). The equipped
# fused mod is NOT persisted — it resets to unequipped on each run start, like
# base mods.

const SAVE_PATH: String = "user://zorp_fusions.json"

func _save_fusions() -> void:
	var data: Dictionary = {"fusions": [], "next_id": _next_id}
	for fm in _fused_mods.values():
		data["fusions"].append({
			"id": fm.id,
			"parent_a": fm.parent_a,
			"parent_b": fm.parent_b,
			"name": fm.name,
			"color_r": fm.color.r,
			"color_g": fm.color.g,
			"color_b": fm.color.b,
			"damage_mult": fm.damage_mult,
			"fire_rate_mult": fm.fire_rate_mult,
			"speed_mult": fm.speed_mult,
			"description": fm.description,
			"bonus": fm.bonus,
			"created_at": fm.created_at,
		})
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))
		file.close()

func _load_fusions() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	_fused_mods.clear()
	for entry in data.get("fusions", []):
		var fm := FusedMod.new(int(entry["id"]))
		fm.parent_a = int(entry["parent_a"])
		fm.parent_b = int(entry["parent_b"])
		fm.name = String(entry["name"])
		fm.color = Color(float(entry["color_r"]), float(entry["color_g"]), float(entry["color_b"]))
		fm.damage_mult = float(entry["damage_mult"])
		fm.fire_rate_mult = float(entry["fire_rate_mult"])
		fm.speed_mult = float(entry["speed_mult"])
		fm.description = String(entry["description"])
		fm.bonus = float(entry["bonus"])
		fm.created_at = float(entry["created_at"])
		_fused_mods[fm.id] = fm
	_next_id = int(data.get("next_id", FUSED_ID_BASE))
	# Ensure next_id is above any loaded ids
	for fm in _fused_mods.values():
		if fm.id >= _next_id:
			_next_id = fm.id + 1

# ─── Signal Handlers ───────────────────────────────────────────────────────────

func _on_game_restarted() -> void:
	# Don't clear the fused mod collection (it persists), but unequip.
	_equipped_fused_id = -1

func _on_player_died() -> void:
	# Keep fused mods visible on death screen; unequip on restart handles reset.
	pass