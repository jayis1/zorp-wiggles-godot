## Zorp Wiggles — Boss Arena System (Phase 18: Boss Arenas)
## When a boss spawns, the terrain around the player morphs into an enclosed
## arena with walls, destructible cover, and environmental hazards.
## Arena types are determined by the boss type:
##   - LAVA_ARENA (Drake): lava geysers + shrinking floor over time
##   - CRYSTAL_ARENA (Serpent King): falling stalactites + crystal walls
##   - VOID_ARENA (Graviton Prime): void shockwaves + gravity shifts
##
## On boss death, the walls lower and an exit portal appears.
## The arena auto-spawns bosses periodically if the player has enough score.

extends Node3D

class_name BossArena

signal arena_activated(arena_type: int)
signal arena_deactivated()
signal arena_shrunk(new_radius: float)

# ─── Arena State ──────────────────────────────────────────────────────────────
enum ArenaState { IDLE, RISING, ACTIVE, LOWERING }

var _state: int = ArenaState.IDLE
var _arena_type: int = GameConstants.ArenaType.LAVA_ARENA
var _center: Vector3 = Vector3.ZERO
var _current_radius: float = GameConstants.ARENA_RADIUS
var _shrink_timer: float = 0.0
var _hazard_timer: float = 0.0
var _boss_node: Node = null

# ─── Arena visual/collision nodes ─────────────────────────────────────────────
var _wall_segments: Array[StaticBody3D] = []
var _wall_meshes: Array[MeshInstance3D] = []
var _cover_pillars: Array[Node3D] = []
var _floor_disc: MeshInstance3D = null
var _floor_mat: StandardMaterial3D = null
var _exit_portal: Node3D = null

# ─── Boss auto-spawn timer ────────────────────────────────────────────────────
var _boss_spawn_timer: float = GameConstants.BOSS_ARENA_SPAWN_INTERVAL
var _has_spawned_first_boss: bool = false

# ─── Hazard type pools per arena type ─────────────────────────────────────────
const LAVA_HAZARDS: Array[int] = [
	ArenaHazard.HazardType.LAVA_GEYSER,
	ArenaHazard.HazardType.LAVA_GEYSER,
	ArenaHazard.HazardType.FALLING_CRYSTAL,  # Occasional mixed hazard
]
const CRYSTAL_HAZARDS: Array[int] = [
	ArenaHazard.HazardType.FALLING_CRYSTAL,
	ArenaHazard.HazardType.FALLING_CRYSTAL,
	ArenaHazard.HazardType.VOID_SHOCKWAVE,
]
const VOID_HAZARDS: Array[int] = [
	ArenaHazard.HazardType.VOID_SHOCKWAVE,
	ArenaHazard.HazardType.VOID_SHOCKWAVE,
	ArenaHazard.HazardType.LAVA_GEYSER,
]

func _ready() -> void:
	# Listen for boss spawn/death to activate/deactivate arenas
	GameManager.boss_spawned.connect(_on_boss_spawned)
	GameManager.boss_defeated.connect(_on_boss_defeated)

func _process(delta: float) -> void:
	if GameManager.is_paused or not GameManager.player_is_alive:
		return

	match _state:
		ArenaState.IDLE:
			_update_idle(delta)
		ArenaState.RISING:
			_update_rising(delta)
		ArenaState.ACTIVE:
			_update_active(delta)
		ArenaState.LOWERING:
			_update_lowering(delta)

# ─── IDLE: count down to auto-spawn a boss if none active ─────────────────────
func _update_idle(delta: float) -> void:
	if GameManager.current_boss != null and is_instance_valid(GameManager.current_boss):
		return  # A boss is already active (spawned by normal spawner)

	# Don't auto-spawn until player has minimum score
	if GameManager.player_score < GameConstants.BOSS_ARENA_SPAWN_MIN_SCORE:
		return

	_boss_spawn_timer -= delta
	if _boss_spawn_timer <= 0:
		_spawn_arena_boss()
		_boss_spawn_timer = GameConstants.BOSS_ARENA_SPAWN_INTERVAL

# ─── RISING: walls animate up from the ground ─────────────────────────────────
func _update_rising(delta: float) -> void:
	# Walls are tweened up in _build_arena; just wait for them to finish
	# The tween callback sets state to ACTIVE
	# This is a fallback timer in case tween callback is missed
	_shrink_timer -= delta
	if _shrink_timer <= 0:
		_activate_arena()

# ─── ACTIVE: spawn hazards, shrink arena over time ────────────────────────────
func _update_active(delta: float) -> void:
	# Check if boss is still alive
	if _boss_node == null or not is_instance_valid(_boss_node):
		# Boss died or was freed — start lowering
		_start_lowering()
		return

	# Hazard spawning
	_hazard_timer -= delta
	if _hazard_timer <= 0:
		_spawn_hazard()
		_hazard_timer = randf_range(
			GameConstants.ARENA_HAZARD_INTERVAL_MIN,
			GameConstants.ARENA_HAZARD_INTERVAL_MAX
		)

	# Arena shrinking (lava arena only)
	if _arena_type == GameConstants.ArenaType.LAVA_ARENA:
		_shrink_timer -= delta
		if _shrink_timer <= 0:
			_shrink_arena()
			_shrink_timer = GameConstants.ARENA_SHRINK_INTERVAL

	# Update floor disc pulse
	if _floor_mat:
		var pulse: float = 0.7 + 0.15 * sin(Time.get_ticks_msec() * 0.003)
		_floor_mat.emission_energy_multiplier = pulse

# ─── LOWERING: walls animate down, then clean up ──────────────────────────────
func _update_lowering(delta: float) -> void:
	# Walls are tweened down in _start_lowering; just wait
	_shrink_timer -= delta
	if _shrink_timer <= 0:
		_cleanup_arena()

# ─── Boss Spawn Integration ───────────────────────────────────────────────────
func _on_boss_spawned(boss: Node) -> void:
	# Track the current boss
	GameManager.current_boss = boss
	_boss_node = boss

	# Determine arena type from boss type
	if boss is EnemyDrake:
		_arena_type = GameConstants.ArenaType.LAVA_ARENA
	elif boss.has_method("get") and boss.get("enemy_type") == GameConstants.EnemyType.SERPENT:
		_arena_type = GameConstants.ArenaType.CRYSTAL_ARENA
	elif boss.has_method("get") and boss.get("enemy_type") == GameConstants.EnemyType.GRAVITON:
		_arena_type = GameConstants.ArenaType.VOID_ARENA
	else:
		# Default to lava arena for any boss
		_arena_type = GameConstants.ArenaType.LAVA_ARENA

	# Build the arena around the player's current position
	var player: Node3D = GameManager.player
	if player and is_instance_valid(player):
		_center = player.global_position
		_center.y = 0.0
	else:
		_center = Vector3.ZERO

	_build_arena()
	_state = ArenaState.RISING
	_shrink_timer = GameConstants.ARENA_RISE_DURATION  # Reuse as rise timer
	arena_activated.emit(_arena_type)

	GameManager.add_message("⚠ Arena formed! Defeat the boss to escape!")

func _on_boss_defeated(boss: Node) -> void:
	GameManager.current_boss = null
	# Start lowering sequence
	if _state == ArenaState.ACTIVE:
		_start_lowering()

# ─── Arena Construction ───────────────────────────────────────────────────────
func _build_arena() -> void:
	_current_radius = GameConstants.ARENA_RADIUS
	var arena_color: Color = _get_arena_color()
	var glow_color: Color = _get_arena_glow()

	# ── Floor disc — colored overlay on terrain ──
	_floor_disc = MeshInstance3D.new()
	var floor_geom := CylinderMesh.new()
	floor_geom.top_radius = _current_radius
	floor_geom.bottom_radius = _current_radius
	floor_geom.height = 0.15
	floor_geom.radial_segments = 48
	_floor_disc.mesh = floor_geom
	_floor_mat = StandardMaterial3D.new()
	_floor_mat.albedo_color = Color(arena_color.r, arena_color.g, arena_color.b, 0.35)
	_floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_floor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_floor_mat.emission_enabled = true
	_floor_mat.emission = glow_color * 0.3
	_floor_mat.emission_energy_multiplier = 0.8
	_floor_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_floor_disc.material_override = _floor_mat
	_floor_disc.rotate_x(deg_to_rad(90))
	get_parent().add_child(_floor_disc)
	_floor_disc.global_position = _center + Vector3(0, 0.08, 0)

	# ── Arena walls — ring of StaticBody3D segments ──
	var wall_segments: int = 12
	var segment_arc: float = TAU / wall_segments
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = GameConstants.ARENA_WALL_COLOR
	wall_mat.roughness = 0.7
	wall_mat.metallic = 0.2
	wall_mat.emission_enabled = true
	wall_mat.emission = glow_color * 0.15
	wall_mat.emission_energy_multiplier = 0.5

	for i in wall_segments:
		var angle: float = i * segment_arc
		var seg_pos := _center + Vector3(
			cos(angle) * _current_radius,
			0,
			sin(angle) * _current_radius
		)

		# StaticBody3D wall segment
		var wall := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(
			2.0 * _current_radius * tan(segment_arc / 2.0) + 1.0,
			GameConstants.ARENA_WALL_HEIGHT,
			GameConstants.ARENA_WALL_THICKNESS
		)
		col.shape = box
		wall.add_child(col)

		# Visual mesh
		var mesh_inst := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = box.size
		mesh_inst.mesh = box_mesh
		mesh_inst.material_override = wall_mat
		# Add emission edge strip
		var edge_mat := StandardMaterial3D.new()
		edge_mat.albedo_color = glow_color
		edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		edge_mat.emission_enabled = true
		edge_mat.emission = glow_color
		edge_mat.emission_energy_multiplier = 2.0
		mesh_inst.material_override = wall_mat
		wall.add_child(mesh_inst)

		# Orient wall segment to face center
		wall.global_position = seg_pos
		wall.look_at(_center, Vector3.UP)
		# Start walls underground (will rise via tween)
		wall.position.y = -GameConstants.ARENA_WALL_HEIGHT

		get_parent().add_child(wall)
		_wall_segments.append(wall)
		_wall_meshes.append(mesh_inst)

		# Animate wall rising
		var rise_tween := wall.create_tween()
		rise_tween.tween_property(wall, "position:y",
			GameConstants.ARENA_WALL_HEIGHT / 2.0,
			GameConstants.ARENA_RISE_DURATION
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# ── Arena transition particle effect ──
	ParticleEffects.spawn_explosion(get_parent(), _center, glow_color,
		GameConstants.ARENA_TRANSITION_PARTICLES, 1.5)

	# Camera shake for impact
	var cam: Node3D = GameManager.camera_rig
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.4)

	# ── Destructible cover pillars ──
	_spawn_cover_pillars()

	# Rebuild navigation mesh after arena is built
	call_deferred("_rebuild_nav")

func _spawn_cover_pillars() -> void:
	var pillar_count: int = 6
	var pillar_color: Color = _get_arena_color()
	var glow: Color = _get_arena_glow()

	for i in pillar_count:
		var angle: float = (i / float(pillar_count)) * TAU + randf_range(-0.3, 0.3)
		var dist: float = _current_radius * 0.5 + randf_range(-3.0, 3.0)
		var pos: Vector3 = _center + Vector3(cos(angle) * dist, 0, sin(angle) * dist)

		# Use destructible scene as cover
		var destructible_scene: PackedScene = load("res://scenes/entities/destructible.tscn")
		if destructible_scene:
			var pillar: Node3D = destructible_scene.instantiate()
			get_parent().add_child(pillar)
			pillar.global_position = pos

			# Configure as arena pillar
			if pillar is Destructible:
				pillar.hp = 60  # Tougher than normal crates
				pillar.shatter_count = 12
				pillar.is_crystal = _arena_type == GameConstants.ArenaType.CRYSTAL_ARENA
				if pillar.is_crystal:
					pillar.fragment_color = GameConstants.ARENA_CRYSTAL_COLOR
				else:
					pillar.fragment_color = Color(
						GameConstants.ARENA_WALL_COLOR.r + 0.1,
						GameConstants.ARENA_WALL_COLOR.g + 0.1,
						GameConstants.ARENA_WALL_COLOR.b + 0.1
					)
				# Scale up the pillar for better cover
				pillar.scale = Vector3(1.5, 1.8, 1.5)

			_cover_pillars.append(pillar)

func _rebuild_nav() -> void:
	if NavigationManager:
		NavigationManager.build_nav_region(get_parent())

# ─── Arena Activation ─────────────────────────────────────────────────────────
func _activate_arena() -> void:
	_state = ArenaState.ACTIVE
	_shrink_timer = GameConstants.ARENA_SHRINK_INTERVAL
	_hazard_timer = randf_range(
		GameConstants.ARENA_HAZARD_INTERVAL_MIN,
		GameConstants.ARENA_HAZARD_INTERVAL_MAX
	)

# ─── Arena Shrinking ──────────────────────────────────────────────────────────
func _shrink_arena() -> void:
	if _current_radius <= GameConstants.ARENA_MIN_RADIUS:
		return  # Already at minimum

	var new_radius: float = max(
		GameConstants.ARENA_MIN_RADIUS,
		_current_radius - GameConstants.ARENA_SHRINK_AMOUNT
	)

	# Animate walls inward
	for i in _wall_segments.size():
		var wall: StaticBody3D = _wall_segments[i]
		if not is_instance_valid(wall):
			continue
		var angle: float = (i / float(_wall_segments.size())) * TAU
		var new_pos := _center + Vector3(cos(angle) * new_radius, wall.position.y, sin(angle) * new_radius)
		var shrink_tween := wall.create_tween()
		shrink_tween.tween_property(wall, "global_position", new_pos, 1.5) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

	# Shrink floor disc
	if _floor_disc:
		var floor_tween := _floor_disc.create_tween()
		var new_scale := Vector3(new_radius / _current_radius, 1.0, new_radius / _current_radius)
		# We need to account for the rotated disc (rotated 90° on X)
		# Scale on local Z maps to world Y, but since it's flat, X/Z scale is what matters
		floor_tween.tween_property(_floor_disc, "scale",
			Vector3(new_radius / _current_radius, 1.0, new_radius / _current_radius), 1.5) \
			.set_ease(Tween.EASE_IN_OUT)

	_current_radius = new_radius
	arena_shrunk.emit(new_radius)
	GameManager.add_message("⚠ The arena is shrinking!")

	# Particle burst at center
	ParticleEffects.spawn_explosion(get_parent(), _center, _get_arena_glow(), 50, 0.8)

	# Camera shake
	var cam: Node3D = GameManager.camera_rig
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.25)

# ─── Hazard Spawning ──────────────────────────────────────────────────────────
func _spawn_hazard() -> void:
	var hazard_pool: Array[int]
	match _arena_type:
		GameConstants.ArenaType.LAVA_ARENA:
			hazard_pool = LAVA_HAZARDS
		GameConstants.ArenaType.CRYSTAL_ARENA:
			hazard_pool = CRYSTAL_HAZARDS
		GameConstants.ArenaType.VOID_ARENA:
			hazard_pool = VOID_HAZARDS
		_:
			hazard_pool = LAVA_HAZARDS

	var htype: int = hazard_pool[randi() % hazard_pool.size()]

	# Spawn at random position within arena
	var angle: float = randf() * TAU
	var dist: float = randf() * (_current_radius - 2.0)
	var pos: Vector3 = _center + Vector3(cos(angle) * dist, 0, sin(angle) * dist)

	# Create hazard node
	var hazard := ArenaHazard.new()
	hazard.set_hazard_type(htype)
	hazard.damage = GameConstants.ARENA_HAZARD_DAMAGE
	hazard.damage_radius = GameConstants.ARENA_HAZARD_RADIUS
	get_parent().add_child(hazard)
	hazard.global_position = pos

# ─── Arena Lowering & Cleanup ─────────────────────────────────────────────────
func _start_lowering() -> void:
	_state = ArenaState.LOWERING
	_shrink_timer = GameConstants.ARENA_RISE_DURATION  # Reuse as lower timer

	# Animate walls sinking
	for wall in _wall_segments:
		if is_instance_valid(wall):
			var lower_tween := wall.create_tween()
			lower_tween.tween_property(wall, "position:y",
				-GameConstants.ARENA_WALL_HEIGHT,
				GameConstants.ARENA_RISE_DURATION
			).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	# Fade out floor disc
	if _floor_disc and _floor_mat:
		var fade_tween := _floor_disc.create_tween()
		fade_tween.tween_property(_floor_mat, "albedo_color:a", 0.0,
			GameConstants.ARENA_RISE_DURATION).set_ease(Tween.EASE_IN)

	# Spawn exit portal
	_spawn_exit_portal()

	# Particle burst
	ParticleEffects.spawn_explosion(get_parent(), _center, _get_arena_glow(), 80, 1.0)

	# Camera shake
	var cam: Node3D = GameManager.camera_rig
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.3)

	arena_deactivated.emit()
	GameManager.add_message("✦ Boss defeated! Arena dissolved!")

func _spawn_exit_portal() -> void:
	# Spawn a portal at arena center that the player can use to teleport away
	var portal_scene: PackedScene = load("res://scenes/entities/portal.tscn")
	if portal_scene:
		_exit_portal = portal_scene.instantiate()
		get_parent().add_child(_exit_portal)
		_exit_portal.global_position = _center + Vector3(0, 0.5, 0)
		# Auto-free after lifetime
		var timer := get_tree().create_timer(GameConstants.ARENA_EXIT_PORTAL_LIFETIME)
		timer.timeout.connect(func(): if is_instance_valid(_exit_portal): _exit_portal.queue_free())

func _cleanup_arena() -> void:
	# Remove walls
	for wall in _wall_segments:
		if is_instance_valid(wall):
			wall.queue_free()
	_wall_segments.clear()
	_wall_meshes.clear()

	# Remove floor
	if _floor_disc and is_instance_valid(_floor_disc):
		_floor_disc.queue_free()
	_floor_disc = null
	_floor_mat = null

	# Cover pillars are destructibles — let them be destroyed naturally or clean up remaining
	for pillar in _cover_pillars:
		if is_instance_valid(pillar):
			pillar.queue_free()
	_cover_pillars.clear()

	# Rebuild nav mesh after arena removal
	call_deferred("_rebuild_nav")

	_state = ArenaState.IDLE
	_arena_type = GameConstants.ArenaType.LAVA_ARENA
	_boss_node = null
	_has_spawned_first_boss = true

# ─── Auto-Spawn Boss ──────────────────────────────────────────────────────────
func _spawn_arena_boss() -> void:
	# Pick a random boss type and spawn it near the player
	var player: Node3D = GameManager.player
	if not player or not is_instance_valid(player):
		return

	# Rotate through arena types for variety
	var boss_types: Array[int] = [
		GameConstants.EnemyType.DRAKE,
		GameConstants.EnemyType.SERPENT,
		GameConstants.EnemyType.GRAVITON,
	]
	var boss_type: int = boss_types[randi() % boss_types.size()]

	# Map to scene
	var scene_path: String = ""
	match boss_type:
		GameConstants.EnemyType.DRAKE:
			scene_path = "res://scenes/entities/enemy_drake.tscn"
		GameConstants.EnemyType.SERPENT:
			scene_path = "res://scenes/entities/enemy_serpent.tscn"
		GameConstants.EnemyType.GRAVITON:
			scene_path = "res://scenes/entities/enemy_graviton.tscn"
		_:
			scene_path = "res://scenes/entities/enemy_drake.tscn"

	var scene: PackedScene = load(scene_path)
	if not scene:
		print("[BossArena] Failed to load boss scene: %s" % scene_path)
		return

	var boss: CharacterBody3D = scene.instantiate()
	# Spawn near player at a visible distance
	var angle: float = randf() * TAU
	var spawn_pos: Vector3 = player.global_position + Vector3(
		cos(angle) * 15.0, 1.0, sin(angle) * 15.0
	)
	boss.position = spawn_pos
	get_parent().add_child(boss)
	GameManager.enemies.append(boss)

	# Scale boss to player level (tougher)
	if boss is EnemyBase:
		var hp_mult: float = 1.0 + (GameManager.player_level - 1) * 0.1
		var new_hp: int = int(boss.max_hp * hp_mult)
		boss.max_hp = new_hp
		boss.hp = new_hp
		# Make non-Drake bosses emit boss signals (Drake does this in _ready)
		if boss_type != GameConstants.EnemyType.DRAKE:
			# Boost HP to boss-tier if not already
			if new_hp < 200:
				boss.max_hp = 250 + GameManager.player_level * 20
				boss.hp = boss.max_hp
			# Mark as arena boss so _die() emits boss_defeated
			boss.is_arena_boss = true
			# Emit boss signal after _ready has run
			GameManager.boss_spawned.emit(boss)

	GameManager.add_message("⚔ A boss has appeared!")

# ─── Helpers ──────────────────────────────────────────────────────────────────
func _get_arena_color() -> Color:
	match _arena_type:
		GameConstants.ArenaType.LAVA_ARENA:
			return GameConstants.ARENA_LAVA_COLOR
		GameConstants.ArenaType.CRYSTAL_ARENA:
			return GameConstants.ARENA_CRYSTAL_COLOR
		GameConstants.ArenaType.VOID_ARENA:
			return GameConstants.ARENA_VOID_COLOR
		_:
			return Color.GRAY

func _get_arena_glow() -> Color:
	match _arena_type:
		GameConstants.ArenaType.LAVA_ARENA:
			return GameConstants.ARENA_LAVA_GLOW
		GameConstants.ArenaType.CRYSTAL_ARENA:
			return GameConstants.ARENA_CRYSTAL_GLOW
		GameConstants.ArenaType.VOID_ARENA:
			return GameConstants.ARENA_VOID_GLOW
		_:
			return Color.WHITE

## Check if a position is inside the current arena bounds (used by player/enemies)
func is_inside_arena(pos: Vector3) -> bool:
	if _state != ArenaState.ACTIVE and _state != ArenaState.RISING:
		return true  # No arena active, always "inside"
	var flat_pos := Vector3(pos.x, 0, pos.z)
	return flat_pos.distance_to(_center) <= _current_radius

## Get the current arena center
func get_arena_center() -> Vector3:
	return _center

## Get the current arena radius
func get_arena_radius() -> float:
	return _current_radius

## Is an arena currently active?
func is_arena_active() -> bool:
	return _state == ArenaState.ACTIVE or _state == ArenaState.RISING