## Zorp Wiggles — Spawn Warning Ring
## Visual warning that appears on the ground before an enemy materializes.
## Expands and pulses, then disappears when the enemy spawns.
##
## Juice improvements:
## - Scale expands with an ease-out curve (decelerating) instead of linear,
##   so the ring "unfurls" quickly then settles — reads as an energy bloom
##   rather than a mechanical growing circle.
## - Multi-octave pulse (two sines at incommensurate frequencies) give an
##   organic, non-rhythmic flicker instead of a metronomic blink.
## - Anticipation flash: in the final 15% of the warning, the ring snaps to
##   full white and peaks in scale — a classic "tell" that telegraphs the
##   exact spawn moment so the player can pre-aim. This is the same trick
##   used in bullet-hell telegraphs (Touhou, Enter the Gungeon).
##   A 3D positional "warp" SFX fires once at the spawn location when the
##   anticipation flash begins, so off-screen spawns the player can't see
##   still register audibly with correct directional cueing — the player
##   hears the materialization coming from the right direction.
## - Final pop tween on free so the ring doesn't just vanish — it flashes
##   out with a quick scale-up + fade, masking the spawn frame.

extends Node3D

class_name SpawnWarningRing

var age: float = 0.0
var duration: float = 1.2
var _material: StandardMaterial3D = null
# Tracks whether the anticipation flash SFX has fired so we only play it once.
var _flash_sfx_played: bool = false

# Instance-level base colors — set by set_tier_color() based on the enemy
# type that's about to spawn. Default to hard (red) so rings without a
# tier override still read as threats.
var _base_color: Color = _BASE_COLOR_HARD
var _base_emission: Color = _BASE_EMISSION_HARD

## Set the warning ring color based on the enemy type's difficulty tier.
## Called by EnemySpawner after instantiating the warning ring. The tier is
## determined by the spawner's _pick_enemy_type distance-from-center logic:
## easy (yellow) → medium (orange) → hard (red). This gives the player an
## instant visual cue about what's materializing before the enemy appears.
func set_tier_color(enemy_type: int) -> void:
	if enemy_type in EnemySpawner.EASY_TYPES:
		_base_color = _BASE_COLOR_EASY
		_base_emission = _BASE_EMISSION_EASY
	elif enemy_type in EnemySpawner.HARD_TYPES:
		_base_color = _BASE_COLOR_HARD
		_base_emission = _BASE_EMISSION_HARD
	else:
		_base_color = _BASE_COLOR_MEDIUM
		_base_emission = _BASE_EMISSION_MEDIUM

# Base colors — stored so the anticipation flash can swap to white and back.
# The default is overridden by set_tier_color() when the spawner passes the
# enemy type, so the ring color communicates the threat tier:
#   easy (yellow) → medium (orange) → hard (red).
# This gives the player an instant visual cue about what's materializing
# before the enemy even appears, matching the telegraph color language
# used in bullet-hell games (yellow = safe, red = dangerous).
const _BASE_COLOR_EASY := Color(1.0, 0.85, 0.2)     # Yellow — easy tier
const _BASE_EMISSION_EASY := Color(0.9, 0.75, 0.15)
const _BASE_COLOR_MEDIUM := Color(1.0, 0.5, 0.2)    # Orange — medium tier
const _BASE_EMISSION_MEDIUM := Color(0.9, 0.4, 0.15)
const _BASE_COLOR_HARD := Color(1.0, 0.3, 0.3)      # Red — hard tier (default)
const _BASE_EMISSION_HARD := Color(1.0, 0.2, 0.2)
const _FLASH_COLOR := Color(1.0, 1.0, 1.0)
const _FLASH_EMISSION := Color(1.0, 0.9, 0.7)

# Anticipation window — the last 15% of the duration snaps to a white flash.
const _FLASH_FRAC := 0.85

@onready var mesh: MeshInstance3D = $MeshInstance3D

# ── Ground glow light ── An OmniLight3D that illuminates the ground below
#    the spawn warning, making spawns visible in dark biomes and giving the
#    telegraph a physical "energy gathering" presence. The light grows with
#    the ring scale and intensifies during the anticipation flash, so the
#    ground literally brightens as the enemy is about to materialize.
var _glow_light: OmniLight3D = null

func _ready() -> void:
	if mesh:
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color(_base_color.r, _base_color.g, _base_color.b, 0.5)
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.emission_enabled = true
		_material.emission = _base_emission * 0.5
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material_override = _material
	# ── Ground glow ── A low OmniLight3D placed at ground level that grows
	# with the warning ring and intensifies during the anticipation flash.
	# The light color matches the warning red so it reads as a threat glow.
	# It starts dim and ramps up so the glow "charges" alongside the ring.
	# POOLING: Uses the PerformanceOptimizer transient light pool instead of
	# allocating a new OmniLight3D per spawn warning. During heavy combat
	# (swarm packs, endless mode), multiple spawn warnings can be active
	# simultaneously — each creating + freeing a light. The pool reuses
	# dormant lights, eliminating per-warning light allocation churn. The
	# pool auto-reclaims the light after the warning duration + a small
	# margin, so we don't need to manage the release ourselves.
	var glow_pos := global_position + Vector3(0, 0.1, 0)
	if PerformanceOptimizer:
		# The pool duration is set slightly longer than the warning duration
		# so the pop tween (which fades the light) has time to complete
		# before the pool auto-reclaims the light.
		_glow_light = PerformanceOptimizer.acquire_transient_light(
			glow_pos, _base_emission, 0.3, duration + 0.3, 3.0, 1.5)
	else:
		# Fallback: create a standalone light (non-pooled path)
		_glow_light = OmniLight3D.new()
		_glow_light.light_color = _base_emission
		_glow_light.light_energy = 0.3  # Starts dim
		_glow_light.omni_range = 3.0
		_glow_light.omni_attenuation = 1.5
		_glow_light.position = Vector3(0, 0.1, 0)  # Local pos (child of warning)
		add_child(_glow_light)

func _process(delta: float) -> void:
	age += delta
	var progress: float = clampf(age / duration, 0.0, 1.0)

	# ── Scale: ease-out cubic so the ring unfurls fast then decelerates.
	# Linear expansion looks mechanical; ease-out reads as an energy bloom.
	# Final scale target is 1.5x (was 1.0 + 1.2*0.5 = 1.6 with old linear).
	var eased: float = 1.0 - pow(1.0 - progress, 3.0)
	var s: float = 1.0 + eased * 0.6
	scale = Vector3.ONE * s

	# ── Ground glow: ramp the light energy and range with the ring progress.
	# The light starts dim (0.3, set in _ready) and brightens as the ring
	# expands, so the ground glow "charges" alongside the visual telegraph.
	# During the anticipation flash, the light snaps to full white-red
	# intensity matching the ring's white flash. After the flash, the light
	# fades to zero as the ring pops out.
	# Guard with is_instance_valid for the pooled-light path — the pool
	# may reclaim the light if the duration timer fires before the warning
	# ends (edge case during scene teardown).
	if _glow_light and is_instance_valid(_glow_light):
		if progress < _FLASH_FRAC:
			# Charging phase — light grows with the ring
			_glow_light.light_energy = 0.3 + eased * 1.2  # 0.3 → 1.5
			_glow_light.omni_range = 3.0 + eased * 4.0  # 3.0 → 7.0
			_glow_light.light_color = _base_emission
		else:
			# Anticipation flash — light peaks at full intensity and shifts
			# toward the warm white flash color, matching the ring
			var glow_flash_t: float = (progress - _FLASH_FRAC) / (1.0 - _FLASH_FRAC)
			var glow_flash_intensity: float = glow_flash_t * glow_flash_t
			_glow_light.light_energy = 1.5 + glow_flash_intensity * 2.5  # 1.5 → 4.0
			_glow_light.omni_range = 7.0 + glow_flash_intensity * 3.0  # 7.0 → 10.0
			_glow_light.light_color = _base_emission.lerp(_FLASH_EMISSION, glow_flash_intensity)

	if _material:
		# ── Anticipation flash: in the final 15% of the warning, snap to
		# full white and ramp emission so the player sees the exact spawn
		# moment coming. The flash intensity ramps up (not snaps) so it
		# reads as a "charging" tell rather than a strobe.
		if progress >= _FLASH_FRAC:
			var flash_t: float = (progress - _FLASH_FRAC) / (1.0 - _FLASH_FRAC)
			# Ease-in quad so the flash accelerates into the spawn moment
			var flash_intensity: float = flash_t * flash_t
			_material.albedo_color = _base_color.lerp(_FLASH_COLOR, flash_intensity)
			_material.albedo_color.a = 0.5 + 0.5 * flash_intensity
			_material.emission = _base_emission.lerp(_FLASH_EMISSION, flash_intensity) * (0.5 + flash_intensity)
			# ── Play the warp SFX once at the start of the anticipation flash
			#    so the player hears the spawn coming. This fires a single
			#    time when the flash begins (progress == _FLASH_FRAC) and
			#    is guarded by _flash_sfx_played so it doesn't repeat.
			#    ── Distance attenuation ── The volume scales with distance to
			#    the player so spawns far off-screen don't play at full volume
			#    (which would be disorienting — the player hears a loud warp
			#    but sees nothing). Within 15m → full volume, at 60m+ → ~15%
			#    volume, smoothstep in between. This keeps nearby spawns
			#    audible while distant ones read as a subtle ambient cue.
			if not _flash_sfx_played:
				_flash_sfx_played = true
				# ── 3D positional SFX ── The spawn warning warp sound now
				#    plays as a positional AudioStreamPlayer3D at the
				#    spawn location, so the player hears the direction
				#    the enemy is materializing from. This is critical
				#    for off-screen spawns — the player can turn toward
				#    the sound to find the threat. Godot's 3D audio
				#    handles the distance attenuation natively (linear
				#    model, 60m max distance), replacing the manual
				#    smoothstep volume calculation.
				AudioManager.play_sfx_3d(AudioManager.SFX_RIFT, global_position)
		else:
			# ── Multi-octave pulse: two sines at incommensurate frequencies
			# (15 Hz and 23 Hz) give an organic, non-rhythmic flicker instead
			# of a metronomic blink. The base alpha fades out as progress
			# increases so the ring dims naturally toward the flash point.
			var pulse: float = 0.5 + 0.5 * (sin(age * 15.0) * 0.7 + sin(age * 23.0) * 0.3)
			var fade: float = 1.0 - (progress / _FLASH_FRAC) * 0.4  # Fade to 60% before flash
			_material.albedo_color = Color(_base_color.r, _base_color.g, _base_color.b, 0.5 * fade * pulse)
			_material.emission = _base_emission * (0.5 * fade * pulse)

	if age >= duration:
		# ── Final pop: quick scale-up + fade-out so the ring doesn't just
		# vanish on the spawn frame. Masks the materialization frame and
		# gives the spawn a satisfying "snap" exit.
		if _material:
			_material.albedo_color = Color(_FLASH_COLOR.r, _FLASH_COLOR.g, _FLASH_COLOR.b, 0.9)
		var pop_tween := create_tween()
		pop_tween.set_parallel(true)
		pop_tween.tween_property(self, "scale", Vector3.ONE * 2.2, 0.12) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD) \
			.set_trans(Tween.TRANS_QUAD)
		if _material:
			pop_tween.tween_property(_material, "albedo_color:a", 0.0, 0.12) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		# Fade the ground glow out alongside the ring pop so the light
		# doesn't snap off while the ring is still fading.
		# Guard with is_instance_valid — the pooled light may have been
		# reclaimed by the transient light pool if the timing is tight.
		if _glow_light and is_instance_valid(_glow_light):
			pop_tween.tween_property(_glow_light, "light_energy", 0.0, 0.12) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		pop_tween.chain().tween_callback(queue_free)
		# Disable further processing while the pop tween runs
		set_process(false)