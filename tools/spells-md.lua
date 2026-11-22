-- Writes docs/SPELLS.md (every spell asked for out of the box, its default English words and its clients)
-- from Data.lua, so the list never drifts from the addon. Run from the repo root:
--   lua tools/spells-md.lua > docs/SPELLS.md
WhisperCastSW = { client = "era" }
dofile("Data.lua")
local D = WhisperCastSW.Data
local clients = { "era", "tbc", "mists", "retail", "forever" }
local cname = { era = "Era", tbc = "TBC", mists = "Mists", retail = "Retail", forever = "Forever" }
local classOrder = { "DRUID", "PALADIN", "PRIEST", "MAGE", "SHAMAN", "WARLOCK", "HUNTER", "ROGUE", "MONK",
	"DEATHKNIGHT", "WARRIOR", "EVOKER" }
local cls = { DRUID = "Druid", PALADIN = "Paladin", PRIEST = "Priest", MAGE = "Mage", SHAMAN = "Shaman",
	WARLOCK = "Warlock", HUNTER = "Hunter", ROGUE = "Rogue", MONK = "Monk", DEATHKNIGHT = "Death Knight",
	WARRIOR = "Warrior", EVOKER = "Evoker" }

local out, total = {}, 0
local function p(s) out[#out + 1] = s end
local body = {}
for _, class in ipairs(classOrder) do
	local order, rows = {}, {}
	for _, c in ipairs(clients) do
		for _, e in ipairs((D.spells[c] or {})[class] or {}) do
			if not rows[e.key] then
				rows[e.key] = { e = e, cl = {}, words = D.DefaultWords(class, e, "enUS", c) }
				order[#order + 1] = e.key
			end
			table.insert(rows[e.key].cl, cname[c])
		end
	end
	if #order > 0 then
		body[#body + 1] = "## " .. cls[class] .. "\n"
		body[#body + 1] = "| Spell | Whisper | Clients |"
		body[#body + 1] = "|---|---|---|"
		for _, key in ipairs(order) do
			local r, e = rows[key], rows[key].e
			local kind = e.isGroup and " *(group)*" or e.rez and " *(resurrect)*" or e.cure and " *(cure)*" or ""
			local words = {}
			for i, w in ipairs(r.words) do words[i] = "`" .. w .. "`" end
			local w = #words > 0 and table.concat(words, ", ") or "its name"
			local cl = (#r.cl == #clients) and "All" or table.concat(r.cl, ", ")
			body[#body + 1] = string.format("| %s%s | %s | %s |", e.name, kind, w, cl)
			total = total + 1
		end
		body[#body + 1] = ""
	end
end

p("# What you can be asked for")
p("")
p(string.format("Every spell WhisperCast: Second Wind queues out of the box: %d spells across %d classes, with the", total, 12))
p("words that ask for each one and the clients it's on. *This file is made from `Data.lua` by")
p("`lua tools/spells-md.lua > docs/SPELLS.md`; don't edit it by hand.*")
p("")
p("- **Each spell's own name always works too**, in the game's language (\"Innervate on me please\" queues")
p("  Innervate). Change any spell's words in **Settings › Spells and words**.")
p("- **All** means Classic Era, TBC Anniversary, MoP Classic, Retail and WoW: Forever.")
p("- *(group)* is the group version: when two or more in one party ask for the single version, one group cast")
p("  answers them all. The paladin Greater Blessings cover the asker's class instead of their party.")
p("- *(cure)* removes a debuff; *(resurrect)* brings back a dead groupmate.")
p("- When two of your spells share a word, the stronger one wins: a level 40 priest's `disease` is Abolish")
p("  Disease, a level 20 priest's is Cure Disease.")
p("- Words in German, French, Korean and Chinese (the 2007 lists) are used on those game languages.")
p("")
for _, l in ipairs(body) do p(l) end
p("## Not on every client")
p("")
p("- WoW: Forever has no Blessing of Light, Salvation or Sanctuary, nor their Greater versions.")
p("- The soulstone is an item on Classic Era, TBC and Forever (not a spell you cast), so it is listed on MoP")
p("  Classic and Retail only.")
io.write(table.concat(out, "\n"), "\n")
