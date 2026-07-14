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
		var mat := StandardMaterial3D.new()
		mat.albedo_color = config["color"]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = config["color"] * 0.3
		mesh_instance.material_override = mat

func _physics_process(delta: float) -> void:
	if GameManager.is_paused or not GameManager.player_is_alive:
		return
	
	# Bob up and down
	if not is_popping:
		bob_offset += delta * 2.0
		position.y = base_y + sin(bob_offset) * 0.3
	
	# Magnetic pull toward player
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var dist := global_position.distance_to(player.global_position)
	
	# Pull radius
	if dist < GameConstants.COLLECT_PULL_RADIUS and not is_popping:
		is_magnetic = true
		var pull_speed := GameConstants.COLLECT_PULL_SPEED * (1.0 - dist / GameConstants.COLLECT_PULL_RADIUS)
		var dir := (player.global_position - global_position).normalized()
		position += dir * pull_speed * delta
	
	# Collect radius
	if dist < GameConstants.COLLECT_RADIUS:
		_collect()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_collect()

func _collect() -> void:
	if is_popping:
		return
	
	is_popping = true
	
	# Award XP
	if xp_value > 0:
		GameManager.gain_xp(xp_value)
	
	# Health fragments heal
	if collectible_type == GameConstants.CollectibleType.HEALTH_FRAGMENT:
		GameManager.heal(25)
	
	# Pickup streak
	GameManager.add_pickup_streak()
	
	# Pickup animation then remove
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.5, 0.1)
	tween.chain().tween_property(self, "scale", Vector3.ZERO, 0.15)
	tween.tween_callback(queue_free)
	
	collected.emit(collectible_type, xp_value)