--[[
    Handles Light Melee server logic.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Util = require(ReplicatedStorage.Shared.Util)
local MoveUtil = require(ReplicatedStorage.Shared.MoveHandler.MoveUtil)
local Promise = require(ReplicatedStorage.Packages.Promise)
local PlayerUtil = require(ReplicatedStorage.Shared.Modules.PlayerUtil)

local Assets = ReplicatedStorage.Storage.Assets
local LightMeleeAnimations = Assets.Animations.LightMelee

local numLightMeleeHits = #LightMeleeAnimations:GetChildren()
local rng = Random.new()

local module = {}
module.__index = module

function module.new(stats: {[string]: any}, playerState: {[string]: any}): {[string]: any}
    local self = setmetatable({}, module)
    self.playerState = playerState
    self.stats = stats
    self.trove = Trove.new()
    return self
end

function module:GetDamage(): (number, boolean)
    local critical = rng:NextNumber(0, 100) < self.stats.criticalChance
    local damage = critical and self.stats.damage * self.stats.criticalDamageMultiplier or self.stats.damage
    return damage, critical
end

function module:Attack(): {[string]: any}
    local playerState = self.playerState
    local meleeState = playerState.meleeState
    local player = playerState.player

    local animationIndex = meleeState.index
    local nextIndex = animationIndex % numLightMeleeHits + 1
    local isLast = animationIndex == numLightMeleeHits
    local animation = LightMeleeAnimations[animationIndex]
    local animationLength = Util.animation.getAnimationLength(animation)
    local cooldown = isLast and self.stats.finalHitCooldown or self.stats.normalHitCooldown --let the last hit fade out
    local speed = animationLength / self.stats.normalHitCooldown
    local hitbox = self.trove:Add(MoveUtil.CreateHitboxForCharacter(player, self.stats.hitboxSize))
    local root = PlayerUtil.GetBodyPart(player, "HumanoidRootPart")
    local markers = {
        Hit = function()
            local char = hitbox:Query(1)[1]
            local targetState = playerState.moveHandler.GetPlayerStateFromCharacter(char)
            if targetState == nil then
                return
            end
            targetState.attacked:Fire(player) --still need to let the state object know that it's been attacked
            local damage, critical = self:GetDamage()
            local success = targetState:TakeDamage(damage)
            if not success then
                return
            end
            local sound = critical and "OneShotPunch" or "Punch"
            local particleColor = critical and Util.colors.RED or Util.colors.WHITE
            Util.sound.play3d(sound, root)
            MoveUtil.EmitAndDestroyParticle("MeleeHit", char.PrimaryPart, function(particle: ParticleEmitter)
                particle.Color = ColorSequence.new(particleColor)
            end)
        end
    }

    return self.trove:AddPromise(Promise.new(function(resolve: ()->())
        meleeState.index = nextIndex --update index so the next animation is played
        self.trove:Add(MoveUtil.ConnectAnimationEventsThenPlay(player, animation, speed, markers, self.trove))
        Util.sound.play3d("PunchSwing", root)
        task.wait(cooldown)
        resolve()
    end))
end

function module:Destroy()
    self.trove:Clean()
end

return module