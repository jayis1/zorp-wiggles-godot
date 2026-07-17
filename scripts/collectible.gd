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
}

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	# Connect area signals
	body_entered.connect(_on_body_entered)
	
	# Setup visual based on type
	_apply_type_config()
	
	# Start bobbing animation
	base_y = global_position.y
	bob_offset = randf() * TAU  # Random phase offset

func set_type(type: int) -> void:
	collectible_type = type
	_apply_type_config()

func _apply_type_config() -> void:
	var config: Dictionary = TYPE_CONFIG.get(collectible_type, TYPE_CONFIG[GameConstants.CollectibleType.XP_ORB])
	xp_value = config["value"]
	
	if mesh_instance:
		# Create sphere mesh for collectible
		var sphere := SphereMesh.new()
		sphere.radius = config["scale"]
		sphere.height = config["scale"] * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		mesh_instance.mesh = sphere
		
		# Unlit material with the type color
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = config["color"]
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.emission_enabled = true
		_mat.emission = config["color"] * 0.3
		_mat.emission_energy_multiplier = 1.0
		mesh_instance.material_override = _mat

func _physics_process(delta: float) -> void:
	if GameManager.is_paused or not GameManager.player_is_alive:
		return

	# Bob up and down + gentle spin
	if not is_popping:
		bob_offset += delta * 2.0
		global_position.y = base_y + sin(bob_offset) * 0.3
		# Continuous slow rotation for visual appeal
		rotate_y(delta * 1.5)
		# Pulsing emission glow for better visibility ("breathing" effect)
		if _mat:
			var pulse: float = 0.7 + 0.4 * sin(bob_offset * 1.5)
			_mat.emission_energy_multiplier = pulse

	# Magnetic pull toward player
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	var player: Node3D = _cached_player
	if not player:
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
		var pull_speed := GameConstants.COLLECT_PULL_SPEED * (1.0 - dist / GameConstants.COLLECT_PULL_RADIUS)
		var dir := (player.global_position - global_position).normalized()
		global_position += dir * pull_speed * delta
	
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

	# Award XP
	if xp_value > 0:
		GameManager.gain_xp(xp_value)
		# Spawn XP gain popup (cyan-blue "+N XP")
		_spawn_xp_popup(xp_value)

	# Health fragments heal
	if collectible_type == GameConstants.CollectibleType.HEALTH_FRAGMENT:
		GameManager.heal(25)
		# Spawn heal popup (green "+25")
		_spawn_heal_popup(25)

	# Pickup streak
	GameManager.add_pickup_streak()

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