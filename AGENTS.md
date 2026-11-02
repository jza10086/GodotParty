# GodotParty Development Rules

## Priorities

- Build a practical indie-scale party game. Finish playable feature loops before refactoring or optimizing them.
- Do not introduce enterprise architecture, speculative abstractions, or framework layers without a current need.
- Prefer clear, direct code. Extract shared code only after stable duplication or a concrete reuse case appears.

## Editing and permissions

- Make safe edits that are clearly within the requested task without repeatedly asking for confirmation.
- If an edit or command is blocked by filesystem, sandbox, account, or operating-system permissions, stop the blocked operation and report the exact blocker to the user for guidance.
- Do not cycle through multiple privileged workarounds or repeated approval requests after a permission failure.
- Platform-required approval dialogs still apply and must not be bypassed.
- The user authorizes task-scoped deletions within this project after a Git recovery point is committed. Before deletion, verify every target file is recoverable from that commit; do not assume ignored or untracked files are backed up.
- If Godot MCP is disconnected, do not edit or delete project files. Resume only after MCP confirms the GodotParty project; do not switch to shell editing as a connection workaround.

## Godot editor tooling

- When the Godot editor and Godot MCP Toolkit are available, prefer its structured scene, node, resource, script, project-setting, and input-map tools over manual text or shell edits.
- Delete `.gd`, `.tscn`, and `.tres`/`.res` files with `script_delete`, `scene_delete`, and `resource_delete` respectively so their `.uid` companions are removed in the same operation. Use `file_delete` only for file types not covered by those typed tools.
- After an external file edit, call targeted `editor_refresh` with the affected `res://` paths, then `editor_wait_for_idle` before relying on editor state, global classes, scene data, or LSP results.
- Load on-demand MCP groups with `discover_tools` only when needed and reset unused groups after the task to keep tool context small.
- Keep `godot-project-tooling` as the canonical cold-start path for exact engine-version checks, complete headless imports, standalone GDScript checks, and version-control metadata audits when no live editor connection is required.
- Third-party code under `addons/` is exempt from this project's GDScript naming and typing style rules. Do not rewrite vendored plugins merely to match project-authored code style.

## Language and typing

- Use GDScript by default.
- Do not use `:=`. Declare types explicitly for member variables, local variables, parameters, return values, signals, arrays, and dictionaries whenever Godot supports it.
- When an API intentionally accepts several types, declare `Variant` explicitly instead of leaving the type implicit.
- Consider GDExtension or C# only after the profiler identifies a serious performance bottleneck and ordinary GDScript or algorithmic optimization is insufficient.

## Naming and files

- Use `snake_case` for scene, script, resource, function, variable, and signal names.
- Use `PascalCase` for node names, enums, and `class_name` declarations.
- Use `UPPER_SNAKE_CASE` for constants.
- Give `class_name` only to shared components, custom resources, core data types, and types that need editor-wide creation. Do not register every scene script globally.
- Organize files primarily by feature. Keep a feature's scene, script, and dedicated resources near each other.

## External assets

- Record every externally downloaded art, font, music, sound, or other asset in `res://doc/credits.md`.
- Follow the existing concise credits format: `类别：资产名称 来源 URL`.
- Keep required license files alongside the corresponding asset when redistribution terms require it.

## Scenes, dependencies, and architecture

- Prefer scene composition and small focused components over deep inheritance.
- Use `@export` for cross-scene dependencies, replaceable node references, and configurable resources.
- Use `%UniqueNode` for stable private implementation nodes owned by the same scene. Reserve `$NodePath` for trivial, stable private paths.
- Validate required exported references during startup. Do not silently continue with an invalid scene setup.
- Use custom `Resource` types for static configuration. Keep mutable runtime state in runtime objects or nodes; duplicate shared resource templates before mutation.
- Use Autoload only for truly global, cross-scene services. The formal app owns its connection and coordinator; PartyAPI is injected per scope, never an Autoload. Add another global service only for a demonstrated cross-scene need.
- `SignalBus` carries cross-scene notifications only. It must not store gameplay state or replace local signals.

## Comments and documentation

- At the top of a module, explain its responsibility and boundary when the purpose is not obvious.
- Use `##` documentation comments for public APIs and complex private functions.
- Explain a function's purpose, important inputs, output, side effects, and unusual constraints. Do not repeat obvious type annotations or narrate simple code line by line.
- Comments should explain why a decision exists, not merely restate what the code does.

## Game structure

- Support online multiplayer only. Do not add same-screen local multiplayer or AI players unless explicitly requested later.
- Support up to eight players, with four-player behavior as the primary development and balancing target.
- The primary mode is a large game, such as a board-game layer, containing tagged medium games and minigames.
- Medium games are ordinary minigames with a medium tag, not a distinct runtime type. Each main game binds one executable protocol package and named pools; hosts select compatible minigames, and authors own business semantics and rewards.
- A playlist is an ordinary main-game package. The old thin test content has been removed; protocol tests should accompany the new original content.
- Every minigame has its own state machine. Ordinary nodes implement party_setup, party_start and party_stop, with an injected PartyAPI and explicit mark_ready. Main-game controllers also expose state, view and pure reducer hooks.

## Networking

- Start with Godot's high-level multiplayer API and `ENetMultiplayerPeer` for editor-based local multi-client testing.
- After the base framework is stable, support direct IPv4 and IPv6 connections. Add Steam lobby, invitation, relay, or transport integration afterward.
- The host owns session coordination and final publication; activity authors choose local, host, or mixed computation and result rules. Generic streams and native Godot RPC, authority, spawners, and synchronizers may coexist.
- Choose synchronization according to gameplay needs. A turn-based card game may be fully host-controlled; a latency-sensitive rhythm game may judge locally and report results.
- Prioritize responsive client experience. Strict anti-cheat is not an initial requirement, but network messages must be validated enough to avoid crashes, invalid state, and protocol bugs.
- Send logical actions over the network, never physical key codes.
- The host selects the game ID and random seed. Clients report scene readiness; only the host starts play after all required clients are ready or a defined timeout occurs.
- In the initial implementation, remove disconnected players in the lobby, mark a disconnected active player withdrawn and let the activity decide ranking, and end the session if the host leaves. Do not implement reconnection or host migration yet.

## Input and local configuration

- Load input mappings when the game starts.
- Store core settings and persistent player_id in `core/config/settings.json`. User settings, profiles and room presets use JSON without CFG compatibility readers. Business settings.gd scripts declare schema 3 fields and recursive UI layout; user files persist values only. Resolve the portable root beside the project or executable through PartyInput.installation_directory(), never cwd or user://. Protocols, maingames and minigames install in separate root folders; local settings and named preset files live under each package config/. Protocol config/ is fixed; protocols declare config_directories for game override/preset subfolders. Player names and appearances belong to protocol config/profile.json. Core owns only identity, not avatar assets. See doc/api/configuration.md.
- Keep settings local to each client. Do not synchronize physical input mappings over the network.
- Each game has one independent preference file. Reads never materialize inherited defaults; explicit Apply persists changes.
- Protocols define common local preferences and input actions. Main and mini games independently override the selected protocol ID/major; no parent-to-child inheritance. Room rules come only from host snapshots.
- Reuse common movement actions when suitable. Prefix genuinely game-specific actions, such as `shooter_fire` or `rhythm_hit`.
- Keyboard and mouse are the initial supported devices. Keep input-reading boundaries replaceable so gamepad support can be added later, but do not build gamepad behavior now.

## UI and resolution

- Design UI at 1920x1080. Treat 2560x1440 and 3840x2160 as recommended validation resolutions.
- Use `canvas_items` stretch mode, `expand` aspect, and fractional scaling for non-pixel-art UI.
- Use full-rect `Control` roots, anchors, and container nodes. Avoid absolute positioning for primary layouts.
- Anchor HUD elements to their intended corners or center. Design for additional horizontal space on ultrawide displays.
- Prefer dynamic fonts, SVG icons where suitable, and scalable style boxes or nine-patch textures.
- Keep user-selectable UI scale separate from render resolution when that setting is implemented.

## Testing and completion

- Choose the smallest validation that answers a concrete question about the changed behavior. Complete related edits as one coherent batch before running checks; check earlier only to resolve a blocker or a risky implementation assumption.
- Documentation, comments, and other non-behavioral edits need only a focused text review. Simple configuration edits need only the relevant syntax or value check. Neither requires a game launch, full import, smoke test, file hashes, or a new test harness.
- For local gameplay logic changes, prefer the existing test for that feature. Add a focused regression test only when it protects a meaningful behavior; do not add tests that merely repeat implementation details or chase coverage.
- Changes to RPC validation, host/client authority, loading readiness, disconnect handling, serialization, or cross-round state require the relevant protocol/state regression checks. Add a host/client smoke check when the changed behavior depends on communication between peers; do not run every multiplayer suite for unrelated edits.
- At a completed module or playable loop, validate the affected integration path. Reserve full-project imports/checks for changes to shared dependencies, autoloads, global classes, asset imports, engine/plugins, or evidence of a project-wide regression; module completion alone does not require every suite.
- Stop after the relevant checks pass. Repeat or broaden checks only after a relevant code/dependency/environment change, a failure, an unresolved concrete concern, or an explicit user request. Reuse results from the current task while their inputs remain unchanged; a commit or final summary alone is not a reason to rerun them.
- Use one suitable diagnostic route for each question. Successful inline MCP diagnostics can satisfy script parsing, but not runtime or multiplayer correctness; do not duplicate the same parse check through MCP, LSP, and CLI without a reason.
- Before an automated Godot validation batch, verify the intended engine using `godot --version`. The version check performed by `godot-project-tooling` already satisfies this requirement; do not add a separate duplicate version probe. Recheck when the engine selection changes.
- Use the console editor binary with `--headless --path <project> --import` for non-interactive project import and resource parsing.
- Run standalone GDScript checks with `--headless --path <project> --script res://path/to/test.gd`; add `--check-only` when only parsing is intended.
- Treat the process exit code plus `SCRIPT ERROR`, `ERROR`, and parser output as the result. Do not assume silence means success.
- Use Godot editor multi-instance features for human local multiplayer acceptance.
- For UI, feel, physics, timing, and multiplayer experience, prioritize manual editor testing.
- Add focused automated tests for pure logic, configuration, serialization, networking protocol boundaries, and serious regressions when useful.
- The agent may choose lightweight launch scripts or automated debug harnesses for its own repeatable checks, but these must not replace the requested editor-based human acceptance.
- Report automated checks separately from manual multiplayer testing and real external-network or Steam validation.
- Keep investigation and output scoped: read changed files and direct dependencies first; use targeted searches, bounded logs, and incremental diagnostics instead of repeated repository scans or full scene dumps. For running checks, use completion-aware waits rather than frequent status polls. Summarize the result and relevant untested behavior briefly; do not generate a separate verification report unless requested.

## Git

- The user grants standing project-level authorization for task-scoped Git inspection, staging and commits in this repository, including future sessions. Do not ask again for ordinary Git operations within the requested task. This does not authorize unrelated changes, destructive history rewrites or remote publication.
- Use `git -C F:/GodotProjects/GodotParty add ...` and `git -C F:/GodotProjects/GodotParty commit ...` for local writes so the project's narrow command rules can match. Platform approval and managed sandbox restrictions still apply; this instruction does not override them.
- Work directly on `main`; do not create feature branches unless the user changes this rule.
- Keep `main` runnable and commit coherent, describable functionality rather than every small edit.
- Use concise English imperative commit messages, for example `Add multiplayer lobby flow`.
- Never commit local user settings, generated import caches, credentials, or export credentials.

## Prototype compatibility policy

- Maintain only the current API and data formats. Remove superseded fields, aliases, migration readers and compatibility branches; update current callers and API documentation together. Keep external-input validation; invalid required resources must report failure instead of selecting a default resource.

## Framework content boundary

- Framework 4.2.0 uses API 4, network protocol 16 and manifest format 2. manifest.json is the only author-maintained content catalog entry.
- Games use public core/api and documented UI contracts. Minigames (including medium tags) live under games/minigame/<id>/; main games and playlists live under games/maingame/<id>/. Avatar packs belong to their protocol under games/protocols/<protocol_id>/avatars/<id>/; exported installs use protocols/<protocol_id>/avatars/<id>/. Host code must not interpret game economy or maintain another activity runner.
- One top-level activity may start one foreground child with a participant subset; everyone else spectates, including the host when unselected. Only the host parent applies rewards.
- Same-process content has ordinary Godot script capabilities. Do not introduce source-publication requirements, code audits, sandboxes, system-function blacklists or permission wrappers in this iteration. Retain protocol/version/dependency/file-conflict correctness checks.

## Game author documentation

- For game content authoring or API integration, read `doc/skills/godot-party-authoring/SKILL.md` and only its task-relevant references. Keep public interface documentation in sync with API changes.

## Temporary files

- Put all test scripts, scenes, fixtures, disposable acceptance projects and generated test data, logs, screenshots and caches under project-root tmp/test/. Keep tmp/.gdignore so Godot does not import temporary content. This directory is ignored by Git; do not create tests/ or temporary sibling projects. Retired tests are archived under tmp/test/archive/ and are not runnable acceptance criteria.

## Framework layout and development

- core/ owns framework code, scenes, UI and built-in assets; games/ owns installed content and protocols; doc/ owns documentation and author skill.
- The complete repository is the development environment. Use the real main menu/lobby; do not restore a standalone SDK, project generator or alternate development launcher.
- Keep addons/, tmp/, Git and MCP development configuration in their existing top-level locations. Tests belong only in tmp/test/.
