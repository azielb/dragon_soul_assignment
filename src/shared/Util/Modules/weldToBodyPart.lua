return function(data: {char: Model, bodyPart: string | BasePart, model: Model | BasePart , pos: CFrame, weldName: string?}): WeldConstraint
    local character = data.char
    local bodyPart = data.bodyPart
    local model = data.model
    local pos = data.pos
    local weldName = data.weldName

    local part = if typeof(bodyPart) == "string" then character:FindFirstChild(bodyPart) else bodyPart
    if part == nil then
        return
    end

    local root = model:IsA("Model") and model.PrimaryPart or model
    if root == nil then
        return warn(`Model is missing primary part ({model.Name})!`)
    end

    local weld = Instance.new("WeldConstraint")

    model:PivotTo(pos) --have to move model before welding

    weld.Name = weldName or "CharacterWeld"
    weld.Part0 = root
    weld.Part1 = part
    weld.Parent = root
    return weld
end