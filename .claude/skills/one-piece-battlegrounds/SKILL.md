---
name: one-piece-battlegrounds
description: Development guide for the One Piece Battlegrounds Roblox game. Use when adding characters, moves, ults, VFX, or rebalancing combat in this repository, or when building/testing the game with Rojo and Roblox Studio.
---

# One Piece Battlegrounds — Development Skill

A *The Strongest Battlegrounds*-style Roblox fighting game inspired by One Piece,
written in Luau and laid out for Rojo.

## Golden rules

1. **Server-authoritative always.** The client only ever sends "which button was
   pressed" (`UseSkill(slot)`, `M1`, `ActivateUlt`). All cooldowns, hitboxes,
   damage, status effects and ult charge are computed and validated on the
   server. Never trust positions, targets, or damage numbers from a client.
2. **All balance numbers live in `src/shared/Config.lua`.** Never hardcode
   damage, cooldowns, ranges or timings inside move logic — add a config entry.
3. **VFX are fire-and-forget.** The server fires the `VFX` RemoteEvent with an
   effect name + data table; `src/client/VFXClient.lua` renders it. VFX must
   never affect gameplay. Effects are procedural (parts/tweens/particles) so
   the game works with zero uploaded assets; asset ids in `Config.Sounds` /
   `Config.Animations` are optional and consumers must skip ids that are 0.
4. **Status effects are character attributes** (`Stunned`, `Ragdolled`,
   `Rubberized`, `Busy`, `Gear5`), managed only through `CombatService`
   (`Stun`, `Ragdoll`, `Rubberize`, `SetBusy`). They use monotonic tokens so
   overlapping applications don't cancel each other early — keep that pattern.
5. **Movement restore goes through attributes.** `BaseWalkSpeed` /
   `BaseJumpPower` attributes on the character are the source of truth;
   anything that changes speed (stuns ending, buffs) calls
   `Combat.RefreshMovement(character)` instead of writing WalkSpeed directly.

## File map

| Path | Role |
| --- | --- |
| `default.project.json` | Rojo tree (shared → ReplicatedStorage, server → ServerScriptService, client → StarterPlayerScripts) |
| `src/shared/Config.lua` | Every tunable number; `Config.Base[slot]` and `Config.Gear5[slot]` are the movesets |
| `src/shared/Remotes.lua` | Creates/fetches RemoteEvents (`UseSkill`, `M1`, `ActivateUlt`, `Dash`, `Block`, `VFX`, `HUDUpdate`) |
| `src/server/init.server.lua` | Entry point: remote validation, per-slot cooldown store, `casting` lock, dash/block handling, block regen, spawning, KO leaderstats |
| `src/server/CombatService.lua` | Combat primitives: `FrontHitbox`, `NearestTarget`, `DealDamage`, statuses, blocking/guard break, knockback, ult charge |
| `src/server/MapBuilder.lua` | Generates the arena (geometry, spawns, kill plane, lighting) at startup |
| `src/server/Characters/Luffy.lua` | All Luffy moves; dispatch via `Luffy.UseSkill(player, character, slot)` returning the cooldown (or nil if the cast failed) |
| `src/client/init.client.lua` | Input: LMB = M1, keys 1–4 = skills, G = ult |
| `src/client/HUD.lua` | Skill bar, cooldown sweeps, ult bar; slot names swap when `Gear5` is active |
| `src/client/VFXClient.lua` | One function per effect name in the `Effects` table |

## How to add a move

1. Add a config entry (`Config.Base[n]` or `Config.Gear5[n]` for Luffy, or the
   new character's table) with `Id`, `Name`, `Cooldown`, and its numbers.
2. Implement the move as a local function in the character module:
   `Combat.SetBusy` for the animation window (pass `true` to root heavy moves),
   `task.wait(cfg.WindUp)`, then `Combat.FrontHitbox` / `Combat.NearestTarget`
   and `Combat.DealDamage` with knockback/stun/ragdoll options.
3. Register it in the module's move table (`BASE_MOVES` / `GEAR5_MOVES`).
4. Fire a `VFX` event at cast time and add a matching function to the
   `Effects` table in `VFXClient.lua`.
5. Return `false` from the move to refuse the cast without burning the
   cooldown (see Devour's once-per-ult check).

## How to add a character

1. Create `src/server/Characters/<Name>.lua` mirroring `Luffy.lua`'s interface:
   `UseSkill`, `M1`, `ActivateUlt`, `DeactivateUlt`, `ForgetPlayer`.
2. Add its moveset tables to `Config.lua`.
3. In `init.server.lua`, route the remotes to the player's selected character
   module instead of the hardcoded `Luffy` require (add a per-player character
   selection map — this is the only dispatch point).
4. HUD reads move names from config, so wire the character's config tables
   into `HUD.lua`'s `slotName`.

## Build & test loop

```sh
rojo build -o OnePieceBattlegrounds.rbxlx   # open the file in Studio
# or live-sync while editing:
rojo serve                                   # connect the Rojo plugin in Studio
```

Test combat in Studio via Test tab → Clients and Servers → 2 players.
Syntax-check Luau without Studio: `stylua --syntax Luau --check src`.

## Gameplay conventions

- One-hit-kill or high-impact moves need a long, rooted, visually loud wind-up
  (see Drums of Liberation: 2.2s rooted channel) so they are dodgeable.
- Multi-hit combos stun the victim per tick (`StunTime ≈ 2× tick interval`)
  and only the final hit applies knockback/ragdoll.
- Ult charge comes only from `Combat.DealDamage` (dealt > taken); the charge
  from a single hit is capped at the victim's MaxHealth so one-shots don't
  insta-fill bars.
- Dash moves snap in front of `Combat.NearestTarget` rather than tweening —
  battlegrounds-style feel and no pathing edge cases.
- Blocking (hold F) absorbs front-180° hits using the `BlockHealth` attribute;
  guard break ragdolls + locks re-guarding. Grabs set `Unblockable = true` in
  their `DealDamage` opts. Attacking or dashing drops the guard.
