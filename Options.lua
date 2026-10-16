---------------------------------------------------------
--  CastCount - Options Panel
--  Author: Dranged
---------------------------------------------------------

local addonName, CC = ...

CC = CC or {}

---------------------------------------------------------
--  SECTION: Panel creation
---------------------------------------------------------
local panel = CreateFrame("Frame", "CastCountOptionsPanel", UIParent)
panel.name = "CastCount"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("CastCount Options")

---------------------------------------------------------
--  SECTION: Bars list
---------------------------------------------------------
local bars = {
    "ActionBar1",
    "ActionBar2",
    "ActionBar3",
    "ActionBar4",
    "ActionBar5",
    "ActionBar6",
	"ActionBar7",
	"ActionBar8",
}

local checkboxes = {}
local initialized = false

local function GetConfig()
    CastCountDB = CastCountDB or {}
    CastCountDB.bars = CastCountDB.bars or {}
    CastCountDB.ignoreList = CastCountDB.ignoreList or {}
    return CastCountDB
end

---------------------------------------------------------
--  SECTION: Combat-only toggle
---------------------------------------------------------
local combatCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
combatCB:SetPoint("TOPLEFT", 16, -320)
combatCB.Text:SetText("Only show in combat")

combatCB:SetScript("OnClick", function(self)
    CastCountDB.onlyInCombat = self:GetChecked()
    CC:UpdateAllButtons()
end)

---------------------------------------------------------
--  SECTION: Always show toggle
---------------------------------------------------------
local alwaysCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
alwaysCB:SetPoint("TOPLEFT", 16, -350)
alwaysCB.Text:SetText("Always show")

alwaysCB:SetScript("OnClick", function(self)
    CastCountDB.alwaysShow = self:GetChecked()
    CC:UpdateAllButtons()
end)

---------------------------------------------------------
--  SECTION: Initialize checkboxes AFTER SavedVariables load
---------------------------------------------------------
local function InitializeCheckboxes()
    if initialized then return end
    initialized = true

    local cfg = GetConfig()
    local y = -60

    for _, barName in ipairs(bars) do
        local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, y)
        cb.Text:SetText(barName)

        if cfg.bars[barName] == nil then
            cfg.bars[barName] = true
        end

        cb:SetChecked(cfg.bars[barName])

        cb:SetScript("OnClick", function(self)
            cfg.bars[barName] = self:GetChecked()
            if CC and CC.UpdateAllButtons then
                CC:UpdateAllButtons()
            end
        end)

        checkboxes[barName] = cb
        y = y - 30
    end
end

---------------------------------------------------------
--  SECTION: Ignore List UI
---------------------------------------------------------

local ignoreTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
ignoreTitle:SetPoint("TOPLEFT", 300, -16)
ignoreTitle:SetText("Ignored Spells")

-- Scroll frame
local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 300, -50)
scrollFrame:SetSize(260, 260)

local scrollChild = CreateFrame("Frame")
scrollChild:SetSize(260, 260)
scrollFrame:SetScrollChild(scrollChild)

local ignoreRows = {}

local function RefreshIgnoreList()
    local cfg = GetConfig()

    -- Clear old rows
    for _, row in ipairs(ignoreRows) do
        row:Hide()
    end
    wipe(ignoreRows)

    local y = -5
    for spellID in pairs(cfg.ignoreList) do
        local name, _, icon = GetSpellInfo(spellID)

        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(240, 30)
        row:SetPoint("TOPLEFT", 0, y)

        local tex = row:CreateTexture(nil, "ARTWORK")
        tex:SetSize(24, 24)
        tex:SetPoint("LEFT", 0, 0)
        tex:SetTexture(icon)

        local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", tex, "RIGHT", 8, 0)
        label:SetText(name or ("SpellID " .. spellID))

        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetSize(60, 20)
        removeBtn:SetPoint("RIGHT", 0, 0)
        removeBtn:SetText("Remove")

        removeBtn:SetScript("OnClick", function()
            cfg.ignoreList[spellID] = nil
            RefreshIgnoreList()
            CC:UpdateAllButtons()
        end)

        table.insert(ignoreRows, row)
        y = y - 32
    end
end

---------------------------------------------------------
--  SECTION: Add Spell Input
---------------------------------------------------------

local inputBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
inputBox:SetSize(200, 30)
inputBox:SetPoint("TOPLEFT", 300, -330)
inputBox:SetAutoFocus(false)

local addButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
addButton:SetSize(80, 24)
addButton:SetPoint("LEFT", inputBox, "RIGHT", 10, 0)
addButton:SetText("Add")

addButton:SetScript("OnClick", function()
    local cfg = GetConfig()
    local text = inputBox:GetText()
    if not text or text == "" then return end

    local spellID = tonumber(text)
    if not spellID then
        spellID = select(7, GetSpellInfo(text))
    end

    if spellID then
        cfg.ignoreList[spellID] = true
        inputBox:SetText("")
        RefreshIgnoreList()
        CC:UpdateAllButtons()
    end
end)

---------------------------------------------------------
--  SECTION: Panel refresh
---------------------------------------------------------
panel.refresh = function()
    InitializeCheckboxes()

    local cfg = GetConfig()

    for _, barName in ipairs(bars) do
        local cb = checkboxes[barName]
        if cb then
            cb:SetChecked(cfg.bars[barName])
        end
    end

    combatCB:SetChecked(cfg.onlyInCombat)
	alwaysCB:SetChecked(CastCountDB.alwaysShow)
    RefreshIgnoreList()
end

---------------------------------------------------------
--  SECTION: Panel registration
---------------------------------------------------------
if InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
elseif Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
elseif InterfaceOptionsFrameAddOns then
    table.insert(InterfaceOptionsFrameAddOns, panel)
end

---------------------------------------------------------
--  SECTION: Wait for SavedVariables before initializing
---------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, addon)
    if addon == addonName then
        InitializeCheckboxes()
        RefreshIgnoreList()
    end
end)