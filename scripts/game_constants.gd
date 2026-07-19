## Zorp Wiggles: Alien Adventure — Godot Remake
## Central constants ported from Ursina game.py
## All values match the original Python game for gameplay parity.

class_name GameConstants

# ─── Version ──────────────────────────────────────────────────────────────────
const VERSION: String = "0.1.0-godot"

# ─── World Generation ─────────────────────────────────────────────────────────
const WORLD_SIZE: int = 80
const TILE_SCALE: float = 4.0
const WORLD_EXTENT: float = WORLD_SIZE * TILE_SCALE / 2.0  # 160

# ─── Player ───────────────────────────────────────────────────────────────────
const PLAYER_SPEED: float = 12.0
const PLAYER_ACCELERATION: float = 45.0
const PLAYER_DECELERATION: float = 36.0
const PLAYER_INVULN_DURATION: float = 0.5
const PLAYER_BLINK_RATE: float = 20.0
const PLAYER_START_XP: int = 80
const PLAYER_START_HP: int = 120
const PLAYER_DASH_SPEED: float = 40.0
const PLAYER_DASH_DURATION: float = 0.15
const PLAYER_DASH_COOLDOWN: float = 1.5
const PLAYER_DASH_INVULN_DURATION: float = 0.3
const PLAYER_LEVEL_XP_MULT: float = 1.35
const PLAYER_LEVEL_HP_BONUS: int = 12
const PLAYER_LEVEL_DMG_BONUS: int = 2
# ── Phase 7: XP curve and level-up stat scaling ──
# XP follows a quadratic curve: xp_to_next = base * (1.35^level) with a minimum
# floor so early levels still progress smoothly. Stat scaling per level:
#   HP: +12 base, plus +3 per 5 levels (tier bonus)
#   Damage: +2 base, plus +1 per 5 levels (tier bonus)
#   Speed: +0.5 m/s per 5 levels (subtle, keeps mobility relevant)
const PLAYER_LEVEL_XP_CURVE_BASE: int = 80
const PLAYER_LEVEL_XP_CURVE_EXP: float = 1.35
const PLAYER_LEVEL_HP_TIER_BONUS: int = 3   # Extra HP per 5 levels
const PLAYER_LEVEL_DMG_TIER_BONUS: int = 1  # Extra damage per 5 levels
const PLAYER_LEVEL_SPEED_TIER_BONUS: float = 0.5  # Extra speed per 5 levels
const PLAYER_LEVEL_HEAL_PERCENT: float = 0.15  # Heal 15% max HP on level up

# ─── Combat ──────────────────────────────────────────────────────────────────
const SHOOT_COOLDOWN: float = 0.11
const COLLECT_RADIUS: float = 3.0
const COLLECT_PULL_RADIUS: float = 5.5
const COLLECT_PULL_SPEED: float = 16.0
const PROJECTILE_BASE_DAMAGE: int = 20
const PROJECTILE_LEVEL_DAMAGE_BONUS: int = 2
const PROJECTILE_SPEED: float = 55.0
const PROJECTILE_LIFETIME: float = 2.0

# ─── Enemy ───────────────────────────────────────────────────────────────────
const ENEMY_DETECT_RANGE: float = 32.0
const ENEMY_ATTACK_RANGE: float = 2.0
const ENEMY_ATTACK_COOLDOWN: float = 1.2
const ENEMY_ALERT_FLASH_DURATION: float = 0.3
const ENEMY_SPAWN_GRACE_PERIOD: float = 2.0
const ENEMY_SPAWN_BOUNCE_START: float = 0.85
const ENEMY_SPAWN_BOUNCE_PEAK: float = 1.08
const ENEMY_ALERT_INDICATOR_DURATION: float = 0.6
const ENEMY_ALERT_INDICATOR_SCALE: float = 1.4
const ENEMY_ATTACK_WINDUP_TIME: float = 0.25
const ENEMY_ATTACK_WINDUP_SQUASH: float = 0.15
const ENEMY_ATTACK_WINDUP_BRIGHTNESS: float = 0.5
const ENEMY_ATTACK_LUNGE_DISTANCE: float = 1.5
const ENEMY_ATTACK_LUNGE_DURATION: float = 0.15
const ENEMY_ATTACK_LUNGE_SIZE_BASE: float = 1.0
const ENEMY_ATTACK_LUNGE_SIZE_MULT_MIN: float = 0.3

# ─── Pulse Wave (Q ability) ──────────────────────────────────────────────────
const PULSE_WAVE_COOLDOWN: float = 8.0
const PULSE_WAVE_RADIUS: float = 18.0
const PULSE_WAVE_DAMAGE: int = 60

# ─── Camera ──────────────────────────────────────────────────────────────────
const CAMERA_DISTANCE: float = 22.0
const CAMERA_ANGLE: float = 55.0
const CAMERA_ROTATE_SPEED: float = 200.0
const CAMERA_DEFAULT_FOV: float = 70.0
const CAMERA_DASH_FOV_KICK: float = 8.0    # Degrees added to FOV on dash
const CAMERA_FOV_RETURN_SPEED: float = 6.0 # How fast FOV eases back to default

# ─── HUD Colors (0-1 normalized for Godot) ──────────────────────────────────
# In Ursina, color.rgb() used 0-255. In Godot, Color uses 0-1.
# We convert here for clean GDScript usage.
const C_HP_GREEN: Color = Color(0.2, 0.9, 0.2)
const C_HP_MISSING: Color = Color(0.3, 0.1, 0.1)
const C_XP_PURPLE: Color = Color(0.6, 0.2, 0.9)
const C_COMBO_GOLD: Color = Color(1.0, 0.85, 0.0)
const C_COMBO_ORANGE: Color = Color(1.0, 0.55, 0.0)
const C_COMBO_RED: Color = Color(1.0, 0.2, 0.0)
const C_DANGER_RED: Color = Color(0.9, 0.1, 0.1)
const C_SPAWN_HEAL: Color = Color(0.3, 1.0, 0.5)

# ─── Biome Definitions ────────────────────────────────────────────────────────
enum Biome {
	GRASS,
	DESERT,
	WATER,
	LAVA,
	FOREST,
	CRYSTAL,
	SNOW,
	SWAMP,
	ALIEN,
	MUSHROOM,
	FLOATING_ISLANDS,
	TOXIC_BOG,
	# ── Phase 22: New biomes ──
	DEEP_OCEAN,      # Underwater sections, buoyancy physics, bioluminescent creatures
	VOLCANO_CORE,    # Erupting terrain, lava rivers, heat damage zones
	SKY_CITADEL,     # Floating platforms, wind currents, cloud navigation
	DIGITAL_GRID,    # Cyberpunk aesthetic, wireframe terrain, glitch effects
	CRYSTAL_CAVERNS, # Reflective surfaces, prism light, crystal enemies
	ANCIENT_RUINS,   # Decayed structures, hidden traps, relic collectibles
	UNDERGROUND,     # Subterranean caverns with limited light, unique enemies
}

# ─── Enemy Types ─────────────────────────────────────────────────────────────
enum EnemyType {
	BLOB,
	SERPENT,
	GRAVITON,
	WISP,
	SENTINEL,
	BOMBER,
	SPITTER,
	DRAKE,
	# ── Enhancement: New enemy types ──
	SWARM_MITE,       # Tiny, fast, spawns in packs — low HP but overwhelms
	CRYSTAL_GUARDIAN, # Slow, tanky, fires crystal shard projectiles
	PHASE_SHIFTER,    # Periodically becomes intangible — must time shots to hit it
	# ── Phase 23: New enemy types ──
	TOXIC_SPORE,      # Explodes into poison cloud on death, cloud damages over time
	SWARM_QUEEN,      # Spawns Swarm Mites continuously, must be killed to stop spawns
	CRYSTAL_WRAITH,   # Shatters into shards on death, shards reform into mini-wraiths
	ECHO_KNIGHT,      # Creates shadow copies of itself, all attack simultaneously
	# ── Phase 23: New enemy types (batch 2) ──
	PLASMA_STALKER,    # Turns invisible — only visible by particle trail
	TIME_WARDEN,       # Slows player in AoE, speeds self, teleport attacks
	MIRROR_MIMIC,      # Copies player's weapon mod, fires it back at them
	# ── Phase 23: New enemy types (batch 3 — bosses & elites) ──
	VOID_LEVIATHAN,    # Giant serpentine boss, multi-stage, swims through terrain
	ANCIENT_SENTINEL,  # Mega-boss, multiple attack phases, arena-wide hazards
	GRAVITY_ELEMENTAL, # Gravity-manipulating elite, throws objects, repels player
}

# ─── Enemy Spawn & Difficulty ────────────────────────────────────────────────
const MAX_ACTIVE_ENEMIES: int = 40
const ENEMY_SPAWN_INTERVAL: float = 10.0
const ENEMY_SPAWN_INTERVAL_LEVEL_DECAY: float = 0.5
const MIN_SPAWN_INTERVAL: float = 3.0
const ENEMY_SPAWN_DISTANCE_MIN: float = 30.0
const ENEMY_SPAWN_DISTANCE_MAX: float = 60.0
const PLAYER_LEVEL_DIFFICULTY_INTERVAL: int = 5
const ENEMY_HP_SCALE_PER_TIER: float = 0.15
const ENEMY_DAMAGE_SCALE_PER_TIER: float = 0.10
const DIFFICULTY_SCALE_DISTANCE: float = 100.0
const SPAWN_DENSITY_NEAR_RADIUS: float = 25.0
const SPAWN_DENSITY_NEAR_THRESHOLD: int = 8
const SPAWN_DENSITY_SLOWDOWN: float = 0.5
# ── Phase 7: Difficulty scaling over time ──
# As game_time increases, enemies spawn faster, get stronger, and more can be active.
# These are applied ON TOP of the player-level-based scaling.
const DIFFICULTY_TIME_INTERVAL: float = 60.0  # Every 60 seconds, difficulty tier increases
const DIFFICULTY_TIME_SPAWN_ACCEL: float = 0.12  # Spawn interval reduced by 12% per time-tier
const DIFFICULTY_TIME_HP_SCALE: float = 0.08  # +8% enemy HP per time-tier
const DIFFICULTY_TIME_DAMAGE_SCALE: float = 0.05  # +5% enemy damage per time-tier
const DIFFICULTY_TIME_SPEED_SCALE: float = 0.03  # +3% enemy speed per time-tier
const DIFFICULTY_TIME_MAX_TIER: int = 10  # Cap at 10 time-tiers (10 minutes)
const DIFFICULTY_TIME_MAX_ENEMY_BONUS: int = 10  # Max +10 additional enemies from time scaling
const ENEMY_SPAWN_WARNING_DURATION: float = 1.2

# ─── Plasma Serpent ───────────────────────────────────────────────────────────
const PLASMA_SERPENT_SEGMENTS: int = 4
const PLASMA_SERPENT_SEGMENT_SPACING: float = 1.8
const PLASMA_SERPENT_SCATTER_HP: int = 8
const PLASMA_SERPENT_SCATTER_DAMAGE: int = 4
const PLASMA_SERPENT_SCATTER_SPEED: float = 6.0

# ─── Graviton ─────────────────────────────────────────────────────────────────
const GRAVITON_PULL_RADIUS: float = 18.0
const GRAVITON_PULL_FORCE: float = 8.0
const GRAVITON_PULL_DURATION: float = 2.5
const GRAVITON_PULL_COOLDOWN_MIN: float = 4.0
const GRAVITON_PULL_COOLDOWN_MAX: float = 7.0
const GRAVITON_PULL_DAMAGE: int = 5

# ─── Void Wisp ────────────────────────────────────────────────────────────────
const VOID_WISP_TELEPORT_RANGE: float = 8.0
const VOID_WISP_TELEPORT_CHANCE: float = 0.50
const VOID_WISP_TELEPORT_COOLDOWN: float = 2.0

# ─── Starburst Sentinel ───────────────────────────────────────────────────────
const STARBURST_SHOCKWAVE_INTERVAL_MIN: float = 3.0
const STARBURST_SHOCKWAVE_INTERVAL_MAX: float = 5.0
const STARBURST_SHOCKWAVE_RADIUS: float = 8.0
const STARBURST_SHOCKWAVE_DAMAGE: int = 15
const STARBURST_SHOCKWAVE_EXPAND_SPEED: float = 15.0
const STARBURST_SHOCKWAVE_MAX_RADIUS: float = 8.0

# ─── Void Bomber ──────────────────────────────────────────────────────────────
const VOID_BOMBER_EXPLOSION_RADIUS: float = 5.5
const VOID_BOMBER_EXPLOSION_DAMAGE: int = 40
const VOID_BOMBER_FUSE_DURATION: float = 1.5
const VOID_BOMBER_FUSE_TRIGGER_RANGE: float = 6.0

# ─── Spore Spitter ────────────────────────────────────────────────────────────
const SPORE_SPIT_CHARGE_TIME: float = 0.45
const SPORE_SPIT_CHARGE_SCALE: float = 0.25
const SPORE_SPIT_CHARGE_BRIGHTNESS: float = 0.55
const SPORE_SPIT_SPEED: float = 20.0
const SPORE_SPIT_DAMAGE: int = 12
const SPORE_SPIT_LIFETIME: float = 3.0
const SPORE_SPIT_RANGE: float = 25.0

# ─── Enemy Projectile ─────────────────────────────────────────────────────────
const ENEMY_PROJECTILE_HIT_RADIUS: float = 1.5
const ENEMY_PROJECTILE_AURA_PULSE_SPEED: float = 10.0

# ─── Plasma Drake (Boss) ──────────────────────────────────────────────────────
const DRAKE_ENRAGE_HP_THRESHOLD: float = 0.3
const DRAKE_ENRAGE_SPEED_MULT: float = 1.5
const DRAKE_ENRAGE_DAMAGE_MULT: float = 1.3
const DRAKE_FIRE_BREATH_COOLDOWN: float = 5.0
const DRAKE_FIRE_BREATH_RANGE: float = 15.0
const DRAKE_FIRE_BREATH_DAMAGE: int = 30
const DRAKE_FIRE_BREATH_CONE_ANGLE: float = 45.0
const DRAKE_CHARGE_COOLDOWN: float = 8.0
const DRAKE_CHARGE_SPEED: float = 25.0
const DRAKE_CHARGE_DAMAGE: int = 35

# ─── Enhancement: Swarm Mite ──────────────────────────────────────────────────
# Tiny, very fast, very low HP enemy that spawns in packs. Individually weak
# but they swarm the player from multiple directions, creating pressure.
const SWARM_MITE_HP: int = 12
const SWARM_MITE_SPEED: float = 9.0
const SWARM_MITE_DAMAGE: int = 4
const SWARM_MITE_SCALE: float = 0.35
const SWARM_MITE_XP: int = 6
const SWARM_MITE_SCORE: int = 25
const SWARM_MITE_PACK_SIZE_MIN: int = 3
const SWARM_MITE_PACK_SIZE_MAX: int = 6
const SWARM_MITE_PACK_SPAWN_CHANCE: float = 0.4  # 40% of mite spawns are packs
const SWARM_MITE_COLOR: Color = Color(0.85, 0.35, 0.1)  # Orange-brown

# ─── Enhancement: Crystal Guardian ────────────────────────────────────────────
# Slow, high-HP, ranged enemy that fires crystal shard projectiles.
# Tanky but predictable — kiting is the counter-strategy.
const CRYSTAL_GUARDIAN_HP: int = 180
const CRYSTAL_GUARDIAN_SPEED: float = 1.8
const CRYSTAL_GUARDIAN_DAMAGE: int = 18
const CRYSTAL_GUARDIAN_SCALE: float = 1.6
const CRYSTAL_GUARDIAN_XP: int = 60
const CRYSTAL_GUARDIAN_SCORE: int = 200
const CRYSTAL_GUARDIAN_DETECT_RANGE: float = 30.0
const CRYSTAL_GUARDIAN_ATTACK_RANGE: float = 22.0  # Ranged
const CRYSTAL_GUARDIAN_ATTACK_COOLDOWN: float = 2.5
const CRYSTAL_GUARDIAN_SHARD_SPEED: float = 18.0
const CRYSTAL_GUARDIAN_SHARD_DAMAGE: int = 16
const CRYSTAL_GUARDIAN_SHARD_LIFETIME: float = 3.5
const CRYSTAL_GUARDIAN_COLOR: Color = Color(0.0, 0.8, 0.9)  # Cyan
const CRYSTAL_GUARDIAN_SHARD_COLOR: Color = Color(0.3, 0.9, 1.0)

# ─── Enhancement: Phase Shifter ───────────────────────────────────────────────
# An enemy that periodically shifts into a spectral phase, becoming intangible
# (immune to damage) for a brief window. Players must time their shots to land
# hits while it is in the material phase. Visual telegraph: transparent + bluish
# shimmer while phasing; solid + vivid color while vulnerable.
const PHASE_SHIFTER_HP: int = 60
const PHASE_SHIFTER_SPEED: float = 4.5
const PHASE_SHIFTER_DAMAGE: int = 14
const PHASE_SHIFTER_SCALE: float = 0.9
const PHASE_SHIFTER_XP: int = 35
const PHASE_SHIFTER_SCORE: int = 120
const PHASE_SHIFTER_DETECT_RANGE: float = 30.0
const PHASE_SHIFTER_ATTACK_RANGE: float = 2.0
const PHASE_SHIFTER_ATTACK_COOLDOWN: float = 1.5
const PHASE_SHIFTER_COLOR: Color = Color(0.6, 0.3, 0.9)            # Vivid violet
const PHASE_SHIFTER_PHASE_COLOR: Color = Color(0.3, 0.6, 1.0, 0.3) # Translucent blue while intangible
const PHASE_SHIFTER_PHASE_DURATION: float = 2.0     # Seconds intangible
const PHASE_SHIFTER_MATERIAL_DURATION: float = 3.0  # Seconds vulnerable
const PHASE_SHIFTER_PHASE_WARN_TIME: float = 0.4    # Shimmer telegraph before phasing
const PHASE_SHIFTER_PHASE_BLINK_SPEED: float = 18.0 # Hz of blink during warn

# ─── Collectible Types ───────────────────────────────────────────────────────
enum CollectibleType {
	STAR_FRUIT,
	METEOR_SHARD,
	QUANTUM_FUZZ,
	NEBULA_DUST,
	SPACE_GLOOP,
	XP_ORB,
	HEALTH_FRAGMENT,
	# ── Phase 16: Weapon Mod Crafting materials ──
	SHIELD_CRYSTAL,   # Blue crystalline shielding material
	FIREBALL_SCROLL,  # Orange combustible scroll
	REGEN_CRYSTAL,    # Green regenerative crystal
	MAGNET_CORE,      # Metallic magnetic core
	TOXIC_EXTRACT,    # Sickly green toxic extract
	# ── Phase 27: Pet Evolution Stones (rare drops that force a pet path) ──
	EMBER_STONE,      # Fire path
	FROST_STONE,     # Ice path
	SPARK_STONE,     # Electric path
	VOID_STONE,      # Void path
	LEAF_STONE,      # Nature path
}

# Collectible types that are crafting materials (used by weapon mod system)
const CRAFTING_MATERIALS: Array[int] = [
	CollectibleType.METEOR_SHARD,
	CollectibleType.QUANTUM_FUZZ,
	CollectibleType.NEBULA_DUST,
	CollectibleType.SPACE_GLOOP,
	CollectibleType.STAR_FRUIT,
	CollectibleType.HEALTH_FRAGMENT,  # Used in Vampire Beam recipe
	CollectibleType.SHIELD_CRYSTAL,
	CollectibleType.FIREBALL_SCROLL,
	CollectibleType.REGEN_CRYSTAL,
	CollectibleType.MAGNET_CORE,
	CollectibleType.TOXIC_EXTRACT,
]

# Drop chance for crafting materials from enemy kills
const CRAFTING_MATERIAL_DROP_CHANCE: float = 0.12  # 12% chance per kill
const CRAFTING_MATERIAL_DROP_CHANCE_BOSS: float = 1.0  # Bosses always drop a material

# ── Loot table: weighted drop chances for crafting materials ──
# Instead of a uniform random pick from all materials, we weight by rarity tier.
# Common materials drop more often, rare materials drop less often. This creates
# a meaningful progression curve — players accumulate common mats quickly and
# rarely see the exotic ones, making the rare recipes feel special when they
# finally get the ingredients. Bosses bias toward rarer drops (see below).
#
# Tiers (weight = relative probability):
#   Common (30):  SPACE_GLOOP, STAR_FRUIT, MAGNET_CORE
#   Uncommon (18): NEBULA_DUST, TOXIC_EXTRACT, REGEN_CRYSTAL
#   Rare (8):      FIREBALL_SCROLL, SHIELD_CRYSTAL
#   Epic (4):      QUANTUM_FUZZ, METEOR_SHARD
#   Legendary (2): HEALTH_FRAGMENT  (precious — also a healing item)
#
# HEALTH_FRAGMENT is in the loot table because it's used in the Vampire Beam
# recipe. It's weighted lowest because it doubles as a heal pickup, so dropping
# it as a crafting mat would steal the heal opportunity. The low weight means
# most of the time you'll get HP fragments from world spawns, not enemy drops.
const CRAFTING_LOOT_TABLE: Dictionary = {
	CollectibleType.SPACE_GLOOP: 30,
	CollectibleType.STAR_FRUIT: 30,
	CollectibleType.MAGNET_CORE: 30,
	CollectibleType.NEBULA_DUST: 18,
	CollectibleType.TOXIC_EXTRACT: 18,
	CollectibleType.REGEN_CRYSTAL: 18,
	CollectibleType.FIREBALL_SCROLL: 8,
	CollectibleType.SHIELD_CRYSTAL: 8,
	CollectibleType.QUANTUM_FUZZ: 4,
	CollectibleType.METEOR_SHARD: 4,
	CollectibleType.HEALTH_FRAGMENT: 2,
}
# Bosses get a rarity bias — their loot table shifts weight toward rarer tiers
# so boss kills feel rewarding. Common weights are halved, epic/legendary are
# doubled. This means a boss is ~4x more likely to drop a Meteor Shard or
# Quantum Fuzz than a normal enemy, and ~10x more likely to drop a Health Fragment.
const CRAFTING_LOOT_TABLE_BOSS_BIAS: Dictionary = {
	CollectibleType.SPACE_GLOOP: 15,
	CollectibleType.STAR_FRUIT: 15,
	CollectibleType.MAGNET_CORE: 15,
	CollectibleType.NEBULA_DUST: 18,
	CollectibleType.TOXIC_EXTRACT: 18,
	CollectibleType.REGEN_CRYSTAL: 18,
	CollectibleType.FIREBALL_SCROLL: 16,
	CollectibleType.SHIELD_CRYSTAL: 16,
	CollectibleType.QUANTUM_FUZZ: 8,
	CollectibleType.METEOR_SHARD: 8,
	CollectibleType.HEALTH_FRAGMENT: 4,
}

# ─── Sky & Stars ──────────────────────────────────────────────────────────────
const STAR_COUNT: int = 80
const STAR_HEIGHT_MIN: float = 80.0
const STAR_HEIGHT_MAX: float = 150.0
const STAR_SPREAD: float = 200.0
const SKY_RADIUS: float = 300.0
const SKY_HEIGHT_MIN: float = 60.0
const SKY_HEIGHT_MAX: float = 250.0
# Sky gradient: deep purple at zenith → alien pink at horizon
const SKY_TOP_COLOR: Color = Color(20.0 / 255.0, 0.0, 60.0 / 255.0)
const SKY_HORIZON_COLOR: Color = Color(120.0 / 255.0, 40.0 / 255.0, 80.0 / 255.0)

# Star color palette (0-1 normalized — converted from Ursina rgba 0-255)
const STAR_COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(1.0, 240.0 / 255.0, 220.0 / 255.0),
	Color(220.0 / 255.0, 230.0 / 255.0, 1.0),
	Color(1.0, 200.0 / 255.0, 180.0 / 255.0),
	Color(180.0 / 255.0, 220.0 / 255.0, 1.0),
	Color(1.0, 220.0 / 255.0, 1.0),
	Color(1.0, 1.0, 200.0 / 255.0),
	Color(200.0 / 255.0, 1.0, 220.0 / 255.0),
]

# ─── Nebula Clouds ────────────────────────────────────────────────────────────
const NEBULA_CLOUD_COUNT: int = 12
const NEBULA_SPREAD: float = 250.0
const NEBULA_HEIGHT_MIN: float = 100.0
const NEBULA_HEIGHT_MAX: float = 180.0

# Nebula color palette (0-1 normalized — converted from Ursina rgb 0-255)
const NEBULA_COLORS: Array[Color] = [
	Color(100.0 / 255.0, 30.0 / 255.0, 160.0 / 255.0),   # deep purple
	Color(30.0 / 255.0, 60.0 / 255.0, 160.0 / 255.0),    # deep blue
	Color(160.0 / 255.0, 30.0 / 255.0, 60.0 / 255.0),    # crimson
	Color(30.0 / 255.0, 140.0 / 255.0, 100.0 / 255.0),   # teal
	Color(160.0 / 255.0, 90.0 / 255.0, 30.0 / 255.0),    # amber
	Color(60.0 / 255.0, 30.0 / 255.0, 140.0 / 255.0),    # indigo
	Color(50.0 / 255.0, 100.0 / 255.0, 160.0 / 255.0),   # sky blue
	Color(140.0 / 255.0, 50.0 / 255.0, 100.0 / 255.0),   # rose
]

# ─── Horizon Glow ─────────────────────────────────────────────────────────────
const HORIZON_GLOW_COUNT: int = 8
const HORIZON_GLOW_SPREAD: float = 300.0
const HORIZON_GLOW_HEIGHT_MIN: float = 5.0
const HORIZON_GLOW_HEIGHT_MAX: float = 40.0
const HORIZON_GLOW_ALPHA_BASE: float = 35.0 / 255.0

# ─── Portal System ────────────────────────────────────────────────────────────
const PORTAL_COUNT: int = 4
const PORTAL_COOLDOWN: float = 3.0
const PORTAL_INNER_COLOR: Color = Color(0.0, 1.0, 1.0, 150.0 / 255.0)
const PORTAL_OUTER_COLOR: Color = Color(100.0 / 255.0, 0.0, 1.0, 80.0 / 255.0)
const PORTAL_GROUND_GLOW_COLOR: Color = Color(0.0, 200.0 / 255.0, 1.0, 40.0 / 255.0)
const PORTAL_PILLAR_COLOR: Color = Color(60.0 / 255.0, 180.0 / 255.0, 220.0 / 255.0)

# ─── Wandering Trader ────────────────────────────────────────────────────────
const TRADER_NAMES: Array[String] = ["Zix", "Glip", "Orbix", "Fweem"]
const TRADER_SPEED: float = 2.5
const TRADER_WANDER_RADIUS: float = 40.0
const TRADER_TRADE_COST: int = 5
const TRADER_RESPAWN_TIME: float = 60.0
const TRADER_INITIAL_COUNT: int = 2
const TRADER_GLOW_RANGE: float = 4.0
const TRADER_GLOW_PULSE_SPEED: float = 5.0
const TRADER_BODY_COLOR: Color = Color(1.0, 200.0 / 255.0, 100.0 / 255.0)
const TRADER_HAT_COLOR: Color = Color(200.0 / 255.0, 50.0 / 255.0, 200.0 / 255.0)

# ─── Alien Monolith ──────────────────────────────────────────────────────────
const MONOLITH_SPAWN_CHANCE_CRYSTAL: float = 0.06
const MONOLITH_SPAWN_CHANCE_SNOW: float = 0.04
const MONOLITH_BUFF_DURATION: float = 10.0
const MONOLITH_COOLDOWN: float = 45.0
const MONOLITH_ACTIVATE_RANGE: float = 4.5
const MONOLITH_SPEED_MULT: float = 1.5
const MONOLITH_DAMAGE_MULT: float = 1.4
const MONOLITH_XP_MULT: float = 2.0
const MONOLITH_BODY_COLOR: Color = Color(80.0 / 255.0, 60.0 / 255.0, 120.0 / 255.0)
const MONOLITH_CAP_COLOR: Color = Color(150.0 / 255.0, 100.0 / 255.0, 1.0)
const MONOLITH_SKIP_IF_ALL_BUFFS_ACTIVE: bool = true

# ─── Healing Crystal Shrine ──────────────────────────────────────────────────
const SHRINE_HEAL_AMOUNT: int = 55
const SHRINE_COOLDOWN: float = 60.0
const SHRINE_ACTIVATE_RANGE: float = 4.5
const SHRINE_SPAWN_CHANCE_MUSHROOM: float = 0.04
const SHRINE_SPAWN_CHANCE_SWAMP: float = 0.05
const SHRINE_CRYSTAL_COLOR: Color = Color(100.0 / 255.0, 1.0, 150.0 / 255.0)

# ─── Floating Islands ────────────────────────────────────────────────────────
const FLOATING_ISLAND_HEIGHT_MIN: float = 3.0
const FLOATING_ISLAND_HEIGHT_MAX: float = 6.0
const FLOATING_ISLAND_SPAWN_CHANCE: float = 0.15
const FLOATING_ISLAND_CRYSTAL_CHANCE: float = 0.4
const FLOATING_ISLAND_COLOR: Color = Color(160.0 / 255.0, 120.0 / 255.0, 220.0 / 255.0)

# ─── Alien Ruins ─────────────────────────────────────────────────────────────
const RUINS_PILLAR_CHANCE: float = 0.08
const RUINS_WALL_CHANCE: float = 0.05

# ─── Phase 22: New Biomes ─────────────────────────────────────────────────────
# Deep Ocean — underwater biome with buoyancy physics and bioluminescent life.
# Player experiences reduced gravity (floats up slowly) and slower movement.
const DEEP_OCEAN_DEPTH: float = -2.5               # Terrain height (below water plane)
const DEEP_OCEAN_BUOYANCY: float = 4.0              # Upward force on player per second
const DEEP_OCEAN_SPEED_MULT: float = 0.6            # Player moves slower while "swimming"
const DEEP_OCEAN_DAMAGE_INTERVAL: float = 0.0      # No damage — just buoyancy (set >0 to drown)
const DEEP_OCEAN_GLOW_CHANCE: float = 0.25          # Per-tile chance of bioluminescent deco
const DEEP_OCEAN_COLOR: Color = Color(10.0 / 255.0, 60.0 / 255.0, 130.0 / 255.0)
const DEEP_OCEAN_DEEP_COLOR: Color = Color(5.0 / 255.0, 20.0 / 255.0, 70.0 / 255.0)

# Volcano Core — erupting terrain, lava rivers, heat damage zones.
const VOLCANO_CORE_HEIGHT: float = 0.8              # Slightly raised terrain
const VOLCANO_CORE_HEAT_DAMAGE: int = 3            # Per-tick damage to exposed entities
const VOLCANO_CORE_HEAT_INTERVAL: float = 1.5      # Seconds between heat ticks
const VOLCANO_CORE_ERUPTION_CHANCE: float = 0.12   # Per-tile chance of lava-vent decoration
const VOLCANO_CORE_COLOR: Color = Color(120.0 / 255.0, 30.0 / 255.0, 10.0 / 255.0)
const VOLCANO_CORE_GLOW_COLOR: Color = Color(1.0, 100.0 / 255.0, 20.0 / 255.0, 80.0 / 255.0)

# Sky Citadel — floating platforms, wind currents, cloud navigation.
const SKY_CITADEL_HEIGHT: float = 8.0               # High altitude terrain
const SKY_CITADEL_WIND_FORCE: float = 3.0          # Horizontal wind push (varies direction)
const SKY_CITADEL_WIND_CHANGE_INTERVAL: float = 6.0  # Seconds between wind direction shifts
const SKY_CITADEL_PLATFORM_CHANCE: float = 0.18    # Per-tile chance of floating platform
const SKY_CITADEL_COLOR: Color = Color(200.0 / 255.0, 220.0 / 255.0, 240.0 / 255.0)
const SKY_CITADEL_CLOUD_COLOR: Color = Color(1.0, 1.0, 1.0, 0.5)

# Digital Grid — cyberpunk aesthetic, wireframe terrain, glitch effects.
const DIGITAL_GRID_GLITCH_CHANCE: float = 0.04     # Per-tile chance of glitch deco
const DIGITAL_GRID_COLOR: Color = Color(20.0 / 255.0, 40.0 / 255.0, 60.0 / 255.0)
const DIGITAL_GRID_NEON_COLOR: Color = Color(0.0, 1.0, 1.0)
const DIGITAL_GRID_PINK_COLOR: Color = Color(1.0, 0.2, 0.8)

# Crystal Caverns — reflective surfaces, prism light, crystal enemies.
const CRYSTAL_CAVERNS_HEIGHT: float = -1.5         # Sunken cavern floor
const CRYSTAL_CAVERNS_CRYSTAL_CHANCE: float = 0.22  # Per-tile chance of crystal cluster
const CRYSTAL_CAVERNS_COLOR: Color = Color(60.0 / 255.0, 130.0 / 255.0, 180.0 / 255.0)
const CRYSTAL_CAVERNS_PRISM_COLORS: Array[Color] = [
	Color(1.0, 0.2, 0.2),  # Red prism
	Color(1.0, 0.6, 0.0),  # Orange prism
	Color(1.0, 1.0, 0.0),  # Yellow prism
	Color(0.2, 1.0, 0.2),  # Green prism
	Color(0.2, 0.6, 1.0),  # Blue prism
	Color(0.6, 0.2, 1.0),  # Violet prism
]

# Ancient Ruins — decayed structures, hidden traps, relic collectibles.
const ANCIENT_RUINS_HEIGHT: float = 0.3
const ANCIENT_RUINS_PILLAR_CHANCE: float = 0.10    # Per-tile chance of ruined pillar
const ANCIENT_RUINS_TRAP_CHANCE: float = 0.06      # Per-tile chance of hidden trap
const ANCIENT_RUINS_RELIC_CHANCE: float = 0.03     # Per-tile chance of relic collectible
const ANCIENT_RUINS_COLOR: Color = Color(140.0 / 255.0, 120.0 / 255.0, 80.0 / 255.0)
const ANCIENT_RUINS_STONE_COLOR: Color = Color(110.0 / 255.0, 100.0 / 255.0, 80.0 / 255.0)
const ANCIENT_RUINS_TRAP_DAMAGE: int = 20
const ANCIENT_RUINS_TRAP_RADIUS: float = 3.0

# Underground — subterranean caverns with limited light, unique enemies.
const UNDERGROUND_HEIGHT: float = -4.0             # Deep below surface
const UNDERGROUND_STALACTITE_CHANCE: float = 0.15
const UNDERGROUND_STALAGMITE_CHANCE: float = 0.12
const UNDERGROUND_GLOW_CHANCE: float = 0.08        # Glowing mushroom/fungus
const UNDERGROUND_COLOR: Color = Color(40.0 / 255.0, 35.0 / 255.0, 30.0 / 255.0)
const UNDERGROUND_DARKNESS: float = 0.85            # Ambient light reduction (0..1)

# Biome transition zones — blended terrain between adjacent biomes.
# When the player is within TRANSITION_BLEND_DISTANCE of a biome boundary,
# the terrain color and fog cross-fade smoothly between the two biomes.
const TRANSITION_BLEND_DISTANCE: float = 8.0       # Tiles near boundary to blend
const TRANSITION_BLEND_SPEED: float = 2.0          # Lerp speed for color/fog blend

# ─── Biome Fog (0-1 normalized colors, converted from Ursina 0-255) ──────────
const BIOME_FOG: Dictionary = {
	GameConstants.Biome.GRASS: {"color": Color(30.0 / 255.0, 10.0 / 255.0, 60.0 / 255.0), "density": 0.006},
	GameConstants.Biome.DESERT: {"color": Color(100.0 / 255.0, 70.0 / 255.0, 30.0 / 255.0), "density": 0.014},
	GameConstants.Biome.WATER: {"color": Color(10.0 / 255.0, 20.0 / 255.0, 80.0 / 255.0), "density": 0.010},
	GameConstants.Biome.LAVA: {"color": Color(100.0 / 255.0, 20.0 / 255.0, 5.0 / 255.0), "density": 0.016},
	GameConstants.Biome.FOREST: {"color": Color(10.0 / 255.0, 40.0 / 255.0, 15.0 / 255.0), "density": 0.012},
	GameConstants.Biome.CRYSTAL: {"color": Color(15.0 / 255.0, 40.0 / 255.0, 60.0 / 255.0), "density": 0.007},
	GameConstants.Biome.SNOW: {"color": Color(60.0 / 255.0, 60.0 / 255.0, 80.0 / 255.0), "density": 0.005},
	GameConstants.Biome.SWAMP: {"color": Color(30.0 / 255.0, 50.0 / 255.0, 15.0 / 255.0), "density": 0.016},
	GameConstants.Biome.MUSHROOM: {"color": Color(50.0 / 255.0, 10.0 / 255.0, 60.0 / 255.0), "density": 0.012},
	GameConstants.Biome.ALIEN: {"color": Color(60.0 / 255.0, 20.0 / 255.0, 70.0 / 255.0), "density": 0.010},
	GameConstants.Biome.FLOATING_ISLANDS: {"color": Color(40.0 / 255.0, 25.0 / 255.0, 60.0 / 255.0), "density": 0.005},
	GameConstants.Biome.TOXIC_BOG: {"color": Color(50.0 / 255.0, 60.0 / 255.0, 15.0 / 255.0), "density": 0.018},
	# ── Phase 22: New biome fog ──
	GameConstants.Biome.DEEP_OCEAN: {"color": Color(5.0 / 255.0, 15.0 / 255.0, 50.0 / 255.0), "density": 0.024},
	GameConstants.Biome.VOLCANO_CORE: {"color": Color(80.0 / 255.0, 15.0 / 255.0, 5.0 / 255.0), "density": 0.022},
	GameConstants.Biome.SKY_CITADEL: {"color": Color(150.0 / 255.0, 180.0 / 255.0, 230.0 / 255.0), "density": 0.004},
	GameConstants.Biome.DIGITAL_GRID: {"color": Color(10.0 / 255.0, 30.0 / 255.0, 40.0 / 255.0), "density": 0.008},
	GameConstants.Biome.CRYSTAL_CAVERNS: {"color": Color(20.0 / 255.0, 50.0 / 255.0, 70.0 / 255.0), "density": 0.009},
	GameConstants.Biome.ANCIENT_RUINS: {"color": Color(60.0 / 255.0, 50.0 / 255.0, 30.0 / 255.0), "density": 0.013},
	GameConstants.Biome.UNDERGROUND: {"color": Color(10.0 / 255.0, 8.0 / 255.0, 5.0 / 255.0), "density": 0.030},
}
const FOG_TRANSITION_SPEED: float = 4.0

# ─── Water & Lava Surface Colors (0-1 normalized) ────────────────────────────
const WATER_OVERLAY_COLOR: Color = Color(30.0 / 255.0, 80.0 / 255.0, 220.0 / 255.0, 80.0 / 255.0)
const LAVA_GLOW_COLOR: Color = Color(1.0, 120.0 / 255.0, 30.0 / 255.0, 60.0 / 255.0)

# ─── Bounce Pad ──────────────────────────────────────────────────────────────
const BOUNCE_PAD_FORCE: float = 25.0
const BOUNCE_PAD_COLOR: Color = Color(1.0, 200.0 / 255.0, 50.0 / 255.0)
const BOUNCE_PAD_COOLDOWN: float = 0.5

# ─── Damage Numbers (Phase 4) ─────────────────────────────────────────────────
const DMG_NUMBER_LIFETIME: float = 1.2
const DMG_NUMBER_RISE_SPEED: float = 3.0
const DMG_NUMBER_FADE_START: float = 0.5  # Fraction of lifetime before fade begins
const DMG_NUMBER_POPIN_DURATION: float = 0.12
const DMG_NUMBER_POPIN_START_SCALE: float = 0.3
const DMG_NUMBER_POPIN_PEAK_SCALE: float = 1.15
const DMG_NUMBER_BASE_SCALE: float = 1.0
const DMG_NUMBER_CRIT_SCALE: float = 1.25
const DMG_NUMBER_KILL_SCALE: float = 1.4
const DMG_NUMBER_CRIT_COLOR: Color = Color(1.0, 215.0 / 255.0, 0.0)   # Gold
const DMG_NUMBER_KILL_COLOR: Color = Color(1.0, 1.0, 0.0)             # Yellow
const DMG_NUMBER_NORMAL_COLOR: Color = Color(1.0, 1.0, 1.0)           # White
const DMG_NUMBER_HEAL_COLOR: Color = Color(80.0 / 255.0, 1.0, 120.0 / 255.0)  # Green
const DMG_NUMBER_XP_COLOR: Color = Color(100.0 / 255.0, 200.0 / 255.0, 1.0)   # Cyan-blue
const DMG_NUMBER_JITTER_X: float = 0.8
const DMG_NUMBER_JITTER_Z: float = 0.4

# ─── Combo Milestones (Phase 4) ───────────────────────────────────────────────
const COMBO_MILESTONE_INTERVAL: int = 5
const COMBO_MILESTONE_XP_BASE: int = 20
const COMBO_MILESTONE_XP_PER_TIER: int = 10
const COMBO_MILESTONE_FLASH_DURATION: float = 0.3
const COMBO_MILESTONE_FLASH_COLORS: Array[Color] = [
	Color(1.0, 60.0 / 255.0, 60.0 / 255.0),    # Tier 1 (x5): Red
	Color(60.0 / 255.0, 200.0 / 255.0, 1.0),   # Tier 2 (x10): Cyan
	Color(1.0, 215.0 / 255.0, 50.0 / 255.0),   # Tier 3 (x15): Gold
	Color(200.0 / 255.0, 60.0 / 255.0, 1.0),   # Tier 4 (x20): Purple
	Color(60.0 / 255.0, 1.0, 80.0 / 255.0),    # Tier 5 (x25): Green
]

# ─── Pickup Streak Milestones (Phase 4) ───────────────────────────────────────
const PICKUP_STREAK_WINDOW: float = 3.0
const PICKUP_STREAK_MILESTONE_INTERVAL: int = 5
const PICKUP_STREAK_XP_PER_MILESTONE: int = 15
const PICKUP_STREAK_DISPLAY_LIFETIME: float = 2.5
const PICKUP_STREAK_COLOR: Color = Color(100.0 / 255.0, 1.0, 180.0 / 255.0)  # Mint-cyan

# ─── Crit Chain (Phase 4) ─────────────────────────────────────────────────────
const CRIT_CHAIN_WINDOW: float = 3.0
const CRIT_CHAIN_THRESHOLD: int = 3
const CRIT_CHAIN_MULT: float = 3.0
const CRIT_BASE_CHANCE: float = 0.1
const CRIT_BASE_MULT: float = 2.0

# ─── Emergency Health Magnet (Phase 4) ────────────────────────────────────────
const EMERGENCY_HP_THRESHOLD: float = 0.25
const HEALTH_FRAGMENT_EMERGENCY_PULL_RADIUS: float = 14.0
const HEALTH_FRAGMENT_EMERGENCY_PULL_SPEED: float = 18.0

# ─── Spawn Direction Indicator (Phase 4) ──────────────────────────────────────
const SPAWN_DIRECTION_INDICATOR_DURATION: float = 2.0
const SPAWN_DIRECTION_INDICATOR_DISTANCE: float = 250.0  # Screen-edge offset
const SPAWN_DIRECTION_ARROW_COLOR: Color = Color(1.0, 0.4, 0.2, 0.8)

# ─── Minimap (Phase 5) ────────────────────────────────────────────────────────
const MINIMAP_SIZE: float = 180.0           # Pixel size of the minimap square
const MINIMAP_MARGIN: float = 20.0          # Margin from screen edge
const MINIMAP_REFRESH_INTERVAL: float = 0.25  # Seconds between terrain redraw
const MINIMAP_DOT_REFRESH_INTERVAL: float = 0.05  # Seconds between dot updates
const MINIMAP_ENEMY_DOT_COLOR: Color = Color(1.0, 60.0 / 255.0, 60.0 / 255.0)
const MINIMAP_PLAYER_DOT_COLOR: Color = Color(1.0, 1.0, 1.0)
const MINIMAP_BOSS_DOT_COLOR: Color = Color(1.0, 0.0, 1.0)
const MINIMAP_COLLECTIBLE_DOT_COLOR: Color = Color(100.0 / 255.0, 200.0 / 255.0, 1.0)
const MINIMAP_BG_COLOR: Color = Color(0.05, 0.03, 0.08, 0.85)
const MINIMAP_BORDER_COLOR: Color = Color(0.3, 0.6, 0.9, 0.9)
const MINIMAP_PORTAL_DOT_COLOR: Color = Color(0.0, 1.0, 1.0)
const MINIMAP_TRADER_DOT_COLOR: Color = Color(1.0, 200.0 / 255.0, 100.0 / 255.0)
const MINIMAP_VIEW_RANGE: float = 120.0  # World units visible around player

# ─── Damage Direction Indicator (Phase 5) ─────────────────────────────────────
const DAMAGE_INDICATOR_DURATION: float = 1.5
const DAMAGE_INDICATOR_MAX_ALPHA: float = 220.0 / 255.0
const DAMAGE_INDICATOR_DISTANCE: float = 180.0  # Pixels from screen center
const DAMAGE_INDICATOR_FADE_SPEED: float = 1.5
const DAMAGE_INDICATOR_COLOR: Color = Color(1.0, 0.15, 0.15)
const DAMAGE_INDICATOR_MAX_ACTIVE: int = 6  # Max simultaneous indicators

# ─── Boss Tension Vignette (Phase 5) ──────────────────────────────────────────
const BOSS_VIGNETTE_BASE_ALPHA: float = 30.0 / 255.0
const BOSS_VIGNETTE_MAX_ALPHA: float = 90.0 / 255.0
const BOSS_VIGNETTE_PULSE_SPEED: float = 3.0
const BOSS_VIGNETTE_PROXIMITY_RANGE: float = 60.0  # World units for max intensity
const BOSS_VIGNETTE_COLOR: Color = Color(0.9, 0.05, 0.05)

# ─── Death Screen (Phase 5) ───────────────────────────────────────────────────
const DEATH_SCREEN_FADE_IN_DURATION: float = 0.8
const DEATH_SCREEN_BG_COLOR: Color = Color(0.02, 0.0, 0.05, 0.82)
const DEATH_SCREEN_TITLE_COLOR: Color = Color(0.9, 0.15, 0.15)
const DEATH_SCREEN_STAT_COLOR: Color = Color(0.85, 0.85, 0.95)
const DEATH_SCREEN_STAT_LABEL_COLOR: Color = Color(0.5, 0.5, 0.6)

# ─── Biome Indicator (Phase 5) ────────────────────────────────────────────────
const BIOME_INDICATOR_FADE_SPEED: float = 5.0
const BIOME_NAMES: Dictionary = {
	GameConstants.Biome.GRASS: "Grasslands",
	GameConstants.Biome.DESERT: "Desert Wastes",
	GameConstants.Biome.WATER: "Azure Lakes",
	GameConstants.Biome.LAVA: "Magma Fields",
	GameConstants.Biome.FOREST: "Whispering Forest",
	GameConstants.Biome.CRYSTAL: "Crystal Caverns",
	GameConstants.Biome.SNOW: "Frostfall Tundra",
	GameConstants.Biome.SWAMP: "Murk Swamp",
	GameConstants.Biome.ALIEN: "Alien Zone",
	GameConstants.Biome.MUSHROOM: "Mushroom Grove",
	GameConstants.Biome.FLOATING_ISLANDS: "Floating Isles",
	GameConstants.Biome.TOXIC_BOG: "Toxic Bog",
	# ── Phase 22: New biomes ──
	GameConstants.Biome.DEEP_OCEAN: "Deep Ocean",
	GameConstants.Biome.VOLCANO_CORE: "Volcano Core",
	GameConstants.Biome.SKY_CITADEL: "Sky Citadel",
	GameConstants.Biome.DIGITAL_GRID: "Digital Grid",
	GameConstants.Biome.CRYSTAL_CAVERNS: "Crystal Caverns",
	GameConstants.Biome.ANCIENT_RUINS: "Ancient Ruins",
	GameConstants.Biome.UNDERGROUND: "Underground",
}
const BIOME_INDICATOR_TEXT_COLOR: Color = Color(0.9, 0.9, 1.0, 0.85)

# ─── Dash Cooldown Indicator (Phase 5) ────────────────────────────────────────
const DASH_COOLDOWN_RING_RADIUS: float = 22.0
const DASH_COOLDOWN_RING_THICKNESS: float = 4.0
const DASH_COOLDOWN_READY_COLOR: Color = Color(0.3, 1.0, 0.5, 0.9)
const DASH_COOLDOWN_CHARGING_COLOR: Color = Color(0.5, 0.5, 0.5, 0.6)
const DASH_COOLDOWN_ICON_COLOR: Color = Color(0.4, 1.0, 0.6)

# ─── Kill Feed (Phase 5) ──────────────────────────────────────────────────────
const KILL_FEED_MAX_ENTRIES: int = 5
const KILL_FEED_LIFETIME: float = 4.0
const KILL_FEED_FADE_SPEED: float = 2.0
const KILL_FEED_COLOR: Color = Color(1.0, 0.85, 0.3, 0.9)

# ─── Phase 8: Physics & Interaction ───────────────────────────────────────────
# Knockback impulse forces applied when enemies take damage / push each other.
const KNOCKBACK_FORCE_HIT: float = 12.0          # Impulse when struck by projectile
const KNOCKBACK_FORCE_EXPLOSION: float = 30.0    # Impulse from explosions (bomber, pulse)
const KNOCKBACK_FORCE_MELEE: float = 8.0         # Enemy-to-enemy push
const KNOCKBACK_FORCE_DASH_BUMP: float = 18.0    # Zorp dashes into enemy
const KNOCKBACK_DAMPING: float = 25.0            # How fast knockback velocity decays per second
const ENEMY_SEPARATION_RADIUS: float = 1.2       # Minimum spacing between same-type enemies
const ENEMY_SEPARATION_FORCE: float = 14.0       # Force applied when enemies overlap

# Physics-based dash — Zorp slides and bounces off walls
const DASH_SLIDE_FRICTION: float = 0.92          # Velocity retained per frame during slide (1.0 = no friction)
const DASH_SLIDE_MIN_SPEED: float = 3.0          # Below this speed, slide ends
const DASH_BOUNCE_RESTITUTION: float = 0.6       # Energy retained on wall bounce

# Collectible bounce & tumble (RigidBody3D physics)
const COLLECTIBLE_BOUNCE_RESTITUTION: float = 0.55
const COLLECTIBLE_BOUNCE_MASS: float = 0.3
const COLLECTIBLE_TUMBLE_TORQUE: float = 5.0     # Random angular impulse on spawn
const COLLECTIBLE_GRAVITY_SCALE: float = 0.8     # Slight floatiness

# Destructible objects
const DESTRUCTIBLE_HP: int = 30
const DESTRUCTIBLE_KNOCKBACK_FORCE: float = 15.0
const DESTRUCTIBLE_SHATTER_COUNT: int = 8        # Number of fragments on shatter
const DESTRUCTIBLE_SHATTER_IMPULSE: float = 10.0
const DESTRUCTIBLE_SHATTER_LIFETIME: float = 3.0
const DESTRUCTIBLE_SPAWN_CHANCE: float = 0.05    # Per-tile chance in a biome
const DESTRUCTIBLE_CRATE_COLOR: Color = Color(0.65, 0.45, 0.25)   # Wooden crate
const DESTRUCTIBLE_CRYSTAL_COLOR: Color = Color(0.7, 0.4, 0.9)    # Crystal chunk
const DESTRUCTIBLE_REWARD_SCORE: int = 30
const DESTRUCTIBLE_REWARD_XP: int = 10

# Graviton physics gravity well (Area3D gravity point)
const GRAVITON_AREA_GRAVITY: float = 14.0        # Gravity strength (Godot units)
const GRAVITON_AREA_FALLOFF: float = 1.0         # Falloff exponent (1.0 = linear)

# ─── Phase 9: Shaders & Visual Effects ────────────────────────────────────────
# Biome → screen shader mapping. Each biome can have at most one ambient
# screen shader active at a time (heat, frost, chromatic, dissolve, crystal).
# The ShaderManager autoloads the .gdshader files and swaps the active shader
# when the biome changes, cross-fading the strength for smooth transitions.
const BIOME_SHADER_MAP: Dictionary = {
	GameConstants.Biome.LAVA: "heat_distortion",
	GameConstants.Biome.SNOW: "frost_vignette",
	GameConstants.Biome.ALIEN: "chromatic_aberration",
	GameConstants.Biome.TOXIC_BOG: "dissolve",
	GameConstants.Biome.CRYSTAL: "crystal_refraction",
	# ── Phase 22: New biome shader mappings ──
	GameConstants.Biome.VOLCANO_CORE: "heat_distortion",      # Hot shimmer
	GameConstants.Biome.DIGITAL_GRID: "chromatic_aberration",  # Glitch RGB split
	GameConstants.Biome.CRYSTAL_CAVERNS: "crystal_refraction", # Prismatic shimmer
	GameConstants.Biome.DEEP_OCEAN: "frost_vignette",          # Cold blue tint at edges
}

# Ambient shader strength per biome (0..1). Tuned so the effect is noticeable
# but never obscures gameplay.
const BIOME_SHADER_STRENGTH: Dictionary = {
	GameConstants.Biome.LAVA: 0.55,
	GameConstants.Biome.SNOW: 0.6,
	GameConstants.Biome.ALIEN: 0.45,
	GameConstants.Biome.TOXIC_BOG: 0.5,
	GameConstants.Biome.CRYSTAL: 0.4,
	# ── Phase 22: New biome shader strengths ──
	GameConstants.Biome.VOLCANO_CORE: 0.7,
	GameConstants.Biome.DIGITAL_GRID: 0.55,
	GameConstants.Biome.CRYSTAL_CAVERNS: 0.5,
	GameConstants.Biome.DEEP_OCEAN: 0.35,
}

# Low-HP warning vignette config
const LOW_HP_SHADER_THRESHOLD: float = 0.3      # HP ratio below which the warning kicks in
const LOW_HP_SHADER_MAX_STRENGTH: float = 0.85  # Strength when HP is near 0
const LOW_HP_SHADER_FADE_SPEED: float = 3.0     # How fast strength transitions (per second)

# Boss enrage shader config
const BOSS_ENRAGE_SHADER_THRESHOLD: float = 0.3  # Boss HP ratio below which enrage shader activates
const BOSS_ENRAGE_SHADER_MAX_STRENGTH: float = 0.8
const BOSS_ENRAGE_SHADER_FADE_SPEED: float = 4.0

# Shader cross-fade speed (biome transition)
const SHADER_TRANSITION_SPEED: float = 2.5

# ─── Phase 10: Smart Enemy AI ─────────────────────────────────────────────────
# Navigation & pathfinding
const AI_NAV_TARGET_DESIRED_DISTANCE: float = 2.5     # Stopping distance at nav target
const AI_NAV_PATH_UPDATE_INTERVAL: float = 0.4        # Seconds between repathing
const AI_NAV_RAYCAST_LENGTH: float = 80.0             # Max LOS check distance

# Line-of-sight detection
const AI_LOS_CHECK_INTERVAL: float = 0.3              # Seconds between LOS rechecks
const AI_LOS_RAY_COLLISION_MASK: int = 0b0001         # Only check against world/static layer

# Flanking — enemies try to circle around to the player's side/back
const AI_FLANK_CHANCE: float = 0.35                   # Probability an alerted enemy flanks
const AI_FLANK_ANGLE: float = 75.0                    # Degrees offset from direct approach
const AI_FLANK_DISTANCE: float = 6.0                  # Ideal flanking standoff distance
const AI_FLANK_REPOSITION_INTERVAL: float = 3.0       # Seconds between new flank angle picks

# Retreat — enemies back off at low HP
const AI_RETREAT_HP_THRESHOLD: float = 0.25           # HP ratio below which enemy retreats
const AI_RETREAT_DISTANCE: float = 14.0               # How far to back away
const AI_RETREAT_SPEED_MULT: float = 1.15             # Speed boost while fleeing
const AI_RETREAT_HEAL_THRESHOLD: float = 0.55         # HP ratio above which enemy resumes fighting

# Ambush — enemies hide behind the nearest cover until player is close
const AI_AMBUSH_DETECT_RANGE_MULT: float = 0.5        # Detection range multiplier while ambushing
const AI_AMBUSH_TRIGGER_RANGE: float = 10.0           # Player distance that breaks ambush
const AI_AMBUSH_COOLDOWN: float = 20.0                # Cooldown before re-ambush
const AI_AMBUSH_RUSH_SPEED_MULT: float = 1.6          # Speed boost when ambush breaks

# Pack behavior — nearby same-type allies coordinate
const AI_PACK_RADIUS: float = 12.0                    # Distance to find pack allies
const AI_PACK_MIN_ALLIES: int = 2                     # Min allies to form a pack
const AI_PACK_SYNC_INTERVAL: float = 1.5              # Seconds between pack sync checks
const AI_PACK_SURROUND_SPACING: float = 3.0           # Ideal spacing between surrounders
const AI_PACK_FRENZY_HP_THRESHOLD: float = 0.10       # HP ratio that triggers pack frenzy
const AI_PACK_FRENZY_RADIUS: float = 8.0              # How far frenzy spreads to allies
const AI_PACK_FRENZY_DURATION: float = 1.5            # Seconds of frenzy speed boost
const AI_PACK_FRENZY_SPEED_MULT: float = 1.4          # Speed multiplier during frenzy
const AI_PACK_FRENZY_FLASH_DURATION: float = 0.3      # Seconds of bright flash on frenzied allies
const AI_PACK_FRENZY_MIN_ALLIES: int = 2              # Min allies to trigger frenzy
const AI_PACK_FRENZY_COOLDOWN: float = 3.0            # Cooldown before frenzy retrigger

# Call for help — wounded enemy alerts nearby allies
const AI_CALL_HELP_HP_THRESHOLD: float = 0.35         # HP ratio below which enemy calls for help
const AI_CALL_HELP_RADIUS: float = 16.0               # Ally alert radius
const AI_CALL_HELP_COOLDOWN: float = 8.0              # Cooldown before calling again
const AI_CALL_HELP_ALERT_DURATION: float = 4.0        # Seconds alerted allies stay aggressive

# Enrage — when HP drops below threshold, enemy speeds up + red tint
const AI_ENRAGE_HP_THRESHOLD: float = 0.25            # HP ratio below which enrage triggers
const AI_ENRAGE_SPEED_MULT: float = 1.35              # Speed multiplier while enraged
const AI_ENRAGE_COLOR_MIX: float = 0.6                # Lerp factor toward red
const AI_ENRAGE_PROXIMITY_RADIUS: float = 25.0        # Distance for proximity warning
const AI_ENRAGE_PROXIMITY_NOTIFY_COOLDOWN: float = 4.0 # Min seconds between enrage warnings
const AI_ENRAGE_COLOR_TRANSITION: float = 0.3         # Seconds for color transition

# Near-death shudder
const AI_SHUDDER_HP_THRESHOLD: float = 0.10           # HP ratio below which shudder activates
const AI_SHUDDER_INTERVAL_MIN: float = 0.4            # Min seconds between shudder bursts
const AI_SHUDDER_INTERVAL_MAX: float = 0.9            # Max seconds between shudder bursts
const AI_SHUDDER_DURATION: float = 0.15               # How long a shudder burst lasts
const AI_SHUDDER_AMPLITUDE: float = 0.08              # X/Z scale jitter magnitude

# ─── Phase 14: Dimensional Rifts ──────────────────────────────────────────────
# 4 alternate dimensions, each with distinct gameplay effects.
enum Dimension {
	NORMAL,         # Default state
	VOID,           # Silhouettes only, shadow clone boss
	MIRROR,         # Collectibles hostile, enemies friendly
	TIME_SLOW,      # World at 0.3x speed, Zorp at 0.5x (relative advantage)
	REVERSE_GRAVITY,# Walk on ceiling, collectibles fall up
}

const DIMENSION_NAMES: Dictionary = {
	Dimension.NORMAL: "Normal Space",
	Dimension.VOID: "Void Dimension",
	Dimension.MIRROR: "Mirror Dimension",
	Dimension.TIME_SLOW: "Time-Slow Dimension",
	Dimension.REVERSE_GRAVITY: "Reverse Gravity",
}

const DIMENSION_COLORS: Dictionary = {
	Dimension.NORMAL: Color(0.9, 0.9, 1.0),
	Dimension.VOID: Color(0.1, 0.0, 0.15),
	Dimension.MIRROR: Color(0.8, 0.9, 1.0),
	Dimension.TIME_SLOW: Color(0.5, 0.7, 1.0),
	Dimension.REVERSE_GRAVITY: Color(0.9, 0.6, 1.0),
}

# Rift spawn system
const RIFT_SPAWN_INTERVAL_MIN: float = 25.0       # Min seconds between rift spawns
const RIFT_SPAWN_INTERVAL_MAX: float = 45.0       # Max seconds between rift spawns
const RIFT_SPAWN_DISTANCE_MIN: float = 20.0       # Min distance from player
const RIFT_SPAWN_DISTANCE_MAX: float = 50.0       # Max distance from player
const RIFT_MAX_ACTIVE: int = 2                    # Max rifts in world at once
const RIFT_LIFETIME: float = 60.0                 # Rift despawns after this (if not entered)
const RIFT_INTERACT_RANGE: float = 3.0            # Distance to enter rift

# Dimension duration (auto-return to normal after this)
const DIMENSION_DURATION: float = 30.0            # Seconds in alternate dimension
const DIMENSION_TRANSITION_DURATION: float = 0.8  # Screen wipe duration

# Time-slow dimension multipliers
const TIME_SLOW_WORLD_SCALE: float = 0.3          # Enemy/projectile speed multiplier
const TIME_SLOW_PLAYER_SCALE: float = 0.5         # Player speed multiplier (relative advantage)

# Reverse gravity
const REVERSE_GRAVITY_HEIGHT: float = 20.0        # Ceiling height above ground

# Mirror dimension
const MIRROR_COLLECTIBLE_DAMAGE: int = 8          # Damage from touching "hostile" collectibles
const MIRROR_ENEMY_PASSIVE: bool = true           # Enemies don't attack in mirror

# Void dimension
const VOID_SHADOW_CLONE_HP: int = 80              # HP of shadow clone boss in void
const VOID_SHADOW_CLONE_DAMAGE: int = 12          # Damage of shadow clone
const VOID_VISIBILITY_THRESHOLD: float = 0.3      # How dark everything gets

# Dimension-exclusive collectibles (rare items only found in rifts)
const RIFT_COLLECTIBLE_CHANCE: float = 0.5        # Chance a rift drops a rare item on exit
const RIFT_COLLECTIBLE_TYPES: Array[int] = [
	GameConstants.CollectibleType.METEOR_SHARD,
	GameConstants.CollectibleType.QUANTUM_FUZZ,
	GameConstants.CollectibleType.NEBULA_DUST,
]

# ─── Phase 15: Alien Companion Pet ────────────────────────────────────────────
# Pet evolution stages
enum PetStage {
	BABY,        # Stage 0: collect only, small radius
	ADOLESCENT,  # Stage 1: collect + attack small enemies
	ADULT,       # Stage 2: collect + attack all + shield Zorp
}

const PET_STAGE_NAMES: Array[String] = ["Baby", "Adolescent", "Adult"]

# Evolution points needed to advance to each stage
const PET_EVOLVE_TO_ADOLESCENT: int = 100   # Points needed: Baby → Adolescent
const PET_EVOLVE_TO_ADULT: int = 250        # Points needed: Adolescent → Adult

# Feeding values — how many evolution points each collectible type grants
const PET_FEED_VALUES: Dictionary = {
	GameConstants.CollectibleType.XP_ORB: 5,
	GameConstants.CollectibleType.SPACE_GLOOP: 10,
	GameConstants.CollectibleType.STAR_FRUIT: 15,
	GameConstants.CollectibleType.HEALTH_FRAGMENT: 8,
	GameConstants.CollectibleType.METEOR_SHARD: 40,
	GameConstants.CollectibleType.QUANTUM_FUZZ: 35,
	GameConstants.CollectibleType.NEBULA_DUST: 30,
	# Phase 16: Crafting materials also feed the pet
	GameConstants.CollectibleType.SHIELD_CRYSTAL: 35,
	GameConstants.CollectibleType.FIREBALL_SCROLL: 35,
	GameConstants.CollectibleType.REGEN_CRYSTAL: 35,
	GameConstants.CollectibleType.MAGNET_CORE: 30,
	GameConstants.CollectibleType.TOXIC_EXTRACT: 30,
	# Phase 27: Evolution stones also feed the pet a large chunk (60 pts)
	GameConstants.CollectibleType.EMBER_STONE: 60,
	GameConstants.CollectibleType.FROST_STONE: 60,
	GameConstants.CollectibleType.SPARK_STONE: 60,
	GameConstants.CollectibleType.VOID_STONE: 60,
	GameConstants.CollectibleType.LEAF_STONE: 60,
}

# Maps a CollectibleType evolution stone to its PetPath. Looked up by the
# companion pet when it consumes a stone via the player's "use_stone" action.
const PET_STONE_TO_PATH: Dictionary = {
	GameConstants.CollectibleType.EMBER_STONE: 1,  # PetPath.FIRE
	GameConstants.CollectibleType.FROST_STONE: 2,  # PetPath.ICE
	GameConstants.CollectibleType.SPARK_STONE: 3,  # PetPath.ELECTRIC
	GameConstants.CollectibleType.VOID_STONE: 4,   # PetPath.VOID
	GameConstants.CollectibleType.LEAF_STONE: 5,   # PetPath.NATURE
}

# Pet stats per stage
const PET_STAGE_CONFIG: Array[Dictionary] = [
	{  # BABY
		"scale": 0.3,
		"color": Color(0.4, 0.9, 1.0),          # Light cyan
		"emission": Color(0.2, 0.6, 1.0),
		"collect_radius": 8.0,
		"attack_range": 0.0,                      # Can't attack
		"attack_damage": 0,
		"attack_cooldown": 0.0,
		"shield_reduction": 0.0,                  # No shield
		"follow_distance": 3.0,
		"speed": 10.0,
		"hp": 30,
	},
	{  # ADOLESCENT
		"scale": 0.5,
		"color": Color(0.3, 0.7, 0.9),           # Teal
		"emission": Color(0.15, 0.5, 0.8),
		"collect_radius": 12.0,
		"attack_range": 4.0,
		"attack_damage": 8,
		"attack_cooldown": 1.5,
		"shield_reduction": 0.0,
		"follow_distance": 4.0,
		"speed": 12.0,
		"hp": 60,
	},
	{  # ADULT
		"scale": 0.7,
		"color": Color(0.5, 0.4, 0.9),           # Blue-purple
		"emission": Color(0.3, 0.2, 0.7),
		"collect_radius": 16.0,
		"attack_range": 6.0,
		"attack_damage": 15,
		"attack_cooldown": 1.0,
		"shield_reduction": 0.15,                 # 15% damage reduction for Zorp
		"follow_distance": 5.0,
		"speed": 14.0,
		"hp": 100,
	},
]

# Pet movement and behavior
const PET_FOLLOW_LERP_SPEED: float = 6.0       # How fast pet lerps toward follow position
const PET_HEIGHT_OFFSET: float = 1.5           # Floats above player's shoulder
const PET_BOB_AMPLITUDE: float = 0.15          # Idle bob height
const PET_BOB_SPEED: float = 3.0               # Idle bob frequency
const PET_FETCH_SPEED: float = 20.0            # Speed when fetching a specific item
const PET_FETCH_RANGE: float = 60.0            # Max distance for fetch command
const PET_HEAL_PER_PICKUP: float = 2.0         # Pet heals itself per item collected
const PET_IDLE_ANIMATION_INTERVAL: float = 5.0 # Seconds between random idle anims
const PET_SPAWN_OFFSET: Vector3 = Vector3(2.0, 1.0, 0.0)  # Initial spawn offset from player

# ─── Phase 27: Pet Evolution Expansion ────────────────────────────────────────
# Elemental evolution paths. The default pet (no stone used) follows the
# "PRISMATIC" path which is the original cyan→teal→blue-purple stage config
# above. Feeding the pet a matching Evolution Stone locks it into one of the
# five elemental paths — each path overrides the stage config colors, stats,
# and grants a unique passive ability.

enum PetPath {
	PRISMATIC,   # 0 — default path (original cyan/teal/blue-purple)
	FIRE,        # 1 — Ember Stone → burns attackers, fireball attack
	ICE,         # 2 — Frost Stone → slows nearby enemies, ice shard attack
	ELECTRIC,    # 3 — Spark Stone → chain-zaps nearby enemies on attack
	VOID,        # 4 — Void Stone → absorbs enemy projectiles, void bolt attack
	NATURE,      # 5 — Leaf Stone → regenerates Zorp's HP, vine lash attack
}

const PET_PATH_NAMES: Array[String] = [
	"Prismatic", "Fire", "Ice", "Electric", "Void", "Nature",
]

# Evolution stones — rare collectible-type items that force a specific path.
# These reuse the CollectibleType enum but use the high end of the ID space
# so they don't collide with existing materials. See CollectibleType below.
# Drop chances and loot tables are in LootDrops / Wildlife / TreasureChest.

# Path-specific stage config overrides. Index by [path][stage]. Any key
# missing here falls back to the base PET_STAGE_CONFIG value, so each path
# only needs to specify what it changes. This keeps the data compact and
# makes it easy to add new paths later.
#
# Per-path abilities (active at Adolescent+ unless noted):
#   FIRE      — "Ember Aura": melee attackers take 4 fire damage (DoT 2s, 3s cd);
#                Adolescent+ attack fires a small fireball projectile (14 dmg).
#   ICE       — "Frost Aura": enemies within 6m are slowed to 0.6× speed;
#                Adolescent+ attack fires an ice shard that slows the target 1.5s.
#   ELECTRIC  — "Static Field": each attack chains 4 dmg to up to 2 nearby enemies;
#                Adolescent+ attack deals +2 dmg per chain target.
#   VOID      — "Void Veil": 12% chance to absorb incoming enemy projectiles;
#                Adolescent+ attack fires a void bolt that pierces 1 enemy.
#   NATURE    — "Bloom": regenerates Zorp's HP by 1.0/sec when within 10m;
#                Adolescent+ attack is a vine lash (range 5m, 10 dmg).
const PET_PATH_CONFIG: Array = [
	# 0: PRISMATIC — no overrides, uses base config
	[{}, {}, {}],
	# 1: FIRE
	[
		{
			"color": Color(1.0, 0.45, 0.15),         # Warm orange
			"emission": Color(1.0, 0.3, 0.05),
			"ability": "ember_aura",
			"ability_label": "Ember Aura",
		},
		{
			"color": Color(1.0, 0.35, 0.1),
			"emission": Color(0.9, 0.2, 0.0),
			"attack_damage": 10,
			"attack_range": 5.0,
			"ability": "ember_aura",
			"ability_label": "Ember Aura + Fireball",
		},
		{
			"color": Color(1.0, 0.25, 0.05),
			"emission": Color(0.85, 0.1, 0.0),
			"attack_damage": 18,
			"attack_range": 7.0,
			"shield_reduction": 0.10,  # Fire favors offense over defense
			"ability": "ember_aura",
			"ability_label": "Ember Aura + Fireball + Blast",
		},
	],
	# 2: ICE
	[
		{
			"color": Color(0.55, 0.85, 1.0),         # Pale ice blue
			"emission": Color(0.3, 0.6, 1.0),
			"ability": "frost_aura",
			"ability_label": "Frost Aura",
		},
		{
			"color": Color(0.4, 0.75, 1.0),
			"emission": Color(0.2, 0.5, 0.95),
			"attack_damage": 7,
			"attack_range": 5.0,
			"ability": "frost_aura",
			"ability_label": "Frost Aura + Ice Shard",
		},
		{
			"color": Color(0.3, 0.7, 1.0),
			"emission": Color(0.15, 0.45, 0.9),
			"attack_damage": 13,
			"attack_range": 7.0,
			"shield_reduction": 0.20,  # Ice favors defense
			"ability": "frost_aura",
			"ability_label": "Frost Aura + Ice Shard + Blizzard",
		},
	],
	# 3: ELECTRIC
	[
		{
			"color": Color(1.0, 0.95, 0.3),         # Bright yellow
			"emission": Color(1.0, 0.85, 0.1),
			"ability": "static_field",
			"ability_label": "Static Field",
		},
		{
			"color": Color(1.0, 0.9, 0.2),
			"emission": Color(0.95, 0.75, 0.05),
			"attack_damage": 9,
			"attack_range": 5.0,
			"attack_cooldown": 1.0,  # Faster attacks
			"ability": "static_field",
			"ability_label": "Static Field + Chain Zap",
		},
		{
			"color": Color(1.0, 0.85, 0.1),
			"emission": Color(0.9, 0.65, 0.0),
			"attack_damage": 16,
			"attack_range": 7.0,
			"attack_cooldown": 0.8,
			"shield_reduction": 0.12,
			"ability": "static_field",
			"ability_label": "Static Field + Chain Zap + Overload",
		},
	],
	# 4: VOID
	[
		{
			"color": Color(0.4, 0.15, 0.55),        # Deep purple
			"emission": Color(0.25, 0.05, 0.4),
			"ability": "void_veil",
			"ability_label": "Void Veil",
		},
		{
			"color": Color(0.3, 0.1, 0.45),
			"emission": Color(0.2, 0.05, 0.35),
			"attack_damage": 12,
			"attack_range": 6.0,
			"ability": "void_veil",
			"ability_label": "Void Veil + Void Bolt",
		},
		{
			"color": Color(0.2, 0.05, 0.35),
			"emission": Color(0.15, 0.0, 0.3),
			"attack_damage": 20,
			"attack_range": 8.0,
			"shield_reduction": 0.18,
			"ability": "void_veil",
			"ability_label": "Void Veil + Void Bolt + Pierce",
		},
	],
	# 5: NATURE
	[
		{
			"color": Color(0.35, 0.85, 0.4),        # Leaf green
			"emission": Color(0.2, 0.6, 0.25),
			"ability": "bloom",
			"ability_label": "Bloom",
		},
		{
			"color": Color(0.25, 0.75, 0.3),
			"emission": Color(0.15, 0.5, 0.2),
			"attack_damage": 8,
			"attack_range": 5.0,
			"ability": "bloom",
			"ability_label": "Bloom + Vine Lash",
		},
		{
			"color": Color(0.2, 0.65, 0.25),
			"emission": Color(0.1, 0.45, 0.15),
			"attack_damage": 14,
			"attack_range": 6.0,
			"shield_reduction": 0.22,  # Nature favors defense and regen
			"ability": "bloom",
			"ability_label": "Bloom + Vine Lash + Regrowth",
		},
	],
]

# Tuning constants for path abilities
const PET_FIRE_AURA_DAMAGE: int = 4            # Damage to melee attackers
const PET_FIRE_AURA_DOT_DURATION: float = 2.0  # Burn DoT duration
const PET_FIRE_AURA_COOLDOWN: float = 3.0      # Per-attacker cooldown
const PET_FIRE_AURA_RANGE: float = 2.5         # Melee contact range
const PET_FIREBALL_DAMAGE: int = 14            # Adolescent+ ranged attack
const PET_FIREBALL_SPEED: float = 18.0
const PET_FIREBALL_LIFETIME: float = 2.0

const PET_ICE_AURA_RANGE: float = 6.0          # Slow aura radius
const PET_ICE_AURA_SLOW_MULT: float = 0.6      # Enemy speed multiplier
const PET_ICE_SHARD_SLOW_DURATION: float = 1.5 # Slow on hit

const PET_ELECTRIC_CHAIN_COUNT: int = 2        # Extra targets per attack
const PET_ELECTRIC_CHAIN_DAMAGE: int = 4       # Per-chain damage
const PET_ELECTRIC_CHAIN_RANGE: float = 5.0    # Max chain jump distance

const PET_VOID_VEIL_ABSORB_CHANCE: float = 0.12 # 12% projectile absorb
const PET_VOID_BOLT_PIERCE: int = 1             # Enemies a void bolt pierces

const PET_NATURE_REGEN_PER_SEC: float = 1.0    # HP/sec to Zorp
const PET_NATURE_REGEN_RANGE: float = 10.0     # Max distance for regen
const PET_NATURE_VINE_RANGE: float = 5.0       # Melee vine lash range

# Evolution stone drop chance — adds a small chance for any enemy kill to drop
# a path stone. Bosses always drop one stone (random path).
const PET_STONE_DROP_CHANCE: float = 0.015      # 1.5% normal enemy
const PET_STONE_BOSS_DROP_CHANCE: float = 1.0   # 100% boss
const PET_STONE_DROP_BIOME_BONUS: Dictionary = {
	# Bonus weight added to the drop roll when the kill happens in these biomes
	# (matches the path's thematic biome).
	GameConstants.Biome.LAVA: 0.02,           # Fire stone
	GameConstants.Biome.SNOW: 0.02,           # Ice stone
	GameConstants.Biome.ALIEN: 0.02,          # Electric stone
	GameConstants.Biome.VOLCANO_CORE: 0.03,   # Fire stone (high bonus)
	GameConstants.Biome.CRYSTAL_CAVERNS: 0.02, # Ice stone
	GameConstants.Biome.UNDERGROUND: 0.02,    # Void stone
	GameConstants.Biome.FOREST: 0.02,         # Nature stone
	GameConstants.Biome.MUSHROOM: 0.02,       # Nature stone
	GameConstants.Biome.DEEP_OCEAN: 0.02,     # Ice stone
}

# Stone item names for collectible spawn and inventory display
const PET_STONE_NAMES: Array[String] = [
	"", "Ember Stone", "Frost Stone", "Spark Stone", "Void Stone", "Leaf Stone",
]
const PET_STONE_COLORS: Array[Color] = [
	Color(0.5, 0.7, 1.0), # unused (prismatic has no stone)
	Color(1.0, 0.4, 0.1), # Fire — orange
	Color(0.4, 0.75, 1.0), # Ice — ice blue
	Color(1.0, 0.9, 0.2), # Electric — yellow
	Color(0.3, 0.1, 0.45), # Void — purple
	Color(0.3, 0.8, 0.35), # Nature — green
]

# Pet emote definitions — short visual reactions to game events.
# Each emote is a brief expression shown above the pet's head as a Label3D
# plus a small visual flourish (color flash, particle puff, scale pop).
enum PetEmote {
	NONE,       # 0
	HAPPY,      # 1 — pickup / level up / evolution
	SCARED,     # 2 — player took damage / low HP
	ANGRY,      # 3 — enemy nearby / pet under attack
	CURIOUS,    # 4 — new biome entered / new NPC seen
	SLEEPY,     # 5 — idle for a long time
	LOVE,       # 6 — player healed / pet evolved
	HUNGRY,     # 7 — low evolution progress for a while
}
const PET_EMOTE_TEXTS: Array[String] = [
	"", ":D", "D:", ">:(", "?", "zZz", "<3", ":o",
]
const PET_EMOTE_COLORS: Array[Color] = [
	Color(1, 1, 1, 0),
	Color(1.0, 0.95, 0.3),   # Happy — yellow
	Color(0.6, 0.7, 1.0),    # Scared — pale blue
	Color(1.0, 0.4, 0.3),    # Angry — red
	Color(0.7, 0.9, 1.0),    # Curious — light cyan
	Color(0.7, 0.7, 0.8),    # Sleepy — grey
	Color(1.0, 0.5, 0.8),    # Love — pink
	Color(1.0, 0.7, 0.3),    # Hungry — orange
]
const PET_EMOTE_DURATION: float = 1.6          # How long an emote stays visible
const PET_EMOTE_COOLDOWN: float = 3.0          # Min time between emotes
const PET_EMOTE_SCALE_POP: float = 1.4        # Pop-in scale

# ─── Phase 16: Weapon Mod Crafting ────────────────────────────────────────────

# Weapon mod IDs (0 = NONE / default laser)
enum WeaponMod {
	NONE,                # 0 — default laser, no mod
	HOMING_LASER,        # 1 — Meteor Shard + Quantum Fuzz
	REFLECTIVE_SHIELD,   # 2 — Shield Crystal + Fireball Scroll
	CHAIN_LIGHTNING,     # 3 — Nebula Dust + Star Fruit
	SPREAD_SHOT,         # 4 — Fireball Scroll + Quantum Fuzz
	PIERCING_BEAM,       # 5 — Meteor Shard + Star Fruit
	BOUNCING_BOLT,       # 6 — Quantum Fuzz + Space Gloop
	FREEZE_RAY,          # 7 — Regen Crystal + Star Fruit
	ACID_TRAIL,          # 8 — Magnet Core + Toxic Extract
	MEGA_BLAST,          # 9 — Meteor Shard + Quantum Fuzz + Nebula Dust (3-item mega)
	SPLITTER_LASER,      # 10 — Star Fruit + Shield Crystal
	VAMPIRE_BEAM,        # 11 — Health Fragment + Meteor Shard (uses health frag as material)
	GRAVITY_WELL_LASER,  # 12 — Magnet Core + Nebula Dust
	RICOCHET_PULSE,      # 13 — Shield Crystal + Quantum Fuzz
	PLASMA_NOVA,         # 14 — Fireball Scroll + Nebula Dust
	SNIPER_BEAM,         # 15 — Meteor Shard + Shield Crystal
	SHRAPNEL_BURST,      # 16 — Toxic Extract + Fireball Scroll
	BLAZE_TRAIL,         # 17 — Fireball Scroll + Meteor Shard
	TESLA_COIL,          # 18 — Regen Crystal + Quantum Fuzz
	VOID_RAY,            # 19 — Nebula Dust + Toxic Extract
	QUANTUM_OVERDRIVE,   # 20 — Meteor Shard + Quantum Fuzz + Star Fruit (3-item mega)
	# ── Enhancement: New weapon mods ──
	BLACK_HOLE_BEAM,     # 21 — Magnet Core + Meteor Shard — creates a black hole that sucks enemies in
	PHOTON_BEAM,         # 22 — Regen Crystal + Shield Crystal — rapid-fire piercing beam
	SPECTRAL_BEAM,       # 23 — Quantum Fuzz + Toxic Extract — phases through walls, ignores enemy shields
	MAGNET_MINE,         # 24 — Magnet Core + Fireball Scroll — homing mine that attaches then detonates
	# ── Phase 24: New weapon mods ──
	BLACK_HOLE_LAUNCHER, # 25 — Magnet Core + Nebula Dust + Meteor Shard — portable singularity launcher
	TIME_FREEZE_RAY,     # 26 — Regen Crystal + Quantum Fuzz + Star Fruit — freezes enemies in time
	SHRINK_BEAM,         # 27 — Toxic Extract + Shield Crystal — shrinks enemies, making them slow & weak
	METEOR_STRIKE,       # 28 — Meteor Shard + Fireball Scroll + Nebula Dust — calls down a meteor at cursor
	LIGHTNING_STORM,     # 29 — Regen Crystal + Magnet Core + Quantum Fuzz — chain lightning storm
	POISON_NOVA,         # 30 — Nebula Dust + Space Gloop + Toxic Extract — expanding ring of poison, DoT to all hit
	# ── Phase 24: Deployable weapon mods (triggered via deploy_ability key) ──
	SHIELD_BUBBLE,       # 31 — Shield Crystal + Regen Crystal — encases player in a bubble that absorbs damage & reflects projectiles
	TURRET_DEPLOY,       # 32 — Magnet Core + Shield Crystal + Fireball Scroll — stationary turret that auto-fires at nearest enemy
	GRAVITY_FLIP_FIELD,  # 33 — Magnet Core + Nebula Dust + Quantum Fuzz — area where gravity reverses, enemies fall up
	VOID_RIFT_CUTTER,    # 34 — Nebula Dust + Meteor Shard + Toxic Extract — opens a dimensional rift that damages enemies passing through
}

const WEAPON_MOD_NAMES: Array[String] = [
	"Standard Laser",
	"Homing Laser",
	"Reflective Shield",
	"Chain Lightning",
	"Spread Shot",
	"Piercing Beam",
	"Bouncing Bolt",
	"Freeze Ray",
	"Acid Trail",
	"Mega Blast",
	"Splitter Laser",
	"Vampire Beam",
	"Gravity Well Laser",
	"Ricochet Pulse",
	"Plasma Nova",
	"Sniper Beam",
	"Shrapnel Burst",
	"Blaze Trail",
	"Tesla Coil",
	"Void Ray",
	"Quantum Overdrive",
	# Enhancement: New weapon mods
	"Black Hole Beam",
	"Photon Beam",
	"Spectral Beam",
	"Magnet Mine",
	# Phase 24: New weapon mods
	"Black Hole Launcher",
	"Time Freeze Ray",
	"Shrink Beam",
	"Meteor Strike",
	"Lightning Storm",
	"Poison Nova",
	# Phase 24: Deployable weapon mods
	"Shield Bubble",
	"Turret Deploy",
	"Gravity Flip Field",
	"Void Rift Cutter",
]

const WEAPON_MOD_DESCRIPTIONS: Array[String] = [
	"Zorp's default tentacle laser. Reliable and effective.",
	"Homing bolts that track the nearest enemy.",
	"Shields that reflect enemy projectiles back at them.",
	"Lightning chains between nearby enemies on hit.",
	"Three bolts spread in a fan pattern.",
	"Pierces through multiple enemies in a line.",
	"Bounces off walls and enemies up to 3 times.",
	"Freezes enemies, slowing them for 2 seconds.",
	"Leaves a damaging acid pool on impact.",
	"Massive explosion on impact — the big one.",
	"Splits into two on hit, hitting more enemies.",
	"Drains HP from enemies and heals Zorp.",
	"Creates a gravity well pulling enemies in.",
	"Ricochets between nearby enemies on hit.",
	"Explodes in a plasma nova on impact.",
	"Long-range high-damage single bolt.",
	"Explodes into shrapnel fragments on hit.",
	"Sets enemies on fire, burning over time.",
	"Shocks nearby enemies with electric arcs.",
	"Slows enemies and drains their energy.",
	"Devastating triple-bolt with homing + chain.",
	# Enhancement: New weapon mods
	"Creates a singularity that sucks enemies in, then collapses for damage.",
	"Rapid-fire piercing photon bolts that pass through enemies.",
	"Phases through walls and terrain — never blocked. Ignores enemy intangibility.",
	"Homing mine that attaches to an enemy, then detonates for massive AoE damage.",
	# Phase 24: New weapon mods
	"Launches a portable singularity that travels forward, pulling enemies in, then collapses for massive AoE damage.",
	"Freezes enemies in time for 3 seconds — they can't move, attack, or take damage from other sources.",
	"Shrinks enemies for 5 seconds — they become tiny, slow, and deal reduced damage.",
	"Calls down a meteor from the sky at the cursor location, dealing massive AoE damage on impact.",
	"Chain lightning storm — bolts arc between all nearby enemies, dealing damage to each.",
	"Expanding ring of poison that damages all enemies it touches, with lingering DoT.",
	# Phase 24: Deployable weapon mods
	"Encases Zorp in a protective bubble that absorbs damage and reflects enemy projectiles back at them.",
	"Deploys a stationary turret at your location that auto-fires at the nearest enemy for 15 seconds.",
	"Creates a gravity-flip field where enemies fall upward, then take fall damage when the field ends.",
	"Opens a dimensional rift that damages all enemies passing through it, persisting for several seconds.",
]

# Colors for each weapon mod (laser color)
const WEAPON_MOD_COLORS: Array[Color] = [
	Color(0.2, 1.0, 0.8),   # Standard: cyan
	Color(1.0, 0.5, 0.1),   # Homing: orange
	Color(0.3, 0.6, 1.0),   # Reflective: sky blue
	Color(0.6, 0.8, 1.0),   # Chain Lightning: pale blue
	Color(1.0, 0.4, 0.2),   # Spread: red-orange
	Color(0.8, 0.2, 1.0),   # Piercing: purple
	Color(0.9, 0.9, 0.3),   # Bouncing: yellow
	Color(0.3, 0.9, 1.0),   # Freeze: ice blue
	Color(0.4, 0.8, 0.2),   # Acid: toxic green
	Color(1.0, 0.3, 0.3),   # Mega Blast: bright red
	Color(0.6, 1.0, 0.4),   # Splitter: lime
	Color(0.9, 0.2, 0.4),   # Vampire: crimson
	Color(0.5, 0.3, 0.9),   # Gravity Well: deep purple
	Color(0.3, 0.7, 1.0),   # Ricochet: azure
	Color(1.0, 0.6, 0.9),   # Plasma Nova: pink
	Color(0.2, 0.4, 1.0),   # Sniper: deep blue
	Color(0.7, 0.5, 0.2),   # Shrapnel: brown-orange
	Color(1.0, 0.5, 0.3),   # Blaze: fire orange
	Color(0.5, 0.9, 1.0),   # Tesla: electric blue
	Color(0.3, 0.1, 0.5),   # Void: dark purple
	Color(1.0, 0.8, 0.2),   # Quantum Overdrive: gold
	# Enhancement: New weapon mods
	Color(0.1, 0.0, 0.2),   # Black Hole: near-black with purple tint
	Color(1.0, 1.0, 0.8),   # Photon: warm white-gold
	Color(0.4, 0.2, 0.6, 0.7), # Spectral: translucent violet ghost
	Color(0.9, 0.5, 0.1),   # Magnet Mine: orange-red explosive
	# Phase 24: New weapon mods
	Color(0.05, 0.0, 0.15),  # Black Hole Launcher: deep void purple-black
	Color(0.6, 0.85, 1.0),   # Time Freeze Ray: crystalline ice-cyan
	Color(0.4, 0.9, 0.3),    # Shrink Beam: lime green (compress)
	Color(1.0, 0.4, 0.1),    # Meteor Strike: fiery orange-red
	Color(0.7, 0.85, 1.0),   # Lightning Storm: electric pale blue
	Color(0.5, 0.9, 0.2),    # Poison Nova: toxic green
	# Phase 24: Deployable weapon mods
	Color(0.3, 0.7, 1.0),    # Shield Bubble: sky blue (protective)
	Color(0.7, 0.85, 0.3),   # Turret Deploy: military green
	Color(0.6, 0.4, 1.0),    # Gravity Flip Field: anti-gravity purple
	Color(0.3, 0.1, 0.5),    # Void Rift Cutter: dark void purple
]

# Damage multiplier per weapon mod
const WEAPON_MOD_DAMAGE_MULT: Array[float] = [
	1.0,   # Standard
	0.8,   # Homing (lower damage, tracking compensates)
	0.6,   # Reflective Shield (defensive utility)
	0.7,   # Chain Lightning
	0.6,   # Spread Shot (3 bolts, so each is weaker)
	1.2,   # Piercing Beam
	0.7,   # Bouncing Bolt
	0.5,   # Freeze Ray (utility — slow, not damage)
	0.6,   # Acid Trail
	2.5,   # Mega Blast (big damage)
	0.8,   # Splitter
	0.9,   # Vampire
	0.7,   # Gravity Well
	0.8,   # Ricochet
	1.3,   # Plasma Nova
	2.0,   # Sniper Beam
	1.1,   # Shrapnel
	0.8,   # Blaze Trail
	0.9,   # Tesla Coil
	0.7,   # Void Ray
	1.5,   # Quantum Overdrive
	# Enhancement: New weapon mods
	1.0,   # Black Hole Beam (damage from the collapse, not the bolt)
	0.5,   # Photon Beam (rapid fire, each bolt is weak but fires 2x as fast)
	0.9,   # Spectral Beam (phasing is the utility, damage is decent)
	1.6,   # Magnet Mine (big single-hit AoE detonation)
	# Phase 24: New weapon mods
	1.4,   # Black Hole Launcher (the collapse is the damage)
	0.6,   # Time Freeze Ray (utility — freeze, not damage)
	0.7,   # Shrink Beam (utility — debuff, not damage)
	2.8,   # Meteor Strike (massive single-hit AoE)
	1.2,   # Lightning Storm (chains to many enemies)
	1.3,   # Poison Nova (AoE + DoT)
	# Phase 24: Deployable weapon mods (these are utility/deployables, damage is from the deployable not the bolt)
	0.5,   # Shield Bubble (defensive utility — no projectile, bubble absorbs damage)
	0.4,   # Turret Deploy (the turret does the damage, not the trigger bolt)
	0.3,   # Gravity Flip Field (utility — the fall damage is the threat)
	0.5,   # Void Rift Cutter (the rift does the damage, not the bolt)
]

# Fire rate multiplier (lower = faster)
const WEAPON_MOD_FIRE_RATE_MULT: Array[float] = [
	1.0,   # Standard
	1.0,   # Homing
	1.5,   # Reflective (slower)
	1.2,   # Chain
	1.3,   # Spread
	1.5,   # Piercing (slower, more powerful)
	1.0,   # Bouncing
	1.2,   # Freeze
	1.0,   # Acid
	2.5,   # Mega Blast (much slower)
	1.1,   # Splitter
	1.0,   # Vampire
	1.5,   # Gravity
	1.1,   # Ricochet
	1.8,   # Plasma Nova
	2.0,   # Sniper (slow, powerful)
	1.3,   # Shrapnel
	1.0,   # Blaze
	1.2,   # Tesla
	1.2,   # Void
	2.0,   # Quantum Overdrive
	# Enhancement: New weapon mods
	2.0,   # Black Hole Beam (slow, powerful singularity)
	0.5,   # Photon Beam (very rapid fire — 2x as fast as standard)
	1.3,   # Spectral Beam (slower, deliberate shots)
	1.8,   # Magnet Mine (slow deploy — big payoff)
	# Phase 24: New weapon mods
	2.4,   # Black Hole Launcher (very slow — heavy singularity)
	1.8,   # Time Freeze Ray (slow, deliberate)
	1.4,   # Shrink Beam (moderate)
	3.0,   # Meteor Strike (very slow — calling down a meteor)
	2.2,   # Lightning Storm (slow charge-up)
	1.8,   # Poison Nova (slow — expanding ring)
	# Phase 24: Deployable weapon mods (deployables have their own cooldowns, fire rate is the trigger cooldown)
	3.0,   # Shield Bubble (very slow — one bubble at a time, long cooldown)
	3.5,   # Turret Deploy (very slow — one turret at a time)
	3.2,   # Gravity Flip Field (slow — field duration is long)
	3.0,   # Void Rift Cutter (slow — rift persists)
]

# Projectile speed multiplier
const WEAPON_MOD_SPEED_MULT: Array[float] = [
	1.0,   # Standard
	0.8,   # Homing (slower to allow turning)
	1.0,   # Reflective
	1.0,   # Chain
	0.9,   # Spread
	1.5,   # Piercing (fast)
	0.9,   # Bouncing
	0.8,   # Freeze
	0.9,   # Acid
	0.7,   # Mega Blast (slow, heavy)
	1.0,   # Splitter
	1.0,   # Vampire
	0.8,   # Gravity Well
	0.9,   # Ricochet
	0.8,   # Plasma Nova
	2.0,   # Sniper (very fast)
	0.9,   # Shrapnel
	0.9,   # Blaze
	1.0,   # Tesla
	0.9,   # Void
	1.2,   # Quantum Overdrive
	# Enhancement: New weapon mods
	0.6,   # Black Hole Beam (slow bolt — it's heavy, collapsing into a singularity)
	2.0,   # Photon Beam (very fast light-speed bolts)
	1.1,   # Spectral Beam (moderate — phasing through everything)
	0.7,   # Magnet Mine (slow — it's a drifting mine, then homes in)
	# Phase 24: New weapon mods
	0.5,   # Black Hole Launcher (slow — heavy singularity travels forward)
	1.0,   # Time Freeze Ray (moderate)
	1.2,   # Shrink Beam (moderate-fast)
	0.4,   # Meteor Strike (slow — the bolt is the meteor strike marker)
	1.0,   # Lightning Storm (moderate)
	0.8,   # Poison Nova (slow-ish — expanding ring)
	# Phase 24: Deployable weapon mods (these don't fire a traditional bolt; speed is for the trigger marker)
	1.0,   # Shield Bubble (no projectile — bubble appears instantly)
	1.0,   # Turret Deploy (no projectile — turret appears at player location)
	1.0,   # Gravity Flip Field (no projectile — field appears at player location)
	1.0,   # Void Rift Cutter (no projectile — rift appears at player location)
]

# Crafting recipes: maps a sorted key string "typeA,typeB[,typeC]" → WeaponMod enum value
# Two-item recipes combine two different materials. Three-item recipes (mega) need all three.
const CRAFTING_RECIPES: Dictionary = {
	# Two-item recipes (19 of them)
	"METEOR_SHARD,QUANTUM_FUZZ": WeaponMod.HOMING_LASER,
	"FIREBALL_SCROLL,SHIELD_CRYSTAL": WeaponMod.REFLECTIVE_SHIELD,
	"NEBULA_DUST,STAR_FRUIT": WeaponMod.CHAIN_LIGHTNING,
	"FIREBALL_SCROLL,QUANTUM_FUZZ": WeaponMod.SPREAD_SHOT,
	"METEOR_SHARD,STAR_FRUIT": WeaponMod.PIERCING_BEAM,
	"QUANTUM_FUZZ,SPACE_GLOOP": WeaponMod.BOUNCING_BOLT,
	"REGEN_CRYSTAL,STAR_FRUIT": WeaponMod.FREEZE_RAY,
	"MAGNET_CORE,TOXIC_EXTRACT": WeaponMod.ACID_TRAIL,
	"SHIELD_CRYSTAL,STAR_FRUIT": WeaponMod.SPLITTER_LASER,
	"HEALTH_FRAGMENT,METEOR_SHARD": WeaponMod.VAMPIRE_BEAM,
	"MAGNET_CORE,NEBULA_DUST": WeaponMod.GRAVITY_WELL_LASER,
	"QUANTUM_FUZZ,SHIELD_CRYSTAL": WeaponMod.RICOCHET_PULSE,
	"FIREBALL_SCROLL,NEBULA_DUST": WeaponMod.PLASMA_NOVA,
	"METEOR_SHARD,SHIELD_CRYSTAL": WeaponMod.SNIPER_BEAM,
	"FIREBALL_SCROLL,TOXIC_EXTRACT": WeaponMod.SHRAPNEL_BURST,
	"FIREBALL_SCROLL,METEOR_SHARD": WeaponMod.BLAZE_TRAIL,
	"REGEN_CRYSTAL,QUANTUM_FUZZ": WeaponMod.TESLA_COIL,  # electric + quantum
	"NEBULA_DUST,TOXIC_EXTRACT": WeaponMod.VOID_RAY,
	# Three-item mega recipes
	"METEOR_SHARD,NEBULA_DUST,QUANTUM_FUZZ": WeaponMod.MEGA_BLAST,
	"METEOR_SHARD,QUANTUM_FUZZ,STAR_FRUIT": WeaponMod.QUANTUM_OVERDRIVE,
	# Enhancement: New weapon mod recipes
	"MAGNET_CORE,METEOR_SHARD": WeaponMod.BLACK_HOLE_BEAM,
	"REGEN_CRYSTAL,SHIELD_CRYSTAL": WeaponMod.PHOTON_BEAM,
	"QUANTUM_FUZZ,TOXIC_EXTRACT": WeaponMod.SPECTRAL_BEAM,
	"FIREBALL_SCROLL,MAGNET_CORE": WeaponMod.MAGNET_MINE,
	# Phase 24: New weapon mod recipes (3-item mega recipes)
	"MAGNET_CORE,METEOR_SHARD,NEBULA_DUST": WeaponMod.BLACK_HOLE_LAUNCHER,
	"QUANTUM_FUZZ,REGEN_CRYSTAL,STAR_FRUIT": WeaponMod.TIME_FREEZE_RAY,
	"SHIELD_CRYSTAL,TOXIC_EXTRACT": WeaponMod.SHRINK_BEAM,
	"FIREBALL_SCROLL,METEOR_SHARD,NEBULA_DUST": WeaponMod.METEOR_STRIKE,
	"MAGNET_CORE,QUANTUM_FUZZ,REGEN_CRYSTAL": WeaponMod.LIGHTNING_STORM,
	# Poison Nova uses a 3-item recipe to avoid colliding with Void Ray's key
	"NEBULA_DUST,SPACE_GLOOP,TOXIC_EXTRACT": WeaponMod.POISON_NOVA,
	# Phase 24: Deployable weapon mods
	"REGEN_CRYSTAL,SHIELD_CRYSTAL,SPACE_GLOOP": WeaponMod.SHIELD_BUBBLE,
	"FIREBALL_SCROLL,MAGNET_CORE,SHIELD_CRYSTAL": WeaponMod.TURRET_DEPLOY,
	"MAGNET_CORE,NEBULA_DUST,QUANTUM_FUZZ": WeaponMod.GRAVITY_FLIP_FIELD,
	"METEOR_SHARD,NEBULA_DUST,TOXIC_EXTRACT": WeaponMod.VOID_RIFT_CUTTER,
}

# Crafting material type names for recipe key lookup
const COLLECTIBLE_TYPE_NAMES: Dictionary = {
	CollectibleType.STAR_FRUIT: "STAR_FRUIT",
	CollectibleType.METEOR_SHARD: "METEOR_SHARD",
	CollectibleType.QUANTUM_FUZZ: "QUANTUM_FUZZ",
	CollectibleType.NEBULA_DUST: "NEBULA_DUST",
	CollectibleType.SPACE_GLOOP: "SPACE_GLOOP",
	CollectibleType.HEALTH_FRAGMENT: "HEALTH_FRAGMENT",
	CollectibleType.SHIELD_CRYSTAL: "SHIELD_CRYSTAL",
	CollectibleType.FIREBALL_SCROLL: "FIREBALL_SCROLL",
	CollectibleType.REGEN_CRYSTAL: "REGEN_CRYSTAL",
	CollectibleType.MAGNET_CORE: "MAGNET_CORE",
	CollectibleType.TOXIC_EXTRACT: "TOXIC_EXTRACT",
}

# Pet aura particle counts per stage
const PET_AURA_PARTICLE_COUNTS: Array[int] = [0, 8, 20]  # Baby: none, Adolescent: few, Adult: many

# ─── Phase 17: Dynamic Weather ────────────────────────────────────────────────
enum Weather {
	CLEAR,         # Normal conditions
	ACID_RAIN,     # Damages player and enemies; reduced under shelter
	SOLAR_FLARE,   # Boosts fire rate (energy regen), orange light pulse
	FOG,           # Reduces enemy detection range (stealth)
	THUNDERSTORM,  # Random lightning strikes (AoE damage zones)
	SNOW_STORM,    # Slows movement, icy physics (slide on surfaces)
	# ── Enhancement: New weather types ──
	METEOR_SHOWER, # Random meteor strikes (telegraphed AoE, larger than lightning)
	AURORA,        # Colorful sky lights, boosts XP gain by 50%
	SANDSTORM,     # Reduced visibility, damages player, boosts enemy speed
	# ── Phase 28: Weather Expansion ──
	BLOOD_MOON,    # All enemies stronger/faster, 3x loot & XP — high risk, high reward
	ECLIPSE,       # Darkness falls, shadow enemies spawn, light sources critical
	POLLEN_STORM,  # Heals everything slowly, peaceful period for exploration
	MAGNETIC_STORM, # Disables minimap/radar, random EMP pulses disable dashing
	GRAVITY_ANOMALY, # Random gravity shifts every 10s, affects vertical movement
	DIMENSIONAL_STORM, # Rifts open randomly, dimension shifts every 15s
}

# Weather state duration ranges (seconds): [min, max]
const WEATHER_DURATION_MIN: float = 35.0
const WEATHER_DURATION_MAX: float = 70.0
const WEATHER_TRANSITION_DURATION: float = 4.0  # Fade-in / fade-out time

# Damage / effect tuning
const ACID_RAIN_DAMAGE_PER_TICK: int = 2        # Per second applied to exposed entities
const ACID_RAIN_TICK_INTERVAL: float = 1.0      # How often damage ticks
const ACID_RAIN_SHELTER_REDUCTION: float = 0.75  # 75% damage reduction under shelter (y < overhang)
const SOLAR_FLARE_FIRE_RATE_MULT: float = 1.5   # 50% faster fire rate
const SOLAR_FLARE_LIGHT_ENERGY: float = 2.5     # OmniLight energy for orange glow
const FOG_DETECT_RANGE_MULT: float = 0.5        # Enemy detection range multiplied by this
const FOG_DENSITY_MULT: float = 3.0             # WorldEnvironment fog density multiplier
const THUNDER_LIGHTNING_INTERVAL_MIN: float = 5.0  # Min seconds between strikes
const THUNDER_LIGHTNING_INTERVAL_MAX: float = 12.0 # Max seconds between strikes
const THUNDER_LIGHTNING_DAMAGE: int = 45          # AoE damage at strike center
const THUNDER_LIGHTNING_RADIUS: float = 6.0        # AoE radius
const THUNDER_LIGHTNING_WARN_TIME: float = 1.2     # Telegraph (glowing ground patch) before strike
const SNOW_STORM_SPEED_MULT: float = 0.7           # Player/enemy movement speed multiplier
const SNOW_STORM_FRICTION_MULT: float = 0.4        # Lower friction = slidey surfaces

# ── Enhancement: Meteor Shower weather ──
const METEOR_SHOWER_INTERVAL_MIN: float = 8.0      # Min seconds between meteor strikes
const METEOR_SHOWER_INTERVAL_MAX: float = 16.0     # Max seconds between meteor strikes
const METEOR_DAMAGE: int = 60                       # AoE damage at impact center
const METEOR_RADIUS: float = 8.0                    # AoE radius (larger than lightning)
const METEOR_WARN_TIME: float = 2.0                 # Telegraph time (longer than lightning — meteors are visible falling)

# ── Enhancement: Aurora weather ──
const AURORA_XP_MULT: float = 1.5                   # 50% XP boost during aurora
const AURORA_LIGHT_ENERGY: float = 1.5              # Ambient aurora light energy

# ── Enhancement: Sandstorm weather ──
# Sandstorms whip up in desert biomes, scouring everything in sight. Visibility
# drops (fog density spikes), the player takes periodic sand-scour damage, and
# enemies gain a speed boost (the storm energizes them). Encourages sheltering.
const SANDSTORM_SPEED_MULT: float = 1.25             # Enemies 25% faster in sandstorm
const SANDSTORM_PLAYER_SPEED_MULT: float = 0.85      # Player slowed 15% (fighting wind)
const SANDSTORM_DAMAGE_PER_TICK: int = 2             # Per-second scour damage
const SANDSTORM_TICK_INTERVAL: float = 1.0           # How often damage ticks
const SANDSTORM_FOG_DENSITY_MULT: float = 4.0        # Visibility reduction
const SANDSTORM_SHELTER_REDUCTION: float = 0.80      # 80% damage reduction under shelter

# ── Phase 28: Weather Expansion — new weather tuning constants ──
# Blood Moon — all enemies empowered, but loot & XP are tripled. High risk, high reward.
const BLOOD_MOON_ENEMY_HP_MULT: float = 1.4           # +40% enemy HP
const BLOOD_MOON_ENEMY_DAMAGE_MULT: float = 1.3       # +30% enemy damage
const BLOOD_MOON_ENEMY_SPEED_MULT: float = 1.2        # +20% enemy speed
const BLOOD_MOON_LOOT_MULT: float = 3.0               # 3x crafting-material drop chance
const BLOOD_MOON_XP_MULT: float = 3.0                 # 3x XP gain
const BLOOD_MOON_LIGHT_ENERGY: float = 1.8            # Red ambient moonlight intensity
const BLOOD_MOON_FOG_DENSITY_MULT: float = 1.6       # Slight red haze

# Eclipse — darkness falls; shadow enemies spawn; light sources become critical.
const ECLIPSE_AMBIENT_DARKEN: float = 0.18            # Ambient light energy during eclipse (very dark)
const ECLIPSE_FOG_DENSITY_MULT: float = 2.5           # Heavy darkness fog
const ECLIPSE_SPAWN_BONUS_WEIGHT: float = 2.0         # Extra spawn weight for shadow enemies
const ECLIPSE_LIGHT_RADIUS_BOOST: float = 1.5         # Player light sources reach 1.5x farther
const ECLIPSE_PLAYER_LIGHT_BONUS: float = 0.8         # Extra light energy the player's pet/tools emit

# Pollen Storm — heals everything slowly; peaceful period good for exploration.
const POLLEN_STORM_HEAL_PER_TICK: int = 1             # HP per tick (player & enemies)
const POLLEN_STORM_TICK_INTERVAL: float = 1.5         # Heal every 1.5s
const POLLEN_STORM_XP_MULT: float = 1.2               # Gentle 20% XP boost (exploration reward)
const POLLEN_STORM_LIGHT_ENERGY: float = 1.2          # Soft warm light

# Magnetic Storm — disables minimap/radar; random EMP pulses disable dashing.
const MAGNETIC_STORM_EMP_INTERVAL_MIN: float = 8.0   # Min seconds between EMP pulses
const MAGNETIC_STORM_EMP_INTERVAL_MAX: float = 16.0   # Max seconds between EMP pulses
const MAGNETIC_STORM_EMP_DISABLE_DURATION: float = 2.5  # Dash disabled duration after EMP
const MAGNETIC_STORM_FOG_DENSITY_MULT: float = 1.4    # Slight visual haze

# Gravity Anomaly — random gravity shifts every 10s, affects vertical movement.
const GRAVITY_ANOMALY_SHIFT_INTERVAL: float = 10.0   # Seconds between gravity shifts
const GRAVITY_ANOMALY_SHIFT_DURATION: float = 3.0    # How long each shift lasts
const GRAVITY_ANOMALY_UPWARD_FORCE: float = 14.0     # m/s upward force during upward shift
const GRAVITY_ANOMALY_DOWNWARD_FORCE: float = 22.0   # m/s downward force during downward shift
const GRAVITY_ANOMALY_LIGHT_ENERGY: float = 1.4     # Subtle violet ambient pulse

# Dimensional Storm — rifts open randomly; dimension shifts every 15s.
const DIMENSIONAL_STORM_RIFT_INTERVAL_MIN: float = 8.0   # Min seconds between rift spawns
const DIMENSIONAL_STORM_RIFT_INTERVAL_MAX: float = 14.0  # Max seconds between rift spawns
const DIMENSIONAL_STORM_SHIFT_INTERVAL: float = 15.0  # Seconds between forced dimension shifts
const DIMENSIONAL_STORM_FOG_DENSITY_MULT: float = 2.0  # Reality-thinning haze

# Weather combo system — when a second weather type can overlap with the primary.
# Combo bonus multipliers apply when two compatible weathers are active simultaneously.
const WEATHER_COMBO_CHANCE: float = 0.18              # 18% chance a weather also activates a combo layer
const WEATHER_COMBO_MAX_OVERLAP: int = 1              # At most one combo weather at a time
# Combo pairs — each entry lists weathers that can co-occur with the key weather.
const WEATHER_COMBO_PAIRS: Dictionary = {
	Weather.THUNDERSTORM: [Weather.AURORA],            # Thunderstorm + Aurora = stormy sky lights
	Weather.SNOW_STORM: [Weather.AURORA],              # Snow + Aurora = polar lights
	Weather.FOG: [Weather.POLLEN_STORM],               # Fog + Pollen = misty bloom
	Weather.SANDSTORM: [Weather.MAGNETIC_STORM],       # Sandstorm + Magnetic = charged dust
	Weather.BLOOD_MOON: [Weather.ECLIPSE],             # Blood Moon + Eclipse = total darkness
	Weather.METEOR_SHOWER: [Weather.GRAVITY_ANOMALY],  # Meteors + Gravity = chaotic skies
	Weather.DIMENSIONAL_STORM: [Weather.BLOOD_MOON],   # Dimensional + Blood Moon = nightmare rifts
}
# Combo XP/loot bonuses (compounding on top of each weather's own bonus).
const WEATHER_COMBO_XP_BONUS: float = 0.25            # +25% XP when a combo is active
const WEATHER_COMBO_LOOT_BONUS: float = 0.25          # +25% loot chance when a combo is active

# Weather → biome affinity (weather more likely in thematic biomes)
# Each weather type maps to a list of biomes where it has a higher chance of starting.
const WEATHER_BIOME_AFFINITY: Dictionary = {
	Weather.ACID_RAIN: [GameConstants.Biome.TOXIC_BOG, GameConstants.Biome.SWAMP, GameConstants.Biome.DEEP_OCEAN],
	Weather.SOLAR_FLARE: [GameConstants.Biome.LAVA, GameConstants.Biome.DESERT, GameConstants.Biome.VOLCANO_CORE],
	Weather.FOG: [GameConstants.Biome.WATER, GameConstants.Biome.SWAMP, GameConstants.Biome.FOREST, GameConstants.Biome.UNDERGROUND, GameConstants.Biome.CRYSTAL_CAVERNS],
	Weather.THUNDERSTORM: [GameConstants.Biome.WATER, GameConstants.Biome.GRASS, GameConstants.Biome.FLOATING_ISLANDS, GameConstants.Biome.SKY_CITADEL, GameConstants.Biome.DEEP_OCEAN],
	Weather.SNOW_STORM: [GameConstants.Biome.SNOW, GameConstants.Biome.CRYSTAL, GameConstants.Biome.SKY_CITADEL],
	# Enhancement: New weather biome affinities
	Weather.METEOR_SHOWER: [GameConstants.Biome.LAVA, GameConstants.Biome.DESERT, GameConstants.Biome.ALIEN, GameConstants.Biome.VOLCANO_CORE],
	Weather.AURORA: [GameConstants.Biome.SNOW, GameConstants.Biome.CRYSTAL, GameConstants.Biome.FLOATING_ISLANDS],
	Weather.SANDSTORM: [GameConstants.Biome.DESERT, GameConstants.Biome.LAVA, GameConstants.Biome.ALIEN],
	# ── Phase 28: Weather Expansion biome affinities ──
	Weather.BLOOD_MOON: [GameConstants.Biome.ALIEN, GameConstants.Biome.VOLCANO_CORE, GameConstants.Biome.ANCIENT_RUINS],
	Weather.ECLIPSE: [GameConstants.Biome.UNDERGROUND, GameConstants.Biome.ANCIENT_RUINS, GameConstants.Biome.ALIEN, GameConstants.Biome.DIGITAL_GRID],
	Weather.POLLEN_STORM: [GameConstants.Biome.FOREST, GameConstants.Biome.MUSHROOM, GameConstants.Biome.SWAMP, GameConstants.Biome.GRASS],
	Weather.MAGNETIC_STORM: [GameConstants.Biome.DIGITAL_GRID, GameConstants.Biome.ALIEN, GameConstants.Biome.CRYSTAL_CAVERNS],
	Weather.GRAVITY_ANOMALY: [GameConstants.Biome.SKY_CITADEL, GameConstants.Biome.FLOATING_ISLANDS, GameConstants.Biome.VOLCANO_CORE],
	Weather.DIMENSIONAL_STORM: [GameConstants.Biome.ALIEN, GameConstants.Biome.DIGITAL_GRID, GameConstants.Biome.ANCIENT_RUINS],
}

# Weather enemy spawn overrides — weather types that bias spawning toward specific enemies.
# Keyed by Weather enum → array of EnemyType values that get a bonus weight during that weather.
const WEATHER_SPAWN_BONUS: Dictionary = {
	Weather.THUNDERSTORM: [GameConstants.EnemyType.WISP],   # Storms spawn Void Wisps
	Weather.FOG: [GameConstants.EnemyType.WISP, GameConstants.EnemyType.SENTINEL],
	Weather.ACID_RAIN: [GameConstants.EnemyType.SPITTER, GameConstants.EnemyType.BOMBER],
	Weather.SOLAR_FLARE: [GameConstants.EnemyType.GRAVITON],
	Weather.SNOW_STORM: [GameConstants.EnemyType.SENTINEL],
	# Enhancement: New weather spawn bonuses
	Weather.METEOR_SHOWER: [GameConstants.EnemyType.BOMBER, GameConstants.EnemyType.CRYSTAL_GUARDIAN],
	Weather.AURORA: [GameConstants.EnemyType.SWARM_MITE, GameConstants.EnemyType.WISP],
	Weather.SANDSTORM: [GameConstants.EnemyType.PHASE_SHIFTER, GameConstants.EnemyType.GRAVITON],
	# ── Phase 28: Weather Expansion spawn bonuses ──
	Weather.BLOOD_MOON: [GameConstants.EnemyType.DRAKE, GameConstants.EnemyType.ECHO_KNIGHT, GameConstants.EnemyType.GRAVITY_ELEMENTAL],
	Weather.ECLIPSE: [GameConstants.EnemyType.WISP, GameConstants.EnemyType.PLASMA_STALKER, GameConstants.EnemyType.MIRROR_MIMIC],
	Weather.POLLEN_STORM: [],  # Peaceful — no spawn bonus
	Weather.MAGNETIC_STORM: [GameConstants.EnemyType.GRAVITON, GameConstants.EnemyType.TIME_WARDEN],
	Weather.GRAVITY_ANOMALY: [GameConstants.EnemyType.GRAVITY_ELEMENTAL, GameConstants.EnemyType.GRAVITON],
	Weather.DIMENSIONAL_STORM: [GameConstants.EnemyType.WISP, GameConstants.EnemyType.PHASE_SHIFTER, GameConstants.EnemyType.MIRROR_MIMIC],
}

# Weather display info (name, icon emoji, color for UI)
const WEATHER_INFO: Dictionary = {
	Weather.CLEAR: {"name": "Clear", "icon": "☀", "color": Color(1.0, 0.9, 0.5)},
	Weather.ACID_RAIN: {"name": "Acid Rain", "icon": "☣", "color": Color(0.5, 1.0, 0.2)},
	Weather.SOLAR_FLARE: {"name": "Solar Flare", "icon": "🔥", "color": Color(1.0, 0.5, 0.1)},
	Weather.FOG: {"name": "Fog", "icon": "🌫", "color": Color(0.7, 0.75, 0.8)},
	Weather.THUNDERSTORM: {"name": "Thunderstorm", "icon": "⚡", "color": Color(0.5, 0.6, 1.0)},
	Weather.SNOW_STORM: {"name": "Snow Storm", "icon": "❄", "color": Color(0.8, 0.9, 1.0)},
	# Enhancement: New weather types
	Weather.METEOR_SHOWER: {"name": "Meteor Shower", "icon": "☄", "color": Color(1.0, 0.4, 0.2)},
	Weather.AURORA: {"name": "Aurora", "icon": "🌌", "color": Color(0.3, 1.0, 0.6)},
	Weather.SANDSTORM: {"name": "Sandstorm", "icon": "🌪", "color": Color(0.9, 0.75, 0.3)},
	# ── Phase 28: Weather Expansion ──
	Weather.BLOOD_MOON: {"name": "Blood Moon", "icon": "🌑", "color": Color(0.85, 0.1, 0.1)},
	Weather.ECLIPSE: {"name": "Eclipse", "icon": "🌑", "color": Color(0.25, 0.2, 0.35)},
	Weather.POLLEN_STORM: {"name": "Pollen Storm", "icon": "🌼", "color": Color(1.0, 0.9, 0.4)},
	Weather.MAGNETIC_STORM: {"name": "Magnetic Storm", "icon": "🧲", "color": Color(0.4, 0.6, 1.0)},
	Weather.GRAVITY_ANOMALY: {"name": "Gravity Anomaly", "icon": "🌀", "color": Color(0.7, 0.4, 1.0)},
	Weather.DIMENSIONAL_STORM: {"name": "Dimensional Storm", "icon": "💫", "color": Color(0.8, 0.3, 1.0)},
}

# ─── Phase 18: Boss Arenas ───────────────────────────────────────────────────
# Arena types — each morphs the terrain into an enclosed battlefield
enum ArenaType {
	LAVA_ARENA,        # Drake — lava geysers, shrinking floor
	CRYSTAL_ARENA,     # Serpent King — falling stalactites, crystal walls
	VOID_ARENA,        # Graviton Prime — gravity shifts, void shockwaves
}

# Arena geometry
const ARENA_RADIUS: float = 28.0              # Initial radius of the arena floor
const ARENA_WALL_HEIGHT: float = 12.0         # Height of arena walls
const ARENA_WALL_THICKNESS: float = 2.0       # Wall collider thickness
const ARENA_RISE_DURATION: float = 2.0        # Time for walls to rise from ground
const ARENA_SHRINK_INTERVAL: float = 15.0     # Seconds between shrink stages
const ARENA_SHRINK_AMOUNT: float = 4.0        # Meters of radius lost per shrink stage
const ARENA_MIN_RADIUS: float = 10.0          # Minimum radius (walls stop shrinking)
const ARENA_TRANSITION_PARTICLES: int = 200   # Particle count for arena rise effect

# Hazard timing
const ARENA_HAZARD_INTERVAL_MIN: float = 4.0  # Min seconds between hazard spawns
const ARENA_HAZARD_INTERVAL_MAX: float = 8.0  # Max seconds between hazard spawns
const ARENA_HAZARD_TELEGRAPH_TIME: float = 1.5  # Warning before hazard activates
const ARENA_HAZARD_DAMAGE: int = 30           # Base damage from arena hazards
const ARENA_HAZARD_RADIUS: float = 4.0        # AoE radius for hazard damage
const ARENA_HAZARD_LIFETIME: float = 3.0      # How long a hazard remains active

# Hazard-specific
const LAVA_GEYSER_HEIGHT: float = 10.0        # Height of lava geyser column
const LAVA_GEYSER_KNOCKBACK: float = 20.0     # Knockback force from geyser eruption
const FALLING_CRYSTAL_HEIGHT: float = 25.0    # Drop height for falling crystals
const FALLING_CRYSTAL_DAMAGE: int = 45        # Damage from falling crystal
const VOID_SHOCKWAVE_SPEED: float = 12.0      # Expansion speed of void shockwave
const VOID_SHOCKWAVE_MAX_RADIUS: float = 15.0 # Max radius of void shockwave

# Arena exit portal
const ARENA_EXIT_PORTAL_LIFETIME: float = 30.0  # Seconds exit portal stays after boss dies

# Arena colors (0-1 normalized)
const ARENA_LAVA_COLOR: Color = Color(1.0, 0.3, 0.05)
const ARENA_LAVA_GLOW: Color = Color(1.0, 0.5, 0.1)
const ARENA_CRYSTAL_COLOR: Color = Color(0.4, 0.7, 1.0)
const ARENA_CRYSTAL_GLOW: Color = Color(0.3, 0.8, 1.0)
const ARENA_VOID_COLOR: Color = Color(0.5, 0.0, 0.8)
const ARENA_VOID_GLOW: Color = Color(0.6, 0.1, 1.0)
const ARENA_WALL_COLOR: Color = Color(0.3, 0.3, 0.35)

# Boss arena trigger: time between boss spawns if none active (seconds)
const BOSS_ARENA_SPAWN_INTERVAL: float = 120.0  # 2 minutes between boss spawns
const BOSS_ARENA_SPAWN_MIN_SCORE: int = 500     # Minimum score before first boss arena

# ─── Phase 19: Local Co-op ────────────────────────────────────────────────────
# Player 2 "Zerp" drops in for shared-screen co-op with Zorp.
# Uses arrow keys + numpad for movement/shooting, Enter for dash, RShift for pulse.

# P2 character visual
const P2_NAME: String = "Zerp"
const P2_BASE_COLOR: Color = Color(0.85, 0.3, 0.9)  # Magenta-purple (distinct from Zorp green)
const P2_EMISSION_COLOR: Color = Color(0.5, 0.1, 0.6)
const P2_SPAWN_OFFSET: Vector3 = Vector3(3.0, 0.5, 0.0)  # Spawn next to P1

# P2 stat tweaks (slightly different feel from Zorp)
const P2_SPEED_MULT: float = 1.0       # Same base speed
const P2_DASH_MULT: float = 1.05       # Slightly longer dash
const P2_DAMAGE_MULT: float = 0.9      # Slightly less damage (utility character)
const P2_HP: int = 100                 # Less HP than Zorp (120) — glass cannon lean

# Co-op enemy scaling
const COOP_ENEMY_HP_MULT: float = 2.0       # 2x health
const COOP_ENEMY_DAMAGE_MULT: float = 1.5   # 1.5x damage
const COOP_ENEMY_SPAWN_RATE_MULT: float = 1.3  # 30% faster spawns
const COOP_MAX_ENEMIES_BONUS: int = 15      # Extra spawn cap with 2 players

# Shared combo system
const COOP_COMBO_SHARED: bool = true        # Both players contribute to same combo
const COOP_COMBO_WINDOW_BONUS: float = 1.0  # Extra seconds on combo timer in co-op
const COMBO_TIMEOUT: float = 3.0            # Base combo window duration (seconds)

# Revive system
const COOP_REVIVE_DURATION: float = 3.0       # Seconds to hold revive
const COOP_REVIVE_RANGE: float = 3.5          # Max distance to revive
const COOP_REVIVE_HP_RESTORE: int = 60        # HP on revive
const COOP_REVIVE_INVULN_DURATION: float = 2.0 # Invuln after revive
const COOP_DOWNED_SPEED: float = 0.0          # Downed player can't move
const COOP_DOWNED_TIMER_MAX: float = 30.0     # Bleed-out timer (auto-die after this)
const COOP_DOWNED_REVIVE_PROGRESS_TICK: float = 1.0 / 60.0 / COOP_REVIVE_DURATION  # Progress per physics tick at 60fps → COOP_REVIVE_DURATION seconds total

# Co-op mega pulse wave (both players Q within sync window)
const COOP_PULSE_SYNC_WINDOW: float = 1.0     # Seconds for both players to press Q
const COOP_PULSE_RADIUS_MULT: float = 1.8     # Mega wave radius multiplier
const COOP_PULSE_DAMAGE_MULT: float = 2.5     # Mega wave damage multiplier

# Co-op camera: dynamic zoom pulls back to frame both players
const COOP_CAMERA_MIN_DISTANCE: float = 22.0  # When players close together
const COOP_CAMERA_MAX_DISTANCE: float = 42.0  # When players far apart
const COOP_CAMERA_ZOOM_SMOOTHING: float = 2.5
const COOP_CAMERA_PLAYER_SPACING_THRESH: float = 15.0  # Distance at which max zoom kicks in

# Drop-in / drop-out
const COOP_DROP_IN_KEY: String = "p2_start"   # Input action name for P2 drop-in

# ─── Phase 23: New Enemy Types ────────────────────────────────────────────────

# ── Toxic Spore ──────────────────────────────────────────────────────────────
# On death, explodes into a lingering poison cloud that damages any entity
# (player or enemy) standing inside it. The cloud persists for several seconds,
# creating a temporary hazard zone. The spore itself is slow and weak in melee,
# but the player is incentivized to kill it at range so the cloud spawns far
# away. Enemies caught in the cloud take damage too — friendly-fire pressure.
const TOXIC_SPORE_HP: int = 40
const TOXIC_SPORE_SPEED: float = 2.8
const TOXIC_SPORE_DAMAGE: int = 10          # Melee damage (low — the cloud is the threat)
const TOXIC_SPORE_SCALE: float = 0.85
const TOXIC_SPORE_XP: int = 30
const TOXIC_SPORE_SCORE: int = 110
const TOXIC_SPORE_DETECT_RANGE: float = 28.0
const TOXIC_SPORE_ATTACK_RANGE: float = 1.6
const TOXIC_SPORE_ATTACK_COOLDOWN: float = 1.4
const TOXIC_SPORE_COLOR: Color = Color(0.35, 0.78, 0.20)  # Sickly green
# Poison cloud (spawned on death)
const TOXIC_SPORE_CLOUD_RADIUS: float = 4.5        # Damage radius
const TOXIC_SPORE_CLOUD_DURATION: float = 5.0      # Seconds the cloud persists
const TOXIC_SPORE_CLOUD_DAMAGE_PER_TICK: int = 6   # Damage per tick
const TOXIC_SPORE_CLOUD_TICK_INTERVAL: float = 0.7 # Seconds between damage ticks
const TOXIC_SPORE_CLOUD_COLOR: Color = Color(0.35, 0.78, 0.20, 0.35)  # Translucent green
const TOXIC_SPORE_CLOUD_ENEMY_DAMAGE_MULT: float = 0.5  # Enemies take half damage

# ── Swarm Queen ──────────────────────────────────────────────────────────────
# Continuously spawns Swarm Mites from her body. The mites stream out and rush
# the player. The Queen herself is slow and tanky — she must be killed to stop
# the spawn. High HP, slow speed, high reward. Mites spawn every few seconds in
# small batches (1-3). The Queen will not exceed the global enemy cap.
const SWARM_QUEEN_HP: int = 280
const SWARM_QUEEN_SPEED: float = 1.6
const SWARM_QUEEN_DAMAGE: int = 18
const SWARM_QUEEN_SCALE: float = 2.0
const SWARM_QUEEN_XP: int = 120
const SWARM_QUEEN_SCORE: int = 450
const SWARM_QUEEN_DETECT_RANGE: float = 32.0
const SWARM_QUEEN_ATTACK_RANGE: float = 2.2
const SWARM_QUEEN_ATTACK_COOLDOWN: float = 1.8
const SWARM_QUEEN_COLOR: Color = Color(0.55, 0.25, 0.55)  # Muted magenta
const SWARM_QUEEN_SPAWN_INTERVAL_MIN: float = 3.0  # Seconds between mite batches
const SWARM_QUEEN_SPAWN_INTERVAL_MAX: float = 5.0
const SWARM_QUEEN_SPAWN_BATCH_MIN: int = 1
const SWARM_QUEEN_SPAWN_BATCH_MAX: int = 3
const SWARM_QUEEN_SPAWN_RADIUS: float = 2.5  # Mites spawn around the queen
const SWARM_QUEEN_MAX_MITES_ALIVE: int = 12  # Hard cap on concurrent queen-spawned mites

# ── Crystal Wraith ───────────────────────────────────────────────────────────
# On death, shatters into 3-5 crystal shards that fly outward. Each shard then
# reforms into a mini-wraith (low HP, fast, low damage) that continues attacking
# the player. This creates a "hydra" feel — killing the wraith spawns more
# enemies, so the player must be ready to deal with the mini-wraiths. The wraith
# itself is medium-tier: moderate HP, fast, melee.
const CRYSTAL_WRAITH_HP: int = 90
const CRYSTAL_WRAITH_SPEED: float = 5.5
const CRYSTAL_WRAITH_DAMAGE: int = 16
const CRYSTAL_WRAITH_SCALE: float = 1.2
const CRYSTAL_WRAITH_XP: int = 55
const CRYSTAL_WRAITH_SCORE: int = 180
const CRYSTAL_WRAITH_DETECT_RANGE: float = 32.0
const CRYSTAL_WRAITH_ATTACK_RANGE: float = 1.8
const CRYSTAL_WRAITH_ATTACK_COOLDOWN: float = 1.2
const CRYSTAL_WRAITH_COLOR: Color = Color(0.45, 0.75, 1.0)  # Ice blue
const CRYSTAL_WRAITH_SHARD_COUNT_MIN: int = 3
const CRYSTAL_WRAITH_SHARD_COUNT_MAX: int = 5
const CRYSTAL_WRAITH_SHARD_SCATTER_SPEED: float = 8.0
const CRYSTAL_WRAITH_SHARD_REFORM_DELAY: float = 0.9  # Seconds before shard becomes mini-wraith
# Mini-wraith (spawned from shards)
const CRYSTAL_WRAITH_MINI_HP: int = 18
const CRYSTAL_WRAITH_MINI_SPEED: float = 7.0
const CRYSTAL_WRAITH_MINI_DAMAGE: int = 6
const CRYSTAL_WRAITH_MINI_SCALE: float = 0.4
const CRYSTAL_WRAITH_MINI_XP: int = 8
const CRYSTAL_WRAITH_MINI_SCORE: int = 30
const CRYSTAL_WRAITH_MINI_COLOR: Color = Color(0.6, 0.85, 1.0)

# ── Echo Knight ──────────────────────────────────────────────────────────────
# Creates 2 shadow copies of itself at fixed offsets. All three entities share
# the same movement and attack in sync — when the real knight attacks, all
# copies attack simultaneously in the same pattern. Copies are intangible
# (can't be damaged) and fade when the real knight dies. The player must
# identify the real knight (slightly brighter / has a subtle aura) and focus it
# down; the copies are a constant threat that can't be removed any other way.
const ECHO_KNIGHT_HP: int = 110
const ECHO_KNIGHT_SPEED: float = 4.0
const ECHO_KNIGHT_DAMAGE: int = 14
const ECHO_KNIGHT_SCALE: float = 1.1
const ECHO_KNIGHT_XP: int = 50
const ECHO_KNIGHT_SCORE: int = 160
const ECHO_KNIGHT_DETECT_RANGE: float = 30.0
const ECHO_KNIGHT_ATTACK_RANGE: float = 2.0
const ECHO_KNIGHT_ATTACK_COOLDOWN: float = 1.3
const ECHO_KNIGHT_COLOR: Color = Color(0.6, 0.6, 0.7)  # Pale grey-blue
const ECHO_KNIGHT_REAL_COLOR: Color = Color(0.85, 0.85, 1.0)  # Brighter — the real one
const ECHO_KNIGHT_COPY_COUNT: int = 2
const ECHO_KNIGHT_COPY_OFFSET: float = 3.0   # Meters from the real knight
const ECHO_KNIGHT_COPY_ALPHA: float = 0.45   # Translucent copies
const ECHO_KNIGHT_COPY_DAMAGE_MULT: float = 0.6  # Copies deal reduced damage
const COOP_DROP_OUT_HOLD_TIME: float = 2.0     # Hold drop-in key this long to drop out

# ── Plasma Stalker ───────────────────────────────────────────────────────────
# An ambusher that periodically turns nearly invisible. While cloaked the mesh
# is almost fully transparent — the only tell is a particle trail of plasma
# sparks that drift behind it. The player must spot the trail to track the
# stalker and burst it down during the brief visible window. Fast, low-HP,
# high-damage — a glass-cannon ambusher.
const PLASMA_STALKER_HP: int = 55
const PLASMA_STALKER_SPEED: float = 6.0
const PLASMA_STALKER_DAMAGE: int = 18
const PLASMA_STALKER_SCALE: float = 1.0
const PLASMA_STALKER_XP: int = 45
const PLASMA_STALKER_SCORE: int = 150
const PLASMA_STALKER_DETECT_RANGE: float = 34.0
const PLASMA_STALKER_ATTACK_RANGE: float = 1.8
const PLASMA_STALKER_ATTACK_COOLDOWN: float = 1.1
const PLASMA_STALKER_COLOR: Color = Color(1.0, 0.25, 0.55)   # Hot pink-magenta
const PLASMA_STALKER_CLOAK_COLOR: Color = Color(1.0, 0.25, 0.55, 0.06)  # Near-invisible
const PLASMA_STALKER_VISIBLE_DURATION: float = 2.5   # Seconds visible (vulnerable tell)
const PLASMA_STALKER_CLOAK_DURATION: float = 4.0     # Seconds cloaked
const PLASMA_STALKER_CLOAK_WARN_TIME: float = 0.35  # Shimmer before cloaking
const PLASMA_STALKER_CLOAK_BLINK_SPEED: float = 16.0 # Hz of blink during warn
const PLASMA_STALKER_TRAIL_INTERVAL: float = 0.05    # Seconds between trail sparks
const PLASMA_STALKER_TRAIL_SPARK_COUNT: int = 2     # Sparks per emission
const PLASMA_STALKER_SPEED_BOOST_CLOAK: float = 1.3 # Faster while cloaked (ambush)

# ── Time Warden ──────────────────────────────────────────────────────────────
# A temporal controller that projects a slowing field around itself. Players
# inside the field move and attack slower; the Warden itself moves faster.
# Periodically teleports behind the player for a surprise attack. Tanky and
# disruptive — the counter is to stay outside its AoE and burst it from range.
const TIME_WARDEN_HP: int = 140
const TIME_WARDEN_SPEED: float = 3.0
const TIME_WARDEN_DAMAGE: int = 16
const TIME_WARDEN_SCALE: float = 1.4
const TIME_WARDEN_XP: int = 70
const TIME_WARDEN_SCORE: int = 220
const TIME_WARDEN_DETECT_RANGE: float = 32.0
const TIME_WARDEN_ATTACK_RANGE: float = 2.0
const TIME_WARDEN_ATTACK_COOLDOWN: float = 1.6
const TIME_WARDEN_COLOR: Color = Color(0.35, 0.55, 1.0)    # Cool temporal blue
const TIME_WARDEN_FIELD_COLOR: Color = Color(0.35, 0.55, 1.0, 0.12)  # Translucent field
const TIME_WARDEN_FIELD_RADIUS: float = 7.0       # Slowing field radius
const TIME_WARDEN_PLAYER_SLOW_MULT: float = 0.55  # Player speed multiplier in field
const TIME_WARDEN_SELF_SPEED_MULT: float = 1.35    # Warden speed boost (always on)
const TIME_WARDEN_TELEPORT_INTERVAL: float = 6.0  # Seconds between teleports
const TIME_WARDEN_TELEPORT_DISTANCE: float = 4.0  # Behind player, this far
const TIME_WARDEN_TELEPORT_WARN_TIME: float = 0.5 # Blink telegraph before teleport
const TIME_WARDEN_TELEPORT_BLINK_SPEED: float = 14.0
const TIME_WARDEN_FIELD_TICK_INTERVAL: float = 0.3  # How often to re-check player in field

# ── Mirror Mimic ─────────────────────────────────────────────────────────────
# Copies the player's currently equipped weapon mod and fires it back at them.
# When the player has no mod equipped, it fires a standard projectile. The
# mimic reads WeaponModSystem.get_equipped_mod() and mirrors the mod's color
# and projectile behavior. Medium HP, medium speed, ranged — the counter is to
# equip a mod that's hard to dodge (or unequip to deny it a powerful mod).
const MIRROR_MIMIC_HP: int = 85
const MIRROR_MIMIC_SPEED: float = 3.4
const MIRROR_MIMIC_DAMAGE: int = 12
const MIRROR_MIMIC_SCALE: float = 1.2
const MIRROR_MIMIC_XP: int = 55
const MIRROR_MIMIC_SCORE: int = 180
const MIRROR_MIMIC_DETECT_RANGE: float = 30.0
const MIRROR_MIMIC_ATTACK_RANGE: float = 24.0      # Ranged — fires from distance
const MIRROR_MIMIC_ATTACK_COOLDOWN: float = 2.0
const MIRROR_MIMIC_COLOR: Color = Color(0.85, 0.85, 0.92)  # Mirror silver
const MIRROR_MIMIC_NONE_COLOR: Color = Color(0.7, 0.7, 0.75)  # No-mod fallback
const MIRROR_MIMIC_PROJECTILE_SPEED: float = 18.0
const MIRROR_MIMIC_PROJECTILE_LIFETIME: float = 3.5
const MIRROR_MIMIC_SPREAD_DEGREES: float = 6.0     # Slight inaccuracy
const MIRROR_MIMIC_MIMICRY_DAMAGE_MULT: float = 0.7  # Mimic's copy is weaker than original

# ── Phase 23: Void Leviathan (boss) ──────────────────────────────────────────
# A giant serpentine boss that "swims" through terrain (ignores collision with
# static world geometry for its body, though its head still collides with the
# player). Multi-stage fight:
#   Stage 1 (>66% HP): slow chase + void breath (cone of dark projectiles)
#   Stage 2 (33-66% HP): faster, summons Void Wisps, tail sweep attack
#   Stage 3 (<33% HP): enraged — very fast, vacuum pull (sucks player toward
#     the maw), rapid void breath volleys
# The leviathan has a segmented body like the Plasma Serpent but much larger,
# and the segments damage the player on contact (tail swipe). On death the
# body collapses segment-by-segment with cascading particle bursts.
const VOID_LEVIATHAN_HP: int = 600
const VOID_LEVIATHAN_SPEED: float = 2.8
const VOID_LEVIATHAN_DAMAGE: int = 30
const VOID_LEVIATHAN_SCALE: float = 3.0
const VOID_LEVIATHAN_XP: int = 400
const VOID_LEVIATHAN_SCORE: int = 2500
const VOID_LEVIATHAN_DETECT_RANGE: float = 45.0
const VOID_LEVIATHAN_ATTACK_RANGE: float = 3.5
const VOID_LEVIATHAN_ATTACK_COOLDOWN: float = 2.0
const VOID_LEVIATHAN_COLOR: Color = Color(0.15, 0.0, 0.35)  # Deep void purple
const VOID_LEVIATHAN_ENRAGE_COLOR: Color = Color(0.6, 0.0, 0.8)  # Bright void purple
const VOID_LEVIATHAN_SEGMENTS: int = 6
const VOID_LEVIATHAN_SEGMENT_SPACING: float = 2.8
const VOID_LEVIATHAN_STAGE2_THRESHOLD: float = 0.66   # HP fraction
const VOID_LEVIATHAN_STAGE3_THRESHOLD: float = 0.33   # HP fraction
const VOID_LEVIATHAN_ENRAGE_SPEED_MULT: float = 1.6
const VOID_LEVIATHAN_ENRAGE_DAMAGE_MULT: float = 1.3
const VOID_LEVIATHAN_BREATH_COOLDOWN: float = 4.5
const VOID_LEVIATHAN_BREATH_DAMAGE: int = 22
const VOID_LEVIATHAN_BREATH_BOLTS: int = 7
const VOID_LEVIATHAN_BREATH_CONE_DEGREES: float = 35.0
const VOID_LEVIATHAN_BREATH_PROJECTILE_SPEED: float = 22.0
const VOID_LEVIATHAN_TAIL_SWEEP_DAMAGE: int = 25
const VOID_LEVIATHAN_TAIL_SWEEP_RADIUS: float = 4.5
const VOID_LEVIATHAN_SUMMON_INTERVAL: float = 8.0  # Seconds between wisp summons (stage 2+)
const VOID_LEVIATHAN_SUMMON_COUNT: int = 2
const VOID_LEVIATHAN_VACUUM_COOLDOWN: float = 7.0  # Stage 3 vacuum pull
const VOID_LEVIATHAN_VACUUM_RADIUS: float = 20.0
const VOID_LEVIATHAN_VACUUM_FORCE: float = 14.0
const VOID_LEVIATHAN_VACUUM_DURATION: float = 2.0

# ── Phase 23: Ancient Sentinel (mega-boss) ───────────────────────────────────
# A colossal mega-boss with multiple attack phases and arena-wide hazards. The
# Sentinel is stationary (like the Starburst Sentinel) but much larger and with
# a rotating cycle of attacks:
#   Phase A (rotating beam): sweeps a death ray around the arena
#   Phase B (pillar barrage): summons falling crystal pillars across the arena
#   Phase C (shockwave nova): expanding ring waves that must be jumped/dodged
#   Phase D (enrage, <25% HP): all attacks at once, faster cycle
# Very high HP, very high reward. The fight is a multi-minute endurance battle
# that tests dodging, positioning, and sustained DPS.
const ANCIENT_SENTINEL_HP: int = 900
const ANCIENT_SENTINEL_SPEED: float = 0.0  # Stationary
const ANCIENT_SENTINEL_DAMAGE: int = 35
const ANCIENT_SENTINEL_SCALE: float = 3.5
const ANCIENT_SENTINEL_XP: int = 600
const ANCIENT_SENTINEL_SCORE: int = 4000
const ANCIENT_SENTINEL_DETECT_RANGE: float = 50.0
const ANCIENT_SENTINEL_ATTACK_RANGE: float = 50.0  # Arena-wide
const ANCIENT_SENTINEL_ATTACK_COOLDOWN: float = 1.0
const ANCIENT_SENTINEL_COLOR: Color = Color(0.8, 0.7, 0.3)  # Ancient gold-brown
const ANCIENT_SENTINEL_ENRAGE_COLOR: Color = Color(1.0, 0.3, 0.1)
const ANCIENT_SENTINEL_ENRAGE_HP_THRESHOLD: float = 0.25
const ANCIENT_SENTINEL_PHASE_DURATION: float = 5.0  # Seconds per attack phase
const ANCIENT_SENTINEL_BEAM_ROTATE_SPEED: float = 1.2  # rad/s for rotating beam
const ANCIENT_SENTINEL_BEAM_DAMAGE: int = 30           # Per second of exposure
const ANCIENT_SENTINEL_BEAM_LENGTH: float = 40.0
const ANCIENT_SENTINEL_BEAM_WARN_TIME: float = 1.2
const ANCIENT_SENTINEL_PILLAR_COUNT: int = 8            # Falling pillars per barrage
const ANCIENT_SENTINEL_PILLAR_DAMAGE: int = 40
const ANCIENT_SENTINEL_PILLAR_RADIUS: float = 3.5
const ANCIENT_SENTINEL_PILLAR_WARN_TIME: float = 1.0
const ANCIENT_SENTINEL_NOVA_COUNT: int = 3              # Sequential nova rings
const ANCIENT_SENTINEL_NOVA_DAMAGE: int = 35
const ANCIENT_SENTINEL_NOVA_EXPAND_SPEED: float = 14.0
const ANCIENT_SENTINEL_NOVA_MAX_RADIUS: float = 30.0
const ANCIENT_SENTINEL_NOVA_INTERVAL: float = 1.2  # Seconds between rings

# ── Phase 23: Gravity Elemental ─────────────────────────────────────────────
# An elite enemy that manipulates gravity around itself. Periodically creates a
# gravity field that repels the player outward and flings nearby loose objects
# (RigidBody3D fragments, collectibles) at the player as projectiles. Medium-high
# HP, moderate speed. The counter is to stay at range and burst it down before
# it can set up its gravity field. The repel field has a telegraph (charging
# visual) before activating, giving the player time to back away.
const GRAVITY_ELEMENTAL_HP: int = 160
const GRAVITY_ELEMENTAL_SPEED: float = 3.2
const GRAVITY_ELEMENTAL_DAMAGE: int = 20
const GRAVITY_ELEMENTAL_SCALE: float = 1.6
const GRAVITY_ELEMENTAL_XP: int = 80
const GRAVITY_ELEMENTAL_SCORE: int = 280
const GRAVITY_ELEMENTAL_DETECT_RANGE: float = 32.0
const GRAVITY_ELEMENTAL_ATTACK_RANGE: float = 2.2
const GRAVITY_ELEMENTAL_ATTACK_COOLDOWN: float = 1.5
const GRAVITY_ELEMENTAL_COLOR: Color = Color(0.3, 0.5, 0.9)  # Gravitic blue
const GRAVITY_ELEMENTAL_FIELD_COLOR: Color = Color(0.3, 0.5, 0.9, 0.18)
const GRAVITY_ELEMENTAL_FIELD_RADIUS: float = 9.0
const GRAVITY_ELEMENTAL_REPEL_FORCE: float = 22.0
const GRAVITY_ELEMENTAL_FIELD_DURATION: float = 1.5
const GRAVITY_ELEMENTAL_FIELD_COOLDOWN: float = 6.0
const GRAVITY_ELEMENTAL_FIELD_WARN_TIME: float = 0.8  # Telegraph before repel
const GRAVITY_ELEMENTAL_FIELD_TICK_INTERVAL: float = 0.1  # How often to apply repel force
const GRAVITY_ELEMENTAL_PROJECTILE_DAMAGE: int = 14
const GRAVITY_ELEMENTAL_PROJECTILE_SPEED: float = 16.0
const GRAVITY_ELEMENTAL_MAX_FLUNG_OBJECTS: int = 6  # Max objects to fling per field activation

# ── Phase 24: New Weapon Mod Tuning ──────────────────────────────────────────
# Black Hole Launcher — a portable singularity that travels forward then
# collapses. The bolt itself pulls enemies in as it flies (stronger than Black
# Hole Beam), then on impact (or max lifetime) it collapses for massive AoE.
const BLACK_HOLE_LAUNCHER_PULL_RADIUS: float = 14.0
const BLACK_HOLE_LAUNCHER_PULL_FORCE: float = 24.0
const BLACK_HOLE_LAUNCHER_COLLAPSE_RADIUS: float = 12.0
const BLACK_HOLE_LAUNCHER_COLLAPSE_MULT: float = 2.0  # × base damage on collapse
const BLACK_HOLE_LAUNCHER_LIFETIME: float = 1.8  # Auto-collapse after this

# Time Freeze Ray — freezes a single enemy in place for 3 seconds. While frozen
# the enemy can't move, attack, or take damage from other sources (it's locked
# outside time). The freeze is broken early if the player damages the frozen
# enemy with the Time Freeze Ray again (refresh) or another weapon (shatters
# the freeze for bonus damage). Single-target utility — great for locking down
# a dangerous elite while you deal with its friends.
const TIME_FREEZE_RAY_DURATION: float = 3.0
const TIME_FREEZE_RAY_SHATTER_BONUS_MULT: float = 1.5  # Bonus damage if a non-freeze hit breaks the freeze

# Shrink Beam — shrinks an enemy for 5 seconds. While shrunk the enemy moves at
# 0.4× speed, deals 0.5× damage, and has 0.6× HP (the lost HP is restored when
# the effect ends, capped at max). The shrink visual is a dramatic scale-down
# with a green aura. Multiple shrinks don't stack (refresh duration instead).
const SHRINK_BEAM_DURATION: float = 5.0
const SHRINK_BEAM_SPEED_MULT: float = 0.4
const SHRINK_BEAM_DAMAGE_MULT: float = 0.5
const SHRINK_BEAM_HP_MULT: float = 0.6
const SHRINK_BEAM_SCALE_MULT: float = 0.35

# Meteor Strike — calls down a meteor at the bolt's impact point. The bolt
# itself is just a marker (low damage); the meteor falls from the sky after a
# short delay, dealing massive AoE damage on impact. The meteor is visible
# during its fall (telegraph), and the impact creates a large explosion + crater
# glow + camera shake. Biome-agnostic — works anywhere.
const METEOR_STRIKE_FALL_HEIGHT: float = 50.0
const METEOR_STRIKE_FALL_TIME: float = 0.9  # Seconds from spawn to impact
const METEOR_STRIKE_RADIUS: float = 9.0
const METEOR_STRIKE_BOLT_DAMAGE: int = 10  # The marker bolt itself (small)
const METEOR_STRIKE_IMPACT_MULT: float = 3.5  # × base damage on impact

# Lightning Storm — on hit, chains lightning to ALL nearby enemies (up to a cap)
# with damage falloff per jump. The chain is visualized with electric arc
# particles between each hit enemy. Unlike Chain Lightning (3 targets), the
# storm hits up to 8 enemies but each jump does less damage.
const LIGHTNING_STORM_MAX_TARGETS: int = 8
const LIGHTNING_STORM_CHAIN_RANGE: float = 10.0
const LIGHTNING_STORM_FALLOFF_PER_JUMP: float = 0.12  # Each jump loses 12% damage

# Poison Nova — on impact, expands a ring of poison that damages all enemies it
# touches. Leaves a lingering poison cloud at the impact point for DoT. The ring
# expands faster than a shockwave but deals less instant damage — the DoT is the
# main threat. Great against groups.
const POISON_NOVA_RADIUS: float = 12.0
const POISON_NOVA_EXPAND_SPEED: float = 18.0
const POISON_NOVA_RING_DAMAGE: int = 20  # Instant damage from the ring
const POISON_NOVA_CLOUD_RADIUS: float = 5.0
const POISON_NOVA_CLOUD_DURATION: float = 4.0
const POISON_NOVA_CLOUD_DAMAGE_PER_TICK: int = 8

# ─── Phase 26: World Life — Lore Stones, Treasure Chests, Wildlife ────────────
# Lore Stones — scattered ancient relics that reveal fragments of game lore
# when the player approaches. Each stone has a piece of lore text. Collecting
# all stones grants a completion bonus. Lore stones persist (don't respawn) in
# the save file (future Phase 31 save/load), but for now they simply disappear
# after being read.
const LORE_STONE_SPAWN_CHANCE: float = 0.012       # Per-tile chance of a lore stone
const LORE_STONE_READ_RANGE: float = 4.5           # Player must be within this range
const LORE_STONE_XP_REWARD: int = 25                # XP for reading a lore stone
const LORE_STONE_TOTAL_COUNT_TARGET: int = 30      # Approximate target count across world
const LORE_STONE_COLOR: Color = Color(110.0 / 255.0, 90.0 / 255.0, 160.0 / 255.0)
const LORE_STONE_GLOW_COLOR: Color = Color(140.0 / 255.0, 120.0 / 255.0, 1.0)
const LORE_STONE_HEIGHT: float = 1.8                # Visual height of the stone pillar

# Lore fragments — revealed when a lore stone is read. Each entry is a short
# snippet of world-building text. Stones pick from this list sequentially so
# the player uncovers the story in a loose order.
const LORE_FRAGMENTS: Array[String] = [
	"Before the Void came, the Zorpions tended gardens of starlight.",
	"The Wiggling was discovered by Zix the Wanderer in the Age of Foam.",
	"Each biome was seeded by a different Tribe, long since dissolved.",
	"The Crystal Caverns hum a song older than the planet's core.",
	"Ancient Sentinels were guardians, not conquerors — until the corruption.",
	"The Dimensional Rifts opened when the Sky Citadel fell from orbit.",
	"Glip the Trader once crossed the Toxic Bog on a single raft of spores.",
	"Deep Ocean is not water. It is liquid memory, breathing slowly.",
	"The Volcano Core is the planet's last heartbeat, fading but defiant.",
	"Meteor Shards are tears of the sky, shed when the stars began to die.",
	"Quantum Fuzz grows where time has been wounded by the Time Wardens.",
	"Nebula Dust is the ash of a galaxy that never finished forming.",
	"The Swarm Queen was once a gardener, before the hive consumed her.",
	"Echo Knights repeat the last patrol they ever flew — forever.",
	"Gravity Elementals dream of falling upward, toward a sky they lost.",
	"Mirror Mimics were built to reflect heroes — but they learned to hate them.",
	"Plasma Stalkers learned invisibility from the Shadow Clones of the Void.",
	"The Companion Pet species was engineered to be loyal. It exceeded the spec.",
	"Blood Moon is not a moon. It is an eye, and it is watching.",
	"Aurora Borealis is the breath of something sleeping beneath the snow.",
	"The Digital Grid is a tomb for a civilization that uploaded itself.",
	"Ancient Ruins are not ruins. They are cages, and the doors are open.",
	"Every Monolith is a finger of the same buried hand.",
	"Healing Shrines grow where a Zorpion once wept for a fallen friend.",
	"The portals do not move you through space. They move space around you.",
	"Prestige is not power. It is remembering who you were before.",
	"The first Zorp landed here with nothing but a wiggle and a wish.",
	"Sandstorms carry the voices of every creature the desert has swallowed.",
	"Magnetic Storms are the planet trying to remember how to speak.",
	"The last lore stone is this one. The story continues in you.",
]

# Treasure Chests — hidden containers buried across the world. They're not
# visible from far away (semi-buried, low-profile), but emit a faint glimmer
# when the player is close. Opening one grants rare loot + XP. Some chests
# are "trapped" (spawn a small enemy or trigger a hazard) for risk/reward.
const TREASURE_CHEST_SPAWN_CHANCE: float = 0.008   # Per-tile chance
const TREASURE_CHEST_OPEN_RANGE: float = 3.5       # Player must be within this range
const TREASURE_CHEST_XP_REWARD: int = 60           # XP for opening
const TREASURE_CHEST_GLOW_RANGE: float = 12.0     # Distance at which glimmer appears
const TREASURE_CHEST_TRAP_CHANCE: float = 0.25    # 25% are trapped
const TREASURE_CHEST_COLOR: Color = Color(140.0 / 255.0, 100.0 / 255.0, 50.0 / 255.0)
const TREASURE_CHEST_GLOW_COLOR: Color = Color(1.0, 0.85, 0.3)
const TREASURE_CHEST_TRAP_DAMAGE: int = 25
const TREASURE_CHEST_LOOT_COUNT: int = 3           # Number of items per chest

# Wildlife — non-hostile creatures that roam the world. They flee from the
# player when approached. If caught (player touches them), they drop loot
# (XP orb + occasional crafting material) and a small score bonus. They do
# NOT fight back. They're a light exploration reward — hunting them is
# optional but worthwhile. Each wildlife type has a different color, speed,
# and preferred biome.
const WILDLIFE_SPAWN_CHANCE: float = 0.018         # Per-tile chance
const WILDLIFE_FLEE_SPEED: float = 9.0             # Speed when fleeing
const WILDLIFE_FLEE_RANGE: float = 14.0            # Distance at which they start fleeing
const WILDLIFE_WANDER_SPEED: float = 1.8           # Speed when wandering
const WILDLIFE_WANDER_RADIUS: float = 30.0         # Wander radius from home
const WILDLIFE_XP_REWARD: int = 15                  # XP for catching
const WILDLIFE_SCORE_REWARD: int = 30              # Score for catching
const WILDLIFE_MATERIAL_DROP_CHANCE: float = 0.30  # 30% chance to drop a crafting material
const WILDLIFE_CATCH_RANGE: float = 1.5            # Touch distance to catch

# Wildlife species — each species has a name, color, scale, and preferred
# biome list (biomes where they spawn). Wildlife of a species only spawns in
# its preferred biomes, creating biome-specific fauna.
const WILDLIFE_SPECIES: Array[Dictionary] = [
	{
		"name": "Glimmer Hopper",
		"color": Color(0.9, 0.8, 0.3),
		"scale": 0.5,
		"biomes": [Biome.GRASS, Biome.FOREST, Biome.MUSHROOM],
	},
	{
		"name": "Frost Mite",
		"color": Color(0.7, 0.9, 1.0),
		"scale": 0.4,
		"biomes": [Biome.SNOW, Biome.CRYSTAL, Biome.CRYSTAL_CAVERNS],
	},
	{
		"name": "Sand Skitter",
		"color": Color(0.95, 0.75, 0.4),
		"scale": 0.45,
		"biomes": [Biome.DESERT, Biome.ANCIENT_RUINS],
	},
	{
		"name": "Bog Hopper",
		"color": Color(0.5, 0.85, 0.4),
		"scale": 0.5,
		"biomes": [Biome.SWAMP, Biome.TOXIC_BOG],
	},
	{
		"name": "Void Mote",
		"color": Color(0.6, 0.3, 0.9),
		"scale": 0.35,
		"biomes": [Biome.ALIEN, Biome.UNDERGROUND, Biome.DIGITAL_GRID],
	},
	{
		"name": "Tidal Sprite",
		"color": Color(0.3, 0.7, 0.95),
		"scale": 0.4,
		"biomes": [Biome.WATER, Biome.DEEP_OCEAN],
	},
	{
		"name": "Ember Wisp",
		"color": Color(1.0, 0.5, 0.2),
		"scale": 0.4,
		"biomes": [Biome.LAVA, Biome.VOLCANO_CORE],
	},
	{
		"name": "Cloud Drifter",
		"color": Color(0.95, 0.95, 1.0),
		"scale": 0.55,
		"biomes": [Biome.FLOATING_ISLANDS, Biome.SKY_CITADEL],
	},
]
const POISON_NOVA_CLOUD_TICK_INTERVAL: float = 0.6

# ── Phase 24: Deployable Weapon Mod Tuning ───────────────────────────────────
# These mods are triggered by the deploy_ability input (V key) when equipped.
# They don't fire a traditional projectile — instead they spawn a deployable
# effect at/near the player. Each has its own duration and behavior.

# Shield Bubble — encases the player in a protective bubble. The bubble absorbs
# a fixed amount of incoming damage (a "shield HP" pool) before breaking. While
# active, enemy projectiles that touch the bubble are reflected back at the
# shooter with 50% increased speed. The bubble also grants 30% damage reduction
# on melee/contact damage that gets through. Lasts 8 seconds or until the shield
# HP is depleted. Only one bubble can be active at a time.
const SHIELD_BUBBLE_DURATION: float = 8.0
const SHIELD_BUBBLE_HP: int = 80
const SHIELD_BUBBLE_RADIUS: float = 1.8
const SHIELD_BUBBLE_DAMAGE_REDUCTION: float = 0.3
const SHIELD_BUBBLE_REFLECT_SPEED_MULT: float = 1.5
const SHIELD_BUBBLE_REFLECT_DAMAGE_MULT: float = 0.7

# Turret Deploy — spawns a stationary turret at the player's location. The turret
# auto-targets the nearest enemy within range and fires bolts at a steady rate.
# Lasts 15 seconds. The turret has its own HP (can be destroyed by enemies).
# Only one turret can be active at a time (deploying a new one removes the old).
const TURRET_DEPLOY_DURATION: float = 15.0
const TURRET_DEPLOY_RANGE: float = 25.0
const TURRET_DEPLOY_FIRE_RATE: float = 0.35  # Seconds between shots
const TURRET_DEPLOY_DAMAGE: int = 18
const TURRET_DEPLOY_HP: int = 60
const TURRET_DEPLOY_PROJECTILE_SPEED: float = 28.0
const TURRET_DEPLOY_ROTATE_SPEED: float = 4.0  # How fast it tracks targets (rad/s)

# Gravity Flip Field — creates a cylindrical field around the player. Enemies
# inside the field have their gravity reversed — they're launched upward, then
# fall back down when the field ends (taking fall damage on landing). The field
# persists for 4 seconds. Player is unaffected (Zorp has magnetic boots).
const GRAVITY_FLIP_FIELD_DURATION: float = 4.0
const GRAVITY_FLIP_FIELD_RADIUS: float = 8.0
const GRAVITY_FLIP_FIELD_HEIGHT: float = 15.0
const GRAVITY_FLIP_FIELD_UPWARD_FORCE: float = 18.0
const GRAVITY_FLIP_FIELD_FALL_DAMAGE: int = 30
const GRAVITY_FLIP_FIELD_TICK_INTERVAL: float = 0.2

# Void Rift Cutter — opens a dimensional rift at the player's location that
# persists for 6 seconds. The rift is a planar slice through space; any enemy
# that touches the rift takes damage (with a per-enemy cooldown so they don't
# get melted in one pass). The rift slowly rotates and emits void particles.
const VOID_RIFT_CUTTER_DURATION: float = 6.0
const VOID_RIFT_CUTTER_LENGTH: float = 8.0
const VOID_RIFT_CUTTER_WIDTH: float = 0.8
const VOID_RIFT_CUTTER_DAMAGE: int = 25
const VOID_RIFT_CUTTER_TICK_INTERVAL: float = 0.5  # Per-enemy damage cooldown
const VOID_RIFT_CUTTER_ROTATE_SPEED: float = 0.8  # rad/s

# ─── Phase 26: World Life — NPC Dialogue, Environmental Hazards, Interactive Objects ─

# NPC Dialogue System — talk to traders, villagers, ancient holograms.
# Each NPC has a set of dialogue lines organized into "topics". The player
# presses the interact key (T) when near a dialogue-capable NPC to advance
# through the lines. Dialogue is shown as a HUD panel. Some NPCs give
# missions or rewards through dialogue.
const DIALOGUE_INTERACT_RANGE: float = 4.5        # Max distance to talk to an NPC
const DIALOGUE_LINE_DISPLAY_TIME: float = 5.0    # Auto-advance time per line (0 = manual)
const DIALOGUE_XP_REWARD: int = 10                # Small XP for completing a dialogue
const DIALOGUE_TEXT_SPEED: float = 30.0           # Characters per second for typewriter effect
const DIALOGUE_PANEL_WIDTH: float = 600.0         # HUD panel width in pixels
const DIALOGUE_PANEL_HEIGHT: float = 160.0        # HUD panel height in pixels

# Dialogue-capable NPC archetypes. Each archetype has a name pool, color,
# and a set of dialogue topics. Topics are picked based on context (first
# meeting, repeat meeting, mission available, etc.).
const DIALOGUE_NPC_TYPES: Array[Dictionary] = [
	{
		"archetype": "villager",
		"name_pool": ["Blib", "Worp", "Tix", "Vreep", "Nemmo", "Quill"],
		"color": Color(0.7, 0.85, 0.5),
		"hat_color": Color(0.5, 0.7, 0.3),
		"scale": 0.9,
	},
	{
		"archetype": "elder",
		"name_pool": ["Ancient One", "The Keeper", "Old Zorp", "The Rememberer"],
		"color": Color(0.9, 0.8, 0.4),
		"hat_color": Color(0.6, 0.4, 0.2),
		"scale": 1.1,
	},
	{
		"archetype": "hologram",
		"name_pool": ["Ancient Hologram", "Echo of the Past", "The Last Voice"],
		"color": Color(0.4, 0.9, 1.0),
		"hat_color": Color(0.2, 0.6, 0.9),
		"scale": 1.0,
	},
]

# Dialogue line pools. NPCs pick from these based on archetype and context.
# Each entry is a single line shown in sequence. Topics are picked in order
# for the first meeting, then random on repeat.
const DIALOGUE_LINES: Dictionary = {
	"villager_intro": [
		"Oh! A visitor. We don't get many who wiggle quite like you.",
		"The gardens used to sing. Now they only hum. But we tend them still.",
		"If you see Glip, tell them I still have their spore-basket.",
		"Be careful out there. The Void doesn't sleep, and neither should you.",
	],
	"villager_repeat": [
		"Back again? The gardens missed you.",
		"Stay warm. The Snow biome is colder than it looks.",
		"If you find a Meteor Shard, don't sell it to the first trader you meet.",
	],
	"elder_intro": [
		"I remember when the sky was whole. You have the look of one who can mend it.",
		"The Zorpions were gardeners once. Then the Void came, and we became survivors.",
		"Seek the lore stones. They hold the memory we lost when the Rifts opened.",
		"When you face the Ancient Sentinel, remember: it was built to guard, not to destroy. The corruption changed it.",
		"Go now. The world wiggles when you move through it. That is a good sign.",
	],
	"elder_repeat": [
		"The world is still breathing. So are you. Good.",
		"Prestige is not power. It is remembering who you were before.",
		"The last lore stone holds no words. Only a mirror.",
	],
	"hologram_intro": [
		"...you... are not... a recording... you are... real...",
		"We uploaded ourselves to escape the Void. We did not escape. We only became... this.",
		"The Digital Grid is our tomb. Do not pity us. We chose this. We were wrong.",
		"If you can, sever the Grid from the core. Let us rest. Let us stop... looping.",
	],
	"hologram_repeat": [
		"...still... here... so are... we... the loop... continues...",
		"...the silence... between words... is where... we dream...",
	],
}

# Environmental Hazards — world-spawned hazards (not arena-bound). These are
# scattered across hostile biomes and add danger to exploration. Unlike
# arena hazards (which are tied to a boss fight), these are persistent world
# features that respawn on a timer.
const ENV_HAZARD_SPAWN_CHANCE: float = 0.012      # Per-tile chance in hostile biomes
const ENV_HAZARD_RESPAWN_TIME: float = 20.0       # Seconds before a hazard re-activates
const ENV_HAZARD_TELEGRAPH_TIME: float = 1.2      # Warning time before activation
const ENV_HAZARD_ACTIVE_TIME: float = 2.5         # Duration of the active danger phase
const ENV_HAZARD_COOLDOWN_TIME: float = 8.0       # Cooldown between cycles
const ENV_HAZARD_DAMAGE: int = 18                 # Damage per hit
const ENV_HAZARD_RADIUS: float = 3.5              # Damage radius
const ENV_HAZARD_KNOCKBACK: float = 12.0          # Knockback force

# Hazard types — each spawns in specific biomes.
#   LAVA_GEYSER:  erupts in LAVA / VOLCANO_CORE biomes
#   FALLING_ROCK: drops from above in UNDERGROUND / ANCIENT_RUINS / MOUNTAIN areas
#   TOXIC_VENT:   poisonous gas puff in TOXIC_BOG / SWAMP biomes
#   ICE_PATCH:    slippery surface in SNOW / CRYSTAL_CAVERNS biomes (no damage, slide effect)
const ENV_HAZARD_TYPES: Array[Dictionary] = [
	{
		"type": "lava_geyser",
		"biomes": [Biome.LAVA, Biome.VOLCANO_CORE],
		"color": Color(1.0, 0.4, 0.1),
		"glow_color": Color(1.0, 0.6, 0.2),
		"damage": 22,
	},
	{
		"type": "falling_rock",
		"biomes": [Biome.UNDERGROUND, Biome.ANCIENT_RUINS, Biome.CRYSTAL_CAVERNS],
		"color": Color(0.5, 0.45, 0.4),
		"glow_color": Color(0.7, 0.6, 0.5),
		"damage": 25,
	},
	{
		"type": "toxic_vent",
		"biomes": [Biome.TOXIC_BOG, Biome.SWAMP],
		"color": Color(0.4, 0.9, 0.2),
		"glow_color": Color(0.5, 1.0, 0.3),
		"damage": 12,
	},
	{
		"type": "ice_patch",
		"biomes": [Biome.SNOW, Biome.CRYSTAL_CAVERNS],
		"color": Color(0.7, 0.9, 1.0),
		"glow_color": Color(0.8, 0.95, 1.0),
		"damage": 0,  # No damage — causes sliding
	},
]

# Interactive Objects — switches, doors, breakable walls, hidden passages.
# These add light puzzle/exploration elements to the world.
#   SWITCH:     press interact to toggle; can open linked doors or reveal passages
#   DOOR:       opens/closes when a linked switch is toggled; blocks movement when closed
#   BREAKABLE_WALL: destroyed by weapons/dash; may hide a treasure chest behind it
#   HIDDEN_PASSAGE: invisible until a switch is activated or player is close; reveals loot
const INTERACTIVE_SPAWN_CHANCE: float = 0.006     # Per-tile chance
const INTERACTIVE_INTERACT_RANGE: float = 3.5     # Distance to activate a switch
const INTERACTIVE_BREAKABLE_HP: int = 30         # HP of breakable walls
const INTERACTIVE_BREAKABLE_DASH_DAMAGE: int = 15  # Dash damage to breakable walls
const INTERACTIVE_SWITCH_COOLDOWN: float = 0.5    # Cooldown between toggles
const INTERACTIVE_DOOR_OPEN_TIME: float = 1.0    # Animation time for door opening
const INTERACTIVE_HIDDEN_REVEAL_RANGE: float = 6.0  # Distance at which hidden passages reveal

# Interactive object types — each has a color and biome preference.
const INTERACTIVE_TYPES: Array[Dictionary] = [
	{
		"type": "switch",
		"color": Color(0.9, 0.8, 0.2),
		"glow_color": Color(1.0, 0.9, 0.3),
		"scale": 0.6,
	},
	{
		"type": "door",
		"color": Color(0.6, 0.5, 0.4),
		"glow_color": Color(0.8, 0.7, 0.5),
		"scale": 1.5,
	},
	{
		"type": "breakable_wall",
		"color": Color(0.5, 0.45, 0.4),
		"glow_color": Color(0.7, 0.5, 0.3),
		"scale": 1.2,
	},
	{
		"type": "hidden_passage",
		"color": Color(0.3, 0.3, 0.4),
		"glow_color": Color(0.5, 0.5, 0.7),
		"scale": 1.0,
	},
]

# ─── Phase 26: Wandering Merchants ──────────────────────────────────────────
# Rare traveling merchants that appear periodically near the player (unlike the
# two stationary Phase 3 traders). They despawn after a while or when the player
# trades, and carry a premium stock of rare items at a discounted Space Gloop
# cost. They are clearly distinguishable from regular traders by a vivid magenta
# canopy + a "Rare Goods" banner.
const WANDERING_MERCHANT_SPAWN_INTERVAL_MIN: float = 180.0   # Earliest a merchant can appear (seconds)
const WANDERING_MERCHANT_SPAWN_INTERVAL_MAX: float = 360.0   # Latest a merchant can appear
const WANDERING_MERCHANT_LIFETIME: float = 120.0             # How long they stay before despawning
const WANDERING_MERCHANT_SPAWN_DISTANCE: float = 35.0        # Distance from player at which they appear
const WANDERING_MERCHANT_TRADE_RANGE: float = 5.0            # Distance to open the trade menu
const WANDERING_MERCHANT_TRADE_RANGE_DESPAWN: float = 90.0   # Despawn if player wanders too far
const WANDERING_MERCHANT_SPEED: float = 1.4                  # Slow wander speed
const WANDERING_MERCHANT_WANDER_RADIUS: float = 8.0          # Tight wander radius (stays near spawn)
const WANDERING_MERCHANT_MAX_ALIVE: int = 1                  # Only one wandering merchant at a time
const WANDERING_MERCHANT_BODY_COLOR: Color = Color(0.85, 0.3, 0.9)  # Vivid magenta
const WANDERING_MERCHANT_HAT_COLOR: Color = Color(1.0, 0.85, 0.2)    # Gold canopy
const WANDERING_MERCHANT_GLOW_COLOR: Color = Color(1.0, 0.4, 1.0)
const WANDERING_MERCHANT_NAMES: Array[String] = ["Vex the Wanderer", "Glip-Who-Walks", "Orbix Prime", "Zara of the Rifts", "Fweem the Rare"]
# Wandering merchant rare stock — discounted from the regular trader (cost 3 vs 5).
const WANDERING_MERCHANT_STOCK: Array[Dictionary] = [
	{"name": "Meteor Shard", "type": GameConstants.CollectibleType.METEOR_SHARD, "cost": 3, "icon": "☄"},
	{"name": "Quantum Fuzz", "type": GameConstants.CollectibleType.QUANTUM_FUZZ, "cost": 3, "icon": "✦"},
	{"name": "Nebula Dust", "type": GameConstants.CollectibleType.NEBULA_DUST, "cost": 3, "icon": "🌌"},
	{"name": "Shield Crystal", "type": GameConstants.CollectibleType.SHIELD_CRYSTAL, "cost": 3, "icon": "🛡"},
	{"name": "Magnet Core", "type": GameConstants.CollectibleType.MAGNET_CORE, "cost": 3, "icon": "🧲"},
	{"name": "Toxic Extract", "type": GameConstants.CollectibleType.TOXIC_EXTRACT, "cost": 3, "icon": "☠"},
]

# ─── Phase 26: World Bosses ──────────────────────────────────────────────────
# Roaming bosses not tied to the BossArena system. They spawn very rarely at a
# distance from the player, wander the open world, and drop a large loot shower
# on death. Unlike arena bosses, they do NOT seal the player in — the player can
# flee. They are flagged as world bosses so the HUD/minimap can highlight them.
const WORLD_BOSS_SPAWN_INTERVAL_MIN: float = 300.0    # Earliest a world boss can spawn (5 min)
const WORLD_BOSS_SPAWN_INTERVAL_MAX: float = 600.0   # Latest (10 min)
const WORLD_BOSS_SPAWN_DISTANCE: float = 60.0       # Spawn far from the player
const WORLD_BOSS_DESPAWN_DISTANCE: float = 180.0   # Despawn if player flees too far
const WORLD_BOSS_MAX_ALIVE: int = 1                # Only one world boss at a time
const WORLD_BOSS_HP_MULT: float = 1.6              # 60% tougher than the base boss stats
const WORLD_BOSS_DAMAGE_MULT: float = 1.2          # 20% more damage
const WORLD_BOSS_XP_MULT: float = 2.0              # Double XP
const WORLD_BOSS_SCORE_MULT: float = 2.5           # 2.5x score
const WORLD_BOSS_LOOT_COUNT: int = 8               # Number of collectibles dropped on death
const WORLD_BOSS_TELEGRAPH_TIME: float = 3.0       # Warning time before the boss materializes
const WORLD_BOSS_COLOR: Color = Color(1.0, 0.2, 0.2)  # Distinct red tint for the minimap
# Which enemy types can be promoted to world boss (must have a boss-tier scene).
const WORLD_BOSS_CANDIDATES: Array[int] = [
	GameConstants.EnemyType.DRAKE,
	GameConstants.EnemyType.VOID_LEVIATHAN,
	GameConstants.EnemyType.ANCIENT_SENTINEL,
	GameConstants.EnemyType.GRAVITY_ELEMENTAL,
]
const WORLD_BOSS_NAMES: Dictionary = {
	GameConstants.EnemyType.DRAKE: "Apex Plasma Drake",
	GameConstants.EnemyType.VOID_LEVIATHAN: "Colossal Void Leviathan",
	GameConstants.EnemyType.ANCIENT_SENTINEL: "Rogue Ancient Sentinel",
	GameConstants.EnemyType.GRAVITY_ELEMENTAL: "Singularity Elemental",
}

# ─── Phase 26: Fast Travel Network ───────────────────────────────────────────
# Waypoints scattered across the world. The player activates one by stepping on
# it (or pressing the interact key), after which it can be selected from the
# fast-travel menu to teleport back. Only activated waypoints appear in the
# menu. Teleporting costs a small amount of Space Gloop to discourage spam.
const FAST_TRAVEL_SPAWN_CHANCE: float = 0.004        # Per-tile chance
const FAST_TRAVEL_ACTIVATE_RANGE: float = 4.0        # Distance to activate a waypoint
const FAST_TRAVEL_SKIP_NEAR_SPAWN: float = 55.0      # Skip waypoints near spawn
const FAST_TRAVEL_TELEPORT_COST: int = 2            # Space Gloop per teleport
const FAST_TRAVEL_COLOR: Color = Color(0.3, 1.0, 0.7)  # Teal
const FAST_TRAVEL_GLOW_COLOR: Color = Color(0.5, 1.0, 0.85)
const FAST_TRAVEL_INACTIVE_COLOR: Color = Color(0.4, 0.4, 0.45)  # Grey when not yet activated
const FAST_TRAVEL_HEIGHT: float = 2.5                # Pillar height
const FAST_TRAVEL_RADIUS: float = 1.8                # Activation ring radius
const FAST_TRAVEL_MAX_WAYPOINTS: int = 12            # Cap on total waypoints in the world

# ─── Phase 29: Equipment & Crafting Expansion ─────────────────────────────────
# Equipment system: armor pieces (head/body), accessories (ring/amulet), and
# consumables craftable from enemy drops + rare materials. Wearing matching
# pieces of a set grants a set bonus. Rare materials drop from bosses, specific
# weather types, and specific biomes (encouraging exploration & risk-taking).
# Materials can be refined (3 common → 1 rare) at no cost other than the mats.

# Equipment slot IDs
const EQUIP_SLOT_HEAD: int = 0
const EQUIP_SLOT_BODY: int = 1
const EQUIP_SLOT_ACCESSORY: int = 2
const EQUIP_SLOT_COUNT: int = 3

# Equipment rarity tiers (matches the loot-table tiering language)
enum EquipRarity {
	COMMON,     # Grey
	UNCOMMON,   # Green
	RARE,       # Blue
	EPIC,       # Purple
	LEGENDARY,  # Gold
}

const EQUIP_RARITY_COLORS: Array[Color] = [
	Color(0.6, 0.6, 0.6),       # COMMON — grey
	Color(0.3, 0.85, 0.4),      # UNCOMMON — green
	Color(0.35, 0.55, 1.0),     # RARE — blue
	Color(0.7, 0.4, 1.0),       # EPIC — purple
	Color(1.0, 0.85, 0.3),      # LEGENDARY — gold
]
const EQUIP_RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

# ── New collectible types: rare crafting materials ──
# These extend the CollectibleType enum. They drop from bosses, weather-specific
# sources, and biome-specific sources. They're used in equipment crafting recipes
# and refinement (3 common → 1 rare). They're stored in the same inventory as
# the regular crafting materials (WeaponModSystem inventory) for simplicity —
# one unified material pool the player manages.
# NOTE: We can't extend an enum after declaration in GDScript, so we add a
# separate enum for the rare materials and store them in a parallel inventory
# in EquipmentSystem. This keeps the existing CollectibleType stable.
enum RareMaterial {
	VOID_CORE,        # Boss drop — from Void Leviathan / world bosses
	PRISM_HEART,      # Boss drop — from Ancient Sentinel / Crystal Wraith
	PLASMA_SHARD,     # Weather drop — Meteor Shower / Solar Flare
	AURORA_DUST,      # Weather drop — Aurora
	BLOOD_CRYSTAL,    # Weather drop — Blood Moon
	ECLIPSE_ESSENCE,  # Weather drop — Eclipse
	EMBER_HEART,      # Biome drop — Volcano Core / Lava
	TIDE_PEARL,       # Biome drop — Deep Ocean
	GALE_SHARD,       # Biome drop — Sky Citadel
	DATA_FRAGMENT,    # Biome drop — Digital Grid
	SPORE_SAC,        # Biome drop — Mushroom / Swamp
	RELIC_DUST,       # Biome drop — Ancient Ruins
}

const RARE_MATERIAL_NAMES: Array[String] = [
	"Void Core", "Prism Heart", "Plasma Shard", "Aurora Dust", "Blood Crystal",
	"Eclipse Essence", "Ember Heart", "Tide Pearl", "Gale Shard", "Data Fragment",
	"Spore Sac", "Relic Dust",
]
# Vivid colors for each rare material (used by collectible glow + UI)
const RARE_MATERIAL_COLORS: Array[Color] = [
	Color(0.4, 0.1, 0.7),    # VOID_CORE — deep void purple
	Color(0.9, 0.5, 1.0),    # PRISM_HEART — prism pink
	Color(1.0, 0.5, 0.2),    # PLASMA_SHARD — fiery orange
	Color(0.3, 1.0, 0.7),    # AURORA_DUST — aurora teal
	Color(0.9, 0.1, 0.2),    # BLOOD_CRYSTAL — blood red
	Color(0.15, 0.1, 0.3),   # ECLIPSE_ESSENCE — dark eclipse
	Color(1.0, 0.3, 0.1),    # EMBER_HEART — ember red-orange
	Color(0.2, 0.6, 1.0),    # TIDE_PEARL — ocean blue
	Color(0.7, 0.9, 1.0),    # GALE_SHARD — sky cyan
	Color(0.2, 1.0, 0.9),    # DATA_FRAGMENT — digital cyan
	Color(0.5, 0.9, 0.3),    # SPORE_SAC — spore green
	Color(0.85, 0.75, 0.4),  # RELIC_DUST — ancient gold-brown
]

# Rare material drop sources
# Bosses drop VOID_CORE or PRISM_HEART. Weather-specific drops happen during
# the matching weather. Biome-specific drops happen while in the matching biome.
const RARE_MATERIAL_BOSS_DROPS: Array[int] = [
	RareMaterial.VOID_CORE,
	RareMaterial.PRISM_HEART,
]
const RARE_MATERIAL_WEATHER_DROPS: Dictionary = {
	Weather.METEOR_SHOWER: RareMaterial.PLASMA_SHARD,
	Weather.SOLAR_FLARE: RareMaterial.PLASMA_SHARD,
	Weather.AURORA: RareMaterial.AURORA_DUST,
	Weather.BLOOD_MOON: RareMaterial.BLOOD_CRYSTAL,
	Weather.ECLIPSE: RareMaterial.ECLIPSE_ESSENCE,
}
const RARE_MATERIAL_BIOME_DROPS: Dictionary = {
	Biome.LAVA: RareMaterial.EMBER_HEART,
	Biome.VOLCANO_CORE: RareMaterial.EMBER_HEART,
	Biome.DEEP_OCEAN: RareMaterial.TIDE_PEARL,
	Biome.SKY_CITADEL: RareMaterial.GALE_SHARD,
	Biome.DIGITAL_GRID: RareMaterial.DATA_FRAGMENT,
	Biome.MUSHROOM: RareMaterial.SPORE_SAC,
	Biome.SWAMP: RareMaterial.SPORE_SAC,
	Biome.ANCIENT_RUINS: RareMaterial.RELIC_DUST,
}
# Drop chance for rare materials from enemy kills (separate from common mats)
const RARE_MATERIAL_DROP_CHANCE: float = 0.04        # 4% normal enemy
const RARE_MATERIAL_DROP_CHANCE_BOSS: float = 1.0    # Bosses always drop a rare mat
const RARE_MATERIAL_WEATHER_BONUS: float = 0.06      # +6% during matching weather
const RARE_MATERIAL_BIOME_BONUS: float = 0.04       # +4% in matching biome

# ── Refinement recipes: 3 common materials → 1 rare material ──
# Key = RareMaterial enum int, Value = Array of CollectibleType (need 3 of each... no, 3 total)
# Actually: 3 of the listed common material → 1 rare material. Single-input recipes.
const REFINEMENT_RECIPES: Dictionary = {
	# 3 Magnet Core → 1 Void Core (gravitic compression)
	RareMaterial.VOID_CORE: {"mat": CollectibleType.MAGNET_CORE, "count": 3},
	# 3 Shield Crystal → 1 Prism Heart (crystalline fusion)
	RareMaterial.PRISM_HEART: {"mat": CollectibleType.SHIELD_CRYSTAL, "count": 3},
	# 3 Fireball Scroll → 1 Plasma Shard (combustion concentration)
	RareMaterial.PLASMA_SHARD: {"mat": CollectibleType.FIREBALL_SCROLL, "count": 3},
	# 3 Star Fruit → 1 Aurora Dust (stellar distillation)
	RareMaterial.AURORA_DUST: {"mat": CollectibleType.STAR_FRUIT, "count": 3},
	# 3 Meteor Shard → 1 Blood Crystal (meteoric crystallization)
	RareMaterial.BLOOD_CRYSTAL: {"mat": CollectibleType.METEOR_SHARD, "count": 3},
	# 3 Nebula Dust → 1 Eclipse Essence (nebular convergence)
	RareMaterial.ECLIPSE_ESSENCE: {"mat": CollectibleType.NEBULA_DUST, "count": 3},
	# 3 Toxic Extract → 1 Spore Sac (toxic compression)
	RareMaterial.SPORE_SAC: {"mat": CollectibleType.TOXIC_EXTRACT, "count": 3},
	# 3 Regen Crystal → 1 Relic Dust (ancient crystallization)
	RareMaterial.RELIC_DUST: {"mat": CollectibleType.REGEN_CRYSTAL, "count": 3},
}
# Refinement recipes that need 2 different common materials (the harder rares)
const REFINEMENT_RECIPES_DUAL: Dictionary = {
	# 2 Quantum Fuzz + 2 Space Gloop → 1 Ember Heart
	RareMaterial.EMBER_HEART: {"mats": [CollectibleType.QUANTUM_FUZZ, CollectibleType.SPACE_GLOOP], "count": 2},
	# 2 Quantum Fuzz + 2 Star Fruit → 1 Tide Pearl
	RareMaterial.TIDE_PEARL: {"mats": [CollectibleType.QUANTUM_FUZZ, CollectibleType.STAR_FRUIT], "count": 2},
	# 2 Quantum Fuzz + 2 Magnet Core → 1 Gale Shard
	RareMaterial.GALE_SHARD: {"mats": [CollectibleType.QUANTUM_FUZZ, CollectibleType.MAGNET_CORE], "count": 2},
	# 2 Quantum Fuzz + 2 Shield Crystal → 1 Data Fragment
	RareMaterial.DATA_FRAGMENT: {"mats": [CollectibleType.QUANTUM_FUZZ, CollectibleType.SHIELD_CRYSTAL], "count": 2},
}

# ── Equipment piece definitions ──
# Each piece: id, name, slot, rarity, stats (dict of bonus type → value),
# craft recipe (dict of material type → count), set_id (or -1 if no set).
# Stat keys: "max_hp", "damage_mult", "speed_mult", "crit_chance", "damage_reduction", "xp_mult", "loot_mult", "fire_rate_mult"
enum EquipPiece {
	# Head armor (slot 0)
	LEATHER_CAP,        # Common — small HP bonus
	PLASMA_HELM,        # Uncommon — damage + crit
	CRYSTAL_CROWN,      # Rare — crit + damage
	VOID_VISAGE,        # Epic — damage + damage reduction
	ANCIENT_MASK,       # Legendary — all stats
	# Body armor (slot 1)
	LEATHER_VEST,       # Common — HP + damage reduction
	PLASMA_PLATE,       # Uncommon — HP + damage
	CRYSTAL_CARAPACE,   # Rare — HP + damage reduction
	VOID_CLOAK,         # Epic — speed + damage reduction + crit
	ANCIENT_REGALIA,    # Legendary — all stats
	# Accessories (slot 2 — ring/amulet)
	BONE_RING,          # Common — small damage
	PRISM_AMULET,       # Uncommon — crit + xp
	AURORA_PENDANT,     # Rare — xp + loot
	BLOOD_SIGIL,        # Epic — damage + crit + loot
	COSMIC_TALISMAN,    # Legendary — all stats
}

const EQUIP_PIECE_NAMES: Array[String] = [
	# Head
	"Leather Cap", "Plasma Helm", "Crystal Crown", "Void Visage", "Ancient Mask",
	# Body
	"Leather Vest", "Plasma Plate", "Crystal Carapace", "Void Cloak", "Ancient Regalia",
	# Accessory
	"Bone Ring", "Prism Amulet", "Aurora Pendant", "Blood Sigil", "Cosmic Talisman",
]
const EQUIP_PIECE_ICONS: Array[String] = [
	# Head
	"⛑", "⚡", "💎", "👁", "🎭",
	# Body
	"🦺", "🔥", "🔷", "🌌", "👑",
	# Accessory
	"💍", "🔮", "🌌", "🩸", "✨",
]
# Slot for each piece (head=0, body=1, accessory=2)
const EQUIP_PIECE_SLOT: Array[int] = [
	0, 0, 0, 0, 0,  # Head pieces
	1, 1, 1, 1, 1,  # Body pieces
	2, 2, 2, 2, 2,  # Accessories
]
# Rarity for each piece
const EQUIP_PIECE_RARITY: Array[int] = [
	0, 1, 2, 3, 4,  # Head: common → legendary
	0, 1, 2, 3, 4,  # Body
	0, 1, 2, 3, 4,  # Accessory
]
# Stats for each piece — dict of stat_key → bonus value
# Design notes:
#   - Head pieces emphasize crit/damage (precision/aim theme)
#   - Body pieces emphasize HP/damage reduction (protection theme)
#   - Accessories emphasize utility (XP, loot, speed)
#   - Legendary pieces give small bonuses to ALL stats (jack-of-all-trades)
const EQUIP_PIECE_STATS: Array[Dictionary] = [
	# ── Head ──
	{"max_hp": 10},                                           # Leather Cap
	{"damage_mult": 0.08, "crit_chance": 0.03},             # Plasma Helm
	{"crit_chance": 0.08, "damage_mult": 0.05},             # Crystal Crown
	{"damage_mult": 0.12, "damage_reduction": 0.05},        # Void Visage
	{"max_hp": 20, "damage_mult": 0.10, "crit_chance": 0.05, "damage_reduction": 0.05, "speed_mult": 0.05},  # Ancient Mask
	# ── Body ──
	{"max_hp": 20, "damage_reduction": 0.03},               # Leather Vest
	{"max_hp": 30, "damage_mult": 0.06},                    # Plasma Plate
	{"max_hp": 40, "damage_reduction": 0.08},               # Crystal Carapace
	{"speed_mult": 0.10, "damage_reduction": 0.10, "crit_chance": 0.04},  # Void Cloak
	{"max_hp": 50, "damage_mult": 0.08, "damage_reduction": 0.08, "speed_mult": 0.08, "xp_mult": 0.10},  # Ancient Regalia
	# ── Accessories ──
	{"damage_mult": 0.05},                                    # Bone Ring
	{"crit_chance": 0.05, "xp_mult": 0.08},                 # Prism Amulet
	{"xp_mult": 0.15, "loot_mult": 0.10},                  # Aurora Pendant
	{"damage_mult": 0.10, "crit_chance": 0.06, "loot_mult": 0.08},  # Blood Sigil
	{"max_hp": 15, "damage_mult": 0.06, "crit_chance": 0.04, "speed_mult": 0.06, "xp_mult": 0.10, "loot_mult": 0.10, "fire_rate_mult": 0.05},  # Cosmic Talisman
]

# ── Crafting recipes for equipment pieces ──
# Key = EquipPiece enum int, Value = Dictionary of {material_type: count}
# Material types can be CollectibleType (common) or RareMaterial (rare).
# We use a tagged dict: {"common": {type: count}, "rare": {type: count}}
const EQUIP_CRAFT_RECIPES: Dictionary = {
	# ── Head ──
	EquipPiece.LEATHER_CAP: {"common": {CollectibleType.SPACE_GLOOP: 3}},
	EquipPiece.PLASMA_HELM: {"common": {CollectibleType.FIREBALL_SCROLL: 2, CollectibleType.MAGNET_CORE: 2}},
	EquipPiece.CRYSTAL_CROWN: {"common": {CollectibleType.SHIELD_CRYSTAL: 3}, "rare": {RareMaterial.PRISM_HEART: 1}},
	EquipPiece.VOID_VISAGE: {"common": {CollectibleType.NEBULA_DUST: 3, CollectibleType.QUANTUM_FUZZ: 2}, "rare": {RareMaterial.VOID_CORE: 1}},
	EquipPiece.ANCIENT_MASK: {"common": {CollectibleType.METEOR_SHARD: 2, CollectibleType.REGEN_CRYSTAL: 2}, "rare": {RareMaterial.RELIC_DUST: 2, RareMaterial.ECLIPSE_ESSENCE: 1}},
	# ── Body ──
	EquipPiece.LEATHER_VEST: {"common": {CollectibleType.SPACE_GLOOP: 4}},
	EquipPiece.PLASMA_PLATE: {"common": {CollectibleType.FIREBALL_SCROLL: 3, CollectibleType.STAR_FRUIT: 2}},
	EquipPiece.CRYSTAL_CARAPACE: {"common": {CollectibleType.SHIELD_CRYSTAL: 4}, "rare": {RareMaterial.PRISM_HEART: 1}},
	EquipPiece.VOID_CLOAK: {"common": {CollectibleType.NEBULA_DUST: 4, CollectibleType.QUANTUM_FUZZ: 3}, "rare": {RareMaterial.VOID_CORE: 1}},
	EquipPiece.ANCIENT_REGALIA: {"common": {CollectibleType.METEOR_SHARD: 3, CollectibleType.HEALTH_FRAGMENT: 2}, "rare": {RareMaterial.RELIC_DUST: 2, RareMaterial.VOID_CORE: 1}},
	# ── Accessories ──
	EquipPiece.BONE_RING: {"common": {CollectibleType.SPACE_GLOOP: 2, CollectibleType.STAR_FRUIT: 1}},
	EquipPiece.PRISM_AMULET: {"common": {CollectibleType.SHIELD_CRYSTAL: 2, CollectibleType.STAR_FRUIT: 2}, "rare": {RareMaterial.PRISM_HEART: 1}},
	EquipPiece.AURORA_PENDANT: {"common": {CollectibleType.STAR_FRUIT: 3}, "rare": {RareMaterial.AURORA_DUST: 2}},
	EquipPiece.BLOOD_SIGIL: {"common": {CollectibleType.METEOR_SHARD: 2, CollectibleType.TOXIC_EXTRACT: 2}, "rare": {RareMaterial.BLOOD_CRYSTAL: 2}},
	EquipPiece.COSMIC_TALISMAN: {"common": {CollectibleType.QUANTUM_FUZZ: 3, CollectibleType.NEBULA_DUST: 3}, "rare": {RareMaterial.VOID_CORE: 1, RareMaterial.AURORA_DUST: 1, RareMaterial.RELIC_DUST: 1}},
}

# ── Equipment sets ──
# Wearing matching pieces of a set grants a set bonus. A set is defined by a
# group of pieces (any 2 of them = 1-piece bonus, all 3 = full set bonus).
# Set bonuses are stronger than individual piece bonuses, encouraging collection.
enum EquipSet {
	NONE,           # No set
	PLASMA_SET,     # Plasma Helm + Plasma Plate + Blood Sigil
	CRYSTAL_SET,    # Crystal Crown + Crystal Carapace + Prism Amulet
	VOID_SET,       # Void Visage + Void Cloak + Cosmic Talisman
	ANCIENT_SET,    # Ancient Mask + Ancient Regalia + Cosmic Talisman
}
const EQUIP_SET_NAMES: Array[String] = ["None", "Plasma", "Crystal", "Void", "Ancient"]
const EQUIP_SET_COLORS: Array[Color] = [
	Color(0.5, 0.5, 0.5),     # NONE
	Color(1.0, 0.5, 0.2),     # PLASMA — orange
	Color(0.35, 0.55, 1.0),   # CRYSTAL — blue
	Color(0.4, 0.1, 0.7),     # VOID — purple
	Color(1.0, 0.85, 0.3),    # ANCIENT — gold
]
# Which pieces belong to which set (for set-bonus detection)
const EQUIP_SET_PIECES: Dictionary = {
	EquipSet.PLASMA_SET: [EquipPiece.PLASMA_HELM, EquipPiece.PLASMA_PLATE, EquipPiece.BLOOD_SIGIL],
	EquipSet.CRYSTAL_SET: [EquipPiece.CRYSTAL_CROWN, EquipPiece.CRYSTAL_CARAPACE, EquipPiece.PRISM_AMULET],
	EquipSet.VOID_SET: [EquipPiece.VOID_VISAGE, EquipPiece.VOID_CLOAK, EquipPiece.COSMIC_TALISMAN],
	EquipSet.ANCIENT_SET: [EquipPiece.ANCIENT_MASK, EquipPiece.ANCIENT_REGALIA, EquipPiece.COSMIC_TALISMAN],
}
# Set bonuses: 2-piece bonus (wear any 2 of the set) and 3-piece bonus (full set)
# Stat keys match EQUIP_PIECE_STATS. The 3-piece bonus is ADDED on top of the 2-piece.
const EQUIP_SET_BONUSES: Dictionary = {
	EquipSet.PLASMA_SET: {
		2: {"damage_mult": 0.10, "fire_rate_mult": 0.05},
		3: {"damage_mult": 0.10, "fire_rate_mult": 0.05, "crit_chance": 0.05},
	},
	EquipSet.CRYSTAL_SET: {
		2: {"damage_reduction": 0.08, "max_hp": 20},
		3: {"damage_reduction": 0.05, "max_hp": 30, "crit_chance": 0.05},
	},
	EquipSet.VOID_SET: {
		2: {"speed_mult": 0.10, "crit_chance": 0.05},
		3: {"speed_mult": 0.05, "crit_chance": 0.05, "damage_mult": 0.08},
	},
	EquipSet.ANCIENT_SET: {
		2: {"max_hp": 30, "damage_reduction": 0.05, "xp_mult": 0.10},
		3: {"max_hp": 30, "damage_reduction": 0.05, "xp_mult": 0.10, "damage_mult": 0.10, "loot_mult": 0.10},
	},
}

# ── Consumable items ──
# Craftable single-use items that grant temporary effects. Stored in a
# separate consumable inventory (not the material inventory).
enum Consumable {
	HEALTH_POTION,     # Restore 50 HP instantly
	SPEED_POTION,      # +30% speed for 10s
	SHIELD_POTION,     # +20% damage reduction for 10s
	POWER_POTION,      # +25% damage for 10s
	VOID_BOMB,         # AoE explosion dealing 80 damage in 8m radius
}
const CONSUMABLE_NAMES: Array[String] = [
	"Health Potion", "Speed Potion", "Shield Potion", "Power Potion", "Void Bomb",
]
const CONSUMABLE_ICONS: Array[String] = ["🧪", "💨", "🛡", "💪", "💥"]
const CONSUMABLE_COLORS: Array[Color] = [
	Color(0.9, 0.2, 0.3),   # HEALTH — red
	Color(0.3, 0.9, 1.0),   # SPEED — cyan
	Color(0.3, 0.5, 1.0),   # SHIELD — blue
	Color(1.0, 0.5, 0.2),   # POWER — orange
	Color(0.5, 0.1, 0.8),   # VOID — purple
]
const CONSUMABLE_EFFECT_DURATION: Array[float] = [0.0, 10.0, 10.0, 10.0, 0.0]  # 0 = instant
const CONSUMABLE_EFFECT_VALUE: Array[float] = [50.0, 0.30, 0.20, 0.25, 80.0]   # magnitude
const CONSUMABLE_AOE_RADIUS: float = 8.0  # For Void Bomb
# Consumable crafting recipes (use common + rare materials)
const CONSUMABLE_CRAFT_RECIPES: Dictionary = {
	Consumable.HEALTH_POTION: {"common": {CollectibleType.REGEN_CRYSTAL: 1, CollectibleType.HEALTH_FRAGMENT: 1}},
	Consumable.SPEED_POTION: {"common": {CollectibleType.STAR_FRUIT: 2, CollectibleType.SPACE_GLOOP: 1}},
	Consumable.SHIELD_POTION: {"common": {CollectibleType.SHIELD_CRYSTAL: 2}},
	Consumable.POWER_POTION: {"common": {CollectibleType.FIREBALL_SCROLL: 2, CollectibleType.METEOR_SHARD: 1}},
	Consumable.VOID_BOMB: {"common": {CollectibleType.NEBULA_DUST: 2, CollectibleType.MAGNET_CORE: 1}, "rare": {RareMaterial.VOID_CORE: 1}},
}
# Consumable hotkeys: use consumables with number keys 1-5
const CONSUMABLE_HOTKEYS: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
# Max stack size per consumable type
const CONSUMABLE_MAX_STACK: int = 10

# ── Equipment upgrade system ──
# Spend materials to upgrade an equipped piece to +1, +2, +3 (max).
# Each upgrade level adds +20% to all of the piece's stat bonuses.
const EQUIP_MAX_UPGRADE_LEVEL: int = 3
const EQUIP_UPGRADE_MULT_PER_LEVEL: float = 0.20  # +20% per level
# Upgrade cost: base cost scales with upgrade level. Uses common materials.
# Cost = {material_type: count} — the material type is the piece's "theme" material.
const EQUIP_UPGRADE_BASE_COST: int = 2  # Base material count for +1
const EQUIP_UPGRADE_COST_SCALE: float = 1.5  # Each level costs 1.5x the previous
const FAST_TRAVEL_MENU_KEY: String = "fast_travel"   # Input action name