---------------------------------------------------------
--  CastCount - Button picker
--  Author: Dranged
---------------------------------------------------------
-- The keybind-style selection mode: every action button on screen gets a
-- clickable cover. A click toggles the button; with Shift, its whole bar.

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

-- Hover highlight: white-blue = clicking adds, red = clicking removes.
local ADD_COLOR = { 0.7, 0.9, 1 }
local REMOVE_COLOR = { 1, 0.2, 0.2 }
local hovered          -- the cover under the mouse

-- The covers a click on o would change: o alone, or with Shift its whole bar (on screen).
local function Group(o)
    if not IsShiftKeyDown() then return { o } end
    local key, group = CC.BarKey(o.btn), {}
    for _, other in pairs(overlays) do
        if other:IsShown() and CC.BarKey(other.btn) == key then group[#group + 1] = other end
    end
    return group
end

-- A click removes when everything it would change is already selected, otherwise it adds.
local function ClickRemoves(group)
    for _, o in ipairs(group) do
        if not IsSelected(o.btn) then return false end
    end
    return true
end

local function PaintHover()
    for _, o in pairs(overlays) do o.hover:Hide() end
    if not (active and hovered and hovered:IsShown()) then return end
    local group = Group(hovered)
    local c = ClickRemoves(group) and REMOVE_COLOR or ADD_COLOR
    for _, o in ipairs(group) do
        o.hover:SetColorTexture(c[1], c[2], c[3], 0.4)
        o.hover:Show()
    end
end

function CC.RepaintPicker()
    for _, o in pairs(overlays) do
        if o:IsShown() then Paint(o) end
    end
    PaintHover()
end

local function ShowTooltip(o)
    GameTooltip:SetOwner(o, "ANCHOR_TOP")
    local spell = CC.ButtonSpell(o.btn)
    local name = spell and CC.SpellName(spell)
    GameTooltip:AddLine(name or "Empty button", 1, 1, 1)
    GameTooltip:AddLine(IsSelected(o.btn) and "|cff33ff55Shows a cast count|r" or "|cff999999No cast count|r")
    local removes = ClickRemoves(Group(o))
    if IsShiftKeyDown() then
        GameTooltip:AddLine(removes and "Click: remove this bar" or "Click: add this bar", 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine(removes and "Click: remove this button" or "Click: add this button", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Hold Shift for the whole bar", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

-- Click toggles: if everything it covers is selected it's removed, otherwise it's added.
-- With Shift it acts on the whole bar, including empty buttons that aren't on screen.
local function OnClick(o)
    if InCombatLockdown() then return end
    local add = not ClickRemoves(Group(o))
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
    o.hover = o:CreateTexture(nil, "ARTWORK")
    o.hover:SetAllPoints(o.fill)
    o.hover:Hide()
    o.check = o:CreateTexture(nil, "OVERLAY")
    o.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    o.check:SetSize(18, 18)
    o.check:SetPoint("TOPRIGHT", 3, 3)
    o:RegisterForClicks("LeftButtonUp")
    o:SetScript("OnClick", OnClick)
    o:SetScript("OnEnter", function(self)
        hovered = self
        PaintHover()
        ShowTooltip(self)
    end)
    o:SetScript("OnLeave", function(self)
        if hovered == self then hovered = nil end
        PaintHover()
        GameTooltip:Hide()
    end)
    o.btn = btn
    overlays[btn] = o
    return o
end

-- Pressing or releasing Shift while hovering switches between button and bar.
CC.On("MODIFIER_STATE_CHANGED", function()
    if not (active and hovered) then return end
    PaintHover()
    if GameTooltip:GetOwner() == hovered then ShowTooltip(hovered) end
end)

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
    hovered = nil
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
