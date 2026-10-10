-- LT2 Vehicle Mover
-- Собственный интерфейс Rayfield

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer

local Rayfield = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua"
))()

local Window = Rayfield:CreateWindow({
    Name = "LT2 Vehicle Mover",
    LoadingTitle = "LT2 Vehicle Mover",
    LoadingSubtitle = "Personal Hub",
    ConfigurationSaving = {Enabled = false}
})

local function notify(title, content)
    Rayfield:Notify({
        Title = title,
        Content = content,
        Duration = 3
    })
end

-- PLAYER TAB
local PlayerTab = Window:CreateTab("Игроки")

local targetName = nil
local function getPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player then
            table.insert(names, p.Name)
        end
    end
    return names
end

PlayerTab:CreateDropdown({
    Name = "Выбрать игрока",
    Options = getPlayerNames(),
    CurrentOption = {},
    MultipleOptions = false,
    Callback = function(value)
        targetName = type(value) == "table" and value[1] or value
        notify("Цель", targetName or "Не выбрана")
    end
})

PlayerTab:CreateButton({
    Name = "Обновить список игроков",
    Callback = function()
        notify("Игроки", "Перезапусти меню для обновления списка")
    end
})

PlayerTab:CreateParagraph({
    Title = "Телепортация",
    Content = "Выбор цели работает. Серверное перемещение машины и груза в LT2 этим клиентским скриптом не гарантируется."
})

-- LIGHTING TAB
local LightTab = Window:CreateTab("Освещение")

local lightingMode = "День"
local shadowsOff = false

LightTab:CreateDropdown({
    Name = "Время суток",
    Options = {"День", "Ночь", "Обычное"},
    CurrentOption = {"День"},
    MultipleOptions = false,
    Callback = function(value)
        lightingMode = type(value) == "table" and value[1] or value
        if lightingMode == "День" then
            Lighting.ClockTime = 14
        elseif lightingMode == "Ночь" then
            Lighting.ClockTime = 0
        end
        notify("Освещение", lightingMode)
    end
})

LightTab:CreateToggle({
    Name = "Отключить тени",
    CurrentValue = false,
    Callback = function(value)
        shadowsOff = value
        Lighting.GlobalShadows = not value
        notify("Тени", value and "Отключены" or "Включены")
    end
})

-- FLIGHT TAB
local FlightTab = Window:CreateTab("Полёт")

local flying = false
local flightSpeed = 135
local flightConnection
local bodyVelocity
local bodyGyro

FlightTab:CreateSlider({
    Name = "Скорость полёта",
    Range = {135, 350},
    Increment = 5,
    Suffix = " speed",
    CurrentValue = 135,
    Callback = function(value)
        flightSpeed = value
    end
})

local function stopFlight()
    flying = false
    if flightConnection then
        flightConnection:Disconnect()
        flightConnection = nil
    end

    if bodyVelocity then
        bodyVelocity:Destroy()
        bodyVelocity = nil
    end
    if bodyGyro then
        bodyGyro:Destroy()
        bodyGyro = nil
    end

    notify("Полёт", "Выключен")
end

local function startFlight()
    local character = Player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if not root or not humanoid then
        notify("Полёт", "Персонаж не найден")
        return
    end

    flying = true

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.Parent = root

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bodyGyro.P = 1e4
    bodyGyro.CFrame = root.CFrame
    bodyGyro.Parent = root

    flightConnection = RunService.RenderStepped:Connect(function()
        if not flying or not root.Parent then
            stopFlight()
            return
        end

        local camera = workspace.CurrentCamera
        local direction = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            direction += camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            direction -= camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            direction -= camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            direction += camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            direction += Vector3.yAxis
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            direction -= Vector3.yAxis
        end

        bodyVelocity.Velocity =
            direction.Magnitude > 0 and direction.Unit * flightSpeed
            or Vector3.zero

        bodyGyro.CFrame = camera.CFrame
    end)

    notify("Полёт", "Включён")
end

FlightTab:CreateToggle({
    Name = "Полёт (Q)",
    CurrentValue = false,
    Callback = function(value)
        if value then
            startFlight()
        else
            stopFlight()
        end
    end
})

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Q then
        if flying then
            stopFlight()
        else
            startFlight()
        end
    end
end)

-- OBJECT TAB
local ObjectTab = Window:CreateTab("Объекты")

local selectedObjectName = ""

ObjectTab:CreateInput({
    Name = "Имя модели",
    PlaceholderText = "Например: Log",
    RemoveTextAfterFocusLost = false,
    Callback = function(value)
        selectedObjectName = value
    end
})

ObjectTab:CreateButton({
    Name = "Найти объект",
    Callback = function()
        if selectedObjectName == "" then
            notify("Объекты", "Введи имя модели")
            return
        end

        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model")
                and string.find(
                    string.lower(obj.Name),
                    string.lower(selectedObjectName),
                    1,
                    true
                ) then
                notify("Найден объект", obj.Name)
                return
            end
        end

        notify("Объекты", "Ничего не найдено")
    end
})

ObjectTab:CreateParagraph({
    Title = "Перемещение",
    Content = "Поиск объектов работает локально. Сервер может запрещать перемещение деревьев и брёвен."
})

-- Keep local lighting settings
task.spawn(function()
    while true do
        if lightingMode == "День" then
            Lighting.ClockTime = 14
        elseif lightingMode == "Ночь" then
            Lighting.ClockTime = 0
        end

        if shadowsOff then
            Lighting.GlobalShadows = false
        end

        task.wait(1)
    end
end)

notify("LT2 Vehicle Mover", "Загружен")
