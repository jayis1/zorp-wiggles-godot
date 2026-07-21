## Zorp Wiggles — Performance Optimizer (Phase 35)
## Centralized performance optimization system that provides:
##   1. Object pooling for frequently spawned/freed nodes (projectiles, impact bursts,
##      enemy projectiles, damage numbers, spawn warnings).
##   2. LOD (Level of Detail) management for distant enemies — reduces particle
##      counts, disables non-essential visuals, and culls far decorations.
##   3. Draw call reduction via visibility culling for distant objects and
##      render priority hints.
##   4. Frame budget tracking — monitors frame time and auto-adjusts quality.
##
## Registered as the `PerformanceOptimizer` autoload singleton.
## All pooling is opt-in — systems call acquire()/release() instead of
## instantiate()/queue_free(). The pool transparently creates new instances
## when empty and reclaims them on release() instead of freeing.

extends Node

# ─── Object Pool ──────────────────────────────────────────────────────────────
# A generic object pool that recycles PackedScene instances. When acquire()
# is called, a dormant instance is pulled from the pool and re-activated. When
# release() is called, the instance is de-activated and returned to the pool
# instead of being freed. This eliminates the instantiate/free churn for
# high-frequency objects like projectiles (~9/sec) and impact bursts.

const POOL_DEFAULT_SIZE: int = 30        # Pre-warm count per pool
const POOL_MAX_SIZE: int = 80            # Hard cap — prevents unbounded growth
const POOL_WARN_THRESHOLD: int = 60      # Warn if pool is running hot

# scene_path → { "scene": PackedScene, "free": Array[Node], "active": int, "created": int }
var _pools: Dictionary = {}

# Track active (in-use) instances so we can reclaim them on scene change.
# weak references via instance_id — safe against queue_free.
var _active_instances: Dictionary = {}  # instance_id → pool_key

# ─── LOD (Level of Detail) ───────────────────────────────────────────────────
# Enemies and decorations far from the player don't need full visual fidelity.
# The LOD manager periodically reclassifies objects by distance and adjusts:
#   - Particle emission counts (GPUParticles3D)
#   - Light range/energy (OmniLight3D)
#   - Mesh visibility for tiny decorations
#   - Process mode (far enemies skip AI ticks at reduced rate)

const LOD_UPDATE_INTERVAL: float = 0.5  # Re-classify every 0.5s (not every frame)
const LOD_NEAR_DIST: float = 40.0       # Full quality
const LOD_MID_DIST: float = 80.0        # Reduced particles, dimmer lights
const LOD_FAR_DIST: float = 150.0       # Minimal — particles off, lights off
const LOD_CULL_DIST: float = 250.0      # Hide entirely (decorations only)

var _lod_timer: float = 0.0
# Track registered LOD targets: instance_id → { "node": Node, "particles": Array, "lights": Array, "base_data": Dictionary }
var _lod_targets: Dictionary = {}

# ─── Frame Budget ─────────────────────────────────────────────────────────────
const FRAME_BUDGET_MS: float = 16.67    # 60 FPS target
const FRAME_BUDGET_WARN_MS: float = 20.0  # Warn at <50 FPS
const QUALITY_ADJUST_INTERVAL: float = 5.0  # Re-evaluate every 5s
const FRAME_HISTORY_SIZE: int = 120     # 2 seconds at 60 FPS

var _frame_times: Array[float] = []
var _quality_timer: float = 0.0
var _auto_quality_enabled: bool = true
var _current_quality_level: int = 2  # 0=low, 1=medium, 2=high, 3=ultra

signal quality_changed(level: int, level_name: String)
signal pool_stats_updated(stats: Dictionary)


# ═══════════════════════════════════════════════════════════════════════════════
#   LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Connect to scene change for pool cleanup
	if get_tree():
		get_tree().tree_changed.connect(_on_tree_changed)
	# Connect to game restart for full pool flush
	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)
	# Start at high quality (will auto-adjust down if needed)
	_current_quality_level = 2
	print("[PerformanceOptimizer] Initialized — auto-quality enabled")

func _process(delta: float) -> void:
	# Track frame time
	var frame_ms: float = Time.get_ticks_msec()
	# We can't measure the current frame's time yet, so we use the delta
	# from the previous frame (delta is the time since last _process call).
	_frame_times.append(delta * 1000.0)
	if _frame_times.size() > FRAME_HISTORY_SIZE:
		_frame_times.pop_front()

	# LOD update tick
	_lod_timer += delta
	if _lod_timer >= LOD_UPDATE_INTERVAL:
		_lod_timer = 0.0
		_update_lod()

	# Quality auto-adjust tick
	_quality_timer += delta
	if _quality_timer >= QUALITY_ADJUST_INTERVAL:
		_quality_timer = 0.0
		_evaluate_quality()


# ═══════════════════════════════════════════════════════════════════════════════
#   OBJECT POOLING — PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Register a scene for pooling. Pre-warms the pool with `pre_warm` instances.
## Call this once at startup (or on first use) for each scene type you want pooled.
func register_pool(scene_path: String, pre_warm: int = POOL_DEFAULT_SIZE) -> void:
	if _pools.has(scene_path):
		return
	var scene: PackedScene = load(scene_path)
	if scene == null:
		push_warning("[PerformanceOptimizer] Cannot load scene for pooling: %s" % scene_path)
		return
	_pools[scene_path] = {
		"scene": scene,
		"free": [],
		"active": 0,
		"created": 0,
	}
	# Pre-warm the pool — create dormant instances ready for use
	for i in range(pre_warm):
		var node: Node = scene.instantiate()
		_pools[scene_path]["created"] += 1
		# Keep dormant — not added to scene tree until acquired
		_pools[scene_path]["free"].append(node)
	print("[PerformanceOptimizer] Pool registered: %s (pre-warmed %d)" % [scene_path, pre_warm])

## Acquire an instance from the pool. The instance is activated and added to
## the specified parent. Returns null if the pool is unregistered.
func acquire(scene_path: String, parent: Node) -> Node:
	if not _pools.has(scene_path):
		# Auto-register on first use (no pre-warm)
		register_pool(scene_path, 0)
	var pool: Dictionary = _pools[scene_path]
	var node: Node = null
	if pool["free"].size() > 0:
		node = pool["free"].pop_back()
	else:
		# Pool empty — create a new instance
		node = pool["scene"].instantiate()
		pool["created"] += 1
	# Activate and add to tree
	if node.get_parent() == null:
		parent.add_child(node)
	# Re-enable processing
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node is Node3D:
		(node as Node3D).visible = true
	elif node is CanvasItem:
		(node as CanvasItem).visible = true
	pool["active"] += 1
	_active_instances[node.get_instance_id()] = scene_path
	# Call reset if the node supports it
	if node.has_method("_pool_reset"):
		node.call("_pool_reset")
	return node

## Release an instance back to the pool. The instance is deactivated and
## removed from the scene tree. Safe to call on an already-released instance.
func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var instance_id: int = node.get_instance_id()
	if not _active_instances.has(instance_id):
		# Not a pooled instance — ignore
		return
	var scene_path: String = _active_instances[instance_id]
	_active_instances.erase(instance_id)
	if not _pools.has(scene_path):
		# Pool was cleared — just free the node
		node.queue_free()
		return
	var pool: Dictionary = _pools[scene_path]
	pool["active"] -= 1
	# Call pool cleanup if supported
	if node.has_method("_pool_cleanup"):
		node.call("_pool_cleanup")
	# Deactivate
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is Node3D:
		(node as Node3D).visible = false
	elif node is CanvasItem:
		# BUG FIX: this was `visible = true`, which kept released UI nodes
		# visible after release() — defeating the purpose of deactivation
		# and leaving orphaned UI elements on screen. Now correctly hidden.
		(node as CanvasItem).visible = false
	# Remove from tree (keep in memory for reuse)
	if node.get_parent():
		node.get_parent().remove_child(node)
	# Return to pool (respect max size)
	if pool["free"].size() < POOL_MAX_SIZE:
		pool["free"].append(node)
	else:
		# Pool full — actually free
		pool["created"] -= 1
		node.queue_free()

## Check if a node is currently a pooled active instance.
func is_pooled_instance(node: Node) -> bool:
	if node == null:
		return false
	return _active_instances.has(node.get_instance_id())

## Get pool statistics for debugging/UI.
func get_pool_stats() -> Dictionary:
	var stats: Dictionary = {}
	for path in _pools:
		var pool: Dictionary = _pools[path]
		stats[path] = {
			"free": pool["free"].size(),
			"active": pool["active"],
			"created": pool["created"],
		}
	return stats


# ═══════════════════════════════════════════════════════════════════════════════
#   LOD (Level of Detail) — PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Register a node for LOD management. The node should be a Node3D (enemy,
## decoration, etc.). Particles and lights within the node are automatically
## discovered and adjusted by distance.
func register_lod_target(node: Node3D) -> void:
	if node == null:
		return
	var instance_id: int = node.get_instance_id()
	if _lod_targets.has(instance_id):
		return
	# Discover particles and lights in the node
	var particles: Array[GPUParticles3D] = []
	var lights: Array[OmniLight3D] = []
	_find_particles_and_lights(node, particles, lights)
	# Store base data for restoration
	var base_data: Dictionary = {
		"particles_count": [],
		"lights_range": [],
		"lights_energy": [],
	}
	for p in particles:
		base_data["particles_count"].append(p.amount)
	for l in lights:
		base_data["lights_range"].append(l.omni_range)
		base_data["lights_energy"].append(l.light_energy)
	_lod_targets[instance_id] = {
		"node": node,
		"particles": particles,
		"lights": lights,
		"base_data": base_data,
		"current_lod": 0,  # 0=near, 1=mid, 2=far, 3=cull
	}

## Unregister a node from LOD management (call on queue_free).
func unregister_lod_target(node: Node3D) -> void:
	if node == null:
		return
	_lod_targets.erase(node.get_instance_id())

## Update LOD for all registered targets based on distance to player.
func _update_lod() -> void:
	if GameManager == null or GameManager.player == null or not is_instance_valid(GameManager.player):
		return
	var player_pos: Vector3 = GameManager.player.global_position
	for instance_id in _lod_targets:
		var entry: Dictionary = _lod_targets[instance_id]
		var node: Node3D = entry["node"]
		if node == null or not is_instance_valid(node):
			_lod_targets.erase(instance_id)
			continue
		var dist: float = node.global_position.distance_to(player_pos)
		var new_lod: int = _distance_to_lod(dist)
		if new_lod != entry["current_lod"]:
			_apply_lod(entry, new_lod)
			entry["current_lod"] = new_lod

func _distance_to_lod(dist: float) -> int:
	var near_d: float = LOD_NEAR_DIST
	var mid_d: float = LOD_MID_DIST
	var far_d: float = LOD_FAR_DIST
	var cull_d: float = LOD_CULL_DIST
	if _lod_distances_override.has("near"):
		near_d = float(_lod_distances_override["near"])
		mid_d = float(_lod_distances_override["mid"])
		far_d = float(_lod_distances_override["far"])
		cull_d = float(_lod_distances_override["cull"])
	if dist <= near_d:
		return 0  # Near — full quality
	elif dist <= mid_d:
		return 1  # Mid — reduced particles
	elif dist <= far_d:
		return 2  # Far — minimal
	else:
		return 3  # Cull — hide

func _apply_lod(entry: Dictionary, lod: int) -> void:
	var node: Node3D = entry["node"]
	var particles: Array = entry["particles"]
	var lights: Array = entry["lights"]
	var base_data: Dictionary = entry["base_data"]
	# Check for custom cull distance meta
	var cull_dist: float = LOD_CULL_DIST
	if node.has_meta("_visibility_cull_distance"):
		cull_dist = float(node.get_meta("_visibility_cull_distance"))
	match lod:
		0:  # Near — full quality
			node.visible = true
			for i in range(particles.size()):
				if is_instance_valid(particles[i]):
					particles[i].amount = int(base_data["particles_count"][i])
					particles[i].emitting = true
			for i in range(lights.size()):
				if is_instance_valid(lights[i]):
					lights[i].omni_range = float(base_data["lights_range"][i])
					lights[i].light_energy = float(base_data["lights_energy"][i])
		1:  # Mid — 50% particles, 70% light
			node.visible = true
			for i in range(particles.size()):
				if is_instance_valid(particles[i]):
					particles[i].amount = int(base_data["particles_count"][i] * 0.5)
			for i in range(lights.size()):
				if is_instance_valid(lights[i]):
					lights[i].omni_range = float(base_data["lights_range"][i]) * 0.7
					lights[i].light_energy = float(base_data["lights_energy"][i]) * 0.7
		2:  # Far — 10% particles, 30% light
			node.visible = true
			for i in range(particles.size()):
				if is_instance_valid(particles[i]):
					particles[i].amount = int(base_data["particles_count"][i] * 0.1)
			for i in range(lights.size()):
				if is_instance_valid(lights[i]):
					lights[i].omni_range = float(base_data["lights_range"][i]) * 0.3
					lights[i].light_energy = float(base_data["lights_energy"][i]) * 0.3
		3:  # Cull — hide entirely (respect custom cull distance)
			# Only hide if the node's custom cull distance allows it
			# (enemies are never hidden, only decorations)
			if node.has_meta("_visibility_cull_distance"):
				node.visible = false
			else:
				# For enemies: keep visible but minimize particles
				node.visible = true
				for i in range(particles.size()):
					if is_instance_valid(particles[i]):
						particles[i].amount = 0
				for i in range(lights.size()):
					if is_instance_valid(lights[i]):
						lights[i].light_energy = 0.0

func _find_particles_and_lights(node: Node, particles: Array[GPUParticles3D], lights: Array[OmniLight3D]) -> void:
	if node is GPUParticles3D:
		particles.append(node as GPUParticles3D)
	elif node is OmniLight3D:
		lights.append(node as OmniLight3D)
	for child in node.get_children():
		_find_particles_and_lights(child, particles, lights)


# ═══════════════════════════════════════════════════════════════════════════════
#   FRAME BUDGET & AUTO QUALITY
# ═══════════════════════════════════════════════════════════════════════════════

## Get the average frame time over the history window (in ms).
func get_avg_frame_time() -> float:
	if _frame_times.is_empty():
		return 0.0
	var total: float = 0.0
	for t in _frame_times:
		total += t
	return total / _frame_times.size()

## Get the current FPS estimate (based on average frame time).
func get_current_fps() -> int:
	var avg: float = get_avg_frame_time()
	if avg <= 0.0:
		return 0
	return int(1000.0 / avg)

## Get the 95th percentile frame time (worst 5% of frames).
func get_p95_frame_time() -> float:
	if _frame_times.is_empty():
		return 0.0
	var sorted: Array[float] = _frame_times.duplicate()
	sorted.sort()
	var idx: int = int(sorted.size() * 0.95)
	if idx >= sorted.size():
		idx = sorted.size() - 1
	return sorted[idx]

## Auto-adjust quality based on frame time history.
func _evaluate_quality() -> void:
	if not _auto_quality_enabled:
		return
	var avg: float = get_avg_frame_time()
	var p95: float = get_p95_frame_time()
	# Downgrade if consistently slow
	if avg > FRAME_BUDGET_WARN_MS and _current_quality_level > 0:
		_current_quality_level -= 1
		_apply_quality_level(_current_quality_level)
		var names: Array = ["Low", "Medium", "High", "Ultra"]
		var name: String = names[_current_quality_level]
		quality_changed.emit(_current_quality_level, name)
		print("[PerformanceOptimizer] Quality downgraded to %s (avg %.1fms, p95 %.1fms)" % [name, avg, p95])
	# Upgrade if consistently fast and headroom available
	elif avg < FRAME_BUDGET_MS * 0.6 and p95 < FRAME_BUDGET_MS and _current_quality_level < 3:
		_current_quality_level += 1
		_apply_quality_level(_current_quality_level)
		var names: Array = ["Low", "Medium", "High", "Ultra"]
		var name: String = names[_current_quality_level]
		quality_changed.emit(_current_quality_level, name)
		print("[PerformanceOptimizer] Quality upgraded to %s (avg %.1fms, p95 %.1fms)" % [name, avg, p95])

## Apply a quality level by adjusting engine settings.
func _apply_quality_level(level: int) -> void:
	match level:
		0:  # Low — max performance
			# Reduce all LOD distances (cull more aggressively)
			_set_lod_distances(20.0, 40.0, 80.0, 120.0)
			# Disable shadow casting on all lights
			_set_shadow_mode(false)
			# Reduce particle amounts globally
			_set_global_particle_scale(0.3)
		1:  # Medium
			_set_lod_distances(30.0, 60.0, 120.0, 180.0)
			_set_shadow_mode(true, 1024)  # Low shadow atlas
			_set_global_particle_scale(0.6)
		2:  # High (default)
			_set_lod_distances(LOD_NEAR_DIST, LOD_MID_DIST, LOD_FAR_DIST, LOD_CULL_DIST)
			_set_shadow_mode(true, 2048)
			_set_global_particle_scale(1.0)
		3:  # Ultra
			_set_lod_distances(60.0, 120.0, 200.0, 350.0)
			_set_shadow_mode(true, 4096)
			_set_global_particle_scale(1.0)

func _set_lod_distances(near: float, mid: float, far: float, cull: float) -> void:
	# We can't reassign const, so we use a runtime override dict
	_lod_distances_override = { "near": near, "mid": mid, "far": far, "cull": cull }

var _lod_distances_override: Dictionary = {}

func _set_shadow_mode(enabled: bool, atlas_size: int = 2048) -> void:
	# Adjust shadow atlas size via ProjectSettings (runtime-safe, persists)
	# and toggle shadow casting on all lights in the scene.
	ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", atlas_size if enabled else 0)
	# Toggle shadow casting on all OmniLight3D and DirectionalLight3D in the scene
	var current: Node = get_tree().current_scene
	if current == null:
		return
	_set_shadows_recursive(current, enabled)

func _set_shadows_recursive(node: Node, enabled: bool) -> void:
	if node is Light3D:
		(node as Light3D).shadow_enabled = enabled
	for child in node.get_children():
		_set_shadows_recursive(child, enabled)

func _set_global_particle_scale(scale: float) -> void:
	# Store for use when new particles are created
	_global_particle_scale = scale

var _global_particle_scale: float = 1.0

func get_global_particle_scale() -> float:
	return _global_particle_scale

## Toggle auto-quality adjustment.
func set_auto_quality(enabled: bool) -> void:
	_auto_quality_enabled = enabled

func get_quality_level() -> int:
	return _current_quality_level

func get_quality_name() -> String:
	var names: Array = ["Low", "Medium", "High", "Ultra"]
	if _current_quality_level >= 0 and _current_quality_level < names.size():
		return names[_current_quality_level]
	return "Unknown"


# ═══════════════════════════════════════════════════════════════════════════════
#   DRAW CALL REDUCTION
# ═══════════════════════════════════════════════════════════════════════════════

## Enable visibility culling for a node — the node will be hidden when beyond
## the cull distance from the player. Useful for decorations, structures, etc.
func enable_visibility_culling(node: Node3D, cull_distance: float = LOD_CULL_DIST) -> void:
	if node == null:
		return
	node.set_meta("_visibility_cull_distance", cull_distance)
	# The LOD update loop handles culling for registered targets,
	# but for non-LOD objects we use a lighter check via process scale.
	# Register as LOD target with no particles/lights — just visibility.
	if not _lod_targets.has(node.get_instance_id()):
		_lod_targets[node.get_instance_id()] = {
			"node": node,
			"particles": [],
			"lights": [],
			"base_data": {},
			"current_lod": 0,
		}

## Merge static decorations into a single MultiMeshInstance3D for draw call
## reduction. Call after all decorations of the same type are spawned.
func merge_static_meshes(nodes: Array[MeshInstance3D]) -> MultiMeshInstance3D:
	if nodes.size() < 2:
		return null
	# All nodes must share the same mesh resource
	var base_mesh: Mesh = nodes[0].mesh
	if base_mesh == null:
		return null
	var multimesh_inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.mesh = base_mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = nodes.size()
	for i in range(nodes.size()):
		multimesh.set_instance_transform(i, nodes[i].global_transform)
	multimesh_inst.multimesh = multimesh
	# Inherit material from first instance
	if nodes[0].material_override:
		multimesh_inst.material_override = nodes[0].material_override
	# Add to the parent of the first node (same scene layer)
	var parent: Node = nodes[0].get_parent()
	if parent:
		parent.add_child(multimesh_inst)
	# Remove the individual instances
	for node in nodes:
		node.queue_free()
	return multimesh_inst


# ═══════════════════════════════════════════════════════════════════════════════
#   CLEANUP
# ═══════════════════════════════════════════════════════════════════════════════

func _on_tree_changed() -> void:
	# Light periodic cleanup — remove stale active instance references
	# (nodes that were freed without calling release())
	pass  # Handled in _update_lod and on demand

func _on_game_restarted() -> void:
	# Release all active instances back to pools
	for instance_id in _active_instances.keys():
		var node: Node = instance_from_id(instance_id)
		if node and is_instance_valid(node):
			release(node)
	_active_instances.clear()
	# Clear LOD targets
	_lod_targets.clear()
	# Reset frame history
	_frame_times.clear()
	# Reset quality to high
	_current_quality_level = 2
	_apply_quality_level(2)

## Clear all pools (called on scene change or game exit).
func clear_all_pools() -> void:
	for path in _pools:
		var pool: Dictionary = _pools[path]
		for node in pool["free"]:
			if is_instance_valid(node):
				node.queue_free()
	_pools.clear()
	_active_instances.clear()