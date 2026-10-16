---------------------------------------------------------
--  CastCount - Config window
--  Author: Dranged
---------------------------------------------------------
-- /castcount opens it. Tabs: Buttons (the picker), Blacklist, Text, Visibility, Rules.

local ADDON, CC = ...
local UI = CC.UI
local Color = CC.Color

local W, H = 680, 500
local win
local pages, tabButtons = {}, {}
local current = "buttons"

local TABS = {
    { key = "buttons",    label = "Buttons" },
    { key = "blacklist",  label = "Blacklist" },
    { key = "text",       label = "Text" },
    { key = "visibility", label = "Visibility" },
    { key = "rules",      label = "Rules" },
}
-- Tabs where every selected count shows, whatever the visibility settings say.
local PREVIEW = { blacklist = true, text = true, rules = true }

local function Version()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return get and get(ADDON, "Version") or ""
end

local function Heading(page, text, x, y)
    local fs = UI.Text(page, text, "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    return fs
end

local function Note(page, text, x, y, w)
    local fs = UI.Text(page, text, "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(w or 640)
    fs:SetTextColor(0.75, 0.75, 0.75)
    return fs
end

local function Refresher(fn) return UI.Track({ Refresh = fn }) end

local function Changed()
    CC.MarkDirty()
end

local function StyleChanged()
    CC.ApplyStyle()
end

---------------------------------------------------------
--  SECTION: Buttons tab
---------------------------------------------------------
StaticPopupDialogs["CASTCOUNT_CLEAR"] = {
    text = "Remove CastCount from all of your buttons?",
    button1 = YES, button2 = NO,
    OnAccept = function() CC.ClearSelection() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local builders = {}

function builders.buttons(p)
    Heading(p, "Choose which action buttons show a cast count", 0, 0)
    local lines = {
        "While this tab is open your action buttons are covered, like the game's key binding mode:",
        "    |cffffd100Click|r a button to add it, click it again to remove it",
        "    Hold |cffffd100Shift|r to do the same for its whole bar",
        "    |cffb3e6ffBlue|r highlight: the click adds  ·  |cffff3333red|r highlight: the click removes",
        "Selected buttons are green with a tick. Hover a button to see its spell.",
    }
    local y = -26
    for _, line in ipairs(lines) do
        local fs = UI.Text(p, line)
        fs:SetPoint("TOPLEFT", 0, y)
        y = y - 20
    end

    local status = UI.Text(p, "", "GameFontNormalLarge")
    status:SetPoint("TOPLEFT", 0, y - 14)
    Refresher(function() status:SetText(("%d buttons selected"):format(CC.SelectedCount())) end)

    local addAll = UI.Button(p, "Add every button on screen", 210, 24, function() CC.SelectAllVisible() end)
    addAll:SetPoint("TOPLEFT", 0, y - 48)
    local clear = UI.Button(p, "Remove all", 120, 24, function() StaticPopup_Show("CASTCOUNT_CLEAR") end)
    clear:SetPoint("LEFT", addAll, "RIGHT", 10, 0)

    Note(p, "Works with Blizzard's action bars and EllesmereUI. Your selection is saved per character. "
        .. "Combat pauses the selection; it comes back when combat ends.", 0, -330)
end

---------------------------------------------------------
--  SECTION: Blacklist tab
---------------------------------------------------------
function builders.blacklist(p)
    local COLW, ROWS, ROWH = 280, 14, 20
    local RIGHT_X = COLW + 60
    local source, manaOnly = "all", true
    local known = {}
    local leftList, rightList, rightSelName

    local Rebuild

    local function Add(e)
        if not e then return end
        CC.char.blacklist[e.name] = e.id or true
        leftList.selected = nil
        Rebuild()
        Changed()
    end

    local function Remove(e)
        if not e then return end
        CC.char.blacklist[e.name] = nil
        rightSelName = nil
        Rebuild()
        Changed()
    end

    Heading(p, "Your spells", 0, 0)
    local search = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    search:SetSize(COLW - 6, 20)
    search:SetPoint("TOPLEFT", 6, -20)
    search:SetAutoFocus(false)
    local hint = UI.Text(search, "Search...", "GameFontDisable")
    hint:SetPoint("LEFT", 2, 0)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local sourceDD = UI.Dropdown(p, 160, function()
        return {
            { value = "all",  label = "All known spells" },
            { value = "bars", label = "On my action bars" },
        }
    end, function() return source end, function(v) source = v; Rebuild() end)
    sourceDD:SetPoint("TOPLEFT", 0, -46)

    local manaCB = UI.Check(p, "Mana spells only", function() return manaOnly end,
        function(v) manaOnly = v; Rebuild() end)
    manaCB:SetPoint("TOPLEFT", 168, -45)

    local function RenderLeft(row, e)
        local label = e.name
        if e.onBars and source == "all" then label = label .. "  |cff888888(on bars)|r" end
        UI.RenderRow(row, label, e.icon)
        if e.mana then row.text:SetTextColor(1, 1, 1) else row.text:SetTextColor(0.6, 0.6, 0.6) end
    end
    local function RenderRight(row, e)
        UI.RenderRow(row, e.name, e.icon)
        row.text:SetTextColor(1, 1, 1)
    end

    leftList = UI.List(p, COLW, ROWH, ROWS, RenderLeft, function(list, e)
        list.selected = e
        list:Update()
    end)
    leftList:SetPoint("TOPLEFT", 0, -74)
    leftList.onDouble = function(_, e) Add(e) end

    Heading(p, "Blacklist: never show a count", RIGHT_X, 0)
    Note(p, "Blacklisting a spell covers all of its ranks.", RIGHT_X, -24, COLW)

    rightList = UI.List(p, COLW, ROWH, ROWS, RenderRight, function(list, e)
        list.selected = e
        rightSelName = e.name
        list:Update()
    end)
    rightList:SetPoint("TOPLEFT", RIGHT_X, -74)
    rightList.onDouble = function(_, e) Remove(e) end

    local toRight = UI.Button(p, ">", 36, 26, function() Add(leftList.selected) end)
    toRight:SetPoint("TOPLEFT", COLW + 12, -150)
    local toLeft = UI.Button(p, "<", 36, 26, function() Remove(rightList.selected) end)
    toLeft:SetPoint("TOPLEFT", COLW + 12, -186)

    Note(p, "Select a spell and use the arrows, or double-click it to move it across. "
        .. "Grey spells don't cost mana, so they never show a count anyway.", 0, -370, 620)

    Rebuild = function()
        local filter = (search:GetText() or ""):lower()
        hint:SetShown(filter == "" and not search:HasFocus())
        local left = {}
        for _, e in ipairs(known) do
            if not CC.char.blacklist[e.name]
                and (source == "all" or e.onBars)
                and (not manaOnly or e.mana)
                and (filter == "" or e.name:lower():find(filter, 1, true)) then
                left[#left + 1] = e
            end
        end
        leftList:SetData(left)

        local right = {}
        for name, id in pairs(CC.char.blacklist) do
            right[#right + 1] = { name = name, id = id, icon = CC.SpellIcon(type(id) == "number" and id or nil) }
        end
        table.sort(right, function(a, b) return a.name < b.name end)
        rightList.selected = nil
        rightList:SetData(right)
        for _, e in ipairs(right) do
            if e.name == rightSelName then rightList.selected = e end
        end
        rightList:Update()
    end

    search:SetScript("OnTextChanged", function() Rebuild() end)
    search:SetScript("OnEditFocusGained", function() hint:Hide() end)
    search:SetScript("OnEditFocusLost", function() Rebuild() end)

    p:SetScript("OnShow", function()
        known = CC.KnownSpells()
        Rebuild()
    end)
    CC.On("SPELLS_CHANGED", function()
        if p:IsVisible() then
            known = CC.KnownSpells()
            Rebuild()
        end
    end)
end

---------------------------------------------------------
--  SECTION: Text tab
---------------------------------------------------------
local ANCHORS = {
    { value = "TOPLEFT",     label = "Top left" },
    { value = "TOP",         label = "Top" },
    { value = "TOPRIGHT",    label = "Top right" },
    { value = "LEFT",        label = "Left" },
    { value = "CENTER",      label = "Centre" },
    { value = "RIGHT",       label = "Right" },
    { value = "BOTTOMLEFT",  label = "Bottom left" },
    { value = "BOTTOM",      label = "Bottom" },
    { value = "BOTTOMRIGHT", label = "Bottom right" },
}

-- The spell icon and size of the first selected mana-spell button, for the preview.
local function PreviewSource()
    for name in pairs(CC.char.buttons) do
        local btn = _G[name]
        local spell = type(btn) == "table" and btn.GetObjectType and CC.ButtonSpell(btn)
        if spell and CC.SpellCost(spell) == "mana" then
            local w = btn:GetWidth()
            return CC.SpellIcon(spell), (w and w > 10) and w or 45
        end
    end
    return "Interface\\Icons\\Spell_Frost_FrostBolt02", 45
end

-- A mock action button showing a count in the current text style.
local function PreviewButton(parent, scale)
    local b = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    b:SetScale(scale)
    UI.Backdrop(b, 0, 0, 0, 1, 0, 0, 0, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local h = CreateFrame("Frame", nil, b)
    h:SetAllPoints(b)
    h:SetFrameLevel(b:GetFrameLevel() + 2)
    h.text = h:CreateFontString(nil, "OVERLAY")
    b.holder = h
    return b
end

function builders.text(p)
    local function T() return CC.db.text end
    local UpdatePreview
    -- Restyle the real buttons and the preview together.
    local function StyleChanged()
        CC.ApplyStyle()
        if UpdatePreview then UpdatePreview() end
    end

    Heading(p, "Font", 0, 0)
    local font = UI.Dropdown(p, 220, function()
        local items = {}
        for _, f in ipairs(CC.Fonts()) do items[#items + 1] = { value = f.name, label = f.name, font = f.path } end
        return items
    end, function() return T().font end, function(v) T().font = v; StyleChanged() end)
    font:SetPoint("TOPLEFT", 0, -20)

    local outline = UI.Dropdown(p, 140, function()
        return {
            { value = "NONE",         label = "No outline" },
            { value = "OUTLINE",      label = "Outline" },
            { value = "THICKOUTLINE", label = "Thick outline" },
        }
    end, function() return T().outline end, function(v) T().outline = v; StyleChanged() end)
    outline:SetPoint("TOPLEFT", 236, -20)

    local shadow = UI.Check(p, "Shadow", function() return T().shadow end,
        function(v) T().shadow = v; StyleChanged() end)
    shadow:SetPoint("TOPLEFT", 392, -19)

    local size = UI.Slider(p, "Size", 8, 40, 1, 220, function() return T().size end,
        function(v) T().size = v; StyleChanged() end)
    size:SetPoint("TOPLEFT", 0, -56)

    Heading(p, "Colour", 0, -110)
    local swatch = UI.Swatch(p, function() return T().color end, StyleChanged)
    swatch:SetPoint("TOPLEFT", 0, -130)
    Note(p, "Normal count colour. Low-count rules on the Rules tab can override it.", 30, -136, 500)

    Heading(p, "Position on the button", 0, -172)
    local anchor = UI.Dropdown(p, 160, function() return ANCHORS end,
        function() return T().anchor end, function(v) T().anchor = v; StyleChanged() end)
    anchor:SetPoint("TOPLEFT", 0, -192)

    local x = UI.Slider(p, "Nudge left / right", -30, 30, 1, 220, function() return T().x end,
        function(v) T().x = v; StyleChanged() end)
    x:SetPoint("TOPLEFT", 0, -226)
    local y = UI.Slider(p, "Nudge down / up", -30, 30, 1, 220, function() return T().y end,
        function(v) T().y = v; StyleChanged() end)
    y:SetPoint("TOPLEFT", 236, -226)

    local reset = UI.Button(p, "Reset text settings", 160, 22, function()
        CC.ResetSection("text")
        StyleChanged()
        UI.RefreshAll()
    end)
    reset:SetPoint("TOPLEFT", 0, -290)

    Note(p, "While this tab is open every selected button shows its count, so you can see your changes.", 0, -370)

    -- Preview, on the right: one big button with a normal count, and smaller
    -- real-size ones showing a low-count rule colour and an empty count.
    local box = CreateFrame("Frame", nil, p, "BackdropTemplate")
    box:SetSize(170, 300)
    box:SetPoint("TOPRIGHT", 0, 0)
    UI.Backdrop(box, 0.03, 0.03, 0.035, 0.9)
    local title = UI.Text(box, "Preview", "GameFontNormal")
    title:SetPoint("TOP", 0, -8)
    title:SetJustifyH("CENTER")

    local big = PreviewButton(box, 2)
    local small = { PreviewButton(box, 1), PreviewButton(box, 1) }
    local labels = {}
    for i = 1, 2 do
        labels[i] = UI.Text(box, "", "GameFontHighlightSmall")
        labels[i]:SetPoint("TOP", small[i], "BOTTOM", 0, -4)
        labels[i]:SetJustifyH("CENTER")
    end

    UpdatePreview = function()
        if not box:IsVisible() then return end
        local icon, size = PreviewSource()
        local path = CC.FontPath(T().font)
        -- Real size inside a box the scaled button must fit (2x, at most 140 wide).
        local bigScale = math.min(2, 140 / size)
        big:SetScale(bigScale)
        big:SetSize(size, size)
        big:ClearAllPoints()
        big:SetPoint("TOP", box, "TOP", 0, -32 / bigScale)

        -- The highest rule shows its colour on the left small button; 0 casts on the right.
        local rules, ruleAt = CC.db.rules, nil
        if rules.enabled then
            for _, rule in ipairs(rules.list) do
                if not ruleAt or rule.at > ruleAt then ruleAt = rule.at end
            end
        end
        local counts = { { 12, "12 casts" }, { ruleAt or 3, ruleAt and "Low count" or "3 casts" }, { 0, "Out of mana" } }

        local function Fill(b, n)
            b.icon:SetTexture(icon)
            CC.StyleHolder(b.holder, path)
            local c = CC.CountColor(n)
            b.holder.text:SetText(n)
            b.holder.text:SetTextColor(c.r, c.g, c.b, c.a or 1)
        end
        Fill(big, counts[1][1])
        local smallScale = math.min(1, 60 / size)
        for i, b in ipairs(small) do
            b:SetScale(smallScale)
            b:SetSize(size, size)
            b:ClearAllPoints()
            b:SetPoint("TOP", box, "TOPLEFT", (i == 1 and 45 or 125) / smallScale, -(32 + size * bigScale + 24) / smallScale)
            Fill(b, counts[i + 1][1])
            labels[i]:SetText(counts[i + 1][2])
        end
    end
    box:SetScript("OnShow", UpdatePreview)
    Refresher(function() UpdatePreview() end)
end

---------------------------------------------------------
--  SECTION: Visibility tab
---------------------------------------------------------
function builders.visibility(p)
    local function S() return CC.db.show end
    local function Check(label, key, x, y)
        local cb = UI.Check(p, label, function() return S()[key] end, function(v) S()[key] = v; Changed() end)
        cb:SetPoint("TOPLEFT", x, y)
        return cb
    end

    Heading(p, "When to show the counts", 0, 0)
    Check("Show in combat", "inCombat", 0, -22)
    Check("Show out of combat", "outOfCombat", 0, -50)
    local notFull = Check("Only when my mana isn't full", "oocOnlyNotFull", 26, -76)
    Check("Show while the mouse is over the button (even when the options above hide it)", "onHover", 0, -108)
    Refresher(function() notFull:SetActive(S().outOfCombat) end)

    Heading(p, "Spells", 0, -150)
    Check("Count spells cast by macros", "macros", 0, -172)

    local reset = UI.Button(p, "Reset visibility settings", 180, 22, function()
        CC.ResetSection("show")
        Changed()
        UI.RefreshAll()
    end)
    reset:SetPoint("TOPLEFT", 0, -220)

    Note(p, "Tip: untick both combat options and keep the mouse-over option ticked to see counts only when you hover a button.", 0, -370)
end

---------------------------------------------------------
--  SECTION: Rules tab
---------------------------------------------------------
local MAX_RULES = 5
local NO_COLOR = Color(1, 1, 1)

function builders.rules(p)
    local function F() return CC.db.free end
    local function R() return CC.db.rules end

    Heading(p, "Free spells", 0, 0)
    local label = UI.Text(p, "When a spell costs no mana:")
    label:SetPoint("TOPLEFT", 0, -26)
    local mode = UI.Dropdown(p, 150, function()
        return {
            { value = "hide", label = "Show nothing" },
            { value = "text", label = "Show text" },
        }
    end, function() return F().mode end, function(v) F().mode = v; Changed() end)
    mode:SetPoint("TOPLEFT", 190, -21)
    local freeText = UI.Edit(p, 80, false, function() return F().text end,
        function(v) F().text = v; Changed() end)
    freeText:SetPoint("TOPLEFT", 356, -22)
    local freeColor = UI.Swatch(p, function() return F().color end, Changed)
    freeColor:SetPoint("TOPLEFT", 446, -20)
    Refresher(function()
        local on = F().mode == "text"
        freeText:SetActive(on)
        freeColor:SetActive(on)
    end)

    Heading(p, "Low count colours", 0, -66)
    local enabled = UI.Check(p, "Change the colour when casts run low",
        function() return R().enabled end, function(v) R().enabled = v; Changed() end)
    enabled:SetPoint("TOPLEFT", 0, -86)

    local rows = {}
    for i = 1, MAX_RULES do
        local row = CreateFrame("Frame", nil, p)
        row:SetSize(400, 26)
        row:SetPoint("TOPLEFT", 26, -116 - (i - 1) * 30)
        local at = UI.Text(row, "At")
        at:SetPoint("LEFT", 0, 0)
        local num = UI.Edit(row, 36, true, function()
            local rule = R().list[i]
            return rule and rule.at or 0
        end, function(v)
            local rule = R().list[i]
            if rule then rule.at = v; Changed() end
        end)
        num:SetPoint("LEFT", at, "RIGHT", 10, 0)
        local fewer = UI.Text(row, "casts or fewer")
        fewer:SetPoint("LEFT", num, "RIGHT", 6, 0)
        local sw = UI.Swatch(row, function()
            local rule = R().list[i]
            return rule and rule.color or NO_COLOR
        end, Changed)
        sw:SetPoint("LEFT", fewer, "RIGHT", 10, 0)
        local remove = UI.Button(row, "Remove", 70, 20, function()
            table.remove(R().list, i)
            Changed()
            UI.RefreshAll()
        end)
        remove:SetPoint("LEFT", sw, "RIGHT", 10, 0)
        rows[i] = row
    end

    local add = UI.Button(p, "Add a rule", 110, 22, function()
        local list = R().list
        if #list >= MAX_RULES then return end
        local top = 0
        for _, rule in ipairs(list) do top = math.max(top, rule.at) end
        list[#list + 1] = { at = top + 3, color = Color(1, 1, 0) }
        Changed()
        UI.RefreshAll()
    end)
    add:SetPoint("TOPLEFT", 26, -116 - MAX_RULES * 30 - 4)

    Refresher(function()
        local n = #R().list
        for i, row in ipairs(rows) do row:SetShown(i <= n) end
        add:SetEnabled(n < MAX_RULES)
    end)

    local reset = UI.Button(p, "Reset rules", 120, 22, function()
        CC.ResetSection("free")
        CC.ResetSection("rules")
        Changed()
        UI.RefreshAll()
    end)
    reset:SetPoint("TOPLEFT", 0, -310)

    Note(p, "The lowest rule a count falls under wins. Counts above every rule use the normal colour from the Text tab.", 0, -370)

    -- Show the rules lowest first whenever the tab opens.
    p:SetScript("OnShow", function()
        table.sort(R().list, function(a, b) return a.at < b.at end)
        UI.RefreshAll()
    end)
end

---------------------------------------------------------
--  SECTION: Window
---------------------------------------------------------
local function ShowTab(key)
    current = key
    for k, b in pairs(tabButtons) do b:SetSelectedLook(k == key) end
    for k, p in pairs(pages) do p:SetShown(k == key) end
    UI.CloseMenu()
    CC.preview = PREVIEW[key] or false
    CC.pickingPaused = nil
    if key == "buttons" then
        if not CC.StartPicking() then CC.pickingPaused = true end
    else
        CC.StopPicking()
    end
    UI.RefreshAll()
    CC.MarkDirty()
end

local function TabButton(parent, label, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(112, 24)
    UI.Backdrop(b, 0.1, 0.1, 0.11, 1)
    b.text = UI.Text(b, label, "GameFontNormal")
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    b:SetScript("OnClick", onClick)
    function b:SetSelectedLook(on)
        if on then
            self:SetBackdropColor(0.22, 0.18, 0.04, 1)
            self:SetBackdropBorderColor(1, 0.82, 0, 1)
            self.text:SetTextColor(1, 0.82, 0)
        else
            self:SetBackdropColor(0.1, 0.1, 0.11, 1)
            self:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
            self.text:SetTextColor(0.85, 0.85, 0.85)
        end
    end
    return b
end

local function Build()
    win = CreateFrame("Frame", "CastCountConfig", UIParent, "BackdropTemplate")
    win:SetSize(W, H)
    win:SetPoint("TOP", UIParent, "TOP", 0, -60)
    win:SetFrameStrata("HIGH")
    win:SetToplevel(true)
    UI.Backdrop(win, 0.05, 0.05, 0.06, 0.97)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    tinsert(UISpecialFrames, "CastCountConfig")

    local title = UI.Text(win, "CastCount", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    local ver = UI.Text(win, "v" .. Version(), "GameFontDisableSmall")
    ver:SetPoint("LEFT", title, "RIGHT", 6, -1)
    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    for i, tab in ipairs(TABS) do
        local b = TabButton(win, tab.label, function() ShowTab(tab.key) end)
        b:SetPoint("TOPLEFT", 14 + (i - 1) * 118, -40)
        tabButtons[tab.key] = b

        local page = CreateFrame("Frame", nil, win)
        page:SetPoint("TOPLEFT", 14, -78)
        page:SetPoint("BOTTOMRIGHT", -14, 14)
        page:Hide()
        pages[tab.key] = page
        builders[tab.key](page)
    end

    win:SetScript("OnShow", function() ShowTab(current) end)
    win:SetScript("OnHide", function()
        CC.StopPicking()
        CC.preview = false
        UI.CloseMenu()
        CC.MarkDirty()
    end)
end

function CC.ShowConfig()
    if not CC.db then return end
    if not win then Build() end
    if win:IsShown() then ShowTab(current) else win:Show() end
end

function CC.ToggleConfig()
    if win and win:IsShown() then win:Hide() else CC.ShowConfig() end
end

-- Combat closed the picker; reopen it if the Buttons tab is still up.
CC.On("PLAYER_REGEN_ENABLED", function()
    if CC.pickingPaused and win and win:IsShown() and current == "buttons" then
        CC.pickingPaused = nil
        CC.StartPicking()
    end
end)

-- The addon list button (top of the minimap) opens the window too.
function CastCount_OnCompartmentClick()
    CC.ToggleConfig()
end

---------------------------------------------------------
--  SECTION: Game settings entry
---------------------------------------------------------
CC.OnReady(function()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = CreateFrame("Frame")
    panel.name = "CastCount"
    local title = UI.Text(panel, "CastCount", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    local text = UI.Text(panel, "CastCount has its own settings window. You can also open it with /castcount.")
    text:SetPoint("TOPLEFT", 16, -46)
    local open = UI.Button(panel, "Open CastCount", 160, 24, function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        CC.ShowConfig()
    end)
    open:SetPoint("TOPLEFT", 16, -74)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "CastCount")
    Settings.RegisterAddOnCategory(category)
end)
