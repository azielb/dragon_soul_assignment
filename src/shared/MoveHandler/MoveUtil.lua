--[[
    Utility functions that can be used from any move.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlayerUtil = require(ReplicatedStorage.Shared.Modules.PlayerUtil)
local Util = require(ReplicatedStorage.Shared.Util)
local Hitbox = require(ReplicatedStorage.Shared.MoveHandler.Hitbox)
local TweenUtil = require(ReplicatedStorage.Shared.Modules.TweenUtil)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Assets = ReplicatedStorage.Storage.Assets
local Effects = Workspace.Effects
local Particles = Assets.Particles
local Moves = script.Parent.Moves
local Melee = script.Parent.Melee

local ANIMATION_TRACK_ATTRIBUTE = "MoveAnimation"
local RAGDOLL_CONSTRAINT_TYPE = "HingeConstraint"

local MoveUtil = {}

function MoveUtil.StopTracks(animator: Animator)
    if animator == nil then
        return
    end
    local tracks = animator:GetPlayingAnimationTracks()
    for _, track: AnimationTrack in tracks do
        if track:GetAttribute(ANIMATION_TRACK_ATTRIBUTE) then
            track:Stop()
        end
    end
end

function MoveUtil.StopTracksForPlayer(player: Player | Model)
    local character = PlayerUtil.GetCharacter(player)
    local animator = character and character:FindFirstChildWhichIsA("Animator", true)
    MoveUtil.StopTracks(animator)
end

function MoveUtil.ConnectAnimationEventsThenPlay(player: Player | Model, animation: Animation | string, speed: number?, markers: {[string]: ()->()}, trove: {[string]: any}?): AnimationTrack?
    local character = PlayerUtil.GetCharacterFromPlayer(player)
    if character == nil then
        return
    end
    animation = typeof(animation) == "string" and MoveUtil.GetAnimation(animation) or animation
    local animator = character:FindFirstChildWhichIsA("Animator", true)
    local track = animator:LoadAnimation(animation)
    Util.table.Apply(markers, function(callback: (arg: any?)->(), markerName: string)
        if trove then
            track:GetMarkerReachedSignal(markerName):Connect(function()
                trove:Add(task.spawn(callback))
            end)
        else
            track:GetMarkerReachedSignal(markerName):Connect(callback)
        end
    end)
    return MoveUtil.PlayAnimation(player, track, speed)
end

function MoveUtil.PlayAnimation(player: Player | Model, animationOrTrackOrString: Animation | AnimationTrack | string, speed: number?): AnimationTrack?
    local character = PlayerUtil.GetCharacterFromPlayer(player)
    if character == nil then
        return warn(`No character found for player {player.Name}`)
    end
    local animator = character:FindFirstChildWhichIsA("Animator", true)
    if typeof(animationOrTrackOrString) == "string" then
        animationOrTrackOrString = MoveUtil.GetAnimation(animationOrTrackOrString)
    end
    if animationOrTrackOrString == nil then
        return warn(`Invalid animation | {debug.traceback()}`)
    end
    local track =
        if animationOrTrackOrString:IsA("Animation")
        then animator:LoadAnimation(animationOrTrackOrString)
        else animationOrTrackOrString

    MoveUtil.StopTracks(animator)
    track:SetAttribute(ANIMATION_TRACK_ATTRIBUTE, true)
    track:Play()
    track:AdjustSpeed(speed or 1)
    return track
end

function MoveUtil.GetAnimation(name: string): Animation?
    return Assets.Animations:FindFirstChild(name, true)
end

function MoveUtil.GetAnimationLength(name: string): number?
    local animation = MoveUtil.GetAnimation(name)
    return animation and Util.animation.getAnimationLength(animation) or 1
end

function MoveUtil.GetCutsceneCamera(): Model
    local camera = Assets.Camera:Clone()
    TweenUtil.Fade(camera:GetDescendants(), false, nil, true)
    camera.Parent = Effects
    return camera
end

function MoveUtil.GetParticle(particle: ParticleEmitter | string): ParticleEmitter
    return typeof(particle) == "string" and Particles:FindFirstChild(particle, true) or particle
end

function MoveUtil.EmitAndDestroyParticle(particle: ParticleEmitter | string, parent: Instance, transformFn: (ParticleEmitter)->()?)
    Util.particle.emitAndDestroyAfter(MoveUtil.GetParticle(particle), parent, nil, transformFn)
end

function MoveUtil.InsertParticle(particle: ParticleEmitter | string, parent: Instance): (ParticleEmitter | {ParticleEmitter}, ()->())
    return Util.particle.insert(MoveUtil.GetParticle(particle), parent)
end

function MoveUtil.CreateHitbox(player: Player | Model, size: Vector3, ignore: {}?): {[string]: any}
    return Hitbox.new(player, size, ignore)
end

function MoveUtil.CreateHitboxForCharacter(player: Player | Model, size: Vector3): {[string]: any}?
    local character = PlayerUtil.GetCharacter(player)
    if character == nil then
        return
    end
    return MoveUtil.CreateHitbox(player, size, {character})
end

function MoveUtil.AddTrail(parent: Instance, trailProps: {[string]: any}, trailPositions: {A0: CFrame, A1: CFrame}): ()->()
    local a0 = Util.create("Attachment", {CFrame = trailPositions.A0, Parent = parent})
    local a1 = Util.create("Attachment", {CFrame = trailPositions.A1, Parent = parent})
    local trail = Util.create("Trail", Util.table.Assign(trailProps or {}, {Attachment0 = a0, Attachment1 = a1, Parent = parent}))
    return function()
        a0:Destroy()
        a1:Destroy()
        trail:Destroy()
    end
end

function MoveUtil.GetMove(moveName: string?): {[string]: any}?
    local module = moveName and Moves:FindFirstChild(moveName)
    if module == nil then
        return warn(`Invalid move: {moveName} | {debug.traceback()}`)
    end
    return require(module)
end

function MoveUtil.GetMelee(meleeName: string): {[string]: any}?
    local module = meleeName and Melee:FindFirstChild(meleeName)
    if module == nil then
        return warn(`Invalid melee attack: {meleeName} | {debug.traceback()}`)
    end
    return require(module)
end

function MoveUtil.GetMoveProperties(moveName: string, ...: string): ...any?
    local move = MoveUtil.GetMove(moveName)
    if move == nil then
        return
    end
    local props = {...}
    local results = {}
    for _, prop in props do
        table.insert(results, move[prop])
    end
    return table.unpack(results)
end

function MoveUtil.GetAllMoves(): {{[string]: any}}
    return Util.table.Reduce(Moves:GetChildren(), function(acc: {}, module: ModuleScript)
        table.insert(acc, require(module))
        return acc
    end, {})
end

function MoveUtil.RagdollApplication(descendant: Instance)
    if not descendant:IsA("Motor6D") then
        return
    end
    local angle = 30
    local part0 = descendant.Part0
    local jointName = descendant.Name
    local jointAttachmentName = `{jointName}Attachment`
    local rigAttachmentName = `{jointName}RigAttachment`
    local attachment0 = descendant.Parent:FindFirstChild(jointAttachmentName) or descendant.Parent:FindFirstChild(rigAttachmentName)
    local attachment1 = part0:FindFirstChild(jointAttachmentName) or part0:FindFirstChild(rigAttachmentName)
    if not attachment0 or not attachment1 then
       return
    end
    Util.create(RAGDOLL_CONSTRAINT_TYPE, {
        LimitsEnabled = true,
        UpperAngle = angle,
        LowerAngle = -angle,
        Attachment0 = attachment0,
        Attachment1 = attachment1,
        Parent = descendant.Parent
    })
    descendant.Enabled = false
end

function MoveUtil.UnragdollApplication(descendant: Instance)
    if descendant:IsA("Motor6D") then
        descendant.Enabled = true
    elseif descendant:IsA(RAGDOLL_CONSTRAINT_TYPE) then
        descendant:Destroy()
    end
end

function MoveUtil.ApplyImpulse(player: Player | Model, force: Vector3, duration: number): {[string]: any}
    local character = PlayerUtil.GetCharacter(player)
    local trove = Trove.new()
    local function executor(resolve: ()->())
        if character == nil then
            return resolve()
        end
        local humanoid = character.Humanoid
        local root = character.PrimaryPart
        local a0 = trove:Add(Util.create("Attachment", {Name = "A0", Parent = root}))

        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        trove:Add(Util.create("VectorForce", {
            Force = force,
            ApplyAtCenterOfMass = true,
            RelativeTo = Enum.ActuatorRelativeTo.World,
            Attachment0 = a0,
            Parent = root,
        }))
        task.wait(duration)
        resolve()
    end
    local function onFinally()
        trove:Clean()
    end
    return Promise.new(executor):finally(onFinally)
end

return MoveUtil