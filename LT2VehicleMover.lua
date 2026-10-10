
-- LT2 Vehicle Mover
-- Client-side utilities for Lumber Tycoon 2

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Rayfield = loadstring(game:HttpGet(
    "https://sirius.menu/rayfield"
))()

local Window = Rayfield:CreateWindow({
    Name = "LT2 Vehicle Mover",
    LoadingTitle = "LT2 Vehicle Mover",
    LoadingSubtitle = "Lumber Tycoon 2",
    ConfigurationSaving = {
        Enabled = false
    },
    KeySystem = false
})

local MainTab = Window:CreateTab("Главная", 4483362458)
local VehicleTab = Window:CreateTab("Машина", 4483362458)
local VisualTab = Window:CreateTab("Визуал", 4483362458)
local FlightTab = Window:CreateTab("Полёт", 4483362458)

local function notify(title, message)
    Rayfield:Notify({
        Title = title,
        Content = message,
        Duration = 4
    })
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getRoot(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

-- PLAYER LIST

local selectedPlayerName = nil

local function getPlayerNames()
    local names = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(names, player.Name)
        end
    end

    table.sort(names)
    return names
end

local PlayerDropdown = MainTab:CreateDropdown({
    Name = "Выбрать игрока",
    Options = getPlayerNames(),
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "SelectedPlayer",
    Callback = function(options)
        selectedPlayerName = options[1]
    end
})

MainTab:CreateButton({
    Name = "Обновить список игроков",
    Callback = function()
        PlayerDropdown:Refresh(getPlayerNames(), true)
        notify("LT2 Vehicle Mover", "Список игроков обновлён")
    end
})

local function getSelectedPlayer()
    if not selectedPlayerName then
        notify("Ошибка", "Сначала выбери игрока")
        return nil
    end

    local target = Players:FindFirstChild(selectedPlayerName)

    if not target or not target.Character then
        notify("Ошибка", "Игрок не найден или ещё загружается")
        return nil
    end

    return target
end

-- VISUALS: DAY / NIGHT / SHADOWS

local originalClockTime = Lighting.ClockTime
local originalBrightness = Lighting.Brightness
local originalGlobalShadows = Lighting.GlobalShadows

local lightingMode = "Обычное"

local function applyLighting()
    if lightingMode == "День" then
        Lighting.ClockTime = 14
        Lighting.Brightness = 2
    elseif lightingMode == "Ночь" then
        Lighting.ClockTime = 0
        Lighting.Brightness = 1
    else
        Lighting.ClockTime = originalClockTime
        Lighting.Brightness = originalBrightness
    end
end

VisualTab:CreateDropdown({
    Name = "Время суток",
    Options = {"День", "Ночь", "Обычное"},
    CurrentOption = {"День"},
    MultipleOptions = false,
    Callback = function(options)
        lightingMode = options[1] or "Обычное"
        applyLighting()
        notify("Освещение", "Режим: " .. lightingMode)
    end
})

VisualTab:CreateToggle({
    Name = "Отключить тени",
    CurrentValue = false,
    Callback = function(value)
        Lighting.GlobalShadows = not value

        if value then
            notify("Освещение", "Тени отключены локально")
        else
            notify("Освещение", "Тени включены")
        end
    end
})

-- TELEPORT TO SELECTED PLAYER
-- This changes only the local character position.
-- The server may correct or reject the movement.

MainTab:CreateButton({
    Name = "Переместить персонажа к игроку",
    Callback = function()
        local target = getSelectedPlayer()
        if not target then return end

        local targetRoot = getRoot(target.Character)
        local myRoot = getRoot(getCharacter())

        if not targetRoot or not myRoot then
            notify("Ошибка", "Персонаж ещё не загружен")
            return
        end

        myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -5)
        notify("Телепорт", "Выполнена локальная попытка перемещения")
    end
})

-- VEHICLE

local function getVehicle()
    local character = getCharacter()
    if not character then return nil end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end

    local seat = humanoid.SeatPart
    if not seat then return nil end

    local current = seat

    while current and current ~= workspace do
        if current:IsA("Model") then
            return current
        end
        current = current.Parent
    end

    return seat
end

VehicleTab:CreateButton({
    Name = "Найти мою машину",
    Callback = function()
        local vehicle = getVehicle()

        if vehicle then
            notify("Машина найдена", vehicle:GetFullName())
        else
            notify("Машина не найдена", "Сядь на сиденье своей машины")
        end
    end
})

VehicleTab:CreateButton({
    Name = "Попытка переместить машину к игроку",
    Callback = function()
        local target = getSelectedPlayer()
        if not target then return end

        local targetRoot = getRoot(target.Character)
        local vehicle = getVehicle()

        if not targetRoot then
            notify("Ошибка", "Не удалось найти персонажа игрока")
            return
        end

        if not vehicle then
            notify("Ошибка", "Сначала сядь в свою машину")
            return
        end

        local destination = targetRoot.CFrame * CFrame.new(0, 0, -12)

        local success = pcall(function()
            vehicle:PivotTo(destination)
        end)

        if success then
            notify(
                "Попытка перемещения",
                "Сервер может отменить перемещение машины или груза"
            )
        else
            notify("Ошибка", "Не удалось переместить машину")
        end
    end
})

VehicleTab:CreateInput({
    Name = "Поиск объекта по названию",
    PlaceholderText = "Например: Tree, Log, Vehicle",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        if text == "" then return end

        local found = 0
        local search = string.lower(text)

        for _, object in ipairs(workspace:GetDescendants()) do
            if (object:IsA("Model") or object:IsA("BasePart"))
                and string.find(string.lower(object.Name), search, 1, true) then
                found += 1
            end
        end

        notify("Поиск объектов", "Найдено совпадений: " .. found)
    end
})

-- FLIGHT

local flying = false
local flySpeed = 180
local flyConnection = nil
local bodyVelocity = nil
local bodyGyro = nil

local function stopFlight()
    flying = false

    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end

    local character = getCharacter()
    local root = getRoot(character)

    if root then
        for _, child in ipairs(root:GetChildren()) do
            if child.Name == "LTVM_FlyVelocity"
                or child.Name == "LTVM_FlyGyro" then
                child:Destroy()
            end
        end
    end

    bodyVelocity = nil
    bodyGyro = nil
    notify("Полёт", "Выключен")
end

local function startFlight()
    local character = getCharacter()
    local root = getRoot(character)

    if not root then
        notify("Полёт", "Персонаж не найден")
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.SeatPart then
        notify("Полёт", "Выйди из машины перед полётом")
        return
    end

    stopFlight()
    flying = true

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "LTVM_FlyVelocity"
    bodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.Parent = root

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "LTVM_FlyGyro"
    bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bodyGyro.P = 1e5
    bodyGyro.CFrame = Camera.CFrame
    bodyGyro.Parent = root

    flyConnection = RunService.RenderStepped:Connect(function()
        if not flying or not root.Parent then
            stopFlight()
            return
        end

        local direction = Vector3.zero
        local camera = workspace.CurrentCamera

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            direction += camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            direction -= camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            direction += camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            direction -= camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            direction += Vector3.yAxis
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            direction -= Vector3.yAxis
        end

        if direction.Magnitude > 0 then
            direction = direction.Unit
        end

        bodyVelocity.Velocity = direction * flySpeed
        bodyGyro.CFrame = camera.CFrame
    end)

    notify(
        "Полёт включён",
        "WASD — движение, Space/Ctrl — вверх/вниз"
    )
end

FlightTab:CreateSlider({
    Name = "Скорость полёта",
    Range = {135, 350},
    Increment = 5,
    Suffix = " speed",
    CurrentValue = 180,
    Flag = "FlySpeed",
    Callback = function(value)
        flySpeed = value
    end
})

FlightTab:CreateToggle({
    Name = "Полёт",
    CurrentValue = false,
    Callback = function(value)
        if value then
            startFlight()
        else
            stopFlight()
        end
    end
})

FlightTab:CreateParagraph({
    Title = "Управление полётом",
    Content = "W/A/S/D — движение; Space — вверх; Left Ctrl — вниз. Скорость регулируется ползунком."
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

-- KEEP LOCAL LIGHTING SETTINGS

RunService.Heartbeat:Connect(function()
    if lightingMode ~= "Обычное" then
        applyLighting()
    end
end)

-- CLEANUP WHEN RESPAWNING

LocalPlayer.CharacterAdded:Connect(function()
    if flying then
        stopFlight()
    end
end)

notify("LT2 Vehicle Mover", "Хаб загружен")
