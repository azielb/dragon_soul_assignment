local keyframeService = game:GetService('KeyframeSequenceProvider')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService('RunService')
local Workspace = game:GetService('Workspace')

local Trove = require(ReplicatedStorage.Packages.Trove)
local Util = require(ReplicatedStorage.Shared.Util)

local Animation = {}
Animation.__index = Animation

local function GetAnimationType(self)
    if string.lower(self.animationType) == "visual" or self.animationType == 1 then
        return 1
    elseif string.lower(self.animationType) == "physics" or string.lower(self.animationType) == "physical" or self.animationType == 2 then
        return 2
    end
    return self.animationType
end

local function Collide(origin, goal, ignorelist)
    local direction = (goal - origin).Unit
    local distance = (origin - goal).Magnitude + .65

    local Rayparams = RaycastParams.new()
    Rayparams.FilterDescendantsInstances = ignorelist
    Rayparams.FilterType = Enum.RaycastFilterType.Exclude

    local raycast = workspace:Raycast(origin, direction * distance, Rayparams)

    if raycast then
        if raycast.Instance and raycast.Instance.CanCollide then
            return true
        end
    end

    return false
end

function Animation:GetCFrames(): {{[string]: any}}
    local frames = {}
    local frameIndex, priorFrame = 1, 0

    table.sort(self.frames, function(index1, index2) -- filter the frames so the timestamps are correct/in-order
        return index1.Time < index2.Time
    end)

    for _, frame in pairs(self.frames) do

        if string.find(frame.Name, "CFRAME") then
            local cframeData = string.split(frame.Name, ";")
            local position = string.split(cframeData[2], ',')

            frames[frameIndex] = {
                Time = (frame.Time - priorFrame);
                Offset = CFrame.new(Vector3.new(position[1], position[2], position[3]) * self.power)
            }

            if RunService:IsClient() and GetAnimationType(self) == 1 then -- do not bother w/ calculations if being performed on server
                if self.furthestFrame then
                    if self.furthestFrame.Magnitude < Vector3.new(position[1], position[2], position[3]).Magnitude then
                        self.furthestFrame = Vector3.new(position[1], position[2], position[3])
                    end
                else
                    self.furthestFrame = Vector3.new(position[1], position[2], position[3])
                end
            end

            priorFrame = frame.Time
            frameIndex += 1
        end
    end

    return frames
end

function Animation:CalculateTweens() : "Calculate the tweens before playing animation every time"
    local tweens = {}
    local initial_location = self.primaryPart.CFrame

    -- for i, frame in self.CFrames do
    --     tweens[i] = self.trove:Add(TweenService:Create(self.primaryPart, TweenInfo.new(frame.Time/self.currentSpeed), {
    --         CFrame = initial_location * frame.Offset
    --     }))
    -- end

    for i, frame in self.CFrames do
        local t = frame.Time/self.currentSpeed
        local f = 2/t
        tweens[i] = {
            time = t,
            Play = function()
                Util.spring.target(self.primaryPart, 1, f, {CFrame = initial_location * frame.Offset})
            end,
            Pause = function()
                Util.spring.stop(self.primaryPart)
            end
        }
        -- tweens[i] = self.trove:Add(TweenService:Create(self.primaryPart, TweenInfo.new(frame.Time/self.currentSpeed), {
        --     CFrame = initial_location * frame.Offset
        -- }))
    end

    return tweens
end

function Animation:CalculateDirections() : "Calculate the Directions"
    local directions = {}
    local initial_location = self.primaryPart.CFrame

    for i, frame : "smart_info" in pairs(self.CFrames) do
        directions[i] = {
            Length = frame.Time/self.currentSpeed; -- goes from 0.3 to 0.2 | does length not timestamp
            Goal = initial_location * (frame.Offset);
        }
    end

    return directions
end

function Animation.new(humanoid: Humanoid, anim: Animation, settings : "Smart settings")
    settings = settings or {}
    local sequence = keyframeService:GetKeyframeSequenceAsync(anim.AnimationId)
    local self = {}
    setmetatable(self, Animation)

    self.raw = anim
    self.humanoid = humanoid
    self.frames = sequence:GetKeyframes()
    self.trove = Trove.new()

    self.primaryPart = self.humanoid.Parent:WaitForChild('HumanoidRootPart') -- should be the prime part
    self.track = self.humanoid:WaitForChild('Animator'):LoadAnimation(self.raw) -- the actual animation track
    self.currentSpeed = 1
    self.gravityForce = 1

    self.power = if settings.power then settings.power else 1
    self.animationType = if settings.type then settings.type else "Visual"
    self.gravity = if GetAnimationType(self) == 2 and settings.Gravity then true else false
    self.CFrames = self:GetCFrames()

    self.trove:Add(function()
        self.primaryPart.Anchored = false
    end)
    return self
end

function Animation:Play(speed: number)
    if speed then
        self.currentSpeed = speed
    end
    local function playAnim()
        self.isPlaying = true
        self.tweens = self:CalculateTweens()
        self.directions = self:CalculateDirections()
        self.playingTween = nil
        self.tweensPlaying = true

        self.track:SetAttribute("MoveAnimation", true)
        self.track:Play() -- does the actual animation
        self.track:AdjustSpeed(self.currentSpeed)

        self.storedCollision = {}
        self.storedAnchored = {}

        if GetAnimationType(self) == 1 then
            if RunService:IsClient() then -- if client must use anti-gravity method to reflect to server
                local antiGrav = self.trove:Add(Instance.new('LinearVelocity'))
                antiGrav.VelocityConstraintMode = Enum.VelocityConstraintMode.Line

                antiGrav.LineVelocity = 0
                antiGrav.LineDirection = Vector3.new(0, -1, 0)
                antiGrav.MaxForce = 10000

                antiGrav.Attachment0 = self.primaryPart:WaitForChild('RootAttachment')
                antiGrav.Name = "Gravity"
                antiGrav.Parent = self.primaryPart

                local overlapParams = OverlapParams.new()
                overlapParams.FilterDescendantsInstances = {self.primaryPart.Parent}
                overlapParams.FilterType = Enum.RaycastFilterType.Exclude

                local list = Workspace:GetPartBoundsInRadius(self.primaryPart.Position, self.furthestFrame.Magnitude * 1.15, overlapParams) -- should give list of collision between us and end goal w/ a little more breathing room
                for _, collision in pairs(list) do
                    if not collision.CanCollide then continue end
                    table.insert(self.storedCollision, collision)
                    if not collision.Anchored then
                        table.insert(self.storedAnchored, collision)
                        collision.Anchored = true
                    end
                    collision.CanCollide = false
                end
            elseif RunService:IsServer() then -- if server anchor for the tween for best visuals
                self.primaryPart.Anchored = true
            end

            for _, tween in pairs(self.tweens) do -- does our movement for us
                if self.track.IsPlaying and self.track.Speed == 0 then -- yield until track starts playing
                    repeat task.wait()
                    until self.track.Speed ~= 0
                end

                tween:Play()
                self.playingTween = tween

                task.wait(tween.time)
                -- tween.Completed:Wait()
                self.playingTween = nil
            end

            self.tweensPlaying = false
        elseif GetAnimationType(self) == 2 then
            if not self.gravity then -- wants 0 gravity
                local antiGrav = self.trove:Add(Instance.new('LinearVelocity'))
                antiGrav.VelocityConstraintMode = Enum.VelocityConstraintMode.Line

                antiGrav.LineVelocity = 0
                antiGrav.LineDirection = Vector3.new(0, -1, 0)
                antiGrav.MaxForce = 10000

                antiGrav.Attachment0 = self.primaryPart:WaitForChild('RootAttachment')
                antiGrav.Name = "Gravity"
                antiGrav.Parent = self.primaryPart

                if self.humanoid then
                    self.storedSpeed = self.humanoid.WalkSpeed
                    self.humanoid.WalkSpeed = 0
                end
            end

            local lastFrameStamp = workspace:GetServerTimeNow()
            for _, directionTable in self.directions do -- does our movement for us
                local loop; loop = self.trove:Add(RunService.Heartbeat:Connect(function(delta)
                    if (workspace:GetServerTimeNow() - lastFrameStamp) < directionTable.Length then
                        local location, goal = self.primaryPart.CFrame, CFrame.new(delta * (directionTable.Goal.Position - self.primaryPart.CFrame.Position).Unit * ((directionTable.Goal.Position - self.primaryPart.CFrame.Position).Magnitude)/directionTable.Length) * self.primaryPart.CFrame
                        if self.gravity then
                            goal += (Vector3.new(0, -1 ,0) * delta * self.gravityForce)
                        end
                        if not Collide(location.Position, goal.Position, {self.primaryPart.Parent}) then
                            self.primaryPart.CFrame = goal
                        end
                    else
                        loop:Disconnect()
                        loop = nil
                    end
                end))

                while loop do
                    task.wait()
                end
                lastFrameStamp = workspace:GetServerTimeNow()
            end
        else
            return warn(self.animationType..' is not a supported animation type!')
        end
        self.track.Stopped:Wait()
        if GetAnimationType(self) == 1 then
            if RunService:IsClient() then -- if client must use anti-gravity method to reflect to server
                for _, collision in self.storedCollision do
                    collision.CanCollide = true
                end

                for _, collision in self.storedAnchored do
                    collision.Anchored = false
                end

                self.primaryPart:FindFirstChild("Gravity"):Destroy()
            elseif RunService:IsServer() then -- if server anchor for the tween for best visuals
                self.primaryPart.Anchored = false
            end

        elseif GetAnimationType(self) == 2 and not self.gravity then
            if self.humanoid then
                self.humanoid.WalkSpeed = self.storedSpeed
            end
            if not self.gravity then
                self.primaryPart:FindFirstChild("Gravity"):Destroy()
            end
        end

        self.isPlaying = false
    end

    if self.isPlaying then
        self:Resume()
    else
        self.trove:Add(task.spawn(playAnim))
    end
end

function Animation:Resume()
    if not self.isPlaying or (self.isPlaying and (self.track.Speed > 0 and not self.playingTween)) then return end

    if self.playingTween then
        self.playingTween:Play()
    end

    self.track:AdjustSpeed(1)
end

function Animation:Pause()
    if self.animationType ~= "Visual" or not self.track.IsPlaying or not self.isPlaying then return end

    self.track:AdjustSpeed(0)

    if self.playingTween then
        self.playingTween:Pause()
    end
end

function Animation:Stop()
    self:Pause()
    self.primaryPart.Anchored = false
end

function Animation:Destroy()
    self.trove:Destroy()
end

return Animation