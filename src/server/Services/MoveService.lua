--[[
    Service that initializes the server side move handler
]]

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

--// Dependencies
local Knit = require(ReplicatedStorage.Packages.Knit)
local MoveHandler = require(ReplicatedStorage.Shared.MoveHandler)
local PlayerUtil = require(ReplicatedStorage.Shared.Modules.PlayerUtil)
local Util = require(ReplicatedStorage.Shared.Util)
local ThreadUtil = require(ReplicatedStorage.Shared.Modules.ThreadUtil)

local Spawn = Workspace.Spawn
local GuiFolder = Util.create("Folder", {Name = "Gui", Parent = ReplicatedStorage})

local HUMANOID_DESCRIPTION_PROPS = {
    Head = 0,
    LeftArm = 0,
    RightArm = 0,
    RightLeg = 0,
    LeftLeg = 0,
    Torso = 0,
    WidthScale = 1,
    HeightScale = 1,
    ProportionScale = 0,
    BodyTypeScale = 0,
}

local MoveService = Knit.CreateService {
    Name = "MoveService",
    Client = {
        ActivateMove = Knit.CreateSignal(),
        LightMelee = Knit.CreateSignal(),
    },
}

local function onPlayerAdded(player: Player)
    local function onDied()
        local playerState = MoveHandler.GetPlayerState(player)
        if playerState:GetProperty("cutscenePlaying") then
            playerState.cutsceneEnded:Wait()
        end
        task.wait(Players.RespawnTime)
        PlayerUtil.LoadCharacter(player)
    end
    local function onAdded(character: Model)
        character:PivotTo(Spawn:GetPivot())
    end
    local function applyDescription(character: Model)
        local description = ThreadUtil.Retry(Players.GetHumanoidDescriptionFromUserId, false, 3, Players, player.CharacterAppearanceId)
        local humanoid = character:WaitForChild("Humanoid")
        if description then
            Util.setProperties(description, HUMANOID_DESCRIPTION_PROPS)
            humanoid:ApplyDescription(description)
        end
    end
    Util.table.ApplyOnChildren(GuiFolder, function(gui: ScreenGui)
        gui:Clone().Parent = player.PlayerGui
    end)
    player.CharacterAppearanceLoaded:Connect(applyDescription)
    PlayerUtil.LoadCharacter(player)
    PlayerUtil.OnCharacterAdded(player, onAdded)
    PlayerUtil.OnCharacterDied(player, onDied)
    MoveHandler.OnPlayerAdded(player)
end

function MoveService:KnitInit()
    Util.table.ApplyOnChildren(StarterGui, function(gui: ScreenGui)
        gui.Parent = GuiFolder
    end)
    self.Client.ActivateMove:Connect(MoveHandler.RegisterMove)
    self.Client.LightMelee:Connect(MoveHandler.LightMelee)
    MoveHandler.SpawnNpcs()
end

function MoveService:KnitStart()
    for _, player in Players:GetPlayers() do
        task.spawn(onPlayerAdded, player)
    end
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(MoveHandler.OnPlayerRemoving)
end

return MoveService