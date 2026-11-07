-- ForeverRanks.lua — WoW Forever ONLY (on retail it stops at once and defines nothing,
-- so every place that asks for these functions keeps its old behaviour there).
--
-- 1. Ranks: in Forever an ability has ranks (Lightning Shield rank 1, 2, 3 ...) and every rank is a
--    different spell id. For the add-on they are ONE ability: the lists show it once (the highest
--    rank) and casting any rank counts for an aura made with any rank (same NAME = same ability).
-- 2. Tracker list: the duration data (KnownDurations.lua) is from retail, so in Forever the Tracker
--    list showed the whole spell book. Here an ability counts as "trackable" when the game's own
--    description of it speaks of a time ("Lasts 10 min", "for 15 sec"): pure heals / damage drop out.

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

-- the same ability (any rank)?
function HeadsUpAuras_SameAbility(idA, idB)
    if not idA or not idB then return false end
    if idA == idB then return true end
    local a = NameOf(idA)
    return a ~= nil and a == NameOf(idB)
end

-- the same ability as a spell with this name?
function HeadsUpAuras_SameAbilityName(spellID, name)
    return name ~= nil and NameOf(spellID) == name
end

-- one entry per ability name: the highest rank (or, without a rank number, the last one in the spell book,
-- which is the highest there). The list keeps its order.
function HeadsUpAuras_OneRankEach(list)
    local best = {}
    for i, a in ipairs(list) do
        local b = a.name and best[a.name]
        if a.name and (not b or (a.rank or i) >= (list[b].rank or b)) then best[a.name] = i end
    end
    local out = {}
    for i, a in ipairs(list) do
        if not a.name or best[a.name] == i then out[#out + 1] = a end
    end
    return out
end

-- does the ability leave an effect that lasts? true / false, or nil when the game gave no description
local function Lasts(spellID)
    if not C_Spell or not C_Spell.GetSpellDescription then return nil end
    local ok, text = pcall(C_Spell.GetSpellDescription, spellID)
    if not ok or type(text) ~= "string" or Secret(text) or text == "" then
        if C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, spellID) end
        return nil
    end
    local t = text:lower()
    if t:find("lasts") or t:find("%d+%.?%d*%s*sec") or t:find("%d+%.?%d*%s*min")
        or t:find("%d+%.?%d*%s*hour") then
        return true
    end
    return false
end

-- the Tracker list: only the abilities whose effect lasts. An ability without a description stays
-- (nothing is hidden by mistake); if no description could be read at all, the whole list stays.
function HeadsUpAuras_TrackableOnly(list)
    local out, anyKnown = {}, false
    for _, a in ipairs(list) do
        local l = Lasts(a.id)
        if l ~= nil then anyKnown = true end
        if l ~= false then out[#out + 1] = a end
    end
    return anyKnown and out or list
end
