## Zorp Wiggles — Dialogue NPC (Phase 26: World Life)
## A friendly NPC the player can talk to by pressing the interact key (T).
## Three archetypes: villager, elder, and ancient hologram. Each has a pool
## of dialogue lines (intro lines for the first meeting, repeat lines after).
## Completing a dialogue grants a small XP reward. Dialogue is shown via the
## DialoguePanel (a CanvasLayer HUD element).
##
## All colors use Godot 0-1 range.

extends CharacterBody3D

signal dialogue_started(npc: Node)
signal dialogue_ended(npc: Node)

# ─── Export ──────────────────────────────────────────────────────────────────
@export var archetype: String = "villager"  # "villager", "elder", "hologram"
@export var npc_name: String = ""  # Auto-picked from name pool if empty

# ─── State ───────────────────────────────────────────────────────────────────
var _home: Vector3 = Vector3.ZERO
var _wander_dir: Vector3 = Vector3.ZERO
var _wander_timer: float = 0.0
var _time: float = 0.0
var _has_met: bool = false  # True after the first dialogue
var _cached_player: Node3D = null
var _prompt_shown: bool = false
var _config: Dictionary = {}
var _is_talking: bool = false

# ─── Child nodes (built in _ready) ───────────────────────────────────────────
var _body_mesh: MeshInstance3D
var _hat_mesh: MeshInstance3D
var _eye_l: MeshInstance3D
var _eye_r: MeshInstance3D
var _glow_light: OmniLight3D
var _prompt_label: Label3D  # "Press T to talk" floating prompt
var _material: StandardMaterial3D

func _ready() -> void:
	add_to_group("dialogue_npc")
	add_to_group("non_hostile")
	# Look up the archetype config.
	_config = _pick_archetype_config(archetype)
	if npc_name == "":
		var pool: Array = _config.get("name_pool", ["Unknown"])
		npc_name = pool[randi() % pool.size()]
	_wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	_wander_timer = randf_range(3, 6)
	_home = global_position
	_build_visuals()
	call_deferred("_update_home")

func _update_home() -> void:
	_home = global_position

func _pick_archetype_config(a: String) -> Dictionary:
	for entry in GameConstants.DIALOGUE_NPC_TYPES:
		if entry.get("archetype", "") == a:
			return entry
	# Fallback to villager.
	return GameConstants.DIALOGUE_NPC_TYPES[0]

func _build_visuals() -> void:
	var body_color: Color = _config.get("color", Color(0.7, 0.85, 0.5))
	var hat_color: Color = _config.get("hat_color", Color(0.5, 0.7, 0.3))
	var npc_scale: float = _config.get("scale", 1.0)

	# Body — sphere, archetype-colored, emissive for visibility in dark biomes.
	_body_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.6
	_body_mesh.mesh = sphere
	_body_mesh.scale = Vector3.ONE * npc_scale
	_material = StandardMaterial3D.new()
	_material.albedo_color = body_color
	_material.emission_enabled = true
	_material.emission = body_color * 0.25
	_material.emission_energy_multiplier = 1.0
	_material.rim_enabled = true
	_material.rim = 0.6
	_material.rim_tint = 0.8
	_body_mesh.material_override = _material
	add_child(_body_mesh)

	# Hat — small box on top (archetype-tinted).
	_hat_mesh = MeshInstance3D.new()
	var hat_box := BoxMesh.new()
	hat_box.size = Vector3(0.8, 0.4, 0.8)
	_hat_mesh.mesh = hat_box
	_hat_mesh.position = Vector3(0, 0.8 * npc_scale, 0)
	_hat_mesh.scale = Vector3.ONE * npc_scale
	var hat_mat := StandardMaterial3D.new()
	hat_mat.albedo_color = hat_color
	hat_mat.emission_enabled = true
	hat_mat.emission = hat_color * 0.2
	_hat_mesh.material_override = hat_mat
	add_child(_hat_mesh)

	# Two small cyan eyes.
	_eye_l = _create_eye(Vector3(-0.22 * npc_scale, 0.2 * npc_scale, -0.6 * npc_scale))
	_eye_r = _create_eye(Vector3(0.22 * npc_scale, 0.2 * npc_scale, -0.6 * npc_scale))
	add_child(_eye_l)
	add_child(_eye_r)

	# Soft glow light.
	_glow_light = OmniLight3D.new()
	_glow_light.position = Vector3(0, 0.5, 0)
	_glow_light.omni_range = 5.0
	_glow_light.light_color = body_color
	_glow_light.light_energy = 0.6
	add_child(_glow_light)

	# Floating "Press T to talk" prompt (hidden until player is near).
	_prompt_label = Label3D.new()
	_prompt_label.text = "Press T to talk"
	_prompt_label.position = Vector3(0, 2.2 * npc_scale, 0)
	_prompt_label.font_size = 32
	_prompt_label.outline_size = 8
	_prompt_label.outline_modulate = Color(0, 0, 0, 0.8)
	_prompt_label.modulate = Color(1.0, 0.95, 0.4)
	_prompt_label.visible = false
	_prompt_label.no_depth_test = true
	add_child(_prompt_label)

func _create_eye(pos: Vector3) -> MeshInstance3D:
	var eye := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.12
	m.height = 0.24
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
	if _is_talking:
		# Stop wandering while talking.
		velocity = velocity.move_toward(Vector3.ZERO, delta * 5.0)
		move_and_slide()
		return
	_time += delta
	# Gentle wander within home radius.
	_wander_timer -= delta
	if _wander_timer <= 0:
		_wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		_wander_timer = randf_range(3, 6)
	var to_home: Vector3 = global_position - _home
	if to_home.length() > 12.0:
		_wander_dir = -to_home.normalized()
	velocity = _wander_dir * 1.2
	move_and_slide()
	# Bob the body slightly for liveliness.
	if _body_mesh:
		_body_mesh.position.y = 0.05 * sin(_time * 3.0)

func _process(_delta: float) -> void:
	if _is_talking:
		return
	# Update the talk prompt based on player proximity.
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	if _cached_player:
		var dist: float = global_position.distance_to(_cached_player.global_position)
		var in_range: bool = dist <= GameConstants.DIALOGUE_INTERACT_RANGE
		if in_range and not _prompt_shown:
			_prompt_shown = true
			_prompt_label.visible = true
			# Pop-in animation.
			_prompt_label.scale = Vector3(0.001, 0.001, 0.001)
			var t := create_tween()
			t.tween_property(_prompt_label, "scale", Vector3.ONE, 0.25) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		elif not in_range and _prompt_shown:
			_prompt_shown = false
			_prompt_label.visible = false

# ─── Dialogue interaction ────────────────────────────────────────────────────

func can_interact() -> bool:
	return _prompt_shown and not _is_talking

func start_dialogue() -> void:
	if _is_talking:
		return
	_is_talking = true
	_prompt_label.visible = false
	# Pick the dialogue topic pool.
	var topic_key: String = archetype + ("_intro" if not _has_met else "_repeat")
	var lines: Array = GameConstants.DIALOGUE_LINES.get(topic_key, ["..."])
	# Show the dialogue panel via the DialoguePanel autoload if present.
	if DialoguePanel:
		DialoguePanel.show_dialogue(npc_name, lines, self)
	dialogue_started.emit(self)

func end_dialogue() -> void:
	_is_talking = false
	if not _has_met:
		_has_met = true
		# First-meeting XP reward.
		GameManager.gain_xp(GameConstants.DIALOGUE_XP_REWARD)
		GameManager.add_message("💬 %s: \"Farewell, traveler.\"" % npc_name)
	dialogue_ended.emit(self)

# Called by the player's interact input when nearby.
func interact() -> void:
	start_dialogue()