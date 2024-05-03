--[[
    Client side version of the move handler. Contains utility functions related
    to the client side portion of the moves.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ThreadUtil = require(ReplicatedStorage.Shared.Modules.ThreadUtil)
local PlayerUtil = require(ReplicatedStorage.Shared.Modules.PlayerUtil)

local camera = Workspace.CurrentCamera
local player = Players.LocalPlayer

local MoveHandlerClient = {}

function MoveHandlerClient.BindToCutsceneCamera(cutsceneCamera: Model): ()->()
    local conn; conn = RunService.RenderStepped:Connect(function()
        local cameraRoot = cutsceneCamera:FindFirstChild("CameraRoot")
        if cameraRoot then
            camera.CFrame = cameraRoot.CFrame
        end
    end)
    return function()
        conn = ThreadUtil.Disconnect(conn)
    end
end

function MoveHandlerClient.SetCameraSubjectToPlayer()
    local humanoid = PlayerUtil.GetBodyPart(player, "Humanoid")
    camera.CameraType = Enum.CameraType.Custom
    if humanoid then
        camera.CameraSubject = humanoid
    end
end

return MoveHandlerClient
