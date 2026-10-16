# Changelog

## 2.0.0
A full redesign for WoW Forever.
- **Choose your buttons like key binding mode.** `/castcount` opens the settings; on the Buttons tab every action button is covered. Left-click adds a button, Shift + left-click adds its whole bar, right-click removes, Shift + right-click removes the bar.
- Works with Blizzard's action bars and EllesmereUI's.
- **Blacklist:** two columns. Your known spells (spellbook plus anything on your bars) on the left with search and filters, the blacklist on the right; move spells with the arrows or a double-click. Blacklisting covers every rank.
- **Text:** font (including LibSharedMedia fonts), size, outline, shadow, colour, position and nudge.
- **Visibility:** in combat, out of combat (optionally only when mana isn't full), and on mouse-over. Macros that cast a spell can be counted too.
- **Rules:** show nothing or custom text for free spells; colour changes at low counts (up to 5 thresholds).
- Button choice and blacklist are saved per character; look and visibility are account-wide.
- Uses Forever's C_Spell / C_SpellBook APIs and copes with values the game hides in combat.

## 1.0.0
- Imported from ManaCastCount (Season of Discovery) and rebranded as CastCount for WoW Forever.
- No code changes yet beyond the rename; the Forever API port is still to come.
