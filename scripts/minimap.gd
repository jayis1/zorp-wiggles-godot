## Zorp Wiggles — Minimap (Phase 5: HUD Polish)
## Top-down minimap with color-coded biome tiles, enemy dots, player dot,
## collectible dots, portal dots, and trader dots. Rendered via _draw().
## Toggle with the "minimap" input action (M key).
## Inspired by the minimap system in Ursina game.py.

extends Control

class_name Minimap

# ─── Internal State ───────────────────────────────────────────────────────────
var _minimap_visible: bool = true
var _terrain_refresh_timer: float = 0.0
var _dot_refresh_timer: float = 0.0
var _world_ref: Node3D = null
var _grid: Array[int] = []
var _grid_size: int = 0
var _tile_scale: float = 4.0
var _biome_colors: Dictionary = {}

# ─── Minimap geometry (pixels) ────────────────────────────────────────────────
var _size: float = GameConstants.MINIMAP_SIZE
var _margin: float = GameConstants.MINIMAP_MARGIN
var _half_size: float = GameConstants.MINIMAP_SIZE / 2.0

func _ready() -> void:
	# Anchor to bottom-right corner
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Set the control size
	offset_left = -(_size + _margin)
	offset_top = -(_size + _margin)
	offset_right = -_margin
	offset_bottom = -_margin

	# Resolve world reference and biome colors
	call_deferred("_resolve_world_ref")

func _resolve_world_ref() -> void:
	_world_ref = GameManager.world
	if _world_ref and "grid" in _world_ref:
		_grid = _world_ref.grid
		_grid_size = _world_ref.GRID_SIZE
		_tile_scale = _world_ref.TILE_SIZE
	# Copy biome colors from WorldGenerator's const dictionary
	if _world_ref and "BIOME_COLORS" in _world_ref:
		_biome_colors = _world_ref.BIOME_COLORS

func _process(delta: float) -> void:
	if not _minimap_visible:
		return
	_terrain_refresh_timer -= delta
	_dot_refresh_timer -= delta
	# Dots update frequently for smooth tracking
	if _dot_refresh_timer <= 0:
		_dot_refresh_timer = GameConstants.MINIMAP_DOT_REFRESH_INTERVAL
		queue_redraw()
	# Terrain refresh is less frequent (tiles rarely change)
	if _terrain_refresh_timer <= 0:
		_terrain_refresh_timer = GameConstants.MINIMAP_REFRESH_INTERVAL
		# Re-sync grid in case world was regenerated
		if _world_ref and "grid" in _world_ref and _grid.size() != _world_ref.grid.size():
			_grid = _world_ref.grid
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("minimap"):
		_minimap_visible = not _minimap_visible
		visible = _minimap_visible

func _draw() -> void:
	if not _minimap_visible:
		return

	var draw_origin := Vector2.ZERO
	var minimap_rect := Rect2(draw_origin, Vector2(_size, _size))

	# Draw background
	draw_rect(minimap_rect, GameConstants.MINIMAP_BG_COLOR, true)

	# Draw biome terrain tiles (downsampled, centered on player)
	if _grid.size() > 0 and _grid_size > 0 and _biome_colors.size() > 0:
		_draw_terrain(minimap_rect)

	# Draw border frame
	draw_rect(minimap_rect, GameConstants.MINIMAP_BORDER_COLOR, false, 2.0)

	# Draw dots: portals, traders, collectibles, enemies, boss, player
	_draw_entity_dots(minimap_rect)

func _draw_terrain(rect: Rect2) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var player_world_pos: Vector2 = Vector2.ZERO
	if player and is_instance_valid(player):
		player_world_pos = Vector2(player.global_position.x, player.global_position.z)

	# World units per minimap pixel
	var pixel_per_world: float = _size / GameConstants.MINIMAP_VIEW_RANGE
	var half_world_extent: float = GameConstants.MINIMAP_VIEW_RANGE / 2.0

	# Player world position
	var px_x: float = player_world_pos.x
	var px_z: float = player_world_pos.y

	var tile_size_pixels: float = _tile_scale * pixel_per_world
	if tile_size_pixels < 2.0:
		tile_size_pixels = 4.0

	# Iterate over visible tile range
	var min_wx: float = px_x - half_world_extent
	var max_wx: float = px_x + half_world_extent
	var min_wz: float = px_z - half_world_extent
	var max_wz: float = px_z + half_world_extent

	var start_tx: int = int((min_wx / _tile_scale) + _grid_size / 2.0)
	var end_tx: int = int((max_wx / _tile_scale) + _grid_size / 2.0)
	var start_tz: int = int((min_wz / _tile_scale) + _grid_size / 2.0)
	var end_tz: int = int((max_wz / _tile_scale) + _grid_size / 2.0)

	start_tx = maxi(start_tx - 1, 0)
	end_tx = mini(end_tx + 1, _grid_size - 1)
	start_tz = maxi(start_tz - 1, 0)
	end_tz = mini(end_tz + 1, _grid_size - 1)

	for tx in range(start_tx, end_tx + 1):
		for tz in range(start_tz, end_tz + 1):
			var idx: int = tx * _grid_size + tz
			if idx < 0 or idx >= _grid.size():
				continue
			var biome: int = _grid[idx]
			var color: Color = _biome_colors.get(biome, Color(0.3, 0.3, 0.3))
			# World position of this tile center
			var wx: float = (tx - _grid_size / 2.0) * _tile_scale + _tile_scale / 2.0
			var wz: float = (tz - _grid_size / 2.0) * _tile_scale + _tile_scale / 2.0
			# Minimap position relative to player
			var mx: float = (wx - px_x) * pixel_per_world + _half_size
			var mz: float = (wz - px_z) * pixel_per_world + _half_size
			# Draw tile
			var tile_rect := Rect2(mx - tile_size_pixels / 2.0, mz - tile_size_pixels / 2.0,
				tile_size_pixels, tile_size_pixels)
			draw_rect(tile_rect, color, true)

func _world_to_mini(wx: float, wz: float, px: float, pz: float, pixel_per_world: float) -> Vector2:
	var mx: float = (wx - px) * pixel_per_world + _half_size
	var mz: float = (wz - pz) * pixel_per_world + _half_size
	return Vector2(mx, mz)

func _draw_entity_dots(rect: Rect2) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return

	var px: float = player.global_position.x
	var pz: float = player.global_position.z
	var pixel_per_world: float = _size / GameConstants.MINIMAP_VIEW_RANGE

	# ── Collectible dots (small cyan) ──
	for collectible in GameManager.collectibles:
		if not is_instance_valid(collectible):
			continue
		var pos: Vector2 = _world_to_mini(collectible.global_position.x, collectible.global_position.z, px, pz, pixel_per_world)
		if _is_in_rect(pos, rect):
			draw_circle(pos, 1.5, GameConstants.MINIMAP_COLLECTIBLE_DOT_COLOR)

	# ── Portal dots (cyan squares) ──
	for portal in get_tree().get_nodes_in_group("portals"):
		if not is_instance_valid(portal):
			continue
		var pos: Vector2 = _world_to_mini(portal.global_position.x, portal.global_position.z, px, pz, pixel_per_world)
		if _is_in_rect(pos, rect):
			draw_rect(Rect2(pos.x - 2.5, pos.y - 2.5, 5.0, 5.0), GameConstants.MINIMAP_PORTAL_DOT_COLOR, true)

	# ── Phase 14: Rift dots (pulsing purple diamonds) ──
	for rift in get_tree().get_nodes_in_group("rifts"):
		if not is_instance_valid(rift):
			continue
		var rpos: Vector2 = _world_to_mini(rift.global_position.x, rift.global_position.z, px, pz, pixel_per_world)
		if _is_in_rect(rpos, rect):
			var rift_color: Color = Color(0.7, 0.3, 1.0)
			# Draw a diamond shape
			var s: float = 4.0
			var pts: PackedVector2Array = PackedVector2Array([
				Vector2(rpos.x, rpos.y - s),
				Vector2(rpos.x + s, rpos.y),
				Vector2(rpos.x, rpos.y + s),
				Vector2(rpos.x - s, rpos.y),
			])
			draw_colored_polygon(pts, rift_color)

	# ── Trader dots (orange) ──
	for trader in get_tree().get_nodes_in_group("trader"):
		if not is_instance_valid(trader):
			continue
		var pos: Vector2 = _world_to_mini(trader.global_position.x, trader.global_position.z, px, pz, pixel_per_world)
		if _is_in_rect(pos, rect):
			draw_circle(pos, 2.5, GameConstants.MINIMAP_TRADER_DOT_COLOR)

	# ── Enemy dots (red, boss = magenta) ──
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue
		var pos: Vector2 = _world_to_mini(enemy.global_position.x, enemy.global_position.z, px, pz, pixel_per_world)
		if _is_in_rect(pos, rect):
			var is_boss: bool = false
			if "enemy_type" in enemy and enemy.enemy_type == GameConstants.EnemyType.DRAKE:
				is_boss = true
			if is_boss:
				draw_circle(pos, 4.0, GameConstants.MINIMAP_BOSS_DOT_COLOR)
				draw_circle(pos, 6.0, Color(GameConstants.MINIMAP_BOSS_DOT_COLOR.r,
					GameConstants.MINIMAP_BOSS_DOT_COLOR.g, GameConstants.MINIMAP_BOSS_DOT_COLOR.b, 0.3))
			else:
				draw_circle(pos, 2.0, GameConstants.MINIMAP_ENEMY_DOT_COLOR)

	# ── Player dot (white, center) with facing direction line ──
	var center := Vector2(_half_size, _half_size)
	draw_circle(center, 3.0, GameConstants.MINIMAP_PLAYER_DOT_COLOR)
	# Direction indicator based on player's facing
	var facing := Vector2(0, -1)  # Default: up
	if player.has_method("get_shoot_direction"):
		var shoot_dir: Vector3 = player.get_shoot_direction()
		facing = Vector2(shoot_dir.x, shoot_dir.z).normalized()
	var dir_end := center + facing * 8.0
	draw_line(center, dir_end, Color.WHITE, 1.5)

func _is_in_rect(pos: Vector2, rect: Rect2) -> bool:
	return pos.x >= rect.position.x and pos.x <= rect.position.x + rect.size.x \
		and pos.y >= rect.position.y and pos.y <= rect.position.y + rect.size.y