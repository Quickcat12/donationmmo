# Donation MMO (Roblox / Rojo)

**Start by reading `docs/HANDOFF.md`.** It holds the full game concept, the decisions the
owner has already made, the architecture, known bugs, and the current task (a World 1
island lobby with 30 booths, with the reward system worked into everything).

Quick facts:
- Rojo project: `src/shared` → `ReplicatedStorage.Shared`, `src/server` →
  `ServerScriptService.Server`, `src/client` → `StarterPlayerScripts.Client`. Workspace is
  not Rojo-managed; the map is generated at runtime by `WorldBuilderService`.
- None of the Luau has ever been compiled or play-tested. Build/serve with Rojo and fix
  Output errors before building new features on top.
- Work branch: `claude/donation-mmo-progression-zx3kh8`.
- Never commit API keys. Monetization IDs are filled in by
  `scripts/monetization/create_products.py`.
