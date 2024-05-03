--[[
    Stores move input information and has some helper functions to determine
    whether input is valid for the specified action type.
]]

local LightMeleeInputs = {
    [Enum.UserInputType.MouseButton1] = true,
    [Enum.KeyCode.ButtonR2] = true,
}
local SlotInputs = {
    [Enum.KeyCode.One] = "1",
    [Enum.KeyCode.Two] = "2",
    -- [Enum.KeyCode.Three] = "3",
    -- [Enum.KeyCode.Four] = "4",
    -- [Enum.KeyCode.Five] = "5",
}

local Input = {}

function Input.IsLightMeleeInput(input: InputObject): boolean
    return LightMeleeInputs[input.KeyCode] == true or LightMeleeInputs[input.UserInputType] == true
end

function Input.IsSlotInput(input: InputObject): (boolean, number)
    local slot = SlotInputs[input.KeyCode]
    return slot ~= nil, slot
end

return Input