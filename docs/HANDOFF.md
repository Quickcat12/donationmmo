# Handoff: Donation MMO

Written at the end of a long **cloud** Claude Code session, for the next session. The next
session is expected to be a **Code → Local** session on the owner's Mac, with computer use
enabled (it can drive Roblox Studio) and Higgsfield's `/use-blender` (it can run scripts in
the owner's local Blender). The cloud session had neither of these. It could not open
Studio, could not run Rojo, and **could never compile or play-test any of this code**. Read
section 6 before trusting anything.

Branch: `claude/donation-mmo-progression-zx3kh8` (all work is pushed there and has not been
merged to `main`). Run `git pull` first.

---

## 1. The owner's next request (the task you're picking this up for)

> "Fully build this game. Design stunning lobby map features and models using Blender, and
> make a stunning World 1 donation lobby. It doesn't have to be a massive world, just a
> pretty lobby on a large island with maybe 20 booths, or 30 depending on which is better.
> Read through the concept of this project thoroughly. **The reward system has to be worked
> into everything.**"

The owner wants you to control their screen to do the Studio and Blender work. Section 7
has the plan.

---

## 2. The game concept (from the owner, condensed — read all of it)

**Pitch:** It's PLS DONATE, but **both sides of a donation progress**. Today only the
receiver benefits from a donation. Here the donor gets XP too, so donating becomes the core
progression mechanic.

**The loop:**
- You get XP by donating to other players' booths (the biggest source), by receiving
  donations, by completing short obbies (small XP each), from quests, and from the XP shop
  (Robux, the owner's income).
- XP gives you levels, and levels get you **ranks**. Each rank needs more XP than the last.
- Higher levels unlock **higher worlds/servers**. Worlds are gated by **level, not Robux**,
  so poor players can still climb (by receiving donations, doing obbies, and doing quests).
- **Higher worlds have a higher XP-per-donated-Robux multiplier.** In World 1, buying XP
  from the shop is the efficient route. Higher up, donating to other players becomes
  cheaper per XP than the shop. That is the hook.
- The real draw: **people in higher worlds have donated more to get there, so they are
  richer.** In higher servers the ratio of rich players to poor ones rises. Players donate
  to climb into rooms full of richer people, who also want to donate to climb, and so on.
  The owner describes it as an investment: you can eventually raise more than you put in,
  because the richer servers are full of people trying to donate. (The owner is explicit
  that this is a motivation to climb, **not a guarantee**. Never phrase it in-game as
  guaranteed earnings.)
- The ladder never ends: the owner will keep adding worlds above the top, so nobody can max
  out.

**Social classes (the identity layer).** Inspired by *Red Rising*, but only its colors and
hierarchy, not its roles. Players identify by **rank color**, not level number: "I finally
reached Gold", never "I'm level 143". Hide raw levels from marketing. The ranks are, in
order: Gray → Green → Blue → Purple → Gold → Diamond → Celestial.
- Exclusive chat colors, join messages ("[DIAMOND] TyHurd has joined the server"),
  overhead titles, booth upgrades, cosmetics, and premium titles per rank.
- **Every class must feel prestigious relative to the class below it.** Never "if you're
  not Gold you're irrelevant", or new players quit. Gray should aspire to Green, Green to
  Blue, and so on.

**Visual language per world.** Every promotion should feel like entering a new social class.
- Gray: simple. Green: nicer, larger spaces. Blue: premium.
- Purple: beautiful architecture.
- Gold: white marble, gold trim, luxury buildings, elegant music.
- Diamond: crystal structures, reflective surfaces, expensive-looking effects.
- Celestial: floating islands, nebulas, massive monuments, animated skies.

**Owner's long summary doc themes:** donors get progression, rank, worlds, multipliers,
cosmetics, and status. Booths evolve with rank. There are activities beyond standing at a
booth (obbies, quests, exploration, events, seasonal content). Fully free-to-play is
possible. The game is a living ladder that keeps expanding upward.

---

## 3. Decisions the owner has already made (don't relitigate)

- **Blanket permission:** "I fully permit you to do any upgrades that would make this game
  more professional, addictive, and altogether better. You will not ask me. Just do it if
  you agree with it and it works to the summary of the game loop." The owner still corrects
  details afterwards (see the XP shop below), so make sensible calls and explain them.
- **Donations use player-owned Gamepasses**, linked to their booth (see `DonationService`).
  The owner once said "people link their own dev products". That was loose wording: players
  can't create Developer Products on someone else's experience. Keep Gamepasses.
- **XP Shop = Developer Products** sold by the game (the owner's revenue, not donations).
  Final tiers: 99 R$ → 2,500 XP · 249 → 6,750 · 499 → 14,750 · 999 → 32,000 · **2,500 →
  85,000** (max price 2,500 R$, per the owner). The XP-per-Robux rate must **strictly
  increase** with tier. The owner caught an earlier version where buying the 999 R$ pack
  twice beat buying the 2,500 R$ pack once. Never ship a dominated tier. The source of truth
  is `scripts/monetization/products.py`.
- **VIP Game Pass** (349 R$, +15% XP from every source, permanent).
- **Server XP Blessing** Developer Product (499 R$, 2x XP for the **whole server** for 15
  minutes, with a public announcement crediting the buyer).
- **Fixed 7-rank ladder** (curated thresholds). Reviewers suggested an infinite cubic XP
  formula. It was rejected because it fights the named-class design. To extend the ladder,
  add ranks and worlds.
- **No gacha/pets yet.** Roblox loot-box/paid-random-item rules need a deliberate decision
  first. Bring it up with the owner; don't add it silently.

---

## 4. Architecture (Rojo project)

`default.project.json` maps `src/shared` → `ReplicatedStorage.Shared`, `src/server` →
`ServerScriptService.Server`, and `src/client` → `StarterPlayerScripts.Client`.
**Workspace is NOT managed by Rojo.** The whole map is generated at runtime by
`WorldBuilderService`, so a Rojo sync never overwrites hand-built Studio content.

**Server boot order** (`src/server/Main.server.luau`): `Net.bootstrap()` (creates every
RemoteEvent) → `WorldBuilderService.build()` → each service's `.start()` →
`PlayerDataService.start()` **last**, because every service listens for its `DataLoaded`
signal.

| Server service | Does |
|---|---|
| PlayerDataService | ProfileService (session-locked) load/save. Store `PlayerData_v1`. `Reconcile()` fills new default fields. |
| XPService | `grantXp(player, amount, source)`. Final XP = amount × rank mult × world mult × VIP mult × server-boost mult. Updates leaderstats, fires `XpChanged`/`RankUp` and the `RankChanged` Signal. |
| DonationService | Players link up to 6 of their own Gamepass IDs. A donation is verified server-side (`UserOwnsGamePassAsync` + the receiver's linked list) before XP is granted. Donor XP = `price*10*(1+price/2000)`; the receiver gets 35% of that. 5-second rate limit on the Marketplace-calling handlers. A donation of 1,000 R$ or more broadcasts `BigDonationAnnouncement`. |
| StandService | Assigns the first unclaimed `DonationStand`-tagged model, wires the ProximityPrompt, and runs tier visuals (bigger footprint, Metal/Marble/Neon material, glow ring, Gold+ canopy, owner's title on the sign). |
| CosmeticService | Titles unlock and auto-equip on rank-up. Sets the Player attributes `RankName`/`RankColor`/`RankTitle`/`ShowChatTag`. Builds a custom overhead nameplate (hides the default one). Join announcements for Green and above. |
| XPShopService | **Sole owner of `MarketplaceService.ProcessReceipt`.** Delegates other products, e.g. to `ServerBoostService.tryProcessReceipt`. Never register a second ProcessReceipt. |
| VIPService / ServerBoostService | Multiplier providers read by XPService. VIP sets the `VIPOwned` attribute. |
| QuestService | Daily quests (`QuestConfig`). Other services call `QuestService.reportProgress(player, tag)`. |
| ObbyService | Anything tagged `ObbyFinish` (attributes `XpReward`, `CourseId`) grants XP with a 30-second cooldown per course. |
| CheckpointService | Parts tagged `ObbyCheckpoint` save a respawn point for the session. |
| WorldService | Validates the level gate, then `TeleportAsync`. **Every `placeId` is still 0**, so travel is disabled. |
| WorldPopulationService | Per-world player counts via DataStore (stale after 120s) → `WorldPopulationUpdated`. |
| LeaderboardService | OrderedDataStores for top XP and top donors, batched every 60 seconds. |
| PrestigeStandService | 5 pedestals near spawn showing the server's current top donors (read-only). |
| WorldBuilderService | Builds everything procedurally, themed by `WorldConfig.theme` for the current place. The plaza floats at `WORLD_Y = 500`. `Workspace.FallenPartsDestroyHeight = 440` handles void deaths. |

**CollectionService tags:** `DonationStand`, `ObbyFinish`, `ObbyCheckpoint`,
`WorldTeleporterPrompt`, `PrestigeStand`.

**Stand model contract** (keep these names if you replace the art): a Model tagged
`DonationStand` containing `Podium` (BasePart, with a `ProximityPrompt` named `DonatePrompt`),
`SignPost` → `BillboardGui "Sign"` → `TextLabel "OwnerLabel"` + `"TitleLabel"`, and the
optional parts `TierRing` and `Canopy`.

**Client** (`src/client/Main.client.luau` starts the controllers in order): HUD (XP bar),
RankUp (banner + sparkles), Donation (gamepass picker + toast), StandManager ("S" button),
XPShop ("XP" button: tiers, VIP, Blessing), WorldSelect ("W" button: rich world cards +
Preview modal; exposes `open()`/`toggle()`), Teleporter (the plaza portal opens WorldSelect),
Quest ("Q"), Leaderboard ("L"), Titles ("T"), ChatTag (rank prefix via
`TextChannel.OnIncomingMessage`), ChatStyle (themes the chat window/bubbles), and the
JoinAnnouncement, BigDonation, and ServerBoost banners. All UI is built in code with
`Shared.Util.UICreate` + `Theme`.

**Networking:** add new remotes to `RemoteNames.luau` (both the type union and the
`Events` table), then use `Net.get(RemoteNames.Events.X)`. The client is never trusted for
anything worth Robux or XP.

**Monetization scripts** (`scripts/monetization/`): `products.py` (source of truth),
`generate_icons.py` (Pillow; icons are already generated in `icons/`), and
`create_products.py`, which calls the real Open Cloud Developer Products/Game Passes APIs
via the `rblxopencloud` library, then patches the IDs into `XPShopConfig.luau`,
`VIPConfig.luau`, and `ServerBoostConfig.luau`. **It has never been run.** Until it is,
every product/pass ID is 0 and those buttons do nothing. See its README.

---

## 5. Known bugs and gaps (found but not fixed yet)

1. **The top world is unreachable.** `RankConfig.getLevelForXp` returns the base level of
   the top rank (Celestial = level 151) forever, but `celestial_apex` requires level 175.
   Levels must keep increasing past the last rank threshold (e.g. a fixed XP-per-level step
   after Celestial). That also supports "new worlds get added, so nobody maxes out".
2. **Only 16 booths** (`STAND_COUNT = 16` in WorldBuilderService). Every player needs a
   booth, so the booth count must be ≥ Max Players. For more than 16 players, `StandService`
   just warns and the extra player gets nothing.
3. **WorldSelectController rebuilds its whole panel on every XP gain** (`State.Changed`
   fires on every `XpChanged`). Rebuild only when the level actually changes.
4. **XP shop with unset IDs:** every `productId` is 0, so `getItemByProductId(0)` matches,
   and the server calls `PromptProductPurchase(player, 0)`. Guard `productId == 0` on both
   client and server.
5. **Max Players** is a Studio game setting, not code. Set it to match the booth count.
6. **World travel is dead** until each world exists as a real Place and its `placeId` is
   filled in `WorldConfig`.
7. **Security housekeeping:** the owner pasted a live Roblox Open Cloud API key into chat in
   the first session. It must be **rotated** in Creator Dashboard → Credentials before any
   use. Never commit a key; `create_products.py` reads `ROBLOX_API_KEY` from the
   environment. Grant the key the newer "Developer Products" and "Game Passes" scopes. The
   experience's dashboard URL id is `10439890130`. That's *probably* the Universe ID; the
   script prints the experience name to confirm before creating anything.

---

## 6. Verification status — READ THIS

**None of this Luau has ever been compiled, type-checked, or play-tested.** The cloud session
had no Studio, and running downloaded `rojo`/`luau-lsp` binaries was blocked there. It was
reviewed carefully by reading, and several bugs were caught that way, but expect some
errors. Your first job:

1. `rojo build -o DonationMMO.rbxlx` (or `rojo serve` + the Studio plugin), then play-test.
2. Fix every Output error. Likely trouble spots, by risk:
   - `ChatStyleController`: TextChatService config property names (wrapped in `pcall`, so it
     degrades quietly; verify it actually styles anything).
   - `ChatTagController`: the `OnIncomingMessage` PrefixText approach.
   - `CosmeticService`: hiding the default nameplate via `NameDisplayDistance = 0`.
   - `FallenPartsDestroyHeight` respawn, `CheckpointService` `PivotTo` on respawn.
   - `--!strict` type errors throughout (casts, `unknown` remote args).
3. Test with 2+ local players (Studio → Test → Clients and Servers) for booths, donation
   prompts, announcements, and chat tags.

---

## 7. The task: World 1 island lobby

**Booth count: 30**, with Max Players set to 30. A donation lobby lives on density: more
players means more potential donors in view of every booth. World 1 is also the most
populated world, and every player needs a booth. (Fix bug #2. Booths are what players
stand at, so 30 players need 30 booths.)

**Recommended direction** (adjust after seeing it in Studio):
- **Replace the floating sky plaza with a large island at sea level**, built with Terrain
  (`Workspace.Terrain:FillBlock/FillBall/FillCylinder/FillWedge`): sand beaches, grass,
  rock cliffs, and Terrain water for the ocean. Then move the kill height well below the sea
  floor (or keep it as a safety net); falling into water just means swimming back.
- **Layout:** spawn on a dock/pier, then a central plaza with a hero centerpiece
  (fountain/monument), then 30 booths along curved promenades, arcs, or a ring. Keep
  sightlines so a donor can see many booths at once. The prestige showcase goes near spawn,
  the Lobby Teleporter portal somewhere prominent, and obbies on offshore islets or floating
  rocks (a natural "explore the island" path). A lighthouse or lookout makes a good landmark.
- **World 1 is Gray**, so it should feel pleasant and approachable but clearly *below*
  Green, leaving headroom for every world above. Don't spend the Gold/Diamond look here.
- **Blender pipeline:** model hero props (centerpiece, booth shell, palms, rocks, lighthouse,
  dock) in Blender via `/use-blender` → export FBX/GLB → import with Studio's 3D Importer.
  That uploads the meshes. Then save the resulting models as `.rbxm` files *into the repo*
  (e.g. `assets/lobby/`) and map that folder in `default.project.json` to something like
  `ServerStorage.LobbyAssets`. That keeps the art in git. Make `WorldBuilderService` use
  those models when present and fall back to the current primitive builds when not, so the
  game never breaks without the assets.
- **Booth art:** if you replace the booth model, keep the stand model contract from
  section 4 so `StandService`/`DonationService` keep working.

**"Reward system worked into everything":** every activity on the island should feed XP and
progression, with visible feedback. Already rewarded: donating, receiving, obbies, quests, the
XP shop, VIP, and the Server Blessing. Add:
- **"+XP" popups** on the HUD for every gain (`XpChanged` already carries `gained` and
  `source`). This is the cheapest and biggest "juice" win.
- **Booth-duty/playtime XP:** a small XP grant every few minutes, bigger while standing at
  your own booth. That keeps players at their booths, which increases donations.
- **Daily login streak** with an escalating reward and a visible streak UI.
- **Exploration/discovery:** hidden landmarks around the island grant one-time XP, stored
  in the profile, with an "Explorer" quest line.
- Island-specific quests (visit the lighthouse, finish every islet obby, etc.).
- New profile fields go in `PlayerDataSchema.Default`. `Reconcile()` backfills existing
  players. **Don't** rename `ProfileStoreName` (that would wipe everyone's data).

**Verify visually.** Play-test in Studio, take screenshots, and fix the biggest visible
problem first. Work from multiple camera angles: spawn view, plaza, booth row, and the
obbies.

---

## 8. Repo conventions

- Luau files start with `--!strict` and a header comment explaining *why* the file exists.
  Comments explain reasoning, not mechanics.
- Commit to `claude/donation-mmo-progression-zx3kh8` and push with
  `git push -u origin claude/donation-mmo-progression-zx3kh8`. Don't open a PR unless the
  owner asks.
- `.gitignore` excludes `*.rbxl`/`*.rbxlx`, `sourcemap.json`, and `__pycache__/`.
- Be straight with the owner about what was and wasn't verified. They appreciated being
  told when reviewer suggestions were wrong instead of having everything rubber-stamped.

## 9. Session 2026-11-06 (local) — what changed

Done offline. Everything type-checks with luau-lsp; nothing has been play-tested in Studio yet.
- Bugs fixed: post-Celestial levels keep climbing (8,000 XP/level), so celestial_apex is reachable;
  STAND_COUNT 30; WorldSelect only rebuilds on level change; productId 0 guarded on client and
  server; ProcessReceipt now refuses to grant without a loaded profile and dedupes PurchaseIds;
  checkpoints clear on finish and expire after 10 minutes; Blessing stacks its duration instead
  of resetting it.
- Economy fix: XP Shop XP is fixed-rate (VIP only). Rank, world and Blessing multipliers no
  longer apply to it, so donating overtakes the shop around Gold, as the concept requires.
- Leaderstats: Rank / Donated / Raised (no raw level).
- Rewards: +XP popups for every gain, daily login streak (7-day track), playtime and booth-duty
  XP (daily-capped), 8 discoverable landmarks with "?" markers, Island Journal one-time quests
  (some unlock titles), public rank-promotion announcements, booth guide beam.
- World 1: src/server/World/IslandBuilder.luau builds a terrain island at sea level with 30
  booths, plaza and fountain, pier spawn, lighthouse, three islet obbies. It uses
  ServerStorage.LobbyAssets meshes when present, otherwise primitives.
- Art: art/blender/lobby_props.py → art/blender/out/lobby_props.glb (13 props). Import with
  File > Import 3D, then run in the command bar:
  require(game.ServerScriptService.Server.Dev.LobbyAssetImporter:Clone())()
  Then save ServerStorage.LobbyAssets to assets/LobbyAssets.rbxm and map it in
  default.project.json. Don't map it before that file exists, or Rojo will empty the folder.

### Later the same day (Studio session)
- Play-tested in Studio on the real experience (GameId 10439890130, place 83308240806095).
  Fixed the boot crash: FallenPartsDestroyHeight can't be set by scripts. It's now -200 in
  default.project.json.
- Blender props imported (uploaded as Fire Ablaze) → assets/LobbyAssets.rbxm, mapped to
  ServerStorage.LobbyAssets.
- Mobile: the letter buttons are replaced by src/client/Dock.luau, an icon + label dock.
  It's a single bottom row on short screens and a left column on tall ones. Panels are
  centered, one open at a time, with a close button, and scale to the viewport.
  Checked in the iPhone 17 Pro simulator, landscape and portrait.
- Still to do: set Max Players to 30 on Creator Hub (Configure → Places → server size);
  it's currently 60. Turn on Allow HTTP Requests if the gamepass auto-discovery
  (roproxy) should work. Publishing hasn't happened; the owner decides when.
