local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

return function(): string
    if GuiService:IsTenFootInterface() then
        return "Console"
    elseif UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
        return "Mobile"
    else
        return "Desktop"
    end
end