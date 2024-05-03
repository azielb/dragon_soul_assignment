--[[
    Server side version of the move handler. Initializes player & npc state.
    Contains utility functions related to the server side portion of the moves.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local MoveUtil = require(ReplicatedStorage.Shared.MoveHandler.MoveUtil)
local Network = require(ReplicatedStorage.Shared.Modules.Network)
local PlayerState = require(ReplicatedStorage.Shared.MoveHandler.PlayerState)
local PlayerUtil = require(ReplicatedStorage.Shared.Modules.PlayerUtil)
local Util = require(ReplicatedStorage.Shared.Util)
local Knit = require(ReplicatedStorage.Packages.Knit)

local DummyTemplate = ReplicatedStorage.Storage.Assets.DummyTemplate
local DummySpawns = Workspace.DummySpawns
local DummyFolder = Workspace.Dummies

local DUMMY_MASS = Util.mass.getMass(DummyTemplate)

local playerStates = {}

local NotificationService

Knit.OnStart():andThen(function()
    NotificationService = Knit.GetService("NotificationService")
end)

local MoveHandlerServer = {}

--this can also be a model since Npcs can attack as well
function MoveHandlerServer.GetPlayerState(player: Player | Model): {[string]: any}?
    return playerStates[player]
end

function MoveHandlerServer.SetPlayerState(player: Player | Model, state: {[string]: any}?)
    playerStates[player] = state
end

function MoveHandlerServer.GetPlayerStateFromCharacter(character: Model?): {[string]: any}?
    if character == nil then
        return
    end
    local player = Players:GetPlayerFromCharacter(character) or character
    return MoveHandlerServer.GetPlayerState(player)
end

--safely calls the PlayerState method for the given player/npc
function MoveHandlerServer.AttemptCallStateFunction(player: Player | Model, functionName: string, ...): ...any?
    local state = MoveHandlerServer.GetPlayerState(player)
    if state then
        return state[functionName](state, ...)
    end
end

--sets up npc to just do light attacks, although any move that works on a player can work on an npc
function MoveHandlerServer.MakeNpcAttack(state: {[string]: any})
    while true do
        MoveHandlerServer.LightMelee(state.player)
        task.wait(0.1)
    end
end

function MoveHandlerServer.SpawnNpcAtSpawnPoint(spawnPoint: BasePart)
    while true do
        local dummy = DummyTemplate:Clone()
        dummy:PivotTo(spawnPoint.CFrame)
        dummy.Parent = DummyFolder
        local state = MoveHandlerServer.OnPlayerAdded(dummy)
        state.trove:Add(task.delay(1, MoveHandlerServer.MakeNpcAttack, state))
        state.died:Wait()
        task.wait(0.5)
        if state:GetProperty("cutscenePlaying") then
            state.cutsceneEnded:Wait()
        end
        state:Destroy()
        task.wait(1)
    end
end

function MoveHandlerServer.SpawnNpcs()
    Util.table.ApplyOnChildren(DummySpawns, function(spawnPoint: BasePart)
        task.spawn(MoveHandlerServer.SpawnNpcAtSpawnPoint, spawnPoint)
    end)
end

function MoveHandlerServer.SetupActualPlayer(player: Player)
    local state = MoveHandlerServer.GetPlayerState(player)
    local function onCharacterAdded(character: Model)
        local humanoid = character:WaitForChild("Humanoid")
        local root = character:WaitForChild("HumanoidRootPart")
        if root == nil then --need to wait for root to load in before setting the mass
            return
        end
        humanoid.BreakJointsOnDeath = false
        Util.mass.normalize(character, DUMMY_MASS)
    end
    local function onDied()
        local moves = MoveUtil.GetAllMoves()
        Util.table.Apply(moves, function(stats: {[string]: any})
            if stats.resetCooldownOnDeath then
                state:SetMoveCastable(stats.name) --let player cast again when they die
            end
        end)
    end
    PlayerUtil.OnCharacterAdded(player, onCharacterAdded)
    state:Connect("died", onDied)
end

--initialize player state
function MoveHandlerServer.OnPlayerAdded(player: Player | Model): {[string]: any}
    local state = PlayerState.new(player, MoveHandlerServer)
    MoveHandlerServer.SetPlayerState(player, state)
    if not state.isNpc then
        MoveHandlerServer.SetupActualPlayer(player)
    else
        Util.mass.normalize(player, DUMMY_MASS)
    end
    return state
end

--cleanup player state
function MoveHandlerServer.OnPlayerRemoving(player: Player)
    MoveHandlerServer.AttemptCallStateFunction(player, "Destroy")
end

function MoveHandlerServer.CanCast(player: Player | Model, moveName: string, now: number): boolean
    return MoveHandlerServer.AttemptCallStateFunction(player, "CanCast", moveName, now)
end

function MoveHandlerServer.CanAttack(player: Player | Model): boolean
    return MoveHandlerServer.AttemptCallStateFunction(player, "CanAttack")
end

function MoveHandlerServer.AttemptFireClient(player: Player | Model, name, ...)
    if not PlayerUtil.IsPlayer(player) then --this may be called on npcs, so need to verify it's an actual player
        return
    end
    Network:FireClient(player, name, ...)
end

--sets up the move and starts it
function MoveHandlerServer.RegisterMove(player: Player | Model, moveName: string)
    local now = os.clock()
    if not MoveHandlerServer.CanCast(player, moveName, now) then
        if PlayerUtil.IsPlayer(player) then
            NotificationService:SendError(player, {message = "You can't use this move right now!"})
        end
        return
    end
    local playerState = MoveHandlerServer.GetPlayerState(player)
    local move = MoveUtil.GetMove(moveName)
    local moveObject = move.server.new(move, playerState)
    local function destroy()
        moveObject:Destroy()
    end
    playerState:SetProperty("castDebounce", true)
    playerState:SetMoveCastedTime(moveName, now)
    moveObject.trove:Add(function()
        playerState:SetProperty("castDebounce", false)
    end)
    moveObject.trove:Add(task.delay(move.castTime, destroy))
    playerState:RegisterMove(moveObject)
    moveObject:Start():catch(destroy) --start the move sequence
    MoveHandlerServer.AttemptFireClient(player, "CooldownStarted", moveName)
end

--sets up and starts the melee attack
function MoveHandlerServer.LightMelee(player: Player | Model)
    if not MoveHandlerServer.CanAttack(player) then
        return
    end
    local playerState = MoveHandlerServer.GetPlayerState(player)
    local melee = MoveUtil.GetMelee("LightMelee")
    local meleeObject = melee.new(melee, playerState)
    local function onResolved()
        meleeObject:Destroy()
    end
    local function onFinally()
        playerState:SetLightMeleeDebounce(false)
    end
    playerState:SetLightMeleeDebounce(true)
    playerState:RegisterMove(meleeObject)
    meleeObject:Attack():andThen(onResolved):catch(onResolved):finally(onFinally)
end

--stop players from moving their camera during cutscenes
function MoveHandlerServer.ToggleMouseLock(player: Player | Model, state: boolean)
    if not PlayerUtil.IsPlayer(player) then
        return
    end
    player.DevEnableMouseLock = state
end

function MoveHandlerServer.ToggleMovement(player: Player | Model, state: boolean)
    MoveHandlerServer.AttemptFireClient(player, "ToggleControls", state)
    local character = PlayerUtil.GetCharacter(player)
    if character then
        local humanoid = character.Humanoid
        local jumpPower = state and StarterPlayer.CharacterJumpPower or 0
        local walkSpeed = state and StarterPlayer.CharacterWalkSpeed or 0
        Util.setProperties(humanoid, {JumpPower = jumpPower, WalkSpeed = walkSpeed})
    end
end

return MoveHandlerServer