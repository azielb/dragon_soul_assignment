local function setGroup(parent: BasePart | Model, group: string)
    if parent == nil then
        return
    end
    local function set(part: BasePart?)
        if part:IsA("BasePart") then
            part.CollisionGroup = group
        end
    end
    set(parent)
    for _, instance in parent:GetDescendants() do
        set(instance)
    end
    parent.DescendantAdded:Connect(set)
end

return {
    SetGroup = setGroup,
    Groups = {
        PLAYER = "Player",
        NPC = "Npc",
    }
}