---
name: godot-party-authoring
description: Author or integrate GodotParty API 4 games, protocol packages and appearances in the complete framework project; use for lifecycle, networking, state commits, configuration and content publishing.
---

# GodotParty authoring

Work in the complete framework project. The formal app and development arguments share one connection and coordinator. There is no standalone SDK product.

The formal create flow selects a protocol, then a compatible main game, then opens the room. Joiners follow the host selection; the room binding cannot be changed in place. Keep core system settings and the persistent player_id separate from protocol-owned appearance preferences. Main-menu connection diagnostics remain available; do not restore a standalone protocol-selection button.

## Read only the relevant contract

Paths are relative to the project root.

- New minigame: doc/api/authoring.md and the chosen protocol package doc/.
- Exact signatures/errors: doc/api/reference.md, then core/api/party_api.gd or party_net.gd.
- Readiness, scope cleanup, generic/native networking: doc/api/api.md.
- Main-game state, reducers, durable results and recovery: doc/api/results.md.
- Configuration, custom panels and host-selected pools: doc/api/configuration.md.
- Package languages, Chinese fallback, translated metadata/settings and api.i18n: doc/api/localization.md. Selection is manual in the main menu and never synchronized with room rules.
- Exact participant counts and configuration-dependent start limits: doc/api/player_counts.md.
- Protocols and optional adapters: doc/api/protocols_and_briefing.md.
- Protocol-defined player configuration and assets: doc/api/avatars.md.
- Source/PCK delivery: doc/api/source_packages.md and doc/testing.md.

## Decisions that matter

- Use only current API 4. Do not recreate GPActivityRuntime, controller inheritance, compatibility aliases or old Resource activity definitions.
- setup runs before entering the tree; it cannot use @onready. Explicitly mark_ready after initialization. Simulation starts in party_start.
- Host owns final publication; authors choose local/host/mixed judgement. A spectator host still runs coordination and host game logic.
- finish OK accepts a candidate, not a durable reward. Main-game reducers are pure; never award again from round_committed.
- Economy belongs to the main game. Ranking is not a wallet settlement. Never invent resources or claim compatibility without implementing protocol semantics.
- One main game binds one protocol. A minigame can have multiple adapters, but only the selected adapter and its dependencies activate. Never preload an absent optional protocol.
- Appearance data and its editor belong to the protocol. Do not assume color, portrait or first/third-person fields unless its DOC defines them.
- Identity is player_id; peer_id is transport routing. Returned player/settings data are snapshots.
- Main controller/state persist across a foreground minigame; the view is released and rebuilt. Old scope callbacks must not mutate new games.
- Main games declare room_scene and own their lobby presentation through core/api/party_room_api.gd. Reuse documented public room scenes and framework panels; do not depend on private frontend nodes. Room activations close on rule changes and leaving. Optional minigames limits pool candidates; every declared pool must be nonempty before start.
- Use declared streams or native Godot RPC as appropriate. Sending is not remote acknowledgement; framework channel ownership still applies.
- Source and PCK use the same paths and runtime. Publish only after a clean host without author source/cache can run the package.
- Same-process content has ordinary Godot abilities. API correctness checks are not a security sandbox.

Use typed GDScript without :=. Keep public docs and protocol examples aligned with behavior.
Run the narrow tests for the changed boundary; separate automated checks from manual editor and external-network acceptance.

Windows host exports use core/dev/export_windows_host.ps1; the old Acceptance fixture was removed.
Exported templates do not run editor-only --script tests. Read doc/api/source_packages.md for delivery.
Native RPC is outside scope filtering. Stop author-owned senders before removal; native packets already
in flight can still produce engine path errors after cancellation. See doc/testing.md for tested boundaries.

## Layered settings and voice (4.1)

- For preferences, inherited input bindings, runtime effects or room edits, read doc/api/configuration.md first; for media/endpoints/routing read doc/api/voice.md. Exact signatures remain in implementation comments and doc/api/reference.md.
- Protocols own common preference semantics/defaults. Games independently inherit and override the selected protocol ID/major; a child never inherits the main game's overrides. Only explicit clear/unset restores inheritance; false, zero and empty bindings are valid overrides.
- Keep local preferences, RoomDraft, immutable RuleSnapshot and adapter request data separate. Never broadcast snapshot_effective or read new room rules when settling an old round.
- Preference persistence does not prove engine effects are applied. Respect apply stages and report unsupported/deferred effects without rewriting desired values.
- A settings runtime owns one activation. Enter before game tree insertion, attach after insertion, and clean up callbacks, players, buses and viewport changes in leave. Do not write Master or another scope's input actions.
- Voice routing is host-owned; local endpoints still require device consent and a registered bus. Only one protocol runtime or explicitly delegated game controls an endpoint. Never infer groups or distances from arbitrary business state.
- Read current manifest 2/declaration schema 3 only. Business-owned settings.gd exposes static schema() with fields and recursive layout; manifest config_schema points to that script. User files are JSON values, never UI declarations. Do not recreate legacy fields/defaults/input_actions, CFG readers or migration paths.
- For this increment, keep checks to relevant data and smoke paths. Four-player audio, real devices, weak networks, stress and clean exported-host acceptance are pending the original protocol stage.

## Original protocol

For GodotPartyDefault content, read games/protocols/godot_party_default_protocol/doc/README.md and only its relevant examples. Names use GodotPartyDefault; package IDs use godot_party_default_. The protocol owns the color/2D/3D appearance contract. Monetary grants and ordered collateral are main-authorized snapshots, not a wallet. The pure settlement helper does not persist or deduplicate applications; the parent reducer and core commit do that. Item effects need real mutual support; never execute arbitrary parent effects or invent collateral consent/valuation. Do not restore deleted demo games to demonstrate the protocol.

- Default-protocol graphics: read games/protocols/godot_party_default_protocol/doc/README.md. Reuse its settings runtime and view registration; do not duplicate quality exports or write the same viewport/global rendering properties from games. Lighting composition stays in game scenes; frame limit and VSync stay in core.

- Default-protocol appearance: the default 3D reference is godot_party_default_avatars/character_3d (Cube); the protocol depends on godot_party_default_avatars_2d for its six 2D avatars. Load appearances through PartyAPI, then apply the player's color. Games own movement, collision and networking. The default Cube has no animation API or native runtime dependency.

- Portable layout and presets: read doc/api/configuration.md. Avatar packs belong to their protocol and declare owner_protocol. Core retains player_id only; protocol profile.json owns display names/appearance. Install protocols, maingame and minigame in distinct root folders. Preset filenames are their names; load edits drafts, explicit Apply commits. Never calculate file hashes.

- Visual export lives in Project → Tools → GodotParty：导出可玩包. Declare loose payloads in manifest external_files (directory paths end in /), and resolve them with api.get_external_path. See doc/api/source_packages.md. Personal config/ is excluded from publication.
