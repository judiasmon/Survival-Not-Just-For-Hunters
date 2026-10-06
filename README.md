# Survival: Not Just For Hunters

A WoW Forever addon that adds hunger and thirst survival meters.

## Features

- Hunger and thirst gradually decrease over time.
- Eating or drinking refills its meter at 100% divided by the buff duration, capped at 100%.
- The Well Fed buff halves hunger and thirst depletion.
- Unmounted movement and combat each double hunger and thirst depletion; the multipliers stack.
- Settings open from the minimap button or with `/survival` or `/snjh`.
- `/survival debug` opens a live diagnostics window with auras, need drain rates, and active modifiers.
- Press Escape to close settings. The status bars can be dragged to reposition them.
- Settings and survival values are saved between sessions.

## Install

Copy the `SurvivalNotJustForHunters` folder into the game's `Interface/AddOns`
directory, then enable the addon from the character selection screen.

The minimap icon can be dragged around the minimap. Use the settings window to
toggle need depletion or hide the status bars.
