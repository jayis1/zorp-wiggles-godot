## Zorp Wiggles — Ping System (Phase 31: QoL)
## Lets the player drop a "ping" marker at a world location. The marker appears
## as a pulsing 3D beacon in the world AND as a flashing dot on the minimap, so
## the player can mark points of interest, enemies, or navigation waypoints.
##
## Usage:
##   Press the "ping" input action (default: middle mouse button) to drop a
##   ping at the position under the crosshair (raycast from camera). The ping
##   lasts PING_LIFETIME seconds then fades out. Up to MAX_PINGS can be active.
##   Pings are color-coded: default cyan, but holding Shift makes a red "danger"
##   ping, holding Alt makes a gold "loot" ping.
##
## Architecture:
##   - PingSystem is added as a child of the main scene (not an autoload — it
##     needs to spawn 3D nodes into the world).
##   - Each ping is a self-contained PingMarker Node3D with a vertical beam,
##     ground ring, and Label3D. It registers itself in the "ping" group so
##     the minimap can find it.
##   - The minimap draws pings as flashing colored diamonds.

extends Node3D

class_name PingSystem

const MAX_PINGS: int = 6
const PING_LIFETIME: float = 8.0
const PING_FADE_DURATION: float = 1.0
const PING_BEAM_HEIGHT: float = 12.0
const PING_BEAM_RADIUS: float = 0.15
const PING_RING_RADIUS: float = 1.5
const PING_RAYCAST_LENGTH: float = 100.0

# Ping colors by type
enum PingType {
	DEFAULT,   # Cyan — generic marker
	DANGER,    # Red — enemy/threat
	LOOT,      # Gold — treasure/item
	NAV,       # Teal — navigation waypoint
}
const PING_COLORS: Array[Color] = [
	Color(0.3, 0.9, 1.0),   # DEFAULT — cyan
	Color(1.0, 0.2, 0.2),   # DANGER — red
	Color(1.0, 0.85, 0.3),  # LOOT — gold
	Color(0.3, 1.0, 0.7),   # NAV — teal
]
const PING_LABELS: Array[String] = ["📌", "⚠", "💰", "➤"]

var _pings: Array[Node3D] = []
var _camera: Camera3D = null
var _player: CharacterBody3D = null
var _raycast: RayCast3D = null
var _enabled: bool = true


func _ready() -> void:
	# Create a RayCast3D for raycasting from the camera through the crosshair
	_raycast = RayCast3D.new()
	_raycast.enabled = false  # We only enable it momentarily during ping
	_raycast.collision_mask = 0b0001  # World/static layer only
	add_child(_raycast)
	# Resolve camera and player references on next frame (after scene is built)
	call_deferred("_resolve_refs")
	# Clear pings on game restart so stale markers don't persist into a new run.
	if GameManager and not GameManager.game_restarted.is_connected(_on_game_restarted):
		GameManager.game_restarted.connect(_on_game_restarted)


func _resolve_refs() -> void:
	_camera = get_viewport().get_camera_3d()
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event.is_action_pressed("ping") and GameManager.player_is_alive and not GameManager.is_paused:
		# Determine ping type from modifier keys
		var ptype: int = PingType.DEFAULT
		if Input.is_key_pressed(KEY_SHIFT):
			ptype = PingType.DANGER
		elif Input.is_key_pressed(KEY_ALT):
			ptype = PingType.LOOT
		elif Input.is_key_pressed(KEY_CTRL):
			ptype = PingType.NAV
		_drop_ping(ptype)
		get_viewport().set_input_as_handled()


## Drop a ping at the world position under the crosshair (or at the player's
## facing direction if no surface is hit).
func _drop_ping(ptype: int) -> void:
	if not _camera:
		_resolve_refs()
		if not _camera:
			return
	# Raycast from camera center through the screen
	var center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var from: Vector3 = _camera.global_position
	var dir: Vector3 = _camera.project_ray_normal(center)
	var to: Vector3 = from + dir * PING_RAYCAST_LENGTH

	_raycast.global_position = from
	_raycast.target_position = to - from
	_raycast.enabled = true
	_raycast.force_raycast_update()
	var hit_pos: Vector3 = _raycast.get_collision_point() if _raycast.is_colliding() else (from + dir * 40.0)
	_raycast.enabled = false

	# Snap to ground level (pings sit on the floor)
	hit_pos.y = 0.5

	# Enforce max pings — remove the oldest
	if _pings.size() >= MAX_PINGS:
		var oldest: Node3D = _pings[0]
		_pings.pop_at(0)
		if is_instance_valid(oldest):
			oldest.queue_free()

	# Spawn the ping marker
	var ping := _create_ping_marker(hit_pos, ptype)
	add_child(ping)
	_pings.append(ping)

	# Play a subtle UI sound
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)

	# Notify the player via HUD message (brief)
	var label_text: String = PING_LABELS[ptype] + " Ping dropped"
	if ptype == PingType.DANGER:
		label_text = "⚠ Danger ping!"
	elif ptype == PingType.LOOT:
		label_text = "💰 Loot ping!"
	GameManager.add_message(label_text)


func _create_ping_marker(pos: Vector3, ptype: int) -> Node3D:
	var ping := Node3D.new()
	ping.global_position = pos
	ping.add_to_group("ping")
	ping.set_meta("ping_type", ptype)
	ping.set_meta("ping_color", PING_COLORS[ptype])
	ping.set_meta("ping_lifetime", PING_LIFETIME)

	# Vertical beam (cylinder)
	var beam := MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = PING_BEAM_RADIUS
	beam_mesh.bottom_radius = PING_BEAM_RADIUS
	beam_mesh.height = PING_BEAM_HEIGHT
	beam.mesh = beam_mesh
	beam.position = Vector3(0, PING_BEAM_HEIGHT * 0.5, 0)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = PING_COLORS[ptype]
	beam_mat.emission_enabled = true
	beam_mat.emission = PING_COLORS[ptype]
	beam_mat.emission_energy_multiplier = 2.0
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_color.a = 0.6
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = beam_mat
	ping.add_child(beam)

	# Ground ring (torus)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.major_radius = PING_RING_RADIUS
	ring_mesh.minor_radius = 0.08
	ring.mesh = ring_mesh
	ring.position = Vector3(0, 0.05, 0)
	ring.rotation_degrees.x = 90.0
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = PING_COLORS[ptype]
	ring_mat.emission_enabled = true
	ring_mat.emission = PING_COLORS[ptype]
	ring_mat.emission_energy_multiplier = 1.5
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color.a = 0.8
	ring.material_override = ring_mat
	ping.add_child(ring)

	# OmniLight for visibility in dark biomes
	var light := OmniLight3D.new()
	light.light_color = PING_COLORS[ptype]
	light.light_energy = 1.5
	light.omni_range = 8.0
	light.omni_attenuation = 1.5
	light.position = Vector3(0, 2.0, 0)
	ping.add_child(light)

	# Label3D with the ping icon
	var label := Label3D.new()
	label.text = PING_LABELS[ptype]
	label.font_size = 48
	label.modulate = PING_COLORS[ptype]
	label.position = Vector3(0, PING_BEAM_HEIGHT + 0.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	ping.add_child(label)

	# Animate: pulsing scale on the ring + beam
	var tween := ping.create_tween()
	tween.set_loops()
	tween.tween_property(ring, "scale", Vector3(1.3, 1.3, 1.3), 0.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(ring, "scale", Vector3.ONE, 0.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Schedule fade-out and removal.
	# NOTE: `ping` is a Node3D, which has no `modulate` property (only
	# CanvasItem / Label3D descendants do). Fading the parent's modulate is a
	# no-op that would leave the beacon fully visible until it is freed. Fade
	# the Label3D's modulate plus the beam/ring/light that we actually own.
	var fade_tween := ping.create_tween()
	fade_tween.tween_interval(PING_LIFETIME - PING_FADE_DURATION)
	fade_tween.tween_property(label, "modulate:a", 0.0, PING_FADE_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fade_tween.parallel().tween_property(beam_mat, "albedo_color:a", 0.0, PING_FADE_DURATION)
	fade_tween.parallel().tween_property(ring_mat, "albedo_color:a", 0.0, PING_FADE_DURATION)
	fade_tween.parallel().tween_property(light, "light_energy", 0.0, PING_FADE_DURATION)
	fade_tween.tween_callback(func():
		if is_instance_valid(ping):
			_pings.erase(ping)
			ping.queue_free()
	)

	return ping


## Clear all active pings (on game restart, dimension shift, etc.)
func clear_pings() -> void:
	for ping in _pings:
		if is_instance_valid(ping):
			ping.queue_free()
	_pings.clear()


## Get all active ping positions for the minimap.
func get_pings() -> Array[Node3D]:
	return _pings


func _on_game_restarted() -> void:
	clear_pings()