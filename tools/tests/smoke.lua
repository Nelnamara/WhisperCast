-- Smoke load: every file of one TOC in order (real Ace3 + libs, LibEditMode stubbed), login, a
-- few seconds of timers and frames, the options tree validated and opened. Each lane adds its own
-- harness beside this one; this one only proves the whole addon loads and logs in clean.
dofile(HARNESS_DIR .. "/wow.lua")
local class = HARNESS_ARG ~= "" and HARNESS_ARG or "PRIEST"
PLAYER.class = class

local files = LoadTOC(HARNESS_TOCFILE)
print(string.format("[%s %s %s] loaded %d toc entries (%d lua files), load errors: %d", HARNESS_TOCFILE, FLAVOR, class, #files, #LOADED_FILES, #ERRORS))
TrackMisses()
Login()
Advance(5.1)
RunOnUpdate(0.02, 60)
print(string.format("  after login + 5 s: errors %d, enabled=%s", #ERRORS, tostring(WhisperCastSW and WhisperCastSW:IsEnabled())))

local reg = LibStub("AceConfigRegistry-3.0")
if reg.tables and reg.tables["WhisperCastSW"] then
	local ok, err = pcall(function() return reg:GetOptionsTable("WhisperCastSW", "dialog", "MyLib-1.0") end)
	print("  options validate: " .. (ok and "ok" or ("FAIL " .. tostring(err))))
end

local addonMisses = {}
for k in pairs(MISSES) do addonMisses[#addonMisses + 1] = k end
table.sort(addonMisses)
print("  nil-global reads from addon files: " .. table.concat(addonMisses, ", "))
for _, e in ipairs(ERRORS) do print("  FAIL " .. tostring(e):sub(1, 300)) end
print(string.format("RESULT %s %s: total lua errors %d", HARNESS_TOCFILE, class, #ERRORS))
