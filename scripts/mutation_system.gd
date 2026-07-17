## Zorp Wiggles — Biome Mutation System (Phase 13)
## Tracks time spent in each biome and grants mutations that change Zorp's
## abilities and appearance. Mutations decay after leaving the biome.
##
## Mutations:
## - Lava: fire resistance + flame dash (leave fire trail)
## - Crystal: refractive cloak (partial invisibility) + crystal shard attack
## - Snow: freeze pulse (AoE slow) + ice armor (damage reduction)
## - Alien: gravity flip (walk on ceiling briefly) + plasma burst
## - Forest: nature's ally (enemies in forest biome become passive)
## - Toxic: poison trail (damage-over-time zone behind Zorp)

extends Node

# ─── Mutation IDs ─────────────────────────────────────────────────────────────
enum Mutation {
	NONE,
	LAVA,       # Fire resistance + flame dash
	CRYSTAL,    # Refractive cloak + crystal shard
	SNOW,       # Freeze pulse + ice armor
	ALIEN,      # Gravity flip + plasma burst
	FOREST,     # Nature's ally (enemies passive in forest)
	TOXIC,      # Poison trail (DoT zone)
}

# ─── Biome → Mutation Mapping ─────────────────────────────────────────────────
const BIOME_MUTATION_MAP: Dictionary = {
	GameConstants.Biome.LAVA: Mutation.LAVA,
	GameConstants.Biome.CRYSTAL: Mutation.CRYSTAL,
	GameConstants.Biome.SNOW: Mutation.SNOW,
	GameConstants.Biome.ALIEN: Mutation.ALIEN,
	GameConstants.Biome.FOREST: Mutation.FOREST,
	GameConstants.Biome.TOXIC_BOG: Mutation.TOXIC,
	GameConstants.Biome.SWAMP: Mutation.TOXIC,   # Swamp also gives toxic
	GameConstants.Biome.MUSHROOM: Mutation.TOXIC, # Mushroom biome gives toxic
}

# ─── Configuration ────────────────────────────────────────────────────────────
const MUTATION_THRESHOLD: float = 15.0     # Seconds in biome to activate mutation
const MUTATION_DECAY_TIME: float = 60.0    # Seconds after leaving before mutation fades
const MAX_MUTATIONS: int = 3               # Max concurrent mutations
const COMBO_THRESHOLD: int = 2             # Mutations needed for enhanced version

# ─── State ────────────────────────────────────────────────────────────────────
# Time spent in current biome
var _biome_time: float = 0.0
var _current_biome: int = -1

# Active mutations: { Mutation: { "time_left": float, "strength": float } }
var _active_mutations: Dictionary = {}

# ─── Signals ──────────────────────────────────────────────────────────────────
signal mutation_activated(mutation: int, name: String)
signal mutation_deactivated(mutation: int)
signal mutation_progress_changed(biome: int, progress: float)

# ─── Mutation Info ────────────────────────────────────────────────────────────
const MUTATION_NAMES: Dictionary = {
	Mutation.LAVA: "Inferno Form",
	Mutation.CRYSTAL: "Prismatic Veil",
	Mutation.SNOW: "Frost Aegis",
	Mutation.ALIEN: "Void Step",
	Mutation.FOREST: "Nature's Pact",
	Mutation.TOXIC: "Venom Trail",
}

const MUTATION_COLORS: Dictionary = {
	Mutation.LAVA: Color(1.0, 0.3, 0.0),
	Mutation.CRYSTAL: Color(0.7, 0.4, 0.9),
	Mutation.SNOW: Color(0.7, 0.9, 1.0),
	Mutation.ALIEN: Color(0.6, 0.2, 0.7),
	Mutation.FOREST: Color(0.2, 0.6, 0.2),
	Mutation.TOXIC: Color(0.5, 0.8, 0.15),
}

func _ready() -> void:
	GameManager.biome_changed.connect(_on_biome_changed)

func _on_biome_changed(biome_id: int) -> void:
	if _current_biome == biome_id:
		return
	_current_biome = biome_id
	_biome_time = 0.0

func _process(delta: float) -> void:
	if GameManager.is_paused or not GameManager.player_is_alive:
		return

	# Track time in current biome
	var mutation: int = BIOME_MUTATION_MAP.get(_current_biome, Mutation.NONE)
	if mutation != Mutation.NONE:
		_biome_time += delta

		# Activate mutation when threshold reached
		if _biome_time >= MUTATION_THRESHOLD and not _active_mutations.has(mutation):
			if _active_mutations.size() < MAX_MUTATIONS:
				_activate_mutation(mutation)
			else:
				# Replace oldest mutation
				var oldest: int = _active_mutations.keys()[0]
				_deactivate_mutation(oldest)
				_activate_mutation(mutation)

		# Emit progress for UI
		var progress: float = clampf(_biome_time / MUTATION_THRESHOLD, 0.0, 1.0)
		mutation_progress_changed.emit(_current_biome, progress)
	else:
		# No mutation for this biome — reset timer
		_biome_time = 0.0

	# Decay active mutations (only those whose biome we're NOT in)
	var mutations_to_remove: Array = []
	for mut_key in _active_mutations:
		var mut: int = mut_key
		var mut_biome: int = _find_biome_for_mutation(mut)
		if mut_biome != _current_biome:
			# Decay this mutation
			_active_mutations[mut].time_left -= delta
			if _active_mutations[mut].time_left <= 0:
				mutations_to_remove.append(mut)

	for mut in mutations_to_remove:
		_deactivate_mutation(mut)

func _find_biome_for_mutation(mutation: int) -> int:
	for biome_key in BIOME_MUTATION_MAP:
		if BIOME_MUTATION_MAP[biome_key] == mutation:
			return biome_key
	return -1

func _activate_mutation(mutation: int) -> void:
	_active_mutations[mutation] = {
		"time_left": MUTATION_DECAY_TIME,
		"strength": 1.0,
	}
	var name: String = MUTATION_NAMES.get(mutation, "Unknown")
	mutation_activated.emit(mutation, name)
	GameManager.add_message("✦ Mutation acquired: %s" % name)
	# Phase 20: Audio — mutation SFX
	AudioManager.play_sfx(AudioManager.SFX_MUTATION)

	# Apply visual changes to player
	_apply_mutation_visuals(mutation)

func _deactivate_mutation(mutation: int) -> void:
	_active_mutations.erase(mutation)
	mutation_deactivated.emit(mutation)
	var name: String = MUTATION_NAMES.get(mutation, "Unknown")
	GameManager.add_message("✦ Mutation faded: %s" % name)

	# Remove visual changes
	_remove_mutation_visuals(mutation)

func _apply_mutation_visuals(mutation: int) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
	var color: Color = MUTATION_COLORS.get(mutation, Color.WHITE)

	# Spawn a mutation activation particle burst
	ParticleEffects.spawn_explosion(player.get_parent(),
		player.global_position + Vector3(0, 1, 0), color, 20, 0.8)

	# Shift player color toward mutation color
	if player.has_method("_apply_mutation_color"):
		player._apply_mutation_color(mutation, color)

func _remove_mutation_visuals(mutation: int) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
	if player.has_method("_remove_mutation_color"):
		player._remove_mutation_color(mutation)

# ─── Public API ───────────────────────────────────────────────────────────────

## Check if a specific mutation is active.
func has_mutation(mutation: int) -> bool:
	return _active_mutations.has(mutation)

## Get mutation strength (0.0 to 1.0, ramps up over time).
func get_mutation_strength(mutation: int) -> float:
	if not _active_mutations.has(mutation):
		return 0.0
	return _active_mutations[mutation].strength

## Get all active mutations as an array.
func get_active_mutations() -> Array:
	return _active_mutations.keys()

## Get the number of active mutations.
func get_mutation_count() -> int:
	return _active_mutations.size()

## Check if mutation combo is active (2+ mutations).
func has_combo() -> bool:
	return _active_mutations.size() >= COMBO_THRESHOLD

## Get fire resistance (0.0 to 1.0) from Lava mutation.
func get_fire_resistance() -> float:
	if has_mutation(Mutation.LAVA):
		return 0.5 if has_combo() else 0.3
	return 0.0

## Get damage reduction from Snow mutation (ice armor).
func get_damage_reduction() -> float:
	if has_mutation(Mutation.SNOW):
		return 0.3 if has_combo() else 0.2
	return 0.0

## Check if enemies should be passive (Forest mutation).
func enemies_passive() -> bool:
	return has_mutation(Mutation.FOREST) and _current_biome == GameConstants.Biome.FOREST

## Get the mutation for the current biome (or NONE).
func get_pending_mutation() -> int:
	return BIOME_MUTATION_MAP.get(_current_biome, Mutation.NONE)

## Get progress toward next mutation (0.0 to 1.0).
func get_mutation_progress() -> float:
	return clampf(_biome_time / MUTATION_THRESHOLD, 0.0, 1.0)