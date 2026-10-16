---------------------------------------------------------
--  CastCount - Button picker
--  Author: Dranged
---------------------------------------------------------
-- The keybind-style selection mode: every action button on screen gets a
-- clickable cover. Left-click adds, right-click removes, Shift does the whole bar.

local ADDON, CC = ...
local UI = CC.UI

local overlays = {}   -- button -> cover
local active = false

local function IsSelected(btn) return CC.char.buttons[btn:GetName()] and true or false end

local function SetSelected(btn, on)
    CC.char.buttons[btn:GetName()] = on or nil
end

function CC.SelectedCount()
    local n = 0
    for _ in pairs(CC.char.buttons) do n = n + 1 end
    return n
end

local function Paint(o)
    local sel = IsSelected(o.btn)
    if sel then
        o.fill:SetColorTexture(0.1, 0.8, 0.25, 0.35)
        o:SetBackdropBorderColor(0.2, 1, 0.35, 1)
    else
        o.fill:SetColorTexture(0, 0, 0, 0.55)
        o:SetBackdropBorderColor(0.45, 0.45, 0.45, 0.9)
    end
    o.check:SetShown(sel)
end

function CC.RepaintPicker()
    for _, o in pairs(overlays) do
        if o:IsShown() then Paint(o) end
    end
end

local function ShowTooltip(o)
    GameTooltip:SetOwner(o, "ANCHOR_TOP")
    local spell = CC.ButtonSpell(o.btn)
    local name = spell and CC.SpellName(spell)
    GameTooltip:AddLine(name or "Empty button", 1, 1, 1)
    GameTooltip:AddLine(IsSelected(o.btn) and "|cff33ff55Shows a cast count|r" or "|cff999999No cast count|r")
    GameTooltip:AddLine("Left-click: add  |  Shift + left-click: add bar", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: remove  |  Shift + right-click: remove bar", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

local function OnClick(o, mouse)
    if InCombatLockdown() then return end
    local add = (mouse == "LeftButton")
    if IsShiftKeyDown() then
        local key = CC.BarKey(o.btn)
        for _, btn in ipairs(CC.Candidates(false)) do
            if CC.BarKey(btn) == key then SetSelected(btn, add) end
        end
    else
        SetSelected(o.btn, add)
    end
    CC.RepaintPicker()
    CC.MarkDirty()
    UI.RefreshAll()
    if GameTooltip:GetOwner() == o then ShowTooltip(o) end
end

local function Overlay(btn)
    local o = overlays[btn]
    if o then return o end
    o = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    o:SetFrameStrata("DIALOG")
    o:SetAllPoints(btn)
    o:SetBackdrop({ edgeFile = UI.WHITE, edgeSize = 2 })
    o.fill = o:CreateTexture(nil, "BACKGROUND")
    o.fill:SetPoint("TOPLEFT", 2, -2)
    o.fill:SetPoint("BOTTOMRIGHT", -2, 2)
    o.check = o:CreateTexture(nil, "OVERLAY")
    o.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    o.check:SetSize(18, 18)
    o.check:SetPoint("TOPRIGHT", 3, 3)
    o:SetHighlightTexture(UI.WHITE)
    local hl = o:GetHighlightTexture()
    hl:SetVertexColor(1, 1, 1)
    hl:SetAlpha(0.15)
    o:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    o:SetScript("OnClick", OnClick)
    o:SetScript("OnEnter", ShowTooltip)
    o:SetScript("OnLeave", function() GameTooltip:Hide() end)
    o.btn = btn
    overlays[btn] = o
    return o
end

-- Covers every button on screen. Returns false (with a message) in combat.
function CC.StartPicking()
    if InCombatLockdown() then
        CC.Print("Button selection opens after combat.")
        return false
    end
    active = true
    for _, o in pairs(overlays) do o:Hide() end
    for _, btn in ipairs(CC.Candidates(true)) do Overlay(btn):Show() end
    CC.RepaintPicker()
    return true
end

function CC.StopPicking()
    active = false
    for _, o in pairs(overlays) do
        if GameTooltip:GetOwner() == o then GameTooltip:Hide() end
        o:Hide()
    end
end

function CC.IsPicking() return active end

-- The covers would swallow clicks meant for spells, so combat always closes them.
CC.On("PLAYER_REGEN_DISABLED", function()
    if active then
        CC.StopPicking()
        CC.Print("Button selection paused for combat.")
        CC.pickingPaused = true
    end
end)

-- Adds every button on screen.
function CC.SelectAllVisible()
    for _, btn in ipairs(CC.Candidates(true)) do SetSelected(btn, true) end
    CC.RepaintPicker()
    CC.MarkDirty()
    UI.RefreshAll()
end

function CC.ClearSelection()
    wipe(CC.char.buttons)
    CC.RepaintPicker()
    CC.MarkDirty()
    UI.RefreshAll()
end
