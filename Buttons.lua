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
-- cooldown swipe). What it shows is worked out as a "state": which look, the
-- colour, transparency, any size/offset/text/pulse overrides from conditions,
-- glows and an icon tint. Every distinct text variant (look + overrides) gets its
-- own text layer, every distinct glow its own glow frame; the state decides
-- which are visible. When mana is secret the game decides, through curves.
local holders = {}   -- button -> holder
local hovered = {}   -- button -> true while the mouse is over it
local LOOKS = CC.LOOKS
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
local NO_TINT = { r = 0, g = 0, b = 0, a = 0 }
local styleVersion = 1

-- Applies a look (font, size, outline, shadow, position) to a font string;
-- size and dx/dy come from conditions when they override the look.
function CC.StyleFont(fs, look, anchorTo, fontPath, size, dx, dy)
    local flags = (look.outline ~= "NONE") and look.outline or ""
    size = size or look.size
    fs:SetFont(fontPath or CC.FontPath(look.font), size, flags)
    if not fs:GetFont() then fs:SetFont(CC.DEFAULT_FONT, size, flags) end
    if look.shadow then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
    fs:ClearAllPoints()
    fs:SetPoint(look.anchor, anchorTo, look.anchor, look.x + (dx or 0), look.y + (dy or 0))
end

local function Holder(btn)
    local h = holders[btn]
    if not h then
        h = CreateFrame("Frame", nil, btn)
        h:SetAllPoints(btn)
        h.layers, h.glows = {}, {}
        h.tint = h:CreateTexture(nil, "ARTWORK")
        h.tint:SetPoint("TOPLEFT", 2, -2)
        h.tint:SetPoint("BOTTOMRIGHT", -2, 2)
        h.tint:SetColorTexture(1, 1, 1, 1)
        h.tint:SetVertexColor(0, 0, 0, 0)
        holders[btn] = h
        btn:HookScript("OnEnter", function() hovered[btn] = true; CC.MarkDirty() end)
        btn:HookScript("OnLeave", function() hovered[btn] = nil; CC.MarkDirty() end)
    end
    -- Keep above the button even if a bar addon re-levels it.
    local want = math.min(9980, btn:GetFrameLevel() + 10)
    if h:GetFrameLevel() < want then h:SetFrameLevel(want) end
    return h
end

local function NewLayer(h, pulse)
    local f = CreateFrame("Frame", nil, h)
    f:SetAllPoints(h)
    f:SetFrameLevel(h:GetFrameLevel() + 5)
    f.fs = f:CreateFontString(nil, "OVERLAY")
    f.pulse = pulse
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

-- The text layer for variant key (reusing an idle layer when one fits).
local function Layer(h, key, spec, inUse)
    local f = h.layers[key]
    if not f then
        for k, other in pairs(h.layers) do
            if not inUse[k] and other.pulse == spec.pulse then
                h.layers[k], f = nil, other
                break
            end
        end
        f = f or NewLayer(h, spec.pulse)
        h.layers[key] = f
        f.styled = nil
    end
    if f.styled ~= styleVersion then
        local look = CC.db.looks[spec.look]
        local text = spec.text or (spec.look == "free" and look.text) or nil
        CC.StyleFont(f.fs, look, f, CC.LookFontPath(look, text), spec.size, spec.dx, spec.dy)
        f.styled = styleVersion
    end
    return f
end

local GLOW_TYPES = {
    { value = "button",   label = "Action button glow" },
    { value = "pixel",    label = "Pixel glow" },
    { value = "autocast", label = "Autocast shine" },
    { value = "proc",     label = "Proc glow" },
    { value = "border",   label = "Simple border" },
}
CC.GLOW_TYPES = GLOW_TYPES

-- A glow frame of one kind and colour; its alpha says whether it shows.
local function GlowGate(h, key, glowType, c)
    local g = h.glows[key]
    if g then return g end
    g = CreateFrame("Frame", nil, h)
    g:SetAllPoints(h)
    g:SetFrameLevel(h:GetFrameLevel() + 2)
    local color = { c.r, c.g, c.b, c.a or 1 }
    if LCG and glowType == "pixel" then
        LCG.PixelGlow_Start(g, color, 8, 0.25, nil, 2, 0, 0, false, "cc")
    elseif LCG and glowType == "autocast" then
        LCG.AutoCastGlow_Start(g, color, 4, 0.125, 1, 0, 0, "cc")
    elseif LCG and glowType == "proc" and LCG.ProcGlow_Start then
        LCG.ProcGlow_Start(g, { color = color, startAnim = false, key = "cc" })
    elseif LCG and glowType == "button" then
        LCG.ButtonGlow_Start(g, color, 0.125)
    else
        local t = g:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        t:SetBlendMode("ADD")
        t:SetPoint("CENTER")
        local w = h:GetWidth()
        t:SetSize((w > 0 and w or 36) * 1.75, (w > 0 and w or 36) * 1.75)
        t:SetVertexColor(c.r, c.g, c.b, c.a or 1)
    end
    g:SetAlpha(0)
    h.glows[key] = g
    return g
end

function CC.ApplyStyle()
    styleVersion = styleVersion + 1
    CC.MarkDirty()
end

-- ManaFill bar: inside the icon, filling bottom-up from 0 to the spell's cost.
function CC.StyleFill(bar)
    local s = CC.db.fill
    bar:SetStatusBarTexture(CC.BarTexturePath(s.texture))
    local c = s.color
    bar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
end

local function FillBar(h)
    local f = h.fill
    if not f then
        f = CreateFrame("StatusBar", nil, h)
        f:SetPoint("TOPLEFT", 2, -2)
        f:SetPoint("BOTTOMRIGHT", -2, 2)
        f:SetOrientation("VERTICAL")
        f:SetFrameLevel(h:GetFrameLevel() + 1)
        f:SetAlpha(0)
        h.fill = f
    end
    if f.styled ~= styleVersion then
        CC.StyleFill(f)
        f.styled = styleVersion
    end
    return f
end

-- Holders fading out: holder -> { start = GetTime(), duration }. A shared OnUpdate
-- lowers each one's alpha from 1 to 0 over its duration, then hides it.
local fading = {}
local fadeDriver = CreateFrame("Frame")
fadeDriver:Hide()
fadeDriver:SetScript("OnUpdate", function(self)
    local now, any = GetTime(), false
    for h, f in pairs(fading) do
        local a = 1 - (now - f.start) / f.duration
        if a <= 0 then
            fading[h] = nil
            h:Hide()
            h:SetAlpha(1)
        else
            h:SetAlpha(a)
            any = true
        end
    end
    if not any then self:Hide() end
end)

local function StopFade(h)
    fading[h] = nil
end

local function HideHolder(btn)
    local h = holders[btn]
    if not h then return end
    StopFade(h)
    h:Hide()
end

-- Fade on hide: when a count is hidden by the visibility settings it fades away
-- instead of vanishing. Showing is always instant (UpdateButton stops the fade).
local function FadeHolder(btn)
    local h = holders[btn]
    if not h or not h:IsShown() then return end
    local s = CC.db.show
    if not s.fadeOut or CC.preview then return HideHolder(btn) end
    if fading[h] then return end
    fading[h] = { start = GetTime(), duration = math.max(0.05, tonumber(s.fadeTime) or 0.5) }
    h:SetAlpha(1)
    fadeDriver:Show()
end

---------------------------------------------------------
--  SECTION: Conditions
---------------------------------------------------------
-- Checks CastCount can answer in Lua even while mana is secret.
local LUA_SUBJECTS = { free = true, combat = true, hover = true }

local function Compare(v, op, t)
    if op == "<" then return v < t
    elseif op == "<=" then return v <= t
    elseif op == "=" then return v == t
    elseif op == "!=" then return v ~= t
    elseif op == ">=" then return v >= t
    elseif op == ">" then return v > t
    end
    return false
end

-- k = casts left (nil when the spell is free now), pct = mana % (nil = unknown),
-- ctx = what's known in Lua (free, combat, hover).
local function TestCheck(ch, k, pct, ctx)
    local s = ch.subject
    if LUA_SUBJECTS[s] then return (ctx[s] and true or false) == (ch.op ~= "false") end
    local t = tonumber(ch.value) or 0
    if s == "casts" then
        return k ~= nil and Compare(k, ch.op, t)
    elseif s == "mana" then
        return pct ~= nil and Compare(math.floor(pct + 1e-9), ch.op, t)
    end
    return false
end

-- Checks are joined by "and" / "or" (each check after the first carries its own).
-- "and" binds tighter, as usual: A or B and C means A or (B and C). So the checks
-- split into groups at every "or", and the condition holds when any group holds.
local function Matches(c, k, pct, ctx)
    local checks = c.checks or {}
    if #checks == 0 then return false end
    local group = true
    for i, ch in ipairs(checks) do
        if i > 1 and ch.join == "or" then
            if group then return true end
            group = true
        end
        if group and not TestCheck(ch, k, pct, ctx) then group = false end
    end
    return group
end
CC.ConditionMatches = Matches

-- Can CastCount tell in Lua whether this condition holds (needed for sounds and
-- chat messages)? Only when every check is one it can answer.
function CC.CondIsLuaKnown(c)
    for _, ch in ipairs(c.checks or {}) do
        if not LUA_SUBJECTS[ch.subject] then return false end
    end
    return true
end

-- What a button shows at k casts / pct mana.
local function StateAt(k, pct, ctx)
    local db = CC.db
    local look = ctx.free and "free" or (k == 0) and "oom" or (k <= db.lowAt) and "low" or "normal"
    local st = {
        look = look, color = db.looks[look].color, alpha = 1, hidden = false,
        dx = 0, dy = 0, pulse = false, glows = {}, tint = NO_TINT,
    }
    for _, c in ipairs(db.conditions) do
        if c.enabled and Matches(c, k, pct, ctx) then
            for _, pr in ipairs(c.props or {}) do
                local t = pr.type
                if t == "textcolor" and pr.color then st.color = pr.color
                elseif t == "alpha" then st.alpha = math.max(0, math.min(100, tonumber(pr.value) or 100)) / 100
                elseif t == "hide" then st.hidden = true
                elseif t == "size" then st.size = tonumber(pr.value)
                elseif t == "offset" then st.dx, st.dy = tonumber(pr.x) or 0, tonumber(pr.y) or 0
                elseif t == "text" then st.text = pr.text
                elseif t == "pulse" then st.pulse = true
                elseif t == "glow" and pr.color then
                    local c2 = pr.color
                    st.glows[("%s:%.3f,%.3f,%.3f,%.3f"):format(pr.glowType or "button", c2.r, c2.g, c2.b, c2.a or 1)] =
                        { glowType = pr.glowType or "button", color = c2 }
                elseif t == "tint" and pr.color then st.tint = pr.color
                end
            end
        end
    end
    -- The text variant: everything about the text except colour and transparency.
    st.variant = table.concat({ look, st.size or "", st.dx, st.dy, st.text or "#", st.pulse and 1 or 0 }, ":")
    return st
end

---------------------------------------------------------
--  SECTION: Curves (when mana is secret)
---------------------------------------------------------
-- Forever hides the player's current mana from addons (a secret value, even out of
-- combat); max mana and spell costs stay readable. So CastCount works out what the
-- button shows on every stretch of mana % (x from 0 to 1) and hands the game step
-- curves; UnitPowerPercent evaluates them against the real mana. The count steps at
-- every k * cost; mana % checks add steps at their thresholds. The results are secret
-- too, but text, colour and alpha setters accept them.
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
-- ManaFill alpha: 1 while mana is below one cast's worth, 0 from then on.
local fillCurves = {}
local function FillCurve(cost, max)
    local key = cost .. ":" .. max
    local c = fillCurves[key]
    if c then return c end
    c = C_CurveUtil.CreateCurve()
    c:SetType(Enum.LuaCurveType.Step)
    c:AddPoint(0, 1)
    c:AddPoint(StepX(1, cost, max), 0)
    fillCurves[key] = c
    return c
end

local function AlphaCurve()
    if alphaCurve then return alphaCurve end
    alphaCurve = C_CurveUtil.CreateCurve()
    alphaCurve:SetType(Enum.LuaCurveType.Step)
    alphaCurve:AddPoint(0, 1)
    alphaCurve:AddPoint(1 - EPS, 0)
    return alphaCurve
end

-- Identifies every setting that feeds the plans, so they rebuild when one changes.
local function Ser(v)
    if type(v) ~= "table" then return tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local out = {}
    for _, k in ipairs(keys) do
        local x = v[k]
        if x == nil then x = v[tonumber(k)] end
        out[#out + 1] = k .. "=" .. Ser(x)
    end
    return "{" .. table.concat(out, ",") .. "}"
end
local function SettingsSig()
    return Ser({ CC.db.lowAt, CC.db.looks, CC.db.conditions })
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

-- A colour per stretch; fn may return nil where it doesn't matter (hidden), and
-- those stretches borrow a neighbour's colour so the curve has no gaps.
local function ColorSeries(B, states, fn, fallback)
    local cols, any = {}, false
    for i, st in ipairs(states) do
        cols[i] = fn(st)
        if cols[i] then any = true end
    end
    if not any then return { const = fallback } end
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
    if same or not HAS_CURVES then return { const = first } end
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

-- Turns the states of every stretch into what the holder needs.
local function MakePlan(B, states)
    local plan = { variants = {}, glows = {} }
    for _, st in ipairs(states) do
        if not plan.variants[st.variant] then
            plan.variants[st.variant] = {
                spec = { look = st.look, size = st.size, dx = st.dx, dy = st.dy, text = st.text, pulse = st.pulse },
            }
        end
        for key, gl in pairs(st.glows) do
            plan.glows[key] = plan.glows[key] or { glowType = gl.glowType, color = gl.color }
        end
    end
    for key, v in pairs(plan.variants) do
        v.alpha = Series(B, states, function(st) return (st.variant == key and not st.hidden) and st.alpha or 0 end)
        v.color = ColorSeries(B, states, function(st) return st.variant == key and st.color or nil end,
            CC.db.looks[v.spec.look].color)
    end
    for key, gl in pairs(plan.glows) do
        gl.alpha = Series(B, states, function(st) return st.glows[key] and 1 or 0 end)
    end
    plan.tint = ColorSeries(B, states, function(st) return st.tint end, NO_TINT)
    return plan
end

-- Everything a button with this cost (nil = zero cost right now) shows, across all mana levels.
local function Plan(cost, max, ctx, sig)
    local key = table.concat({ cost or "free", max, ctx.combat and 1 or 0, ctx.hover and 1 or 0, sig }, ":")
    local plan = plans[key]
    if plan then return plan end
    if planCount > 150 then wipe(plans); planCount = 0 end

    local raw = { 0 }
    if cost then
        for k = 1, math.min(MAX_COUNT, math.floor(max / cost)) do raw[#raw + 1] = StepX(k, cost, max) end
    end
    for _, c in ipairs(CC.db.conditions) do
        if c.enabled then
            for _, ch in ipairs(c.checks or {}) do
                if ch.subject == "mana" then
                    local t = tonumber(ch.value) or 0
                    for _, x in ipairs({ t / 100, (t + 1) / 100 }) do
                        if x > 0 and x < 1 then raw[#raw + 1] = x end
                    end
                end
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
    plan = MakePlan(B, states)
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

local function ColorFrom(entry)
    if entry.const then
        local c = entry.const
        return c.r, c.g, c.b, c.a or 1
    end
    local col = Evaluate(entry.curve)
    if col and col.GetRGBA then return col:GetRGBA() end
    return 1, 1, 1, 1
end

local function ApplyPlan(h, plan, countText)
    local inUse = {}
    for key in pairs(plan.variants) do inUse[key] = true end
    for key, v in pairs(plan.variants) do
        local f = Layer(h, key, v.spec, inUse)
        local text = v.spec.text
        if v.spec.look == "free" and not text then text = CC.db.looks.free.text end
        f.fs:SetText(text or countText or "")
        SetAlphaFrom(f, v.alpha)
        f.fs:SetTextColor(ColorFrom(v.color))
    end
    for key, f in pairs(h.layers) do
        if not inUse[key] then f:SetAlpha(0) end
    end
    for key, gl in pairs(plan.glows) do
        SetAlphaFrom(GlowGate(h, key, gl.glowType, gl.color), gl.alpha)
    end
    for key, g in pairs(h.glows) do
        if not plan.glows[key] then g:SetAlpha(0) end
    end
    h.tint:SetVertexColor(ColorFrom(plan.tint))
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

-- ManaFill for a spell costing cost (nil = free now: no fill). With secret mana the
-- bar takes the secret value directly and a curve decides whether it shows.
local function UpdateFill(h, cost, max, mana)
    if not (CC.db.fill.enabled and cost) then
        if h.fill then h.fill:SetAlpha(0) end
        return
    end
    local f = FillBar(h)
    f:SetMinMaxValues(0, cost)
    if mana then
        f:SetValue(math.min(mana, cost))
        f:SetAlpha(mana < cost and 1 or 0)
        return
    end
    local ok, err = pcall(f.SetValue, f, UnitPower("player", CC.MANA))
    if not ok then
        CC.curveError = tostring(err)
        f:SetAlpha(0)
        return
    end
    if cost >= max then
        f:SetAlpha(1)
    else
        local a = Evaluate(FillCurve(cost, max))
        f:SetAlpha(a == nil and 0 or a)
    end
end

-- Spells seen costing mana this session: a 0 cost from then on means "Zero cost".
CC.everMana = CC.everMana or {}

-- condNow collects the conditions (for sounds and chat) that hold on some selected button.
function CC.UpdateButton(btn, mana, max, sig, condNow)
    local spell = CC.ButtonSpell(btn)
    if not spell then return HideHolder(btn) end
    local name = CC.SpellName(spell)
    if name and CC.char.blacklist[name] then return HideHolder(btn) end
    local kind, cost = CC.SpellCost(spell)
    local freeNow = kind == "free" and CC.everMana[spell]
    if kind ~= "mana" and not freeNow then return HideHolder(btn) end
    if freeNow then cost = nil end
    local ctx = { combat = CC.inCombat, free = freeNow and true or false, hover = hovered[btn] and true or false }

    local k = (mana and cost) and math.floor(mana / cost) or nil
    local pct = mana and (mana / max * 100) or nil
    for _, c in ipairs(CC.db.conditions) do
        if c.enabled and not condNow[c] and (mana or CC.CondIsLuaKnown(c)) and Matches(c, k, pct, ctx) then
            condNow[c] = true
        end
    end

    local vis = Visibility(btn, mana, max)
    if not vis then return FadeHolder(btn) end

    local h = Holder(btn)
    StopFade(h)
    if mana then
        ApplyPlan(h, MakePlan({ 0 }, { StateAt(k, pct, ctx) }), k and tostring(k))
    elseif HAS_CURVES then
        local countText
        if cost then
            local n = Evaluate(CountCurve(cost, max))
            if n == nil then return HideHolder(btn) end
            countText = string.format("%d", n)
        end
        ApplyPlan(h, Plan(cost, max, ctx, sig), countText)
    else
        return HideHolder(btn)
    end

    UpdateFill(h, cost, max, mana)

    if vis == "notfull" then
        local a = Evaluate(AlphaCurve())
        h:SetAlpha(a == nil and 1 or a)
    else
        h:SetAlpha(1)
    end
    h:Show()
end

-- Sounds and chat messages fire when a condition starts to hold (not while it keeps holding).
local condWas, condsReady = {}, false
local function FireTriggers(condNow)
    for _, c in ipairs(CC.db.conditions) do
        if c.enabled then
            local now = condNow[c] or false
            if now and not condWas[c] and condsReady then
                for _, pr in ipairs(c.props or {}) do
                    if pr.type == "sound" then
                        CC.PlaySound(pr.sound)
                    elseif pr.type == "chat" and pr.text and pr.text ~= "" then
                        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99CastCount|r: " .. pr.text)
                    end
                end
            end
            condWas[c] = now
        end
    end
    condsReady = true
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
    local condNow = {}
    for name in pairs(selected) do
        local btn = _G[name]
        if type(btn) == "table" and btn.GetObjectType then CC.UpdateButton(btn, mana, max, sig, condNow) end
    end
    FireTriggers(condNow)
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
-- safety refresh every second (buffs that change costs fire no cost event).
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
