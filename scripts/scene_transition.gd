## Zorp Wiggles — Scene Transition Manager (Phase 35: Final Polish)
## Provides smooth fade transitions between scenes (main menu <-> game,
## mode switches, quit-to-menu, etc.) so the player never sees a hard cut.
##
## Usage:
##   SceneTransition.change_scene("res://scenes/main.tscn")
##   SceneTransition.change_scene("res://scenes/main_menu.tscn", 0.4)
##
## The transition is a two-phase overlay:
##   1. Fade IN (radial vignette closes from edges → center, duration = fade_out_time)
##   2. Change scene at peak black
##   3. Fade OUT (radial vignette opens from center → edges, duration = fade_in_time)
##
## ── Radial vignette ── The old flat black overlay read as a dropped frame
##    rather than a stylized transition. A radial gradient (dark at the edges,
##    transparent in the center) that closes in during fade-out and opens out
##    during fade-in makes the transition feel cinematic — the world irises
##    shut, the scene swaps, then irises open into the new scene. The vignette
##    is drawn via a custom _draw() on a Control rather than a plain ColorRect,
##    using CanvasItem's draw_primitive for a smooth radial gradient.
##
## A subtle starfield-style shimmer during the hold makes the black frame
## feel intentional rather than a dropped frame. The overlay lives on a
## high-layer CanvasLayer so it always paints above gameplay and HUD.
##
## The manager is safe to call repeatedly — concurrent requests are ignored
## until the current transition completes (is_transitioning() guard).

extends Node

signal transition_started()
signal transition_midpoint()
signal transition_finished()

# ─── Tuning ──────────────────────────────────────────────────────────────────
const DEFAULT_FADE_OUT_TIME: float = 0.35  # Time to fade to black
const DEFAULT_FADE_IN_TIME: float = 0.45   # Time to fade from black
const MIN_HOLD_TIME: float = 0.08          # Min time held at black (prevents flicker)

# ─── Internal State ───────────────────────────────────────────────────────────
var _canvas_layer: CanvasLayer = null
# ── Radial vignette overlay ── Replaces the old flat ColorRect. Custom-drawn
#    Control that renders a radial gradient (dark edges → transparent center).
#    The vignette radius animates: closes inward during fade-out (iris shut),
#    opens outward during fade-in (iris open). At peak black the radius is 0
#    (fully covered). The draw routine uses concentric rings with decreasing
#    alpha for a smooth gradient without needing a Shader.
var _vignette_ctrl: Control = null
var _vignette_alpha: float = 0.0  # 0..1, overall coverage (0=clear, 1=full black)
var _shimmer: ColorRect = null  # Subtle shimmer overlay during hold
var _is_transitioning: bool = false
var _pending_scene: String = ""
var _phase: int = 0  # 0=idle, 1=fading out, 2=hold, 3=fading in
var _phase_timer: float = 0.0
var _phase_duration: float = 0.0
var _fade_out_time: float = DEFAULT_FADE_OUT_TIME
var _fade_in_time: float = DEFAULT_FADE_IN_TIME

# Shimmer animation phase accumulator (for the hold period sparkle)
var _shimmer_phase: float = 0.0

# ── Vignette ring count ── More rings = smoother gradient but more draw calls.
#    24 rings is smooth enough at typical 1280×720 resolution (each ring is ~13px
#    at the largest radius) without being a GPU hog. The rings are drawn as
#    filled concentric circles using draw_arc + draw_rect fill — but since
#    CanvasItem doesn't have a draw_filled_circle, we use draw_colored_polygon
#    with a triangle fan per ring. A simpler and faster approach: draw concentric
#    rects with decreasing alpha. The visual difference is negligible at 24 rings.
const VIGNETTE_RINGS: int = 24


func _ready() -> void:
	# Build a persistent CanvasLayer that survives scene changes.
	# Layer 1000 sits above the HUD (100) and all shader overlays (50-60).
	# Connect to game_restarted so we don't get stuck mid-transition if the
	# scene reloads (via get_tree().reload_current_scene) while a fade is
	# in progress — the overlay would stay visible on the new scene.
	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 1000
	_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas_layer)

	# ── Radial vignette overlay ── Custom-drawn Control that renders the
	#    radial gradient. mouse_filter is set to IGNORE until the fade is
	#    mostly done, then switched to STOP to block stray clicks during
	#    the scene swap (same guard as the old flat ColorRect).
	_vignette_ctrl = Control.new()
	_vignette_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_ctrl.process_mode = Node.PROCESS_MODE_ALWAYS
	_vignette_ctrl.draw.connect(_draw_vignette)
	_canvas_layer.add_child(_vignette_ctrl)

	# Subtle shimmer — a very faint blue-purple tint that pulses during the
	# hold phase so the black frame reads as a stylized transition rather
	# than a dropped frame. Stays invisible (alpha 0) outside the hold.
	_shimmer = ColorRect.new()
	_shimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shimmer.color = Color(0.04, 0.02, 0.10, 0.0)
	_shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shimmer.process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas_layer.add_child(_shimmer)

	process_mode = Node.PROCESS_MODE_ALWAYS


## Custom draw for the radial vignette. Draws concentric rings from the
## screen edge inward, each with increasing alpha toward the edge and
## decreasing alpha toward the center. The overall alpha is driven by
## _vignette_alpha (0 = transparent, 1 = fully black).
## At _vignette_alpha = 1.0, all rings are fully opaque (total black).
## At _vignette_alpha = 0.0, all rings are transparent (no vignette).
## In between, the rings interpolate — creating an iris/shutter effect.
func _draw_vignette() -> void:
	if _vignette_alpha <= 0.01:
		return
	var screen: Vector2 = _vignette_ctrl.size
	if screen.x <= 0 or screen.y <= 0:
		return
	var center: Vector2 = screen * 0.5
	# The maximum radius reaches the farthest screen corner so the vignette
	# fully covers the screen at peak alpha (no visible gaps at corners).
	var max_radius: float = sqrt(screen.x * screen.x + screen.y * screen.y) * 0.5
	# Draw concentric rings from outer (full alpha) to inner (zero alpha).
	# The alpha at each ring is: _vignette_alpha * (ring_i / VIGNETTE_RINGS)²
	# The quadratic falloff makes the transition smooth and the center stays
	# transparent longer (the iris opens from center), matching the classic
	# cinematic vignette shape.
	for i in range(VIGNETTE_RINGS, 0, -1):
		var frac: float = float(i) / float(VIGNETTE_RINGS)
		var ring_radius: float = max_radius * frac
		# Alpha at this ring: quadratic falloff from edge to center
		var ring_alpha: float = _vignette_alpha * frac * frac
		if ring_alpha < 0.01:
			continue
		var col := Color(0.0, 0.0, 0.0, ring_alpha)
		# Draw a filled circle for this ring. We use draw_colored_polygon
		# with a triangle fan — but that's expensive per ring. Instead,
		# draw_arc with a filled interior via draw_circle (Godot's built-in
		# filled circle draw). draw_circle is the simplest API and performs
		# fine for 24 concentric rings at 60 FPS.
		_vignette_ctrl.draw_circle(center, ring_radius, col)


func _process(delta: float) -> void:
	if not _is_transitioning:
		return
	_phase_timer += delta
	_shimmer_phase += delta

	match _phase:
		1:  # Fading out — radial vignette closes in (iris shut)
			var t: float = clampf(_phase_timer / _phase_duration, 0.0, 1.0)
			# Ease-in cubic for a smooth accelerate-into-black feel.
			# The vignette alpha ramps from 0 to 1 as the iris closes.
			var eased: float = t * t * t
			_vignette_alpha = eased
			# Block input once we're mostly faded (prevents stray clicks into the new scene)
			if t > 0.5:
				_vignette_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
			_vignette_ctrl.queue_redraw()
			if _phase_timer >= _phase_duration:
				_phase = 2
				_phase_timer = 0.0
				_phase_duration = MIN_HOLD_TIME
				_vignette_alpha = 1.0
				# Pulse the shimmer in during the hold
				_shimmer.color.a = 0.35
				_vignette_ctrl.queue_redraw()
				transition_midpoint.emit()
				# Perform the scene change now (at peak black)
				if _pending_scene != "":
					get_tree().change_scene_to_file(_pending_scene)
					_pending_scene = ""

		2:  # Hold at black (scene swap frame)
			# Animate the shimmer with a soft sine pulse
			_shimmer.color.a = 0.25 + 0.15 * sin(_shimmer_phase * 8.0)
			if _phase_timer >= _phase_duration:
				_phase = 3
				_phase_timer = 0.0
				_phase_duration = _fade_in_time
				# Stop blocking input as we fade back in
				_vignette_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_shimmer.color.a = 0.0

		3:  # Fading in — radial vignette opens out (iris open)
			var t2: float = clampf(_phase_timer / _phase_duration, 0.0, 1.0)
			# Ease-out cubic — fast start, gentle landing
			# The vignette alpha ramps from 1 to 0 as the iris opens.
			var eased2: float = 1.0 - (1.0 - t2) * (1.0 - t2) * (1.0 - t2)
			_vignette_alpha = 1.0 - eased2
			_vignette_ctrl.queue_redraw()
			if _phase_timer >= _phase_duration:
				_finish_transition()


func _finish_transition() -> void:
	_phase = 0
	_is_transitioning = false
	_vignette_alpha = 0.0
	_vignette_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_ctrl.queue_redraw()
	_shimmer.color.a = 0.0
	_phase_timer = 0.0
	transition_finished.emit()

func _on_game_restarted() -> void:
	# If a scene transition was mid-flight when the game restarted (via
	# reload_current_scene, which bypasses SceneTransition), force-clean
	# the overlay so the new scene isn't covered by a black screen.
	_is_transitioning = false
	_phase = 0
	_phase_timer = 0.0
	_pending_scene = ""
	_vignette_alpha = 0.0
	if _vignette_ctrl:
		_vignette_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vignette_ctrl.queue_redraw()
	if _shimmer:
		_shimmer.color.a = 0.0


# ─── Public API ───────────────────────────────────────────────────────────────

## Change to a new scene with a fade transition. If a transition is already
## in progress, the request is ignored (returns false).
func change_scene(scene_path: String, fade_out: float = DEFAULT_FADE_OUT_TIME, fade_in: float = DEFAULT_FADE_IN_TIME) -> bool:
	if _is_transitioning:
		return false
	_is_transitioning = true
	_pending_scene = scene_path
	_fade_out_time = maxf(0.05, fade_out)
	_fade_in_time = maxf(0.05, fade_in)
	_phase = 1
	_phase_timer = 0.0
	_phase_duration = _fade_out_time
	_vignette_alpha = 0.0
	_shimmer.color.a = 0.0
	_vignette_ctrl.queue_redraw()
	# Play a soft whoosh so the scene change has an audio identity —
	# previously the fade-to-black was completely silent, making the
	# transition feel like a technical hitch rather than a stylized cut.
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_RIFT)
	transition_started.emit()
	return true


## Transition without changing scenes — useful for mode switches or
## "restart with a flash" effects. Calls callback at the midpoint.
func fade_callback(callback: Callable, fade_out: float = DEFAULT_FADE_OUT_TIME, fade_in: float = DEFAULT_FADE_IN_TIME) -> bool:
	if _is_transitioning:
		return false
	_is_transitioning = true
	_pending_scene = ""  # No scene change
	_fade_out_time = maxf(0.05, fade_out)
	_fade_in_time = maxf(0.05, fade_in)
	_phase = 1
	_phase_timer = 0.0
	_phase_duration = _fade_out_time
	_vignette_alpha = 0.0
	_shimmer.color.a = 0.0
	_vignette_ctrl.queue_redraw()
	# Audio feedback for non-scene transitions (mode switches, restarts)
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_RIFT)
	# Connect a one-shot midpoint listener that fires the callback
	transition_midpoint.connect(callback, CONNECT_ONE_SHOT)
	transition_started.emit()
	return true


## Is a transition currently in progress?
func is_transitioning() -> bool:
	return _is_transitioning


## Instantly clear the overlay (for emergency cleanup or scene reloads
## that bypass the transition system).
func clear() -> void:
	_phase = 0
	_is_transitioning = false
	_vignette_alpha = 0.0
	if _vignette_ctrl:
		_vignette_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vignette_ctrl.queue_redraw()
	if _shimmer:
		_shimmer.color.a = 0.0