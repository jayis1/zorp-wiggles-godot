## Zorp Wiggles — Companion Pet HUD Indicator (Phase 15 + Phase 27)
## Displays pet status at the bottom-left of the screen:
##   - Pet name + current stage + evolution path (Phase 27)
##   - HP bar (small)
##   - Evolution progress bar (fills as pet is fed)
##   - Current state (Follow/Fetch/Attack)
##   - Active ability label (Phase 27)
##   - Evolution stone inventory summary (Phase 27)
##
## The pet is optional — the HUD only shows when a pet exists.

extends Control

var _container: Panel = null
var _name_label: Label = null
var _hp_bar_bg: ColorRect = null
var _hp_bar: ColorRect = null
var _hp_text: Label = null
var _evo_bar_bg: ColorRect = null
var _evo_bar: ColorRect = null
var _evo_text: Label = null
var _state_label: Label = null
# ── Phase 27: Path + ability + stone inventory labels ──
var _path_label: Label = null
var _ability_label: Label = null
var _stone_label: Label = null

var _pet: Node = null

const PANEL_W: float = 240.0
const PANEL_H: float = 168.0  # Taller to fit path/ability/stone lines
const PANEL_MARGIN: float = 20.0
const BAR_W: float = 210.0
const BAR_H: float = 8.0

func _ready() -> void:
	# Container panel — bottom-left
	_container = Panel.new()
	_container.offset_left = PANEL_MARGIN
	_container.offset_top = 720.0 - PANEL_H - PANEL_MARGIN - 140.0
	_container.offset_right = PANEL_MARGIN + PANEL_W
	_container.offset_bottom = 720.0 - PANEL_MARGIN - 140.0
	_container.visible = false
	# Semi-transparent dark background
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.1, 0.8)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.6, 0.9, 0.5)
	style.set_corner_radius_all(4)
	_container.add_theme_stylebox_override("panel", style)
	add_child(_container)

	# Pet name + stage label
	_name_label = Label.new()
	_name_label.offset_left = 8.0
	_name_label.offset_top = 4.0
	_name_label.offset_right = PANEL_W - 8.0
	_name_label.offset_bottom = 24.0
	_name_label.text = "🐾 Companion Pet"
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	_container.add_child(_name_label)

	# HP bar background
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.offset_left = 8.0
	_hp_bar_bg.offset_top = 28.0
	_hp_bar_bg.offset_right = 8.0 + BAR_W
	_hp_bar_bg.offset_bottom = 28.0 + BAR_H
	_hp_bar_bg.color = Color(0.3, 0.1, 0.1, 0.8)
	_container.add_child(_hp_bar_bg)

	# HP bar fill
	_hp_bar = ColorRect.new()
	_hp_bar.offset_left = 9.0
	_hp_bar.offset_top = 29.0
	_hp_bar.offset_right = 9.0 + BAR_W - 2.0
	_hp_bar.offset_bottom = 29.0 + BAR_H - 2.0
	_hp_bar.color = Color(0.2, 0.9, 0.3)
	_container.add_child(_hp_bar)

	# HP text
	_hp_text = Label.new()
	_hp_text.offset_left = 8.0
	_hp_text.offset_top = 36.0
	_hp_text.offset_right = PANEL_W - 8.0
	_hp_text.offset_bottom = 52.0
	_hp_text.text = "HP: 30/30"
	_hp_text.add_theme_font_size_override("font_size", 11)
	_hp_text.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_container.add_child(_hp_text)

	# Evolution bar background
	_evo_bar_bg = ColorRect.new()
	_evo_bar_bg.offset_left = 8.0
	_evo_bar_bg.offset_top = 56.0
	_evo_bar_bg.offset_right = 8.0 + BAR_W
	_evo_bar_bg.offset_bottom = 56.0 + BAR_H
	_evo_bar_bg.color = Color(0.15, 0.1, 0.25, 0.8)
	_container.add_child(_evo_bar_bg)

	# Evolution bar fill
	_evo_bar = ColorRect.new()
	_evo_bar.offset_left = 9.0
	_evo_bar.offset_top = 57.0
	_evo_bar.offset_right = 9.0 + BAR_W - 2.0
	_evo_bar.offset_bottom = 57.0 + BAR_H - 2.0
	_evo_bar.color = Color(0.5, 0.4, 0.9)
	_container.add_child(_evo_bar)

	# Evolution text
	_evo_text = Label.new()
	_evo_text.offset_left = 8.0
	_evo_text.offset_top = 64.0
	_evo_text.offset_right = PANEL_W - 8.0
	_evo_text.offset_bottom = 80.0
	_evo_text.text = "Evolution: 0%"
	_evo_text.add_theme_font_size_override("font_size", 11)
	_evo_text.add_theme_color_override("font_color", Color(0.7, 0.6, 0.9))
	_container.add_child(_evo_text)

	# State label
	_state_label = Label.new()
	_state_label.offset_left = 8.0
	_state_label.offset_top = 84.0
	_state_label.offset_right = PANEL_W - 8.0
	_state_label.offset_bottom = 104.0
	_state_label.text = "State: Follow"
	_state_label.add_theme_font_size_override("font_size", 12)
	_state_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	_container.add_child(_state_label)

	# ── Phase 27: Evolution path label ──
	_path_label = Label.new()
	_path_label.offset_left = 8.0
	_path_label.offset_top = 106.0
	_path_label.offset_right = PANEL_W - 8.0
	_path_label.offset_bottom = 124.0
	_path_label.text = "Path: Prismatic"
	_path_label.add_theme_font_size_override("font_size", 12)
	_path_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	_container.add_child(_path_label)

	# ── Phase 27: Active ability label ──
	_ability_label = Label.new()
	_ability_label.offset_left = 8.0
	_ability_label.offset_top = 124.0
	_ability_label.offset_right = PANEL_W - 8.0
	_ability_label.offset_bottom = 140.0
	_ability_label.text = "Ability: —"
	_ability_label.add_theme_font_size_override("font_size", 11)
	_ability_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_container.add_child(_ability_label)

	# ── Phase 27: Stone inventory summary ──
	_stone_label = Label.new()
	_stone_label.offset_left = 8.0
	_stone_label.offset_top = 142.0
	_stone_label.offset_right = PANEL_W - 8.0
	_stone_label.offset_bottom = 160.0
	_stone_label.text = "Stones: none (B to use)"
	_stone_label.add_theme_font_size_override("font_size", 11)
	_stone_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	_container.add_child(_stone_label)

	# Connect to PetStoneInventory signals for live stone count updates
	if PetStoneInventory:
		if not PetStoneInventory.stone_added.is_connected(_on_stone_changed):
			PetStoneInventory.stone_added.connect(_on_stone_changed)
		if not PetStoneInventory.stone_consumed.is_connected(_on_stone_changed):
			PetStoneInventory.stone_consumed.connect(_on_stone_changed)


func _process(_delta: float) -> void:
	# Find pet if we don't have a reference
	if not _pet or not is_instance_valid(_pet):
		_pet = get_tree().get_first_node_in_group("companion_pet")
		if _pet:
			_connect_pet_signals()
		_container.visible = _pet != null and is_instance_valid(_pet)
		if not _container.visible:
			return
	# Update displays
	if _pet and is_instance_valid(_pet):
		_update_display()
	# Always update stone inventory (it's independent of pet existence)
	_update_stone_display()


func _connect_pet_signals() -> void:
	if not _pet:
		return
	if not _pet.pet_stage_changed.is_connected(_on_stage_changed):
		_pet.pet_stage_changed.connect(_on_stage_changed)
	if not _pet.pet_evolution_progress.is_connected(_on_evolution_progress):
		_pet.pet_evolution_progress.connect(_on_evolution_progress)
	if not _pet.pet_hp_changed.is_connected(_on_hp_changed):
		_pet.pet_hp_changed.connect(_on_hp_changed)
	if not _pet.pet_state_changed.is_connected(_on_state_changed):
		_pet.pet_state_changed.connect(_on_state_changed)
	# ── Phase 27: Path changed signal ──
	if "pet_path_changed" in _pet and not _pet.pet_path_changed.is_connected(_on_path_changed):
		_pet.pet_path_changed.connect(_on_path_changed)


func _update_display() -> void:
	if not _pet or not is_instance_valid(_pet):
		return
	# Name + stage
	var stage_name: String = _pet.get_stage_name()
	_name_label.text = "🐾 Pet — %s" % stage_name
	# State
	var state_name: String = "Follow"
	if "current_state" in _pet:
		match _pet.current_state:
			0: state_name = "Follow"
			1: state_name = "Fetch"
			2: state_name = "Attack"
			3: state_name = "Idle"
	_state_label.text = "State: %s" % state_name
	# ── Phase 27: Path + ability ──
	if _pet.has_method("get_path_name"):
		var path_name: String = _pet.get_path_name()
		_path_label.text = "Path: %s" % path_name
		# Color the path label based on the path
		var path_id: int = _pet.get_path_id() if _pet.has_method("get_path_id") else 0
		_path_label.add_theme_color_override("font_color", _path_color(path_id))
	else:
		_path_label.text = "Path: Prismatic"
	if _pet.has_method("get_ability_name"):
		var ability: String = _pet.get_ability_name()
		_ability_label.text = "Ability: %s" % ability if ability != "" else "Ability: —"
	else:
		_ability_label.text = "Ability: —"


# ── Phase 27: Stone inventory display ──
func _update_stone_display() -> void:
	if not PetStoneInventory:
		_stone_label.text = "Stones: —"
		return
	var summary: String = PetStoneInventory.get_summary()
	if summary == "":
		_stone_label.text = "Stones: none (B to use)"
	else:
		_stone_label.text = "Stones: %s  [B]" % summary


func _on_stage_changed(new_stage: int) -> void:
	var stage_name: String = GameConstants.PET_STAGE_NAMES[new_stage]
	_name_label.text = "🐾 Pet — %s" % stage_name
	# Flash the panel border on evolution
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.1, 0.8)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.8, 0.3, 1.0)
	style.set_corner_radius_all(4)
	_container.add_theme_stylebox_override("panel", style)


func _on_evolution_progress(pct: float) -> void:
	var fill_w: float = (BAR_W - 2.0) * pct
	_evo_bar.offset_right = 9.0 + fill_w
	_evo_text.text = "Evolution: %d%%" % int(pct * 100.0)


func _on_hp_changed(new_hp: int, max_hp: int) -> void:
	var ratio: float = float(new_hp) / float(max_hp) if max_hp > 0 else 0.0
	ratio = clampf(ratio, 0.0, 1.0)
	var fill_w: float = (BAR_W - 2.0) * ratio
	_hp_bar.offset_right = 9.0 + fill_w
	_hp_text.text = "HP: %d/%d" % [new_hp, max_hp]
	# Color shift: green → yellow → red
	_hp_bar.color = _ratio_to_color(ratio)


func _on_state_changed(state_name: String) -> void:
	_state_label.text = "State: %s" % state_name
	# Color-code the state label
	var col: Color = Color(0.6, 0.8, 0.6)  # Follow = green
	match state_name:
		"fetch":
			col = Color(0.9, 0.8, 0.3)  # Fetch = yellow
		"attack":
			col = Color(1.0, 0.4, 0.3)  # Attack = red
		"idle":
			col = Color(0.5, 0.7, 0.9)  # Idle = blue
	_state_label.add_theme_color_override("font_color", col)


# ── Phase 27: Path changed callback ──
func _on_path_changed(new_path: int) -> void:
	var path_name: String = GameConstants.PET_PATH_NAMES[new_path]
	_path_label.text = "Path: %s" % path_name
	_path_label.add_theme_color_override("font_color", _path_color(new_path))
	# Flash the panel border in the path color
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.1, 0.8)
	style.set_border_width_all(2)
	style.border_color = _path_color(new_path)
	style.set_corner_radius_all(4)
	_container.add_theme_stylebox_override("panel", style)


# ── Phase 27: Stone inventory changed callback ──
func _on_stone_changed(_type: int, _count: int) -> void:
	_update_stone_display()


# Returns a HUD color for a given pet path ID.
func _path_color(path_id: int) -> Color:
	match path_id:
		GameConstants.PetPath.PRISMATIC:
			return Color(0.7, 0.8, 1.0)
		GameConstants.PetPath.FIRE:
			return Color(1.0, 0.45, 0.15)
		GameConstants.PetPath.ICE:
			return Color(0.4, 0.75, 1.0)
		GameConstants.PetPath.ELECTRIC:
			return Color(1.0, 0.9, 0.2)
		GameConstants.PetPath.VOID:
			return Color(0.5, 0.3, 0.7)
		GameConstants.PetPath.NATURE:
			return Color(0.3, 0.8, 0.35)
	return Color(0.8, 0.8, 0.9)


func _ratio_to_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.2, 0.9, 0.3).lerp(Color(1.0, 0.85, 0.0), (1.0 - ratio) * 2.0)
	else:
		return Color(1.0, 0.85, 0.0).lerp(Color(0.9, 0.2, 0.2), (0.5 - ratio) * 2.0)