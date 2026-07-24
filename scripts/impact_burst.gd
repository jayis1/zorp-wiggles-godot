## Zorp Wiggles — Impact Burst Effect
## Quick expanding + fading sphere that plays on projectile hit.
## Uses a tween for smooth scale-up and fade-out, then queue_free.
## Includes a brief OmniLight3D flash for a punchy real-time hit feel.
##
## POOLING: When PerformanceOptimizer is available, impact bursts are
## pooled. The lifecycle is:
##   1. PerformanceOptimizer.acquire() → _pool_reset() + add_child() + _ready()
##   2. Caller sets impact_color (if override needed)
##   3. Caller calls _play() to trigger the animation
##   4. Animation completes → _deactivate() → PerformanceOptimizer.release()
## For non-pooled use (fallback), _ready() calls _play() automatically.

extends Node3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

# ─── Shared Resources ──────────────────────────────────────────────────────────
# Impact bursts are spawned on every projectile hit (~9/sec during combat).
# Sharing the mesh and material eliminates per-hit GPU resource allocation.
# The material is duplicated per-instance because the alpha tweens independently.
static var _shared_mesh: SphereMesh = null
static var _shared_material_base: StandardMaterial3D = null

static func _ensure_shared_resources() -> void:
	if _shared_mesh == null:
		_shared_mesh = SphereMesh.new()
		_shared_mesh.radius = 0.2
		_shared_mesh.height = 0.4
		_shared_mesh.radial_segments = 8
		_shared_mesh.rings = 4
	if _shared_material_base == null:
		_shared_material_base = StandardMaterial3D.new()
		_shared_material_base.albedo_color = Color(0.2, 1.0, 0.8, 0.8)
		_shared_material_base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_material_base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shared_material_base.emission_enabled = true
		_shared_material_base.emission = Color(0.2, 1.0, 0.8) * 0.6

var _material: StandardMaterial3D = null
var _light: OmniLight3D = null
var _light_tween: Tween = null
var _main_tween: Tween = null
var _is_setup: bool = false  # True after first _ready() — prevents re-creating material/light
## Optional override color — set before _play() to retint the burst.
## When non-null, the shared base material is recolored to this color,
## so enemy projectiles and AoE effects can reuse the same impact scene
## with their own color identity.
var impact_color: Color = Color(0.0, 0.0, 0.0, -1.0)  # Negative alpha = no override

func _ready() -> void:
	if not _is_setup:
		# First-time setup — create material + light (persistent, reused across pool cycles)
		_ensure_shared_resources()
		if mesh_instance:
			mesh_instance.mesh = _shared_mesh
			_material = _shared_material_base.duplicate() as StandardMaterial3D
			mesh_instance.material_override = _material
		# POOLING: The light is a persistent child created once and reused.
		# This eliminates OmniLight3D allocation churn at ~9 impacts/sec.
		_light = OmniLight3D.new()
		_light.omni_range = 4.0
		_light.omni_attenuation = 1.2
		_light.light_energy = 0.0
		add_child(_light)
		_is_setup = true
	# For non-pooled instances (fresh instantiate), play immediately.
	# For pooled instances, the caller must set impact_color then call _play().
	if not PerformanceOptimizer or not PerformanceOptimizer.is_pooled_instance(self):
		_play()

## Play the impact burst animation. Applies the current impact_color to the
## material + light, then tweens scale-up + fade-out + light flash.
## Called automatically by _ready() for non-pooled instances, or explicitly
## by the caller after setting impact_color for pooled instances.
func _play() -> void:
	# Apply impact color override to material
	if mesh_instance and _material:
		if impact_color.a >= 0.0:
			_material.albedo_color = Color(impact_color.r, impact_color.g, impact_color.b, 0.8)
			_material.emission = impact_color * 0.6
		else:
			# Reset to default cyan
			_material.albedo_color = Color(0.2, 1.0, 0.8, 0.8)
			_material.emission = Color(0.2, 1.0, 0.8) * 0.6
	# Apply color to light
	var light_col := Color(0.2, 1.0, 0.8)
	if impact_color.a >= 0.0:
		light_col = impact_color
	_light.light_color = light_col
	# Animate: scale up + fade out, then deactivate
	scale = Vector3.ONE * 0.3
	# Kill any in-progress main tween so calling _play() twice (e.g. for
	# non-pooled instances where _ready auto-plays then caller calls _play
	# with the override color) doesn't stack tweens.
	if _main_tween and _main_tween.is_valid():
		_main_tween.kill()
	_main_tween = create_tween()
	_main_tween.set_parallel(true)
	# TRANS_BACK gives a slight overshoot on the scale-up — the burst pops
	# past its target size and settles back, which reads as a punchy "snap"
	# impact rather than a smooth glide. This is the standard juice curve
	# for hit sparks (e.g. Vlambeer's Nuclear Throne impacts). EASE_OUT
	# so the overshoot happens at the end of the rise, not the start.
	_main_tween.tween_property(self, "scale", Vector3.ONE * 2.0, 0.25) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)
	if _material:
		_main_tween.tween_property(_material, "albedo_color:a", 0.0, 0.25) \
			.set_ease(Tween.EASE_IN)
	# Light fades faster than the sphere for a snappy flash.
	# Reuse the light: snap to full intensity then tween to 0.
	_light.light_energy = 2.5
	if _light_tween and _light_tween.is_valid():
		_light_tween.kill()
	_light_tween = _light.create_tween()
	_light_tween.tween_property(_light, "light_energy", 0.0, 0.12) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	_main_tween.chain().tween_callback(_deactivate)

## Called when the impact burst finishes its animation. Instead of queue_free,
## releases the node back to the pool (if pooled) or frees it.
func _deactivate() -> void:
	if PerformanceOptimizer and PerformanceOptimizer.is_pooled_instance(self):
		PerformanceOptimizer.release(self)
	else:
		queue_free()

## Pool reset — called when the impact burst is acquired from the object pool,
## BEFORE the node is added to the scene tree. Resets state so the instance
## is clean for reuse. The caller should set impact_color then call _play()
## after acquire() returns.
func _pool_reset() -> void:
	scale = Vector3.ONE * 0.3
	if _material:
		_material.albedo_color.a = 0.8
	impact_color = Color(0.0, 0.0, 0.0, -1.0)  # Reset to default (no override)

## Pool cleanup — called when the impact burst is released back to the pool.
## Hides the light so it doesn't render while dormant.
func _pool_cleanup() -> void:
	if _light:
		_light.light_energy = 0.0
	if _light_tween and _light_tween.is_valid():
		_light_tween.kill()
	if _main_tween and _main_tween.is_valid():
		_main_tween.kill()