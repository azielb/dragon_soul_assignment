--// Services
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

--// Dependencies
local Knit = require(ReplicatedStorage.Packages.Knit)
local Util = require(ReplicatedStorage.Shared.Util)

--// Variables
local DEFAULT_MESSAGE = "???"
local DEFAULT_DURATION = 5
local DEFAULT_COLOR = Util.colors.WHITE
local INITIAL_MESSAGE_SIZE = UDim2.fromScale(0, 0)
local TARGET_MESSAGE_SIZE

local NotificationService
local HudController

local MessageFrame
local MessageTemplate = ReplicatedStorage.Storage.UI.Message

local NotificationController = Knit.CreateController { Name = "NotificationController" }

function NotificationController:PlaySound(sound: string | Sound, oneOnly: boolean?)
    oneOnly = oneOnly or false
    if oneOnly then
        local found = SoundService.CurrentlyPlaying:FindFirstChild(sound, true)
        if found then
            return
        end
    end
    sound = SoundService.Sounds:FindFirstChild(sound, true)
    if sound == nil then
        return
    end
    local group = sound:FindFirstAncestorWhichIsA("Folder")
    local parent = (group and group.Name) or "SFX"
    sound = sound:Clone()
    local soundGroup = SoundService.CurrentlyPlaying[parent]
    sound.Parent = soundGroup
    sound.SoundGroup = soundGroup
    sound:Play()
    sound.Ended:Once(function()
        sound:Destroy()
    end)
end

--[[
    data:
        message: string?, --> default: "???"
        color: Color3?, --> default: white
        duration: number?, --> default: 5 seconds
        richText: boolean?, --> default: false
        oneMessageOnly: boolean? --> default: false
]]
function NotificationController:SendNotification(data: {})
    local message = data.message or DEFAULT_MESSAGE
    local duration = data.duration or DEFAULT_DURATION
    local color = data.color or DEFAULT_COLOR
    local richText = data.richText or false
    local oneOnly = data.oneMessageOnly or false
    if oneOnly then
        local found = Util.table.Find(MessageFrame:GetChildren(), function(child: Instance)
            return child:IsA("TextLabel") and child.Text == message
        end)
        if found then
            return
        end
    end
    local clone = MessageTemplate:Clone()
    local stroke = clone.UIStroke

    clone.Size = INITIAL_MESSAGE_SIZE
    clone.Text = message
    clone.RichText = richText
    clone.TextColor3 = color
    stroke.Color = richText and stroke.Color or Util.colorUtil.darken(color, 100)
    clone.Parent = MessageFrame

    Util.spring.target(clone, 0.4, 2.5, {Size = TARGET_MESSAGE_SIZE})
    task.delay(duration, function()
        Util.spring.target(clone, 1, 2, {Size = INITIAL_MESSAGE_SIZE, TextTransparency = 1})
        Util.spring.target(stroke, 1, 2, {Transparency = 1})
        Debris:AddItem(clone, 0.5)
    end)
end

--[[
    data:
        rest same as SendNotification
        sound: string | Sound
        oneSoundOnly: boolean? --> default: false
]]
function NotificationController:SendError(data: {})
    data.color = data.color or Util.colors.RED
    self:PlaySound(data.sound or "Error", data.oneSoundOnly)
    self:SendNotification(data)
end

--[[
    data:
        rest same as SendNotification
        sound: string | Sound
        oneSoundOnly: boolean? --> default: false
]]
function NotificationController:SendSuccess(data: {})
    data.color = data.color or Util.colors.GOLD
    self:PlaySound(data.sound or "Success", data.oneSoundOnly)
    self:SendNotification(data)
end

function NotificationController:KnitInit()
    NotificationService = Knit.GetService("NotificationService")
    HudController = Knit.GetController("HudController")
end

function NotificationController:KnitStart()
    local UI = HudController:GetHud()
    TARGET_MESSAGE_SIZE = MessageTemplate.Size
    MessageFrame = UI.Messages.Messages
    MessageFrame.Visible = true
    local function sendNotification(data: {})
        self:SendNotification(data)
    end
    local function sendError(data: {})
        self:SendError(data)
    end
    local function sendSuccess(data: {})
        self:SendSuccess(data)
    end
    local function playSound(sound: string | Sound, oneOnly: boolean?)
        self:PlaySound(sound, oneOnly)
    end
    NotificationService.SendNotification:Connect(sendNotification)
    NotificationService.SendError:Connect(sendError)
    NotificationService.SendSuccess:Connect(sendSuccess)
    NotificationService.PlaySound:Connect(playSound)
end

return NotificationController
