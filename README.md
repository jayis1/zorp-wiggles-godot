# Zorp Wiggles: Alien Adventure — Godot Edition

A 3D open-world alien adventure game, rebuilt from the Ursina/Python original in Godot 4.4 with GDScript.

## About

You are Zorp, a squishy green alien exploring a procedurally-generated 3D planet. Collect weird stuff, complete missions, blast enemies with your tentacle laser, and survive the alien wilderness!

Originally built with the Ursina engine (Python), this is a ground-up rewrite in Godot 4.4 using GDScript for better performance, export options, and a proper scene architecture.

## Controls

| Key | Action |
|---|---|
| WASD | Move (camera-relative) |
| Right-click + drag | Orbit camera |
| Left-click | Shoot tentacle laser |
| Space | Dash (with invulnerability frames) |
| Q | Pulse Wave (AoE attack, 8s cooldown) |
| E | Trade (near Trader) |
| M | Toggle minimap |
| Tab | Toggle missions panel |
| P | Pause |

## Building & Running

1. Install [Godot 4.4+](https://godotengine.org/downloads)
2. Open this project folder in Godot
3. Press F5 to run

## Project Structure

```
zorp-wiggles-godot/
├── project.godot           # Project settings, input mappings
├── scenes/
│   ├── main.tscn           # Main game scene
│   ├── main_menu.tscn       # Start menu
│   ├── entities/
│   │   ├── enemy_blob.tscn  # Basic enemy
│   │   └── collectible.tscn # Pickup items
│   └── ui/                  # HUD scenes (TODO)
├── scripts/
│   ├── game_constants.gd   # All game constants
│   ├── game_manager.gd     # Autoload singleton — game state
│   ├── player.gd           # Player controller
│   ├── camera_rig.gd       # Orbit camera
│   ├── enemy_base.gd       # Base enemy AI
│   ├── world_generator.gd  # Procedural world
│   ├── hud.gd              # HUD overlay
│   ├── collectible.gd      # Pickup items
│   ├── projectile.gd       # Player laser
│   ├── pulse_wave.gd       # Q ability
│   └── main_menu.gd        # Menu logic
├── assets/                  # Models, textures, audio (TODO)
└── CONVERSION_TRACKER.md   # Conversion progress tracker
```

## Conversion Status

See [CONVERSION_TRACKER.md](CONVERSION_TRACKER.md) for detailed progress.

**Phase 1 (Core Framework):** ✅ Complete
- Player movement, dash, camera
- Basic enemy AI
- Procedural world generation
- HUD (HP, XP, combo, boss bar)
- Collectibles with magnetic pull
- Projectile system
- Pulse wave ability

**Remaining phases:** Enemy varieties, decorations, particle effects, missions, audio, polish, export.

## License

Open source — same as the original Zorp Wiggles project.# v0.1.0-godot
