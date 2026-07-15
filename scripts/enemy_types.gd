## Zorp Wiggles — Enemy Type Data (Autoload Singleton)
## All 18 enemy types ported from Ursina game.py Enemy.TYPES
## Colors converted from Ursina (0-255 rgb / 0-1 named) to Godot Color(0-1)

extends Node

## Enemy type definitions: name, hp, speed, damage, scale, model, decor, detect_range, color
## Ported from game.py lines 4483-4503

static var TYPES: Dictionary = {
	"Slime Blob": {
		"color": Color(0.0, 1.0, 0.0),          # color.lime
		"hp": 25,   "speed": 3.0,  "damage": 8,   "scale": 1.0,
		"model": "sphere",  "decor": "none",   "detect": 32,
	},
	"Space Beetle": {
		"color": Color(0.55, 0.27, 0.07),       # color.brown
		"hp": 45,   "speed": 4.5,  "damage": 12,  "scale": 1.2,
		"model": "cube",    "decor": "wings",   "detect": 32,
	},
	"Void Wraith": {
		"color": Color(0.54, 0.17, 0.89),       # color.violet
		"hp": 70,   "speed": 4.0,  "damage": 22,  "scale": 1.4,
		"model": "diamond", "decor": "aura",    "detect": 32,
	},
	"Lava Crawler": {
		"color": Color(1.0, 0.55, 0.0),          # color.orange
		"hp": 100,  "speed": 5.5,  "damage": 28,  "scale": 1.1,
		"model": "cube",    "decor": "spikes",  "detect": 32,
	},
	"Crystal Guardian": {
		"color": Color(0.0, 1.0, 1.0),          # color.cyan
		"hp": 180,  "speed": 2.2,  "damage": 38,  "scale": 1.8,
		"model": "diamond", "decor": "shards",  "detect": 32,
	},
	"Plasma Drake": {
		"color": Color(1.0, 0.0, 1.0),          # color.magenta
		"hp": 350,  "speed": 6.5,  "damage": 45,  "scale": 2.2,
		"model": "diamond", "decor": "wings",   "detect": 32,
	},
	"Phase Shifter": {
		"color": Color(0.71, 0.0, 1.0, 0.78),   # color.rgba(180,0,255,200)
		"hp": 60,   "speed": 5.0,  "damage": 18,  "scale": 1.3,
		"model": "diamond", "decor": "aura",    "detect": 32,
	},
	"Spore Spitter": {
		"color": Color(0.78, 0.39, 0.0),         # color.rgb(200,100,0)
		"hp": 80,   "speed": 3.0,  "damage": 12,  "scale": 1.4,
		"model": "sphere",  "decor": "spikes",  "detect": 32,
	},
	"Swarm Mite": {
		"color": Color(0.59, 0.78, 0.20),       # color.rgb(150,200,50)
		"hp": 12,   "speed": 7.0,  "damage": 3,   "scale": 0.5,
		"model": "sphere",  "decor": "none",   "detect": 28,
	},
	"Void Bomber": {
		"color": Color(0.31, 0.0, 0.16),         # color.rgb(80,0,40)
		"hp": 50,   "speed": 3.5,  "damage": 15,  "scale": 1.1,
		"model": "sphere",  "decor": "spikes",  "detect": 28,
	},
	"Nebula Phantom": {
		"color": Color(0.39, 0.59, 1.0, 0.59),  # color.rgba(100,150,255,150)
		"hp": 90,   "speed": 5.5,  "damage": 25,  "scale": 1.3,
		"model": "sphere",  "decor": "aura",    "detect": 38,
	},
	"Starburst Sentinel": {
		"color": Color(1.0, 0.78, 0.20),         # color.rgb(255,200,50)
		"hp": 60,   "speed": 0.0,  "damage": 12,  "scale": 1.5,
		"model": "diamond", "decor": "shards",  "detect": 28,
	},
	"Cosmic Leech": {
		"color": Color(0.31, 0.0, 0.31),         # color.rgb(80,0,80)
		"hp": 30,   "speed": 5.5,  "damage": 4,   "scale": 0.7,
		"model": "sphere",  "decor": "aura",    "detect": 22,
	},
	"Void Stalker": {
		"color": Color(0.16, 0.16, 0.24),        # color.rgb(40,40,60)
		"hp": 55,   "speed": 6.5,  "damage": 15,  "scale": 1.1,
		"model": "diamond", "decor": "aura",    "detect": 32,
	},
	"Plasma Serpent": {
		"color": Color(0.0, 1.0, 0.78),          # color.rgb(0,255,200)
		"hp": 120,  "speed": 3.5,  "damage": 20,  "scale": 1.0,
		"model": "sphere",  "decor": "aura",    "detect": 34,
	},
	"Graviton": {
		"color": Color(0.71, 0.0, 1.0),          # color.rgb(180,0,255)
		"hp": 75,   "speed": 2.8,  "damage": 10,  "scale": 1.5,
		"model": "sphere",  "decor": "aura",    "detect": 30,
	},
	"Void Wisp": {
		"color": Color(0.39, 1.0, 0.78, 0.63),   # color.rgba(100,255,200,160)
		"hp": 18,   "speed": 8.0,  "damage": 5,   "scale": 0.4,
		"model": "sphere",  "decor": "aura",    "detect": 26,
	},
	"Echo Wraith": {
		"color": Color(0.47, 0.78, 0.86),        # color.rgb(120,200,220)
		"hp": 65,   "speed": 4.5,  "damage": 16,  "scale": 1.3,
		"model": "diamond", "decor": "aura",    "detect": 30,
	},
	"Shard Golem": {
		"color": Color(0.39, 0.71, 0.86),        # color.rgb(100,180,220)
		"hp": 160,  "speed": 1.8,  "damage": 22,  "scale": 1.6,
		"model": "cube",    "decor": "shards",  "detect": 26,
	},
}

static var EASY_TYPES: Array[String] = ["Slime Blob", "Space Beetle", "Swarm Mite", "Void Wisp"]
static var MEDIUM_TYPES: Array[String] = ["Space Beetle", "Void Wraith", "Phase Shifter", "Cosmic Leech", "Void Bomber", "Graviton", "Void Wisp", "Echo Wraith", "Shard Golem"]
static var HARD_TYPES: Array[String] = ["Void Wraith", "Lava Crawler", "Crystal Guardian", "Plasma Drake", "Spore Spitter", "Void Bomber", "Nebula Phantom", "Starburst Sentinel", "Void Stalker", "Plasma Serpent", "Graviton", "Echo Wraith", "Shard Golem"]

## Loot drop ranges per enemy type
static var LOOT_DROPS: Dictionary = {
	"Slime Blob":          [1, 2],
	"Space Beetle":        [1, 2],
	"Swarm Mite":          [1, 2],
	"Cosmic Leech":        [2, 3],
	"Phase Shifter":       [2, 3],
	"Void Bomber":         [2, 3],
	"Spore Spitter":       [2, 3],
	"Void Wraith":         [2, 4],
	"Nebula Phantom":      [2, 4],
	"Void Stalker":        [2, 4],
	"Lava Crawler":        [3, 5],
	"Crystal Guardian":   [3, 5],
	"Starburst Sentinel": [3, 5],
	"Plasma Drake":        [4, 6],
	"Plasma Serpent":     [3, 5],
	"Graviton":            [2, 4],
	"Void Wisp":          [1, 3],
	"Echo Wraith":         [2, 4],
	"Shard Golem":         [2, 4],
}

static func get_type(name: String) -> Dictionary:
	if TYPES.has(name):
		return TYPES[name]
	return TYPES["Slime Blob"]  # Default fallback

static func pick_type_by_distance(dist: float, difficulty_scale: float = 100.0) -> String:
	var tier := int(dist / difficulty_scale)
	if tier == 0:
		return EASY_TYPES[randi() % EASY_TYPES.size()]
	elif tier == 1:
		return MEDIUM_TYPES[randi() % MEDIUM_TYPES.size()]
	else:
		return HARD_TYPES[randi() % HARD_TYPES.size()]