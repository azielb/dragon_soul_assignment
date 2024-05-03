--[[
    Handles Counter server logic.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Util = require(ReplicatedStorage.Shared.Util)
local PlayerUtil = require(ReplicatedStorage.Shared.Modules.PlayerUtil)
local MoveUtil = require(ReplicatedStorage.Shared.MoveHandler.MoveUtil)
local Promise = require(ReplicatedStorage.Packages.Promise)

local module = {}
module.__index = module

function module.new(stats: {[string]: any}, playerState: {[string]: any}): {[string]: any}
    local self = setmetatable({}, module)
    self.trove = Trove.new()
    self.playerState = playerState
    self.stats = stats
    self.inWindupPhase = false
    self.trove:Add(function()
        MoveUtil.StopTracksForPlayer(playerState.player)
        playerState:SetFrozen(false)
        playerState:SetProperty("countering", false)
    end)
    return self
end

function module:Start(): {[string]: any}
    local playerState = self.playerState
    local player = playerState.player
    local root = PlayerUtil.GetBodyPart(player, "HumanoidRootPart")
    local sound, removeParticle, conn
    local track = self.trove:Add(MoveUtil.ConnectAnimationEventsThenPlay(player, "ChargeUp", 1, {
        ChargeUp = function()
            sound = self.trove:Add(Util.sound.play3dLooped("Electricity", root))
            removeParticle = self.trove:Add(select(2, MoveUtil.InsertParticle("CounterElectricity", root)))
        end
    }, self.trove))

    local function onAttacked(victim: Player)
        local victimState = playerState.moveHandler.GetPlayerState(victim)

        self.trove:Remove(conn)
        self.trove:Remove(removeParticle)
        self.trove:Remove(sound)
        Util.sound.play3d("ChurchBell", root)

        victimState:CancelCurrentMoves()
        victimState:SetFrozen(true)
        playerState:SetFrozen(true)

        self.trove:Add(function()
            -- no need to call SetFrozen again on the playerState object
            -- since it is already added in the constructor
            victimState:SetFrozen(false)
        end)
        task.wait(0.5)
        self:InitializeCutscene(victimState)
    end

    return self.trove:AddPromise(Promise.new(function(resolve: ()->())
        self.inWindupPhase = true
        playerState:SetFrozen(true)
        track.Ended:Wait()
        self.inWindupPhase = false
        Util.sound.play3d("ChargeComplete", root)
        playerState:SetFrozen(false)
        conn = self.trove:Add(playerState.attacked:Connect(function(victim: Player)
            self.trove:Add(task.spawn(onAttacked, victim)) --this move may be cleaned up before this completes, need to store the thread
        end))
        playerState:SetProperty("countering", true)
        resolve()
    end))
end

function module:InitializeCutscene(victimState: {[string]: any})
    local playerState = self.playerState
    local attacker = playerState.player
    local victim = victimState.player

    local camera = self.trove:Add(MoveUtil.GetCutsceneCamera())
    local attackerChar = PlayerUtil.GetCharacter(attacker)
    local victimChar = PlayerUtil.GetCharacter(victim)
    local attackerTorso = attackerChar.UpperTorso
    local victimTorso = victimChar.UpperTorso
    local cameraRoot = camera.CameraRoot
    local pivot = attackerChar:GetPivot()
    local look = pivot.LookVector
    local victimCF = CFrame.new((pivot + (look * self.stats.victimDistanceFromChar)).Position, pivot.Position)
    local trailData = self.stats.trailData
    local removeTrail = self.trove:Add(MoveUtil.AddTrail(attackerTorso, trailData.props, trailData.attachmentPositions))
    local removeParticle

    local function playSound(soundName: string)
        Util.sound.play3d(soundName, cameraRoot)
    end
    local function setCutscenePlaying(state: boolean)
        playerState:SetProperty("cutscenePlaying", state)
        victimState:SetProperty("cutscenePlaying", state)
    end

    self.trove:Add(function()
        MoveUtil.StopTracksForPlayer(victim)
        setCutscenePlaying(false)
        self:FireForPlayers({attacker, victim}, "Cleanup")
    end)
    setCutscenePlaying(true)
    victimChar:PivotTo(pivot)
    camera:PivotTo(pivot)
    self:FireForPlayers({attacker, victim}, "BindCamera", camera)
    local attackerTrack = self.trove:Add(MoveUtil.PlayAnimation(attacker, "AdvancedMoveAttacker"))
    local victimTrack = self.trove:Add(MoveUtil.PlayAnimation(victim, "AdvancedMoveVictim"))

    local markers = {
        Dash = function()
            playSound("Dash")
        end,
        Kick = function()
            playSound("OneShotPunch")
            victimState:TakeDamage(self.stats.bigHitDamage, true)
        end,
        Damage = function()
            playSound("AdvancedMovePunch")
            MoveUtil.EmitAndDestroyParticle("MeleeHit", victimTorso)
            victimState:TakeDamage(self.stats.normalHitDamage, true)
        end,
        BigHit = function()
            self.trove:Remove(removeTrail)
            playSound("OneShotPunch")
            victimState:TakeDamage(self.stats.normalHitDamage, true)
        end,
        Tp = function()
            playSound("Teleport")
        end,
        FinalCharge = function()
            removeParticle = self.trove:Add(select(2, MoveUtil.InsertParticle("ElectricChargeUp", attackerChar.LeftHand)))
            playSound("ChargeUp")
        end,
        Impact = function()
            self.trove:Remove(removeParticle)
            playSound("OneShotPunch")
            victimState:TakeDamage(self.stats.bigHitDamage, true)
        end,
    }

    local cameraTrack = self.trove:Add(MoveUtil.ConnectAnimationEventsThenPlay(camera, "AdvancedMoveCamera", 1, markers, self.trove))
    cameraTrack.Stopped:Wait()
    attackerTrack:Stop()
    victimTrack:Stop()
    victimChar:PivotTo(victimCF) --set the victim a bit back from the player
    self:Destroy()
end

function module:Destroy()
    self.trove:Clean()
end

return module