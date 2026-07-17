## Zorp Wiggles — HUD (Heads-Up Display)
## All UI elements: HP bar, XP bar, level text, combo counter, minimap, etc.
## Ported from the Game._update_hud() logic in Ursina game.py.

extends CanvasLayer

# ─── HP Bar ──────────────────────────────────────────────────────────────────
@onready var hp_bar: ColorRect = $HPBarContainer/HPBar
@onready var hp_bar_bg: ColorRect = $HPBarContainer/HPBarBG
@onready var hp_text: Label = $HPBarContainer/HPText

# ─── XP Bar ──────────────────────────────────────────────────────────────────
@onready var xp_bar: ColorRect = $XPBarContainer/XPBar
@onready var xp_bar_container: Panel = $XPBarContainer
@onready var xp_text: Label = $XPBarContainer/XPText

# ─── Level & Score ───────────────────────────────────────────────────────────
@onready var level_text: Label = $LevelText
@onready var score_text: Label = $ScoreText
@onready var kills_text: Label = $KillsText

# ─── Combo ───────────────────────────────────────────────────────────────────
@onready var combo_text: Label = $ComboText
@onready var combo_timer_bar: ColorRect = $ComboTimerBar

# ─── Messages ────────────────────────────────────────────────────────────────
@onready var message_text: Label = $MessageText
@onready var level_up_text: Label = $LevelUpText

# ─── Boss HP ──────────────────────────────────────────────────────────────────
@onready var boss_hp_container: Panel = $BossHPContainer
@onready var boss_hp_bar: ColorRect = $BossHPContainer/BossHPBar
@onready var boss_name_text: Label = $BossHPContainer/BossNameText

# ─── Combo Milestone Flash ────────────────────────────────────────────────────
var _combo_flash_rect: ColorRect = null
var _combo_flash_timer: float = 0.0

# ─── Pickup Streak Display ────────────────────────────────────────────────────
var _pickup_streak_label: Label = null
var _pickup_streak_timer: float = 0.0

# ─── Spawn Direction Indicator ────────────────────────────────────────────────
var _spawn_direction_indicator: Control = null

# ─── Minimap ──────────────────────────────────────────────────────────────────
# Minimap viewport nodes — not yet implemented; refs resolved lazily if added.
var minimap: SubViewport = null
var minimap_display: TextureRect = null

# ─── Internal State ───────────────────────────────────────────────────────────
var message_timer: float = 0.0
var level_up_display_timer: float = 0.0
var boss_ref: Node3D = null

# ─── Smooth Bar Animation ─────────────────────────────────────────────────────
var _hp_bar_target_ratio: float = 1.0
var _xp_bar_target_ratio: float = 0.0
var _boss_bar_target_ratio: float = 0.0
var _bar_smoothing: float = 10.0  # Higher = snappier bar transitions

# ── Smooth bar color animation ──
# The bar *size* lerps smoothly, but the color was snapping instantly on
# hp_changed. Now we track a target color and lerp toward it in _process so
# the color transition matches the smooth bar drain/fill. This makes HP loss
# feel less jarring — the color eases from green → yellow → red alongside
# the shrinking bar instead of popping at the 50% threshold.
var _hp_bar_target_color: Color = Color(0.0, 1.0, 0.0)
var _boss_bar_target_color: Color = Color(0.0, 1.0, 0.0)
var _color_smoothing: float = 8.0  # Color lerp speed (slightly slower than bar for soft transition)

# ── Phase 16: Weapon Mod indicator ──
var _mod_indicator: Label = null

func _ready() -> void:
	# Connect game manager signals
	GameManager.hp_changed.connect(_on_hp_changed)
	GameManager.xp_changed.connect(_on_xp_changed)
	GameManager.level_up.connect(_on_level_up)
	GameManager.combo_changed.connect(_on_combo_changed)
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.player_died.connect(_on_player_died)
	GameManager.game_restarted.connect(_on_game_restarted)
	GameManager.boss_spawned.connect(_on_boss_spawned)
	GameManager.boss_defeated.connect(_on_boss_defeated)
	GameManager.message_added.connect(_on_message_added)
	GameManager.combo_milestone.connect(_on_combo_milestone)
	GameManager.pickup_streak_milestone.connect(_on_pickup_streak_milestone)
	
	# Create combo milestone flash overlay (full-screen ColorRect)
	_combo_flash_rect = ColorRect.new()
	_combo_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_combo_flash_rect.color = Color(0, 0, 0, 0)
	_combo_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_combo_flash_rect)
	
	# Create pickup streak label (bottom-right area)
	_pickup_streak_label = Label.new()
	_pickup_streak_label.offset_left = 900.0
	_pickup_streak_label.offset_top = 140.0
	_pickup_streak_label.offset_right = 1150.0
	_pickup_streak_label.offset_bottom = 170.0
	_pickup_streak_label.text = ""
	_pickup_streak_label.visible = false
	_pickup_streak_label.add_theme_color_override("font_color", GameConstants.PICKUP_STREAK_COLOR)
	_pickup_streak_label.add_theme_font_size_override("font_size", 18)
	add_child(_pickup_streak_label)
	
	# Create spawn direction indicator
	var sdi_script := load("res://scripts/spawn_direction_indicator.gd")
	_spawn_direction_indicator = Control.new()
	_spawn_direction_indicator.set_script(sdi_script)
	_spawn_direction_indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spawn_direction_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_spawn_direction_indicator)
	
	# ── Phase 5: Minimap ──
	var minimap_script := load("res://scripts/minimap.gd")
	var minimap_ctrl := Control.new()
	minimap_ctrl.set_script(minimap_script)
	add_child(minimap_ctrl)
	
	# ── Phase 5: Damage Direction Indicator ──
	var ddi_script := load("res://scripts/damage_direction_indicator.gd")
	var ddi_ctrl := Control.new()
	ddi_ctrl.set_script(ddi_script)
	add_child(ddi_ctrl)
	
	# ── Phase 5: Boss Tension Vignette ──
	var btv_script := load("res://scripts/boss_tension_vignette.gd")
	var btv_ctrl := Control.new()
	btv_ctrl.set_script(btv_script)
	add_child(btv_ctrl)
	
	# ── Phase 5: Death Screen ──
	var ds_script := load("res://scripts/death_screen.gd")
	var ds_ctrl := Control.new()
	ds_ctrl.set_script(ds_script)
	add_child(ds_ctrl)
	
	# ── Phase 5: Biome Indicator ──
	var bi_script := load("res://scripts/biome_indicator.gd")
	var bi_ctrl := Control.new()
	bi_ctrl.set_script(bi_script)
	add_child(bi_ctrl)
	
	# ── Phase 5: Dash Cooldown Indicator ──
	var dci_script := load("res://scripts/dash_cooldown_indicator.gd")
	var dci_ctrl := Control.new()
	dci_ctrl.set_script(dci_script)
	add_child(dci_ctrl)
	
	# ── Phase 5: Kill Feed ──
	var kf_script := load("res://scripts/kill_feed.gd")
	var kf_ctrl := Control.new()
	kf_ctrl.set_script(kf_script)
	add_child(kf_ctrl)
	
	# ── Phase 5: Achievement Popups ──
	var ap_script := load("res://scripts/achievement_popup.gd")
	var ap_ctrl := Control.new()
	ap_ctrl.set_script(ap_script)
	add_child(ap_ctrl)
	
	# ── Phase 5: Power-up Timer Display ──
	var pud_script := load("res://scripts/powerup_timer_display.gd")
	var pud_ctrl := Control.new()
	pud_ctrl.set_script(pud_script)
	add_child(pud_ctrl)

	# ── Phase 6: Player Damage Flash ──
	var df_script := load("res://scripts/damage_flash.gd")
	var df_ctrl := Control.new()
	df_ctrl.set_script(df_script)
	add_child(df_ctrl)

	# ── Phase 14: Dimension Indicator ──
	var di_script := load("res://scripts/dimension_indicator.gd")
	var di_ctrl := Control.new()
	di_ctrl.set_script(di_script)
	add_child(di_ctrl)

	# ── Phase 15: Companion Pet HUD ──
	var ph_script := load("res://scripts/companion_hud.gd")
	var ph_ctrl := Control.new()
	ph_ctrl.set_script(ph_script)
	add_child(ph_ctrl)
	
	# ── Phase 16: Weapon Mod Crafting Menu ──
	var cm_script := load("res://scripts/crafting_menu.gd")
	var cm_ctrl := Control.new()
	cm_ctrl.set_script(cm_script)
	cm_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	cm_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP  # Needs to capture clicks when visible
	add_child(cm_ctrl)
	
	# ── Phase 16: Weapon Mod Indicator (bottom-center, shows current mod) ──
	_mod_indicator = Label.new()
	_mod_indicator.offset_left = 440.0
	_mod_indicator.offset_top = 690.0
	_mod_indicator.offset_right = 840.0
	_mod_indicator.offset_bottom = 715.0
	_mod_indicator.text = "🔫 Standard Laser  |  📦 Materials: 0  |  [C] Craft"
	_mod_indicator.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	_mod_indicator.add_theme_font_size_override("font_size", 13)
	_mod_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_mod_indicator)
	
	# Connect weapon mod signals for indicator updates
	WeaponModSystem.mod_equipped.connect(_on_mod_equipped_hud)
	WeaponModSystem.mod_unequipped.connect(_on_mod_unequipped_hud)
	WeaponModSystem.inventory_changed.connect(_on_inventory_changed_hud)

	# ── Phase 17: Weather Indicator ──
	var wi_script := load("res://scripts/weather_indicator.gd")
	var wi_ctrl := Control.new()
	wi_ctrl.set_script(wi_script)
	wi_ctrl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	wi_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wi_ctrl)

	# ── Phase 19: Co-op HUD ──
	var coop_script := load("res://scripts/co_op_hud.gd")
	var coop_ctrl := Control.new()
	coop_ctrl.set_script(coop_script)
	coop_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	coop_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coop_ctrl)

	# Initialize displays
	_update_all_displays()

func _process(delta: float) -> void:
	# Timers
	if message_timer > 0:
		message_timer -= delta
		if message_timer <= 0:
			message_text.visible = false

	if level_up_display_timer > 0:
		level_up_display_timer -= delta
		if level_up_display_timer <= 0:
			# Smooth fade-out + scale down instead of a hard disappear
			if level_up_text:
				if level_up_text.has_meta("_lv_tween") and is_instance_valid(level_up_text.get_meta("_lv_tween") as Tween):
					(level_up_text.get_meta("_lv_tween") as Tween).kill()
				var fade_tween := create_tween()
				fade_tween.tween_property(level_up_text, "modulate:a", 0.0, 0.3) \
					.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				fade_tween.parallel().tween_property(level_up_text, "scale", Vector3.ONE * 0.8, 0.3) \
					.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
				fade_tween.tween_callback(func():
					level_up_text.visible = false
					level_up_text.modulate.a = 1.0
					level_up_text.scale = Vector3.ONE
				)
	
	# Combo milestone flash decay
	if _combo_flash_timer > 0:
		_combo_flash_timer -= delta
		var flash_progress: float = _combo_flash_timer / GameConstants.COMBO_MILESTONE_FLASH_DURATION
		flash_progress = clampf(flash_progress, 0.0, 1.0)
		if _combo_flash_rect:
			# Fade out the flash
			var alpha: float = flash_progress * (40.0 / 255.0)  # Max alpha = 40/255 (subtle)
			var c: Color = _combo_flash_rect.color
			c.a = alpha
			_combo_flash_rect.color = c
			if _combo_flash_timer <= 0:
				_combo_flash_rect.color = Color(0, 0, 0, 0)
	
	# Pickup streak display timer
	if _pickup_streak_timer > 0:
		_pickup_streak_timer -= delta
		if _pickup_streak_timer <= 0 and _pickup_streak_label:
			_pickup_streak_label.visible = false

	# Smoothly animate bars toward target ratios (frame-rate independent lerp)
	var weight: float = 1.0 - exp(-_bar_smoothing * delta)

	# HP bar
	var hp_current_ratio: float = hp_bar.size.x / hp_bar_bg.size.x if hp_bar_bg.size.x > 0 else 0.0
	hp_current_ratio = lerpf(hp_current_ratio, _hp_bar_target_ratio, weight)
	hp_bar.size.x = hp_bar_bg.size.x * hp_current_ratio
	# Smooth HP bar color toward target (eases green → yellow → red)
	hp_bar.color = hp_bar.color.lerp(_hp_bar_target_color, 1.0 - exp(-_color_smoothing * delta))

	# XP bar
	var xp_bar_width: float = xp_bar_container.size.x - 4.0 if xp_bar_container.size.x > 0 else 396.0
	var xp_current_ratio: float = xp_bar.size.x / xp_bar_width if xp_bar_width > 0 else 0.0
	xp_current_ratio = lerpf(xp_current_ratio, _xp_bar_target_ratio, weight)
	xp_bar.size.x = xp_bar_width * xp_current_ratio

	# Combo timer bar
	if GameManager.player_combo > 0:
		combo_timer_bar.visible = true
		var ratio := GameManager.player_combo_timer / 3.0
		combo_timer_bar.size.x = 200.0 * ratio
		# Color: green → yellow → red
		if ratio > 0.5:
			combo_timer_bar.color = Color(1.0, 1.0, 0.0)
		else:
			combo_timer_bar.color = Color(1.0, ratio * 2.0, 0.0)
	else:
		combo_timer_bar.visible = false

	# Boss HP bar (smooth)
	if boss_ref and is_instance_valid(boss_ref) and boss_ref.hp > 0:
		boss_hp_container.visible = true
		_boss_bar_target_ratio = float(boss_ref.hp) / float(boss_ref.max_hp) if boss_ref.max_hp > 0 else 0.0
		var boss_bar_width: float = boss_hp_container.size.x - 4.0 if boss_hp_container.size.x > 0 else 496.0
		var boss_current_ratio: float = boss_hp_bar.size.x / boss_bar_width if boss_bar_width > 0 else 0.0
		boss_current_ratio = lerpf(boss_current_ratio, _boss_bar_target_ratio, weight)
		boss_hp_bar.size.x = boss_bar_width * boss_current_ratio
		var display_name: String = "Boss"
		if "enemy_name" in boss_ref:
			display_name = boss_ref.enemy_name
		boss_name_text.text = "☠ %s" % display_name
		# Smooth boss bar color toward target (eases green → yellow → red)
		_boss_bar_target_color = _ratio_to_bar_color(_boss_bar_target_ratio)
		boss_hp_bar.color = boss_hp_bar.color.lerp(_boss_bar_target_color, 1.0 - exp(-_color_smoothing * delta))
	else:
		boss_hp_container.visible = false
		boss_ref = null

func _on_hp_changed(new_hp: int, max_hp: int) -> void:
	var ratio := float(new_hp) / float(max_hp) if max_hp > 0 else 0.0
	_hp_bar_target_ratio = ratio
	hp_text.text = "%d / %d" % [new_hp, max_hp]

	# Target color: green → yellow → red. The color lerps toward this target
	# in _process so it transitions smoothly alongside the bar size.
	_hp_bar_target_color = _ratio_to_bar_color(ratio)

func _on_xp_changed(new_xp: int, xp_to_next: int) -> void:
	var ratio := float(new_xp) / float(xp_to_next) if xp_to_next > 0 else 0.0
	_xp_bar_target_ratio = ratio
	xp_text.text = "XP: %d / %d" % [new_xp, xp_to_next]

func _on_level_up(level: int) -> void:
	level_text.text = "Lv %d" % level
	level_up_text.text = "LEVEL UP! → Lv %d" % level
	level_up_text.visible = true
	level_up_display_timer = 3.0
	# Animated scale-in with bounce overshoot — the text pops in from zero
	# scale, overshoots slightly, then settles. This makes level-ups feel
	# celebratory instead of a flat text swap. The tween is killed if a
	# new level-up happens before it completes (via kill + recreate).
	if level_up_text:
		# Kill any existing tween on the label to avoid stacking
		if level_up_text.has_meta("_lv_tween") and is_instance_valid(level_up_text.get_meta("_lv_tween") as Tween):
			(level_up_text.get_meta("_lv_tween") as Tween).kill()
		level_up_text.scale = Vector3.ZERO
		level_up_text.modulate.a = 1.0
		var lv_tween := create_tween()
		lv_tween.tween_property(level_up_text, "scale", Vector3.ONE * 1.25, 0.25) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		lv_tween.tween_property(level_up_text, "scale", Vector3.ONE, 0.15) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		level_up_text.set_meta("_lv_tween", lv_tween)
	show_message("Level Up! Full HP restored!", 3.0)

func _on_combo_changed(count: int) -> void:
	if count > 1:
		combo_text.text = "COMBO x%d" % count
		combo_text.visible = true
		# Color tiers: gold → orange → red
		if count >= 15:
			combo_text.add_theme_color_override("font_color", GameConstants.C_COMBO_RED)
		elif count >= 10:
			combo_text.add_theme_color_override("font_color", GameConstants.C_COMBO_ORANGE)
		else:
			combo_text.add_theme_color_override("font_color", GameConstants.C_COMBO_GOLD)
		# Punch-in scale pop on each combo increment — quick squash to 1.3x
		# then elastic settle back to 1.0. Gives each combo tick a juicy
		# "thwack" feel. Only plays if the label is already visible (not
		# the first combo hit which already has scale=1).
		if combo_text:
			if combo_text.has_meta("_combo_tween") and is_instance_valid(combo_text.get_meta("_combo_tween") as Tween):
				(combo_text.get_meta("_combo_tween") as Tween).kill()
			var combo_tween := create_tween()
			combo_tween.tween_property(combo_text, "scale", Vector3.ONE * 1.3, 0.06) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			combo_tween.tween_property(combo_text, "scale", Vector3.ONE, 0.15) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
			combo_text.set_meta("_combo_tween", combo_tween)
	else:
		combo_text.visible = false

func _on_score_changed(new_score: int) -> void:
	score_text.text = "Score: %d" % new_score
	kills_text.text = "Kills: %d" % GameManager.player_kills

func _on_player_died() -> void:
	show_message("Zorp has fallen!", 5.0)
	# TODO: Show death screen with stats

func _on_game_restarted() -> void:
	_update_all_displays()
	combo_text.visible = false
	level_up_text.visible = false

func _update_all_displays() -> void:
	_on_hp_changed(GameManager.player_hp, GameManager.player_max_hp)
	_on_xp_changed(GameManager.player_xp, GameManager.player_xp_to_next)
	_on_score_changed(GameManager.player_score)
	level_text.text = "Lv %d" % GameManager.player_level

func show_message(text: String, duration: float = 2.0) -> void:
	message_text.text = text
	message_text.visible = true
	message_timer = duration

func set_boss_reference(enemy: Node3D) -> void:
	boss_ref = enemy

func _on_boss_spawned(boss: Node) -> void:
	boss_ref = boss
	GameManager.current_boss = boss
	boss_hp_container.visible = true
	if "enemy_name" in boss:
		boss_name_text.text = "☠ %s" % boss.enemy_name
		show_message("⚠ %s has appeared!" % boss.enemy_name, 3.0)

func _on_boss_defeated(boss: Node) -> void:
	boss_ref = null
	GameManager.current_boss = null
	boss_hp_container.visible = false
	var display_name: String = "Boss"
	if "enemy_name" in boss:
		display_name = boss.enemy_name
	show_message("%s defeated!" % display_name, 3.0)

func _on_message_added(text: String) -> void:
	show_message(text, 2.5)

# ─── Combo Milestone Flash ───────────────────────────────────────────────────
func _on_combo_milestone(combo: int, tier: int, flash_color: Color) -> void:
	_combo_flash_timer = GameConstants.COMBO_MILESTONE_FLASH_DURATION
	if _combo_flash_rect:
		# Set the flash color with initial alpha
		_combo_flash_rect.color = Color(flash_color.r, flash_color.g, flash_color.b, 40.0 / 255.0)

# ─── Pickup Streak Milestone ──────────────────────────────────────────────────
func _on_pickup_streak_milestone(streak: int, xp_bonus: int) -> void:
	if _pickup_streak_label:
		_pickup_streak_label.text = "✦ PICKUP STREAK x%d (+%d XP)" % [streak, xp_bonus]
		_pickup_streak_label.visible = true
		_pickup_streak_timer = GameConstants.PICKUP_STREAK_DISPLAY_LIFETIME

# ─── Bar Color Helper ─────────────────────────────────────────────────────────
# Maps an HP ratio (0..1) to a green → yellow → red color gradient.
# Used by both the player HP bar and the boss HP bar so they share the same
# color language. >0.5 interpolates green→yellow; <0.5 interpolates yellow→red.
func _ratio_to_bar_color(ratio: float) -> Color:
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio > 0.5:
		# Green (0,1,0) → Yellow (1,1,0) as ratio goes 1.0 → 0.5
		var t: float = (1.0 - ratio) * 2.0  # 0 at full, 1 at half
		return Color(t, 1.0, 0.0)
	else:
		# Yellow (1,1,0) → Red (1,0,0) as ratio goes 0.5 → 0.0
		var t: float = ratio * 2.0  # 1 at half, 0 at empty
		return Color(1.0, t, 0.0)

# ─── Phase 16: Weapon Mod HUD Handlers ────────────────────────────────────────

func _on_mod_equipped_hud(mod_id: int) -> void:
	_update_mod_indicator()

func _on_mod_unequipped_hud() -> void:
	_update_mod_indicator()

func _on_inventory_changed_hud() -> void:
	_update_mod_indicator()

func _update_mod_indicator() -> void:
	if not _mod_indicator:
		return
	var mod_name: String = "Standard Laser"
	var mod_color: Color = Color(0.7, 0.8, 1.0)
	if WeaponModSystem:
		mod_name = WeaponModSystem.get_equipped_name()
		mod_color = WeaponModSystem.get_equipped_color()
	# Count total materials
	var total_mats: int = 0
	if WeaponModSystem:
		var inv: Dictionary = WeaponModSystem.get_inventory()
		for count in inv.values():
			total_mats += count
	_mod_indicator.text = "🔫 %s  |  📦 Materials: %d  |  [C] Craft" % [mod_name, total_mats]
	_mod_indicator.add_theme_color_override("font_color", mod_color)