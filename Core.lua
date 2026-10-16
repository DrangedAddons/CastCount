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
-- Account-wide: how the numbers look and when they show.
CC.DEFAULTS = {
    text = {
        font = "Friz Quadrata TT", size = 18, outline = "OUTLINE", shadow = false,
        color = Color(0, 1, 0), anchor = "CENTER", x = 0, y = 0,
    },
    show = {
        inCombat = true, outOfCombat = true, oocOnlyNotFull = false,
        onHover = true, macros = true,
    },
    free = { mode = "hide", text = "Free", color = Color(0.4, 0.8, 1) },
    rules = {
        enabled = true,
        list = {
            { at = 0, color = Color(1, 0.2, 0.2) },
            { at = 3, color = Color(1, 0.65, 0) },
        },
    },
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

-- Fills missing keys. Lists (rules.list) are copied whole only when missing,
-- so a user who removed the default rules doesn't get them back.
local function FillDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = CopyDeep(v)
        elseif type(v) == "table" and type(dst[k]) == "table" and v[1] == nil then
            FillDefaults(dst[k], v)
        end
    end
end

-- Puts one section of the account settings (text, show, free, rules) back to its defaults.
function CC.ResetSection(key)
    CC.db[key] = CopyDeep(CC.DEFAULTS[key])
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

function CC.FontPath(name)
    for _, f in ipairs(CC.Fonts()) do
        if f.name == name then return f.path end
    end
    return CC.DEFAULT_FONT
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
SlashCmdList.CASTCOUNT = function()
    if CC.ToggleConfig then CC.ToggleConfig() end
end
