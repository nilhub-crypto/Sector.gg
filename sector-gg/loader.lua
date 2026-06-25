-- Sector.gg Universal Loader
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/nilhub-crypto/Sector.gg/refs/heads/main/sector-gg/loader.lua"))()

local GITHUB_RAW = "https://raw.githubusercontent.com/nilhub-crypto/Sector.gg/refs/heads/main/sector-gg"

local function fetch(url)
    local ok, res = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and res and res ~= "" then return res end
    return nil
end

local gameId = tostring(game.PlaceId)
local configUrl = GITHUB_RAW .. "/games/" .. gameId .. "/config.json"
local configRaw = fetch(configUrl)

if not configRaw then
    warn("[Sector.gg] No config found for game ID: " .. gameId)
    return
end

local HttpService = game:GetService("HttpService")
local config = HttpService:JSONDecode(configRaw)

local guiUrl = GITHUB_RAW .. "/core/gui.lua"
local guiSource = fetch(guiUrl)
if not guiSource then warn("[Sector.gg] Failed to load GUI engine") return end

local gui = loadstring(guiSource)()
gui:Init(config, GITHUB_RAW .. "/games/" .. gameId)