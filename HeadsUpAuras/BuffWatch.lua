-- BuffWatch.lua — WoW Forever ONLY (on retail it stops at once and defines nothing).
--
-- A tracker of an ability that puts a BUFF ON YOU (Lightning Shield, Mark of the Wild, Arcane Intellect,
-- any class) follows the real buff instead of a fixed "hide for N seconds" timer.
--
-- What the game allows in Forever (tested with ForeverProbe):
--   * out of combat every buff can be read: is it there, how long is left, how many stacks;
--   * IN combat nothing about buffs can be read (not even which one changed).
-- So:
--   * at a cast the timer runs for the real length of the buff (learned from the buff itself, or from the
--     description of the ability: "Lasts 10 min"), in combat too;
--   * out of combat (and the moment a fight ends, at login, at /reload) the tracker is corrected from the
--     real buff: gone -> the icon shows; time left -> the timer follows it; stacks -> see below.
--   * "Show the icon": when it is gone, or N seconds/minutes before it ends (same choice as weapon imbues).
--   * "Also show at N stacks or fewer" (buffs with stacks/charges): checked out of combat only.
--
-- Which abilities are buffs on you is learned by itself: when the buff of the same name is seen on you
-- (HeadsUpAurasDB.buffs[name] = { dur = seconds, stk = most stacks seen }). No spell is listed by hand.

local build = select(4, GetBuildInfo())
local isForever = (WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)
    or (build and build >= 16000 and build < 20000)
if not isForever then return end

local function Secret(v)
    return issecretvalue and issecretvalue(v) or false
end

local function NameOf(spellID)
    if not spellID or not C_Spell or not C_Spell.GetSpellInfo then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    local n = ok and type(info) == "table" and info.name
    if type(n) ~= "string" or Secret(n) then return nil end
    return n
end

local function Learned(name)
    local db = HeadsUpAurasDB and HeadsUpAurasDB.buffs
    return name and db and db[name] or nil
end

-- the buff of that name on you, read safely: { left = seconds or nil (no end), stk = number, dur = number }
-- false = not on you; nil = cannot be read now (combat)
local function ReadBuff(spellID, name)
    if InCombatLockdown() or not C_UnitAuras then return nil end
    local a
    if C_UnitAuras.GetAuraDataBySpellName and name then
        local ok, r = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
        if not ok then return nil end
        a = r
    end
    if not a and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, r = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if not ok then return nil end
        a = r
    end
    if a == nil then return false end
    if Secret(a) or type(a) ~= "table" then return nil end
    local exp, dur, stk = a.expirationTime, a.duration, a.applications
    if Secret(exp) or Secret(dur) or Secret(stk) then return nil end
    local left = (type(exp) == "number" and exp > 0) and (exp - GetTime()) or nil
    return { left = left, dur = type(dur) == "number" and dur or 0, stk = type(stk) == "number" and stk or 0 }
end

-- "Lasts 10 min." / "for 30 sec" -> seconds (nil if the description has no time)
local function DescDuration(spellID)
    if not C_Spell or not C_Spell.GetSpellDescription then return nil end
    local ok, text = pcall(C_Spell.GetSpellDescription, spellID)
    if not ok or type(text) ~= "string" or Secret(text) then return nil end
    local t = text:lower()
    local part = t:match("lasts%s+(.*)") or t
    local n, unit = part:match("(%d+%.?%d*)%s*(%a+)")
    n = tonumber(n)
    if not n or not unit then return nil end
    if unit:find("^hour") then return n * 3600 end
    if unit:find("^min") then return n * 60 end
    if unit:find("^sec") then return n end
    return nil
end

-- a tracker of a buff on you? (not a weapon imbue: ImbueWatch.lua has those)
function HeadsUpAuras_BuffOwns(cfg)
    if not (cfg and cfg.spellID and cfg.suppressEnabled) then return false end
    if HeadsUpAuras_ImbueOwns and HeadsUpAuras_ImbueOwns(cfg) then return false end
    local name = NameOf(cfg.spellID)
    if Learned(name) then return true end
    local b = ReadBuff(cfg.spellID, name)
    return b and true or false
end

-- the most stacks the buff was seen with (for the stacks option of the wizard); 0 if unknown
function HeadsUpAuras_BuffStacks(cfg)
    local l = cfg and Learned(NameOf(cfg.spellID))
    return l and l.stk or 0
end

local function Remember(name, b)
    if not (HeadsUpAurasDB and name and b) then return end
    HeadsUpAurasDB.buffs = HeadsUpAurasDB.buffs or {}
    local l = HeadsUpAurasDB.buffs[name] or {}
    if b.dur and b.dur > 0 then l.dur = b.dur end
    if b.stk and b.stk > (l.stk or 0) then l.stk = b.stk end
    HeadsUpAurasDB.buffs[name] = l
end

-- how long to hide from now, for a buff with "left" seconds (nil left = no end: hide for a long time)
local function HideFor(c, left)
    local warn = (c.trackShow ~= "while") and (c.imbueWarn or 0) or 0
    if left == nil then return 24 * 3600 end
    return left - warn
end

local function SetUntil(ind, new)
    local now = GetTime()
    local old = ind.suppressUntil
    local running = old and old > now
    if new then
        if not running or math.abs(old - new) > 1.5 then ind.suppressUntil = new; return true end
    elseif running then
        ind.suppressUntil = nil; return true
    end
    return false
end

-- out of combat: make every buff tracker follow the real buff
local function Sync()
    if InCombatLockdown() then return end
    local changed = false
    local now = GetTime()
    HeadsUpAuras_EachIndicator(function(ind)
        local c = ind.cfg
        if not (c and c.suppressEnabled and c.spellID) then return end
        if HeadsUpAuras_ImbueOwns and HeadsUpAuras_ImbueOwns(c) then return end
        local name = NameOf(c.spellID)
        local b = ReadBuff(c.spellID, name)
        if b == nil then return end
        if b then Remember(name, b) elseif not Learned(name) then return end   -- not a buff we know
        local new
        if b then
            local hide = HideFor(c, b.left)
            -- "also show at N stacks or fewer" (only when the buff has stacks)
            local few = c.buffStacks or 0
            if few > 0 and c.trackShow ~= "while" and b.stk > 0 and b.stk <= few then hide = 0 end
            if hide > 0 then new = now + hide end
        end
        if SetUntil(ind, new) then changed = true end
    end)
    if changed then HeadsUpAuras_RefreshAll() end
end

-- after a cast of a buff ability (in combat too): the timer runs for the real length of the buff
local function AfterCast(spellID)
    local castName = NameOf(spellID)
    if not castName then return end
    local changed = false
    local now = GetTime()
    HeadsUpAuras_EachIndicator(function(ind)
        local c = ind.cfg
        if not (c and c.suppressEnabled and c.spellID) or NameOf(c.spellID) ~= castName then return end
        if HeadsUpAuras_ImbueOwns and HeadsUpAuras_ImbueOwns(c) then return end
        local l = Learned(castName)
        local dur = (l and l.dur) or DescDuration(spellID)
        if not dur then return end
        if not l and not InCombatLockdown() then return end   -- out of combat Sync reads the real buff
        local hide = HideFor(c, dur)
        if SetUntil(ind, hide > 0 and (now + hide) or nil) then changed = true end
    end)
    if changed then HeadsUpAuras_RefreshAll() end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...)
    local ok, err = pcall(function(...)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            local _, _, spellID = ...
            if type(spellID) == "number" and not Secret(spellID) then
                -- a moment later: after the core started its own timer, and the buff is on
                C_Timer.After(0.3, function()
                    pcall(AfterCast, spellID)
                    pcall(Sync)
                end)
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(1.5, function() pcall(Sync) end)   -- after the auras are built
        elseif event == "PLAYER_REGEN_ENABLED" then
            C_Timer.After(0.2, function() pcall(Sync) end)   -- the fight is over: the buffs can be read again
        else
            Sync()
        end
    end, ...)
    if not ok and HeadsUpAuras_Log then HeadsUpAuras_Log("buff-error", tostring(err)) end
end)

pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_ENABLED")
pcall(frame.RegisterUnitEvent, frame, "UNIT_AURA", "player")
pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "player")

-- the countdown has no event: look every 3 seconds out of combat (changes nothing unless it differs)
C_Timer.NewTicker(3, function() pcall(Sync) end)
