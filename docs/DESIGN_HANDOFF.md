# WhisperCast: Second Wind: Design Handoff (20 Nov 2026)

Every visual build follows this file. The drawings are the look board
(`tools/look-board/index.html`, published at https://claude.ai/artifact/4mXN13cT96EHhvSZWtnCu4); sizes and colours
below come from it. The owner's picks and notes are in `SCOPE.md`. Anything this file doesn't settle is a question
for the owner, not a builder's call.

## Identity
- Title "WhisperCast: Second Wind" (TOC `## Title: |cFFFF80FFWhisperCast|r: Second Wind`). Folder and TOC base
  `WhisperCast` (the owner, 21 Nov: the folder is just WhisperCast; it was `WhisperCastSecondWind`). AceAddon and global object `WhisperCastSW`; saved variables `WhisperCastSWDB`.
- Slash `/wc` and `/whispercast`. Reply prefix `[WC]`. Addon message prefix `WCSW`.
- Accent: whisper pink `#ff80ff` (1, 0.5, 1). Everything pink below means the accent colour setting.
- Addon list icon: a game icon (`Interface\Icons\Spell_Holy_WordFortitude`) until the owner picks art.

## The queue window
Default 260 px wide, scale 1.0, movable when unlocked and in Edit Mode, position saved per Edit Mode layout.
- **Title bar** (20 px): the name in the accent colour, then right-aligned: a count badge (pink pill, 16 px
  high, dark text; shown when the queue has anything), a fold button (folds to the round icon) and a close button.
  In combat a small red "IN COMBAT" label follows the name.
- **Next up** (the spotlight): 44 px icon of the first request's spell, then three lines: "NEXT · <key>" (10.5 px,
  note grey, upper case), the asker's name (15 px, class colour), the spell name with rank on ranked clients
  (12 px, light grey). A green or red range dot after the spell when it can be read.
- **The rest**, under a small "THEN" heading:
  - **Grouped by spell** (on by default): one row per spell (3 px accent bar, 18 px icon, spell name, count at the
    right), then the askers' names in class colours on one wrapping line. When two or more askers of one spell
    share a party and a group version exists (Era, TBC, Forever), a yellow hint line: "All N in group G: <group
    spell> covers them", and the group spell becomes the cast for those askers (one cast, all answered).
  - **Grouped off**: one row per request (3 px class-colour bar, 14 px icon, name in class colour, spell, waited
    time, range dot).
- The window grows with the queue up to 10 rows under the spotlight, then "+N more".
- **Empty**: the spotlight says "No requests" with the logo icon greyed; the window follows its show rule.
- **Glowing edge**: while anything waits, the window edge glows in the accent colour (soft outer glow, 2 px
  edge); it stops when the queue empties. A setting turns it off.
- **Classic buttons** (the "Button on the window" option, off by default): Cast (with the key) and Clear along
  the bottom, red game buttons, as in the board's Cast key choice 1.

## Looks (all three, a setting) and colour adjusters
Drawn exactly as the board's Overall look item:
- **Suite dark** (default): background rgba(13,13,20,0.9), 1 px edge rgba(140,89,140,0.85), 4 px corners, title
  divider rgba(110,77,128,0.6), class-colour row bars.
- **Blizzard classic**: dark brown gradient (#2a1d12 to #120b06), 2 px gold edge #b8902f with a 1 px #4f3a14 inner
  line, the title centred in gold #ffd100 on a plate #3b2412, red game buttons.
- **Flat modern**: background rgba(6,6,8,0.84), no frame, a 2 px accent line across the top, flat rows with
  rgba(255,255,255,0.04), no row bars, outline buttons in the accent colour.
Colour and opacity settings, per profile, each starting from the chosen look's values: background colour and
opacity, edge colour and opacity, title colour, accent colour (badge, glow, toast edge, armed outline, row
highlight), font size (10 to 16), window scale (0.6 to 2.0), and "Reset to the look's colours".

## The Cast button (its own action button, the default)
- 40 px square, Masque group "WhisperCast: Second Wind" / "Cast button". Wears the next spell's icon, the bound
  key top-right, the count bottom-right, and (a setting, on) the asker's name in class colour and the spell
  under it. Pink glow while something waits. Empty: the logo icon at 40% opacity (a setting can hide it instead).
- Movable when unlocked and in Edit Mode; size 24 to 64.
- One key binding, "Cast the next request" (Key Bindings › WhisperCast: Second Wind), bound to this button. With
  the classic option the window's Cast button uses the same binding.
- **How a cast is set up**: a secure action button, `type = "spell"`, `spell = <the rank's spell ID>`,
  `unit = <the asker's party or raid unit>`, set only out of combat, every time the queue changes. Clicking casts
  it; the request is answered on `UNIT_SPELLCAST_SUCCEEDED` for that spell, and failures come back through the
  error messages, as in 2007 (out of range, line of sight and not in party count as a try, 4 tries; cooldown puts
  it back without a try).

## In combat ("First one stays ready", with a lock row and the badge)
- When combat starts, the first request stays on the button. One press casts it; a secure wrap on the button
  clears its `type` after that click, so a second press does nothing. Out of combat the button is set up again.
- The window shows: the title's "IN COMBAT" label and count badge; the armed request in the spotlight with a pink
  outline and a "<key> READY" tag (after its press: "CAST" greyed); then the lock row, "Casts wait until the
  fight ends" (red tint, lock mark); then the rest greyed with "after" in place of the waited time.
- Requests that arrive in combat queue normally and reply "after this fight" (see Replies).
- Settings: the window in combat shows, fades (opacity slider) or hides; the lock row on or off.

## When a request comes in (note by the window, with the glowing edge)
- A note (toast) 260 x 40 at scale 1: dark background rgba(10,10,18,0.94), 3 px accent edge on the left, 24 px
  spell icon, "<Name> asks for <Spell>" (name in class colour). It shows for 3 s (a setting, 1 to 10) and fades.
  Several in a row stack downward, up to 3.
- Its own place: anchored beside the window by default; movable and sizable (scale 0.5 to 2) when unlocked and
  in Edit Mode (LibEditMode, as CDTL3: every client except Era, where it moves only when unlocked).
- A sound on each new request, from the same checked Blizzard sound list as CDTL3 plus LibSharedMedia sounds;
  default the 2007 behaviour, one sound only when the queue goes from empty to one.
- The window's glowing edge as above.

## Folded away (the round icon)
- 34 px round icon (size 20 to 64), Masque group "WhisperCast: Second Wind" / "Folded icon". Pink count badge
  top-right; glows while something waits. Left-click opens the window, right-click opens settings, drag moves it
  (unlocked or Edit Mode).
- Settings: what it shows (the logo, or the next request's spell icon), the badge on or off, the glow on or off,
  a ring border on or off, opacity out of combat and in combat (0 to 1 each), and when it shows: always, only
  while folded, or only while something waits.
- The fold button on the window folds to it; it remembers folded across reloads.

## Replies ("Short, with your place")
Ordinary whispers, so they reach players without the addon. Exact text (enUS):
- queued: `[WC] %s: you're %s in line.` (spell, 1st/2nd/3rd...)
- queued in combat: `[WC] %s: you're %s in line, after this fight.`
- already queued: `[WC] %s: you're already %s in line.`
- casting: `[WC] %s coming now.`
- couldn't reach them, first try only (out of range, line of sight; added 21 Nov at the owner's walk note): `[WC] %s: couldn't reach you (%s). You're still in line.`
- failed for good: `[WC] Couldn't cast %s on you (%s). Whisper again to retry.`
- cleared: `[WC] Your %s request was cleared.`
- not taking requests: `[WC] Not taking requests right now.`
- the "wc" whisper: `[WC] Whisper me one of: %s` (each spell's first word, comma separated; two lines at most).
- `/wc announce` to party or raid: `Whisper me for buffs: %s. Whisper "wc" for the list.`
Settings: replies on or off; hide my [WC] whispers from my chat (on); hide the request whispers from my chat (off).

## Trigger words (word chips)
Settings › Spells and words: every spell the character knows, its 22 px icon and name, then its words as chips
(pink-tinted pills, × removes) and a "+ word" chip that opens a one-line box. A tick per spell turns requests for
it on or off. Each spell's own name (in the client's language) always works as a word, so "Innervate on me
please" from CooldownCollaborator queues Innervate. Matching (the 2007 choice): the whole whisper, its first
words (default), or any words in it. "Reset words" per spell.

## Settings layout (AceConfig, one window, tabs)
General (on/off, matching, group members only, replies, hide whispers, announce, lock/unlock frames) · Spells and
words · Window (look, colours and opacity, scale, font size, grouped by spell, classic buttons, show rules out of
and in combat) · Cast button (size, label, empty look, key binding) · Alerts (note on/off, time, scale, sound,
glow) · Folded icon · Profiles (AceDBOptions).

## CooldownCollaborator
- **Asks tab** on CDC's panel when WhisperCast: Second Wind is loaded: the queue drawn in CDC's own row style
  (next request first, then grouped by spell when that setting is on), with a Cast button that is a second
  secure button set up by Second Wind (`WhisperCastSW:CreateCastButton(parent)`), and the count as a badge on the
  tab.
- **The whispers as well**: CDC's Ask already whispers "<Spell> on me please"; Second Wind matches the spell's own
  name, so it queues with no change on CDC's side. CDC may use `WhisperCastSW:TriggerFor(spellID)` when it wants
  the shortest word.

## The welcome window, the demo and the tour (21 Nov; picks in SCOPE.md, drawings in tools/welcome-board)
Welcome.lua and Locales/enUS_Welcome.lua. Every client.
- **The window** `WhisperCastSWWelcome`: 440 x 430, DIALOG strata, centred, dragged by its title, Esc closes it.
  Fill, edge, title colour and accent from the Overall look, as the queue window. Title "WhisperCast: Second Wind"
  then the version in note grey; a close x. Under the title three text tabs, **Welcome · The story · What's
  new** (12 px; the chosen one in the accent colour with a 2 px accent line under it, the others note grey).
  Along the bottom: **Take the tour** (left) and **Close** (right), game buttons.
- **Welcome tab**: the demo (below), then "What it is": `Your group whispers you a word like "motw"; the spell
  queues on them and one key casts it.` After the tour has run once, the checklist sits under it.
- **The demo** (the loop, with steps): a 408 x 150 panel (black at 35%) drawn from the addon's own pieces in the
  current look: three chat lines (top left), a small queue window (title, pink count badge, Next up spotlight,
  glowing edge), the note ("Thornwick asks for Mark of the Wild", accent edge on the left) and the Cast button
  (32 px, the bound key top-right, "F" when none is bound). Under the panel three step labels, **1 They whisper ·
  2 It queues · 3 You press <key>**; the current one in the accent colour, the others note grey. One 8 s loop:
  0.8 s the whisper line shows (step 1); 2.0 s the request queues: spotlight, badge, glow, the note and the
  button's icon and glow (step 2); 4.6 s the button is pressed (step 3); 5.0 s the reply line "To [Thornwick]:
  [WC] Mark of the Wild coming now." shows and the note fades; 5.6 s the window empties ("No requests"); 7.4 s
  the chat lines fade; again. It runs only while the Welcome tab is showing (OnUpdate on the panel, as CDTL3's
  samples). The asker and spell are the same on every client (a sample, not the player's spells).
- **The story tab**: "Where it came from" (accent, 13 px) and the owner's history text, scrolling (12 px).
- **What's new tab**: "New since 2007" with the version, then one line each with an accent dot. The 1.0.0 lines
  are the board's eight; on Mists and Retail (no group buffs) the second line drops "one group buff when two in a
  party ask". A later version adds its own block above.
- **The tour** (on the real frames): a note `WhisperCastSWTour`, 300 wide, in the window's look: "<n> of 3 ·
  <title>" in the accent, the text, three dots, its buttons, a skip x. An accent edge with a soft glow
  (`WhisperCastSWTourMark`) rings the frame the step is about; the note sits beside it, kept on screen.
  1. **Your queue window** (the window, shown for the tour): "Requests line up here, next one first. Drag it by
     its title where you like." Frames are unlocked for this step and locked again after it (unless they were
     already unlocked). Next.
  2. **Your Cast key** (the Cast button; the window when the button is hidden): "This button casts the next
     request. Give it a key you can reach in a fight." and "Your key: F" or "No key yet." **Set the key** waits
     for the next key press (with Shift, Ctrl, Alt; Esc cancels), binds it to "Cast the next request" in place
     of any older key and says in chat what that key did before. Out of combat only. Next.
  3. **Tell your group** (the chat box): "Your group whispers you a word and the spell queues on them. Tell them
     the words, or try one on yourself first." **Announce** (`/wc announce`), **Try it** (`/wc test` with the
     first word of the first spell this character knows; nothing is sent), **Done**.
  Done opens the welcome window on Welcome with the checklist. The x ends the tour too (the checklist waits in
  the window). Not in combat: "/wc tour" in a fight says it starts after the fight.
- **The checklist** (Welcome tab, after the tour): "Set up in three steps"; three lines that tick themselves:
  Place your queue window (**Unlock** / **Lock**; ticked once it has been moved or locked after the tour's
  step 1), Bind your Cast key (**Set the key**; ticked while a key is bound, the key shown), Tell your group
  (**Announce**; ticked once an announce went out). Then "Or Try it to see a request arrive." with **Try it**.
- **When it shows**: a first install (no saved settings yet) opens the window on Welcome, and closing it starts
  the tour. After an update (the version differs from the last one shown, or none was recorded) it opens once
  on What's new. Both wait 2 s after login and until a fight ends. `/wc welcome` and `/wc tour` any time.
