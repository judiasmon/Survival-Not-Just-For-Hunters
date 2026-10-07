# Survival: Not Just For Hunters

A WoW Forever addon that adds hunger and thirst survival meters.

## Features

- Hunger and thirst gradually decrease over time.
- At Normal difficulty, hunger takes 180 minutes and thirst 150 minutes to deplete from full with no modifiers. The settings slider offers Casual (50%), Normal (100%), and Hardcore (200%) need depletion rates.
- Fatigue takes about eight hours to deplete at normal hunger and thirst, drains faster when either need is below 25%, and recovers fully in about five minutes in WoW resting areas.
- Logging out in a WoW resting area restores fatigue to full when logging back in.
- Eating or drinking refills its meter at 100% divided by the buff duration, capped at 100%.
- The Well Fed buff halves hunger and thirst depletion.
- Unmounted movement and combat each double hunger and thirst depletion, but do not stack because movement cannot be detected reliably during combat.
- Mapped cold zones increase hunger depletion, while warm zones increase thirst depletion. Searing Gorge, Burning Steppes, and most of Stranglethorn Vale are hot; Booty Bay is warm. The temperature gauge runs from cold on the left through neutral to hot on the right; indoor areas are neutral.
- Hunger, thirst, or fatigue reaching 10%, 5%, and 0% plays the mapped race- and gender-specific low-energy sound when available. At zero on any of those meters, a race- and gender-specific cry sound plays immediately and every 10 seconds until all recover above zero. Unmapped low-energy voices are reported in `/survival debug`.
- Settings open from the minimap button or with `/survival` or `/snjh`.
- Settings include a Statistics tab tracking eating/drinking sessions, resting time, time below 25% hunger or thirst, and the most recent eating/drinking times.
- `/survival debug` opens a live diagnostics window with auras, need drain rates, and active modifiers.
- The addon pauses survival updates and hides its bars in dungeons, raids, battlegrounds, and arenas by default; this can be changed in settings.
- Press Escape to close settings. The status bars can be dragged to reposition them.
- Settings and survival values are saved between sessions.

## Temperature map

Temperature is checked from the current zone and subzone. Dun Morogh and
Winterspring are cold; Alterac Mountains, Hillsbrad Foothills, both
Plaguelands, and The Hinterlands are cool. The Barrens, Badlands, Blasted Lands,
Un'Goro Crater, and Silithus are warm; Searing Gorge, Burning Steppes, and most
of Stranglethorn Vale are hot; Tanaris is hot. Booty Bay, Ironforge, Everlook,
Ratchet, The Crossroads, Gadgetzan, Steamwheedle Port, and Caverns of Time have
specific subzone overrides. Indoor areas are neutral. Unmapped locations
default to neutral.

Each temperature level increases the relevant drain by 20%: cold and cool
affect hunger, while warm and hot affect thirst. The gauge marker changes color
by level, from dark blue at cold through green at neutral to red at hot. Its
scale is labeled Cold at the left and Hot at the right.

## Statistics

The Statistics settings tab saves food and drink session counts, time spent
resting, time spent below 25% hunger or thirst, and the timestamps of the
latest eating and drinking sessions. Time totals are accumulated during active
play only and pause in disabled instances.

## Fatigue

Fatigue depletes over about eight hours at normal hunger and thirst. If either
need drops below 25%, fatigue drains faster, up to four times the normal rate
when a need reaches zero. It recovers fully in about five minutes in a WoW
resting area.

Fatigue recovery currently uses WoW's resting-area API. General proximity to a
cooking fire is not exposed as a player buff, so campsite recovery is not
included yet.

## Install

Copy the `SurvivalNotJustForHunters` folder into the game's `Interface/AddOns`
directory, then enable the addon from the character selection screen.

The minimap icon can be dragged around the minimap. Use the settings window to
toggle need depletion or hide the status bars.

## Module layout

- `Survival.lua` initializes saved settings and handles addon lifecycle events.
- `Auras.lua` detects eating, drinking, and Well Fed auras.
- `Temperature.lua` maps selected zones and subzones to a temperature level and treats indoor areas as neutral.
- `Needs.lua` calculates recovery and depletion rates, including temperature effects.
- `Fatigue.lua` manages fatigue depletion and resting-area recovery.
- `Feedback.lua` plays race- and gender-specific low-need and cry sounds.
- `Statistics.lua` tracks saved survival activity statistics.
- `Debug.lua` builds the live diagnostics content.
- `Windows.lua` creates settings and diagnostics windows and registers slash commands.
- `UI.lua` creates the status bars and minimap button.
