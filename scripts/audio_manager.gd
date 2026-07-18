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
const SFX_BOSS_SPAWN: String = "boss_spawn"
const SFX_BOSS_DEFEATED: String = "boss_defeated"
const SFX_EXPLOSION: String = "explosion"
const SFX_PULSE_WAVE: String = "pulse_wave"
const SFX_HEAL: String = "heal"
const SFX_DASH_BUMP: String = "dash_bump"
const SFX_COMBO_MILESTONE: String = "combo_milestone"
const SFX_UI_CLICK: String = "ui_click"
const SFX_MUTATION: String = "mutation"
const SFX_RIFT: String = "rift"
const SFX_THUNDER: String = "thunder"
const SFX_REVIVE: String = "revive"
const SFX_PET: String = "pet"
const SFX_CRAFT: String = "craft"
const SFX_ARENA: String = "arena"


func _ready() -> void:
	_create_sfx_pool()
	_generate_all_sfx()
	_generate_all_music()
	_initialized = true
	# Connect to game signals for automatic SFX
	_connect_signals()
	# Apply initial volumes
	_apply_volumes()


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
func play_sfx(sfx_name: String) -> void:
	if not _initialized:
		return
	if not _sfx_streams.has(sfx_name):
		return
	var player = _next_sfx_player()
	player.stream = _sfx_streams[sfx_name]
	player.volume_db = linear_to_db(sfx_volume * master_volume)
	player.play()


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
	_music_player.volume_db = linear_to_db(0.0)
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
	_boss_music_player.volume_db = linear_to_db(0.0)
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
	# Master bus volume
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
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
	var vol_db = linear_to_db(music_volume * master_volume)
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
			linear_to_db(0.0), MUSIC_FADE_OUT_DURATION) \
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
			linear_to_db(0.0), MUSIC_FADE_OUT_DURATION) \
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
	fade_tween.tween_property(player, "volume_db",
		linear_to_db(target_linear), duration) \
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
	_sfx_streams[SFX_ENEMY_DEATH] = _gen_pop(0.12, 0.35)
	_sfx_streams[SFX_BOSS_SPAWN] = _gen_rumble(60.0, 1.0, 0.6)
	_sfx_streams[SFX_BOSS_DEFEATED] = _gen_arpeggio([784.0, 988.0, 1175.0, 1568.0], 0.1, 0.4)
	_sfx_streams[SFX_EXPLOSION] = _gen_explosion(0.4, 0.6)
	_sfx_streams[SFX_PULSE_WAVE] = _gen_whoosh(0.3, 0.4)
	_sfx_streams[SFX_HEAL] = _gen_chime([659.0, 988.0], 0.2, 0.3)
	_sfx_streams[SFX_DASH_BUMP] = _gen_blip(200.0, 0.06, 0.3)
	_sfx_streams[SFX_COMBO_MILESTONE] = _gen_arpeggio([523.0, 659.0, 784.0], 0.06, 0.35)
	_sfx_streams[SFX_UI_CLICK] = _gen_blip(600.0, 0.03, 0.2)
	_sfx_streams[SFX_MUTATION] = _gen_chime([440.0, 554.0, 659.0], 0.25, 0.3)
	_sfx_streams[SFX_RIFT] = _gen_whoosh(0.5, 0.35)
	_sfx_streams[SFX_THUNDER] = _gen_noise_hit(0.3, 0.7)
	_sfx_streams[SFX_REVIVE] = _gen_arpeggio([392.0, 523.0, 659.0, 784.0, 988.0], 0.07, 0.35)
	_sfx_streams[SFX_PET] = _gen_blip(900.0, 0.05, 0.25)
	_sfx_streams[SFX_CRAFT] = _gen_chime([659.0, 880.0], 0.12, 0.3)
	_sfx_streams[SFX_ARENA] = _gen_rumble(50.0, 1.2, 0.5)


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