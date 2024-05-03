local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local lengthCache = {}
local markerCache = {}

local animation = {}

function animation.getAnimationLength(anim: Animation | number): number
    local id = if typeof(anim) == "number" then anim else anim.AnimationId
    if lengthCache[id] then
        return lengthCache[id]
    end
    local success, sequence = pcall(function()
        return KeyframeSequenceProvider:GetKeyframeSequenceAsync(id)
    end)
    if not success then
        return 1
    end
    local keyframes = sequence:GetKeyframes()
    local length = 0
    for i = 1, #keyframes do
        local time = keyframes[i].Time
        if time > length then
            length = time
        end
    end
    if length == 0 then
        return 1
    end
    sequence:Destroy()
    lengthCache[id] = length
    return length
end

function animation.getAnimationEvents(anim: Animation | number): {string}
    local id = if typeof(anim) == "number" then anim else anim.AnimationId
    if markerCache[id] then
        return markerCache[id]
    end
    local success, sequence = pcall(function()
        return KeyframeSequenceProvider:GetKeyframeSequenceAsync(id)
    end)
    if not success then
        return {}
    end
    local markers = {}
    for _, child in sequence:GetDescendants() do
        if child:IsA("KeyframeMarker") then
            table.insert(markers, child.Name)
        end
    end
    markerCache[id] = markers
    return markers
end

return animation