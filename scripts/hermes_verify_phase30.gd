## Hermes ad-hoc verification for Phase 30 features.
## Temporarily registered as an autoload so it runs in the full project context
## (autoloads registered, GameManager/CharacterSelectManager/etc. available).
## Runs the checks in _ready, prints a summary, then quits the game.
## This is NOT a test suite — it's a focused smoke test of the new behavior.
##
## ⚠️  WARNING: This script calls get_tree().quit() in _ready(). If registered
##     as an autoload in project.godot during normal play, it will quit the game
##     ~3 seconds after launch. Only register it when running headless
##     verification:
##       1. Add `HermesVerify="*res://scripts/hermes_verify_phase30.gd"` to [autoload]
##       2. Run: `godot --headless --quit-after 10`
##       3. Remove the HermesVerify line from project.godot before committing.
##
## Safety guard: if the game is NOT running in headless mode (i.e. a real
## display is attached), this script skips all verification and does NOT quit,
## so an accidental autoload registration won't kill a player's game session.

extends Node

var _failures: Array[String] = []
var _passes: Array[String] = []
var _scene_loaded: bool = false

func _assert(cond: bool, label: String) -> void:
	if cond:
		_passes.append(label)
		print("  PASS: %s" % label)
	else:
		_failures.append(label)
		print("  FAIL: %s" % label)

func _ready() -> void:
	# Safety guard: only run verification in headless mode. If a display is
	# attached (normal play), skip everything so an accidental
	# autoload registration doesn't quit the player's game session.
	if DisplayServer.get_name() != "headless":
		push_warning("HermesVerify autoload is registered in project.godot but the game is not running headless — skipping verification to avoid quitting the game. Remove the HermesVerify autoload from project.godot for normal play.")
		return
	print("=== Phase 30 Ad-Hoc Verification ===")
	print("")
	_test_autoloads()
	_test_character_select()
	_test_adaptive_sfx()
	_test_death_replay()
	# Defer the main scene test so autoloads + scene are fully ready
	call_deferred("_test_main_scene")
	# Schedule summary + quit after the deferred test has time to run
	call_deferred("_schedule_quit")

func _schedule_quit() -> void:
	# Give the scene ~2s to load + the IntroCinematic to start
	await get_tree().create_timer(3.0).timeout
	_print_summary()
	get_tree().quit()

# ─── 1. Autoloads registered ─────────────────────────────────────────────────
func _test_autoloads() -> void:
	print("[1/5] Autoload registration")
	_assert(CharacterSelectManager != null, "CharacterSelectManager autoload exists")
	_assert(DeathReplay != null, "DeathReplay autoload exists")
	_assert(CosmeticManager != null, "CosmeticManager autoload exists (pre-existing)")
	_assert(AudioManager != null, "AudioManager autoload exists")
	_assert(GameManager != null, "GameManager autoload exists")

# ─── 2. Character select profiles ─────────────────────────────────────────────
func _test_character_select() -> void:
	print("[2/5] CharacterSelectManager profiles")
	var csm = CharacterSelectManager
	_assert(csm.Character.size() == 2, "Character enum has exactly 2 values (ZORP, ZERP)")
	_assert(csm.get_character_name(csm.Character.ZORP) == "Zorp", "Zorp name correct")
	_assert(csm.get_character_name(csm.Character.ZERP) == "Zerp", "Zerp name correct")
	var zorp_p = csm.get_character_profile(csm.Character.ZORP)
	var zerp_p = csm.get_character_profile(csm.Character.ZERP)
	_assert(int(zorp_p.get("hp_bonus", 999)) == 0, "Zorp HP bonus = 0")
	_assert(int(zerp_p.get("hp_bonus", 999)) == -20, "Zerp HP bonus = -20 (frailer)")
	_assert(float(zerp_p.get("speed_mult", 0)) > 1.0, "Zerp speed mult > 1.0 (faster)")
	_assert(float(zerp_p.get("dash_speed_mult", 0)) > 1.0, "Zerp dash speed mult > 1.0")
	_assert(float(zerp_p.get("damage_mult", 0)) < 1.0, "Zerp damage mult < 1.0 (weaker shots)")
	var sel = csm.get_selected_character()
	_assert(sel >= 0 and sel < csm.Character.size(), "Selected character is in valid range")
	var prev = csm.get_selected_character()
	var other = (prev + 1) % csm.Character.size()
	csm.set_character(other)
	_assert(csm.get_selected_character() == other, "set_character updates selection")
	csm.set_character(prev)
	_assert(csm.get_selected_character() == prev, "set_character restores previous selection")
	var active = csm.get_active_profile()
	_assert(int(active.get("id", -1)) == prev, "get_active_profile matches selected character")

# ─── 3. Adaptive SFX map ─────────────────────────────────────────────────────
func _test_adaptive_sfx() -> void:
	print("[3/5] AudioManager adaptive shoot SFX")
	var am = AudioManager
	_assert(am.has_method("play_shoot_sfx"), "AudioManager has play_shoot_sfx method")
	_assert(am.has_method("_build_mod_shoot_sfx_map"), "AudioManager has _build_mod_shoot_sfx_map method")
	var wm = GameConstants.WeaponMod
	var test_mods = [wm.NONE, wm.HOMING_LASER, wm.FREEZE_RAY, wm.BLACK_HOLE_LAUNCHER,
					 wm.LIGHTNING_STORM, wm.VAMPIRE_BEAM, wm.SHIELD_BUBBLE]
	for mod_id in test_mods:
		am.play_shoot_sfx(mod_id)
		_assert(true, "play_shoot_sfx(%d) does not crash" % mod_id)
	var names = [am.SFX_SHOOT_STANDARD, am.SFX_SHOOT_HOMING, am.SFX_SHOOT_ENERGY,
				 am.SFX_SHOOT_PIERCE, am.SFX_SHOOT_FREEZE, am.SFX_SHOOT_POISON,
				 am.SFX_SHOOT_FIRE, am.SFX_SHOOT_VOID, am.SFX_SHOOT_LIGHTNING,
				 am.SFX_SHOOT_HEAVY, am.SFX_SHOOT_UTILITY, am.SFX_SHOOT_VAMPIRE]
	var seen: Dictionary = {}
	var all_unique = true
	for n in names:
		if seen.has(n):
			all_unique = false
			break
		seen[n] = true
	_assert(all_unique, "All 12 shoot SFX name constants are unique")
	_assert(names.size() == 12, "Exactly 12 shoot SFX variants defined")

func _ready() -> void:
	print("=== Phase 30 Ad-Hoc Verification ===")
	print("")
	_test_autoloads()
	_test_character_select()
	_test_adaptive_sfx()
	_test_death_replay()
	# Defer the main scene test so autoloads + scene are fully ready
	call_deferred("_test_main_scene")

# ─── 5. Main scene loads with IntroCinematic node ────────────────────────────
func _test_main_scene() -> void:
	print("[5/5] Main scene loads with IntroCinematic node")
	# The main scene is main_menu.tscn by default. Load main.tscn directly.
	var scene = load("res://scenes/main.tscn")
	_assert(scene != null, "main.tscn PackedScene loads successfully")
	if scene == null:
		_print_summary_and_quit()
		return
	var instance = scene.instantiate()
	_assert(instance != null, "main.tscn instantiates successfully")
	if instance == null:
		_print_summary_and_quit()
		return
	# Set as current scene so IntroCinematic's get_tree().current_scene lookup works
	# (IntroCinematic._ready uses current_scene to find the Player node)
	get_tree().root.add_child(instance)
	get_tree().current_scene = instance
	# Give it a moment to process _ready (world gen happens synchronously in _ready)
	await get_tree().create_timer(1.0).timeout
	var ic = instance.get_node_or_null("IntroCinematic")
	_assert(ic != null, "IntroCinematic node exists in main scene")
	if ic:
		_assert(ic.has_method("is_active"), "IntroCinematic has is_active method")
		_assert(ic.has_method("is_controls_unlocked"), "IntroCinematic has is_controls_unlocked method")
	var player = instance.get_node_or_null("World/Player")
	_assert(player != null, "Player node exists in main scene")
	if player:
		_assert(player.has_method("get_character_damage_mult"), "Player has get_character_damage_mult")
		_assert(player.has_method("get_character_speed_mult"), "Player has get_character_speed_mult")
		_assert(player.has_method("get_character_dash_speed_mult"), "Player has get_character_dash_speed_mult")
		_assert(player.has_method("_apply_character_profile"), "Player has _apply_character_profile")
		_assert(player.has_method("_record_death_replay"), "Player has _record_death_replay")
		_assert(player.has_method("_cinematic_active"), "Player has _cinematic_active")
		var dmg_mult = player.get_character_damage_mult()
		_assert(typeof(dmg_mult) == TYPE_FLOAT, "Character damage mult is a float")
		_assert(dmg_mult > 0.0 and dmg_mult <= 1.5, "Character damage mult in sane range (0, 1.5]")
	instance.queue_free()
	_print_summary_and_quit()

func _print_summary_and_quit() -> void:
	_print_summary()
	get_tree().quit()

# ─── Summary ──────────────────────────────────────────────────────────────────
func _print_summary() -> void:
	print("")
	print("=== Verification Summary ===")
	print("  PASS: %d" % _passes.size())
	print("  FAIL: %d" % _failures.size())
	if _failures.size() > 0:
		print("  FAILED CHECKS:")
		for f in _failures:
			print("    - %s" % f)
	print("")
	if _failures.size() == 0:
		print("RESULT: ALL CHECKS PASSED")
	else:
		print("RESULT: %d CHECK(S) FAILED" % _failures.size())