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

# ── Boss bar damage flash ── When the boss takes damage, the HP bar flashes
#    white and shakes horizontally for a brief moment. This gives each hit on
#    the boss a visceral "impact" read on the UI, mirroring the enemy hit
#    flash on the 3D mesh. We detect damage by comparing the boss's current
#    HP ratio to the previous frame's value — a drop triggers the flash.
#    The flash decays over BOSS_BAR_FLASH_DURATION and the shake uses a
#    decaying sine wobble. State is tracked here so _process can drive it
#    without needing a per-hit signal connection.
var _boss_bar_prev_ratio: float = 1.0
var _boss_bar_flash_timer: float = 0.0
const BOSS_BAR_FLASH_DURATION: float = 0.18
const BOSS_BAR_SHAKE_AMP: float = 6.0  # Max horizontal shake in pixels
var _boss_bar_rest_left: float = 0.0   # Resting offset_left (for shake restore)

# ── Player HP bar damage flash ── Mirrors the boss bar juice: when the player
#    takes damage, the HP bar flashes white and shakes horizontally. This
#    gives the player's own damage events a visceral UI read that matches the
#    boss bar language, so damage feels consistent whether you're giving or
#    receiving it. The flash is driven by polling the HP ratio in _process
#    (same approach as the boss bar) so we don't need a per-hit signal — the
#    hp_changed signal only fires on the actual change, but the visual decay
#    needs to run every frame in _process anyway.
var _hp_bar_prev_ratio: float = 1.0
var _hp_bar_flash_timer: float = 0.0
const HP_BAR_FLASH_DURATION: float = 0.15  # Slightly shorter than boss (player hits are more frequent)
const HP_BAR_SHAKE_AMP: float = 4.0        # Slightly less violent than boss (player bar is smaller)

# ── Phase 16: Weapon Mod indicator ──
var _mod_indicator: Label = null
var _auto_fire_indicator: Label = null
var _auto_fire_pulse_phase: float = 0.0  # Phase accumulator for the [AUTO] badge alpha breathing

func _ready() -> void:
	# Add to "hud" group so other systems (PhotoMode) can find the HUD canvas layer
	add_to_group("hud")
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
	ap_ctrl.add_to_group("achievement_popup")
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

	# ── Auto-fire indicator (top-center, just under the level text) ──
	# Shows a pulsing [AUTO] badge while the Z-key pinned auto-fire is on, so
	# the player can tell at a glance that the game is firing for them. The
	# pulse is a gentle alpha breathing so it reads as "active" without being
	# distracting. Hidden by default; toggled by Player via set_auto_fire_indicator().
	_auto_fire_indicator = Label.new()
	_auto_fire_indicator.offset_left = 540.0
	_auto_fire_indicator.offset_top = 72.0
	_auto_fire_indicator.offset_right = 740.0
	_auto_fire_indicator.offset_bottom = 96.0
	_auto_fire_indicator.text = "🔥 [AUTO]"
	_auto_fire_indicator.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	_auto_fire_indicator.add_theme_font_size_override("font_size", 16)
	_auto_fire_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_auto_fire_indicator.visible = false
	add_child(_auto_fire_indicator)
	
	# Connect weapon mod signals for indicator updates
	WeaponModSystem.mod_equipped.connect(_on_mod_equipped_hud)
	WeaponModSystem.mod_unequipped.connect(_on_mod_unequipped_hud)
	WeaponModSystem.inventory_changed.connect(_on_inventory_changed_hud)
	# ── Phase 33: Weapon Mod Fusion — update HUD on fusion equip/unequip ──
	if WeaponModFusion:
		WeaponModFusion.fusion_equipped.connect(_on_fusion_equipped_hud)
		WeaponModFusion.fusion_removed.connect(_on_mod_unequipped_hud)

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

	# ── Phase 7: Quest Log / Mission Board ──
	var ql_script := load("res://scripts/quest_log.gd")
	var ql_ctrl := Control.new()
	ql_ctrl.set_script(ql_script)
	ql_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ql_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ql_ctrl)

	# ── Phase 7: Trader Trade Menu ──
	var tm_script := load("res://scripts/trade_menu.gd")
	var tm_ctrl := Control.new()
	tm_ctrl.set_script(tm_script)
	tm_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tm_ctrl)

	# ── Phase 26: Fast Travel Menu (B key) ──
	var ft_script := load("res://scripts/fast_travel_menu.gd")
	var ft_ctrl := Control.new()
	ft_ctrl.set_script(ft_script)
	ft_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ft_ctrl.add_to_group("fast_travel_menu")
	add_child(ft_ctrl)

	# ── Phase 25: Statistics Page (F2) ──
	var sp_script := load("res://scripts/statistics_page.gd")
	var sp_ctrl := Control.new()
	sp_ctrl.set_script(sp_script)
	sp_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	sp_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sp_ctrl)

	# ── Phase 25: Skill Tree UI (K) ──
	var st_script := load("res://scripts/skill_tree.gd")
	var st_ctrl := Control.new()
	st_ctrl.set_script(st_script)
	st_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	st_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(st_ctrl)

	# ── Phase 29: Equipment Menu UI (X) ──
	var eq_script := load("res://scripts/equipment_menu.gd")
	var eq_ctrl := Control.new()
	eq_ctrl.set_script(eq_script)
	eq_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	eq_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(eq_ctrl)

	# ── Phase 31: FPS Counter & Performance Overlay (F3) ──
	var fps_script := load("res://scripts/fps_counter.gd")
	var fps_ctrl := Control.new()
	fps_ctrl.set_script(fps_script)
	fps_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fps_ctrl)

	# ── Phase 25: Game Mode HUDs — Speedrun Timer, Boss Rush, Endless Wave ──
	# These overlays only draw when their respective mode is active; otherwise
	# they stay invisible (alpha 0) and consume negligible overhead.
	var srt_script := load("res://scripts/speedrun_timer.gd")
	var srt_ctrl := Control.new()
	srt_ctrl.set_script(srt_script)
	srt_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(srt_ctrl)

	var brh_script := load("res://scripts/boss_rush_hud.gd")
	var brh_ctrl := Control.new()
	brh_ctrl.set_script(brh_script)
	brh_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(brh_ctrl)

	var ewh_script := load("res://scripts/endless_wave_hud.gd")
	var ewh_ctrl := Control.new()
	ewh_ctrl.set_script(ewh_script)
	ewh_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ewh_ctrl)

	# ── Phase 30: Victory Screen (boss rush / speedrun / endless completion) ──
	var vs_script := load("res://scripts/victory_screen.gd")
	var vs_ctrl := Control.new()
	vs_ctrl.set_script(vs_script)
	vs_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	vs_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vs_ctrl)

	# ── Phase 30: Photo Mode (free-look camera + screenshots) ──
	# PhotoMode is a Node (not a Control) — it manages its own Camera3D and HUD panel.
	var pm_script := load("res://scripts/photo_mode.gd")
	var pm_node := Node.new()
	pm_node.set_script(pm_script)
	pm_node.name = "PhotoMode"
	add_child(pm_node)

	# ── Phase 32: Leaderboards Page (F12) ──
	var lb_script := load("res://scripts/leaderboards_page.gd")
	var lb_ctrl := Control.new()
	lb_ctrl.set_script(lb_script)
	lb_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lb_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lb_ctrl)

	# ── Phase 32: Replay Browser (F11) ──
	var rb_script := load("res://scripts/replay_browser.gd")
	var rb_ctrl := Control.new()
	rb_ctrl.set_script(rb_script)
	rb_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	rb_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rb_ctrl)

	# ── Phase 32: PvP Arena HUD ──
	var pvp_script := load("res://scripts/pvp_hud.gd")
	var pvp_ctrl := Control.new()
	pvp_ctrl.set_script(pvp_script)
	pvp_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	pvp_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pvp_ctrl)

	# ── Phase 27: Pet Accessory Menu UI (F6) ──
	var pam_script := load("res://scripts/pet_accessory_menu.gd")
	var pam_ctrl := Control.new()
	pam_ctrl.set_script(pam_script)
	pam_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	pam_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pam_ctrl)

	# ── Phase 27: Pet Training Menu UI (Shift+T) ──
	var ptm_script := load("res://scripts/pet_training_menu.gd")
	var ptm_ctrl := Control.new()
	ptm_ctrl.set_script(ptm_script)
	ptm_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ptm_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ptm_ctrl)

	# ── Phase 30/31: Register HUD with AccessibilityManager for UI scaling ──
	# AccessibilityManager scales the fixed-offset HUD children (HP bar, minimap,
	# labels) based on the persisted ui_scale setting. Full-rect menus are skipped.
	if AccessibilityManager:
		AccessibilityManager.register_hud(self)

	# Initialize displays
	_update_all_displays()

func _process(delta: float) -> void:
	# Timers
	if message_timer > 0:
		message_timer -= delta
		if message_timer <= 0:
			# Smooth fade-out instead of a hard visibility cut. The message
			# text used to vanish instantly when the timer hit zero, which
			# felt abrupt for informational text the player might still be
			# reading. Now it eases modulate.a to 0 over 0.25s (ease-in quad
			# for a gentle "settling" feel) and hides itself after the fade.
			# A tracked tween lets a new message kill the in-progress fade
			# and restart cleanly without stacking.
			if message_text:
				if message_text.has_meta("_msg_tween") and is_instance_valid(message_text.get_meta("_msg_tween") as Tween):
					(message_text.get_meta("_msg_tween") as Tween).kill()
				var msg_fade := create_tween()
				msg_fade.tween_property(message_text, "modulate:a", 0.0, 0.25) \
					.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				msg_fade.tween_callback(func():
					message_text.visible = false
					message_text.modulate.a = 1.0
				)
				message_text.set_meta("_msg_tween", msg_fade)

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
				fade_tween.parallel().tween_property(level_up_text, "scale", Vector2.ONE * 0.8, 0.3) \
					.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
				fade_tween.tween_callback(func():
					level_up_text.visible = false
					level_up_text.modulate.a = 1.0
					level_up_text.scale = Vector2.ONE
				)
	
	# Combo milestone flash decay — ease-out cubic so the flash punches in
	# and fades smoothly rather than linearly draining. Linear decay reads
	# as mechanical (a constant brightness slope); ease-out gives a sharp
	# pop that decelerates into nothing, matching the combo "thwack" feel.
	if _combo_flash_timer > 0:
		_combo_flash_timer -= delta
		var flash_progress: float = _combo_flash_timer / GameConstants.COMBO_MILESTONE_FLASH_DURATION
		flash_progress = clampf(flash_progress, 0.0, 1.0)
		# Ease-out cubic: 1-(1-t)^3 — sharp onset, gentle tail
		var eased: float = 1.0 - pow(1.0 - flash_progress, 3.0)
		if _combo_flash_rect:
			var alpha: float = eased * (40.0 / 255.0)  # Max alpha = 40/255 (subtle)
			var c: Color = _combo_flash_rect.color
			c.a = alpha
			_combo_flash_rect.color = c
			if _combo_flash_timer <= 0:
				_combo_flash_rect.color = Color(0, 0, 0, 0)
	
	# Pickup streak display timer
	if _pickup_streak_timer > 0:
		_pickup_streak_timer -= delta
		if _pickup_streak_timer <= 0 and _pickup_streak_label:
			# Smooth fade-out instead of a hard hide. The streak label used
			# to vanish instantly, which felt flat for a celebratory popup.
			# Now it eases modulate.a to 0 over 0.3s (ease-in quad) and
			# hides itself after the fade. A tracked tween lets a new
			# streak milestone kill the in-progress fade and restart cleanly.
			if _pickup_streak_label.has_meta("_ps_tween") and is_instance_valid(_pickup_streak_label.get_meta("_ps_tween") as Tween):
				(_pickup_streak_label.get_meta("_ps_tween") as Tween).kill()
			var ps_fade := create_tween()
			ps_fade.tween_property(_pickup_streak_label, "modulate:a", 0.0, 0.3) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			ps_fade.tween_callback(func():
				_pickup_streak_label.visible = false
				_pickup_streak_label.modulate.a = 1.0
			)
			_pickup_streak_label.set_meta("_ps_tween", ps_fade)

	# Smoothly animate bars toward target ratios (frame-rate independent lerp)
	var weight: float = 1.0 - exp(-_bar_smoothing * delta)

	# HP bar
	var hp_current_ratio: float = hp_bar.size.x / hp_bar_bg.size.x if hp_bar_bg.size.x > 0 else 0.0
	hp_current_ratio = lerpf(hp_current_ratio, _hp_bar_target_ratio, weight)
	hp_bar.size.x = hp_bar_bg.size.x * hp_current_ratio
	# ── Player HP bar damage flash + shake ── Mirrors the boss bar juice.
	# Detect a ratio drop (damage taken) by comparing to last frame's value,
	# then drive a white flash blend + horizontal sine shake that decays over
	# HP_BAR_FLASH_DURATION. The flash envelope uses ease-out cubic (sharp
	# onset, gentle tail) and the shake amplitude scales with the envelope so
	# the bar jitters hardest on the hit frame and settles smoothly. This
	# gives the player's own damage events a visceral UI read that matches
	# the boss bar language — damage feels consistent whether giving or
	# receiving it. Heals (ratio increase) do NOT trigger the flash, so
	# pickups/healing read as positive without a confusing white pop.
	if _hp_bar_target_ratio < _hp_bar_prev_ratio - 0.001:
		_hp_bar_flash_timer = HP_BAR_FLASH_DURATION
	_hp_bar_prev_ratio = _hp_bar_target_ratio
	# Build the target color: the ratio-based gradient, optionally blended
	# toward white while the flash timer is active.
	var hp_bar_color_target: Color = _hp_bar_target_color
	if _hp_bar_flash_timer > 0.0:
		_hp_bar_flash_timer = max(0.0, _hp_bar_flash_timer - delta)
		var hp_flash_env: float = _hp_bar_flash_timer / HP_BAR_FLASH_DURATION
		# Ease-out cubic for a sharp onset and gentle tail (matches boss bar)
		hp_flash_env = 1.0 - pow(1.0 - hp_flash_env, 3.0)
		hp_bar_color_target = hp_bar_color_target.lerp(Color.WHITE, hp_flash_env * 0.7)
	hp_bar.color = hp_bar.color.lerp(hp_bar_color_target, 1.0 - exp(-_color_smoothing * delta))
	# Horizontal shake on the bar fill — decaying sine wobble biased by the
	# flash envelope. We shake the bar ColorRect's offset_left rather than the
	# container so the border/HP text stay steady and only the fill jitters.
	if _hp_bar_flash_timer > 0.0:
		var hp_shake_env: float = _hp_bar_flash_timer / HP_BAR_FLASH_DURATION
		var hp_shake: float = sin(_hp_bar_flash_timer * 70.0) * HP_BAR_SHAKE_AMP * hp_shake_env
		hp_bar.offset_left = 2.0 + hp_shake
	else:
		hp_bar.offset_left = 2.0

	# XP bar
	var xp_bar_width: float = xp_bar_container.size.x - 4.0 if xp_bar_container.size.x > 0 else 396.0
	var xp_current_ratio: float = xp_bar.size.x / xp_bar_width if xp_bar_width > 0 else 0.0
	xp_current_ratio = lerpf(xp_current_ratio, _xp_bar_target_ratio, weight)
	xp_bar.size.x = xp_bar_width * xp_current_ratio

	# Combo timer bar
	if GameManager.player_combo > 0:
		combo_timer_bar.visible = true
		var combo_max: float = GameConstants.COMBO_TIMEOUT + CoOpManager.get_combo_window_bonus()
		var ratio := GameManager.player_combo_timer / combo_max
		combo_timer_bar.size.x = 200.0 * clampf(ratio, 0.0, 1.0)
		# Color: green (fresh) → yellow → red (expiring). The comment used to
		# claim this gradient but only yellow→red was implemented — the green
		# "just pressed" state was missing. Now a fresh combo reads as green
		# and warms through yellow to red as it runs out, matching the HP bar
		# color language and giving players a clear "time is running out" cue.
		if ratio > 0.5:
			# Green (0,1,0) → Yellow (1,1,0) as ratio goes 1.0 → 0.5
			var t_green: float = (1.0 - ratio) * 2.0
			combo_timer_bar.color = Color(t_green, 1.0, 0.0)
		else:
			# Yellow (1,1,0) → Red (1,0,0) as ratio goes 0.5 → 0.0
			combo_timer_bar.color = Color(1.0, ratio * 2.0, 0.0)
	else:
		combo_timer_bar.visible = false

	# Boss HP bar (smooth)
	# NOTE: We do NOT touch boss_hp_container.visible here — the entrance
	# and exit animations in _on_boss_spawned/_on_boss_defeated own the
	# container's visibility, modulate, and offset_top. Forcing visible=true
	# here would fight the exit fade-out tween; forcing visible=false would
	# cut off the entrance slide-in. We only update the bar fill + color
	# while a valid boss reference exists.
	if boss_ref and is_instance_valid(boss_ref) and boss_ref.hp > 0:
		_boss_bar_target_ratio = float(boss_ref.hp) / float(boss_ref.max_hp) if boss_ref.max_hp > 0 else 0.0
		# ── Damage flash detection ── Compare the boss's current HP ratio
		# to last frame's value. A drop means the boss was hit this frame —
		# trigger the white flash + horizontal shake. This is polled here
		# rather than connected to EnemyBase.enemy_hit because that signal
		# is per-enemy and we'd need to re-connect every time a new boss
		# spawns. Polling the ratio is simpler and robust to boss swaps.
		if _boss_bar_target_ratio < _boss_bar_prev_ratio - 0.001:
			_boss_bar_flash_timer = BOSS_BAR_FLASH_DURATION
		_boss_bar_prev_ratio = _boss_bar_target_ratio
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
		# ── Damage flash: blend the bar color toward white while the flash
		# timer is active, then ease back. The flash envelope is a decaying
		# exponential so it punches in on the hit frame and fades smoothly.
		var bar_color: Color = _boss_bar_target_color
		if _boss_bar_flash_timer > 0.0:
			_boss_bar_flash_timer = max(0.0, _boss_bar_flash_timer - delta)
			var flash_env: float = _boss_bar_flash_timer / BOSS_BAR_FLASH_DURATION
			# Ease-out cubic for a sharp onset and gentle tail
			flash_env = 1.0 - pow(1.0 - flash_env, 3.0)
			bar_color = bar_color.lerp(Color.WHITE, flash_env * 0.7)
		boss_hp_bar.color = boss_hp_bar.color.lerp(bar_color, 1.0 - exp(-_color_smoothing * delta))
		# ── Horizontal shake on the bar fill ── A decaying sine wobble
		# biased by the flash envelope. The bar shakes left/right by a
		# few pixels on each hit, reinforcing the impact. We shake the
		# bar ColorRect's offset_left/right rather than the container so
		# the border/name text stay steady and only the fill jitters.
		if _boss_bar_flash_timer > 0.0:
			var shake_env: float = _boss_bar_flash_timer / BOSS_BAR_FLASH_DURATION
			var shake: float = sin(_boss_bar_flash_timer * 60.0) * BOSS_BAR_SHAKE_AMP * shake_env
			boss_hp_bar.offset_left = 2.0 + shake
		else:
			boss_hp_bar.offset_left = 2.0
	else:
		# Boss reference is gone — clear it so we don't keep querying a
		# freed node. The container visibility is handled by the exit anim.
		boss_ref = null
		_boss_bar_prev_ratio = 1.0
		_boss_bar_flash_timer = 0.0

	# ── Auto-fire indicator pulse ── A gentle alpha breathing so the [AUTO]
	#    badge reads as "active" without being distracting. Uses a slow sine
	#    (1.5 Hz) that swings modulate.a between 0.55 and 1.0 — clearly
	#    visible, never fully dim. Only runs while the indicator is visible
	#    (i.e. while the Z-key pinned auto-fire is on).
	if _auto_fire_indicator and _auto_fire_indicator.visible:
		_auto_fire_pulse_phase += delta * 1.5 * TAU
		var pulse: float = 0.775 + 0.225 * sin(_auto_fire_pulse_phase)
		_auto_fire_indicator.modulate.a = pulse

## Toggle the [AUTO] fire indicator visibility. Called by Player when the
## Z-key auto-fire toggle changes state. No-op if the HUD hasn't been built
## yet (defensive — the player could theoretically toggle before _ready).
func set_auto_fire_indicator(active: bool) -> void:
	if not _auto_fire_indicator:
		return
	_auto_fire_indicator.visible = active
	if not active:
		# Reset alpha so a later show starts at full opacity, not the last
		# pulse value (which could be near the dim trough and look like a
		# faded-in badge).
		_auto_fire_indicator.modulate.a = 1.0
		_auto_fire_pulse_phase = 0.0

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
		level_up_text.scale = Vector2.ZERO
		level_up_text.modulate.a = 1.0
		var lv_tween := create_tween()
		lv_tween.tween_property(level_up_text, "scale", Vector2.ONE * 1.25, 0.25) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		lv_tween.tween_property(level_up_text, "scale", Vector2.ONE, 0.15) \
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
			combo_tween.tween_property(combo_text, "scale", Vector2.ONE * 1.3, 0.06) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			combo_tween.tween_property(combo_text, "scale", Vector2.ONE, 0.15) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
			combo_text.set_meta("_combo_tween", combo_tween)
	else:
		combo_text.visible = false

func _on_score_changed(new_score: int) -> void:
	score_text.text = "Score: %d" % new_score
	kills_text.text = "Kills: %d" % GameManager.player_kills
	# ── Score pop animation ── A quick scale punch on the score label so
	# gaining score feels rewarding, mirroring the combo text "thwack".
	# Skipped on the initial _update_all_displays() call (score 0 → 0 is
	# not a gain). The tween is tracked so rapid score changes (kills,
	# pickup streaks) kill the in-progress pop and restart cleanly without
	# stacking. Tiny amplitude (1.18x) and short duration keep it from
	# being distracting during fast combat.
	if score_text and new_score > 0:
		if score_text.has_meta("_score_tween") and is_instance_valid(score_text.get_meta("_score_tween") as Tween):
			(score_text.get_meta("_score_tween") as Tween).kill()
		score_text.scale = Vector2.ONE * 1.18
		var score_tween := create_tween()
		score_tween.tween_property(score_text, "scale", Vector2.ONE, 0.15) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		score_text.set_meta("_score_tween", score_tween)
	# ── Kills text pop ── Same treatment for the kills counter so kill
	# events register visually. Slightly smaller amplitude (1.12x) since
	# the kills label is secondary to the score.
	if kills_text and GameManager.player_kills > 0:
		if kills_text.has_meta("_kills_tween") and is_instance_valid(kills_text.get_meta("_kills_tween") as Tween):
			(kills_text.get_meta("_kills_tween") as Tween).kill()
		kills_text.scale = Vector2.ONE * 1.12
		var kills_tween := create_tween()
		kills_tween.tween_property(kills_text, "scale", Vector2.ONE, 0.15) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		kills_text.set_meta("_kills_tween", kills_tween)

func _on_player_died() -> void:
	show_message("Zorp has fallen!", 5.0)
	# Death screen is handled by DeathScreen node (death_screen.gd)

func _on_game_restarted() -> void:
	_update_all_displays()
	combo_text.visible = false
	level_up_text.visible = false
	# Reset HP bar damage-flash state so a fresh game doesn't carry over a
	# lingering flash/shake from the previous run's last hit. The boss bar
	# state is reset in its own block above (when boss_ref clears).
	_hp_bar_prev_ratio = 1.0
	_hp_bar_flash_timer = 0.0
	if hp_bar:
		hp_bar.offset_left = 2.0
	# Reset the auto-fire indicator — the player's _auto_fire_pinned flag is
	# reset on respawn (see Player._on_game_restarted_player), but the HUD
	# indicator also needs to clear so a stale [AUTO] badge doesn't persist
	# into the new run. Calling set_auto_fire_indicator(false) hides the
	# label and resets the pulse phase.
	set_auto_fire_indicator(false)

func _update_all_displays() -> void:
	_on_hp_changed(GameManager.player_hp, GameManager.player_max_hp)
	_on_xp_changed(GameManager.player_xp, GameManager.player_xp_to_next)
	_on_score_changed(GameManager.player_score)
	level_text.text = "Lv %d" % GameManager.player_level

func show_message(text: String, duration: float = 2.0) -> void:
	# Kill any in-progress fade-out tween so a new message doesn't fight
	# the dying one's modulate:a animation. Without this, a message arriving
	# during the 0.25s fade window would snap to alpha 0 (the fade's current
	# value) and be invisible. Resetting modulate.a to 1.0 here guarantees
	# the new text is fully opaque on entry.
	if message_text:
		if message_text.has_meta("_msg_tween") and is_instance_valid(message_text.get_meta("_msg_tween") as Tween):
			(message_text.get_meta("_msg_tween") as Tween).kill()
		message_text.modulate.a = 1.0
	message_text.text = text
	message_text.visible = true
	message_timer = duration

func set_boss_reference(enemy: Node3D) -> void:
	boss_ref = enemy

# ── Boss HP bar entrance/exit tween ── Tracked so a re-spawn mid-fade-out
#    doesn't stack tweens fighting over modulate/position. Killed before
#    starting a new one.
var _boss_bar_tween: Tween = null

func _on_boss_spawned(boss: Node) -> void:
	boss_ref = boss
	GameManager.current_boss = boss
	if "enemy_name" in boss:
		boss_name_text.text = "☠ %s" % boss.enemy_name
		show_message("⚠ %s has appeared!" % boss.enemy_name, 3.0)
	# ── Entrance animation: slide down from above + fade in ──
	# The bar snaps in on a hard `visible = true` previously, which felt flat
	# for such a dramatic event (a boss appearing). Now it slides down from
	# 40px above its resting position with an ease-out-back overshoot and
	# fades in modulate.a, so the boss bar "drops in" with weight. The
	# container starts fully transparent and off-position so there's no
	# one-frame flash of the resting bar before the tween kicks in.
	if boss_hp_container:
		if _boss_bar_tween and _boss_bar_tween.is_valid():
			_boss_bar_tween.kill()
		boss_hp_container.visible = true
		boss_hp_container.modulate.a = 0.0
		# Reset damage-flash state so the spawn doesn't register as a hit
		_boss_bar_prev_ratio = 1.0
		_boss_bar_flash_timer = 0.0
		# Cache the resting offsets so we can tween relative to them
		var rest_top: float = boss_hp_container.offset_top
		# Start from 40px above the resting position BEFORE creating the
		# tween so the tween reads the correct initial value on its first
		# processing frame.
		boss_hp_container.offset_top = rest_top - 40.0
		_boss_bar_tween = create_tween()
		_boss_bar_tween.set_parallel(true)
		# Fade in
		_boss_bar_tween.tween_property(boss_hp_container, "modulate:a", 1.0, 0.35) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		# Slide down from 40px above — ease-out-back gives a subtle overshoot
		# for a "dropping in with weight" feel.
		_boss_bar_tween.tween_property(boss_hp_container, "offset_top",
			rest_top, 0.45) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_boss_defeated(boss: Node) -> void:
	boss_ref = null
	GameManager.current_boss = null
	var display_name: String = "Boss"
	if "enemy_name" in boss:
		display_name = boss.enemy_name
	show_message("%s defeated!" % display_name, 3.0)
	# ── Exit animation: fade out + slide up, then hide ──
	# Previously the bar vanished instantly on boss death, which undercut the
	# climactic moment. Now it fades out over 0.5s while sliding up 30px,
	# giving the player a beat to register the kill before the UI clears.
	# The container is hidden via tween_callback after the fade so the
	# smooth exit completes fully.
	if boss_hp_container:
		if _boss_bar_tween and _boss_bar_tween.is_valid():
			_boss_bar_tween.kill()
		# If the bar is already hidden (e.g. boss died during spawn fade),
		# skip the exit animation entirely.
		if not boss_hp_container.visible:
			return
		var rest_top: float = boss_hp_container.offset_top
		_boss_bar_tween = create_tween()
		_boss_bar_tween.set_parallel(true)
		_boss_bar_tween.tween_property(boss_hp_container, "modulate:a", 0.0, 0.5) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_boss_bar_tween.tween_property(boss_hp_container, "offset_top",
			rest_top - 30.0, 0.5) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		# After the fade, hide and restore the resting position + modulate
		# so the next boss spawn starts from a clean state.
		_boss_bar_tween.chain().tween_callback(func():
			boss_hp_container.visible = false
			boss_hp_container.modulate.a = 1.0
			boss_hp_container.offset_top = rest_top
		)

func _on_message_added(text: String) -> void:
	# ── Phase 26: Lore messages display longer so the player can read them ──
	if text.begins_with("📜 LORE:"):
		show_message(text, 6.0)
	elif text.begins_with("📜"):
		show_message(text, 3.5)
	else:
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
		# Kill any in-progress fade-out so a new streak milestone doesn't
		# fight the dying label's modulate:a animation and end up invisible.
		if _pickup_streak_label.has_meta("_ps_tween") and is_instance_valid(_pickup_streak_label.get_meta("_ps_tween") as Tween):
			(_pickup_streak_label.get_meta("_ps_tween") as Tween).kill()
		_pickup_streak_label.modulate.a = 1.0
		_pickup_streak_label.text = "✦ PICKUP STREAK x%d (+%d XP)" % [streak, xp_bonus]
		_pickup_streak_label.visible = true
		# Quick scale pop on each new milestone — mirrors the combo text
		# punch-in. Grows to 1.25x in 60ms then settles with elastic wobble,
		# giving each streak tick a celebratory "thwack" feel.
		_pickup_streak_label.scale = Vector2.ONE
		var ps_pop := create_tween()
		ps_pop.tween_property(_pickup_streak_label, "scale", Vector2.ONE * 1.25, 0.06) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		ps_pop.tween_property(_pickup_streak_label, "scale", Vector2.ONE, 0.18) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
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

# ── Phase 33: Weapon Mod Fusion — HUD handler for fusion equip ──
func _on_fusion_equipped_hud(_fused_id: int) -> void:
	_update_mod_indicator()

func _on_inventory_changed_hud() -> void:
	_update_mod_indicator()

func _update_mod_indicator() -> void:
	if not _mod_indicator:
		return
	var mod_name: String = "Standard Laser"
	var mod_color: Color = Color(0.7, 0.8, 1.0)
	# ── Phase 33: Weapon Mod Fusion — show fused mod when equipped ──
	if WeaponModFusion and WeaponModFusion.is_fused_equipped():
		mod_name = "⚗ " + WeaponModFusion.get_equipped_name()
		mod_color = WeaponModFusion.get_equipped_color()
	elif WeaponModSystem:
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