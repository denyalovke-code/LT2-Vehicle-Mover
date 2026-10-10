
--[[
    LT2 Vehicle Mover
    Lumber Tycoon 2
    Единый русскоязычный интерфейс
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet(
        "https://sirius.menu/rayfield"
    ))()
end)

if not success or not Rayfield then
    warn("Не удалось загрузить Rayfield")
    return
end

local Window = Rayfield:CreateWindow({
    Name = "LT2 Vehicle Mover",
    LoadingTitle = "LT2 Vehicle Mover",
    LoadingSubtitle = "Lumber Tycoon 2 | Единый хаб",
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
        Duration = 5
    })
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getRoot(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

-- =========================================
-- ИГРОКИ
-- =========================================

local selectedPlayerName

local function getPlayerNames()
    local result = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(result, player.Name)
        end
    end

    table.sort(result)
    return result
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

local function refreshPlayers()
    task.defer(function()
        PlayerDropdown:Refresh(getPlayerNames(), true)
    end)
end

Players.PlayerAdded:Connect(refreshPlayers)
Players.PlayerRemoving:Connect(refreshPlayers)

local function getSelectedPlayer()
    if not selectedPlayerName then
        notify("Ошибка", "Сначала выбери игрока")
        return nil
    end

    local player = Players:FindFirstChild(selectedPlayerName)

    if not player or not player.Character then
        notify("Ошибка", "Игрок не найден или загружается")
        return nil
    end

    return player
end

-- =========================================
-- ОСВЕЩЕНИЕ
-- =========================================

local originalClockTime = Lighting.ClockTime
local originalBrightness = Lighting.Brightness
local originalShadows = Lighting.GlobalShadows

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
        notify("Освещение", value and "Тени отключены" or "Тени включены")
    end
})

-- =========================================
-- ТЕЛЕПОРТАЦИЯ ПЕРСОНАЖА
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
        notify("Телепортация", "Запрос выполнен")
    end
})

-- =========================================
-- ПОИСК МАШИНЫ
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
-- ПОИСК УЧАСТКА
-- =========================================

local function findPlayerPlot(player)
    local candidates = {}

    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("Model") then
            local name = string.lower(object.Name)

            if name:find("plot", 1, true)
                or name:find("land", 1, true)
                or name:find("slot", 1, true)
                or name:find("участ", 1, true) then
                table.insert(candidates, object)
            end
        end
    end

    for _, model in ipairs(candidates) do
        for name, value in pairs(model:GetAttributes()) do
            name = string.lower(name)

            if name:find("owner", 1, true)
                or name:find("player", 1, true)
                or name:find("user", 1, true) then

                if value == player.Name
                    or value == player.DisplayName
                    or value == tostring(player.UserId)
                    or value == player.UserId then
                    return model
                end
            end
        end

        for _, item in ipairs(model:GetDescendants()) do
            if item:IsA("StringValue")
                or item:IsA("IntValue")
                or item:IsA("NumberValue") then

                local name = string.lower(item.Name)

                if name:find("owner", 1, true)
                    or name:find("player", 1, true)
                    or name:find("user", 1, true) then

                    if item.Value == player.Name
                        or item.Value == player.DisplayName
                        or tostring(item.Value) == tostring(player.UserId) then
                        return model
                    end
                end
            end
        end
    end

    return nil
end

-- =========================================
-- ПОДАРКИ И ПЕРЕМЕЩЕНИЕ
-- =========================================

local function isGiftName(name)
    name = string.lower(name)

    return name:find("gift", 1, true) ~= nil
        or name:find("present", 1, true) ~= nil
        or name:find("подар", 1, true) ~= nil
end

local function getObjectPivot(object)
    if object:IsA("Model") then
        return object:GetPivot()
    elseif object:IsA("BasePart") then
        return object.CFrame
    end

    return nil
end

local function setObjectPivot(object, cf)
    if object:IsA("Model") then
        object:PivotTo(cf)
    elseif object:IsA("BasePart") then
        object.CFrame = cf
    end
end

local function collectGifts(vehicle)
    local oldPivot = vehicle:GetPivot()
    local boxCF, boxSize = vehicle:GetBoundingBox()
    local gifts = {}
    local seen = {}

    for _, object in ipairs(workspace:GetDescendants()) do
        if (object:IsA("Model") or object:IsA("BasePart"))
            and not object:IsDescendantOf(vehicle)
            and isGiftName(object.Name) then

            local cf = getObjectPivot(object)

            if cf then
                local p = boxCF:PointToObjectSpace(cf.Position)

                local inside =
                    math.abs(p.X) <= boxSize.X / 2 + 2
                    and math.abs(p.Y) <= boxSize.Y / 2 + 2
                    and math.abs(p.Z) <= boxSize.Z / 2 + 2

                if inside and not seen[object] then
                    local parent = object.Parent
                    local nested = false

                    while parent and parent ~= workspace do
                        if parent:IsA("Model") and isGiftName(parent.Name) then
                            nested = true
                            break
                        end
                        parent = parent.Parent
                    end

                    if not nested then
                        seen[object] = true

                        table.insert(gifts, {
                            object = object,
                            relative = oldPivot:ToObjectSpace(cf)
                        })
                    end
                end
            end
        end
    end

    return gifts
end

VehicleTab:CreateButton({
    Name = "Перенести машину на участок игрока",
    Callback = function()
        local target = getSelectedPlayer()
        if not target then return end

        local vehicle = getVehicle()

        if not vehicle then
            notify("Ошибка", "Сначала сядь в машину")
            return
        end

        task.spawn(function()
            local ok, err = pcall(function()
                local myPlot = findPlayerPlot(LocalPlayer)
                local targetPlot = findPlayerPlot(target)

                if not myPlot then
                    notify("Ошибка", "Не удалось определить твой участок")
                    return
                end

                if not targetPlot then
                    notify("Ошибка", "Участок выбранного игрока не найден")
                    return
                end

                local sourceCF = myPlot:GetPivot()
                local targetCF = targetPlot:GetPivot()
                local oldVehicleCF = vehicle:GetPivot()

                local relativeVehicle =
                    sourceCF:ToObjectSpace(oldVehicleCF)

                local gifts = collectGifts(vehicle)

                local destination = targetCF * relativeVehicle

                vehicle:PivotTo(destination)

                for _, gift in ipairs(gifts) do
                    if gift.object and gift.object.Parent then
                        setObjectPivot(
                            gift.object,
                            destination * gift.relative
                        )
                    end
                end

                notify(
                    "Перемещение выполнено",
                    "Найдено подарков: " .. #gifts
                    .. ". Проверь результат в игре."
                )
            end)

            if not ok then
                notify("Ошибка", tostring(err))
            end
        end)
    end
})

-- =========================================
-- ПОИСК ОБЪЕКТОВ
-- =========================================

VehicleTab:CreateInput({
    Name = "Поиск объекта",
    PlaceholderText = "Tree, Log, Gift...",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        if text == "" then return end

        local count = 0
        local query = string.lower(text)

        for _, object in ipairs(workspace:GetDescendants()) do
            if (object:IsA("Model") or object:IsA("BasePart"))
                and string.find(
                    string.lower(object.Name),
                    query,
                    1,
                    true
                ) then
                count += 1
            end
        end

        notify("Результаты поиска", "Найдено: " .. count)
    end
})

-- =========================================
-- ПОЛЁТ
-- =========================================

local flying = false
local flySpeed = 180
local flyConnection
local bodyVelocity
local bodyGyro

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
        notify("Полёт", "Выйди из машины")
        return
    end

    flying = true

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "LTVM_Velocity"
    bodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.Parent = root

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "LTVM_Gyro"
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

    notify("Полёт", "WASD — движение, Space/Ctrl — высота")
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
    Content = "W/A/S/D — движение; Space — вверх; Left Ctrl — вниз; Q — переключение."
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
-- ЗАВЕРШЕНИЕ
-- =========================================

LocalPlayer.CharacterAdded:Connect(function()
    if flying then
        stopFlight(true)
    end
end)

notify("LT2 Vehicle Mover", "Хаб загружен")
