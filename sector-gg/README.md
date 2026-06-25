# Sector.gg Script Hub

## Repo structure

```
sector-gg/
├── loader.lua                        ← the ONE loadstring users run
├── core/
│   └── gui.lua                       ← GUI engine (never touch this normally)
└── games/
    └── {PlaceId}/
        ├── config.json               ← edit this to add tabs & buttons
        └── {TabName}/
            └── {Button_Name}.lua     ← one file per button
```

## How to add a new game

1. Create folder `games/{PlaceId}/`
2. Add `config.json` (copy from existing game, edit tab/button names)
3. Add `.lua` files for each button inside `games/{PlaceId}/{TabName}/`
4. Push to GitHub — the GUI updates automatically for all users

## How to add a new tab or button

Edit `config.json` — no other file needs changing.  
Button name in the JSON must match the filename (spaces → underscores).

```json
{ "name": "Kill Aura", "desc": "Attack in range", "type": "toggle" }
```
→ file: `Combat/Kill_Aura.lua`

## The one loadstring

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USER/sector-gg/main/loader.lua"))()
```

## Button types

| type     | behavior                              |
|----------|---------------------------------------|
| toggle   | on/off switch, runs script on enable  |
| execute  | one-shot run button (▶)               |

## Coming soon
- Key system / premium tier
- Discord role verification
- Per-user settings saved to GitHub Gist
