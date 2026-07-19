## Zorp Wiggles — Procedural Boss Generator (Phase 33)
## Assembles a unique boss from a palette of attack patterns and visual parts.
## The generated boss is a custom CharacterBody3D enemy with:
##   - A procedural name (prefix + core + suffix)
##   - A body assembled from primitive meshes (core sphere + visual parts)
##   - A subset of attack patterns from the BossPattern enum
##   - Stats scaled to the player's level
##
## The generator exposes two entry points:
##   - generate_boss(player_level) → spawns a procedural boss near the player
##   - generate_world_boss(player_level, pos) → spawns one at a fixed position
##
## All colors use Godot 0-1 range.

extends Node

class_name ProcBossGen

# ─── Signals ────────────────────────────────────────────────────────────────────
signal boss_generated(boss: Node, name: String, patterns: Array)

# ─── State ─────────────────────────────────────────────────────────────────────
var _rng := RandomNumberGenerator.new()

# ─── Public API ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("procedural_boss_generator")

# Generate a procedural boss near the player. Returns the spawned node.
func generate_boss(player_level: int) -> Node:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return null
	var angle: float = _rng.randf() * TAU
	var dist: float = 20.0
	var pos: Vector3 = player.global_position + Vector3(cos(angle) * dist, 1.5, sin(angle) * dist)
	return generate_boss_at(player_level, pos)

# Generate a procedural boss at a specific position.
func generate_boss_at(player_level: int, pos: Vector3) -> Node:
	var seed_val: int = GameManager.world_seed if GameManager else randi()
	_rng.seed = seed_val + int(pos.x) * 31 + int(pos.z) * 17
	# Pick attack patterns.
	var pattern_count: int = _rng.randi_range(
		GameConstants.PROC_BOSS_MIN_PATTERNS,
		GameConstants.PROC_BOSS_MAX_PATTERNS
	)
	var pool: Array[int] = []
	for i in GameConstants.BossPattern.size():
		pool.append(i)
	pool.shuffle()
	var patterns: Array = []
	for i in pattern_count:
		patterns.append(pool[i])
	# Pick visual parts (2-3 parts).
	var visual_count: int = _rng.randi_range(2, 3)
	var vpool: Array[int] = []
	for i in GameConstants.BossVisualPart.size():
		vpool.append(i)
	vpool.shuffle()
	var visuals: Array = []
	for i in visual_count:
		visuals.append(vpool[i])
	# Generate the boss name (use a local variable to avoid shadowing
	# the Node.name property — GDScript warns on this).
	var boss_name := _generate_name()
	# Compute stats.
	var hp: int = int(GameConstants.PROC_BOSS_BASE_HP + GameConstants.PROC_BOSS_HP_PER_PLAYER_LEVEL * player_level)
	var damage: int = int(GameConstants.PROC_BOSS_BASE_DAMAGE + GameConstants.PROC_BOSS_DAMAGE_PER_PLAYER_LEVEL * player_level)
	var speed: float = GameConstants.PROC_BOSS_BASE_SPEED
	# Build the boss node.
	var boss := _build_boss_node(boss_name, hp, damage, speed, patterns, visuals)
	boss.position = pos
	get_tree().current_scene.add_child(boss)
	if "enemies" in GameManager:
		GameManager.enemies.append(boss)
	# Emit signals for HUD / arena integration.
	GameManager.boss_spawned.emit(boss)
	boss_generated.emit(boss, boss_name, patterns)
	GameManager.add_message("☠ PROCEDURAL BOSS: %s has appeared!" % boss_name)
	return boss

# ─── Name Generation ────────────────────────────────────────────────────────────

func _generate_name() -> String:
	var prefix: String = GameConstants.PROC_BOSS_NAME_PREFIXES[_rng.randi() % GameConstants.PROC_BOSS_NAME_PREFIXES.size()]
	var core: String = GameConstants.PROC_BOSS_NAME_CORES[_rng.randi() % GameConstants.PROC_BOSS_NAME_CORES.size()]
	var suffix: String = GameConstants.PROC_BOSS_NAME_SUFFIXES[_rng.randi() % GameConstants.PROC_BOSS_NAME_SUFFIXES.size()]
	return "%s %s %s" % [prefix, core, suffix]

# ─── Boss Node Construction ──────────────────────────────────────────────────────

func _build_boss_node(boss_name: String, hp: int, damage: int, speed: float, patterns: Array, visuals: Array) -> CharacterBody3D:
	# We extend EnemyBase by reusing the base scene — instantiate an enemy_blob
	# and reconfigure it as a procedural boss. This gives us pathfinding,
	# damage handling, death logic, etc. for free.
	var scene: PackedScene = load("res://scenes/entities/enemy_blob.tscn")
	if not scene:
		return null
	var boss: CharacterBody3D = scene.instantiate()
	# Configure stats.
	if boss is EnemyBase:
		boss.enemy_name = boss_name
		boss.max_hp = hp
		boss.hp = hp
		boss.damage = damage
		boss.speed = speed
		boss.scale = Vector3(2.5, 2.5, 2.5)
		boss.is_arena_boss = true
		# Procedural boss metadata so other systems can identify it.
		boss.set_meta("procedural_boss", true)
		boss.set_meta("boss_patterns", patterns)
		boss.set_meta("boss_visuals", visuals)
		boss.set_meta("boss_name", boss_name)
	# Recolor the body with a unique procedural color.
	var body_mesh: MeshInstance3D = boss.get_node_or_null("BodyMesh")
	if body_mesh:
		var mat := StandardMaterial3D.new()
		var hue: float = _rng.randf()
		var base_color := Color.from_hsv(hue, 0.6, 0.9)
		mat.albedo_color = base_color
		mat.emission_enabled = true
		mat.emission = Color.from_hsv(hue, 0.8, 1.0)
		mat.emission_energy_multiplier = 1.5
		mat.rim_enabled = true
		mat.rim_tint = 1.0
		body_mesh.material_override = mat
	# Add visual parts as children.
	for v in visuals:
		_add_visual_part(boss, v)
	# Add a point light for a threatening glow.
	var light := OmniLight3D.new()
	light.light_color = Color.from_hsv(_rng.randf(), 0.7, 1.0)
	light.light_energy = 4.0
	light.omni_range = 18.0
	light.position = Vector3(0, 2.0, 0)
	boss.add_child(light)
	# Attach a small script extension that executes the attack patterns.
	# We do this by setting a meta flag that the enemy_base will read in its
	# _update_ai() — but since enemy_base doesn't know about procedural bosses
	# natively, we attach a per-frame pattern controller as a child Node.
	var controller := Node.new()
	controller.name = "ProcBossController"
	controller.set_script(_make_pattern_script(patterns, damage))
	boss.add_child(controller)
	return boss

# ─── Visual Parts ──────────────────────────────────────────────────────────────

func _add_visual_part(boss: Node3D, part: int) -> void:
	match part:
		GameConstants.BossVisualPart.ORBITING_CRYSTALS:
			_add_orbiting_crystals(boss)
		GameConstants.BossVisualPart.SPIKE_CROWN:
			_add_spike_crown(boss)
		GameConstants.BossVisualPart.GLOWING_CORE:
			_add_glowing_core(boss)
		GameConstants.BossVisualPart.ENERGY_RINGS:
			_add_energy_rings(boss)
		GameConstants.BossVisualPart.SHADOW_TENDRILS:
			_add_shadow_tendrils(boss)
		GameConstants.BossVisualPart.PRISM_SHARDS:
			_add_prism_shards(boss)

func _add_orbiting_crystals(boss: Node3D) -> void:
	var container := Node3D.new()
	container.name = "OrbitingCrystals"
	boss.add_child(container)
	for i in 4:
		var crystal := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.4, 0.8, 0.4)
		crystal.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.4, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.7, 0.5, 1.0)
		mat.emission_energy_multiplier = 2.0
		crystal.material_override = mat
		var angle: float = (float(i) / 4.0) * TAU
		crystal.position = Vector3(cos(angle) * 1.5, 0.5, sin(angle) * 1.5)
		crystal.rotation = Vector3(_rng.randf(), _rng.randf(), _rng.randf())
		container.add_child(crystal)
	# Animate rotation.
	var tween := container.create_tween()
	tween.set_loops()
	tween.tween_property(container, "rotation:y", TAU, 3.0).from(0.0)

func _add_spike_crown(boss: Node3D) -> void:
	for i in 5:
		var spike := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.05
		mesh.bottom_radius = 0.25
		mesh.height = 1.2
		spike.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.3, 0.35)
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.2, 0.2)
		mat.emission_energy_multiplier = 1.2
		spike.material_override = mat
		var angle: float = (float(i) / 5.0) * TAU
		spike.position = Vector3(cos(angle) * 0.8, 1.0, sin(angle) * 0.8)
		spike.rotation.z = -cos(angle) * 0.4
		spike.rotation.x = sin(angle) * 0.4
		boss.add_child(spike)

func _add_glowing_core(boss: Node3D) -> void:
	var core := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 1.2
	core.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.4)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	core.material_override = mat
	core.position = Vector3(0, 0.8, 0)
	boss.add_child(core)
	var core_light := OmniLight3D.new()
	core_light.light_color = Color(1.0, 0.9, 0.4)
	core_light.light_energy = 5.0
	core_light.omni_range = 10.0
	core_light.position = Vector3(0, 0.8, 0)
	boss.add_child(core_light)

func _add_energy_rings(boss: Node3D) -> void:
	for i in 2:
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 1.4 + i * 0.2
		mesh.outer_radius = 1.6 + i * 0.2
		ring.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.8, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.9, 1.0)
		mat.emission_energy_multiplier = 2.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.7
		ring.material_override = mat
		ring.position = Vector3(0, 0.3 + i * 0.5, 0)
		ring.rotation = Vector3(deg_to_rad(90.0 + i * 30.0), 0, 0)
		boss.add_child(ring)
		var tween := ring.create_tween()
		tween.set_loops()
		tween.tween_property(ring, "rotation:y", TAU, 2.0 + i).from(0.0)

func _add_shadow_tendrils(boss: Node3D) -> void:
	for i in 6:
		var tendril := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.05
		mesh.bottom_radius = 0.15
		mesh.height = 1.5
		tendril.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.05, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.2, 0.8)
		mat.emission_energy_multiplier = 1.5
		tendril.material_override = mat
		var angle: float = (float(i) / 6.0) * TAU
		tendril.position = Vector3(cos(angle) * 1.0, -0.5, sin(angle) * 1.0)
		tendril.rotation.z = cos(angle) * 0.3
		tendril.rotation.x = sin(angle) * 0.3
		boss.add_child(tendril)

func _add_prism_shards(boss: Node3D) -> void:
	var colors := [Color(1, 0, 0), Color(1, 0.5, 0), Color(1, 1, 0), Color(0, 1, 0), Color(0, 0.5, 1), Color(0.7, 0, 1)]
	for i in 6:
		var shard := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.5, 1.0, 0.5)
		shard.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i]
		mat.emission_enabled = true
		mat.emission = colors[i]
		mat.emission_energy_multiplier = 2.0
		shard.material_override = mat
		var angle: float = (float(i) / 6.0) * TAU
		shard.position = Vector3(cos(angle) * 1.8, 0.5, sin(angle) * 1.8)
		shard.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)
		boss.add_child(shard)

# ─── Pattern Controller Script ──────────────────────────────────────────────────
# We generate a small GDScript at runtime that runs the boss's attack patterns.
# This keeps the procedural boss self-contained without modifying enemy_base.

func _make_pattern_script(patterns: Array, _base_damage: int) -> GDScript:
	var src := "extends Node\n"
	src += "var _timer: float = 0.0\n"
	src += "var _phase: int = 0\n"
	src += "var _patterns: Array = " + str(patterns) + "\n"
	src += "var _base_damage: int = " + str(_base_damage) + "\n"
	src += "var _player: Node3D = null\n"
	src += "\n"
	src += "func _physics_process(delta: float) -> void:\n"
	src += "\t_timer += delta\n"
	src += "\t_find_player()\n"
	src += "\tif not _player:\n"
	src += "\t\treturn\n"
	src += "\tvar parent = get_parent()\n"
	src += "\tif not parent or not parent is EnemyBase:\n"
	src += "\t\treturn\n"
	src += "\tif parent.is_dead:\n"
	src += "\t\treturn\n"
	src += "\t# Cycle through patterns every 2.5 seconds.\n"
	src += "\tif _timer >= 2.5:\n"
	src += "\t\t_timer = 0.0\n"
	src += "\t\t_phase = (_phase + 1) % _patterns.size()\n"
	src += "\t\t_execute_pattern(parent)\n"
	src += "\n"
	src += "func _find_player() -> void:\n"
	src += "\tif _player and is_instance_valid(_player):\n"
	src += "\t\treturn\n"
	src += "\t_player = get_tree().get_first_node_in_group(\"player\")\n"
	src += "\n"
	src += "func _execute_pattern(boss: EnemyBase) -> void:\n"
	src += "\tvar pattern: int = _patterns[_phase]\n"
	src += "\tmatch pattern:\n"
	src += "\t\t0: _charge(boss)\n"
	src += "\t\t1: _projectile_fan(boss)\n"
	src += "\t\t2: _shockwave(boss)\n"
	src += "\t\t3: _summon(boss)\n"
	src += "\t\t4: _teleport(boss)\n"
	src += "\t\t5: _beam(boss)\n"
	src += "\t\t6: _gravity_pull(boss)\n"
	src += "\t\t7: _enrage(boss)\n"
	src += "\n"
	src += "func _charge(boss: EnemyBase) -> void:\n"
	src += "\t# Boost speed temporarily for a charge attack.\n"
	src += "\tboss.speed *= 2.0\n"
	src += "\tvar tween = boss.create_tween()\n"
	src += "\ttween.tween_property(boss, \"speed\", boss.speed * 0.5, 1.5)\n"
	src += "\ttween.tween_callback(func(): boss.speed = %s)\n" % str(GameConstants.PROC_BOSS_BASE_SPEED)
	src += "\n"
	src += "func _projectile_fan(boss: EnemyBase) -> void:\n"
	src += "\t# Fire 5 enemy projectiles in a fan toward the player.\n"
	src += "\tif not _player:\n"
	src += "\t\treturn\n"
	src += "\tvar dir = (_player.global_position - boss.global_position).normalized()\n"
	src += "\tvar base_angle = atan2(dir.z, dir.x)\n"
	src += "\tfor i in 5:\n"
	src += "\t\tvar spread = (i - 2.0) * 0.3\n"
	src += "\t\tvar a = base_angle + spread\n"
	src += "\t\tvar vel = Vector3(cos(a), 0.0, sin(a)) * 20.0\n"
	src += "\t\t_spawn_enemy_projectile(boss, vel)\n"
	src += "\n"
	src += "func _shockwave(boss: EnemyBase) -> void:\n"
	src += "	# Spawn a shockwave ring at the boss position.\n"
	src += "	var sw_scene = load(\"res://scenes/entities/shockwave.tscn\")\n"
	src += "	if not sw_scene:\n"
	src += "		return\n"
	src += "	var sw = sw_scene.instantiate()\n"
	src += "	sw.position = boss.global_position\n"
	src += "	get_tree().current_scene.add_child(sw)\n"
	src += "	sw.damage = _base_damage\n"
	src += "	sw.max_radius = 12.0\n"
	src += "\n"
	src += "func _summon(boss: EnemyBase) -> void:\n"
	src += "\t# Spawn 2 enemy_blob minions near the boss.\n"
	src += "\tvar blob_scene = load(\"res://scenes/entities/enemy_blob.tscn\")\n"
	src += "\tif not blob_scene:\n"
	src += "\t\treturn\n"
	src += "\tfor i in 2:\n"
	src += "\t\tvar minion = blob_scene.instantiate()\n"
	src += "\t\tvar angle = (float(i) / 2.0) * TAU\n"
	src += "\t\tminion.position = boss.global_position + Vector3(cos(angle) * 4.0, 1.5, sin(angle) * 4.0)\n"
	src += "\t\tget_tree().current_scene.add_child(minion)\n"
	src += "\t\tif \"enemies\" in GameManager:\n"
	src += "\t\t\tGameManager.enemies.append(minion)\n"
	src += "\t\tif minion is EnemyBase:\n"
	src += "\t\t\tminion.max_hp = 30\n"
	src += "\t\t\tminion.hp = 30\n"
	src += "\t\t\tminion.damage = 8\n"
	src += "\n"
	src += "func _teleport(boss: EnemyBase) -> void:\n"
	src += "\tif not _player:\n"
	src += "\t\treturn\n"
	src += "\t# Teleport behind the player.\n"
	src += "\tvar behind = _player.global_position - _player.global_transform.basis.z * 4.0\n"
	src += "\tboss.global_position = behind + Vector3(0, 1.5, 0)\n"
	src += "\t_spawn_teleport_particles(boss)\n"
	src += "\n"
	src += "func _beam(boss: EnemyBase) -> void:\n"
	src += "\t# Beam attack — damage the player if they're roughly in front of the boss.\n"
	src += "\tif not _player:\n"
	src += "\t\treturn\n"
	src += "\tvar to_player = (_player.global_position - boss.global_position).normalized()\n"
	src += "\tvar forward = -boss.global_transform.basis.z\n"
	src += "\tif forward.dot(to_player) > 0.7 and _player.global_position.distance_to(boss.global_position) < 20.0:\n"
	src += "\t\tif GameManager and GameManager.player_is_alive:\n"
	src += "\t\t\tGameManager.take_damage(_base_damage)\n"
	src += "\n"
	src += "func _gravity_pull(boss: EnemyBase) -> void:\n"
	src += "\t# Pull the player toward the boss for 1.5 seconds.\n"
	src += "\tif not _player:\n"
	src += "\t\treturn\n"
	src += "\tvar tween = boss.create_tween()\n"
	src += "\ttween.set_loops(8)\n"
	src += "\ttween.tween_method(_pull_tick.bind(boss), 0.0, 1.0, 0.18)\n"
	src += "\n"
	src += "func _pull_tick(_t: float, boss: EnemyBase) -> void:\n"
	src += "\tif not _player or not is_instance_valid(_player):\n"
	src += "\t\treturn\n"
	src += "\tvar dir = (boss.global_position - _player.global_position).normalized()\n"
	src += "\t_player.global_position += dir * 0.5\n"
	src += "\n"
	src += "func _enrage(boss: EnemyBase) -> void:\n"
	src += "\t# Permanent enrage — speed + damage boost.\n"
	src += "\tboss.speed *= 1.5\n"
	src += "\tboss.damage = int(boss.damage * 1.4)\n"
	src += "\tvar mesh = boss.get_node_or_null(\"BodyMesh\")\n"
	src += "\tif mesh and mesh.material_override:\n"
	src += "\t\tmesh.material_override.emission_energy_multiplier = 4.0\n"
	src += "\n"
	src += "func _spawn_enemy_projectile(boss: EnemyBase, velocity: Vector3) -> void:\n"
	src += "	var proj_scene = load(\"res://scenes/entities/enemy_projectile.tscn\")\n"
	src += "	if not proj_scene:\n"
	src += "		return\n"
	src += "	var proj = proj_scene.instantiate()\n"
	src += "	proj.position = boss.global_position + Vector3(0, 1.0, 0)\n"
	src += "	get_tree().current_scene.add_child(proj)\n"
	src += "	var spd = velocity.length()\n"
	src += "	if spd > 0.1:\n"
	src += "		proj.direction = velocity / spd\n"
	src += "		proj.speed = spd\n"
	src += "	proj.damage = _base_damage\n"
	src += "\n"
	src += "func _spawn_teleport_particles(boss: EnemyBase) -> void:\n"
	src += "	var light = OmniLight3D.new()\n"
	src += "	light.light_color = Color(0.5, 0.2, 0.8)\n"
	src += "	light.light_energy = 5.0\n"
	src += "	light.omni_range = 8.0\n"
	src += "	light.position = boss.global_position\n"
	src += "\tget_tree().current_scene.add_child(light)\n"
	src += "\tvar tween = light.create_tween()\n"
	src += "\ttween.tween_property(light, \"light_energy\", 0.0, 0.3)\n"
	src += "\ttween.tween_callback(light.queue_free)\n"
	var script := GDScript.new()
	script.source_code = src
	var err := script.reload()
	if err != OK:
		push_warning("[ProcBossGenerator] Pattern script reload error: %d" % err)
	return script