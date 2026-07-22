## Zorp Wiggles — Lore Stone (Phase 26: World Life)
## A scattered ancient relic that reveals a fragment of game lore when the
## player approaches. Reading grants a small XP reward. Each stone picks a
## lore fragment from the LORE_FRAGMENTS list in game_constants.gd. Stones
## disappear after being read (so the player can track which ones they've
## found). Future save/load (Phase 31) will persist read state across runs.
##
## All colors use Godot 0-1 range.

extends Area3D

signal lore_read(stone: Node, fragment_index: int, text: String)

# ─── Export ──────────────────────────────────────────────────────────────────
@export var fragment_index: int = -1  # Index into LORE_FRAGMENTS; -1 = auto-pick

# ─── State ───────────────────────────────────────────────────────────────────
var _read: bool = false
var _time: float = 0.0
var _glow_phase: float = 0.0
var _cached_player: Node3D = null
var _prompt_shown: bool = false

# ─── Child nodes (built in _ready) ───────────────────────────────────────────
var _pillar: MeshInstance3D
var _cap: MeshInstance3D
var _ground_glow: MeshInstance3D
var _light: OmniLight3D
var _rune: MeshInstance3D  # Glowing rune plane on the front face

func _ready() -> void:
	add_to_group("lore_stone")
	_glow_phase = randf() * TAU
	# Auto-pick a fragment if none assigned by the spawner.
	if fragment_index < 0:
		fragment_index = randi() % GameConstants.LORE_FRAGMENTS.size()
	_build_visuals()
	# Collision shape is provided by the scene (LoreStoneCollision).
	body_entered.connect(_on_body_entered)

func _build_visuals() -> void:
	# Stone pillar — tall thin box, ancient purple-grey.
	_pillar = _create_box(
		Vector3(0, GameConstants.LORE_STONE_HEIGHT * 0.5, 0),
		Vector3(0.7, GameConstants.LORE_STONE_HEIGHT, 0.7),
		GameConstants.LORE_STONE_COLOR
	)
	add_child(_pillar)

	# Cap — small rounded top piece.
	_cap = _create_sphere(
		Vector3(0, GameConstants.LORE_STONE_HEIGHT + 0.2, 0),
		0.45,
		GameConstants.LORE_STONE_COLOR
	)
	add_child(_cap)

	# Glowing rune plane on the front face — a thin emissive quad that pulses.
	_rune = _create_rune_quad(
		Vector3(0, GameConstants.LORE_STONE_HEIGHT * 0.55, -0.36),
		Vector2(0.45, 0.8),
		GameConstants.LORE_STONE_GLOW_COLOR
	)
	add_child(_rune)

	# Ground glow disc — soft purple halo on the ground.
	_ground_glow = _create_ground_disc(
		Vector3(0, 0.05, 0),
		2.5,
		Color(
			GameConstants.LORE_STONE_GLOW_COLOR.r,
			GameConstants.LORE_STONE_GLOW_COLOR.g,
			GameConstants.LORE_STONE_GLOW_COLOR.b,
			0.15
		)
	)
	add_child(_ground_glow)

	# OmniLight for ambient glow.
	_light = OmniLight3D.new()
	_light.position = Vector3(0, GameConstants.LORE_STONE_HEIGHT * 0.6, 0)
	_light.omni_range = 6.0
	_light.light_color = GameConstants.LORE_STONE_GLOW_COLOR
	_light.light_energy = 0.8
	add_child(_light)

func _process(delta: float) -> void:
	if _read:
		return
	_time += delta
	# Pulse the rune emission + light for a "calling" effect.
	var pulse: float = 0.6 + 0.4 * sin(_time * 2.0 + _glow_phase)
	if _rune and _rune.material_override:
		_rune.material_override.emission_energy_multiplier = pulse * 2.0
	if _light:
		_light.light_energy = 0.6 + 0.4 * pulse
	# Rotate the cap slowly for ambient motion.
	if _cap:
		_cap.rotate_y(delta * 0.5)

	# Check player proximity for the read prompt.
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	if _cached_player:
		var dist: float = global_position.distance_to(_cached_player.global_position)
		if dist <= GameConstants.LORE_STONE_READ_RANGE and not _prompt_shown:
			_prompt_shown = true
			GameManager.add_message("📜 Lore Stone nearby — approach to read")
		elif dist > GameConstants.LORE_STONE_READ_RANGE + 2.0 and _prompt_shown:
			_prompt_shown = false

func _on_body_entered(body: Node3D) -> void:
	if _read:
		return
	if not body.is_in_group("player"):
		return
	_read_lore()

func _read_lore() -> void:
	_read = true
	var text: String = GameConstants.LORE_FRAGMENTS[fragment_index % GameConstants.LORE_FRAGMENTS.size()]
	# Display the lore fragment as a HUD message.
	GameManager.add_message("📜 LORE: %s" % text)
	# Audio feedback — deep mystical chime.
	AudioManager.play_sfx(AudioManager.SFX_LORE)
	# XP reward.
	GameManager.gain_xp(GameConstants.LORE_STONE_XP_REWARD)
	# Camera shake for feedback.
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.08)
	# Particle burst (purple) — reuse levelup burst as a soft sparkle.
	var parent: Node = get_parent()
	if parent and parent.has_node("ParticleEffects") == false:
		# ParticleEffects is an autoload; spawn at our position via the parent.
		if ParticleEffects:
			ParticleEffects.spawn_levelup_burst(parent, global_position)
	# Fade out + shrink animation, then queue_free.
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.3, 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(self, "scale", Vector3.ZERO, 0.4) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(self, "global_position:y", global_position.y + 1.5, 0.5) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)
	# Emit signal for any listeners (future achievement/stat tracking).
	lore_read.emit(self, fragment_index, text)
	# Phase 25: Statistics tracking — count lore stones read.
	if Statistics:
		Statistics.record_lore_stone_read()

# ─── Mesh helpers ────────────────────────────────────────────────────────────

func _create_box(pos: Vector3, sz: Vector3, col: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = sz
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi

func _create_sphere(pos: Vector3, radius: float, col: Color) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi

func _create_rune_quad(pos: Vector3, sz: Vector2, col: Color) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = sz
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = pos
	# Face the quad forward (-Z). PlaneMesh faces +Y by default, so rotate.
	mi.rotation_degrees.x = 90.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi

func _create_ground_disc(pos: Vector3, sz: float, col: Color) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(sz, sz)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi