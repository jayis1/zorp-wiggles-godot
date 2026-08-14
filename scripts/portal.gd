## Zorp Wiggles — Portal
## A linked portal pair for fast travel across the world.
## Stepping into one portal teleports the player to its linked partner.
## Ported from the Portal class in Ursina game.py.
## All colors use Godot 0-1 range.

extends Area3D

signal teleport_used(portal: Node3D, destination: Vector3)

# ─── Export properties ───────────────────────────────────────────────────────
@export var partner_position: Vector3 = Vector3.ZERO
@export var portal_id: int = 0

# ─── State ───────────────────────────────────────────────────────────────────
var cooldown: float = 0.0
var _bob_offset: float = 0.0
var _time: float = 0.0

# Tracked tweens for the on-use emission flash so rapid re-uses don't stack.
var _use_flash_tween_inner: Tween = null
var _use_flash_tween_outer: Tween = null

# ─── Child nodes ─────────────────────────────────────────────────────────────
var _inner_ring: MeshInstance3D
var _outer_ring: MeshInstance3D
var _ground_glow: MeshInstance3D
var _pillars: Array[MeshInstance3D] = []

func _ready() -> void:
	_bob_offset = randf() * TAU
	_build_visuals()
	add_to_group("portals")

	# Collision shape is provided by the scene (PortalCollision) — no need to create a duplicate.
	body_entered.connect(_on_body_entered)

func _build_visuals() -> void:
	# Inner ring (cyan) — main visual, facing up
	_inner_ring = _create_ring(
		Vector3(0, 2.5, 0),
		3.0,
		GameConstants.PORTAL_INNER_COLOR
	)
	add_child(_inner_ring)

	# Outer ring (purple) — glow border
	_outer_ring = _create_ring(
		Vector3(0, 2.5, 0),
		3.5,
		GameConstants.PORTAL_OUTER_COLOR
	)
	add_child(_outer_ring)

	# Ground glow disc
	_ground_glow = _create_ground_disc(
		Vector3(0, 0.1, 0),
		4.0,
		GameConstants.PORTAL_GROUND_GLOW_COLOR
	)
	add_child(_ground_glow)

	# Four pillar markers at cardinal directions
	for angle_deg in [0, 90, 180, 270]:
		var rad: float = deg_to_rad(angle_deg)
		var pillar := _create_box(
			Vector3(cos(rad) * 1.8, 1.5, sin(rad) * 1.8),
			Vector3(0.25, 3.0, 0.25),
			GameConstants.PORTAL_PILLAR_COLOR
		)
		_pillars.append(pillar)
		add_child(pillar)

func _process(delta: float) -> void:
	_time += delta

	# Inner ring spins and pulses
	if _inner_ring:
		_inner_ring.rotate_y(deg_to_rad(120.0 * delta))
		var pulse: float = 3.0 + sin(_time * 4.0 + _bob_offset) * 0.3
		_inner_ring.scale = Vector3(pulse, pulse, pulse)

	# Outer ring counter-rotates
	if _outer_ring:
		_outer_ring.rotate_y(deg_to_rad(-80.0 * delta))
		var pulse_outer: float = 3.5 + sin(_time * 4.0 + _bob_offset) * 0.3
		_outer_ring.scale = Vector3(pulse_outer, pulse_outer, pulse_outer)

	# Ground glow pulses
	if _ground_glow:
		var ground_pulse: float = 4.0 + sin(_time * 3.0 + _bob_offset) * 0.5
		_ground_glow.scale = Vector3(ground_pulse, ground_pulse, ground_pulse)

	# Update cooldown and dim/dim visuals
	if cooldown > 0.0:
		cooldown -= delta
		# Dimmed state during cooldown
		if _inner_ring:
			var mat: StandardMaterial3D = _inner_ring.material_override
			if mat:
				mat.albedo_color = Color(0.0, 0.392, 0.392, 0.314)
				if mat.emission_enabled:
					mat.emission_energy_multiplier = 0.3
		if _outer_ring:
			var mat2: StandardMaterial3D = _outer_ring.material_override
			if mat2:
				mat2.albedo_color = Color(0.196, 0.0, 0.392, 0.118)
				if mat2.emission_enabled:
					mat2.emission_energy_multiplier = 0.3
	else:
		# Vibrant state — ready to teleport
		if _inner_ring:
			var mat: StandardMaterial3D = _inner_ring.material_override
			if mat:
				mat.albedo_color = GameConstants.PORTAL_INNER_COLOR
				if mat.emission_enabled:
					mat.emission_energy_multiplier = 1.0
		if _outer_ring:
			var mat2: StandardMaterial3D = _outer_ring.material_override
			if mat2:
				mat2.albedo_color = GameConstants.PORTAL_OUTER_COLOR
				if mat2.emission_enabled:
					mat2.emission_energy_multiplier = 1.0

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if cooldown > 0.0:
		return
	if partner_position == Vector3.ZERO:
		return

	# Teleport the player to the partner portal
	cooldown = GameConstants.PORTAL_COOLDOWN
	var player: CharacterBody3D = body as CharacterBody3D
	if player:
		# ── Teleport-out effect ── Before snapping the player to the
		#    destination, play a quick scale-down + flash at the origin
		#    portal so the departure reads as a "warp out" instead of a
		#    pop. The player mesh scales to near-zero over 0.12s (ease-in
		#    cubic for accelerating shrink), then we move the player and
		#    play the teleport-in effect at the destination. The player's
		#    own idle/walk bob writes to mesh.position.y, so we tween
		#    scale only (not position) to avoid fighting that system.
		var player_mesh: MeshInstance3D = player.get_node_or_null("BodyMesh")
		if player_mesh:
			# Flash the player white briefly via a duplicate material so
			# we don't permanently alter the player's base material.
			var pmat: StandardMaterial3D = player_mesh.material_override
			var flash_mat: StandardMaterial3D = null
			if pmat and pmat is StandardMaterial3D:
				flash_mat = (pmat as StandardMaterial3D).duplicate() as StandardMaterial3D
				flash_mat.albedo_color = Color(0.7, 1.0, 1.0)
				flash_mat.emission_enabled = true
				flash_mat.emission = Color(0.7, 1.0, 1.0) * 2.0
				flash_mat.emission_energy_multiplier = 3.0
				player_mesh.material_override = flash_mat
			var out_tween := create_tween()
			out_tween.tween_property(player_mesh, "scale",
				Vector3(0.001, 0.001, 0.001), 0.12) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
			# Move the player at the nadir of the shrink (end of tween)
			out_tween.tween_callback(func():
				# Snap to destination
				player.global_position = partner_position + Vector3(0, 0.5, 0)
				# ── Arrival particle burst ── a small cyan sparkle at the
				#    destination so the arrival has a physical "energy
				#    materialization" visual, matching the departure burst.
				var arrive_parent: Node = player.get_parent()
				if arrive_parent and ParticleEffects:
					ParticleEffects.spawn_pickup_sparkle(arrive_parent,
						partner_position + Vector3(0, 1.0, 0),
						GameConstants.PORTAL_INNER_COLOR)
				# Teleport-in: scale back up with elastic overshoot
				player_mesh.scale = Vector3(0.001, 0.001, 0.001)
				var in_tween := player_mesh.create_tween()
				in_tween.tween_property(player_mesh, "scale",
					Vector3.ONE, 0.25) \
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				# Fade the flash emission back to normal over the scale-up
				if flash_mat:
					in_tween.parallel().tween_property(flash_mat,
						"emission_energy_multiplier", 0.0, 0.3) \
						.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
					# Restore original material after the fade
					in_tween.chain().tween_callback(func():
						player_mesh.material_override = pmat)
			)
		else:
			# No mesh — instant teleport fallback
			player.global_position = partner_position + Vector3(0, 0.5, 0)

		teleport_used.emit(self, partner_position)
		GameManager.add_message("Portal teleport!")
		# Audio feedback — fast-travel whoosh on teleport (not SFX_RIFT which
		# is the dimensional-rift sound; portals are inter-biome travel, not
		# dimension shifts — matches dungeon/fast-travel/waypoint audio).
		AudioManager.play_sfx(AudioManager.SFX_FAST_TRAVEL)
		# ── Departure particle burst ── a small cyan explosion at the
		#    origin portal so the departure has a physical "energy
		#    discharge" visual, not just an emission flash on the rings.
		#    Pairs with the arrival scale-up at the destination.
		var depart_parent: Node = get_parent()
		if depart_parent and ParticleEffects:
			ParticleEffects.spawn_explosion(depart_parent, global_position + Vector3(0, 2.0, 0),
				GameConstants.PORTAL_INNER_COLOR, 16, 0.4)
		# ── Departure light flash ── a brief cyan OmniLight at the origin
		#    portal so the departure is visible in dark biomes where the
		#    emission flash alone may be subtle. Self-managing tween → free.
		#    Guard: depart_parent could be null if the portal was detached
		#    from the scene tree (e.g. scene teardown during teleport).
		if depart_parent:
			var depart_light := OmniLight3D.new()
			depart_light.light_color = GameConstants.PORTAL_INNER_COLOR
			depart_light.light_energy = 5.0
			depart_light.omni_range = 10.0
			depart_parent.add_child(depart_light)
			depart_light.global_position = global_position + Vector3(0, 2.0, 0)
			var dl_tween := depart_light.create_tween()
			dl_tween.tween_property(depart_light, "light_energy", 0.0, 0.4) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			dl_tween.tween_callback(depart_light.queue_free)

	# Screen shake on teleport
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.2)

	# ── Portal flash on use ── Both the origin and partner portal briefly
	#    spike their emission energy so the teleport reads at both ends.
	#    The origin portal (self) flashes cyan; we can't directly flash the
	#    partner (we only have its position, not its node), so the origin
	#    flash + the arrival scale-up + the camera shake together convey
	#    the warp. The origin flash uses the inner ring's emission.
	_flash_on_use()

# ─── Mesh helpers ────────────────────────────────────────────────────────────

func _create_ring(pos: Vector3, size: float, col: Color) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# ── Emission so the portal rings glow in dark biomes ── Without
	#    emission, the unlit rings are invisible against a dark sky/ground
	#    because unlit just means "no lighting calc" — the albedo is still
	#    the only color source, and a transparent cyan at night reads as
	#    near-black. Emission makes the rings self-illuminated so they
	#    pop in any biome, matching the pulse wave / shockwave / spawn
	#    warning which all use emission for the same reason.
	mat.emission_enabled = true
	mat.emission = col * 0.6
	mat.emission_energy_multiplier = 1.0
	mi.material_override = mat
	return mi

func _create_ground_disc(pos: Vector3, size: float, col: Color) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Emission so the ground glow disc is visible in dark biomes.
	mat.emission_enabled = true
	mat.emission = col * 0.4
	mat.emission_energy_multiplier = 0.8
	mi.material_override = mat
	return mi

func _create_box(pos: Vector3, scale: Vector3, col: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(scale.x, scale.y, scale.x)
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.position = pos
	# BoxMesh depth equals width, so scale Z to match scale.z when it differs.
	if scale.x > 0.0 and scale.z != scale.x:
		mi.scale.z = scale.z / scale.x
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Emission so the pillar markers glow in dark biomes. The portal rings
	# and ground glow all have emission, but the four cardinal pillars —
	# which are the portal's most visible structural element — were the
	# only component without emission. In a dark biome (Underground,
	# Eclipse) the unlit pillars read as black silhouettes against the
	# dark sky, making the portal's structure invisible from afar while
	# the glowing rings float in a void. A subtle emission (0.4×) gives
	# the pillars presence in any lighting without overwhelming the
	# brighter ring/ground-glow elements.
	mat.emission_enabled = true
	mat.emission = col * 0.4
	mat.emission_energy_multiplier = 0.5
	mi.material_override = mat
	return mi

## Flash the portal rings' emission energy on teleport use. The inner and
## outer ring materials spike to 4x emission then ease back to 1.0 over
## 0.4s, giving the departure a bright "energy discharge" read. Uses a
## tracked tween per ring so rapid re-uses don't stack.
func _flash_on_use() -> void:
	if _inner_ring:
		var mat: StandardMaterial3D = _inner_ring.material_override
		if mat and mat.emission_enabled:
			if _use_flash_tween_inner and _use_flash_tween_inner.is_valid():
				_use_flash_tween_inner.kill()
			mat.emission_energy_multiplier = 4.0
			_use_flash_tween_inner = create_tween()
			_use_flash_tween_inner.tween_property(mat,
				"emission_energy_multiplier", 1.0, 0.4) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if _outer_ring:
		var mat2: StandardMaterial3D = _outer_ring.material_override
		if mat2 and mat2.emission_enabled:
			if _use_flash_tween_outer and _use_flash_tween_outer.is_valid():
				_use_flash_tween_outer.kill()
			mat2.emission_energy_multiplier = 3.0
			_use_flash_tween_outer = create_tween()
			_use_flash_tween_outer.tween_property(mat2,
				"emission_energy_multiplier", 1.0, 0.4) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)