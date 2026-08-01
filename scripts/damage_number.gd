## Zorp Wiggles — Damage Number
## Floating 3D Label3D that rises from the hit point and fades out.
## Pops in with a scale overshoot, drifts upward, then fades.
## Ported from the DamageNumber class in Ursina game.py.

extends Label3D

class_name DamageNumber

# ── Lightweight free-list pool ──────────────────────────────────────────────
# Damage numbers are spawned on every hit (~9/sec during combat, more with
# multi-bolt mods). Each `DamageNumber.new()` allocates a Label3D + configures
# its material/outline from scratch. A static free-list reuses recycled
# instances instead of allocating new ones, eliminating per-hit allocation
# churn. The pool is capped to prevent unbounded memory growth. Instances
# are released back to the pool when their lifetime expires (instead of
# queue_free), and re-acquired on spawn. The pool self-heals: if the free
# list is empty, a new instance is created (fallback to the old path).
static var _pool: Array[DamageNumber] = []
const POOL_MAX_SIZE: int = 40  # Cap — prevents unbounded growth

static func _acquire() -> DamageNumber:
	if _pool.size() > 0:
		return _pool.pop_back()
	return DamageNumber.new()

func _release_to_pool() -> void:
	# Hide + detach from tree, return to the free list for reuse.
	# Only pool if the tree still exists (avoid issues during scene teardown).
	if not get_tree():
		queue_free()
		return
	visible = false
	if get_parent():
		get_parent().remove_child(self)
	if _pool.size() < POOL_MAX_SIZE:
		process_mode = Node.PROCESS_MODE_DISABLED
		_pool.append(self)
	else:
		# Pool full — let it actually free to avoid memory growth.
		queue_free()

## Clear the entire pool (scene change / game restart). Frees all dormant
## pooled instances so memory is released between runs. Called by
## GameManager on game_restart to prevent stale instances from a previous
## scene lingering in the static pool.
static func clear_pool() -> void:
	for dn in _pool:
		if is_instance_valid(dn):
			dn.queue_free()
	_pool.clear()

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
# ── Directional drift bias ── When a source direction is provided (from the
#    projectile to the enemy, or from the player to the enemy), the random
#    horizontal drift is biased away from that direction so the damage
#    number pops outward from the hit point — toward the player's view —
#    rather than in a purely random direction. This makes hits feel
#    directional: a shot from the left pushes the number to the right,
#    reinforcing the impact direction. The bias is blended with the random
#    drift (not replacing it) so numbers still spread organically on rapid
#    multi-hits. 0.0 = fully random (old behavior), 1.0 = fully biased.
var _drift_bias_x: float = 0.0
var _drift_bias_z: float = 0.0
const DRIFT_BIAS_STRENGTH: float = 0.6  # 60% biased, 40% random

func _ready() -> void:
	# Configure Label3D for crisp readability.
	# These properties persist on the node across pool cycles, so they only
	# need to be set once (first _ready). On pooled re-entry, they're already
	# configured and we just reset the per-spawn runtime state below.
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	shaded = false
	double_sided = true
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	outline_modulate = Color(0, 0, 0, 0.8)
	outline_size = 8
	pixel_size = 0.008

	# ── Per-spawn reset (runs on every _ready, including pool re-entry) ──
	# Reset lifetime + popin timer — pooled instances have stale (≤0) values
	# from their previous use. Without this reset, a reused damage number
	# would immediately expire (lifetime ≤ 0 → instant re-pool) and skip the
	# pop-in animation (popin_timer ≤ 0). configure() may override lifetime/
	# max_lifetime for boss kills, but the baseline reset here ensures all
	# non-boss hits and the popin timer are correct for every spawn.
	lifetime = GameConstants.DMG_NUMBER_LIFETIME
	max_lifetime = GameConstants.DMG_NUMBER_LIFETIME
	popin_timer = GameConstants.DMG_NUMBER_POPIN_DURATION
	_start_y = global_position.y

	# Random horizontal drift so multiple numbers don't overlap.
	# The drift is blended with a directional bias (set by spawn_with_bias)
	# so the number pops away from the source — 60% biased, 40% random.
	_drift_x = lerpf(randf_range(-0.5, 0.5), _drift_bias_x, DRIFT_BIAS_STRENGTH)
	_drift_z = lerpf(randf_range(-0.3, 0.3), _drift_bias_z, DRIFT_BIAS_STRENGTH)

	# Start small for pop-in
	scale = Vector3.ONE * GameConstants.DMG_NUMBER_POPIN_START_SCALE

	# Reset modulate alpha to full (pooled instances may have faded to 0)
	modulate.a = 1.0

	# Re-enable processing (pool disables it on release)
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true

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
		_release_to_pool()

func _update_popin() -> void:
	# Pop-in: start_scale → peak_scale → settle_scale using proper easing curves.
	# First half uses ease-out cubic (1-(1-t)^3) for a quick, decisive pop.
	# Second half uses ease-out quartic (1-(1-t)^4) for a soft, decelerating landing.
	# Replaces the previous linear lerp with the same juice techniques used on
	# dash squash. Note: Godot's ease(t, curve) uses curve<1 for ease-out, but
	# the manual pow formula is clearer and matches standard animation terminology.
	#
	# ── Crit/Kill anticipation ── Critical and killing hits get a brief
	# initial shrink (anticipation) before the overshoot pop, so they
	# read as a "wind-up then snap" impact rather than just appearing.
	# The anticipation takes the first 15% of the pop-in duration
	# (shrinking to 0.7× start_scale), then the overshoot pop covers
	# the remaining 85%. This is classic anticipation→action framing
	# from animation — the shrink creates a visual "gathering" before
	# the "release" of the big number landing. Normal hits skip this
	# for speed (a 0.15s wind-up on every hit would feel sluggish).
	var progress: float = 1.0 - (popin_timer / GameConstants.DMG_NUMBER_POPIN_DURATION)
	progress = clampf(progress, 0.0, 1.0)

	var start_s := GameConstants.DMG_NUMBER_POPIN_START_SCALE
	var peak_s := GameConstants.DMG_NUMBER_POPIN_PEAK_SCALE
	var settle_s := 1.0

	# Anticipation threshold — crit/kill numbers get a wind-up phase
	var antic_frac: float = 0.15 if (is_crit or is_kill) else 0.0

	var current_scale: float
	if progress < antic_frac:
		# Anticipation phase: shrink slightly (ease-in quad for a "pulling back" feel)
		var t: float = progress / antic_frac
		t = t * t  # Ease-in quadratic
		current_scale = lerpf(start_s, start_s * 0.7, t)
	elif progress < 0.6:
		# Ramp from start (post-anticipation) to peak (first 60% of total)
		# — ease-out cubic: fast pop, decelerates
		var t: float = 1.0 - pow(1.0 - (progress - antic_frac) / (0.6 - antic_frac), 3.0)
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
## Uses the static free-list pool to reuse recycled instances when available,
## avoiding per-hit Label3D allocation during combat.
## Optional `source_pos` biases the drift so the number pops away from the
## source (e.g. the player's position), making hits feel directional.
static func spawn(parent: Node, pos: Vector3, amount: int, is_crit: bool = false, is_kill: bool = false, is_boss: bool = false, source_pos: Vector3 = Vector3.ZERO) -> void:
	var dn := _acquire()
	# Request _ready() to fire on re-entry for pooled instances so per-spawn
	# runtime state (drift, scale, modulate) resets cleanly.
	dn.request_ready()
	# ── Directional drift bias ── If a source position is provided (e.g. the
	#    player's position), compute a horizontal direction from source→hit
	#    and bias the drift so the number pops outward, away from the source.
	#    This makes hits feel directional — a shot from the player pushes the
	#    damage number toward the player's view, reinforcing the impact line.
	#    The bias MUST be set BEFORE add_child() so _ready() (which reads it
	#    to compute the lerped drift) sees the fresh values — _ready fires
	#    synchronously during add_child because request_ready() was called.
	if source_pos != Vector3.ZERO:
		var bias_dir: Vector3 = (pos - source_pos)
		bias_dir.y = 0.0
		if bias_dir.length_squared() > 0.01:
			bias_dir = bias_dir.normalized()
			# Scale to match the random drift range (~0.5 on X, ~0.3 on Z)
			dn._drift_bias_x = bias_dir.x * 0.5
			dn._drift_bias_z = bias_dir.z * 0.3
		else:
			dn._drift_bias_x = 0.0
			dn._drift_bias_z = 0.0
	else:
		dn._drift_bias_x = 0.0
		dn._drift_bias_z = 0.0
	parent.add_child(dn)
	# Add jitter so overlapping numbers spread out
	var jitter_x := randf_range(-GameConstants.DMG_NUMBER_JITTER_X, GameConstants.DMG_NUMBER_JITTER_X)
	var jitter_z := randf_range(-GameConstants.DMG_NUMBER_JITTER_Z, GameConstants.DMG_NUMBER_JITTER_Z)
	dn.global_position = pos + Vector3(jitter_x, 2.0, jitter_z)
	dn.configure(amount, is_crit, is_kill, is_boss)