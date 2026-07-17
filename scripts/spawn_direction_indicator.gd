## Zorp Wiggles — Spawn Direction Indicator
## Shows directional arrows on the HUD pointing toward recently spawned enemies
## that are off-screen. Arrows fade in at the screen edge, pointing toward the
## enemy world position, and fade out after a duration.
## Part of Phase 4: Full Combat & Abilities.

extends Control

class_name SpawnDirectionIndicator

# ─── Internal arrow tracking ──────────────────────────────────────────────────
var _arrows: Array[Dictionary] = []  # Each: {pos, timer, arrow_rect, type}

var _arrow_container: Control = null

func _ready() -> void:
	# Connect to enemy spawn signal
	GameManager.enemy_spawned_near.connect(_on_enemy_spawned_near)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create container for arrow elements
	_arrow_container = Control.new()
	_arrow_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrow_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrow_container)

func _process(delta: float) -> void:
	# Update each arrow
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return

	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return

	for i in range(_arrows.size() - 1, -1, -1):
		var arrow_data: Dictionary = _arrows[i]
		arrow_data["timer"] -= delta

		var enemy_pos: Vector3 = arrow_data["pos"]
		var arrow: Label = arrow_data["arrow_rect"] as Label
		if not is_instance_valid(arrow):
			_arrows.remove_at(i)
			continue

		# Check if the enemy is still alive (find it by position proximity)
		var still_relevant: bool = arrow_data["timer"] > 0
		if not still_relevant:
			# Fade out
			var a: float = arrow.modulate.a
			a = max(0.0, a - delta * 4.0)
			arrow.modulate.a = a
			if a <= 0:
				arrow.queue_free()
				_arrows.remove_at(i)
				continue
		else:
			# Position arrow at screen edge pointing toward enemy
			var screen_pos: Vector2 = camera.unproject_position(enemy_pos)
			var is_behind: bool = camera.is_position_behind(enemy_pos)
			var is_on_screen: bool = (
				not is_behind and
				screen_pos.x >= 0 and screen_pos.x <= viewport_size.x and
				screen_pos.y >= 0 and screen_pos.y <= viewport_size.y
			)

			if is_on_screen:
				# Enemy is visible — hide arrow
				arrow.visible = false
			else:
				arrow.visible = true
				# Clamp to screen edge with margin
				var margin: float = 40.0
				var edge_x: float = clampf(screen_pos.x, margin, viewport_size.x - margin)
				var edge_y: float = clampf(screen_pos.y, margin, viewport_size.y - margin)

				# If behind camera, flip direction
				if is_behind:
					edge_x = viewport_size.x - edge_x
					edge_y = viewport_size.y - edge_y

				arrow.position = Vector2(edge_x - 15, edge_y - 15)

				# Calculate rotation to point toward enemy
				var dir_to_enemy: Vector2 = screen_pos - Vector2(edge_x, edge_y)
				if is_behind:
					dir_to_enemy = -dir_to_enemy
				if dir_to_enemy.length() > 1.0:
					var angle: float = dir_to_enemy.angle()
					arrow.rotation = angle + PI / 2.0  # Arrow points up by default, offset by 90°

				# Fade in
				arrow.modulate.a = min(1.0, arrow.modulate.a + delta * 5.0)

func _on_enemy_spawned_near(pos: Vector3, enemy_type: int) -> void:
	# Create a new arrow
	var arrow := Label.new()
	arrow.text = "▲"
	arrow.add_theme_font_size_override("font_size", 24)
	arrow.add_theme_color_override("font_color", GameConstants.SPAWN_DIRECTION_ARROW_COLOR)
	arrow.modulate.a = 0.0
	arrow.size = Vector2(30, 30)
	_arrow_container.add_child(arrow)

	_arrows.append({
		"pos": pos,
		"timer": GameConstants.SPAWN_DIRECTION_INDICATOR_DURATION,
		"arrow_rect": arrow,
		"type": enemy_type,
	})