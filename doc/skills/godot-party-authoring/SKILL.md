---
name: godot-party-authoring
description: Author or integrate GodotParty games, protocols, appearances and asset libraries in the complete framework project; use for lifecycle, networking, settings and content publishing.
---

# GodotParty content authoring

Use the complete project and its formal menu/lobby. Read root `AGENTS.md` for execution rules and only the contracts relevant to this task. Paths below are relative to the project root.

## Choose the contract

| Task | Read |
| --- | --- |
| New game or scene integration | [Game authoring](../../api/game_authoring.md), then the selected protocol and package `doc/` |
| Exact API signatures and errors | [API reference](../../api/party_api_reference.md), then the owning `core/api/` implementation |
| Readiness, cancellation and cleanup | [Activity lifecycle](../../api/activity_lifecycle.md) |
| RPC, channels, spawning and interpolation | [Networking](../../api/networking.md) |
| Main-game state, reducers and durable results | [Main-game state](../../api/main_game_state.md) |
| Preferences, room drafts, pools and presets | [Configuration](../../api/configuration.md) |
| Translation or participant limits | [Localization](../../api/localization.md), [player counts](../../api/player_counts.md) |
| Protocol, appearance or voice | [Protocols](../../api/protocols_and_briefing.md), [appearance](../../api/player_appearance.md), [voice](../../api/voice.md) |
| Source/PCK delivery or asset libraries | [Content packages](../../api/content_packages.md), [external resources](../../api/external_resources.md) |
| Validation or existing work | [Project validation](../../development/project_validation.md), package development notes via [task index](../../content/content_development.md) |

## Integration constraints

- `party_setup` runs before tree entry; do not use `@onready` there. Initialize, explicitly `mark_ready`, and start simulation in `party_start`. `party_stop` supports cancellation before setup/tree entry and repeated close.
- Technical readiness is separate from player confirmation. Stop author-owned input, simulation, timers and audio at the appropriate lifecycle boundary; native RPC is not filtered by PartyNet scopes.
- A spectator host still coordinates and runs host game logic. Identity is `player_id`; `peer_id` is transport routing. Returned player/settings data are snapshots.
- `finish` accepts a candidate, not a durable reward. Main-game reducers stay pure; never award again from `round_committed`. Preserve the current view on ordinary commits; rebuild only across foreground switches.
- A main game binds one protocol. Load only the selected adapter and its declared dependencies; do not preload absent optional protocols or all songs for discovery.
- Keep catalog definitions independent of gameplay/media. Use globally unique shared class names and declared dependencies. Runtime content must not reference excluded `authoring/` files.
- Local preferences, room drafts, frozen rules and adapter requests are separate. Main and mini games independently override protocol defaults. Voice routing and appearance semantics belong to their declared owners.
- Use public APIs and documented UI/resources. Do not restore old activity wrappers, private frontend dependencies, compatibility aliases or a standalone SDK.
- Follow the version notification rule in [content packages](../../api/content_packages.md): report the object, old/new version and reason when changing content/framework versions; builds do not automatically bump versions or change the user-owned Godot project version.

For original-protocol content, read [GodotPartyDefault](../../../games/protocols/godot_party_default_protocol/doc/godot_party_default_protocol_guide.md) and its relevant examples. Use package IDs prefixed `gp_` for minigames. The protocol owns graphics/audio integration, color and appearances; games own movement, collision and networking. Preserve unverified behavior as pending rather than treating historical checks as current acceptance.
