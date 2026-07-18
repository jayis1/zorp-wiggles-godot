## Zorp Wiggles — Interactive Object (Phase 26: World Life)
## World objects the player can interact with: switches, doors, breakable
## walls, and hidden passages. These add light puzzle/exploration elements.
##
##   switch:         press T to toggle; opens/closes linked doors, reveals
##                   hidden passages. Has a cooldown between toggles.
##   door:           a static barrier that opens (lowers into the ground) when
##                   its linked switch is toggled. Blocks movement when closed.
##   breakable_wall: takes damage from player projectiles and dash; destroyed
##                   at 0 HP. May reveal a treasure chest behind it.
##   hidden_passage: invisible until a linked switch is activated or the
##                   player gets close; reveals a passage with loot inside.
##
## Linking: switches and doors/passages are linked via the `linked_id`
## property. A switch with linked_id "X" toggles all doors/passages with
## linked_id "X". The world generator assigns linked_ids when spawning.
##
## All colors use Godot 0-1 range.

extends StaticBody3D

class_name InteractiveObject

signal toggled(obj: InteractiveObject, new_state: bool)
signal destroyed(obj: InteractiveObject)

# ─── Export ──────────────────────────────────────────────────────────────────
@export var object_type: String = "switch"  # "switch", "door", "breakable_wall", "hidden_passage"
@export var linked_id: String = ""  # Links switches to doors/passages
@export var start_active: bool = false  # Initial toggle state (for doors: open/closed)

# ─── State ───────────────────────────────────────────────────────────────────
var _is_active: bool = false  # For switches: on/off. For doors: open/closed. For passages: revealed/hidden.
var _hp: int = 0
var _cooldown_timer: float = 0.0
var _time: float = 0.0
var _cached_player: Node3D = null
var _prompt_shown: bool = false
var _config: Dictionary = {}

# ─── Visual nodes ─────────────────────────────────────────────────────────────
var _body_mesh: MeshInstance3D
var _glow_mesh: MeshInstance3D
var _light: OmniLight3D
var _prompt_label: Label3D
var _material: StandardMaterial3D
var _collision_shape: CollisionShape3D

func _ready() -> void:
	add_to_group("interactive_object")
	_config = _lookup_config(object_type)
	_is_active = start_active
	if object_type == "breakable_wall":
		_hp = GameConstants.INTERACTIVE_BREAKABLE_HP
	_build_visuals()
	# Collision shape is provided by the scene.
	_collision_shape = get_node_or_null("CollisionShape3D")

func _lookup_config(type_name: String) -> Dictionary:
	for entry in GameConstants.INTERACTIVE_TYPES:
		if entry.get("type", "") == type_name:
			return entry
	return {}

func _build_visuals() -> void:
	var col: Color = _config.get("color", Color(0.6, 0.5, 0.4))
	var glow: Color = _config.get("glow_color", Color(0.8, 0.7, 0.5))
	var obj_scale: float = _config.get("scale", 1.0)

	_material = StandardMaterial3D.new()
	_material.albedo_color = col
	_material.emission_enabled = true
	_material.emission = glow * 0.3
	_material.emission_energy_multiplier = 0.8
	_material.rim_enabled = true
	_material.rim = 0.5

	_body_mesh = MeshInstance3D.new()
	_body_mesh.scale = Vector3.ONE * obj_scale
	_body_mesh.material_override = _material
	add_child(_body_mesh)
	_build_body_mesh()

	# Glow accent (small emissive sphere on top).
	_glow_mesh = MeshInstance3D.new()
	var glow_sphere := SphereMesh.new()
	glow_sphere.radius = 0.15
	glow_sphere.height = 0.3
	_glow_mesh.mesh = glow_sphere
	_glow_mesh.position = Vector3(0, obj_scale * 0.6, 0)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = glow
	glow_mat.emission_enabled = true
	glow_mat.emission = glow
	glow_mat.emission_energy_multiplier = 1.5
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mesh.material_override = glow_mat
	add_child(_glow_mesh)

	# Light.
	_light = OmniLight3D.new()
	_light.position = Vector3(0, obj_scale * 0.6, 0)
	_light.omni_range = 4.0
	_light.light_color = glow
	_light.light_energy = 0.6
	add_child(_light)

	# Prompt label for switches.
	_prompt_label = Label3D.new()
	_prompt_label.text = "Press T to activate"
	_prompt_label.position = Vector3(0, obj_scale * 1.2, 0)
	_prompt_label.font_size = 28
	_prompt_label.outline_size = 6
	_prompt_label.outline_modulate = Color(0, 0, 0, 0.8)
	_prompt_label.modulate = Color(1.0, 0.95, 0.4)
	_prompt_label.visible = false
	_prompt_label.no_depth_test = true
	add_child(_prompt_label)

	# Initial state setup.
	_apply_state_visual()

func _build_body_mesh() -> void:
	match object_type:
		"switch":
			# A short pedestal with a button on top.
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.3
			cyl.bottom_radius = 0.5
			cyl.height = 1.0
			_body_mesh.mesh = cyl
			_body_mesh.position = Vector3(0, 0.5, 0)
		"door":
			# A tall rectangular slab.
			var box := BoxMesh.new()
			box.size = Vector3(2.0, 3.0, 0.4)
			_body_mesh.mesh = box
			_body_mesh.position = Vector3(0, 1.5, 0)
		"breakable_wall":
			# A cracked wall slab.
			var box := BoxMesh.new()
			box.size = Vector3(2.5, 3.0, 0.6)
			_body_mesh.mesh = box
			_body_mesh.position = Vector3(0, 1.5, 0)
		"hidden_passage":
			# A narrow archway.
			var box := BoxMesh.new()
			box.size = Vector3(2.0, 3.0, 0.3)
			_body_mesh.mesh = box
			_body_mesh.position = Vector3(0, 1.5, 0)
		_:
			var box := BoxMesh.new()
			box.size = Vector3(1.0, 1.0, 1.0)
			_body_mesh.mesh = box

func _apply_state_visual() -> void:
	match object_type:
		"switch":
			# Active switch: glow brighter, change color slightly.
			if _material:
				_material.emission_energy_multiplier = 1.8 if _is_active else 0.8
			if _light:
				_light.light_energy = 1.2 if _is_active else 0.6
		"door":
			# Open door: lower into the ground and disable collision.
			var target_y: float = -3.0 if _is_active else 1.5
			var tween := create_tween()
			tween.tween_property(_body_mesh, "position:y", target_y,
				GameConstants.INTERACTIVE_DOOR_OPEN_TIME) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
			if _collision_shape:
				_collision_shape.disabled = _is_active
			if _light:
				_light.light_energy = 0.0 if _is_active else 0.6
		"hidden_passage":
			# Revealed passage: fade out the wall, disable collision.
			var target_alpha: float = 0.0 if _is_active else 1.0
			var tween := create_tween()
			tween.tween_property(_material, "albedo_color:a", target_alpha, 0.5) \
				.set_ease(Tween.EASE_IN_OUT)
			tween.parallel().tween_property(_material, "emission_energy_multiplier",
				0.0 if _is_active else 0.8, 0.5)
			if _collision_shape:
				_collision_shape.disabled = _is_active
			if _light:
				_light.light_energy = 0.0 if _is_active else 0.4
			_body_mesh.visible = not _is_active
		"breakable_wall":
			pass  # State driven by HP.

func _process(delta: float) -> void:
	_time += delta
	if _cooldown_timer > 0:
		_cooldown_timer -= delta
	# Show/hide the interact prompt for switches.
	if object_type == "switch":
		_update_prompt()
	# Pulse the glow for switches.
	if object_type == "switch" and _glow_mesh and _glow_mesh.material_override:
		var pulse: float = 0.6 + 0.4 * sin(_time * 3.0)
		_glow_mesh.material_override.emission_energy_multiplier = pulse * 1.5

func _update_prompt() -> void:
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	if _cached_player:
		var dist: float = global_position.distance_to(_cached_player.global_position)
		var in_range: bool = dist <= GameConstants.INTERACTIVE_INTERACT_RANGE
		if in_range and not _prompt_shown:
			_prompt_shown = true
			_prompt_label.visible = true
			_prompt_label.text = "Press T to %s" % ("deactivate" if _is_active else "activate")
			_prompt_label.scale = Vector3(0.001, 0.001, 0.001)
			var t := create_tween()
			t.tween_property(_prompt_label, "scale", Vector3.ONE, 0.2) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		elif not in_range and _prompt_shown:
			_prompt_shown = false
			_prompt_label.visible = false

# ─── Interaction ─────────────────────────────────────────────────────────────

func can_interact() -> bool:
	if object_type == "switch":
		return _prompt_shown and _cooldown_timer <= 0
	return false

func interact() -> void:
	if object_type != "switch":
		return
	if _cooldown_timer > 0:
		return
	_is_active = not _is_active
	_cooldown_timer = GameConstants.INTERACTIVE_SWITCH_COOLDOWN
	_apply_state_visual()
	# Toggle all linked doors and hidden passages.
	_toggle_linked()
	toggled.emit(self, _is_active)
	# Feedback: small camera shake + message.
	var cam: Node3D = GameManager.camera_rig
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.08)
	GameManager.add_message("🔘 Switch %s — %s" % [linked_id, "ON" if _is_active else "OFF"])

func _toggle_linked() -> void:
	if linked_id == "":
		return
	for obj in get_tree().get_nodes_in_group("interactive_object"):
		if not is_instance_valid(obj) or obj == self:
			continue
		if "linked_id" in obj and obj.linked_id == linked_id:
			if obj.object_type == "door" or obj.object_type == "hidden_passage":
				obj.set_state(_is_active)

# Called by linked switches to set the door/passage state.
func set_state(new_state: bool) -> void:
	if object_type != "door" and object_type != "hidden_passage":
		return
	_is_active = new_state
	_apply_state_visual()

# ─── Damage (for breakable walls) ─────────────────────────────────────────────

func take_damage(amount: int, _source_pos: Vector3 = Vector3.ZERO) -> void:
	if object_type != "breakable_wall":
		return
	_hp -= amount
	# Hit flash.
	if _material:
		_material.emission_energy_multiplier = 3.0
		var t := create_tween()
		t.tween_property(_material, "emission_energy_multiplier", 0.8, 0.2)
	# Camera shake feedback.
	var cam: Node3D = GameManager.camera_rig
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.05)
	if _hp <= 0:
		_destroy()

func _destroy() -> void:
	# Shatter effect: scale down + fade + particle burst.
	var tween := create_tween()
	tween.tween_property(_body_mesh, "scale", Vector3.ZERO, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(_material, "albedo_color:a", 0.0, 0.3)
	if _collision_shape:
		_collision_shape.disabled = true
	# Particle burst.
	var parent: Node = get_parent()
	if parent and ParticleEffects:
		ParticleEffects.spawn_death_poof(parent, global_position + Vector3(0, 1.5, 0),
			_config.get("color", Color(0.5, 0.45, 0.4)), 1.2)
	# Camera shake.
	var cam: Node3D = GameManager.camera_rig
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.15)
	GameManager.add_message("💥 Wall shattered!")
	destroyed.emit(self)
	tween.tween_callback(queue_free)

# Called by the player's dash to damage breakable walls on contact.
func dash_hit() -> void:
	if object_type == "breakable_wall":
		take_damage(GameConstants.INTERACTIVE_BREAKABLE_DASH_DAMAGE)