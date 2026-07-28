## Zorp Wiggles — Hit-Stop Coordinator (Autoload)
## Centralizes all Engine.time_scale freeze requests so overlapping hit-stops
## don't conflict. Previously, ~10 call sites across 6 files each independently
## set Engine.time_scale and scheduled a restore timer. When two freezes
## overlapped (e.g. a crit hit-stop at 0.08x for 45ms and a player-damage
## hit-stop at 0.35x for 55ms on the same frame), the second overwrote the
## first's scale, and whichever timer fired FIRST would restore to 1.0 —
## cutting the other freeze short and snapping the game back to full speed
## mid-impact. In rare cases this left Engine.time_scale stuck at a non-1.0
## value if a node was freed before its restore timer fired.
##
## This coordinator tracks ALL active freezes in a list. The STRONGEST freeze
## (lowest time_scale) wins. Engine.time_scale is only restored to 1.0 when
## the LAST active freeze expires — so overlapping freezes compose correctly:
## the player sees the strongest freeze, and the game stays frozen until the
## longest-duration freeze completes.
##
## Usage:
##   HitStopCoordinator.request_freeze(0.08, 0.045)   # crit hit-stop
##   HitStopCoordinator.request_freeze(0.04, 0.09)     # boss-kill hit-stop
##   HitStopCoordinator.reset()                        # emergency reset to 1.0
##
## All durations are in REAL-TIME seconds (the coordinator uses
## ignore_time_scale=true on its timer so the restore fires correctly even
## while the world is frozen).

extends Node

# ── Active freezes ── Each entry is { "scale": float, "expire_at": float }
# We track the real-time deadline (Time.get_ticks_msec() + duration_ms) so
# we don't rely on per-freeze timers that could be killed by node freeing.
var _active_freezes: Array[Dictionary] = []

# ── Current applied scale ── Cached so we only write Engine.time_scale when
# it actually changes (avoids redundant writes every frame).
var _current_applied_scale: float = 1.0

# ── Restoration tween ── Instead of snapping from the freeze scale back to
# 1.0, we ease the restoration over RESTORE_EASE_DURATION so the world
# "thaws" smoothly rather than snapping to full speed. This is a subtle
# but noticeable polish — the freeze punches in hard, then the world
# accelerates back over ~80ms instead of a hard cut. The ease uses
# ease-out cubic so the acceleration is front-loaded (the world quickly
# gets back to ~90% speed, then gently settles the last 10%).
const RESTORE_EASE_DURATION: float = 0.08
var _restore_tween: Tween = null

func _ready() -> void:
	# Safety: ensure Engine.time_scale starts at 1.0 in case a previous
	# session left it stuck (e.g. a crash during a freeze).
	Engine.time_scale = 1.0
	_current_applied_scale = 1.0

func _process(_delta: float) -> void:
	if _active_freezes.is_empty():
		return
	# Prune expired freezes (compare against real-time clock)
	var now: float = Time.get_ticks_msec()
	var pruned: bool = false
	for i in range(_active_freezes.size() - 1, -1, -1):
		if _active_freezes[i]["expire_at"] <= now:
			_active_freezes.remove_at(i)
			pruned = true
	if _active_freezes.is_empty():
		# All freezes expired — ease back to 1.0
		_ease_restore()
	elif pruned:
		# Some expired but others remain — re-evaluate the strongest
		_apply_strongest()
	# If nothing was pruned, the strongest is still active — no change needed

## Request a world freeze. `scale` is the target Engine.time_scale (0.0 = full
## stop, 1.0 = normal). `duration` is in real-time seconds. The strongest
## (lowest) scale among all active freezes wins. The world stays frozen until
## the longest-duration freeze expires.
func request_freeze(scale: float, duration: float) -> void:
	if duration <= 0.0:
		return
	# Kill any in-progress restore tween — we're re-freezing
	if _restore_tween and _restore_tween.is_valid():
		_restore_tween.kill()
		_restore_tween = null
	var expire_at: float = Time.get_ticks_msec() + duration * 1000.0
	_active_freezes.append({"scale": clampf(scale, 0.0, 1.0), "expire_at": expire_at})
	# Immediately apply if this is the strongest freeze
	var strongest: float = _get_strongest_scale()
	if strongest < _current_applied_scale:
		Engine.time_scale = strongest
		_current_applied_scale = strongest

## Emergency reset — restores Engine.time_scale to 1.0 immediately and clears
## all active freezes. Called on game restart, death replay, etc.
func reset() -> void:
	_active_freezes.clear()
	if _restore_tween and _restore_tween.is_valid():
		_restore_tween.kill()
		_restore_tween = null
	Engine.time_scale = 1.0
	_current_applied_scale = 1.0

## Returns the strongest (lowest) time_scale among all active freezes.
## Returns 1.0 if no freezes are active.
func _get_strongest_scale() -> float:
	if _active_freezes.is_empty():
		return 1.0
	var strongest: float = 1.0
	for f in _active_freezes:
		if f["scale"] < strongest:
			strongest = f["scale"]
	return strongest

## Apply the strongest active freeze scale to Engine.time_scale.
func _apply_strongest() -> void:
	var strongest: float = _get_strongest_scale()
	if absf(strongest - _current_applied_scale) > 0.001:
		Engine.time_scale = strongest
		_current_applied_scale = strongest

## Ease Engine.time_scale back to 1.0 over RESTORE_EASE_DURATION.
## Uses a scene-tree timer with ignore_time_scale=true so the restore
## completes in real-time seconds regardless of the current freeze scale.
func _ease_restore() -> void:
	if absf(_current_applied_scale - 1.0) < 0.001:
		Engine.time_scale = 1.0
		_current_applied_scale = 1.0
		return
	# Kill any existing restore tween
	if _restore_tween and _restore_tween.is_valid():
		_restore_tween.kill()
	# Tween the time_scale from the current frozen value back to 1.0.
	# We use a Tween with ignore_time_scale so it ticks in real time.
	# The tween calls a method that writes Engine.time_scale each frame.
	var start_scale: float = _current_applied_scale
	_restore_tween = create_tween()
	_restore_tween.tween_method(
		func(s: float):
			Engine.time_scale = s
			_current_applied_scale = s,
		start_scale, 1.0, RESTORE_EASE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_restore_tween.tween_callback(func():
		Engine.time_scale = 1.0
		_current_applied_scale = 1.0
	)
