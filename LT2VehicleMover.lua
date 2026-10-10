
-- LT2 Vehicle Mover
-- Lumber Tycoon 2 | Rayfield GUI

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Rayfield = loadstring(game:HttpGet(
    "https://sirius.menu/rayfield"
))()

local Window = Rayfield:CreateWindow({
    Name = "LT2 Vehicle Mover",
    LoadingTitle = "LT2 Vehicle Mover",
    LoadingSubtitle = "Lumber Tycoon 2",
    ConfigurationSaving = { Enabled = false },
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

-- =========================================
-- PLAYER LIST
-- =========================================

local selectedPlayerName

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
    Callback = function(options)
        selectedPlayerName = options[1]
    end
})

MainTab:CreateButton({
    Name = "Обновить список игроков",
    Callback = function()
        PlayerDropdown:Refresh(getPlayerNames(), true)
        notify("Игроки", "Список обновлён")
    end
})

Players.PlayerAdded:Connect(function()
    task.defer(function()
        PlayerDropdown:Refresh(getPlayerNames(), true)
    end)
end)

Players.PlayerRemoving:Connect(function()
    task.defer(function()
        PlayerDropdown:Refresh(getPlayerNames(), true)
    end)
end)

local function getSelectedPlayer()
    if not selectedPlayerName then
        notify("Ошибка", "Сначала выбери игрока")
        return nil
    end

    local target = Players:FindFirstChild(selectedPlayerName)

    if not target or not target.Character then
        notify("Ошибка", "Игрок не найден или загружается")
        return nil
    end

    return target
end

-- =========================================
-- VISUALS
-- =========================================

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
        notify("Освещение", value and
            "Тени отключены локально" or "Тени включены")
    end
})

-- =========================================
-- CHARACTER TELEPORT
-- =========================================

MainTab:CreateButton({
    Name = "Переместить персонажа к игроку",
    Callback = function()
        local target = getSelectedPlayer()
        if not target then return end

        local targetRoot = getRoot(target.Character)
        local myRoot = getRoot(getCharacter())

        if not targetRoot or not myRoot then
            notify("Ошибка", "Персонаж не загружен")
            return
        end

        myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -5)
        notify("Телепорт", "Запрошено локальное перемещение")
    end
})

-- =========================================
-- VEHICLE DETECTION
-- =========================================

local function getVehicle()
    local character = getCharacter()
    if not character then return nil end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart

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
            notify("Машина", "Сначала сядь на сиденье")
        end
    end
})

-- =========================================
-- VEHICLE + GIFT MOVE ATTEMPT
-- =========================================

local function isGiftName(name)
    name = string.lower(name)

    return string.find(name, "gift", 1, true) ~= nil
        or string.find(name, "present", 1, true) ~= nil
end

local function getObjectPivot(object)
    if object:IsA("Model") then
        return object:GetPivot()
    elseif object:IsA("BasePart") then
        return object.CFrame
    end

    return nil
end

local function moveObject(object, cf)
    if object:IsA("Model") then
        object:PivotTo(cf)
    elseif object:IsA("BasePart") then
        object.CFrame = cf
    end
end

VehicleTab:CreateButton({
    Name = "Телепортировать машину и подарки",
    Callback = function()
        local target = getSelectedPlayer()
        if not target then return end

        local targetRoot = getRoot(target.Character)
        local vehicle = getVehicle()

        if not targetRoot then
            notify("Ошибка", "Персонаж выбранного игрока не найден")
            return
        end

        if not vehicle then
            notify("Ошибка", "Сначала сядь в свою машину")
            return
        end

        local oldPivot = vehicle:GetPivot()
        local boxCF, boxSize = vehicle:GetBoundingBox()
        local gifts = {}
        local seen = {}

        local function insideVehicle(position)
            local localPos = boxCF:PointToObjectSpace(position)

            return math.abs(localPos.X) <= boxSize.X / 2 + 3
                and math.abs(localPos.Y) <= boxSize.Y / 2 + 3
                and math.abs(localPos.Z) <= boxSize.Z / 2 + 3
        end

        for _, object in ipairs(workspace:GetDescendants()) do
            if not object:IsDescendantOf(vehicle)
                and object ~= vehicle
                and (object:IsA("Model") or object:IsA("BasePart"))
                and isGiftName(object.Name)
                and not seen[object] then

                local skip = false

                if object:IsA("BasePart") then
                    local ancestor = object.Parent

                    while ancestor and ancestor ~= workspace do
                        if ancestor:IsA("Model")
                            and isGiftName(ancestor.Name) then
                            skip = true
                            break
                        end
                        ancestor = ancestor.Parent
                    end
                end

                local cf = getObjectPivot(object)

                if not skip and cf and insideVehicle(cf.Position) then
                    seen[object] = true

                    table.insert(gifts, {
                        object = object,
                        relative = oldPivot:ToObjectSpace(cf)
                    })
                end
            end
        end

        local destination =
            targetRoot.CFrame * CFrame.new(0, 0, -12)

        local ok, err = pcall(function()
            vehicle:PivotTo(destination)

            for _, gift in ipairs(gifts) do
                if gift.object and gift.object.Parent then
                    moveObject(
                        gift.object,
                        destination * gift.relative
                    )
                end
            end
        end)

        if ok then
            notify(
                "Перемещение отправлено",
                "Обнаружено подарков: " .. #gifts
                    .. ". Сервер может отменить перемещение."
            )
        else
            notify("Ошибка", tostring(err))
        end
    end
})

-- =========================================
-- OBJECT SEARCH
-- =========================================

VehicleTab:CreateInput({
    Name = "Поиск объекта по названию",
    PlaceholderText = "Например: Tree, Log, Gift",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        if text == "" then return end

        local found = 0
        local search = string.lower(text)

        for _, object in ipairs(workspace:GetDescendants()) do
            if (object:IsA("Model") or object:IsA("BasePart"))
                and string.find(
                    string.lower(object.Name),
                    search,
                    1,
                    true
                ) then
                found += 1
            end
        end

        notify("Поиск объектов", "Совпадений: " .. found)
    end
})

-- =========================================
-- FLIGHT
-- =========================================

local flying = false
local flySpeed = 180
local flyConnection
local bodyVelocity
local bodyGyro
local flightRoot

local function stopFlight(silent)
    flying = false

    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end

    if bodyVelocity then
        bodyVelocity:Destroy()
        bodyVelocity = nil
    end

    if bodyGyro then
        bodyGyro:Destroy()
        bodyGyro = nil
    end

    flightRoot = nil

    if not silent then
        notify("Полёт", "Выключен")
    end
end

local function startFlight()
    if flying then return end

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

    flying = true
    flightRoot = root

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "LTVM_FlyVelocity"
    bodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.Parent = root

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "LTVM_FlyGyro"
    bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bodyGyro.P = 1e5
    bodyGyro.CFrame = workspace.CurrentCamera.CFrame
    bodyGyro.Parent = root

    flyConnection = RunService.RenderStepped:Connect(function()
        if not flying or not root.Parent
            or not bodyVelocity or not bodyGyro then
            stopFlight(true)
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

    notify("Полёт включён", "WASD — движение; Space/Ctrl — высота")
end

FlightTab:CreateSlider({
    Name = "Скорость полёта",
    Range = {135, 350},
    Increment = 5,
    Suffix = " speed",
    CurrentValue = 180,
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
    Title = "Управление",
    Content = "W/A/S/D — движение; Space — вверх; Left Ctrl — вниз. Q — переключение полёта."
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

-- =========================================
-- LIGHTING KEEP
-- =========================================

RunService.Heartbeat:Connect(function()
    if lightingMode ~= "Обычное" then
        applyLighting()
    end
end)

-- =========================================
-- RESPAWN CLEANUP
-- =========================================

LocalPlayer.CharacterAdded:Connect(function()
    if flying then
        stopFlight(true)
    end
end)

-- =========================================
-- START
-- =========================================

notify("LT2 Vehicle Mover", "Хаб загружен")
