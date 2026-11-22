# WhisperCast: Second Wind

> **WoW:** Retail 12.1.5 · MoP Classic 5.5.4 · TBC Anniversary 2.5.6 · Classic Era 1.15.9 · WoW: Forever 1.60.1 · **Author:** Nelnamara

Your group whispers you a word like `motw`, `fort` or `kings`. The spell joins a queue on them, and one key casts
it. No targeting, no hunting through raid frames: whoever asked is next, and the key knows who that is.

A fresh rewrite of Valconeye's WhisperCast, the raid buff addon last updated in 2007. One download covers all
five clients, and each client has its own spell list.

**Only you need it.** Your groupmates just whisper. They don't need the addon, and the replies they get are
ordinary whispers.

---

## Where it came from

WhisperCast was a crucial addon for Vanilla raiders, made by Valconeye in 2005. Druids and Paladins specifically
made great use of this addon, needing to buff a 40 man raid was a time consuming and often inefficient process.
WhisperCast helped put ownership in a player's needed raid buffs also on the player. Arriving late, after a
partial wipe, simply whispering paw to a Druid would autocast Mark of the Wild. With Wow v2.0.0 TBC, brought new
limitations on auto casting and in 2007 the addon became unmaintained.

Second Wind is a fresh rewrite: none of the old code, all of the old idea, the same trigger words and /wc now on
Classic era, TBC, Mists, Retail and Forever. I made this in an effort to help bring some of that helpful utility to
an overwhelming process for a learning player. I hope this Forever is as fun a ride for us Vanilla gave us.

~Nelnamara

---

## How it works

1. **They whisper.** A groupmate whispers you a word: `motw`, `fort`, `kings`, `innervate`, `summon`, `rez`.
2. **It queues.** The request lines up in a small window with the asker's name and the spell. A note pops up
   beside it, the window glows, and the asker gets a reply with their place in line.
3. **You press your key.** One key casts the next request on the right person, with the right rank for their
   level on Classic Era, TBC and Forever. Press again for the next one.

The first time you log in, a welcome window shows this as a moving demo, and a three-step tour sets you up:
where the window goes, which key casts, and how to tell your group what to whisper.

---

## Features

- **Next up, big.** The window shows the next request large, then the rest grouped by spell (or one row each).
  When two or more in one party ask for the same buff, it offers the group version: one cast answers them all.
- **Its own Cast button** on one key, which Masque can skin. It wears the next spell's icon and the asker's name.
  Or put Cast and Clear buttons on the window, the classic way.
- **Three looks:** Suite dark, Blizzard classic and Flat modern, with your own colours, opacity, scale and font
  size.
- **A note and a glow** when someone asks, and a sound when the queue goes from empty to one (as in 2007), or on
  every request, with any sound you pick. The note can be moved and sized in Edit Mode (on Classic Era, when the
  frames are unlocked).
- **Folds away** to a round icon with a count badge, and remembers it across reloads.
- **Replies with your place:** `[WC] Mark of the Wild: you're 2nd in line.` Then `coming now`, `couldn't reach you
  (Out of range). You're still in line.`, or `cleared`. Replies are on by default and can be switched off, and your
  own `[WC]` whispers stay out of your chat.
- **Whisper `wc`** and anyone gets your list of words back. `/wc announce` tells your party or raid.
- **In a fight, the first request stays ready:** one press casts it. Requests that come in during the fight queue
  as usual and are told "after this fight".
- **Out of range never lands on you.** Out of combat the press is stopped and counts as a try. After four tries
  the asker is told and the request is dropped.
- **The queue survives a /reload,** in the same order, with no whispers sent.
- **Trigger words as chips** in the settings, per spell: add, remove or reset them, or turn a spell off. Party
  and raid chat requests too, if you like.
- **English, German, French, Korean and Chinese words** from 2007. Each spell's own name works in every language.
- **Profiles, a minimap button** and a launcher for Titan Panel and other display addons.
- **CooldownCollaborator** shows the queue on its Asks tab (see below).

---

## What you can be asked for

86 spells across 12 classes. Some of the most asked-for (each has more words):

| Class | Buffs and spells | Whisper |
|---|---|---|
| Druid | Mark and Gift of the Wild, Thorns, Innervate, curse and poison cures, Rebirth | `motw` `paw` `gotw` `thorns` `innervate` `rez` |
| Paladin | Blessings of Might, Wisdom, Kings, Salvation, Light, Sanctuary and their Greater versions; Freedom, Protection, Sacrifice, Cleanse | `might` `wis` `kings` `bos` `bof` `cleanse` |
| Priest | Fortitude, Shadow Protection, Divine Spirit and their Prayers; Shield, Fear Ward, Power Infusion, dispels | `fort` `shadow` `spirit` `shield` `fw` `pi` |
| Mage | Arcane Intellect and Brilliance, Dampen and Amplify Magic, Slow Fall, curse removal | `ai` `ab` `dampen` `slowfall` `curse` |
| Shaman | Water Breathing and Walking, Earth Shield, cures, Ancestral Spirit | `water` `walk` `es` `poison` `rez` |
| Warlock | Unending Breath, Detect Invisibility, Ritual of Summoning, Soulstone | `water` `invis` `summon` `ss` |
| Others | Misdirection, Tricks of the Trade, Monk legacies and Life Cocoon, Raise Ally, Vigilance, Evoker buffs | `md` `tricks` `cocoon` `rez` `vig` `som` |

**Every spell, every word and which clients have it: [docs/SPELLS.md](docs/SPELLS.md).** The list follows each
client: Gift of the Wild and the Greater Blessings on Classic Era, TBC and Forever; Evoker spells on Retail; and so
on.

---

## Requirements and limits

- One of: WoW Retail 12.1.5, MoP Classic 5.5.4, TBC Anniversary 2.5.6, Classic Era 1.15.9 or WoW: Forever 1.60.1.
- No other addons needed. Masque and CooldownCollaborator are optional.
- **Every cast takes your key press.** Blizzard doesn't let an addon cast by itself, and that has been true since
  TBC.
- **In combat, the button can't change who it casts on,** another Blizzard rule. That's why the first request
  stays ready for one press, and the rest wait until the fight ends.
- **Retail and Forever:** during a boss fight the game can hide whispers from addons, so a request sent mid-fight
  may not queue.

---

## Installation

Drop the `WhisperCast` folder into your client's AddOns folder, or install it with the CurseForge app. The same
folder works on every client.

| Client | AddOns folder |
|---|---|
| Retail | `World of Warcraft\_retail_\Interface\AddOns\` |
| MoP Classic | `World of Warcraft\_classic_\Interface\AddOns\` |
| TBC Anniversary | `World of Warcraft\_anniversary_\Interface\AddOns\` |
| Classic Era | `World of Warcraft\_classic_era_\Interface\AddOns\` |
| World of Warcraft: Forever | `World of Warcraft\_forever_\Interface\AddOns\` |

The welcome window opens on your first login. Take the tour to bind your key, or bind it any time under Key
Bindings › WhisperCast: Second Wind › Cast the next request.

---

## Usage

### Slash commands

`/wc` or `/whispercast`

| Command | What it does |
|---|---|
| `/wc` | Show or hide the window |
| `/wc settings` | Open the settings |
| `/wc welcome` | The welcome window: what it is, its story, what's new |
| `/wc tour` | The three-step setup tour |
| `/wc announce` | Tell your party or raid what to whisper |
| `/wc on`, `/wc off` | Take requests, or stop |
| `/wc clear` | Clear the queue |
| `/wc fold` | Fold the window to its icon, or open it |
| `/wc lock`, `/wc unlock` | Lock the frames, or unlock them to move |
| `/wc reset` | Put every frame back in its place |
| `/wc status` | Your spells, their words and the settings |
| `/wc test motw` | Act as if you whispered yourself (nothing is sent) |
| `/wc debug` | Print every step of each whisper |

### Settings

General · Spells and words · Window · Cast button · Alerts · Folded icon · Profiles

---

## Works with CooldownCollaborator

When [CooldownCollaborator](https://github.com/Nelnamara/CooldownCollaborator) is loaded too, its panel gets an
**Asks** tab with your queue in its own style, a Cast button and a count on the tab. CooldownCollaborator's Ask
whispers "<Spell> on me please", and WhisperCast queues it by the spell's name, so the two work together with no
setup.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

---

## Author

Nelnamara · [GitHub](https://github.com/Nelnamara/WhisperCast)

The original WhisperCast is by Valconeye. Second Wind shares its idea, its trigger words and `/wc`, and none of
its code.
