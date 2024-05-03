--[[
    Controller that handles player input and the hotbar/mobile UI
]]

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

--// Dependencies
local Knit = require(ReplicatedStorage.Packages.Knit)
local Util = require(ReplicatedStorage.Shared.Util)
local MoveUtil = require(ReplicatedStorage.Shared.MoveHandler.MoveUtil)
local Network = require(ReplicatedStorage.Shared.Modules.Network)
local TweenUtil = require(ReplicatedStorage.Shared.Modules.TweenUtil)
local MoveInput = require(ReplicatedStorage.Shared.MoveHandler.MoveInput)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerUtil = require(ReplicatedStorage.Shared.Modules.PlayerUtil)

--// Variables
local COOLDOWN_ORIGINAL_SIZE = UDim2.fromScale(1, 1)
local COOLDOWN_TARGET_SIZE = UDim2.fromScale(1, 0)
local HOTBAR_OFF_POSITION = UDim2.fromScale(0.5, 1.5)
local HOTBAR_ON_POSITION --gets set in KnitStart()
local MOBILE_BUTTON_OFF_POSITION = UDim2.fromScale(1.5, 0.5)
local MOBILE_BUTTON_ON_POSITION --gets set in KnitStart()

local MoveItem = ReplicatedStorage.Storage.UI.MoveItem

local HudController
local MoveService

local Hotbar
local MobileButtons

local slotGraph = {}
local troves = {}

local HotbarController = Knit.CreateController { Name = "HotbarController" }

function HotbarController:KnitInit()
    HudController = Knit.GetController("HudController")
    MoveService = Knit.GetService("MoveService")
end

function HotbarController:KnitStart()
    Hotbar = HudController:GetHud().Hotbar
    MobileButtons = HudController:GetScreenGui("MobileButtons")
    HOTBAR_ON_POSITION = Hotbar.Position
    MOBILE_BUTTON_ON_POSITION = MobileButtons.Holder.Buttons.Position
    self:BuildHotbar()
    self:ConnectMoveEvents()
    self:InitInput()
    self:InitMobile()
end

function HotbarController:BuildHotbar()
    local function initSlot(move: {})
        local name = move.name
        local slot = move.slot
        local item = MoveItem:Clone()
        item.LayoutOrder = move.layoutOrder or tonumber(slot)
        item.Slot.Text = move.sloText or slot
        item.MoveName.Text = move.displayName or name
        item.Cooldown.Size = UDim2.fromScale(1, 0)
        item.Name = name
        HudController:AnimateButton(item, function()
            MoveService.ActivateMove:Fire(name)
        end)
        slotGraph[name] = slot
        slotGraph[slot] = name
        item.Parent = Hotbar
    end
    Util.table.Apply(MoveUtil.GetAllMoves(), initSlot)
end

function HotbarController:ConnectMoveEvents()
    local function cooldownStarted(moveName: string)
        local trove = troves[moveName] or Trove.new()
        trove:Clean()
        troves[moveName] = trove
        local cooldown = MoveUtil.GetMoveProperties(moveName, "cooldown")
        local moveButton = Hotbar:FindFirstChild(moveName)
        local cooldownFrame = moveButton.Cooldown
        local tweenInfo = TweenInfo.new(cooldown, Enum.EasingStyle.Linear)

        Util.setProperties(cooldownFrame, {Visible = true, Size = COOLDOWN_ORIGINAL_SIZE})
        local tween = TweenUtil.TweenImmediate(cooldownFrame, tweenInfo, {Size = COOLDOWN_TARGET_SIZE})
        trove:Add(function()
            tween:Cancel()
            Util.setProperties(cooldownFrame, {Visible = false, Size = COOLDOWN_ORIGINAL_SIZE})
        end)
        trove:Add(task.delay(cooldown, function()
            Util.setProperties(cooldownFrame, {Visible = false, Size = COOLDOWN_ORIGINAL_SIZE})
            trove:Clean()
        end))
    end
    local function onCooldownCancelled(moveName: string)
        local trove = troves[moveName]
        if trove then
            trove:Clean()
        end
    end
    local function onCutsceneStateChanged(state: boolean)
        local hotbarPos = state and HOTBAR_OFF_POSITION or HOTBAR_ON_POSITION
        local mobileButtonPos = state and MOBILE_BUTTON_OFF_POSITION or MOBILE_BUTTON_ON_POSITION
        local d = state and 1 or 0.6
        Util.spring.target(Hotbar, d, 2, {Position = hotbarPos})
        Util.spring.target(MobileButtons.Holder.Buttons, d, 2, {Position = mobileButtonPos})
    end
    Network:BindEvents({
        CooldownStarted = cooldownStarted,
        CooldownCancelled = onCooldownCancelled,
        ToggleControls = PlayerUtil.ToggleControls,
        CutsceneStateChanged = onCutsceneStateChanged,
    })
end

function HotbarController:InitInput()
    local function onInputBegan(input: InputObject, processed: boolean)
        if processed then
            return
        end
        local isLightMelee = MoveInput.IsLightMeleeInput(input)
        if isLightMelee then
            return MoveService.LightMelee:Fire()
        end
        local isMoveActivation, slot = MoveInput.IsSlotInput(input)
        if isMoveActivation then
            MoveService.ActivateMove:Fire(slotGraph[slot])
        end
    end
    UserInputService.InputBegan:Connect(onInputBegan)
end

function HotbarController:InitMobile()
    local buttons = MobileButtons.Holder.Buttons
    local function onM1Activated()
        MoveService.LightMelee:Fire()
    end
    HudController:AnimateButton(buttons.M1, onM1Activated, buttons.M1.Icon, nil, 0.1)
    MobileButtons.Enabled = Util.platform() == "Mobile"
end

return HotbarController