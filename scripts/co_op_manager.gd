## Zorp Wiggles — Co-op Manager (Autoload Singleton)
## Phase 19: Local Co-op — Player 2 "Zerp" drops in for shared-screen co-op.
##
## Manages:
##   - Drop-in / drop-out for Player 2
##   - Shared combo system (both players contribute)
##   - Co-op mega pulse wave (both players Q within sync window)
##   - Revive system (downed player can be revived by partner)
##   - Enemy scaling queries (HP/damage/spawn-rate multipliers)
##   - Co-op achievement milestones

extends Node

signal p2_joined()
signal p2_left()
signal p2_downed()
signal p2_revived()
signal p2_died()
signal p2_hp_changed(hp: int, max_hp: int)
signal p2_score_changed(score: int)
signal mega_pulse_triggered(center: Vector3)
signal co_op_milestone(milestone_id: int, description: String)
signal revive_progress_changed(progress: float)
# ── Visual feedback signals (co-op parity with P1's damage/level/heal effects) ──
signal p2_damaged(source_pos: Vector3)
signal p2_healed(amount: int)
signal p2_levelup(level: int)

# ─── State ───────────────────────────────────────────────────────────────────
var p2_active: bool = false
var p2_node: CharacterBody3D = null
var p2_hp: int = 0
var p2_max_hp: int = 0
var p2_score: int = 0
var p2_is_downed: bool = false
var p2_downed_timer: float = 0.0
var p2_revive_progress: float = 0.0

# ── Drop-out hold tracking ──
var _drop_out_hold_timer: float = 0.0

# ── Mega pulse sync window ──
# When P1 fires pulse wave, we start a sync window. If P2 fires within the
# window, a mega pulse is triggered instead of two normal pulses.
var _mega_pulse_window: float = 0.0
var _p1_pulse_pending: bool = false
var _p2_pulse_pending: bool = false
var _p1_pulse_pos: Vector3 = Vector3.ZERO
var _p2_pulse_pos: Vector3 = Vector3.ZERO

# ── Co-op achievement tracking ──
var _coop_kills: int = 0
var _coop_revives: int = 0
var _coop_mega_pulses: int = 0
var _coop_milestones_unlocked: Dictionary = {}  # { id: true }
# ── P2 HP regen accumulator (fractional HP from Regeneration skill) ──
var _p2_regen_accumulator: float = 0.0

# ── P2 scene ──
const P2_SCENE := preload("res://scenes/entities/player2_zerp.tscn")

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if not p2_active:
		# Check for drop-in input
		if Input.is_action_just_pressed("p2_start") and GameManager.player_is_alive and not GameManager.is_paused:
			drop_in_p2()
		return

	# Drop-out: hold p2_start for COOP_DROP_OUT_HOLD_TIME seconds
	if Input.is_action_pressed("p2_start"):
		_drop_out_hold_timer += delta
		if _drop_out_hold_timer >= GameConstants.COOP_DROP_OUT_HOLD_TIME:
			drop_out_p2()
			_drop_out_hold_timer = 0.0
	else:
		_drop_out_hold_timer = 0.0

	# Downed state handling
	if p2_is_downed:
		_update_downed(delta)
	else:
		# ── Phase 25: HP regen from ProgressionSystem (Regeneration skill) ──
		# P2 also benefits from passive HP regen, same as P1
		if ProgressionSystem and p2_hp < p2_max_hp:
			var regen: float = ProgressionSystem.get_hp_regen_per_sec()
			if regen > 0:
				_p2_regen_accumulator += regen * delta
				while _p2_regen_accumulator >= 1.0:
					_p2_regen_accumulator -= 1.0
					p2_hp = min(p2_max_hp, p2_hp + 1)
				p2_hp_changed.emit(p2_hp, p2_max_hp)

	# Mega pulse sync window countdown
	if _mega_pulse_window > 0:
		_mega_pulse_window -= delta
		if _mega_pulse_window <= 0:
			# Window expired — fire any pending normal pulses
			_fire_pending_normal_pulses()

# ─── Drop-in / Drop-out ─────────────────────────────────────────────────────

## Spawn Player 2 (Zerp) near Player 1. Called when P2 presses Start.
func drop_in_p2() -> void:
	if p2_active:
		return
	if not GameManager.player or not is_instance_valid(GameManager.player):
		return

	p2_node = P2_SCENE.instantiate() as CharacterBody3D
	var world: Node3D = GameManager.player.get_parent()
	world.add_child(p2_node)
	p2_node.global_position = GameManager.player.global_position + GameConstants.P2_SPAWN_OFFSET

	p2_active = true
	# ── Phase 25/29: Scale P2 max HP by ProgressionSystem (Vitality) + EquipmentSystem bonuses ──
	p2_max_hp = GameConstants.P2_HP
	if ProgressionSystem:
		p2_max_hp += ProgressionSystem.get_max_hp_bonus()
	if EquipmentSystem:
		p2_max_hp += EquipmentSystem.get_max_hp_bonus()
	p2_hp = p2_max_hp
	p2_score = 0
	p2_is_downed = false
	p2_downed_timer = 0.0
	p2_revive_progress = 0.0
	_p2_regen_accumulator = 0.0

	p2_joined.emit()
	p2_hp_changed.emit(p2_hp, p2_max_hp)
	p2_score_changed.emit(p2_score)
	GameManager.add_message("🎮 %s joined the adventure! [Arrows] move, [/] shoot, [Enter] dash, [RShift] pulse, [.] revive" % GameConstants.P2_NAME)
	print("[CoOp] Player 2 (%s) dropped in" % GameConstants.P2_NAME)

## Remove Player 2 from the game. Called on drop-out or game restart.
func drop_out_p2() -> void:
	if not p2_active:
		return
	if p2_node and is_instance_valid(p2_node):
		# Death poof effect
		ParticleEffects.spawn_death_poof(p2_node.get_parent(), p2_node.global_position, GameConstants.P2_BASE_COLOR, 0.8)
		p2_node.queue_free()
	p2_node = null
	p2_active = false
	p2_is_downed = false
	p2_downed_timer = 0.0
	p2_revive_progress = 0.0
	p2_left.emit()
	GameManager.add_message("🎮 %s left the game" % GameConstants.P2_NAME)
	print("[CoOp] Player 2 dropped out")

## Force-remove P2 (used on game restart / death)
func force_remove_p2() -> void:
	if p2_node and is_instance_valid(p2_node):
		p2_node.queue_free()
	p2_node = null
	p2_active = false
	p2_is_downed = false
	p2_downed_timer = 0.0
	p2_revive_progress = 0.0
	_mega_pulse_window = 0.0
	_p1_pulse_pending = false
	_p2_pulse_pending = false

# ─── Shared Combo ────────────────────────────────────────────────────────────

## Called when either player kills an enemy. In co-op, the combo is shared.
func register_coop_kill(killer_is_p1: bool) -> void:
	_coop_kills += 1
	# Check co-op milestones
	_check_coop_milestones()

func get_combo_window_bonus() -> float:
	if p2_active:
		return GameConstants.COOP_COMBO_WINDOW_BONUS
	return 0.0

# ─── Mega Pulse Wave ─────────────────────────────────────────────────────────

## Called by a player when they fire a pulse wave. If both players fire within
## the sync window, a mega pulse is triggered instead.
func report_pulse_wave(is_p1: bool, pos: Vector3) -> void:
	if not p2_active:
		return  # No mega pulse in single player

	if is_p1:
		_p1_pulse_pending = true
		_p1_pulse_pos = pos
	else:
		_p2_pulse_pending = true
		_p2_pulse_pos = pos

	# Check if both are pending → trigger mega pulse
	if _p1_pulse_pending and _p2_pulse_pending:
		_trigger_mega_pulse()
		return

	# Start / extend the sync window
	_mega_pulse_window = GameConstants.COOP_PULSE_SYNC_WINDOW

func _trigger_mega_pulse() -> void:
	# Mega pulse centered between both players
	var center: Vector3 = (_p1_pulse_pos + _p2_pulse_pos) * 0.5
	mega_pulse_triggered.emit(center)
	_coop_mega_pulses += 1
	GameManager.add_message("💫 CO-OP MEGA PULSE WAVE!")
	# Audio cue — mega pulse boom (co-op ultimate ability)
	AudioManager.play_sfx(AudioManager.SFX_PULSE_WAVE)
	AudioManager.play_sfx(AudioManager.SFX_EXPLOSION)
	# Particle spectacle
	if GameManager.player and is_instance_valid(GameManager.player):
		ParticleEffects.spawn_boss_death_spectacle(GameManager.player.get_parent(), center, Color(1.0, 0.6, 1.0))
	# Spawn actual mega pulse wave (larger radius + more damage)
	var PULSE_WAVE_SCENE := preload("res://scenes/entities/pulse_wave.tscn")
	var world: Node3D = GameManager.player.get_parent()
	if world:
		# Spawn multiple overlapping pulse waves for a bigger visual
		for i in range(3):
			var pulse: Node3D = PULSE_WAVE_SCENE.instantiate()
			world.add_child(pulse)
			pulse.global_position = center + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
			# Scale up the pulse wave for mega effect
			if pulse.has_method("set_mega_params"):
				pulse.set_mega_params(
					GameConstants.PULSE_WAVE_RADIUS * GameConstants.COOP_PULSE_RADIUS_MULT,
					int(GameConstants.PULSE_WAVE_DAMAGE * GameConstants.COOP_PULSE_DAMAGE_MULT)
				)
		# Damage all enemies in mega radius
		var mega_radius: float = GameConstants.PULSE_WAVE_RADIUS * GameConstants.COOP_PULSE_RADIUS_MULT
		for enemy in GameManager.enemies:
			if not is_instance_valid(enemy):
				continue
			var d: float = center.distance_to(enemy.global_position)
			if d < mega_radius:
				if enemy.has_method("take_damage_from"):
					enemy.take_damage_from(
						int(GameConstants.PULSE_WAVE_DAMAGE * GameConstants.COOP_PULSE_DAMAGE_MULT),
						center
					)
				# Knockback away from center
				if enemy.has_method("apply_knockback"):
					var push_dir: Vector3 = (enemy.global_position - center).normalized()
					push_dir.y = 0
					enemy.apply_knockback(push_dir, GameConstants.KNOCKBACK_FORCE_EXPLOSION)
	# Camera shake
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.6)
	# ── Hit-stop on mega pulse ── A heavier freeze than the solo pulse wave
	# (90ms @ 0.12x) because the mega pulse is a rare, triumphant co-op
	# climax moment — the synced cast deserves a weightier beat than a solo
	# cast. Mirrors the boss-kill hit-stop duration (90ms) but with a gentler
	# time scale (0.12x vs 0.04x) so it reads as a dramatic pause, not a
	# stutter. Scheduled on the scene tree with ignore_time_scale=true so
	# the restore fires in real-time seconds. Restores to 1.0 because
	# DimensionSystem uses per-node _time_scale multipliers.
	Engine.time_scale = 0.12
	var restore_timer := get_tree().create_timer(0.09, true, false, true)
	restore_timer.timeout.connect(func(): Engine.time_scale = 1.0)
	# Clear pending
	_p1_pulse_pending = false
	_p2_pulse_pending = false
	_mega_pulse_window = 0.0
	_check_coop_milestones()

## If the sync window expires without both players firing, fire normal pulses.
func _fire_pending_normal_pulses() -> void:
	# The individual player scripts already fired their own pulse waves.
	# We just clear the pending state — the normal pulses already happened.
	_p1_pulse_pending = false
	_p2_pulse_pending = false

# ─── Revive System ───────────────────────────────────────────────────────────

## Called when P2's HP reaches 0 — enters downed state instead of dying.
func p2_enter_downed() -> void:
	if p2_is_downed:
		return
	p2_is_downed = true
	p2_downed_timer = GameConstants.COOP_DOWNED_TIMER_MAX
	p2_revive_progress = 0.0
	p2_downed.emit()
	GameManager.add_message("💔 %s is down! Get close and hold [.] to revive!" % GameConstants.P2_NAME)

## Called when P1's HP reaches 0 and P2 is active — P1 enters downed state.
## This is handled by GameManager._die() which checks CoOpManager.p2_active.
## This function is kept for compatibility but the main logic is in GameManager.
func p1_enter_downed() -> void:
	# P1 downed is handled by GameManager._die() directly
	pass

func _update_downed(delta: float) -> void:
	p2_downed_timer -= delta
	if p2_downed_timer <= 0:
		# Bleed out — P2 dies for real
		_p2_die_for_real()
		return

	# Check if P1 is close enough and holding revive key (E = trade action)
	if GameManager.player and is_instance_valid(GameManager.player) and GameManager.player_is_alive:
		if not p2_node or not is_instance_valid(p2_node):
			_p2_die_for_real()
			return
		var dist: float = GameManager.player.global_position.distance_to(p2_node.global_position)
		if dist <= GameConstants.COOP_REVIVE_RANGE and Input.is_action_pressed("trade"):
			p2_revive_progress += GameConstants.COOP_DOWNED_REVIVE_PROGRESS_TICK * 60.0 * delta
			revive_progress_changed.emit(p2_revive_progress)
			if p2_revive_progress >= 1.0:
				_revive_p2()
		else:
			# Decay progress when not reviving
			p2_revive_progress = max(0.0, p2_revive_progress - delta * 0.5)
			revive_progress_changed.emit(p2_revive_progress)

func _revive_p2() -> void:
	p2_is_downed = false
	p2_hp = GameConstants.COOP_REVIVE_HP_RESTORE
	p2_downed_timer = 0.0
	p2_revive_progress = 0.0
	_coop_revives += 1
	p2_revived.emit()
	p2_hp_changed.emit(p2_hp, p2_max_hp)
	revive_progress_changed.emit(0.0)
	# Phase 20: Audio — revive SFX
	AudioManager.play_sfx(AudioManager.SFX_REVIVE)
	GameManager.add_message("✨ %s revived! Back in action!" % GameConstants.P2_NAME)
	# Heal particles
	if p2_node and is_instance_valid(p2_node):
		ParticleEffects.spawn_levelup_burst(p2_node.get_parent(), p2_node.global_position)
	# Give invuln
	if p2_node and p2_node.has_method("set_invuln"):
		p2_node.set_invuln(GameConstants.COOP_REVIVE_INVULN_DURATION)
	_check_coop_milestones()
	# ── Phase 25: Statistics tracking — record revive ──
	if Statistics:
		Statistics.record_revive()

func _p2_die_for_real() -> void:
	p2_is_downed = false
	p2_died.emit()
	GameManager.add_message("☠ %s bled out..." % GameConstants.P2_NAME)
	if p2_node and is_instance_valid(p2_node):
		ParticleEffects.spawn_death_poof(p2_node.get_parent(), p2_node.global_position, GameConstants.P2_BASE_COLOR, 1.0)
		p2_node.queue_free()
	p2_node = null
	p2_active = false
	p2_left.emit()
	_check_coop_milestones()

## P1 revive is handled by GameManager._update_p1_downed() which checks
## if P2 is close and holding the p2_revive key (".").

# ─── P2 HP Management ────────────────────────────────────────────────────────

func p2_take_damage(amount: int, source_pos: Vector3 = Vector3.ZERO) -> void:
	if not p2_active or p2_is_downed:
		return
	# Apply mutation/pet shield reductions (same as P1)
	var actual: int = amount
	if MutationSystem:
		var reduction: float = MutationSystem.get_damage_reduction()
		if reduction > 0:
			actual = int(actual * (1.0 - reduction))
	# ── Phase 25: ProgressionSystem damage reduction (Energy Shield + Toughness) ──
	if ProgressionSystem:
		var prog_reduce: float = ProgressionSystem.get_damage_reduction()
		if prog_reduce > 0:
			actual = int(actual * (1.0 - prog_reduce))
	# ── Phase 29: EquipmentSystem damage reduction (armor + set bonuses + shield potion) ──
	if EquipmentSystem:
		var equip_reduce: float = EquipmentSystem.get_damage_reduction_bonus()
		if equip_reduce > 0:
			actual = int(actual * (1.0 - equip_reduce))
	# ── Phase 33: WorldModifierSystem — THIN_SKIN increases damage taken ──
	if WorldModifierSystem and WorldModifierSystem.is_initialized():
		var dmg_taken_mult: float = WorldModifierSystem.get_player_damage_taken_mult()
		if dmg_taken_mult != 1.0:
			actual = int(actual * dmg_taken_mult)
	# ── Phase 16: Reflective Shield weapon mod reduces incoming damage (shared mod) ──
	if WeaponModSystem and WeaponModSystem.get_equipped_mod() == GameConstants.WeaponMod.REFLECTIVE_SHIELD:
		actual = int(actual * 0.6)  # 40% damage reduction
	# ── Phase 24: Shield Bubble deployable absorbs damage (same as P1's path) ──
	if DeployableSystem and DeployableSystem.is_shield_bubble_active():
		actual = DeployableSystem.absorb_damage(actual)
		if actual <= 0:
			# Fully absorbed by the bubble — no damage to P2
			return
		# Apply the bubble's damage reduction to the remaining damage
		var bubble_reduction: float = DeployableSystem.get_shield_bubble_damage_reduction()
		if bubble_reduction > 0:
			actual = int(actual * (1.0 - bubble_reduction))
	# ── Phase 30: Damage SFX — P2 also gets the damage sound ──
	AudioManager.play_sfx(AudioManager.SFX_DAMAGE)
	p2_hp = max(0, p2_hp - actual)
	p2_hp_changed.emit(p2_hp, p2_max_hp)
	# ── Visual feedback: damage squash + emission flash on P2 mesh ──
	p2_damaged.emit(source_pos)
	# Camera shake
	var cam_rig: Node3D = GameManager.camera_rig
	if cam_rig and cam_rig.has_method("add_trauma"):
		cam_rig.add_trauma(0.3)
	if p2_hp <= 0:
		# ── Phase 32: PvP — P2 death triggers a round end ──
		if PvpArena and PvpArena.is_pvp_active():
			PvpArena.register_pvp_death(false)  # P2 died → P1 wins the round
			# Restore P2 HP for the next round instead of downing
			p2_hp = p2_max_hp
			p2_hp_changed.emit(p2_hp, p2_max_hp)
			return
		p2_enter_downed()

func p2_heal(amount: int) -> void:
	if not p2_active or p2_is_downed:
		return
	p2_hp = min(p2_max_hp, p2_hp + amount)
	p2_hp_changed.emit(p2_hp, p2_max_hp)
	# ── Visual feedback: heal pop + emission flash on P2 mesh ──
	p2_healed.emit(amount)

func p2_add_score(amount: int) -> void:
	if not p2_active:
		return
	p2_score += amount
	p2_score_changed.emit(p2_score)

# ─── Enemy Scaling ───────────────────────────────────────────────────────────

func get_enemy_hp_mult() -> float:
	return GameConstants.COOP_ENEMY_HP_MULT if p2_active else 1.0

func get_enemy_damage_mult() -> float:
	return GameConstants.COOP_ENEMY_DAMAGE_MULT if p2_active else 1.0

func get_spawn_rate_mult() -> float:
	return GameConstants.COOP_ENEMY_SPAWN_RATE_MULT if p2_active else 1.0

func get_max_enemies_bonus() -> int:
	return GameConstants.COOP_MAX_ENEMIES_BONUS if p2_active else 0

# ─── Camera Queries ──────────────────────────────────────────────────────────

## Returns true if co-op is active (camera should use dual-target mode).
func is_coop_active() -> bool:
	return p2_active and p2_node and is_instance_valid(p2_node)

## Returns the midpoint between both players for camera targeting.
func get_camera_target_midpoint() -> Vector3:
	if not is_coop_active():
		return Vector3.ZERO
	var p1: Vector3 = GameManager.player.global_position if (GameManager.player and is_instance_valid(GameManager.player)) else Vector3.ZERO
	var p2: Vector3 = p2_node.global_position
	return (p1 + p2) * 0.5

## Returns the distance between the two players (for camera zoom).
func get_player_spacing() -> float:
	if not is_coop_active():
		return 0.0
	if not GameManager.player or not is_instance_valid(GameManager.player):
		return 0.0
	return GameManager.player.global_position.distance_to(p2_node.global_position)

# ─── Co-op Achievements ──────────────────────────────────────────────────────

const MILESTONE_FIRST_COOP_KILL: int = 0
const MILESTONE_50_COOP_KILLS: int = 1
const MILESTONE_FIRST_REVIVE: int = 2
const MILESTONE_5_REVIVES: int = 3
const MILESTONE_FIRST_MEGA_PULSE: int = 4
const MILESTONE_3_MEGA_PULSES: int = 5
const MILESTONE_COOP_SURVIVOR: int = 6  # Survive 5 min in co-op

func _check_coop_milestones() -> void:
	if _coop_kills >= 1 and not _coop_milestones_unlocked.has(MILESTONE_FIRST_COOP_KILL):
		_unlock_milestone(MILESTONE_FIRST_COOP_KILL, "First Co-op Kill!")
	if _coop_kills >= 50 and not _coop_milestones_unlocked.has(MILESTONE_50_COOP_KILLS):
		_unlock_milestone(MILESTONE_50_COOP_KILLS, "Dynamic Duo — 50 co-op kills!")
	if _coop_revives >= 1 and not _coop_milestones_unlocked.has(MILESTONE_FIRST_REVIVE):
		_unlock_milestone(MILESTONE_FIRST_REVIVE, "Guardian Angel — first revive!")
	if _coop_revives >= 5 and not _coop_milestones_unlocked.has(MILESTONE_5_REVIVES):
		_unlock_milestone(MILESTONE_5_REVIVES, "Field Medic — 5 revives!")
	if _coop_mega_pulses >= 1 and not _coop_milestones_unlocked.has(MILESTONE_FIRST_MEGA_PULSE):
		_unlock_milestone(MILESTONE_FIRST_MEGA_PULSE, "Pulse Brothers — first mega pulse!")
	if _coop_mega_pulses >= 3 and not _coop_milestones_unlocked.has(MILESTONE_3_MEGA_PULSES):
		_unlock_milestone(MILESTONE_3_MEGA_PULSES, "Wave Force — 3 mega pulses!")

func _unlock_milestone(id: int, desc: String) -> void:
	_coop_milestones_unlocked[id] = true
	co_op_milestone.emit(id, desc)
	GameManager.add_message("🏆 CO-OP: %s" % desc)

# ─── Reset (on game restart) ─────────────────────────────────────────────────

func reset() -> void:
	force_remove_p2()
	_coop_kills = 0
	_coop_revives = 0
	_coop_mega_pulses = 0
	_coop_milestones_unlocked.clear()
	_drop_out_hold_timer = 0.0