---------------------------------------------------------
--  CastCount - Config window
--  Author: Dranged
---------------------------------------------------------
-- /castcount opens it. Tabs: Buttons (the picker), Blacklist, Appearance, Visibility, Conditions.

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
    { key = "text",       label = "Appearance" },
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
    items[#items + 1] = { value = "fill", label = "ManaFill" }
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

local PREVIEW_LABELS = { normal = "Normal", low = "Low", oom = "Out of mana", free = "Free", fill = "ManaFill" }

-- A clickable mock action button showing a count in one look.
local function PreviewButton(parent, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    UI.Backdrop(b, 0, 0, 0, 1, 0, 0, 0, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.fill = CreateFrame("StatusBar", nil, b)
    b.fill:SetPoint("TOPLEFT", 2, -2)
    b.fill:SetPoint("BOTTOMRIGHT", -2, 2)
    b.fill:SetOrientation("VERTICAL")
    b.fill:SetFrameLevel(b:GetFrameLevel() + 1)
    b.fill:SetMinMaxValues(0, 1)
    b.fill:SetValue(0.6)
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
    local function L() return CC.db.looks[editing] or CC.db.looks.normal end
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

    local styleLabel = UI.Text(p, "Edit:", "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", 0, -4)
    local which = UI.Dropdown(p, 160, LookItems, function() return editing end, Select)
    which:SetPoint("TOPLEFT", 44, 0)
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
    local freeRow = CreateFrame("Frame", nil, p)
    freeRow:SetSize(440, 22)
    freeRow:SetPoint("TOPLEFT", 0, -30)
    local freeLabel = UI.Text(freeRow, "Show")
    freeLabel:SetPoint("LEFT", 0, 0)
    local freeText = UI.Edit(freeRow, 70, false, function() return CC.db.looks.free.text end,
        function(v) CC.db.looks.free.text = v; StyleChanged() end)
    freeText:SetPoint("LEFT", freeLabel, "RIGHT", 10, 0)
    local freeNote = UI.Text(freeRow, "when a mana spell is free right now (Clearcasting...)", "GameFontHighlightSmall")
    freeNote:SetPoint("LEFT", freeText, "RIGHT", 8, 0)
    local when = Note(p, "", 0, -34, 440)
    Refresher(function()
        lowRow:SetShown(editing == "low")
        freeRow:SetShown(editing == "free")
        when:SetShown(editing == "normal" or editing == "oom" or editing == "fill")
        copy:SetShown(editing ~= "normal" and editing ~= "fill")
        if editing == "normal" then
            when:SetText("Used when you have more casts left than the Low count look covers.")
        elseif editing == "fill" then
            when:SetText("While you can't afford a spell, its button fills from the bottom as your mana comes back.")
        else
            when:SetText("Used when you can't afford a single cast.")
        end
    end)

    local y0 = -64
    local lp = CreateFrame("Frame", nil, p)
    lp:SetAllPoints(p)
    Heading(lp, "Font", 0, y0)
    local font = UI.Dropdown(lp, 220, function()
        local items = {}
        for _, f in ipairs(CC.Fonts()) do items[#items + 1] = { value = f.name, label = f.name, font = f.path } end
        return items
    end, function() return L().font end, function(v) L().font = v; StyleChanged() end)
    font:SetPoint("TOPLEFT", 0, y0 - 20)

    local outline = UI.Dropdown(lp, 120, function()
        return {
            { value = "NONE",         label = "No outline" },
            { value = "OUTLINE",      label = "Outline" },
            { value = "THICKOUTLINE", label = "Thick outline" },
        }
    end, function() return L().outline end, function(v) L().outline = v; StyleChanged() end)
    outline:SetPoint("TOPLEFT", 230, y0 - 20)

    local shadow = UI.Check(lp, "Shadow", function() return L().shadow end,
        function(v) L().shadow = v; StyleChanged() end)
    shadow:SetPoint("TOPLEFT", 358, y0 - 19)

    local size = UI.Slider(lp, "Size", 8, 40, 1, 220, function() return L().size end,
        function(v) L().size = v; StyleChanged() end)
    size:SetPoint("TOPLEFT", 0, y0 - 56)

    Heading(lp, "Colour", 0, y0 - 104)
    local swatch = UI.Swatch(lp, function() return L().color end, StyleChanged)
    swatch:SetPoint("TOPLEFT", 0, y0 - 124)
    Note(lp, "Conditions can override it.", 30, y0 - 130, 300)

    Heading(lp, "Position on the button", 0, y0 - 164)
    local anchor = UI.Dropdown(lp, 160, function() return ANCHORS end,
        function() return L().anchor end, function(v) L().anchor = v; StyleChanged() end)
    anchor:SetPoint("TOPLEFT", 0, y0 - 184)

    -- 0, 0 is the chosen position itself; the arrows nudge 1 (Shift 5, Ctrl 10).
    local x = UI.Slider(lp, "X offset (left - / right +)", -50, 50, 1, 216, function() return L().x end,
        function(v) L().x = v; StyleChanged() end, true)
    x:SetPoint("TOPLEFT", 0, y0 - 218)
    local y = UI.Slider(lp, "Y offset (down - / up +)", -50, 50, 1, 216, function() return L().y end,
        function(v) L().y = v; StyleChanged() end, true)
    y:SetPoint("TOPLEFT", 230, y0 - 218)
    Note(lp, "Arrows nudge by 1, Shift-click by 5, Ctrl-click by 10.", 0, y0 - 256, 440)

    local reset = UI.Button(lp, "Reset all looks", 140, 22, function()
        CC.ResetSection("looks")
        StyleChanged()
        UI.RefreshAll()
    end)
    reset:SetPoint("TOPLEFT", 0, y0 - 282)


    -- ManaFill settings, shown instead of the look settings when ManaFill is picked.
    local function FS() return CC.db.fill end
    local fp = CreateFrame("Frame", nil, p)
    fp:SetAllPoints(p)
    local fillOn = UI.Check(fp, "Show ManaFill", function() return FS().enabled end,
        function(v) FS().enabled = v; StyleChanged() end)
    fillOn:SetPoint("TOPLEFT", 0, y0)
    Note(fp, "Full means you have enough mana for one cast; the fill disappears as soon as you can cast it.", 0, y0 - 28, 440)
    Heading(fp, "Colour", 0, y0 - 56)
    local fillColor = UI.Swatch(fp, function() return FS().color end, StyleChanged)
    fillColor:SetPoint("TOPLEFT", 0, y0 - 76)
    Note(fp, "The colour picker's opacity sets how see-through the fill is.", 30, y0 - 82, 400)
    Heading(fp, "Texture", 0, y0 - 116)
    local fillTex = UI.Dropdown(fp, 220, function()
        local items = {}
        for _, t in ipairs(CC.BarTextures()) do items[#items + 1] = { value = t.name, label = t.name } end
        return items
    end, function() return FS().texture end, function(v) FS().texture = v; StyleChanged() end)
    fillTex:SetPoint("TOPLEFT", 0, y0 - 136)
    local fillReset = UI.Button(fp, "Reset ManaFill", 140, 22, function()
        CC.ResetSection("fill")
        StyleChanged()
        UI.RefreshAll()
    end)
    fillReset:SetPoint("TOPLEFT", 0, y0 - 180)
    Refresher(function()
        lp:SetShown(editing ~= "fill")
        fp:SetShown(editing == "fill")
    end)

    Note(p, "While this tab is open every selected button shows its count, so you can see your changes.", 0, -380)

    -- Preview, on the right: Normal big, Low count, Out of mana and Free smaller.
    -- Clicking one picks that look to edit.
    local box = CreateFrame("Frame", nil, p, "BackdropTemplate")
    box:SetSize(176, 340)
    box:SetPoint("TOPRIGHT", 0, 0)
    UI.Backdrop(box, 0.03, 0.03, 0.035, 0.9)
    local title = UI.Text(box, "Preview  (click to edit)", "GameFontNormal")
    title:SetPoint("TOP", 0, -8)
    title:SetJustifyH("CENTER")

    local previews = {}
    local previewKeys = { "normal", "low", "oom", "free", "fill" }
    for _, key in ipairs(previewKeys) do
        local b = PreviewButton(box, function() Select(key) end)
        b.label = UI.Text(box, "", "GameFontHighlightSmall")
        b.label:SetPoint("TOP", b, "BOTTOM", 0, -4)
        b.label:SetJustifyH("CENTER")
        previews[key] = b
    end

    UpdatePreview = function()
        if not box:IsVisible() then return end
        local icon, size = PreviewSource()
        local counts = {
            normal = math.max(12, CC.db.lowAt + 5), low = math.max(1, CC.db.lowAt), oom = 0,
            free = CC.db.looks.free.text,
        }
        local small = math.min(1, 46 / size)
        local layout = {
            normal = { scale = math.min(2, 120 / size), x = 88, y = 30 },
            low    = { scale = small, x = 32 },
            oom    = { scale = small, x = 88 },
            free   = { scale = small, x = 144 },
            fill   = { scale = small, x = 88 },
        }
        local bigH = size * layout.normal.scale
        local row2 = 30 + bigH + 34
        layout.fill.y = row2 + size * small + 30
        for _, key in ipairs(previewKeys) do
            local b, lay = previews[key], layout[key]
            local look = CC.db.looks[key] or CC.db.looks.oom
            b:SetScale(lay.scale)
            b:SetSize(size, size)
            b:ClearAllPoints()
            b:SetPoint("TOP", box, "TOPLEFT", lay.x / lay.scale, -(lay.y or row2) / lay.scale)
            b.icon:SetTexture(icon)
            CC.StyleFont(b.fs, look, b.holder)
            b.fs:SetText(key == "fill" and "" or counts[key])
            b.fs:SetTextColor(look.color.r, look.color.g, look.color.b, look.color.a or 1)
            CC.StyleFill(b.fill)
            b.fill:SetShown(CC.db.fill.enabled and (key == "oom" or key == "fill"))
            if key == editing then
                b:SetBackdropBorderColor(1, 0.82, 0, 1)
            else
                b:SetBackdropBorderColor(0, 0, 0, 1)
            end
            b.label:SetText(PREVIEW_LABELS[key])
            if key == "low" and CC.db.lowAt < 1 then b.label:SetText("Low (off)") end
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
-- WeakAuras-style condition cards in a scrolling list, as many as you like:
--   If <check> [and/or more checks]   Then <property change> [more changes]
-- Each card collapses, moves up/down, copies and deletes.
local SUBJECTS = {
    { value = "casts",  label = "Casts left" },
    { value = "mana",   label = "Mana %" },
    { value = "free",   label = "Spell is free right now" },
    { value = "combat", label = "In combat" },
    { value = "hover",  label = "Mouse is over the button" },
}
local IS_BOOL = { free = true, combat = true, hover = true }
local NUMBER_OPS = {
    { value = "<",  label = "<" },
    { value = "<=", label = "<=" },
    { value = "=",  label = "=" },
    { value = "!=", label = "!=" },
    { value = ">=", label = ">=" },
    { value = ">",  label = ">" },
}
local BOOL_OPS = {
    { value = "true",  label = "is true" },
    { value = "false", label = "is false" },
}
local PROPS = {
    { value = "textcolor", label = "Count colour" },
    { value = "alpha",     label = "Count transparency" },
    { value = "hide",      label = "Hide the count" },
    { value = "size",      label = "Count size" },
    { value = "offset",    label = "Move the count" },
    { value = "text",      label = "Replace the count with text" },
    { value = "pulse",     label = "Pulse the count" },
    { value = "glow",      label = "Glow the button" },
    { value = "tint",      label = "Tint the button" },
    { value = "sound",     label = "Play a sound" },
    { value = "chat",      label = "Chat message (only you)" },
}
local PROP_LABEL = {}
for _, pr in ipairs(PROPS) do PROP_LABEL[pr.value] = pr.label end
local SUBJECT_LABEL = {}
for _, s in ipairs(SUBJECTS) do SUBJECT_LABEL[s.value] = s.label end

local CARD_W, HEADER_H, ROW_H = 620, 28, 28

local function NewCheck() return { join = "and", subject = "casts", op = "<=", value = 1 } end
local JOINS = {
    { value = "and", label = "and" },
    { value = "or",  label = "or" },
}

local function NewProp(t)
    local pr = { type = t or "glow", color = Color(1, 0.82, 0), glowType = "button", sound = "raidwarning",
        value = 50, text = "", x = 0, y = 0 }
    if t == "size" then pr.value = 24 end
    if t == "tint" then pr.color = Color(1, 0, 0, 0.35) end
    if t == "textcolor" then pr.color = Color(1, 0.2, 0.2) end
    return pr
end

local function NewCondition()
    return { enabled = true, checks = { NewCheck() }, props = { NewProp("glow") } }
end

-- Keeps a check consistent after its subject changes.
local function FixCheck(ch)
    if IS_BOOL[ch.subject] then
        if ch.op ~= "true" and ch.op ~= "false" then ch.op = "true" end
    elseif ch.op == "true" or ch.op == "false" then
        ch.op = "<="
    end
end

local function DropFocus()
    local f = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if f then f:ClearFocus() end
end

local function SmallButton(parent, text, w, onClick)
    local b = UI.Button(parent, text, w, 20, onClick)
    return b
end

function builders.conditions(p)
    local sf, content = UI.ScrollArea(p)
    local function Conds() return CC.db.conditions end
    local cards = {}
    local add

    local function Rebuild()
        DropFocus()
        Changed()
        UI.RefreshAll()
    end

    Note(content, "Each condition checks your casts left (and a few other things) and changes how the count "
        .. "or button looks. They're applied top to bottom, so a lower condition wins when two change the same thing.",
        0, 0, 600)

    -- One check row: subject, operator, value.
    local function CheckRow(card, i)
        local row = CreateFrame("Frame", nil, card)
        row:SetSize(CARD_W - 30, ROW_H - 2)
        local function Ch() return row.item or NewCheck() end
        local function Set(field, v)
            if not row.item then return end
            row.item[field] = v
            FixCheck(row.item)
            Changed()
        end
        -- The first check reads "If", every later one says how it joins the ones before.
        row.ifText = UI.Text(row, "If", "GameFontNormal")
        row.ifText:SetPoint("LEFT", 8, 0)
        row.join = UI.Dropdown(row, 56, function() return JOINS end,
            function() return Ch().join or "and" end, function(v) Set("join", v); UI.RefreshAll() end)
        row.join:SetPoint("LEFT", 0, 0)
        local subject = UI.Dropdown(row, 190, function() return SUBJECTS end,
            function() return Ch().subject end, function(v) Set("subject", v) end)
        subject:SetPoint("LEFT", 62, 0)
        local op = UI.Dropdown(row, 80, function() return IS_BOOL[Ch().subject] and BOOL_OPS or NUMBER_OPS end,
            function() return Ch().op end, function(v) Set("op", v) end)
        op:SetPoint("LEFT", subject, "RIGHT", 6, 0)
        row.value = UI.Edit(row, 44, true, function() return Ch().value or 0 end, function(v) Set("value", v) end)
        row.value:SetPoint("LEFT", op, "RIGHT", 10, 0)
        row.unit = UI.Text(row, "")
        row.unit:SetPoint("LEFT", row.value, "RIGHT", 4, 0)
        row.remove = SmallButton(row, "X", 24, function()
            local list = card.cond and card.cond.checks
            if not list or #list < 2 then return end
            for idx, ch in ipairs(list) do
                if ch == row.item then table.remove(list, idx) break end
            end
            Rebuild()
        end)
        row.remove:SetPoint("LEFT", subject, "LEFT", 400, 0)
        return row
    end

    -- One property row: what to change, and its settings.
    local function PropRow(card, i)
        local row = CreateFrame("Frame", nil, card)
        row:SetSize(CARD_W - 30, ROW_H - 2)
        local function Pr() return row.item or NewProp() end
        local function Set(field, v)
            if not row.item then return end
            row.item[field] = v
            -- Sensible starting values when the kind of change switches.
            if field == "type" then
                local pr = row.item
                if v == "size" and ((pr.value or 0) < 6 or (pr.value or 0) > 60) then pr.value = 24 end
                if v == "alpha" and (pr.value or 0) > 100 then pr.value = 50 end
                if v == "tint" and pr.color and (pr.color.a or 1) > 0.6 then pr.color.a = 0.35 end
                if v ~= "tint" and pr.color and (pr.color.a or 1) < 0.3 then pr.color.a = 1 end
                UI.RefreshAll()
            end
            Changed()
        end
        local kind = UI.Dropdown(row, 200, function() return PROPS end,
            function() return Pr().type end, function(v) Set("type", v) end)
        kind:SetPoint("LEFT", 0, 0)
        local x0 = 210
        row.swatch = UI.Swatch(row, function() return Pr().color end, Changed)
        row.number = UI.Edit(row, 44, true, function() return Pr().value or 0 end, function(v) Set("value", v) end)
        row.numberUnit = UI.Text(row, "")
        row.numberUnit:SetPoint("LEFT", row.number, "RIGHT", 4, 0)
        row.text = UI.Edit(row, 150, false, function() return Pr().text or "" end, function(v) Set("text", v) end)
        row.xLabel = UI.Text(row, "X")
        row.x = UI.Edit(row, 44, "signed", function() return Pr().x or 0 end, function(v) Set("x", v) end)
        row.yLabel = UI.Text(row, "Y")
        row.y = UI.Edit(row, 44, "signed", function() return Pr().y or 0 end, function(v) Set("y", v) end)
        row.glowType = UI.Dropdown(row, 150, function() return CC.GLOW_TYPES end,
            function() return Pr().glowType end, function(v) Set("glowType", v) end)
        row.sound = UI.Dropdown(row, 160, CC.SoundItems,
            function() return Pr().sound end, function(v) Set("sound", v); CC.PlaySound(v) end)
        row.test = SmallButton(row, "Test", 44, function() CC.PlaySound(Pr().sound) end)

        row.swatch:SetPoint("LEFT", x0, 0)
        row.number:SetPoint("LEFT", x0 + 6, 0)
        row.text:SetPoint("LEFT", x0 + 6, 0)
        row.xLabel:SetPoint("LEFT", x0, 0)
        row.x:SetPoint("LEFT", row.xLabel, "RIGHT", 8, 0)
        row.yLabel:SetPoint("LEFT", row.x, "RIGHT", 10, 0)
        row.y:SetPoint("LEFT", row.yLabel, "RIGHT", 8, 0)
        row.glowType:SetPoint("LEFT", x0, 0)
        row.sound:SetPoint("LEFT", x0, 0)
        row.test:SetPoint("LEFT", row.sound, "RIGHT", 6, 0)

        row.remove = SmallButton(row, "X", 24, function()
            local list = card.cond and card.cond.props
            if not list then return end
            for idx, pr in ipairs(list) do
                if pr == row.item then table.remove(list, idx) break end
            end
            Rebuild()
        end)
        row.remove:SetPoint("LEFT", 420, 0)

        function row:ShowFor(pr)
            local t = pr.type
            self.swatch:SetShown(t == "textcolor" or t == "tint" or t == "glow")
            self.swatch:ClearAllPoints()
            if t == "glow" then
                self.swatch:SetPoint("LEFT", self.glowType, "RIGHT", 8, 0)
            else
                self.swatch:SetPoint("LEFT", x0, 0)
            end
            self.number:SetShown(t == "alpha" or t == "size")
            self.numberUnit:SetShown(t == "alpha" or t == "size")
            self.numberUnit:SetText(t == "alpha" and "% visible" or "pt")
            self.text:SetShown(t == "text" or t == "chat")
            self.text:SetWidth(t == "chat" and 200 or 120)
            self.xLabel:SetShown(t == "offset")
            self.x:SetShown(t == "offset")
            self.yLabel:SetShown(t == "offset")
            self.y:SetShown(t == "offset")
            self.glowType:SetShown(t == "glow")
            self.sound:SetShown(t == "sound")
            self.test:SetShown(t == "sound")
        end
        return row
    end

    local function Card(i)
        local card = CreateFrame("Frame", nil, content, "BackdropTemplate")
        card:SetWidth(CARD_W)
        UI.Backdrop(card, 0.08, 0.08, 0.09, 0.95)
        card.checkRows, card.propRows = {}, {}

        card.toggle = CreateFrame("Button", nil, card)
        card.toggle:SetSize(16, 16)
        card.toggle:SetPoint("TOPLEFT", 6, -6)
        card.toggle:SetScript("OnClick", function()
            if card.cond then card.cond.collapsed = not card.cond.collapsed end
            Rebuild()
        end)
        card.enabled = UI.Check(card, "", function() return card.cond and card.cond.enabled end,
            function(v) if card.cond then card.cond.enabled = v; Changed() end end)
        card.enabled:SetPoint("TOPLEFT", 26, -2)
        card.title = UI.Text(card, "", "GameFontNormal")
        card.title:SetPoint("TOPLEFT", 54, -8)
        card.title:SetWidth(390)
        card.title:SetWordWrap(false)

        local function Move(dir)
            local list = Conds()
            for idx, c in ipairs(list) do
                if c == card.cond then
                    local to = idx + dir
                    if to >= 1 and to <= #list then list[idx], list[to] = list[to], list[idx] end
                    break
                end
            end
            Rebuild()
        end
        card.delete = SmallButton(card, "X", 24, function()
            for idx, c in ipairs(Conds()) do
                if c == card.cond then table.remove(Conds(), idx) break end
            end
            Rebuild()
        end)
        card.delete:SetPoint("TOPRIGHT", -6, -4)
        card.copy = SmallButton(card, "Copy", 46, function()
            for idx, c in ipairs(Conds()) do
                if c == card.cond then table.insert(Conds(), idx + 1, CC.CopyDeep(c)) break end
            end
            Rebuild()
        end)
        card.copy:SetPoint("RIGHT", card.delete, "LEFT", -4, 0)
        card.down = SmallButton(card, "Down", 46, function() Move(1) end)
        card.down:SetPoint("RIGHT", card.copy, "LEFT", -4, 0)
        card.up = SmallButton(card, "Up", 36, function() Move(-1) end)
        card.up:SetPoint("RIGHT", card.down, "LEFT", -4, 0)

        card.nameLabel = UI.Text(card, "Name", "GameFontNormal")
        card.nameEdit = UI.Edit(card, 220, false, function() return card.cond and card.cond.name or "" end,
            function(v) if card.cond then card.cond.name = (v ~= "") and v or nil; UI.RefreshAll() end end)
        card.nameEdit.allowEmpty = true
        card.nameNote = UI.Text(card, "optional", "GameFontDisableSmall")
        card.logicNote = UI.Text(card, "\"and\" is checked before \"or\": A or B and C means A, or both B and C.",
            "GameFontHighlightSmall")
        card.logicNote:SetTextColor(0.75, 0.75, 0.75)
        card.addCheck = SmallButton(card, "+ Add check", 100, function()
            if card.cond then table.insert(card.cond.checks, NewCheck()) end
            Rebuild()
        end)
        card.thenLabel = UI.Text(card, "Then", "GameFontNormal")
        card.addProp = SmallButton(card, "+ Add property change", 160, function()
            if card.cond then table.insert(card.cond.props, NewProp("textcolor")) end
            Rebuild()
        end)
        card.warn = UI.Text(card, "Sounds and chat messages only work when every check is one CastCount can see "
            .. "(Spell is free, In combat, Mouse over): Forever hides your mana.", "GameFontHighlightSmall")
        card.warn:SetWidth(CARD_W - 90)
        card.warn:SetTextColor(1, 0.5, 0.3)

        -- Lays the card out for its condition and returns its height.
        function card:Layout(index)
            local c = self.cond
            self.title:SetText((c.name and c.name ~= "") and c.name or ("Condition " .. index))
            self.toggle:SetNormalTexture(c.collapsed and "Interface\\Buttons\\UI-PlusButton-Up"
                or "Interface\\Buttons\\UI-MinusButton-Up")
            self.up:SetEnabled(index > 1)
            self.down:SetEnabled(index < #Conds())
            local open = not c.collapsed
            for _, w in ipairs({ self.nameLabel, self.nameEdit, self.nameNote, self.logicNote, self.addCheck,
                self.thenLabel, self.addProp, self.warn }) do
                w:SetShown(open)
            end
            for _, r in ipairs(self.checkRows) do r:Hide() end
            for _, r in ipairs(self.propRows) do r:Hide() end
            if not open then return HEADER_H + 4 end

            local y = -HEADER_H - 4
            self.nameLabel:ClearAllPoints()
            self.nameLabel:SetPoint("TOPLEFT", 10, y - 4)
            self.nameEdit:ClearAllPoints()
            self.nameEdit:SetPoint("TOPLEFT", 58, y)
            self.nameNote:ClearAllPoints()
            self.nameNote:SetPoint("LEFT", self.nameEdit, "RIGHT", 8, 0)
            y = y - 30
            local hasAnd, hasOr = false, false
            for ci, ch in ipairs(c.checks) do
                local r = self.checkRows[ci] or CheckRow(self, ci)
                self.checkRows[ci] = r
                r.item = ch
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 10, y)
                r.ifText:SetShown(ci == 1)
                r.join:SetShown(ci > 1)
                if ci > 1 then
                    if ch.join == "or" then hasOr = true else hasAnd = true end
                end
                local numeric = not IS_BOOL[ch.subject]
                r.value:SetShown(numeric)
                r.unit:SetShown(numeric)
                r.unit:SetText(ch.subject == "mana" and "%" or (ch.subject == "casts" and "casts" or ""))
                r.remove:SetShown(#c.checks > 1)
                r:Show()
                y = y - ROW_H
            end
            local mixed = hasAnd and hasOr
            self.logicNote:SetShown(mixed)
            if mixed then
                self.logicNote:ClearAllPoints()
                self.logicNote:SetPoint("TOPLEFT", 72, y - 2)
                y = y - 18
            end
            self.addCheck:ClearAllPoints()
            self.addCheck:SetPoint("TOPLEFT", 72, y)
            y = y - 28

            self.thenLabel:ClearAllPoints()
            self.thenLabel:SetPoint("TOPLEFT", 10, y - 4)
            local needsLua = false
            for pi, pr in ipairs(c.props) do
                local r = self.propRows[pi] or PropRow(self, pi)
                self.propRows[pi] = r
                r.item = pr
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 72, y)
                r:ShowFor(pr)
                r:Show()
                if pr.type == "sound" or pr.type == "chat" then needsLua = true end
                y = y - ROW_H
            end
            if #c.props == 0 then y = y - 4 end
            local warn = needsLua and not CC.CondIsLuaKnown(c)
            self.warn:SetShown(warn)
            if warn then
                self.warn:ClearAllPoints()
                self.warn:SetPoint("TOPLEFT", 72, y - 2)
                y = y - 30
            end
            self.addProp:ClearAllPoints()
            self.addProp:SetPoint("TOPLEFT", 72, y)
            y = y - 30
            return -y + 4
        end
        cards[i] = card
        return card
    end

    add = UI.Button(content, "Add a condition", 140, 22, function()
        local list = Conds()
        for _, c in ipairs(list) do c.collapsed = true end
        list[#list + 1] = NewCondition()
        Rebuild()
        sf:ScrollToBottom()
    end)

    Refresher(function()
        local list = Conds()
        local y = -40
        for i, c in ipairs(list) do
            local card = cards[i] or Card(i)
            card.cond = c
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", 0, y)
            card:SetHeight(card:Layout(i))
            card:Show()
            y = y - card:GetHeight() - 8
        end
        for i = #list + 1, #cards do
            cards[i].cond = nil
            cards[i]:Hide()
        end
        add:ClearAllPoints()
        add:SetPoint("TOPLEFT", 0, y - 4)
        sf:SetContentHeight(-y + 40)
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
