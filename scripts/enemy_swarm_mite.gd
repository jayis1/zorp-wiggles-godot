## Zorp Wiggles — Swarm Mite (Enhancement: New Enemy Type)
## Tiny, very fast, very low HP enemy that spawns in packs.
## Individually weak but they overwhelm from multiple directions.
## Designed to create pressure by numbers — a single shot kills them,
## but a pack of 6 rushing from different angles is a real threat.
##
## Behavior: No special attacks — just rushes the player at high speed.
## The danger comes from quantity, not quality. Dies in 1-2 hits.

extends EnemyBase

class_name EnemySwarmMite

func _ready() -> void:
	enemy_name = "Swarm Mite"
	enemy_type = GameConstants.EnemyType.SWARM_MITE
	max_hp = GameConstants.SWARM_MITE_HP
	speed = GameConstants.SWARM_MITE_SPEED
	damage = GameConstants.SWARM_MITE_DAMAGE
	base_scale = GameConstants.SWARM_MITE_SCALE
	detect_range = 28.0
	attack_range = 1.2  # Melee range — they bite
	attack_cooldown = 0.6  # Fast attacks
	xp_reward = GameConstants.SWARM_MITE_XP
	score_reward = GameConstants.SWARM_MITE_SCORE
	base_color = GameConstants.SWARM_MITE_COLOR
	# Swarm mites don't use smart AI — they're too simple to flank/retreat.
	# Their behavior is purely "rush the player". This also makes them
	# cheaper to process when many are active simultaneously.
	use_smart_ai = false
	super._ready()

	# Extra emission for a "glowing bug" look — mites pulse with energy
	if _material:
		_material.emission = base_color * 0.5
		_material.emission_energy_multiplier = 1.8