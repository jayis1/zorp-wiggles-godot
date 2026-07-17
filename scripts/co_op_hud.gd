## Zorp Wiggles — Co-op HUD (Phase 19)
## Shows Player 2 HP bar, score, downed/revive UI, and co-op milestones.
## Attached as a Control by the main HUD.

extends Control

# ─── P2 HP Bar ───────────────────────────────────────────────────────────────
var _p2_hp_container: Panel = null
var _p2_hp_bar: ColorRect = null
var _p2_hp_text: Label = null
var _p2_name_label: Label = null

# ─── P2 Score ────────────────────────────────────────────────────────────────
var _p2_score_label: Label = null

# ─── Downed / Revive UI ──────────────────────────────────────────────────────
var _downed_overlay: Panel = null
var _downed_label: Label = null
var _revive_progress_bar: ColorRect = null
var _downed_timer_label: Label = null

# ── P1 downed overlay ──
var _p1_downed_overlay: Panel = null
var _p1_downed_label: Label = null
var _p1_revive_progress_bar: ColorRect = null
var _p1_downed_timer_label: Label = null

# ─── Drop-in prompt (shown when P2 not active) ───────────────────────────────
var _drop_in_label: Label = null

# ─── Co-op milestone popup ───────────────────────────────────────────────────
var _milestone_label: Label = null
var _milestone_timer: float = 0.0

# ─── Smooth bar ──────────────────────────────────────────────────────────────
var _hp_bar_target_ratio: float = 1.0
var _bar_smoothing: float = 10.0
var _hp_bar_target_color: Color = Color(0.85, 0.3, 0.9)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# P2 HP bar (top-left area, below P1's HP bar)
	_p2_hp_container = Panel.new()
	_p2_hp_container.offset_left = 20.0
	_p2_hp_container.offset_top = 175.0
	_p2_hp_container.offset_right = 320.0
	_p2_hp_container.offset_bottom = 205.0
	_p2_hp_container.visible = false
	add_child(_p2_hp_container)

	_p2_name_label = Label.new()
	_p2_name_label.offset_left = 5.0
	_p2_name_label.offset_top = -16.0
	_p2_name_label.offset_right = 200.0
	_p2_name_label.offset_bottom = 2.0
	_p2_name_label.text = "%s (P2)" % GameConstants.P2_NAME
	_p2_name_label.add_theme_color_override("font_color", GameConstants.P2_BASE_COLOR)
	_p2_name_label.add_theme_font_size_override("font_size", 13)
	_p2_hp_container.add_child(_p2_name_label)

	var hp_bg := ColorRect.new()
	hp_bg.offset_left = 2.0
	hp_bg.offset_top = 2.0
	hp_bg.offset_right = 298.0
	hp_bg.offset_bottom = 28.0
	hp_bg.color = Color(0.3, 0.1, 0.3)
	_p2_hp_container.add_child(hp_bg)

	_p2_hp_bar = ColorRect.new()
	_p2_hp_bar.offset_left = 2.0
	_p2_hp_bar.offset_top = 2.0
	_p2_hp_bar.offset_right = 298.0
	_p2_hp_bar.offset_bottom = 28.0
	_p2_hp_bar.color = GameConstants.P2_BASE_COLOR
	_p2_hp_container.add_child(_p2_hp_bar)

	_p2_hp_text = Label.new()
	_p2_hp_text.offset_left = 5.0
	_p2_hp_text.offset_top = 3.0
	_p2_hp_text.offset_right = 295.0
	_p2_hp_text.offset_bottom = 27.0
	_p2_hp_text.text = "%d / %d" % [GameConstants.P2_HP, GameConstants.P2_HP]
	_p2_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_p2_hp_container.add_child(_p2_hp_text)

	# P2 score label (below P2 HP bar)
	_p2_score_label = Label.new()
	_p2_score_label.offset_left = 20.0
	_p2_score_label.offset_top = 210.0
	_p2_score_label.offset_right = 300.0
	_p2_score_label.offset_bottom = 230.0
	_p2_score_label.text = "%s Score: 0" % GameConstants.P2_NAME
	_p2_score_label.add_theme_color_override("font_color", Color(0.85, 0.5, 0.9))
	_p2_score_label.visible = false
	add_child(_p2_score_label)

	# Drop-in prompt (shown when P2 not active)
	_drop_in_label = Label.new()
	_drop_in_label.offset_left = 500.0
	_drop_in_label.offset_top = 680.0
	_drop_in_label.offset_right = 780.0
	_drop_in_label.offset_bottom = 710.0
	_drop_in_label.text = "🎮 Press [Enter] for Player 2 (Zerp)"
	_drop_in_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.8, 0.7))
	_drop_in_label.add_theme_font_size_override("font_size", 14)
	_drop_in_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_drop_in_label)

	# Downed overlay (center screen, visible when P2 is downed)
	_downed_overlay = Panel.new()
	_downed_overlay.offset_left = 440.0
	_downed_overlay.offset_top = 300.0
	_downed_overlay.offset_right = 840.0
	_downed_overlay.offset_bottom = 420.0
	_downed_overlay.visible = false
	add_child(_downed_overlay)

	_downed_label = Label.new()
	_downed_label.offset_left = 10.0
	_downed_label.offset_top = 10.0
	_downed_label.offset_right = 390.0
	_downed_label.offset_bottom = 40.0
	_downed_label.text = "💔 %s is DOWN!" % GameConstants.P2_NAME
	_downed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_downed_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_downed_label.add_theme_font_size_override("font_size", 20)
	_downed_overlay.add_child(_downed_label)

	_revive_progress_bar = ColorRect.new()
	_revive_progress_bar.offset_left = 20.0
	_revive_progress_bar.offset_top = 50.0
	_revive_progress_bar.offset_right = 380.0
	_revive_progress_bar.offset_bottom = 65.0
	_revive_progress_bar.color = Color(0.3, 0.8, 1.0)
	_revive_progress_bar.size.x = 0  # Will be set by progress
	_downed_overlay.add_child(_revive_progress_bar)

	var revive_hint := Label.new()
	revive_hint.offset_left = 10.0
	revive_hint.offset_top = 70.0
	revive_hint.offset_right = 390.0
	revive_hint.offset_bottom = 90.0
	revive_hint.text = "P1: Hold [E] near %s to revive" % GameConstants.P2_NAME
	revive_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	revive_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_downed_overlay.add_child(revive_hint)

	_downed_timer_label = Label.new()
	_downed_timer_label.offset_left = 10.0
	_downed_timer_label.offset_top = 95.0
	_downed_timer_label.offset_right = 390.0
	_downed_timer_label.offset_bottom = 115.0
	_downed_timer_label.text = "Bleed out in: 30s"
	_downed_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_downed_timer_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	_downed_overlay.add_child(_downed_timer_label)

	# ── P1 downed overlay (shown when Zorp is downed in co-op) ──
	_p1_downed_overlay = Panel.new()
	_p1_downed_overlay.offset_left = 440.0
	_p1_downed_overlay.offset_top = 300.0
	_p1_downed_overlay.offset_right = 840.0
	_p1_downed_overlay.offset_bottom = 420.0
	_p1_downed_overlay.visible = false
	add_child(_p1_downed_overlay)

	_p1_downed_label = Label.new()
	_p1_downed_label.offset_left = 10.0
	_p1_downed_label.offset_top = 10.0
	_p1_downed_label.offset_right = 390.0
	_p1_downed_label.offset_bottom = 40.0
	_p1_downed_label.text = "💔 Zorp is DOWN!"
	_p1_downed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_p1_downed_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_p1_downed_label.add_theme_font_size_override("font_size", 20)
	_p1_downed_overlay.add_child(_p1_downed_label)

	_p1_revive_progress_bar = ColorRect.new()
	_p1_revive_progress_bar.offset_left = 20.0
	_p1_revive_progress_bar.offset_top = 50.0
	_p1_revive_progress_bar.offset_right = 380.0
	_p1_revive_progress_bar.offset_bottom = 65.0
	_p1_revive_progress_bar.color = Color(0.3, 0.8, 1.0)
	_p1_revive_progress_bar.size.x = 0
	_p1_downed_overlay.add_child(_p1_revive_progress_bar)

	var p1_revive_hint := Label.new()
	p1_revive_hint.offset_left = 10.0
	p1_revive_hint.offset_top = 70.0
	p1_revive_hint.offset_right = 390.0
	p1_revive_hint.offset_bottom = 90.0
	p1_revive_hint.text = "%s: Hold [.] near Zorp to revive" % GameConstants.P2_NAME
	p1_revive_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p1_revive_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_p1_downed_overlay.add_child(p1_revive_hint)

	_p1_downed_timer_label = Label.new()
	_p1_downed_timer_label.offset_left = 10.0
	_p1_downed_timer_label.offset_top = 95.0
	_p1_downed_timer_label.offset_right = 390.0
	_p1_downed_timer_label.offset_bottom = 115.0
	_p1_downed_timer_label.text = "Bleed out in: 30s"
	_p1_downed_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_p1_downed_timer_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	_p1_downed_overlay.add_child(_p1_downed_timer_label)

	# Co-op milestone popup
	_milestone_label = Label.new()
	_milestone_label.offset_left = 340.0
	_milestone_label.offset_top = 280.0
	_milestone_label.offset_right = 940.0
	_milestone_label.offset_bottom = 330.0
	_milestone_label.text = ""
	_milestone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_milestone_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	_milestone_label.add_theme_font_size_override("font_size", 22)
	_milestone_label.visible = false
	add_child(_milestone_label)

	# Connect CoOpManager signals
	CoOpManager.p2_joined.connect(_on_p2_joined)
	CoOpManager.p2_left.connect(_on_p2_left)
	CoOpManager.p2_hp_changed.connect(_on_p2_hp_changed)
	CoOpManager.p2_score_changed.connect(_on_p2_score_changed)
	CoOpManager.p2_downed.connect(_on_p2_downed)
	CoOpManager.p2_revived.connect(_on_p2_revived)
	CoOpManager.p2_died.connect(_on_p2_died)
	CoOpManager.revive_progress_changed.connect(_on_revive_progress)
	CoOpManager.co_op_milestone.connect(_on_coop_milestone)
	# P1 downed signal
	GameManager.p1_downed.connect(_on_p1_downed)

func _process(delta: float) -> void:
	# Smooth HP bar
	if _p2_hp_bar and _p2_hp_container and _p2_hp_container.visible:
		var bg_width: float = 296.0
		var current_ratio: float = _p2_hp_bar.size.x / bg_width if bg_width > 0 else 0.0
		var weight: float = 1.0 - exp(-_bar_smoothing * delta)
		current_ratio = lerpf(current_ratio, _hp_bar_target_ratio, weight)
		_p2_hp_bar.size.x = bg_width * current_ratio
		_p2_hp_bar.color = _p2_hp_bar.color.lerp(_hp_bar_target_color, weight)

	# Update downed timer display
	if CoOpManager.p2_is_downed and _downed_timer_label:
		var time_left: int = int(ceilf(CoOpManager.p2_downed_timer))
		_downed_timer_label.text = "Bleed out in: %ds" % time_left
		# Flash red when time is low
		if time_left <= 10:
			_downed_timer_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		else:
			_downed_timer_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))

	# P1 downed timer display
	if GameManager.player_is_downed and _p1_downed_timer_label:
		var p1_time: int = int(ceilf(GameManager.p1_downed_timer))
		_p1_downed_timer_label.text = "Bleed out in: %ds" % p1_time
		if p1_time <= 10:
			_p1_downed_timer_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		else:
			_p1_downed_timer_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
		# Update P1 revive progress bar
		if _p1_revive_progress_bar:
			_p1_revive_progress_bar.size.x = 360.0 * clampf(GameManager.p1_revive_progress, 0.0, 1.0)

	# Milestone popup timer
	if _milestone_timer > 0:
		_milestone_timer -= delta
		if _milestone_timer <= 0:
			_milestone_label.visible = false

	# Show/hide drop-in prompt
	_drop_in_label.visible = not CoOpManager.p2_active and GameManager.player_is_alive and not GameManager.is_paused

	# Hide P1 downed overlay when no longer downed
	_process_p1_downed_hide()

# ─── Signal Handlers ─────────────────────────────────────────────────────────

func _on_p2_joined() -> void:
	_p2_hp_container.visible = true
	_p2_score_label.visible = true
	_hp_bar_target_ratio = 1.0
	if _p2_hp_bar:
		_p2_hp_bar.size.x = 296.0
		_p2_hp_bar.color = GameConstants.P2_BASE_COLOR
	_hp_bar_target_color = GameConstants.P2_BASE_COLOR

func _on_p2_left() -> void:
	_p2_hp_container.visible = false
	_p2_score_label.visible = false
	_downed_overlay.visible = false

func _on_p2_hp_changed(hp: int, max_hp: int) -> void:
	var ratio: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
	_hp_bar_target_ratio = ratio
	if _p2_hp_text:
		_p2_hp_text.text = "%d / %d" % [hp, max_hp]
	# Color: magenta → orange → red as HP drops
	if ratio > 0.5:
		_hp_bar_target_color = GameConstants.P2_BASE_COLOR.lerp(Color(1.0, 0.6, 0.2), (1.0 - ratio) * 2.0)
	else:
		_hp_bar_target_color = Color(1.0, 0.6, 0.2).lerp(Color(1.0, 0.2, 0.2), (0.5 - ratio) * 2.0)

func _on_p2_score_changed(score: int) -> void:
	if _p2_score_label:
		_p2_score_label.text = "%s Score: %d" % [GameConstants.P2_NAME, score]

func _on_p2_downed() -> void:
	_downed_overlay.visible = true

func _on_p2_revived() -> void:
	_downed_overlay.visible = false
	if _revive_progress_bar:
		_revive_progress_bar.size.x = 0.0

func _on_p2_died() -> void:
	_downed_overlay.visible = false

func _on_revive_progress(progress: float) -> void:
	if _revive_progress_bar:
		_revive_progress_bar.size.x = 360.0 * clampf(progress, 0.0, 1.0)

func _on_coop_milestone(id: int, desc: String) -> void:
	_milestone_label.text = "🏆 %s" % desc
	_milestone_label.visible = true
	_milestone_timer = 3.0

# ── P1 downed handlers ──

func _on_p1_downed() -> void:
	if _p1_downed_overlay:
		_p1_downed_overlay.visible = true

# Hide P1 downed overlay when P1 is revived or dies
func _process_p1_downed_hide() -> void:
	if _p1_downed_overlay and not GameManager.player_is_downed:
		_p1_downed_overlay.visible = false
		if _p1_revive_progress_bar:
			_p1_revive_progress_bar.size.x = 0.0