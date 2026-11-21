-- ForeverReactive.lua — WoW Forever ONLY (on retail it stops at once and defines nothing,
-- so the core keeps its old behaviour there).
--
-- "Reactive" abilities (Overpower after a dodge, Revenge after a block/dodge/parry, Execute on a target
-- with low health, Victory Rush after a kill...) can be pressed only for a short time after something
-- happened. The game shows no glow for them in Forever, but it does tell, also IN combat, whether the
-- ability can be used right now (found with ForeverProbe, 21/11/2026). The condition "Available" of an
-- aura uses this: the icon shows only while the game says the ability can be pressed.
-- For an ordinary ability nothing changes in practice (it can be pressed whenever it has its resource).

local build = select(4, GetBuildInfo())
local isForever = (WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)
    or (build and build >= 16000 and build < 20000)
if not isForever then return end

-- Glows ("Empowered"): the list of abilities that light up (KnownGlows.lua) is made from RETAIL data and is
-- wrong for Forever (e.g. Overpower glows on retail, never in Forever). In Forever the addon trusts only
-- what it has seen light up here (self-learning, also without a specialization). The core and the settings
-- ask for this function; on retail it does not exist.
function HeadsUpAuras_OwnGlowsOnly() return true end

-- true: the addon has never seen this aura's ability light up in Forever (any specialization of the aura's
-- class, any rank). Then "Empowered" cannot ever be met, so it is unticked by itself (at login and on save)
-- and its box is grey: the player cannot make an icon that never shows.
function HeadsUpAuras_GlowNeverSeen(cfg)
    if not cfg or not cfg.spellID then return false end
    local learned = HeadsUpAurasDB and HeadsUpAurasDB.learned
    local forClass = learned and learned[cfg.class or HeadsUpAuras_GetPlayerClass()]
    if not forClass then return true end
    for _, forSpec in pairs(forClass) do
        if type(forSpec) == "table" then
            if forSpec[cfg.spellID] then return false end
            for id in pairs(forSpec) do
                if HeadsUpAuras_SameAbility and HeadsUpAuras_SameAbility(id, cfg.spellID) then return false end
            end
        end
    end
    return true
end

-- "Available" as a plain yes/no that can be read IN combat (for the sound): the game says the ability can be
-- pressed, and it is not on its own cooldown (the global cooldown does not count). In Forever both are readable in
-- combat (ForeverProbe 21/11: usable, and the cooldown's isActive / isOnGCD). nil: the game hides it right now.
function HeadsUpAuras_ReadableAvailable(spellID)
    if not spellID or not C_Spell or not C_Spell.IsSpellUsable then return nil end
    local ok, usable = pcall(C_Spell.IsSpellUsable, spellID)
    if not ok or (issecretvalue and issecretvalue(usable)) then return nil end
    if not usable then return false end
    local okC, cd = pcall(C_Spell.GetSpellCooldown, spellID)
    if not okC or type(cd) ~= "table" then return nil end
    local active, gcd = cd.isActive, cd.isOnGCD
    if issecretvalue and (issecretvalue(active) or issecretvalue(gcd)) then return nil end
    if active and not gcd then return false end
    return true
end

-- true: the game clearly says the ability cannot be used right now (not its moment / not enough resource).
-- false: it can, or the game does not tell (then the other "Available" checks decide alone).
function HeadsUpAuras_ReactiveBlocked(spellID)
    if not spellID or not C_Spell or not C_Spell.IsSpellUsable then return false end
    local ok, usable = pcall(C_Spell.IsSpellUsable, spellID)
    if not ok or (issecretvalue and issecretvalue(usable)) then return false end
    return not usable
end
