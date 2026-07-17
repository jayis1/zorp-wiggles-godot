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
}

# Ambient shader strength per biome (0..1). Tuned so the effect is noticeable
# but never obscures gameplay.
const BIOME_SHADER_STRENGTH: Dictionary = {
	GameConstants.Biome.LAVA: 0.55,
	GameConstants.Biome.SNOW: 0.6,
	GameConstants.Biome.ALIEN: 0.45,
	GameConstants.Biome.TOXIC_BOG: 0.5,
	GameConstants.Biome.CRYSTAL: 0.4,
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

# Weather → biome affinity (weather more likely in thematic biomes)
# Each weather type maps to a list of biomes where it has a higher chance of starting.
const WEATHER_BIOME_AFFINITY: Dictionary = {
	Weather.ACID_RAIN: [GameConstants.Biome.TOXIC_BOG, GameConstants.Biome.SWAMP],
	Weather.SOLAR_FLARE: [GameConstants.Biome.LAVA, GameConstants.Biome.DESERT],
	Weather.FOG: [GameConstants.Biome.WATER, GameConstants.Biome.SWAMP, GameConstants.Biome.FOREST],
	Weather.THUNDERSTORM: [GameConstants.Biome.WATER, GameConstants.Biome.GRASS, GameConstants.Biome.FLOATING_ISLANDS],
	Weather.SNOW_STORM: [GameConstants.Biome.SNOW, GameConstants.Biome.CRYSTAL],
	# Enhancement: New weather biome affinities
	Weather.METEOR_SHOWER: [GameConstants.Biome.LAVA, GameConstants.Biome.DESERT, GameConstants.Biome.ALIEN],
	Weather.AURORA: [GameConstants.Biome.SNOW, GameConstants.Biome.CRYSTAL, GameConstants.Biome.FLOATING_ISLANDS],
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

# Revive system
const COOP_REVIVE_DURATION: float = 3.0       # Seconds to hold revive
const COOP_REVIVE_RANGE: float = 3.5          # Max distance to revive
const COOP_REVIVE_HP_RESTORE: int = 60        # HP on revive
const COOP_REVIVE_INVULN_DURATION: float = 2.0 # Invuln after revive
const COOP_DOWNED_SPEED: float = 0.0          # Downed player can't move
const COOP_DOWNED_TIMER_MAX: float = 30.0     # Bleed-out timer (auto-die after this)
const COOP_DOWNED_REVIVE_PROGRESS_TICK: float = 0.034  # Progress per tick (~30/sec → ~3s)

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
const COOP_DROP_OUT_HOLD_TIME: float = 2.0     # Hold drop-in key this long to drop out