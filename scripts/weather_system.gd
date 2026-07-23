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
# ── Phase 28: Weather Expansion signals ──
signal weather_combo_started(combo_weather: int, primary_weather: int)
signal weather_combo_ended(combo_weather: int)
signal emp_pulse_triggered()              # Magnetic Storm EMP fired
signal gravity_shift_started(direction: int)  # -1 = upward, 1 = downward
signal gravity_shift_ended()
signal dimensional_shift_triggered()      # Dimensional Storm forced shift

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

# ── Phase 28: Weather Expansion state ──
# Blood Moon — red ambient light
var _blood_moon_light: OmniLight3D = null
# Eclipse — darkness ambient override
var _eclipse_light: OmniLight3D = null
var _eclipse_base_ambient_energy: float = 1.0
# Pollen Storm — heal tick + soft light
var _pollen_tick_timer: float = 0.0
var _pollen_light: OmniLight3D = null
# Magnetic Storm — EMP pulse scheduling + dash disable
var _emp_timer: float = 10.0
var _emp_disable_timer: float = 0.0
var _magnetic_light: OmniLight3D = null
# Gravity Anomaly — periodic gravity shifts
var _gravity_shift_timer: float = 0.0
var _gravity_shift_active: bool = false
var _gravity_shift_remaining: float = 0.0
var _gravity_anomaly_force: float = 0.0
var _gravity_light: OmniLight3D = null
# Dimensional Storm — rift spawn + forced dimension shifts
var _dim_rift_timer: float = 8.0
var _dim_shift_timer: float = 15.0
var _dimensional_light: OmniLight3D = null
# Weather combo — a second weather type overlapping the primary
var _combo_weather: int = GameConstants.Weather.CLEAR
var _combo_timer: float = 0.0  # Time remaining in combo overlap

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
## Applies to the PLAYER. Sandstorm slows the player (fighting wind).
func get_speed_multiplier() -> float:
	match _current_weather:
		GameConstants.Weather.SNOW_STORM:
			return GameConstants.SNOW_STORM_SPEED_MULT
		GameConstants.Weather.SANDSTORM:
			return GameConstants.SANDSTORM_PLAYER_SPEED_MULT
		_:
			return 1.0

## Enhancement: Enemy speed multiplier for the current weather (1.0 = normal).
## Sandstorm energizes enemies (25% faster). Snow storm slows enemies too (0.7x).
## Other weather types don't affect enemy speed.
func get_enemy_speed_multiplier() -> float:
	match _current_weather:
		GameConstants.Weather.SNOW_STORM:
			return GameConstants.SNOW_STORM_SPEED_MULT  # Enemies also slowed in snow
		GameConstants.Weather.SANDSTORM:
			return GameConstants.SANDSTORM_SPEED_MULT  # Enemies energized by sand
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

## Enhancement: XP gain multiplier for the current weather (1.0 = normal).
## Aurora weather boosts XP by 50%, encouraging aggressive play during auroras.
## Phase 28: Blood Moon triples XP, Pollen Storm gives a gentle 20% boost,
## and an active weather combo adds an extra 25% on top.
func get_xp_multiplier() -> float:
	var mult: float = 1.0
	match _current_weather:
		GameConstants.Weather.AURORA:
			mult = GameConstants.AURORA_XP_MULT
		# ── Phase 28: Weather Expansion ──
		GameConstants.Weather.BLOOD_MOON:
			mult = GameConstants.BLOOD_MOON_XP_MULT
		GameConstants.Weather.POLLEN_STORM:
			mult = GameConstants.POLLEN_STORM_XP_MULT
		_:
			mult = 1.0
	# ── Phase 28: Weather combo bonus XP ──
	if _combo_weather != GameConstants.Weather.CLEAR:
		mult += GameConstants.WEATHER_COMBO_XP_BONUS
	return mult

## Phase 28: Loot chance multiplier for the current weather (1.0 = normal).
## Blood Moon triples loot, and an active weather combo adds +25%.
func get_loot_multiplier() -> float:
	var mult: float = 1.0
	match _current_weather:
		GameConstants.Weather.BLOOD_MOON:
			mult = GameConstants.BLOOD_MOON_LOOT_MULT
		_:
			mult = 1.0
	if _combo_weather != GameConstants.Weather.CLEAR:
		mult += GameConstants.WEATHER_COMBO_LOOT_BONUS
	return mult

## Phase 28: Enemy HP multiplier for the current weather (1.0 = normal).
## Blood Moon boosts enemy HP by 40%.
func get_enemy_hp_multiplier() -> float:
	match _current_weather:
		GameConstants.Weather.BLOOD_MOON:
			return GameConstants.BLOOD_MOON_ENEMY_HP_MULT
		_:
			return 1.0

## Phase 28: Enemy damage multiplier for the current weather (1.0 = normal).
## Blood Moon boosts enemy damage by 30%.
func get_enemy_damage_multiplier() -> float:
	match _current_weather:
		GameConstants.Weather.BLOOD_MOON:
			return GameConstants.BLOOD_MOON_ENEMY_DAMAGE_MULT
		_:
			return 1.0

## Phase 28: Whether the minimap/radar should be disabled (Magnetic Storm).
func is_minimap_disabled() -> bool:
	return _current_weather == GameConstants.Weather.MAGNETIC_STORM \
		or _combo_weather == GameConstants.Weather.MAGNETIC_STORM

## Phase 28: Whether dashing is currently disabled by an EMP pulse (Magnetic Storm).
## Returns the remaining disable time in seconds, or 0.0 if dashing is allowed.
func get_emp_dash_disable_remaining() -> float:
	return max(0.0, _emp_disable_timer)

## Phase 28: The current gravity-anomaly vertical force (negative = upward,
## positive = downward, 0.0 = normal gravity). Polled by the player to apply
## vertical velocity during Gravity Anomaly weather.
func get_gravity_anomaly_force() -> float:
	if _current_weather != GameConstants.Weather.GRAVITY_ANOMALY \
		and _combo_weather != GameConstants.Weather.GRAVITY_ANOMALY:
		return 0.0
	return _gravity_anomaly_force

## Phase 28: The current combo (overlapping) weather, or CLEAR if no combo active.
func get_combo_weather() -> int:
	return _combo_weather

## Phase 28: Whether a weather combo is currently active.
func is_combo_active() -> bool:
	return _combo_weather != GameConstants.Weather.CLEAR

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
	# Re-resolve the WorldEnvironment after scene transitions so we don't
	# hold a stale reference to the freed node from the previous scene.
	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)

func _on_game_restarted() -> void:
	# The scene was reloaded; the old WorldEnvironment is freed. Re-resolve
	# on the next frame so the new scene's WorldEnvironment is available.
	_world_env = null
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
		if _current_weather == GameConstants.Weather.AURORA:
			# Enhancement: Aurora — shift the light color through green-teal-purple hues
			var hue_shift: float = GameManager.game_time * 0.3
			var aurora_color := Color.from_hsv(
				fposmod(hue_shift, 1.0) * 0.4 + 0.3,  # Hue range 0.3-0.7 (green to purple)
				0.8,  # Saturation
				1.0   # Value
			)
			_solar_light.light_color = aurora_color
			var pulse: float = 0.7 + 0.3 * sin(GameManager.game_time * 1.5)
			_solar_light.light_energy = GameConstants.AURORA_LIGHT_ENERGY * pulse
		else:
			# Solar flare — orange pulsing light
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
		# Enhancement: New weather types
		GameConstants.Weather.METEOR_SHOWER,
		GameConstants.Weather.AURORA,
		GameConstants.Weather.SANDSTORM,
		# ── Phase 28: Weather Expansion ──
		GameConstants.Weather.BLOOD_MOON,
		GameConstants.Weather.ECLIPSE,
		GameConstants.Weather.POLLEN_STORM,
		GameConstants.Weather.MAGNETIC_STORM,
		GameConstants.Weather.GRAVITY_ANOMALY,
		GameConstants.Weather.DIMENSIONAL_STORM,
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
		# Enhancement: Meteor Shower — telegraphed meteor strikes (bigger than lightning)
		GameConstants.Weather.METEOR_SHOWER:
			_tick_meteor_shower(delta)
		# Enhancement: Sandstorm — periodic sand-scour damage to exposed entities
		GameConstants.Weather.SANDSTORM:
			_tick_sandstorm(delta)
		# ── Phase 28: Weather Expansion ──
		GameConstants.Weather.POLLEN_STORM:
			_tick_pollen_storm(delta)
		GameConstants.Weather.MAGNETIC_STORM:
			_tick_magnetic_storm(delta)
		GameConstants.Weather.GRAVITY_ANOMALY:
			_tick_gravity_anomaly(delta)
		GameConstants.Weather.DIMENSIONAL_STORM:
			_tick_dimensional_storm(delta)
		# SOLAR_FLARE, FOG, SNOW_STORM, AURORA, BLOOD_MOON, ECLIPSE effects are
		# passive (multipliers queried by other systems); only light + particles
		# are managed here.
		_:
			pass
	# ── Phase 28: Weather combo tick (independent of primary weather) ──
	if _combo_weather != GameConstants.Weather.CLEAR:
		_tick_combo_weather(delta)

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
			# Enhancement: Check if this is a meteor strike or regular lightning
			if s.get("is_meteor", false):
				_execute_meteor_strike(s["pos"])
			else:
				_execute_lightning_strike(s["pos"])
			_pending_strikes.remove_at(i)
			# Clean up any falling meteor meshes that reached their target
			for j in range(_active_meteors.size() - 1, -1, -1):
				var m: Dictionary = _active_meteors[j]
				var mesh: MeshInstance3D = m["mesh"]
				if is_instance_valid(mesh):
					var d: float = mesh.global_position.distance_to(s["pos"])
					if d < 2.0:
						mesh.queue_free()
						_active_meteors.remove_at(j)
				else:
					_active_meteors.remove_at(j)

func _execute_lightning_strike(pos: Vector3) -> void:
	# Phase 20: Audio — thunder SFX
	AudioManager.play_sfx(AudioManager.SFX_THUNDER)
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

# ─── Enhancement: Meteor Shower ───────────────────────────────────────────────
# Meteors are larger, more damaging, and have a longer telegraph than lightning.
# The meteor is visible falling from the sky during the telegraph (a streaking
# fiery orb descending from height), then impacts with a big explosion.

var _meteor_timer: float = 10.0
# Active falling meteor visuals (visible during telegraph)
var _active_meteors: Array[Dictionary] = []

func _tick_meteor_shower(delta: float) -> void:
	_meteor_timer -= delta
	if _meteor_timer <= 0:
		_meteor_timer = randf_range(
			GameConstants.METEOR_SHOWER_INTERVAL_MIN,
			GameConstants.METEOR_SHOWER_INTERVAL_MAX)
		_schedule_meteor_strike()

func _schedule_meteor_strike() -> void:
	var player: CharacterBody3D = _get_player()
	if not player:
		return
	# Strike at a random position within 22m of the player (wider spread than lightning)
	var angle: float = randf() * TAU
	var dist: float = randf_range(4.0, 22.0)
	var strike_pos: Vector3 = player.global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	_pending_strikes.append({
		"pos": strike_pos,
		"warn_timer": GameConstants.METEOR_WARN_TIME,
		"struck": false,
		"is_meteor": true,  # Flag to distinguish from lightning strikes
	})
	lightning_strike_requested.emit(strike_pos, GameConstants.METEOR_WARN_TIME)
	# Spawn a visible falling meteor during the telegraph
	var parent: Node = GameManager.world if GameManager.world else get_tree().current_scene
	if parent:
		var meteor_mesh := MeshInstance3D.new()
		var meteor_sphere := SphereMesh.new()
		meteor_sphere.radius = 0.8
		meteor_sphere.height = 1.6
		meteor_sphere.radial_segments = 8
		meteor_mesh.mesh = meteor_sphere
		var meteor_mat := StandardMaterial3D.new()
		meteor_mat.albedo_color = Color(1.0, 0.4, 0.1)
		meteor_mat.emission_enabled = true
		meteor_mat.emission = Color(1.0, 0.5, 0.1)
		meteor_mat.emission_energy_multiplier = 3.0
		meteor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		meteor_mesh.material_override = meteor_mat
		# Trail light
		var meteor_light := OmniLight3D.new()
		meteor_light.light_color = Color(1.0, 0.5, 0.2)
		meteor_light.light_energy = 4.0
		meteor_light.omni_range = 8.0
		meteor_mesh.add_child(meteor_light)
		parent.add_child(meteor_mesh)
		# Start high above and animate falling to the strike position
		var start_pos: Vector3 = strike_pos + Vector3(0, 40.0, 0)
		meteor_mesh.global_position = start_pos
		_active_meteors.append({"mesh": meteor_mesh, "target": strike_pos})
		# Animate the meteor falling over the warn time
		var fall_tween := meteor_mesh.create_tween()
		fall_tween.tween_property(meteor_mesh, "global_position", strike_pos, GameConstants.METEOR_WARN_TIME) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		# Spin the meteor as it falls
		fall_tween.parallel().tween_property(meteor_mesh, "rotation:y", TAU * 3, GameConstants.METEOR_WARN_TIME)
		# Trail particles
		fall_tween.parallel().tween_callback(func():
			if is_instance_valid(meteor_mesh) and randf() < 0.5:
				ParticleEffects.spawn_explosion(parent, meteor_mesh.global_position,
					Color(1.0, 0.4, 0.1), 4, 0.15)
		)

func _execute_meteor_strike(pos: Vector3) -> void:
	# Phase 20: Audio — explosion SFX (bigger than thunder)
	AudioManager.play_sfx(AudioManager.SFX_EXPLOSION)
	AudioManager.play_sfx(AudioManager.SFX_THUNDER)
	var parent: Node = GameManager.world if GameManager.world else get_tree().current_scene
	if parent:
		# Big fiery light flash
		var flash: OmniLight3D = OmniLight3D.new()
		flash.light_color = Color(1.0, 0.4, 0.1)
		flash.light_energy = 12.0
		flash.omni_range = 25.0
		parent.add_child(flash)
		flash.global_position = pos + Vector3(0, 6, 0)
		var tw: Tween = create_tween()
		tw.tween_property(flash, "light_energy", 0.0, 0.6).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(flash, "omni_range", 8.0, 0.6)
		tw.chain().tween_callback(flash.queue_free)
		# Large explosion particles (bigger than lightning)
		ParticleEffects.spawn_mega_explosion(parent, pos + Vector3(0, 2, 0), Color(1.0, 0.4, 0.1))
		# Camera shake (bigger than lightning — meteors hit harder)
		if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
			GameManager.camera_rig.add_trauma(0.6)
	# Damage entities in radius (larger than lightning)
	var radius: float = GameConstants.METEOR_RADIUS
	var player: CharacterBody3D = _get_player()
	if player and is_instance_valid(player):
		if player.global_position.distance_to(pos) <= radius:
			GameManager.take_damage(GameConstants.METEOR_DAMAGE, pos)
	# Enemies take damage too
	for enemy in GameManager.enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			if enemy.global_position.distance_to(pos) <= radius:
				if enemy.has_method("take_damage_from"):
					enemy.take_damage_from(GameConstants.METEOR_DAMAGE, pos)

# ─── Enhancement: Sandstorm ───────────────────────────────────────────────────
# Sandstorms scour exposed entities with damage over time. Enemies are energized
# by the storm (speed boost handled via get_enemy_speed_multiplier()). The player
# is slowed (handled via get_speed_multiplier()). Fog density is increased for
# reduced visibility. Shelter reduces damage (like acid rain).

var _sandstorm_tick_timer: float = 0.0

func _tick_sandstorm(delta: float) -> void:
	_sandstorm_tick_timer -= delta
	if _sandstorm_tick_timer > 0:
		return
	_sandstorm_tick_timer = GameConstants.SANDSTORM_TICK_INTERVAL
	# Damage player if exposed (same shelter check as acid rain)
	var player: CharacterBody3D = _get_player()
	if not player or not is_instance_valid(player):
		return
	var exposed: bool = _is_player_exposed_to_sky()
	var dmg: int = GameConstants.SANDSTORM_DAMAGE_PER_TICK
	if not exposed:
		dmg = int(dmg * (1.0 - GameConstants.SANDSTORM_SHELTER_REDUCTION))
	if exposed or dmg > 0:
		GameManager.take_damage(dmg, player.global_position + Vector3(0, 20, 0))
	# Damage enemies too (sand is indiscriminate)
	for enemy in GameManager.enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			if enemy.has_method("take_damage_from"):
				enemy.take_damage_from(GameConstants.SANDSTORM_DAMAGE_PER_TICK,
					player.global_position if player else Vector3.ZERO)

# ─── Phase 28: Weather Expansion tick functions ──────────────────────────────

# Pollen Storm — heals everything slowly; peaceful period for exploration.
func _tick_pollen_storm(delta: float) -> void:
	_pollen_tick_timer -= delta
	if _pollen_tick_timer > 0:
		return
	_pollen_tick_timer = GameConstants.POLLEN_STORM_TICK_INTERVAL
	# Heal the player a small amount
	if GameManager.player_is_alive and GameManager.player_hp < GameManager.player_max_hp:
		GameManager.heal(GameConstants.POLLEN_STORM_HEAL_PER_TICK)
	# Heal enemies too (the pollen is indiscriminate — everything blooms)
	for enemy in GameManager.enemies:
		if is_instance_valid(enemy) and not enemy.is_dead and "hp" in enemy and "max_hp" in enemy:
			if enemy.hp < enemy.max_hp:
				enemy.hp = min(enemy.max_hp, enemy.hp + GameConstants.POLLEN_STORM_HEAL_PER_TICK)

# Magnetic Storm — periodic EMP pulses that temporarily disable dashing.
func _tick_magnetic_storm(delta: float) -> void:
	# Tick down any active EMP disable timer
	if _emp_disable_timer > 0:
		_emp_disable_timer -= delta
	_emp_timer -= delta
	if _emp_timer <= 0:
		_emp_timer = randf_range(
			GameConstants.MAGNETIC_STORM_EMP_INTERVAL_MIN,
			GameConstants.MAGNETIC_STORM_EMP_INTERVAL_MAX)
		# Fire an EMP pulse — disables dashing for a short window
		_emp_disable_timer = GameConstants.MAGNETIC_STORM_EMP_DISABLE_DURATION
		emp_pulse_triggered.emit()
		GameManager.add_message("⚡ Magnetic EMP! Dashing disabled for %.1fs!" % GameConstants.MAGNETIC_STORM_EMP_DISABLE_DURATION)
		# Visual: brief blue-white light flash at the player's position
		var player: CharacterBody3D = _get_player()
		var parent: Node = GameManager.world if GameManager.world else get_tree().current_scene
		if parent and player and is_instance_valid(player):
			var flash: OmniLight3D = OmniLight3D.new()
			flash.light_color = Color(0.6, 0.7, 1.0)
			flash.light_energy = 6.0
			flash.omni_range = 18.0
			parent.add_child(flash)
			flash.global_position = player.global_position + Vector3(0, 3, 0)
			var tw: Tween = create_tween()
			tw.tween_property(flash, "light_energy", 0.0, 0.5).set_trans(Tween.TRANS_QUAD)
			tw.chain().tween_callback(flash.queue_free)
			# Small camera shake for the pulse impact
			if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
				GameManager.camera_rig.add_trauma(0.25)

# Gravity Anomaly — periodic gravity shifts that affect vertical movement.
# Every GRAVITY_ANOMALY_SHIFT_INTERVAL seconds, gravity reverses for
# GRAVITY_ANOMALY_SHIFT_DURATION seconds, then returns to normal.
func _tick_gravity_anomaly(delta: float) -> void:
	if _gravity_shift_active:
		_gravity_shift_remaining -= delta
		if _gravity_shift_remaining <= 0:
			_gravity_shift_active = false
			_gravity_anomaly_force = 0.0
			gravity_shift_ended.emit()
			GameManager.add_message("🌀 Gravity normalizes.")
	else:
		_gravity_shift_timer -= delta
		if _gravity_shift_timer <= 0:
			_gravity_shift_timer = GameConstants.GRAVITY_ANOMALY_SHIFT_INTERVAL
			_gravity_shift_active = true
			_gravity_shift_remaining = GameConstants.GRAVITY_ANOMALY_SHIFT_DURATION
			# Randomly pick upward or downward shift
			var direction: int = 1 if randf() < 0.5 else -1
			_gravity_anomaly_force = direction * (GameConstants.GRAVITY_ANOMALY_UPWARD_FORCE if direction < 0 else GameConstants.GRAVITY_ANOMALY_DOWNWARD_FORCE)
			gravity_shift_started.emit(direction)
			var dir_name: String = "UPWARD" if direction < 0 else "DOWNWARD"
			GameManager.add_message("🌀 Gravity anomaly! Shift %s for %.1fs!" % [dir_name, GameConstants.GRAVITY_ANOMALY_SHIFT_DURATION])
			# Visual: violet light pulse
			var player: CharacterBody3D = _get_player()
			var parent: Node = GameManager.world if GameManager.world else get_tree().current_scene
			if parent and player and is_instance_valid(player):
				var flash: OmniLight3D = OmniLight3D.new()
				flash.light_color = Color(0.7, 0.4, 1.0)
				flash.light_energy = 5.0
				flash.omni_range = 15.0
				parent.add_child(flash)
				flash.global_position = player.global_position + Vector3(0, 3, 0)
				var tw: Tween = create_tween()
				tw.tween_property(flash, "light_energy", 0.0, 0.6).set_trans(Tween.TRANS_QUAD)
				tw.chain().tween_callback(flash.queue_free)
				if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
					GameManager.camera_rig.add_trauma(0.2)

# Dimensional Storm — rifts open randomly and dimensions shift every 15s.
func _tick_dimensional_storm(delta: float) -> void:
	# Spawn rifts periodically by asking DimensionSystem to spawn one
	_dim_rift_timer -= delta
	if _dim_rift_timer <= 0:
		_dim_rift_timer = randf_range(
			GameConstants.DIMENSIONAL_STORM_RIFT_INTERVAL_MIN,
			GameConstants.DIMENSIONAL_STORM_RIFT_INTERVAL_MAX)
		# DimensionSystem handles rift spawning internally; we just nudge it
		# by calling its _try_spawn_rift if available.
		if DimensionSystem and DimensionSystem.has_method("_try_spawn_rift"):
			DimensionSystem._try_spawn_rift()
	# Force a dimension shift every DIMENSIONAL_STORM_SHIFT_INTERVAL seconds
	_dim_shift_timer -= delta
	if _dim_shift_timer <= 0:
		_dim_shift_timer = GameConstants.DIMENSIONAL_STORM_SHIFT_INTERVAL
		# Only shift if we're currently in normal space (don't interrupt an
		# active dimension — let it resolve naturally).
		if DimensionSystem and DimensionSystem.get_current_dimension() == GameConstants.Dimension.NORMAL:
			dimensional_shift_triggered.emit()
			# Pick a random dimension and enter it directly
			var dimensions: Array[int] = [
				GameConstants.Dimension.VOID,
				GameConstants.Dimension.MIRROR,
				GameConstants.Dimension.TIME_SLOW,
				GameConstants.Dimension.REVERSE_GRAVITY,
			]
			var target_dim: int = dimensions[randi() % dimensions.size()]
			if DimensionSystem.has_method("enter_dimension"):
				DimensionSystem.enter_dimension(target_dim)
			GameManager.add_message("💫 Dimensional instability! Reality shifts!")

# Weather combo tick — handles the overlapping combo weather's own passive
# effects (EMP pulses for magnetic combo, gravity shifts for gravity combo,
# rifts for dimensional combo). The combo weather's multipliers are already
# queried via the getter functions (e.g. is_minimap_disabled checks both).
func _tick_combo_weather(delta: float) -> void:
	# Tick down the combo timer; when it expires, end the combo
	_combo_timer -= delta
	if _combo_timer <= 0:
		_end_weather_combo()
		return
	# Apply the combo weather's active effects (if any)
	match _combo_weather:
		GameConstants.Weather.MAGNETIC_STORM:
			# Combo magnetic storm still fires EMP pulses
			_tick_magnetic_storm(delta)
		GameConstants.Weather.GRAVITY_ANOMALY:
			# Combo gravity anomaly still shifts gravity
			_tick_gravity_anomaly(delta)
		GameConstants.Weather.DIMENSIONAL_STORM:
			# Combo dimensional storm still opens rifts
			_tick_dimensional_storm(delta)
		_:
			pass

## Phase 28: Start a weather combo — a second weather type overlapping the
## primary. The combo lasts for a portion of the primary weather's duration.
func _try_start_weather_combo(primary_weather: int) -> void:
	if _combo_weather != GameConstants.Weather.CLEAR:
		return  # Already have a combo
	if randf() > GameConstants.WEATHER_COMBO_CHANCE:
		return  # No combo this time
	var combo_candidates: Array = GameConstants.WEATHER_COMBO_PAIRS.get(primary_weather, [])
	if combo_candidates.is_empty():
		return
	_combo_weather = combo_candidates[randi() % combo_candidates.size()]
	# Combo lasts for ~60% of the primary weather's duration
	_combo_timer = _weather_timer * 0.6
	weather_combo_started.emit(_combo_weather, primary_weather)
	# Apply the combo weather's start effects (particles, lights, fog)
	_start_combo_effects(_combo_weather)
	var combo_info: Dictionary = GameConstants.WEATHER_INFO.get(_combo_weather, {})
	var combo_name: String = combo_info.get("name", "Unknown")
	var primary_info: Dictionary = GameConstants.WEATHER_INFO.get(primary_weather, {})
	var primary_name: String = primary_info.get("name", "Unknown")
	GameManager.add_message("🌟 Weather combo! %s + %s!" % [primary_name, combo_name])

## Phase 28: End the active weather combo.
func _end_weather_combo() -> void:
	if _combo_weather == GameConstants.Weather.CLEAR:
		return
	var old_combo: int = _combo_weather
	_end_combo_effects(_combo_weather)
	_combo_weather = GameConstants.Weather.CLEAR
	_combo_timer = 0.0
	weather_combo_ended.emit(old_combo)

## Phase 28: Apply the combo weather's visual effects (particles, lights, fog).
## These run alongside the primary weather's effects.
func _start_combo_effects(combo: int) -> void:
	var parent: Node = GameManager.world if GameManager.world else get_tree().current_scene
	if not parent:
		return
	match combo:
		GameConstants.Weather.MAGNETIC_STORM:
			_magnetic_light = OmniLight3D.new()
			_magnetic_light.light_color = Color(0.4, 0.6, 1.0)
			_magnetic_light.light_energy = 1.5
			_magnetic_light.omni_range = 40.0
			parent.add_child(_magnetic_light)
			_target_fog_density = max(_target_fog_density, _base_fog_density * GameConstants.MAGNETIC_STORM_FOG_DENSITY_MULT)
			_emp_timer = randf_range(GameConstants.MAGNETIC_STORM_EMP_INTERVAL_MIN, GameConstants.MAGNETIC_STORM_EMP_INTERVAL_MAX)
		GameConstants.Weather.GRAVITY_ANOMALY:
			_gravity_light = OmniLight3D.new()
			_gravity_light.light_color = Color(0.7, 0.4, 1.0)
			_gravity_light.light_energy = GameConstants.GRAVITY_ANOMALY_LIGHT_ENERGY
			_gravity_light.omni_range = 50.0
			parent.add_child(_gravity_light)
			_gravity_shift_timer = GameConstants.GRAVITY_ANOMALY_SHIFT_INTERVAL
		GameConstants.Weather.DIMENSIONAL_STORM:
			_dimensional_light = OmniLight3D.new()
			_dimensional_light.light_color = Color(0.8, 0.3, 1.0)
			_dimensional_light.light_energy = 1.5
			_dimensional_light.omni_range = 50.0
			parent.add_child(_dimensional_light)
			_target_fog_density = max(_target_fog_density, _base_fog_density * GameConstants.DIMENSIONAL_STORM_FOG_DENSITY_MULT)
			_dim_rift_timer = randf_range(GameConstants.DIMENSIONAL_STORM_RIFT_INTERVAL_MIN, GameConstants.DIMENSIONAL_STORM_RIFT_INTERVAL_MAX)
			_dim_shift_timer = GameConstants.DIMENSIONAL_STORM_SHIFT_INTERVAL
		GameConstants.Weather.POLLEN_STORM:
			_pollen_light = OmniLight3D.new()
			_pollen_light.light_color = Color(1.0, 0.9, 0.4)
			_pollen_light.light_energy = GameConstants.POLLEN_STORM_LIGHT_ENERGY
			_pollen_light.omni_range = 40.0
			parent.add_child(_pollen_light)
			_pollen_tick_timer = GameConstants.POLLEN_STORM_TICK_INTERVAL
		GameConstants.Weather.ECLIPSE:
			_apply_eclipse_darkness()
		_:
			pass

## Phase 28: Remove the combo weather's visual effects.
func _end_combo_effects(combo: int) -> void:
	match combo:
		GameConstants.Weather.MAGNETIC_STORM:
			if _magnetic_light and is_instance_valid(_magnetic_light):
				_magnetic_light.queue_free()
			_magnetic_light = null
			_emp_disable_timer = 0.0
		GameConstants.Weather.GRAVITY_ANOMALY:
			if _gravity_light and is_instance_valid(_gravity_light):
				_gravity_light.queue_free()
			_gravity_light = null
			_gravity_shift_active = false
			_gravity_anomaly_force = 0.0
		GameConstants.Weather.DIMENSIONAL_STORM:
			if _dimensional_light and is_instance_valid(_dimensional_light):
				_dimensional_light.queue_free()
			_dimensional_light = null
		GameConstants.Weather.POLLEN_STORM:
			if _pollen_light and is_instance_valid(_pollen_light):
				_pollen_light.queue_free()
			_pollen_light = null
		GameConstants.Weather.ECLIPSE:
			_restore_eclipse_darkness()
		_:
			pass

## Phase 28: Apply the Eclipse darkness effect to the WorldEnvironment.
func _apply_eclipse_darkness() -> void:
	if _world_env and _world_env.environment:
		_eclipse_base_ambient_energy = _world_env.environment.ambient_light_energy
		# Tween the ambient light energy down to the eclipse value
		var tw: Tween = create_tween()
		tw.tween_property(_world_env.environment, "ambient_light_energy",
			GameConstants.ECLIPSE_AMBIENT_DARKEN, 2.0).set_trans(Tween.TRANS_QUAD)

## Phase 28: Restore the WorldEnvironment after Eclipse ends.
func _restore_eclipse_darkness() -> void:
	if _world_env and _world_env.environment:
		var tw: Tween = create_tween()
		tw.tween_property(_world_env.environment, "ambient_light_energy",
			_eclipse_base_ambient_energy, 2.0).set_trans(Tween.TRANS_QUAD)

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
		# Enhancement: New weather effects
		GameConstants.Weather.METEOR_SHOWER:
			_weather_particles = _create_weather_particles("embers")
			parent.add_child(_weather_particles)
			_meteor_timer = randf_range(5.0, 10.0)  # First meteor sooner
		GameConstants.Weather.AURORA:
			# Aurora: colorful shifting sky lights (green-teal-purple) + XP boost
			_weather_particles = _create_weather_particles("aurora")
			parent.add_child(_weather_particles)
			# Create aurora light — a high-altitude colored light that shifts hues
			_solar_light = OmniLight3D.new()
			_solar_light.light_color = Color(0.3, 1.0, 0.6)
			_solar_light.light_energy = GameConstants.AURORA_LIGHT_ENERGY
			_solar_light.omni_range = 80.0
			parent.add_child(_solar_light)
		# Enhancement: Sandstorm — scouring sand particles + dense fog + damage tick
		GameConstants.Weather.SANDSTORM:
			_weather_particles = _create_weather_particles("sandstorm")
			parent.add_child(_weather_particles)
			_target_fog_density = _base_fog_density * GameConstants.SANDSTORM_FOG_DENSITY_MULT
			_sandstorm_tick_timer = GameConstants.SANDSTORM_TICK_INTERVAL
			# Sandy ambient light — dim warm-orange tint
			_solar_light = OmniLight3D.new()
			_solar_light.light_color = Color(0.85, 0.65, 0.3)
			_solar_light.light_energy = 1.5
			_solar_light.omni_range = 50.0
			parent.add_child(_solar_light)
		# ── Phase 28: Weather Expansion ──
		GameConstants.Weather.BLOOD_MOON:
			_weather_particles = _create_weather_particles("blood_moon")
			parent.add_child(_weather_particles)
			_target_fog_density = _base_fog_density * GameConstants.BLOOD_MOON_FOG_DENSITY_MULT
			# Red ambient moonlight
			_blood_moon_light = OmniLight3D.new()
			_blood_moon_light.light_color = Color(0.85, 0.1, 0.1)
			_blood_moon_light.light_energy = GameConstants.BLOOD_MOON_LIGHT_ENERGY
			_blood_moon_light.omni_range = 70.0
			parent.add_child(_blood_moon_light)
		GameConstants.Weather.ECLIPSE:
			_weather_particles = _create_weather_particles("eclipse")
			parent.add_child(_weather_particles)
			_target_fog_density = _base_fog_density * GameConstants.ECLIPSE_FOG_DENSITY_MULT
			_apply_eclipse_darkness()
		GameConstants.Weather.POLLEN_STORM:
			_weather_particles = _create_weather_particles("pollen")
			parent.add_child(_weather_particles)
			_pollen_light = OmniLight3D.new()
			_pollen_light.light_color = Color(1.0, 0.9, 0.4)
			_pollen_light.light_energy = GameConstants.POLLEN_STORM_LIGHT_ENERGY
			_pollen_light.omni_range = 40.0
			parent.add_child(_pollen_light)
			_pollen_tick_timer = GameConstants.POLLEN_STORM_TICK_INTERVAL
		GameConstants.Weather.MAGNETIC_STORM:
			_weather_particles = _create_weather_particles("magnetic")
			parent.add_child(_weather_particles)
			_target_fog_density = _base_fog_density * GameConstants.MAGNETIC_STORM_FOG_DENSITY_MULT
			_magnetic_light = OmniLight3D.new()
			_magnetic_light.light_color = Color(0.4, 0.6, 1.0)
			_magnetic_light.light_energy = 1.5
			_magnetic_light.omni_range = 40.0
			parent.add_child(_magnetic_light)
			_emp_timer = randf_range(GameConstants.MAGNETIC_STORM_EMP_INTERVAL_MIN, GameConstants.MAGNETIC_STORM_EMP_INTERVAL_MAX)
		GameConstants.Weather.GRAVITY_ANOMALY:
			_weather_particles = _create_weather_particles("gravity_anomaly")
			parent.add_child(_weather_particles)
			_gravity_light = OmniLight3D.new()
			_gravity_light.light_color = Color(0.7, 0.4, 1.0)
			_gravity_light.light_energy = GameConstants.GRAVITY_ANOMALY_LIGHT_ENERGY
			_gravity_light.omni_range = 50.0
			parent.add_child(_gravity_light)
			_gravity_shift_timer = GameConstants.GRAVITY_ANOMALY_SHIFT_INTERVAL
		GameConstants.Weather.DIMENSIONAL_STORM:
			_weather_particles = _create_weather_particles("dimensional")
			parent.add_child(_weather_particles)
			_target_fog_density = _base_fog_density * GameConstants.DIMENSIONAL_STORM_FOG_DENSITY_MULT
			_dimensional_light = OmniLight3D.new()
			_dimensional_light.light_color = Color(0.8, 0.3, 1.0)
			_dimensional_light.light_energy = 1.5
			_dimensional_light.omni_range = 50.0
			parent.add_child(_dimensional_light)
			_dim_rift_timer = randf_range(GameConstants.DIMENSIONAL_STORM_RIFT_INTERVAL_MIN, GameConstants.DIMENSIONAL_STORM_RIFT_INTERVAL_MAX)
			_dim_shift_timer = GameConstants.DIMENSIONAL_STORM_SHIFT_INTERVAL
		GameConstants.Weather.CLEAR:
			pass  # No particles; baseline
	# ── Phase 28: Weather combo — try to start a combo weather overlap ──
	_try_start_weather_combo(weather)

func _end_weather_effects(weather: int) -> void:
	# Remove weather particles
	if _weather_particles and is_instance_valid(_weather_particles):
		_weather_particles.queue_free()
	_weather_particles = null
	# Remove solar/aurora light (shared variable — used for both solar flare and aurora)
	if _solar_light and is_instance_valid(_solar_light):
		_solar_light.queue_free()
	_solar_light = null
	# Reset fog
	_target_fog_density = _base_fog_density
	# Clear pending strikes
	_pending_strikes.clear()
	# Enhancement: Clean up active falling meteor meshes
	for m in _active_meteors:
		var mesh: MeshInstance3D = m["mesh"]
		if is_instance_valid(mesh):
			mesh.queue_free()
	_active_meteors.clear()
	# ── Phase 28: Weather Expansion — clean up new weather lights ──
	if _blood_moon_light and is_instance_valid(_blood_moon_light):
		_blood_moon_light.queue_free()
	_blood_moon_light = null
	if _eclipse_light and is_instance_valid(_eclipse_light):
		_eclipse_light.queue_free()
	_eclipse_light = null
	# Eclipse darkness restoration (only if this was the eclipse weather)
	if weather == GameConstants.Weather.ECLIPSE:
		_restore_eclipse_darkness()
	if _pollen_light and is_instance_valid(_pollen_light):
		_pollen_light.queue_free()
	_pollen_light = null
	if _magnetic_light and is_instance_valid(_magnetic_light):
		_magnetic_light.queue_free()
	_magnetic_light = null
	_emp_disable_timer = 0.0
	if _gravity_light and is_instance_valid(_gravity_light):
		_gravity_light.queue_free()
	_gravity_light = null
	_gravity_shift_active = false
	_gravity_anomaly_force = 0.0
	if _dimensional_light and is_instance_valid(_dimensional_light):
		_dimensional_light.queue_free()
	_dimensional_light = null
	# ── Phase 28: End any active weather combo ──
	_end_weather_combo()

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
	# Solar/aurora light follows player too
	if _solar_light and is_instance_valid(_solar_light):
		if player and is_instance_valid(player):
			if _current_weather == GameConstants.Weather.AURORA:
				# Enhancement: Aurora light is higher and wider — it's a sky-wide phenomenon
				_solar_light.global_position = player.global_position + Vector3(0, 40, 0)
			elif _current_weather == GameConstants.Weather.SANDSTORM:
				# Enhancement: Sandstorm light is lower — ground-level haze
				_solar_light.global_position = player.global_position + Vector3(0, 15, 0)
			else:
				_solar_light.global_position = player.global_position + Vector3(0, 25, 0)
	# ── Phase 28: Weather Expansion — new lights follow the player ──
	if _blood_moon_light and is_instance_valid(_blood_moon_light) and player and is_instance_valid(player):
		_blood_moon_light.global_position = player.global_position + Vector3(0, 30, 0)
	if _pollen_light and is_instance_valid(_pollen_light) and player and is_instance_valid(player):
		_pollen_light.global_position = player.global_position + Vector3(0, 18, 0)
	if _magnetic_light and is_instance_valid(_magnetic_light) and player and is_instance_valid(player):
		_magnetic_light.global_position = player.global_position + Vector3(0, 20, 0)
	if _gravity_light and is_instance_valid(_gravity_light) and player and is_instance_valid(player):
		_gravity_light.global_position = player.global_position + Vector3(0, 22, 0)
	if _dimensional_light and is_instance_valid(_dimensional_light) and player and is_instance_valid(player):
		_dimensional_light.global_position = player.global_position + Vector3(0, 25, 0)

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
		# Enhancement: Aurora particles — colorful slow-drifting lights high above
		"aurora":
			p.amount = 60
			p.lifetime = 8.0
			pmat.direction = Vector3(1, 0, 0)
			pmat.spread = 45.0
			pmat.gravity = Vector3.ZERO
			pmat.initial_velocity_min = 0.3
			pmat.initial_velocity_max = 1.5
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_scale = 0.2
			color = Color(0.3, 1.0, 0.6, 0.4)
			mesh.radius = 2.0  # Large soft globes of light
			mesh.height = 4.0
		# Enhancement: Sandstorm particles — fast horizontal sand grains, thick
		"sandstorm":
			p.amount = 500
			p.lifetime = 2.0
			pmat.direction = Vector3(1, 0, 0.2)  # Strong horizontal wind
			pmat.spread = 15.0
			pmat.gravity = Vector3(0, -2, 0)  # Slight settling
			pmat.initial_velocity_min = 15.0
			pmat.initial_velocity_max = 25.0
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_scale = 0.8
			color = Color(0.9, 0.75, 0.35, 0.6)
			mesh.radius = 0.04
			mesh.height = 0.08
		# ── Phase 28: Weather Expansion particle types ──
		# Blood Moon — drifting red embers + dark haze motes
		"blood_moon":
			p.amount = 250
			p.lifetime = 5.0
			pmat.direction = Vector3(0.2, -0.3, 0.2)
			pmat.spread = 30.0
			pmat.gravity = Vector3(0, -1.5, 0)
			pmat.initial_velocity_min = 1.0
			pmat.initial_velocity_max = 4.0
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_scale = 0.5
			color = Color(0.8, 0.15, 0.15, 0.55)
			mesh.radius = 0.08
			mesh.height = 0.16
		# Eclipse — dark ash-like motes drifting in the dimmed air
		"eclipse":
			p.amount = 180
			p.lifetime = 6.0
			pmat.direction = Vector3(0.4, -0.2, 0.4)
			pmat.spread = 40.0
			pmat.gravity = Vector3(0, -0.8, 0)
			pmat.initial_velocity_min = 0.5
			pmat.initial_velocity_max = 2.5
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_scale = 0.4
			color = Color(0.2, 0.18, 0.3, 0.45)
			mesh.radius = 0.1
			mesh.height = 0.2
		# Pollen Storm — soft golden pollen grains drifting gently
		"pollen":
			p.amount = 300
			p.lifetime = 6.0
			pmat.direction = Vector3(0.3, 0.2, 0.3)  # Slight upward drift (blooming)
			pmat.spread = 35.0
			pmat.gravity = Vector3(0, 0.5, 0)  # Positive = floats up gently
			pmat.initial_velocity_min = 0.5
			pmat.initial_velocity_max = 2.0
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_scale = 0.6
			color = Color(1.0, 0.9, 0.4, 0.7)
			mesh.radius = 0.07
			mesh.height = 0.14
		# Magnetic Storm — crackling blue sparks drifting in the air
		"magnetic":
			p.amount = 220
			p.lifetime = 3.0
			pmat.direction = Vector3(0, 1, 0)  # Rise upward (ionized air)
			pmat.spread = 25.0
			pmat.gravity = Vector3(0, 2.0, 0)
			pmat.initial_velocity_min = 1.0
			pmat.initial_velocity_max = 4.0
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_scale = 0.7
			color = Color(0.4, 0.6, 1.0, 0.55)
			mesh.radius = 0.05
			mesh.height = 0.1
		# Gravity Anomaly — violet particles drifting in unstable patterns
		"gravity_anomaly":
			p.amount = 200
			p.lifetime = 4.0
			pmat.direction = Vector3(0, 1, 0)  # Default upward (shifts with gravity)
			pmat.spread = 30.0
			pmat.gravity = Vector3(0, 0, 0)  # No gravity — they float erratically
			pmat.initial_velocity_min = 0.5
			pmat.initial_velocity_max = 3.0
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_scale = 1.0  # High turbulence = unstable motion
			color = Color(0.7, 0.4, 1.0, 0.5)
			mesh.radius = 0.06
			mesh.height = 0.12
		# Dimensional Storm — purple rift sparks spiraling chaotically
		"dimensional":
			p.amount = 280
			p.lifetime = 4.0
			pmat.direction = Vector3(0, 1, 0)
			pmat.spread = 45.0
			pmat.gravity = Vector3(0, 1.0, 0)
			pmat.initial_velocity_min = 1.0
			pmat.initial_velocity_max = 5.0
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_scale = 0.9
			color = Color(0.8, 0.3, 1.0, 0.6)
			mesh.radius = 0.06
			mesh.height = 0.12

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