# WhisperCast: Second Wind

A rewrite of WhisperCast 3.2.3 (Valconeye, 2007): group members whisper a word, the spell queues on them, one
key casts it. Standalone; CooldownCollaborator shows its queue on an Asks tab (CDC branch `whispercast-asks`).

- Start with `docs/DESIGN_HANDOFF.md` (governs every visual change), `docs/SCOPE.md` (the owner's look picks and
  notes, word for word), `docs/BUILD_PLAN.md`, and THE CONTRACT block at the top of `Core.lua`.
- Five clients from one folder, six TOCs (Era 11509, TBC 20506, MoP 50504, Retail 120105, Forever 16001 twice);
  `Libs\LibEditMode\embed.xml` in every TOC except `_Vanilla`. Libraries copied from cdtl3-dev.
- Files: Core (object, settings, modules, callbacks, slash) · Data (spells per client and class, ranks, words,
  `D.priority` for shared words) · Engine (queue, matching, replies, chat filters, ranks, combat arming) · API ·
  Looks · CastButton (secure `WhisperCastSWCastButton`, set out of combat only; a SecureHandlerWrapScript lets the
  armed request cast once in combat) · Window · Toast (note + sounds) · Folded · Minimap · EditMode · Chips
  (AceGUI `WCSW_Chips`) · Options · Welcome (the welcome window, its demo, the tour and checklist).
- Tests: `bash tools/tests/runall.sh` (smoke, engine, ui, options on all six TOCs; fengari from cdtl3-dev).
  LuaLS: `cd ../cdtl3-dev && LUALS=/opt/homebrew/bin/lua-language-server WOW_API_ANNOTATIONS=$HOME/.local/wow-api-annotations python3 tools/luals-check/run.py ../WhisperCast` — keep 0 warnings.
- Deploy to Forever: rsync to `/Applications/World of Warcraft/_forever_/Interface/AddOns/WhisperCast`
  excluding .git, docs, tools, CLAUDE.md, README.md, .pkgmeta, .gitignore and the source art (Media/*.png,
  Media/whispercast-art.jpg). Icons: Media/icon.tga (AddOns list), minimap.tga, logo.tga, cut by tools/icon-board/make.py.
- Commits as Nelnamara <gwilkins@local>, no Co-Authored-By trailer. GitHub: https://github.com/Nelnamara/WhisperCast (public, as all his addons are; `main`, HTTPS remote; created 21 Nov at the owner's ask).
