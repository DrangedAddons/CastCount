---------------------------------------------------------
--  CastCount - Config window
--  Author: Dranged
---------------------------------------------------------
-- /castcount opens it. Tabs: Buttons (the picker), Blacklist, Text, Visibility, Conditions.

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
    { key = "conditions", label = "Conditions" },
}
-- Tabs where every selected count shows, whatever the visibility settings say.
local PREVIEW = { blacklist = true, text = true, conditions = true }

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

    local addAll = UI.Button(p, "Add every button on screen", 210, 24, function() CC.SelectAllVisible() end)
    addAll:SetPoint("TOPLEFT", 0, y - 16)
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

local function LookItems()
    local items = {}
    for _, key in ipairs(CC.LOOKS) do items[#items + 1] = { value = key, label = CC.LOOK_LABELS[key] } end
    return items
end

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

-- A clickable mock action button showing a count in one look.
local function PreviewButton(parent, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    UI.Backdrop(b, 0, 0, 0, 1, 0, 0, 0, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.holder = CreateFrame("Frame", nil, b)
    b.holder:SetAllPoints(b)
    b.holder:SetFrameLevel(b:GetFrameLevel() + 2)
    b.fs = b.holder:CreateFontString(nil, "OVERLAY")
    b:SetHighlightTexture(UI.WHITE)
    local hl = b:GetHighlightTexture()
    hl:SetVertexColor(1, 1, 1)
    hl:SetAlpha(0.12)
    b:SetScript("OnClick", onClick)
    return b
end

function builders.text(p)
    local editing = "normal"
    local function L() return CC.db.looks[editing] end
    local UpdatePreview
    -- Restyle the real buttons and the preview together.
    local function StyleChanged()
        CC.ApplyStyle()
        if UpdatePreview then UpdatePreview() end
    end
    local function Select(key)
        editing = key
        UI.RefreshAll()
    end

    local styleLabel = UI.Text(p, "Style for:", "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", 0, -4)
    local which = UI.Dropdown(p, 160, LookItems, function() return editing end, Select)
    which:SetPoint("TOPLEFT", 74, 0)
    local copy = UI.Button(p, "Copy from Normal", 140, 22, function()
        local color = L().color
        CC.db.looks[editing] = CC.CopyDeep(CC.db.looks.normal)
        CC.db.looks[editing].color = color
        StyleChanged()
        UI.RefreshAll()
    end)
    copy:SetPoint("LEFT", which, "RIGHT", 10, 0)

    -- When each look applies.
    local lowRow = CreateFrame("Frame", nil, p)
    lowRow:SetSize(400, 22)
    lowRow:SetPoint("TOPLEFT", 0, -30)
    local lowText = UI.Text(lowRow, "Use this look from 1 up to")
    lowText:SetPoint("LEFT", 0, 0)
    local lowAt = UI.Edit(lowRow, 36, true, function() return CC.db.lowAt end,
        function(v) CC.db.lowAt = v; StyleChanged() end)
    lowAt:SetPoint("LEFT", lowText, "RIGHT", 10, 0)
    local lowText2 = UI.Text(lowRow, "casts left (0 turns it off)")
    lowText2:SetPoint("LEFT", lowAt, "RIGHT", 6, 0)
    local when = Note(p, "", 0, -34, 440)
    Refresher(function()
        lowRow:SetShown(editing == "low")
        when:SetShown(editing ~= "low")
        copy:SetShown(editing ~= "normal")
        if editing == "normal" then
            when:SetText("Used when you have more casts left than the Low count look covers.")
        else
            when:SetText("Used when you can't afford a single cast.")
        end
    end)

    local y0 = -64
    Heading(p, "Font", 0, y0)
    local font = UI.Dropdown(p, 220, function()
        local items = {}
        for _, f in ipairs(CC.Fonts()) do items[#items + 1] = { value = f.name, label = f.name, font = f.path } end
        return items
    end, function() return L().font end, function(v) L().font = v; StyleChanged() end)
    font:SetPoint("TOPLEFT", 0, y0 - 20)

    local outline = UI.Dropdown(p, 120, function()
        return {
            { value = "NONE",         label = "No outline" },
            { value = "OUTLINE",      label = "Outline" },
            { value = "THICKOUTLINE", label = "Thick outline" },
        }
    end, function() return L().outline end, function(v) L().outline = v; StyleChanged() end)
    outline:SetPoint("TOPLEFT", 230, y0 - 20)

    local shadow = UI.Check(p, "Shadow", function() return L().shadow end,
        function(v) L().shadow = v; StyleChanged() end)
    shadow:SetPoint("TOPLEFT", 358, y0 - 19)

    local size = UI.Slider(p, "Size", 8, 40, 1, 220, function() return L().size end,
        function(v) L().size = v; StyleChanged() end)
    size:SetPoint("TOPLEFT", 0, y0 - 56)

    Heading(p, "Colour", 0, y0 - 104)
    local swatch = UI.Swatch(p, function() return L().color end, StyleChanged)
    swatch:SetPoint("TOPLEFT", 0, y0 - 124)
    Note(p, "Conditions can override it.", 30, y0 - 130, 300)

    Heading(p, "Position on the button", 0, y0 - 164)
    local anchor = UI.Dropdown(p, 160, function() return ANCHORS end,
        function() return L().anchor end, function(v) L().anchor = v; StyleChanged() end)
    anchor:SetPoint("TOPLEFT", 0, y0 - 184)

    local x = UI.Slider(p, "Nudge left / right", -30, 30, 1, 210, function() return L().x end,
        function(v) L().x = v; StyleChanged() end)
    x:SetPoint("TOPLEFT", 0, y0 - 218)
    local y = UI.Slider(p, "Nudge down / up", -30, 30, 1, 210, function() return L().y end,
        function(v) L().y = v; StyleChanged() end)
    y:SetPoint("TOPLEFT", 230, y0 - 218)

    local reset = UI.Button(p, "Reset all looks", 140, 22, function()
        CC.ResetSection("looks")
        StyleChanged()
        UI.RefreshAll()
    end)
    reset:SetPoint("TOPLEFT", 0, y0 - 282)

    Note(p, "While this tab is open every selected button shows its count, so you can see your changes.", 0, -380)

    -- Preview, on the right: Normal big, Low count and Out of mana smaller.
    -- Clicking one picks that look to edit.
    local box = CreateFrame("Frame", nil, p, "BackdropTemplate")
    box:SetSize(176, 320)
    box:SetPoint("TOPRIGHT", 0, 0)
    UI.Backdrop(box, 0.03, 0.03, 0.035, 0.9)
    local title = UI.Text(box, "Preview  (click to edit)", "GameFontNormal")
    title:SetPoint("TOP", 0, -8)
    title:SetJustifyH("CENTER")

    local previews = {}
    for _, key in ipairs(CC.LOOKS) do
        local b = PreviewButton(box, function() Select(key) end)
        b.label = UI.Text(box, "", "GameFontHighlightSmall")
        b.label:SetPoint("TOP", b, "BOTTOM", 0, -4)
        b.label:SetJustifyH("CENTER")
        previews[key] = b
    end

    UpdatePreview = function()
        if not box:IsVisible() then return end
        local icon, size = PreviewSource()
        local counts = { normal = math.max(12, CC.db.lowAt + 5), low = math.max(1, CC.db.lowAt), oom = 0 }
        local layout = {
            normal = { scale = math.min(2, 120 / size), x = 88, y = 30 },
            low    = { scale = math.min(1, 60 / size), x = 46 },
            oom    = { scale = math.min(1, 60 / size), x = 130 },
        }
        local bigH = size * layout.normal.scale
        for _, key in ipairs(CC.LOOKS) do
            local b, lay, look = previews[key], layout[key], CC.db.looks[key]
            b:SetScale(lay.scale)
            b:SetSize(size, size)
            b:ClearAllPoints()
            b:SetPoint("TOP", box, "TOPLEFT", lay.x / lay.scale, -(lay.y or (30 + bigH + 34)) / lay.scale)
            b.icon:SetTexture(icon)
            CC.StyleFont(b.fs, look, b.holder)
            b.fs:SetText(counts[key])
            b.fs:SetTextColor(look.color.r, look.color.g, look.color.b, look.color.a or 1)
            if key == editing then
                b:SetBackdropBorderColor(1, 0.82, 0, 1)
            else
                b:SetBackdropBorderColor(0, 0, 0, 1)
            end
            b.label:SetText(CC.LOOK_LABELS[key])
            if key == "low" and CC.db.lowAt < 1 then b.label:SetText("Low count (off)") end
            b.label:SetTextColor(key == editing and 1 or 0.8, key == editing and 0.82 or 0.8, key == editing and 0 or 0.8)
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
--  SECTION: Conditions tab
---------------------------------------------------------
-- A scrolling list of "If <subject> <op> <value> then <action>" rows, as many as you like.
local SUBJECTS = {
    { value = "casts",  label = "Casts left" },
    { value = "mana",   label = "Mana %" },
    { value = "combat", label = "In combat" },
    { value = "free",   label = "Spell costs no mana" },
}
local NUMBER_OPS = {
    { value = "lt", label = "is below" },
    { value = "le", label = "is at most" },
    { value = "eq", label = "is" },
    { value = "ne", label = "is not" },
    { value = "ge", label = "is at least" },
    { value = "gt", label = "is above" },
}
local BOOL_OPS = {
    { value = "is",    label = "is true" },
    { value = "isnot", label = "is false" },
}
local ACTIONS = {
    { value = "color", label = "Change count colour" },
    { value = "hide",  label = "Hide the count" },
    { value = "glow",  label = "Glow the button" },
    { value = "pulse", label = "Pulse the count" },
    { value = "sound", label = "Play a sound" },
}
local ROW_H = 62

local function IsBool(subject) return subject == "combat" or subject == "free" end

local function NewCondition()
    return {
        enabled = true, subject = "casts", op = "le", value = 1,
        action = "glow", color = Color(1, 0.82, 0), sound = "raidwarning",
    }
end

-- Keeps a condition consistent after its subject changes.
local function FixCondition(c)
    if IsBool(c.subject) then
        if c.op ~= "is" and c.op ~= "isnot" then c.op = "is" end
    elseif c.op == "is" or c.op == "isnot" then
        c.op = "le"
    end
    if c.action == "sound" and not CC.CondIsLuaKnown(c) then c.action = "color" end
end

local function DropFocus()
    local f = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if f then f:ClearFocus() end
end

function builders.conditions(p)
    local sf, content = UI.ScrollArea(p)
    local function Conds() return CC.db.conditions end

    -- Free spells
    local function F() return CC.db.free end
    Heading(content, "Free spells", 0, 0)
    local freeLabel = UI.Text(content, "When a spell costs no mana:")
    freeLabel:SetPoint("TOPLEFT", 0, -26)
    local mode = UI.Dropdown(content, 150, function()
        return {
            { value = "hide", label = "Show nothing" },
            { value = "text", label = "Show text" },
        }
    end, function() return F().mode end, function(v) F().mode = v; Changed() end)
    mode:SetPoint("TOPLEFT", 190, -21)
    local freeText = UI.Edit(content, 80, false, function() return F().text end,
        function(v) F().text = v; Changed() end)
    freeText:SetPoint("TOPLEFT", 356, -22)
    local freeColor = UI.Swatch(content, function() return F().color end, Changed)
    freeColor:SetPoint("TOPLEFT", 446, -20)
    Refresher(function()
        local on = F().mode == "text"
        freeText:SetActive(on)
        freeColor:SetActive(on)
    end)

    Heading(content, "Conditions", 0, -64)
    Note(content, "Checked top to bottom; when two change the colour, the lower one wins. "
        .. "Sounds can only follow In combat and Spell costs no mana: Forever hides your current mana from addons.", 0, -84, 600)

    local rows = {}
    local add

    local function Layout()
        local list = Conds()
        for i, row in ipairs(rows) do
            row.cond = list[i]
            row:SetShown(row.cond ~= nil)
        end
        add:ClearAllPoints()
        add:SetPoint("TOPLEFT", 0, -124 - #list * ROW_H)
        sf:SetContentHeight(124 + #list * ROW_H + 40)
    end

    local function NewRow(i)
        local row = CreateFrame("Frame", nil, content, "BackdropTemplate")
        row:SetSize(620, ROW_H - 6)
        row:SetPoint("TOPLEFT", 0, -118 - (i - 1) * ROW_H)
        UI.Backdrop(row, 0.08, 0.08, 0.09, 0.9)
        local function C() return row.cond or NewCondition() end
        local function Set(field, v)
            if not row.cond then return end
            row.cond[field] = v
            FixCondition(row.cond)
            Changed()
        end

        local en = UI.Check(row, "If", function() return C().enabled end, function(v) Set("enabled", v) end)
        en:SetPoint("TOPLEFT", 4, -4)
        local subject = UI.Dropdown(row, 150, function() return SUBJECTS end,
            function() return C().subject end, function(v) Set("subject", v) end)
        subject:SetPoint("TOPLEFT", 50, -5)
        local op = UI.Dropdown(row, 110, function() return IsBool(C().subject) and BOOL_OPS or NUMBER_OPS end,
            function() return C().op end, function(v) Set("op", v) end)
        op:SetPoint("LEFT", subject, "RIGHT", 6, 0)
        local value = UI.Edit(row, 40, true, function() return C().value or 0 end,
            function(v) Set("value", v) end)
        value:SetPoint("LEFT", op, "RIGHT", 10, 0)
        local unit = UI.Text(row, "")
        unit:SetPoint("LEFT", value, "RIGHT", 4, 0)

        local thenText = UI.Text(row, "then")
        thenText:SetPoint("TOPLEFT", 30, -36)
        local action = UI.Dropdown(row, 170, function()
            local items = {}
            for _, a in ipairs(ACTIONS) do
                if a.value ~= "sound" or CC.CondIsLuaKnown(C()) then items[#items + 1] = a end
            end
            return items
        end, function() return C().action end, function(v) Set("action", v) end)
        action:SetPoint("TOPLEFT", 66, -31)
        local swatch = UI.Swatch(row, function() return C().color end, Changed)
        swatch:SetPoint("LEFT", action, "RIGHT", 8, 0)
        local sound = UI.Dropdown(row, 150, CC.SoundItems,
            function() return C().sound end, function(v) Set("sound", v); CC.PlaySound(v) end)
        sound:SetPoint("LEFT", action, "RIGHT", 8, 0)
        local test = UI.Button(row, "Test", 50, 20, function() CC.PlaySound(C().sound) end)
        test:SetPoint("LEFT", sound, "RIGHT", 6, 0)

        local remove = UI.Button(row, "Remove", 70, 20, function()
            DropFocus()
            for idx, c in ipairs(Conds()) do
                if c == row.cond then table.remove(Conds(), idx) break end
            end
            Changed()
            UI.RefreshAll()
        end)
        remove:SetPoint("TOPRIGHT", -6, -6)

        Refresher(function()
            if not row.cond then return end
            local c = row.cond
            local numeric = not IsBool(c.subject)
            value:SetShown(numeric)
            unit:SetText(c.subject == "mana" and "%" or (c.subject == "casts" and "casts" or ""))
            unit:SetShown(numeric)
            swatch:SetShown(c.action == "color" or c.action == "glow")
            sound:SetShown(c.action == "sound")
            test:SetShown(c.action == "sound")
            row:SetAlpha(c.enabled and 1 or 0.6)
        end)
        rows[i] = row
        return row
    end

    add = UI.Button(content, "Add a condition", 140, 22, function()
        DropFocus()
        local list = Conds()
        list[#list + 1] = NewCondition()
        if not rows[#list] then NewRow(#list) end
        Changed()
        UI.RefreshAll()
        sf:ScrollToBottom()
    end)

    Refresher(function()
        for i = #rows + 1, #Conds() do NewRow(i) end
        Layout()
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
