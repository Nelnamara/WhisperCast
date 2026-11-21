--[[
	WhisperCast: Second Wind - the public API, for CooldownCollaborator and other addons.
	Global object: WhisperCastSW (an AceAddon). Check it exists (the addon may not be loaded).

	Reading the queue
	  WhisperCastSW:GetQueue()          -> { req, ... }  a copy, in line order (each request copied)
	  WhisperCastSW:GetView()           -> the view the window draws (Core.lua's contract), plus
	                                       view.nextCast (what the Cast button casts now) and, on each
	                                       group, groupCasts (every party / class a group version covers).
	                                       A group cast: { spell, castID, rank, party, class, byClass,
	                                       askers, hint } where hint is the line to show, e.g.
	                                       "All 3 in group 1: Prayer of Fortitude covers them" or
	                                       "All 2 Warriors: Greater Blessing of Kings covers them"
	  WhisperCastSW.noGroup[key]        true when a group version ran out of reagents (single casts
	                                       until /reload)
	  WhisperCastSW:NextCast()          -> { castID, unit, spell, rank, reqs = { req, ... } } or nil
	  WhisperCastSW:InRange(req)        -> true / false / nil (nil when the game won't say)
	  WhisperCastSW:IsInCombat()        -> true while the fight's armed request holds the button
	  A request: { id, name, short, class, unit, spell, castID, rank, party, time, fails, inCombat,
	               armed, done }; WhisperCastSW.spells[req.spell] has its name and icon.

	Asking another player's copy
	  WhisperCastSW:TriggerFor(spellID) -> the shortest default word for that spell (any class on this
	                                       client), or the spell's name. Either queues it on their side
	                                       (each spell's own name always matches).

	Changing the queue
	  WhisperCastSW:CastClicked(cast)   a Cast button calls this from PreClick with NextCast()'s result;
	                                       it whispers "coming now" to everyone the cast answers
	  WhisperCastSW:RemoveRequest(req or id, why)   why defaults to "cleared" (the asker is told)
	  WhisperCastSW:ClearQueue()        everyone waiting is told their request was cleared
	  WhisperCastSW:SetSpellEnabled(key, on)        off drops that spell's requests

	Callbacks (CallbackHandler-1.0): WhisperCastSW.RegisterCallback(yourTable, "Event", fn)
	  "QueueChanged"   ()             anything about the queue changed
	  "RequestAdded"   (req)          a new request was queued
	  "RequestRemoved" (req, why)     why = "cast", "failed", "cleared", "left" or "disabled"
	  "CombatChanged"  (inCombat)
	  "ArmedChanged"   (req or nil)   the request on the Cast button for this fight
	  Unregister with WhisperCastSW.UnregisterCallback(yourTable, "Event").
]]
local WCSW = WhisperCastSW

-- every spell entry on this client (all classes) that has this spell ID as its base, a rank or an alt
local function entryFor(spellID)
	local D = WCSW.Data
	for class, list in pairs(D.spells[WCSW.client] or {}) do
		for _, e in ipairs(list) do
			if e.id == spellID then return e, class end
			for _, r in ipairs(e.ranks or {}) do if r[1] == spellID then return e, class end end
			for _, a in ipairs(e.alts or {}) do if a == spellID then return e, class end end
		end
	end
end

function WCSW:TriggerFor(spellID)
	spellID = tonumber(spellID)
	if not spellID then return nil end
	local e, class = entryFor(spellID)
	if e then
		local best
		for _, w in ipairs(self.Data.DefaultWords(class, e, GetLocale and GetLocale() or "enUS")) do
			if not best or #w < #best then best = w end
		end
		if best then return best end
	end
	local name = self:SpellInfo(spellID)
	return name or (e and e.name) or nil
end
