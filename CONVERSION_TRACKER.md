# Zorp Wiggles: Godot Conversion Tracker

## Status: PHASE 1 — Core Framework (IN PROGRESS)

Original: 21,927 lines of Ursina/Python in game.py
Target: Godot 4.4 GDScript project with proper scene architecture

## Architecture Mapping

| Ursina Concept | Godot Equivalent | Status |
|---|---|---|
| `from ursina import *` | Individual class references | N/A |
| `Entity` | `Node3D` / `MeshInstance3D` / `Area3D` | ✅ |
| `color.rgb(r,g,b)` 0-255 | `Color(r/255, g/255, b/255)` 0-1 | ✅ Converted |
| `color.rgba(r,g,b,a)` | `Color(r/255, g/255, b/255, a/255)` | ✅ Converted |
| `Text` | `Label` / `Label3D` | ✅ |
| `destroy(entity)` | `queue_free()` | ✅ |
| `app.update = func` | `_process(delta)` / `_physics_process(delta)` | ✅ |
| `held_keys['w']` | `Input.is_action_pressed("move_up")` | ✅ |
| `input(key)` | `_unhandled_input(event)` | ✅ |
| `time.dt` | `delta` parameter | ✅ |
| `mouse.world_point` | RayCast from camera to ground plane | ✅ |
| Single Game class | Multiple autoloads + scene scripts | ✅ |

## Phase Progress

### Phase 1: Core Framework ✅ (Current)
- [x] project.godot — Input mappings, display settings
- [x] game_constants.gd — All constants ported (0-1 colors)
- [x] game_manager.gd — Game state autoload singleton
- [x] player.gd — WASD movement, dash, invuln, camera-relative
- [x] camera_rig.gd — Orbit camera following player
- [x] enemy_base.gd — Base enemy AI, HP, damage, attacks
- [x] world_generator.gd — Procedural biome terrain
- [x] hud.gd — HP/XP/combo/boss bars, messages
- [x] collectible.gd — Item pickup with magnetic pull
- [x] projectile.gd — Player laser projectile
- [x] pulse_wave.gd — Q ability expanding ring
- [x] main_menu.gd — Start screen
- [x] main.tscn — Main game scene
- [x] main_menu.tscn — Menu scene
- [x] enemy_blob.tscn — Basic enemy scene
- [x] collectible.tscn — Pickup item scene

### Phase 2: Enemy Varieties (TODO)
- [ ] enemy_serpent.gd — Plasma Serpent (segmented body)
- [ ] enemy_graviton.gd — Gravity pull attack
- [ ] enemy_wisp.gd — Void Wisp (teleport on hit)
- [ ] enemy_sentinel.gd — Shockwave Sentinel (ring attack)
- [ ] enemy_bomber.gd — Void Bomber (ranged AoE)
- [ ] enemy_spitter.gd — Spore Spitter (ranged projectile)
- [ ] enemy_drake.gd — Plasma Drake (boss)
- [ ] All enemy .tscn scene files
- [ ] Enemy spawn system (dynamic spawning over time)

### Phase 3: World & Decorations (TODO)
- [ ] Biome decorations: trees (forest), crystals, mushrooms
- [ ] Floating islands with shadows and crystals
- [ ] Sky dome (3 layers, 24 billboard quads)
- [ ] Star field with twinkling
- [ ] Nebula clouds
- [ ] Portal structures
- [ ] Trader NPC
- [ ] Monolith buff structures

### Phase 4: Full Combat & Abilities (TODO)
- [ ] Damage numbers (floating 3D text)
- [ ] Kill combo system with milestones
- [ ] Pickup streak system
- [ ] Crit chain bonus (3x at 3+ consecutive crits)
- [ ] Dash invulnerability frames
- [ ] Enemy attack windup telegraph
- [ ] Enemy spawn animation (fade-in + bounce)
- [ ] Enemy alert indicator (!)
- [ ] Spawn direction indicator arrows

### Phase 5: HUD Polish (TODO)
- [ ] Minimap (SubViewport with top-down camera)
- [ ] Enemy proximity radar dots
- [ ] Power-up timer display
- [ ] Damage direction indicators (arrows)
- [ ] Boss tension vignette
- [ ] Death screen with stats
- [ ] Achievement popups
- [ ] Kill feed
- [ ] Biome indicator

### Phase 6: Particle Effects & Juice (TODO)
- [ ] Movement trail particles
- [ ] Idle regen sparkles
- [ ] Level-up shockwave burst
- [ ] Combo milestone fireworks
- [ ] Pickup lift animation
- [ ] Sky beam on rare pickup
- [ ] Shield break shatter effect
- [ ] Player damage flash
- [ ] Damage number popups
- [ ] Health fragment emergency magnet

### Phase 7: Missions & Progression (TODO)
- [ ] Mission system (collect X, kill Y, explore Z)
- [ ] Trader NPC with trade items
- [ ] Monolith buff system
- [ ] Achievement system

### Phase 8: Audio & Polish (TODO)
- [ ] Sound effects
- [ ] Background music
- [ ] Screen shake
- [ ] Smooth camera follow
- [ ] Pause menu
- [ ] Settings (resolution, volume)

### Phase 9: Export & Distribution (TODO)
- [ ] Windows export
- [ ] Linux export
- [ ] macOS export
- [ ] Web export

## Notes
- All Ursina color.rgb() 0-255 values have been converted to Godot Color() 0-1 range
- Single Game class split into: GameManager (autoload), WorldGenerator, Player, HUD, etc.
- Ursina's global update() replaced by per-node _process()/_physics_process()
- Ursina's global input(key) replaced by _unhandled_input(event) + Input actions
- Scene tree architecture replaces single-file imperative approach

## Last Updated
Phase 1 complete — core framework ported, basic gameplay loop functional.