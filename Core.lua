---------------------------------------------------------
--  CastCount - Core
--  Author: Dranged
---------------------------------------------------------

---------------------------------------------------------
--  SECTION: Addon table and forward declarations
---------------------------------------------------------
local addonName, CC = ...

CC = CC or {}
CC.frame = CreateFrame("Frame")

local NormalizeBarName

---------------------------------------------------------
--  SECTION: Config initialization (defaults after SV)
---------------------------------------------------------
function CC:InitConfig()
    CastCountDB = CastCountDB or {}

    -- Bar visibility config
    CastCountDB.bars = CastCountDB.bars or {}

    local defaults = {
        ActionBar1 = true,
        ActionBar2 = true,
        ActionBar3 = true,
        ActionBar4 = true,
        ActionBar5 = true,
        ActionBar6 = true,
		ActionBar7 = true,
		ActionBar8 = true,
    }

    for bar, defaultValue in pairs(defaults) do
        if CastCountDB.bars[bar] == nil then
            CastCountDB.bars[bar] = defaultValue
        end
    end

    -- Spell ignore list
    CastCountDB.onlyInCombat = CastCountDB.onlyInCombat or false
	CastCountDB.alwaysShow = CastCountDB.alwaysShow or false

    CastCountDB.ignoreList = CastCountDB.ignoreList or {}
end


---------------------------------------------------------
--  SECTION: Bar name normalization (DFUI / Classic)
---------------------------------------------------------
NormalizeBarName = function(parentName)
    if not parentName then return nil end

    -- DFUI Classic Anniversary bar frames (with 4 & 5 swapped)
    local dfuiBars = {
        DragonflightUIActionbarFrame1 = "ActionBar1",
        DragonflightUIActionbarFrame2 = "ActionBar2",
        DragonflightUIActionbarFrame3 = "ActionBar3",
        DragonflightUIActionbarFrame4 = "ActionBar5", -- swapped
        DragonflightUIActionbarFrame5 = "ActionBar4", -- swapped
        DragonflightUIActionbarFrame6 = "ActionBar6",
        DragonflightUIActionbarFrame7 = "ActionBar7",
        DragonflightUIActionbarFrame8 = "ActionBar8",
    }

    if dfuiBars[parentName] then
        return dfuiBars[parentName]
    end

    -- NEW: Retail DFUI parent for ActionBar1 (TBC Anniversary update)
    if parentName == "MainActionBarButtonContainer1" then
        return "ActionBar1"
    end

    -- Legacy DFUI parent for ActionBar1
    if parentName == "MainMenuBarArtFrame" then
        return "ActionBar1"
    end

    -- Blizzard Classic fallback
    local knownBars = {
        ActionBar1 = "ActionBar1",
        ActionBar2 = "ActionBar2",
        ActionBar3 = "ActionBar3",
        ActionBar4 = "ActionBar4",
        ActionBar5 = "ActionBar5",
        ActionBar6 = "ActionBar6",
        ActionBar7 = "ActionBar7",
        ActionBar8 = "ActionBar8",
        MultiBarBottomLeft = "ActionBar2",
        MultiBarBottomRight = "ActionBar3",
        MultiBarRight = "ActionBar4",
        MultiBarLeft = "ActionBar5",
    }

    return knownBars[parentName] or nil
end

---------------------------------------------------------
--  SECTION: Spell cost helper
---------------------------------------------------------
function CC:GetSpellCost(spellID)
    if not spellID then return nil end
    local costTable = GetSpellPowerCost(spellID)
    if not costTable then return nil end

    for _, costInfo in ipairs(costTable) do
        if costInfo.type == 0 then -- mana
            return costInfo.cost
        end
    end
    return nil
end

---------------------------------------------------------
--  SECTION: Button update logic (with ignore list)
---------------------------------------------------------
function CC:UpdateButton(button)
    local action = button.action
    if not action then
        CC.Overlay:Hide(button)
        return
    end

    local actionType, id = GetActionInfo(action)
    if actionType ~= "spell" then
        CC.Overlay:Hide(button)
        return
    end

-- Always show overrides everything
if CastCountDB.alwaysShow then
    -- do nothing, continue to normal overlay logic
else
    -- Combat-only mode (but show if mana < 100%)
    if CastCountDB.onlyInCombat then
        local inCombat = UnitAffectingCombat("player")
        local mana = UnitPower("player", 0)
        local maxMana = UnitPowerMax("player", 0)

        if not inCombat and mana == maxMana then
            CC.Overlay:Hide(button)
            return
        end
    end
end

    -- Ignore list check
    if CastCountDB.ignoreList and CastCountDB.ignoreList[id] then
        CC.Overlay:Hide(button)
        return
    end


    local cost = CC:GetSpellCost(id)
    if not cost or cost == 0 then
        CC.Overlay:Hide(button)
        return
    end

    local mana = UnitPower("player", 0)
    local casts = math.floor(mana / cost)

    CC.Overlay:SetText(button, casts)
end

---------------------------------------------------------
--  SECTION: Update all buttons (with safe bar filtering)
---------------------------------------------------------
function CC:UpdateAllButtons()
    if not ActionBarButtonEventsFrame or not ActionBarButtonEventsFrame.frames then
        return
    end

    for _, button in ipairs(ActionBarButtonEventsFrame.frames) do
        if button and button.action then
            local parent = button:GetParent()
            local rawName = parent and parent:GetName()
            local barName = NormalizeBarName(rawName)

            -- If we can map to a known bar, respect config.
            if barName then
                if CastCountDB.bars[barName] then
                    CC:UpdateButton(button)
                else
                    CC.Overlay:Hide(button)
                end
            else
                -- Unknown bar → show overlays by default
                CC:UpdateButton(button)
            end
        end
    end
end

---------------------------------------------------------
--  SECTION: Events and main update
---------------------------------------------------------
local events = {
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "UNIT_POWER_UPDATE",
    "ACTIONBAR_SLOT_CHANGED",
    "SPELLS_CHANGED",
    "PLAYER_TALENT_UPDATE",
}

for _, e in ipairs(events) do
    CC.frame:RegisterEvent(e)
end

CC.frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        CC:InitConfig()
        C_Timer.After(0.1, function()
            CC:UpdateAllButtons()
        end)
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.1, function()
            CC:UpdateAllButtons()
        end)
        return
    end

    if event == "UNIT_POWER_UPDATE" then
        if arg1 == "player" then
            CC:UpdateAllButtons()
        end
        return
    end

    if event == "ACTIONBAR_SLOT_CHANGED"
        or event == "SPELLS_CHANGED"
        or event == "PLAYER_TALENT_UPDATE" then
        CC:UpdateAllButtons()
        return
    end
end)