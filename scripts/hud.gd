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
			level_up_text.visible = false

	# Smoothly animate bars toward target ratios (frame-rate independent lerp)
	var weight: float = 1.0 - exp(-_bar_smoothing * delta)

	# HP bar
	var hp_current_ratio: float = hp_bar.size.x / hp_bar_bg.size.x if hp_bar_bg.size.x > 0 else 0.0
	hp_current_ratio = lerpf(hp_current_ratio, _hp_bar_target_ratio, weight)
	hp_bar.size.x = hp_bar_bg.size.x * hp_current_ratio

	# XP bar
	var xp_current_ratio: float = xp_bar.size.x / 400.0
	xp_current_ratio = lerpf(xp_current_ratio, _xp_bar_target_ratio, weight)
	xp_bar.size.x = 400.0 * xp_current_ratio

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
		var boss_current_ratio: float = boss_hp_bar.size.x / 300.0
		boss_current_ratio = lerpf(boss_current_ratio, _boss_bar_target_ratio, weight)
		boss_hp_bar.size.x = 300.0 * boss_current_ratio
		boss_name_text.text = "☠ %s" % boss_ref.enemy_name
		# Boss bar color: red → orange → yellow
		if boss_current_ratio > 0.5:
			boss_hp_bar.color = Color(1.0, (1.0 - boss_current_ratio) * 2.0 * 0.78, 0.0)
		else:
			boss_hp_bar.color = Color(1.0, boss_current_ratio * 2.0 * 0.39, 0.0)
	else:
		boss_hp_container.visible = false
		boss_ref = null

func _on_hp_changed(new_hp: int, max_hp: int) -> void:
	var ratio := float(new_hp) / float(max_hp) if max_hp > 0 else 0.0
	_hp_bar_target_ratio = ratio
	hp_text.text = "%d / %d" % [new_hp, max_hp]

	# Color: green → yellow → red (set immediately, bar size animates smoothly)
	if ratio > 0.5:
		hp_bar.color = Color(1.0 - (ratio - 0.5) * 2.0, 1.0, 0.0)
	else:
		hp_bar.color = Color(1.0, ratio * 2.0, 0.0)

func _on_xp_changed(new_xp: int, xp_to_next: int) -> void:
	var ratio := float(new_xp) / float(xp_to_next) if xp_to_next > 0 else 0.0
	_xp_bar_target_ratio = ratio
	xp_text.text = "XP: %d / %d" % [new_xp, xp_to_next]

func _on_level_up(level: int) -> void:
	level_text.text = "Lv %d" % level
	level_up_text.text = "LEVEL UP! → Lv %d" % level
	level_up_text.visible = true
	level_up_display_timer = 3.0
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
	show_message("%s defeated!" % boss.enemy_name, 3.0)

func _on_message_added(text: String) -> void:
	show_message(text, 2.5)