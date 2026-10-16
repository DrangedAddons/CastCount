# Changelog

## 2.0.0
A full redesign for WoW Forever.
- **Choose your buttons like key binding mode.** `/cc` (or `/castcount`) opens the settings; on the Buttons tab every action button is covered. Click a button to add it and click again to remove it; hold Shift for the whole bar. The hover highlight shows what the click will do: white-blue adds, red removes.
- Works with Blizzard's action bars and EllesmereUI's.
- **Blacklist:** two columns. Your known spells (spellbook plus anything on your bars) on the left with search and filters, the blacklist on the right; move spells with the arrows or a double-click. Blacklisting covers every rank.
- **Text:** four looks (Normal, Low count, Out of mana, Free right now), each with its own font (including LibSharedMedia fonts), size, outline, shadow, colour, position and X/Y offset. Pick one from the dropdown or click its preview button. The < > arrows nudge by 1 (Shift 5, Ctrl 10). "Free right now" is for a mana spell that costs nothing at the moment (Clearcasting and the like) and shows an infinity sign.
- **Visibility:** in combat, out of combat (optionally only when mana isn't full), and on mouse-over. Macros that cast a spell can be counted too.
- **Conditions:** WeakAuras-style cards, as many as you like. **If** one or more checks (Casts left, Mana %, Spell is free right now, In combat, Mouse over the button; all or any of them) **then** one or more changes: count colour, transparency, size, position, replacement text, hide, pulse, button glow (action button, pixel, autocast, proc or simple border, via LibCustomGlow), button tint, a sound or a chat message only you see. Cards collapse, move up and down, copy and delete. Sounds and chat messages only follow checks CastCount can see (Forever hides your mana from addons).
- Button choice and blacklist are saved per character; look and visibility are account-wide.
- Uses Forever's C_Spell / C_SpellBook APIs. Forever hides your current mana from addons, so counts, looks and conditions are worked out by the game through curves.
- `/cc debug` prints what the game reports for mana and costs.

## 1.0.0
- Imported from ManaCastCount (Season of Discovery) and rebranded as CastCount for WoW Forever.
- No code changes yet beyond the rename; the Forever API port is still to come.
