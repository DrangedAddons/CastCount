---------------------------------------------------------
--  CastCount - Spells
--  Author: Dranged
---------------------------------------------------------
-- Spell names, icons, costs, and the list of spells you know (for the blacklist).

local ADDON, CC = ...
local Plain = CC.Plain

---------------------------------------------------------
--  SECTION: Spell info
---------------------------------------------------------
function CC.SpellName(id)
    if not Plain(id) then return nil end
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end

function CC.SpellIcon(id)
    if not Plain(id) then return nil end
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    return GetSpellInfo and select(3, GetSpellInfo(id))
end

local function IsPassive(id)
    if C_Spell and C_Spell.IsSpellPassive then return C_Spell.IsSpellPassive(id) end
    return IsPassiveSpell and IsPassiveSpell(id)
end

---------------------------------------------------------
--  SECTION: Spell cost
---------------------------------------------------------
local GetCosts = (C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
local lastCost = {}   -- spellID -> { kind, amount }, the last plain answer

-- Returns "mana", cost / "free", 0 / "other", 0 (costs rage, energy...) / nil (unknown).
-- When the game hides the cost (a secret value in combat), the last plain answer is used.
function CC.SpellCost(spellID)
    if not Plain(spellID) or not GetCosts then return nil end
    local costs = GetCosts(spellID)
    if type(costs) ~= "table" then return nil end
    local kind, amount = "free", 0
    for _, c in ipairs(costs) do
        local t, cost, pct = c.type, c.cost, c.costPercent
        if not (Plain(t) and Plain(cost)) then
            local prev = lastCost[spellID]
            if prev then return prev[1], prev[2] end
            return nil
        end
        if t == CC.MANA then
            if cost == 0 and Plain(pct) and pct and pct > 0 then
                local max = UnitPowerMax("player", CC.MANA)
                if Plain(max) then cost = math.floor(max * pct / 100) end
            end
            if cost > 0 then
                kind, amount = "mana", cost
                CC.everMana = CC.everMana or {}
                CC.everMana[spellID] = true
                break
            end
        elseif cost > 0 then
            kind = "other"
        end
    end
    local prev = lastCost[spellID]
    if prev then
        prev[1], prev[2] = kind, amount
    else
        lastCost[spellID] = { kind, amount }
    end
    return kind, amount
end

---------------------------------------------------------
--  SECTION: Action slots
---------------------------------------------------------
-- The spell an action slot casts: a spell, or (when allowed) the spell a macro casts.
function CC.ActionSpell(slot)
    if not slot or not HasAction(slot) then return nil end
    local kind, id, sub = GetActionInfo(slot)
    if not Plain(id) then return nil end
    if kind == "spell" then return id end
    if kind == "macro" and CC.db.show.macros then
        if sub == "spell" and type(id) == "number" then return id end
        if GetMacroSpell then
            local sid = GetMacroSpell(id)
            if Plain(sid) then return sid end
        end
    end
    return nil
end

---------------------------------------------------------
--  SECTION: Known spells
---------------------------------------------------------
-- Every non-passive spell in your spellbook plus anything on an action slot, one
-- entry per name (Forever lists each rank separately; the blacklist covers all ranks).
-- Entry: { name, id, icon, mana = costs mana, onBars = on an action slot }.
function CC.KnownSpells()
    local byName, list = {}, {}
    local function add(id, onBars)
        if not Plain(id) then return end
        local name = CC.SpellName(id)
        if not name then return end
        local e = byName[name]
        if not e then
            e = { name = name, id = id, icon = CC.SpellIcon(id) }
            byName[name] = e
            list[#list + 1] = e
        end
        if onBars then e.onBars = true end
        if not e.mana and CC.SpellCost(id) == "mana" then e.mana = true end
    end

    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and Enum and Enum.SpellBookSpellBank then
        local bank = Enum.SpellBookSpellBank.Player
        for tab = 1, C_SpellBook.GetNumSpellBookSkillLines() or 0 do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(tab)
            if info and not info.shouldHide and not (info.offSpecID and info.offSpecID ~= 0) then
                local offset = info.itemIndexOffset or 0
                for i = offset + 1, offset + (info.numSpellBookItems or 0) do
                    local t, actionID, spellID = C_SpellBook.GetSpellBookItemType(i, bank)
                    if t == Enum.SpellBookItemType.Spell then
                        local id = spellID or actionID
                        if Plain(id) and not IsPassive(id) then add(id) end
                    end
                end
            end
        end
    elseif GetNumSpellTabs then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, num = GetSpellTabInfo(tab)
            for i = offset + 1, offset + num do
                local t, id = GetSpellBookItemInfo(i, BOOKTYPE_SPELL or "spell")
                if t == "SPELL" and not IsPassive(id) then add(id) end
            end
        end
    end

    for slot = 1, 180 do
        add(CC.ActionSpell(slot), true)
    end

    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end
