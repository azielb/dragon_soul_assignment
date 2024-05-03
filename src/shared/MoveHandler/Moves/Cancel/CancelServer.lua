--[[
    Handles Cancel server logic.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Promise = require(ReplicatedStorage.Packages.Promise)

local module = {}
module.__index = module

function module.new(_, playerState: {[string]: any}): {[string]: any}
    local self = setmetatable({}, module)
    self.trove = Trove.new()
    self.playerState = playerState
    return self
end

function module:Start(): {[string]: any}
    return self.trove:AddPromise(Promise.new(function()
        self.playerState:CancelCurrentMoves()
    end))
end

function module:Destroy()
    self.trove:Clean()
end

return module