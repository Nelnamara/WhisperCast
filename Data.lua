--[[
	WhisperCast: Second Wind - spell data: what each class can be asked for, per client, and the
	default trigger words. Read docs/DESIGN_HANDOFF.md ("Trigger words") and the contract in Core.lua.

	WCSW.Data.spells[client][CLASS] = ordered list of
	  { key, id (base spell ID), name (English; the game's localized name is used at run time), icon,
	    ranks = { { spellID, level, rankNumber or nil }, ... } (Era, TBC, Forever: lowest first; the cast
	      picks the highest known rank whose level is at most 10 above the target's),
	    alts = { spellID, ... } (other IDs the same spell is known or cast as on that client),
	    group = key of the group version, isGroup = true on a group version, byClass = true when the
	      group version covers the target's class (Greater Blessings) instead of the target's party,
	    combat = true (cures, externals, combat resurrections), cure = true (no level rule),
	    rez = true (a resurrection: no level rule, the asker is dead), wordsFrom = { key, ... } (the
	      word lists it takes, default its own key) }
	  The list order breaks ties: when two known spells share a word ("disease"), the first one wins.

	IDs, names, icons and levels were read from each build's DB2 tables on wago.tools
	(SpellName, Spell.NameSubtext, SpellLevels, SpellMisc, SkillLineAbility, Talent, TraitDefinition):
	  era 1.15.9.70576, tbc 2.5.6.70577, forever 1.60.1.70888, mists 5.5.4.70631, retail 12.1.5.70783.
	WoW: Forever has no Blessing of Light, Salvation or Sanctuary (or their Greater versions) in any
	paladin skill line, and Detect Invisibility is one spell with three ranks there.
	The soulstone is an item on Era, TBC and Forever (not a spell you cast), so it is listed on MoP and
	retail only. Druids have Revive on Forever (five ranks), MoP and retail; Era's Revive is a Season of
	Discovery rune and is left out.

	WCSW.Data.words[CLASS][key] = { enUS = { ... }, deDE = { ... }, frFR, koKR, zhCN }
	  The 2007 WhisperCast 3.2.3 words (enUS, deDE, frFR, koKR, zhCN) for its spells; English words for the
	  spells it didn't have (those lists say new = true). How a language's list joins the English one
	  follows 2007: German and French go in front of the English words, Chinese after them, Korean
	  replaces them; a list with replace = true replaces them in any language. Spells may share words;
	  D.priority says which one a shared word picks (see there). Each spell's own localized name always
	  matches too (Engine.lua adds it), so CooldownCollaborator's "<Spell> on me please" queues it.
]]
local WCSW = WhisperCastSW
local D = {}
WCSW.Data = D

D.localeMode = { deDE = "prepend", frFR = "prepend", zhCN = "append", koKR = "replace" }

D.words = {
	PRIEST = {
		fortitude = {
			enUS = { "fort", "single fort", "fortitude", "stam", "sta", "stamina" },
			deDE = { "ss", "seelen", "seelenstärke", "ausdauer", "seele" },
			frFR = { "robust", "robustesse" },
			koKR = { "인내" },
			zhCN = { "韧" },
		},
		prayerFortitude = {
			enUS = { "group fort", "group fortitude", "group stam", "group stamina" },
			deDE = { "gruppen ss", "gruppen seelen", "gruppen seelenstärke", "gruppen ausdauer", "gruppen seele", "gdss", "gss", "gds", "gebet" },
			frFR = { "groupe robust", "groupe robustesse" },
			koKR = { "기원" },
			zhCN = { "群韧" },
		},
		shadowProtection = {
			enUS = { "shadow" },
			deDE = { "schatten", "schattenschutz" },
			frFR = { "l'ombre", "lombre" },
			koKR = { "어둠" },
			zhCN = { "防护暗影", "暗影" },
		},
		prayerShadow = { enUS = { "group shadow" } },
		divineSpirit = {
			enUS = { "spirit", "wis" },
			deDE = { "weisheit", "wille" },
			frFR = { "esprit", "sagesse" },
			koKR = { "천정" },
			zhCN = { "神圣之灵", "精神" },
		},
		prayerSpirit = { enUS = { "group spirit", "group wis" } },
		shield = {
			enUS = { "shield" },
			deDE = { "schild" },
			frFR = { "bouclier" },
			koKR = { "보망", "보막", "보호막" },
			zhCN = { "盾", "真言盾" },
		},
		dispelMagic = {
			enUS = { "dispel" },
			deDE = { "bannen", "magie" },
			frFR = { "dissipe", "magie" },
			koKR = { "마법", "해제" },
			zhCN = { "驱散魔法", "魔法" },
		},
		abolishDisease = {
			enUS = { "disease" },
			deDE = { "krankheit", "krank" },
			frFR = { "maladie" },
			koKR = { "질병", "질병해제" },
			zhCN = { "驱除疾病", "疾病" },
		},
		cureDisease = {
			enUS = { "disease" },
			deDE = { "krankheit", "krank" },
			frFR = { "maladie" },
			koKR = { "질병치료" },
			zhCN = { "疾病" },
		},
		fearWard = {
			enUS = { "fw", "fear", "ward" },
			deDE = { "furcht", "zauberschutz", "furchtbarriere", "barriere" },
			frFR = { "gardien", "peur" },
			koKR = { "수호물" },
			zhCN = { "恐惧结界", "恐惧", "结界" },
		},
		powerInfusion = { enUS = { "pi", "power", "infuse", "infusion" } },
		-- not in 2007
		painSuppression = { new = true, enUS = { "ps", "pain", "suppression" } },
		guardianSpirit = { new = true, enUS = { "gs", "guardian" } },
		purify = { new = true, enUS = { "purify" } },
		purifyDisease = { new = true, enUS = {} },
		resurrection = { new = true, enUS = { "rez", "res" } },
	},
	MAGE = {
		intellect = {
			enUS = { "ai", "int" },
			deDE = { "intellekt", "intelligenz", "arkan" },
			frFR = { "int", "arcane" },
			koKR = { "지능" },
			zhCN = { "智力" },
		},
		brilliance = {
			enUS = { "ab", "group ai", "group int", "brilliance" },
			deDE = { "gruppen ai", "gruppen int", "brillanz", "brillianz" },
			frFR = { "illum", "illumine", "groupe int", "groupe arcane" },
			koKR = { "총명" },
			zhCN = { "群智力", "群智" },
		},
		dampen = {
			enUS = { "dampen" },
			deDE = { "dämpfer", "dampfer", "dämpfen", "dampfen" },
			frFR = { "atténue", "attenue" },
			koKR = { "마법감쇠", "감쇠" },
			zhCN = { "魔法抑制", "抑制" },
		},
		amplify = {
			enUS = { "amplify" },
			deDE = { "verstärken", "verstarken" },
			frFR = { "amplifie" },
			koKR = { "마법증폭", "증폭" },
			zhCN = { "魔法增效", "增效" },
		},
		removeLesserCurse = {
			enUS = { "curse" },
			deDE = { "fluch" },
			frFR = { "malédiction", "malediction" },
			koKR = { "저주" },
			zhCN = { "诅咒" },
		},
		-- not in 2007
		slowFall = { new = true, enUS = { "slowfall", "slow fall" } },
	},
	DRUID = {
		mark = {
			enUS = { "motw", "mark" },
			deDE = { "mal", "mdw" },
			frFR = { "marque" },
			koKR = { "야징", "발바닥" },
			zhCN = { "野性印记", "印记", "爪子" },
		},
		gift = {
			enUS = { "gotw", "gift", "group mark" },
			-- 2007's German list replaced the English one ("gift" is poison in German)
			deDE = { replace = true, "gotw", "group mark", "gabe", "gruppen mal", "gdw" },
			frFR = { "cadeau", "groupe marque" },
			koKR = { "야선", "선물" },
			zhCN = { "野性赐福", "群野性", "群爪", "群爪子" },
		},
		thorns = {
			enUS = { "thorns" },
			deDE = { "dornen" },
			frFR = { "epines" },
			koKR = { "가시" },
			zhCN = { "荆棘" },
		},
		innervate = {
			enUS = { "innervate" },
			deDE = { "anregen" },
			frFR = { "innervation" },
			koKR = { "정신", "자극" },
			zhCN = { "激活" },
		},
		removeCurse = {
			enUS = { "curse" },
			deDE = { "fluch" },
			frFR = { "malédiction", "malediction" },
			koKR = { "저주" },
			zhCN = { "诅咒" },
		},
		abolishPoison = {
			enUS = { "poison" },
			deDE = { "gift" },
			koKR = { "독", "독해제" },
			zhCN = { "中毒", "毒" },
		},
		curePoison = {
			enUS = { "poison" },
			deDE = { "gift" },
			koKR = { "해독" },
			zhCN = { "中毒", "毒" },
		},
		-- not in 2007
		ironbark = { new = true, enUS = { "ironbark", "bark" } },
		naturesCure = { new = true, enUS = { "dispel" } },
		removeCorruption = { new = true, enUS = {} },
		revive = { new = true, enUS = { "rez", "res" } },
		rebirth = { new = true, enUS = { "rez", "res", "rebirth" } },
	},
	PALADIN = {
		might = {
			enUS = { "might", "bom" },
			deDE = { "macht", "sdm" },
			frFR = { "puissance" },
			koKR = { "힘축" },
			zhCN = { "力量" },
		},
		wisdom = {
			enUS = { "wisdom", "wis", "bow" },
			deDE = { "weisheit", "sdw" },
			frFR = { "sagesse" },
			koKR = { "지축" },
			zhCN = { "智慧" },
		},
		freedom = {
			enUS = { "freedom", "bof" },
			deDE = { "freiheit", "sdf" },
			frFR = { "liberté", "liberte" },
			koKR = { "자축" },
			zhCN = { "自由" },
		},
		light = {
			enUS = { "light", "bol" },
			deDE = { "licht", "sdl" },
			frFR = { "lumière", "lumiere" },
			koKR = { "빛축" },
			zhCN = { "光明" },
		},
		sacrifice = {
			enUS = { "sacrifice" },
			deDE = { "opferung", "opfer", "opfern", "sdo" },
			koKR = { "희축" },
			zhCN = { "牺牲" },
		},
		kings = {
			enUS = { "kings", "king", "bok" },
			deDE = { "könige", "könig", "konige", "konig", "sdk" },
			frFR = { "roi", "rois" },
			koKR = { "왕축" },
			zhCN = { "王者" },
		},
		salvation = {
			enUS = { "salvation", "bos" },
			deDE = { "rettung", "sdr" },
			frFR = { "salut" },
			koKR = { "구축" },
			zhCN = { "拯救" },
		},
		sanctuary = {
			enUS = { "sanctuary" },
			deDE = { "refugium", "ref" },
			frFR = { "sanctuaire" },
			koKR = { "성축" },
			zhCN = { "庇护" },
		},
		protection = {
			enUS = { "protection" },
			deDE = { "schutz", "sds" },
			frFR = { "protection" },
			koKR = { "보축" },
			zhCN = { "保护" },
		},
		cleanse = {
			enUS = { "cleanse", "dispel", "cure" },
			deDE = { "bannen", "magie" },
			frFR = { "epuration", "dissiper", "magie" },
			koKR = { "정화", "독", "질병", "마법", "해제", "해독" },
			zhCN = { "清洁", "魔法", "驱散" },
		},
		purify = {
			enUS = { "purify", "poison", "disease" },
			deDE = { "gift", "krankheit", "krank" },
			frFR = { "purifie", "maladie" },
			koKR = { "순화" },
			zhCN = { "纯净", "疾病", "中毒", "毒" },
		},
		greaterMight = {
			enUS = { "gbom", "gmight" },
			deDE = { "gsdm", "gmacht" },
		},
		greaterKings = {
			enUS = { "gbok", "gkings", "gking" },
			deDE = { "gsdk", "gkönige", "gkönig" },
		},
		greaterWisdom = {
			enUS = { "gbow", "gwis", "gwisdom" },
			deDE = { "gsdw", "gweisheit" },
		},
		greaterLight = {
			enUS = { "gbol", "glight" },
			deDE = { "gsdl", "glicht" },
		},
		greaterSalvation = {
			enUS = { "gbos", "gsal", "gsalvation" },
			deDE = { "gsdr", "grettung" },
		},
		greaterSanctuary = {
			enUS = { "gbosa", "gsan", "gsanctuary" },
			deDE = { "gsdr", "gref", "grefugium" },
		},
		-- not in 2007
		spellwarding = { new = true, enUS = { "spellwarding", "spellward" } },
		cleanseToxins = { new = true, enUS = { "toxins" } },
		redemption = { new = true, enUS = { "rez", "res" } },
	},
	SHAMAN = {
		curePoison = {
			enUS = { "poison" },
			deDE = { "gift" },
			koKR = { "독", "해독" },
			zhCN = { "中毒", "毒" },
		},
		cureDisease = {
			enUS = { "disease" },
			deDE = { "krankheit", "krank" },
			frFR = { "maladie" },
			koKR = { "질병" },
			zhCN = { "疾病" },
		},
		waterBreathing = {
			enUS = { "water" },
			deDE = { "tauchen", "atmung", "wasser atmung" },
			frFR = { "l'eau", "leau" },
			koKR = { "호흡" },
			zhCN = { "水下", "水下呼吸", "呼吸" },
		},
		-- not in 2007
		waterWalking = { new = true, enUS = { "water walking", "waterwalk", "walk" } },
		earthShield = { new = true, enUS = { "es", "earth shield", "earth" } },
		purifySpirit = { new = true, enUS = { "purify", "dispel", "curse" } },
		cleanseSpirit = { new = true, enUS = { "cleanse", "curse" } },
		ancestralSpirit = { new = true, enUS = { "rez", "res" } },
	},
	WARLOCK = {
		unendingBreath = {
			enUS = { "water" },
			deDE = { "tauchen", "atmung", "wasser atmung" },
			frFR = { "l'eau", "leau" },
			koKR = { "호흡", "숨결" },
			zhCN = { "水下", "水下呼吸", "呼吸", "魔息" },
		},
		detectInvisibility = {
			enUS = { "invis", "invisible" },
			deDE = { "unsicht", "unsichtbar" },
			koKR = { "은신감지", "감지" },
			zhCN = { "隐形", "探隐", "反隐" },
		},
		summon = {
			enUS = { "summon" },
			deDE = { "beschwörung", "beschworung" },
			frFR = { "invoquant", "invocation" },
			koKR = { "소환" },
			zhCN = { "召唤" },
		},
		-- not in 2007
		soulstone = { new = true, enUS = { "soulstone", "ss", "stone" } },
		darkIntent = { new = true, enUS = { "di", "intent" } },
	},
	-- not in 2007
	HUNTER = { misdirection = { new = true, enUS = { "md", "misdirect", "misdirection" } } },
	ROGUE = { tricks = { new = true, enUS = { "tricks", "tott" } } },
	MONK = {
		legacyEmperor = { new = true, enUS = { "legacy", "emperor" } },
		legacyTiger = { new = true, enUS = { "tiger" } },
		lifeCocoon = { new = true, enUS = { "cocoon", "lc" } },
		detox = { new = true, enUS = { "detox", "dispel", "poison", "disease" } },
		resuscitate = { new = true, enUS = { "rez", "res" } },
	},
	DEATHKNIGHT = { raiseAlly = { new = true, enUS = { "rez", "res" } } },
	WARRIOR = { vigilance = { new = true, enUS = { "vigilance", "vig" } } },
	EVOKER = {
		timeDilation = { new = true, enUS = { "td", "dilation" } },
		sourceOfMagic = { new = true, enUS = { "som", "source" } },
		prescience = { new = true, enUS = { "prescience", "presc" } },
		blisteringScales = { new = true, enUS = { "scales", "blistering" } },
		naturalize = { new = true, enUS = { "naturalize", "dispel", "poison" } },
		expunge = { new = true, enUS = { "expunge", "poison" } },
		cauterizingFlame = { new = true, enUS = { "cauterize", "bleed", "curse", "disease" } },
		evokerReturn = { new = true, enUS = { "rez", "res" } },
	},
}

-- One entry's words: its wordsFrom lists (or its own key) joined, each merged
-- with English the 2007 way. Returns { { word, is2007 }, ... }, lower case, no repeats, in order.
local function rawWords(class, entry, locale)
	local out, seen = {}, {}
	local byKey = D.words[class] or {}
	for _, k in ipairs(entry.wordsFrom or { entry.key }) do
		local lists = byKey[k]
		if lists then
			local old = not lists.new
			local function add(w)
				w = w:lower()
				if w ~= "" and not seen[w] then seen[w] = true; out[#out + 1] = { w, old } end
			end
			local en, loc = lists.enUS or {}, locale ~= "enUS" and lists[locale] or nil
			local mode = loc and (loc.replace and "replace" or D.localeMode[locale]) or nil
			if not loc then
				for _, w in ipairs(en) do add(w) end
			elseif mode == "replace" then
				for _, w in ipairs(loc) do add(w) end
			elseif mode == "append" then
				for _, w in ipairs(en) do add(w) end
				for _, w in ipairs(loc) do add(w) end
			else -- prepend
				for _, w in ipairs(loc) do add(w) end
				for _, w in ipairs(en) do add(w) end
			end
		end
	end
	return out
end

-- When a whisper's word fits more than one known, turned-on spell of a class, the higher priority wins
-- (the upgrade first); a group version never wins a word a single-target spell also has, and equal
-- priorities fall back to list order. Spells may share default words: a level 20 priest's "disease"
-- is Cure Disease, a level 40 one's is Abolish Disease. Unlisted spells have priority 0.
D.priority = {
	PRIEST = { abolishDisease = 1, purify = 1 },
	DRUID = { abolishPoison = 1, naturesCure = 1, revive = 1 },
	PALADIN = { cleanse = 1, greaterSalvation = 1 },
	SHAMAN = { purifySpirit = 1 },
	EVOKER = { naturalize = 2, expunge = 1 },
}

-- the rank a spell entry has when two spells share a matching word: higher wins
function D.Priority(class, entry)
	local p = (D.priority[class] and D.priority[class][entry.key]) or 0
	if entry.isGroup then p = p - 100 end
	return p
end

-- The default words of every spell on a client in one language: [class][key] = { word, ... }
local cache = {}
function D.Defaults(client, locale)
	local id = tostring(client) .. ":" .. tostring(locale)
	if cache[id] then return cache[id] end
	local words = {}
	for class, list in pairs(D.spells[client] or {}) do
		words[class] = {}
		for _, e in ipairs(list) do
			local out = {}
			for _, wo in ipairs(rawWords(class, e, locale)) do out[#out + 1] = wo[1] end
			words[class][e.key] = out
		end
	end
	cache[id] = words
	return words
end

-- the default words of one spell entry (see D.Defaults)
function D.DefaultWords(class, entry, locale, client)
	local words = D.Defaults(client or WCSW.client, locale)
	return (words[class] and words[class][entry.key]) or {}
end

D.spells = {}
D.spells.era = {  -- build 1.15.9.70576
	PRIEST = {
		{ key = "prayerFortitude", id = 21562, name = "Prayer of Fortitude", icon = 135941, ranks = { { 21562, 48, 1 }, { 21564, 60, 2 } }, isGroup = true },
		{ key = "fortitude", id = 1243, name = "Power Word: Fortitude", icon = 135987, ranks = { { 1243, 1, 1 }, { 1244, 12, 2 }, { 1245, 24, 3 }, { 2791, 36, 4 }, { 10937, 48, 5 }, { 10938, 60, 6 } }, group = "prayerFortitude" },
		{ key = "prayerShadow", id = 27683, name = "Prayer of Shadow Protection", icon = 135945, ranks = { { 27683, 56, 1 } }, isGroup = true },
		{ key = "shadowProtection", id = 976, name = "Shadow Protection", icon = 136121, ranks = { { 976, 30, 1 }, { 10957, 42, 2 }, { 10958, 56, 3 } }, group = "prayerShadow" },
		{ key = "prayerSpirit", id = 27681, name = "Prayer of Spirit", icon = 135946, ranks = { { 27681, 60, 1 } }, isGroup = true },
		{ key = "divineSpirit", id = 14752, name = "Divine Spirit", icon = 135898, ranks = { { 14752, 30, 1 }, { 14818, 40, 2 }, { 14819, 50, 3 }, { 27841, 60, 4 } }, group = "prayerSpirit" },
		{ key = "shield", id = 17, name = "Power Word: Shield", icon = 135940, ranks = { { 17, 6, 1 }, { 592, 12, 2 }, { 600, 18, 3 }, { 3747, 24, 4 }, { 6065, 30, 5 }, { 6066, 36, 6 }, { 10898, 42, 7 }, { 10899, 48, 8 }, { 10900, 54, 9 }, { 10901, 60, 10 } }, combat = true },
		{ key = "fearWard", id = 6346, name = "Fear Ward", icon = 135902, ranks = { { 6346, 20 } }, combat = true },
		{ key = "powerInfusion", id = 10060, name = "Power Infusion", icon = 135939, ranks = { { 10060, 40 } }, combat = true },
		{ key = "abolishDisease", id = 552, name = "Abolish Disease", icon = 136066, ranks = { { 552, 32 } }, combat = true, cure = true },
		{ key = "cureDisease", id = 528, name = "Cure Disease", icon = 135935, ranks = { { 528, 14 } }, combat = true, cure = true },
		{ key = "dispelMagic", id = 527, name = "Dispel Magic", icon = 135894, ranks = { { 527, 18, 1 }, { 988, 36, 2 } }, combat = true, cure = true },
		{ key = "resurrection", id = 2006, name = "Resurrection", icon = 135955, ranks = { { 2006, 10, 1 }, { 2010, 22, 2 }, { 10880, 34, 3 }, { 10881, 46, 4 }, { 20770, 58, 5 } }, rez = true },
	},
	MAGE = {
		{ key = "brilliance", id = 23028, name = "Arcane Brilliance", icon = 135869, ranks = { { 23028, 56, 1 } }, isGroup = true },
		{ key = "intellect", id = 1459, name = "Arcane Intellect", icon = 135932, ranks = { { 1459, 1, 1 }, { 1460, 14, 2 }, { 1461, 28, 3 }, { 10156, 42, 4 }, { 10157, 56, 5 } }, group = "brilliance" },
		{ key = "dampen", id = 604, name = "Dampen Magic", icon = 136006, ranks = { { 604, 12, 1 }, { 8450, 24, 2 }, { 8451, 36, 3 }, { 10173, 48, 4 }, { 10174, 60, 5 } } },
		{ key = "amplify", id = 1008, name = "Amplify Magic", icon = 135907, ranks = { { 1008, 18, 1 }, { 8455, 30, 2 }, { 10169, 42, 3 }, { 10170, 54, 4 } } },
		{ key = "slowFall", id = 130, name = "Slow Fall", icon = 135992, ranks = { { 130, 12 } } },
		{ key = "removeLesserCurse", id = 475, name = "Remove Lesser Curse", icon = 136082, ranks = { { 475, 18 } }, combat = true, cure = true },
	},
	DRUID = {
		{ key = "gift", id = 21849, name = "Gift of the Wild", icon = 136078, ranks = { { 21849, 50, 1 }, { 21850, 60, 2 } }, isGroup = true },
		{ key = "mark", id = 1126, name = "Mark of the Wild", icon = 136078, ranks = { { 1126, 1, 1 }, { 5232, 10, 2 }, { 6756, 20, 3 }, { 5234, 30, 4 }, { 8907, 40, 5 }, { 9884, 50, 6 }, { 9885, 60, 7 } }, group = "gift" },
		{ key = "thorns", id = 467, name = "Thorns", icon = 136104, ranks = { { 467, 6, 1 }, { 782, 14, 2 }, { 1075, 24, 3 }, { 8914, 34, 4 }, { 9756, 44, 5 }, { 9910, 54, 6 } } },
		{ key = "innervate", id = 29166, name = "Innervate", icon = 136048, ranks = { { 29166, 40 } }, combat = true },
		{ key = "removeCurse", id = 2782, name = "Remove Curse", icon = 135952, ranks = { { 2782, 24 } }, combat = true, cure = true },
		{ key = "abolishPoison", id = 2893, name = "Abolish Poison", icon = 136068, ranks = { { 2893, 26 } }, combat = true, cure = true },
		{ key = "curePoison", id = 8946, name = "Cure Poison", icon = 136067, ranks = { { 8946, 14 } }, combat = true, cure = true },
		{ key = "rebirth", id = 20484, name = "Rebirth", icon = 136080, ranks = { { 20484, 20, 1 }, { 20739, 30, 2 }, { 20742, 40, 3 }, { 20747, 50, 4 }, { 20748, 60, 5 } }, combat = true, rez = true },
	},
	PALADIN = {
		{ key = "greaterMight", id = 25782, name = "Greater Blessing of Might", icon = 135908, ranks = { { 25782, 52, 1 }, { 25916, 60, 2 } }, isGroup = true, byClass = true },
		{ key = "might", id = 19740, name = "Blessing of Might", icon = 135906, ranks = { { 19740, 4, 1 }, { 19834, 12, 2 }, { 19835, 22, 3 }, { 19836, 32, 4 }, { 19837, 42, 5 }, { 19838, 52, 6 }, { 25291, 60, 7 } }, group = "greaterMight" },
		{ key = "greaterWisdom", id = 25894, name = "Greater Blessing of Wisdom", icon = 135912, ranks = { { 25894, 54, 1 }, { 25918, 60, 2 } }, isGroup = true, byClass = true },
		{ key = "wisdom", id = 19742, name = "Blessing of Wisdom", icon = 135970, ranks = { { 19742, 14, 1 }, { 19850, 24, 2 }, { 19852, 34, 3 }, { 19853, 44, 4 }, { 19854, 54, 5 }, { 25290, 60, 6 } }, group = "greaterWisdom" },
		{ key = "greaterKings", id = 25898, name = "Greater Blessing of Kings", icon = 135993, ranks = { { 25898, 60 } }, isGroup = true, byClass = true },
		{ key = "kings", id = 20217, name = "Blessing of Kings", icon = 135995, ranks = { { 20217, 20 } }, group = "greaterKings" },
		{ key = "greaterSalvation", id = 25895, name = "Greater Blessing of Salvation", icon = 135910, ranks = { { 25895, 60 } }, isGroup = true, byClass = true },
		{ key = "salvation", id = 1038, name = "Blessing of Salvation", icon = 135967, ranks = { { 1038, 26 } }, group = "greaterSalvation" },
		{ key = "greaterLight", id = 25890, name = "Greater Blessing of Light", icon = 135909, ranks = { { 25890, 60, 1 } }, isGroup = true, byClass = true },
		{ key = "light", id = 19977, name = "Blessing of Light", icon = 135943, ranks = { { 19977, 40, 1 }, { 19978, 50, 2 }, { 19979, 60, 3 } }, group = "greaterLight" },
		{ key = "greaterSanctuary", id = 25899, name = "Greater Blessing of Sanctuary", icon = 135911, ranks = { { 25899, 60, 1 } }, isGroup = true, byClass = true },
		{ key = "sanctuary", id = 20911, name = "Blessing of Sanctuary", icon = 136051, ranks = { { 20911, 30, 1 }, { 20912, 40, 2 }, { 20913, 50, 3 }, { 20914, 60, 4 } }, group = "greaterSanctuary" },
		{ key = "freedom", id = 1044, name = "Blessing of Freedom", icon = 135968, ranks = { { 1044, 18 } }, combat = true },
		{ key = "protection", id = 1022, name = "Blessing of Protection", icon = 135964, ranks = { { 1022, 10, 1 }, { 5599, 24, 2 }, { 10278, 38, 3 } }, combat = true },
		{ key = "sacrifice", id = 6940, name = "Blessing of Sacrifice", icon = 135966, ranks = { { 6940, 46, 1 }, { 20729, 54, 2 } }, combat = true },
		{ key = "cleanse", id = 4987, name = "Cleanse", icon = 135953, ranks = { { 4987, 42 } }, combat = true, cure = true },
		{ key = "purify", id = 1152, name = "Purify", icon = 135949, ranks = { { 1152, 8 } }, combat = true, cure = true },
		{ key = "redemption", id = 7328, name = "Redemption", icon = 135955, ranks = { { 7328, 12, 1 }, { 10322, 24, 2 }, { 10324, 36, 3 }, { 20772, 48, 4 }, { 20773, 60, 5 } }, rez = true },
	},
	SHAMAN = {
		{ key = "curePoison", id = 526, name = "Cure Poison", icon = 136067, ranks = { { 526, 16 } }, combat = true, cure = true },
		{ key = "cureDisease", id = 2870, name = "Cure Disease", icon = 136083, ranks = { { 2870, 22 } }, combat = true, cure = true },
		{ key = "waterBreathing", id = 131, name = "Water Breathing", icon = 136148, ranks = { { 131, 22 } } },
		{ key = "waterWalking", id = 546, name = "Water Walking", icon = 135863, ranks = { { 546, 28 } } },
		{ key = "ancestralSpirit", id = 2008, name = "Ancestral Spirit", icon = 136077, ranks = { { 2008, 12, 1 }, { 20609, 24, 2 }, { 20610, 36, 3 }, { 20776, 48, 4 }, { 20777, 60, 5 } }, rez = true },
	},
	WARLOCK = {
		{ key = "unendingBreath", id = 5697, name = "Unending Breath", icon = 136148, ranks = { { 5697, 16 } } },
		{ key = "detectInvisibility", id = 132, name = "Detect Invisibility", icon = 136153, ranks = { { 132, 26 }, { 2970, 38 }, { 11743, 50 } } },
		{ key = "summon", id = 698, name = "Ritual of Summoning", icon = 136223, ranks = { { 698, 20 } } },
	},
}
D.spells.tbc = {  -- build 2.5.6.70577
	PRIEST = {
		{ key = "prayerFortitude", id = 21562, name = "Prayer of Fortitude", icon = 135941, ranks = { { 21562, 48, 1 }, { 21564, 60, 2 }, { 25392, 70, 3 } }, isGroup = true },
		{ key = "fortitude", id = 1243, name = "Power Word: Fortitude", icon = 135987, ranks = { { 1243, 1, 1 }, { 1244, 12, 2 }, { 1245, 24, 3 }, { 2791, 36, 4 }, { 10937, 48, 5 }, { 10938, 60, 6 }, { 25389, 70, 7 } }, group = "prayerFortitude" },
		{ key = "prayerShadow", id = 27683, name = "Prayer of Shadow Protection", icon = 135945, ranks = { { 27683, 56, 1 }, { 39374, 70, 2 } }, isGroup = true },
		{ key = "shadowProtection", id = 976, name = "Shadow Protection", icon = 136121, ranks = { { 976, 30, 1 }, { 10957, 42, 2 }, { 10958, 56, 3 }, { 25433, 68, 4 } }, group = "prayerShadow" },
		{ key = "prayerSpirit", id = 27681, name = "Prayer of Spirit", icon = 135946, ranks = { { 27681, 60, 1 }, { 32999, 70, 2 } }, isGroup = true },
		{ key = "divineSpirit", id = 14752, name = "Divine Spirit", icon = 135898, ranks = { { 14752, 30, 1 }, { 14818, 40, 2 }, { 14819, 50, 3 }, { 27841, 60, 4 }, { 25312, 70, 5 } }, group = "prayerSpirit" },
		{ key = "shield", id = 17, name = "Power Word: Shield", icon = 135940, ranks = { { 17, 6, 1 }, { 592, 12, 2 }, { 600, 18, 3 }, { 3747, 24, 4 }, { 6065, 30, 5 }, { 6066, 36, 6 }, { 10898, 42, 7 }, { 10899, 48, 8 }, { 10900, 54, 9 }, { 10901, 60, 10 }, { 25217, 65, 11 }, { 25218, 70, 12 } }, combat = true },
		{ key = "fearWard", id = 6346, name = "Fear Ward", icon = 135902, ranks = { { 6346, 20 } }, combat = true },
		{ key = "powerInfusion", id = 10060, name = "Power Infusion", icon = 135939, ranks = { { 10060, 40 } }, combat = true },
		{ key = "painSuppression", id = 33206, name = "Pain Suppression", icon = 135936, ranks = { { 33206, 0 } }, combat = true },
		{ key = "abolishDisease", id = 552, name = "Abolish Disease", icon = 136066, ranks = { { 552, 32 } }, combat = true, cure = true },
		{ key = "cureDisease", id = 528, name = "Cure Disease", icon = 135935, ranks = { { 528, 14 } }, combat = true, cure = true },
		{ key = "dispelMagic", id = 527, name = "Dispel Magic", icon = 135894, ranks = { { 527, 18, 1 }, { 988, 36, 2 } }, combat = true, cure = true },
		{ key = "resurrection", id = 2006, name = "Resurrection", icon = 135955, ranks = { { 2006, 10, 1 }, { 2010, 22, 2 }, { 10880, 34, 3 }, { 10881, 46, 4 }, { 20770, 58, 5 }, { 25435, 68, 6 } }, rez = true },
	},
	MAGE = {
		{ key = "brilliance", id = 23028, name = "Arcane Brilliance", icon = 135869, ranks = { { 23028, 56, 1 }, { 27127, 70, 2 } }, isGroup = true },
		{ key = "intellect", id = 1459, name = "Arcane Intellect", icon = 135932, ranks = { { 1459, 1, 1 }, { 1460, 14, 2 }, { 1461, 28, 3 }, { 10156, 42, 4 }, { 10157, 56, 5 }, { 27126, 70, 6 } }, group = "brilliance" },
		{ key = "dampen", id = 604, name = "Dampen Magic", icon = 136006, ranks = { { 604, 12, 1 }, { 8450, 24, 2 }, { 8451, 36, 3 }, { 10173, 48, 4 }, { 10174, 60, 5 }, { 33944, 67, 6 } } },
		{ key = "amplify", id = 1008, name = "Amplify Magic", icon = 135907, ranks = { { 1008, 18, 1 }, { 8455, 30, 2 }, { 10169, 42, 3 }, { 10170, 54, 4 }, { 27130, 63, 5 }, { 33946, 69, 6 } } },
		{ key = "slowFall", id = 130, name = "Slow Fall", icon = 135992, ranks = { { 130, 12 } } },
		{ key = "removeLesserCurse", id = 475, name = "Remove Lesser Curse", icon = 136082, ranks = { { 475, 18 } }, combat = true, cure = true },
	},
	DRUID = {
		{ key = "gift", id = 21849, name = "Gift of the Wild", icon = 136038, ranks = { { 21849, 50, 1 }, { 21850, 60, 2 }, { 26991, 70, 3 } }, isGroup = true },
		{ key = "mark", id = 1126, name = "Mark of the Wild", icon = 136078, ranks = { { 1126, 1, 1 }, { 5232, 10, 2 }, { 6756, 20, 3 }, { 5234, 30, 4 }, { 8907, 40, 5 }, { 9884, 50, 6 }, { 9885, 60, 7 }, { 26990, 70, 8 } }, group = "gift" },
		{ key = "thorns", id = 467, name = "Thorns", icon = 136104, ranks = { { 467, 6, 1 }, { 782, 14, 2 }, { 1075, 24, 3 }, { 8914, 34, 4 }, { 9756, 44, 5 }, { 9910, 54, 6 }, { 26992, 64, 7 } } },
		{ key = "innervate", id = 29166, name = "Innervate", icon = 136048, ranks = { { 29166, 40 } }, combat = true },
		{ key = "removeCurse", id = 2782, name = "Remove Curse", icon = 135952, ranks = { { 2782, 24 } }, combat = true, cure = true },
		{ key = "abolishPoison", id = 2893, name = "Abolish Poison", icon = 136068, ranks = { { 2893, 26 } }, combat = true, cure = true },
		{ key = "curePoison", id = 8946, name = "Cure Poison", icon = 136067, ranks = { { 8946, 14 } }, combat = true, cure = true },
		{ key = "rebirth", id = 20484, name = "Rebirth", icon = 136080, ranks = { { 20484, 20, 1 }, { 20739, 30, 2 }, { 20742, 40, 3 }, { 20747, 50, 4 }, { 20748, 60, 5 }, { 26994, 69, 6 } }, combat = true, rez = true },
	},
	PALADIN = {
		{ key = "greaterMight", id = 25782, name = "Greater Blessing of Might", icon = 135908, ranks = { { 25782, 52, 1 }, { 25916, 60, 2 }, { 27141, 70, 3 } }, isGroup = true, byClass = true },
		{ key = "might", id = 19740, name = "Blessing of Might", icon = 135906, ranks = { { 19740, 4, 1 }, { 19834, 12, 2 }, { 19835, 22, 3 }, { 19836, 32, 4 }, { 19837, 42, 5 }, { 19838, 52, 6 }, { 25291, 60, 7 }, { 27140, 70, 8 } }, group = "greaterMight" },
		{ key = "greaterWisdom", id = 25894, name = "Greater Blessing of Wisdom", icon = 135912, ranks = { { 25894, 54, 1 }, { 25918, 60, 2 }, { 27143, 65, 3 } }, isGroup = true, byClass = true },
		{ key = "wisdom", id = 19742, name = "Blessing of Wisdom", icon = 135970, ranks = { { 19742, 14, 1 }, { 19850, 24, 2 }, { 19852, 34, 3 }, { 19853, 44, 4 }, { 19854, 54, 5 }, { 25290, 60, 6 }, { 27142, 65, 7 } }, group = "greaterWisdom" },
		{ key = "greaterKings", id = 25898, name = "Greater Blessing of Kings", icon = 135993, ranks = { { 25898, 60 } }, isGroup = true, byClass = true },
		{ key = "kings", id = 20217, name = "Blessing of Kings", icon = 135995, ranks = { { 20217, 20 } }, group = "greaterKings" },
		{ key = "greaterSalvation", id = 25895, name = "Greater Blessing of Salvation", icon = 135910, ranks = { { 25895, 60 } }, isGroup = true, byClass = true },
		{ key = "salvation", id = 1038, name = "Blessing of Salvation", icon = 135967, ranks = { { 1038, 26 } }, group = "greaterSalvation" },
		{ key = "greaterLight", id = 25890, name = "Greater Blessing of Light", icon = 135909, ranks = { { 25890, 60, 1 }, { 27145, 69, 2 } }, isGroup = true, byClass = true },
		{ key = "light", id = 19977, name = "Blessing of Light", icon = 135943, ranks = { { 19977, 40, 1 }, { 19978, 50, 2 }, { 19979, 60, 3 }, { 27144, 69, 4 } }, group = "greaterLight" },
		{ key = "greaterSanctuary", id = 25899, name = "Greater Blessing of Sanctuary", icon = 135911, ranks = { { 25899, 60, 1 }, { 27169, 70, 2 } }, isGroup = true, byClass = true },
		{ key = "sanctuary", id = 20911, name = "Blessing of Sanctuary", icon = 136051, ranks = { { 20911, 30, 1 }, { 20912, 40, 2 }, { 20913, 50, 3 }, { 20914, 60, 4 }, { 27168, 70, 5 } }, group = "greaterSanctuary" },
		{ key = "freedom", id = 1044, name = "Blessing of Freedom", icon = 135968, ranks = { { 1044, 18 } }, combat = true },
		{ key = "protection", id = 1022, name = "Blessing of Protection", icon = 135964, ranks = { { 1022, 10, 1 }, { 5599, 24, 2 }, { 10278, 38, 3 } }, combat = true },
		{ key = "sacrifice", id = 6940, name = "Blessing of Sacrifice", icon = 135966, ranks = { { 6940, 46, 1 }, { 20729, 54, 2 }, { 27147, 62, 3 }, { 27148, 70, 4 } }, combat = true },
		{ key = "cleanse", id = 4987, name = "Cleanse", icon = 135953, ranks = { { 4987, 42 } }, combat = true, cure = true },
		{ key = "purify", id = 1152, name = "Purify", icon = 135949, ranks = { { 1152, 8 } }, combat = true, cure = true },
		{ key = "redemption", id = 7328, name = "Redemption", icon = 135955, ranks = { { 7328, 12, 1 }, { 10322, 24, 2 }, { 10324, 36, 3 }, { 20772, 48, 4 }, { 20773, 60, 5 } }, rez = true },
	},
	SHAMAN = {
		{ key = "earthShield", id = 974, name = "Earth Shield", icon = 136089, ranks = { { 974, 50, 1 }, { 32593, 60, 2 }, { 32594, 70, 3 } }, combat = true },
		{ key = "curePoison", id = 526, name = "Cure Poison", icon = 136067, ranks = { { 526, 16 } }, combat = true, cure = true },
		{ key = "cureDisease", id = 2870, name = "Cure Disease", icon = 136083, ranks = { { 2870, 22 } }, combat = true, cure = true },
		{ key = "waterBreathing", id = 131, name = "Water Breathing", icon = 136148, ranks = { { 131, 22 } } },
		{ key = "waterWalking", id = 546, name = "Water Walking", icon = 135863, ranks = { { 546, 28 } } },
		{ key = "ancestralSpirit", id = 2008, name = "Ancestral Spirit", icon = 136077, ranks = { { 2008, 12, 1 }, { 20609, 24, 2 }, { 20610, 36, 3 }, { 20776, 48, 4 }, { 20777, 60, 5 } }, rez = true },
	},
	WARLOCK = {
		{ key = "unendingBreath", id = 5697, name = "Unending Breath", icon = 136148, ranks = { { 5697, 16 } } },
		{ key = "detectInvisibility", id = 132, name = "Detect Invisibility", icon = 136153, ranks = { { 132, 26 } } },
		{ key = "summon", id = 698, name = "Ritual of Summoning", icon = 136223, ranks = { { 698, 20 } } },
	},
	HUNTER = {
		{ key = "misdirection", id = 34477, name = "Misdirection", icon = 132180, ranks = { { 34477, 70 } } },
	},
}
D.spells.forever = {  -- build 1.60.1.70888
	PRIEST = {
		{ key = "prayerFortitude", id = 21562, name = "Prayer of Fortitude", icon = 135941, ranks = { { 21562, 48, 1 }, { 21564, 60, 2 } }, isGroup = true },
		{ key = "fortitude", id = 1243, name = "Power Word: Fortitude", icon = 135987, ranks = { { 1243, 1, 1 }, { 1244, 12, 2 }, { 1245, 24, 3 }, { 2791, 36, 4 }, { 10937, 48, 5 }, { 10938, 60, 6 } }, group = "prayerFortitude" },
		{ key = "prayerShadow", id = 27683, name = "Prayer of Shadow Protection", icon = 135945, ranks = { { 27683, 56 } }, isGroup = true },
		{ key = "shadowProtection", id = 976, name = "Shadow Protection", icon = 136121, ranks = { { 976, 30, 1 }, { 10957, 42, 2 }, { 10958, 56, 3 } }, group = "prayerShadow" },
		{ key = "prayerSpirit", id = 27681, name = "Prayer of Spirit", icon = 135946, ranks = { { 27681, 60, 1 } }, isGroup = true },
		{ key = "divineSpirit", id = 14752, name = "Divine Spirit", icon = 135898, ranks = { { 14752, 30, 1 }, { 14818, 40, 2 }, { 14819, 50, 3 }, { 27841, 60, 4 } }, group = "prayerSpirit" },
		{ key = "shield", id = 17, name = "Power Word: Shield", icon = 135940, ranks = { { 17, 6, 1 }, { 592, 12, 2 }, { 600, 18, 3 }, { 3747, 24, 4 }, { 6065, 30, 5 }, { 6066, 36, 6 }, { 10898, 42, 7 }, { 10899, 48, 8 }, { 10900, 54, 9 }, { 10901, 60, 10 } }, combat = true },
		{ key = "fearWard", id = 6346, name = "Fear Ward", icon = 135902, ranks = { { 6346, 20 } }, combat = true },
		{ key = "powerInfusion", id = 10060, name = "Power Infusion", icon = 135939, ranks = { { 10060, 40 } }, combat = true },
		{ key = "abolishDisease", id = 552, name = "Abolish Disease", icon = 136066, ranks = { { 552, 32 } }, combat = true, cure = true },
		{ key = "cureDisease", id = 528, name = "Cure Disease", icon = 135935, ranks = { { 528, 14 } }, combat = true, cure = true },
		{ key = "dispelMagic", id = 527, name = "Dispel Magic", icon = 135894, ranks = { { 527, 18, 1 }, { 988, 36, 2 } }, combat = true, cure = true },
		{ key = "resurrection", id = 2006, name = "Resurrection", icon = 135955, ranks = { { 2006, 10, 1 }, { 2010, 22, 2 }, { 10880, 34, 3 }, { 10881, 46, 4 }, { 20770, 58, 5 } }, rez = true },
	},
	MAGE = {
		{ key = "brilliance", id = 23028, name = "Arcane Brilliance", icon = 135869, ranks = { { 23028, 56 } }, isGroup = true },
		{ key = "intellect", id = 1459, name = "Arcane Intellect", icon = 135932, ranks = { { 1459, 1, 1 }, { 1460, 14, 2 }, { 1461, 28, 3 }, { 10156, 42, 4 }, { 10157, 56, 5 } }, group = "brilliance" },
		{ key = "dampen", id = 604, name = "Dampen Magic", icon = 136006, ranks = { { 604, 12, 1 }, { 8450, 24, 2 }, { 8451, 36, 3 }, { 10173, 48, 4 }, { 10174, 60, 5 } } },
		{ key = "amplify", id = 1008, name = "Amplify Magic", icon = 135907, ranks = { { 1008, 18, 1 }, { 8455, 30, 2 }, { 10169, 42, 3 }, { 10170, 54, 4 } } },
		{ key = "slowFall", id = 130, name = "Slow Fall", icon = 135992, ranks = { { 130, 12 } } },
		{ key = "removeLesserCurse", id = 475, name = "Remove Lesser Curse", icon = 136082, ranks = { { 475, 18 } }, combat = true, cure = true },
	},
	DRUID = {
		{ key = "gift", id = 21849, name = "Gift of the Wild", icon = 136078, ranks = { { 21849, 50, 1 }, { 21850, 60, 2 } }, isGroup = true },
		{ key = "mark", id = 1126, name = "Mark of the Wild", icon = 136078, ranks = { { 1126, 1, 1 }, { 5232, 10, 2 }, { 6756, 20, 3 }, { 5234, 30, 4 }, { 8907, 40, 5 }, { 9884, 50, 6 }, { 9885, 60, 7 } }, group = "gift" },
		{ key = "thorns", id = 467, name = "Thorns", icon = 136104, ranks = { { 467, 6, 1 }, { 782, 14, 2 }, { 1075, 24, 3 }, { 8914, 34, 4 }, { 9756, 44, 5 }, { 9910, 54, 6 } } },
		{ key = "innervate", id = 29166, name = "Innervate", icon = 136048, ranks = { { 29166, 40 } }, combat = true },
		{ key = "removeCurse", id = 2782, name = "Remove Curse", icon = 135952, ranks = { { 2782, 24 } }, combat = true, cure = true },
		{ key = "abolishPoison", id = 2893, name = "Abolish Poison", icon = 136068, ranks = { { 2893, 26 } }, combat = true, cure = true },
		{ key = "curePoison", id = 8946, name = "Cure Poison", icon = 136067, ranks = { { 8946, 14 } }, combat = true, cure = true },
		{ key = "revive", id = 437138, name = "Revive", icon = 132132, ranks = { { 437138, 12, 1 }, { 1237948, 24, 2 }, { 1237949, 36, 3 }, { 1237950, 48, 4 }, { 1237951, 60, 5 } }, rez = true },
		{ key = "rebirth", id = 20484, name = "Rebirth", icon = 136080, ranks = { { 20484, 20, 1 }, { 20739, 30, 2 }, { 20742, 40, 3 }, { 20747, 50, 4 }, { 20748, 60, 5 } }, combat = true, rez = true },
	},
	PALADIN = {
		{ key = "greaterMight", id = 25782, name = "Greater Blessing of Might", icon = 135908, ranks = { { 25782, 52, 1 }, { 25916, 60, 2 } }, isGroup = true, byClass = true },
		{ key = "might", id = 19740, name = "Blessing of Might", icon = 135906, ranks = { { 19740, 4, 1 }, { 19834, 12, 2 }, { 19835, 22, 3 }, { 19836, 32, 4 }, { 19837, 42, 5 }, { 19838, 52, 6 }, { 25291, 60, 7 } }, group = "greaterMight" },
		{ key = "greaterWisdom", id = 25894, name = "Greater Blessing of Wisdom", icon = 135912, ranks = { { 25894, 54, 1 }, { 25918, 60, 2 } }, isGroup = true, byClass = true },
		{ key = "wisdom", id = 19742, name = "Blessing of Wisdom", icon = 135970, ranks = { { 19742, 14, 1 }, { 19850, 24, 2 }, { 19852, 34, 3 }, { 19853, 44, 4 }, { 19854, 54, 5 }, { 25290, 60, 6 } }, group = "greaterWisdom" },
		{ key = "greaterKings", id = 25898, name = "Greater Blessing of Kings", icon = 135993, ranks = { { 25898, 60 } }, isGroup = true, byClass = true },
		{ key = "kings", id = 20217, name = "Blessing of Kings", icon = 135995, ranks = { { 20217, 20 } }, group = "greaterKings" },
		{ key = "freedom", id = 1044, name = "Blessing of Freedom", icon = 135968, ranks = { { 1044, 18 } }, combat = true },
		{ key = "protection", id = 1022, name = "Blessing of Protection", icon = 135964, ranks = { { 1022, 10, 1 }, { 5599, 24, 2 }, { 10278, 38, 3 } }, combat = true },
		{ key = "sacrifice", id = 6940, name = "Blessing of Sacrifice", icon = 135966, ranks = { { 6940, 46, 1 }, { 20729, 54, 2 } }, combat = true },
		{ key = "cleanse", id = 4987, name = "Cleanse", icon = 135953, ranks = { { 4987, 42 } }, combat = true, cure = true },
		{ key = "purify", id = 1152, name = "Purify", icon = 135949, ranks = { { 1152, 8 } }, combat = true, cure = true },
		{ key = "redemption", id = 7328, name = "Redemption", icon = 135955, ranks = { { 7328, 12, 1 }, { 10322, 24, 2 }, { 10324, 36, 3 }, { 20772, 48, 4 }, { 20773, 60, 5 } }, rez = true },
	},
	SHAMAN = {
		{ key = "curePoison", id = 526, name = "Cure Poison", icon = 136067, ranks = { { 526, 16 } }, combat = true, cure = true },
		{ key = "cureDisease", id = 2870, name = "Cure Disease", icon = 136083, ranks = { { 2870, 22 } }, combat = true, cure = true },
		{ key = "waterBreathing", id = 131, name = "Water Breathing", icon = 136148, ranks = { { 131, 22 } } },
		{ key = "waterWalking", id = 546, name = "Water Walking", icon = 135863, ranks = { { 546, 28 } } },
		{ key = "ancestralSpirit", id = 2008, name = "Ancestral Spirit", icon = 136077, ranks = { { 2008, 12, 1 }, { 20609, 24, 2 }, { 20610, 36, 3 }, { 20776, 48, 4 }, { 20777, 60, 5 } }, rez = true },
	},
	WARLOCK = {
		{ key = "unendingBreath", id = 5697, name = "Unending Breath", icon = 136148, ranks = { { 5697, 16 } } },
		{ key = "detectInvisibility", id = 132, name = "Detect Invisibility", icon = 136152, ranks = { { 132, 26, 1 }, { 2970, 38, 2 }, { 11743, 50, 3 } } },
		{ key = "summon", id = 698, name = "Ritual of Summoning", icon = 136223, ranks = { { 698, 20 } } },
	},
}
D.spells.mists = {  -- build 5.5.4.70631
	PRIEST = {
		{ key = "fortitude", id = 21562, name = "Power Word: Fortitude", icon = 135987 },
		{ key = "shield", id = 17, name = "Power Word: Shield", icon = 135940, combat = true },
		{ key = "fearWard", id = 6346, name = "Fear Ward", icon = 135902, combat = true },
		{ key = "powerInfusion", id = 10060, name = "Power Infusion", icon = 135939, combat = true },
		{ key = "painSuppression", id = 33206, name = "Pain Suppression", icon = 135936, combat = true },
		{ key = "guardianSpirit", id = 47788, name = "Guardian Spirit", icon = 237542, combat = true },
		{ key = "purify", id = 527, name = "Purify", icon = 135894, wordsFrom = { "purify", "dispelMagic", "abolishDisease" }, combat = true, cure = true },
		{ key = "resurrection", id = 2006, name = "Resurrection", icon = 135955, rez = true },
	},
	MAGE = {
		{ key = "brilliance", id = 1459, name = "Arcane Brilliance", icon = 135932, alts = { 61316 }, wordsFrom = { "intellect", "brilliance" } },
		{ key = "slowFall", id = 130, name = "Slow Fall", icon = 135992 },
		{ key = "removeCurse", id = 475, name = "Remove Curse", icon = 136082, wordsFrom = { "removeLesserCurse" }, combat = true, cure = true },
	},
	DRUID = {
		{ key = "mark", id = 1126, name = "Mark of the Wild", icon = 136078 },
		{ key = "innervate", id = 29166, name = "Innervate", icon = 136048, combat = true },
		{ key = "ironbark", id = 102342, name = "Ironbark", icon = 572025, combat = true },
		{ key = "naturesCure", id = 88423, name = "Nature's Cure", icon = 236288, wordsFrom = { "naturesCure", "removeCurse", "abolishPoison" }, combat = true, cure = true },
		{ key = "removeCorruption", id = 2782, name = "Remove Corruption", icon = 135952, wordsFrom = { "removeCorruption", "removeCurse", "abolishPoison" }, combat = true, cure = true },
		{ key = "revive", id = 50769, name = "Revive", icon = 132132, rez = true },
		{ key = "rebirth", id = 20484, name = "Rebirth", icon = 136080, combat = true, rez = true },
	},
	PALADIN = {
		{ key = "kings", id = 20217, name = "Blessing of Kings", icon = 135993 },
		{ key = "might", id = 19740, name = "Blessing of Might", icon = 135908 },
		{ key = "freedom", id = 1044, name = "Hand of Freedom", icon = 135968, combat = true },
		{ key = "protection", id = 1022, name = "Hand of Protection", icon = 135964, combat = true },
		{ key = "sacrifice", id = 6940, name = "Hand of Sacrifice", icon = 135966, combat = true },
		{ key = "salvation", id = 1038, name = "Hand of Salvation", icon = 135967, combat = true },
		{ key = "cleanse", id = 4987, name = "Cleanse", icon = 135949, wordsFrom = { "cleanse", "purify" }, combat = true, cure = true },
		{ key = "redemption", id = 7328, name = "Redemption", icon = 135955, rez = true },
	},
	SHAMAN = {
		{ key = "earthShield", id = 974, name = "Earth Shield", icon = 136089, combat = true },
		{ key = "purifySpirit", id = 77130, name = "Purify Spirit", icon = 236288, combat = true, cure = true },
		{ key = "cleanseSpirit", id = 51886, name = "Cleanse Spirit", icon = 236288, combat = true, cure = true },
		{ key = "waterWalking", id = 546, name = "Water Walking", icon = 135863 },
		{ key = "ancestralSpirit", id = 2008, name = "Ancestral Spirit", icon = 136077, rez = true },
	},
	WARLOCK = {
		{ key = "darkIntent", id = 109773, name = "Dark Intent", icon = 463285 },
		{ key = "unendingBreath", id = 5697, name = "Unending Breath", icon = 136148 },
		{ key = "soulstone", id = 20707, name = "Soulstone", icon = 136210 },
		{ key = "summon", id = 698, name = "Ritual of Summoning", icon = 136223 },
	},
	HUNTER = {
		{ key = "misdirection", id = 34477, name = "Misdirection", icon = 132180 },
	},
	ROGUE = {
		{ key = "tricks", id = 57934, name = "Tricks of the Trade", icon = 236283 },
	},
	MONK = {
		{ key = "legacyEmperor", id = 115921, name = "Legacy of the Emperor", icon = 606547 },
		{ key = "legacyTiger", id = 116781, name = "Legacy of the White Tiger", icon = 606548 },
		{ key = "lifeCocoon", id = 116849, name = "Life Cocoon", icon = 627485, combat = true },
		{ key = "detox", id = 115450, name = "Detox", icon = 135894, combat = true, cure = true },
		{ key = "resuscitate", id = 115178, name = "Resuscitate", icon = 132132, rez = true },
	},
	DEATHKNIGHT = {
		{ key = "raiseAlly", id = 61999, name = "Raise Ally", icon = 136143, combat = true, rez = true },
	},
	WARRIOR = {
		{ key = "vigilance", id = 114030, name = "Vigilance", icon = 236318, combat = true },
	},
}
D.spells.retail = {  -- build 12.1.5.70783
	PRIEST = {
		{ key = "fortitude", id = 21562, name = "Power Word: Fortitude", icon = 135987 },
		{ key = "shield", id = 17, name = "Power Word: Shield", icon = 135940, combat = true },
		{ key = "powerInfusion", id = 10060, name = "Power Infusion", icon = 135939, combat = true },
		{ key = "painSuppression", id = 33206, name = "Pain Suppression", icon = 135936, combat = true },
		{ key = "guardianSpirit", id = 47788, name = "Guardian Spirit", icon = 237542, combat = true },
		{ key = "purify", id = 527, name = "Purify", icon = 135894, wordsFrom = { "purify", "dispelMagic", "abolishDisease" }, combat = true, cure = true },
		{ key = "purifyDisease", id = 213634, name = "Purify Disease", icon = 135935, alts = { 440006 }, wordsFrom = { "purifyDisease", "abolishDisease" }, combat = true, cure = true },
		{ key = "resurrection", id = 2006, name = "Resurrection", icon = 135955, rez = true },
	},
	MAGE = {
		{ key = "intellect", id = 1459, name = "Arcane Intellect", icon = 135932 },
		{ key = "slowFall", id = 130, name = "Slow Fall", icon = 135992 },
		{ key = "removeCurse", id = 475, name = "Remove Curse", icon = 136082, wordsFrom = { "removeLesserCurse" }, combat = true, cure = true },
	},
	DRUID = {
		{ key = "mark", id = 1126, name = "Mark of the Wild", icon = 136078 },
		{ key = "innervate", id = 29166, name = "Innervate", icon = 136048, combat = true },
		{ key = "ironbark", id = 102342, name = "Ironbark", icon = 572025, combat = true },
		{ key = "naturesCure", id = 88423, name = "Nature's Cure", icon = 236288, wordsFrom = { "naturesCure", "removeCurse", "abolishPoison" }, combat = true, cure = true },
		{ key = "removeCorruption", id = 2782, name = "Remove Corruption", icon = 135952, alts = { 440015 }, wordsFrom = { "removeCorruption", "removeCurse", "abolishPoison" }, combat = true, cure = true },
		{ key = "revive", id = 50769, name = "Revive", icon = 132132, rez = true },
		{ key = "rebirth", id = 20484, name = "Rebirth", icon = 136080, combat = true, rez = true },
	},
	PALADIN = {
		{ key = "freedom", id = 1044, name = "Blessing of Freedom", icon = 135968, combat = true },
		{ key = "protection", id = 1022, name = "Blessing of Protection", icon = 135964, combat = true },
		{ key = "sacrifice", id = 6940, name = "Blessing of Sacrifice", icon = 135966, combat = true },
		{ key = "spellwarding", id = 204018, name = "Blessing of Spellwarding", icon = 135880, combat = true },
		{ key = "cleanse", id = 4987, name = "Cleanse", icon = 135949, wordsFrom = { "cleanse", "purify" }, combat = true, cure = true },
		{ key = "cleanseToxins", id = 213644, name = "Cleanse Toxins", icon = 135953, alts = { 440013 }, wordsFrom = { "cleanseToxins", "purify" }, combat = true, cure = true },
		{ key = "redemption", id = 7328, name = "Redemption", icon = 135955, rez = true },
	},
	SHAMAN = {
		{ key = "earthShield", id = 974, name = "Earth Shield", icon = 136089, combat = true },
		{ key = "purifySpirit", id = 77130, name = "Purify Spirit", icon = 236288, combat = true, cure = true },
		{ key = "cleanseSpirit", id = 51886, name = "Cleanse Spirit", icon = 236288, alts = { 440012 }, combat = true, cure = true },
		{ key = "waterWalking", id = 546, name = "Water Walking", icon = 135863 },
		{ key = "ancestralSpirit", id = 2008, name = "Ancestral Spirit", icon = 136077, rez = true },
	},
	WARLOCK = {
		{ key = "unendingBreath", id = 5697, name = "Unending Breath", icon = 136148 },
		{ key = "soulstone", id = 20707, name = "Soulstone", icon = 136210 },
		{ key = "summon", id = 698, name = "Ritual of Summoning", icon = 7439232 },
	},
	HUNTER = {
		{ key = "misdirection", id = 34477, name = "Misdirection", icon = 132180 },
	},
	ROGUE = {
		{ key = "tricks", id = 57934, name = "Tricks of the Trade", icon = 236283 },
	},
	MONK = {
		{ key = "lifeCocoon", id = 116849, name = "Life Cocoon", icon = 627485, combat = true },
		{ key = "detox", id = 115450, name = "Detox", icon = 460692, alts = { 218164 }, combat = true, cure = true },
		{ key = "resuscitate", id = 115178, name = "Resuscitate", icon = 132132, rez = true },
	},
	DEATHKNIGHT = {
		{ key = "raiseAlly", id = 61999, name = "Raise Ally", icon = 136143, combat = true, rez = true },
	},
	EVOKER = {
		{ key = "timeDilation", id = 357170, name = "Time Dilation", icon = 4622478, combat = true },
		{ key = "sourceOfMagic", id = 369459, name = "Source of Magic", icon = 4630412 },
		{ key = "prescience", id = 409311, name = "Prescience", icon = 5199639, combat = true },
		{ key = "blisteringScales", id = 360827, name = "Blistering Scales", icon = 5199621, combat = true },
		{ key = "naturalize", id = 360823, name = "Naturalize", icon = 4630445, combat = true, cure = true },
		{ key = "expunge", id = 365585, name = "Expunge", icon = 4630445, combat = true, cure = true },
		{ key = "cauterizingFlame", id = 374251, name = "Cauterizing Flame", icon = 4630446, combat = true, cure = true },
		{ key = "evokerReturn", id = 361227, name = "Return", icon = 4622472, rez = true },
	},
}
