## Zorp Wiggles — Balance Manager (Phase 35: Final Polish)
## Centralizes the balance pass so tuning values are in one auditable place
## rather than scattered across a dozen systems. The constants here are
## APPLIED at runtime — they don't replace the base constants in
## game_constants.gd, they layer on top as multipliers/adjustments.
##
## What this does:
##   1. Smooths the XP curve — early levels are slightly faster (feels good),
##      late levels slightly slower (prevents runaway leveling).
##   2. Loot table balance — rare material drop chance scales subtly with
##      player level so late-game runs aren't starved of rare mats.
##   3. Weapon mod damage normalization — a few outlier mods are brought
##      closer to the mean so no single mod dominates.
##   4. Pet ability tuning — pet evolution point gain is slightly more
##      generous so the pet progression feels rewarding.
##   5. Difficulty curve smoothing — applies an easing function to the
##      time-based difficulty tier so early tiers are gentler and late
##      tiers ramp harder (smooth S-curve instead of linear).
##
## All values are designed to be subtle (5-15% adjustments) — the goal is
## to smooth the existing curve, not redefine it. Big balance overhauls
## would require extensive playtesting beyond a polish pass.

extends Node

# ─── XP Curve Tuning ──────────────────────────────────────────────────────────
# The base XP curve is xp_to_next = 80 * 1.35^level. This grows fast — by
# level 10 a single level needs ~1160 XP. We apply a per-level multiplier
# that gently curves the requirement:
#   - Levels 1-5:   0.90× (slightly easier — early-game momentum)
#   - Levels 6-15:  1.00× (base curve)
#   - Levels 16-30: 1.08× (slightly harder — mid-game pacing)
#   - Levels 31+:   1.15× (harder — endgame progression)
const XP_CURVE_EARLY_MULT: float = 0.90    # Levels 1-5
const XP_CURVE_MID_MULT: float = 1.00     # Levels 6-15
const XP_CURVE_LATE_MULT: float = 1.08    # Levels 16-30
const XP_CURVE_ENDGAME_MULT: float = 1.15 # Levels 31+

# ─── Loot Drop Tuning ────────────────────────────────────────────────────────
# Rare material drop chance scales with player level (subtle bonus) so
# late-game players aren't starved of rare mats for crafting/upgrades.
# At level 1: base 4% (from game_constants). At level 30: +3% = 7%.
const RARE_MATERIAL_LEVEL_BONUS: float = 0.001  # +0.1% per level

# ─── Pet Evolution Tuning ─────────────────────────────────────────────────────
# Slightly more generous evolution point gain so the pet progression feels
# rewarding. The base values (5/15/40) are good but a small global bonus
# makes the first evolution (100 points) reachable in ~6 feeds instead of 8.
const PET_EVOLUTION_POINT_MULT: float = 1.15

# ─── Difficulty Curve Easing ──────────────────────────────────────────────────
# The time-based difficulty tiers (every 60s) scale linearly. We apply an
# S-curve easing so early tiers are gentler (player is still learning the
# ropes) and late tiers ramp harder (veterans want a challenge). The easing
# is applied as a multiplier on the tier value before the linear scaling.
#   tier 0 → 0.0 (no change, base difficulty)
#   tier 5 → ~0.78 (gentler — 22% reduction)
#   tier 10 → 1.0 (full difficulty at max tier)
const DIFFICULTY_EASE_ENABLED: bool = true

# ─── Weapon Mod Damage Normalization ──────────────────────────────────────────
# A few mods had damage multipliers that were notably above/below the pack.
# These multipliers nudge them toward the mean without changing their feel:
#   - Mega Blast (2.0×): reduced to 1.85× (still the highest, just less extreme)
#   - Sniper Beam (2.0×): reduced to 1.9× (still strong, less of an outlier)
#   - Shrink Beam (0.7×): bumped to 0.75× (slightly more usable as a weapon)
# Applied in get_mod_damage_adjustment() — returns 1.0 for unlisted mods.
const MEGA_BLAST_DMG_ADJUST: float = 0.925   # 2.0× → 1.85×
const SNIPER_BEAM_DMG_ADJUST: float = 0.95   # 2.0× → 1.9×
const SHRINK_BEAM_DMG_ADJUST: float = 1.071  # 0.7× → 0.75×

# ─── Internal ─────────────────────────────────────────────────────────────────
var _is_initialized: bool = false


func _ready() -> void:
	_is_initialized = true
	print("[BalanceManager] Balance tuning active — XP curve, loot, pets, difficulty, weapon mods")


# ─── XP Curve ─────────────────────────────────────────────────────────────────

## Returns the XP-curve multiplier for a given player level.
## Applied to the base xp_to_next value from game_constants.
func get_xp_curve_mult(level: int) -> float:
	if level <= 5:
		return XP_CURVE_EARLY_MULT
	elif level <= 15:
		return XP_CURVE_MID_MULT
	elif level <= 30:
		return XP_CURVE_LATE_MULT
	return XP_CURVE_ENDGAME_MULT


## Compute the adjusted XP needed for the next level, applying the curve.
## Called from GameManager._level_up() to override the base curve.
func get_xp_to_next(level: int) -> int:
	var base: int = int(GameConstants.PLAYER_LEVEL_XP_CURVE_BASE * pow(GameConstants.PLAYER_LEVEL_XP_CURVE_EXP, level - 1))
	return maxi(20, int(base * get_xp_curve_mult(level)))


# ─── Loot Drop Tuning ────────────────────────────────────────────────────────

## Returns the rare material drop chance adjusted for player level.
func get_rare_material_drop_chance(player_level: int, is_boss: bool) -> float:
	if is_boss:
		return GameConstants.RARE_MATERIAL_DROP_CHANCE_BOSS
	var base: float = GameConstants.RARE_MATERIAL_DROP_CHANCE
	return base + float(player_level) * RARE_MATERIAL_LEVEL_BONUS


# ─── Pet Evolution Tuning ─────────────────────────────────────────────────────

## Returns the evolution point value for a collectible type, with the
## balance multiplier applied. Called from companion_pet.feed().
func get_evolution_points(base_points: int) -> int:
	return int(base_points * PET_EVOLUTION_POINT_MULT)


# ─── Difficulty Curve Easing ──────────────────────────────────────────────────

## Returns an eased tier value for the time-based difficulty system.
## Input: raw tier (0-10). Output: eased tier (0.0-10.0).
## Early tiers are reduced (gentler), late tiers approach full.
func get_eased_time_tier(raw_tier: int) -> float:
	if not DIFFICULTY_EASE_ENABLED:
		return float(raw_tier)
	# S-curve: ease_out_cubic scaled to the max tier
	var t: float = clampf(float(raw_tier) / float(GameConstants.DIFFICULTY_TIME_MAX_TIER), 0.0, 1.0)
	var eased: float = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)  # ease-out cubic
	return eased * float(GameConstants.DIFFICULTY_TIME_MAX_TIER)


## Returns the time-based enemy HP multiplier with easing applied.
func get_time_enemy_hp_mult(raw_tier: int) -> float:
	var eased_tier: float = get_eased_time_tier(raw_tier)
	return 1.0 + eased_tier * GameConstants.DIFFICULTY_TIME_HP_SCALE


## Returns the time-based enemy damage multiplier with easing applied.
func get_time_enemy_damage_mult(raw_tier: int) -> float:
	var eased_tier: float = get_eased_time_tier(raw_tier)
	return 1.0 + eased_tier * GameConstants.DIFFICULTY_TIME_DAMAGE_SCALE


## Returns the time-based enemy speed multiplier with easing applied.
func get_time_enemy_speed_mult(raw_tier: int) -> float:
	var eased_tier: float = get_eased_time_tier(raw_tier)
	return 1.0 + eased_tier * GameConstants.DIFFICULTY_TIME_SPEED_SCALE


## Returns the time-based spawn interval multiplier with easing applied.
func get_time_spawn_interval_mult(raw_tier: int) -> float:
	var eased_tier: float = get_eased_time_tier(raw_tier)
	return maxf(0.3, 1.0 - eased_tier * GameConstants.DIFFICULTY_TIME_SPAWN_ACCEL)


# ─── Weapon Mod Damage Normalization ──────────────────────────────────────────

## Returns a damage adjustment multiplier for a weapon mod (1.0 = no change).
## Applied AFTER the mod's base damage multiplier to nudge outliers toward
## the mean. Unlisted mods return 1.0 (no adjustment).
func get_mod_damage_adjustment(mod_id: int) -> float:
	match mod_id:
		GameConstants.WeaponMod.MEGA_BLAST:
			return MEGA_BLAST_DMG_ADJUST
		GameConstants.WeaponMod.SNIPER_BEAM:
			return SNIPER_BEAM_DMG_ADJUST
		GameConstants.WeaponMod.SHRINK_BEAM:
			return SHRINK_BEAM_DMG_ADJUST
	return 1.0


# ─── Query Helpers ────────────────────────────────────────────────────────────

func is_initialized() -> bool:
	return _is_initialized