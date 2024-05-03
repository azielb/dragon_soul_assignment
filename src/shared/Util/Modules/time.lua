local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local isServer = RunService:IsServer()

local function getCurrentTime(): number
    return isServer and os.time() or Workspace:GetServerTimeNow()
end

return {
    HOUR_IN_SECONDS = 60 * 60,
    DAY_IN_SECONDS = 60 * 60 * 24,
    getCurrentTime = getCurrentTime,
}