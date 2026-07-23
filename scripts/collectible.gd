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
# ── Magnet activation flash ── When the collectible first enters the
#    magnetic pull radius, the emission briefly spikes. This gives the
#    player a visual "the item noticed me" signal — the collectible
#    "lights up" as it starts moving toward them. The flag tracks whether
#    we've already flashed for the current magnetic engagement so we only
#    fire once per pull sequence (not every frame while being pulled).
var _magnet_flash_triggered: bool = false

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

	# Physics material with bounce
	var phys_mat := PhysicsMaterial.new()
	phys_mat.bounce = 0.4
	phys_mat.friction = 0.5
	_tumble_rigid.physics_material_override = phys_mat

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
		if _mat:
			var pulse: float = 0.7 + 0.4 * sin(bob_offset * 1.5)
			_mat.emission_energy_multiplier = pulse

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
				# Trigger the magnet activation flash on first engagement
				_trigger_magnet_flash()
				var pull_speed := GameConstants.HEALTH_FRAGMENT_EMERGENCY_PULL_SPEED * (1.0 - dist / GameConstants.HEALTH_FRAGMENT_EMERGENCY_PULL_RADIUS)
				var dir := (player.global_position - global_position).normalized()
				global_position += dir * pull_speed * delta

	# Normal pull radius (skip if emergency magnet already handled)
	if not is_emergency_magnet and dist < GameConstants.COLLECT_PULL_RADIUS and not is_popping:
		is_magnetic = true
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
		global_position += dir * pull_speed * delta
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

	# ── Pickup light flash ── A brief OmniLight3D at the pickup point that
	# flashes the collectible's color and fades over 0.25s. Gives pickups
	# extra punch in dark biomes where the sparkle particles alone can be
	# subtle. Rare items get a brighter, wider flash for a juicier reward.
	var pickup_light := OmniLight3D.new()
	pickup_light.light_color = config["color"]
	var flash_intensity: float = 2.0
	var flash_range: float = 3.0
	if _is_rare():
		flash_intensity = 3.5
		flash_range = 5.0
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
		AudioManager.play_sfx(AudioManager.SFX_PICKUP_RARE)
		# ── FOV micro-kick on rare pickup ── A tiny, quick FOV widen (3°) that
		#    eases back over ~0.8s. Much smaller than the level-up kick (8°)
		#    so it reads as a subtle "ooh, shiny" pulse rather than a power
		#    surge. Gives rare pickups a touch more reward feel without
		#    being distracting when farming materials. Only fires for rare
		#    items so common XP orbs don't make the camera breathe constantly.
		if GameManager.camera_rig and GameManager.camera_rig.has_method("kick_fov"):
			GameManager.camera_rig.kick_fov(3.0)
	else:
		AudioManager.play_sfx(AudioManager.SFX_PICKUP)

func _spawn_xp_popup(amount: int) -> void:
	var parent: Node = get_parent()
	if not parent:
		return
	var dn := DamageNumber.new()
	parent.add_child(dn)
	dn.global_position = global_position + Vector3(0, 1.5, 0)
	dn.configure_xp(amount)

func _spawn_heal_popup(amount: int) -> void:
	var parent: Node = get_parent()
	if not parent:
		return
	var dn := DamageNumber.new()
	parent.add_child(dn)
	dn.global_position = global_position + Vector3(0, 1.5, 0)
	dn.configure_heal(amount)