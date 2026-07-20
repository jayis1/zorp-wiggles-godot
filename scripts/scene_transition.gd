## Zorp Wiggles — Scene Transition Manager (Phase 35: Final Polish)
## Provides smooth fade transitions between scenes (main menu <-> game,
## mode switches, quit-to-menu, etc.) so the player never sees a hard cut.
##
## Usage:
##   SceneTransition.change_scene("res://scenes/main.tscn")
##   SceneTransition.change_scene("res://scenes/main_menu.tscn", 0.4)
##
## The transition is a two-phase black overlay:
##   1. Fade IN to black (duration = fade_out_time)
##   2. Change scene at peak black
##   3. Fade OUT from black (duration = fade_in_time)
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
var _overlay: ColorRect = null
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


func _ready() -> void:
	# Build a persistent CanvasLayer + ColorRect that survives scene changes.
	# Layer 1000 sits above the HUD (100) and all shader overlays (50-60).
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 1000
	_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas_layer)

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input until fading
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas_layer.add_child(_overlay)

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


func _process(delta: float) -> void:
	if not _is_transitioning:
		return
	_phase_timer += delta
	_shimmer_phase += delta

	match _phase:
		1:  # Fading out to black
			var t: float = clampf(_phase_timer / _phase_duration, 0.0, 1.0)
			# Ease-in cubic for a smooth accelerate-into-black feel
			var eased: float = t * t * t
			_overlay.color.a = eased
			# Block input once we're mostly faded (prevents stray clicks into the new scene)
			if t > 0.5:
				_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
			if _phase_timer >= _phase_duration:
				_phase = 2
				_phase_timer = 0.0
				_phase_duration = MIN_HOLD_TIME
				_overlay.color.a = 1.0
				# Pulse the shimmer in during the hold
				_shimmer.color.a = 0.35
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
				_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_shimmer.color.a = 0.0

		3:  # Fading in from black
			var t2: float = clampf(_phase_timer / _phase_duration, 0.0, 1.0)
			# Ease-out cubic — fast start, gentle landing
			var eased2: float = 1.0 - (1.0 - t2) * (1.0 - t2) * (1.0 - t2)
			_overlay.color.a = 1.0 - eased2
			if _phase_timer >= _phase_duration:
				_finish_transition()


func _finish_transition() -> void:
	_phase = 0
	_is_transitioning = false
	_overlay.color.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shimmer.color.a = 0.0
	_phase_timer = 0.0
	transition_finished.emit()


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
	_overlay.color.a = 0.0
	_shimmer.color.a = 0.0
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
	_overlay.color.a = 0.0
	_shimmer.color.a = 0.0
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
	if _overlay:
		_overlay.color.a = 0.0
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _shimmer:
		_shimmer.color.a = 0.0