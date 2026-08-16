## Zorp Wiggles — Environmental Hazard (Phase 26: World Life)
## Persistent world hazards scattered across hostile biomes. Unlike arena
## hazards (which are tied to a boss fight and queue_free on expiry), these
## cycle through a telegraph → active → cooldown loop indefinitely, adding
## ongoing danger to exploration.
##
## Four types (see ENV_HAZARD_TYPES in game_constants.gd):
##   lava_geyser  — erupts in LAVA / VOLCANO_CORE biomes, damage + knockback
##   falling_rock — drops from above in UNDERGROUND / ANCIENT_RUINS / CRYSTAL_CAVERNS
##   toxic_vent   — poisonous gas puff in TOXIC_BOG / SWAMP, lower damage
##   ice_patch    — slippery surface in SNOW / CRYSTAL_CAVERNS, no damage, slide
##
## All colors use Godot 0-1 range.

extends Node3D

class_name EnvironmentalHazard

signal hazard_activated(hazard: EnvironmentalHazard)

# ─── Export ──────────────────────────────────────────────────────────────────
@export var hazard_type_name: String = "lava_geyser"
@export var damage: int = 18
@export var radius: float = 3.5
@export var knockback: float = 12.0

# ─── State machine ───────────────────────────────────────────────────────────
enum State { IDLE, TELEGRAPH, ACTIVE, COOLDOWN }
var _state: int = State.IDLE
var _timer: float = 0.0
var _has_dealt_damage: bool = false
var _config: Dictionary = {}
var _time: float = 0.0
var _toxic_tick_timer: float = 0.0

# ── Ice frost trail timer ── Spawns small frost particles while the player
#    slides on ice, giving the slide a visual "skating" trail. The timer
#    controls how often a frost sparkle spawns (every ~0.08s).
var _ice_frost_timer: float = 0.0
const ICE_FROST_INTERVAL: float = 0.08
# Cache the physics delta for the ice frost timer (set in _process)
var _physics_delta: float = 0.0

# ─── Visual nodes ─────────────────────────────────────────────────────────────
var _telegraph_mesh: MeshInstance3D
var _hazard_mesh: MeshInstance3D
var _hazard_light: OmniLight3D
var _particles: GPUParticles3D
var _damage_area: Area3D
var _damage_shape: CollisionShape3D
var _mat: StandardMaterial3D
var _telegraph_mat: StandardMaterial3D
var _cached_player: Node3D = null

func _ready() -> void:
	add_to_group("env_hazard")
	# Look up the config for this hazard type.
	_config = _lookup_config(hazard_type_name)
	if _config.is_empty():
		push_warning("[EnvHazard] Unknown hazard type: %s" % hazard_type_name)
		queue_free()
		return
	damage = int(_config.get("damage", damage))
	_build_visuals()
	# Start in idle — wait briefly before the first cycle.
	_timer = randf_range(1.0, 4.0)
	# ── Spawn-in pop animation ── the hazard's root node scales up from
	#    zero so the hazard "emerges" into the world rather than popping
	#    in at full scale. Ease-out-back gives a subtle overshoot. The
	#    telegraph mesh and hazard mesh start hidden (visible = false),
	#    so only the root scale matters for the initial appearance.
	#    Matches the treasure chest and lore stone spawn language.
	scale = Vector3.ZERO
	var spawn_tween := create_tween()
	spawn_tween.tween_property(self, "scale", Vector3.ONE, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _lookup_config(type_name: String) -> Dictionary:
	for entry in GameConstants.ENV_HAZARD_TYPES:
		if entry.get("type", "") == type_name:
			return entry
	return {}

func _build_visuals() -> void:
	var col: Color = _config.get("color", Color(1.0, 0.4, 0.1))
	var glow: Color = _config.get("glow_color", Color(1.0, 0.6, 0.2))

	# Telegraph — a flat ground ring that pulses before activation.
	_telegraph_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.0, radius * 2.0)
	_telegraph_mesh.mesh = plane
	_telegraph_mesh.position = Vector3(0, 0.06, 0)
	_telegraph_mat = StandardMaterial3D.new()
	_telegraph_mat.albedo_color = Color(col.r, col.g, col.b, 0.0)
	_telegraph_mat.emission_enabled = true
	_telegraph_mat.emission = glow
	_telegraph_mat.emission_energy_multiplier = 0.0
	_telegraph_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_telegraph_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_telegraph_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_telegraph_mesh.material_override = _telegraph_mat
	_telegraph_mesh.visible = false
	add_child(_telegraph_mesh)

	# Hazard mesh — type-specific.
	_hazard_mesh = MeshInstance3D.new()
	_hazard_mesh.visible = false
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = col
	_mat.emission_enabled = true
	_mat.emission = glow
	_mat.emission_energy_multiplier = 1.5
	_mat.rim_enabled = true
	_mat.rim = 0.7
	_mat.rim_tint = 0.8
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_hazard_mesh.material_override = _mat
	add_child(_hazard_mesh)
	_build_hazard_mesh()

	# Light — flashes during active phase.
	_hazard_light = OmniLight3D.new()
	_hazard_light.position = Vector3(0, 1.5, 0)
	_hazard_light.omni_range = radius * 3.0
	_hazard_light.light_color = glow
	_hazard_light.light_energy = 0.0
	add_child(_hazard_light)

	# Damage area (disabled unless active).
	_damage_area = Area3D.new()
	_damage_shape = CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 4.0
	_damage_shape.shape = cyl
	_damage_area.add_child(_damage_shape)
	_damage_area.monitoring = false
	add_child(_damage_area)

func _build_hazard_mesh() -> void:
	# Type-specific mesh shape.
	match hazard_type_name:
		"lava_geyser":
			# Tall narrow cylinder (the geyser column).
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.3
			cyl.bottom_radius = 0.8
			cyl.height = 4.0
			_hazard_mesh.mesh = cyl
			_hazard_mesh.position = Vector3(0, 2.0, 0)
		"falling_rock":
			# A rough sphere (the boulder).
			var sphere := SphereMesh.new()
			sphere.radius = 0.8
			sphere.height = 1.6
			_hazard_mesh.mesh = sphere
			_hazard_mesh.position = Vector3(0, 1.0, 0)
		"toxic_vent":
			# A wide flat disc (the gas cloud).
			var disc := CylinderMesh.new()
			disc.top_radius = radius
			disc.bottom_radius = radius
			disc.height = 0.4
			_hazard_mesh.mesh = disc
			_hazard_mesh.position = Vector3(0, 0.8, 0)
		"ice_patch":
			# A flat translucent plane (the icy surface).
			var plane := PlaneMesh.new()
			plane.size = Vector2(radius * 2.0, radius * 2.0)
			_hazard_mesh.mesh = plane
			_hazard_mesh.position = Vector3(0, 0.1, 0)
		_:
			var sphere := SphereMesh.new()
			sphere.radius = 0.6
			sphere.height = 1.2
			_hazard_mesh.mesh = sphere

func _process(delta: float) -> void:
	if GameManager.is_paused:
		return
	_time += delta
	_physics_delta = delta  # Cached for ice frost timer in _apply_ice_slide
	match _state:
		State.IDLE:
			_update_idle(delta)
		State.TELEGRAPH:
			_update_telegraph(delta)
		State.ACTIVE:
			_update_active(delta)
		State.COOLDOWN:
			_update_cooldown(delta)

# ─── State updates ───────────────────────────────────────────────────────────

func _update_idle(delta: float) -> void:
	_timer -= delta
	if _timer <= 0:
		_start_telegraph()

func _start_telegraph() -> void:
	_state = State.TELEGRAPH
	_timer = GameConstants.ENV_HAZARD_TELEGRAPH_TIME
	_has_dealt_damage = false
	_anticip_sfx_played = false
	_telegraph_mesh.visible = true
	# For falling_rock, show the rock dropping during telegraph.
	if hazard_type_name == "falling_rock":
		_hazard_mesh.visible = true
		_hazard_mesh.position.y = 12.0  # Start high.

# ── Anticipation flash ── In the final 20% of the telegraph, the ring snaps
#    to white and peaks in emission — a classic "tell" that telegraphs the
#    exact activation moment so the player can dodge. Same technique used
#    by spawn_warning.gd. Also plays a warp SFX once at the flash onset so
#    off-screen hazards the player can't see still register audibly.
const _ANTICIP_FRAC: float = 0.80
const _FLASH_COLOR: Color = Color(1.0, 1.0, 1.0)
var _anticip_sfx_played: bool = false

func _update_telegraph(delta: float) -> void:
	_timer -= delta
	var progress: float = 1.0 - (_timer / GameConstants.ENV_HAZARD_TELEGRAPH_TIME)
	progress = clampf(progress, 0.0, 1.0)
	# ── Telegraph intensity ──
	# Pre-anticipation: multi-octave pulse (two sines at incommensurate
	# frequencies) for an organic, non-rhythmic flicker instead of the
	# mechanical single-sine blink. Matches the spawn_warning telegraph
	# language so world hazards and enemy spawns read as the same visual
	# grammar. Anticipation phase: ramp to full white with ease-in-quad so
	# the flash accelerates into the activation moment.
	if _telegraph_mat:
		if progress < _ANTICIP_FRAC:
			var pulse: float = 0.3 + 0.3 * (sin(_time * 14.0) * 0.7 + sin(_time * 21.0) * 0.3)
			var fade: float = 1.0 - (progress / _ANTICIP_FRAC) * 0.3
			var col: Color = _config.get("color", Color(1.0, 0.4, 0.1))
			_telegraph_mat.albedo_color = Color(col.r, col.g, col.b, pulse * fade)
			_telegraph_mat.emission_energy_multiplier = pulse * fade * 1.5
		else:
			# Anticipation flash — ramp to white, accelerate into activation
			var flash_t: float = (progress - _ANTICIP_FRAC) / (1.0 - _ANTICIP_FRAC)
			var flash_intensity: float = flash_t * flash_t  # ease-in quad
			var base_col: Color = _config.get("color", Color(1.0, 0.4, 0.1))
			var glow_col: Color = _config.get("glow_color", Color(1.0, 0.6, 0.2))
			_telegraph_mat.albedo_color = base_col.lerp(_FLASH_COLOR, flash_intensity)
			_telegraph_mat.albedo_color.a = 0.6 + 0.4 * flash_intensity
			_telegraph_mat.emission_energy_multiplier = 1.5 + flash_intensity * 3.0
			_telegraph_mat.emission = glow_col.lerp(_FLASH_COLOR, flash_intensity)
			# Play the warp SFX once at the start of the anticipation flash
			if not _anticip_sfx_played:
				_anticip_sfx_played = true
				if AudioManager:
					AudioManager.play_sfx(AudioManager.SFX_RIFT)
	# Falling rock: drop the boulder during telegraph.
	if hazard_type_name == "falling_rock" and _hazard_mesh:
		var t: float = 1.0 - (_timer / GameConstants.ENV_HAZARD_TELEGRAPH_TIME)
		_hazard_mesh.position.y = lerpf(12.0, 1.0, t * t)
	if _timer <= 0:
		_activate()

func _activate() -> void:
	_state = State.ACTIVE
	_timer = GameConstants.ENV_HAZARD_ACTIVE_TIME
	_toxic_tick_timer = 0.7
	_telegraph_mesh.visible = false
	_hazard_mesh.visible = true
	_damage_area.monitoring = true
	# ── Scale-in pop: the hazard mesh snaps in from a small scale and
	#    overshoots to full size with an ease-out-back curve, so the
	#    eruption/impact reads as an explosive birth rather than popping
	#    in at full size. Falling rocks skip this (the boulder has
	#    already descended from above during telegraph — the descent IS
	#    the scale-in). Matches the spawn_warning final-pop language.
	if _hazard_mesh and hazard_type_name != "falling_rock":
		_hazard_mesh.scale = Vector3(0.1, 0.1, 0.1)
		var pop_tween := _hazard_mesh.create_tween()
		pop_tween.tween_property(_hazard_mesh, "scale", Vector3.ONE, 0.15) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_BACK)
	# Light flash.
	if _hazard_light:
		_hazard_light.light_energy = 4.0
	# Impact particle burst — type-specific color for a satisfying "eruption" feel.
	var parent: Node = get_parent()
	if parent and ParticleEffects:
		var burst_col: Color = _config.get("glow_color", Color(1.0, 0.6, 0.2))
		match hazard_type_name:
			"lava_geyser":
				# Tall vertical eruption burst (more particles, upward bias).
				ParticleEffects.spawn_explosion(parent, global_position + Vector3(0, 2.0, 0),
					burst_col, 28, 0.7)
			"falling_rock":
				# Dust + debris burst on impact.
				ParticleEffects.spawn_death_poof(parent, global_position + Vector3(0, 0.8, 0),
					burst_col, 1.0)
				ParticleEffects.spawn_explosion(parent, global_position + Vector3(0, 0.8, 0),
					burst_col, 18, 0.5)
			"toxic_vent":
				# Greenish gas puff.
				ParticleEffects.spawn_death_poof(parent, global_position + Vector3(0, 1.0, 0),
					burst_col, 0.8)
			"ice_patch":
				# Subtle frost shimmer — small sparkle, no big burst.
				ParticleEffects.spawn_pickup_sparkle(parent,
					global_position + Vector3(0, 0.3, 0), burst_col)
	# Camera shake for impactful hazards.
	if hazard_type_name == "lava_geyser" or hazard_type_name == "falling_rock":
		var cam: Node3D = GameManager.camera_rig
		if cam and cam.has_method("add_trauma"):
			cam.add_trauma(0.2)
	# Deal damage immediately on activation (one-shot for geyser/rock/vent).
	if hazard_type_name != "ice_patch":
		_deal_damage_in_radius()
	# Audio cue — distinct SFX per hazard type for identifiable audio feedback
	match hazard_type_name:
		"lava_geyser":
			AudioManager.play_sfx(AudioManager.SFX_EXPLOSION)
		"falling_rock":
			AudioManager.play_sfx(AudioManager.SFX_BREAKABLE)
		"toxic_vent":
			AudioManager.play_sfx(AudioManager.SFX_SHOOT_POISON)
		"ice_patch":
			AudioManager.play_sfx(AudioManager.SFX_SHOOT_FREEZE)
	hazard_activated.emit(self)

func _update_active(delta: float) -> void:
	_timer -= delta
	# Flicker the light for energy.
	if _hazard_light:
		_hazard_light.light_energy = 3.0 + randf() * 2.0
	# For toxic_vent, tick damage over time.
	if hazard_type_name == "toxic_vent":
		# Re-deal damage every 0.7s during active phase.
		_toxic_tick_timer -= delta
		if _toxic_tick_timer <= 0:
			_deal_damage_in_radius()
			_toxic_tick_timer = 0.7
	# For ice_patch, apply slide effect to the player.
	if hazard_type_name == "ice_patch":
		_apply_ice_slide()
	if _timer <= 0:
		_start_cooldown()

func _start_cooldown() -> void:
	_state = State.COOLDOWN
	_timer = GameConstants.ENV_HAZARD_COOLDOWN_TIME
	_hazard_mesh.visible = false
	_hazard_mesh.scale = Vector3.ONE  # Reset for next cycle's scale-in pop
	_damage_area.monitoring = false
	if _hazard_light:
		# Fade the light out.
		var t := create_tween()
		t.tween_property(_hazard_light, "light_energy", 0.0, 0.4) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func _update_cooldown(delta: float) -> void:
	_timer -= delta
	if _timer <= 0:
		# Start a new cycle.
		_state = State.IDLE
		_timer = randf_range(1.0, 3.0)

# ─── Damage ───────────────────────────────────────────────────────────────────

func _deal_damage_in_radius() -> void:
	if hazard_type_name == "ice_patch":
		return  # No damage — only slide effect.
	var center: Vector3 = global_position
	# Damage P1.
	var player: Node3D = GameManager.player
	if player and is_instance_valid(player) and player.is_in_group("player") and not GameManager.player_is_downed:
		var dist: float = player.global_position.distance_to(center)
		if dist < radius:
			GameManager.take_damage(damage, center)
			if knockback > 0:
				_apply_knockback(player, center, knockback)
	# Damage P2 in co-op.
	if CoOpManager.is_coop_active() and CoOpManager.p2_node and is_instance_valid(CoOpManager.p2_node):
		if not CoOpManager.p2_is_downed:
			var p2_dist: float = CoOpManager.p2_node.global_position.distance_to(center)
			if p2_dist < radius:
				CoOpManager.p2_take_damage(damage, center)
				if knockback > 0:
					_apply_knockback(CoOpManager.p2_node, center, knockback)

func _apply_knockback(target: Node3D, center: Vector3, force: float) -> void:
	if not target is CharacterBody3D:
		return
	var dir: Vector3 = (target.global_position - center)
	dir.y = 0.3  # Slight upward arc.
	dir = dir.normalized()
	(target as CharacterBody3D).velocity += dir * force

func _apply_ice_slide() -> void:
	# Apply a slippery slide effect to the player when standing on the ice patch.
	# Instead of pushing outward from center (which felt like a fan, not ice),
	# we amplify the player's existing horizontal velocity so they keep sliding
	# in their current movement direction with reduced friction — the classic
	# "ice physics" feel. If the player is standing still, a very small outward
	# drift is applied so they slowly slide off the patch (preventing them from
	# standing safely on ice indefinitely). A frost particle trail spawns at
	# intervals to give the slide a visual "skating" read.
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = GameManager.player
	if not _cached_player:
		return
	var dist: float = _cached_player.global_position.distance_to(global_position)
	if dist > radius:
		return
	if not (_cached_player is CharacterBody3D):
		return
	var cb := _cached_player as CharacterBody3D
	var horiz_vel := Vector2(cb.velocity.x, cb.velocity.z)
	# If the player is moving, amplify their existing momentum (ice = less
	# friction = more slide). The amplification factor is small per frame but
	# compounds across physics ticks, creating a gradual acceleration that
	# feels like losing traction on ice. The max speed is capped so the slide
	# doesn't become uncontrollable.
	if horiz_vel.length() > 0.5:
		# Amplify existing momentum — 3% per frame at 60fps ≈ 82%/sec
		var amplification: float = 1.03
		# Cap the amplified speed so the slide doesn't runaway
		var max_slide_speed: float = GameConstants.PLAYER_SPEED * 1.6
		var new_horiz := horiz_vel * amplification
		if new_horiz.length() > max_slide_speed:
			new_horiz = new_horiz.normalized() * max_slide_speed
		cb.velocity.x = new_horiz.x
		cb.velocity.z = new_horiz.y
		# Frost trail particles while sliding at speed
		_ice_frost_timer -= _physics_delta
		if _ice_frost_timer <= 0.0 and ParticleEffects:
			ParticleEffects.spawn_pickup_sparkle(
				get_parent(),
				cb.global_position + Vector3(0, 0.2, 0),
				Color(0.7, 0.9, 1.0))
			_ice_frost_timer = ICE_FROST_INTERVAL
	else:
		# Player is nearly stationary — apply a tiny outward drift so they
		# can't stand safely on the ice. Much weaker than the old push.
		var slide_dir: Vector3 = (cb.global_position - global_position)
		slide_dir.y = 0.0
		if slide_dir.length() < 0.1:
			slide_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		slide_dir = slide_dir.normalized()
		cb.velocity += slide_dir * 1.5  # Gentle drift (was 4.0 — too forceful)