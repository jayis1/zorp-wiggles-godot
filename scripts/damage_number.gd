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

	# Fade out in the second half of life
	var life_frac: float = lifetime / max_lifetime
	if life_frac < GameConstants.DMG_NUMBER_FADE_START:
		var fade_alpha: float = life_frac / GameConstants.DMG_NUMBER_FADE_START
		modulate.a = clampf(fade_alpha, 0.0, 1.0)

	if lifetime <= 0:
		queue_free()

func _update_popin() -> void:
	# Pop-in: start_scale → peak_scale → settle_scale
	var progress: float = 1.0 - (popin_timer / GameConstants.DMG_NUMBER_POPIN_DURATION)
	progress = clampf(progress, 0.0, 1.0)

	var start_s := GameConstants.DMG_NUMBER_POPIN_START_SCALE
	var peak_s := GameConstants.DMG_NUMBER_POPIN_PEAK_SCALE
	var settle_s := 1.0

	var current_scale: float
	if progress < 0.6:
		# Ramp from start to peak (first 60% of popin duration)
		var t: float = progress / 0.6
		current_scale = lerpf(start_s, peak_s, t)
	else:
		# Settle from peak to base (last 40%)
		var t: float = (progress - 0.6) / 0.4
		current_scale = lerpf(peak_s, settle_s, t)

	scale = Vector3.ONE * current_scale * _base_scale

## Configure the damage number's appearance based on type and amount.
func configure(amount: int, crit: bool, kill: bool) -> void:
	is_crit = crit
	is_kill = kill

	var text_str: String
	var color: Color
	var scale_factor: float = GameConstants.DMG_NUMBER_BASE_SCALE

	if kill:
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
static func spawn(parent: Node, pos: Vector3, amount: int, is_crit: bool = false, is_kill: bool = false) -> void:
	var dn := DamageNumber.new()
	parent.add_child(dn)
	# Add jitter so overlapping numbers spread out
	var jitter_x := randf_range(-GameConstants.DMG_NUMBER_JITTER_X, GameConstants.DMG_NUMBER_JITTER_X)
	var jitter_z := randf_range(-GameConstants.DMG_NUMBER_JITTER_Z, GameConstants.DMG_NUMBER_JITTER_Z)
	dn.global_position = pos + Vector3(jitter_x, 2.0, jitter_z)
	dn.configure(amount, is_crit, is_kill)