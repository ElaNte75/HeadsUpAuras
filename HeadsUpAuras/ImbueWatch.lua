-- ImbueWatch.lua — WoW Forever and retail (since 10/11; it was Forever only before).
--
-- Weapon imbues (Rockbiter Weapon, Flametongue ...) are not normal buffs: they never appear in the
-- aura list. The game tells about them through GetWeaponEnchantInfo(), which stays readable in combat.
--
-- This module makes a tracker / hide-timer aura of an imbue ability follow the REAL imbue instead of
-- a timer started by the cast: while the imbue is on the weapon the aura is hidden for exactly the
-- time the game says is left; the moment it is gone (expired, dispelled, weapon changed) it shows.
--
-- Which enchant belongs to which ability is learned by itself (cast the ability, see which enchant
-- appears) and kept in HeadsUpAurasDB.imbues; Rockbiter Weapon is known from the start.

-- (whatever cannot be read, secret in combat for example, is skipped: the aura keeps its timer)
if not GetWeaponEnchantInfo then return end

-- ability (spell id) -> enchant id the game reports on the weapon
local SEED = { [8017] = 29 }     -- Rockbiter Weapon

local lastSlots

local function Secret(v)
    return issecretvalue and issecretvalue(v) or false
end

local function EnchantFor(spellID)
    local learned = HeadsUpAurasDB and HeadsUpAurasDB.imbues
    return (learned and learned[spellID]) or SEED[spellID]
end

-- Abilities have ranks (Rockbiter Weapon rank 1, 2, 3 ...): every rank is a different spell id and puts a
-- different enchant on the weapon, but all ranks share the same NAME. So an aura made for one rank must
-- accept the enchant of any rank: collect the enchants of every known spell with the same name.
local nameCache = {}
local function NameOf(spellID)
    local n = nameCache[spellID]
    if n == nil then
        n = false
        if C_Spell and C_Spell.GetSpellInfo then
            local ok, si = pcall(C_Spell.GetSpellInfo, spellID)
            if ok and type(si) == "table" and type(si.name) == "string" and not Secret(si.name) then n = si.name end
        end
        nameCache[spellID] = n
    end
    return n or nil
end

local function EnchantsFor(spellID)
    local set, any = {}, false
    local own = EnchantFor(spellID)
    if own then set[own], any = true, true end
    local name = NameOf(spellID)
    if name then
        local learned = HeadsUpAurasDB and HeadsUpAurasDB.imbues or {}
        for _, tbl in ipairs({ SEED, learned }) do
            for sid, eid in pairs(tbl) do
                if sid ~= spellID and NameOf(sid) == name then set[eid], any = true, true end
            end
        end
    end
    return any and set or nil
end

-- "Also counts" (cfg.alsoCounts = { [ability name] = true }): the imbues of those abilities are fine too
-- (Rockbiter OR Flametongue: only one can be on the weapon)
local function WantedFor(c)
    local set = EnchantsFor(c.spellID)
    if not set or type(c.alsoCounts) ~= "table" then return set end
    local learned = HeadsUpAurasDB and HeadsUpAurasDB.imbues or {}
    for _, tbl in ipairs({ SEED, learned }) do
        for sid, eid in pairs(tbl) do
            local n = NameOf(sid)
            if n and c.alsoCounts[n] then set[eid] = true end
        end
    end
    return set
end

-- { {has, left(seconds), id}, ... } for main hand, off hand, thrown — or nil if it cannot be read.
-- (GetWeaponEnchantInfo returns 4 values per slot: has, milliseconds left, charges, enchant id.)
local function ReadSlots()
    local r = { pcall(GetWeaponEnchantInfo) }
    if not r[1] then return nil end
    local slots = {}
    for s = 0, 2 do
        local has, ms, id = r[s * 4 + 2], r[s * 4 + 3], r[s * 4 + 5]
        if Secret(has) or Secret(ms) or Secret(id) then return nil end
        slots[#slots + 1] = {
            has = has and true or false,
            left = type(ms) == "number" and ms / 1000 or nil,
            id = type(id) == "number" and id or nil,
        }
    end
    return slots
end

-- used by the core: an aura whose timer follows the imbue (not the target, not the cast)
function HeadsUpAuras_ImbueOwns(cfg)
    return cfg and cfg.spellID and EnchantsFor(cfg.spellID) ~= nil or false
end

local function Sync()
    local slots = ReadSlots()
    if not slots then return end
    lastSlots = slots
    local now = GetTime()
    local changed = false
    HeadsUpAuras_EachIndicator(function(ind)
        local c = ind.cfg
        if c and c.suppressEnabled and c.spellID then
            local want = WantedFor(c)
            if want then
                local left
                for _, s in ipairs(slots) do
                    if s.has and s.id and want[s.id] and s.left then left = math.max(left or 0, s.left) end
                end
                local old = ind.suppressUntil
                local running = old and old > now
                -- "Show the icon N seconds before it ends": the icon stays hidden until N seconds are left
                -- (only for "show when it is gone"; "while it lasts" shows for the whole time)
                local warn = (c.trackShow ~= "while") and (c.imbueWarn or 0) or 0
                local hideFor = left and (left - warn)
                if hideFor and hideFor > 0 then
                    local new = now + hideFor
                    if not running or math.abs(old - new) > 1.5 then
                        ind.suppressUntil = new
                        changed = true
                    end
                elseif running then
                    ind.suppressUntil = nil
                    changed = true
                end
            end
        end
    end)
    if changed then
        HeadsUpAuras_Log("imbue", "synced to the weapon enchant")
        HeadsUpAuras_RefreshAll()
    end
end

-- after the player cast an ability: did a new enchant appear on a weapon? then that ability makes it.
local function Learn(spellID, before)
    local after = ReadSlots()
    if not (after and before and HeadsUpAurasDB) or EnchantFor(spellID) then return end
    local found, count = nil, 0
    for i = 1, #after do
        local a, b = after[i], before[i]
        if a.has and a.id and not (b and b.has and b.id == a.id) then found, count = a.id, count + 1 end
    end
    if count == 1 then
        HeadsUpAurasDB.imbues = HeadsUpAurasDB.imbues or {}
        HeadsUpAurasDB.imbues[spellID] = found
        HeadsUpAuras_Log("imbue", "learned: spell " .. spellID .. " = enchant " .. found)
    end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...)
    local ok, err = pcall(function(...)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            local _, _, spellID = ...
            if type(spellID) == "number" and not Secret(spellID) then
                local before = lastSlots
                C_Timer.After(0.6, function()
                    pcall(Learn, spellID, before)
                    pcall(Sync)
                end)
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(1.5, function() pcall(Sync) end)   -- after the auras are built
        else
            Sync()
        end
    end, ...)
    if not ok then HeadsUpAuras_Log("imbue-error", tostring(err)) end
end)

pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_ENABLED")
pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
pcall(frame.RegisterUnitEvent, frame, "UNIT_INVENTORY_CHANGED", "player")
pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "player")

-- the countdown itself has no event: look every 3 seconds (cheap; changes nothing unless it differs)
C_Timer.NewTicker(3, function() pcall(Sync) end)
