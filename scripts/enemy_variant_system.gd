## Zorp Wiggles — Enemy Variant System (Phase 33: Procedural Content)
##
## Procedurally generates elite/golden/champion variants of regular enemies with
## random modifiers. Each variant gets 1-3 random "traits" drawn from a pool of
## ~12 traits (fast, tanky, exploding, regenerating, shielded, lifesteal, etc.).
## Variants are visually distinct (color tint, size, glow) and drop better loot.
##
## The system is queried by EnemySpawner._materialize_enemy() after a standard
## enemy is created. If the roll succeeds (chance from WorldModifierSystem's
## CHAMPION_ENEMIES modifier, or a small base chance), the enemy is promoted to
## a variant via apply_variant().
##
## Variants store their traits as metadata on the enemy node ("variant_traits",
## "variant_tier", "variant_color_override") so other systems can query them.
## The enemy_base.gd material/scale is updated, and a death hook grants bonus
## XP/score/loot when the variant dies.
extends Node

# ─── Signals ──────────────────────────────────────────────────────────────────
signal variant_spawned(enemy: Node, tier: int, traits: Array)
signal variant_defeated(enemy: Node, tier: int, traits: Array)

# ─── Variant Tiers ────────────────────────────────────────────────────────────
enum Tier {
	NONE,       # Not a variant — regular enemy
	ELITE,      # 1 trait, 1.5× HP, 1.2× damage, slight visual tint
	GOLDEN,     # 2 traits, 2.0× HP, 1.4× damage, golden glow, 3× loot
	CHAMPION,   # 3 traits, 3.0× HP, 1.6× damage, big size, 5× loot, guaranteed rare drop
}

const TIER_NAMES: Array[String] = ["None", "Elite", "Golden", "Champion"]
const TIER_COLORS: Array[Color] = [
	Color(0.6, 0.6, 0.6),
	Color(0.4, 0.8, 1.0),    # Elite — cyan
	Color(1.0, 0.85, 0.2),   # Golden — gold
	Color(1.0, 0.3, 0.8),    # Champion — magenta
]
const TIER_SCALE_MULT: Array[float] = [1.0, 1.15, 1.3, 1.5]
const TIER_HP_MULT: Array[float] = [1.0, 1.5, 2.0, 3.0]
const TIER_DAMAGE_MULT: Array[float] = [1.0, 1.2, 1.4, 1.6]
const TIER_XP_MULT: Array[float] = [1.0, 2.0, 3.5, 6.0]
const TIER_SCORE_MULT: Array[float] = [1.0, 2.0, 4.0, 8.0]
const TIER_LOOT_MULT: Array[float] = [1.0, 1.5, 3.0, 5.0]
const TIER_GLOW_ENERGY: Array[float] = [0.0, 1.2, 2.5, 4.0]

# ─── Variant Traits ───────────────────────────────────────────────────────────
enum Trait {
	NONE,
	SWIFT,         # +50% move speed
	TANKY,         # +50% HP (stacks with tier HP mult)
	BERSERKER,     # +30% damage at <50% HP
	REGENERATING,  # regen 2 HP/sec
	EXPLODING,     # explodes on death (3m radius, 25 dmg)
	SHIELDED,      # 20% damage reduction
	LIFESTEAL,     # heals 3 HP on hit
	TELEPORTING,   # teleports every 4s toward player
	VENOMOUS,      # applies a slow on hit (0.6× player speed for 2s)
	KNOCKBACK_IMMUNE,  # immune to knockback
	EVASIVE,        # 25% chance to dodge incoming damage
	GIANT,          # +30% scale (stacks with tier scale)
}

const TRAIT_NAMES: Array[String] = [
	"None", "Swift", "Tanky", "Berserker", "Regenerating", "Exploding",
	"Shielded", "Lifesteal", "Teleporting", "Venomous", "Knockback-Immune",
	"Evasive", "Giant",
]

const TRAIT_COLORS: Array[Color] = [
	Color(0.6, 0.6, 0.6),
	Color(0.3, 0.9, 1.0),    # Swift — cyan
	Color(0.7, 0.7, 0.8),    # Tanky — steel
	Color(1.0, 0.3, 0.3),    # Berserker — red
	Color(0.3, 1.0, 0.4),    # Regenerating — green
	Color(1.0, 0.5, 0.1),    # Exploding — orange
	Color(0.4, 0.6, 1.0),    # Shielded — blue
	Color(0.9, 0.2, 0.4),    # Lifesteal — crimson
	Color(0.6, 0.4, 1.0),    # Teleporting — purple
	Color(0.4, 0.9, 0.3),    # Venomous — toxic green
	Color(0.8, 0.7, 0.4),    # Knockback-Immune — bronze
	Color(0.9, 0.9, 0.9),    # Evasive — white
	Color(0.9, 0.6, 0.9),    # Giant — pink
]

# ─── Tuning ───────────────────────────────────────────────────────────────────
const BASE_VARIANT_CHANCE: float = 0.05  # 5% base chance without CHAMPION_ENEMIES modifier
const TRAITS_PER_TIER: Array[int] = [0, 1, 2, 3]  # Number of traits by tier
# Tier roll weights (when a variant IS rolled, what tier is it?)
const TIER_WEIGHTS: Array[float] = [0.0, 5.0, 2.0, 0.5]  # Elite common, Champion rare

# ─── State ────────────────────────────────────────────────────────────────────
var _variant_count: int = 0  # Total variants spawned this run (for stats)

# Per-enemy tick state (stored on the enemy node via set_meta)
const META_TRAITS := "variant_traits"
const META_TIER := "variant_tier"
const META_ORIGINAL_HP := "variant_original_hp"
const META_ORIGINAL_MAX_HP := "variant_original_max_hp"
const META_ORIGINAL_SPEED := "variant_original_speed"
const META_ORIGINAL_DAMAGE := "variant_original_damage"
const META_ORIGINAL_SCALE := "variant_original_scale"
const META_ORIGINAL_COLOR := "variant_original_color"
const META_ORIGINAL_XP := "variant_original_xp"
const META_ORIGINAL_SCORE := "variant_original_score"
const META_REGEN_ACCUMULATOR := "variant_regen_accumulator"
const META_TELEPORT_TIMER := "variant_teleport_timer"
const META_VENOM_TIMER := "variant_venom_timer"
const META_EVASIVE_DODGE_CHANCE := "variant_evasive_dodge_chance"

# ─── Public API ────────────────────────────────────────────────────────────────

func _ready() -> void:
	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)
		GameManager.player_died.connect(_on_player_died)

# Roll whether a newly-spawned enemy should be promoted to a variant.
# Called by EnemySpawner._materialize_enemy() after the enemy is created.
# Returns true if the enemy was promoted (and traits were applied).
func try_promote_enemy(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false
	if not (enemy is EnemyBase):
		return false
	# Don't promote bosses — they're already special
	var eb: EnemyBase = enemy as EnemyBase
	if eb.is_arena_boss or eb.is_world_boss:
		return false
	if eb.base_scale >= 2.0 or eb.max_hp >= 200:
		return false  # Skip boss-tier enemies
	# Determine chance
	var chance: float = BASE_VARIANT_CHANCE
	if WorldModifierSystem and WorldModifierSystem.is_initialized():
		chance = maxf(chance, WorldModifierSystem.get_champion_chance())
	if chance <= 0.0:
		return false
	if randf() > chance:
		return false
	# Roll the tier
	var tier: int = _roll_tier()
	if tier == Tier.NONE:
		return false
	# Roll traits
	var trait_count: int = TRAITS_PER_TIER[tier]
	var traits: Array[int] = _roll_traits(trait_count)
	# Apply the variant
	_apply_variant(enemy, tier, traits)
	_variant_count += 1
	variant_spawned.emit(enemy, tier, traits)
	return true

func _roll_tier() -> int:
	var total: float = 0.0
	for w in TIER_WEIGHTS:
		total += w
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for i in range(TIER_WEIGHTS.size()):
		cumulative += TIER_WEIGHTS[i]
		if roll <= cumulative:
			return i
	return Tier.ELITE

func _roll_traits(count: int) -> Array[int]:
	if count <= 0:
		return []
	var pool: Array[int] = []
	for i in range(1, TRAIT_NAMES.size()):
		pool.append(i)
	var picked: Array[int] = []
	for _i in range(count):
		if pool.is_empty():
			break
		var idx: int = randi() % pool.size()
		picked.append(pool[idx])
		pool.remove_at(idx)
	return picked

# Apply a variant tier + traits to an enemy. Modifies HP, damage, speed, scale,
# color, XP, score, and stores trait metadata for per-frame ticking.
func _apply_variant(enemy: Node, tier: int, traits: Array[int]) -> void:
	var eb: EnemyBase = enemy as EnemyBase
	# Store originals (for restoration / death bonus calc)
	enemy.set_meta(META_TRAITS, traits)
	enemy.set_meta(META_TIER, tier)
	enemy.set_meta(META_ORIGINAL_HP, eb.hp)
	enemy.set_meta(META_ORIGINAL_MAX_HP, eb.max_hp)
	enemy.set_meta(META_ORIGINAL_SPEED, eb.speed)
	enemy.set_meta(META_ORIGINAL_DAMAGE, eb.damage)
	enemy.set_meta(META_ORIGINAL_SCALE, eb.base_scale)
	enemy.set_meta(META_ORIGINAL_COLOR, eb.base_color)
	enemy.set_meta(META_ORIGINAL_XP, eb.xp_reward)
	enemy.set_meta(META_ORIGINAL_SCORE, eb.score_reward)
	enemy.set_meta(META_REGEN_ACCUMULATOR, 0.0)
	enemy.set_meta(META_TELEPORT_TIMER, 4.0)
	enemy.set_meta(META_VENOM_TIMER, 0.0)
	# Apply tier multipliers
	var hp_mult: float = TIER_HP_MULT[tier]
	var dmg_mult: float = TIER_DAMAGE_MULT[tier]
	var scale_mult: float = TIER_SCALE_MULT[tier]
	var xp_mult: float = TIER_XP_MULT[tier]
	var score_mult: float = TIER_SCORE_MULT[tier]
	# Apply trait multipliers (stack with tier)
	for t in traits:
		match t:
			Trait.TANKY:
				hp_mult *= 1.5
			Trait.SWIFT:
				eb.speed *= 1.5
			Trait.GIANT:
				scale_mult *= 1.3
			Trait.EVASIVE:
				enemy.set_meta(META_EVASIVE_DODGE_CHANCE, 0.25)
	# Apply HP
	eb.max_hp = int(eb.max_hp * hp_mult)
	eb.hp = eb.max_hp
	# Apply damage
	eb.damage = int(eb.damage * dmg_mult)
	# Apply scale (also updates base_scale so separation radius scales)
	eb.base_scale = eb.base_scale * scale_mult
	# Apply XP and score
	eb.xp_reward = int(eb.xp_reward * xp_mult)
	eb.score_reward = int(eb.score_reward * score_mult)
	# Apply visual: blend tier color into base color
	var tier_color: Color = TIER_COLORS[tier]
	eb.base_color = eb.base_color.lerp(tier_color, 0.45)
	eb.current_color = eb.base_color
	# Update the material if it exists
	if eb._material:
		eb._material.albedo_color = eb.base_color
		eb._material.emission = eb.base_color * 0.25
		eb._material.emission_energy_multiplier = 1.0 + TIER_GLOW_ENERGY[tier]
		eb._material.rim = 0.8
		eb._material.rim_tint = 1.0
	# Update the enemy's name to include the tier prefix
	var tier_prefix: String = "[%s] " % TIER_NAMES[tier].to_upper()
	eb.enemy_name = tier_prefix + eb.enemy_name
	# Apply scale tween (smoothly grow to new size)
	if eb.body_mesh:
		var scale_tween := eb.create_tween()
		scale_tween.tween_property(eb, "scale",
			Vector3.ONE * eb.base_scale, 0.4) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Spawn a materialization burst to telegraph the variant
	ParticleEffects.spawn_materialization(eb.get_parent(), eb.global_position, tier_color)
	# Spawn a glow light for golden/champion tiers
	if tier >= Tier.GOLDEN:
		_spawn_variant_glow(eb, tier)

func _spawn_variant_glow(eb: EnemyBase, tier: int) -> void:
	var light := OmniLight3D.new()
	light.light_color = TIER_COLORS[tier]
	light.light_energy = TIER_GLOW_ENERGY[tier]
	light.omni_range = 6.0 + tier * 2.0
	light.omni_attenuation = 1.2
	# Parent to the enemy so it follows
	eb.add_child(light)
	# Pulse the light via tween
	var pulse_tween := eb.create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(light, "light_energy",
		TIER_GLOW_ENERGY[tier] * 0.6, 0.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(light, "light_energy",
		TIER_GLOW_ENERGY[tier] * 1.3, 0.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

# ─── Per-Frame Update ─────────────────────────────────────────────────────────
# Called by GameManager._process() to tick variant traits on all enemies.
func update(delta: float) -> void:
	if GameManager.is_paused or not GameManager.player_is_alive:
		return
	for enemy in GameManager.enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_meta(META_TIER):
			continue
		_tick_variant(enemy, delta)

func _tick_variant(enemy: Node, delta: float) -> void:
	var eb: EnemyBase = enemy as EnemyBase
	if eb == null or eb.is_dead:
		return
	var traits: Array = enemy.get_meta(META_TRAITS, [])
	for t in traits:
		match t:
			Trait.REGENERATING:
				_tick_regen(enemy, eb, delta)
			Trait.TELEPORTING:
				_tick_teleport(enemy, eb, delta)
			Trait.BERSERKER:
				_tick_berserker(enemy, eb)
			Trait.VENOMOUS:
				_tick_venom(enemy, eb, delta)

func _tick_regen(enemy: Node, eb: EnemyBase, delta: float) -> void:
	if eb.hp >= eb.max_hp:
		return
	var acc: float = enemy.get_meta(META_REGEN_ACCUMULATOR, 0.0)
	acc += 2.0 * delta
	while acc >= 1.0:
		acc -= 1.0
		eb.hp = min(eb.max_hp, eb.hp + 1)
	enemy.set_meta(META_REGEN_ACCUMULATOR, acc)

func _tick_teleport(enemy: Node, eb: EnemyBase, delta: float) -> void:
	var timer: float = enemy.get_meta(META_TELEPORT_TIMER, 4.0)
	timer -= delta
	if timer <= 0.0:
		enemy.set_meta(META_TELEPORT_TIMER, 4.0)
		# Teleport toward the player (closer)
		var player: Node3D = GameManager.player
		if not player or not is_instance_valid(player):
			return
		var dir: Vector3 = (player.global_position - eb.global_position).normalized()
		var new_pos: Vector3 = player.global_position - dir * 6.0
		new_pos.y = eb.global_position.y
		# Particle burst at old and new positions
		ParticleEffects.spawn_materialization(eb.get_parent(), eb.global_position, Color(0.6, 0.4, 1.0))
		eb.global_position = new_pos
		ParticleEffects.spawn_materialization(eb.get_parent(), eb.global_position, Color(0.6, 0.4, 1.0))
	else:
		enemy.set_meta(META_TELEPORT_TIMER, timer)

func _tick_berserker(enemy: Node, eb: EnemyBase) -> void:
	# Dynamically boost damage when below 50% HP
	var original_dmg: int = int(enemy.get_meta(META_ORIGINAL_DAMAGE, eb.damage))
	var hp_fraction: float = float(eb.hp) / float(eb.max_hp) if eb.max_hp > 0 else 1.0
	if hp_fraction < 0.5:
		eb.damage = int(original_dmg * TIER_DAMAGE_MULT[enemy.get_meta(META_TIER, 1)] * 1.3)
	else:
		eb.damage = int(original_dmg * TIER_DAMAGE_MULT[enemy.get_meta(META_TIER, 1)])

func _tick_venom(enemy: Node, eb: EnemyBase, delta: float) -> void:
	# Decay the venom-on-hit timer (the actual slow application happens on hit
	# via on_player_hit()). This timer tracks how long the slow lasts after
	# the most recent hit.
	var timer: float = enemy.get_meta(META_VENOM_TIMER, 0.0)
	if timer > 0.0:
		timer = maxf(0.0, timer - delta)
		enemy.set_meta(META_VENOM_TIMER, timer)

# ─── Hit Hooks (called by enemy_base.gd) ──────────────────────────────────────

# Called by enemy_base.gd when the enemy deals damage to the player. Returns
# the (possibly modified) damage and applies trait effects.
func on_player_hit(enemy: Node, player: Node3D) -> int:
	if not is_instance_valid(enemy) or not enemy.has_meta(META_TIER):
		return -1  # Not a variant — no modification
	var eb: EnemyBase = enemy as EnemyBase
	var traits: Array = enemy.get_meta(META_TRAITS, [])
	var damage: int = eb.damage
	# Lifesteal — enemy heals on hit
	if Trait.LIFESTEAL in traits:
		eb.hp = min(eb.max_hp, eb.hp + 3)
	# Venomous — apply a slow to the player (we set a meta the player reads)
	if Trait.VENOMOUS in traits:
		player.set_meta("venom_slow_timer", 2.0)
		enemy.set_meta(META_VENOM_TIMER, 2.0)
	return damage

# Called by enemy_base.gd take_damage_from() before applying damage. Returns
# the modified damage (after shield/evasive reductions) and true if the hit
# was dodged (in which case damage is 0 and the hit should be skipped).
func on_enemy_take_damage(enemy: Node, amount: int) -> Dictionary:
	if not is_instance_valid(enemy) or not enemy.has_meta(META_TIER):
		return {"damage": amount, "dodged": false}
	var traits: Array = enemy.get_meta(META_TRAITS, [])
	# Evasive — chance to dodge
	if Trait.EVASIVE in traits:
		var dodge_chance: float = enemy.get_meta(META_EVASIVE_DODGE_CHANCE, 0.0)
		if dodge_chance > 0.0 and randf() < dodge_chance:
			return {"damage": 0, "dodged": true}
	# Shielded — 20% damage reduction
	var actual: int = amount
	if Trait.SHIELDED in traits:
		actual = int(actual * 0.8)
	return {"damage": actual, "dodged": false}

# Called by enemy_base.gd when the enemy is about to be knocked back. Returns
# true if the knockback should be cancelled (Knockback-Immune trait).
func should_cancel_knockback(enemy: Node) -> bool:
	if not is_instance_valid(enemy) or not enemy.has_meta(META_TIER):
		return false
	var traits: Array = enemy.get_meta(META_TRAITS, [])
	return Trait.KNOCKBACK_IMMUNE in traits

# Called by enemy_base.gd when the variant dies. Grants bonus loot/XP and
# triggers the Exploding trait.
func on_variant_death(enemy: Node) -> void:
	if not is_instance_valid(enemy) or not enemy.has_meta(META_TIER):
		return
	var tier: int = enemy.get_meta(META_TIER, Tier.NONE)
	var traits: Array = enemy.get_meta(META_TRAITS, [])
	var eb: EnemyBase = enemy as EnemyBase
	# Exploding trait — AoE explosion on death
	if Trait.EXPLODING in traits and eb:
		_spawn_death_explosion(eb)
	# Bonus loot drop — champions get a guaranteed rare material
	if tier >= Tier.CHAMPION and eb:
		# Drop an extra collectible (rare)
		_spawn_bonus_loot(eb, tier)
	# Statistics tracking
	if Statistics and Statistics.has_method("set_lifetime_max"):
		var current: int = int(Statistics.get_lifetime_stat("variant_kills"))
		Statistics.set_lifetime_max("variant_kills", current + 1)
	variant_defeated.emit(enemy, tier, traits)

func _spawn_death_explosion(eb: EnemyBase) -> void:
	# Visual + damage AoE
	ParticleEffects.spawn_mega_explosion(eb.get_parent(), eb.global_position, Color(1.0, 0.5, 0.1))
	# Damage the player if within 3m
	var player: Node3D = GameManager.player
	if player and is_instance_valid(player):
		if eb.global_position.distance_to(player.global_position) < 3.0:
			GameManager.take_damage(25, eb.global_position)
	# Camera shake
	if GameManager.camera_rig and GameManager.camera_rig.has_method("add_trauma"):
		GameManager.camera_rig.add_trauma(0.35)

func _spawn_bonus_loot(eb: EnemyBase, tier: int) -> void:
	# Drop 1-2 extra collectibles (rare crafting materials as physical drops)
	var drop_count: int = 1 if tier == Tier.CHAMPION else 2
	var collectible_scene: PackedScene = load("res://scenes/entities/collectible.tscn")
	if not collectible_scene:
		return
	# Pick a rare-ish collectible type
	var rare_types: Array[int] = [
		GameConstants.CollectibleType.METEOR_SHARD,
		GameConstants.CollectibleType.QUANTUM_FUZZ,
		GameConstants.CollectibleType.NEBULA_DUST,
		GameConstants.CollectibleType.STAR_FRUIT,
	]
	for i in range(drop_count):
		var drop: Area3D = collectible_scene.instantiate()
		eb.get_parent().add_child(drop)
		drop.global_position = eb.global_position + Vector3(
			randf_range(-1.5, 1.5), 0.5, randf_range(-1.5, 1.5)
		)
		var drop_type: int = rare_types[randi() % rare_types.size()]
		if drop.has_method("set_type"):
			drop.set_type(drop_type)
		if drop.has_method("start_tumble"):
			drop.start_tumble(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized())
		GameManager.collectibles.append(drop)
		if not drop.is_in_group("collectibles"):
			drop.add_to_group("collectibles")

# ─── Query API ────────────────────────────────────────────────────────────────

func is_variant(enemy: Node) -> bool:
	return is_instance_valid(enemy) and enemy.has_meta(META_TIER)

func get_variant_tier(enemy: Node) -> int:
	if not is_variant(enemy):
		return Tier.NONE
	return enemy.get_meta(META_TIER, Tier.NONE)

func get_variant_traits(enemy: Node) -> Array:
	if not is_variant(enemy):
		return []
	return enemy.get_meta(META_TRAITS, [])

func get_variant_loot_mult(enemy: Node) -> float:
	if not is_variant(enemy):
		return 1.0
	var tier: int = enemy.get_meta(META_TIER, Tier.NONE)
	return TIER_LOOT_MULT[tier]

func get_variant_count() -> int:
	return _variant_count

func get_trait_name(t_id: int) -> String:
	if t_id < 0 or t_id >= TRAIT_NAMES.size():
		return "Unknown"
	return TRAIT_NAMES[t_id]

func get_trait_color(t_id: int) -> Color:
	if t_id < 0 or t_id >= TRAIT_COLORS.size():
		return Color(0.6, 0.6, 0.6)
	return TRAIT_COLORS[t_id]

func get_tier_name(tier: int) -> String:
	if tier < 0 or tier >= TIER_NAMES.size():
		return "Unknown"
	return TIER_NAMES[tier]

func get_tier_color(tier: int) -> Color:
	if tier < 0 or tier >= TIER_COLORS.size():
		return Color(0.6, 0.6, 0.6)
	return TIER_COLORS[tier]

# ─── Signal Handlers ───────────────────────────────────────────────────────────

func _on_game_restarted() -> void:
	_variant_count = 0

func _on_player_died() -> void:
	pass  # Variants persist on the death screen