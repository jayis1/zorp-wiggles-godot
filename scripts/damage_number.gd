## Zorp Wiggles — Damage Number
## Floating 3D Label3D that rises from the hit point and fades out.
## Pops in with a scale overshoot, drifts upward, then fades.
## Ported from the DamageNumber class in Ursina game.py.

extends Label3D

class_name DamageNumber

# ─── Configuration ────────────────────────────────────────────────────────────
var lifetime: float = GameConstants.DMG_NUMBER_LIFETIME
var max_lifetime: float = GameConstants.DMG_NUMBER_LIFETIME
var popin_timer: float = GameConstants.DMG_NUMBER_POPIN_DURATION
var is_crit: bool = false
var is_kill: bool = false
var is_boss: bool = false  # Boss kill — gets a distinct "BOSS SLAIN!" popup

var _base_scale: float = 1.0
var _drift_x: float = 0.0
var _drift_z: float = 0.0
var _start_y: float = 0.0

func _ready() -> void:
	# Configure Label3D for crisp readability
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	shaded = false
	double_sided = true
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	outline_modulate = Color(0, 0, 0, 0.8)
	outline_size = 8
	pixel_size = 0.008

	_start_y = global_position.y

	# Random horizontal drift so multiple numbers don't overlap
	_drift_x = randf_range(-0.5, 0.5)
	_drift_z = randf_range(-0.3, 0.3)

	# Start small for pop-in
	scale = Vector3.ONE * GameConstants.DMG_NUMBER_POPIN_START_SCALE

func _process(delta: float) -> void:
	lifetime -= delta

	if popin_timer > 0:
		popin_timer -= delta
		_update_popin()
	else:
		# Settle at base scale
		scale = Vector3.ONE * _base_scale

	# Rise upward + drift
	var rise_amount := GameConstants.DMG_NUMBER_RISE_SPEED * delta
	global_position.y += rise_amount
	global_position.x += _drift_x * delta
	global_position.z += _drift_z * delta

	# ── Crit / kill jitter ── Critical and killing hits get a brief horizontal
	# micro-jitter (a fast side-to-side wobble) on top of the drift, so they
	# feel more visceral than normal hits. The jitter is driven by a decaying
	# envelope that's strongest right after the pop-in completes (when the
	# number has "landed" at its base scale) and eases to zero over ~0.4s so
	# the number settles smoothly before the fade-out begins. The wobble uses
	# a high-frequency sine (28 Hz) so it reads as a rapid "impact vibration"
	# rather than a slow sway. Normal (non-crit) hits skip this entirely to
	# preserve visual hierarchy — only big hits vibrate.
	if (is_crit or is_kill) and popin_timer <= 0.0:
		# Boss kills get a stronger, longer jitter for extra impact.
		var jitter_scale: float = 1.7 if is_boss else 1.0
		var jitter_window: float = 0.6 if is_boss else 0.4
		# Time since pop-in finished, clamped to the jitter envelope window.
		var since_popin: float = clampf(
			(max_lifetime - lifetime) - GameConstants.DMG_NUMBER_POPIN_DURATION,
			0.0, jitter_window)
		if since_popin < jitter_window:
			var env: float = 1.0 - (since_popin / jitter_window)  # 1 → 0 linear decay
			var env_eased: float = env * env  # quadratic so it starts strong
			var jitter_amp: float = 0.18 * env_eased * jitter_scale  # Max ~18cm sideways
			# Incoherent X/Z frequencies so the wobble isn't a clean circle
			var wob_x: float = sin(since_popin * 28.0) * jitter_amp
			var wob_z: float = sin(since_popin * 31.0 + 1.7) * jitter_amp * 0.6
			global_position.x += wob_x * delta * 10.0
			global_position.z += wob_z * delta * 10.0

	# Fade out in the second half of life. Use an ease-in quadratic curve
	# (alpha = t²) instead of a linear ramp: the number stays near-full
	# opacity for most of its life and only drops off sharply at the end.
	# A linear fade makes the number visibly dim from the moment the fade
	# window starts, which reads as "the number is dying" too early — the
	# quadratic keeps it punchy and readable, then snaps out of view.
	# This mirrors classic arcade damage-pop behavior (Vlambeer / Doom Eternal).
	var life_frac: float = lifetime / max_lifetime
	if life_frac < GameConstants.DMG_NUMBER_FADE_START:
		var fade_t: float = life_frac / GameConstants.DMG_NUMBER_FADE_START  # 1→0
		# Quadratic ease-in: t² — holds opacity, then drops fast at the end
		var fade_alpha: float = fade_t * fade_t
		modulate.a = clampf(fade_alpha, 0.0, 1.0)

	if lifetime <= 0:
		queue_free()

func _update_popin() -> void:
	# Pop-in: start_scale → peak_scale → settle_scale using proper easing curves.
	# First half uses ease-out cubic (1-(1-t)^3) for a quick, decisive pop.
	# Second half uses ease-out quartic (1-(1-t)^4) for a soft, decelerating landing.
	# Replaces the previous linear lerp with the same juice techniques used on
	# dash squash. Note: Godot's ease(t, curve) uses curve<1 for ease-out, but
	# the manual pow formula is clearer and matches standard animation terminology.
	var progress: float = 1.0 - (popin_timer / GameConstants.DMG_NUMBER_POPIN_DURATION)
	progress = clampf(progress, 0.0, 1.0)

	var start_s := GameConstants.DMG_NUMBER_POPIN_START_SCALE
	var peak_s := GameConstants.DMG_NUMBER_POPIN_PEAK_SCALE
	var settle_s := 1.0

	var current_scale: float
	if progress < 0.6:
		# Ramp from start to peak (first 60%) — ease-out cubic: fast pop, decelerates
		var t: float = 1.0 - pow(1.0 - progress / 0.6, 3.0)
		current_scale = lerpf(start_s, peak_s, t)
	else:
		# Settle from peak to base (last 40%) — ease-out quartic: soft landing
		var t: float = 1.0 - pow(1.0 - (progress - 0.6) / 0.4, 4.0)
		current_scale = lerpf(peak_s, settle_s, t)

	scale = Vector3.ONE * current_scale * _base_scale

## Configure the damage number's appearance based on type and amount.
## Boss kills get a dramatic magenta "BOSS SLAIN!" popup that's larger and
## lives longer than a normal kill, so downing a major foe feels like an event.
func configure(amount: int, crit: bool, kill: bool, boss: bool = false) -> void:
	is_crit = crit
	is_kill = kill
	is_boss = boss

	var text_str: String
	var color: Color
	var scale_factor: float = GameConstants.DMG_NUMBER_BASE_SCALE

	if boss:
		# Boss kills are the climax — magenta/gold, big, and longer-lived so
		# the player has time to register the milestone during the hit-stop.
		text_str = "☠ %d BOSS SLAIN!" % amount
		color = Color(1.0, 0.2, 0.8)  # Magenta — distinct from gold crits & yellow kills
		scale_factor = GameConstants.DMG_NUMBER_KILL_SCALE * 1.4
		# Boss popups live ~2x longer so they're still on-screen when the
		# hit-stop ends and the death spectacle begins.
		lifetime = max_lifetime * 2.0
		max_lifetime = lifetime
	elif kill:
		text_str = "%d KILL!" % amount
		color = GameConstants.DMG_NUMBER_KILL_COLOR
		scale_factor = GameConstants.DMG_NUMBER_KILL_SCALE
	elif crit:
		text_str = "★%d" % amount
		color = GameConstants.DMG_NUMBER_CRIT_COLOR
		scale_factor = GameConstants.DMG_NUMBER_CRIT_SCALE
	else:
		text_str = str(amount)
		color = GameConstants.DMG_NUMBER_NORMAL_COLOR

	_base_scale = scale_factor
	text = text_str
	modulate = color

## Configure as an XP gain popup (cyan-blue "+N XP")
func configure_xp(amount: int) -> void:
	is_crit = false
	is_kill = false
	_base_scale = 0.95
	text = "+%d XP" % amount
	modulate = GameConstants.DMG_NUMBER_XP_COLOR

## Configure as a heal popup (green "+N")
func configure_heal(amount: int) -> void:
	is_crit = false
	is_kill = false
	_base_scale = 1.1
	text = "+%d" % amount
	modulate = GameConstants.DMG_NUMBER_HEAL_COLOR

## Static factory: create and spawn a damage number in the world.
static func spawn(parent: Node, pos: Vector3, amount: int, is_crit: bool = false, is_kill: bool = false, is_boss: bool = false) -> void:
	var dn := DamageNumber.new()
	parent.add_child(dn)
	# Add jitter so overlapping numbers spread out
	var jitter_x := randf_range(-GameConstants.DMG_NUMBER_JITTER_X, GameConstants.DMG_NUMBER_JITTER_X)
	var jitter_z := randf_range(-GameConstants.DMG_NUMBER_JITTER_Z, GameConstants.DMG_NUMBER_JITTER_Z)
	dn.global_position = pos + Vector3(jitter_x, 2.0, jitter_z)
	dn.configure(amount, is_crit, is_kill, is_boss)