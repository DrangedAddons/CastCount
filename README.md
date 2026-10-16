# CastCount

A World of Warcraft addon for WoW Forever that shows how many times you can cast each spell with your current mana, right on the action buttons you choose.

## Using it
- `/cc` (or `/castcount`, `/ccount`, the addon list button, or Options > AddOns > CastCount) opens the settings.
- **Buttons:** while this tab is open your action buttons are covered, like key binding mode. Click a button to add or remove it; hold Shift for the whole bar. White-blue highlight = the click adds, red = it removes.
- **Blacklist:** spells that should never show a count.
- **Appearance:** the Normal, Low count, Out of mana and Free right now looks, and ManaFill (the button fills up as mana returns when you can't afford a spell); click a preview to edit it.
- **Visibility:** when counts show.
- **Conditions:** If <casts left / mana % / ...> then glow, pulse, recolour, resize, move, tint, hide, play a sound...

Works with Blizzard's action bars and EllesmereUI.

A minimap button opens the settings too.

Includes LibStub, CallbackHandler, LibDataBroker, LibDBIcon and LibCustomGlow-1.0 (MIT licence, see Libs).

Originally released for Season of Discovery as ManaCastCount.
