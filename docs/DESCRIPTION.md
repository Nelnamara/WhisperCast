# WhisperCast: Second Wind

Your group whispers you a word like **motw**, **fort** or **kings**. The spell joins a queue on them, and one key casts it. No targeting, no hunting through raid frames: whoever asked is next, and the key knows who that is.

A fresh rewrite of Valconeye's WhisperCast, the raid buff addon last updated in 2007. One download covers Retail 12.1.5, MoP Classic 5.5.4, TBC Anniversary 2.5.6, Classic Era 1.15.9 and WoW: Forever 1.60.1, and each client has its own spell list.

**Only you need it.** Your groupmates just whisper. They don't need the addon, and the replies they get are ordinary whispers.

## Where it came from

WhisperCast was a crucial addon for Vanilla raiders, made by Valconeye in 2005. Druids and Paladins specifically made great use of this addon, needing to buff a 40 man raid was a time consuming and often inefficient process. WhisperCast helped put ownership in a player's needed raid buffs also on the player. Arriving late, after a partial wipe, simply whispering paw to a Druid would autocast Mark of the Wild. With Wow v2.0.0 TBC, brought new limitations on auto casting and in 2007 the addon became unmaintained.

Second Wind is a fresh rewrite: none of the old code, all of the old idea, the same trigger words and /wc now on Classic era, TBC, Mists, Retail and Forever. I made this in an effort to help bring some of that helpful utility to an overwhelming process for a learning player. I hope this Forever is as fun a ride for us Vanilla gave us.

~Nelnamara

## How it works

1. **They whisper.** A groupmate whispers you a word: motw, fort, kings, innervate, summon, rez.
2. **It queues.** The request lines up in a small window with their name and the spell. A note pops up, the window glows, and they get a reply with their place in line.
3. **You press your key.** One key casts the next request on the right person, with the right rank for their level on Classic Era, TBC and Forever.

The first time you log in, a welcome window shows this as a moving demo, and a three-step tour sets you up.

## What it does

- **Next up, big.** The next request shows large, then the rest grouped by spell. When two or more in one party ask for the same buff, it offers the group version: one cast answers them all.
- **Its own Cast button** on one key, which Masque can skin. Or put Cast and Clear buttons on the window, the classic way.
- **Three looks:** Suite dark, Blizzard classic and Flat modern, with your own colours, opacity, scale and font size.
- **A note, a glow and a sound** when someone asks. Move and size the note in Edit Mode.
- **Folds away** to a round icon with a count badge.
- **Replies with their place in line,** then "coming now". Out of range, they hear they're still in line.
- **Whisper "wc"** and anyone gets your list of words back. **/wc announce** tells your party or raid.
- **In a fight, the first request stays ready** for one press. The rest wait until the fight ends.
- **Out of range never lands on you,** and **the queue survives a /reload.**
- **Trigger words as chips:** add, remove or reset them per spell, or turn a spell off. Party and raid chat requests too, if you like.
- **The 2007 words in English, German, French, Korean and Chinese,** and each spell's own name works in every language.
- **Profiles, a minimap button** and a launcher for Titan Panel and other display addons.
- **Works with CooldownCollaborator:** its panel gets an Asks tab with your queue and a Cast button.

## What you can be asked for

86 spells across 12 classes, including:

- **Druid:** Mark and Gift of the Wild, Thorns, Innervate, cures, Rebirth (motw, paw, gotw, thorns, innervate)
- **Paladin:** every Blessing and Greater Blessing, Freedom, Protection, Sacrifice, Cleanse (might, wis, kings, bos, bof)
- **Priest:** Fortitude, Shadow Protection, Divine Spirit and their Prayers, Shield, Fear Ward, Power Infusion (fort, shadow, spirit, fw, pi)
- **Mage:** Arcane Intellect and Brilliance, Dampen and Amplify Magic, Slow Fall (ai, ab, dampen, slowfall)
- **Shaman:** Water Breathing and Walking, Earth Shield, cures (water, walk, es)
- **Warlock:** Unending Breath, Detect Invisibility, Ritual of Summoning, Soulstone (water, invis, summon, ss)
- **And more:** Misdirection, Tricks of the Trade, Monk legacies, Life Cocoon, Vigilance, Evoker buffs, and every resurrection (rez)

Every spell, every word and which clients have it: https://github.com/Nelnamara/WhisperCast/blob/main/docs/SPELLS.md

## Good to know

- **Every cast takes your key press.** Blizzard doesn't let an addon cast by itself.
- **In combat the button can't change who it casts on** (another Blizzard rule), so the first request stays ready for one press and the rest wait for the fight to end.
- **Retail and Forever:** during a boss fight the game can hide whispers from addons, so a request sent mid-fight may not queue.

## Commands

- **/wc**: show or hide the window
- **/wc settings**: the settings
- **/wc welcome** and **/wc tour**: the welcome window and the setup tour
- **/wc announce**: tell your group what to whisper
- **/wc on**, **/wc off**: take requests, or stop
- **/wc test motw**: try it on yourself (nothing is sent)

## Bugs and requests

https://github.com/Nelnamara/WhisperCast/issues

The original WhisperCast is by Valconeye. Second Wind shares its idea, its trigger words and /wc, and none of its code.
