## Zorp Wiggles — Navigation Manager (Phase 10: Smart Enemy AI)
## Autoload singleton that maintains a NavigationRegion3D for the world.
## Builds a navigation mesh at runtime from the world's static colliders so
## enemies can use NavigationAgent3D to path around obstacles (decorations,
## destructibles, monoliths, etc.) instead of walking in straight lines.
##
## Usage:
##   1. NavigationManager is registered as an autoload in project.godot.
##   2. After the world is generated, WorldGenerator calls build_nav_region()
##      with the world node, which bakes a NavigationMesh from the existing
##      StaticBody3D colliders.
##   3. Enemies query get_next_position(target) to get a waypoint, or simply
##      add a NavigationAgent3D child and call set_target_position().

extends Node

# ─── Internal State ───────────────────────────────────────────────────────────
var _nav_region: NavigationRegion3D = null
var _is_baked: bool = false
var _world_node: Node = null

# Baked navigation mesh data
var _nav_mesh: NavigationMesh = null

# ─── Public API ───────────────────────────────────────────────────────────────

## Build a navigation region from the world's static geometry.
## Call this AFTER WorldGenerator has finished spawning all colliders.
func build_nav_region(world: Node) -> void:
	_world_node = world
	_is_baked = false

	# Remove any previous region
	if _nav_region and is_instance_valid(_nav_region):
		_nav_region.queue_free()
		_nav_region = null

	# Create a new NavigationRegion3D
	_nav_region = NavigationRegion3D.new()
	_nav_region.name = "NavRegion"
	# Add the nav region as a child of the WORLD node (not the autoload) so that
	# SOURCE_GEOMETRY_ROOT_NODE_CHILDREN parses the world's static colliders.
	if world and is_instance_valid(world):
		world.add_child(_nav_region)
	else:
		add_child(_nav_region)

	# Configure the navigation mesh
	_nav_mesh = NavigationMesh.new()
	_nav_mesh.agent_radius = 0.6
	_nav_mesh.agent_height = 2.0
	_nav_mesh.agent_max_slope = 45.0
	_nav_mesh.agent_max_climb = 0.5
	_nav_mesh.cell_size = 0.25
	_nav_mesh.cell_height = 0.25
	_nav_mesh.region_min_size = 10.0
	# Use a broad collision mask so all static colliders contribute
	_nav_mesh.geometry_collision_mask = 0xFFFFFFFF
	_nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	_nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	_nav_region.navigation_mesh = _nav_mesh

	# When the nav region is a child of the world, SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	# will parse all of the world's children (terrain, decorations, destructibles,
	# monoliths, portals, etc.) for static colliders to bake the nav mesh around.
	_nav_region.bake_navigation_mesh(false)  # on_thread = false for immediate result
	_is_baked = true
	print("[NavigationManager] Nav mesh baked for world: %s" % world.name)


## Returns true if the nav mesh has been baked and is ready to use.
func is_ready() -> bool:
	return _is_baked and _nav_region != null and is_instance_valid(_nav_region)


## Get the navigation map RID (needed by NavigationAgent3D).
func get_map_rid() -> RID:
	if _nav_region and is_instance_valid(_nav_region):
		return _nav_region.get_region_rid()
	# Fallback: try to get the default world 3D navigation map from the scene tree
	var world_3d: World3D = null
	if _world_node and is_instance_valid(_world_node):
		world_3d = _world_node.get_world_3d()
	if world_3d:
		return world_3d.navigation_map
	return RID()


## Get the next path position from `from` to `to` using the navigation server.
## Returns Vector3.ZERO if no path is available.
func get_next_position(from: Vector3, to: Vector3) -> Vector3:
	if not is_ready():
		return to  # Fallback: straight line
	var map: RID = _nav_region.get_region_rid()
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
	if path.size() < 2:
		return to
	return path[1]


## Get the full path from `from` to `to`. Returns empty array if unavailable.
func get_nav_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not is_ready():
		return PackedVector3Array()
	var map: RID = _nav_region.get_region_rid()
	return NavigationServer3D.map_get_path(map, from, to, true)


## Check if a position is reachable on the nav mesh.
## Uses map_get_path to determine reachability — if a path exists, it's reachable.
func is_position_reachable(from: Vector3, to: Vector3) -> bool:
	if not is_ready():
		return true
	var map: RID = _nav_region.get_region_rid()
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
	return path.size() > 0


## Get the closest point on the nav mesh to the given world position.
func get_closest_point(pos: Vector3) -> Vector3:
	if not is_ready():
		return pos
	var map: RID = _nav_region.get_region_rid()
	return NavigationServer3D.map_get_closest_point(map, pos)