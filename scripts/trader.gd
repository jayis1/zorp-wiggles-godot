## Zorp Wiggles — Wandering Trader NPC
## A friendly alien NPC that wanders the world and trades Space Gloop for rare items.
## Ported from the Trader class in Ursina game.py.
## All colors use Godot 0-1 range.

extends CharacterBody3D

signal trade_completed(item_name: String)
signal trade_available(is_available: bool)

# ─── Export properties ───────────────────────────────────────────────────────
@export var trader_name: String = "Zix"

# ─── State ───────────────────────────────────────────────────────────────────
var _wander_dir: Vector3 = Vector3.ZERO
var _wander_timer: float = 0.0
var _home: Vector3 = Vector3.ZERO
var _trade_prompt_shown: bool = false
var _time: float = 0.0
var _can_trade: bool = false

# Trade item pool
const TRADE_ITEMS: Array[String] = [
	"Meteor Shard", "Quantum Fuzz", "Shield Crystal", "Weapon Upgrade",
	"Nebula Dust", "Magnet Core", "Time Warp", "Star Fruit",
	"Fireball Scroll", "Regen Crystal", "Lucky Clover", "Mirror Shard"
]

# ─── Child nodes ─────────────────────────────────────────────────────────────
@onready var _body_mesh: MeshInstance3D = $BodyMesh
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
var _hat_mesh: MeshInstance3D
var _eye_l: MeshInstance3D
var _eye_r: MeshInstance3D
var _glow_light: OmniLight3D

func _ready() -> void:
	if trader_name == "":
		trader_name = GameConstants.TRADER_NAMES[randi() % GameConstants.TRADER_NAMES.size()]
	_wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	_wander_timer = randf_range(3, 6)
	_home = global_position
	_build_visuals()
	add_to_group("trader")
	# Defer home position update to ensure global_position is set
	call_deferred("_update_home")

func _update_home() -> void:
	_home = global_position

func _build_visuals() -> void:
	# Apply material to the body mesh provided by the scene
	if _body_mesh:
		_body_mesh.material_override = _make_mat(GameConstants.TRADER_BODY_COLOR)

	# Hat — small box on top
	var hat_box := BoxMesh.new()
	hat_box.size = Vector3(0.8, 0.4, 0.8)
	_hat_mesh = MeshInstance3D.new()
	_hat_mesh.mesh = hat_box
	_hat_mesh.position = Vector3(0, 0.8, 0)
	_hat_mesh.material_override = _make_mat(GameConstants.TRADER_HAT_COLOR)
	add_child(_hat_mesh)

	# Left eye — small cyan sphere
	_eye_l = MeshInstance3D.new()
	var eye_l_mesh := SphereMesh.new()
	eye_l_mesh.radius = 0.25
	eye_l_mesh.height = 0.5
	_eye_l.mesh = eye_l_mesh
	_eye_l.position = Vector3(-0.25, 0.25, -0.5)
	_eye_l.material_override = _make_mat(Color(0, 1, 1))
	add_child(_eye_l)

	# Right eye
	_eye_r = MeshInstance3D.new()
	var eye_r_mesh := SphereMesh.new()
	eye_r_mesh.radius = 0.25
	eye_r_mesh.height = 0.5
	_eye_r.mesh = eye_r_mesh
	_eye_r.position = Vector3(0.25, 0.25, -0.5)
	_eye_r.material_override = _make_mat(Color(0, 1, 1))
	add_child(_eye_r)

	# Glow light for trade proximity effect
	_glow_light = OmniLight3D.new()
	_glow_light.position = Vector3(0, 0.5, 0)
	_glow_light.omni_range = 4.0
	_glow_light.light_color = GameConstants.TRADER_BODY_COLOR
	_glow_light.light_energy = 0.0  # Off until player is close
	add_child(_glow_light)

	# Collision shape is provided by the scene (CollisionShape3D) — no need to create a duplicate.

func _physics_process(delta: float) -> void:
	_time += delta

	# Wander AI
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		_wander_timer = randf_range(3, 6)

	# Move toward wander direction, but stay near home
	var to_home: Vector3 = global_position - _home
	var dist_from_home: float = to_home.length()
	if dist_from_home > GameConstants.TRADER_WANDER_RADIUS:
		# Steer back toward home
		_wander_dir = -to_home.normalized()

	velocity = _wander_dir * GameConstants.TRADER_SPEED
	move_and_slide()

	# Check if player is near enough to trade
	var player: CharacterBody3D = GameManager.player
	if player and is_instance_valid(player):
		var dist: float = global_position.distance_to(player.global_position)
		var was_can_trade: bool = _can_trade
		_can_trade = dist <= GameConstants.TRADER_GLOW_RANGE

		# Glow when player can trade
		if _can_trade:
			var pulse: float = 0.5 + 0.5 * sin(_time * GameConstants.TRADER_GLOW_PULSE_SPEED)
			_glow_light.light_energy = pulse * 2.0
			if not _trade_prompt_shown:
				_trade_prompt_shown = true
				trade_available.emit(true)
				GameManager.add_message("🛒 Press [E] to trade with %s" % trader_name)
		else:
			_glow_light.light_energy = 0.0
			if _trade_prompt_shown:
				_trade_prompt_shown = false
				trade_available.emit(false)

		# Check for trade input — opens trade menu UI
		if _can_trade and Input.is_action_just_pressed("trade"):
			_open_trade_menu()

func _open_trade_menu() -> void:
	# Find the trade menu in the HUD and open it
	var hud: CanvasLayer = GameManager.hud
	if not hud:
		# Fallback to old instant trade if HUD not available
		_try_trade()
		return
	# Find TradeMenu control
	for child in hud.get_children():
		if child is Control and child.has_method("open"):
			child.open(self)
			return
	# Fallback to old instant trade
	_try_trade()

func _try_trade() -> void:
	# Check if player has enough Space Gloop
	var gloop_count: int = 0
	# Access player inventory if available
	if GameManager.has_method("get_collectible_count"):
		gloop_count = GameManager.get_collectible_count(GameConstants.CollectibleType.SPACE_GLOOP)
	else:
		# Fallback — check collectibles array for nearby Space Gloop
		gloop_count = GameManager.collectibles.size()  # rough estimate

	if gloop_count < GameConstants.TRADER_TRADE_COST:
		GameManager.add_message("Need %d Space Gloop to trade!" % GameConstants.TRADER_TRADE_COST)
		return

	# Deduct Space Gloop
	if GameManager.has_method("remove_collectible"):
		GameManager.remove_collectible(GameConstants.CollectibleType.SPACE_GLOOP, GameConstants.TRADER_TRADE_COST)

	# Give random rare item
	var item_name: String = TRADE_ITEMS[randi() % TRADE_ITEMS.size()]
	GameManager.add_message("%s traded! Got: %s" % [trader_name, item_name])
	trade_completed.emit(item_name)

	# Camera shake
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.1)

func _make_mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat