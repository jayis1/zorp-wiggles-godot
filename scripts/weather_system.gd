## Zorp Wiggles — Dynamic Weather System (Phase 17)
##
## Cycles through 6 weather states: Clear, Acid Rain, Solar Flare, Fog,
## Thunderstorm, Snow Storm. Each state lasts 35–70s with a 4s cross-fade
## transition. Weather is biased by current biome (thematic affinity) and
## affects gameplay:
##
##   CLEAR         — No effects (baseline)
##   ACID_RAIN     — Damages exposed entities (player & enemies), particles
##   SOLAR_FLARE   — 1.5x fire rate, pulsing orange world light
##   FOG           — Enemy detection range *0.5, denser WorldEnvironment fog
##   THUNDERSTORM  — Random lightning strikes (telegraphed AoE damage zones)
##   SNOW_STORM    — 0.7x movement speed, reduced friction (slidey surfaces)
##
## Weather also biases enemy spawning (Void Wisps in storms, etc.) via
## signals consumed by EnemySpawner, and provides ambient particle effects
## (acid drops, rain, snow, fog motes) attached to the player.
##
## Registered as an autoload singleton (WeatherSystem).

extends Node

# ─── Signals ──────────────────────────────────────────────────────────────────
signal weather_changed(new_weather: int, old_weather: int)
signal weather_transition_started(new_weather: int)
signal weather_transition_ended(weather: int)
signal lightning_strike_requested(pos: Vector3, warn_time: float)
signal weather_timer_changed(time_remaining: float)

# ─── State ────────────────────────────────────────────────────────────────────
var _current_weather: int = GameConstants.Weather.CLEAR
var _next_weather: int = GameConstants.Weather.CLEAR
var _weather_timer: float = 20.0           # Time remaining in current state
var _transition_timer: float = 0.0         # >0 means transitioning
var _is_transitioning: bool = false

# Acid rain tick
var _acid_rain_tick_timer: float = 0.0
# Lightning strike scheduling
var _lightning_timer: float = 8.0
# Solar flare light
var _solar_light: OmniLight3D = null
# Thunderstorm light flash (brief)
var _thunder_flash_light: OmniLight3D = null
# Active weather particle node (follows player)
var _weather_particles: GPUParticles3D = null
# Weather fog override — references the WorldEnvironment for density tweaks
var _world_env: WorldEnvironment = null
var _base_fog_density: float = 0.0
var _target_fog_density: float = 0.0
# Cached player reference
var _cached_player: CharacterBody3D = null
# Pending lightning strike warnings
var _pending_strikes: Array[Dictionary] = []

# ─── Public API ───────────────────────────────────────────────────────────────

func get_current_weather() -> int:
	return _current_weather

func get_next_weather() -> int:
	return _next_weather

func get_weather_timer() -> float:
	return _weather_timer

func is_transitioning() -> bool:
	return _is_transitioning

func get_transition_progress() -> float:
	if not _is_transitioning:
		return 1.0
	return 1.0 - clampf(_transition_timer / GameConstants.WEATHER_TRANSITION_DURATION, 0.0, 1.0)

## Whether the current weather biases toward a given enemy type (spawn weighting).
func get_weather_spawn_bonus_types() -> Array:
	return GameConstants.WEATHER_SPAWN_BONUS.get(_current_weather, [])

## Movement speed multiplier for the current weather (1.0 = normal).
func get_speed_multiplier() -> float:
	match _current_weather:
		GameConstants.Weather.SNOW_STORM:
			return GameConstants.SNOW_STORM_SPEED_MULT
		_:
			return 1.0

## Friction multiplier for the current weather (1.0 = normal).
func get_friction_multiplier() -> float:
	match _current_weather:
		GameConstants.Weather.SNOW_STORM:
			return GameConstants.SNOW_STORM_FRICTION_MULT
		_:
			return 1.0

## Fire rate multiplier for the current weather (1.0 = normal).
func get_fire_rate_multiplier() -> float:
	match _current_weather:
		GameConstants.Weather.SOLAR_FLARE:
			return GameConstants.SOLAR_FLARE_FIRE_RATE_MULT
		_:
			return 1.0

## Enemy detection range multiplier for the current weather (1.0 = normal).
func get_detect_range_multiplier() -> float:
	match _current_weather:
		GameConstants.Weather.FOG:
			return GameConstants.FOG_DETECT_RANGE_MULT
		_:
			return 1.0

## Force-set a weather state (used for testing/debug; skips transition).
func force_weather(weather: int) -> void:
	var old: int = _current_weather
	_end_weather_effects(old)
	_current_weather = weather
	_next_weather = weather
	_weather_timer = randf_range(GameConstants.WEATHER_DURATION_MIN, GameConstants.WEATHER_DURATION_MAX)
	_start_weather_effects(weather)
	weather_changed.emit(weather, old)
	weather_transition_ended.emit(weather)

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Start with clear weather; first transition picks a weather after initial delay
	_weather_timer = 20.0  # Grace period before first weather change
	_lightning_timer = randf_range(GameConstants.THUNDER_LIGHTNING_INTERVAL_MIN, GameConstants.THUNDER_LIGHTNING_INTERVAL_MAX)
	# Defer world env lookup — autoload runs before main scene exists
	call_deferred("_resolve_world_env")

func _resolve_world_env() -> void:
	var main: Node = get_tree().current_scene
	if not main:
		return
	_world_env = main.get_node_or_null("WorldEnvironment")
	if _world_env and _world_env.environment:
		_base_fog_density = _world_env.environment.fog_density
		_target_fog_density = _base_fog_density

func _process(delta: float) -> void:
	if GameManager.is_paused:
		return
	# ── Phase 19: Co-op — keep weather running if either player is alive ──
	if not GameManager.player_is_alive and not (CoOpManager.p2_active and not CoOpManager.p2_is_downed):
		return

	# Smooth fog density toward target
	if _world_env and _world_env.environment:
		var cur: float = _world_env.environment.fog_density
		_world_env.environment.fog_density = lerpf(cur, _target_fog_density, 1.0 - exp(-3.0 * delta))

	# Transition handling
	if _is_transitioning:
		_transition_timer -= delta
		if _transition_timer <= 0:
			_finalize_transition()
		# During transition, still tick the active effects partially
		_tick_weather_effects(delta * 0.5)
		weather_timer_changed.emit(_weather_timer + _transition_timer)
		return

	# Weather countdown
	_weather_timer -= delta
	weather_timer_changed.emit(max(0.0, _weather_timer))
	if _weather_timer <= 0:
		_begin_transition(_pick_next_weather())

	# Per-weather effect ticking
	_tick_weather_effects(delta)

	# Update particle follower position
	_update_weather_particle_position()

	# Update pending lightning strikes
	_update_pending_lightning(delta)

	# Solar flare light pulse
	if _solar_light and is_instance_valid(_solar_light):
		var pulse: float = 0.7 + 0.3 * sin(GameManager.game_time * 3.0)
		_solar_light.light_energy = GameConstants.SOLAR_FLARE_LIGHT_ENERGY * pulse

# ─── Weather state machine ────────────────────────────────────────────────────

func _pick_next_weather() -> int:
	# 40% chance to go clear (recovery breather), else pick a non-clear weather
	# biased by the current biome affinity.
	if randf() < 0.40:
		return GameConstants.Weather.CLEAR

	var candidates: Array[int] = [
		GameConstants.Weather.ACID_RAIN,
		GameConstants.Weather.SOLAR_FLARE,
		GameConstants.Weather.FOG,
		GameConstants.Weather.THUNDERSTORM,
		GameConstants.Weather.SNOW_STORM,
	]
	# Weight: base 1.0, +2.0 if biome-affinity match
	var biome: int = GameManager.current_biome
	var weights: Array[float] = []
	for w in candidates:
		var weight: float = 1.0
		var affinity: Array = GameConstants.WEATHER_BIOME_AFFINITY.get(w, [])
		if biome in affinity:
			weight += 2.0
		# Don't repeat current weather unless nothing else available
		if w == _current_weather:
			weight *= 0.25
		weights.append(weight)

	# Weighted random pick
	var total: float = 0.0
	for w in weights:
		total += w
	var roll: float = randf() * total
	var acc: float = 0.0
	for i in candidates.size():
		acc += weights[i]
		if roll <= acc:
			return candidates[i]
	return candidates[candidates.size() - 1]

func _begin_transition(new_weather: int) -> void:
	_next_weather = new_weather
	_is_transitioning = true
	_transition_timer = GameConstants.WEATHER_TRANSITION_DURATION
	weather_transition_started.emit(new_weather)
	# Pre-load the next weather's particles so they fade in during the transition
	# (handled at finalize for simplicity; here we just signal HUD for transition text)

func _finalize_transition() -> void:
	var old: int = _current_weather
	_end_weather_effects(old)
	_current_weather = _next_weather
	_weather_timer = randf_range(GameConstants.WEATHER_DURATION_MIN, GameConstants.WEATHER_DURATION_MAX)
	_is_transitioning = false
	_start_weather_effects(_current_weather)
	weather_changed.emit(_current_weather, old)
	weather_transition_ended.emit(_current_weather)
	# Announce weather change in message log
	var info: Dictionary = GameConstants.WEATHER_INFO.get(_current_weather, {})
	var name: String = info.get("name", "Unknown")
	if _current_weather == GameConstants.Weather.CLEAR:
		GameManager.add_message("The weather clears up.")
	else:
		GameManager.add_message("☁ Weather: %s" % name)

# ─── Per-weather effect ticking ───────────────────────────────────────────────

func _tick_weather_effects(delta: float) -> void:
	match _current_weather:
		GameConstants.Weather.ACID_RAIN:
			_tick_acid_rain(delta)
		GameConstants.Weather.THUNDERSTORM:
			_tick_thunderstorm(delta)
		# SOLAR_FLARE, FOG, SNOW_STORM effects are passive (multipliers queried
		# by other systems); only light + particles are managed here.
		_:
			pass

func _tick_acid_rain(delta: float) -> void:
	_acid_rain_tick_timer -= delta
	if _acid_rain_tick_timer > 0:
		return
	_acid_rain_tick_timer = GameConstants.ACID_RAIN_TICK_INTERVAL
	# Damage player if exposed (not under shelter — we approximate shelter as
	# the player being close to a decoration with an overhang. Since we can't
	# raycast cheaply every tick, we use a simple y-proximity check against
	# any nearby StaticBody3D above the player via a short ray.)
	var player: CharacterBody3D = _get_player()
	if not player or not is_instance_valid(player):
		return
	var exposed: bool = _is_player_exposed_to_sky()
	var dmg: int = GameConstants.ACID_RAIN_DAMAGE_PER_TICK
	if not exposed:
		dmg = int(dmg * (1.0 - GameConstants.ACID_RAIN_SHELTER_REDUCTION))
	if exposed or dmg > 0:
		GameManager.take_damage(dmg, player.global_position + Vector3(0, 20, 0))
	# Damage enemies too (acid rain is indiscriminate)
	for enemy in GameManager.enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			if enemy.has_method("take_damage_from"):
				enemy.take_damage_from(GameConstants.ACID_RAIN_DAMAGE_PER_TICK, player.global_position if player else Vector3.ZERO)

func _tick_thunderstorm(delta: float) -> void:
	_lightning_timer -= delta
	if _lightning_timer <= 0:
		_lightning_timer = randf_range(
			GameConstants.THUNDER_LIGHTNING_INTERVAL_MIN,
			GameConstants.THUNDER_LIGHTNING_INTERVAL_MAX)
		_schedule_lightning_strike()

func _schedule_lightning_strike() -> void:
	var player: CharacterBody3D = _get_player()
	if not player:
		return
	# Strike at a random position within 18m of the player (not directly on top)
	var angle: float = randf() * TAU
	var dist: float = randf_range(3.0, 18.0)
	var strike_pos: Vector3 = player.global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	_pending_strikes.append({
		"pos": strike_pos,
		"warn_timer": GameConstants.THUNDER_LIGHTNING_WARN_TIME,
		"struck": false,
	})
	lightning_strike_requested.emit(strike_pos, GameConstants.THUNDER_LIGHTNING_WARN_TIME)

func _update_pending_lightning(delta: float) -> void:
	for i in range(_pending_strikes.size() - 1, -1, -1):
		var s: Dictionary = _pending_strikes[i]
		s["warn_timer"] -= delta
		if s["warn_timer"] <= 0 and not s["struck"]:
			s["struck"] = true
			_execute_lightning_strike(s["pos"])
			_pending_strikes.remove_at(i)

func _execute_lightning_strike(pos: Vector3) -> void:
	# Visual: bright white-blue OmniLight flash + particle burst
	var parent: Node = GameManager.world if GameManager.world else get_tree().current_scene
	if parent:
		# Light flash
		var flash: OmniLight3D = OmniLight3D.new()
		flash.light_color = Color(0.7, 0.8, 1.0)
		flash.light_energy = 8.0
		flash.omni_range = 20.0
		parent.add_child(flash)
		flash.global_position = pos + Vector3(0, 8, 0)
		var tw: Tween = create_tween()
		tw.tween_property(flash, "light_energy", 0.0, 0.4).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(flash, "omni_range", 5.0, 0.4)
		tw.chain().tween_callback(flash.queue_free)
		# Particle burst (electrical spark column)
		ParticleEffects.spawn_explosion(parent, pos + Vector3(0, 2, 0), Color(0.6, 0.7, 1.0), 80, 0.6)
		# Camera shake
		if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
			GameManager.camera_rig.add_trauma(0.5)
	# Damage entities in radius
	var radius: float = GameConstants.THUNDER_LIGHTNING_RADIUS
	# Player
	var player: CharacterBody3D = _get_player()
	if player and is_instance_valid(player):
		if player.global_position.distance_to(pos) <= radius:
			GameManager.take_damage(GameConstants.THUNDER_LIGHTNING_DAMAGE, pos)
	# Enemies
	for enemy in GameManager.enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			if enemy.global_position.distance_to(pos) <= radius:
				if enemy.has_method("take_damage_from"):
					enemy.take_damage_from(GameConstants.THUNDER_LIGHTNING_DAMAGE, pos)

# ─── Weather effects start / end ──────────────────────────────────────────────

func _start_weather_effects(weather: int) -> void:
	var parent: Node = GameManager.world if GameManager.world else get_tree().current_scene
	if not parent:
		return
	match weather:
		GameConstants.Weather.ACID_RAIN:
			_weather_particles = _create_weather_particles("acid_rain")
			parent.add_child(_weather_particles)
			_acid_rain_tick_timer = GameConstants.ACID_RAIN_TICK_INTERVAL
		GameConstants.Weather.SOLAR_FLARE:
			_weather_particles = _create_weather_particles("embers")
			parent.add_child(_weather_particles)
			# Pulsing orange light above the player
			_solar_light = OmniLight3D.new()
			_solar_light.light_color = Color(1.0, 0.55, 0.15)
			_solar_light.light_energy = GameConstants.SOLAR_FLARE_LIGHT_ENERGY
			_solar_light.omni_range = 60.0
			parent.add_child(_solar_light)
		GameConstants.Weather.FOG:
			_weather_particles = _create_weather_particles("fog")
			parent.add_child(_weather_particles)
			_target_fog_density = _base_fog_density * GameConstants.FOG_DENSITY_MULT
		GameConstants.Weather.THUNDERSTORM:
			_weather_particles = _create_weather_particles("rain")
			parent.add_child(_weather_particles)
			_lightning_timer = randf_range(3.0, 8.0)  # First strike sooner
		GameConstants.Weather.SNOW_STORM:
			_weather_particles = _create_weather_particles("snow_storm")
			parent.add_child(_weather_particles)
		GameConstants.Weather.CLEAR:
			pass  # No particles; baseline

func _end_weather_effects(weather: int) -> void:
	# Remove weather particles
	if _weather_particles and is_instance_valid(_weather_particles):
		_weather_particles.queue_free()
	_weather_particles = null
	# Remove solar light
	if _solar_light and is_instance_valid(_solar_light):
		_solar_light.queue_free()
	_solar_light = null
	# Reset fog
	_target_fog_density = _base_fog_density
	# Clear pending strikes
	_pending_strikes.clear()

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _get_player() -> CharacterBody3D:
	if _cached_player and is_instance_valid(_cached_player):
		return _cached_player
	_cached_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	return _cached_player

func _update_weather_particle_position() -> void:
	if not _weather_particles or not is_instance_valid(_weather_particles):
		return
	var player: CharacterBody3D = _get_player()
	if player and is_instance_valid(player):
		_weather_particles.global_position = player.global_position + Vector3(0, 12, 0)
	# Solar light follows player too
	if _solar_light and is_instance_valid(_solar_light):
		if player and is_instance_valid(player):
			_solar_light.global_position = player.global_position + Vector3(0, 25, 0)

func _is_player_exposed_to_sky() -> bool:
	# Simple heuristic: raycast upward 30m from the player. If it hits nothing,
	# the player is exposed to the sky (acid rain hits). If it hits something,
	# the player is under shelter.
	var player: CharacterBody3D = _get_player()
	if not player or not is_instance_valid(player):
		return true  # Default: exposed
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var from: Vector3 = player.global_position + Vector3(0, 1, 0)
	var to: Vector3 = from + Vector3(0, 30, 0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var result: Dictionary = space.intersect_ray(query)
	return result.is_empty()

func _create_weather_particles(type: String) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = 200
	p.lifetime = 3.0
	p.one_shot = false
	p.emitting = true
	p.local_coords = false
	var pmat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	var color: Color = Color(1, 1, 1, 0.7)
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.radial_segments = 4
	mesh.rings = 2

	match type:
		"acid_rain":
			p.amount = 300
			p.lifetime = 2.0
			pmat.direction = Vector3(0.1, -1, 0.1)  # Slight diagonal
			pmat.spread = 8.0
			pmat.gravity = Vector3(0, -25, 0)
			pmat.initial_velocity_min = 15.0
			pmat.initial_velocity_max = 22.0
			color = Color(0.5, 1.0, 0.2, 0.6)
			mesh.radius = 0.04
			mesh.height = 0.4  # Stretched = streaking raindrop
		"rain":
			p.amount = 400
			p.lifetime = 2.0
			pmat.direction = Vector3(0, -1, 0)
			pmat.spread = 6.0
			pmat.gravity = Vector3(0, -30, 0)
			pmat.initial_velocity_min = 18.0
			pmat.initial_velocity_max = 28.0
			color = Color(0.6, 0.7, 1.0, 0.5)
			mesh.radius = 0.03
			mesh.height = 0.5
		"snow_storm":
			p.amount = 350
			p.lifetime = 5.0
			pmat.direction = Vector3(0.3, -1, 0.3)  # Blowing wind
			pmat.spread = 20.0
			pmat.gravity = Vector3(0, -3, 0)
			pmat.initial_velocity_min = 3.0
			pmat.initial_velocity_max = 8.0
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_scale = 0.6
			color = Color(0.9, 0.95, 1.0, 0.85)
			mesh.radius = 0.08
			mesh.height = 0.16
		"fog":
			p.amount = 80
			p.lifetime = 8.0
			pmat.direction = Vector3(1, 0, 0)
			pmat.spread = 180.0
			pmat.gravity = Vector3.ZERO
			pmat.initial_velocity_min = 0.5
			pmat.initial_velocity_max = 2.0
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_scale = 0.3
			color = Color(0.75, 0.78, 0.82, 0.25)
			mesh.radius = 1.5  # Large = fog motes
			mesh.height = 3.0
		"embers":
			p.amount = 150
			p.lifetime = 3.5
			pmat.direction = Vector3(0, 1, 0)
			pmat.spread = 25.0
			pmat.gravity = Vector3(0, 4, 0)
			pmat.initial_velocity_min = 2.0
			pmat.initial_velocity_max = 6.0
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_scale = 0.4
			color = Color(1.0, 0.5, 0.1, 0.7)
			mesh.radius = 0.05
			mesh.height = 0.1

	pmat.color = color
	pmat.scale_min = 0.5
	pmat.scale_max = 1.5
	p.process_material = pmat
	var smat: StandardMaterial3D = StandardMaterial3D.new()
	smat.albedo_color = color
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.emission_enabled = true
	smat.emission = color * 0.4
	mesh.material = smat
	p.draw_pass_1 = mesh
	return p