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

# ─── Collectible Types ───────────────────────────────────────────────────────
enum CollectibleType {
	STAR_FRUIT,
	METEOR_SHARD,
	QUANTUM_FUZZ,
	NEBULA_DUST,
	SPACE_GLOOP,
	XP_ORB,
	HEALTH_FRAGMENT,
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