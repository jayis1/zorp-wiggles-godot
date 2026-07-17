## Zorp Wiggles — Animation System (Phase 12)
## Manages AnimationPlayer-based animations for the player and enemies.
## Since the game uses procedural meshes (no skeletal rigs), animations are
## created programmatically as Animation resources with property tracks.
##
## This system provides:
## - Player idle bob (subtle breathing float via AnimationPlayer)
## - Dash squash-and-stretch (compress → launch → extend)
## - Attack windup animation (anticipation → strike → recovery)
## - Hit reaction animation (stagger + flash)
## - Enemy walk cycle (bob + sway per type)
## - Enemy death animation (dramatic collapse)
## - Collectible spawn animation (bounce in from below)
## - Animation event callbacks for syncing sound/particles

extends Node

class_name AnimationSystem

# ─── Animation Library ────────────────────────────────────────────────────────
# Animation names (used as keys in the AnimationLibrary)
const ANIM_PLAYER_IDLE := "player_idle"
const ANIM_PLAYER_DASH_SQUASH := "player_dash_squash"
const ANIM_PLAYER_SHOOT_PULSE := "player_shoot_pulse"
const ANIM_ENEMY_WALK := "enemy_walk"
const ANIM_ENEMY_DEATH := "enemy_death"
const ANIM_ENEMY_HIT_REACT := "enemy_hit_react"
const ANIM_ENEMY_WINDUP := "enemy_windup"
const ANIM_COLLECTIBLE_SPAWN := "collectible_spawn"
const ANIM_COLLECTIBLE_BOB := "collectible_bob"

# ─── Player Animations ────────────────────────────────────────────────────────

## Create and register player animations on the given AnimationPlayer.
## Call this from Player._ready() after the AnimationPlayer is added.
static func setup_player_animations(anim_player: AnimationPlayer) -> void:
	if not anim_player:
		return

	var lib := AnimationLibrary.new()

	# Idle bob animation — subtle vertical float + emission pulse (2s loop)
	var idle := Animation.new()
	idle.length = 2.0
	idle.loop_mode = Animation.LOOP_LINEAR
	# Position track (mesh Y bob)
	var pos_track := idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(pos_track, "BodyMesh:position")
	var pos_interpolation := Animation.INTERPOLATION_LINEAR
	idle.track_set_interpolation_type(pos_track, pos_interpolation)
	# Keyframes: y = sin(t * π) * 0.04 over 2 seconds
	for i in range(9):
		var t: float = i * 0.25
		var y: float = sin(t * PI) * 0.04
		idle.track_insert_key(pos_track, t, Vector3(0, y, 0))
	# Emission track
	var em_track := idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(em_track, "BodyMesh:surface_material_override_0:emission_energy_multiplier")
	idle.track_set_interpolation_type(em_track, Animation.INTERPOLATION_LINEAR)
	for i in range(5):
		var t: float = i * 0.5
		var val: float = 0.8 + 0.5 * (0.5 + 0.5 * sin(t * PI))
		idle.track_insert_key(em_track, t, val)
	lib.add_animation(ANIM_PLAYER_IDLE, idle)

	# Dash squash-and-stretch (0.4s, one-shot)
	var dash := Animation.new()
	dash.length = 0.4
	var dash_scale_track := dash.add_track(Animation.TYPE_VALUE)
	dash.track_set_path(dash_scale_track, "BodyMesh:scale")
	dash.track_set_interpolation_type(dash_scale_track, Animation.INTERPOLATION_CUBIC)
	# Compress at start, bounce back
	dash.track_insert_key(dash_scale_track, 0.0, Vector3(1.4, 0.6, 1.4))
	dash.track_insert_key(dash_scale_track, 0.15, Vector3(0.85, 1.25, 0.85))
	dash.track_insert_key(dash_scale_track, 0.4, Vector3.ONE)
	lib.add_animation(ANIM_PLAYER_DASH_SQUASH, dash)

	# Shoot pulse (0.15s, one-shot)
	var shoot := Animation.new()
	shoot.length = 0.15
	var shoot_track := shoot.add_track(Animation.TYPE_VALUE)
	shoot.track_set_path(shoot_track, "BodyMesh:scale")
	shoot.track_set_interpolation_type(shoot_track, Animation.INTERPOLATION_CUBIC)
	shoot.track_insert_key(shoot_track, 0.0, Vector3(1.12, 1.12, 1.12))
	shoot.track_insert_key(shoot_track, 0.15, Vector3.ONE)
	lib.add_animation(ANIM_PLAYER_SHOOT_PULSE, shoot)

	anim_player.add_animation_library("", lib)


# ─── Enemy Animations ─────────────────────────────────────────────────────────

## Create and register enemy animations on the given AnimationPlayer.
## Call this from EnemyBase._ready() after the AnimationPlayer is added.
static func setup_enemy_animations(anim_player: AnimationPlayer, base_scale: float = 1.0) -> void:
	if not anim_player:
		return

	var lib := AnimationLibrary.new()

	# Walk cycle — bob + sway (1s loop, scales with enemy size)
	var walk := Animation.new()
	walk.length = 1.0
	walk.loop_mode = Animation.LOOP_LINEAR
	var walk_pos_track := walk.add_track(Animation.TYPE_VALUE)
	walk.track_set_path(walk_pos_track, "BodyMesh:position")
	walk.track_set_interpolation_type(walk_pos_track, Animation.INTERPOLATION_LINEAR)
	var bob_amp: float = 0.08 * base_scale
	for i in range(9):
		var t: float = i * 0.125
		var y: float = sin(t * TAU) * bob_amp
		walk.track_insert_key(walk_pos_track, t, Vector3(0, 0.5 + y, 0))
	# Slight X sway
	var walk_rot_track := walk.add_track(Animation.TYPE_ROTATION_3D)
	walk.track_set_path(walk_rot_track, "BodyMesh:rotation")
	walk.track_set_interpolation_type(walk_rot_track, Animation.INTERPOLATION_LINEAR)
	for i in range(5):
		var t: float = i * 0.25
		var angle: float = sin(t * TAU) * 0.1
		walk.track_insert_key(walk_rot_track, t, Quaternion.from_euler(Vector3(0, 0, angle)))
	lib.add_animation(ANIM_ENEMY_WALK, walk)

	# Death animation — collapse + spin (0.5s, one-shot)
	var death := Animation.new()
	death.length = 0.5
	var death_scale_track := death.add_track(Animation.TYPE_VALUE)
	death.track_set_path(death_scale_track, "scale")
	death.track_set_interpolation_type(death_scale_track, Animation.INTERPOLATION_CUBIC)
	death.track_insert_key(death_scale_track, 0.0, Vector3.ONE * base_scale)
	death.track_insert_key(death_scale_track, 0.5, Vector3.ZERO)
	var death_rot_track := death.add_track(Animation.TYPE_ROTATION_3D)
	death.track_set_path(death_rot_track, "rotation")
	death.track_set_interpolation_type(death_rot_track, Animation.INTERPOLATION_LINEAR)
	death.track_insert_key(death_rot_track, 0.0, Quaternion.from_euler(Vector3.ZERO))
	death.track_insert_key(death_rot_track, 0.5, Quaternion.from_euler(Vector3(0, PI, 0)))
	lib.add_animation(ANIM_ENEMY_DEATH, death)

	# Hit reaction — stagger back + flash (0.2s, one-shot)
	var hit := Animation.new()
	hit.length = 0.2
	var hit_pos_track := hit.add_track(Animation.TYPE_POSITION_3D)
	hit.track_set_path(hit_pos_track, "BodyMesh:position")
	hit.track_set_interpolation_type(hit_pos_track, Animation.INTERPOLATION_CUBIC)
	hit.track_insert_key(hit_pos_track, 0.0, Vector3(0, 0.5, 0))
	hit.track_insert_key(hit_pos_track, 0.1, Vector3(0, 0.7, 0.2))
	hit.track_insert_key(hit_pos_track, 0.2, Vector3(0, 0.5, 0))
	lib.add_animation(ANIM_ENEMY_HIT_REACT, hit)

	# Attack windup — squash anticipation (0.25s, one-shot)
	var windup := Animation.new()
	windup.length = 0.25
	var windup_track := windup.add_track(Animation.TYPE_VALUE)
	windup.track_set_path(windup_track, "scale")
	windup.track_set_interpolation_type(windup_track, Animation.INTERPOLATION_CUBIC)
	windup.track_insert_key(windup_track, 0.0, Vector3.ONE * base_scale)
	windup.track_insert_key(windup_track, 0.25, Vector3.ONE * base_scale * 0.85)
	lib.add_animation(ANIM_ENEMY_WINDUP, windup)

	anim_player.add_animation_library("", lib)


# ─── Collectible Animations ───────────────────────────────────────────────────

## Create and register collectible animations.
static func setup_collectible_animations(anim_player: AnimationPlayer) -> void:
	if not anim_player:
		return

	var lib := AnimationLibrary.new()

	# Spawn animation — bounce in from below (0.6s, one-shot)
	var spawn := Animation.new()
	spawn.length = 0.6
	var spawn_pos_track := spawn.add_track(Animation.TYPE_POSITION_3D)
	spawn.track_set_path(spawn_pos_track, "MeshInstance3D:position")
	spawn.track_set_interpolation_type(spawn_pos_track, Animation.INTERPOLATION_CUBIC)
	spawn.track_insert_key(spawn_pos_track, 0.0, Vector3(0, -2, 0))
	spawn.track_insert_key(spawn_pos_track, 0.6, Vector3(0, 0.5, 0))
	var spawn_scale_track := spawn.add_track(Animation.TYPE_VALUE)
	spawn.track_set_path(spawn_scale_track, "MeshInstance3D:scale")
	spawn.track_set_interpolation_type(spawn_scale_track, Animation.INTERPOLATION_CUBIC)
	spawn.track_insert_key(spawn_scale_track, 0.0, Vector3.ZERO)
	spawn.track_insert_key(spawn_scale_track, 0.6, Vector3.ONE)
	lib.add_animation(ANIM_COLLECTIBLE_SPAWN, spawn)

	# Idle bob — continuous float + spin (2s loop)
	var bob := Animation.new()
	bob.length = 2.0
	bob.loop_mode = Animation.LOOP_LINEAR
	var bob_pos_track := bob.add_track(Animation.TYPE_VALUE)
	bob.track_set_path(bob_pos_track, "MeshInstance3D:position")
	bob.track_set_interpolation_type(bob_pos_track, Animation.INTERPOLATION_LINEAR)
	for i in range(9):
		var t: float = i * 0.25
		var y: float = 0.5 + sin(t * PI) * 0.15
		bob.track_insert_key(bob_pos_track, t, Vector3(0, y, 0))
	var bob_rot_track := bob.add_track(Animation.TYPE_VALUE)
	bob.track_set_path(bob_rot_track, "MeshInstance3D:rotation:y")
	bob.track_set_interpolation_type(bob_rot_track, Animation.INTERPOLATION_LINEAR)
	bob.track_insert_key(bob_rot_track, 0.0, 0.0)
	bob.track_insert_key(bob_rot_track, 2.0, TAU)
	lib.add_animation(ANIM_COLLECTIBLE_BOB, bob)

	anim_player.add_animation_library("", lib)


# ─── Helper: Create AnimationPlayer ───────────────────────────────────────────

## Create and add an AnimationPlayer to a node. Returns the player.
static func create_anim_player(node: Node) -> AnimationPlayer:
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	node.add_child(player)
	return player