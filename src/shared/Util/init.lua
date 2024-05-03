local RunService = game:GetService("RunService")

local utility = {}

for _, module in script.Modules:GetChildren() do
    utility[module.Name] = require(module)
end

utility.isStudio = function()
    return RunService:IsStudio()
end

utility.isServer = function()
    return RunService:IsServer()
end

return utility