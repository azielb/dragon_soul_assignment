--[[
    Handles Counter client logic.
]]

local cleanupCallback

local module = {}

function module.BindCamera(moveHandler: {[string]: any}, camera: Model)
    cleanupCallback = moveHandler.BindToCutsceneCamera(camera)
end

function module.Cleanup(moveHandler: {[string]: any})
    if cleanupCallback then
        cleanupCallback = cleanupCallback()
    end
    moveHandler.SetCameraSubjectToPlayer()
end

return module