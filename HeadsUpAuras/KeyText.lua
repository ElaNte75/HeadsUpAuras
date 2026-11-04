-- HeadsUp Auras: a short text on the icon of an aura (for example the key that casts the ability).
-- It has two parts: the text itself, drawn on every face of an indicator (HeadsUpAuras_ApplyKeyText, called by
-- ApplyConfig in HeadsUpAuras.lua), and the fields of the settings window (HeadsUpAuras_KeyTextFields, called by
-- BuildAuraPage in Settings.lua). The saved keys are keyText, keyPos, keySize and keyColor.

-- the places on the icon: { point, x, y } (a small gap keeps the letters off the edge)
local PLACES = {
    center = { "CENTER", 0, 0 },
    top = { "TOP", 0, -2 },
    bottom = { "BOTTOM", 0, 2 },
    topleft = { "TOPLEFT", 2, -2 },
    topright = { "TOPRIGHT", -2, -2 },
    bottomleft = { "BOTTOMLEFT", 2, 2 },
    bottomright = { "BOTTOMRIGHT", -2, 2 },
}

local PLACE_LIST = {
    { value = "topright", text = "Top right" },
    { value = "topleft", text = "Top left" },
    { value = "top", text = "Top" },
    { value = "center", text = "Middle" },
    { value = "bottom", text = "Bottom" },
    { value = "bottomright", text = "Bottom right" },
    { value = "bottomleft", text = "Bottom left" },
}

-- the frame and the letters of one face, made the first time they are needed. The frame is a child of the face, so the
-- text appears and disappears together with the icon; it sits above the icon, the rim and the effects.
local function FaceText(ind, face, strata)
    if face.keyFrame then return face.keyFrame, face.keyText end
    local frame = CreateFrame("Frame", nil, face.B)
    frame:SetAllPoints(face.B)
    frame:SetFrameLevel(face.B:GetFrameLevel() + 12)
    frame:SetFrameStrata(strata)
    ind.parts[#ind.parts + 1] = frame   -- (so that the display priority of the aura moves it too)
    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetWordWrap(false)
    face.keyFrame, face.keyText = frame, text
    return frame, text
end

-- show (or hide) the text of an aura on its icon. allowed: false for a bar, a counter or a resource.
function HeadsUpAuras_ApplyKeyText(ind, cfg, allowed, strata)
    local label = cfg.keyText
    local show = allowed and type(label) == "string" and label ~= ""
    for _, face in ipairs(ind.faces) do
        if show then
            local frame, text = FaceText(ind, face, strata)
            local size = math.max(8, math.min(64, math.floor(cfg.keySize or 14)))
            local color = cfg.keyColor or { 1, 1, 1 }
            local place = PLACES[cfg.keyPos] or PLACES.topright
            text:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
            text:SetTextColor(color[1], color[2], color[3], 1)
            text:SetText(label)
            text:ClearAllPoints()
            text:SetPoint(place[1], frame, place[1], place[2], place[3])
            frame:Show()
        elseif face.keyFrame then
            face.keyFrame:Hide()
        end
    end
end

-- the fields of the settings window, added to the Appearance card of an icon (look). The helpers of Settings.lua
-- are given in h: Choice, Tip, HasAbility, SLOT_W.
function HeadsUpAuras_KeyTextFields(look, h)
    local UI = HeadsUpAurasUI
    local function isIcon(d) return d.shape ~= "bar" end
    local function hasText(d) return h.HasAbility(d) and d.keyText ~= nil and d.keyText ~= "" end
    look:Field({
        label = "Text",
        usable = h.HasAbility,
        shown = isIcon,
        tip = h.Tip("Text", "A short text written on the icon, for example the key that casts the ability (F1, Shift+3, Q...). Leave it empty for no text.", "You choose where it is written, its size and its color below."),
        controls = {
            {
                type = "input", w = h.SLOT_W, gap = 0, maxLetters = 12,
                get = function(d) return d.keyText or "" end,
                set = function(d, text) d.keyText = strtrim(text) end,
            },
        },
    })
    look:Field({
        label = "Text position",
        usable = hasText,
        shown = isIcon,
        tip = h.Tip("Text position", "Where the text is written on the icon: in a corner, at the top, at the bottom or in the middle.", "Grey while there is no text."),
        controls = { h.Choice("keyPos", PLACE_LIST, "topright") },
    })
    look:Field({
        label = "Text size",
        usable = hasText,
        shown = isIcon,
        tip = h.Tip("Text size", "The size of the letters, in pixels (from 8 to 64).", "Grey while there is no text."),
        controls = {
            {
                type = "input", numeric = true, maxLetters = 2, unit = "px",
                get = function(d) return d.keySize or 14 end,
                set = function(d, v) d.keySize = UI.Clamp(math.floor(v + 0.5), 8, 64) end,
            },
        },
    })
    look:Field({
        label = "Text color",
        usable = hasText,
        shown = isIcon,
        tip = h.Tip("Text color", "The color of the text. Click the square to choose any color from a small palette.", "Grey while there is no text."),
        controls = {
            {
                type = "color", w = h.SLOT_W, gap = 0,
                get = function(d) return d.keyColor or { 1, 1, 1 } end,
                set = function(d, rgb) d.keyColor = rgb end,
            },
        },
    })
end
