---
name: godot-party-authoring
description: Author or integrate GodotParty games, protocol packages and appearances in the complete framework project; use for lifecycle, networking, state commits, configuration and content publishing.
---

# GodotParty authoring

Work in the complete framework project. The formal app and development arguments share one connection and coordinator. There is no standalone SDK product.

The formal create flow selects a protocol, then a compatible main game, then opens the room. Joiners follow the host selection; the room binding cannot be changed in place. Keep core system settings and the persistent player_id separate from protocol-owned appearance preferences. Main-menu connection diagnostics remain available; do not restore a standalone protocol-selection button.

## Read only the relevant contract

Paths are relative to the project root.

- New minigame: doc/api/authoring.md and the chosen protocol package doc/.
- Exact signatures/errors: doc/api/reference.md, then core/api/party_api.gd or party_net.gd.
- Readiness and scope cleanup: doc/api/api.md. Network design and native examples: doc/api/networking.md.
- Main-game state, reducers, durable results and recovery: doc/api/results.md.
- Configuration, custom panels and host-selected pools: doc/api/configuration.md.
- Package languages, Chinese fallback, translated metadata/settings and api.i18n: doc/api/localization.md. Selection is manual in the main menu and never synchronized with room rules.
- Exact participant counts and configuration-dependent start limits: doc/api/player_counts.md.
- Protocols and optional adapters: doc/api/protocols_and_briefing.md.
- Protocol-defined player configuration and assets: doc/api/avatars.md.
- Source/PCK delivery: doc/api/source_packages.md and doc/testing.md.
- Author export exclusions and loose resources (rhythm song examples and pending distribution choices): doc/api/external_resources.md.

## Decisions that matter

- Use only the current public API. Do not recreate GPActivityRuntime, controller inheritance, compatibility aliases or old Resource activity definitions.
- setup runs before entering the tree; it cannot use @onready. party_stop must be safe before setup/tree entry and on repeated close; release only initialized resources. Explicitly mark_ready after initialization. Simulation starts in party_start.
- Host owns final publication; authors choose local/host/mixed judgement. A spectator host still runs coordination and host game logic.
- finish OK accepts a candidate, not a durable reward. Main-game reducers are pure; never award again from round_committed.
- Economy belongs to the main game. Ranking is not a wallet settlement. Never invent resources or claim compatibility without implementing protocol semantics.
- One main game binds one protocol. A minigame can have multiple adapters, but only the selected adapter and its dependencies activate. Never preload an absent optional protocol.
- Independent PCKs support direct `class_name` references: the exporter records package-owned types and the loader registers the merged core/content types before parsing content. Use globally unique names for shared types, declare cross-package dependencies, and finish editor imports before export. Validate changed types through room creation and affected game entries in an exported EXE; see doc/api/source_packages.md for descriptor upgrades.
- Appearance data and its editor belong to the protocol. Do not assume color, portrait or first/third-person fields unless its DOC defines them.
- Identity is player_id; peer_id is transport routing. Returned player/settings data are snapshots.
- Main controller/state persist across a foreground minigame; the view is released and rebuilt only across foreground activity switches. Ordinary commits restore authoritative state and emit state_committed while retaining the view; update its existing controls. Main entries do not implement a required get_state hook. Old scope callbacks must not mutate new games.
- Protocols, main games and minigames declare metadata in package-root definition.gd (extends RefCounted, static party_definition). Keep it independent of gameplay scripts, scenes and media so catalog scans stay lightweight. game.tscn loads only when the activity starts; protocol.gd is only the runtime entry, loaded on first use.
- Main games provide room.tscn and own their lobby presentation through core/api/party_room_api.gd. Reuse documented public room scenes and framework panels; do not depend on private frontend nodes. Room activations close on rule changes and leaving. Optional minigames limits pool candidates; every declared pool must be nonempty before start.
- Use native @rpc or PartyNet with call-site reliability. Do not declare streams/native_channels. Send only necessary data; send discrete data once and animate locally. Never periodically broadcast whole gameplay/world snapshots. Read doc/api/networking.md for channel ownership, native spawning, input rates and interpolation.
- Source and PCK use the same paths and runtime. Publish only after a clean host without author source/cache can run the package.
- Same-process content has ordinary Godot abilities. API correctness checks are not a security sandbox.
- All manifests use name, kind, package_version, framework_version, remark (empty allowed), supported_languages (currently ["zh-CN"]), and optional dependencies. IDs and avatar ownership come from directories. Framework 0.0.1 is declared separately in core/framework_version.gd; never modify the user-owned Godot project version. Dependency ranges support exact, ~ and ^. Published startup reads descriptors only; PCKs and full resource indices load on first use. Whole-package Hash is removed; joins compare cached versions and random build_id across Windows, Android and iOS. Build IDs do not verify file bytes. Editor runs load sources directly without building PCKs or computing package hashes; internal editor peers compare framework/package versions and dependencies. Editor and published peers cannot connect. See doc/api/source_packages.md.

Use typed GDScript without :=. Keep public docs and protocol examples aligned with behavior.
Run the narrow tests for the changed boundary; separate automated checks from manual editor and external-network acceptance.

Windows host exports use core/dev/export_windows_host.ps1; the old Acceptance fixture was removed.
Android exports use core/dev/export_android.ps1 through the Android export menu. Content stays in independent PCKs, installed from a platform-specific ZIP into private application storage before class registration. Touch emulates the left mouse button; keyboard-dependent games need their own mobile controls. See doc/api/source_packages.md for APK and content-only updates.
Exported templates do not run editor-only --script tests. Read doc/api/source_packages.md for delivery.
Native RPC is outside scope filtering. Stop author-owned senders before removal; native packets already
in flight can still produce engine path errors after cancellation. See doc/testing.md for tested boundaries.

## Layered settings and voice (4.1)

- For preferences, inherited input bindings, runtime effects or room edits, read doc/api/configuration.md first; for media/endpoints/routing read doc/api/voice.md. Exact signatures remain in implementation comments and doc/api/reference.md.
- Protocols own common preference semantics/defaults. Games independently inherit and override the selected protocol ID; a child never inherits the main game's overrides. Only explicit clear/unset restores inheritance; false, zero and empty bindings are valid overrides.
- Keep local preferences, RoomDraft, immutable RuleSnapshot and adapter request data separate. Never broadcast snapshot_effective or read new room rules when settling an old round.
- Preference persistence does not prove engine effects are applied. Respect apply stages and report unsupported/deferred effects without rewriting desired values.
- A settings runtime owns one activation. Enter before game tree insertion, attach after insertion, and clean up callbacks, players, buses and viewport changes in leave. Do not write Master or another scope's input actions.
- Voice routing is host-owned; local endpoints still require device consent and a registered bus. Only one protocol runtime or explicitly delegated game controls an endpoint. Never infer groups or distances from arbitrary business state.
- Use the current six-field manifest plus optional dependencies and settings schema 3. Business-owned settings.gd exposes static schema() with fields and recursive layout; The filename is fixed. User files are JSON values, never UI declarations. Do not recreate legacy fields/defaults/input_actions, CFG readers or migration paths.
- For this increment, keep checks to relevant data and smoke paths. Four-player audio, real devices, weak networks, stress and clean exported-host acceptance are pending the original protocol stage.

## Original protocol

For GodotPartyDefault content, read games/protocols/godot_party_default_protocol/doc/README.md and only its relevant examples. Minigame root folders and package IDs use gp_ followed by a concise English game name or abbreviation; they must match. Existing protocol and main-game IDs retain godot_party_default_. The protocol owns the color/2D/3D appearance contract. Monetary grants and ordered collateral are main-authorized snapshots, not a wallet. The pure settlement helper does not persist or deduplicate applications; the parent reducer and core commit do that. Item effects need real mutual support; never execute arbitrary parent effects or invent collateral consent/valuation. Do not restore deleted demo games to demonstrate the protocol.

- Default-protocol graphics: read games/protocols/godot_party_default_protocol/doc/README.md. Reuse its settings runtime and view registration; do not duplicate quality exports or write the same viewport/global rendering properties from games. Lighting composition stays in game scenes; frame limit and VSync stay in core.

- Default-protocol appearance: the default 3D reference is godot_party_default_avatars/character_3d.tscn (Cube); the protocol depends on godot_party_default_avatars_2d for its six 2D avatars. Load appearances through PartyAPI, then apply the player's color. Games own movement, collision and networking. The default Cube has no animation API or native runtime dependency.

- Portable layout and presets: read doc/api/configuration.md. Avatar packs belong to their protocol and derive ownership from their directory. Core retains player_id only; protocol profile.json owns display names/appearance. Installed package folders are recognized by content.pck.json, independently of physical category names; packs may list multiple PCK files. Config paths retain their existing category/ID namespaces. Preset filenames are their names; load edits drafts, explicit Apply commits. Package build identities are generated at export; do not hash files for development copying/download verification.

- Visual export has three entries in Project → Tools: GodotParty：导出 Windows 可玩包, GodotParty：导出 Android 可玩包 and GodotParty：导出 iOS 可玩包. All scan package manifests and use independent protocol/avatar/asset/main/minigame checkboxes and an output directory; omit core for content-only updates. export_job.ps1 runs independently of the editor and records job-result.json/export.log. Android and iOS share export_mobile_content.ps1; mobile app versions come from the user-owned project.godot, written only into build copies. Place formal loose payloads under external/ for automatic collection, and resolve them with api.get_external_path. See doc/api/source_packages.md. Personal config/ is excluded from publication.

iOS export uses core/dev/export_ios_cloud.ps1 and GitHub macOS/Xcode builds. It builds the pushed HEAD and selected package IDs, not uncommitted local sources. The IPA requires SideStore re-signing; player data lives in the app sandbox. See doc/api/source_packages.md.

- Original content keeps non-shipping creative sources, candidate audio/images and offline generators in package-local `authoring/`. Do not place `.gdignore` there: keep development scenes visible and runnable in the Godot editor. Package-root `export_ignore.txt` fully replaces the defaults in `core/content/default_export_ignore.txt`; an empty file disables default exclusions. Defaults exclude `authoring/` at all depths, but authors own their publication list. Source ZIPs, PCK staging and loose payloads share the rules. `.gdignore` only controls engine import, not publication. Keep one canonical runtime input per logical asset; preserve its `.import` settings and UID. Shared assets belong to declared dependencies. Keep formal loose runtime data in `external/`, licenses with shipped assets, and tests under `tmp/test/`. Read doc/api/external_resources.md and the resource development section in doc/api/authoring.md before adding or reorganizing media. Runtime `core/ui/source/` is not an authoring directory.

- Asset packages: games/assets/<id>/ uses a six-field manifest (name, kind, package_version, remark, framework_version, supported_languages); directory identity, exact framework version, no platform or package dependencies. Assets may contain code/media/docs and reference only themselves or public core content. Games/protocols declare dependency ranges and reference paths directly. Original UI lives in godot_party_default_ui 0.0.1; protocol coordination stays in the protocol.
