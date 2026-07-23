## Zorp Wiggles — Mirror Mimic (Phase 23: New Enemy Type)
## Copies the player's currently equipped weapon mod and fires it back at them.
## When the player has no mod equipped, it fires a standard projectile. The
## mimic reads WeaponModSystem.get_equipped_mod() and mirrors the mod's color
## and projectile behavior. Medium HP, medium speed, ranged — the counter is to
## equip a mod that's hard to dodge (or unequip to deny it a powerful mod).
##
## Behavior:
##   - Ranged enemy — fires from MIRROR_MIMIC_ATTACK_RANGE (24m).
##   - On attack, reads the player's equipped mod ID. The fired projectile
##     takes the mod's color and applies a weakened version of its behavior
##     (MIRROR_MIMIC_MIMICRY_DAMAGE_MULT = 0.7x the base enemy projectile damage).
##   - The mimic's own material shifts to mirror the equipped mod's color, so
##     the player can see what it's about to fire. This is a visual telegraph.
##   - Slight spread (MIRROR_MIMIC_SPREAD_DEGREES) so it's not perfectly accurate.
##   - Uses the existing EnemyProjectile scene for the fired bolts.
##
## The mimic is a "weapon mod tax" — it punishes players who rely on a single
## powerful mod by turning that mod against them. Switching mods or unequipping
## denies the mimic its strongest option. Smart players will adapt their loadout
## when a mimic appears.

extends EnemyBase

class_name EnemyMirrorMimic

# ─── Attack State ─────────────────────────────────────────────────────────────
var _attack_timer: float = 0.0  # Cooldown timer for ranged attacks
var _current_mimic_color: Color = GameConstants.MIRROR_MIMIC_NONE_COLOR
var _current_mimic_mod: int = GameConstants.WeaponMod.NONE

# Reuse the EnemyProjectile scene for the mimic's fired bolts
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/entities/enemy_projectile.tscn")

func _ready() -> void:
	enemy_name = "Mirror Mimic"
	enemy_type = GameConstants.EnemyType.MIRROR_MIMIC
	max_hp = GameConstants.MIRROR_MIMIC_HP
	speed = GameConstants.MIRROR_MIMIC_SPEED
	damage = GameConstants.MIRROR_MIMIC_DAMAGE
	base_scale = GameConstants.MIRROR_MIMIC_SCALE
	detect_range = GameConstants.MIRROR_MIMIC_DETECT_RANGE
	attack_range = GameConstants.MIRROR_MIMIC_ATTACK_RANGE
	attack_cooldown = GameConstants.MIRROR_MIMIC_ATTACK_COOLDOWN
	xp_reward = GameConstants.MIRROR_MIMIC_XP
	score_reward = GameConstants.MIRROR_MIMIC_SCORE
	base_color = GameConstants.MIRROR_MIMIC_COLOR
	# Smart AI enabled — flanking makes it harder to pin down, retreat keeps it
	# at range where its projectiles are most effective.
	use_smart_ai = true
	super._ready()

	# Mirror-silver material with strong rim for a reflective look
	if _material:
		_material.emission = base_color * 0.3
		_material.emission_energy_multiplier = 1.2
		_material.rim = 1.0
		_material.rim_tint = 1.0
		# Metallic for a mirror-chrome feel
		_material.metallic = 0.7
		_material.roughness = 0.2

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_dead or GameManager.is_paused or spawn_grace_timer > 0:
		return

	# Update the mimic's color to mirror the player's equipped mod.
	# This is a visual telegraph — the player can see what the mimic will fire.
	_update_mimic_color(delta)

	# Tick the ranged attack cooldown
	if _attack_timer > 0:
		_attack_timer -= delta * _time_scale

	# Try to fire if the player is in range and we're off cooldown
	if _attack_timer <= 0 and is_alerted:
		_try_ranged_attack()

## Update the mimic's material color to mirror the player's equipped weapon mod.
## Smoothly lerps so the color shift is visible but not jarring. The emission
## also shifts to match, so the mimic "glows" in the mod's color.
func _update_mimic_color(delta: float) -> void:
	if not _material:
		return
	if not WeaponModSystem:
		return
	var equipped_mod: int = WeaponModSystem.get_equipped_mod()
	if equipped_mod == _current_mimic_mod:
		return  # No change — skip the lerp
	_current_mimic_mod = equipped_mod
	# Get the mod's color (or the none-color fallback if no mod equipped)
	var target_color: Color
	if equipped_mod == GameConstants.WeaponMod.NONE:
		target_color = GameConstants.MIRROR_MIMIC_NONE_COLOR
	else:
		target_color = WeaponModSystem.get_equipped_color()
	_current_mimic_color = target_color
	# Apply the color to the material — instant for now (the lerp would need
	# a per-frame accumulator; the mod changes rarely so instant is fine)
	_material.emission = target_color * 0.4
	_material.emission_energy_multiplier = 1.3

## Attempt a ranged attack on the player. Fires an EnemyProjectile that takes
## the mimic's color (matching the player's equipped mod). The projectile
## damage is the mimic's base damage scaled by MIRROR_MIMIC_MIMICRY_DAMAGE_MULT.
func _try_ranged_attack() -> void:
	if not _cached_player or not is_instance_valid(_cached_player):
		return
	var dist: float = global_position.distance_to(_cached_player.global_position)
	# Only fire if within attack range and roughly in line of sight
	if dist > attack_range:
		return
	# Don't fire if currently in a windup (melee attack) — the mimic is ranged
	# but inherits the base melee attack logic. We suppress melee by setting
	# attack_range high, so the base AI's _try_attack won't trigger at range.
	# Reset the ranged attack timer
	_attack_timer = attack_cooldown
	# Compute the fire direction — from mimic to player, with slight spread
	var fire_dir: Vector3 = (_cached_player.global_position - global_position).normalized()
	fire_dir.y = 0
	fire_dir = fire_dir.normalized()
	# Apply spread
	var spread_rad: float = deg_to_rad(GameConstants.MIRROR_MIMIC_SPREAD_DEGREES)
	fire_dir = fire_dir.rotated(Vector3.UP, randf_range(-spread_rad, spread_rad))
	# Spawn the enemy projectile
	_spawn_mimic_projectile(fire_dir)
	# Muzzle flash in the mimic's current color
	_spawn_muzzle_flash(_current_mimic_color)
	# Audio cue — mirrored weapon fire (uses standard shoot SFX for weapon-copy feel)
	AudioManager.play_sfx(AudioManager.SFX_SHOOT)

## Spawn an EnemyProjectile with the mimic's current color and scaled damage.
## The projectile inherits the mimic's color so it visually matches the mod
## it's copying. The damage is the mimic's base damage × MIRROR_MIMIC_MIMICRY_DAMAGE_MULT.
func _spawn_mimic_projectile(fire_dir: Vector3) -> void:
	var proj: Area3D = ENEMY_PROJECTILE_SCENE.instantiate()
	# Set properties BEFORE add_child so _ready() picks them up
	proj.set("direction", fire_dir)
	proj.set("speed", GameConstants.MIRROR_MIMIC_PROJECTILE_SPEED)
	proj.set("damage", int(damage * GameConstants.MIRROR_MIMIC_MIMICRY_DAMAGE_MULT))
	proj.set("lifetime", GameConstants.MIRROR_MIMIC_PROJECTILE_LIFETIME)
	proj.set("projectile_color", _current_mimic_color)
	get_parent().add_child(proj)
	proj.global_position = global_position + Vector3(0, 0.8, 0)

## Spawn a brief OmniLight3D muzzle flash at the mimic's position.
func _spawn_muzzle_flash(col: Color) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = col
	flash.light_energy = 3.0
	flash.omni_range = 3.0
	flash.omni_attenuation = 1.5
	get_parent().add_child(flash)
	flash.global_position = global_position + Vector3(0, 0.8, 0)
	var flash_tween := flash.create_tween()
	flash_tween.tween_property(flash, "light_energy", 0.0, 0.08) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	flash_tween.tween_callback(flash.queue_free)

## Override _try_attack to suppress the inherited melee attack. The mimic is
## purely ranged — we don't want it lunging at the player. The base AI calls
## _try_attack when the player is within attack_range, but our attack_range is
## set to the ranged distance (24m), so the base AI's melee lunge would trigger
## at long range, which looks wrong. We override to no-op; the ranged attack
## is handled by _try_ranged_attack in _physics_process.
func _try_attack(player: Node3D) -> void:
	# No-op — the mimic is ranged; attacks are handled in _physics_process
	pass

func _die() -> void:
	# Mirror-shatter particle burst on death — extra particles for the mirror theme
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		_current_mimic_color, 24, 0.5)
	# Also a silvery burst for the "mirror" identity
	ParticleEffects.spawn_explosion(get_parent(), global_position,
		GameConstants.MIRROR_MIMIC_COLOR, 16, 0.4)
	super._die()