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

## Scenes, dependencies, and architecture

- Prefer scene composition and small focused components over deep inheritance.
- Use `@export` for cross-scene dependencies, replaceable node references, and configurable resources.
- Use `%UniqueNode` for stable private implementation nodes owned by the same scene. Reserve `$NodePath` for trivial, stable private paths.
- Validate required exported references during startup. Do not silently continue with an invalid scene setup.
- Use custom `Resource` types for static configuration. Keep mutable runtime state in runtime objects or nodes; duplicate shared resource templates before mutation.
- Use Autoload only for truly global, cross-scene services. Current intended services are `NetworkManager`, `GameSession`, `SignalBus`, `SceneRouter`, `AudioManager`, and `SaveManager` when each becomes necessary.
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
- Medium games are longer, may retain cross-round state, and may award larger rewards to the large game.
- The secondary mode is a continuous medium-game/minigame playlist. Build this mode first as the networking and framework test bed.
- Every minigame has its own state machine. A shared `MinigameController` contract coordinates prepare, countdown, start, finish, results, and cleanup without dictating internal gameplay states.

## Networking

- Start with Godot's high-level multiplayer API and `ENetMultiplayerPeer` for editor-based local multi-client testing.
- After the base framework is stable, support direct IPv4 and IPv6 connections. Add Steam lobby, invitation, relay, or transport integration afterward.
- Use a host-authoritative session, but let each minigame declare its synchronization policy through the framework interface.
- Choose synchronization according to gameplay needs. A turn-based card game may be fully host-controlled; a latency-sensitive rhythm game may judge locally and report results.
- Prioritize responsive client experience. Strict anti-cheat is not an initial requirement, but network messages must be validated enough to avoid crashes, invalid state, and protocol bugs.
- Send logical actions over the network, never physical key codes.
- The host selects the game ID and random seed. Clients report scene readiness; only the host starts play after all required clients are ready or a defined timeout occurs.
- In the initial implementation, remove disconnected players in the lobby, rank a disconnected active player last or withdrawn, and end the session if the host leaves. Do not implement reconnection or host migration yet.

## Input and local configuration

- Load input mappings when the game starts.
- Store common user settings in `user://settings.cfg` using `ConfigFile`.
- Keep settings local to each client. Do not synchronize physical input mappings over the network.
- Each minigame has an independent configuration file. Generate it on first entry if missing and load it directly on later entries.
- A minigame action mapping takes precedence; if it does not define the requested action, fall back to the global mapping.
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

- Do not add excessive tests during small iterations.
- Test after a complete module or playable loop is assembled.
- Before automated Godot checks, run `godot --version` and require the project's intended engine version.
- Use the console editor binary with `--headless --path <project> --import` for non-interactive project import and resource parsing.
- Run standalone GDScript checks with `--headless --path <project> --script res://path/to/test.gd`; add `--check-only` when only parsing is intended.
- Treat the process exit code plus `SCRIPT ERROR`, `ERROR`, and parser output as the result. Do not assume silence means success.
- Use Godot editor multi-instance features for human local multiplayer acceptance.
- For UI, feel, physics, timing, and multiplayer experience, prioritize manual editor testing.
- Add focused automated tests for pure logic, configuration, serialization, networking protocol boundaries, and serious regressions when useful.
- The agent may choose lightweight launch scripts or automated debug harnesses for its own repeatable checks, but these must not replace the requested editor-based human acceptance.
- Report automated checks separately from manual multiplayer testing and real external-network or Steam validation.

## Git

- Work directly on `main`; do not create feature branches unless the user changes this rule.
- Keep `main` runnable and commit coherent, describable functionality rather than every small edit.
- Use concise English imperative commit messages, for example `Add multiplayer lobby flow`.
- Never commit local user settings, generated import caches, credentials, or export credentials.
