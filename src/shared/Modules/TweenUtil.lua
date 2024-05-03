local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Util = require(ReplicatedStorage.Shared.Util)
local ThreadUtil = require(ReplicatedStorage.Shared.Modules.ThreadUtil)

local faded = {}
local connections = {}
local calls = {}

local classProperties = {
    ImageLabel = {"ImageTransparency", "BackgroundTransparency"},
    ImageButton = {"ImageTransparency", "BackgroundTransparency"},
    TextButton = {"BackgroundTransparency", "TextTransparency"},
    TextLabel = {"BackgroundTransparency", "TextTransparency"},
    Frame = {"BackgroundTransparency"},
    UIStroke = {"Transparency"},
    MeshPart = {"Transparency"},
    Part = {"Transparency"},
    UnionOperation = {"Transparency"},
    Texture = {"Transparency"},
    Decal = {"Transparency"},
    Highlight = {"FillTransparency", "OutlineTransparency"},
}

local function tweenImmediate(instance: Instance, tweenInfo: TweenInfo?, properties: {}, callback: () -> ()?): Tween
    if instance == nil or instance.Parent == nil then
        return
    end
    local tween = TweenService:Create(instance, tweenInfo or TweenInfo.new(1), properties)
    tween:Play()
    tween.Completed:Once(function()
        tween:Destroy()
        tween = nil
        if callback then
            task.spawn(callback)
        end
    end)
    return tween
end

local function tweenWait(instance: Instance, tweenInfo: TweenInfo?, properties: {}, callback: () -> ()?)
    if instance == nil or instance.Parent == nil then
        return
    end
    local tween = TweenService:Create(instance, tweenInfo or TweenInfo.new(1), properties)
    tween:Play()
    tween.Completed:Wait()
    if callback then
        task.spawn(callback)
    end
    tween:Destroy()
    tween = nil
end

local function fade(descendants: {Instance}, state: boolean, frequency: number?, instant: boolean?)
    local function handleInstance(instance: Instance)
        local properties = classProperties[instance.ClassName]
        if properties == nil then
            return
        end
        connections[instance] = connections[instance] or instance.Destroying:Connect(function()
            faded[instance] = Util.table.Clear(faded[instance])
            calls[instance] = nil
            connections[instance] = ThreadUtil.Disconnect(connections[instance])
        end)

        local original = faded[instance] or {}
        for _, property in properties do
            local originalValue = original[property] or instance[property]
            local value = state and originalValue or 1
            original[property] = originalValue
            if instant then
                instance[property] = value
            else
                Util.spring.target(instance, 1, frequency, {[property] = value})
            end
        end
        faded[instance] = original
    end
    for _, instance in descendants do
        task.spawn(handleInstance, instance)
    end
end

local function massFade(parent: GuiObject, state: boolean, frequency: number?, delayTime: number?, setDescendantsVisible: boolean?, waitToEnd: boolean?)
    local isGuiObject = parent:IsA("GuiObject")
    if not state and isGuiObject and not parent.Visible then
        return
    end
    frequency = frequency or 2
    delayTime = delayTime or 0.5
    setDescendantsVisible = if setDescendantsVisible == nil then false else setDescendantsVisible
    local descendants = Util.table.Filter(parent:GetDescendants(), function(instance: Instance)
        return CollectionService:HasTag(instance, "IgnoreFade") == false --viewport frames in UI
    end)
    if setDescendantsVisible then
        for _, descendant in descendants do
            if descendant:IsA("GuiObject") then
                descendant.Visible = true
            end
        end
    end
    local thisCall = (calls[parent] or 0) + 1
    if isGuiObject then
        calls[parent] = thisCall
        parent.Visible = true
        table.insert(descendants, 1, parent)
    end
    fade(descendants, state, frequency)
    task.delay(delayTime, function()
        if isGuiObject and thisCall == calls[parent] then
            parent.Visible = state
        end
    end)
    if waitToEnd then
        task.wait(delayTime)
    end
end

local function massFadeInstant(parent: GuiObject, state: boolean)
    parent.Visible = state
    local descendants = Util.table.Filter(parent:GetDescendants(), function(instance: Instance)
        return CollectionService:HasTag(instance, "IgnoreFade") == false --viewport frames in UI
    end)
    fade(descendants, state, nil, true)
end

local function massFadeModel(model: Model | BasePart, state: boolean, frequency: number?)
    frequency = frequency or 2
    local descendants = Util.table.Filter(model:GetDescendants(), function(instance: Instance)
        if instance:IsA("BasePart") and CollectionService:HasTag(instance, "IgnoreFade") then
            return false
        end
        return true --there might be things other than baseparts that need to get faded out
    end)
    if model:IsA("BasePart") and not state and model.Transparency ~= 1 then
        table.insert(descendants, 1, model)
    end
    fade(descendants, state, frequency)
end

local function _doRotation(guiObj: GuiObject, angle: number, delay: number?)
    delay = delay or 0.15
    local function goto(rotation: number)
        Util.spring.target(guiObj, 0.5, 4, {Rotation = rotation})
    end
    goto(-angle)
    task.delay(delay, function()
        goto(angle)
        task.wait(delay)
        goto(0)
    end)
end

local function rotate(guiObj: GuiObject, angle: number, delay: number?, forever: boolean?): (()->())?
    if not forever then
        return _doRotation(guiObj, angle, delay)
    end
    local thread = task.spawn(function()
        while true do
            _doRotation(guiObj, angle, delay)
            task.wait(1)
        end
    end)
    return function()
        ThreadUtil.Cancel(thread)
    end
end

local function _smoothRotation(guiObj: GuiObject, angle: number, delay: number?)
    local function goto(rotation: number)
        tweenWait(guiObj, TweenInfo.new(delay, Enum.EasingStyle.Linear), {Rotation = rotation})
    end
    goto(-angle)
    goto(0)
    goto(angle)
    goto(0)
end

local function smoothRotation(guiObj: GuiObject, angle: number, delay: number?, forever: boolean?): (()->())?
    if not forever then
        task.spawn(_smoothRotation, guiObj, angle, delay)
        return
    end
    local thread = task.spawn(function()
        while true do
            _smoothRotation(guiObj, angle, delay)
        end
    end)
    return function()
        ThreadUtil.Cancel(thread)
    end
end

return {
    SmoothRotation = smoothRotation,
    MassFadeInstant = massFadeInstant,
    MassFadeModel = massFadeModel,
    MassFade = massFade,
    Fade = fade,
    TweenImmediate = tweenImmediate,
    TweenWait = tweenWait,
    Rotate = rotate,
}