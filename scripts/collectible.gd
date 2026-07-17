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
		scale = Vector3.ZERO
		var pop_tween := create_tween()
		pop_tween.tween_property(self, "scale", Vector3.ONE, 0.35) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
		# Rare collectibles get a persistent point light so they glow in
		# dark biomes and are visible from a distance.
		# Phase 16: Crafting materials also get the glow (they're valuable).
		if collectible_type == GameConstants.CollectibleType.METEOR_SHARD \
				or collectible_type == GameConstants.CollectibleType.QUANTUM_FUZZ \
				or collectible_type == GameConstants.CollectibleType.NEBULA_DUST \
				or collectible_type == GameConstants.CollectibleType.SHIELD_CRYSTAL \
				or collectible_type == GameConstants.CollectibleType.FIREBALL_SCROLL \
				or collectible_type == GameConstants.CollectibleType.REGEN_CRYSTAL \
				or collectible_type == GameConstants.CollectibleType.MAGNET_CORE \
				or collectible_type == GameConstants.CollectibleType.TOXIC_EXTRACT:
			var glow := OmniLight3D.new()
			glow.light_color = config["color"]
			glow.light_energy = 1.2
			glow.omni_range = 4.0
			glow.omni_attenuation = 1.5
			add_child(glow)

func _physics_process(delta: float) -> void:
	if GameManager.is_paused or not GameManager.player_is_alive:
		return

	# Bob up and down + gentle spin + lateral wobble for an organic float
	if not is_popping:
		bob_offset += delta * 2.0
		global_position.y = base_y + sin(bob_offset) * 0.3
		# Rarity-based spin speed — rarer items spin faster, creating a
		# visual hierarchy where valuable pickups draw the eye. Crafting
		# materials (rare) spin faster than common XP orbs.
		var rarity_spin: float = 1.5  # Common default
		if collectible_type == GameConstants.CollectibleType.METEOR_SHARD \
				or collectible_type == GameConstants.CollectibleType.QUANTUM_FUZZ \
				or collectible_type == GameConstants.CollectibleType.NEBULA_DUST \
				or GameConstants.CRAFTING_MATERIALS.has(collectible_type):
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
				var pull_speed := GameConstants.HEALTH_FRAGMENT_EMERGENCY_PULL_SPEED * (1.0 - dist / GameConstants.HEALTH_FRAGMENT_EMERGENCY_PULL_RADIUS)
				var dir := (player.global_position - global_position).normalized()
				global_position += dir * pull_speed * delta

	# Normal pull radius (skip if emergency magnet already handled)
	if not is_emergency_magnet and dist < GameConstants.COLLECT_PULL_RADIUS and not is_popping:
		is_magnetic = true
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

	# Rare items get a sky beam
	if collectible_type == GameConstants.CollectibleType.METEOR_SHARD:
		ParticleEffects.spawn_sky_beam(get_parent(), global_position, Color(1.0, 0.5, 0.1))

	# Pickup animation: pop up + spin fast + shrink, with easing for juicy feel
	var tween := create_tween()
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