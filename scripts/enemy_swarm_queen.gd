## Zorp Wiggles — Swarm Queen (Phase 23: New Enemy Type)
## Continuously spawns Swarm Mites from her body. The mites stream out and rush
## the player. The Queen herself is slow and tanky — she must be killed to stop
## the spawn. High HP, slow speed, high reward. Mites spawn every few seconds in
## small batches (1-3). The Queen will not exceed the global enemy cap or her
## own concurrent-mite cap.
##
## Behavior: Slow chase toward the player. Spawns mites on a timer (3-5s) in
## batches of 1-3. The mites appear around the queen in a small radius and
## immediately path toward the player. The queen herself is a low-damage melee
## threat — the danger is the mite stream. High HP makes her a priority target
## (kill her fast or be overwhelmed).

extends EnemyBase

class_name EnemySwarmQueen

# ─── Spawn State ──────────────────────────────────────────────────────────────
var _spawn_timer: float = 2.0  # Initial delay before first mite batch
var _spawned_mites: Array[CharacterBody3D] = []  # Track our mites so we can cap them

# Reuse the Swarm Mite scene for spawned mites
const MITE_SCENE := preload("res://scenes/entities/enemy_swarm_mite.tscn")

func _ready() -> void:
	enemy_name = "Swarm Queen"
	enemy_type = GameConstants.EnemyType.SWARM_QUEEN
	max_hp = GameConstants.SWARM_QUEEN_HP
	speed = GameConstants.SWARM_QUEEN_SPEED
	damage = GameConstants.SWARM_QUEEN_DAMAGE
	base_scale = GameConstants.SWARM_QUEEN_SCALE
	detect_range = GameConstants.SWARM_QUEEN_DETECT_RANGE
	attack_range = GameConstants.SWARM_QUEEN_ATTACK_RANGE
	attack_cooldown = GameConstants.SWARM_QUEEN_ATTACK_COOLDOWN
	xp_reward = GameConstants.SWARM_QUEEN_XP
	score_reward = GameConstants.SWARM_QUEEN_SCORE
	base_color = GameConstants.SWARM_QUEEN_COLOR
	# Smart AI disabled — the queen is a slow simple chaser. Her threat is the
	# mite stream, not her movement. Disabling smart AI makes her cheaper.
	use_smart_ai = false
	super._ready()

	# Queen material — strong emission + rim for a "regal" glowing look
	if _material:
		_material.emission = base_color * 0.4
		_material.emission_energy_multiplier = 1.5
		_material.rim = 1.0
		_material.rim_tint = 0.8
		# Slightly metallic for a chitinous "armored" feel
		_material.metallic = 0.3
		_material.roughness = 0.4

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_dead or GameManager.is_paused or spawn_grace_timer > 0:
		return
	# Tick the mite spawn timer
	_spawn_timer -= delta * _time_scale
	if _spawn_timer <= 0:
		_spawn_mite_batch()
		_spawn_timer = randf_range(
			GameConstants.SWARM_QUEEN_SPAWN_INTERVAL_MIN,
			GameConstants.SWARM_QUEEN_SPAWN_INTERVAL_MAX
		)
	# Clean up freed/invalid mites from our tracking list
	_cleanup_mite_list()

## Spawn a batch of 1-3 Swarm Mites around the queen. Respects the global enemy
## cap and the queen's own concurrent-mite cap. Mites spawn with a small particle
## burst for visual feedback.
func _spawn_mite_batch() -> void:
	# Clean up dead/freed mites first so the cap check is accurate
	_cleanup_mite_list()
	# Check our own concurrent-mite cap
	if _spawned_mites.size() >= GameConstants.SWARM_QUEEN_MAX_MITES_ALIVE:
		return
	# Check the global enemy cap (don't spawn if the world is already at max)
	var alive_enemies: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.is_dead:
			alive_enemies += 1
	var spawn_cap: int = GameConstants.MAX_ACTIVE_ENEMIES + CoOpManager.get_max_enemies_bonus() + GameManager.get_time_max_enemy_bonus()
	if alive_enemies >= spawn_cap:
		return  # World is full — wait for the next batch
	# Pick batch size (limited by remaining cap)
	var max_batch: int = GameConstants.SWARM_QUEEN_MAX_MITES_ALIVE - _spawned_mites.size()
	var batch_size: int = min(
		randi_range(GameConstants.SWARM_QUEEN_SPAWN_BATCH_MIN, GameConstants.SWARM_QUEEN_SPAWN_BATCH_MAX),
		max_batch
	)
	batch_size = max(1, batch_size)  # Always spawn at least 1
	for i in range(batch_size):
		_spawn_single_mite()

## Spawn a single Swarm Mite at a random position around the queen.
func _spawn_single_mite() -> void:
	var angle: float = randf() * TAU
	var dist: float = randf_range(0.5, GameConstants.SWARM_QUEEN_SPAWN_RADIUS)
	var spawn_pos: Vector3 = global_position + Vector3(
		cos(angle) * dist, 0.5, sin(angle) * dist
	)
	var mite: CharacterBody3D = MITE_SCENE.instantiate()
	# Set position BEFORE add_child so _ready() sees the correct global_position
	mite.position = spawn_pos
	get_parent().add_child(mite)
	GameManager.enemies.append(mite)
	# Track the mite so we can cap our concurrent spawns
	_spawned_mites.append(mite)
	# Small particle burst at the spawn point — "birth" effect
	ParticleEffects.spawn_materialization(get_parent(), spawn_pos,
		GameConstants.SWARM_MITE_COLOR)
	# Materialization audio
	AudioManager.play_sfx(AudioManager.SFX_ENEMY_HIT)

## Remove freed/invalid mites from the tracking list. Called each frame and
## before spawning a new batch so the cap check is accurate.
func _cleanup_mite_list() -> void:
	for i in range(_spawned_mites.size() - 1, -1, -1):
		var m: CharacterBody3D = _spawned_mites[i]
		if not is_instance_valid(m) or m.is_dead:
			_spawned_mites.remove_at(i)

func _die() -> void:
	# On death, spawn a burst of mites as a final "swarm release" — the queen's
	# death throws scatter her brood. This is a small bonus wave (2-4 mites)
	# that creates a moment of pressure even after killing the queen.
	_cleanup_mite_list()
	var final_burst: int = randi_range(2, 4)
	for i in range(final_burst):
		_spawn_single_mite()
	# Extra particle burst for the queen's death
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		GameConstants.SWARM_QUEEN_COLOR, 30, 0.7)
	super._die()