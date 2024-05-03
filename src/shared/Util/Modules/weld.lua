local function getArg(data: {[string]: any}, key: string, default: any): any
    local arg = data[key]
    if arg == nil then
        return default
    end
    return arg
end

return function(data: {
    model: Model | Tool,
    weldType: string?,
    excluded: {}?,
    setAnchored: boolean?,
    setRootAnchored: boolean?,
    massless: boolean?
})
    local model = data.model
    local primaryPart = model and model.PrimaryPart
    local weldType = getArg(data, "weldType", "WeldConstraint")
    local excluded = getArg(data, "exlcluded", {})
    local setAnchored = getArg(data, "setAnchored", false)
    local setRootAnchored = getArg(data, "setRootAnchored", true)
    local massless = getArg(data, "massless", true)
    if not primaryPart then
        return warn(`No primary part for {model.Name}`)
    end
    local welds = model:FindFirstChild("Welds")
    if welds then
        welds:ClearAllChildren()
    else
        welds = Instance.new("Folder")
        welds.Name = "Welds"
        welds.Parent = model
    end
    
    local function weldInstance(instance: Instance)
        if instance:IsA("BasePart") and not excluded[instance.Name] then
            local Weld = Instance.new(weldType)
            Weld.Part0 = primaryPart
            Weld.Part1 = instance
            Weld.Parent = welds
        end
    end
    local function setProperties(instance: Instance)
        if instance:IsA("BasePart") then
            instance.Massless = massless
            if instance == primaryPart then
                instance.Anchored = setRootAnchored
            else
                instance.Anchored = setAnchored
            end
        end
    end
    for _, instance in model:GetDescendants() do
        weldInstance(instance)
    end
    for _, instance in model:GetDescendants() do
        setProperties(instance)
    end
    model.DescendantAdded:Connect(function(descendant: Instance)
        weldInstance(descendant)
        setProperties(descendant)
    end)
end