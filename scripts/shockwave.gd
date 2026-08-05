## Zorp Wiggles — Shockwave Ring
## Expanding ring AoE fired by Starburst Sentinel.
## Grows outward, damages player if caught in the ring.
## Polished: correct radius scaling, center light flash, shared resources.

extends Area3D

class_name ShockwaveRing

@export var damage: int = 15
@export var max_radius: float = 8.0
@export var expand_speed: float = 15.0

var current_radius: float = 0.0
var _prev_radius: float = 0.0  # Previous-frame radius for band-skip detection
var age: float = 0.0
var _material: StandardMaterial3D = null
var _has_hit_player: bool = false
var _light: OmniLight3D = null
var _cached_player: Node3D = null

@onready var mesh: MeshInstance3D = $MeshInstance3D

# ─── Shared Resources ──────────────────────────────────────────────────────────
# Shockwaves are fired repeatedly by Sentinels. Share the mesh geometry
# to avoid per-shot allocation. Material is per-instance (alpha/emission tween).
static var _shared_mesh: CylinderMesh = null
# Shared base material — duplicated per instance so each ring can tween its
# alpha/emission independently without creating a full StandardMaterial3D
# from scratch every spawn. Duplicate is cheaper than new+configure because
# it copies the property block in one shot instead of setting each property.
static var _shared_material_base: StandardMaterial3D = null

static func _ensure_shared_mesh() -> void:
	if _shared_mesh == null:
		_shared_mesh = CylinderMesh.new()
		# Base radius of 0.5m — the ring is then scaled by current_radius / 0.5
		# to reach the actual desired radius. This gives a smooth, visible ring
		# at all sizes without changing the mesh.
		_shared_mesh.top_radius = 0.5
		_shared_mesh.bottom_radius = 0.5
		_shared_mesh.height = 0.1
		_shared_mesh.radial_segments = 24
		_shared_mesh.rings = 2
	if _shared_material_base == null:
		_shared_material_base = StandardMaterial3D.new()
		_shared_material_base.albedo_color = Color(1.0, 0.784, 0.196, 0.6)
		_shared_material_base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_material_base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shared_material_base.emission_enabled = true
		_shared_material_base.emission = Color(1.0, 0.8, 0.2) * 0.5
		_shared_material_base.emission_energy_multiplier = 1.5

## The base mesh radius — used to compute the correct scale factor.
const _BASE_MESH_RADIUS: float = 0.5

func _ready() -> void:
	# Enhancement Pack 26: SFX on shockwave spawn — the Sentinel's shockwave
	# ring had a light flash + expanding ring visual but no audio. The
	# SFX_EXPLOSION conveys a seismic detonation matching the visual impact.
	AudioManager.play_sfx(AudioManager.SFX_EXPLOSION)
	# Set up material — duplicate the shared base so each instance can tween
	# its alpha/emission independently. Cheaper than creating a new
	# StandardMaterial3D and setting every property from scratch per spawn.
	_ensure_shared_mesh()
	if mesh:
		mesh.mesh = _shared_mesh
		_material = _shared_material_base.duplicate() as StandardMaterial3D
		mesh.material_override = _material

	# Center light flash — illuminates the Sentinel's area as the shockwave
	# fires, fading as the ring expands. Matches the pulse wave's light flash
	# for a consistent shockwave visual language.
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.8, 0.2)
	_light.light_energy = 2.5
	_light.omni_range = 6.0
	_light.omni_attenuation = 1.5
	add_child(_light)

func _physics_process(delta: float) -> void:
	age += delta
	# Ease-out expansion — fast burst, gentle deceleration. Matches the pulse
	# wave's feel so both expanding-ring effects share a consistent visual
	# language. Feels more energetic than a constant linear growth.
	var progress: float = current_radius / max_radius if max_radius > 0.0 else 0.0
	progress = clampf(progress, 0.0, 1.0)
	var speed_mult: float = 1.0 - 0.6 * progress
	# Track previous radius BEFORE advancing so the hit band covers the full
	# swept area this frame. Without this, a fast-expanding ring (or a
	# low-FPS physics tick) can skip past the player between frames — the
	# player is inside the ring at frame N and outside at frame N+1, but
	# never within the 1.0m band at either sample, so the hit is dropped.
	_prev_radius = current_radius
	current_radius += expand_speed * speed_mult * delta

	# Scale the shockwave ring to the actual current radius.
	# The base mesh has radius 0.5m, so we scale by current_radius / 0.5
	# to reach the desired physical size. Previously this scaled by the
	# ratio (0→1), making the ring only 0.5m at max — nearly invisible.
	var ring_scale: float = current_radius / _BASE_MESH_RADIUS
	# CylinderMesh axis is along Y; radius is in the XZ plane.
	# Scale X and Z to expand the ring radius; keep Y (thickness) at 1.
	var target_scale := Vector3(ring_scale, 1.0, ring_scale)
	scale = scale.lerp(target_scale, 1.0 - exp(-12.0 * delta))

	# Check player hit — damage once when ring passes through
	# In co-op, check both players — the ring can hit either one
	# ── Swept-band hit detection ── Instead of only checking a fixed 1.0m
	#    band around the current radius, we check the full swept area between
	#    _prev_radius and current_radius (plus a small margin). This prevents
	#    fast-expanding rings or low-FPS ticks from skipping past the player
	#    — the player is hit if they're anywhere in the ring's path this
	#    frame, not just within a thin annulus at the final radius.
	if not _has_hit_player:
		# Swept-band bounds shared by both the P1 and P2 hit checks. Declared
		# here (not inside the player branch) so the co-op P2 branch below can
		# use them — GDScript 4 block-scopes `var`, so a variable declared in
		# the `if player and ...` sibling block would be out of scope here.
		var band_min: float = _prev_radius - 0.5
		var band_max: float = current_radius + 0.5
		# Cached player reference — shockwaves run _physics_process every
		# frame while expanding (~0.5s per shot). Avoid a per-frame
		# scene-tree group scan by caching the player and only re-scanning
		# when the cache is stale. Matches the pattern used by
		# enemy_base.gd, collectible.gd, wildlife.gd, etc.
		if not _cached_player or not is_instance_valid(_cached_player):
			_cached_player = get_tree().get_first_node_in_group("player")
		var player: Node3D = _cached_player
		if player and GameManager.player_is_alive and not GameManager.player_is_downed:
			var dist: float = global_position.distance_to(player.global_position)
			# Hit if the player falls within the swept band this frame
			if dist >= band_min and dist <= band_max:
				GameManager.take_damage(damage, global_position)
				_has_hit_player = true
		# ── Phase 19: Co-op — check P2 ──
		if not _has_hit_player and CoOpManager.is_coop_active() and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
			if not CoOpManager.p2_is_downed:
				var p2_dist: float = global_position.distance_to(CoOpManager.p2_node.global_position)
				if p2_dist >= band_min and p2_dist <= band_max:
					CoOpManager.p2_take_damage(damage, global_position)
					_has_hit_player = true

	# Fade out as it reaches max radius — quadratic fade for a sharper disappear
	var fade: float = 1.0 - progress
	if _material:
		_material.albedo_color.a = 0.6 * fade * fade
		# Emission fades alongside alpha for a coherent dissipating glow
		_material.emission_energy_multiplier = 1.5 * fade * fade

	# Fade the center light as the ring expands (punchy flash → off).
	# Use an ease-out cubic curve (matching the pulse wave's light fade) so
	# the flash snaps bright and decays smoothly rather than linearly dimming.
	if _light:
		var light_fade: float = 1.0 - pow(progress, 3.0)  # Ease-out cubic
		_light.light_energy = 2.5 * light_fade

	# Destroy when fully expanded
	if current_radius >= max_radius:
		queue_free()