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
# ── Idle bob phase accumulator — drives a subtle vertical bob so the
# trader feels alive while wandering, instead of sliding like a statue.
# The bob is a low-amplitude sine (±6cm at ~1.5 Hz) applied to the body
# mesh only, so it doesn't interfere with the CharacterBody3D's physics.
var _bob_phase: float = 0.0
const _BOB_AMPLITUDE: float = 0.06
const _BOB_SPEED: float = 1.5
# ── Smoothed glow energy — the old code snapped the glow off instantly
# when the player left trade range, which read as a flicker at the
# threshold. We lerp the target energy so the glow fades in/out smoothly.
var _glow_energy_current: float = 0.0
var _glow_energy_target: float = 0.0
const _GLOW_SMOOTHING: float = 6.0  # Higher = snappier glow transition
# ── Facing: when the player is in trade range, the trader smoothly
# rotates to face them so the interaction feels attentive. Outside trade
# range, the trader faces its wander direction. The rotation is eased
# (not snapped) so it reads as a deliberate turn.
var _target_yaw: float = 0.0
const _TURN_SMOOTHING: float = 5.0
# ── Base Y positions of the visual meshes — stored so the idle bob can
# be applied as an offset (base_y + bob_y) without drifting over time.
# The hat and eyes are children of the trader root, not the body mesh,
# so we track each one's resting Y separately.
var _body_base_y: float = 0.0
var _hat_base_y: float = 0.8
var _eye_l_base_y: float = 0.25
var _eye_r_base_y: float = 0.25

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
	_hat_base_y = _hat_mesh.position.y
	_hat_mesh.material_override = _make_mat(GameConstants.TRADER_HAT_COLOR)
	add_child(_hat_mesh)

	# Left eye — small cyan sphere
	_eye_l = MeshInstance3D.new()
	var eye_l_mesh := SphereMesh.new()
	eye_l_mesh.radius = 0.25
	eye_l_mesh.height = 0.5
	_eye_l.mesh = eye_l_mesh
	_eye_l.position = Vector3(-0.25, 0.25, -0.5)
	_eye_l_base_y = _eye_l.position.y
	_eye_l.material_override = _make_mat(Color(0, 1, 1))
	add_child(_eye_l)

	# Right eye
	_eye_r = MeshInstance3D.new()
	var eye_r_mesh := SphereMesh.new()
	eye_r_mesh.radius = 0.25
	eye_r_mesh.height = 0.5
	_eye_r.mesh = eye_r_mesh
	_eye_r.position = Vector3(0.25, 0.25, -0.5)
	_eye_r_base_y = _eye_r.position.y
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
	_bob_phase += delta * _BOB_SPEED

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

	# ── Idle bob: apply a subtle vertical sine to all visual meshes
	# (body, hat, eyes) so the trader feels alive while wandering. The
	# bob only affects the visuals (not the CharacterBody3D's y position)
	# so physics/collision are undisturbed. The hat and eyes are children
	# of the trader root (not the body mesh), so we bob them all together
	# to keep the rig rigid. The bob pauses while trading so the trader
	# feels attentive and still during the interaction.
	var bob_y: float
	if not _can_trade:
		bob_y = _BOB_AMPLITUDE * sin(_bob_phase * TAU * 0.5)
	else:
		# Ease the bob back to zero when trading so the trader settles
		var settle_weight: float = 1.0 - exp(-_GLOW_SMOOTHING * delta)
		bob_y = lerpf(_get_visual_bob_y(), 0.0, settle_weight)
	_apply_visual_bob_y(bob_y)

	# Check if player is near enough to trade
	var player: CharacterBody3D = GameManager.player
	if player and is_instance_valid(player):
		var dist: float = global_position.distance_to(player.global_position)
		var was_can_trade: bool = _can_trade
		_can_trade = dist <= GameConstants.TRADER_GLOW_RANGE

		# ── Smoothed glow: lerp the energy toward the target so the glow
		# fades in/out smoothly instead of snapping on/off at the range
		# threshold. The target is a pulsing value when trading, 0 when not.
		if _can_trade:
			var pulse: float = 0.5 + 0.5 * sin(_time * GameConstants.TRADER_GLOW_PULSE_SPEED)
			_glow_energy_target = pulse * 2.0
			if not _trade_prompt_shown:
				_trade_prompt_shown = true
				trade_available.emit(true)
				GameManager.add_message("🛒 Press [E] to trade with %s" % trader_name)
		else:
			_glow_energy_target = 0.0
			if _trade_prompt_shown:
				_trade_prompt_shown = false
				trade_available.emit(false)
		# Frame-rate-independent exponential lerp toward the target energy
		var glow_weight: float = 1.0 - exp(-_GLOW_SMOOTHING * delta)
		_glow_energy_current = lerpf(_glow_energy_current, _glow_energy_target, glow_weight)
		if _glow_light:
			_glow_light.light_energy = _glow_energy_current

		# ── Facing: rotate to face the player when in trade range, or
		# face the wander direction otherwise. The rotation is eased so
		# the trader turns deliberately rather than snapping. We compute
		# the target yaw from the direction vector and lerp the actual
		# yaw toward it. This makes the trader feel attentive — it turns
		# to look at you when you approach.
		var face_dir: Vector3
		if _can_trade:
			face_dir = (player.global_position - global_position)
		else:
			face_dir = _wander_dir
		face_dir.y = 0
		if face_dir.length_squared() > 0.01:
			_target_yaw = atan2(face_dir.x, face_dir.z)
		var turn_weight: float = 1.0 - exp(-_TURN_SMOOTHING * delta)
		var current_yaw: float = rotation.y
		# Shortest-angle lerp so the trader doesn't spin the long way around
		var yaw_diff: float = fmod(_target_yaw - current_yaw + PI, TAU) - PI
		rotation.y = current_yaw + yaw_diff * turn_weight

		# Check for trade input — opens trade menu UI
		if _can_trade and Input.is_action_just_pressed("trade"):
			_open_trade_menu()

func _open_trade_menu() -> void:
	# Find the TradeMenu in the HUD and open it
	var hud: CanvasLayer = GameManager.hud
	if not hud:
		# Fallback to old instant trade if HUD not available
		_try_trade()
		return
	# Find TradeMenu control by class — `has_method("open")` is too loose
	# now that FastTravelMenu (open() with no args) also lives in the HUD.
	for child in hud.get_children():
		if child is TradeMenu:
			child.open(self)
			return
	# Fallback to old instant trade
	_try_trade()

func _try_trade() -> void:
	# Fallback trade path used only when the TradeMenu UI isn't available.
	# The primary path opens TradeMenu (see _open_trade_menu above), which
	# handles Space Gloop deduction via WeaponModSystem.remove_materials().
	# This fallback must use the same inventory source so it stays consistent.
	var gloop_count: int = WeaponModSystem.get_material_count(GameConstants.CollectibleType.SPACE_GLOOP)

	if gloop_count < GameConstants.TRADER_TRADE_COST:
		GameManager.add_message("Need %d Space Gloop to trade! (have %d)" % [GameConstants.TRADER_TRADE_COST, gloop_count])
		return

	# Deduct Space Gloop via WeaponModSystem (remove_materials expects an Array
	# of material types, one entry per unit — NOT a Dictionary).
	var materials_to_remove: Array = []
	for _i in range(GameConstants.TRADER_TRADE_COST):
		materials_to_remove.append(GameConstants.CollectibleType.SPACE_GLOOP)
	WeaponModSystem.remove_materials(materials_to_remove)

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

# ── Idle bob helpers ── The body, hat, and eyes are separate children of
# the trader root, so the bob must be applied to all three to keep the
# rig rigid. _get_visual_bob_y returns the current bob offset (relative
# to base) by reading the body mesh's Y; _apply_visual_bob_y writes the
# offset to all three meshes. Using base_y + bob_y prevents drift.
func _get_visual_bob_y() -> float:
	if _body_mesh:
		return _body_mesh.position.y - _body_base_y
	return 0.0

func _apply_visual_bob_y(bob_y: float) -> void:
	if _body_mesh:
		_body_mesh.position.y = _body_base_y + bob_y
	if _hat_mesh:
		_hat_mesh.position.y = _hat_base_y + bob_y
	if _eye_l:
		_eye_l.position.y = _eye_l_base_y + bob_y
	if _eye_r:
		_eye_r.position.y = _eye_r_base_y + bob_y