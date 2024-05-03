local CollectionService = game:GetService("CollectionService")

local function apply(tag: string, callback: (Instance) -> (), spawnNewThread: boolean?)
    local tagged = CollectionService:GetTagged(tag)
    local tagList = {}
    spawnNewThread = if spawnNewThread == nil then true else spawnNewThread
    local function attemptCallback(instance: Instance)
        if tagList[instance] then
            return
        end
        tagList[instance] = true
        instance.Destroying:Connect(function()
            tagList[instance] = nil
        end)
        callback(instance)
    end
    for _, instance in tagged do
        if spawnNewThread then
            task.spawn(attemptCallback, instance)
        else
            attemptCallback(instance)
        end
    end
    CollectionService:GetInstanceAddedSignal(tag):Connect(attemptCallback)
end

return {
    Tags = {
        NPC = "NPC",
    },
    Apply = apply
}