## Zorp Wiggles — Procedural Music Generator (Phase 33)
## Synthesizes short ambient loops from biome properties. Each generated track
## is derived from a "property signature" — a root frequency, a scale, and a
## tempo. Distinct signatures produce distinct tracks, so a "fire+void"
## anomalous zone sounds different from an "ice+crystal" zone.
##
## The generator runs entirely offline (no AudioStreamGenerator playback) — it
## produces AudioStreamWAV buffers that the AudioManager can swap in like the
## existing biome drone loops. This keeps the audio pipeline uniform.
##
## All frequencies are in Hz; all amplitudes are in 0-1 range.

extends Node

class_name ProcMusicGen

const SAMPLE_RATE: int = 22050

# ─── Scales (semitone offsets from the root) ───────────────────────────────────
const SCALE_MAJOR: Array[int] = [0, 2, 4, 5, 7, 9, 11]
const SCALE_MINOR: Array[int] = [0, 2, 3, 5, 7, 8, 10]
const SCALE_PENTATONIC: Array[int] = [0, 2, 4, 7, 9]
const SCALE_WHOLE_TONE: Array[int] = [0, 2, 4, 6, 8, 10]
const SCALE_CHROMATIC: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

# ─── Cache of generated streams keyed by signature string ──────────────────────
var _cache: Dictionary = {}

# ─── Public API ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("procedural_music")

# Build a signature string from a set of properties.
# Properties: root_freq (Hz), scale_id (int), tempo (sec/beat), mood (0..1).
func make_signature(root_freq: float, scale_id: int, tempo: float, mood: float) -> String:
	return "%.2f:%d:%.2f:%.2f" % [root_freq, scale_id, tempo, mood]

# Generate (or fetch from cache) an AudioStreamWAV for the given signature.
func generate_track(root_freq: float, scale_id: int, tempo: float, mood: float) -> AudioStreamWAV:
	var sig := make_signature(root_freq, scale_id, tempo, mood)
	if _cache.has(sig):
		return _cache[sig]
	var scale: Array[int] = _get_scale(scale_id)
	var stream := _synthesize(root_freq, scale, tempo, mood)
	_cache[sig] = stream
	return stream

# Generate a track from a biome's property signature (used by anomalous zones).
func generate_from_traits(traits: Array) -> AudioStreamWAV:
	# Map traits to musical properties.
	var root: float = 110.0
	var scale_id: int = 0
	var tempo: float = GameConstants.PROC_MUSIC_TEMPO
	var mood: float = 0.5
	# Each trait nudges the musical character.
	for t in traits:
		match t:
			GameConstants.ProcBiomeTrait.GLOWING:
				root = 146.83  # D — bright
				scale_id = 0   # Major
				mood = 0.7
			GameConstants.ProcBiomeTrait.CRYSTAL_SHARD:
				root = 164.81  # E — prismatic
				scale_id = 2   # Pentatonic
				mood = 0.65
			GameConstants.ProcBiomeTrait.TOXIC_HAZE:
				root = 82.41  # E low — murky
				scale_id = 1   # Minor
				mood = 0.3
			GameConstants.ProcBiomeTrait.ECHO_CHAMBER:
				root = 130.81  # C — hollow
				scale_id = 4   # Chromatic
				mood = 0.4
			GameConstants.ProcBiomeTrait.GRAVITY_WELL:
				root = 55.0   # A1 — deep
				scale_id = 1   # Minor
				mood = 0.2
			GameConstants.ProcBiomeTrait.RAIN_INDOOR:
				root = 98.0   # G — pensive
				scale_id = 1   # Minor
				mood = 0.35
			GameConstants.ProcBiomeTrait.MIRROR_SURFACE:
				root = 196.0  # G3 — bright, reflective
				scale_id = 3   # Whole tone — dreamy
				mood = 0.6
			GameConstants.ProcBiomeTrait.MAGMA_FISSURES:
				root = 61.74  # B1 — hot, deep
				scale_id = 1   # Minor
				mood = 0.15
	return generate_track(root, scale_id, tempo, mood)

# ─── Synthesis ──────────────────────────────────────────────────────────────────

func _get_scale(scale_id: int) -> Array[int]:
	match scale_id:
		0: return SCALE_MAJOR
		1: return SCALE_MINOR
		2: return SCALE_PENTATONIC
		3: return SCALE_WHOLE_TONE
		4: return SCALE_CHROMATIC
		_: return SCALE_MAJOR

func _note_freq(root: float, semitone: int) -> float:
	return root * pow(2.0, float(semitone) / 12.0)

func _synthesize(root: float, scale: Array[int], tempo: float, mood: float) -> AudioStreamWAV:
	var total_beats: int = GameConstants.PROC_MUSIC_BARS * GameConstants.PROC_MUSIC_BEATS_PER_BAR
	var duration: float = total_beats * tempo
	var n: int = int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)  # 16-bit mono
	# Pre-compute the note sequence — pick PROC_MUSIC_NOTES_PER_BAR notes per bar
	# from the scale, weighted by mood (low mood = lower notes, high = higher).
	var notes: Array[float] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(root * 1000.0) + int(mood * 100.0) + scale.size()
	for bar in GameConstants.PROC_MUSIC_BARS:
		for note_idx in GameConstants.PROC_MUSIC_NOTES_PER_BAR:
			# Pick a scale degree; mood biases toward higher degrees when high.
			var degree: int
			if rng.randf() < mood:
				degree = rng.randi_range(scale.size() / 2, scale.size() - 1)
			else:
				degree = rng.randi_range(0, scale.size() / 2)
			var octave: int = rng.randi_range(0, 1)
			var semitone: int = scale[degree] + octave * 12
			notes.append(_note_freq(root, semitone))
	# Schedule notes evenly across the loop duration.
	var beats_per_note: float = float(GameConstants.PROC_MUSIC_BEATS_PER_BAR) / float(GameConstants.PROC_MUSIC_NOTES_PER_BAR)
	var note_dur: float = beats_per_note * tempo
	# Write the sample buffer.
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var sample: float = 0.0
		# Sum the active notes.
		for ni in notes.size():
			var note_start: float = ni * note_dur
			var age: float = t - note_start
			if age < 0.0 or age > note_dur + GameConstants.PROC_MUSIC_RELEASE:
				continue
			# ADSR envelope (simplified: attack + release).
			var env: float = 1.0
			if age < GameConstants.PROC_MUSIC_ATTACK:
				env = age / GameConstants.PROC_MUSIC_ATTACK
			elif age > note_dur:
				var rel_age: float = age - note_dur
				env = maxf(0.0, 1.0 - rel_age / GameConstants.PROC_MUSIC_RELEASE)
			# Two oscillators: sine + subtle detuned saw for warmth.
			var freq: float = notes[ni]
			var osc: float = sin(t * freq * TAU) * 0.6
			osc += sin(t * freq * 1.005 * TAU) * 0.2  # Slight detune
			sample += osc * env
		# Soft pad drone underneath, sustained for the whole loop.
		sample += sin(t * root * TAU) * 0.15 * mood
		sample += sin(t * root * 2.0 * TAU) * 0.08 * mood
		# Soft saturation to prevent harsh clipping when many notes overlap.
		sample = tanh(sample * 1.5) * 0.7
		# Apply base amplitude.
		sample *= GameConstants.PROC_MUSIC_BASE_AMP
		# Loop boundary fade for seamless wraparound.
		var fade_dur: float = 0.4
		var progress: float = t / duration
		if progress < fade_dur / duration:
			sample *= progress / (fade_dur / duration)
		elif progress > 1.0 - fade_dur / duration:
			sample *= (1.0 - progress) / (fade_dur / duration)
		_pack_sample(data, i, sample)
	# Build the WAV stream.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav

func _pack_sample(data: PackedByteArray, index: int, sample: float) -> void:
	# Clamp + convert to signed 16-bit.
	var s: float = clampf(sample, -1.0, 1.0)
	var iv: int = int(s * 32767.0)
	# Pack as little-endian 16-bit.
	data[index * 2] = iv & 0xFF
	data[index * 2 + 1] = (iv >> 8) & 0xFF