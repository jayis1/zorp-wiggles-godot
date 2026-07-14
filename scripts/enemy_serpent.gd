## Zorp Wiggles — Plasma Serpent
## Segmented snake enemy. Body segments follow the head in a trail.
## On death, segments scatter into independent mini-enemies.
## Ported from Plasma Serpent logic in Ursina game.py.

extends EnemyBase

class_name EnemySerpent

# ─── Segment Data ─────────────────────────────────────────────────────────────
var segment_nodes: Array[MeshInstance3D] = []
var segment_positions: Array[Vector3] = []
var segment_colors: Array[Color] = [
	Color(0.0, 220.0 / 255.0, 180.0 / 255.0),
	Color(0.0, 200.0 / 255.0, 160.0 / 255.0),
	Color(0.0, 180.0 / 255.0, 140.0 / 255.0),
]

func _ready() -> void:
	enemy_name = "Plasma Serpent"
	enemy_type = GameConstants.EnemyType.SERPENT
	max_hp = 120
	speed = 3.5
	damage = 20
	base_scale = 1.0
	detect_range = 34.0
	xp_reward = 60
	score_reward = 200
	base_color = Color(0.0, 1.0, 200.0 / 255.0)
	super._ready()

	# Initialize segment position history
	for i in range(GameConstants.PLASMA_SERPENT_SEGMENTS + 1):
		segment_positions.append(global_position)

	# Create visual segment meshes
	for i in range(GameConstants.PLASMA_SERPENT_SEGMENTS):
		var seg_scale: float = max(0.3, base_scale * 0.8 - i * 0.12)
		var seg_mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = seg_scale * 0.5
		sphere.height = seg_scale
		seg_mesh.mesh = sphere

		var seg_mat := StandardMaterial3D.new()
		seg_mat.albedo_color = segment_colors[i % segment_colors.size()]
		seg_mat.emission_enabled = true
		seg_mat.emission = seg_mat.albedo_color * 0.15
		seg_mesh.material_override = seg_mat

		add_child(seg_mesh)
		seg_mesh.global_position = global_position
		segment_nodes.append(seg_mesh)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_dead or GameManager.is_paused:
		return
	if spawn_grace_timer > 0:
		return
	_update_segments(delta)

func _update_segments(delta: float) -> void:
	# Update position history — head position recorded each frame
	segment_positions[0] = global_position

	# Each segment follows the one ahead of it at a fixed distance
	for i in range(GameConstants.PLASMA_SERPENT_SEGMENTS):
		var target_pos: Vector3 = segment_positions[i]
		var current_pos: Vector3 = segment_positions[i + 1]
		var diff: Vector3 = target_pos - current_pos
		var dist: float = diff.length()
		if dist > GameConstants.PLASMA_SERPENT_SEGMENT_SPACING:
			var move_amount: float = dist - GameConstants.PLASMA_SERPENT_SEGMENT_SPACING
			segment_positions[i + 1] = current_pos + diff.normalized() * move_amount

		# Update visual position
		if i < segment_nodes.size():
			segment_nodes[i].global_position = segment_positions[i + 1]

func _die() -> void:
	# Scatter segments into mini-enemies before death
	for i in range(segment_nodes.size()):
		var seg := segment_nodes[i]
		if is_instance_valid(seg):
			# Create a mini blob at the segment position
			var mini_blob_scene: PackedScene = load("res://scenes/entities/enemy_blob.tscn")
			if mini_blob_scene:
				var mini_blob: CharacterBody3D = mini_blob_scene.instantiate()
				# Configure BEFORE adding to scene tree so _ready() picks up overrides
				mini_blob.set("max_hp", GameConstants.PLASMA_SERPENT_SCATTER_HP)
				mini_blob.set("hp", GameConstants.PLASMA_SERPENT_SCATTER_HP)
				mini_blob.set("damage", GameConstants.PLASMA_SERPENT_SCATTER_DAMAGE)
				mini_blob.set("speed", GameConstants.PLASMA_SERPENT_SCATTER_SPEED)
				mini_blob.set("base_scale", 0.3)
				mini_blob.set("enemy_name", "Serpent Segment")
				mini_blob.set("xp_reward", 5)
				mini_blob.set("score_reward", 25)
				get_parent().add_child(mini_blob)
				mini_blob.global_position = seg.global_position
				seg.queue_free()

	segment_nodes.clear()
	super._die()