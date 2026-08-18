## Zorp Wiggles — Plasma Serpent
## Segmented snake enemy. Body segments follow the head in a trail.
## On death, segments scatter into independent mini-enemies.
## Ported from Plasma Serpent logic in Ursina game.py.

extends EnemyBase

class_name EnemySerpent

# class_name is REQUIRED for Godot 4.4 class resolution. Without it, the
# script is not registered in the global class registry and `extends
# EnemyBase` fails to resolve when the script is loaded via preload() in
# autoload scripts (BossArena, GameModeManager, EndgameManager) before
# enemy_base.gd has been loaded through the resource system. The scenes
# reference the script by path, so the class_name is not strictly needed
# for scene instantiation, but it IS needed for the extends to resolve.

# ─── Segment Data ─────────────────────────────────────────────────────────────
var segment_nodes: Array[MeshInstance3D] = []
var segment_positions: Array[Vector3] = []
static var segment_colors: Array[Color] = [
	Color(0.0, 220.0 / 255.0, 180.0 / 255.0),
	Color(0.0, 200.0 / 255.0, 160.0 / 255.0),
	Color(0.0, 180.0 / 255.0, 140.0 / 255.0),
]

# Preloaded mini-blob scene — shared across all scatter-on-death spawns.
const MINI_BLOB_SCENE := preload("res://scenes/entities/enemy_blob.tscn")

# Shared segment materials — only 3 unique colors, so cache them statically
# to eliminate per-segment StandardMaterial3D allocation on every serpent spawn.
static var _shared_seg_mats: Array[StandardMaterial3D] = []

# Segment visual smoothing rate — higher = snappier follow, lower = more lag.
# 12.0 produces a smooth, flowing trailing motion during turns.
const SERPENT_SEG_SMOOTH: float = 12.0

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

	# Create visual segment meshes — use shared materials to avoid
	# per-segment StandardMaterial3D allocation. Only 3 unique colors.
	for i in range(GameConstants.PLASMA_SERPENT_SEGMENTS):
		var seg_scale: float = max(0.3, base_scale * 0.8 - i * 0.12)
		var seg_mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = seg_scale * 0.5
		sphere.height = seg_scale
		seg_mesh.mesh = sphere
		seg_mesh.material_override = _get_shared_seg_material(i)

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

		# Update visual position — lerp toward the target position for
		# smoother trailing. Without lerp, segments snap to the exact
		# calculated position each frame, producing a rigid "rig on rails"
		# look during sharp turns. The lerp adds a frame-rate-independent
		# smoothing that makes the body flow like a real serpent.
		if i < segment_nodes.size():
			var visual_target: Vector3 = segment_positions[i + 1]
			var lerp_weight: float = 1.0 - exp(-SERPENT_SEG_SMOOTH * delta)
			segment_nodes[i].global_position = segment_nodes[i].global_position.lerp(visual_target, lerp_weight)

func _die() -> void:
	# Plasma scatter burst — the serpent is the only standard enemy with no
	# thematic death particles. Every other enemy type has a bespoke burst
	# (Crystal Wraith → shatter, Plasma Stalker → plasma burst, Time Warden
	# → temporal burst, etc.) but the serpent relied solely on the generic
	# base-class death poof. A plasma-themed explosion in the serpent's
	# signature cyan-green brings it in line with the rest of the roster.
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		base_color, 24, 0.5)
	# ── Enhancement Pack 75: Serpent death SFX — a plasma scatter pop conveying
	#    plasma energy dispersing as the serpent's body scatters into segments.
	#    Distinct from the generic SFX_ENEMY_DEATH so the serpent's scatter
	#    death has its own sonic identity.
	AudioManager.play_sfx(AudioManager.SFX_SERPENT_DEATH)
	# Scatter segments into mini-enemies before death
	for i in range(segment_nodes.size()):
		var seg := segment_nodes[i]
		if is_instance_valid(seg):
			# Create a mini blob at the segment position — preloaded const
			# so the resource loader isn't hit per-segment on death.
			var mini_blob: CharacterBody3D = MINI_BLOB_SCENE.instantiate()
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
			# Track mini-blob so it is cleaned up on restart and counted by the spawner
			GameManager.enemies.append(mini_blob)
			seg.queue_free()

	segment_nodes.clear()
	super._die()

# ─── Shared segment material helper ──────────────────────────────────────────
# Returns the shared StandardMaterial3D for segment index i, creating the
# 3 cached materials on first call. All serpents share the same 3 materials.
static func _get_shared_seg_material(i: int) -> StandardMaterial3D:
	if _shared_seg_mats.is_empty():
		for c in segment_colors:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = c
			mat.emission_enabled = true
			mat.emission = c * 0.15
			_shared_seg_mats.append(mat)
	return _shared_seg_mats[i % _shared_seg_mats.size()]