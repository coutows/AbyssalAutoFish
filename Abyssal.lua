--==================================================
-- ABYSSAL AUTOFISH | V7.4
-- UI simplificada + historico de raridade
--==================================================

local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Config = {
    Enabled = false,
    AutoCast = true,
    AutoReel = true,
    QuickCast = true,
    AutoRetry = true,
    ScanInterval = 0.045,
    ObjectRefresh = 0.65,
    TargetRefresh = 0.12,
    CastDelay = 0.55,
    KeyDelay = 0.018,
    ClickCooldown = 0.055,
    ArcTolerance = 43,
    RadiusTolerance = 0.32,
    HistoryLimit = 10,
    SellThreshold = 100,
    RarityFilter = {
        Epic = true,
        Mythical = true,
        Legendary = true,
        Common = true,
        Uncommon = true,
    },
}

local State = {
    LastScan = 0,
    LastCast = 0,
    LastPress = 0,
    LastObjectRefresh = 0,
    LastTargetRefresh = 0,
    LastBackpackRead = 0,
    LastBackpackCount = nil,
    LastMinigameSeen = 0,
    CastPending = false,
    Fishing = false,
    CachedFishButton = nil,
    CachedFishingGui = nil,
    GuiObjects = {},
    GreenObjects = {},
    CircleCenter = nil,
    CircleRadius = nil,
    PreviousPositions = {},
    ClickedBalls = setmetatable({}, {__mode = "k"}),
    FishCaught = 0,
    Hits = 0,
    History = {},
    SeenCatchMessages = {},
    StartedAt = os.clock(),
    SavedFarmPosition = nil,
    PausedForSell = false,
    CurrentBackpack = 0,
    BackpackCapacity = 150,
}

--==================================================
-- GUI
--==================================================

pcall(function()
    local hui = gethui and gethui()
    local old = (hui and hui:FindFirstChild("AbyssalAutoFish"))
        or CoreGui:FindFirstChild("AbyssalAutoFish")
    if old then old:Destroy() end
end)

local GUI = Instance.new("ScreenGui")
GUI.Name = "AbyssalAutoFish"
GUI.ResetOnSpawn = false
GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
GUI.Parent = (gethui and gethui()) or CoreGui

local Panel = Instance.new("Frame")
Panel.Name = "Main"
Panel.Size = UDim2.fromOffset(360, 475)
Panel.Position = UDim2.new(0, 28, 0.18, 0)
Panel.BackgroundColor3 = Color3.fromRGB(13, 19, 29)
Panel.BorderSizePixel = 0
Panel.Active = true
Panel.Draggable = true
Panel.Parent = GUI

local function corner(obj, radius)
