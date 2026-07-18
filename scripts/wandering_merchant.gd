## Zorp Wiggles — Wandering Merchant (Phase 26: World Life)
## A rare traveling merchant that appears periodically near the player, sells
## premium rare goods at a discounted Space Gloop cost, then despawns after a
## lifetime or if the player wanders too far. Distinct from the stationary
## Phase 3 traders (vivid magenta body + gold canopy + "Rare Goods" banner).
##
## The merchant uses the existing TradeMenu UI (via a small adapter: it sets a
## `stock_override` on itself that the trade menu reads when open). If the
## trade menu is unavailable, it falls back to a one-shot random trade.
##
## All colors use Godot 0-1 range.

extends CharacterBody3D

class_name WanderingMerchant

signal merchant_despawned(merchant: Node)
signal merchant_traded(merchant: Node, item_name: String)

# ─── Export ──────────────────────────────────────────────────────────────────
@export var merchant_name: String = ""

# ─── State ───────────────────────────────────────────────────────────────────
var _home: Vector3 = Vector3.ZERO
var _wander_dir: Vector3 = Vector3.ZERO
var _wander_timer: float = 0.0
var _time: float = 0.0
var _lifetime_left: float = 0.0
var _can_trade: bool = false
var _prompt_shown: bool = false
var _is_despawning: bool = false
var _cached_player: Node3D = null

# Public so the TradeMenu can read the discounted stock when this merchant is
# the active trader. The trade menu checks for this property and prefers it
# over its own TRADE_ITEMS list when present.
var stock_override: Array = []

# ─── Child nodes (built in _ready) ───────────────────────────────────────────
var _body_mesh: MeshInstance3D
var _canopy_mesh: MeshInstance3D
var _banner_mesh: MeshInstance3D
var _eye_l: MeshInstance3D
var _eye_r: MeshInstance3D
var _glow_light: OmniLight3D
var _prompt_label: Label3D
var _material: StandardMaterial3D

func _ready() -> void:
	add_to_group("wandering_merchant")
	add_to_group("trader")  # Reuse trader group so existing trade-menu discovery works
	add_to_group("non_hostile")
	if merchant_name == "":
		merchant_name = GameConstants.WANDERING_MERCHANT_NAMES[randi() % GameConstants.WANDERING_MERCHANT_NAMES.size()]
	stock_override = GameConstants.WANDERING_MERCHANT_STOCK.duplicate(true)
	_wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	_wander_timer = randf_range(3, 6)
	_lifetime_left = GameConstants.WANDERING_MERCHANT_LIFETIME
	_build_visuals()
	call_deferred("_update_home")

func _update_home() -> void:
	_home = global_position

func _build_visuals() -> void:
	# Body — vivid magenta sphere.
	_body_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.85
	sphere.height = 1.7
	_body_mesh.mesh = sphere
	_material = StandardMaterial3D.new()
	_material.albedo_color = GameConstants.WANDERING_MERCHANT_BODY_COLOR
	_material.emission_enabled = true
	_material.emission = GameConstants.WANDERING_MERCHANT_BODY_COLOR * 0.3
	_material.emission_energy_multiplier = 1.0
	_material.rim_enabled = true
	_material.rim = 0.7
	_material.rim_tint = 0.9
	# Enable alpha transparency so the despawn fade-out (tween on
	# albedo_color:a) is actually visible. Without this, StandardMaterial3D
	# ignores the alpha channel and the merchant pops out instead of fading.
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_body_mesh.material_override = _material
	add_child(_body_mesh)

	# Canopy — a flat gold disc floating above the head (the "shop awning").
	_canopy_mesh = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.1
	disc.bottom_radius = 1.1
	disc.height = 0.12
	_canopy_mesh.mesh = disc
	_canopy_mesh.position = Vector3(0, 1.4, 0)
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = GameConstants.WANDERING_MERCHANT_HAT_COLOR
	canopy_mat.emission_enabled = true
	canopy_mat.emission = GameConstants.WANDERING_MERCHANT_HAT_COLOR * 0.4
	canopy_mat.emission_energy_multiplier = 1.2
	_canopy_mesh.material_override = canopy_mat
	add_child(_canopy_mesh)

	# Banner — a thin vertical quad hanging from the canopy with "RARE" text.
	_banner_mesh = MeshInstance3D.new()
	var banner := PlaneMesh.new()
	banner.size = Vector2(0.9, 0.45)
	_banner_mesh.mesh = banner
	_banner_mesh.position = Vector3(0, 1.05, 0.95)
	_banner_mesh.rotation_degrees.x = 90.0
	var banner_mat := StandardMaterial3D.new()
	banner_mat.albedo_color = Color(0.1, 0.05, 0.2)
	banner_mat.emission_enabled = true
	banner_mat.emission = GameConstants.WANDERING_MERCHANT_HAT_COLOR * 0.6
	banner_mat.emission_energy_multiplier = 1.0
	banner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# We can't easily render text on a mesh without a texture, so the banner
	# is a glowing gold plate — readable as "premium goods" by color alone.
	_banner_mesh.material_override = banner_mat
	add_child(_banner_mesh)

	# Two glowing cyan eyes.
	_eye_l = _create_eye(Vector3(-0.28, 0.25, -0.65))
	_eye_r = _create_eye(Vector3(0.28, 0.25, -0.65))
	add_child(_eye_l)
	add_child(_eye_r)

	# Soft magenta glow light.
	_glow_light = OmniLight3D.new()
	_glow_light.position = Vector3(0, 0.6, 0)
	_glow_light.omni_range = 6.0
	_glow_light.light_color = GameConstants.WANDERING_MERCHANT_GLOW_COLOR
	_glow_light.light_energy = 0.0  # Off until player is close
	add_child(_glow_light)

	# Floating "Press E for Rare Goods" prompt.
	_prompt_label = Label3D.new()
	_prompt_label.text = "Press E for Rare Goods"
	_prompt_label.position = Vector3(0, 2.2, 0)
	_prompt_label.font_size = 28
	_prompt_label.outline_size = 8
	_prompt_label.outline_modulate = Color(0, 0, 0, 0.85)
	_prompt_label.modulate = Color(1.0, 0.85, 0.3)
	_prompt_label.visible = false
	_prompt_label.no_depth_test = true
	add_child(_prompt_label)

func _create_eye(pos: Vector3) -> MeshInstance3D:
	var eye := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.13
	m.height = 0.26
	eye.mesh = m
	eye.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 1, 1)
	mat.emission_enabled = true
	mat.emission = Color(0, 1, 1)
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye.material_override = mat
	return eye

func _physics_process(delta: float) -> void:
	if GameManager.is_paused:
		return
	if _is_despawning:
		return
	_time += delta
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		_despawn("The merchant packed up and moved on.")
		return

	# Gentle wander within a tight radius (stays near spawn so the player can
	# find it again after opening/closing the trade menu).
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		_wander_timer = randf_range(3, 6)
	var to_home: Vector3 = global_position - _home
	if to_home.length() > GameConstants.WANDERING_MERCHANT_WANDER_RADIUS:
		_wander_dir = -to_home.normalized()
	velocity = _wander_dir * GameConstants.WANDERING_MERCHANT_SPEED
	move_and_slide()

	# Body bob for liveliness.
	if _body_mesh:
		_body_mesh.position.y = 0.05 * sin(_time * 3.0)

	# Player proximity: glow + prompt + despawn-if-far.
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	if not _cached_player:
		return
	var dist: float = global_position.distance_to(_cached_player.global_position)
	if dist > GameConstants.WANDERING_MERCHANT_TRADE_RANGE_DESPAWN:
		_despawn("The merchant wandered out of range.")
		return
	_can_trade = dist <= GameConstants.WANDERING_MERCHANT_TRADE_RANGE
	if _can_trade:
		var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
		_glow_light.light_energy = pulse * 2.0
		if not _prompt_shown:
			_prompt_shown = true
			_prompt_label.visible = true
			_prompt_label.scale = Vector3(0.001, 0.001, 0.001)
			var t := create_tween()
			t.tween_property(_prompt_label, "scale", Vector3.ONE, 0.25) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			GameManager.add_message("🛍 %s has arrived! Rare goods for sale nearby." % merchant_name)
	else:
		_glow_light.light_energy = 0.0
		if _prompt_shown:
			_prompt_shown = false
			_prompt_label.visible = false

	# Open the trade menu on E (the existing "trade" input action).
	if _can_trade and Input.is_action_just_pressed("trade"):
		_open_trade_menu()

func _open_trade_menu() -> void:
	var hud: CanvasLayer = GameManager.hud
	if not hud:
		_fallback_trade()
		return
	# Find the TradeMenu specifically — using `has_method("open")` alone is
	# fragile because FastTravelMenu also has an open() method (with a
	# different signature: no args). Matching by class avoids calling the
	# wrong menu and protects against future menus that add open().
	for child in hud.get_children():
		if child is TradeMenu:
			# The TradeMenu reads `stock_override` from the trader node if
			# present, falling back to its own TRADE_ITEMS otherwise.
			child.open(self)
			return
	_fallback_trade()

func _fallback_trade() -> void:
	# One-shot random trade if the TradeMenu UI is unavailable.
	var gloop: int = WeaponModSystem.get_material_count(GameConstants.CollectibleType.SPACE_GLOOP)
	if gloop < GameConstants.WANDERING_MERCHANT_STOCK[0]["cost"]:
		GameManager.add_message("Need at least %d Space Gloop to trade! (have %d)" % [GameConstants.WANDERING_MERCHANT_STOCK[0]["cost"], gloop])
		return
	var item: Dictionary = GameConstants.WANDERING_MERCHANT_STOCK[randi() % GameConstants.WANDERING_MERCHANT_STOCK.size()]
	var cost: int = int(item["cost"])
	var to_remove: Array = []
	for _i in range(cost):
		to_remove.append(GameConstants.CollectibleType.SPACE_GLOOP)
	WeaponModSystem.remove_materials(to_remove)
	WeaponModSystem.add_material(int(item["type"]), 1)
	GameManager.add_message("🛍 %s traded! Got: %s" % [merchant_name, item["name"]])
	merchant_traded.emit(self, item["name"])
	if Statistics and Statistics.has_method("record_merchant_trade"):
		Statistics.record_merchant_trade()
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.1)
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_PICKUP)

func _despawn(reason: String) -> void:
	if _is_despawning:
		return
	_is_despawning = true
	GameManager.add_message("🛍 %s — %s" % [merchant_name, reason])
	merchant_despawned.emit(self)
	# Fade out + shrink, then queue_free.
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_material, "albedo_color:a", 0.0, 0.6)
	if _body_mesh:
		t.tween_property(_body_mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.6) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.chain().tween_callback(queue_free)

# Called by the TradeMenu after a successful purchase so the merchant can
# react (small celebration + chance to despawn after a few trades).
func on_trade_completed(item_name: String) -> void:
	merchant_traded.emit(self, item_name)
	if Statistics and Statistics.has_method("record_merchant_trade"):
		Statistics.record_merchant_trade()
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.08)