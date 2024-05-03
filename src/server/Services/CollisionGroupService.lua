--// Services
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Dependencies
local Knit = require(ReplicatedStorage.Packages.Knit)
local CollisionGroupUtil = require(ReplicatedStorage.Shared.Modules.CollisionGroupUtil)
local CollectionServiceUtil = require(ReplicatedStorage.Shared.Modules.CollectionServiceUtil)
local PlayerUtil = require(ReplicatedStorage.Shared.Modules.PlayerUtil)

--// Variables
local Groups = CollisionGroupUtil.Groups

local CollisionGroupService = Knit.CreateService {Name = "CollisionGroupService"}

local function setCharacterGroup(character: Model)
    CollisionGroupUtil.SetGroup(character, CollisionGroupUtil.Groups.PLAYER)
end

local function onPlayerAdded(player: Player)
    PlayerUtil.OnCharacterAdded(player, setCharacterGroup)
end

function CollisionGroupService:_setGroup(group1: string, group2: string, state: boolean)
    PhysicsService:CollisionGroupSetCollidable(group1, group2, state)
end

function CollisionGroupService:_initGroupsCollision()
    self:_setGroup(Groups.PLAYER, Groups.PLAYER, false)
    self:_setGroup(Groups.PLAYER, Groups.NPC, false)
    self:_setGroup(Groups.NPC, Groups.NPC, false)
end

function CollisionGroupService:_bulkSetGroup(tag: string, group: string)
    CollectionServiceUtil.Apply(tag, function(instance: Instance)
        CollisionGroupUtil.SetGroup(instance, group)
    end)
end

function CollisionGroupService:KnitInit()
    for _, name in CollisionGroupUtil.Groups do
        PhysicsService:RegisterCollisionGroup(name)
    end
    self:_initGroupsCollision()
end

function CollisionGroupService:KnitStart()
    for _, player in Players:GetPlayers() do
        task.spawn(onPlayerAdded, player)
    end
    Players.PlayerAdded:Connect(onPlayerAdded)
end

return CollisionGroupService