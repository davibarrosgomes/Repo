# One Piece Battlegrounds

A *The Strongest Battlegrounds*-style Roblox fighting game inspired by **One Piece**.
Playable characters (pick via the topbar character button):

- **Monkey D. Luffy** — ranged rubber attacks + a **Gear 5** ultimate
- **Roronoa Zoro** — fast three-sword rushdown + an **Ashura** ultimate
- **Vinsmoke Sanji** — mobile Black Leg kicks + a **Diable Jambe** ultimate
  that sets enemies on fire (burn damage-over-time)
- **Portgas D. Ace** — ranged fire zoner (projectiles) + a **Great Flame
  Commandment** ultimate; his hits also burn

**Admin character:** press **`\`** (backslash) to open the Admin Panel and
enter the access code to unlock **Tung Tung Tung Sahur** — an OP bat fighter
with 2x health, 1.5x damage, and a "The King" ultimate whose every move is a
one-hit kill (with a crown cutscene). The code is validated server-side and
never ships in client code.

Each character has a full 4-slot base moveset and an ultimate transformation
that replaces all four skills.

## Quick install (just 2 copy-pastes)

No Rojo, no folders, no ModuleScripts. Everything is bundled into two flat
scripts in [`dist/`](dist):

1. In **ServerScriptService**, insert a **Script** and paste all of
   [`dist/ServerScript.lua`](dist/ServerScript.lua) into it.
2. In **StarterPlayer → StarterPlayerScripts**, insert a **LocalScript** and
   paste all of [`dist/ClientScript.lua`](dist/ClientScript.lua) into it.
3. Delete the default **Baseplate** and **SpawnLocation** from Workspace
   (the game builds its own island), then press **Play**.

That's the whole setup. The `src/` tree below is the same code split into
proper modules for editing/Rojo; `dist/` is generated from it.

## Controls

| Input | Action |
| --- | --- |
| **Left Mouse** | M1 combo (4-hit chain, last hit ragdolls) |
| **1** | Skill 1 |
| **2** | Skill 2 |
| **3** | Skill 3 |
| **4** | Skill 4 |
| **Q** | Dash (in your movement direction) |
| **F** (hold) | Block — absorbs front hits until your guard breaks |
| **G** | Activate ult (Gear 5) when the bar is full |

**Blocking:** your guard has its own durability bar (regenerates while not
blocking). It only covers the front 180°, attacking drops it, and when it
shatters you're ragdolled and locked out of guarding for a few seconds.
Devour is a grab and goes straight through guards.

## Luffy — Base Moveset

| Slot | Move | Description |
| --- | --- | --- |
| 1 | **Gomu Gomu no Pistol** | Devastating stretching punch — long-range arm strike with heavy knockback. |
| 2 | **Gomu Gomu no Bazooka** | Double-arm strike that launches and ragdolls anything in front. |
| 3 | **Gomu Gomu no Gatling** | Rapid-fire barrage of punches that stitches victims in place, ending with a knockback blow. |
| 4 | **Rubber Combo** | Dashes to the nearest enemy and unloads a relentless 5-hit rubber combo. |

## Ult — GEAR 5

Deal or take damage to fill the ult bar. At 100%, press **G**: Luffy transforms
into **Gear 5** (white aura, heal, speed boost) for 30 seconds and the moveset becomes:

| Slot | Move | Description |
| --- | --- | --- |
| 1 | **Gomu Gomu no Bajrang Gun** | An island-sized fist that annihilates everything in a huge line. |
| 2 | **Gomu Gomu no Dawn Gatling** | A barrage so fast it looks like dozens of simultaneous arms. |
| 3 | **Toon Force** | Turns the opponent into rubber, combos them relentlessly, and leaves them **paralyzed** after the final punch. |
| 4 | **Drums of Liberation** | Luffy beats his chest to the sound of the drums, his head grows disproportionately large, and he **devours** the enemy — a one-hit kill. One use per transformation, with a long, loud wind-up so it can be dodged. |

## Project structure

```
default.project.json      Rojo project file
src/
  shared/                 -> ReplicatedStorage.Shared
    Config.lua            All balance numbers (damage, cooldowns, ranges, timings)
    Remotes.lua           RemoteEvent creation/lookup
  server/                 -> ServerScriptService.Server
    init.server.lua       Entry point: remotes, cooldowns, dash/block, spawning, KO leaderboard
    CombatService.lua     Hitboxes, damage, ult charge, blocking, stun/ragdoll/knockback/rubberize
    MapBuilder.lua        Generates Onigashima (horned skull mountain, Kaido's mansion, village, spawns)
    Characters/
      Luffy.lua           Every Luffy move (base + Gear 5) and the ult transformation
  client/                 -> StarterPlayerScripts.Client
    init.client.lua       Input handling
    HUD.lua               Skill bar, cooldown sweeps, ult meter
    VFXClient.lua         Procedural visual effects for every move
```

## Getting it into Roblox Studio

The project is laid out for [Rojo](https://rojo.space):

```sh
rojo serve   # then connect with the Rojo plugin in Studio
# or build a place file directly:
rojo build -o OnePieceBattlegrounds.rbxlx
```

No Rojo? Just recreate the tree by hand in Studio: the `src/shared` modules go
in `ReplicatedStorage/Shared`, `src/server` becomes a Script in
`ServerScriptService` (with `CombatService` and `Characters/Luffy` as child
ModuleScripts), and `src/client` becomes a LocalScript in
`StarterPlayer/StarterPlayerScripts` (with `HUD` and `VFXClient` as children).

## Design notes

- **Server-authoritative**: the client only sends "slot N was pressed". All
  cooldowns, hitboxes, damage, status effects and the ult meter live on the
  server, so exploiters can't skip cooldowns or fake damage.
- **Zero required assets**: every visual effect is procedural (parts, tweens,
  particles, highlights), so the game is fully playable immediately.
  `Config.Sounds` and `Config.Animations` contain placeholder ids — drop in
  your own uploaded assets and they'll be used automatically.
- **Balance in one file**: every number worth tuning lives in
  `src/shared/Config.lua`.
- **Adding characters**: create `src/server/Characters/YourCharacter.lua`
  following `Luffy.lua`'s shape (a `UseSkill`, `M1`, `ActivateUlt` interface)
  and add its config tables — the dispatch layer in `init.server.lua` is the
  only other place to touch.
