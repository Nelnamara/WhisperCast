# WhisperCast: Second Wind: rewrite scope (20 Nov 2026)

A standalone addon that CooldownCollaborator can use. A fresh rewrite of WhisperCast 3.2.3 (Valconeye, 2007,
Interface 20003); none of the old code carries over, only its design, trigger words and reply wording.
Reference copy read 20 Nov: WowInterface file 4795, `WhisperCast3.2.3.zip`.

## What it does
- Group members whisper a trigger word ("fort", "motw", "kings", "innervate", "summon", "poison"); the spell
  queues on them. Exact / starts-with / any-word matching; group members only; no duplicates per person.
- One Cast button or key casts the first request: a SecureActionButton whose macro (`/cast [@name] spell`) is
  set out of combat. Out of range, line of sight and cooldown put it back (4 tries, as before).
- Whisper replies (queued, cast, failed, cleared), the "wc" list reply, `/wc announce`, and its own replies
  and request whispers hidden through a chat filter (never by replacing the chat handler).
- Rank by target level on Era, TBC and Forever (as the original did); one spell list per client.
- Five clients from one folder, six TOCs like CDC: Era, TBC, MoP, Retail, Forever.
- The old trigger words in English, German, French, Korean and Chinese; the suite's 11 locales for the text.
- Settings, minimap button and a LibDataBroker launcher (Titan and the rest read it; no Titan plugin).
- Tests in the same fengari harness as CDC and CDTL3.

## What it can't do (every client, as in 2007)
- Cast by itself: every cast needs your key press.
- Change who the button casts on during combat (only out of combat can the macro be set).
- Retail and Forever: during chat messaging lockdown a whisper's text can be secret, so a request sent mid
  boss fight may not queue. To be checked in the game.

## For CDC
- A small public API: `WhisperCastSW:GetQueue()`, callbacks for queued / cast / cleared, and
  `WhisperCastSW:TriggerFor(spellID)` so CDC's Ask whispers a word the other player's copy understands.
- Between two players who both run it, the ask can also travel as an addon message, so it needs no chat
  parsing (subject to the same boss-fight limits as CDC's own messages).

## Look picks (20 Nov, WhisperCast Looks board https://claude.ai/artifact/4mXN13cT96EHhvSZWtnCu4)

Drawings in `tools/look-board/index.html` (section id = item); picks in the board's db collection `picks`.
His notes in quotes.
- Name: **WhisperCast: Second Wind** (folder `WhisperCast` since 21 Nov, "I also want the addon folder to just be called whispercast"; slash `/wc`).
- Overall look: no single pick: "All three. We should also have custom adjusters for all colors and opacity etc."
  So Blizzard classic, Suite dark and Flat modern are selectable looks, with colour and opacity settings.
- Queue window: Next up, big: "Next Up Big + Grouped by spell option (Enabled by default)".
- Cast key: Its own action button: "Its own action button by default, Button on the window as classic option."
- New request: Note by the window: "With glowing edge. The toast should be sizable with edit mode and movable".
  (Edit Mode through LibEditMode as in CDTL3; Era has no LibEditMode yet, so drag when unlocked there.)
- In combat: First one stays ready: "With a lock row - I like the number on option 3 best" (option 3 = Out of
  the way, whose count is the pink badge on the title).
- Replies: Short, with your place.
- Folded away: Round icon: "In/Out of combat settings and more custom options for icon. (Masque support?)"
- Trigger words: Word chips.
- CDC: Asks tab on CDC's panel: "The whispers as well." (CDC's Ask also whispers the right trigger word.)
