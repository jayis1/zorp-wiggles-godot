## Zorp Wiggles — Tutorial Manager (Phase 31: QoL)
## Autoload singleton that provides a guided first-time player experience.
## Shows contextual tooltip overlays when the player encounters each core
## mechanic for the first time (movement, shooting, dashing, picking up
## items, leveling, crafting, etc.).
##
## Design:
##   - Tutorial steps fire based on *gameplay triggers*, not timers — e.g.
##     "shoot your first shot", "pick up your first item", "reach level 2".
##     This means the tutorial adapts to how the player actually plays.
##   - Each step shows a dismissible tooltip panel near the bottom-center
##     of the screen with a title, description, and "Got it!" button.
##   - Progress is persisted to `user://zorp_tutorial.json` so the tutorial
##     only plays once per install (unless reset from settings).
##   - `tutorial_completed` is set true after the last step, after which no
##     more tooltips appear. `skip_tutorial()` dismisses the current step
##     and marks the tutorial as complete.
##   - The tutorial can be replayed from the settings menu via `replay()`.
##
## The tooltip UI is a Control node added to the HUD canvas layer (so it
## renders above gameplay but below pause/menu overlays).

extends Node

const SAVE_PATH: String = "user://zorp_tutorial.json"

# Tutorial step IDs (used as keys in the completed dict)
enum Step {
	MOVEMENT,       # "Use WASD to move"
	SHOOTING,       # "Click to shoot"
	DASHING,        # "Space to dash"
	PICKUP,         # "Walk over items to collect"
	LEVEL_UP,       # "You leveled up! XP bar fills"
	COMBAT_COMBO,   # "Chain kills for combo bonuses"
	CRAFTING,       # "Press C to craft weapon mods"
	PET,            # "Press F to summon your pet"
	BIOME,          # "You entered a new biome"
	WEATHER,        # "Weather changes affect gameplay"
	BOSS,           # "A boss appeared!"
	DIMENSION,      # "Dimensional rifts open periodically"
}

# Step metadata: title, description, and the trigger that fires it.
const STEP_DEFS: Dictionary = {
	Step.MOVEMENT: {
		"title": "🚶 Move with WASD",
		"desc": "Use W A S D to move around the alien world.\nRight-click + drag to rotate the camera.",
	},
	Step.SHOOTING: {
		"title": "🔫 Click to Shoot",
		"desc": "Left-click to fire your laser at enemies.\nAim with the mouse cursor.",
	},
	Step.DASHING: {
		"title": "💨 Dash with Space",
		"desc": "Press Space to dash — you're invulnerable during the dash!\nUse it to dodge enemy attacks.",
	},
	Step.PICKUP: {
		"title": "✨ Collect Items",
		"desc": "Walk over glowing items to collect them.\nXP orbs level you up. Materials unlock weapon mods.",
	},
	Step.LEVEL_UP: {
		"title": "⬆ Level Up!",
		"desc": "You leveled up! Your HP and damage increased.\nCollect more XP to reach higher levels.",
	},
	Step.COMBAT_COMBO: {
		"title": "🔥 Combo Chain!",
		"desc": "Kill enemies quickly to build a combo multiplier.\nHigher combos = bonus XP and milestones!",
	},
	Step.CRAFTING: {
		"title": "🔧 Craft Weapon Mods (C)",
		"desc": "Press C to open the crafting menu.\nCombine materials to discover new weapon mods.",
	},
	Step.PET: {
		"title": "🐾 Summon Pet (F)",
		"desc": "Press F to summon your alien companion pet.\nIt auto-collects items and evolves as you feed it.\nPress Shift+Q to view the Pet Questline!",
	},
	Step.BIOME: {
		"title": "🌍 New Biome",
		"desc": "You entered a new biome! Each biome has unique\nterrain, enemies, weather, and mutations.",
	},
	Step.WEATHER: {
		"title": "🌦 Weather Changed",
		"desc": "Weather affects gameplay — rain damages you,\nsolar flares boost energy, fog hides enemies.",
	},
	Step.BOSS: {
		"title": "⚔ Boss Fight!",
		"desc": "A boss has appeared! Defeat it for rare loot.\nWatch for its telegraphed attacks.",
	},
	Step.DIMENSION: {
		"title": "🌀 Dimensional Rift",
		"desc": "Dimensional rifts open periodically. Enter one\nto shift dimensions with wild gameplay changes.",
	},
}

# Steps that have been completed (shown at least once)
var _completed: Dictionary = {}
# Whether the tutorial has been entirely finished
var tutorial_completed: bool = false
# The currently-shown step ("" = none)
var _current_step: int = -1
# The tooltip UI node
var _tooltip: Control = null
# Whether the tooltip is currently visible
var _tooltip_visible: bool = false
# Retry counter for HUD creation
var _create_retries: int = 0

signal step_shown(step: int)
signal step_completed(step: int)
signal tutorial_finished()

const MAX_CREATE_RETRIES: int = 30  # Max attempts to find HUD


func _ready() -> void:
	_load_progress()
	# Connect to gameplay signals that trigger tutorial steps
	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)
		GameManager.boss_spawned.connect(_on_boss_spawned)
		GameManager.biome_changed.connect(_on_biome_changed)
		GameManager.level_up.connect(_on_level_up)
		GameManager.combo_changed.connect(_on_combo_changed)
	if WeatherSystem:
		WeatherSystem.weather_transition_started.connect(_on_weather_changed)
	if DimensionSystem:
		DimensionSystem.dimension_changed.connect(_on_dimension_changed)
	# Defer UI creation until the HUD exists
	call_deferred("_create_tooltip_ui")


func _process(_delta: float) -> void:
	# Check for movement tutorial trigger (player has moved a bit)
	if not tutorial_completed and not _completed.has(Step.MOVEMENT):
		if GameManager and GameManager.player and is_instance_valid(GameManager.player):
			if GameManager.player.global_position.length() > 3.0:
				_show_step(Step.MOVEMENT)


# ── Public API ──────────────────────────────────────────────────────────────

## Show a specific tutorial step (if not already completed).
func _show_step(step: int) -> void:
	if tutorial_completed:
		return
	if _completed.has(step):
		return
	if not STEP_DEFS.has(step):
		return
	_current_step = step
	_completed[step] = true
	_save_progress()
	step_shown.emit(step)
	_display_tooltip(step)


## Dismiss the current tooltip and mark the step complete.
func dismiss_current() -> void:
	if _current_step < 0:
		return
	step_completed.emit(_current_step)
	_current_step = -1
	_hide_tooltip()
	# Check if all steps are done
	_check_tutorial_complete()


## Skip the entire tutorial (from settings or Esc on a tooltip).
func skip_tutorial() -> void:
	tutorial_completed = true
	_current_step = -1
	_hide_tooltip()
	# Mark all steps as completed so they never fire again
	for step in STEP_DEFS:
		_completed[step] = true
	_save_progress()
	tutorial_finished.emit()


## Replay the tutorial from the beginning (from settings menu).
func replay() -> void:
	tutorial_completed = false
	_completed.clear()
	_current_step = -1
	_hide_tooltip()
	_save_progress()
	GameManager.add_message("🎓 Tutorial will replay as you play")


## Has the tutorial been completed?
func is_completed() -> bool:
	return tutorial_completed


## Get the number of completed steps (for settings display).
func get_completed_count() -> int:
	return _completed.size()


## Get the total number of tutorial steps.
func get_total_steps() -> int:
	return STEP_DEFS.size()


# ── Trigger handlers ─────────────────────────────────────────────────────────

func _on_game_restarted() -> void:
	# Don't reset tutorial progress on restart — it's a one-time thing
	pass


func _on_boss_spawned(_boss: Node) -> void:
	_show_step(Step.BOSS)


func _on_biome_changed(_biome_id: int) -> void:
	# Only show the biome tutorial for the SECOND biome (the first is the
	# starting biome — showing a tooltip immediately on spawn is jarring).
	if _completed.size() > 2:  # At least a couple of other steps done
		_show_step(Step.BIOME)


func _on_level_up(level: int) -> void:
	if level == 2:
		_show_step(Step.LEVEL_UP)


func _on_combo_changed(combo: int) -> void:
	if combo >= 3:
		_show_step(Step.COMBAT_COMBO)


func _on_weather_changed(_weather: int) -> void:
	_show_step(Step.WEATHER)


func _on_dimension_changed(_new_dim: int, _old_dim: int) -> void:
	_show_step(Step.DIMENSION)


# Called by player.gd when the player shoots for the first time
func notify_first_shot() -> void:
	_show_step(Step.SHOOTING)


# Called by player.gd when the player dashes for the first time
func notify_first_dash() -> void:
	_show_step(Step.DASHING)


# Called by collectible.gd when the player picks up their first item
func notify_first_pickup() -> void:
	_show_step(Step.PICKUP)


# Called by crafting_menu.gd when the player opens crafting for the first time
func notify_crafting_opened() -> void:
	_show_step(Step.CRAFTING)


# Called by player.gd when the player summons their pet for the first time
func notify_pet_summoned() -> void:
	_show_step(Step.PET)


# ── Tooltip UI ───────────────────────────────────────────────────────────────

func _create_tooltip_ui() -> void:
	# Find the HUD canvas layer and add the tooltip to it
	var hud: CanvasLayer = null
	var main: Node = get_tree().current_scene
	if main:
		hud = main.get_node_or_null("HUD")
	if not hud:
		# HUD not ready yet — retry with a limit (avoids infinite loop in
		# the main menu scene where there's no HUD)
		_create_retries += 1
		if _create_retries < MAX_CREATE_RETRIES:
			call_deferred("_create_tooltip_ui")
		return
	_create_retries = 0
	_tooltip = Control.new()
	_tooltip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through except on the panel
	_tooltip.visible = false
	hud.add_child(_tooltip)
	_build_tooltip()


func _build_tooltip() -> void:
	if not _tooltip:
		return
	# Semi-transparent background panel (bottom-center)
	var panel := Panel.new()
	panel.offset_left = 340.0
	panel.offset_top = 540.0
	panel.offset_right = 940.0
	panel.offset_bottom = 690.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_tooltip.add_child(panel)
	_tooltip.set_meta("_panel", panel)

	# Title label
	var title := Label.new()
	title.offset_left = 360.0
	title.offset_top = 550.0
	title.offset_right = 920.0
	title.offset_bottom = 590.0
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_tooltip.add_child(title)
	_tooltip.set_meta("_title", title)

	# Description label
	var desc := Label.new()
	desc.offset_left = 360.0
	desc.offset_top = 595.0
	desc.offset_right = 920.0
	desc.offset_bottom = 645.0
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_tooltip.add_child(desc)
	_tooltip.set_meta("_desc", desc)

	# "Got it!" button
	var got_it := Button.new()
	got_it.offset_left = 540.0
	got_it.offset_top = 650.0
	got_it.offset_right = 640.0
	got_it.offset_bottom = 680.0
	got_it.text = "Got it!"
	got_it.add_theme_font_size_override("font_size", 14)
	got_it.pressed.connect(dismiss_current)
	_tooltip.add_child(got_it)
	_tooltip.set_meta("_got_it", got_it)

	# "Skip Tutorial" button
	var skip_btn := Button.new()
	skip_btn.offset_left = 660.0
	skip_btn.offset_top = 650.0
	skip_btn.offset_right = 800.0
	skip_btn.offset_bottom = 680.0
	skip_btn.text = "Skip Tutorial"
	skip_btn.add_theme_font_size_override("font_size", 12)
	skip_btn.pressed.connect(skip_tutorial)
	_tooltip.add_child(skip_btn)
	_tooltip.set_meta("_skip", skip_btn)


func _display_tooltip(step: int) -> void:
	if not _tooltip:
		return
	var def: Dictionary = STEP_DEFS[step]
	var title: Label = _tooltip.get_meta("_title")
	var desc: Label = _tooltip.get_meta("_desc")
	if title:
		title.text = def["title"]
	if desc:
		desc.text = def["desc"]
	_tooltip.visible = true
	_tooltip_visible = true
	# Fade-in animation
	var panel: Panel = _tooltip.get_meta("_panel")
	if panel:
		panel.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(panel, "modulate:a", 1.0, 0.25) \
			.set_ease(Tween.EASE_OUT)


func _hide_tooltip() -> void:
	if not _tooltip:
		return
	_tooltip_visible = false
	var panel: Panel = _tooltip.get_meta("_panel")
	if panel:
		var tween := create_tween()
		tween.tween_property(panel, "modulate:a", 0.0, 0.2) \
			.set_ease(Tween.EASE_IN)
		tween.tween_callback(func():
			_tooltip.visible = false
		)
	else:
		_tooltip.visible = false


func _check_tutorial_complete() -> void:
	# Tutorial is "complete" when all steps have been shown at least once.
	# (We don't require the player to dismiss each one — showing is enough.)
	if _completed.size() >= STEP_DEFS.size():
		tutorial_completed = true
		_save_progress()
		tutorial_finished.emit()


# ── Persistence ──────────────────────────────────────────────────────────────

func _save_progress() -> void:
	var data := {
		"completed": _completed,
		"tutorial_completed": tutorial_completed,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var completed = data.get("completed", {})
	if typeof(completed) == TYPE_DICTIONARY:
		for key in completed:
			_completed[int(key)] = true
	tutorial_completed = bool(data.get("tutorial_completed", false))