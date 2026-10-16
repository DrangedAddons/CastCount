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
--  SECTION: Drawing
---------------------------------------------------------
-- Each selected button gets a holder frame (a child of the button, above its
-- cooldown swipe) with one text layer per look (Normal / Low count / Out of
-- mana), each as a still and a pulsing copy, plus one glow per glow condition.
-- All layers show the same text; which are visible (and their colours) is
-- worked out per refresh, or by the game through curves when mana is secret.
local holders = {}   -- button -> holder
local hovered = {}   -- button -> true while the mouse is over it
local LOOKS = CC.LOOKS
local GLOW_TEX = "Interface\\Buttons\\UI-ActionButton-Border"

-- Applies a look (font, size, outline, shadow, position) to a font string.
function CC.StyleFont(fs, look, anchorTo, fontPath)
    local flags = (look.outline ~= "NONE") and look.outline or ""
    fs:SetFont(fontPath or CC.FontPath(look.font), look.size, flags)
    if not fs:GetFont() then fs:SetFont(CC.DEFAULT_FONT, look.size, flags) end
    if look.shadow then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
    fs:ClearAllPoints()
    fs:SetPoint(look.anchor, anchorTo, look.anchor, look.x, look.y)
end

local function NewLayer(h, pulse)
    local f = CreateFrame("Frame", nil, h)
    f:SetAllPoints(h)
    f:SetFrameLevel(h:GetFrameLevel() + 2)
    f.fs = f:CreateFontString(nil, "OVERLAY")
    if pulse then
        local ag = f:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")
        local sc = ag:CreateAnimation("Scale")
        if sc.SetScaleTo then
            sc:SetScaleFrom(1, 1)
            sc:SetScaleTo(1.35, 1.35)
        else
            sc:SetScale(1.35, 1.35)
        end
        sc:SetOrigin("CENTER", 0, 0)
        sc:SetDuration(0.45)
        sc:SetSmoothing("IN_OUT")
        f:SetScript("OnShow", function() ag:Play() end)
        ag:Play()
    end
    f:SetAlpha(0)
    return f
end

local function StyleHolder(h, paths)
    for _, key in ipairs(LOOKS) do
        local look, L = CC.db.looks[key], h.layers[key]
        CC.StyleFont(L.still.fs, look, L.still, paths and paths[key])
        CC.StyleFont(L.pulse.fs, look, L.pulse, paths and paths[key])
    end
end

local function Holder(btn)
    local h = holders[btn]
    if not h then
        h = CreateFrame("Frame", nil, btn)
        h:SetAllPoints(btn)
        h:SetFrameLevel(math.min(9990, btn:GetFrameLevel() + 10))
        h.layers = {}
        for _, key in ipairs(LOOKS) do
            h.layers[key] = { still = NewLayer(h, false), pulse = NewLayer(h, true) }
        end
        h.glows = {}
        holders[btn] = h
        StyleHolder(h)
        btn:HookScript("OnEnter", function() hovered[btn] = true; CC.MarkDirty() end)
        btn:HookScript("OnLeave", function() hovered[btn] = nil; CC.MarkDirty() end)
    end
    -- Keep above the button even if a bar addon re-levels it.
    local want = math.min(9990, btn:GetFrameLevel() + 10)
    if h:GetFrameLevel() < want then h:SetFrameLevel(want) end
    return h
end

local function Glow(h, i)
    local g = h.glows[i]
    if not g then
        g = CreateFrame("Frame", nil, h)
        g:SetAllPoints(h)
        g:SetFrameLevel(h:GetFrameLevel() + 1)
        g.tex = g:CreateTexture(nil, "OVERLAY")
        g.tex:SetTexture(GLOW_TEX)
        g.tex:SetBlendMode("ADD")
        g.tex:SetPoint("CENTER")
        h.glows[i] = g
    end
    local w = h:GetWidth()
    if w and w > 0 then g.tex:SetSize(w * 1.75, w * 1.75) end
    local c = CC.db.conditions[i] and CC.db.conditions[i].color
    if c then g.tex:SetVertexColor(c.r, c.g, c.b, c.a or 1) end
    return g
end

function CC.ApplyStyle()
    local paths = {}
    for _, key in ipairs(LOOKS) do paths[key] = CC.FontPath(CC.db.looks[key].font) end
    for _, h in pairs(holders) do StyleHolder(h, paths) end
    CC.MarkDirty()
end

local function SetAllText(h, text)
    for _, key in ipairs(LOOKS) do
        h.layers[key].still.fs:SetText(text)
        h.layers[key].pulse.fs:SetText(text)
    end
end

local function HideHolder(btn)
    local h = holders[btn]
    if h then h:Hide() end
end

---------------------------------------------------------
--  SECTION: Looks and conditions
---------------------------------------------------------
-- Does condition c hold? k = casts left (nil for a free spell), pct = mana %,
-- ctx = what's known in Lua (combat, free).
local function TestCond(c, k, pct, ctx)
    local s = c.subject
    if s == "combat" then return ctx.combat == (c.op ~= "isnot") end
    if s == "free" then return ctx.free == (c.op ~= "isnot") end
    local v
    if s == "casts" then
        if not k then return false end
        v = k
    elseif s == "mana" then
        if not pct then return false end
        v = math.floor(pct + 1e-9)
    else
        return false
    end
    local t, op = tonumber(c.value) or 0, c.op
    if op == "lt" then return v < t
    elseif op == "le" then return v <= t
    elseif op == "eq" then return v == t
    elseif op == "ne" then return v ~= t
    elseif op == "gt" then return v > t
    elseif op == "ge" then return v >= t
    end
    return false
end
CC.TestCond = TestCond

-- Conditions whose outcome CastCount can know in Lua even when mana is secret.
function CC.CondIsLuaKnown(c)
    return c.subject == "combat" or c.subject == "free"
end

-- What a button shows: which look, its colour, pulsing, hidden, and which glows.
local function StateAt(k, pct, ctx)
    local db = CC.db
    local st = { glows = {}, pulse = false }
    if ctx.free then
        st.look, st.color, st.hidden = "normal", db.free.color, db.free.mode ~= "text"
    else
        st.look = (k == 0) and "oom" or (k <= db.lowAt) and "low" or "normal"
        st.color, st.hidden = db.looks[st.look].color, false
    end
    for i, c in ipairs(db.conditions) do
        if c.enabled and TestCond(c, k, pct, ctx) then
            local a = c.action
            if a == "color" then st.color = c.color
            elseif a == "hide" then st.hidden = true
            elseif a == "pulse" then st.pulse = true
            elseif a == "glow" then st.glows[i] = true
            end
        end
    end
    return st
end

local function ApplyPlain(h, st)
    for _, key in ipairs(LOOKS) do
        local L = h.layers[key]
        local on = (not st.hidden) and st.look == key
        L.still:SetAlpha((on and not st.pulse) and 1 or 0)
        L.pulse:SetAlpha((on and st.pulse) and 1 or 0)
        if on then
            local c = st.color
            L.still.fs:SetTextColor(c.r, c.g, c.b, c.a or 1)
            L.pulse.fs:SetTextColor(c.r, c.g, c.b, c.a or 1)
        end
    end
    for i, c in ipairs(CC.db.conditions) do
        if st.glows[i] then
            Glow(h, i):SetAlpha(1)
        elseif h.glows[i] then
            h.glows[i]:SetAlpha(0)
        end
    end
    for i, g in pairs(h.glows) do
        if not CC.db.conditions[i] then g:SetAlpha(0) end
    end
end

---------------------------------------------------------
--  SECTION: Curves (when mana is secret)
---------------------------------------------------------
-- Forever hides the player's current mana from addons (a secret value, even out of
-- combat); max mana and spell costs stay readable. So CastCount works out, for every
-- stretch of mana % (x from 0 to 1), what the button should show, and hands the game
-- step curves: UnitPowerPercent evaluates them against the real mana. The count is a
-- step at every k * cost; mana % conditions add steps at their thresholds. The results
-- are secret too, but text, colour and alpha setters accept them.
local lastMax = 1
local function Mana()
    local cur, max = UnitPower("player", CC.MANA), UnitPowerMax("player", CC.MANA)
    if Plain(max) and max > 0 then lastMax = max end
    return Plain(cur) and cur or nil, lastMax
end

local HAS_CURVES = C_CurveUtil and C_CurveUtil.CreateCurve and C_CurveUtil.CreateColorCurve
    and UnitPowerPercent and Enum and Enum.LuaCurveType and true or false
CC.HAS_CURVES = HAS_CURVES
local MAX_COUNT = 999
local EPS = 1e-6
local countCurves, plans, alphaCurve = {}, {}, nil
local planCount = 0
CC.curveError = nil

local function Evaluate(curve)
    local ok, v = pcall(UnitPowerPercent, "player", CC.MANA, false, curve)
    if not ok then
        CC.curveError = tostring(v)
        return nil
    end
    return v
end

-- x where the count reaches k: k casts' worth of mana, as a fraction of max.
local function StepX(k, cost, max)
    if k == 0 then return 0 end
    return math.max(0, k * cost / max - EPS)
end

local function CountCurve(cost, max)
    local key = cost .. ":" .. max
    local c = countCurves[key]
    if c then return c end
    c = C_CurveUtil.CreateCurve()
    c:SetType(Enum.LuaCurveType.Step)
    for k = 0, math.min(MAX_COUNT, math.floor(max / cost)) do
        c:AddPoint(StepX(k, cost, max), k)
    end
    countCurves[key] = c
    return c
end

-- Alpha 1 below full mana, 0 at full (for "only when my mana isn't full").
local function AlphaCurve()
    if alphaCurve then return alphaCurve end
    alphaCurve = C_CurveUtil.CreateCurve()
    alphaCurve:SetType(Enum.LuaCurveType.Step)
    alphaCurve:AddPoint(0, 1)
    alphaCurve:AddPoint(1 - EPS, 0)
    return alphaCurve
end

-- Identifies every setting that feeds the plans, so they rebuild when one changes.
local function SettingsSig()
    local db = CC.db
    local function C(c) return c and ("%.3f,%.3f,%.3f,%.3f"):format(c.r, c.g, c.b, c.a or 1) or "-" end
    local parts = { db.lowAt, db.free.mode, C(db.free.color) }
    for _, key in ipairs(LOOKS) do parts[#parts + 1] = C(db.looks[key].color) end
    for _, c in ipairs(db.conditions) do
        parts[#parts + 1] = table.concat({ tostring(c.enabled), c.subject, c.op, tostring(c.value), c.action, C(c.color) }, ",")
    end
    return table.concat(parts, "|")
end

-- One value per stretch: a constant when it never changes, otherwise a step curve.
local function Series(B, states, fn)
    local first, same = fn(states[1]), true
    for i = 2, #states do
        if fn(states[i]) ~= first then same = false break end
    end
    if same then return { const = first } end
    local curve, prev = C_CurveUtil.CreateCurve(), nil
    curve:SetType(Enum.LuaCurveType.Step)
    for i, st in ipairs(states) do
        local v = fn(st)
        if v ~= prev then curve:AddPoint(B[i], v); prev = v end
    end
    return { curve = curve }
end

-- The colour a look's text has wherever it shows (stretches where it's hidden
-- borrow a neighbour's colour, so the curve has no gaps).
local function ColorSeries(B, states, key)
    local cols, last = {}, nil
    for i, st in ipairs(states) do
        if st.look == key then last = st.color end
        cols[i] = (st.look == key) and st.color or nil
    end
    if not last then return { const = CC.db.looks[key].color } end
    local fill
    for i = #states, 1, -1 do
        if cols[i] then fill = cols[i] else cols[i] = fill end
    end
    for i = 1, #states do
        if cols[i] then fill = cols[i] else cols[i] = fill end
    end
    local first, same = cols[1], true
    for i = 2, #cols do
        if cols[i] ~= first then same = false break end
    end
    if same then return { const = first } end
    local curve, prev = C_CurveUtil.CreateColorCurve(), nil
    curve:SetType(Enum.LuaCurveType.Step)
    for i, c in ipairs(cols) do
        if c ~= prev then
            curve:AddPoint(B[i], CreateColor(c.r, c.g, c.b, c.a or 1))
            prev = c
        end
    end
    return { curve = curve }
end

-- Everything a button with this cost (nil = free spell) shows, across all mana levels.
local function Plan(cost, max, ctx, sig)
    local key = (cost or "free") .. ":" .. max .. ":" .. (ctx.combat and 1 or 0) .. ":" .. sig
    local plan = plans[key]
    if plan then return plan end
    if planCount > 100 then wipe(plans); planCount = 0 end

    local raw = { 0 }
    if cost then
        for k = 1, math.min(MAX_COUNT, math.floor(max / cost)) do raw[#raw + 1] = StepX(k, cost, max) end
    end
    for _, c in ipairs(CC.db.conditions) do
        if c.enabled and c.subject == "mana" then
            local t = tonumber(c.value) or 0
            for _, x in ipairs({ t / 100, (t + 1) / 100 }) do
                if x > 0 and x < 1 then raw[#raw + 1] = x end
            end
        end
    end
    table.sort(raw)
    local B = {}
    for _, x in ipairs(raw) do
        if not B[#B] or x - B[#B] > 1e-9 then B[#B + 1] = x end
    end
    local states = {}
    for i, x0 in ipairs(B) do
        local x1 = B[i + 1] or 1
        local mid = (x0 < x1) and (x0 + x1) / 2 or x0
        local k = cost and math.floor(mid * max / cost + 1e-9) or nil
        states[i] = StateAt(k, mid * 100, ctx)
    end

    plan = { alpha = {}, color = {}, glow = {} }
    for _, look in ipairs(LOOKS) do
        plan.alpha[look] = {
            still = Series(B, states, function(st) return (not st.hidden and st.look == look and not st.pulse) and 1 or 0 end),
            pulse = Series(B, states, function(st) return (not st.hidden and st.look == look and st.pulse) and 1 or 0 end),
        }
        plan.color[look] = ColorSeries(B, states, look)
    end
    for i, c in ipairs(CC.db.conditions) do
        if c.enabled and c.action == "glow" then
            plan.glow[i] = Series(B, states, function(st) return st.glows[i] and 1 or 0 end)
        end
    end
    plans[key] = plan
    planCount = planCount + 1
    return plan
end

local function SetAlphaFrom(frame, entry)
    if entry.const ~= nil then
        frame:SetAlpha(entry.const)
    else
        local a = Evaluate(entry.curve)
        frame:SetAlpha(a == nil and 0 or a)
    end
end

local function SetColorFrom(fs1, fs2, entry)
    local c = entry.const
    if c then
        fs1:SetTextColor(c.r, c.g, c.b, c.a or 1)
        fs2:SetTextColor(c.r, c.g, c.b, c.a or 1)
        return
    end
    local col = Evaluate(entry.curve)
    if col and col.GetRGBA then
        fs1:SetTextColor(col:GetRGBA())
        fs2:SetTextColor(col:GetRGBA())
    end
end

local function ApplyPlan(h, plan)
    for _, key in ipairs(LOOKS) do
        local L = h.layers[key]
        SetAlphaFrom(L.still, plan.alpha[key].still)
        SetAlphaFrom(L.pulse, plan.alpha[key].pulse)
        SetColorFrom(L.still.fs, L.pulse.fs, plan.color[key])
    end
    for i in ipairs(CC.db.conditions) do
        if plan.glow[i] then
            SetAlphaFrom(Glow(h, i), plan.glow[i])
        elseif h.glows[i] then
            h.glows[i]:SetAlpha(0)
        end
    end
    for i, g in pairs(h.glows) do
        if not CC.db.conditions[i] then g:SetAlpha(0) end
    end
end

---------------------------------------------------------
--  SECTION: Updating
---------------------------------------------------------
-- true = show, false = hide, "notfull" = show only while mana isn't full (mana is
-- secret, so the game decides through an alpha curve). CC.preview (set while the
-- Text/Conditions/Blacklist tabs are open) shows every selected count so changes can be seen.
local function Visibility(btn, mana, max)
    if CC.preview then return true end
    local s = CC.db.show
    if s.onHover and hovered[btn] then return true end
    if CC.inCombat then return s.inCombat end
    if not s.outOfCombat then return false end
    if not s.oocOnlyNotFull then return true end
    if mana then return mana < max end
    return HAS_CURVES and "notfull" or true
end

-- soundNow collects which sound conditions hold on some selected button.
function CC.UpdateButton(btn, mana, max, sig, soundNow)
    local spell = CC.ButtonSpell(btn)
    if not spell then return HideHolder(btn) end
    local name = CC.SpellName(spell)
    if name and CC.char.blacklist[name] then return HideHolder(btn) end
    local kind, cost = CC.SpellCost(spell)
    if kind ~= "mana" and kind ~= "free" then return HideHolder(btn) end
    local ctx = { combat = CC.inCombat, free = (kind == "free") }
    if kind == "free" then cost = nil end

    for _, c in ipairs(CC.db.conditions) do
        if c.enabled and c.action == "sound" and CC.CondIsLuaKnown(c) and TestCond(c, nil, nil, ctx) then
            soundNow[c] = true
        end
    end

    local vis = Visibility(btn, mana, max)
    if not vis then return HideHolder(btn) end

    local h = Holder(btn)
    if mana then
        local k = cost and math.floor(mana / cost) or nil
        SetAllText(h, cost and k or CC.db.free.text)
        ApplyPlain(h, StateAt(k, mana / max * 100, ctx))
    elseif HAS_CURVES then
        local text = CC.db.free.text
        if cost then
            local n = Evaluate(CountCurve(cost, max))
            if n == nil then return HideHolder(btn) end
            text = string.format("%d", n)
        end
        SetAllText(h, text)
        ApplyPlan(h, Plan(cost, max, ctx, sig))
    else
        return HideHolder(btn)
    end

    if vis == "notfull" then
        local a = Evaluate(AlphaCurve())
        h:SetAlpha(a == nil and 1 or a)
    else
        h:SetAlpha(1)
    end
    h:Show()
end

-- Sounds play when a condition starts to hold (not while it keeps holding).
local soundWas, soundsReady = {}, false
local function PlaySounds(soundNow)
    for _, c in ipairs(CC.db.conditions) do
        if c.enabled and c.action == "sound" then
            local now = soundNow[c] or false
            if now and not soundWas[c] and soundsReady then CC.PlaySound(c.sound) end
            soundWas[c] = now
        end
    end
    soundsReady = true
end

function CC.Refresh()
    CC.dirty = false
    if not CC.db then return end
    local mana, max = Mana()
    local sig = (not mana and HAS_CURVES) and SettingsSig() or ""
    local selected = CC.char.buttons
    for btn, h in pairs(holders) do
        if not selected[btn:GetName() or ""] then h:Hide() end
    end
    local soundNow = {}
    -- Combat doesn't depend on any button.
    for _, c in ipairs(CC.db.conditions) do
        if c.enabled and c.action == "sound" and c.subject == "combat"
            and TestCond(c, nil, nil, { combat = CC.inCombat }) then
            soundNow[c] = true
        end
    end
    for name in pairs(selected) do
        local btn = _G[name]
        if type(btn) == "table" and btn.GetObjectType then CC.UpdateButton(btn, mana, max, sig, soundNow) end
    end
    PlaySounds(soundNow)
end

---------------------------------------------------------
--  SECTION: Sounds
---------------------------------------------------------
local SOUNDS = {
    { value = "raidwarning", label = "Raid warning", kit = "RAID_WARNING" },
    { value = "readycheck",  label = "Ready check",  kit = "READY_CHECK" },
    { value = "alarm",       label = "Alarm clock",  kit = "ALARM_CLOCK_WARNING_3" },
    { value = "ping",        label = "Map ping",     kit = "MAP_PING" },
    { value = "whisper",     label = "Whisper",      kit = "TELL_MESSAGE" },
}

-- The game's sounds plus any registered with LibSharedMedia ("lsm:<name>").
function CC.SoundItems()
    local items = {}
    for _, s in ipairs(SOUNDS) do
        if SOUNDKIT and SOUNDKIT[s.kit] then items[#items + 1] = { value = s.value, label = s.label } end
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        for _, name in ipairs(LSM:List("sound") or {}) do
            if name ~= "None" then items[#items + 1] = { value = "lsm:" .. name, label = name } end
        end
    end
    return items
end

function CC.PlaySound(key)
    if not key then return end
    local lsmName = key:match("^lsm:(.+)$")
    if lsmName then
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        local file = LSM and LSM:Fetch("sound", lsmName, true)
        if file then PlaySoundFile(file, "Master") end
        return
    end
    for _, s in ipairs(SOUNDS) do
        if s.value == key and SOUNDKIT and SOUNDKIT[s.kit] then
            PlaySound(SOUNDKIT[s.kit], "Master")
        end
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
    CC.Print(("mana %s / %s (secret API %s), power type %s, form %s, in combat %s, curves %s, curve error %s")
        :format(Show(cur), Show(max), issecretvalue and "yes" or "no", Show(ptype),
            Show(GetShapeshiftForm and GetShapeshiftForm()), tostring(CC.inCombat),
            HAS_CURVES and "yes" or "no", tostring(CC.curveError)))
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
