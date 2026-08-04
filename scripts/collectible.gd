## Zorp Wiggles — Collectible Item
## Pickable items that float, glow, and magnetically pull toward the player.
## Ported from collectible logic in Ursina game.py.

extends Area3D

signal collected(type: int, value: int)

# ─── Type Configuration ───────────────────────────────────────────────────────
var collectible_type: int = GameConstants.CollectibleType.XP_ORB
var xp_value: int = 10
var is_magnetic: bool = false
var is_popping: bool = false  # Pickup lift animation
# ── Magnetic pull sparkle trail ── While being magnetically pulled, the
#    collectible spawns tiny sparkle particles at intervals, leaving a trail
#    of light that makes the pull feel dynamic and visually satisfying. The
#    trail timer controls how often a sparkle spawns (every ~0.06s).
var _pull_trail_timer: float = 0.0
const PULL_TRAIL_INTERVAL: float = 0.06
# ── Magnet hum audio timer ── While being magnetically pulled, the
#    collectible plays a very quiet "magnet hum" blip at intervals
#    (every 0.18s) so the player hears the vacuum effect without
#    audio spam from multiple simultaneous pulls. The interval is
#    long enough that 5-10 simultaneous vacuums don't stack into noise
#    but short enough to feel like a continuous "humming" energy field.
var _magnet_hum_timer: float = 0.0
const MAGNET_HUM_INTERVAL: float = 0.18
# ── Magnet activation flash ── When the collectible first enters the
#    magnetic pull radius, the emission briefly spikes. This gives the
#    player a visual "the item noticed me" signal — the collectible
#    "lights up" as it starts moving toward them. The flag tracks whether
#    we've already flashed for the current magnetic engagement so we only
#    fire once per pull sequence (not every frame while being pulled).
var _magnet_flash_triggered: bool = false

# ── Spiral vacuum orbit ── While being magnetically pulled, collectibles
#    spiral around the pull direction (player → item axis) rather than
#    flying in a straight line. This creates a dynamic "energy vortex"
#    visual — items whirl into the player's magnetic field like they're
#    being sucked into a singularity, not sliding on rails. The spiral
#    phase accumulates while pulling and resets on pull start. The orbit
#    radius decays as the item closes in so the spiral tightens near the
#    player, mimicking angular momentum conservation.
var _spiral_phase: float = 0.0
var _spiral_active: bool = false

# ── Phase 8: Collectible bounce and tumble ──
# When true, the collectible is in physics bounce mode (just spawned/dropped).
# A RigidBody3D proxy handles the tumble; once it settles, we switch to
# normal Area3D floating/bobbing behavior.
var _is_tumbling: bool = false
var _tumble_timer: float = 0.0
var _tumble_rigid: RigidBody3D = null
const TUMBLE_DURATION: float = 1.2  # Seconds before settling into float mode

# ─── Visual ──────────────────────────────────────────────────────────────────
var base_y: float = 0.0
var base_pos_x: float = 0.0
var base_pos_z: float = 0.0
var bob_offset: float = 0.0
var glow_phase: float = 0.0
var _mat: StandardMaterial3D = null
var _cached_player: Node3D = null

# ── Despawn timer ── Collectibles that sit uncollected for too long clutter
#    the world and waste memory. After DESPAWN_LIFETIME seconds (unless the
#    player is actively nearby), the collectible enters a warning flicker
#    phase (rapid emission pulsing) for DESPAWN_WARNING_DURATION seconds,
#    then fades out and frees itself. This keeps the world clean during
#    long runs without abruptly removing items the player was approaching.
#    The despawn is paused while the player is within DESPAWN_PAUSE_RADIUS
#    so items the player is walking toward don't vanish from under them.
#    Rare items (evolution stones, meteor shards, crafting materials) get
#    a 3× longer lifetime since they're valuable and the player may want
#    to backtrack for them.
var _despawn_timer: float = 0.0
var _despawn_warning: bool = false
var _despawn_flicker_phase: float = 0.0
const DESPAWN_LIFETIME: float = 45.0           # Seconds before warning phase
const DESPAWN_LIFETIME_RARE: float = 135.0     # 3× longer for rare items
const DESPAWN_WARNING_DURATION: float = 4.0    # Flicker phase before fade
const DESPAWN_PAUSE_RADIUS: float = 12.0       # Don't despawn if player this close
var _despawn_fade_tween: Tween = null

# ─── Type-specific config ────────────────────────────────────────────────────
const TYPE_CONFIG := {
	GameConstants.CollectibleType.XP_ORB: {"color": Color(0.4, 0.2, 1.0), "value": 10, "scale": 0.3},
	GameConstants.CollectibleType.SPACE_GLOOP: {"color": Color(0.2, 0.8, 0.4), "value": 25, "scale": 0.4},
	GameConstants.CollectibleType.STAR_FRUIT: {"color": Color(1.0, 0.9, 0.2), "value": 30, "scale": 0.4},
	GameConstants.CollectibleType.HEALTH_FRAGMENT: {"color": Color(0.9, 0.2, 0.3), "value": 0, "scale": 0.35},
	GameConstants.CollectibleType.METEOR_SHARD: {"color": Color(1.0, 0.5, 0.1), "value": 50, "scale": 0.5},
	GameConstants.CollectibleType.QUANTUM_FUZZ: {"color": Color(0.5, 0.8, 1.0), "value": 40, "scale": 0.45},
	GameConstants.CollectibleType.NEBULA_DUST: {"color": Color(0.8, 0.3, 0.9), "value": 35, "scale": 0.4},
	# ── Phase 16: Crafting materials ──
	GameConstants.CollectibleType.SHIELD_CRYSTAL: {"color": Color(0.3, 0.5, 1.0), "value": 35, "scale": 0.45},
	GameConstants.CollectibleType.FIREBALL_SCROLL: {"color": Color(1.0, 0.4, 0.1), "value": 35, "scale": 0.45},
	GameConstants.CollectibleType.REGEN_CRYSTAL: {"color": Color(0.2, 1.0, 0.4), "value": 35, "scale": 0.45},
	GameConstants.CollectibleType.MAGNET_CORE: {"color": Color(0.6, 0.6, 0.7), "value": 30, "scale": 0.4},
	GameConstants.CollectibleType.TOXIC_EXTRACT: {"color": Color(0.5, 0.9, 0.1), "value": 30, "scale": 0.4},
	# ── Phase 27: Pet Evolution Stones (rare, glowing, large) ──
	GameConstants.CollectibleType.EMBER_STONE: {"color": Color(1.0, 0.4, 0.1), "value": 80, "scale": 0.55},
	GameConstants.CollectibleType.FROST_STONE: {"color": Color(0.4, 0.75, 1.0), "value": 80, "scale": 0.55},
	GameConstants.CollectibleType.SPARK_STONE: {"color": Color(1.0, 0.9, 0.2), "value": 80, "scale": 0.55},
	GameConstants.CollectibleType.VOID_STONE: {"color": Color(0.3, 0.1, 0.45), "value": 80, "scale": 0.55},
	GameConstants.CollectibleType.LEAF_STONE: {"color": Color(0.3, 0.8, 0.35), "value": 80, "scale": 0.55},
}

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# ─── Shared Resources ──────────────────────────────────────────────────────────
# Collectibles are spawned frequently (enemy drops, world scatter, rift exits).
# Each type has a fixed mesh radius, so we cache one SphereMesh per type config
# key and reuse it across all instances. The material is still per-instance
# because the emission pulse and mirror-dimension flash tween its properties
# independently. This eliminates per-spawn geometry allocation for the most
# common pickup types.
static var _shared_meshes: Dictionary = {}  # { type_key: SphereMesh }

# ── Shared tumble physics material ── Every collectible drop creates a
#    RigidBody3D proxy for the bounce-and-tumble animation. Each one was
#    allocating a new PhysicsMaterial (bounce=0.4, friction=0.5) — identical
#    across all drops. Sharing it statically eliminates per-drop physics
#    resource allocation, mirroring the enemy corpse shared PhysicsMaterial
#    pattern in enemy_base.gd. The material is read-only at runtime (no
#    per-instance property writes), so sharing is safe.
static var _shared_tumble_phys_mat: PhysicsMaterial = null

static func _ensure_shared_tumble_phys_mat() -> void:
	if _shared_tumble_phys_mat == null:
		_shared_tumble_phys_mat = PhysicsMaterial.new()
		_shared_tumble_phys_mat.bounce = 0.4
		_shared_tumble_phys_mat.friction = 0.5

static func _get_shared_mesh(type_key: int, radius: float) -> SphereMesh:
	if _shared_meshes.has(type_key):
		return _shared_meshes[type_key]
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	_shared_meshes[type_key] = sphere
	return sphere

func _ready() -> void:
	# Connect area signals
	body_entered.connect(_on_body_entered)
	
	# Setup visual based on type
	_apply_type_config()
	
	# Start bobbing animation
	base_y = global_position.y
	base_pos_x = global_position.x
	base_pos_z = global_position.z
	bob_offset = randf() * TAU  # Random phase offset
	# ── Initialize despawn timer ── Rare items get a 3× longer lifetime so
	#    the player has ample time to backtrack for valuable drops. Common
	#    items (XP orbs, space gloop) despawn sooner to keep the world clean.
	_despawn_timer = DESPAWN_LIFETIME_RARE if _is_rare() else DESPAWN_LIFETIME

func set_type(type: int) -> void:
	collectible_type = type
	_apply_type_config()

## ── Phase 8: Collectible bounce and tumble ──────────────────────────────────────
## Call this right after adding the collectible to the scene tree to give it
## a physics-driven bounce and tumble. The collectible spawns a temporary
## RigidBody3D that bounces off the ground, then after TUMBLE_DURATION seconds
## settles into the normal Area3D floating/bobbing mode.
## [param impulse_dir] — direction to launch the collectible (e.g., away from enemy)
func start_tumble(impulse_dir: Vector3 = Vector3.ZERO) -> void:
	if _is_tumbling:
		return
	_is_tumbling = true
	_tumble_timer = TUMBLE_DURATION

	# Create a RigidBody3D proxy that handles physics bounce
	_tumble_rigid = RigidBody3D.new()
	_tumble_rigid.global_position = global_position
	_tumble_rigid.collision_layer = 0  # Don't collide with player/enemy
	_tumble_rigid.collision_mask = 1   # Only collide with world geometry

	# Collision shape matching collectible size
	var config: Dictionary = TYPE_CONFIG.get(collectible_type, TYPE_CONFIG[GameConstants.CollectibleType.XP_ORB])
	var col_scale: float = config.get("scale", 0.3)
	var col_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = col_scale
	col_shape.shape = sphere_shape
	_tumble_rigid.add_child(col_shape)

	# Visual mesh copy for the tumble body
	var tumble_mesh := MeshInstance3D.new()
	tumble_mesh.mesh = _get_shared_mesh(collectible_type, col_scale)
	var tumble_mat := StandardMaterial3D.new()
	tumble_mat.albedo_color = config["color"]
	tumble_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tumble_mat.emission_enabled = true
	tumble_mat.emission = config["color"] * 0.3
	tumble_mat.rim_enabled = true
	tumble_mat.rim = 0.8
	tumble_mat.rim_tint = 1.0
	tumble_mesh.material_override = tumble_mat
	_tumble_rigid.add_child(tumble_mesh)

	# Physics material with bounce — shared across all tumble proxies to
	# avoid per-drop PhysicsMaterial allocation (identical across all drops).
	_ensure_shared_tumble_phys_mat()
	_tumble_rigid.physics_material_override = _shared_tumble_phys_mat

	# Add to parent scene
	var parent_node: Node = get_parent()
	if parent_node:
		parent_node.add_child(_tumble_rigid)

	# Apply initial impulse — random scatter if no direction given
	if impulse_dir.length_squared() < 0.01:
		impulse_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	_tumble_rigid.apply_central_impulse(impulse_dir * 4.0 + Vector3(0, 3.0, 0))
	_tumble_rigid.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))

	# Hide the Area3D visual while tumbling — the RigidBody handles the look
	if mesh_instance:
		mesh_instance.visible = false

## End tumble mode — snap Area3D to the RigidBody's settled position, free
## the RigidBody, and resume normal floating/bobbing behavior.
func _end_tumble() -> void:
	if not _is_tumbling:
		return
	_is_tumbling = false
	if _tumble_rigid and is_instance_valid(_tumble_rigid):
		# Snap Area3D to the settled position
		global_position = _tumble_rigid.global_position
		_tumble_rigid.queue_free()
	_tumble_rigid = null
	# Update base positions for bobbing/wobble
	base_y = global_position.y
	base_pos_x = global_position.x
	base_pos_z = global_position.z
	# Restore the Area3D visual
	if mesh_instance:
		mesh_instance.visible = true

## ── Rare-item helper ── Returns true for Meteor Shards, Quantum Fuzz, Nebula
##    Dust, all crafting materials (Phase 16), and all Pet Evolution Stones
##    (Phase 27). Used in four places: persistent glow light, rarity-based
##    spin speed, pickup light flash intensity, and the rare SFX / FOV kick.
##    Keeping the check in one place means new rare types only need to be added
##    here once, and the spin / glow / flash / audio all pick it up together.
func _is_rare() -> bool:
	return collectible_type == GameConstants.CollectibleType.METEOR_SHARD \
		or collectible_type == GameConstants.CollectibleType.QUANTUM_FUZZ \
		or collectible_type == GameConstants.CollectibleType.NEBULA_DUST \
		or GameConstants.CRAFTING_MATERIALS.has(collectible_type) \
		or collectible_type == GameConstants.CollectibleType.EMBER_STONE \
		or collectible_type == GameConstants.CollectibleType.FROST_STONE \
		or collectible_type == GameConstants.CollectibleType.SPARK_STONE \
		or collectible_type == GameConstants.CollectibleType.VOID_STONE \
		or collectible_type == GameConstants.CollectibleType.LEAF_STONE

## Trigger a one-shot emission energy spike when the collectible first enters
## the magnetic pull radius. The emission jumps to 3x its current pulse value
## then eases back over 0.3s via a tween. This gives the player a visual
## "the item noticed me" signal — the collectible "lights up" as it begins
## moving toward them. Only fires once per pull engagement (guarded by
## _magnet_flash_triggered, which is reset when the pull ends). Skipped
## while popping (pickup animation owns scale/emission at that point).
## Uses a tracked tween so rapid re-engagements don't stack.
var _magnet_flash_tween: Tween = null
func _trigger_magnet_flash() -> void:
	if _magnet_flash_triggered or is_popping or not _mat:
		return
	_magnet_flash_triggered = true
	# Kill any in-progress magnet flash tween so re-engagements restart clean
	if _magnet_flash_tween and _magnet_flash_tween.is_valid():
		_magnet_flash_tween.kill()
	# Spike the emission energy, then ease back to the breathing pulse baseline.
	# We tween from the current value (which may be mid-pulse) to a fixed spike
	# then back to 1.0 — the _physics_process pulse loop will resume ownership
	# of emission_energy_multiplier after the tween completes.
	var current_emission: float = _mat.emission_energy_multiplier
	_magnet_flash_tween = create_tween()
	_magnet_flash_tween.tween_property(_mat, "emission_energy_multiplier",
		current_emission + 2.0, 0.06) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_magnet_flash_tween.tween_property(_mat, "emission_energy_multiplier",
		1.0, 0.25) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func _apply_type_config() -> void:
	var config: Dictionary = TYPE_CONFIG.get(collectible_type, TYPE_CONFIG[GameConstants.CollectibleType.XP_ORB])
	xp_value = config["value"]
	
	if mesh_instance:
		# Use the shared (cached) sphere mesh for this collectible type —
		# avoids allocating a new SphereMesh on every spawn.
		mesh_instance.mesh = _get_shared_mesh(collectible_type, config["scale"])
		
		# Unlit material with the type color (per-instance — tweens emission/alpha)
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = config["color"]
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.emission_enabled = true
		_mat.emission = config["color"] * 0.3
		_mat.emission_energy_multiplier = 1.0
		# Enable transparency so the despawn fade-out alpha tween works.
		# Alpha SCISSOR would clip the emission halo; ALPHA preserves the glow
		# while fading the overall opacity, giving a clean "dissolve" read.
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Rim lighting so collectibles catch the eye at grazing angles
		_mat.rim_enabled = true
		_mat.rim = 0.8
		_mat.rim_tint = 1.0
		mesh_instance.material_override = _mat
		
		# Spawn pop-in: bounce from scale 0 → 1 with overshoot for a juicy
		# appearance instead of popping in at full size.
		scale = Vector3(0.001, 0.001, 0.001)
		var pop_tween := create_tween()
		pop_tween.tween_property(self, "scale", Vector3.ONE, 0.35) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
		# Rare collectibles get a persistent point light so they glow in
		# dark biomes and are visible from a distance.
		# Phase 16: Crafting materials also get the glow (they're valuable).
		if _is_rare():
			var glow := OmniLight3D.new()
			glow.light_color = config["color"]
			glow.light_energy = 1.2
			glow.omni_range = 4.0
			glow.omni_attenuation = 1.5
			add_child(glow)
			# ── Rare spawn emission flash ── A brief white-hot emission spike
			# on the spawn frame so rare items immediately draw the eye. The
			# emission energy jumps to 5x then eases back to the breathing
			# pulse baseline over 0.4s, creating a "flare" effect that reads
			# as "something valuable just appeared" even in a cluttered field
			# of common drops. Common items don't get this — the pop-in scale
			# tween is enough for them, but rare items need the extra light
			# punch to stand out, especially in dark biomes.
			if _mat:
				_mat.emission_energy_multiplier = 5.0
				var rare_flash_tween := create_tween()
				rare_flash_tween.tween_property(_mat, "emission_energy_multiplier",
					1.0, 0.4) \
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _physics_process(delta: float) -> void:
	if GameManager.is_paused or not GameManager.player_is_alive:
		return

	# ── Despawn timer ── Tick down the lifetime. The timer is paused when
	#    the player is within DESPAWN_PAUSE_RADIUS so items the player is
	#    approaching don't vanish. Once the timer hits zero, a warning
	#    flicker phase begins (rapid emission pulsing) for
	#    DESPAWN_WARNING_DURATION seconds, then the collectible fades out
	#    and frees itself. The flicker uses a high-frequency sine (18 Hz)
	#    so it reads as an urgent "about to disappear" blink — the same
	#    language as low-HP enemy pulsing but faster. The fade-out tween
	#    scales the collectible down and drops alpha to zero so it reads
	#    as "dissolving" rather than popping out of existence.
	if not _is_tumbling and not is_popping and not _despawn_warning:
		if not _cached_player or not is_instance_valid(_cached_player):
			_cached_player = get_tree().get_first_node_in_group("player")
		var player_nearby: bool = false
		if _cached_player and is_instance_valid(_cached_player):
			player_nearby = global_position.distance_to(_cached_player.global_position) < DESPAWN_PAUSE_RADIUS
		if not player_nearby:
			_despawn_timer -= delta
			if _despawn_timer <= 0.0:
				_despawn_warning = true
				_despawn_flicker_phase = 0.0
	# ── Warning flicker + fade-out ── When in the warning phase, rapidly
	#    pulse the emission energy to signal impending despawn, then fade
	#    out and free. The flicker overrides the normal breathing pulse.
	if _despawn_warning and not is_popping:
		_despawn_flicker_phase += delta
		if _despawn_flicker_phase < DESPAWN_WARNING_DURATION:
			# Rapid emission flicker (18 Hz on/off) for an urgent "blink"
			var flicker_t: float = _despawn_flicker_phase / DESPAWN_WARNING_DURATION
			# Ease in the flicker intensity as we approach the despawn moment
			var intensity: float = 0.5 + 0.5 * flicker_t
			var flicker_on: bool = fmod(_despawn_flicker_phase * 18.0, TAU) < PI
			if _mat:
				_mat.emission_energy_multiplier = 3.0 * intensity if flicker_on else 0.3
		else:
			# Fade out and free — scale down + alpha to zero over 0.4s
			if not _despawn_fade_tween or not _despawn_fade_tween.is_valid():
				_despawn_fade_tween = create_tween()
				_despawn_fade_tween.set_parallel(true)
				if _mat:
					_despawn_fade_tween.tween_property(_mat, "albedo_color:a", 0.0, 0.4) \
						.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				_despawn_fade_tween.tween_property(self, "scale", Vector3.ZERO, 0.4) \
					.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
				_despawn_fade_tween.chain().tween_callback(_despawn_free)

	# ── Phase 8: Tumble mode — RigidBody3D physics bounce ──
	# While tumbling, the Area3D follows the RigidBody proxy. When the tumble
	# timer expires, we snap to the RigidBody's settled position, free it,
	# and resume normal floating/bobbing behavior.
	if _is_tumbling:
		_tumble_timer -= delta
		if _tumble_rigid and is_instance_valid(_tumble_rigid):
			# Follow the rigid body so pickup area tracks it
			global_position = _tumble_rigid.global_position
			# Still allow pickup while tumbling
			if not _cached_player or not is_instance_valid(_cached_player):
				_cached_player = get_tree().get_first_node_in_group("player")
			if _cached_player:
				var dist: float = global_position.distance_to(_cached_player.global_position)
				if dist < GameConstants.COLLECT_RADIUS:
					_end_tumble()
					_collect()
					return
			# Check body_entered too (Area3D is following the rigid position)
		if _tumble_timer <= 0:
			_end_tumble()
		return

	# Bob up and down + gentle spin + lateral wobble for an organic float
	if not is_popping:
		bob_offset += delta * 2.0
		global_position.y = base_y + sin(bob_offset) * 0.3
		# Rarity-based spin speed — rarer items spin faster, creating a
		# visual hierarchy where valuable pickups draw the eye. Crafting
		# materials (rare) spin faster than common XP orbs.
		var rarity_spin: float = 1.5  # Common default
		if _is_rare():
			rarity_spin = 3.0
		elif collectible_type == GameConstants.CollectibleType.STAR_FRUIT \
				or collectible_type == GameConstants.CollectibleType.HEALTH_FRAGMENT:
			rarity_spin = 2.2
		rotate_y(delta * rarity_spin)
		# Pulsing emission glow for better visibility ("breathing" effect)
		# Skip during despawn warning — the flicker code owns emission then.
		if _mat and not _despawn_warning:
			var pulse: float = 0.7 + 0.4 * sin(bob_offset * 1.5)
			_mat.emission_energy_multiplier = pulse
		# ── Breathing scale pulse ── A subtle scale oscillation synced to the
		#    bob so the collectible feels alive — it "breathes" as it floats,
		#    growing and shrinking slightly with the same rhythm as the
		#    vertical bob. The pulse is small (±6%) so it reads as organic
		#    life rather than a mechanical throb. Rare items get a slightly
		#    larger pulse (±9%) so they feel more energetic and eye-catching.
		#    We use the same bob_offset phase as the Y bob so the scale
		#    peaks align with the top of the bob arc — the item swells as it
		#    rises, creating a cohesive "breathing" rhythm.
		# Skip during despawn fade — the fade tween owns self.scale and the
		# mesh pulse would visually fight the dissolve.
		if mesh_instance and not _despawn_warning:
			var pulse_amp: float = 0.06 if not _is_rare() else 0.09
			var scale_pulse: float = 1.0 + sin(bob_offset * 1.5) * pulse_amp
			mesh_instance.scale = Vector3.ONE * scale_pulse

	# Magnetic pull toward player — uses direct global_position writes, so the
	# X/Z wobble is only applied above when NOT being pulled (otherwise the
	# pull and wobble would fight over global_position.x/z). The wobble anchor
	# is updated here so that when the pull ends, the wobble resumes from the
	# current position rather than snapping back to the spawn location.
	# Reset magnetic flag each frame; it's set true only while actively pulling.
	is_magnetic = false
	# Reset the magnet flash flag when not being pulled so the next pull
	# engagement triggers a fresh emission flash.
	_magnet_flash_triggered = false
	# Reset spiral orbit state when not being pulled so the next engagement
	# starts a fresh spiral with a new random phase.
	_spiral_active = false
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	var player: Node3D = _cached_player
	# ── Phase 19: Co-op — pull toward nearest player ──
	if CoOpManager.is_coop_active():
		var p1: Node3D = _cached_player
		var p2: Node3D = CoOpManager.p2_node
		if is_instance_valid(p1) and is_instance_valid(p2):
			var d1: float = global_position.distance_to(p1.global_position)
			var d2: float = global_position.distance_to(p2.global_position)
			# Downed players can't collect
			if GameManager.player_is_downed:
				d1 = 99999.0
			if CoOpManager.p2_is_downed:
				d2 = 99999.0
			player = p2 if d2 < d1 else p1
	if not player:
		# No player — still apply a gentle X/Z wobble for ambient float
		if not is_popping:
			var wobble_x: float = sin(bob_offset * 0.7) * 0.12
			var wobble_z: float = cos(bob_offset * 0.7 + PI * 0.25) * 0.12
			global_position.x = base_pos_x + wobble_x
			global_position.z = base_pos_z + wobble_z
		return

	var dist := global_position.distance_to(player.global_position)

	# ── Emergency Health Fragment Magnet ── When player HP is critically low,
	# Health Fragments are pulled from a much larger radius at accelerated speed
	var is_emergency_magnet: bool = false
	if collectible_type == GameConstants.CollectibleType.HEALTH_FRAGMENT:
		var hp_ratio: float = float(GameManager.player_hp) / float(GameManager.player_max_hp) if GameManager.player_max_hp > 0 else 0.0
		if hp_ratio < GameConstants.EMERGENCY_HP_THRESHOLD:
			if dist < GameConstants.HEALTH_FRAGMENT_EMERGENCY_PULL_RADIUS and not is_popping:
				is_emergency_magnet = true
				is_magnetic = true
				# Reset spiral phase on new pull engagement
				if not _spiral_active:
					_spiral_active = true
					_spiral_phase = randf() * TAU  # Random initial phase per item
				# Trigger the magnet activation flash on first engagement
				_trigger_magnet_flash()
				var pull_speed := GameConstants.HEALTH_FRAGMENT_EMERGENCY_PULL_SPEED * (1.0 - dist / GameConstants.HEALTH_FRAGMENT_EMERGENCY_PULL_RADIUS)
				var dir := (player.global_position - global_position).normalized()
				# ── Spiral vacuum orbit ── Apply a perpendicular orbit offset so
				#    the item whirls around the pull axis. The orbit radius is
				#    proportional to distance (tightens as it closes in), and the
				#    phase advances faster when closer (angular momentum).
				_spiral_phase += delta * (8.0 + 12.0 * (1.0 - dist / GameConstants.HEALTH_FRAGMENT_EMERGENCY_PULL_RADIUS))
				var perp := Vector3(-dir.z, 0.0, dir.x).normalized()
				var orbit_radius: float = clampf(dist * 0.15, 0.0, 1.2)
				var spiral_offset: Vector3 = perp * sin(_spiral_phase) * orbit_radius
				global_position += dir * pull_speed * delta
				global_position += spiral_offset * delta * 2.0
				# Sparkle trail for emergency magnet too
				_pull_trail_timer -= delta
				if _pull_trail_timer <= 0.0:
					_pull_trail_timer = PULL_TRAIL_INTERVAL
					_spawn_pull_sparkle()
				# Magnet hum audio — periodic soft blip while vacuuming
				_magnet_hum_timer -= delta
				if _magnet_hum_timer <= 0.0:
					_magnet_hum_timer = MAGNET_HUM_INTERVAL
					AudioManager.play_sfx_volume(AudioManager.SFX_MAGNET_HUM, 0.5)

	# Normal pull radius (skip if emergency magnet already handled)
	if not is_emergency_magnet and dist < GameConstants.COLLECT_PULL_RADIUS and not is_popping:
		is_magnetic = true
		# Reset spiral phase on new pull engagement
		if not _spiral_active:
			_spiral_active = true
			_spiral_phase = randf() * TAU  # Random initial phase per item
		# Trigger the magnet activation flash on first engagement
		_trigger_magnet_flash()
		# Exponential acceleration: pull starts gentle when far, then ramps up
		# sharply as the item closes in. The ease-in curve (t²) makes items
		# feel "sticky" — they hesitate, then snap toward the player for a
		# satisfying pickup. This replaces the previous linear falloff.
		var proximity: float = 1.0 - dist / GameConstants.COLLECT_PULL_RADIUS  # 0..1
		var accel_curve: float = proximity * proximity  # Quadratic ease-in
		var pull_speed: float = GameConstants.COLLECT_PULL_SPEED * (0.3 + 0.7 * accel_curve)
		var dir := (player.global_position - global_position).normalized()
		# ── Spiral vacuum orbit ── Apply a perpendicular orbit offset so
		#    the item whirls around the pull axis. The orbit radius is
		#    proportional to distance (tightens as it closes in), and the
		#    phase advances faster when closer (angular momentum).
		_spiral_phase += delta * (6.0 + 10.0 * proximity)
		var perp := Vector3(-dir.z, 0.0, dir.x).normalized()
		var orbit_radius: float = clampf(dist * 0.12, 0.0, 0.8)
		var spiral_offset: Vector3 = perp * sin(_spiral_phase) * orbit_radius
		global_position += dir * pull_speed * delta
		global_position += spiral_offset * delta * 2.0
		# ── Magnetic lift arc ── While being pulled, items get a subtle
		# vertical lift so they arc upward as they converge on the player,
		# creating a more satisfying "magnetic vacuum" trajectory. The lift
		# is proportional to the pull proximity (stronger when closer) and
		# uses a smoothstep so it eases in. Without this, items glide in a
		# straight horizontal line — the arc makes them feel like they're
		# being lifted by the magnetic field rather than sliding on rails.
		# The lift is small (max 3 m/s upward at point-blank) so it doesn't
		# overshoot the player's position.
		var lift_t: float = proximity * proximity * (3.0 - 2.0 * proximity)  # smoothstep
		global_position.y += lift_t * 3.0 * delta
		# ── Sparkle trail while being pulled ── Spawn tiny sparkle particles
		# at intervals along the pull path, leaving a light trail that makes
		# the magnetic pull visually dynamic. The sparkles are very small and
		# short-lived so they don't clutter the screen during mass pickups.
		_pull_trail_timer -= delta
		if _pull_trail_timer <= 0.0:
			_pull_trail_timer = PULL_TRAIL_INTERVAL
			_spawn_pull_sparkle()
		# Magnet hum audio — periodic soft blip while vacuuming
		_magnet_hum_timer -= delta
		if _magnet_hum_timer <= 0.0:
			_magnet_hum_timer = MAGNET_HUM_INTERVAL
			AudioManager.play_sfx_volume(AudioManager.SFX_MAGNET_HUM, 0.5)
	elif not is_popping and not is_magnetic:
		# Not being pulled — apply gentle X/Z wobble for an organic float.
		# Items feel suspended in alien gravity rather than on a rail.
		# Update the wobble anchor so the wobble centers on the current
		# position (in case the item was previously pulled and released).
		base_pos_x = global_position.x
		base_pos_z = global_position.z
		var wobble_x: float = sin(bob_offset * 0.7) * 0.12
		var wobble_z: float = cos(bob_offset * 0.7 + PI * 0.25) * 0.12
		global_position.x = base_pos_x + wobble_x
		global_position.z = base_pos_z + wobble_z
	
	# Collect radius
	if dist < GameConstants.COLLECT_RADIUS:
		_collect()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_collect()

## Free the collectible after the despawn fade-out completes. Removes from
## the GameManager collectibles list first to prevent invalid references.
func _despawn_free() -> void:
	GameManager.collectibles.erase(self)
	queue_free()

func _collect() -> void:
	if is_popping:
		return

	# ── Phase 14: Mirror dimension — collectibles are hostile, damage the player ──
	if DimensionSystem.collectibles_hostile():
		# In co-op, damage the closest player
		var damage_target_is_p2: bool = false
		if CoOpManager.is_coop_active() and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
			var p1_dist: float = 99999.0
			var p2_dist: float = 99999.0
			if GameManager.player and is_instance_valid(GameManager.player) and not GameManager.player_is_downed:
				p1_dist = global_position.distance_to(GameManager.player.global_position)
			if not CoOpManager.p2_is_downed:
				p2_dist = global_position.distance_to(CoOpManager.p2_node.global_position)
			damage_target_is_p2 = p2_dist < p1_dist
		if damage_target_is_p2:
			CoOpManager.p2_take_damage(GameConstants.MIRROR_COLLECTIBLE_DAMAGE, global_position)
		else:
			GameManager.take_damage(GameConstants.MIRROR_COLLECTIBLE_DAMAGE, global_position)
		# Flash red and knock back instead of collecting
		if _mat:
			_mat.albedo_color = Color.RED
			var flash_tween := create_tween()
			flash_tween.tween_property(_mat, "albedo_color",
				TYPE_CONFIG.get(collectible_type, TYPE_CONFIG[GameConstants.CollectibleType.XP_ORB])["color"],
				0.3).set_ease(Tween.EASE_OUT)
		# Small knockback away from player
		var player: Node3D = _cached_player
		if damage_target_is_p2 and CoOpManager.p2_node:
			player = CoOpManager.p2_node
		if player and is_instance_valid(player):
			var away_dir: Vector3 = (global_position - player.global_position).normalized()
			away_dir.y = 0
			var knockback_tween := create_tween()
			knockback_tween.tween_property(self, "global_position",
				global_position + away_dir * 2.0, 0.2) \
				.set_ease(Tween.EASE_OUT)
		return

	is_popping = true
	# ── Pickup emission flash ── A brief white-hot emission spike on the
	# collectible mesh at the moment of pickup, so the "absorption" reads
	# as a burst of energy being consumed rather than just the item
	# shrinking away. The emission jumps to 6x and eases back over 0.15s
	# (overlapping with the spiral pickup animation), giving the final
	# moment of the collectible's life a flash of brilliance — the visual
	# equivalent of the pickup chime. Skipped if the material is already
	# freed (mirror dimension path may have modified it).
	if _mat:
		_mat.emission_energy_multiplier = 6.0
		var pickup_flash_tween := create_tween()
		pickup_flash_tween.tween_property(_mat, "emission_energy_multiplier",
			1.0, 0.15) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Remove from GameManager's collectible list to prevent the array from growing
	# with invalid references over time (performance leak).
	GameManager.collectibles.erase(self)

	# ── Phase 19: Co-op — track which player collected ──
	# Determine if P2 collected this item (by checking who's closest)
	var collected_by_p2: bool = false
	if CoOpManager.is_coop_active() and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
		var p1_dist: float = 99999.0
		var p2_dist: float = 99999.0
		if GameManager.player and is_instance_valid(GameManager.player) and not GameManager.player_is_downed:
			p1_dist = global_position.distance_to(GameManager.player.global_position)
		if not CoOpManager.p2_is_downed:
			p2_dist = global_position.distance_to(CoOpManager.p2_node.global_position)
		collected_by_p2 = p2_dist < p1_dist

	# ── Phase 16: If this is a crafting material, add it to the weapon mod inventory ──
	if GameConstants.CRAFTING_MATERIALS.has(collectible_type):
		if WeaponModSystem:
			WeaponModSystem.add_material(collectible_type, 1)

	# ── Phase 27: Pet Evolution Stones — add to PetStoneInventory autoload ──
	if GameConstants.PET_STONE_TO_PATH.has(collectible_type):
		if PetStoneInventory:
			PetStoneInventory.add_stone(collectible_type, 1)
		# Dedicated HUD message announcing the stone type — evolution stones
		# are rare drops (1.5% normal, 100% boss) and the player should know
		# exactly which elemental stone they found. Previously the pickup was
		# silent beyond the generic rare-pickup SFX.
		var stone_path: int = GameConstants.PET_STONE_TO_PATH[collectible_type]
		var stone_name: String = GameConstants.PET_STONE_NAMES[stone_path]
		GameManager.add_message("🪨 %s acquired! Press [B] to feed it to your pet!" % stone_name)
		# Stones also feed the active pet automatically (if one exists)
		var pet: Node = get_tree().get_first_node_in_group("companion_pet")
		if pet and is_instance_valid(pet) and pet.has_method("feed"):
			pet.feed(collectible_type)

	# Award XP (shared in co-op — both players benefit from the same XP pool)
	if xp_value > 0:
		GameManager.gain_xp(xp_value)
		# Spawn XP gain popup (cyan-blue "+N XP")
		_spawn_xp_popup(xp_value)

	# Health fragments heal the collecting player
	if collectible_type == GameConstants.CollectibleType.HEALTH_FRAGMENT:
		if collected_by_p2:
			CoOpManager.p2_heal(25)
		else:
			# ── Phase 34: Survival mode — no healing items ──
			GameManager.block_heal_next_call()
			GameManager.heal(25)
		# Spawn heal popup (green "+25")
		_spawn_heal_popup(25)

	# Pickup streak (shared in co-op)
	GameManager.add_pickup_streak()

	# ── Phase 19: Award score to the collecting player ──
	if collected_by_p2:
		CoOpManager.p2_add_score(10)

	# Phase 6: Pickup sparkle burst
	var config: Dictionary = TYPE_CONFIG.get(collectible_type, TYPE_CONFIG[GameConstants.CollectibleType.XP_ORB])
	ParticleEffects.spawn_pickup_sparkle(get_parent(), global_position, config["color"])

	# ── Player pickup feedback pulse ── A subtle scale pop on the player
	#    mesh when collecting an item, so pickups feel tactile — Zorp
	#    briefly "absorbs" the item with a small grow + emission flash
	#    in the collectible's color. Rare items get a slightly bigger
	#    pop. This is skipped during dash/slide (their tweens own
	#    mesh.scale) and when the player is dead. The player reference
	#    is cached (_cached_player) so we don't need a group lookup.
	if _cached_player and is_instance_valid(_cached_player) and _cached_player.has_method("_play_pickup_pulse"):
		_cached_player._play_pickup_pulse(config["color"], _is_rare())

	# ── Pickup light flash ── A brief OmniLight3D at the pickup point that
	# flashes the collectible's color and fades over 0.25s. Gives pickups
	# extra punch in dark biomes where the sparkle particles alone can be
	# subtle. Rare items get a brighter, wider flash for a juicier reward.
	# POOLING: Uses the PerformanceOptimizer transient light pool instead
	# of creating/freeing a new OmniLight3D per pickup.
	var flash_intensity: float = 2.0
	var flash_range: float = 3.0
	if _is_rare():
		flash_intensity = 3.5
		flash_range = 5.0
	if PerformanceOptimizer:
		var pickup_light := PerformanceOptimizer.acquire_transient_light(
			global_position,
			config["color"],
			flash_intensity,
			0.3,
			flash_range,
			1.2
		)
		if pickup_light:
			var light_fade := pickup_light.create_tween()
			light_fade.tween_property(pickup_light, "light_energy", 0.0, 0.25) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	else:
		# Fallback: standalone light (non-pooled path)
		var pickup_light := OmniLight3D.new()
		pickup_light.light_color = config["color"]
		pickup_light.light_energy = flash_intensity
		pickup_light.omni_range = flash_range
		pickup_light.omni_attenuation = 1.2
		get_parent().add_child(pickup_light)
		pickup_light.global_position = global_position
		var light_fade := pickup_light.create_tween()
		light_fade.tween_property(pickup_light, "light_energy", 0.0, 0.25) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		light_fade.tween_callback(pickup_light.queue_free)

	# Rare items get a sky beam
	if collectible_type == GameConstants.CollectibleType.METEOR_SHARD:
		ParticleEffects.spawn_sky_beam(get_parent(), global_position, Color(1.0, 0.5, 0.1))

	# Pickup animation: spiral orbit around the player + pop up + spin fast +
	# shrink, with easing for juicy feel. The spiral gives magnetic pickups
	# a sense of being "drawn in" — the item orbits the player once as it
	# rises and shrinks, creating a satisfying vortex catch effect. The orbit
	# uses a single full rotation (TAU) so it reads as one smooth swirl.
	# We compute the orbit relative to the player's position at pickup time
	# so the spiral doesn't drift if the player moves during the animation.
	var spiral_player_pos: Vector3 = Vector3.ZERO
	if _cached_player and is_instance_valid(_cached_player):
		spiral_player_pos = _cached_player.global_position
	var spiral_start_pos: Vector3 = global_position
	var spiral_radius_start: float = clampf(
		global_position.distance_to(spiral_player_pos), 0.5, 3.0)
	var tween := create_tween()
	# Phase 1: spiral orbit + rise (0.18s) — one full rotation as we lift
	tween.tween_method(
		func(t: float):
			var angle: float = t * TAU
			var radius: float = spiral_radius_start * (1.0 - t * 0.7)
			global_position = spiral_player_pos + Vector3(
				cos(angle) * radius,
				spiral_start_pos.y - spiral_player_pos.y + 0.8 * t,
				sin(angle) * radius
			),
		0.0, 1.0, 0.18
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Phase 2: pop scale up + shrink to zero
	tween.tween_property(self, "scale", Vector3.ONE * 1.5, 0.1) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(self, "scale", Vector3.ZERO, 0.18) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_CUBIC)
	# Rise slightly during shrink for a "lift" feel
	tween.parallel().tween_property(self, "global_position:y", global_position.y + 0.8, 0.25) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)

	collected.emit(collectible_type, xp_value)
	# ── Phase 25: Statistics tracking — record item collection ──
	if Statistics:
		Statistics.record_item_collected(collectible_type)
	# ── Phase 31: Tutorial — first pickup notification ──
	if TutorialManager and TutorialManager.has_method("notify_first_pickup"):
		TutorialManager.notify_first_pickup()
	# Phase 20: Audio — pickup SFX (rare items get a different sound)
	# NOTE: This is a stricter subset of _is_rare() — only the "legendary"
	# pickups (meteor shards, quantum fuzz, nebula dust, pet evolution
	# stones) trigger the rare SFX + FOV micro-kick. Crafting materials
	# (SHIELD_CRYSTAL, etc.) are "rare" visually (glow, spin, flash) but
	# drop often enough (~12%) that giving them the FOV kick would make
	# the camera breathe constantly during farming. So they use the
	# common pickup SFX — still get the brighter flash and faster spin.
	var is_rare: bool = collectible_type in [
		GameConstants.CollectibleType.METEOR_SHARD,
		GameConstants.CollectibleType.QUANTUM_FUZZ,
		GameConstants.CollectibleType.NEBULA_DUST,
		GameConstants.CollectibleType.EMBER_STONE,
		GameConstants.CollectibleType.FROST_STONE,
		GameConstants.CollectibleType.SPARK_STONE,
		GameConstants.CollectibleType.VOID_STONE,
		GameConstants.CollectibleType.LEAF_STONE,
	]
	if is_rare:
		# ── Value-based pitch variation ── Rare pickups get a slightly higher
		#    pitch for more valuable items (evolution stones > meteor shards),
		#    so the player hears a subtle difference between a common rare drop
		#    and a top-tier stone. The base ±6% random variation (from
		#    _PITCH_VARIATION_SFX) still applies on top of this, keeping each
		#    pickup organic. Pet evolution stones get the highest pitch (1.15)
		#    since they're the most valuable drops in the game.
		var rare_pitch: float = 1.0
		var is_pet_stone: bool = collectible_type in [
			GameConstants.CollectibleType.EMBER_STONE,
			GameConstants.CollectibleType.FROST_STONE,
			GameConstants.CollectibleType.SPARK_STONE,
			GameConstants.CollectibleType.VOID_STONE,
			GameConstants.CollectibleType.LEAF_STONE,
		]
		if is_pet_stone:
			rare_pitch = 1.15
		elif collectible_type == GameConstants.CollectibleType.METEOR_SHARD:
			rare_pitch = 1.08
		AudioManager.play_sfx_pitched(AudioManager.SFX_PICKUP_RARE, rare_pitch)
		# ── FOV micro-kick on rare pickup ── A tiny, quick FOV widen (3°) that
		#    eases back over ~0.8s. Much smaller than the level-up kick (8°)
		#    so it reads as a subtle "ooh, shiny" pulse rather than a power
		#    surge. Gives rare pickups a touch more reward feel without
		#    being distracting when farming materials. Only fires for rare
		#    items so common XP orbs don't make the camera breathe constantly.
		if GameManager.camera_rig and GameManager.camera_rig.has_method("kick_fov"):
			GameManager.camera_rig.kick_fov(3.0)
	else:
		# ── Value-based pitch for common pickups ── Higher-value common items
		#    (star fruit, health fragments) get a slightly higher pitch than
		#    base XP orbs, so the player subconsciously learns to associate
		#    the brighter chime with better pickups. The pitch shift is small
		#    (1.0 for XP orbs, 1.06 for star fruit / health fragments) so it
		#    doesn't draw attention but adds subtle variety to mass pickups.
		var common_pitch: float = 1.0
		if collectible_type == GameConstants.CollectibleType.STAR_FRUIT \
				or collectible_type == GameConstants.CollectibleType.HEALTH_FRAGMENT:
			common_pitch = 1.06
		AudioManager.play_sfx_pitched(AudioManager.SFX_PICKUP, common_pitch)

## Spawn a tiny sparkle particle at the collectible's current position for the
## magnetic pull trail. Very lightweight — a single small sphere with quick
## fade-out, pooled via GPUParticles3D one-shot + auto-free. The color matches
## the collectible's type color so the trail reads as "energy flowing toward
## the player" in the right hue. Rare items get slightly brighter sparkles.
##
## PERFORMANCE: This fires every 0.06s during magnetic pull (many collectibles
## simultaneously). Previously each call allocated 6 objects: GPUParticles3D,
## ParticleProcessMaterial, Gradient, GradientTexture1D, SphereMesh, and
## StandardMaterial3D. Now the SphereMesh and StandardMaterial3D template are
## shared statics (duplicated per call — cheaper than new + configure), and the
## fade ramp uses ParticleEffects' cached _create_fade_ramp. The GPUParticles3D
## and ParticleProcessMaterial must still be per-call (one-shot node + per-color
## process material), but the 4-object reduction eliminates the bulk of the
## allocation churn during mass pickups.
static var _shared_sparkle_mesh: SphereMesh = null
static var _shared_sparkle_draw_mat_template: StandardMaterial3D = null

static func _ensure_sparkle_shared_resources() -> void:
	if _shared_sparkle_mesh == null:
		_shared_sparkle_mesh = SphereMesh.new()
		_shared_sparkle_mesh.radius = 0.06
		_shared_sparkle_mesh.height = 0.12
		_shared_sparkle_mesh.radial_segments = 4
		_shared_sparkle_mesh.rings = 2
	if _shared_sparkle_draw_mat_template == null:
		_shared_sparkle_draw_mat_template = StandardMaterial3D.new()
		_shared_sparkle_draw_mat_template.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_sparkle_draw_mat_template.emission_enabled = true

func _spawn_pull_sparkle() -> void:
	var parent_node: Node = get_parent()
	if not parent_node:
		return
	var config: Dictionary = TYPE_CONFIG.get(collectible_type, TYPE_CONFIG[GameConstants.CollectibleType.XP_ORB])
	var col: Color = config["color"]
	_ensure_sparkle_shared_resources()
	var p := GPUParticles3D.new()
	p.amount = 3
	p.lifetime = 0.25
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.local_coords = false
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 0, 0)
	pmat.spread = 180.0
	pmat.gravity = Vector3.ZERO
	pmat.initial_velocity_min = 0.3
	pmat.initial_velocity_max = 1.0
	pmat.scale_min = 0.04
	pmat.scale_max = 0.08
	pmat.color = col
	# Use the cached fade ramp from ParticleEffects (shared across all
	# collectibles of the same type — the color pair is identical).
	pmat.color_ramp = ParticleEffects._create_fade_ramp(
		Color(col.r, col.g, col.b, 0.8),
		Color(col.r, col.g, col.b, 0.0))
	p.process_material = pmat
	# Duplicate the shared mesh so each sparkle gets its own material
	# (geometry arrays are shared via Resource ref-counting).
	var mesh := _shared_sparkle_mesh.duplicate() as SphereMesh
	var smat := _shared_sparkle_draw_mat_template.duplicate() as StandardMaterial3D
	smat.albedo_color = col
	smat.emission = col * 0.5
	mesh.material = smat
	p.draw_pass_1 = mesh
	parent_node.add_child(p)
	p.global_position = global_position
	# Auto-free after the particles finish
	var t := get_tree()
	if t:
		t.create_timer(0.5).timeout.connect(p.queue_free)

func _spawn_xp_popup(amount: int) -> void:
	var parent: Node = get_parent()
	if not parent:
		return
	# Use the static free-list pool to avoid per-pickup Label3D allocation.
	var dn := DamageNumber._acquire()
	dn.request_ready()
	parent.add_child(dn)
	dn.global_position = global_position + Vector3(0, 1.5, 0)
	dn.configure_xp(amount)

func _spawn_heal_popup(amount: int) -> void:
	var parent: Node = get_parent()
	if not parent:
		return
	var dn := DamageNumber._acquire()
	dn.request_ready()
	parent.add_child(dn)
	dn.global_position = global_position + Vector3(0, 1.5, 0)
	dn.configure_heal(amount)