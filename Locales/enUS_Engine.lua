-- English text for the Engine lane. The English text is the key.
local L = LibStub("AceLocale-3.0"):NewLocale("WhisperCastSW", "enUS", true, true)
if not L then return end

-- replies (Engine adds "[WC] " in front)
L["%s: you're %s in line."] = true
L["%s: you're %s in line, after this fight."] = true
L["%s: you're already %s in line."] = true
L["%s coming now."] = true
L["Couldn't cast %s on you (%s). Whisper again to retry."] = true
L["Your %s request was cleared."] = true
L["Not taking requests right now."] = true
L["Whisper me one of: %s"] = true
L["Whisper me for buffs: %s. Whisper \"wc\" for the list."] = true

-- ordinals
L["%dst"] = true
L["%dnd"] = true
L["%drd"] = true
L["%dth"] = true

-- slash words and status
L["tell your party or raid what to whisper"] = true
L["clear the queue"] = true
L["take requests"] = true
L["stop taking requests"] = true
L["your spells, their words and the settings"] = true
L["Queue cleared."] = true
L["Taking requests."] = true
L["Not taking requests."] = true
L["You are not in a group."] = true
L["No spells to offer on this character."] = true
L["Taking requests: %s. Matching: %s. Group members only: %s. Waiting: %d."] = true
L["yes"] = true
L["no"] = true
L["(its name only)"] = true
L["(off)"] = true

-- group casts
L["All %d in group %d: %s covers them"] = true
L["All %d %s: %s covers them"] = true
L["%ss"] = true -- a class name made plural ("Warriors")
L["%s: missing reagent, so single casts for the rest of this session."] = true
L["Debug on: every whisper's steps print in chat. /wc debug again to stop."] = true
L["Debug off."] = true
L["print every step of each whisper (on or off)"] = true
L["Usage: /wc test <words>, e.g. /wc test motw"] = true
L["act as if you whispered yourself, e.g. /wc test motw"] = true
L["Out of range"] = true
L["%s is out of range for %s."] = true
L["%s went to you: %s was out of range."] = true
L["Kept %d request(s) from before the reload."] = true
