--[[
    Initializes all of the moves and setup networking so each move can communicate
    with its client counterpart.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(ReplicatedStorage.Shared.Util)
local Network = require(ReplicatedStorage.Shared.Modules.Network)
local PlayerUtil = require(ReplicatedStorage.Shared.Modules.PlayerUtil)

local Context = script.Context
local Moves = script.Moves
local Melee = script.Melee

local isServer = Util.isServer()
local MoveHandler = isServer and require(Context.MoveHandlerServer) or require(Context.MoveHandlerClient)

local contextHandlers = {
    server = function(name: string, module: {[string]: any})
        module.server.Fire = function(_, player: Player | Model, callbackName: string, ...: any?)
            if not PlayerUtil.IsPlayer(player) then
                return --this could be an npc, which should be ignored
            end
            Network:FireClient(player, name, callbackName, ...)
        end
        module.server.FireForPlayers = function(_, players: {Player | Model}, callbackName: string, ...: any?)
            players = Util.table.Filter(players, PlayerUtil.IsPlayer) --there could be npcs in the table which should be ignored
            Network:FireForClients(players, name, callbackName, ...)
        end
        module.server.FireOthers = function(self: {[string]: any}, callbackName: string, ...: any?)
            if not PlayerUtil.IsPlayer(self.player) then --just fire to all clients if this is an npc
                return Network:FireAllClients(name, callbackName, ...)
            end
            Network:FireOtherClients(self.player, name, callbackName, ...)
        end
    end,
    client = function(name: string, module: {[string]: any})
        Network:BindEvents({ --setup the client connection
            [name] = function(callbackName: string, ...)
                local callback = module.client[callbackName]
                if callback then
                    callback(MoveHandler, ...)
                end
            end
        })
    end
}

Util.table.ApplyOnChildren(Moves, function(module: ModuleScript)
    local name = module.Name
    local m = require(module)
    local context = isServer and "server" or "client"
    local contextModule = module:FindFirstChild(`{name}{isServer and "Server" or "Client"}`)
    m.name = name
    if contextModule then
        m[context] = require(contextModule)
        contextHandlers[context](name, m)
    end
end)

if isServer then
    Util.table.ApplyOnChildren(Melee, function(module: ModuleScript)
        local name = module.Name
        local m = require(module)
        local contextModule = module:FindFirstChild(`{name}Server`)
        local class = require(contextModule)
        m.name = name
        m.new = class.new
    end)
end

return MoveHandler