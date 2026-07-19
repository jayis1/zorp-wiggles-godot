## Zorp Wiggles — Spawn Warning Ring
## Visual warning that appears on the ground before an enemy materializes.
## Expands and pulses, then disappears when the enemy spawns.
##
## Juice improvements:
## - Scale expands with an ease-out curve (decelerating) instead of linear,
##   so the ring "unfurls" quickly then settles — reads as an energy bloom
##   rather than a mechanical growing circle.
## - Multi-octave pulse (two sines at incommensurate frequencies) gives an
##   organic, non-rhythmic flicker instead of a metronomic blink.
## - Anticipation flash: in the final 15% of the warning, the ring snaps to
##   full white and peaks in scale — a classic "tell" that telegraphs the
##   exact spawn moment so the player can pre-aim. This is the same trick
##   used in bullet-hell telegraphs (Touhou, Enter the Gungeon).
## - Final pop tween on free so the ring doesn't just vanish — it flashes
##   out with a quick scale-up + fade, masking the spawn frame.

extends Node3D

class_name SpawnWarningRing

var age: float = 0.0
var duration: float = 1.2
var _material: StandardMaterial3D = null

# Base colors — stored so the anticipation flash can swap to white and back.
const _BASE_COLOR := Color(1.0, 0.3, 0.3)
const _BASE_EMISSION := Color(1.0, 0.2, 0.2)
const _FLASH_COLOR := Color(1.0, 1.0, 1.0)
const _FLASH_EMISSION := Color(1.0, 0.9, 0.7)

# Anticipation window — the last 15% of the duration snaps to a white flash.
const _FLASH_FRAC := 0.85

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	if mesh:
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color(_BASE_COLOR.r, _BASE_COLOR.g, _BASE_COLOR.b, 0.5)
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.emission_enabled = true
		_material.emission = _BASE_EMISSION * 0.5
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material_override = _material

func _process(delta: float) -> void:
	age += delta
	var progress: float = clampf(age / duration, 0.0, 1.0)

	# ── Scale: ease-out cubic so the ring unfurls fast then decelerates.
	# Linear expansion looks mechanical; ease-out reads as an energy bloom.
	# Final scale target is 1.5x (was 1.0 + 1.2*0.5 = 1.6 with old linear).
	var eased: float = 1.0 - pow(1.0 - progress, 3.0)
	var s: float = 1.0 + eased * 0.6
	scale = Vector3.ONE * s

	if _material:
		# ── Anticipation flash: in the final 15% of the warning, snap to
		# full white and ramp emission so the player sees the exact spawn
		# moment coming. The flash intensity ramps up (not snaps) so it
		# reads as a "charging" tell rather than a strobe.
		if progress >= _FLASH_FRAC:
			var flash_t: float = (progress - _FLASH_FRAC) / (1.0 - _FLASH_FRAC)
			# Ease-in quad so the flash accelerates into the spawn moment
			var flash_intensity: float = flash_t * flash_t
			_material.albedo_color = _BASE_COLOR.lerp(_FLASH_COLOR, flash_intensity)
			_material.albedo_color.a = 0.5 + 0.5 * flash_intensity
			_material.emission = _BASE_EMISSION.lerp(_FLASH_EMISSION, flash_intensity) * (0.5 + flash_intensity)
		else:
			# ── Multi-octave pulse: two sines at incommensurate frequencies
			# (15 Hz and 23 Hz) give an organic, non-rhythmic flicker instead
			# of a metronomic blink. The base alpha fades out as progress
			# increases so the ring dims naturally toward the flash point.
			var pulse: float = 0.5 + 0.5 * (sin(age * 15.0) * 0.7 + sin(age * 23.0) * 0.3)
			var fade: float = 1.0 - (progress / _FLASH_FRAC) * 0.4  # Fade to 60% before flash
			_material.albedo_color = Color(_BASE_COLOR.r, _BASE_COLOR.g, _BASE_COLOR.b, 0.5 * fade * pulse)
			_material.emission = _BASE_EMISSION * (0.5 * fade * pulse)

	if age >= duration:
		# ── Final pop: quick scale-up + fade-out so the ring doesn't just
		# vanish on the spawn frame. Masks the materialization frame and
		# gives the spawn a satisfying "snap" exit.
		if _material:
			_material.albedo_color = Color(_FLASH_COLOR.r, _FLASH_COLOR.g, _FLASH_COLOR.b, 0.9)
		var pop_tween := create_tween()
		pop_tween.set_parallel(true)
		pop_tween.tween_property(self, "scale", Vector3.ONE * 2.2, 0.12) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_QUAD)
		if _material:
			pop_tween.tween_property(_material, "albedo_color:a", 0.0, 0.12) \
				.set_ease(Tween.EASE_IN)
		pop_tween.chain().tween_callback(queue_free)
		# Disable further processing while the pop tween runs
		set_process(false)