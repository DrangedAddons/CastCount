---------------------------------------------------------
--  CastCount - Overlay
--  Author: Dranged
---------------------------------------------------------

local addonName, CC = ...

CC = CC or {}
CC.Overlay = {}

---------------------------------------------------------
--  SECTION: Overlay creation
---------------------------------------------------------
function CC.Overlay:Get(button)
    if not button.CCOverlay then
        local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")

        -- Center the text
        text:ClearAllPoints()
        text:SetPoint("CENTER", button, "CENTER", 0, 0)

        -- Larger font, bright green, outlined
        text:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
        text:SetTextColor(0, 1, 0, 1)

        text:SetText("")
        button.CCOverlay = text
    end
    return button.CCOverlay
end

---------------------------------------------------------
--  SECTION: Overlay text control
---------------------------------------------------------
function CC.Overlay:SetText(button, value)
    local overlay = CC.Overlay:Get(button)
    overlay:SetText(value)
    overlay:Show()
end

function CC.Overlay:Hide(button)
    if button.CCOverlay then
        button.CCOverlay:SetText("")
        button.CCOverlay:Hide()
    end
end