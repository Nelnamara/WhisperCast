-- English text for the welcome window, the demo and the tour (Welcome.lua). The English text is the key, so a
-- phrase with no translation shows in English.
local L = LibStub("AceLocale-3.0"):NewLocale("WhisperCastSW", "enUS", true, true)
if not L then return end

-- the window
L["Welcome"] = true
L["The story"] = true
L["What's new"] = true
L["Take the tour"] = true
L["Your group whispers you a word like \"motw\"; the spell queues on them and one key casts it."] = true
L["open the welcome window (what it is, its story, what's new)"] = true
L["the three-step setup tour"] = true

-- the demo (a sample: the same asker and spell on every client)
L["[2. Trade] LFW in UC"] = true
L["[Thornwick] whispers: motw"] = true
L["To [Thornwick]: [WC] Mark of the Wild coming now."] = true
L["Mark of the Wild"] = true
L["NEXT · %s"] = true
L["They whisper"] = true
L["It queues"] = true
L["You press %s"] = true

-- the story: the owner's own words (21 Nov); only the doubled "of the" and "player's" corrected
L["WELCOME_STORY"] = "WhisperCast was a crucial addon for Vanilla raiders, made by Valconeye in 2005. Druids and Paladins specifically made great use of this addon, needing to buff a 40 man raid was a time consuming and often inefficient process. WhisperCast helped put ownership in a player's needed raid buffs also on the player. Arriving late, after a partial wipe, simply whispering paw to a Druid would autocast Mark of the Wild. With Wow v2.0.0 TBC, brought new limitations on auto casting and in 2007 the addon became unmaintained.\n\nSecond Wind is a fresh rewrite: none of the old code, all of the old idea, the same trigger words and /wc now on Classic era, TBC, Retail and Forever. I made this in an effort to help bring some of that helpful utility to an overwhelming process for a learning player. I hope this Forever is as fun a ride for us Vanilla gave us.\n\n~Nelnamara"

-- What's new
L["New since 2007"] = true
L["Three looks, Suite dark, Blizzard classic and Flat modern, with your own colours"] = true
L["Next up, big, then the rest grouped by spell; one group buff when two in a party ask"] = true
L["Next up, big, then the rest grouped by spell"] = true
L["Its own Cast button (Masque skins it) on one key; in a fight the first request stays ready"] = true
L["A note and a glow when someone asks; a round icon when folded away"] = true
L["Trigger words as chips; party and raid chat too, if you like"] = true
L["Out of range never lands on you, and the queue survives a /reload"] = true
L["CooldownCollaborator shows the queue on its Asks tab"] = true
L["Classic Era, TBC, Mists, Retail and Forever, from one folder"] = true

-- the checklist
L["Set up in three steps"] = true
L["All set."] = true
L["Place your queue window"] = true
L["Bind your Cast key"] = true
L["Tell your group"] = true
L["Unlock"] = true
L["Lock"] = true
L["Try it"] = true
L["Or Try it to see a request arrive."] = true
L["Press a key..."] = true
L["%s now casts the next request."] = true
L["%s now casts the next request (it was: %s)."] = true
L["Keys can't change in a fight. Try again after it."] = true

-- the tour
L["%d of %d · %s"] = true
L["Your queue window"] = true
L["Requests line up here, next one first. Drag it by its title where you like."] = true
L["Your Cast key"] = true
L["This button casts the next request. Give it a key you can reach in a fight."] = true
L["Your key: %s"] = true
L["No key yet."] = true
L["Your group whispers you a word and the spell queues on them. Tell them the words, or try one on yourself first."] = true
L["Done"] = true
L["The tour starts after this fight."] = true
