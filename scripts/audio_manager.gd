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
# Pickup streak milestone — a warm golden chime distinct from the combat
# combo milestone. Uses a major triad (C-E-G) at a higher octave so it
# reads as a "collection reward" rather than a "kill reward".
const SFX_PICKUP_STREAK: String = "pickup_streak"
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
# ── Dash cooldown ready chime ── A short, bright two-note "ding" that fires
#    when the dash cooldown completes. The first note (G5=784Hz) resolves to
#    a higher note (C6=1047Hz) — a perfect fifth → octave leap that reads as
#    "ready!" in the player's ear without being intrusive. Lower volume (0.15)
#    than combat SFX so it doesn't compete with the action. Only plays once
#    per cooldown cycle (triggered by the cooldown indicator's edge detection).
const SFX_DASH_READY: String = "dash_ready"

# ── Low-HP heartbeat SFX ── A procedural "lub-dub" heartbeat sound that pairs
#    with the existing visual heartbeat (mesh scale pulse + emission flash)
#    in player.gd / player2_zerp.gd. Two low-frequency thumps per beat: the
#    first ("lub") is louder and longer, the second ("dub") is softer and
#    shorter — the classic cardiac auscultation pattern. A low sine fundamental
#    (~55 Hz) plus a slightly higher body (~110 Hz) gives it a felt-in-the-chest
#    quality rather than a tonal beep. play_heartbeat_sfx(intensity) scales the
#    volume by how close the player is to death (0..1), so the heartbeat grows
#    louder and more urgent as HP drops — mirroring the visual urgency.
const SFX_HEARTBEAT: String = "heartbeat"
# Enemy materialization — a short descending energy-coalesce sound for when
# enemies finish spawning (after the warning ring). Quieter than boss_spawn
# so it doesn't overwhelm during heavy waves, but audible enough to give the
# materialization particles an audio identity.
const SFX_SPAWN_IN: String = "spawn_in"
# Variant promotion — a distinctive ascending shimmer for when an enemy is
# promoted to Golden or Champion tier. Higher pitch + longer than a normal
# spawn so rare variants feel special when they appear.
const SFX_VARIANT_PROMOTE: String = "variant_promote"
# Variant defeat — a triumphant descending arpeggio for killing Golden/Champion
# enemies. Rewards the player for taking down a tough variant with a satisfying
# "elite down" cue, distinct from the normal enemy death sound.
const SFX_VARIANT_DEFEAT: String = "variant_defeat"

# ── Buff expiration SFX ── A short descending chime that plays when a monolith
#    buff (Speed Surge, Power Surge, Wisdom Aura) expires. The descending pitch
#    conveys loss — the player's power is fading — paired with the existing
#    shield-break shatter particles. Quiet (0.18) so it doesn't feel punishing.
const SFX_BUFF_EXPIRE: String = "buff_expire"
# ── Craft failure SFX ── A short low-pitched buzz that plays when a crafting
#    attempt fails (invalid recipe or insufficient materials). The dissonant
#    low tone immediately communicates "that didn't work" without being harsh.
#    Used in both the weapon mod crafting menu and the equipment crafting menu.
const SFX_CRAFT_FAIL: String = "craft_fail"
# ── Pulse wave ready SFX ── Same bright two-note chime as SFX_DASH_READY but at
#    a higher pitch (C6→E6) so the player can distinguish "pulse ready" from
#    "dash ready" by ear alone. Both abilities have cooldowns and the player
#    should know when each is available without looking at the HUD.
const SFX_PULSE_READY: String = "pulse_ready"
# ── Enemy alert SFX ── A short ascending blip (440→880 Hz over 0.08s) that
#    plays when an enemy first detects the player. Gives off-screen detection
#    an audio presence so the player knows they've been spotted even when the
#    "!" indicator isn't visible. Quiet (0.10) so simultaneous detections from
#    a pack don't overwhelm. Pitch-rises so it reads as "noticed you!"
const SFX_ENEMY_ALERT: String = "enemy_alert"
# ── Enhancement Pack 12: Combo break SFX ── A descending "streak lost" tone
# (G4→D4→A3, 392→294→220 Hz) that conveys a streak ending. Short (0.14s) and
# quiet (0.15) so it's noticeable but not punishing. Only fires when a
# meaningful streak (≥5 kills / ≥5 pickups / ≥3 crits) expires — not on
# every trivial 2-kill combo timeout. The descending minor interval reads as
# "something good just ended" without being harsh like the damage sound.
const SFX_COMBO_BREAK: String = "combo_break"

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

# ── Enhancement Pack 13: Camera shutter SFX ── A short mechanical click-clack
#    for the photo mode screenshot capture. Two rapid noise bursts (~0.02s
#    each, 0.02s gap) mimic a camera shutter — the universal audio shorthand
#    for "photo taken" (every smartphone and camera uses a variant of this).
#    Low volume (0.15) so it's a subtle confirmation, not a distraction.
const SFX_SHUTTER: String = "shutter"
# ── Enhancement Pack 16: World Life & Companion Event Feedback ──
# Pet emote — a soft expressive blip whose pitch varies per emote type so
# the player can hear the pet's mood (happy=high, angry=low, love=warm,
# scared=trembling, curious=questioning, sleepy=low-long, hungry=pulsing).
# The base sound is a gentle sine blip; pitch shifting via play_sfx_pitched
# gives each emotion its own sonic identity without 7 separate streams.
const SFX_PET_EMOTE: String = "pet_emote"
# Merchant arrival — a welcoming melodic chime (ascending major triad) that
# reads as \"a friend has arrived.\" Distinct from UI clicks and combat SFX
# so the player notices the merchant even during combat.
const SFX_MERCHANT: String = "merchant"
# Enemy dodge — a quick lateral whoosh (short noise sweep) that conveys
# \"your attack missed\" — the air-distortion sound of something narrowly
# evading a projectile. Distinct from the shield hit (solid thunk) and the
# enemy hit (blip) so the player can identify an Evasive variant by ear.
const SFX_DODGE: String = "dodge"
# Enemy near-death — a subtle metallic groan (low descending tone) that
# plays when an enemy enters the near-death shudder state (<10% HP). Quiet
# and short so it doesn't stack into noise when multiple enemies are dying.
# Reads as \"this enemy is on its last legs\" — the audio cue for focus fire.
const SFX_NEAR_DEATH: String = "near_death"
# ── Enhancement Pack 20: Near-miss graze ── A subtle, very short airy whoosh
# (0.06s noise sweep at low volume 0.12) that plays when an enemy projectile
# passes close to the player without hitting. It's the audio cue for "that
# was close" — conveying danger narrowly avoided. Shorter and quieter than
# SFX_DODGE (0.08s, 0.18) so it doesn't compete with combat sounds. The
# noise-sweep timbre conveys air disturbance — the bolt's wake brushing past.
const SFX_GRAZE: String = "graze"

# ── Enhancement Pack 21: Environmental & combat action SFX ───────────────────
# SFX_LAND — a muffled thud for when Zorp touches down after being airborne
# (reverse-gravity exit, bounce pad, big fall). Scales in volume with fall
# distance — a gentle hop is barely audible, a 20m slam is a solid thump.
# Uses a low-frequency noise hit (80 Hz body, 0.10s, short decay) so it reads
# as a physical impact on terrain rather than a tonal note. Pairs with the
# existing landing squash + dust puff + camera shake.
const SFX_LAND: String = "land"

# SFX_BUFF_ACTIVATE — a warm ascending major arpeggio (C5→E5→G5→C6) distinct
# from SFX_HEAL (two-note chime). Monolith buffs (Speed Surge, Power Surge,
# Wisdom Aura) previously used the generic heal sound — now they get a
# triumphant 4-note arpeggio that conveys "you just got powered up" rather
# than "you just got healed." The ascending major triad is the universal audio
# shorthand for a positive status change in games.
const SFX_BUFF_ACTIVATE: String = "buff_activate"

# SFX_PULL — a deep descending gravitational whomp (90→45 Hz, 0.30s) that
# plays when the Graviton activates its gravity pull. The low-frequency sweep
# conveys a massive force engaging — the sound of space being bent. Pairs
# with the existing visual pull ring that appears on the ground. Previously
# the Graviton's pull activation had a visual warning ring + emission change
# but no audio, making it easy to miss the pull starting until the player was
# already being dragged in.
const SFX_PULL: String = "pull"

# SFX_WILDLIFE_FLEE — a tiny startled chirp (0.05s, high-pitched 1400 Hz blip
# at 0.10 volume) that plays when a wildlife creature begins fleeing. The
# short, high sound reads as a small animal's startled reaction — the audio
# cue for "it saw you and is running." Previously the flee state had only a
# visual emission brightening but no audio, so the player could walk past
# wildlife without realizing they'd scared it.
const SFX_WILDLIFE_FLEE: String = "wildlife_flee"

# ── Enhancement Pack 23: Loot drop feedback SFX ───────────────────────────────
# SFX_RARE_DROP — a shimmering ascending chime (E5→G5→B5→E6, 659→784→988→1319 Hz)
# that plays when a rare crafting material drops from an enemy. Rare materials
# are added directly to inventory (no physical collectible), so previously the
# only feedback was a text message — the player might miss the drop entirely
# during combat. This chime is pitched higher than SFX_PICKUP_RARE (which plays
# on physical collectible pickup) so the player can distinguish "something
# valuable dropped from this enemy" from "I picked up a rare item." Moderate
# volume (0.25) so it's audible over combat but doesn't overwhelm.
const SFX_RARE_DROP: String = "rare_drop"

# SFX_PET_STONE_DROP — a warm magical chime (A4→C5→E5, 440→523→659 Hz) that
# plays when a pet evolution stone drops from an enemy. Pet stones are rare
# (1.5% normal, 100% boss) and the player should know immediately when one
# drops so they can spot the collectible on the ground. The magical timbre
# (major triad) matches the mystical nature of evolution stones. Slightly
# quieter (0.22) than SFX_RARE_DROP since the collectible itself also plays
# SFX_PICKUP_RARE when picked up — the drop SFX is a "look over there" cue,
# not a "you got it" cue.
const SFX_PET_STONE_DROP: String = "pet_stone_drop"

# SFX_CRAFT_DROP — a subtle material-friendly blip (880 Hz, 0.04s, 0.12 vol)
# that plays when a crafting material drops from an enemy. Quieter and shorter
# than the rare drop and pet stone sounds since crafting materials are common
# (12% drop rate) — playing a loud sound on every material drop would be
# noisy during heavy combat. The blip is just loud enough to register
# subconsciously as "something shiny fell from this enemy."
const SFX_CRAFT_DROP: String = "craft_drop"

# ── Player footstep SFX ── A short, soft, muffled thud (~0.04s) that plays
#    when Zorp's walk-bob cycle hits the "foot down" phase (the bottom of
#    each |sin| hump). The sound is a low-frequency filtered-noise click —
#    the universal audio shorthand for a soft step on alien terrain. Very
#    quiet (0.10) so it sits under the biome ambient music and combat SFX
#    without being annoying during long exploration walks. Pitch varies
#    subtly per step (via _PITCH_VARIATION_SFX) so a sprint doesn't sound
#    like a metronome. The footstep only fires when the player is moving
#    at a meaningful speed (above the idle threshold) and not dashing /
#    sliding (those have their own SFX), so standing still is silent.
const SFX_FOOTSTEP: String = "footstep"

# ── Enemy stagger SFX ── A short metallic "recoil" hit (0.10s, 0.25 vol)
#    that plays when an enemy's attack windup is interrupted by taking
#    damage. The sound is a quick descending metallic ping — conveys the
#    enemy's attack being knocked off-balance. Pitch variation keeps
#    successive staggers from sounding identical.
const SFX_STAGGER: String = "stagger"

# ── Collectible magnet hum SFX ── A very short (0.08s) soft sine pulse
#    at a warm mid-range frequency (440 Hz, 0.08 vol) that plays
#    periodically when a collectible is being magnetically vacuumed
#    toward the player. Intentionally very quiet so multiple simultaneous
#    vacuums don't stack into noise. Pitch variation makes each blip
#    feel slightly different, avoiding a mechanical beep.
const SFX_MAGNET_HUM: String = "magnet_hum"

# ── Enhancement Pack 38: Enemy enrage SFX ── A menacing mid-range growl
#    (descending 220→110 Hz with a slight harmonic at 440 Hz, 0.18s) that
#    plays when a regular enemy enters the enrage state (<25% HP). Pairs
#    with the existing red rage particle burst and color shift. The growl
#    is shorter and quieter than the boss enrage roar (SFX_BOSS_SPAWN) so
#    it doesn't overwhelm when multiple enemies enrage simultaneously during
#    AoE combat. The descending pitch reads as "this enemy is getting
#    dangerous" — the universal audio shorthand for a rising threat.
const SFX_ENRAGE: String = "enrage"

# ── Enhancement Pack 38: Prestige fanfare SFX ── A triumphant 5-note
#    ascending fanfare (C4→E4→G4→C5→E5, 0.10s per note) with full volume
#    (0.35) that plays on prestige — one of the biggest milestones in the
#    game. Previously prestige reused SFX_PET_EVOLVE (a 3-note arpeggio at
#    0.30 volume) which wasn't triumphant enough for such a major event.
#    The wider range (two octaves), more notes (5 vs 3), and brighter
#    top end (E5=659 Hz vs C5=523 Hz) make this feel like a true
#    celebration — the "you beat the game and chose to continue" fanfare.
const SFX_PRESTIGE: String = "prestige"

# ── Enhancement Pack 39: Time slow field enter SFX ── A soft descending chime
#    (G5→E5→C5, 784→659→523 Hz, 0.10s, 0.12 vol) that plays when the player
#    enters a Time Warden's slowing field. The gentle descending interval
#    conveys "time is bending" — a subtle temporal warp cue. Very quiet so
#    it doesn't compete with combat sounds, and only fires on the transition
#    (entering/exiting the field), not continuously while inside.
const SFX_TIME_SLOW_ENTER: String = "time_slow_enter"

# ── Enhancement Pack 39: Gravity charge SFX ── A deep descending rumble
#    (70→35 Hz over 0.50s, 0.35 vol) that plays when a Gravity Elemental
#    begins charging its repel field. The very low frequency sweep conveys
#    massive gravitational energy building up — the sound of space warping.
#    Previously the charge used SFX_ARENA (a generic arena hazard rumble at
#    50 Hz) which was shared with boss arena construction and didn't convey
#    the unique gravitic nature of the attack.
const SFX_GRAVITY_CHARGE: String = "gravity_charge"

# ── Enhancement Pack 39: Echo Knight phantom spawn SFX ── An ethereal
#    shimmering chime (B4→D5→F#5, 494→587→740 Hz, 0.18s, 0.18 vol) that
#    plays when an Echo Knight summons its shadow copies. The augmented
#    triad (B-D-F#) has an unsettled, "otherworldly" quality that conveys
#    phantoms splitting from a real body. Quiet and short so it doesn't
#    compete with combat sounds. Previously the shadow copies appeared
#    with no audio at all — the player had no cue that copies had spawned.
const SFX_PHANTOM_SPAWN: String = "phantom_spawn"

# ── Enhancement Pack 41: Deployable system feedback SFX ──
# Shield bubble hit — a crisp metallic \"ting\" (1200 Hz, 0.06s, 0.18 vol)
# that plays when the shield bubble absorbs incoming damage. Short and bright
# so it reads as \"blocked!\" without competing with combat sounds. The high
# metallic frequency conveys a hard energy shield deflecting a hit.
const SFX_SHIELD_HIT: String = "shield_hit"
# Shield bubble break — a shattering descending chime (C6→G5→C5→G4, 0.05s per
# note, 0.30 vol) for when the shield bubble's HP is depleted. The cascading
# downward arpeggio conveys \"the shield has shattered\" — a protective barrier
# collapsing. Distinct from SFX_SHIELD (warm ascending deploy chime) so the
# player distinguishes \"shield activated\" from \"shield destroyed.\"
const SFX_SHIELD_BREAK: String = "shield_break"
# Shield bubble reflect — a quick ricochet blip (1800 Hz, 0.04s, 0.15 vol) for
# when the shield bubble reflects an enemy projectile back at the shooter. The
# very high pitch conveys a deflection — something bouncing off a hard surface.
# Quieter than the deploy/break sounds since reflects can happen in rapid
# succession during projectile-heavy encounters.
const SFX_SHIELD_REFLECT: String = "shield_reflect"
# Turret destroyed — a metallic crunch (descending 300→150 Hz, 0.20s, 0.35 vol)
# for when the player's deployed turret is destroyed by enemy fire. The low
# descending tone conveys mechanical failure — gears grinding to a halt.
const SFX_TURRET_DESTROYED: String = "turret_destroyed"
# Turret expired — a gentle powering-down blip (600→300 Hz, 0.12s, 0.18 vol)
# for when the turret's duration runs out naturally. Quieter and shorter than
# the destroyed sound since natural expiration is less dramatic.
const SFX_TURRET_EXPIRED: String = "turret_expired"
# Gravity flip launch — an upward whoosh (0.30s, 0.30 vol) for when the Gravity
# Flip Field launches enemies into the air. Reuses the whoosh generator with a
# longer duration than SFX_DASH (0.18s) to convey a sustained upward force.
const SFX_GRAVITY_LAUNCH: String = "gravity_launch"
# Void rift slash — a sharp ethereal slash (descending 880→440 Hz, 0.10s, 0.18
# vol) for when an enemy passes through the Void Rift Cutter and takes damage.
# The descending tone conveys a blade cutting through space — a void blade
# slicing reality. Quiet since multiple enemies can pass through in quick
# succession.
const SFX_VOID_SLASH: String = "void_slash"

# ── Enhancement Pack 44: AI state transition SFX ── Dedicated audio cues for
#    the four key enemy AI state changes that previously had visual-only feedback.
#    Each sound is tuned to convey the specific tactical shift that just occurred.
const SFX_AMBUSH_TRIGGER: String = "ambush_trigger"
const SFX_PACK_FRENZY: String = "pack_frenzy"
const SFX_CALL_HELP: String = "call_help"
const SFX_RETREAT: String = "retreat"
# ── Weather combo transition — a shimmering dual-layer chime that conveys two
#    weather systems layering on top of each other.
const SFX_WEATHER_COMBO: String = "weather_combo"

# ── Enhancement Pack 45: Missing combat & world interaction SFX ──
# SFX_WALL_BOUNCE — a quick muffled impact + ricochet for when the player's
# dash slide bounces off a wall. Short (0.08s) and moderate volume (0.20) so
# it reads as a physical "bonk" without competing with the dash SFX. The
# noise-hit timbre conveys a physical collision with terrain, distinct from
# the airy dash whoosh. Previously the wall bounce had camera shake + sparkle
# particles but no audio — the player bounced off walls in silence.
const SFX_WALL_BOUNCE: String = "wall_bounce"
# SFX_RICOCHET — a bright metallic ping for when the Bouncing Bolt weapon mod
# bounces off a wall. Higher pitch (1400 Hz) and shorter (0.05s) than the dash
# wall bounce since the ricochet is a projectile deflection, not a body
# collision. The high metallic frequency reads as a laser bolt glancing off a
# hard surface — the audio shorthand for "ricochet" in every shooter game.
# Quiet (0.15) since the Bouncing Bolt can bounce up to 3 times in quick
# succession.
const SFX_RICOCHET: String = "ricochet"
# SFX_CRYSTAL_CHARGE — a rising crystalline hum for the Crystal Guardian's
# 0.8-second charge-up telegraph. Ascending pitch (440→880 Hz over 0.7s)
# conveys energy building toward release — the player hears the charge
# building and knows a shard is coming. Moderate volume (0.18) so it's
# audible over ambient biome music but doesn't compete with combat. The
# crystalline sine timbre matches the Crystal Guardian's ice-crystal theme.
# Previously the charge-up had only a visual emission brighten — the player
# had no audio cue to start dodging before the shard fired.
const SFX_CRYSTAL_CHARGE: String = "crystal_charge"

# ── Enemy attack windup SFX ── A short rising tone (220→440 Hz, 0.14s, 0.12 vol)
#    that plays when an enemy begins its attack windup. The enemy attack already
#    has a visual telegraph (silhouette squash + emission glow ramp) but no
#    audio — the player had no cue to start dodging until the lunge fired. This
#    subtle rising tone gives the windup an audio identity so the player *hears*
#    the charge-up building, not just sees it. Very quiet (0.12) since multiple
#    enemies can wind up simultaneously during swarm encounters; the tone is
#    meant to register subconsciously as "incoming attack" without competing
#    with combat SFX. Pitch scales per-enemy (set via play_sfx_pitched in
#    enemy_base.gd) so larger enemies get a deeper, more threatening charge.
const SFX_ENEMY_WINDUP: String = "enemy_windup"

# ── Mind control activate SFX ── An ethereal ascending shimmer (E5→A5→E6,
#    659→880→1319 Hz, 0.18s, 0.25 vol) for when an enemy comes under mind
#    control. The shimmering ascending interval conveys "this enemy is now
#    on your side" — a magical, mind-bending transformation. Distinct from
#    SFX_PET_EMOTE (880 Hz blip) and SFX_HEAL (two-note chime) so the player
#    can identify the mind-control activation by ear alone.
const SFX_MIND_CONTROL: String = "mind_control"

# ── Mind control expire SFX ── A soft descending shimmer (E6→A5→E5,
#    1319→880→659 Hz, 0.15s, 0.18 vol) for when mind control wears off —
#    the reversed interval of the activate sound, conveying "the control
#    is fading." Quieter than the activate sound since expiration is less
#    dramatic — the player already knows the timer is running.
const SFX_MIND_CONTROL_END: String = "mind_control_end"

# ── Enhancement Pack 48: Dedicated SFX for gameplay milestones ──
# Previously these events reused SFX_LEVEL_UP or SFX_COMBO_MILESTONE,
# which were thematically misleading — the player would hear "level up"
# when an achievement unlocked, or "kill streak" when a quest completed.
# Each new SFX has a distinct sonic identity matching its event.

# SFX_ACHIEVEMENT — a triumphant 4-note major arpeggio (C5→E5→G5→C6,
# 523→659→784→1047 Hz, 0.08s per note, 0.22 vol). The major triad
# ascending through two octaves conveys "accomplishment unlocked" —
# the classic fanfare interval. Distinct from SFX_LEVEL_UP (3-note)
# so the player can tell an achievement from a level-up by ear.
const SFX_ACHIEVEMENT: String = "achievement"

# SFX_QUEST_COMPLETE — a bright 3-note rising chime (G4→C5→E5,
# 392→523→659 Hz, 0.10s per note, 0.20 vol). The perfect fifth +
# major third interval conveys "task fulfilled" — a satisfying
# resolution. Distinct from SFX_COMBO_MILESTONE (2-note) so quest
# completion doesn't sound like a combat streak.
const SFX_QUEST_COMPLETE: String = "quest_complete"

# SFX_SKILL_UNLOCK — a crystalline 2-note ascending ping (C6→G6,
# 1047→1568 Hz, 0.07s per note, 0.18 vol). The high crystalline
# register conveys "knowledge / skill acquired" — like a rune
# activating. Short and punchy since skill purchases happen in a
# menu where the player is reading, not in combat. Distinct from
# SFX_LEVEL_UP so skill purchases don't sound like leveling.
const SFX_SKILL_UNLOCK: String = "skill_unlock"

# SFX_VICTORY_FANFARE — a 6-note triumphant fanfare (C5→E5→G5→C6→E6→G6,
# 523→659→784→1047→1319→1568 Hz, 0.09s per note, 0.30 vol). The
# extended 2-octave ascending major arpeggio is the most elaborate
# SFX in the game — reserved for the ultimate payoff of completing
# Boss Rush, Speedrun, or Endless modes. The cascading ascent conveys
# "you did it — the run is won." Replaces SFX_LEVEL_UP which was
# themantically wrong for a victory screen.
const SFX_VICTORY_FANFARE: String = "victory_fanfare"

# ── Enhancement Pack 53: Enemy lunge strike SFX ── A sharp impact whoosh
#    (descending 500→200 Hz, 0.08s, 0.15 vol) that plays when an enemy
#    executes its melee lunge — the release moment after the windup.
#    Previously the windup had SFX_ENEMY_WINDUP but the actual strike
#    was silent. The descending pitch conveys a committed forward
#    lunge — a predator leaping. Short and quiet so swarms don't stack
#    into noise. Distinct from SFX_ENEMY_WINDUP (ascending, quieter) so
#    the player hears the full attack cycle: rising charge → striking
#    release. Added to _PITCH_VARIATION_SFX for natural detuning.
const SFX_ENEMY_LUNGE: String = "enemy_lunge"

# ── Enhancement Pack 53: Boss enrage SFX ── A colossal two-stage roar
#    (deep descending 80→40 Hz growl, 0.45s, 0.40 vol) that plays when
#    a boss enters its enrage phase. Previously all 3 bosses (Drake,
#    Void Leviathan, Ancient Sentinel) reused SFX_BOSS_SPAWN at different
#    pitches — the spawn rumble at 0.7× / 0.5× pitch was a hack that
#    sounded muffled. This dedicated SFX is longer than SFX_BOSS_SPAWN
#    (0.45s vs 0.6s spawn), starts lower (80 Hz vs 60 Hz), and has a
#    steeper descent (80→40 vs 60→60 sustained) to convey "escalating
#    rage" rather than "ominous entrance." The lower terminal frequency
#    (40 Hz) gives it a visceral chest-rumble quality. Excluded from
#    pitch variation since enrage is a rare, dramatic event.
const SFX_BOSS_ENRAGE: String = "boss_enrage"

# ── Enhancement Pack 53: Weather transition SFX ── A gentle atmospheric
#    crossfade whoosh (0.35s, 0.18 vol) that plays when the weather
#    changes. Previously weather transitions reused SFX_RIFT (a
#    dimension-rift whoosh at 0.35 vol) — thematically misleading since
#    the player would hear "dimensional rift opening" when it was just
#    rain clearing. This dedicated SFX is quieter (0.18 vs 0.35) since
#    weather changes are informational, not dramatic. Uses a soft
#    ascending-then-descending sweep (300→500→300 Hz) to convey
#    "atmosphere shifting" — a gentle breeze rather than a reality
#    tear. Added to _PITCH_VARIATION_SFX for subtle per-weather
#    variation so the same whoosh doesn't repeat identically.
const SFX_WEATHER_SHIFT: String = "weather_shift"

# ── Enhancement Pack 58: Weather hazard SFX ── Dedicated sounds for three
#    weather hazard events that previously had no audio or reused generic SFX.
#    EMP pulse — a sharp electronic buzz (1000→200 Hz descending, 0.15s, 0.30
#    vol) for the magnetic storm's dash-disabling pulse. The descending
#    electronic sweep conveys a system short-circuit — the player's dash
#    electronics being fried. Moderate volume since the EMP is a significant
#    gameplay event that the player needs to notice immediately.
const SFX_EMP_PULSE: String = "emp_pulse"
# Gravity shift — a deep wavering whomp (60→120→60 Hz, 0.25s, 0.28 vol) for
# the gravity anomaly weather's periodic shift. The rising-then-falling pitch
# conveys gravity reversing direction — a physical "lurch" sensation. Distinct
# from SFX_MUTATION (440→554→659 Hz ascending chime) which was previously
# reused at 0.6× pitch. Moderate volume since the shift affects movement.
const SFX_GRAVITY_SHIFT: String = "gravity_shift"
# Sand scour — a brief abrasive hiss (noise hit, 0.06s, 0.08 vol) for the
# sandstorm's per-tick damage. Very short and quiet since the tick fires every
# 1s and multiple ticks shouldn't stack into noise. The noise-hit timbre
# conveys sand grinding against the player's body.
const SFX_SAND_SCOUR: String = "sand_scour"
# Acid rain sizzle — a brief corrosive sizzle (noise hit, 0.06s, 0.08 vol)
# for the acid rain's per-tick damage. Same short+quiet pattern as the sand
# scour since the tick fires every 1s. The noise-hit timbre conveys acid
# eating through the player's surface — a chemical rather than abrasive hiss.
const SFX_ACID_SIZZLE: String = "acid_sizzle"

# ── Enhancement Pack 60: Endgame milestone SFX ── Dedicated sounds for major
#    endgame unlock/completion events that previously reused SFX_LEVEL_UP or
#    SFX_COMBO_MILESTONE, making every major milestone sound the same. Each
#    new SFX has a distinct sonic identity matching the magnitude of its event.

# SFX_ENDGAME_UNLOCK — a colossal 5-note deep fanfare (C3→G3→C4→E4→G4,
# 130.81→196→262→330→392 Hz, 0.10s per note, 0.35 vol). Starts two octaves
# below the achievement fanfare to convey "a massive new power tier has
# opened" — the deep register reads as something fundamental shifting in
# the game's structure. NG+ and NG++ are the biggest difficulty milestones
# in the game (unlocking 2×/3× enemy stats, rare-only loot, permadeath),
# so they deserve a sound that conveys "the game has escalated" rather
# than "you gained a level." The ascending major triad from a deep bass
# root conveys upward expansion from a heavy foundation — power growing
# from a darker base. Excluded from pitch variation since unlocks are
# rare, dramatic events that should sound consistent.
const SFX_ENDGAME_UNLOCK: String = "endgame_unlock"

# SFX_DUNGEON_CLEAR — a bright 4-note rising chime (D5→G5→B5→D6,
# 587→784→988→1175 Hz, 0.08s per note, 0.28 vol). The D major arpeggio
# ascending through two octaves conveys "a challenge has been conquered"
# — brighter and more open than SFX_QUEST_COMPLETE (G4→C5→E5) since
# clearing a full dungeon (with boss + traps + reward chest) is a bigger
# accomplishment than a single quest. Distinct from SFX_LEVEL_UP
# (C→E→G→C arpeggio) so dungeon clears don't sound like leveling.
# Also used for Ancient Vault unlocks — another major exploration milestone.
# Added to _PITCH_VARIATION_SFX for natural micro-detuning.
const SFX_DUNGEON_CLEAR: String = "dungeon_clear"

# SFX_GAUNTLET_CLEAR — a punchy 3-note triumphant blip (C5→E5→C6,
# 523→659→1047 Hz, 0.06s per note, 0.22 vol). The octave leap (C5→C6) in
# the third note gives it a "victory hop" quality — shorter and punchier
# than SFX_DUNGEON_CLEAR since clearing one gauntlet biome is a smaller
# milestone than clearing a full dungeon. Replaces SFX_COMBO_MILESTONE
# (the kill-streak sound) so gauntlet biome clears don't sound like
# combat streaks. Added to _PITCH_VARIATION_SFX for natural micro-detuning.
const SFX_GAUNTLET_CLEAR: String = "gauntlet_clear"

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
	# Pickup streak milestones — golden chime for collection rewards
	GameManager.pickup_streak_milestone.connect(_on_pickup_streak_milestone)
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

## Play a one-shot SFX with a volume multiplier (0.0 = silent, 1.0 = full).
## Used for distance-attenuated sounds (e.g. spawn warnings far from the
## player) where the caller computes a volume scale based on distance.
## The volume multiplier scales the sfx_volume × master_volume product
## before converting to dB, so 0.5 = half the perceived volume of play_sfx.
## Pitch variation is applied the same way as play_sfx.
func play_sfx_volume(sfx_name: String, vol_mult: float) -> void:
	if not _initialized:
		return
	if not _sfx_streams.has(sfx_name):
		return
	var player = _next_sfx_player()
	player.stream = _sfx_streams[sfx_name]
	var effective_vol: float = maxf(sfx_volume * master_volume * vol_mult, 0.0001)
	player.volume_db = linear_to_db(effective_vol)
	if sfx_name in _PITCH_VARIATION_SFX:
		player.pitch_scale = 1.0 + randf_range(-_PITCH_VARIATION_AMOUNT, _PITCH_VARIATION_AMOUNT)
	else:
		player.pitch_scale = 1.0
	player.play()

## Play a one-shot SFX with an explicit pitch scale override. This is used
## for size-based audio hierarchy: larger enemies get deeper (lower pitch)
## death/hit sounds so a Drake's death sounds weightier than a Blob's.
## The pitch is computed by the caller and passed in directly. The random
## ±6% variation is still applied ON TOP of the base pitch so the size-
## scaled sounds still have natural micro-detuning.
##   pitch_base = 1.0 (normal), 0.7 (deep/large), 1.3 (small/high)
func play_sfx_pitched(sfx_name: String, pitch_base: float) -> void:
	if not _initialized:
		return
	if not _sfx_streams.has(sfx_name):
		return
	var player = _next_sfx_player()
	player.stream = _sfx_streams[sfx_name]
	player.volume_db = linear_to_db(maxf(sfx_volume * master_volume, 0.0001))
	# Apply the base pitch, then add random variation on top for natural detuning
	var variation: float = 0.0
	if sfx_name in _PITCH_VARIATION_SFX:
		variation = randf_range(-_PITCH_VARIATION_AMOUNT, _PITCH_VARIATION_AMOUNT)
	player.pitch_scale = clampf(pitch_base + variation, 0.1, 4.0)
	player.play()

## Play a one-shot SFX with both an explicit pitch scale AND a volume multiplier.
## Combines play_sfx_pitched and play_sfx_volume for sounds that need both
## size-based pitch AND distance attenuation (e.g. enemy activation SFX:
## large enemies get a deeper pitch, distant enemies get a lower volume).
func play_sfx_pitched_volume(sfx_name: String, pitch_base: float, vol_mult: float) -> void:
	if not _initialized:
		return
	if not _sfx_streams.has(sfx_name):
		return
	var player = _next_sfx_player()
	player.stream = _sfx_streams[sfx_name]
	var effective_vol: float = maxf(sfx_volume * master_volume * vol_mult, 0.0001)
	player.volume_db = linear_to_db(effective_vol)
	var variation: float = 0.0
	if sfx_name in _PITCH_VARIATION_SFX:
		variation = randf_range(-_PITCH_VARIATION_AMOUNT, _PITCH_VARIATION_AMOUNT)
	player.pitch_scale = clampf(pitch_base + variation, 0.1, 4.0)
	player.play()

# ── 3D Positional SFX ─────────────────────────────────────────────────────────
## Play a one-shot SFX as a 3D positional sound at the given world position.
## Uses Godot's built-in AudioStreamPlayer3D with inverse-distance attenuation so
## the player hears the sound coming from the correct direction — essential for
## off-screen spawn warnings, distant explosions, and environmental events.
## The SFX auto-frees after playback finishes. The attenuation model is
## ATTENUATION_INVERSE_DISTANCE, with max_distance tuned for gameplay
## readability: full volume near the source, natural rolloff to 60m.
## Inverse-distance is the physically-based default for 3D game audio —
## ATTENUATION_LINEAR produces an unnatural abrupt cutoff at max_distance
## (volume = 0 at exactly max_distance), while inverse-distance fades
## gradually, matching how real sound propagates.
func play_sfx_3d(sfx_name: String, world_pos: Vector3, vol_mult: float = 1.0) -> void:
	if not _initialized:
		return
	if not _sfx_streams.has(sfx_name):
		return
	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		return
	var player_3d := AudioStreamPlayer3D.new()
	player_3d.stream = _sfx_streams[sfx_name]
	player_3d.unit_size = 8.0
	player_3d.max_distance = 60.0
	player_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player_3d.global_position = world_pos
	var effective_vol: float = maxf(sfx_volume * master_volume * vol_mult, 0.0001)
	player_3d.volume_db = linear_to_db(effective_vol)
	if sfx_name in _PITCH_VARIATION_SFX:
		player_3d.pitch_scale = 1.0 + randf_range(-_PITCH_VARIATION_AMOUNT, _PITCH_VARIATION_AMOUNT)
	else:
		player_3d.pitch_scale = 1.0
	scene_root.add_child(player_3d)
	player_3d.play()
	# Auto-free after the stream finishes (plus a small safety margin).
	player_3d.finished.connect(player_3d.queue_free)

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

# ── Low-HP heartbeat audio ── Plays the heartbeat SFX at a scaled volume.
#    intensity (0..1) maps to volume — 0.0 is barely audible (just crossed the
#    threshold), 1.0 is full heartbeat volume (near death). This mirrors the
#    visual heartbeat's urgency curve so the audio and visual stay in sync.
#    We use a dedicated SFX pool slot rather than the round-robin pool to
#    prevent the heartbeat from stealing a player's combat SFX slot (and vice
#    versa) during intense fights — a dedicated player guarantees the heartbeat
#    always has a voice available without cutting off a shoot/dash sound.
var _heartbeat_sfx_player: AudioStreamPlayer = null
func play_heartbeat_sfx(intensity: float) -> void:
	if not _initialized:
		return
	if not _sfx_streams.has(SFX_HEARTBEAT):
		return
	if intensity <= 0.0:
		return
	# Clamp intensity to 0..1 for safety
	intensity = clampf(intensity, 0.0, 1.0)
	# Lazy-init the dedicated heartbeat player
	if not _heartbeat_sfx_player:
		_heartbeat_sfx_player = AudioStreamPlayer.new()
		_heartbeat_sfx_player.bus = "Master"
		add_child(_heartbeat_sfx_player)
	_heartbeat_sfx_player.stream = _sfx_streams[SFX_HEARTBEAT]
	# Volume scales with intensity: at intensity 0.0 → -24 dB (whisper),
	# at intensity 1.0 → -6 dB (clearly felt but below combat SFX).
	# We then apply the master volume multiplier on top. SFX volume is
	# intentionally NOT applied to the full extent — the heartbeat should
	# always be audible when critical, so we use a gentler attenuation.
	var vol_db: float = lerpf(-24.0, -6.0, intensity)
	var master_db: float = linear_to_db(maxf(master_volume, 0.0001))
	_heartbeat_sfx_player.volume_db = vol_db + master_db
	_heartbeat_sfx_player.pitch_scale = 1.0
	_heartbeat_sfx_player.play()

# SFX that get subtle random pitch variation. These are short, percussive
# combat sounds where micro-detuning reads as natural variation rather than
# a tuning error. Melodic SFX (arpeggios, chimes) are excluded so their
# musical intervals stay clean.
const _PITCH_VARIATION_SFX: Array[String] = [
	SFX_SHOOT, SFX_ENEMY_HIT, SFX_DASH_BUMP, SFX_DASH, SFX_ENEMY_DEATH,
	SFX_EXPLOSION, SFX_PULSE_WAVE, SFX_DAMAGE, SFX_CRIT_HIT,
	SFX_PICKUP, SFX_PICKUP_RARE,
	# Phase 30: Adaptive shoot variants — all get subtle pitch variation
	SFX_SHOOT_STANDARD, SFX_SHOOT_HOMING, SFX_SHOOT_ENERGY, SFX_SHOOT_PIERCE,
	SFX_SHOOT_FREEZE, SFX_SHOOT_POISON, SFX_SHOOT_FIRE, SFX_SHOOT_VOID,
	SFX_SHOOT_LIGHTNING, SFX_SHOOT_HEAVY, SFX_SHOOT_UTILITY, SFX_SHOOT_VAMPIRE,
	# Enhancement Pack 21: Environmental impact SFX get pitch variation
	SFX_LAND, SFX_PULL,
	# Enhancement Pack 23: Loot drop SFX get pitch variation
	SFX_RARE_DROP, SFX_PET_STONE_DROP, SFX_CRAFT_DROP,
	# Footstep — micro-detuning so walking doesn't sound like a metronome
	SFX_FOOTSTEP,
	# Stagger + magnet hum — micro-detuning for natural variation
	SFX_STAGGER, SFX_MAGNET_HUM,
	# Enhancement Pack 39: New SFX get pitch variation
	SFX_GRAVITY_CHARGE, SFX_PHANTOM_SPAWN,
	# Enhancement Pack 41: Deployable SFX get pitch variation
	SFX_SHIELD_HIT, SFX_SHIELD_REFLECT, SFX_TURRET_EXPIRED, SFX_VOID_SLASH,
	# Enhancement Pack 44: AI state transition SFX get pitch variation
	SFX_AMBUSH_TRIGGER, SFX_PACK_FRENZY, SFX_CALL_HELP, SFX_RETREAT, SFX_WEATHER_COMBO,
	# Enhancement Pack 45: New SFX get pitch variation
	SFX_WALL_BOUNCE, SFX_RICOCHET, SFX_CRYSTAL_CHARGE,
	# Enhancement Pack 48: Enemy windup + mind control SFX get pitch variation
	SFX_ENEMY_WINDUP, SFX_MIND_CONTROL_END,
	# Enhancement Pack 48: Milestone SFX get pitch variation
	SFX_ACHIEVEMENT, SFX_QUEST_COMPLETE, SFX_SKILL_UNLOCK,
	# Enhancement Pack 53: Enemy lunge + weather shift get pitch variation
	SFX_ENEMY_LUNGE, SFX_WEATHER_SHIFT,
	# Enhancement Pack 58: Weather hazard SFX get pitch variation
	SFX_GRAVITY_SHIFT, SFX_SAND_SCOUR, SFX_ACID_SIZZLE,
	# Enhancement Pack 60: Endgame milestone SFX get pitch variation
	# (SFX_ENDGAME_UNLOCK excluded — rare dramatic event should sound consistent)
	SFX_DUNGEON_CLEAR, SFX_GAUNTLET_CLEAR,
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


## Combo milestone — the SFX pitch rises with each tier so higher combos
## feel increasingly triumphant. Tier 1 (x5) plays at unity pitch, tier 2
## (x10) at +1 semitone, tier 3 (x15) at +2 semitones, etc. Capped at
## +6 semitones (one octave) so very high combos don't squeak into
## cartoonishness. The pitch escalation complements the existing tier-
## scaled camera trauma and FOV kick, making each milestone feel bigger
## than the last through multiple sensory channels. Semitones use the
## standard 2^(n/12) pitch ratio.
func _on_combo_milestone(_combo: int, tier: int, _color: Color) -> void:
	if not _initialized:
		return
	if not _sfx_streams.has(SFX_COMBO_MILESTONE):
		return
	var player = _next_sfx_player()
	player.stream = _sfx_streams[SFX_COMBO_MILESTONE]
	player.volume_db = linear_to_db(maxf(sfx_volume * master_volume, 0.0001))
	# Pitch escalation: +1 semitone per tier, capped at +6 (one octave)
	var semitones: int = clampi(tier - 1, 0, 6)
	player.pitch_scale = pow(2.0, float(semitones) / 12.0)
	player.play()


## Pickup streak milestone — plays a warm golden chime to complement the
## existing camera trauma + sparkle. Previously this milestone had visual
## juice (sparkle + shake) but no audio, making it feel incomplete next
## to the combat combo milestone which has full audio-visual feedback.
## The chime is a C-major triad (C5-E5-G5) — bright and rewarding, distinct
## from the combat milestone's ascending arpeggio so the two don't blur.
func _on_pickup_streak_milestone(_streak: int, _xp: int) -> void:
	play_sfx(SFX_PICKUP_STREAK)


func _on_biome_changed(biome_id: int) -> void:
	play_music_biome(biome_id)
	# ── Enhancement Pack 13: Biome change chime ──
	# Entering a new biome is a significant moment in an exploration game.
	# The music already cross-fades, but there was no short SFX cue. A soft
	# mutation chime (already used for mutations, which are biome-linked)
	# provides an audio "you've arrived" without competing with the music.
	# Pitched at 1.0 (standard) — the mutation system uses the same sound
	# at 1.0 for activation and 0.7 for deactivation, so biome entry reads
	# as "new biome" not "mutation faded".
	play_sfx(SFX_MUTATION)


func _on_player_died() -> void:
	play_sfx(SFX_DEATH)
	# Stop the heartbeat SFX so it doesn't continue after death
	if _heartbeat_sfx_player and _heartbeat_sfx_player.playing:
		_heartbeat_sfx_player.stop()


func _on_game_restarted() -> void:
	_boss_music_playing = false
	_stop_boss_music()
	_current_biome = -1
	# Phase 30: Reset dynamic music intensity
	_music_intensity_current = 0.0
	# Stop the heartbeat SFX player so it doesn't carry over into the new run
	if _heartbeat_sfx_player and _heartbeat_sfx_player.playing:
		_heartbeat_sfx_player.stop()


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
	# Pickup streak milestone — warm golden chime (C5-E5-G5 major triad).
	# Brighter and shorter than the combat combo milestone so it reads as a
	# "collection reward" rather than a "kill streak". The chime uses a
	# major triad (no 7th) for a clean, satisfying resolution.
	_sfx_streams[SFX_PICKUP_STREAK] = _gen_chime([523.0, 659.0, 784.0], 0.18, 0.32)
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
	# ── Dash cooldown ready chime ── A bright two-note "ding" (G5→C6) using a
	# short chime so it reads as "ability refreshed" without being intrusive.
	# The two-note interval (perfect fifth → octave) is the classic "ready"
	# sound shape (think MOBA ability-off-cooldown cues). Low volume (0.15)
	# so it sits under combat without competing.
	_sfx_streams[SFX_DASH_READY] = _gen_chime([784.0, 1047.0], 0.10, 0.15)
	# ── Low-HP heartbeat ── A procedural "lub-dub" cardiac sound. Two low thumps
	# per sample: lub (55 Hz sine, 0.12s, louder) + dub (55 Hz sine, 0.08s, 60%
	# volume) separated by a 0.15s gap. A second harmonic at 110 Hz adds body
	# so it reads as a chest-felt throb rather than a beep. The double-pulse
	# envelope mimics real heart auscultation (S1/S2) so it's instantly
	# recognizable as "heart in danger" — the universal audio shorthand for
	# critical health in games ( Doom, Zelda, Call of Duty, etc.).
	_sfx_streams[SFX_HEARTBEAT] = _gen_heartbeat()
	# ── Enemy materialization SFX ── A short descending energy-coalesce blip
	# (220→110 Hz over 0.12s) that reads as "something materializing." Low
	# volume (0.12) so it doesn't overwhelm during heavy waves where multiple
	# enemies materialize in quick succession.
	_sfx_streams[SFX_SPAWN_IN] = _gen_descending(220.0, 110.0, 0.12, 0.12)
	# ── Variant promotion SFX ── A bright ascending arpeggio (C5→E5→G5→C6)
	# that signals a rare enemy has appeared. Higher and longer than the
	# normal spawn sound so the player notices a Golden/Champion variant.
	_sfx_streams[SFX_VARIANT_PROMOTE] = _gen_arpeggio([523.0, 659.0, 784.0, 1047.0], 0.05, 0.30)
	# ── Variant defeat SFX ── A triumphant descending arpeggio (C6→G5→E5→C5)
	# that rewards the player for taking down a tough variant. Reversed from
	# the promotion arpeggio so it sounds like "victory over the elite."
	_sfx_streams[SFX_VARIANT_DEFEAT] = _gen_arpeggio([1047.0, 784.0, 659.0, 523.0], 0.06, 0.35)
	# ── Buff expire SFX ── A short descending chime (E5→C5→G4) that conveys
	# loss — the player's monolith buff is fading. Quiet (0.18) so it's
	# noticeable but not punishing. Paired with the existing shatter particles.
	_sfx_streams[SFX_BUFF_EXPIRE] = _gen_chime([659.0, 523.0, 392.0], 0.12, 0.18)
	# ── Craft fail SFX ── A low dissonant buzz (150 Hz → 100 Hz) that
	# immediately communicates "that didn't work." Short (0.15s) so it
	# doesn't linger. Used in both weapon mod and equipment crafting menus.
	_sfx_streams[SFX_CRAFT_FAIL] = _gen_descending(150.0, 100.0, 0.15, 0.25)
	# ── Pulse wave ready SFX ── A bright two-note chime (C6→E6, 1047→1319 Hz)
	# higher than SFX_DASH_READY (G5→C6, 784→1047) so the player can tell
	# the two cooldown-ready cues apart by pitch alone.
	_sfx_streams[SFX_PULSE_READY] = _gen_chime([1047.0, 1319.0], 0.10, 0.15)
	# ── Enemy alert SFX ── A short ascending blip (440→880 Hz, 0.08s) that
	# reads as "spotted you!" — quiet (0.10) so pack detections don't stack
	# into noise. Uses the descending generator with reversed freqs to get
	# an ascending pitch sweep.
	_sfx_streams[SFX_ENEMY_ALERT] = _gen_descending(440.0, 880.0, 0.08, 0.10)
	# ── Enhancement Pack 12: Combo break SFX ── A descending "streak lost"
	# chime (G4→D4→A3, 392→294→220 Hz, 0.14s). The descending minor interval
	# conveys "something good just ended" without being harsh. Quiet (0.15)
	# so it's noticeable but not punishing — the player should feel the
	# streak end, not be annoyed by it. Only fires for meaningful streaks.
	_sfx_streams[SFX_COMBO_BREAK] = _gen_chime([392.0, 294.0, 220.0], 0.14, 0.15)
	# ── Enhancement Pack 13: Camera shutter ── two rapid noise clicks mimicking
	# a mechanical camera shutter. Uses _gen_noise_sweep with very short
	# duration for a crisp click rather than a whoosh.
	_sfx_streams[SFX_SHUTTER] = _gen_noise_sweep(0.04, 0.15)
	# ── Enhancement Pack 16: World Life & Companion Event Feedback ──
	# Pet emote — a gentle sine blip (880 Hz, 0.08s, soft volume). The base
	# sound is neutral; per-emote pitch shifting in companion_pet.gd gives
	# each emotion its own identity: HAPPY=1.3× (bright), LOVE=1.1× (warm),
	# CURIOUS=1.2× (questioning), SCARED=0.8× (low/trembling), ANGRY=0.6×
	# (deep/growl), SLEEPY=0.5× (low-long), HUNGRY=0.9× (pulsing).
	_sfx_streams[SFX_PET_EMOTE] = _gen_blip(880.0, 0.08, 0.20)
	# Merchant arrival — a welcoming ascending major triad (C5→E5→G5) that
	# reads as "a friend has arrived." Longer note duration (0.07s each) and
	# moderate volume (0.28) so it's noticeable over ambient biome music
	# without being startling. Distinct from SFX_LEVEL_UP (arpeggio, faster,
	# 4 notes) and SFX_COMBO_MILESTONE (3 notes, shorter) so the player
	# recognizes "merchant" specifically.
	_sfx_streams[SFX_MERCHANT] = _gen_arpeggio([523.0, 659.0, 784.0], 0.07, 0.28)
	# Enemy dodge — a quick lateral whoosh (0.08s noise sweep, low volume).
	# Shorter than SFX_DASH (0.18s) and quieter than SFX_DASH_BUMP so it
	# reads as a subtle "missed" cue, not a combat impact. The noise sweep
	# timbre conveys air disturbance — something slipping past — matching
	# the visual of an enemy sidestepping a projectile.
	_sfx_streams[SFX_DODGE] = _gen_noise_sweep(0.08, 0.18)
	# Enemy near-death — a subtle metallic groan: low descending tone
	# (140→100 Hz over 0.12s, quiet 0.10). Low enough to sit under combat
	# without being annoying when multiple enemies are shuddering. The
	# descending pitch conveys "weakening / about to break" — the audio
	# equivalent of the visual tremor.
	_sfx_streams[SFX_NEAR_DEATH] = _gen_descending(140.0, 100.0, 0.12, 0.10)
	# ── Enhancement Pack 20: Near-miss graze ── A very short airy whoosh
	# (0.06s noise sweep at 0.12 volume) that plays when an enemy projectile
	# narrowly misses the player. Shorter and quieter than SFX_DODGE so
	# multiple grazes during a projectile-heavy encounter don't stack into
	# noise. The noise-sweep timbre conveys air disturbance — the bolt's
	# wake brushing past the player's body.
	_sfx_streams[SFX_GRAZE] = _gen_noise_sweep(0.06, 0.12)

	# ── Enhancement Pack 21: Environmental & combat action SFX ───────────────
	# SFX_LAND — low thud for landing impact (80 Hz body, 0.10s, 0.25 vol)
	_sfx_streams[SFX_LAND] = _gen_noise_hit(0.10, 0.25)

	# SFX_BUFF_ACTIVATE — ascending C major arpeggio (C5→E5→G5→C6, 0.06s/note, 0.30 vol)
	_sfx_streams[SFX_BUFF_ACTIVATE] = _gen_arpeggio([523.0, 659.0, 784.0, 1047.0], 0.06, 0.30)

	# SFX_PULL — deep descending gravitational whomp (90→45 Hz, 0.30s, 0.40 vol)
	_sfx_streams[SFX_PULL] = _gen_descending(90.0, 45.0, 0.30, 0.40)

	# SFX_WILDLIFE_FLEE — tiny startled chirp (1400 Hz, 0.05s, 0.10 vol)
	_sfx_streams[SFX_WILDLIFE_FLEE] = _gen_blip(1400.0, 0.05, 0.10)

	# ── Enhancement Pack 23: Loot drop feedback SFX ───────────────────────────
	# SFX_RARE_DROP — shimmering ascending chime (E5→G5→B5→E6). Higher and
	# brighter than SFX_PICKUP_RARE so the player distinguishes "a rare
	# material just dropped from this enemy" from "I picked up a rare item."
	# Uses an augmented fifth arpeggio (E-G-B-E) for a magical, valuable feel.
	_sfx_streams[SFX_RARE_DROP] = _gen_arpeggio([659.0, 784.0, 988.0, 1319.0], 0.06, 0.25)

	# SFX_PET_STONE_DROP — warm magical chime (A4→C5→E5 major triad). The
	# major triad conveys the mystical nature of evolution stones. Quieter
	# than SFX_RARE_DROP since the collectible pickup itself also plays a
	# sound — this is just the "look over there" attention cue.
	_sfx_streams[SFX_PET_STONE_DROP] = _gen_chime([440.0, 523.0, 659.0], 0.12, 0.22)

	# SFX_CRAFT_DROP — subtle material blip (880 Hz, 0.04s, 0.12 vol). Very
	# quiet and short since crafting materials are common (12% drop rate).
	# Just enough to register subconsciously as "something shiny dropped."
	_sfx_streams[SFX_CRAFT_DROP] = _gen_blip(880.0, 0.04, 0.12)

	# ── Player footstep ── A very short (0.04s) low-frequency filtered-noise
	# thud. Uses _gen_noise_hit with a fast decay so it reads as a soft step
	# on alien terrain — muffled, not clicky. Very quiet (0.10) so it sits
	# under ambient music and combat. The ±6% pitch variation from
	# _PITCH_VARIATION_SFX keeps a sprint from sounding mechanical.
	_sfx_streams[SFX_FOOTSTEP] = _gen_noise_hit(0.04, 0.10)

	# ── Enemy stagger ── A quick descending metallic ping (660→440 Hz,
	# 0.10s, 0.25 vol) that conveys a metallic "clang" of an enemy's
	# attack being knocked off course. The descending pitch reads as
	# "recoil" — the enemy's force being deflected. Uses a short
	# descending tone with fast decay so it's punchy, not lingering.
	_sfx_streams[SFX_STAGGER] = _gen_descending(660.0, 440.0, 0.10, 0.25)

	# ── Collectible magnet hum ── A very short soft sine pulse (440 Hz,
	# 0.08s, 0.08 vol) that plays periodically while a collectible is
	# being magnetically vacuumed. Very quiet so multiple simultaneous
	# vacuums don't stack into noise. The warm mid-range frequency
	# reads as a gentle "energy field" hum.
	_sfx_streams[SFX_MAGNET_HUM] = _gen_blip(440.0, 0.08, 0.08)

	# ── Enhancement Pack 38: Enemy enrage growl ── A menacing descending
	# tone (220→110 Hz, 0.18s, 0.18 vol) that conveys a rising threat.
	# Shorter and quieter than the boss enrage roar (SFX_BOSS_SPAWN at
	# 0.35 vol) so it doesn't overwhelm when multiple enemies enrage
	# simultaneously during AoE combat. The descending pitch reads as
	# "this enemy is getting dangerous."
	_sfx_streams[SFX_ENRAGE] = _gen_descending(220.0, 110.0, 0.18, 0.18)

	# ── Enhancement Pack 38: Prestige fanfare ── A triumphant 5-note
	# ascending arpeggio (C4→E4→G4→C5→E5, 0.10s per note, 0.35 vol) for
	# the biggest milestone in the game. The wider two-octave range and
	# 5 notes make this feel like a true celebration, distinct from
	# SFX_PET_EVOLVE (3 notes, 0.07s/note, 0.30 vol) which was previously
	# reused for prestige. The bright top end (E5=659 Hz) gives it a
	# triumphant resolution — the "you beat the game and chose to
	# continue" fanfare.
	_sfx_streams[SFX_PRESTIGE] = _gen_arpeggio([261.63, 329.63, 392.0, 523.0, 659.0], 0.10, 0.35)

	# ── Enhancement Pack 39: New SFX ──────────────────────────────────────
	# Time slow enter — soft descending chime (G5→E5→C5) for the moment the
	# player crosses into a Time Warden's slowing field.
	_sfx_streams[SFX_TIME_SLOW_ENTER] = _gen_chime([784.0, 659.0, 523.0], 0.10, 0.12)

	# Gravity charge — deep descending rumble (70→35 Hz) for the Gravity
	# Elemental's field-charging telegraph. Replaces SFX_ARENA.
	_sfx_streams[SFX_GRAVITY_CHARGE] = _gen_descending(70.0, 35.0, 0.50, 0.35)

	# Phantom spawn — ethereal augmented-triad chime (B4→D5→F#5) for the
	# Echo Knight summoning its shadow copies.
	_sfx_streams[SFX_PHANTOM_SPAWN] = _gen_chime([494.0, 587.0, 740.0], 0.18, 0.18)

	# ── Enhancement Pack 41: Deployable system feedback SFX ──
	# Shield bubble hit — crisp metallic ting (1200 Hz, 0.06s)
	_sfx_streams[SFX_SHIELD_HIT] = _gen_blip(1200.0, 0.06, 0.18)
	# Shield bubble break — shattering descending arpeggio (C6→G5→C5→G4)
	_sfx_streams[SFX_SHIELD_BREAK] = _gen_arpeggio([1047.0, 784.0, 523.0, 392.0], 0.05, 0.30)
	# Shield bubble reflect — quick ricochet blip (1800 Hz, 0.04s)
	_sfx_streams[SFX_SHIELD_REFLECT] = _gen_blip(1800.0, 0.04, 0.15)
	# Turret destroyed — metallic crunch (300→150 Hz, 0.20s)
	_sfx_streams[SFX_TURRET_DESTROYED] = _gen_descending(300.0, 150.0, 0.20, 0.35)
	# Turret expired — gentle powering-down blip (600→300 Hz, 0.12s)
	_sfx_streams[SFX_TURRET_EXPIRED] = _gen_descending(600.0, 300.0, 0.12, 0.18)
	# Gravity flip launch — upward whoosh (0.30s)
	_sfx_streams[SFX_GRAVITY_LAUNCH] = _gen_whoosh(0.30, 0.30)
	# Void rift slash — sharp descending slash (880→440 Hz, 0.10s)
	_sfx_streams[SFX_VOID_SLASH] = _gen_descending(880.0, 440.0, 0.10, 0.18)

	# ── Enhancement Pack 44: AI state transition SFX ──
	# Ambush trigger — a sudden sharp ascending blip (600→1200 Hz, 0.06s) that
	# reads as "something was hiding and just lunged." The fast upward sweep conveys
	# ambush — a concealed threat springing. Quiet (0.12) since ambushes trigger
	# individually, but multiple nearby enemies can ambush simultaneously.
	_sfx_streams[SFX_AMBUSH_TRIGGER] = _gen_descending(600.0, 1200.0, 0.06, 0.12)
	# Pack frenzy — a dissonant descending cluster (440→220→110 Hz, 0.20s) that
	# conveys a group suddenly going berserk. The layered descending tones read as
	# "multiple threats enraging at once" — distinctly different from the single-
	# enemy enrage growl (SFX_ENRAGE). Moderate volume (0.20) since it only fires
	# when a pack member's frenzy triggers allies.
	_sfx_streams[SFX_PACK_FRENZY] = _gen_chime([440.0, 220.0, 110.0], 0.20, 0.20)
	# Call for help — a rapid urgent double-blip (880 Hz, two 0.04s pulses) that
	# reads as "distress signal." The staccato double-pulse mimics a cry for
	# attention — short, sharp, and urgent. Quiet (0.10) since it's informational,
	# not dramatic — the player should notice allies being alerted, not be
	# startled.
	_sfx_streams[SFX_CALL_HELP] = _gen_blip(880.0, 0.04, 0.10)
	# Retreat — a whimpering descending whine (330→165 Hz, 0.18s) that conveys
	# an enemy losing its nerve. The descending pitch reads as "deflating" —
	# the opposite of enrage. Very quiet (0.08) since retreat is a subtle tactical
	# shift, not a dramatic event — the player should barely notice it
	# subconsciously.
	_sfx_streams[SFX_RETREAT] = _gen_descending(330.0, 165.0, 0.18, 0.08)
	# Weather combo — a shimmering dual-layer ascending chime (C5→E5→G5→B5→E6)
	# that conveys two weather systems layering on top of each other. The wider
	# 5-note range and augmented triad (B5 = augmented fifth) gives it an
	# "overlapping / unusual" quality distinct from any single weather sound.
	# Moderate volume (0.22) since weather combos are rare and noteworthy.
	_sfx_streams[SFX_WEATHER_COMBO] = _gen_arpeggio([523.0, 659.0, 784.0, 988.0, 1319.0], 0.05, 0.22)

	# ── Enhancement Pack 45: Missing combat & world interaction SFX ──
	# Wall bounce — a quick muffled impact (noise hit, 0.08s, 0.20 vol) for
	# when the player's dash slide bounces off a wall. The noise-hit timbre
	# reads as a physical "bonk" against terrain, distinct from the airy
	# dash whoosh. Short so it doesn't compete with the ongoing dash sound.
	_sfx_streams[SFX_WALL_BOUNCE] = _gen_noise_hit(0.08, 0.20)
	# Ricochet — a bright metallic ping (1400 Hz, 0.05s, 0.15 vol) for when
	# the Bouncing Bolt weapon mod deflects off a wall. The high crystalline
	# frequency reads as a laser bolt glancing off a hard surface. Quiet so
	# 3 rapid bounces don't stack into noise.
	_sfx_streams[SFX_RICOCHET] = _gen_blip(1400.0, 0.05, 0.15)
	# Crystal charge — a rising crystalline hum (440→880 Hz ascending,
	# 0.70s, 0.18 vol) for the Crystal Guardian's charge-up telegraph.
	# Uses the descending generator with reversed freqs to get an ascending
	# pitch sweep — the sound of energy building toward release.
	_sfx_streams[SFX_CRYSTAL_CHARGE] = _gen_descending(440.0, 880.0, 0.70, 0.18)

	# ── Enhancement Pack 48: Enemy attack windup SFX ── A short rising tone
	# (220→440 Hz, 0.14s, 0.12 vol). The ascending pitch conveys energy
	# building toward release — the audio cue for "an enemy is about to
	# attack, start dodging." Uses the descending generator with reversed
	# freqs to get an ascending pitch sweep. Very quiet so multiple
	# simultaneous windups don't stack into noise during swarm encounters.
	_sfx_streams[SFX_ENEMY_WINDUP] = _gen_descending(220.0, 440.0, 0.14, 0.12)

	# ── Mind control activate SFX ── An ethereal ascending shimmer
	# (E5→A5→E6, 659→880→1319 Hz, 0.18s, 0.25 vol). The shimmering ascending
	# interval conveys a magical, mind-bending transformation.
	_sfx_streams[SFX_MIND_CONTROL] = _gen_arpeggio([659.0, 880.0, 1319.0], 0.06, 0.25)

	# ── Mind control expire SFX ── A soft descending shimmer (E6→A5→E5,
	# 1319→880→659 Hz, 0.15s, 0.18 vol) — the reversed interval of the
	# activate sound, conveying "the control is fading."
	_sfx_streams[SFX_MIND_CONTROL_END] = _gen_arpeggio([1319.0, 880.0, 659.0], 0.05, 0.18)

	# ── Enhancement Pack 48: Dedicated milestone SFX ──
	# SFX_ACHIEVEMENT — triumphant 4-note major arpeggio (C5→E5→G5→C6)
	_sfx_streams[SFX_ACHIEVEMENT] = _gen_arpeggio([523.0, 659.0, 784.0, 1047.0], 0.08, 0.22)
	# SFX_QUEST_COMPLETE — bright 3-note rising chime (G4→C5→E5)
	_sfx_streams[SFX_QUEST_COMPLETE] = _gen_arpeggio([392.0, 523.0, 659.0], 0.10, 0.20)
	# SFX_SKILL_UNLOCK — crystalline 2-note ascending ping (C6→G6)
	_sfx_streams[SFX_SKILL_UNLOCK] = _gen_arpeggio([1047.0, 1568.0], 0.07, 0.18)
	# SFX_VICTORY_FANFARE — 6-note triumphant fanfare (C5→E5→G5→C6→E6→G6)
	_sfx_streams[SFX_VICTORY_FANFARE] = _gen_arpeggio([523.0, 659.0, 784.0, 1047.0, 1319.0, 1568.0], 0.09, 0.30)

	# ── Enhancement Pack 53: Enemy lunge strike SFX ── A sharp descending
	# impact whoosh (500→200 Hz, 0.08s, 0.15 vol) for the melee lunge
	# release — the strike moment after windup. The descending pitch
	# conveys a committed forward lunge. Short and quiet so swarms don't
	# stack. Uses _gen_descending for a fast predatory sweep.
	_sfx_streams[SFX_ENEMY_LUNGE] = _gen_descending(500.0, 200.0, 0.08, 0.15)

	# ── Enhancement Pack 53: Boss enrage SFX ── A colossal deep descending
	# growl (80→40 Hz, 0.45s, 0.40 vol) for when a boss enters enrage.
	# Steeper and lower than SFX_BOSS_SPAWN (60→60 Hz sustained, 0.6s) to
	# convey escalating rage rather than an ominous entrance. The low 40 Hz
	# terminal gives a visceral chest-rumble.
	_sfx_streams[SFX_BOSS_ENRAGE] = _gen_descending(80.0, 40.0, 0.45, 0.40)

	# ── Enhancement Pack 53: Weather transition SFX ── A gentle atmospheric
	# sweep (300→500→300 Hz, 0.35s, 0.18 vol) for weather changes. Uses a
	# chime with ascending then descending notes to convey "atmosphere
	# shifting" — a gentle breeze, not a reality tear (SFX_RIFT). Quieter
	# than SFX_RIFT (0.35 vol) since weather changes are informational.
	_sfx_streams[SFX_WEATHER_SHIFT] = _gen_chime([300.0, 500.0, 300.0], 0.12, 0.18)

	# ── Enhancement Pack 58: Weather hazard SFX ──
	# EMP pulse — a sharp electronic buzz (1000→200 Hz descending, 0.15s,
	# 0.30 vol). The fast descending sweep conveys a system short-circuit —
	# the player's dash electronics being disrupted. Moderate volume since
	# the EMP is a significant gameplay event.
	_sfx_streams[SFX_EMP_PULSE] = _gen_descending(1000.0, 200.0, 0.15, 0.30)
	# Gravity shift — a deep wavering whomp using a chime with
	# rising-then-falling notes (60→120→60 Hz, 0.25s, 0.28 vol). The
	# rising-then-falling pitch conveys gravity reversing direction — a
	# physical "lurch" sensation. Distinct from SFX_MUTATION which was
	# previously reused at 0.6× pitch.
	_sfx_streams[SFX_GRAVITY_SHIFT] = _gen_chime([60.0, 120.0, 60.0], 0.08, 0.28)
	# Sand scour — a brief abrasive hiss (noise hit, 0.06s, 0.08 vol) for
	# the sandstorm's per-tick damage. Very short and quiet since the tick
	# fires every 1s and shouldn't stack into noise.
	_sfx_streams[SFX_SAND_SCOUR] = _gen_noise_hit(0.06, 0.08)
	# Acid rain sizzle — a brief corrosive sizzle (noise hit, 0.06s, 0.08
	# vol) for the acid rain's per-tick damage. Same short+quiet pattern as
	# the sand scour. The noise-hit timbre conveys acid eating through the
	# player's surface.
	_sfx_streams[SFX_ACID_SIZZLE] = _gen_noise_hit(0.06, 0.08)
	# ── Enhancement Pack 60: Endgame milestone SFX ──
	# Endgame unlock — deep 5-note fanfare from C3 (two octaves below middle C).
	# The deep bass start conveys a fundamental power shift. Uses the arpeggio
	# generator with a slow note rate (0.10s) for weight and gravitas.
	_sfx_streams[SFX_ENDGAME_UNLOCK] = _gen_arpeggio([130.81, 196.0, 262.0, 330.0, 392.0], 0.10, 0.35)
	# Dungeon clear — bright D major arpeggio ascending through two octaves.
	# Brighter than SFX_QUEST_COMPLETE and distinct from SFX_LEVEL_UP (C major).
	_sfx_streams[SFX_DUNGEON_CLEAR] = _gen_arpeggio([587.0, 784.0, 988.0, 1175.0], 0.08, 0.28)
	# Gauntlet biome clear — punchy 3-note with an octave leap for a "victory hop."
	# Shorter than dungeon clear since it's a smaller milestone.
	_sfx_streams[SFX_GAUNTLET_CLEAR] = _gen_arpeggio([523.0, 659.0, 1047.0], 0.06, 0.22)


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


## Generate a "lub-dub" heartbeat sound (low-HP warning audio).
## Two low-frequency thumps in sequence — the S1/S2 cardiac pattern:
##   - "lub" (S1): 55 Hz fundamental + 110 Hz body, 0.12s, louder
##   - gap:       0.15s silence
##   - "dub" (S2): 55 Hz fundamental + 110 Hz body, 0.08s, 60% volume
## A fast attack + exponential decay envelope on each thump gives the
## percussive "thump" character. Total duration ~0.35s — short enough that
## rapid heartbeats (at high BPM + low HP) don't overlap into a drone.
func _gen_heartbeat() -> AudioStreamWAV:
	var lub_dur: float = 0.12
	var gap_dur: float = 0.15
	var dub_dur: float = 0.08
	var total_dur: float = lub_dur + gap_dur + dub_dur
	var n: int = int(total_dur * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(n * 2)
	var dub_start: int = int((lub_dur + gap_dur) * SAMPLE_RATE)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var sample: float = 0.0
		# Lub (S1) — first thump
		if i < dub_start:
			var local_t: float = t
			var env: float = exp(-local_t * 18.0)  # Fast decay
			if local_t < 0.005:
				env *= local_t / 0.005  # Click-free attack
			sample = (sin(local_t * 55.0 * TAU) * 0.7 + sin(local_t * 110.0 * TAU) * 0.3) * env
		# Dub (S2) — second thump, softer
		else:
			var local_t: float = t - (lub_dur + gap_dur)
			var env: float = exp(-local_t * 22.0)  # Slightly faster decay
			if local_t < 0.004:
				env *= local_t / 0.004
			sample = (sin(local_t * 55.0 * TAU) * 0.42 + sin(local_t * 110.0 * TAU) * 0.18) * env
		# Overall normalization — keep headroom so stacked SFX don't clip
		sample *= 0.85
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