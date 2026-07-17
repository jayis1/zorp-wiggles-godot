## Zorp Wiggles — Smart Enemy AI Controller (Phase 10)
## Advanced AI behaviors layered on top of EnemyBase's basic chase AI.
## Implements: line-of-sight checks, flanking, retreat, ambush, pack behavior,
## call-for-help, enrage, and near-death shudder.
##
## Design: This is a utility class (not a Node) that EnemyBase instantiates
## and delegates to. Each behavior is opt-in via @export flags on EnemyBase
## so subclasses (Sentinel, Spitter, Drake) can disable behaviors that don't
## fit their role (e.g. stationary Sentinel doesn't flank).

class_name EnemyAIController

# ─── Behavior State ───────────────────────────────────────────────────────────
# These are owned by the controller but read/written by EnemyBase.

# Line-of-sight
var has_los: bool = false           # True if player is currently visible
var _los_check_timer: float = 0.0
var _los_raycast: RayCast3D = null   # Lazily created

# Flanking
var is_flanking: bool = false
var _flank_angle: float = 0.0        # Current flank offset (degrees, ±)
var _flank_repos_timer: float = 0.0

# Retreat
var is_retreating: bool = false

# Ambush
var is_ambushing: bool = false
var _ambush_cooldown: float = 0.0
var _ambush_rush_timer: float = 0.0  # >0 = speed boost active

# Pack behavior
var pack_allies: Array = []          # Cached list of nearby same-type allies
var _pack_sync_timer: float = 0.0
var _pack_slot_index: int = -1       # Position in surround formation

# Frenzy (triggered by pack behavior when an ally drops below frenzy HP)
var frenzy_timer: float = 0.0
var frenzy_triggered: bool = false
var frenzy_cooldown: float = 0.0

# Call for help
var _call_help_cooldown: float = 0.0
var _has_called_for_help: bool = false

# Enrage
var is_enraged: bool = false
var _enrage_color_t: float = 0.0    # 0→1 transition timer
var _enrage_aura: MeshInstance3D = null

# Near-death shudder
var _shudder_timer: float = 0.0
var _shudder_active: float = 0.0

# ─── Configuration (set by EnemyBase in _ready) ───────────────────────────────
var enable_los: bool = true
var enable_flanking: bool = true
var enable_retreat: bool = true
var enable_ambush: bool = true
var enable_pack: bool = true
var enable_enrage: bool = true
var enable_shudder: bool = true

# Reference to owning enemy (weak reference — use is_instance_valid before access)
var _enemy: WeakRef = null

# ─── Initialization ───────────────────────────────────────────────────────────

func setup(enemy: EnemyBase) -> void:
	_enemy = weakref(enemy)
	_shudder_timer = randf_range(
		GameConstants.AI_SHUDDER_INTERVAL_MIN,
		GameConstants.AI_SHUDDER_INTERVAL_MAX
	)
	_flank_repos_timer = GameConstants.AI_FLANK_REPOSITION_INTERVAL
	# Random initial flank direction
	_flank_angle = 75.0 if randf() < 0.5 else -75.0

# ─── Main Update (called from EnemyBase._physics_process) ─────────────────────

func update(delta: float, enemy: EnemyBase) -> void:
	if enemy.is_dead:
		return

	# Update timers
	_update_timers(delta)

	# Line-of-sight check
	if enable_los:
		_update_los(delta, enemy)

	# Enrage check
	if enable_enrage:
		_update_enrage(delta, enemy)

	# Near-death shudder
	if enable_shudder:
		_update_shudder(delta, enemy)

	# Pack behavior sync
	if enable_pack:
		_update_pack(delta, enemy)

	# Frenzy timer decay
	if frenzy_timer > 0:
		frenzy_timer -= delta
		if frenzy_timer <= 0:
			# Reset speed (EnemyBase reads frenzy_timer for speed mult)
			pass

	# Call for help
	_update_call_help(delta, enemy)

	# Ambush logic
	if enable_ambush:
		_update_ambush(delta, enemy)

	# Flanking reposition timer
	if is_flanking:
		_flank_repos_timer -= delta
		if _flank_repos_timer <= 0:
			_flank_repos_timer = GameConstants.AI_FLANK_REPOSITION_INTERVAL
			_flank_angle = 75.0 if randf() < 0.5 else -75.0

func _update_timers(delta: float) -> void:
	if _call_help_cooldown > 0:
		_call_help_cooldown -= delta
	if _ambush_cooldown > 0:
		_ambush_cooldown -= delta
	if _ambush_rush_timer > 0:
		_ambush_rush_timer -= delta
	if frenzy_cooldown > 0:
		frenzy_cooldown -= delta

# ─── Line-of-Sight ────────────────────────────────────────────────────────────

func _update_los(delta: float, enemy: EnemyBase) -> void:
	_los_check_timer -= delta
	if _los_check_timer > 0:
		return
	_los_check_timer = GameConstants.AI_LOS_CHECK_INTERVAL

	var player: Node3D = enemy._cached_player
	if not player or not is_instance_valid(player):
		has_los = false
		return

	# Use a RayCast3D to check if there's geometry between enemy and player
	if not _los_raycast or not is_instance_valid(_los_raycast):
		_los_raycast = RayCast3D.new()
		_los_raycast.collision_mask = GameConstants.AI_LOS_RAY_COLLISION_MASK
		_los_raycast.enabled = false  # We manually call collide
		enemy.add_child(_los_raycast)

	var from: Vector3 = enemy.global_position + Vector3(0, 0.5, 0)
	var to: Vector3 = player.global_position + Vector3(0, 0.5, 0)
	var dir: Vector3 = to - from

	_los_raycast.global_position = from
	_los_raycast.target_position = _los_raycast.to_local(to)
	_los_raycast.force_raycast_update()

	if _los_raycast.is_colliding():
		# Something is blocking the view
		var collider: Object = _los_raycast.get_collider()
		# If the collider is the player, we have LOS; otherwise blocked
		has_los = (collider == player)
	else:
		# Nothing in the way — clear LOS
		has_los = true

# ─── Enrage ───────────────────────────────────────────────────────────────────

func _update_enrage(delta: float, enemy: EnemyBase) -> void:
	if enemy.max_hp <= 0:
		return
	var hp_ratio: float = float(enemy.hp) / float(enemy.max_hp)

	if not is_enraged and hp_ratio <= GameConstants.AI_ENRAGE_HP_THRESHOLD and enemy.hp > 0:
		is_enraged = true
		_enrage_color_t = 1.0  # Start the color transition
		# Show enrage aura
		_create_enrage_aura(enemy)
		# Proximity warning message (throttled globally)
		if enemy._cached_player and is_instance_valid(enemy._cached_player):
			var dist: float = enemy.global_position.distance_to(enemy._cached_player.global_position)
			if dist < GameConstants.AI_ENRAGE_PROXIMITY_RADIUS:
				var t: float = GameManager.game_time
				if t - GameManager._last_enrage_warning_time > GameConstants.AI_ENRAGE_PROXIMITY_NOTIFY_COOLDOWN:
					GameManager._last_enrage_warning_time = t
					GameManager.add_message("⚠ %s is enraged!" % enemy.enemy_name)
		# Brief red rage burst particle
		ParticleEffects.spawn_explosion(enemy.get_parent(),
			enemy.global_position + Vector3(0, 1, 0),
			Color(1.0, 40.0/255.0, 40.0/255.0), 8, 0.5)

	# Smooth color transition
	if is_enraged and _enrage_color_t > 0:
		_enrage_color_t -= delta / GameConstants.AI_ENRAGE_COLOR_TRANSITION
		_enrage_color_t = maxf(0.0, _enrage_color_t)
		if enemy._material:
			var mix_t: float = (1.0 - _enrage_color_t) * GameConstants.AI_ENRAGE_COLOR_MIX
			var enraged_color: Color = enemy.base_color.lerp(Color(1.0, 0.15, 0.15), mix_t)
			enraged_color.a = enemy._spawn_target_alpha
			enemy._material.albedo_color = enraged_color

	# Pulse the enrage aura
	if is_enraged and _enrage_aura and is_instance_valid(_enrage_aura):
		var pulse: float = 0.5 + 0.5 * sin(GameManager.game_time * 8.0)
		var mat := _enrage_aura.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = 0.3 + 0.2 * pulse
		_enrage_aura.scale = Vector3.ONE * (1.0 + 0.08 * pulse)

func _create_enrage_aura(enemy: EnemyBase) -> void:
	if _enrage_aura and is_instance_valid(_enrage_aura):
		return
	var aura_mesh := SphereMesh.new()
	aura_mesh.radius = enemy.base_scale * 0.65
	aura_mesh.height = enemy.base_scale * 1.3
	_enrage_aura = MeshInstance3D.new()
	_enrage_aura.mesh = aura_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.15, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.1, 0.1)
	mat.emission_energy_multiplier = 0.8
	_enrage_aura.material_override = mat
	enemy.add_child(_enrage_aura)
	_enrage_aura.position = Vector3(0, 0.5, 0)

# ─── Near-Death Shudder ───────────────────────────────────────────────────────

func _update_shudder(delta: float, enemy: EnemyBase) -> void:
	if enemy.max_hp <= 0:
		return
	var hp_ratio: float = float(enemy.hp) / float(enemy.max_hp)

	if hp_ratio > GameConstants.AI_SHUDDER_HP_THRESHOLD or hp_ratio <= 0:
		if _shudder_active > 0:
			_shudder_active = 0
			# Reset scale to base (the enemy's update loop handles this normally)
		return

	if _shudder_active > 0:
		_shudder_active -= delta
		# Apply tremor
		var jitter_x: float = randf_range(-1, 1) * GameConstants.AI_SHUDDER_AMPLITUDE
		var jitter_z: float = randf_range(-1, 1) * GameConstants.AI_SHUDDER_AMPLITUDE
		var s: float = enemy.base_scale
		enemy.scale = Vector3(
			s + jitter_x,
			s * (1.0 - abs(jitter_x) * 0.5),
			s + jitter_z
		)
		return

	_shudder_timer -= delta
	if _shudder_timer <= 0:
		_shudder_timer = randf_range(
			GameConstants.AI_SHUDDER_INTERVAL_MIN,
			GameConstants.AI_SHUDDER_INTERVAL_MAX
		)
		_shudder_active = GameConstants.AI_SHUDDER_DURATION

# ─── Pack Behavior ────────────────────────────────────────────────────────────

func _update_pack(delta: float, enemy: EnemyBase) -> void:
	_pack_sync_timer -= delta
	if _pack_sync_timer > 0:
		return
	_pack_sync_timer = GameConstants.AI_PACK_SYNC_INTERVAL

	# Find nearby same-type allies
	pack_allies.clear()
	var ally_count: int = 0
	for other in GameManager.enemies:
		if other == enemy or not is_instance_valid(other):
			continue
		var other_base: EnemyBase = other as EnemyBase
		if other_base == null or other_base.is_dead:
			continue
		if other_base.enemy_type != enemy.enemy_type:
			continue
		var d: float = enemy.global_position.distance_to(other_base.global_position)
		if d < GameConstants.AI_PACK_RADIUS:
			pack_allies.append(other_base)
			ally_count += 1

	# If we have enough allies, we're in a pack — assign a surround slot
	if ally_count >= GameConstants.AI_PACK_MIN_ALLIES:
		_pack_slot_index = _determine_pack_slot(enemy)
	else:
		_pack_slot_index = -1

	# ── Pack Frenzy Trigger ──
	# If this enemy's HP drops below frenzy threshold, alert nearby allies
	if (not frenzy_triggered and frenzy_cooldown <= 0
			and enemy.hp > 0
			and enemy.max_hp > 0
			and float(enemy.hp) / float(enemy.max_hp) < GameConstants.AI_PACK_FRENZY_HP_THRESHOLD):
		frenzy_triggered = true
		frenzy_cooldown = GameConstants.AI_PACK_FRENZY_COOLDOWN
		_trigger_pack_frenzy(enemy)

func _determine_pack_slot(enemy: EnemyBase) -> int:
	# Determine this enemy's position in the surround formation.
	# We use the enemy's position relative to the player to assign a slot
	# based on angle. Each ally takes a different angular position.
	var player: Node3D = enemy._cached_player
	if not player or not is_instance_valid(player):
		return 0
	var to_player: Vector3 = player.global_position - enemy.global_position
	var my_angle: float = atan2(to_player.z, to_player.x)
	# Sort allies by angle to assign consistent slots
	var angles: Array = []
	angles.append({"angle": my_angle, "is_self": true})
	for ally in pack_allies:
		if not is_instance_valid(ally):
			continue
		var ally_to_player: Vector3 = player.global_position - ally.global_position
		var ally_angle: float = atan2(ally_to_player.z, ally_to_player.x)
		angles.append({"angle": ally_angle, "is_self": false})
	angles.sort_custom(func(a, b): return a.angle < b.angle)
	for i in range(angles.size()):
		if angles[i].is_self:
			return i
	return 0

func _trigger_pack_frenzy(enemy: EnemyBase) -> void:
	var frenzy_count: int = 0
	for ally in pack_allies:
		if not is_instance_valid(ally):
			continue
		var ally_base: EnemyBase = ally as EnemyBase
		if ally_base == null or ally_base.is_dead:
			continue
		var d: float = enemy.global_position.distance_to(ally_base.global_position)
		if d < GameConstants.AI_PACK_FRENZY_RADIUS:
			# Apply frenzy to this ally
			if ally_base.ai_controller:
				ally_base.ai_controller.frenzy_timer = GameConstants.AI_PACK_FRENZY_DURATION
				ally_base.ai_controller.frenzy_triggered = true
				ally_base.ai_controller.frenzy_cooldown = GameConstants.AI_PACK_FRENZY_COOLDOWN
			# Brief bright flash
			if ally_base._material:
				var flash_color := ally_base.base_color.lerp(Color.WHITE, 0.7)
				flash_color.a = ally_base._spawn_target_alpha
				var orig_color := ally_base._material.albedo_color
				ally_base._material.albedo_color = flash_color
				var flash_tween := ally_base.create_tween()
				flash_tween.tween_property(ally_base._material, "albedo_color",
					ally_base.base_color, GameConstants.AI_PACK_FRENZY_FLASH_DURATION)
			frenzy_count += 1

	if frenzy_count >= GameConstants.AI_PACK_FRENZY_MIN_ALLIES:
		GameManager.add_message("⚠ %s pack frenzy! %d allies enraged!" % [enemy.enemy_name, frenzy_count])
		ParticleEffects.spawn_explosion(enemy.get_parent(),
			enemy.global_position + Vector3(0, 1, 0),
			Color(1.0, 100.0/255.0, 50.0/255.0), 8, 0.5)

# ─── Call for Help ────────────────────────────────────────────────────────────

func _update_call_help(delta: float, enemy: EnemyBase) -> void:
	if enemy.max_hp <= 0:
		return
	var hp_ratio: float = float(enemy.hp) / float(enemy.max_hp)

	# Trigger when HP drops below threshold (only once per cooldown)
	if (not _has_called_for_help and _call_help_cooldown <= 0
			and hp_ratio < GameConstants.AI_CALL_HELP_HP_THRESHOLD and enemy.hp > 0):
		_has_called_for_help = true
		_call_help_cooldown = GameConstants.AI_CALL_HELP_COOLDOWN
		_alert_nearby_allies(enemy)

	# Reset call-for-help flag if HP recovers above threshold (allows re-trigger later)
	if hp_ratio > GameConstants.AI_CALL_HELP_HP_THRESHOLD + 0.1:
		_has_called_for_help = false

func _alert_nearby_allies(enemy: EnemyBase) -> void:
	var alerted_count: int = 0
	for other in GameManager.enemies:
		if other == enemy or not is_instance_valid(other):
			continue
		var other_base: EnemyBase = other as EnemyBase
		if other_base == null or other_base.is_dead:
			continue
		var d: float = enemy.global_position.distance_to(other_base.global_position)
		if d < GameConstants.AI_CALL_HELP_RADIUS:
			if not other_base.is_alerted:
				other_base.is_alerted = true
				# Show alert indicator
				if other_base.alert_indicator:
					other_base.alert_indicator.visible = true
					other_base.alert_indicator.text = "!!"
					other_base.alert_indicator_timer = GameConstants.AI_CALL_HELP_ALERT_DURATION
				alerted_count += 1

	if alerted_count > 0:
		GameManager.add_message("%s calls for help! %d allies alerted!" % [enemy.enemy_name, alerted_count])
		ParticleEffects.spawn_explosion(enemy.get_parent(),
			enemy.global_position + Vector3(0, 1.5, 0),
			Color(1.0, 0.8, 0.2), 12, 0.6)

# ─── Ambush ───────────────────────────────────────────────────────────────────

func _update_ambush(delta: float, enemy: EnemyBase) -> void:
	var player: Node3D = enemy._cached_player
	if not player or not is_instance_valid(player):
		return

	if is_ambushing:
		var dist: float = enemy.global_position.distance_to(player.global_position)
		# Stay still and wait
		enemy.velocity = Vector3.ZERO
		# Break ambush when player gets close
		if dist < GameConstants.AI_AMBUSH_TRIGGER_RANGE:
			is_ambushing = false
			_ambush_rush_timer = 1.5  # Brief speed boost on rush
			enemy.is_alerted = true
			if enemy.alert_indicator:
				enemy.alert_indicator.visible = true
				enemy.alert_indicator.text = "!"
				enemy.alert_indicator_timer = 1.0
	else:
		# Try to start ambush if not on cooldown and player is far enough
		if _ambush_cooldown <= 0:
			var dist: float = enemy.global_position.distance_to(player.global_position)
			# Only ambush if we haven't been alerted yet and player is moderately far
			if not enemy.is_alerted and dist > GameConstants.AI_AMBUSH_TRIGGER_RANGE * 2:
				# Check if there's cover nearby (any collider within 5m)
				if _has_cover_nearby(enemy):
					is_ambushing = true
					_ambush_cooldown = GameConstants.AI_AMBUSH_COOLDOWN

func _has_cover_nearby(enemy: EnemyBase) -> bool:
	# Simple check: look for any StaticBody3D within 8m
	var space_state := enemy.get_world_3d().direct_space_state
	var from: Vector3 = enemy.global_position + Vector3(0, 0.5, 0)
	# Check 8 directions
	for i in range(8):
		var angle: float = i * (PI / 4.0)
		var dir: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var to: Vector3 = from + dir * 8.0
		var query := PhysicsRayQueryParameters3D.create(from, to, GameConstants.AI_LOS_RAY_COLLISION_MASK)
		query.exclude = [enemy]
		var result: Dictionary = space_state.intersect_ray(query)
		if result.size() > 0:
			return true
	return false

func get_ambush_speed_mult() -> float:
	if _ambush_rush_timer > 0:
		return GameConstants.AI_AMBUSH_RUSH_SPEED_MULT
	return 1.0

func get_ambush_detect_mult() -> float:
	if is_ambushing:
		return GameConstants.AI_AMBUSH_DETECT_RANGE_MULT
	return 1.0

# ─── Flanking ─────────────────────────────────────────────────────────────────

## Returns a flanking movement direction (or Vector3.ZERO if not flanking).
## Called by EnemyBase when computing desired_velocity for chase.
func get_flank_direction(enemy: EnemyBase, player: Node3D) -> Vector3:
	if not is_flanking:
		return Vector3.ZERO

	var to_player: Vector3 = player.global_position - enemy.global_position
	to_player.y = 0
	var dist: float = to_player.length()
	if dist < 0.1:
		return Vector3.ZERO
	to_player = to_player.normalized()

	# Rotate the approach direction by the flank angle
	var flank_dir: Vector3 = to_player.rotated(Vector3.UP, deg_to_rad(_flank_angle))

	# If too close, circle outward; if too far, approach at the flank angle
	if dist < GameConstants.AI_FLANK_DISTANCE:
		# Circle around — perpendicular movement
		var perp: Vector3 = to_player.rotated(Vector3.UP, PI / 2.0 * signf(_flank_angle))
		return perp
	else:
		return flank_dir

func should_flank() -> bool:
	return is_flanking

## Called by EnemyBase when an enemy first becomes alerted — rolls the flank chance.
func try_start_flank() -> void:
	if not enable_flanking:
		return
	if randf() < GameConstants.AI_FLANK_CHANCE:
		is_flanking = true

# ─── Retreat ──────────────────────────────────────────────────────────────────

## Returns a retreat movement direction (or Vector3.ZERO if not retreating).
func get_retreat_direction(enemy: EnemyBase, player: Node3D) -> Vector3:
	if not is_retreating:
		return Vector3.ZERO

	var from_player: Vector3 = enemy.global_position - player.global_position
	from_player.y = 0
	if from_player.length() < 0.1:
		# Pick a random direction if directly on top of player
		from_player = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	else:
		from_player = from_player.normalized()
	return from_player

func check_retreat(enemy: EnemyBase) -> void:
	if not enable_retreat or enemy.max_hp <= 0:
		return
	var hp_ratio: float = float(enemy.hp) / float(enemy.max_hp)

	if is_retreating:
		# Stop retreating if HP recovers above the heal threshold
		if hp_ratio > GameConstants.AI_RETREAT_HEAL_THRESHOLD:
			is_retreating = false
	else:
		# Start retreating if HP drops below retreat threshold
		if hp_ratio < GameConstants.AI_RETREAT_HP_THRESHOLD:
			is_retreating = true

func is_fleeing() -> bool:
	return is_retreating

# ─── Frenzy Speed Multiplier ──────────────────────────────────────────────────

func get_frenzy_speed_mult() -> float:
	if frenzy_timer > 0:
		return GameConstants.AI_PACK_FRENZY_SPEED_MULT
	return 1.0

func get_enrage_speed_mult() -> float:
	if is_enraged:
		return GameConstants.AI_ENRAGE_SPEED_MULT
	return 1.0

# ─── Cleanup ──────────────────────────────────────────────────────────────────

func cleanup() -> void:
	if _los_raycast and is_instance_valid(_los_raycast):
		_los_raycast.queue_free()
		_los_raycast = null
	if _enrage_aura and is_instance_valid(_enrage_aura):
		_enrage_aura.queue_free()
		_enrage_aura = null
	pack_allies.clear()