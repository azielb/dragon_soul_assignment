--[[
Version 1.0.4

Welcome to the smart animation module for all your world-animation needs :D - Created by cheetamcu


=======================
Smart Animation Settings Template:

Smart_Settings = {
 Type = "Visual" or "Physics" (default = "Visual")| -- physics will interact more w/ the world | no moving through walls and falling | visual will focus more on the animation and will clip through walls and ignore gravity
 Gravity = true or false (default = true) | -- used only during physics mode if you want character to have anti-gravity
 Power = 1; -- used to manually increase the power/distnace in physical animations for straight dashes/rolls without having to redo the animation
}

=======================
Smart Animation Commands:

local smart_track = smart_module:Create(Character.Humanoid : Humanoid, Animation : Animation | AnimationId, Settings : "Smart_Settings")

smart_track:Play(Speed : number, Yield_Code : boolean) -- Plays Smart Animation Track or Resumes a paused animation track

smart_track:Pause() -- pauses the animation if a VISUAL ANIMATION ONLY

======================
Current Limitations:
 - Does not support looping animations
 - Only works on Humanoid Rigs with a lower torso or torso
 - Can not adjust the speed of a smart animation after it has begun
 - Client-Sided Visual Animations are prone to being jittery compared to their physical counter-parts
 - Physical Animations get jittery movement when pushed up against a wall at higher speeds (more distance/less keyframes)

]]--


local keyframeService : KeyframeSequenceProvider = game:GetService('KeyframeSequenceProvider')
local Smart = {
    Storage = {};
    AnimationObject = require(script:WaitForChild('Animation'));
}

function Smart.Check(Animation : Animation | string)
    if not Animation then return error("No animation provided for smart checking!") end

    if not Animation:IsA('Animation') then -- it's a string
        local temp = Animation

        if Smart.Storage[temp] then
            Animation = Smart.Storage[temp] -- retrieve pre-saved animation
        else
            Animation = Instance.new('Animation')
            Animation.AnimationId = temp

            Smart.Storage[temp] = Animation
        end
    end

    local Sequence : KeyframeSequence = keyframeService:GetKeyframeSequenceAsync(Animation.AnimationId)

    for _, frame : Keyframe in pairs(Sequence:GetKeyframes()) do

        if string.find(frame.Name, "CFRAME") then
            return true -- we found 1 cframe position it is a smart animation
        end
    end

    return false -- not a smart animation
end

function Smart.Create(Humanoid : Humanoid, Animation : Animation | string, Settings : "Table for Smart Animation Customization") : "Returns Smart Animation"
    if not Humanoid then return error("No humanoid provided to load animation into!") end
    if not Animation then return error("No animation provided for smart creation!") end
    if Animation:IsA("AnimationTrack") then return error("Smart Animation only accepts Animation Instance or Animation Ids") end
    local self

    if not Animation:IsA('Animation') then -- it's a string
        local temp = Animation

        if Smart.Storage[temp] then
            Animation = Smart.Storage[temp] -- retrieve pre-saved animation
        else
            Animation = Instance.new('Animation')
            Animation.AnimationId = temp

            Smart.Storage[temp] = Animation
        end
    end

    if Smart.Check(Animation) then -- smart animation create the animation object
        self = Smart.AnimationObject.new(Humanoid, Animation, Settings)
    else -- normal animation create normal animation
        self = {}

        self.Raw = Animation
        self.Track = Humanoid:WaitForChild('Animator'):LoadAnimation(Animation)

        self.Play = function()
            self.Track:Play()
        end

        self.AdjustSpeed = function(speed : number)
            self.Track:AdjustSpeed(speed)
        end
    end

    return self
end

return Smart
