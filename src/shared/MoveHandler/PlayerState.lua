--[[
    Object that handles all of the state of its player or npc.
    Each player is assigned a PlayerState object on joining.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)
local MoveUtil = require(ReplicatedStorage.Shared.MoveHandler.MoveUtil)
local Signal = require(ReplicatedStorage.Packages.Signal)
local PlayerUtil = require(ReplicatedStorage.Shared.Modules.PlayerUtil)
local Util = require(ReplicatedStorage.Shared.Util)
local Timer = require(ReplicatedStorage.Packages.Timer)

local HITS_TAKEN_THRESHOLD = 2
local HIT_TAKEN_UPDATE_RATE = 2
local CALLBACK_ERROR_FORMAT = "Update callback for %s encountered an error: %s\nTraceback:\n%s"

local PlayerState = {}
PlayerState.__index = PlayerState

function PlayerState.new(player: Player | Model, moveHandler: {[string]: any}): {}
    local self = setmetatable({}, PlayerState)
    self.player = player
    self.isNpc = PlayerUtil.IsPlayer(player) == false
    self.moveHandler = moveHandler
    self.castDebounce = false
    self.cutscenePlaying = false
    self.propertyChangedCallbacks = {}
    self.castedMoves = {}
    self.registeredMoves = {}
    self.meleeState = {debounce = false, index = 1}
    self.trove = Trove.new()
    self.attacked = self.trove:Add(Signal.new())
    self.hit = self.trove:Add(Signal.new())
    self.died = self.trove:Add(Signal.new())
    self.cutsceneEnded = self.trove:Add(Signal.new())

    self:InitEphemeralState()
    self:BindToProps()
    self:Connect("died", function()
        self:SetProperty("dead", true)
        self:Ragdoll()
    end)

    self.trove:Add(function()
        self.player = nil
        self.moveHandler.SetPlayerState(player, nil)
        table.clear(self.propertyChangedCallbacks)
        self:CancelCurrentMoves()
    end)

    --players have to be hit HITS_TAKEN_THRESHOLD times within this timeframe for a move to cancel
    self.trove:Add(Timer.Simple(HIT_TAKEN_UPDATE_RATE, function()
        self:SetProperty("hitsTaken", 0)
    end))

    if self.isNpc then
        self:SetUpNpc()
    else
        self:SetupPlayer()
    end

    return self
end

function PlayerState:InitEphemeralState() --these will get reset when the player respawns
    self.countering = false
    self.frozen = false
    self.dead = false
    self.damageTaken = 0
    self.hitsTaken = 0
end

function PlayerState:SetUpNpc()
    self.trove:Add(self.player)
    self.player.PrimaryPart:SetNetworkOwner(nil)
end

function PlayerState:SetupPlayer()
    local function onCharacterAdded()
        task.defer(function()
            self:CancelCurrentMoves()
            self:InitEphemeralState()
        end)
    end
    local function onCharacterDied()
        self.died:Fire()
    end
    self.trove:Add(PlayerUtil.OnCharacterAdded(self.player, onCharacterAdded))
    self.trove:Add(PlayerUtil.OnCharacterDied(self.player, onCharacterDied))
end

function PlayerState:Connect(signalName: string, callback: (...any)->()): {[string]: any}
    local signal = self:GetProperty(signalName)
    if signal == nil then
        return warn(`Invalid signal name passed to Connect {signalName} | {debug.traceback()}`)
    end
    return self.trove:Add(signal:Connect(callback))
end

function PlayerState:BindToProps()
    local function onHitsTakenChanged(_, new: number)
        if new >= HITS_TAKEN_THRESHOLD then
            self:CancelCurrentMoves(function(move: {[string]: any})
                return move.inWindupPhase
            end)
        end
    end
    local function onCutscenePlayingChanged(_, playing: boolean)
        self.moveHandler.AttemptFireClient(self.player, "CutsceneStateChanged", playing)
        if not playing then
            self.cutsceneEnded:Fire()
        end
    end
    self.trove:Add(self:BindToPropertyChanged("hitsTaken", onHitsTakenChanged))
    self.trove:Add(self:BindToPropertyChanged("cutscenePlaying", onCutscenePlayingChanged))
end

function PlayerState:GetProperty(prop: string): any?
    local value = self[prop]
    if value == nil then
        return warn(`Invalid PlayerState property: {prop} | {debug.traceback()}`)
    end
    return value
end

function PlayerState:_executeCallbacks(prop: string, old: any, new: any)
    local callbacks = self.propertyChangedCallbacks[prop]
    if callbacks == nil then
        return
    end
    local function execute(callback: (old: any, new: any)->())
        xpcall(callback, function(err: string)
            warn(string.format(CALLBACK_ERROR_FORMAT, prop, err, debug.traceback()))
        end, old, new)
    end
    for _, callback in callbacks do
        task.spawn(execute, callback)
    end
end

function PlayerState:SetProperty(prop: string, value: any?)
    local old = self:GetProperty(prop)
    if old == nil then
        return
    end
    self[prop] = value
    self:_executeCallbacks(prop, old, value)
end

function PlayerState:IncrementProperty(prop: string, amount: number?)
    amount = amount or 1
    local value = self:GetProperty(prop)
    local valueType = typeof(value)
    if valueType ~= "number" then
        return warn(`Invalid property passed to IncrementProperty {prop} | {valueType}`)
    end
    self:SetProperty(prop, amount + value)
end

function PlayerState:BindToPropertyChanged(prop: string, callback: (old: any, new: any)->()): ()->()
    if self:GetProperty(prop) == nil then
        return
    end
    local callbacks = self.propertyChangedCallbacks[prop] or {}
    table.insert(callbacks, callback)
    self.propertyChangedCallbacks[prop] = callbacks
    return function() --unbind function
        local index = table.find(callbacks, callback)
        if index then
            table.remove(callbacks, index)
        end
    end
end

function PlayerState:SetLightMeleeDebounce(state: boolean)
    self.meleeState.debounce = state
end

function PlayerState:SetMoveCastedTime(moveName: string, time: number)
    self.castedMoves[moveName] = time
end

function PlayerState:SetFrozen(state: boolean)
    self:SetProperty("frozen", state)
    self.moveHandler.ToggleMovement(self.player, not state)
    self.moveHandler.ToggleMouseLock(self.player, not state)
end

function PlayerState:CharacterExists(): boolean
    return PlayerUtil.GetCharacter(self.player) ~= nil
end

function PlayerState:CanAttack(): boolean
    return not self:GetProperty("frozen")
    and not self:GetProperty("dead")
    and not self:GetProperty("meleeState").debounce
    and not self:GetProperty("castDebounce")
    and self:CharacterExists()
end

function PlayerState:CanBeAttacked(): boolean
    return not self:GetProperty("cutscenePlaying")
    and not self:GetProperty("countering") --don't take any more damage while countering
    and self:CharacterExists()
end

function PlayerState:RegisterMove(moveObject: {[string]: any})
    moveObject.trove:Add(function()
        self:UnregisterMove(moveObject)
    end)
    table.insert(self.registeredMoves, moveObject)
end

function PlayerState:UnregisterMove(moveObject: {[string]: any} | string)
    local index = table.find(self.registeredMoves, moveObject)
    if index then
        table.remove(self.registeredMoves, index)
    end
end

function PlayerState:GetRegisteredMove(moveName: string): {[string]: any}?
    local move = Util.table.Find(self.registeredMoves, function(m: {[string]: any})
        return m.name == moveName
    end)
    return move
end

function PlayerState:SetMoveCastable(moveName: string)
    local move = self:GetRegisteredMove(moveName)
    if move then
        move:Destroy()
    end
    self:SetMoveCastedTime(moveName, 0)
    self:SetProperty("castDebounce", false)
    self.moveHandler.AttemptFireClient(self.player, "CooldownCancelled", moveName)
end

function PlayerState:CanCast(moveName: string, now: number): boolean
    local move = MoveUtil.GetMove(moveName)
    local castRegardless = move.castRegardless
    local lastCast = self.castedMoves[moveName] or 0
    local cooldownOff = now - lastCast >= move.cooldown
    if castRegardless and cooldownOff then
        return true
    end
    return self:CanAttack() and cooldownOff
end

function PlayerState:CancelCurrentMoves(predicate: ((move: {[string]: any})->boolean)?)
    local registered = self.registeredMoves
    for i = #registered, 1, -1 do
        local move = registered[i]
        if not predicate or predicate(move) then
            move:Destroy()
        end
    end
end

--the ignoreCheck parameter is for taking damage during cutscenes from the attacker, but not from anyone else doing a move
function PlayerState:TakeDamage(amount: number, ignoreCheck: boolean?): boolean
    if not ignoreCheck and not self:CanBeAttacked() then
        return false
    end
    local humanoid = self.player:FindFirstChildWhichIsA("Humanoid") or PlayerUtil.GetBodyPart(self.player, "Humanoid")
    if humanoid == nil then
        return false
    end
    self:IncrementProperty("hitsTaken")
    self:IncrementProperty("damageTaken", amount)
    if humanoid.Health - amount <= 0 and self.isNpc then --players already have a function listening for deaths
        self.died:Fire()
    end
    humanoid:TakeDamage(amount)
    return true
end

function PlayerState:Ragdoll(ignoreCutscene: boolean?): ()->()
    if not ignoreCutscene and self:GetProperty("cutscenePlaying") then
        self.cutsceneEnded:Wait()
    end
    local character = PlayerUtil.GetCharacterFromPlayer(self.player)
    local humanoid = character.Humanoid
    Util.table.ApplyOnChildren(character, MoveUtil.RagdollApplication, true)
    return function()
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        Util.table.ApplyOnChildren(character, MoveUtil.UnragdollApplication, true)
    end
end

function PlayerState:Destroy()
    self.trove:Clean()
end

return PlayerState