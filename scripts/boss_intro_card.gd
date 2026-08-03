## Zorp Wiggles — Boss Intro Card
## Enhancement Pack 20: A dramatic full-screen boss name overlay that plays
## when any boss spawns. The boss's name slides in from the left with a
## dark backdrop bar, holds for ~2 seconds, then slides out to the right.
## This gives boss appearances a cinematic "title card" moment beyond the
## existing boss HP bar slide-in and HUD message — the player sees the
## boss's name in large text centered on screen, creating an anticipation
## beat before the fight begins.
##
## The card is purely visual — it doesn't block input or pause the game.
## It coexists with the boss HP bar entrance animation (which slides down
## from above) and the HUD message ("⚠ [Boss] has appeared!"). The intro
## card is the "big reveal" while the HP bar is the "fight HUD."

extends Control

# ── Visual elements ───────────────────────────────────────────────────────────
var _backdrop: ColorRect = null
var _name_label: Label = null
var _subtitle_label: Label = null
var _card_container: Panel = null

# ── State ────────────────────────────────────────────────────────────────────
var _active: bool = false
var _timer: float = 0.0
var _card_tween: Tween = null

# Card timing — total ~2.2s: 0.3s slide in, 1.6s hold, 0.3s slide out
const SLIDE_IN_DURATION: float = 0.35
const HOLD_DURATION: float = 1.6
const SLIDE_OUT_DURATION: float = 0.35

# Card dimensions
const CARD_WIDTH: float = 600.0
const CARD_HEIGHT: float = 120.0
const NAME_FONT_SIZE: int = 36
const SUBTITLE_FONT_SIZE: int = 16

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# ── Backdrop ── A semi-transparent dark bar across the middle of the
	# screen that provides contrast for the boss name text. It fades in
	# and out with the card.
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.0)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	# ── Card container ── A centered panel that holds the boss name + subtitle.
	# Starts off-screen (left) and slides to center, then exits right.
	_card_container = Panel.new()
	_card_container.offset_left = 0.0
	_card_container.offset_top = 0.0
	_card_container.offset_right = CARD_WIDTH
	_card_container.offset_bottom = CARD_HEIGHT
	_card_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_container.visible = false
	# Center the card horizontally and vertically
	_card_container.position = Vector2(
		(get_viewport_rect().size.x - CARD_WIDTH) * 0.5,
		get_viewport_rect().size.y * 0.35
	)
	add_child(_card_container)

	# Style the panel with a dark semi-transparent background + red border
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.02, 0.08, 0.92)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.8, 0.1, 0.15, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	_card_container.add_theme_stylebox_override("panel", style)

	# ── Boss name label ── Large bold text centered in the card
	_name_label = Label.new()
	_name_label.text = ""
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	_name_label.position = Vector2(0, 18)
	_name_label.size = Vector2(CARD_WIDTH, 50)
	_card_container.add_child(_name_label)

	# ── Subtitle label ── "BOSS" or "MEGA-BOSS" or "WORLD BOSS" tag
	_subtitle_label = Label.new()
	_subtitle_label.text = ""
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	_subtitle_label.add_theme_font_size_override("font_size", SUBTITLE_FONT_SIZE)
	_subtitle_label.position = Vector2(0, 70)
	_subtitle_label.size = Vector2(CARD_WIDTH, 30)
	_card_container.add_child(_subtitle_label)

	# Connect to boss spawn signal
	if GameManager:
		GameManager.boss_spawned.connect(_on_boss_spawned)
		GameManager.game_restarted.connect(_on_game_restarted)

	# Connect to resize so the card stays centered
	get_viewport().size_changed.connect(_recenter_card)

func _recenter_card() -> void:
	if _card_container and _card_container.visible:
		_card_container.position = Vector2(
			(get_viewport_rect().size.x - CARD_WIDTH) * 0.5,
			get_viewport_rect().size.y * 0.35
		)

func _process(delta: float) -> void:
	if not _active:
		return
	_timer += delta
	# Auto-hide after the full sequence
	if _timer >= SLIDE_IN_DURATION + HOLD_DURATION + SLIDE_OUT_DURATION:
		_hide_card()

func _on_boss_spawned(boss: Node) -> void:
	if not is_instance_valid(boss):
		return
	# Get the boss name
	var boss_name: String = "Unknown Boss"
	if "enemy_name" in boss:
		boss_name = boss.enemy_name
	# Determine the subtitle tag
	var subtitle: String = "⚠ BOSS"
	if boss.has_meta("is_world_boss") and boss.get_meta("is_world_boss"):
		subtitle = "🌍 WORLD BOSS"
	elif "max_hp" in boss:
		var hp_val: int = int(boss.get("max_hp"))
		if hp_val >= 500:
			subtitle = "☠ MEGA-BOSS"
		elif hp_val >= 200:
			subtitle = "⚠ BOSS"
	_show_card(boss_name, subtitle)

func _show_card(boss_name: String, subtitle: String) -> void:
	# Enhancement Pack 26: SFX on boss intro card — the dramatic card
	# animation had a visual slide-in but no audio. The SFX_BOSS_SPAWN
	# syncs with the card appearance for a cinematic moment.
	AudioManager.play_sfx(AudioManager.SFX_BOSS_SPAWN)
	# Kill any existing tween
	if _card_tween and _card_tween.is_valid():
		_card_tween.kill()
	_name_label.text = boss_name
	_subtitle_label.text = subtitle
	_card_container.visible = true
	_recenter_card()
	_active = true
	_timer = 0.0
	# Start the card off-screen to the left
	var screen_w: float = get_viewport_rect().size.x
	var center_x: float = (screen_w - CARD_WIDTH) * 0.5
	var card_y: float = get_viewport_rect().size.y * 0.35
	_card_container.position = Vector2(-CARD_WIDTH - 50, card_y)
	_card_container.modulate.a = 0.0
	_backdrop.color.a = 0.0
	# ── Slide-in + hold + slide-out tween sequence ──
	_card_tween = create_tween()
	# Phase 1: Slide in from left + fade in backdrop
	_card_tween.set_parallel(true)
	_card_tween.tween_property(_card_container, "position:x", center_x, SLIDE_IN_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_card_tween.tween_property(_card_container, "modulate:a", 1.0, SLIDE_IN_DURATION * 0.7) \
		.set_ease(Tween.EASE_OUT)
	_card_tween.tween_property(_backdrop, "color:a", 0.35, SLIDE_IN_DURATION) \
		.set_ease(Tween.EASE_OUT)
	# Phase 2: Hold (no tween — just a delay via the timer)
	_card_tween.chain().tween_interval(HOLD_DURATION)
	# Phase 3: Slide out to right + fade out backdrop
	_card_tween.set_parallel(true)
	_card_tween.tween_property(_card_container, "position:x", screen_w + 50, SLIDE_OUT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_card_tween.tween_property(_card_container, "modulate:a", 0.0, SLIDE_OUT_DURATION * 0.8) \
		.set_ease(Tween.EASE_IN)
	_card_tween.tween_property(_backdrop, "color:a", 0.0, SLIDE_OUT_DURATION) \
		.set_ease(Tween.EASE_IN)

func _hide_card() -> void:
	_active = false
	_card_container.visible = false
	_backdrop.color.a = 0.0
	_timer = 0.0

func _on_game_restarted() -> void:
	_hide_card()
	if _card_tween and _card_tween.is_valid():
		_card_tween.kill()