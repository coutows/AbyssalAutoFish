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
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
end

corner(Panel, 14)

local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(35, 210, 150)
outline.Thickness = 1.3
outline.Parent = Panel

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 58)
Header.BackgroundColor3 = Color3.fromRGB(19, 31, 42)
Header.BorderSizePixel = 0
Header.Parent = Panel
corner(Header, 14)
local headerGradient = Instance.new("UIGradient")
headerGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 48, 54)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(17, 27, 42))
})
headerGradient.Rotation = 0
headerGradient.Parent = Header

local panelGradient = Instance.new("UIGradient")
panelGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 27, 39)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 15, 24))
})
panelGradient.Rotation = 90
panelGradient.Parent = Panel

local function label(parent, text, size, color, pos, dims)
    local obj = Instance.new("TextLabel")
    obj.BackgroundTransparency = 1
    obj.Text = text
    obj.TextColor3 = color
    obj.TextSize = size
    obj.Font = Enum.Font.GothamBold
    obj.TextXAlignment = Enum.TextXAlignment.Left
    obj.Position = pos
    obj.Size = dims
    obj.Parent = parent
    return obj
end

local function button(parent, text, pos, dims, color)
    local obj = Instance.new("TextButton")
    obj.Text = text
    obj.Position = pos
    obj.Size = dims
    obj.BackgroundColor3 = color
    obj.TextColor3 = Color3.new(1, 1, 1)
    obj.TextSize = 11
    obj.Font = Enum.Font.GothamBold
    obj.AutoButtonColor = true
    obj.Parent = parent
    corner(obj, 8)
    return obj
end

label(Header, "ABYSSAL", 21, Color3.fromRGB(65, 235, 175),
    UDim2.fromOffset(15, 7), UDim2.fromOffset(190, 25))
label(Header, "AUTOFISH V7.4  |  AUTO SELL LIMIT", 8,
    Color3.fromRGB(145, 165, 180),
    UDim2.fromOffset(17, 34), UDim2.fromOffset(230, 14))

local Minimize = button(Header, "—", UDim2.new(1, -69, 0, 14),
    UDim2.fromOffset(25, 26), Color3.fromRGB(35, 52, 62))
local Close = button(Header, "X", UDim2.new(1, -37, 0, 14),
    UDim2.fromOffset(25, 26), Color3.fromRGB(145, 55, 60))

local StatusCard = Instance.new("Frame")
StatusCard.Position = UDim2.fromOffset(12, 69)
StatusCard.Size = UDim2.new(1, -24, 0, 36)
StatusCard.BackgroundColor3 = Color3.fromRGB(24, 34, 45)
StatusCard.Parent = Panel
corner(StatusCard, 8)
local statusStroke = Instance.new("UIStroke")
statusStroke.Color = Color3.fromRGB(45, 75, 82)
statusStroke.Transparency = 0.45
statusStroke.Thickness = 1
statusStroke.Parent = StatusCard

local Status = label(StatusCard, "● DESLIGADO", 10,
    Color3.fromRGB(220, 90, 90), UDim2.fromOffset(10, 0),
    UDim2.new(1, -20, 1, 0))

local Tabs = Instance.new("Frame")
Tabs.Position = UDim2.fromOffset(12, 114)
Tabs.Size = UDim2.new(1, -24, 0, 32)
Tabs.BackgroundTransparency = 1
Tabs.Parent = Panel

local Content = Instance.new("Frame")
Content.Position = UDim2.fromOffset(12, 154)
Content.Size = UDim2.new(1, -24, 1, -166)
Content.BackgroundTransparency = 1
Content.Parent = Panel

local function makePage()
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Parent = Content

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 7)
    layout.Parent = page
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 8)
    end)
    return page
end

local FishPage = makePage()
local InventoryPage = makePage()
local StatsPage = makePage()
local FilterPage = makePage()
FishPage.Visible = true

local function section(page, text)
    local obj = label(page, text, 11, Color3.fromRGB(65, 220, 165),
        UDim2.fromOffset(5, 0), UDim2.new(1, -10, 0, 23))
    obj.LayoutOrder = #page:GetChildren()
end

local function valueRow(page, name, initial)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -5, 0, 34)
    row.BackgroundColor3 = Color3.fromRGB(24, 34, 45)
    row.Parent = page
    row.LayoutOrder = #page:GetChildren()
    corner(row, 7)

    label(row, name, 10, Color3.fromRGB(160, 180, 195),
        UDim2.fromOffset(10, 0), UDim2.new(0.62, 0, 1, 0))
    local value = label(row, tostring(initial), 11,
        Color3.fromRGB(65, 235, 175), UDim2.new(0.62, 0, 0, 0),
        UDim2.new(0.35, -8, 1, 0))
    value.TextXAlignment = Enum.TextXAlignment.Right
    return value
end

local function optionRow(page, title, key, defaultValue)
    Config[key] = Config[key] == nil and defaultValue or Config[key]

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -5, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(24, 34, 45)
    row.Parent = page
    row.LayoutOrder = #page:GetChildren()
    corner(row, 8)

    label(row, title, 10, Color3.fromRGB(220, 230, 235),
        UDim2.fromOffset(11, 0), UDim2.new(1, -92, 1, 0))

    local toggle = button(row, Config[key] and "ON" or "OFF",
        UDim2.new(1, -68, 0, 5), UDim2.fromOffset(56, 28),
        Config[key] and Color3.fromRGB(25, 145, 100) or Color3.fromRGB(75, 85, 100))

    toggle.Activated:Connect(function()
        Config[key] = not Config[key]
        toggle.Text = Config[key] and "ON" or "OFF"
        toggle.BackgroundColor3 = Config[key]
            and Color3.fromRGB(25, 145, 100)
            or Color3.fromRGB(75, 85, 100)
    end)
    return toggle
end

local function tab(name, x, page)
    local b = button(Tabs, name, UDim2.fromOffset(x, 0),
        UDim2.fromOffset(79, 30), Color3.fromRGB(32, 48, 61))
    b.TextSize = 8
    b.Activated:Connect(function()
        FishPage.Visible = page == FishPage
        InventoryPage.Visible = page == InventoryPage
        StatsPage.Visible = page == StatsPage
        FilterPage.Visible = page == FilterPage
        for _, item in ipairs(Tabs:GetChildren()) do
            if item:IsA("TextButton") then
                item.BackgroundColor3 = item == b
                    and Color3.fromRGB(25, 145, 100)
                    or Color3.fromRGB(32, 48, 61)
            end
        end
    end)
end

tab("PESCA", 0, FishPage)
tab("INVENT.", 83, InventoryPage)
tab("STATS", 166, StatsPage)
tab("FILTROS", 249, FilterPage)
local firstTab = Tabs:FindFirstChildWhichIsA("TextButton")
if firstTab then firstTab.BackgroundColor3 = Color3.fromRGB(25, 145, 100) end

section(FishPage, "CONTROLE")
local MainToggle = button(FishPage, "ATIVAR AUTOFISH",
    UDim2.new(), UDim2.new(1, -5, 0, 39),
    Color3.fromRGB(25, 145, 100))
MainToggle.LayoutOrder = #FishPage:GetChildren()

section(FishPage, "OPCOES DE AUTOMACAO")
optionRow(FishPage, "Auto Cast — arremessar automaticamente", "AutoCast", true)
optionRow(FishPage, "Auto Reel — jogar o minigame", "AutoReel", true)
optionRow(FishPage, "Quick Cast — reduzir espera entre arremessos", "QuickCast", true)
optionRow(FishPage, "Auto Retry — tentar novamente após captura", "AutoRetry", true)

section(InventoryPage, "INVENTARIO")
local BackpackValue = valueRow(InventoryPage, "Mochila", "-- / --")
local FishValue = valueRow(InventoryPage, "Peixes capturados", "0")
local InventoryNote = label(InventoryPage,
    "A contagem usa a quantidade da mochila do jogo.",
    9, Color3.fromRGB(135, 155, 170),
    UDim2.fromOffset(5, 0), UDim2.new(1, -10, 0, 30))
InventoryNote.LayoutOrder = #InventoryPage:GetChildren()

section(InventoryPage, "LIMITE PARA INICIAR A VENDA")
local SellThresholdInfo = label(InventoryPage,
    "Pausar a pesca ao atingir a quantidade escolhida.",
    9, Color3.fromRGB(135, 155, 170),
    UDim2.fromOffset(5, 0), UDim2.new(1, -10, 0, 25))
SellThresholdInfo.LayoutOrder = #InventoryPage:GetChildren()

local ThresholdButtons = {}
local ThresholdStatus = label(InventoryPage,
    "Venda configurada para 100 peixes.",
    9, Color3.fromRGB(65, 220, 165),
    UDim2.fromOffset(5, 0), UDim2.new(1, -10, 0, 30))
ThresholdStatus.LayoutOrder = #InventoryPage:GetChildren()

local ThresholdRow = Instance.new("Frame")
ThresholdRow.Size = UDim2.new(1, -5, 0, 38)
ThresholdRow.BackgroundTransparency = 1
ThresholdRow.Parent = InventoryPage
ThresholdRow.LayoutOrder = #InventoryPage:GetChildren()

local function refreshThresholdButtons()
    for amount, b in pairs(ThresholdButtons) do
        local selected = Config.SellThreshold == amount
        b.BackgroundColor3 = selected
            and Color3.fromRGB(25, 145, 100)
            or Color3.fromRGB(45, 61, 76)
    end
    ThresholdStatus.Text = "Venda configurada para " .. Config.SellThreshold .. " peixes."
end

for index, amount in ipairs({20, 50, 100, 125}) do
    local b = button(ThresholdRow, tostring(amount),
        UDim2.new(0, (index - 1) * 77, 0, 3),
        UDim2.fromOffset(70, 31),
        amount == Config.SellThreshold
            and Color3.fromRGB(25, 145, 100)
            or Color3.fromRGB(45, 61, 76))
    b.Activated:Connect(function()
        Config.SellThreshold = amount
        State.PausedForSell = State.CurrentBackpack >= amount
        refreshThresholdButtons()
    end)
    ThresholdButtons[amount] = b
end
refreshThresholdButtons()

section(StatsPage, "ESTATISTICAS DA SESSAO")
local HitValue = valueRow(StatsPage, "Acertos no minigame", "0")
local TimeValue = valueRow(StatsPage, "Tempo ativo", "00:00")

section(StatsPage, "HISTORICO DE CAPTURAS")
local HistoryFrame = Instance.new("Frame")
HistoryFrame.Size = UDim2.new(1, -5, 0, 245)
HistoryFrame.BackgroundColor3 = Color3.fromRGB(24, 34, 45)
HistoryFrame.Parent = StatsPage
HistoryFrame.LayoutOrder = #StatsPage:GetChildren()
corner(HistoryFrame, 8)

local HistoryText = label(HistoryFrame, "Nenhuma captura detectada.",
    10, Color3.fromRGB(210, 220, 225),
    UDim2.fromOffset(10, 8), UDim2.new(1, -20, 1, -16))
HistoryText.TextYAlignment = Enum.TextYAlignment.Top
HistoryText.TextWrapped = true

--==================================================
-- RARITY FILTERS + FARM WAYPOINT
--==================================================

section(FilterPage, "RARIDADES QUE APARECEM NO HISTORICO")

local rarityLabels = {
    {key = "Epic", label = "Épico"},
    {key = "Mythical", label = "Mítico"},
    {key = "Legendary", label = "Lendário"},
    {key = "Common", label = "Comum"},
    {key = "Uncommon", label = "Incomum"},
}

local function rarityOption(item)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -5, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(24, 34, 45)
    row.Parent = FilterPage
    row.LayoutOrder = #FilterPage:GetChildren()
    corner(row, 8)

    label(row, item.label, 10, Color3.fromRGB(220, 230, 235),
        UDim2.fromOffset(11, 0), UDim2.new(1, -92, 1, 0))

    local toggle = button(row, Config.RarityFilter[item.key] and "MOSTRAR" or "OCULTAR",
        UDim2.new(1, -86, 0, 5), UDim2.fromOffset(75, 28),
        Config.RarityFilter[item.key] and Color3.fromRGB(25, 145, 100)
            or Color3.fromRGB(75, 85, 100))

    toggle.Activated:Connect(function()
        Config.RarityFilter[item.key] = not Config.RarityFilter[item.key]
        toggle.Text = Config.RarityFilter[item.key] and "MOSTRAR" or "OCULTAR"
        toggle.BackgroundColor3 = Config.RarityFilter[item.key]
            and Color3.fromRGB(25, 145, 100)
            or Color3.fromRGB(75, 85, 100)
    end)
end

for _, item in ipairs(rarityLabels) do
    rarityOption(item)
end

local filterNote = label(FilterPage,
    "As opções controlam quais capturas entram no histórico. Elas não alteram a raridade gerada pelo jogo.",
    9, Color3.fromRGB(135, 155, 170),
    UDim2.fromOffset(5, 0), UDim2.new(1, -10, 0, 42))
filterNote.TextWrapped = true
filterNote.LayoutOrder = #FilterPage:GetChildren()

section(FilterPage, "PONTO DE FARM")

local savePositionButton = button(FilterPage, "SALVAR POSIÇÃO ATUAL",
    UDim2.new(), UDim2.new(1, -5, 0, 36), Color3.fromRGB(25, 115, 145))
savePositionButton.LayoutOrder = #FilterPage:GetChildren()

local savedPositionLabel = label(FilterPage, "Nenhuma posição salva nesta sessão.",
    9, Color3.fromRGB(175, 195, 205),
    UDim2.fromOffset(5, 0), UDim2.new(1, -10, 0, 38))
savedPositionLabel.TextWrapped = true
savedPositionLabel.LayoutOrder = #FilterPage:GetChildren()

local copyPositionButton = button(FilterPage, "COPIAR COORDENADAS",
    UDim2.new(), UDim2.new(1, -5, 0, 34), Color3.fromRGB(45, 75, 95))
copyPositionButton.LayoutOrder = #FilterPage:GetChildren()

local waypointNote = label(FilterPage,
    "O ponto salvo serve como referência. O retorno por teleporte precisa ser feito por uma função oficial do próprio jogo; este script não força teleporte pelo executor.",
    9, Color3.fromRGB(135, 155, 170),
    UDim2.fromOffset(5, 0), UDim2.new(1, -10, 0, 55))
waypointNote.TextWrapped = true
waypointNote.LayoutOrder = #FilterPage:GetChildren()

savePositionButton.Activated:Connect(function()
    local character = Player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        savedPositionLabel.Text = "Personagem ainda não está disponível."
        return
    end

    local pos = root.Position
    State.SavedFarmPosition = Vector3.new(pos.X, pos.Y, pos.Z)
    savedPositionLabel.Text = string.format(
        "Posição salva: X %.1f | Y %.1f | Z %.1f",
        pos.X, pos.Y, pos.Z
    )
end)

copyPositionButton.Activated:Connect(function()
    local pos = State.SavedFarmPosition
    if not pos then
        savedPositionLabel.Text = "Salve uma posição antes de copiar."
        return
    end

    local coords = string.format("X=%.2f, Y=%.2f, Z=%.2f", pos.X, pos.Y, pos.Z)
    if setclipboard then
        setclipboard(coords)
        savedPositionLabel.Text = "Coordenadas copiadas: " .. coords
    else
        savedPositionLabel.Text = coords
    end
end)

--==================================================
-- INPUT / UTILITIES
--==================================================

local function pressKey(key)
    return pcall(function()
        VIM:SendKeyEvent(true, key, false, game)
        task.wait(Config.KeyDelay)
        VIM:SendKeyEvent(false, key, false, game)
    end)
end

local function isVisible(obj)
    if not obj:IsA("GuiObject") or not obj.Visible then return false end
    local parent = obj.Parent
    while parent and parent ~= PlayerGui do
        if parent:IsA("GuiObject") and not parent.Visible then
            return false
        end
        parent = parent.Parent
    end
    return true
end

local function getColor(obj)
    if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
        return obj.ImageColor3
    end
    return obj.BackgroundColor3
end

local function isGreen(obj)
    local ok, color, size = pcall(function()
        return getColor(obj), obj.AbsoluteSize
    end)
    if not ok then return false end
    return color.G > 0.55
        and color.G > color.R * 1.25
        and color.G > color.B * 0.80
        and size.X >= 8 and size.X <= 32
        and size.Y >= 8 and size.Y <= 32
        and math.abs(size.X - size.Y) <= 9
end

local function isRed(obj)
    local ok, color = pcall(getColor, obj)
    return ok and color.R > 0.55
        and color.R > color.G * 1.35
        and color.R > color.B * 1.25
end

local function centerOf(obj)
    return obj.AbsolutePosition + obj.AbsoluteSize / 2
end

local function getFishing()
    return PlayerGui:FindFirstChild("PescariaGui", true)
end

--==================================================
-- BACKPACK + CATCH RARITY
-- A notificação visível do jogo mostra nome e raridade.
-- Exemplo visto no vídeo: "Discus" / "Epic · 0.35 kg · 1884 coins".
--==================================================

local Rarities = {
    "Mythical", "Legendary", "Uncommon", "Common", "Epic",
    "Secret", "Rare",
}

local RarityAliases = {
    Mythic = "Mythical",
    Mythical = "Mythical",
    Epic = "Epic",
    Legendary = "Legendary",
    Common = "Common",
    Uncommon = "Uncommon",
}

local function getRarity(text)
    local lower = string.lower(text or "")
    for _, rarity in ipairs(Rarities) do
        if lower:find(string.lower(rarity), 1, true) then
            return RarityAliases[rarity] or rarity
        end
    end
    if lower:find("mythic", 1, true) then return "Mythical" end
    return nil
end

local function cleanText(text)
    return (text or ""):gsub("<[^>]->", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function addCatch(message)
    message = cleanText(message)
    if message == "" or State.SeenCatchMessages[message] then return end
    State.SeenCatchMessages[message] = os.clock()

    local rarity = getRarity(message)
    if not rarity or not Config.RarityFilter[rarity] then return end

    table.insert(State.History, 1, os.date("%H:%M:%S") .. "  •  " .. message .. "  [" .. rarity .. "]")

    while #State.History > Config.HistoryLimit do
        table.remove(State.History)
    end

    HistoryText.Text = table.concat(State.History, "\n\n")
end

local function inspectCatchText(obj)
    if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
    local text = cleanText(obj.Text)
    if text == "" then return end

    local rarity = getRarity(text)
    local lower = text:lower()
    local hasWeight = lower:find("kg", 1, true) ~= nil
    local hasCatchDetails = hasWeight or lower:find("coins", 1, true) ~= nil

    if rarity and hasCatchDetails then
        -- Remove textos de interface que aparecem junto da notificação.
        local details = text
            :gsub("[Pp]ress%s+[Ee]%s+to%s+fish%s+again%s*[%-%—:]?%s*", "")
            :gsub("[Ff]ish%s*%([Ee]%)%s*", "")
            :gsub("%s*[·•|]?%s*[%d,]+%s*[Cc]oins?.*$", "")
            :gsub("%s*[·•|]?%s*[%d,]+%s*[Cc]oins?", "")
            :gsub("%s+", " ")
            :gsub("^%s+", "")
            :gsub("%s+$", "")

        -- O próprio texto pode conter o nome do peixe antes do peso.
        -- Se só houver peso e raridade, registra esses dados sem inventar um nome.
        if details == "" then details = rarity end
        addCatch(details)
    end
end

local function scanCatchNotifications()
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        inspectCatchText(obj)
    end
end

-- Captura textos novos e textos de notificações reutilizadas pelo jogo.
local function hookTextObject(obj)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        inspectCatchText(obj)
        obj:GetPropertyChangedSignal("Text"):Connect(function()
            inspectCatchText(obj)
        end)
    end
end

for _, obj in ipairs(PlayerGui:GetDescendants()) do
    hookTextObject(obj)
end
PlayerGui.DescendantAdded:Connect(hookTextObject)

local function getBackpack()
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local a, b = (obj.Text or ""):match("Backpack:%s*(%d+)%s*/%s*(%d+)")
            if a then return tonumber(a), tonumber(b) end
        end
    end
end

local function updateCounters()
    local now = os.clock()
    if now - State.LastBackpackRead < 0.45 then return end
    State.LastBackpackRead = now

    local current, maximum = getBackpack()
    if current then
        BackpackValue.Text = current .. " / " .. maximum
        State.CurrentBackpack = current
        State.BackpackCapacity = maximum

        if State.LastBackpackCount == nil then
            State.LastBackpackCount = current
        elseif current > State.LastBackpackCount then
            State.FishCaught += current - State.LastBackpackCount
        end
        State.LastBackpackCount = current

        -- Ao atingir o limite escolhido, pausa a pesca para evitar continuar
        -- enchendo a mochila enquanto o jogador vai vender os peixes.
        if current >= Config.SellThreshold then
            State.PausedForSell = true
        elseif current < Config.SellThreshold then
            State.PausedForSell = false
        end

        if State.PausedForSell then
            ThresholdStatus.Text = "LIMITE ATINGIDO: " .. current .. "/" .. Config.SellThreshold .. " — venda necessária."
            ThresholdStatus.TextColor3 = Color3.fromRGB(255, 190, 85)
        else
            ThresholdStatus.Text = "Próxima pausa para venda: " .. Config.SellThreshold .. " peixes."
            ThresholdStatus.TextColor3 = Color3.fromRGB(65, 220, 165)
        end
    end

    FishValue.Text = tostring(State.FishCaught)
    HitValue.Text = tostring(State.Hits)

    local elapsed = math.floor(now - State.StartedAt)
    TimeValue.Text = string.format("%02d:%02d", math.floor(elapsed / 60), elapsed % 60)
end

--==================================================
-- MINIGAME DETECTION
--==================================================

local function refreshObjectCache(fishing, now)
    if State.CachedFishingGui ~= fishing
        or now - State.LastObjectRefresh >= Config.ObjectRefresh then

        local objects, greens = {}, {}
        for _, obj in ipairs(fishing:GetDescendants()) do
            if obj:IsA("GuiObject") then
                objects[#objects + 1] = obj
                if isGreen(obj) then
                    greens[#greens + 1] = obj
                end
            end
        end

        State.GuiObjects = objects
        State.GreenObjects = greens
        State.CachedFishingGui = fishing
        State.LastObjectRefresh = now
        State.LastTargetRefresh = 0
        State.CircleCenter = nil
        State.CircleRadius = nil
    end
end

local function findCircle(fishing, greens, objects)
    local bestRed, redScore = nil, -math.huge

    for _, obj in ipairs(objects) do
        if obj.Parent and isVisible(obj) and isRed(obj) then
            local size = obj.AbsoluteSize
            local ratio = size.X / math.max(size.Y, 1)
            if size.X >= 35 and size.Y >= 20 and ratio >= 0.55 and ratio <= 2 then
                local score = size.X * size.Y
                if score > redScore then
                    bestRed, redScore = obj, score
                end
            end
        end
    end

    if bestRed then
        local size = bestRed.AbsoluteSize
        if math.abs(size.X - size.Y) <= math.max(size.X, size.Y) * 0.38 then
            return bestRed.AbsolutePosition + size / 2, math.min(size.X, size.Y) * 0.5
        end
    end

    local best, bestScore = nil, -math.huge
    for _, obj in ipairs(objects) do
        if obj.Parent and isVisible(obj) then
            local size = obj.AbsoluteSize
            local largest = math.max(size.X, size.Y)
            local ratio = size.X / math.max(size.Y, 1)
            if largest >= 85 and largest <= 360 and ratio >= 0.82 and ratio <= 1.22 then
                local score = size.X * size.Y
                if score > bestScore then
                    best, bestScore = obj, score
                end
            end
        end
    end

    if best then
        local size = best.AbsoluteSize
        return best.AbsolutePosition + size / 2, math.min(size.X, size.Y) * 0.5
    end

    if #greens >= 2 then
        local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
        for _, ball in ipairs(greens) do
            local p = centerOf(ball)
            minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
            minY, maxY = math.min(minY, p.Y), math.max(maxY, p.Y)
        end
        local center = Vector2.new((minX + maxX) / 2, (minY + maxY) / 2)
        local radius = math.max(maxX - minX, maxY - minY) * 0.5
        if radius > 10 then return center, radius end
    end
end

local function inRedArc(point, center, radius)
    if not center or not radius or radius <= 0 then return false end
    local delta = point - center
    local distance = delta.Magnitude
    if distance < radius * (1 - Config.RadiusTolerance)
        or distance > radius * (1 + Config.RadiusTolerance) then
        return false
    end

    local angle = math.deg(math.atan2(delta.Y, delta.X))
    local difference = math.abs(((angle + 90 + 180) % 360) - 180)
    return difference <= Config.ArcTolerance
end

local function scanMinigame()
    local fishing = getFishing()
    if not fishing then return false end

    local now = os.clock()
    refreshObjectCache(fishing, now)

    local greens = {}
    for _, obj in ipairs(State.GreenObjects) do
        if obj.Parent and isVisible(obj) and isGreen(obj) then
            greens[#greens + 1] = obj
        end
    end

    if #greens == 0 then
        table.clear(State.PreviousPositions)
        table.clear(State.ClickedBalls)
        State.CircleCenter, State.CircleRadius = nil, nil
        return false
    end

    if not State.CircleCenter or now - State.LastTargetRefresh >= Config.TargetRefresh then
        State.CircleCenter, State.CircleRadius = findCircle(fishing, greens, State.GuiObjects)
        State.LastTargetRefresh = now
    end

    local center, radius = State.CircleCenter, State.CircleRadius
    if not center then return true end

    local nextPositions = {}
    for _, ball in ipairs(greens) do
        local pos = centerOf(ball)
        local previous = State.PreviousPositions[ball]
        local hit = inRedArc(pos, center, radius)

        -- Interpola o movimento entre ciclos para não perder bolinhas rápidas.
        if previous and not hit then
            local distance = (pos - previous).Magnitude
            local steps = math.clamp(math.ceil(distance / 3), 1, 16)
            for step = 1, steps do
                if inRedArc(previous:Lerp(pos, step / steps), center, radius) then
                    hit = true
                    break
                end
            end
        end

        if hit and not State.ClickedBalls[ball]
            and now - State.LastPress >= Config.ClickCooldown then
            State.ClickedBalls[ball] = true
            State.LastPress = now
            State.Hits += 1
            task.spawn(pressKey, Enum.KeyCode.Space)
        elseif not hit then
            State.ClickedBalls[ball] = nil
        end

        nextPositions[ball] = pos
    end

    State.PreviousPositions = nextPositions
    return true
end

--==================================================
-- AUTO CAST
--==================================================

local function findFishButton()
    local cached = State.CachedFishButton
    if cached and cached.Parent and cached.Visible then
        return cached
    end

    State.CachedFishButton = nil
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextButton") and obj.Visible then
            local text = string.lower((obj.Text or ""):gsub("%s+", " "))
            if text:find("fish", 1, true) and text:find("%(e%)") then
                State.CachedFishButton = obj
                return obj
            end
        end
    end
end

local function autoCast()
    if not Config.AutoCast or State.Fishing or State.CastPending then return end
    if State.HasCast and not Config.AutoRetry then return end
    local now = os.clock()
    local waitTime = Config.QuickCast and Config.CastDelay or 1.15
    if now - State.LastCast < waitTime then return end

    local fishButton = findFishButton()
    if not fishButton then
        State.CachedFishButton = nil
        return
    end

    State.CastPending = true
    State.LastCast = now
    State.HasCast = true
    task.spawn(function()
        local ok = pressKey(Enum.KeyCode.E)
        task.wait(0.25)
        State.CastPending = false
        if not ok or not fishButton.Parent or not fishButton.Visible then
            State.CachedFishButton = nil
            State.LastCast = os.clock() - 0.25
        end
    end)
end

--==================================================
-- CONTROLS / MAIN LOOP
--==================================================

local function setEnabled(value)
    State.Enabled = value
    Config.Enabled = value

    MainToggle.Text = value and "DESATIVAR AUTOFISH" or "ATIVAR AUTOFISH"
    MainToggle.BackgroundColor3 = value
        and Color3.fromRGB(175, 65, 70)
        or Color3.fromRGB(25, 145, 100)

    Status.Text = value and "● AUTOFISH ATIVO" or "● DESLIGADO"
    Status.TextColor3 = value
        and Color3.fromRGB(65, 235, 175)
        or Color3.fromRGB(220, 90, 90)

    State.LastCast = 0
    State.HasCast = false
    State.LastMinigameSeen = 0
    State.Fishing = false
    State.CachedFishingGui = nil
    State.CachedFishButton = nil
    State.CircleCenter, State.CircleRadius = nil, nil
    table.clear(State.PreviousPositions)
    table.clear(State.ClickedBalls)
end

MainToggle.Activated:Connect(function()
    setEnabled(not Config.Enabled)
end)

local minimized = false
local expandedSize = UDim2.fromOffset(360, 475)
local minimizedSize = UDim2.fromOffset(360, 58)

Minimize.Activated:Connect(function()
    minimized = not minimized
    StatusCard.Visible = not minimized
    Tabs.Visible = not minimized
    Content.Visible = not minimized
    Panel.Size = minimized and minimizedSize or expandedSize
    Minimize.Text = minimized and "+" or "—"
end)

local connection
Close.Activated:Connect(function()
    setEnabled(false)
    if connection then connection:Disconnect() end
    GUI:Destroy()
end)

connection = RunService.Heartbeat:Connect(function()
    if not GUI.Parent then
        connection:Disconnect()
        return
    end

    updateCounters()
    if not Config.Enabled then return end

    if State.PausedForSell then
        State.Fishing = false
        State.CastPending = false
        Status.Text = "● LIMITE DE VENDA ATINGIDO"
        Status.TextColor3 = Color3.fromRGB(255, 190, 85)
        return
    end

    local now = os.clock()
    if now - State.LastScan < Config.ScanInterval then return end
    State.LastScan = now

    local fishing = getFishing()
    if not fishing then
        State.Fishing = false
        State.CachedFishingGui = nil
        State.GuiObjects = {}
        State.GreenObjects = {}
        State.CircleCenter, State.CircleRadius = nil, nil
        Status.Text = "● PROCURANDO PESCA"
        autoCast()
        return
    end

    local active = false
    if Config.AutoReel then
        active = scanMinigame()
    end
    if active then
        State.Fishing = true
        State.LastMinigameSeen = now
        Status.Text = "● MINIGAME ATIVO"
    else
        State.Fishing = (now - State.LastMinigameSeen) < 0.75
        if not State.Fishing then
            table.clear(State.PreviousPositions)
            autoCast()
            Status.Text = Config.AutoReel
                and "● AGUARDANDO PRÓXIMA PESCA"
                or "● AUTO REEL DESATIVADO"
        end
    end
end)

-- Primeira leitura para registrar o valor atual da mochila sem contar peixes antigos.
task.defer(function()
    task.wait(1)
    local current = getBackpack()
    if current then State.LastBackpackCount = current end
    scanCatchNotifications()
end)

print("[ABYSSAL] V7.4 CARREGADO")
