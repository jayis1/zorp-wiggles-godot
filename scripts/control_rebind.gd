## Zorp Wiggles — Control Rebinding System (Phase 31: QoL)
## Autoload singleton that lets the player customize all input action key
## bindings and persists them to `user://zorp_rebind.json`.
##
## Architecture:
##   - On _ready, we snapshot the default InputMap actions (the ones defined in
##     project.godot) so we can restore them later. We then load any saved
##     overrides from disk and apply them.
##   - `rebind_action(action_name, new_event)` replaces the primary event for
##     the given action. The old event is removed and the new one is inserted
##     at index 0 (so it's the first event InputMap checks).
##   - `reset_to_defaults()` restores all actions to their project.godot
##     defaults and clears the save file.
##   - The rebind UI (`control_rebind_menu.gd`) is a full-screen overlay
##     listing all rebindable actions with their current keys; clicking one
##     puts it in "listening" mode where the next key/mouse press becomes the
##     new binding.
##
## Only the *primary* event of each action is rebound — secondary events
## (e.g. arrow keys for P2) are left alone. This keeps the rebind UI simple
## and predictable. Co-op P2 actions are intentionally not rebindable here
## (they have a fixed layout to avoid conflicts with P1).
##
## Persisted as a Dictionary { action_name: { "type": "key"/"mouse",
## "keycode": int, "physical": int, "button": int, "unicode": int } }.

extends Node

const SAVE_PATH: String = "user://zorp_rebind.json"

# Actions the player can rebind (P1 only — P2 co-op actions are fixed).
# These match the input actions defined in project.godot.
const REBINDABLE_ACTIONS: Array[String] = [
	"move_up", "move_down", "move_left", "move_right",
	"shoot", "dash", "pulse_wave", "trade", "minimap", "missions", "pause",
	"summon_pet", "pet_fetch", "use_stone", "crafting", "stats_page",
	"skill_tree", "interact", "deploy_ability", "fast_travel", "equipment",
	"fps_counter", "ping", "cycle_color_filter", "cycle_colorblind",
	"photo_mode", "cycle_skin", "cycle_character",
]

# Friendly display names for each action (shown in the rebind UI).
const ACTION_DISPLAY_NAMES: Dictionary = {
	"move_up": "Move Up",
	"move_down": "Move Down",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"shoot": "Shoot",
	"dash": "Dash",
	"pulse_wave": "Pulse Wave",
	"trade": "Trade",
	"minimap": "Toggle Minimap",
	"missions": "Missions Log",
	"pause": "Pause",
	"summon_pet": "Summon/Dismiss Pet",
	"pet_fetch": "Pet Fetch",
	"use_stone": "Use Pet Stone",
	"crafting": "Crafting Menu",
	"stats_page": "Statistics Page",
	"skill_tree": "Skill Tree",
	"interact": "Interact",
	"deploy_ability": "Deploy Ability",
	"fast_travel": "Fast Travel",
	"equipment": "Equipment Menu",
	"fps_counter": "FPS Counter",
	"ping": "Ping",
	"cycle_color_filter": "Color Filter",
	"cycle_colorblind": "Colorblind Mode",
	"photo_mode": "Photo Mode",
	"cycle_skin": "Cycle Skin",
	"cycle_character": "Cycle Character",
}

# Human-readable key name for display. Handles special keys nicely.
# Falls back to the OS keycode name for unmapped keys.
const KEY_DISPLAY_NAMES: Dictionary = {
	KEY_SPACE: "Space",
	KEY_TAB: "Tab",
	KEY_ESCAPE: "Esc",
	KEY_ENTER: "Enter",
	KEY_KP_ENTER: "Enter",
	KEY_BACKSPACE: "Backspace",
	KEY_DELETE: "Delete",
	KEY_INSERT: "Insert",
	KEY_HOME: "Home",
	KEY_END: "End",
	KEY_PAGEUP: "Page Up",
	KEY_PAGEDOWN: "Page Down",
	KEY_UP: "↑",
	KEY_DOWN: "↓",
	KEY_LEFT: "←",
	KEY_RIGHT: "→",
	KEY_F1: "F1", KEY_F2: "F2", KEY_F3: "F3", KEY_F4: "F4",
	KEY_F5: "F5", KEY_F6: "F6", KEY_F7: "F7", KEY_F8: "F8",
	KEY_F9: "F9", KEY_F10: "F10", KEY_F11: "F11", KEY_F12: "F12",
	KEY_SHIFT: "Shift",
	KEY_CTRL: "Ctrl",
	KEY_ALT: "Alt",
	KEY_CAPSLOCK: "Caps Lock",
	KEY_NUMLOCK: "Num Lock",
	KEY_SCROLLLOCK: "Scroll Lock",
	KEY_PRINT: "PrtSc",
	KEY_PAUSE: "Pause",
}

# Default event snapshots { action_name: InputEvent } captured at _ready
# before any overrides are applied. Used by reset_to_defaults().
var _defaults: Dictionary = {}
# Current overrides { action_name: serialized event dict }
var _overrides: Dictionary = {}

signal bindings_changed()
signal binding_rebound(action: String, display_name: String)
signal bindings_reset()


func _ready() -> void:
	# Snapshot the default primary event for each rebindable action.
	# We do this BEFORE loading overrides so the snapshot reflects the
	# project.godot defaults, not the user's custom bindings.
	for action in REBINDABLE_ACTIONS:
		var events: Array = InputMap.action_get_events(action)
		if events.size() > 0:
			_defaults[action] = events[0].duplicate()
	# Load saved overrides and apply them
	_load_overrides()


# ── Public API ──────────────────────────────────────────────────────────────

## Rebind an action to a new primary input event. Persists immediately.
## Returns true on success, false if the action is not rebindable or the
## event is invalid.
func rebind_action(action_name: String, new_event: InputEvent) -> bool:
	if not REBINDABLE_ACTIONS.has(action_name):
		return false
	if not (new_event is InputEventKey or new_event is InputEventMouseButton):
		return false
	# Don't allow binding the same key to two different actions — find any
	# action that currently uses this event and clear it (so the player can
	# "steal" a key from another action without getting stuck).
	_clear_conflicts(new_event)
	# Remove all existing events for this action and set the new one as primary
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, new_event)
	# Record the override
	_overrides[action_name] = _serialize_event(new_event)
	_save_overrides()
	var display: String = get_event_display_name(new_event)
	binding_rebound.emit(action_name, display)
	bindings_changed.emit()
	return true


## Reset a single action to its default binding.
func reset_action(action_name: String) -> void:
	if not _defaults.has(action_name):
		return
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, _defaults[action_name].duplicate())
	_overrides.erase(action_name)
	_save_overrides()
	bindings_changed.emit()


## Reset all actions to their project.godot defaults. Clears the save file.
func reset_to_defaults() -> void:
	for action in REBINDABLE_ACTIONS:
		if _defaults.has(action):
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, _defaults[action].duplicate())
	_overrides.clear()
	_save_overrides()
	bindings_reset.emit()
	bindings_changed.emit()


## Get a human-readable name for the current primary binding of an action.
func get_action_binding_display(action_name: String) -> String:
	var events: Array = InputMap.action_get_events(action_name)
	if events.is_empty():
		return "—"
	return get_event_display_name(events[0])


## Get a human-readable name for an InputEvent (key or mouse button).
func get_event_display_name(event: InputEvent) -> String:
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		var kc: int = ke.keycode
		if KEY_DISPLAY_NAMES.has(kc):
			return String(KEY_DISPLAY_NAMES[kc])
		# Fall back to keycode name (Godot provides OS-dependent names)
		var name: String = OS.get_keycode_string(kc)
		if name.is_empty():
			name = "Key(%d)" % kc
		# Add modifier prefixes for clarity
		var prefix: String = ""
		if ke.shift_pressed:
			prefix += "Shift+"
		if ke.ctrl_pressed:
			prefix += "Ctrl+"
		if ke.alt_pressed:
			prefix += "Alt+"
		return prefix + name
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				return "LClick"
			MOUSE_BUTTON_RIGHT:
				return "RClick"
			MOUSE_BUTTON_MIDDLE:
				return "MClick"
			MOUSE_BUTTON_WHEEL_UP:
				return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Wheel Down"
			MOUSE_BUTTON_XBUTTON1:
				return "Mouse 4"
			MOUSE_BUTTON_XBUTTON2:
				return "Mouse 5"
			_:
				return "Mouse %d" % mb.button_index
	return "—"


## Is this action currently rebindable? (P2 co-op actions are not.)
func is_rebindable(action_name: String) -> bool:
	return REBINDABLE_ACTIONS.has(action_name)


## Get the display name for an action (e.g. "Move Up" for "move_up").
func get_action_display_name(action: String) -> String:
	return String(ACTION_DISPLAY_NAMES.get(action, action))


# ── Internal ─────────────────────────────────────────────────────────────────

## If any rebindable action currently uses this event as its primary binding,
## clear that action's binding so the new rebind doesn't conflict.
func _clear_conflicts(new_event: InputEvent) -> void:
	for action in REBINDABLE_ACTIONS:
		var events: Array = InputMap.action_get_events(action)
		for ev in events:
			if _events_match(ev, new_event):
				InputMap.action_erase_event(action, ev)
				if _overrides.has(action):
					_overrides.erase(action)
				break


## Check if two input events are equivalent (same key or same mouse button).
func _events_match(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return (a as InputEventKey).keycode == (b as InputEventKey).keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


## Serialize an InputEvent to a dictionary for JSON storage.
func _serialize_event(event: InputEvent) -> Dictionary:
	var d := {}
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		d["type"] = "key"
		d["keycode"] = ke.keycode
		d["physical"] = ke.physical_keycode
		d["unicode"] = ke.unicode
		d["shift"] = ke.shift_pressed
		d["ctrl"] = ke.ctrl_pressed
		d["alt"] = ke.alt_pressed
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		d["type"] = "mouse"
		d["button"] = mb.button_index
	return d


## Deserialize a dictionary back into an InputEvent and apply it.
func _deserialize_event(d: Dictionary) -> InputEvent:
	if d.get("type", "") == "key":
		var ev := InputEventKey.new()
		ev.keycode = int(d.get("keycode", 0))
		ev.physical_keycode = int(d.get("physical", 0))
		ev.unicode = int(d.get("unicode", 0))
		ev.shift_pressed = bool(d.get("shift", false))
		ev.ctrl_pressed = bool(d.get("ctrl", false))
		ev.alt_pressed = bool(d.get("alt", false))
		return ev
	elif d.get("type", "") == "mouse":
		var ev := InputEventMouseButton.new()
		ev.button_index = int(d.get("button", 0))
		return ev
	return null


## Load saved overrides from disk and apply them to the InputMap.
func _load_overrides() -> void:
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
	for action in data:
		if not REBINDABLE_ACTIONS.has(action):
			continue
		var event: InputEvent = _deserialize_event(data[action])
		if event == null:
			continue
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)
		_overrides[action] = data[action]
	bindings_changed.emit()


## Save current overrides to disk.
func _save_overrides() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		push_warning("[ControlRebind] Could not open rebind save file for writing")
		return
	f.store_string(JSON.stringify(_overrides, "  "))
	f.close()