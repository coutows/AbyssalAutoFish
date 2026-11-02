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

print("[ABYSSAL] V7.2 CARREGADO")
