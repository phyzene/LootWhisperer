# Changelog

## v1.0.0

### Features
- Added "My class" checkbox directly in the loot frame header — toggle it to instantly filter the list to only items your class/spec can use, no need to open settings

### Fixes
- BoP dungeon and raid drops now show up in the loot frame when inside an instance (they're tradeable via the personal loot trade window) — filtered out in the overworld where they can't be traded
- Warband-bound (WuE) and account-bound items are always filtered out since they can't be traded to other players

## v0.0.1

### Features
- Initial release
- Track non-soulbound items looted by party/raid members via CHAT_MSG_LOOT
- Scrollable, draggable frame with item icons, class-colored names, and item links
- Click any entry to open a whisper to the looter
- Hover entries for full item tooltips
- Auto-show frame when new qualifying loot drops
- Configurable minimum quality filter (defaults to Uncommon/green+)
- "Only show usable items" option in Blizzard Settings panel
- Slash commands: /lw show, hide, clear, config, test
- Embedded Ace3 libraries (AceAddon, AceEvent, AceConsole)
- CurseForge packaging script (package.sh)
