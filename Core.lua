---------------------------------------------------------
--  CastCount - Core
--  Author: Dranged
---------------------------------------------------------
-- Saved settings, events and slash commands. The other files hang their
-- functions off the shared CC table.

local ADDON, CC = ...
_G.CastCount = CC

CC.UI = {}
CC.MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0

local function Color(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end
CC.Color = Color

---------------------------------------------------------
--  SECTION: Defaults
---------------------------------------------------------
-- The looks a count can have, each a full text style. "Free" (key "free") is for
-- a spell that normally costs mana but costs nothing right now, for any reason; it shows
-- its own text (an infinity sign by default) instead of a number.
local function Look(r, g, b, font)
    return {
        font = font or "Friz Quadrata TT", size = 18, outline = "OUTLINE", shadow = false,
        color = Color(r, g, b), anchor = "CENTER", x = 0, y = 0,
    }
end
CC.LOOKS = { "normal", "low", "oom", "free" }
CC.LOOK_LABELS = { normal = "Default", low = "Low", oom = "Out of mana", free = "Free" }
local freeLook = Look(0.4, 0.8, 1, "Arial Narrow")
freeLook.text = "\226\136\158"   -- the infinity sign, UTF-8
freeLook.size = 22

-- Account-wide: how the numbers look, when they show, and the conditions.
CC.DEFAULTS = {
    looks = { normal = Look(0, 1, 0), low = Look(1, 0.65, 0), oom = Look(1, 0.2, 0.2), free = freeLook },
    lowAt = 3,   -- "Low" look from 1 up to this many casts; 0 casts = "Out of mana"
    show = {
        inCombat = true, outOfCombat = true, oocOnlyNotFull = false,
        onHover = true, macros = true,
    },
    -- Each: { enabled, collapsed, name (optional),
    --   checks = { { join = and|or (2nd check on), subject = casts|mana|free|combat|hover,
    --                op = < <= = != >= > | true false, value } },
    --   props = { { type = textcolor|alpha|hide|size|offset|text|pulse|glow|tint|sound|chat, ... } } }
    conditions = {},
    -- ManaFill: while a spell can't be afforded, the button fills from the bottom
    -- up as mana comes back (0 to the spell's cost).
    fill = { enabled = true, color = Color(0.25, 0.55, 1, 0.45), texture = "Solid" },
    minimap = { hide = false },   -- LibDBIcon keeps the button's position here too
}

-- Per character: which buttons show counts (by button name) and which
-- spells never do (by spell name, so every rank is covered; value = a spell ID for the icon).
CC.CHAR_DEFAULTS = { buttons = {}, blacklist = {} }

local function CopyDeep(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = CopyDeep(x) end
    return t
end
CC.CopyDeep = CopyDeep

-- Fills missing keys. Lists (conditions) are copied whole only when missing,
-- so a user's list is never added to.
local function FillDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = CopyDeep(v)
        elseif type(v) == "table" and type(dst[k]) == "table" and v[1] == nil and next(v) ~= nil then
            FillDefaults(dst[k], v)
        end
    end
end

-- 2.0 test builds had one text style plus colour rules: turn them into looks.
local function Migrate(db)
    if db.text and not db.looks then
        local t = db.text
        db.looks = { normal = CopyDeep(t), low = CopyDeep(t), oom = CopyDeep(t) }
        db.looks.low.color, db.looks.oom.color = Color(1, 0.65, 0), Color(1, 0.2, 0.2)
        local lowAt
        for _, rule in ipairs(db.rules and db.rules.list or {}) do
            if rule.at == 0 then
                db.looks.oom.color = CopyDeep(rule.color)
            elseif not lowAt or rule.at > lowAt then
                lowAt = rule.at
                db.looks.low.color = CopyDeep(rule.color)
            end
        end
        db.lowAt = lowAt
    end
    db.text, db.rules, db.free = nil, nil, nil

    -- Earlier test builds had one check and one action per condition.
    local OPS = { lt = "<", le = "<=", eq = "=", ne = "!=", gt = ">", ge = ">=", is = "true", isnot = "false" }
    local PROPS = { color = "textcolor", hide = "hide", glow = "glow", pulse = "pulse", sound = "sound" }
    for i, c in ipairs(db.conditions or {}) do
        if c.checks and c.match then
            for ci, ch in ipairs(c.checks) do
                if ci > 1 and not ch.join then ch.join = (c.match == "any") and "or" or "and" end
            end
            c.match = nil
        end
        if not c.checks then
            db.conditions[i] = {
                enabled = c.enabled, match = "all",
                checks = { { subject = (c.subject == "free") and "free" or c.subject, op = OPS[c.op] or c.op, value = c.value } },
                props = { { type = PROPS[c.action] or "textcolor", color = c.color, sound = c.sound, glowType = "button" } },
            }
        end
    end
end

-- Puts one section of the account settings back to its defaults
-- ("looks" also resets the low-count threshold).
function CC.ResetSection(key)
    CC.db[key] = CopyDeep(CC.DEFAULTS[key])
    if key == "looks" then CC.db.lowAt = CC.DEFAULTS.lowAt end
end

---------------------------------------------------------
--  SECTION: Helpers
---------------------------------------------------------
-- WoW Forever can hand out "secret" values in combat; they can't be compared or
-- used in maths, so anything read from the game goes through this first.
function CC.Plain(v)
    return v ~= nil and not (issecretvalue and issecretvalue(v))
end

function CC.Print(msg)
    print("|cff33ff99CastCount|r: " .. tostring(msg))
end

local BUILTIN_FONTS = {
    { "Friz Quadrata TT", "Fonts\\FRIZQT__.TTF" },
    { "Arial Narrow",     "Fonts\\ARIALN.TTF" },
    { "Morpheus",         "Fonts\\MORPHEUS.TTF" },
    { "Skurri",           "Fonts\\SKURRI.TTF" },
}
CC.DEFAULT_FONT = BUILTIN_FONTS[1][2]

-- The game's fonts plus any registered with LibSharedMedia (EllesmereUI and others).
function CC.Fonts()
    local list, seen = {}, {}
    for _, f in ipairs(BUILTIN_FONTS) do
        list[#list + 1] = { name = f[1], path = f[2] }
        seen[f[1]] = true
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        for _, name in ipairs(LSM:List("font") or {}) do
            if not seen[name] then
                seen[name] = true
                list[#list + 1] = { name = name, path = LSM:Fetch("font", name) }
            end
        end
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

-- Bar textures: plain colour plus any LibSharedMedia status bar textures.
function CC.BarTextures()
    local list = { { name = "Solid", path = "Interface\\Buttons\\WHITE8X8" } }
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        for _, name in ipairs(LSM:List("statusbar") or {}) do
            list[#list + 1] = { name = name, path = LSM:Fetch("statusbar", name) }
        end
    end
    return list
end

function CC.BarTexturePath(name)
    for _, t in ipairs(CC.BarTextures()) do
        if t.name == name then return t.path end
    end
    return "Interface\\Buttons\\WHITE8X8"
end

function CC.FontPath(name)
    for _, f in ipairs(CC.Fonts()) do
        if f.name == name then return f.path end
    end
    return CC.DEFAULT_FONT
end

-- Can this font draw this text? A character a font doesn't have comes out as nothing,
-- or as the same "missing" box every unknown character gets, so the text is measured
-- against a private-use character (U+E000) that no font draws. Plain ASCII always works.
CC.SAFE_FONT = "Fonts\\ARIALN.TTF"   -- has the infinity sign
local probe
local drawable = {}
local MISSING = "\238\128\128"
function CC.FontCanDraw(path, text)
    if not text or text == "" or not text:find("[\128-\255]") then return true end
    local key = path .. "|" .. text
    if drawable[key] then return true end
    if not probe then
        probe = UIParent:CreateFontString(nil, "OVERLAY")
        probe:Hide()
    end
    probe:SetFont(path, 20, "")
    if not probe:GetFont() then return false end
    probe:SetText(text)
    local width = probe:GetStringWidth() or 0
    local chars = select(2, text:gsub("[^\128-\191]", ""))
    probe:SetText(MISSING:rep(chars))
    local missing = probe:GetStringWidth() or 0
    local ok = width > 0.5 and math.abs(width - missing) > 0.5
    if ok then drawable[key] = true end
    return ok
end

-- The font file for a look showing text; falls back to Arial Narrow when the
-- look's font can't draw it (the Free look's infinity sign).
function CC.LookFontPath(look, text)
    local path = CC.FontPath(look.font)
    if text and not CC.FontCanDraw(path, text) then return CC.SAFE_FONT end
    return path
end

---------------------------------------------------------
--  SECTION: Events
---------------------------------------------------------
-- Registering an event the client doesn't have throws, so every event is
-- checked first and quietly skipped when missing.
local eventFrame = CreateFrame("Frame")
local handlers = {}

function CC.On(event, fn)
    if not handlers[event] then
        if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event) then
            return false
        end
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then return false end
        handlers[event] = {}
    end
    table.insert(handlers[event], fn)
    return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for _, fn in ipairs(list) do fn(event, ...) end
end)

local readyCallbacks = {}
-- Runs fn once the saved settings are loaded.
function CC.OnReady(fn)
    if CC.db then fn() else readyCallbacks[#readyCallbacks + 1] = fn end
end

CC.On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    CastCountDB = CastCountDB or {}
    Migrate(CastCountDB)
    FillDefaults(CastCountDB, CC.DEFAULTS)
    CC.db = CastCountDB
    CastCountCharDB = CastCountCharDB or {}
    FillDefaults(CastCountCharDB, CC.CHAR_DEFAULTS)
    CC.char = CastCountCharDB
    for _, fn in ipairs(readyCallbacks) do fn() end
    wipe(readyCallbacks)
end)

---------------------------------------------------------
--  SECTION: Slash commands
---------------------------------------------------------
SLASH_CASTCOUNT1 = "/castcount"
SLASH_CASTCOUNT2 = "/ccount"
SLASH_CASTCOUNT3 = "/cc"
SlashCmdList.CASTCOUNT = function(msg)
    if (msg or ""):lower():match("^%s*debug") then
        if CC.Debug then CC.Debug() end
        return
    end
    if CC.ToggleConfig then CC.ToggleConfig() end
end

-- /cc normally opens the game's click casting window. Take it over: drop every
-- other list's /cc and point the chat lookup at ours.
local function ClaimCC()
    for key, value in pairs(_G) do
        if type(key) == "string" and type(value) == "string" and value:lower() == "/cc"
            and key:find("^SLASH_") and not key:find("^SLASH_CASTCOUNT") then
            _G[key] = nil
        end
    end
    if hash_SlashCmdList then hash_SlashCmdList["/CC"] = SlashCmdList.CASTCOUNT end
end
CC.On("PLAYER_LOGIN", ClaimCC)
