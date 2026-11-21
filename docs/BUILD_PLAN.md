# Build plan (20 Nov 2026)

Schema first (done: Core.lua holds the saved settings, the module list, the callbacks and the request/view
contract), then three lanes at once, each owning its files only, then one integration pass, then CDC.

| Lane | Files it owns | Harness |
|---|---|---|
| Engine | Data.lua, Engine.lua, API.lua, Locales/enUS_Engine.lua | tools/tests/engine.lua |
| UI | Looks.lua, CastButton.lua, Window.lua, Toast.lua, Folded.lua, Minimap.lua, EditMode.lua, Media/*, Locales/enUS_UI.lua | tools/tests/ui.lua |
| Options | Chips.lua, Options.lua, Locales/enUS_Options.lua | tools/tests/options.lua |

Rules for every lane: touch only your files (Core.lua, the TOCs and wow.lua are the integrator's; add stubs a
harness needs inside your own harness file, after `dofile(HARNESS_DIR .. "/wow.lua")`); no git commits; no
installs into the game. Done = your harness and tools/tests/smoke.lua print `total lua errors 0` on all six TOCs
(`bash tools/tests/runall.sh`).

Slash words: Engine adds `announce`, `clear`, `on`, `off`, `status`; UI adds `toggle` (bare /wc), `show`, `hide`,
`fold`, `lock`, `unlock`, `reset`; Options adds `settings`.
