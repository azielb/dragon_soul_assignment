--[[
    Basic hitbox implementation. Uses spatial query api to determine targets.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Util = require(ReplicatedStorage.Shared.Util)
local PlayerUtil = require(ReplicatedStorage.Shared.Modules.PlayerUtil)

local VEC3_NO_Y = Vector3.new(1, 0, 1)
local V_ZERO = Vector3.zero
local HITBOX_PROPS = {
    Name = "HitboxPart",
    Anchored = true,
    CanCollide = false,
    CanTouch = false,
    Massless = true,
    CanQuery = false,
}

local Hitbox = {}
Hitbox.__index = Hitbox

function Hitbox.new(player: Player | Model, size: Vector3, ignore: {Instance}?, visualize: boolean?)
    local self = setmetatable({}, Hitbox)
    self.size = size
    self.ignoreList = ignore or {}
    self.player = player
    self.visualize = visualize or false
    self.overlapParams = OverlapParams.new()
    self.trove = Trove.new()

    Util.setProperties(self.overlapParams, {FilterType = Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = self.ignoreList})
    self.collision = self:InitializeCollision()
    self.trove:Add(function()
        self.player = nil
        self.collision = nil
        table.clear(self.ignoreList)
    end)
    return self
end

function Hitbox:InitializeCollision(): BasePart
    local character = PlayerUtil.GetCharacter(self.player)
    local z = self.size.Z / 2
    local part = self.trove:Add(Util.create("Part", Util.table.Assign(HITBOX_PROPS, {
        Size = self.size,
        CFrame = character:GetPivot(),
        Transparency = self.visualize and 0.5 or 1,
        Parent = self.visualize and Workspace or nil
    })))
    self.trove:Add(RunService.PostSimulation:Connect(function()
        local pivot = character:GetPivot()
        local velocity = character.PrimaryPart.AssemblyLinearVelocity
        local velocityOffset = if velocity:FuzzyEq(V_ZERO) then V_ZERO else velocity.Unit --Unit is NaN when the velocity is zero
        local offset = (pivot.LookVector.Unit + (velocityOffset * VEC3_NO_Y)) * z
        part:PivotTo(pivot + offset)
    end))
    return part
end

--returns all of the alive characters that the hitbox overlaps
function Hitbox:Query(amount: number?): {Instance}
    local collsion = self.collision
    local character = PlayerUtil.GetCharacter(self.player)
    local result = {}
    if collsion == nil or character == nil then
        return result
    end
    collsion.Parent = Workspace
    local parts = Workspace:GetPartsInPart(collsion, self.overlapParams)
    local position = character:GetPivot().Position
    local function reducer(acc: {Instance}, part: BasePart)
        local char = part:FindFirstChildOfClass("Model") or part.Parent
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            local unregistered = table.find(acc, char) == nil
            if unregistered then
                table.insert(acc, char)
            end
        end
        return acc
    end

    local function sortByClosest(charA: Model, charB: Model)
        local d1 = (charA:GetPivot().Position - position).Magnitude
        local d2 = (charB:GetPivot().Position - position).Magnitude
        return d1 < d2
    end

    collsion.Parent = if self.visualize then Workspace else nil
    result = Util.table.Sort(Util.table.Reduce(parts, reducer, result), sortByClosest)
    return amount and not Util.table.IsEmpty(result) and Util.table.Truncate(result, amount) or result
end

function Hitbox:Destroy()
    self.trove:Destroy()
end

return Hitbox