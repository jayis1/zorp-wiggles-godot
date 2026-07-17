## Zorp Wiggles — Shader Manager (Phase 9: Shaders & Visual Effects)
## Manages all screen-space post-process shaders for the game:
##   - Biome ambient shaders (heat, frost, chromatic aberration, dissolve, crystal)
##   - Low-HP warning vignette
##   - Boss enrage screen effect
##
## Architecture:
##   Each shader is a .gdshader (canvas_item type) applied to a full-screen
##   ColorRect via ShaderMaterial. The ColorRects are children of a CanvasLayer
##   that sits above the game world but below the HUD. Strength uniforms are
##   smoothly interpolated in _process() for cross-fades on biome change and
##   gradual intensity changes (low-HP, boss enrage).
##
## All ColorRects use MOUSE_FILTER_IGNORE so they never block gameplay input.

extends CanvasLayer

class_name ShaderManager

# ─── Layer ordering ──────────────────────────────────────────────────────────
# Layer 50 = above world (default 0) and most UI, below HUD (layer 100).
# We keep it high enough that the post-process covers the 3D view but the HUD
# (HP bars, minimap, etc.) renders on top, unaffected by the shaders.

# ─── Shader names → loaded Shader resources ──────────────────────────────────
var _shaders: Dictionary = {}  # String -> Shader

# ─── Overlay ColorRects ────────────────────────────────────────────────────────
# _biome_rect: the currently active biome shader overlay (swapped on biome change)
var _biome_rect: ColorRect = null
var _biome_rect_b: ColorRect = null  # Second rect for cross-fading
var _active_biome_rect: int = 0      # 0 = A, 1 = B

# Low-HP and boss-enrage overlays (persistent, strength-modulated)
var _low_hp_rect: ColorRect = null
var _boss_enrage_rect: ColorRect = null

# ─── Strength tracking ───────────────────────────────────────────────────────
var _biome_strength_current: float = 0.0   # For the active biome rect
var _biome_strength_target: float = 0.0
var _biome_shader_name_current: String = ""
var _biome_shader_name_pending: String = ""
var _cross_fade: float = 0.0  # 0 = fully on current, 1 = fully on pending
var _is_cross_fading: bool = false

var _low_hp_strength: float = 0.0
var _low_hp_target: float = 0.0

var _boss_enrage_strength: float = 0.0
var _boss_enrage_target: float = 0.0
var _boss_ref: Node = null

# ── Phase 14: Dimension transition overlay ──
var _dimension_transition_rect: ColorRect = null
var _dimension_transition_active: bool = false
var _dimension_transition_progress: float = 0.0

# ── Phase 9: Biome transition fog overlay ──
# A screen-space fog overlay that smoothly cross-fades between biome fog
# colors and densities when the player crosses biome boundaries. Gives a
# visible "fog roll" effect during transitions.
var _biome_fog_rect: ColorRect = null
var _fog_current_color: Color = Color(0.1, 0.1, 0.2, 1.0)
var _fog_target_color: Color = Color(0.1, 0.1, 0.2, 1.0)
var _fog_current_density: float = 0.02
var _fog_target_density: float = 0.02
var _fog_transition_progress: float = 1.0  # 1 = fully on target
var _fog_elapsed: float = 0.0

# ─── Shader file paths ───────────────────────────────────────────────────────
const SHADER_PATHS: Dictionary = {
	"heat_distortion": "res://assets/shaders/heat_distortion.gdshader",
	"frost_vignette": "res://assets/shaders/frost_vignette.gdshader",
	"chromatic_aberration": "res://assets/shaders/chromatic_aberration.gdshader",
	"dissolve": "res://assets/shaders/dissolve.gdshader",
	"crystal_refraction": "res://assets/shaders/crystal_refraction.gdshader",
	"low_hp_vignette": "res://assets/shaders/low_hp_vignette.gdshader",
	"boss_enrage": "res://assets/shaders/boss_enrage.gdshader",
	"dimension_transition": "res://assets/shaders/dimension_transition.gdshader",
	"biome_transition_fog": "res://assets/shaders/biome_transition_fog.gdshader",
}

func _ready() -> void:
	# Load all shaders upfront so biome transitions are instant
	for key in SHADER_PATHS:
		var path: String = SHADER_PATHS[key]
		var shader: Shader = load(path)
		if shader:
			_shaders[key] = shader
		else:
			push_warning("[ShaderManager] Failed to load shader: %s" % path)

	# Create the two biome overlay rects (A and B for cross-fading)
	_biome_rect = _create_overlay_rect()
	_biome_rect_b = _create_overlay_rect()
	add_child(_biome_rect)
	add_child(_biome_rect_b)

	# Low-HP warning rect
	_low_hp_rect = _create_overlay_rect()
	_low_hp_rect.material = _create_shader_material("low_hp_vignette", 0.0)
	add_child(_low_hp_rect)

	# Boss enrage rect
	_boss_enrage_rect = _create_overlay_rect()
	_boss_enrage_rect.material = _create_shader_material("boss_enrage", 0.0)
	add_child(_boss_enrage_rect)

	# ── Phase 14: Dimension transition rect ──
	_dimension_transition_rect = _create_overlay_rect()
	_dimension_transition_rect.material = _create_shader_material("dimension_transition", 0.0)
	_dimension_transition_rect.visible = false
	add_child(_dimension_transition_rect)

	# ── Phase 9: Biome transition fog rect ──
	_biome_fog_rect = _create_overlay_rect()
	_biome_fog_rect.material = _create_shader_material("biome_transition_fog", 0.0)
	if _biome_fog_rect.material is ShaderMaterial:
		var fm: ShaderMaterial = _biome_fog_rect.material as ShaderMaterial
		fm.set_shader_parameter("fog_color", _fog_current_color)
		fm.set_shader_parameter("fog_density", _fog_current_density)
		fm.set_shader_parameter("transition_progress", 1.0)
	_biome_fog_rect.visible = false
	add_child(_biome_fog_rect)

	# Connect signals
	GameManager.biome_changed.connect(_on_biome_changed)
	GameManager.hp_changed.connect(_on_hp_changed)
	GameManager.boss_spawned.connect(_on_boss_spawned)
	GameManager.boss_defeated.connect(_on_boss_defeated)
	GameManager.player_died.connect(_on_player_died)
	GameManager.game_restarted.connect(_on_game_restarted)

	# ── Phase 14: Dimension transition signals ──
	DimensionSystem.dimension_transition_started.connect(_on_dimension_transition_started)
	DimensionSystem.dimension_transition_ended.connect(_on_dimension_transition_ended)
	DimensionSystem.dimension_changed.connect(_on_dimension_changed)

func _create_overlay_rect() -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(1, 1, 1, 1)  # White — the shader controls the output
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No material by default; set when a shader is assigned
	return rect

func _create_shader_material(shader_name: String, strength: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	if _shaders.has(shader_name):
		mat.shader = _shaders[shader_name]
	mat.set_shader_parameter("strength", strength)
	return mat

func _process(delta: float) -> void:
	if GameManager.is_paused:
		return

	# ── Biome shader cross-fade ──
	if _is_cross_fading:
		_cross_fade = minf(_cross_fade + delta * GameConstants.SHADER_TRANSITION_SPEED, 1.0)
		# Fade out current, fade in pending
		var out_strength: float = _biome_strength_current * (1.0 - _cross_fade)
		var in_strength: float = _biome_strength_target * _cross_fade
		_apply_biome_strength(0, out_strength)
		_apply_biome_strength(1, in_strength)
		if _cross_fade >= 1.0:
			# Cross-fade complete — swap roles
			_active_biome_rect = 1 - _active_biome_rect
			_biome_shader_name_current = _biome_shader_name_pending
			_biome_strength_current = _biome_strength_target
			_biome_shader_name_pending = ""
			_is_cross_fading = false
			# Hide the now-inactive rect
			var inactive_rect: ColorRect = _biome_rect if _active_biome_rect == 1 else _biome_rect_b
			inactive_rect.visible = false
	else:
		# Smoothly approach target strength for the current biome
		var weight: float = 1.0 - exp(-GameConstants.SHADER_TRANSITION_SPEED * delta)
		_biome_strength_current = lerpf(_biome_strength_current, _biome_strength_target, weight)
		_apply_biome_strength(_active_biome_rect, _biome_strength_current)

	# ── Low-HP vignette ──
	var lp_weight: float = 1.0 - exp(-GameConstants.LOW_HP_SHADER_FADE_SPEED * delta)
	_low_hp_strength = lerpf(_low_hp_strength, _low_hp_target, lp_weight)
	if _low_hp_rect and _low_hp_rect.material is ShaderMaterial:
		(_low_hp_rect.material as ShaderMaterial).set_shader_parameter("strength", _low_hp_strength)
		# Hide the rect entirely when strength is negligible (saves GPU)
		_low_hp_rect.visible = _low_hp_strength > 0.01

	# ── Boss enrage ──
	var be_weight: float = 1.0 - exp(-GameConstants.BOSS_ENRAGE_SHADER_FADE_SPEED * delta)
	_boss_enrage_strength = lerpf(_boss_enrage_strength, _boss_enrage_target, be_weight)
	if _boss_enrage_rect and _boss_enrage_rect.material is ShaderMaterial:
		(_boss_enrage_rect.material as ShaderMaterial).set_shader_parameter("strength", _boss_enrage_strength)
		_boss_enrage_rect.visible = _boss_enrage_strength > 0.01
	# Update boss enrage target from boss HP ratio
	_update_boss_enrage_target()

	# ── Phase 14: Dimension transition progress ──
	if _dimension_transition_active:
		_dimension_transition_progress = minf(_dimension_transition_progress + delta / GameConstants.DIMENSION_TRANSITION_DURATION, 1.0)
		if _dimension_transition_rect and _dimension_transition_rect.material is ShaderMaterial:
			var mat: ShaderMaterial = _dimension_transition_rect.material as ShaderMaterial
			mat.set_shader_parameter("progress", _dimension_transition_progress)
			# Sin wave for in-and-out effect: 0→1→0 over the transition
			var visual_progress: float = sin(_dimension_transition_progress * PI)
			mat.set_shader_parameter("progress", visual_progress)

	# ── Phase 9: Biome transition fog ──
	_fog_elapsed += delta
	if _fog_transition_progress < 1.0:
		_fog_transition_progress = minf(_fog_transition_progress + delta / GameConstants.SHADER_TRANSITION_SPEED, 1.0)
		# Cross-fade color and density
		var t: float = _fog_transition_progress
		# Ease-in-out for smooth fog roll
		t = t * t * (3.0 - 2.0 * t)
		var blended_color: Color = _fog_current_color.lerp(_fog_target_color, t)
		var blended_density: float = lerpf(_fog_current_density, _fog_target_density, t)
		if _biome_fog_rect and _biome_fog_rect.material is ShaderMaterial:
			var fm: ShaderMaterial = _biome_fog_rect.material as ShaderMaterial
			fm.set_shader_parameter("fog_color", blended_color)
			fm.set_shader_parameter("fog_density", blended_density)
			fm.set_shader_parameter("transition_progress", t)
		if _fog_transition_progress >= 1.0:
			_fog_current_color = _fog_target_color
			_fog_current_density = _fog_target_density
	# Update time uniform for animated fog drift
	if _biome_fog_rect and _biome_fog_rect.material is ShaderMaterial:
		(_biome_fog_rect.material as ShaderMaterial).set_shader_parameter("time", _fog_elapsed)

# ─── Biome shader application ─────────────────────────────────────────────────
func _apply_biome_strength(rect_idx: int, strength: float) -> void:
	var rect: ColorRect = _biome_rect if rect_idx == 0 else _biome_rect_b
	if not rect or not rect.material is ShaderMaterial:
		return
	(rect.material as ShaderMaterial).set_shader_parameter("strength", strength)
	rect.visible = strength > 0.01

func _on_biome_changed(biome_id: int) -> void:
	var shader_name: String = GameConstants.BIOME_SHADER_MAP.get(biome_id, "")
	var target_strength: float = GameConstants.BIOME_SHADER_STRENGTH.get(biome_id, 0.0)

	if shader_name.is_empty():
		# No shader for this biome — fade out the current one
		_biome_shader_name_pending = ""
		_biome_strength_target = 0.0
	else:
		_biome_shader_name_pending = shader_name
		_biome_strength_target = target_strength

	# Set up the pending rect with the new shader
	var pending_idx: int = 1 - _active_biome_rect
	var pending_rect: ColorRect = _biome_rect if pending_idx == 0 else _biome_rect_b
	if not _biome_shader_name_pending.is_empty():
		pending_rect.material = _create_shader_material(_biome_shader_name_pending, 0.0)
		pending_rect.visible = true
	else:
		pending_rect.visible = false
		pending_rect.material = null

	# Start cross-fade
	_cross_fade = 0.0
	_is_cross_fading = true

	# ── Phase 9: Biome transition fog ──
	# Update fog target color and density from the new biome's fog config.
	# The fog cross-fades smoothly via _process() using an ease-in-out curve.
	var fog_config: Dictionary = GameConstants.BIOME_FOG.get(biome_id, {})
	if not fog_config.is_empty():
		_fog_target_color = fog_config.get("color", Color(0.1, 0.1, 0.2))
		_fog_target_density = fog_config.get("density", 0.02)
	else:
		_fog_target_color = Color(0.1, 0.1, 0.2)
		_fog_target_density = 0.01
	_fog_transition_progress = 0.0
	# Show the fog rect with a moderate strength
	if _biome_fog_rect:
		_biome_fog_rect.visible = true
		if _biome_fog_rect.material is ShaderMaterial:
			(_biome_fog_rect.material as ShaderMaterial).set_shader_parameter("strength", 0.35)

# ─── Low-HP vignette ──────────────────────────────────────────────────────────
func _on_hp_changed(new_hp: int, max_hp: int) -> void:
	if max_hp <= 0 or not GameManager.player_is_alive:
		_low_hp_target = 0.0
		return
	var ratio: float = float(new_hp) / float(max_hp)
	if ratio < GameConstants.LOW_HP_SHADER_THRESHOLD:
		# Scale: at threshold → 0, at 0 HP → max
		var t: float = 1.0 - (ratio / GameConstants.LOW_HP_SHADER_THRESHOLD)
		_low_hp_target = t * GameConstants.LOW_HP_SHADER_MAX_STRENGTH
	else:
		_low_hp_target = 0.0

# ─── Boss enrage ──────────────────────────────────────────────────────────────
func _on_boss_spawned(boss: Node) -> void:
	_boss_ref = boss

func _on_boss_defeated(_boss: Node) -> void:
	_boss_ref = null
	_boss_enrage_target = 0.0

func _update_boss_enrage_target() -> void:
	if _boss_ref == null or not is_instance_valid(_boss_ref):
		_boss_enrage_target = 0.0
		return
	# Only activate enrage shader if the boss has an enrage threshold
	# We check the boss's HP ratio; Drake has enrage at 30% HP
	var boss_hp = _boss_ref.get("hp")
	var boss_max_hp = _boss_ref.get("max_hp")
	if boss_hp == null or boss_max_hp == null or boss_max_hp <= 0:
		_boss_enrage_target = 0.0
		return
	var ratio: float = float(boss_hp) / float(boss_max_hp)
	if ratio < GameConstants.BOSS_ENRAGE_SHADER_THRESHOLD:
		var t: float = 1.0 - (ratio / GameConstants.BOSS_ENRAGE_SHADER_THRESHOLD)
		_boss_enrage_target = t * GameConstants.BOSS_ENRAGE_SHADER_MAX_STRENGTH
	else:
		_boss_enrage_target = 0.0

# ─── Reset on death / restart ─────────────────────────────────────────────────
func _on_player_died() -> void:
	# Fade out low-HP and boss enrage on death
	_low_hp_target = 0.0
	_boss_enrage_target = 0.0

func _on_game_restarted() -> void:
	_low_hp_strength = 0.0
	_low_hp_target = 0.0
	_boss_enrage_strength = 0.0
	_boss_enrage_target = 0.0
	_boss_ref = null
	_biome_strength_current = 0.0
	_biome_strength_target = 0.0
	_is_cross_fading = false
	_cross_fade = 0.0
	_biome_shader_name_current = ""
	_biome_shader_name_pending = ""
	if _biome_rect:
		_biome_rect.visible = false
		_biome_rect.material = null
	if _biome_rect_b:
		_biome_rect_b.visible = false
		_biome_rect_b.material = null
	if _low_hp_rect and _low_hp_rect.material is ShaderMaterial:
		(_low_hp_rect.material as ShaderMaterial).set_shader_parameter("strength", 0.0)
		_low_hp_rect.visible = false
	if _boss_enrage_rect and _boss_enrage_rect.material is ShaderMaterial:
		(_boss_enrage_rect.material as ShaderMaterial).set_shader_parameter("strength", 0.0)
		_boss_enrage_rect.visible = false
	# ── Phase 9: Reset biome fog ──
	_fog_current_color = Color(0.1, 0.1, 0.2, 1.0)
	_fog_target_color = Color(0.1, 0.1, 0.2, 1.0)
	_fog_current_density = 0.02
	_fog_target_density = 0.02
	_fog_transition_progress = 1.0
	if _biome_fog_rect:
		_biome_fog_rect.visible = false
		if _biome_fog_rect.material is ShaderMaterial:
			(_biome_fog_rect.material as ShaderMaterial).set_shader_parameter("strength", 0.0)

# ── Phase 14: Dimension transition handlers ───────────────────────────────────

func _on_dimension_transition_started(target_dim: int) -> void:
	_dimension_transition_active = true
	_dimension_transition_progress = 0.0
	if _dimension_transition_rect:
		_dimension_transition_rect.visible = true
		var dim_color: Color = GameConstants.DIMENSION_COLORS.get(target_dim, Color(0.5, 0.7, 1.0))
		if _dimension_transition_rect.material is ShaderMaterial:
			(_dimension_transition_rect.material as ShaderMaterial).set_shader_parameter("wipe_color", dim_color)
			(_dimension_transition_rect.material as ShaderMaterial).set_shader_parameter("progress", 0.0)

func _on_dimension_transition_ended(_dim: int) -> void:
	_dimension_transition_active = false
	_dimension_transition_progress = 0.0
	if _dimension_transition_rect:
		_dimension_transition_rect.visible = false
		if _dimension_transition_rect.material is ShaderMaterial:
			(_dimension_transition_rect.material as ShaderMaterial).set_shader_parameter("progress", 0.0)

func _on_dimension_changed(new_dim: int, _old_dim: int) -> void:
	# Apply dimension-specific screen tint via biome-like overlay
	# In Void dimension, darken the screen for silhouette mode
	if new_dim == GameConstants.Dimension.VOID:
		# Use a darkened version of the biome shader to simulate the void
		# We'll boost the low-HP-like darkening effect
		pass  # The transition shader handles the visual; persistent void darkening
			  # could be done via a separate overlay, but the silhouettes come from
			  # the world lighting changes handled by DimensionSystem
	elif new_dim == GameConstants.Dimension.TIME_SLOW:
		# Could add a blue time-slow overlay
		pass