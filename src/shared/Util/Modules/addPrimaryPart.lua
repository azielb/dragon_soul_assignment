return function(model: Model, anchored: boolean?): BasePart
    local primary = model.PrimaryPart
    if primary then
        primary:Destroy()
    end
    local size = model:GetExtentsSize()
    local bb = model:GetBoundingBox()
    local part = Instance.new("Part")
    local modelPivot = model:GetPivot()
    local trueModelCF = bb * (modelPivot - modelPivot.Position):Inverse()
    part.Size = size
    part.Anchored = if anchored == nil then true else anchored
    part.CastShadow = false
    part.CanCollide = false
    part.CanQuery = false
    part.Transparency = 1
    part.Name = "Root"
    part.CFrame = trueModelCF
    part.Parent = model
    model.PrimaryPart = part
    return part
end