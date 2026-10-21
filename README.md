# CastCount

A World of Warcraft addon for WoW Forever (and the Classic beta) that shows how many times you can cast each spell with your current mana, right on the action buttons you choose. Pick your buttons, style the count, fill the button as mana comes back, and set up WeakAuras-style conditions that glow, pulse, recolour or warn you as your casts run low.

## Features
- **Cast counts on your buttons:** current mana divided by the spell's cost, updated as you regenerate and spend. Works with spells cast from macros, and with every rank of a spell.
- **Choose your buttons like key binding mode:** click a button to add or remove it, hold Shift for its whole bar. Works with Blizzard's action bars and EllesmereUI.
- **Four looks:** Default, Low (you set the threshold), Out of mana and Free (an infinity sign when a spell that normally costs mana costs nothing). Each has its own font (LibSharedMedia fonts too), size, outline, shadow, colour, position and X/Y offset, with clickable previews.
- **ManaFill:** when you can't afford a spell, its button fills from the bottom up as your mana returns, so you can see how close the next cast is. Colour, transparency and texture are up to you.
- **Conditions:** as many as you like. **If** casts left, mana %, the spell being zero cost, being in combat or hovering the button, joined with and/or. **Then** change the count's colour, transparency, size, position or text, hide or pulse it, glow the button (action button, pixel, autocast, proc or simple border), tint it, play a sound or print a chat message.
- **Visibility:** show in combat, out of combat and on mouse over; hide on full mana. Counts can fade away when they hide (you pick how fast) and always appear instantly.
- **Blacklist:** spells that should never show a count, picked from your spellbook and bars.
- Your buttons and blacklist are saved per character; looks, conditions and visibility are account-wide.

## Using it
- `/cc` (or `/castcount`, `/ccount`), the minimap button, the addon list button or Options > AddOns > CastCount opens the settings.
- **Buttons:** Choose buttons (or `/cc buttons`) opens CastCount Button Mode, like Quick Keybind Mode: Click adds/removes CastCount on an action button, Shift+Click on a whole bar; selected buttons are green. Okay keeps your changes, Cancel undoes them.
- **Blacklist, Appearance, Visibility, Conditions:** everything above.
- `/cc debug` prints what the game reports for mana and spell costs.

WoW Forever hides your current mana from addons, so CastCount hands the game curves to work out the count, colours, conditions and ManaFill. Sounds and chat messages can only follow checks CastCount can see itself (zero cost, in combat, mouse over).

Includes LibStub, CallbackHandler, LibDataBroker, LibDBIcon and LibCustomGlow-1.0 (MIT licence, see Libs).

Originally released for Season of Discovery as ManaCastCount.
