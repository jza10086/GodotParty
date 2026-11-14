# GodotParty Development Rules

## Priorities

- Build a practical indie-scale party game. Finish playable feature loops before refactoring or optimizing them.
- Follow the user-level coding instructions in `~/.codex/AGENTS.md` (injected into the session): scope, internal contracts, error propagation, abstraction, and testing. This file adds GodotParty-specific requirements; do not duplicate the general rules or introduce stricter defensive coding or testing by default.

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
- The user grants standing authorization for task-scoped Godot validation outside the Codex Windows sandbox under the normal Windows user. Use the system-PATH `godot` command, with `--headless --path <absolute-project-path>` for imports/script checks or `--path <absolute-project-path> --script ...` for graphical checks. In Codex tools, request `sandbox_permissions="require_escalated"` up front for these validations so the approved rules can run them without repeating the known sandbox certificate/cache failures. This is not a request for administrator privileges and does not authorize changing certificates, ACLs, engine installations, or project versions.
- User-level `~/.codex/rules/godotparty-godot.rules` covers the main project, the registered minigame paths and the existing jigsaw preview project. Use forward-slash absolute paths and the documented argument order so rules match; additional test projects or wrapper commands may need their own scoped approval. Prefer main-project scripts under `res://tmp/test/` for new checks. Test-owned scripts, logs, screenshots and data remain under the owning project's `tmp/test/`; do not disable certificate verification or shader caching to hide environment errors.
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

- Keep non-shipping development tools, editable prototypes and creative sources in package-local `authoring/`. Do not hide it with `.gdignore`; Godot must display and run its development scenes normally. Package-root `export_ignore.txt` uses case-sensitive Git ignore syntax (single root file) and fully replaces `core/content/default_export_ignore.txt` for source ZIPs, staging, PCKs and loose payloads; defaults exclude all `authoring/` directories. Authors own their exclusion list, and runtime files must not depend on excluded files. `.gdignore` controls Godot import only, not publication. See `doc/api/external_resources.md`.

- Keep confirmed non-redistributable external assets in project-root `third_party_assets/<license_type>/files/`, including downloads, extracted sources, converted copies and discovered duplicates. Keep each `files/` ignored by Git and the entire `third_party_assets/` ignored by Godot (`.gdignore`); track only registration documents and ignore rules. Each license category has a `<license_type>_assets.md` four-column table sorted alphabetically by asset name. Unresolved private references remain under ignored `private_assets/`; public packages must work without both directories.
- License project-owner/GPT original code under MIT and original media under CC0-1.0 as scoped in `ASSET_LICENSES.md`; preserve all third-party licenses, notices and unresolved provenance records. New independently exported content packages must include their license texts and scope.

- Record every externally downloaded art, font, music, sound, or other asset in `res://doc/assets/project_credits.md`.
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
- A playlist is an ordinary main-game package. The old thin test content has been removed; add protocol tests only for important behavior or concrete regression risks introduced by new content.
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
- Follow `doc/api/configuration.md` for portable paths, JSON settings schema 3, protocol-owned profiles and per-package presets. Core owns persistent player_id; protocol profiles own display names and appearances. Never resolve portable paths from cwd or user://.
- Keep settings local to each client. Do not synchronize physical input mappings over the network.
- Each game has one independent preference file. Reads never materialize inherited defaults; explicit Apply persists changes.
- Protocols define common local preferences and input actions. Main and mini games independently override the selected protocol ID; no parent-to-child inheritance. Room rules come only from host snapshots.
- Reuse common movement actions when suitable. Prefix genuinely game-specific actions, such as `shooter_fire` or `rhythm_hit`.
- Keyboard and mouse are the initial supported devices. Keep input-reading boundaries replaceable so gamepad support can be added later, but do not build gamepad behavior now.

## UI and resolution

- Use Memory Jigsaw as the standard in-game composition: full-viewport gameplay with a minimal edge-mounted overlay HUD. Do not shrink the playfield into a dashboard with permanent wide sidebars or title panels. Keep essential actions visible; reveal detailed rules, rankings, catalogs and settings on demand. Preserve each game's visual theme. The blank minigame game.tscn is the reference scene; see doc/api/game_authoring.md for the public menu and input contract.
- Design UI at 1920x1080. All visual testing, previews used for acceptance, screenshots, and manual or automated layout checks use only 1920x1080. Do not add other resolutions, ultrawide checks, or a resolution test matrix.
- Use `canvas_items` stretch mode, `expand` aspect, and fractional scaling for non-pixel-art UI.
- Use full-rect `Control` roots, anchors, and container nodes. Avoid absolute positioning for primary layouts.
- Anchor HUD elements to their intended corners or center. Design for additional horizontal space on ultrawide displays.
- Prefer dynamic fonts, SVG icons where suitable, and scalable style boxes or nine-patch textures.
- Keep user-selectable UI scale separate from render resolution when that setting is implemented.

## Testing and completion

- Follow the user-level testing rules and choose the smallest validation that answers a concrete question about this change. Complete related edits as one coherent batch before checking; check earlier only to resolve a blocker or a risky implementation assumption.
- Documentation and comments need only focused text review; simple configuration edits need only syntax and value checks. Do not launch the game, import the project, or add smoke tests for these changes. Never validate files with hashes.
- Reuse the relevant existing test for local logic changes. Add a test only for important behavior, complex rules, or a known regression; do not create tests for reversible low-impact edits, simple assignments, forwarding, framework behavior, or implementation details. Do not build a test framework, separate acceptance project, or large simulation for a small change.
- For changes to RPC validation, authority, readiness, disconnect handling, serialization, or cross-round state, select only the affected protocol/state checks. Run a host/client check only when peer communication is needed to verify the changed behavior; do not run a multiplayer suite merely because the project is multiplayer.
- Run integration or full-project checks only when a specific shared-dependency change, cross-module effect, or observed failure requires them. Completing a module, playable loop, commit, or delivery does not itself trigger more tests.
- Stop after the relevant checks pass. Repeat or broaden checks only after a relevant code/dependency/environment change, a failure, an unresolved concrete concern, or an explicit user request. Reuse results from the current task while their inputs remain unchanged; a commit or final summary alone is not a reason to rerun them.
- Use one suitable diagnostic route for each question. Successful inline MCP diagnostics can satisfy script parsing, but not runtime or multiplayer correctness; do not duplicate the same parse check through MCP, LSP, and CLI without a reason.
- Before an automated Godot validation batch, verify the intended engine using `godot --version`. The version check performed by `godot-project-tooling` already satisfies this requirement; do not add a separate duplicate version probe. Recheck when the engine selection changes.
- Use the console editor binary with `--headless --path <project> --import` for non-interactive project import and resource parsing.
- Run standalone GDScript checks with `--headless --path <project> --script res://path/to/test.gd`; add `--check-only` when only parsing is intended.
- Treat the process exit code plus `SCRIPT ERROR`, `ERROR`, and parser output as the result. Do not assume silence means success.
- Use Godot editor multi-instance features for human local multiplayer acceptance.
- For visual changes, use the existing preview and focused manual inspection at 1920x1080 only. Add numeric layout assertions only for explicit numeric requirements; do not create a visual test harness for a cosmetic adjustment.
- Feel, physics, timing, and multiplayer experience need focused manual editor acceptance when affected. Use a lightweight automated harness only when it answers a necessary question that existing checks cannot answer; it does not replace requested human acceptance.
- Report static checks, automated tests, runtime checks, and manual acceptance accurately and separately. Do not imply that local checks validate external networks or Steam.
- Keep investigation and output scoped: read changed files and direct dependencies first; use targeted searches, bounded logs, and incremental diagnostics instead of repeated repository scans or full scene dumps. For running checks, use completion-aware waits rather than frequent status polls. Summarize the result and relevant untested behavior briefly; do not generate a separate verification report unless requested.

## Git

- The user grants standing authorization, including future sessions, for task-scoped Git inspection, fetch, staging, commits and ordinary pushes in this repository and its minigame submodules registered in `.gitmodules`, provided their remotes belong to `jza10086` on GitHub. Do not ask again for these operations within the requested task. Preserve unrelated working-tree changes and never stage or publish them as part of the task.
- Use `git -C F:/GodotProjects/GodotParty ...` for the main repository and `git -C F:/GodotProjects/GodotParty/games/minigame/<id> ...` for submodules so the explicit repository command rules can match. Prefer the configured SSH remotes. Platform approval and managed sandbox restrictions still apply; this authorization does not override them.
- After relevant validation, commit and push affected minigame submodules first, then commit and push the main repository's updated submodule references and task changes. Default to `origin main`; use `push --recurse-submodules=on-demand origin main` for the main repository when appropriate. Recursive push does not commit uncommitted submodule changes.
- This authorization excludes unrelated changes, force pushes, destructive history rewrites, remote branch or tag deletion, remote URL changes, and bypassing branch protection. Remote URL changes require explicit task authorization. Permission-check tasks use `push --dry-run` unless actual publication is explicitly requested.
- Work directly on `main`; do not create feature branches unless the user changes this rule.
- Keep `main` runnable and commit coherent, describable functionality rather than every small edit.
- Use concise English imperative commit messages, for example `Add multiplayer lobby flow`.
- Never commit local user settings, generated import caches, credentials, or export credentials.

## Prototype compatibility policy

- Maintain only the current API and data formats. Remove superseded fields, aliases, migration readers and compatibility branches; update current callers and API documentation together. Keep external-input validation; invalid required resources must report failure instead of selecting a default resource.

## Framework content boundary

- When changing a content package or framework version, briefly notify the user of the affected object, old → new version, reason and any compatibility/re-export impact. Follow `doc/api/content_packages.md`; do not automatically bump versions for builds or ordinary edits, or change the user-owned Godot project version.

- Framework identity is declared in core/framework_version.gd, independently of the Godot project version. Follow `doc/api/content_packages.md` for manifest fields, dependencies, build_id, lazy loading and asset-library contracts. Never hash files for copying or verification. manifest.json is the only author-maintained catalog entry; music/chart folder layouts are author conventions, not validation rules.
- Games use public core/api and documented UI contracts. Minigames (including medium tags) live under games/minigame/<id>/; main games and playlists live under games/maingame/<id>/. Avatar packs belong to their protocol under games/protocols/<protocol_id>/avatars/<id>/; exported installs may keep that layout or use independent recognized package folders. Host code must not interpret game economy or maintain another activity runner.
- One top-level activity may start one foreground child with a participant subset; everyone else spectates, including the host when unselected. Only the host parent applies rewards.
- Same-process content has ordinary Godot script capabilities. Do not introduce source-publication requirements, code audits, sandboxes, system-function blacklists or permission wrappers in this iteration. Retain protocol/version/dependency/file-conflict correctness checks.

## Game author documentation

- Use `doc/project_index.md` as the document index. Keep package-specific documentation in its own `doc/` with `<package_id>_<purpose>.md` names. Maintain each rule in one owning topic and link to it; preserve unfinished work and necessary latest evidence. Keep conventional AGENTS.md, SKILL.md and license filenames.

- For game content authoring or API integration, read `doc/skills/godot-party-authoring/SKILL.md` and only its task-relevant references. Keep public interface documentation in sync with API changes.

## Temporary files

- Put all test scripts, scenes, fixtures, disposable acceptance projects and generated test data, logs, screenshots and caches under project-root tmp/test/. Keep tmp/.gdignore so Godot does not import temporary content. This directory is ignored by Git; do not create tests/ or temporary sibling projects. Retired tests are archived under tmp/test/archive/ and are not runnable acceptance criteria.

## Framework layout and development

- core/ owns framework code, scenes, UI and built-in assets; games/ owns installed content and protocols; doc/ owns documentation and author skill.
- The complete repository is the development environment. Use the real main menu/lobby; do not restore a standalone SDK, project generator or alternate development launcher.
- Keep addons/, tmp/, Git and MCP development configuration in their existing top-level locations. Tests belong only in tmp/test/.
