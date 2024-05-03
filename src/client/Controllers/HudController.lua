--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--// Dependencies
local Knit = require(ReplicatedStorage.Packages.Knit)
local Util = require(ReplicatedStorage.Shared.Util)

--// Variables
local MAX_SCALE = 1.1
local BUTTON_SPRING_DAMPENING = 0.5
local SPRING_SPEED = 2

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local NotificationController

local HudController = Knit.CreateController {Name = "HudController"}

function HudController:AnimateButton(button: ImageButton | TextButton, callback: ()->(), icon: GuiObject?, max: number?, cooldown: number?): {RBXScriptConnection}
    local maxScale: UDim2 = Util.scalarMultiplyUDim2(button.Size, max or MAX_SCALE)
    local defaultScale: UDim2 = button.Size
    local ogIconPos: UDim2? = icon and icon.Position
    local targetIconPos: UDim2? = ogIconPos and ogIconPos - UDim2.fromScale(0, 0.1)
    cooldown = cooldown or 0.25

    local enter = button.MouseEnter:Connect(function()
        Util.spring.target(button, BUTTON_SPRING_DAMPENING, SPRING_SPEED, {Size = maxScale})
        if icon then
            Util.spring.target(icon, BUTTON_SPRING_DAMPENING, SPRING_SPEED, {Position = targetIconPos})
        end
    end)
    local leave = button.MouseLeave:Connect(function()
        Util.spring.target(button, BUTTON_SPRING_DAMPENING, SPRING_SPEED, {Size = defaultScale})
        if icon then
            Util.spring.target(icon, BUTTON_SPRING_DAMPENING, SPRING_SPEED, {Position = ogIconPos})
        end
    end)
    local click = button.Activated:Connect(Util.debounce(cooldown, function()
        if callback then
            task.spawn(callback)
        end
        NotificationController:PlaySound("Click")
    end))

    return {enter, leave, click}
end

function HudController:GetScreenGui(name: string): ScreenGui?
    return PlayerGui:WaitForChild(name)
end

function HudController:GetHud(): ScreenGui
    return PlayerGui:WaitForChild("HUD")
end

function HudController:KnitInit()
    NotificationController = Knit.GetController("NotificationController")
end

return HudController