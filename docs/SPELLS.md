# What you can be asked for

Every spell WhisperCast: Second Wind queues out of the box: 86 spells across 12 classes, with the
words that ask for each one and the clients it's on. *This file is made from `Data.lua` by
`lua tools/spells-md.lua > docs/SPELLS.md`; don't edit it by hand.*

- **Each spell's own name always works too**, in the game's language ("Innervate on me please" queues
  Innervate). Change any spell's words in **Settings › Spells and words**.
- **All** means Classic Era, TBC Anniversary, MoP Classic, Retail and WoW: Forever.
- *(group)* is the group version: when two or more in one party ask for the single version, one group cast
  answers them all. The paladin Greater Blessings cover the asker's class instead of their party.
- *(cure)* removes a debuff; *(resurrect)* brings back a dead groupmate.
- When two of your spells share a word, the stronger one wins: a level 40 priest's `disease` is Abolish
  Disease, a level 20 priest's is Cure Disease.
- Words in German, French, Korean and Chinese (the 2007 lists) are used on those game languages.

## Druid

| Spell | Whisper | Clients |
|---|---|---|
| Gift of the Wild *(group)* | `gotw`, `gift`, `group mark` | Era, TBC, Forever |
| Mark of the Wild | `motw`, `mark`, `paw` | All |
| Thorns | `thorns` | Era, TBC, Forever |
| Innervate | `innervate` | All |
| Remove Curse *(cure)* | `curse` | Era, TBC, Forever |
| Abolish Poison *(cure)* | `poison` | Era, TBC, Forever |
| Cure Poison *(cure)* | `poison` | Era, TBC, Forever |
| Rebirth *(resurrect)* | `rez`, `res`, `rebirth` | All |
| Ironbark | `ironbark`, `bark` | Mists, Retail |
| Nature's Cure *(cure)* | `dispel`, `curse`, `poison` | Mists, Retail |
| Remove Corruption *(cure)* | `curse`, `poison` | Mists, Retail |
| Revive *(resurrect)* | `rez`, `res` | Mists, Retail, Forever |

## Paladin

| Spell | Whisper | Clients |
|---|---|---|
| Greater Blessing of Might *(group)* | `gbom`, `gmight` | Era, TBC, Forever |
| Blessing of Might | `might`, `bom` | Era, TBC, Mists, Forever |
| Greater Blessing of Wisdom *(group)* | `gbow`, `gwis`, `gwisdom` | Era, TBC, Forever |
| Blessing of Wisdom | `wisdom`, `wis`, `bow` | Era, TBC, Forever |
| Greater Blessing of Kings *(group)* | `gbok`, `gkings`, `gking` | Era, TBC, Forever |
| Blessing of Kings | `kings`, `king`, `bok` | Era, TBC, Mists, Forever |
| Greater Blessing of Salvation *(group)* | `gbos`, `gsal`, `gsalvation` | Era, TBC |
| Blessing of Salvation | `salvation`, `bos` | Era, TBC, Mists |
| Greater Blessing of Light *(group)* | `gbol`, `glight` | Era, TBC |
| Blessing of Light | `light`, `bol` | Era, TBC |
| Greater Blessing of Sanctuary *(group)* | `gbosa`, `gsan`, `gsanctuary` | Era, TBC |
| Blessing of Sanctuary | `sanctuary` | Era, TBC |
| Blessing of Freedom | `freedom`, `bof` | All |
| Blessing of Protection | `protection` | All |
| Blessing of Sacrifice | `sacrifice` | All |
| Cleanse *(cure)* | `cleanse`, `dispel`, `cure` | All |
| Purify *(cure)* | `purify`, `poison`, `disease` | Era, TBC, Forever |
| Redemption *(resurrect)* | `rez`, `res` | All |
| Blessing of Spellwarding | `spellwarding`, `spellward` | Retail |
| Cleanse Toxins *(cure)* | `toxins`, `purify`, `poison`, `disease` | Retail |

## Priest

| Spell | Whisper | Clients |
|---|---|---|
| Prayer of Fortitude *(group)* | `group fort`, `group fortitude`, `group stam`, `group stamina` | Era, TBC, Forever |
| Power Word: Fortitude | `fort`, `single fort`, `fortitude`, `stam`, `sta`, `stamina` | All |
| Prayer of Shadow Protection *(group)* | `group shadow` | Era, TBC, Forever |
| Shadow Protection | `shadow` | Era, TBC, Forever |
| Prayer of Spirit *(group)* | `group spirit`, `group wis` | Era, TBC, Forever |
| Divine Spirit | `spirit`, `wis` | Era, TBC, Forever |
| Power Word: Shield | `shield` | All |
| Fear Ward | `fw`, `fear`, `ward` | Era, TBC, Mists, Forever |
| Power Infusion | `pi`, `power`, `infuse`, `infusion` | All |
| Abolish Disease *(cure)* | `disease` | Era, TBC, Forever |
| Cure Disease *(cure)* | `disease` | Era, TBC, Forever |
| Dispel Magic *(cure)* | `dispel` | Era, TBC, Forever |
| Resurrection *(resurrect)* | `rez`, `res` | All |
| Pain Suppression | `ps`, `pain`, `suppression` | TBC, Mists, Retail |
| Guardian Spirit | `gs`, `guardian` | Mists, Retail |
| Purify *(cure)* | `purify`, `dispel`, `disease` | Mists, Retail |
| Purify Disease *(cure)* | `disease` | Retail |

## Mage

| Spell | Whisper | Clients |
|---|---|---|
| Arcane Brilliance *(group)* | `ab`, `group ai`, `group int`, `brilliance` | Era, TBC, Mists, Forever |
| Arcane Intellect | `ai`, `int` | Era, TBC, Retail, Forever |
| Dampen Magic | `dampen` | Era, TBC, Forever |
| Amplify Magic | `amplify` | Era, TBC, Forever |
| Slow Fall | `slowfall`, `slow fall` | All |
| Remove Lesser Curse *(cure)* | `curse` | Era, TBC, Forever |
| Remove Curse *(cure)* | `curse` | Mists, Retail |

## Shaman

| Spell | Whisper | Clients |
|---|---|---|
| Cure Poison *(cure)* | `poison` | Era, TBC, Forever |
| Cure Disease *(cure)* | `disease` | Era, TBC, Forever |
| Water Breathing | `water` | Era, TBC, Forever |
| Water Walking | `water walking`, `waterwalk`, `walk` | All |
| Ancestral Spirit *(resurrect)* | `rez`, `res` | All |
| Earth Shield | `es`, `earth shield`, `earth` | TBC, Mists, Retail |
| Purify Spirit *(cure)* | `purify`, `dispel`, `curse` | Mists, Retail |
| Cleanse Spirit *(cure)* | `cleanse`, `curse` | Mists, Retail |

## Warlock

| Spell | Whisper | Clients |
|---|---|---|
| Unending Breath | `water` | All |
| Detect Invisibility | `invis`, `invisible` | Era, TBC, Forever |
| Ritual of Summoning | `summon` | All |
| Dark Intent | `di`, `intent` | Mists |
| Soulstone | `soulstone`, `ss`, `stone` | Mists, Retail |

## Hunter

| Spell | Whisper | Clients |
|---|---|---|
| Misdirection | `md`, `misdirect`, `misdirection` | TBC, Mists, Retail |

## Rogue

| Spell | Whisper | Clients |
|---|---|---|
| Tricks of the Trade | `tricks`, `tott` | Mists, Retail |

## Monk

| Spell | Whisper | Clients |
|---|---|---|
| Legacy of the Emperor | `legacy`, `emperor` | Mists |
| Legacy of the White Tiger | `tiger` | Mists |
| Life Cocoon | `cocoon`, `lc` | Mists, Retail |
| Detox *(cure)* | `detox`, `dispel`, `poison`, `disease` | Mists, Retail |
| Resuscitate *(resurrect)* | `rez`, `res` | Mists, Retail |

## Death Knight

| Spell | Whisper | Clients |
|---|---|---|
| Raise Ally *(resurrect)* | `rez`, `res` | Mists, Retail |

## Warrior

| Spell | Whisper | Clients |
|---|---|---|
| Vigilance | `vigilance`, `vig` | Mists |

## Evoker

| Spell | Whisper | Clients |
|---|---|---|
| Time Dilation | `td`, `dilation` | Retail |
| Source of Magic | `som`, `source` | Retail |
| Prescience | `prescience`, `presc` | Retail |
| Blistering Scales | `scales`, `blistering` | Retail |
| Naturalize *(cure)* | `naturalize`, `dispel`, `poison` | Retail |
| Expunge *(cure)* | `expunge`, `poison` | Retail |
| Cauterizing Flame *(cure)* | `cauterize`, `bleed`, `curse`, `disease` | Retail |
| Return *(resurrect)* | `rez`, `res` | Retail |

## Not on every client

- WoW: Forever has no Blessing of Light, Salvation or Sanctuary, nor their Greater versions.
- The soulstone is an item on Classic Era, TBC and Forever (not a spell you cast), so it is listed on MoP
  Classic and Retail only.
