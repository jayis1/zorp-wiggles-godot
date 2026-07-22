## Zorp Wiggles — Fast Travel Waypoint (Phase 26: World Life)
## A teal pillar scattered across the world. The player activates it by
## walking within FAST_TRAVEL_ACTIVATE_RANGE (auto-activates on proximity).
## Once activated, it appears in the FastTravelNetwork menu and the player
## can teleport back to it for a small Space Gloop cost.
##
## Visuals: a tall glowing pillar + a ground activation ring + an OmniLight.
## Inactive waypoints are grey; activated waypoints turn teal and pulse.
## All colors use Godot 0-1 range.

extends Area3D

class_name FastTravelWaypoint

signal waypoint_activated(waypoint: Node)

@export var waypoint_name: String = ""

var _is_activated: bool = false
var _time: float = 0.0
var _cached_player: Node3D = null
var _prompt_shown: bool = false

# ─── Child nodes ─────────────────────────────────────────────────────────────
var _pillar_mesh: MeshInstance3D
var _ring_mesh: MeshInstance3D
var _glow_light: OmniLight3D
var _prompt_label: Label3D
var _material: StandardMaterial3D
var _ring_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("fast_travel_waypoint")
	if waypoint_name == "":
		waypoint_name = "Waypoint #%d" % (randi() % 9000 + 1000)
	_build_visuals()
	# Collision: the scene already provides a CollisionShape3D with a
	# BoxShape3D (3.6×3×3.6). We resize that existing shape to match the
	# activation radius instead of adding a second CollisionShape3D — a
	# double-collision pair would cause duplicate body_entered signals and
	# waste broadphase work. Use the scene's shape; only create one if the
	# scene omitted it (defensive for procedural instantiation).
	var col: CollisionShape3D = get_node_or_null("CollisionShape3D")
	if col == null:
		col = CollisionShape3D.new()
		add_child(col)
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = GameConstants.FAST_TRAVEL_RADIUS
	shape.height = 3.0
	col.shape = shape
	col.position = Vector3(0, 1.5, 0)
	# Connect body_entered for auto-activation.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _build_visuals() -> void:
	# Pillar — a tall thin cylinder.
	_pillar_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.35
	cyl.height = GameConstants.FAST_TRAVEL_HEIGHT
	_pillar_mesh.mesh = cyl
	_pillar_mesh.position = Vector3(0, GameConstants.FAST_TRAVEL_HEIGHT * 0.5, 0)
	_material = StandardMaterial3D.new()
	_material.albedo_color = GameConstants.FAST_TRAVEL_INACTIVE_COLOR
	_material.emission_enabled = true
	_material.emission = GameConstants.FAST_TRAVEL_INACTIVE_COLOR * 0.2
	_material.emission_energy_multiplier = 0.5
	_material.rim_enabled = true
	_material.rim = 0.6
	_pillar_mesh.material_override = _material
	add_child(_pillar_mesh)

	# Ground ring — the activation zone indicator.
	_ring_mesh = MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = GameConstants.FAST_TRAVEL_RADIUS
	ring.bottom_radius = GameConstants.FAST_TRAVEL_RADIUS
	ring.height = 0.05
	_ring_mesh.mesh = ring
	_ring_mesh.position = Vector3(0, 0.03, 0)
	_ring_material = StandardMaterial3D.new()
	_ring_material.albedo_color = GameConstants.FAST_TRAVEL_INACTIVE_COLOR
	_ring_material.emission_enabled = true
	_ring_material.emission = GameConstants.FAST_TRAVEL_INACTIVE_COLOR * 0.3
	_ring_material.emission_energy_multiplier = 0.6
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.albedo_color.a = 0.5
	_ring_mesh.material_override = _ring_material
	add_child(_ring_mesh)

	# Glow light.
	_glow_light = OmniLight3D.new()
	_glow_light.position = Vector3(0, GameConstants.FAST_TRAVEL_HEIGHT * 0.6, 0)
	_glow_light.omni_range = 6.0
	_glow_light.light_color = GameConstants.FAST_TRAVEL_INACTIVE_COLOR
	_glow_light.light_energy = 0.3
	add_child(_glow_light)

	# Floating prompt.
	_prompt_label = Label3D.new()
	_prompt_label.text = "Waypoint"
	_prompt_label.position = Vector3(0, GameConstants.FAST_TRAVEL_HEIGHT + 0.5, 0)
	_prompt_label.font_size = 24
	_prompt_label.outline_size = 8
	_prompt_label.outline_modulate = Color(0, 0, 0, 0.85)
	_prompt_label.modulate = Color(0.7, 0.7, 0.75)
	_prompt_label.no_depth_test = true
	add_child(_prompt_label)

func _on_body_entered(body: Node) -> void:
	if _is_activated:
		return
	# Only the player (or P2) activates waypoints.
	if body.is_in_group("player"):
		_activate()
		return
	# P2 check: CoOpManager nodes may carry an is_p2 flag.
	if "is_p2" in body and body.is_p2:
		_activate()

func _activate() -> void:
	if _is_activated:
		return
	_is_activated = true
	# Visual transition: grey → teal with a pop.
	_material.albedo_color = GameConstants.FAST_TRAVEL_COLOR
	_material.emission = GameConstants.FAST_TRAVEL_COLOR * 0.6
	_material.emission_energy_multiplier = 1.5
	_ring_material.albedo_color = GameConstants.FAST_TRAVEL_COLOR
	_ring_material.albedo_color.a = 0.7
	_ring_material.emission = GameConstants.FAST_TRAVEL_COLOR * 0.5
	_ring_material.emission_energy_multiplier = 1.2
	_glow_light.light_color = GameConstants.FAST_TRAVEL_GLOW_COLOR
	_glow_light.light_energy = 1.2
	_glow_light.omni_range = 10.0
	_prompt_label.modulate = GameConstants.FAST_TRAVEL_GLOW_COLOR
	_prompt_label.text = "✓ %s" % waypoint_name
	# Pop-in animation.
	_pillar_mesh.scale = Vector3(0.5, 0.5, 0.5)
	var t := create_tween()
	t.tween_property(_pillar_mesh, "scale", Vector3.ONE, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	# Ring expansion burst — a quick scale-up on the ground ring that snaps
	# back, giving the activation a satisfying radial "ping" feel.
	if _ring_mesh:
		_ring_mesh.scale = Vector3(0.3, 1.0, 0.3)
		var rt := create_tween()
		rt.tween_property(_ring_mesh, "scale", Vector3.ONE, 0.5) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Particle burst.
	# ParticleEffects uses static methods — call directly.
	ParticleEffects.spawn_pickup_sparkle(get_parent(), global_position + Vector3(0, 1, 0), GameConstants.FAST_TRAVEL_GLOW_COLOR)
	# Small camera shake so the activation has a tactile feel even when the
	# player isn't looking directly at the waypoint.
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.15)
	# Register with the FastTravelNetwork autoload.
	if FastTravelNetwork:
		FastTravelNetwork.register_waypoint(self)
	# Stats + message.
	if Statistics and Statistics.has_method("record_waypoint_activated"):
		Statistics.record_waypoint_activated(waypoint_name)
	GameManager.add_message("🧭 Waypoint activated: %s" % waypoint_name)
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_HEAL)
	waypoint_activated.emit(self)

func _process(_delta: float) -> void:
	_time += _delta
	if _is_activated:
		# Pulse the ring + light for a "living" waypoint.
		var pulse: float = 0.7 + 0.3 * sin(_time * 2.5)
		if _ring_material:
			_ring_material.emission_energy_multiplier = 0.8 + 0.6 * pulse
		if _glow_light:
			_glow_light.light_energy = 0.9 + 0.5 * pulse
		# Slow rotation of the pillar for visual interest.
		if _pillar_mesh:
			_pillar_mesh.rotation.y = _time * 0.5

func is_activated() -> bool:
	return _is_activated