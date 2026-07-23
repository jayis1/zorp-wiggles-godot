## Zorp Wiggles — Audio Manager (Phase 20: Audio & Polish)
## Autoload singleton that provides:
##   • Procedurally synthesized sound effects (no external audio files needed)
##   • Per-biome ambient background music (looping drones)
##   • Boss fight music
##   • Volume control (master / SFX / music) for the settings menu
## All sounds are generated at runtime as AudioStreamWAV resources with raw
## PCM data — no .ogg/.wav files required. This keeps the project self-contained.
##
## Usage:
##   AudioManager.play_sfx("shoot")
##   AudioManager.play_music_biome(GameConstants.Biome.LAVA)
##   AudioManager.play_boss_music()
##   AudioManager.stop_music()
##   AudioManager.set_master_volume(0.8)

extends Node

# ─── Volume Settings (0..1) ───────────────────────────────────────────────────
var master_volume: float = 1.0
var sfx_volume: float = 0.8
var music_volume: float = 0.5

# dB value used for "silent" — finite so tweens interpolate cleanly.
# (linear_to_db(0.0) returns -inf, which produces NaN when tweened toward.)
const SILENT_DB: float = -80.0

# ─── Audio Players ────────────────────────────────────────────────────────────
# SFX pool — multiple players so overlapping sounds don't cut each other off.
const SFX_POOL_SIZE: int = 12
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_idx: int = 0

var _music_player: AudioStreamPlayer = null
var _boss_music_player: AudioStreamPlayer = null

# ─── Generated Streams ────────────────────────────────────────────────────────
var _sfx_streams: Dictionary = {}   # name -> AudioStreamWAV
var _music_streams: Dictionary = {} # biome_id -> AudioStreamWAV
var _boss_music_stream: AudioStreamWAV = null

# ─── State ────────────────────────────────────────────────────────────────────
var _current_biome: int = -1
var _boss_music_playing: bool = false
var _initialized: bool = false

# ── Music fade tweens ── Stored so we can kill them before starting a new fade
#    (e.g. rapid biome changes). Without this, overlapping volume tweens would
#    fight and the music volume would jitter.
var _music_fade_tween: Tween = null
var _boss_fade_tween: Tween = null
const MUSIC_FADE_IN_DURATION: float = 0.8   # Seconds for music to swell in
const MUSIC_FADE_OUT_DURATION: float = 0.5  # Seconds for music to fade out

const SAMPLE_RATE: int = 44100

# SFX names
const SFX_SHOOT: String = "shoot"
const SFX_DASH: String = "dash"
const SFX_PICKUP: String = "pickup"
const SFX_PICKUP_RARE: String = "pickup_rare"
const SFX_LEVEL_UP: String = "level_up"
const SFX_DAMAGE: String = "damage"
const SFX_DEATH: String = "death"
const SFX_ENEMY_HIT: String = "enemy_hit"
const SFX_ENEMY_DEATH: String = "enemy_death"
# ── Crit hit SFX ── A distinct, punchy "ping" for critical hits. Crits are
# major game-feel moments (gold flash, hit-stop, gold damage number) but
# previously played the same enemy_hit blip as a normal hit, so crits were
# only visually distinct — not audibly. This short, bright, rising-pitch
# chime cuts through the combat mix so the player *hears* the crit land,
# reinforcing the gold visual language with a matching sonic signature.
const SFX_CRIT_HIT: String = "crit_hit"
const SFX_BOSS_SPAWN: String = "boss_spawn"
const SFX_BOSS_DEFEATED: String = "boss_defeated"
const SFX_EXPLOSION: String = "explosion"
const SFX_PULSE_WAVE: String = "pulse_wave"
const SFX_HEAL: String = "heal"
const SFX_DASH_BUMP: String = "dash_bump"
const SFX_COMBO_MILESTONE: String = "combo_milestone"
const SFX_UI_CLICK: String = "ui_click"
# A softer, shorter, higher-pitched tick for mouse-hover over buttons.
# Distinct from SFX_UI_CLICK so hover and click events don't sound identical
# (previously all hover handlers played SFX_UI_CLICK, making hover and click
# indistinguishable). The hover blip is ~half the duration and ~40% the volume
# of the click, with a higher frequency (900Hz vs 600Hz) so it reads as a
# feather-light "tick" rather than a firm "tock" — the classic UI sound design
# pattern (hover = soft tick, click = firm tock).
const SFX_UI_HOVER: String = "ui_hover"
const SFX_MUTATION: String = "mutation"
const SFX_RIFT: String = "rift"
const SFX_THUNDER: String = "thunder"
const SFX_REVIVE: String = "revive"
const SFX_PET: String = "pet"
const SFX_CRAFT: String = "craft"
const SFX_ARENA: String = "arena"
const SFX_SHIELD: String = "shield"  # Phase 24: Shield Bubble deployable
const SFX_CHEST_OPEN: String = "chest_open"      # Phase 26: Treasure chest opened
const SFX_CHEST_TRAP: String = "chest_trap"      # Phase 26: Trapped chest ambush
const SFX_LORE: String = "lore"                  # Phase 26: Lore stone read
const SFX_WILDLIFE: String = "wildlife"          # Phase 26: Wildlife caught
const SFX_SWITCH: String = "switch_click"        # Phase 26: Interactive switch toggled
const SFX_BREAKABLE: String = "breakable"        # Phase 26: Breakable wall shattered
const SFX_PING: String = "ping"                 # Phase 31: Ping placed
const SFX_DIALOGUE: String = "dialogue"           # Phase 26: NPC dialogue advance
const SFX_FAST_TRAVEL: String = "fast_travel"    # Phase 26: Fast travel teleport
const SFX_WORLD_BOSS: String = "world_boss"      # Phase 26: World boss spawned
# ── Enemy ability SFX ── Distinct audio cues for special enemy abilities so
# the player can identify threats by sound, not just sight.
const SFX_TELEPORT: String = "teleport"           # Time Warden / Phase Shifter phase shift
const SFX_CLOAK: String = "cloak"                 # Plasma Stalker cloak activate/deactivate
const SFX_CONSUMABLE: String = "consumable"       # Consumable item used (dedicated sound)
const SFX_PET_EVOLVE: String = "pet_evolve"       # Pet evolution (major milestone)

# ── Phase 30: Adaptive shoot SFX ──────────────────────────────────────────────
# Per-weapon-mod shoot sound variants. Each mod gets a distinct SFX so the
# player hears the weapon change — a standard laser zaps, a black hole
# whooshes, a freeze ray chimes, etc. We generate one variant per mod at
# startup and pick the right one in play_shoot_sfx(mod_id).
const SFX_SHOOT_STANDARD: String = "shoot"        # Default cyan laser
const SFX_SHOOT_HOMING: String = "shoot_homing"   # Tracking whistle
const SFX_SHOOT_ENERGY: String = "shoot_energy"   # Generic energy bolt (chain/spread/ricochet/etc.)
const SFX_SHOOT_PIERCE: String = "shoot_pierce"   # Piercing beam (high-pitched thin whine)
const SFX_SHOOT_FREEZE: String = "shoot_freeze"   # Ice crystal chime
const SFX_SHOOT_POISON: String = "shoot_poison"   # Acid hiss
const SFX_SHOOT_FIRE: String = "shoot_fire"       # Fireball whoosh
const SFX_SHOOT_VOID: String = "shoot_void"       # Deep void pulse
const SFX_SHOOT_LIGHTNING: String = "shoot_lightning" # Electric zap
const SFX_SHOOT_HEAVY: String = "shoot_heavy"     # Heavy cannon (mega blast, meteor strike, black hole launcher)
const SFX_SHOOT_UTILITY: String = "shoot_utility" # Shrink/deployables — soft chime
const SFX_SHOOT_VAMPIRE: String = "shoot_vampire" # Crimson drain hum
# Maps WeaponMod enum value → SFX name. Mods not in the map fall back to SFX_SHOOT_STANDARD.
var _mod_shoot_sfx: Dictionary = {}


func _ready() -> void:
	_create_sfx_pool()
	_generate_all_sfx()
	_generate_all_music()
	_build_mod_shoot_sfx_map()  # Phase 30: Adaptive shoot SFX
	_initialized = true
	# Connect to game signals for automatic SFX
	_connect_signals()
	# Apply initial volumes
	_apply_volumes()


# ─── Phase 30: Dynamic Music Intensity ────────────────────────────────────────
# The music intensity rises with the player's kill combo, then decays back to
# baseline when the combo timer expires. We modulate the biome music player's
# pitch_scale (subtle, +0..+8%) and volume (+0..+3 dB) so combat feels more
# urgent as the combo climbs, then settles when the action dies down.
#
# Intensity tiers (based on player_combo):
#   0-4   : calm    — pitch 1.00, vol offset 0.0 dB
#   5-14  : engaged — pitch 1.02, vol offset +0.5 dB
#   15-29 : heated  — pitch 1.04, vol offset +1.5 dB
#   30-49 : intense — pitch 1.06, vol offset +2.5 dB
#   50+   : frenzied — pitch 1.08, vol offset +3.5 dB
#
# The intensity eases toward its target (exponential lerp) so the transition
# is smooth, not a snap. Boss music is exempt (it's already intense).
const MUSIC_INTENSITY_FADE_SPEED: float = 2.5  # How fast intensity eases
var _music_intensity_current: float = 0.0  # 0..4 (tier index, fractional)

func _process(delta: float) -> void:
	_update_music_intensity(delta)

func _update_music_intensity(delta: float) -> void:
	if not _initialized:
		return
	# Boss music has its own fixed intensity — don't modulate it.
	if _boss_music_playing:
		return
	if not _music_player or not _music_player.playing:
		return
	# Determine target intensity tier from combo
	var target_tier: float = 0.0
	if GameManager:
		var combo: int = GameManager.player_combo
		# Combo timer expiring → ease back to calm even if combo count is high.
		# This prevents the music from staying maxed-out after combat ends.
		if GameManager.player_combo_timer <= 0.0:
			combo = 0
		if combo >= 50:
			target_tier = 4.0
		elif combo >= 30:
			target_tier = 3.0
		elif combo >= 15:
			target_tier = 2.0
		elif combo >= 5:
			target_tier = 1.0
		else:
			target_tier = 0.0
	# Ease toward target (frame-rate independent)
	_music_intensity_current = lerpf(_music_intensity_current, target_tier,
		1.0 - exp(-MUSIC_INTENSITY_FADE_SPEED * delta))
	# Map intensity (0..4) to pitch (1.00..1.08) and volume offset (0..+3.5 dB)
	var pitch: float = 1.0 + (_music_intensity_current / 4.0) * 0.08
	var vol_offset_db: float = (_music_intensity_current / 4.0) * 3.5
	# Apply — but only if a fade isn't currently animating the volume (so we
	# don't fight the fade tween). Pitch is safe to set any time.
	_music_player.pitch_scale = pitch
	var music_fading: bool = _music_fade_tween != null and is_instance_valid(_music_fade_tween) and _music_fade_tween.is_running()
	if not music_fading:
		var base_vol_db: float = linear_to_db(maxf(music_volume * master_volume, 0.0001))
		_music_player.volume_db = base_vol_db + vol_offset_db

## Get the current music intensity tier (0..4, fractional). For HUD display.
func get_music_intensity() -> float:
	return _music_intensity_current

## Get the current music intensity tier name. For HUD/feedback.
func get_music_intensity_name() -> String:
	var t: int = int(round(_music_intensity_current))
	match t:
		0: return "Calm"
		1: return "Engaged"
		2: return "Heated"
		3: return "Intense"
		4: return "Frenzied"
		_: return "Calm"


# ─── SFX Pool ─────────────────────────────────────────────────────────────────

func _create_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_sfx_pool.append(player)


func _next_sfx_player() -> AudioStreamPlayer:
	var player = _sfx_pool[_sfx_pool_idx]
	_sfx_pool_idx = (_sfx_pool_idx + 1) % SFX_POOL_SIZE
	return player


# ─── Signal Connections ───────────────────────────────────────────────────────

func _connect_signals() -> void:
	# Boss events
	GameManager.boss_spawned.connect(_on_boss_spawned)
	GameManager.boss_defeated.connect(_on_boss_defeated)
	# Level up
	GameManager.level_up.connect(_on_level_up)
	# Combo milestones
	GameManager.combo_milestone.connect(_on_combo_milestone)
	# Biome change → switch music
	GameManager.biome_changed.connect(_on_biome_changed)
	# Player death
	GameManager.player_died.connect(_on_player_died)
	# Game restart
	GameManager.game_restarted.connect(_on_game_restarted)


# ─── Public API ───────────────────────────────────────────────────────────────

## Play a one-shot sound effect by name. Safe to call if the name doesn't exist.
## Combat SFX (shoot, enemy_hit, dash_bump) get subtle random pitch variation
## (±6%) so rapid-fire combat doesn't feel monotonous — a standard game-audio
## juice technique. Non-combat SFX (UI, level-up arpeggios) play at unity pitch
## so melodies stay in tune. The variation is tiny enough that rapid shots
## still read as the same weapon, just with natural micro-detuning.
func play_sfx(sfx_name: String) -> void:
	if not _initialized:
		return
	if not _sfx_streams.has(sfx_name):
		return
	var player = _next_sfx_player()
	player.stream = _sfx_streams[sfx_name]
	player.volume_db = linear_to_db(maxf(sfx_volume * master_volume, 0.0001))
	# Pitch variation for combat sounds — keeps rapid fire from sounding robotic
	if sfx_name in _PITCH_VARIATION_SFX:
		player.pitch_scale = 1.0 + randf_range(-_PITCH_VARIATION_AMOUNT, _PITCH_VARIATION_AMOUNT)
	else:
		player.pitch_scale = 1.0
	player.play()

# ── Phase 30: Adaptive shoot SFX ──────────────────────────────────────────────
## Play the shoot SFX appropriate for the equipped weapon mod. If mod_id is
## NONE (or the mod has no mapping), falls back to the standard laser SFX.
## This gives each weapon mod a distinct auditory identity — the player hears
## the weapon change without looking at the HUD.
func play_shoot_sfx(mod_id: int = 0) -> void:
	if not _initialized:
		return
	var sfx_name: String = _mod_shoot_sfx.get(mod_id, SFX_SHOOT_STANDARD)
	if not _sfx_streams.has(sfx_name):
		sfx_name = SFX_SHOOT_STANDARD
	var player = _next_sfx_player()
	player.stream = _sfx_streams[sfx_name]
	player.volume_db = linear_to_db(maxf(sfx_volume * master_volume, 0.0001))
	# Pitch variation for combat sounds — keeps rapid fire from sounding robotic
	if sfx_name in _PITCH_VARIATION_SFX:
		player.pitch_scale = 1.0 + randf_range(-_PITCH_VARIATION_AMOUNT, _PITCH_VARIATION_AMOUNT)
	else:
		player.pitch_scale = 1.0
	player.play()

## Build the WeaponMod → SFX name mapping. Called once at _ready.
## Mods are grouped by thematic sound character:
##   - Homing mods (HOMING_LASER, MAGNET_MINE) → tracking whistle
##   - Energy bolt mods (CHAIN_LIGHTNING, SPREAD_SHOT, RICOCHET, etc.) → energy bolt
##   - Piercing mods (PIERCING_BEAM, PHOTON_BEAM, SPECTRAL_BEAM) → thin whine
##   - Freeze mods (FREEZE_RAY, TIME_FREEZE_RAY) → ice chime
##   - Poison/acid mods (ACID_TRAIL, POISON_NOVA, SHRINK_BEAM) → acid hiss
##   - Fire mods (BLAZE_TRAIL, METEOR_STRIKE, SHRAPNEL_BURST) → fire whoosh
##   - Void/dark mods (VOID_RAY, BLACK_HOLE_*, VOID_RIFT_CUTTER) → void pulse
##   - Lightning mods (TESLA_COIL, LIGHTNING_STORM) → electric zap
##   - Heavy mods (MEGA_BLAST, METEOR_STRIKE, BLACK_HOLE_LAUNCHER) → heavy cannon
##   - Utility/deployables (SHIELD_BUBBLE, TURRET_DEPLOY, etc.) → soft chime
##   - Vampire → crimson drain hum
func _build_mod_shoot_sfx_map() -> void:
	var WM = GameConstants.WeaponMod
	_mod_shoot_sfx[WM.NONE] = SFX_SHOOT_STANDARD
	_mod_shoot_sfx[WM.HOMING_LASER] = SFX_SHOOT_HOMING
	_mod_shoot_sfx[WM.MAGNET_MINE] = SFX_SHOOT_HOMING
	_mod_shoot_sfx[WM.REFLECTIVE_SHIELD] = SFX_SHOOT_UTILITY
	_mod_shoot_sfx[WM.CHAIN_LIGHTNING] = SFX_SHOOT_LIGHTNING
	_mod_shoot_sfx[WM.SPREAD_SHOT] = SFX_SHOOT_ENERGY
	_mod_shoot_sfx[WM.PIERCING_BEAM] = SFX_SHOOT_PIERCE
	_mod_shoot_sfx[WM.PHOTON_BEAM] = SFX_SHOOT_PIERCE
	_mod_shoot_sfx[WM.SPECTRAL_BEAM] = SFX_SHOOT_PIERCE
	_mod_shoot_sfx[WM.BOUNCING_BOLT] = SFX_SHOOT_ENERGY
	_mod_shoot_sfx[WM.FREEZE_RAY] = SFX_SHOOT_FREEZE
	_mod_shoot_sfx[WM.TIME_FREEZE_RAY] = SFX_SHOOT_FREEZE
	_mod_shoot_sfx[WM.ACID_TRAIL] = SFX_SHOOT_POISON
	_mod_shoot_sfx[WM.POISON_NOVA] = SFX_SHOOT_POISON
	_mod_shoot_sfx[WM.SHRINK_BEAM] = SFX_SHOOT_POISON
	_mod_shoot_sfx[WM.MEGA_BLAST] = SFX_SHOOT_HEAVY
	_mod_shoot_sfx[WM.SPLITTER_LASER] = SFX_SHOOT_ENERGY
	_mod_shoot_sfx[WM.VAMPIRE_BEAM] = SFX_SHOOT_VAMPIRE
	_mod_shoot_sfx[WM.GRAVITY_WELL_LASER] = SFX_SHOOT_VOID
	_mod_shoot_sfx[WM.RICOCHET_PULSE] = SFX_SHOOT_ENERGY
	_mod_shoot_sfx[WM.PLASMA_NOVA] = SFX_SHOOT_ENERGY
	_mod_shoot_sfx[WM.SNIPER_BEAM] = SFX_SHOOT_PIERCE
	_mod_shoot_sfx[WM.SHRAPNEL_BURST] = SFX_SHOOT_FIRE
	_mod_shoot_sfx[WM.BLAZE_TRAIL] = SFX_SHOOT_FIRE
	_mod_shoot_sfx[WM.TESLA_COIL] = SFX_SHOOT_LIGHTNING
	_mod_shoot_sfx[WM.VOID_RAY] = SFX_SHOOT_VOID
	_mod_shoot_sfx[WM.QUANTUM_OVERDRIVE] = SFX_SHOOT_ENERGY
	_mod_shoot_sfx[WM.BLACK_HOLE_BEAM] = SFX_SHOOT_VOID
	_mod_shoot_sfx[WM.BLACK_HOLE_LAUNCHER] = SFX_SHOOT_HEAVY
	_mod_shoot_sfx[WM.METEOR_STRIKE] = SFX_SHOOT_HEAVY
	_mod_shoot_sfx[WM.LIGHTNING_STORM] = SFX_SHOOT_LIGHTNING
	_mod_shoot_sfx[WM.SHIELD_BUBBLE] = SFX_SHOOT_UTILITY
	_mod_shoot_sfx[WM.TURRET_DEPLOY] = SFX_SHOOT_UTILITY
	_mod_shoot_sfx[WM.GRAVITY_FLIP_FIELD] = SFX_SHOOT_UTILITY
	_mod_shoot_sfx[WM.VOID_RIFT_CUTTER] = SFX_SHOOT_VOID
	_mod_shoot_sfx[WM.MIND_CONTROL_DART] = SFX_SHOOT_UTILITY  # Mind control — soft hypnotic chime

# SFX that get subtle random pitch variation. These are short, percussive
# combat sounds where micro-detuning reads as natural variation rather than
# a tuning error. Melodic SFX (arpeggios, chimes) are excluded so their
# musical intervals stay clean.
const _PITCH_VARIATION_SFX: Array[String] = [
	SFX_SHOOT, SFX_ENEMY_HIT, SFX_DASH_BUMP, SFX_DASH, SFX_ENEMY_DEATH,
	SFX_EXPLOSION, SFX_PULSE_WAVE, SFX_DAMAGE, SFX_CRIT_HIT,
	# Phase 30: Adaptive shoot variants — all get subtle pitch variation
	SFX_SHOOT_STANDARD, SFX_SHOOT_HOMING, SFX_SHOOT_ENERGY, SFX_SHOOT_PIERCE,
	SFX_SHOOT_FREEZE, SFX_SHOOT_POISON, SFX_SHOOT_FIRE, SFX_SHOOT_VOID,
	SFX_SHOOT_LIGHTNING, SFX_SHOOT_HEAVY, SFX_SHOOT_UTILITY, SFX_SHOOT_VAMPIRE,
]
const _PITCH_VARIATION_AMOUNT: float = 0.06  # ±6% — subtle but perceptible


## Play looping biome ambient music.
## Fades in smoothly from silence over MUSIC_FADE_IN_DURATION so biome
## transitions don't pop. If biome music is already playing for the same
## biome, this is a no-op (avoids restarting the loop on redundant calls).
func play_music_biome(biome_id: int) -> void:
	if not _initialized:
		return
	if biome_id == _current_biome and _music_player and _music_player.playing:
		return
	_current_biome = biome_id
	if _boss_music_playing:
		return  # Boss music takes priority
	if not _music_streams.has(biome_id):
		_stop_music_player()
		return
	_stop_boss_music()
	if not _music_player:
		_music_player = AudioStreamPlayer.new()
		_music_player.bus = "Master"
		add_child(_music_player)
	_music_player.stream = _music_streams[biome_id]
	# Start from silence and fade in — prevents the jarring hard-pop of the
	# drone cutting in instantly when crossing a biome boundary.
	_music_player.volume_db = SILENT_DB
	_music_player.play()
	_fade_player(_music_player, music_volume * master_volume, MUSIC_FADE_IN_DURATION, "_music_fade_tween")


## Play boss fight music (overrides biome music).
## Fades in so the boss theme swells rather than snaps — a hard cut from
## ambient drone to driving bass feels mechanical; a short fade sells the
## "the fight begins" moment cinematically.
func play_boss_music() -> void:
	if not _initialized:
		return
	if _boss_music_playing and _boss_music_player and _boss_music_player.playing:
		return
	_boss_music_playing = true
	# Crossfade: biome music fades out (0.5s) while boss music fades in
	# (0.8s). The brief overlap is intentional — a crossfade reads as a
	# cinematic transition, whereas a hard cut from ambient drone to
	# driving bass feels mechanical. The biome player stops itself when
	# its fade-out completes; it'll be restarted on boss defeat.
	_stop_music_player()
	if not _boss_music_player:
		_boss_music_player = AudioStreamPlayer.new()
		_boss_music_player.bus = "Master"
		add_child(_boss_music_player)
	_boss_music_player.stream = _boss_music_stream
	_boss_music_player.volume_db = SILENT_DB
	_boss_music_player.play()
	_fade_player(_boss_music_player, music_volume * master_volume, MUSIC_FADE_IN_DURATION, "_boss_fade_tween")


## Stop boss music and resume biome music.
## The boss player fades out while the biome music fades back in, giving a
## smooth "victory" transition instead of an abrupt switch back to ambient.
func stop_boss_music() -> void:
	if not _boss_music_playing:
		return
	_boss_music_playing = false
	_stop_boss_music()
	# Resume biome music (play_music_biome handles its own fade-in)
	if _current_biome >= 0:
		play_music_biome(_current_biome)


## Stop all music.
func stop_music() -> void:
	_stop_music_player()
	_stop_boss_music()
	_boss_music_playing = false


## Set master volume (0..1).
func set_master_volume(vol: float) -> void:
	master_volume = clampf(vol, 0.0, 1.0)
	_apply_volumes()


## Set SFX volume (0..1).
func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)


## Set music volume (0..1).
func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	_apply_music_volume()


func _apply_volumes() -> void:
	# Master bus volume (clamp away from 0 to avoid -inf from linear_to_db)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	_apply_music_volume()


func _apply_music_volume() -> void:
	# If a fade tween is currently animating the music volume, let it run —
	# killing it would snap the volume, and the fade's target was already
	# computed from the current music_volume * master_volume at start time.
	# The next fade (or a direct call without an active fade) will pick up
	# the new volume. This prevents the settings slider from fighting an
	# in-progress fade. When no fade is active, apply the volume directly.
	var music_fading: bool = _music_fade_tween != null and is_instance_valid(_music_fade_tween) and _music_fade_tween.is_running()
	var boss_fading: bool = _boss_fade_tween != null and is_instance_valid(_boss_fade_tween) and _boss_fade_tween.is_running()
	var vol_db = linear_to_db(maxf(music_volume * master_volume, 0.0001))
	if _music_player and not music_fading:
		_music_player.volume_db = vol_db
	if _boss_music_player and not boss_fading:
		_boss_music_player.volume_db = vol_db


func _stop_music_player() -> void:
	if _music_player:
		# Fade out before stopping so the ambient drone doesn't cut off
		# abruptly when the boss music takes over or the game ends. We
		# tween the volume to silence, then stop the player in the callback.
		# If a fade is already running, kill it first to avoid stacking.
		if _music_fade_tween and is_instance_valid(_music_fade_tween):
			_music_fade_tween.kill()
		_music_fade_tween = create_tween()
		_music_fade_tween.tween_property(_music_player, "volume_db",
			SILENT_DB, MUSIC_FADE_OUT_DURATION) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		var player_to_stop := _music_player
		_music_fade_tween.tween_callback(func():
			if is_instance_valid(player_to_stop):
				player_to_stop.stop()
		)


func _stop_boss_music() -> void:
	if _boss_music_player:
		# Same fade-out treatment as biome music — the boss theme tailing
		# off smoothly reads as "the threat has passed" rather than a hard
		# cut when the boss keels over.
		if _boss_fade_tween and is_instance_valid(_boss_fade_tween):
			_boss_fade_tween.kill()
		_boss_fade_tween = create_tween()
		_boss_fade_tween.tween_property(_boss_music_player, "volume_db",
			SILENT_DB, MUSIC_FADE_OUT_DURATION) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		var player_to_stop := _boss_music_player
		_boss_fade_tween.tween_callback(func():
			if is_instance_valid(player_to_stop):
				player_to_stop.stop()
		)


## Fade a music player's volume to a target linear value over `duration`
## seconds. `tween_property_name` is the name of the member Tween variable
## to store the new tween in (so the previous fade can be killed). Uses
## ease-out so the swell settles gently rather than linearly ramping.
func _fade_player(player: AudioStreamPlayer, target_linear: float,
		duration: float, tween_prop_name: String) -> void:
	if not player:
		return
	# Kill any existing fade on this player to avoid fighting tweens
	var existing: Tween = get(tween_prop_name)
	if existing and is_instance_valid(existing):
		existing.kill()
	var fade_tween := create_tween()
	# Clamp target away from 0 so linear_to_db doesn't return -inf, which
	# would make the tween interpolate through NaN.
	var target_db: float = linear_to_db(maxf(target_linear, 0.0001))
	fade_tween.tween_property(player, "volume_db",
		target_db, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	set(tween_prop_name, fade_tween)


# ─── Signal Handlers ──────────────────────────────────────────────────────────

func _on_boss_spawned(_boss: Node) -> void:
	play_sfx(SFX_BOSS_SPAWN)
	play_boss_music()


func _on_boss_defeated(_boss: Node) -> void:
	play_sfx(SFX_BOSS_DEFEATED)
	stop_boss_music()


func _on_level_up(_level: int) -> void:
	play_sfx(SFX_LEVEL_UP)


func _on_combo_milestone(_combo: int, _tier: int, _color: Color) -> void:
	play_sfx(SFX_COMBO_MILESTONE)


func _on_biome_changed(biome_id: int) -> void:
	play_music_biome(biome_id)


func _on_player_died() -> void:
	play_sfx(SFX_DEATH)


func _on_game_restarted() -> void:
	_boss_music_playing = false
	_stop_boss_music()
	_current_biome = -1
	# Phase 30: Reset dynamic music intensity
	_music_intensity_current = 0.0


# ═════════════════════════════════════════════════════════════════════════════
# PROCEDURAL SOUND GENERATION
# ═════════════════════════════════════════════════════════════════════════════

func _generate_all_sfx() -> void:
	_sfx_streams[SFX_SHOOT] = _gen_blip(800.0, 0.08, 0.3)
	_sfx_streams[SFX_DASH] = _gen_noise_sweep(0.18, 0.4)
	_sfx_streams[SFX_PICKUP] = _gen_chime([523.0, 784.0], 0.15, 0.35)
	_sfx_streams[SFX_PICKUP_RARE] = _gen_chime([523.0, 659.0, 784.0, 1047.0], 0.3, 0.4)
	_sfx_streams[SFX_LEVEL_UP] = _gen_arpeggio([392.0, 523.0, 659.0, 784.0], 0.08, 0.35)
	_sfx_streams[SFX_DAMAGE] = _gen_noise_hit(0.15, 0.5)
	_sfx_streams[SFX_DEATH] = _gen_descending(400.0, 80.0, 0.6, 0.4)
	_sfx_streams[SFX_ENEMY_HIT] = _gen_blip(300.0, 0.04, 0.2)
	# ── Crit hit SFX ── A bright, rising-pitch "ping" with a quick attack
	# and fast decay. Higher fundamental (880Hz) than the normal enemy_hit
	# blip (300Hz) so it cuts through the mix as a distinct, rewarding
	# "ka-ching" — the sonic equivalent of the gold crit damage number.
	# A short second harmonic (1320Hz) gives it a bell-like ring that
	# reads as "special" against the flat normal-hit blip.
	_sfx_streams[SFX_CRIT_HIT] = _gen_crit_ping()
	_sfx_streams[SFX_ENEMY_DEATH] = _gen_pop(0.12, 0.35)
	_sfx_streams[SFX_BOSS_SPAWN] = _gen_rumble(60.0, 1.0, 0.6)
	_sfx_streams[SFX_BOSS_DEFEATED] = _gen_arpeggio([784.0, 988.0, 1175.0, 1568.0], 0.1, 0.4)
	_sfx_streams[SFX_EXPLOSION] = _gen_explosion(0.4, 0.6)
	_sfx_streams[SFX_PULSE_WAVE] = _gen_whoosh(0.3, 0.4)
	_sfx_streams[SFX_HEAL] = _gen_chime([659.0, 988.0], 0.2, 0.3)
	_sfx_streams[SFX_DASH_BUMP] = _gen_blip(200.0, 0.06, 0.3)
	_sfx_streams[SFX_COMBO_MILESTONE] = _gen_arpeggio([523.0, 659.0, 784.0], 0.06, 0.35)
	_sfx_streams[SFX_UI_CLICK] = _gen_blip(600.0, 0.03, 0.2)
	# UI hover — softer, shorter, higher-pitched than the click. The lower
	# volume (0.08 vs 0.2) and shorter duration (0.018s vs 0.03s) make it
	# read as a subtle tick that doesn't draw attention to itself on every
	# button pass, while the higher pitch (900Hz vs 600Hz) keeps it distinct
	# from the click so the two events are audibly different.
	_sfx_streams[SFX_UI_HOVER] = _gen_blip(900.0, 0.018, 0.08)
	_sfx_streams[SFX_MUTATION] = _gen_chime([440.0, 554.0, 659.0], 0.25, 0.3)
	_sfx_streams[SFX_RIFT] = _gen_whoosh(0.5, 0.35)
	_sfx_streams[SFX_THUNDER] = _gen_noise_hit(0.3, 0.7)
	_sfx_streams[SFX_REVIVE] = _gen_arpeggio([392.0, 523.0, 659.0, 784.0, 988.0], 0.07, 0.35)
	_sfx_streams[SFX_PET] = _gen_blip(900.0, 0.05, 0.25)
	_sfx_streams[SFX_CRAFT] = _gen_chime([659.0, 880.0], 0.12, 0.3)
	_sfx_streams[SFX_ARENA] = _gen_rumble(50.0, 1.2, 0.5)
	# Phase 24: Shield Bubble — a warm protective chime
	_sfx_streams[SFX_SHIELD] = _gen_chime([523.0, 784.0, 1047.0], 0.3, 0.35)
	# ── Phase 26: World interaction SFX ──
	# Treasure chest open — a triumphant ascending arpeggio with shimmer
	_sfx_streams[SFX_CHEST_OPEN] = _gen_arpeggio([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.06, 0.38)
	# Trapped chest — a discordant surprise buzz (low + detuned high)
	_sfx_streams[SFX_CHEST_TRAP] = _gen_descending(200.0, 120.0, 0.25, 0.45)
	# Lore stone — a deep mystical chime (two low notes + shimmer)
	_sfx_streams[SFX_LORE] = _gen_chime([330.0, 440.0, 554.0], 0.4, 0.35)
	# Wildlife caught — a quick pleasant pop (shorter than enemy death)
	_sfx_streams[SFX_WILDLIFE] = _gen_pop(0.06, 0.22)
	# Interactive switch — a mechanical click (short blip with low pitch)
	_sfx_streams[SFX_SWITCH] = _gen_blip(440.0, 0.04, 0.20)
	# Breakable wall — a crumbling noise hit (longer than switch, rougher than explosion)
	_sfx_streams[SFX_BREAKABLE] = _gen_noise_hit(0.25, 0.45)
	# Ping — a quick sonar-style high blip
	_sfx_streams[SFX_PING] = _gen_blip(1400.0, 0.05, 0.20)
	# Dialogue — a soft warm chime (two notes, gentle)
	_sfx_streams[SFX_DIALOGUE] = _gen_chime([523.0, 659.0], 0.08, 0.18)
	# Fast travel — a teleport whoosh + shimmer (upward sweep)
	_sfx_streams[SFX_FAST_TRAVEL] = _gen_whoosh(0.5, 0.40)
	# World boss — a deeper, longer version of boss_spawn rumble
	_sfx_streams[SFX_WORLD_BOSS] = _gen_rumble(45.0, 1.4, 0.65)
	# ── Phase 30: Adaptive shoot SFX — per-mod shoot sound variants ──
	# Each variant has a distinct timbre so the player hears the weapon change.
	_sfx_streams[SFX_SHOOT_STANDARD] = _sfx_streams[SFX_SHOOT]  # Alias to default blip
	_sfx_streams[SFX_SHOOT_HOMING] = _gen_blip(1200.0, 0.10, 0.28)        # High whistle
	_sfx_streams[SFX_SHOOT_ENERGY] = _gen_blip(700.0, 0.07, 0.30)         # Mid energy bolt
	_sfx_streams[SFX_SHOOT_PIERCE] = _gen_blip(1600.0, 0.05, 0.22)        # Thin high whine
	_sfx_streams[SFX_SHOOT_FREEZE] = _gen_chime([1047.0, 1319.0], 0.18, 0.28)  # Ice chime
	_sfx_streams[SFX_SHOOT_POISON] = _gen_noise_hit(0.10, 0.30)          # Acid hiss
	_sfx_streams[SFX_SHOOT_FIRE] = _gen_noise_sweep(0.14, 0.32)          # Fire whoosh
	_sfx_streams[SFX_SHOOT_VOID] = _gen_descending(220.0, 110.0, 0.18, 0.30)  # Void pulse
	_sfx_streams[SFX_SHOOT_LIGHTNING] = _gen_noise_hit(0.06, 0.32)        # Electric zap
	_sfx_streams[SFX_SHOOT_HEAVY] = _gen_rumble(80.0, 0.20, 0.45)         # Heavy cannon
	_sfx_streams[SFX_SHOOT_UTILITY] = _gen_chime([784.0, 988.0], 0.15, 0.25)  # Soft deploy chime
	_sfx_streams[SFX_SHOOT_VAMPIRE] = _gen_descending(330.0, 260.0, 0.12, 0.30)  # Crimson hum
	# ── Enemy ability SFX ── Distinct audio for special enemy abilities
	# Teleport — a quick upward sweep + shimmer (temporal displacement feel)
	_sfx_streams[SFX_TELEPORT] = _gen_whoosh(0.22, 0.32)
	# Cloak — a soft ethereal chime (stealth activate/deactivate)
	_sfx_streams[SFX_CLOAK] = _gen_chime([880.0, 1175.0], 0.20, 0.22)
	# Consumable — a distinct potion-swirl sound (short descending + chime)
	_sfx_streams[SFX_CONSUMABLE] = _gen_descending(660.0, 440.0, 0.15, 0.30)
	# Pet evolution — a triumphant ascending arpeggio (major milestone)
	_sfx_streams[SFX_PET_EVOLVE] = _gen_arpeggio([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.07, 0.40)


func _generate_all_music() -> void:
	# Generate ambient drone music for each biome
	# Each biome gets a unique base frequency and harmonic set
	_music_streams[GameConstants.Biome.GRASS] = _gen_ambient_drone(110.0, 220.0, 4.0, 0.3)
	_music_streams[GameConstants.Biome.DESERT] = _gen_ambient_drone(146.83, 293.66, 4.0, 0.3)
	_music_streams[GameConstants.Biome.WATER] = _gen_ambient_drone(98.0, 196.0, 5.0, 0.25)
	_music_streams[GameConstants.Biome.LAVA] = _gen_ambient_drone(73.42, 146.83, 3.0, 0.35)
	_music_streams[GameConstants.Biome.FOREST] = _gen_ambient_drone(130.81, 261.63, 4.5, 0.28)
	_music_streams[GameConstants.Biome.CRYSTAL] = _gen_ambient_drone(164.81, 329.63, 5.0, 0.25)
	_music_streams[GameConstants.Biome.SNOW] = _gen_ambient_drone(87.31, 174.61, 6.0, 0.2)
	_music_streams[GameConstants.Biome.SWAMP] = _gen_ambient_drone(82.41, 164.81, 3.5, 0.3)
	_music_streams[GameConstants.Biome.ALIEN] = _gen_ambient_drone(116.54, 233.08, 4.0, 0.32)
	_music_streams[GameConstants.Biome.MUSHROOM] = _gen_ambient_drone(138.59, 277.18, 4.0, 0.28)
	_music_streams[GameConstants.Biome.FLOATING_ISLANDS] = _gen_ambient_drone(155.56, 311.13, 5.5, 0.22)
	_music_streams[GameConstants.Biome.TOXIC_BOG] = _gen_ambient_drone(77.78, 155.56, 3.0, 0.33)
	# ── Phase 22: New biome music ──
	# Deep Ocean — deep, slow, watery drone with low harmonic.
	_music_streams[GameConstants.Biome.DEEP_OCEAN] = _gen_ambient_drone(65.41, 130.81, 7.0, 0.18)
	# Volcano Core — aggressive low rumble, short decay for tension.
	_music_streams[GameConstants.Biome.VOLCANO_CORE] = _gen_ambient_drone(61.74, 116.54, 2.5, 0.38)
	# Sky Citadel — bright, airy, high drone for floating serenity.
	_music_streams[GameConstants.Biome.SKY_CITADEL] = _gen_ambient_drone(196.0, 392.0, 6.5, 0.18)
	# Digital Grid — dissonant, tense, mid-range for cyberpunk feel.
	_music_streams[GameConstants.Biome.DIGITAL_GRID] = _gen_ambient_drone(123.47, 246.94, 3.5, 0.3)
	# Crystal Caverns — bright, shimmering, high-pitched for prismatic clarity.
	_music_streams[GameConstants.Biome.CRYSTAL_CAVERNS] = _gen_ambient_drone(174.61, 349.23, 5.5, 0.22)
	# Ancient Ruins — slow, dusty, mid-low drone for age and mystery.
	_music_streams[GameConstants.Biome.ANCIENT_RUINS] = _gen_ambient_drone(92.5, 185.0, 5.0, 0.25)
	# Underground — deep, dark, very low drone for claustrophobic caves.
	_music_streams[GameConstants.Biome.UNDERGROUND] = _gen_ambient_drone(55.0, 110.0, 7.5, 0.15)

	# Boss music — intense, fast-tempo drone
	_boss_music_stream = _gen_boss_music()


# ─── Wave Generation Helpers ──────────────────────────────────────────────────

## Generate a short blip with descending pitch (laser shot).
func _gen_blip(freq: float, duration: float, vol: float) -> AudioStreamWAV:
	var n = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t = float(i) / SAMPLE_RATE
		var pitch_decay = 1.0 - (t / duration) * 0.5
		var sample = sin(t * freq * pitch_decay * TAU)
		# Envelope: quick attack, exponential decay
		var env = exp(-t * 15.0)
		sample *= vol * env
		_pack_sample(data, i, sample)
	return _make_wav(data)


## Generate a noise sweep (dash sound).
func _gen_noise_sweep(duration: float, vol: float) -> AudioStreamWAV:
	var n = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(n * 2)
	var prev = 0.0
	for i in n:
		var t = float(i) / SAMPLE_RATE
		# Filtered noise with downward sweep
		var noise = (randf() * 2.0 - 1.0)
		prev = prev * 0.85 + noise * 0.15
		var sweep = sin(t * (200.0 + 800.0 * (1.0 - t / duration)) * TAU)
		var sample = (prev * 0.6 + sweep * 0.4) * vol
		# Envelope
		var env: float
		if t < 0.02:
			env = t / 0.02
		else:
			env = exp(-(t - 0.02) * 8.0)
		sample *= env
		_pack_sample(data, i, sample)
	return _make_wav(data)


## Generate a pleasant chime (pickup, heal, craft).
func _gen_chime(freqs: Array, duration: float, vol: float) -> AudioStreamWAV:
	var n = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t = float(i) / SAMPLE_RATE
		var sample = 0.0
		for j in freqs.size():
			var note_start = j * (duration / freqs.size()) * 0.3
			var local_t = t - note_start
			if local_t > 0:
				var env = exp(-local_t * 6.0)
				sample += sin(local_t * freqs[j] * TAU) * env * 0.7 / freqs.size()
		# Overall envelope
		var env: float
		if t < 0.01:
			env = t / 0.01
		else:
			env = 1.0
		sample *= vol * env
		_pack_sample(data, i, sample)
	return _make_wav(data)


## Generate an ascending arpeggio (level up, combo milestone).
func _gen_arpeggio(freqs: Array, note_dur: float, vol: float) -> AudioStreamWAV:
	var total_dur = note_dur * freqs.size() + 0.3
	var n = int(total_dur * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t = float(i) / SAMPLE_RATE
		var sample = 0.0
		for j in freqs.size():
			var note_start = j * note_dur
			var local_t = t - note_start
			if local_t > 0 and local_t < note_dur + 0.3:
				var env = exp(-local_t * 5.0)
				sample += sin(local_t * freqs[j] * TAU) * env * 0.6 / freqs.size()
		sample *= vol
		_pack_sample(data, i, sample)
	return _make_wav(data)


## Generate a noise hit (damage, thunder).
func _gen_noise_hit(duration: float, vol: float) -> AudioStreamWAV:
	var n = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(n * 2)
	var prev = 0.0
	for i in n:
		var t = float(i) / SAMPLE_RATE
		var noise = (randf() * 2.0 - 1.0)
		prev = prev * 0.6 + noise * 0.4
		var env = exp(-t * 10.0)
		var sample = prev * vol * env
		_pack_sample(data, i, sample)
	return _make_wav(data)


## Generate a descending tone (death sound).
func _gen_descending(freq_start: float, freq_end: float, duration: float, vol: float) -> AudioStreamWAV:
	var n = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t = float(i) / SAMPLE_RATE
		var progress = t / duration
		var freq = lerpf(freq_start, freq_end, progress)
		var sample = sin(t * freq * TAU)
		# Add slight vibrato
		sample += sin(t * freq * TAU + sin(t * 10.0) * 3.0) * 0.3
		sample *= vol * exp(-t * 2.0)
		_pack_sample(data, i, sample)
	return _make_wav(data)


## Generate a pop sound (enemy death bubble).
func _gen_pop(duration: float, vol: float) -> AudioStreamWAV:
	var n = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t = float(i) / SAMPLE_RATE
		var progress = t / duration
		var freq = lerpf(200.0, 600.0, progress)
		var sample = sin(t * freq * TAU)
		var env = sin(progress * PI)  # Rise and fall
		sample *= vol * env
		_pack_sample(data, i, sample)
	return _make_wav(data)


## Generate a bright "crit ping" — a short bell-like rising chime that
## signals a critical hit. Two stacked harmonics (880Hz + 1320Hz) with a
## quick exponential decay give it a metallic "ka-ching" ring that cuts
## through the combat mix and reads as a reward cue. The pitch rises
## slightly over the note (880→1100Hz) for an ascending "shiny" feel,
## mirroring the gold crit visual language. Duration is short (~90ms) so
## it doesn't clutter rapid-fire combat.
func _gen_crit_ping() -> AudioStreamWAV:
	var duration: float = 0.09
	var vol: float = 0.32
	var n = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t = float(i) / SAMPLE_RATE
		var progress = t / duration
		# Rising fundamental (880 → 1100 Hz) for an ascending "shiny" feel
		var freq = lerpf(880.0, 1100.0, progress)
		var fundamental = sin(t * freq * TAU)
		# Perfect-fifth harmonic (1.5x) for a bell-like timbre
		var harmonic = sin(t * freq * 1.5 * TAU) * 0.4
		var sample = (fundamental * 0.6 + harmonic * 0.4)
		# Quick attack, fast exponential decay so the ping is crisp, not lingering
		var env: float
		if t < 0.004:
			env = t / 0.004
		else:
			env = exp(-(t - 0.004) * 28.0)
		sample *= vol * env
		_pack_sample(data, i, sample)
	return _make_wav(data)


## Generate a low rumble (boss spawn, arena rise).
func _gen_rumble(freq: float, duration: float, vol: float) -> AudioStreamWAV:
	var n = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t = float(i) / SAMPLE_RATE
		var sample = sin(t * freq * TAU) * 0.6
		sample += sin(t * freq * 1.5 * TAU) * 0.3
		sample += (randf() * 2.0 - 1.0) * 0.15  # Sub-rumble noise
		var env: float
		if t < 0.1:
			env = t / 0.1
		elif t > duration - 0.2:
			env = (duration - t) / 0.2
		else:
			env = 1.0
		sample *= vol * env
		_pack_sample(data, i, sample)
	return _make_wav(data)


## Generate an explosion sound (noise burst + low rumble).
func _gen_explosion(duration: float, vol: float) -> AudioStreamWAV:
	var n = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(n * 2)
	var prev = 0.0
	for i in n:
		var t = float(i) / SAMPLE_RATE
		var noise = (randf() * 2.0 - 1.0)
		prev = prev * 0.5 + noise * 0.5
		var rumble = sin(t * 40.0 * TAU) * 0.5
		var env = exp(-t * 5.0)
		var sample = (prev * 0.6 + rumble * 0.4) * vol * env
		_pack_sample(data, i, sample)
	return _make_wav(data)


## Generate a whoosh (pulse wave, rift).
func _gen_whoosh(duration: float, vol: float) -> AudioStreamWAV:
	var n = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(n * 2)
	var prev = 0.0
	for i in n:
		var t = float(i) / SAMPLE_RATE
		var progress = t / duration
		var noise = (randf() * 2.0 - 1.0)
		prev = prev * 0.8 + noise * 0.2
		# Filtered noise with rising then falling pitch
		var sweep_freq = 100.0 + 400.0 * sin(progress * PI)
		var sweep = sin(t * sweep_freq * TAU)
		var sample = (prev * 0.5 + sweep * 0.5) * vol * sin(progress * PI)
		_pack_sample(data, i, sample)
	return _make_wav(data)


## Generate a looping ambient drone (biome music).
func _gen_ambient_drone(base_freq: float, harmonic_freq: float, duration: float, vol: float) -> AudioStreamWAV:
	var n = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t = float(i) / SAMPLE_RATE
		var progress = t / duration
		# Base drone
		var sample = sin(t * base_freq * TAU) * 0.5
		# Harmonic
		sample += sin(t * harmonic_freq * TAU) * 0.25
		# Sub harmonic for richness
		sample += sin(t * base_freq * 0.5 * TAU) * 0.2
		# Slow LFO modulation for breathing effect
		var lfo = sin(t * 0.5 * TAU) * 0.15
		sample *= 1.0 + lfo
		# Fade in/out at loop boundaries (seamless loop)
		var env = 1.0
		var fade_dur = 0.5
		if progress < fade_dur / duration:
			env = progress / (fade_dur / duration)
		elif progress > 1.0 - fade_dur / duration:
			env = (1.0 - progress) / (fade_dur / duration)
		sample *= vol * env
		_pack_sample(data, i, sample)
	var wav = _make_wav(data)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav


## Generate boss music — intense, driving rhythm.
func _gen_boss_music() -> AudioStreamWAV:
	var duration = 8.0  # 8-second loop
	var n = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(n * 2)
	# Tempo: ~120 BPM = 2 beats/sec → 16 beats in 8 seconds
	var beat_dur = 0.5
	for i in n:
		var t = float(i) / SAMPLE_RATE
		# Driving bass pulse on every beat
		var beat_phase = fmod(t, beat_dur)
		var beat_num = int(t / beat_dur) % 16
		var bass_env = exp(-beat_phase * 8.0)
		var bass_freq = 55.0 if beat_num % 2 == 0 else 65.0
		var sample = sin(t * bass_freq * TAU) * bass_env * 0.5
		# Tension layer — dissonant high tone
		sample += sin(t * 330.0 * TAU) * 0.15
		sample += sin(t * 311.0 * TAU) * 0.12  # Slightly dissonant
		# Percussive noise on beats
		if beat_phase < 0.05:
			sample += (randf() * 2.0 - 1.0) * exp(-beat_phase * 30.0) * 0.3
		# Build intensity in second half
		var intensity = 1.0 + 0.3 * sin(t * 0.25 * TAU)
		sample *= intensity * 0.35
		# Seamless loop fade
		var progress = t / duration
		var fade_dur = 0.3
		var env = 1.0
		if progress < fade_dur / duration:
			env = progress / (fade_dur / duration)
		elif progress > 1.0 - fade_dur / duration:
			env = (1.0 - progress) / (fade_dur / duration)
		sample *= env
		_pack_sample(data, i, sample)
	var wav = _make_wav(data)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav


# ─── Utility ──────────────────────────────────────────────────────────────────

func _pack_sample(data: PackedByteArray, index: int, sample: float) -> void:
	var s = clampi(int(sample * 32767), -32768, 32767)
	data[index * 2] = s & 0xFF
	data[index * 2 + 1] = (s >> 8) & 0xFF


func _make_wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav