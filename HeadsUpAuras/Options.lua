-- Options.lua — the small Options window (the gear button left of the X in the header of the settings window).
-- Colour theme, the windows of HeadsUp Auras in combat, the minimap button. Retail and Forever alike.
-- Saved in HeadsUpAurasDB.options = { theme = "orange", combatHide = false, combatReopen = true }.

local UI = HeadsUpAurasUI
if not UI or not UI.settings then return end
local C = UI.C
local S = UI.settings

local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end
local function Tip(title, text, more)
    return function(tt)
        tt:AddLine(title, 1, 0.82, 0)
        tt:AddLine(text, 1, 1, 1, true)
        if more then
            tt:AddLine(" ")
            tt:AddLine(more, 0.7, 0.7, 0.7, true)
        end
    end
end

local function Opts()
    local db = HeadsUpAurasDB
    if not db then return { theme = "orange", combatHide = false, combatReopen = true } end
    db.options = db.options or {}
    local o = db.options
    if o.theme == nil then o.theme = "orange" end
    if o.combatHide == nil then o.combatHide = false end
    if o.combatReopen == nil then o.combatReopen = true end
    return o
end

------------------------------------------------------------
-- colour themes: the accent colour (titles, highlighted buttons, ticks, the frame of the small panels)
------------------------------------------------------------
local THEMES = {
    { key = "orange", text = "Orange", accent = { 1.000, 0.560, 0.120 }, dim = { 0.780, 0.420, 0.080 } },
    { key = "blue",   text = "Blue",   accent = { 0.300, 0.620, 1.000 }, dim = { 0.180, 0.420, 0.780 } },
    { key = "green",  text = "Green",  accent = { 0.330, 0.820, 0.420 }, dim = { 0.200, 0.580, 0.280 } },
}

local function ApplyTheme(key)
    local theme = THEMES[1]
    for _, t in ipairs(THEMES) do if t.key == key then theme = t end end
    for i = 1, 3 do
        C.accent[i] = theme.accent[i]       -- (changed in place: every piece that holds C.accent sees the new colour)
        C.accentDim[i] = theme.dim[i]
    end
    for _, item in ipairs(UI.themed) do
        local kind, obj, alpha = item[1], item[2], item[3]
        if kind == "text" then obj:SetTextColor(rgba(C.accent))
        elseif kind == "border" then obj:SetBackdropBorderColor(rgba(C.accent))
        elseif kind == "bg" then obj:SetBackdropColor(rgba(C.accent))
        elseif kind == "tex" then obj:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], alpha or 1) end
    end
    for _, b in ipairs(UI.paintables) do pcall(b.Paint, b) end
    for _, fn in ipairs(UI.themeHooks) do pcall(fn) end
    if UI.SyncAll then pcall(UI.SyncAll) end
end

------------------------------------------------------------
-- the panel
------------------------------------------------------------
local frame = S.frame
local panel = UI.Box(frame, C.window, C.accent)
panel:SetSize(330, 232)
panel:SetPoint("TOPRIGHT", S.header, "BOTTOMRIGHT", -12, -6)
panel:SetFrameLevel(frame:GetFrameLevel() + 40)
panel:EnableMouse(true)
panel:Hide()

local title = UI.Text(panel, 14, C.accent)
title:SetPoint("TOPLEFT", 16, -14)
title:SetText("Options")

-- colour theme: one button for each, the chosen one highlighted
local themeLabel = UI.Text(panel, 12, C.text)
themeLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
themeLabel:SetText("Colour theme")
local themeButtons = {}
local function PaintThemeButtons()
    local current = Opts().theme
    for _, b in ipairs(themeButtons) do
        b.primary = (b.key == current)
        b:Paint()
    end
end
for i, t in ipairs(THEMES) do
    local b = UI.Button(panel, t.text, 60)
    b.key = t.key
    if i == 1 then b:SetPoint("LEFT", themeLabel, "LEFT", 96, 0)
    else b:SetPoint("LEFT", themeButtons[i - 1], "RIGHT", 6, 0) end
    b:SetScript("OnClick", function(self)
        Opts().theme = self.key
        ApplyTheme(self.key)
        PaintThemeButtons()
    end)
    UI.Tip(b, Tip("Colour theme: " .. t.text, "The colour of the titles, the highlighted buttons and the ticks of the HeadsUp Auras windows.", "It changes at once."))
    themeButtons[i] = b
end

-- the windows in combat
local hideCheck = UI.Check(panel, 290, "Hide the windows in combat")
hideCheck:SetPoint("TOPLEFT", themeLabel, "BOTTOMLEFT", 0, -20)
UI.Tip(hideCheck, Tip("Hide the windows in combat", "The windows of HeadsUp Auras close the moment a fight starts, so they are not in your way.",
    "The icons on your screen keep working as always."))

local reopenCheck = UI.Check(panel, 264, "Reopen them after combat")
reopenCheck:SetPoint("TOPLEFT", hideCheck, "BOTTOMLEFT", 26, -6)
UI.Tip(reopenCheck, Tip("Reopen them after combat", "When the fight ends, the windows that were open come back, with your work as you left it.",
    "Not ticked: they stay closed, and an aura you had not saved is lost."))

-- the minimap button (it used to be a tick box in the header)
local minimapCheck = UI.Check(panel, 290, "Show minimap button")
minimapCheck:SetPoint("TOPLEFT", hideCheck, "BOTTOMLEFT", 0, -34)
UI.Tip(minimapCheck, Tip("Show minimap button", "Tick it to have the HeadsUp Auras button on the edge of the minimap.",
    "HeadsUp Auras is always in the add-on menu of the minimap, so the button starts hidden. /hua minimap does the same."))

local closeButton = UI.Button(panel, "Got it", 90, true)
closeButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 14)
closeButton:SetScript("OnClick", function() panel:Hide() end)

local function Sync()
    local o = Opts()
    hideCheck:SetValue(o.combatHide)
    reopenCheck:SetValue(o.combatReopen)
    reopenCheck:SetOn(o.combatHide)   -- (only with "Hide the windows in combat")
    minimapCheck:SetValue(HeadsUpAuras_IsMinimapButtonShown and HeadsUpAuras_IsMinimapButtonShown())
    PaintThemeButtons()
end
-- Minimap.lua calls this after /hua minimap
function HeadsUpAuras_SyncMinimapCheck()
    if panel:IsShown() then Sync() end
end

hideCheck:SetScript("OnClick", function(self)
    Opts().combatHide = not self.checked
    Sync()
end)
reopenCheck:SetScript("OnClick", function(self)
    Opts().combatReopen = not self.checked
    Sync()
end)
minimapCheck:SetScript("OnClick", function(self)
    if HeadsUpAuras_SetMinimapButtonShown then HeadsUpAuras_SetMinimapButtonShown(not self.checked) end
    Sync()
end)
panel:SetScript("OnShow", Sync)

-- the gear opens / closes it; only one of the small panels of the header is open at a time
S.gear:SetScript("OnClick", function()
    if panel:IsShown() then
        panel:Hide()
        return
    end
    for _, p in ipairs(S.panels) do p:Hide() end
    panel:Show()
end)
for _, b in ipairs(S.panelButtons) do
    b:HookScript("OnClick", function() panel:Hide() end)
end
frame:HookScript("OnHide", function()
    if not (UI.combatHidden and UI.combatReturn) then panel:Hide() end
end)

------------------------------------------------------------
-- combat: hide the windows, and bring back the ones that were open
------------------------------------------------------------
local wasOpen = {}
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "HeadsUpAuras" then ApplyTheme(Opts().theme) end
        return
    end
    local o = Opts()
    if event == "PLAYER_REGEN_DISABLED" then
        if not o.combatHide then return end
        wipe(wasOpen)
        UI.combatHidden = true
        UI.combatReturn = o.combatReopen and true or false
        for _, w in ipairs({ frame, S.posWindow }) do
            if w and w:IsShown() then
                wasOpen[#wasOpen + 1] = w
                w:Hide()
            end
        end
        if not UI.combatReturn then UI.combatHidden = nil end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if UI.combatHidden and UI.combatReturn then
            for _, w in ipairs(wasOpen) do w:Show() end
        end
        wipe(wasOpen)
        UI.combatHidden, UI.combatReturn = nil, nil
    end
end)
