---------------------------------------------------------
--  CastCount - Minimap button
--  Author: Dranged
---------------------------------------------------------
-- A LibDBIcon button (so minimap addons can collect it): click opens the settings.

local ADDON, CC = ...

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
local ICON = "Interface\\Icons\\Spell_Holy_MagicalSentry"

function CC.SetMinimapShown(on)
    CC.db.minimap.hide = not on
    if not DBI then return end
    if on then DBI:Show("CastCount") else DBI:Hide("CastCount") end
end

CC.OnReady(function()
    if not (LDB and DBI) then return end
    local launcher = LDB:NewDataObject("CastCount", {
        type = "launcher",
        text = "CastCount",
        icon = ICON,
        OnClick = function() CC.ToggleConfig() end,
        OnTooltipShow = function(tt)
            tt:AddLine("CastCount")
            tt:AddLine("|cffffd100Click|r to open the settings", 1, 1, 1)
            tt:AddLine("|cffffd100Drag|r to move this button", 1, 1, 1)
        end,
    })
    DBI:Register("CastCount", launcher, CC.db.minimap)
end)
