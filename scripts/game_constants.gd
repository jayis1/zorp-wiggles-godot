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

# ─── Pulse Wave (Q ability) ──────────────────────────────────────────────────
const PULSE_WAVE_COOLDOWN: float = 8.0
const PULSE_WAVE_RADIUS: float = 18.0
const PULSE_WAVE_DAMAGE: int = 60

# ─── Camera ──────────────────────────────────────────────────────────────────
const CAMERA_DISTANCE: float = 22.0
const CAMERA_ANGLE: float = 55.0
const CAMERA_ROTATE_SPEED: float = 200.0

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