# Changelog

## 2.4.0
- **Fade count on hide** (Visibility tab, on by default): when a count is hidden by your visibility settings (leaving or entering combat, moving the mouse off a button) it fades away instead of vanishing. A slider sets the fade time (0.1 to 3 seconds). Counts still appear instantly. "Only when my mana isn't full" can't fade, since Forever hides your mana.

## 2.3.0
- **CastCount Button Mode**, like the game's Quick Keybind Mode: the Buttons tab's **Choose buttons** (or `/cc buttons`) closes the settings, covers your action buttons and shows a popup with the controls. **Okay** keeps your changes, **Add All** adds every action button on screen, **Remove All** clears them, **Cancel** or Escape undoes everything since you opened it. The Buttons tab itself no longer covers your bars.
- Buttons tab redone: a short description at the top, the controls in a panel, and Choose buttons centred below. Add every button and Remove all moved into the Button Mode popup (Add All / Remove All).

## 2.2.2
- Conditions: click anywhere on a card's title bar (not just the + / -) to expand or collapse it.
- The title bar has its own slightly lighter background, with a thin gold line under it while the card is open.

## 2.2.1
- Looks renamed: **Default** (was Normal), **Low**, **Out of mana** and **Free** (was Free right now). The matching condition check is **Zero cost**: any spell that normally costs mana and costs nothing at the moment, whatever the reason.
- The Appearance tab's title says what you're editing: "Edit look style : Default", "Edit ManaFill" and so on. Copy Normal is now Copy Default.
- The Free look always shows the infinity sign (no longer editable), drawn properly in the settings too.
- X/Y offset: the value sits in a box centred under each bar; click it and type to replace it (Enter keeps it, Escape puts the old one back). The arrows' tooltip explains Shift and Ctrl. Clicking any number box now selects its value.

## 2.2.0
- Appearance: **Apply to all** gives every other look the current look's font, size, outline, shadow and position; each keeps its own colour (and Free keeps its text). Asks first.
- Copy Normal no longer wipes the Free look's text.
- The Free look only offers fonts that can draw its text (the infinity sign): CastCount tests each font. Copies and Apply to all leave Free on a font that can, and the buttons fall back to Arial Narrow if one still can't.
- Appearance: a title names the look you're editing, the selected preview gets a gold frame, and **Reset this look** (next to Reset all looks) resets just that one.

## 2.1.0
- Minimap button (LibDBIcon, so minimap addons can collect it): click to open the settings, drag to move. Turn it off on the Visibility tab.
- Addon icon for the DrangedAddons manager.

## 2.0.0
A full redesign for WoW Forever.
- **Choose your buttons like key binding mode.** `/cc` (or `/castcount`) opens the settings; on the Buttons tab every action button is covered. Click a button to add it and click again to remove it; hold Shift for the whole bar. The hover highlight shows what the click will do: white-blue adds, red removes.
- Works with Blizzard's action bars and EllesmereUI's.
- **Blacklist:** two columns. Your known spells (spellbook plus anything on your bars) on the left with search and filters, the blacklist on the right; move spells with the arrows or a double-click. Blacklisting covers every rank.
- **Appearance** (was Text): four looks (Normal, Low count, Out of mana, Free right now), each with its own font (including LibSharedMedia fonts), size, outline, shadow, colour, position and X/Y offset. Pick one from the dropdown or click its preview button. The < > arrows nudge by 1 (Shift 5, Ctrl 10). "Free right now" is for a mana spell that costs nothing at the moment (Clearcasting and the like) and shows an infinity sign.
- **ManaFill:** while you can't afford a spell, its button fills from the bottom up as your mana comes back (full = enough for one cast). Colour, transparency and texture (LibSharedMedia bars too) on the Appearance tab, with its own preview.
- **Visibility:** in combat, out of combat (optionally only when mana isn't full), and on mouse-over. Macros that cast a spell can be counted too.
- **Conditions:** WeakAuras-style cards, as many as you like. **If** one or more checks (Casts left, Mana %, Spell is free right now, In combat, Mouse over the button), each joined to the last by and / or ("and" binds tighter) **then** one or more changes: count colour, transparency, size, position, replacement text, hide, pulse, button glow (action button, pixel, autocast, proc or simple border, via LibCustomGlow), button tint, a sound or a chat message only you see. Cards are titled Condition 1, 2... or a name you give them, and collapse, move up and down, copy and delete. Sounds and chat messages only follow checks CastCount can see (Forever hides your mana from addons).
- Button choice and blacklist are saved per character; look and visibility are account-wide.
- Uses Forever's C_Spell / C_SpellBook APIs. Forever hides your current mana from addons, so counts, looks and conditions are worked out by the game through curves.
- `/cc debug` prints what the game reports for mana and costs.

## 1.0.0
- Imported from ManaCastCount (Season of Discovery) and rebranded as CastCount for WoW Forever.
- No code changes yet beyond the rename; the Forever API port is still to come.
