---------------------------------------------------------
--  CastCount - Buttons
--  Author: Dranged
---------------------------------------------------------
-- Finds action buttons (Blizzard's and EllesmereUI's), works out the count for
-- each selected one and draws it.

local ADDON, CC = ...
local Plain = CC.Plain

---------------------------------------------------------
--  SECTION: Finding buttons
---------------------------------------------------------
-- Blizzard bars are grouped by button-name prefix (the main bar's buttons each
-- sit in their own container frame); every other bar addon by parent frame.
local BLIZZ_BARS = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton",
    "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}
local IS_BLIZZ_BAR = {}
for _, prefix in ipairs(BLIZZ_BARS) do IS_BLIZZ_BAR[prefix] = true end

local EUI_PREFIX, EUI_MAX = "EABButton", 240   -- EllesmereUI's own buttons, EABButton<slot>

-- The action slot a button currently shows. EllesmereUI's buttons (ID 0) carry it
-- as the "action" attribute; Blizzard's keep it in .action (paging updates it).
local function ActionSlot(btn)
    local attr = btn.GetAttribute and btn:GetAttribute("action")
    local id = btn.GetID and btn:GetID()
    if type(attr) == "number" and attr > 0 and (id == 0 or type(btn.action) ~= "number") then
        return attr
    end
    if type(btn.action) == "number" and btn.action > 0 then return btn.action end
    if type(attr) == "number" and attr > 0 then return attr end
    return nil
end
CC.ActionSlot = ActionSlot

-- Every action button that exists; with visibleOnly, just the ones on screen.
function CC.Candidates(visibleOnly)
    local list, seen = {}, {}
    local function add(btn)
        if type(btn) ~= "table" or seen[btn] or not btn.GetName or not btn:GetName() then return end
        seen[btn] = true
        if visibleOnly and not btn:IsVisible() then return end
        if not ActionSlot(btn) then return end
        list[#list + 1] = btn
    end
    for _, prefix in ipairs(BLIZZ_BARS) do
        for i = 1, 12 do add(_G[prefix .. i]) end
    end
    for i = 1, EUI_MAX do add(_G[EUI_PREFIX .. i]) end
    local registered = ActionBarButtonEventsFrame and ActionBarButtonEventsFrame.frames
    if type(registered) == "table" then
        for _, btn in pairs(registered) do add(btn) end
    end
    return list
end

-- What "the whole bar" means for shift-clicks: buttons with the same key.
function CC.BarKey(btn)
    local name = btn:GetName() or ""
    local prefix = name:match("^(.-)%d+$") or name
    if IS_BLIZZ_BAR[prefix] then return prefix end
    return btn:GetParent() or prefix
end

function CC.ButtonSpell(btn)
    return CC.ActionSpell(ActionSlot(btn))
end

---------------------------------------------------------
--  SECTION: Count text
---------------------------------------------------------
local holders = {}   -- button -> our text frame (a child of the button, drawn above its cooldown swipe)
local hovered = {}   -- button -> true while the mouse is over it

function CC.StyleHolder(h, fontPath)
    local t = CC.db.text
    local fs = h.text
    local flags = (t.outline ~= "NONE") and t.outline or ""
    fs:SetFont(fontPath or CC.FontPath(t.font), t.size, flags)
    if not fs:GetFont() then fs:SetFont(CC.DEFAULT_FONT, t.size, flags) end
    if t.shadow then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
    fs:ClearAllPoints()
    fs:SetPoint(t.anchor, h, t.anchor, t.x, t.y)
end

local function Holder(btn)
    local h = holders[btn]
    if h then return h end
    h = CreateFrame("Frame", nil, btn)
    h:SetAllPoints(btn)
    h:SetFrameLevel(math.min(10000, btn:GetFrameLevel() + 10))
    h.text = h:CreateFontString(nil, "OVERLAY")
    holders[btn] = h
    CC.StyleHolder(h)
    btn:HookScript("OnEnter", function() hovered[btn] = true; CC.MarkDirty() end)
    btn:HookScript("OnLeave", function() hovered[btn] = nil; CC.MarkDirty() end)
    return h
end

function CC.ApplyStyle()
    local path = CC.FontPath(CC.db.text.font)
    for _, h in pairs(holders) do CC.StyleHolder(h, path) end
    CC.MarkDirty()
end

local function ShowText(btn, text, c)
    local h = Holder(btn)
    -- Keep above the button even if a bar addon re-levels it.
    local want = math.min(10000, btn:GetFrameLevel() + 10)
    if h:GetFrameLevel() < want then h:SetFrameLevel(want) end
    h.text:SetText(text)
    h.text:SetTextColor(c.r, c.g, c.b, c.a or 1)
    h.text:Show()
end

local function HideText(btn)
    local h = holders[btn]
    if h then h.text:Hide() end
end

---------------------------------------------------------
--  SECTION: Counting
---------------------------------------------------------
local lastMana, lastMax = 0, 1
local function Mana()
    local cur, max = UnitPower("player", CC.MANA), UnitPowerMax("player", CC.MANA)
    if Plain(cur) then lastMana = cur end
    if Plain(max) then lastMax = max end
    return lastMana, lastMax
end

-- Colour for a count: the lowest low-count rule it falls under, otherwise the
-- normal text colour. (The list isn't kept sorted while it's being edited.)
function CC.CountColor(n)
    local rules = CC.db.rules
    if rules.enabled then
        local best
        for _, rule in ipairs(rules.list) do
            if n <= rule.at and (not best or rule.at < best.at) then best = rule end
        end
        if best then return best.color end
    end
    return CC.db.text.color
end

-- CC.preview (set while the Text/Rules/Blacklist tabs are open) shows every
-- selected count so style changes can be seen.
local function Visible(btn, mana, max)
    if CC.preview then return true end
    local s = CC.db.show
    if s.onHover and hovered[btn] then return true end
    if CC.inCombat then return s.inCombat end
    if not s.outOfCombat then return false end
    return not (s.oocOnlyNotFull and mana >= max)
end

function CC.UpdateButton(btn, mana, max)
    if not Visible(btn, mana, max) then return HideText(btn) end
    local spell = CC.ButtonSpell(btn)
    if not spell then return HideText(btn) end
    local name = CC.SpellName(spell)
    if name and CC.char.blacklist[name] then return HideText(btn) end
    local kind, cost = CC.SpellCost(spell)
    if kind == "mana" then
        local n = math.floor(mana / cost)
        ShowText(btn, n, CC.CountColor(n))
    elseif kind == "free" and CC.db.free.mode == "text" then
        ShowText(btn, CC.db.free.text, CC.db.free.color)
    else
        HideText(btn)
    end
end

function CC.Refresh()
    CC.dirty = false
    if not CC.db then return end
    local mana, max = Mana()
    local selected = CC.char.buttons
    for btn, h in pairs(holders) do
        if not selected[btn:GetName() or ""] then h.text:Hide() end
    end
    for name in pairs(selected) do
        local btn = _G[name]
        if type(btn) == "table" and btn.GetObjectType then CC.UpdateButton(btn, mana, max) end
    end
end

function CC.MarkDirty() CC.dirty = true end

-- Events only mark things dirty; one refresh runs at most every 0.05s, plus a
-- safety refresh every second (buffs like Clearcasting change costs silently).
local driver = CreateFrame("Frame")
local sinceRefresh = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    sinceRefresh = sinceRefresh + elapsed
    if (CC.dirty and sinceRefresh >= 0.05) or sinceRefresh >= 1 then
        sinceRefresh = 0
        CC.Refresh()
    end
end)

---------------------------------------------------------
--  SECTION: Events
---------------------------------------------------------
local function Dirty() CC.MarkDirty() end
local function PlayerDirty(_, unit) if unit == "player" then CC.MarkDirty() end end

for _, e in ipairs({
    "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
    "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "SPELLS_CHANGED",
}) do CC.On(e, Dirty) end

for _, e in ipairs({
    "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_AURA",
}) do CC.On(e, PlayerDirty) end

CC.inCombat = InCombatLockdown() or UnitAffectingCombat("player") or false
CC.On("PLAYER_REGEN_DISABLED", function() CC.inCombat = true; CC.MarkDirty() end)
CC.On("PLAYER_REGEN_ENABLED", function() CC.inCombat = false; CC.MarkDirty() end)
CC.OnReady(CC.MarkDirty)

---------------------------------------------------------
--  SECTION: Debug (/cc debug)
---------------------------------------------------------
-- Prints what the game hands us for mana and costs, so in-game reports show
-- whether a value is plain, secret or missing.
local function Show(v)
    if v == nil then return "nil" end
    if not Plain(v) then return "|cffff5555secret|r" end
    return tostring(v)
end

function CC.Debug()
    local cur, max = UnitPower("player", CC.MANA), UnitPowerMax("player", CC.MANA)
    local ptype = UnitPowerType("player")
    CC.Print(("mana %s / %s (secret API %s), power type %s, form %s, in combat %s, last used mana %s / %s")
        :format(Show(cur), Show(max), issecretvalue and "yes" or "no", Show(ptype),
            Show(GetShapeshiftForm and GetShapeshiftForm()), tostring(CC.inCombat), lastMana, lastMax))
    local n = 0
    for name in pairs(CC.char.buttons) do
        local btn = _G[name]
        if type(btn) == "table" and btn.GetObjectType then
            local slot = ActionSlot(btn)
            local spell = CC.ButtonSpell(btn)
            if spell then
                local costs = ((C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost)(spell)
                local raw = {}
                for _, c in ipairs(type(costs) == "table" and costs or {}) do
                    raw[#raw + 1] = ("type %s cost %s pct %s"):format(Show(c.type), Show(c.cost), Show(c.costPercent))
                end
                local kind, amount = CC.SpellCost(spell)
                CC.Print(("%s slot %s: %s (%s) -> %s %s  [%s]"):format(name, Show(slot), Show(CC.SpellName(spell)),
                    Show(spell), tostring(kind), tostring(amount), table.concat(raw, "; ")))
                n = n + 1
                if n >= 5 then break end
            end
        end
    end
    if n == 0 then CC.Print("No selected buttons with a spell.") end
end
