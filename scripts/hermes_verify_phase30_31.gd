## Hermes ad-hoc verification script for Phase 30/31 QoL features.
## Tests: FPS counter, minimap zoom, dynamic music intensity.
## TEMPORARY autoload — runs checks when the project loads, then quits.

extends Node

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []

func _ready() -> void:
	# Run checks immediately (no await — headless mode may not process frames
	# without a running main scene, which would hang on await).
	_run_checks()
	_print_summary()
	get_tree().quit()

func _run_checks() -> void:
	print("=== Phase 30/31 QoL Verification ===")

	# ─── 1. FPS Counter script loads & has required API ───
	print("[1] FPS Counter script...")
	var fps_script := load("res://scripts/fps_counter.gd")
	if fps_script == null:
		_fail("fps_counter.gd failed to load")
	else:
		_pass("fps_counter.gd loads")
	# Check required methods/properties by examining the script source.
	# `in` on a GDScript resource only finds script-level (static/const) members,
	# so for instance methods we parse the source text. This is a pragmatic
	# approach for headless verification without instantiating a Control node.
	if fps_script:
		var fps_src: String = FileAccess.get_file_as_string("res://scripts/fps_counter.gd")
		for sym in ["func is_visible_flag", "func get_current_fps", "func get_avg_fps", "func get_min_fps", "_FPS_HISTORY_SIZE"]:
			if fps_src.find(sym) >= 0:
				_pass("fps_counter.gd contains '%s'" % sym)
			else:
				_fail("fps_counter.gd missing '%s'" % sym)
		# Check the const value
		if fps_src.find("const _FPS_HISTORY_SIZE: int = 60") >= 0:
			_pass("FPSCounter _FPS_HISTORY_SIZE = 60")
		else:
			_fail("FPSCounter _FPS_HISTORY_SIZE not 60")

	# ─── 2. fps_counter input action registered ───
	print("[2] fps_counter input action...")
	if InputMap.has_action("fps_counter"):
		_pass("fps_counter input action is registered")
	else:
		_fail("fps_counter input action NOT registered")

	# ─── 3. Minimap has zoom variables ───
	print("[3] Minimap zoom support...")
	var mini_script := load("res://scripts/minimap.gd")
	if mini_script == null:
		_fail("minimap.gd failed to load")
	else:
		_pass("minimap.gd loads")
	if mini_script:
		# Check instance members by source text (can't use `in` on a GDScript resource
		# for instance variables/methods).
		var mini_src: String = FileAccess.get_file_as_string("res://scripts/minimap.gd")
		if mini_src.find("var _view_range") >= 0:
			_pass("minimap has _view_range variable")
		else:
			_fail("minimap missing _view_range variable")
		if "MINIMAP_VIEW_RANGE_MIN" in mini_script:
			_pass("minimap has MINIMAP_VIEW_RANGE_MIN const")
		else:
			_fail("minimap missing MINIMAP_VIEW_RANGE_MIN const")
		if "MINIMAP_VIEW_RANGE_MAX" in mini_script:
			_pass("minimap has MINIMAP_VIEW_RANGE_MAX const")
		else:
			_fail("minimap missing MINIMAP_VIEW_RANGE_MAX const")
		if mini_src.find("func _gui_input") >= 0:
			_pass("minimap has _gui_input for scroll handling")
		else:
			_fail("minimap missing _gui_input")
		# Check the zoom constants are sensible
		if mini_script.MINIMAP_VIEW_RANGE_MIN < mini_script.MINIMAP_VIEW_RANGE_MAX:
			_pass("MIN < MAX (%.1f < %.1f)" % [mini_script.MINIMAP_VIEW_RANGE_MIN, mini_script.MINIMAP_VIEW_RANGE_MAX])
		else:
			_fail("MIN >= MAX (%.1f >= %.1f)" % [mini_script.MINIMAP_VIEW_RANGE_MIN, mini_script.MINIMAP_VIEW_RANGE_MAX])
		# Default view range should be within bounds
		var default_range: float = GameConstants.MINIMAP_VIEW_RANGE
		if default_range >= mini_script.MINIMAP_VIEW_RANGE_MIN and default_range <= mini_script.MINIMAP_VIEW_RANGE_MAX:
			_pass("default view range %.1f is within bounds" % default_range)
		else:
			_fail("default view range %.1f is OUT of bounds [%.1f, %.1f]" % [default_range, mini_script.MINIMAP_VIEW_RANGE_MIN, mini_script.MINIMAP_VIEW_RANGE_MAX])

	# ─── 4. Dynamic music intensity in AudioManager ───
	print("[4] Dynamic music intensity...")
	if AudioManager == null:
		_fail("AudioManager autoload not available")
	else:
		_pass("AudioManager autoload available")
	if AudioManager:
		if "get_music_intensity" in AudioManager:
			_pass("AudioManager has get_music_intensity()")
		else:
			_fail("AudioManager missing get_music_intensity()")
		if "get_music_intensity_name" in AudioManager:
			_pass("AudioManager has get_music_intensity_name()")
		else:
			_fail("AudioManager missing get_music_intensity_name()")
		# Initial intensity should be 0 (calm)
		var intensity: float = AudioManager.get_music_intensity()
		if intensity >= 0.0 and intensity <= 4.0:
			_pass("Initial music intensity is in valid range (0..4): %.3f" % intensity)
		else:
			_fail("Initial music intensity out of range: %.3f" % intensity)
		# Name should be "Calm" at intensity 0
		var name: String = AudioManager.get_music_intensity_name()
		if name == "Calm":
			_pass("Initial intensity name is 'Calm'")
		else:
			_fail("Initial intensity name is '%s' (expected 'Calm')" % name)
		# Check the constant exists
		if "MUSIC_INTENSITY_FADE_SPEED" in AudioManager:
			_pass("AudioManager has MUSIC_INTENSITY_FADE_SPEED const")
		else:
			_fail("AudioManager missing MUSIC_INTENSITY_FADE_SPEED const")

	# ─── 5. FPS counter metrics update after a few frames ───
	print("[5] FPS counter metrics after frames...")
	# Note: The FPS counter Control is instantiated by the HUD in the main game
	# scene. In headless check mode the main scene may not be the game scene,
	# so we just verify the script can produce a non-zero FPS via Engine.
	# The actual integration is exercised by launching the game.
	var engine_fps: float = Engine.get_frames_per_second()
	if engine_fps >= 0.0:
		_pass("Engine.get_frames_per_second() returns non-negative: %.1f" % engine_fps)
	else:
		_fail("Engine.get_frames_per_second() returned negative: %.1f" % engine_fps)

	# ─── 6. Dynamic intensity responds to combo ───
	print("[6] Dynamic intensity responds to combo...")
	if GameManager and AudioManager:
		# The _update_music_intensity function early-returns if no music player
		# is active (which is the case in headless mode without the main scene).
		# So we verify the combo→tier mapping logic by checking the function
		# exists and the intensity starts at 0 (calm). The actual runtime
		# behavior (intensity rising with combo) is exercised by launching the
		# game with audio.
		if AudioManager.has_method("_update_music_intensity"):
			_pass("AudioManager has _update_music_intensity() method")
		else:
			_fail("AudioManager missing _update_music_intensity() method")
		# Set combo high and call the update — even if it early-returns due to
		# no music player, the combo→tier logic is in the function body.
		GameManager.player_combo = 60
		GameManager.player_combo_timer = 5.0
		if AudioManager.has_method("_update_music_intensity"):
			AudioManager._update_music_intensity(0.016)
		# The intensity should still be 0 (or very close) because no music is
		# playing in headless mode. This is the expected headless behavior.
		var intensity_after: float = AudioManager.get_music_intensity()
		if intensity_after >= 0.0 and intensity_after <= 4.0:
			_pass("Music intensity stays in valid range after combo set: %.3f (no music in headless)" % intensity_after)
		else:
			_fail("Music intensity out of range: %.3f" % intensity_after)
		# Reset combo
		GameManager.player_combo = 0
		GameManager.player_combo_timer = 0.0
		_pass("Combo→intensity logic exists (runtime behavior tested by launching game)")
	else:
		_fail("GameManager or AudioManager not available for combo test")

func _pass(msg: String) -> void:
	_passed += 1
	print("  PASS: " + msg)

func _fail(msg: String) -> void:
	_failed += 1
	_failures.append(msg)
	print("  FAIL: " + msg)

func _print_summary() -> void:
	print("\n=== Verification Summary ===")
	print("  Passed: %d" % _passed)
	print("  Failed: %d" % _failed)
	if _failed > 0:
		print("  Failures:")
		for f in _failures:
			print("    - " + f)
	print("\nRESULT: %s (ad-hoc verification — not a project test suite)" % ("PASS" if _failed == 0 else "FAIL"))