local module = {}

function module.getMass(model: Model): number
    local mass = 0
    for _, part in model:GetDescendants() do
        if not part:IsA("BasePart") or part.Massless then
            continue
        end
        mass += part:GetMass()
    end
    return mass
end

function module.normalize(model: Model, defaultMass: number)
    local root = model.PrimaryPart
    if root == nil then
        return
    end
    root.Massless = false
    for _, part in model:GetDescendants() do
        if not part:IsA("BasePart") or part == root then
            continue
        end
        part.Massless = true
    end
    local currentMass = root:GetMass()
    local props = root.CustomPhysicalProperties or PhysicalProperties.new(root.Material)
    local currentDensity = props.Density
    local volume = currentMass / currentDensity
    local targetDensity = defaultMass / volume
    local physicalProps = PhysicalProperties.new(targetDensity, 0, 0)
    root.CustomPhysicalProperties = physicalProps
end

function module.calculateAdjustment(model: Model, defaultMass: number): number
    return module.getMass(model) / defaultMass
end

function module.setMassless(model: Model)
    for _, part in model:GetDescendants() do
        if not part:IsA("BasePart") then
            continue
        end
        part.Massless = true
    end
end

return module