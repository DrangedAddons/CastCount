# Changelog

## 2.0.0
A full redesign for WoW Forever.
- **Choose your buttons like key binding mode.** `/cc` (or `/castcount`) opens the settings; on the Buttons tab every action button is covered. Click a button to add it and click again to remove it; hold Shift for the whole bar. The hover highlight shows what the click will do: white-blue adds, red removes.
- Works with Blizzard's action bars and EllesmereUI's.
- **Blacklist:** two columns. Your known spells (spellbook plus anything on your bars) on the left with search and filters, the blacklist on the right; move spells with the arrows or a double-click. Blacklisting covers every rank.
- **Text:** three looks (Normal, Low count, Out of mana), each with its own font (including LibSharedMedia fonts), size, outline, shadow, colour, position and nudge. Pick one from the dropdown or click its preview button; you set the Low count threshold there.
- **Visibility:** in combat, out of combat (optionally only when mana isn't full), and on mouse-over. Macros that cast a spell can be counted too.
- **Conditions:** as many as you like, in a scrolling list: If <casts left / mana % / in combat / spell costs no mana> <is below / at most / is / is not / at least / above> <value> then <change colour / hide the count / glow the button / pulse the count / play a sound>. Sounds only follow In combat and Spell costs no mana. Free spells can show custom text.
- Button choice and blacklist are saved per character; look and visibility are account-wide.
- Uses Forever's C_Spell / C_SpellBook APIs. Forever hides your current mana from addons, so counts, looks and conditions are worked out by the game through curves.
- `/cc debug` prints what the game reports for mana and costs.

## 1.0.0
- Imported from ManaCastCount (Season of Discovery) and rebranded as CastCount for WoW Forever.
- No code changes yet beyond the rename; the Forever API port is still to come.
