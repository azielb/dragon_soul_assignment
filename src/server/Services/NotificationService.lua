--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Dependencies
local Knit = require(ReplicatedStorage.Packages.Knit)

local NotificationService = Knit.CreateService {
    Name = "NotificationService",
    Client = {
        SendNotification = Knit.CreateSignal(),
        SendError = Knit.CreateSignal(),
        SendSuccess = Knit.CreateSignal(),
        PlaySound = Knit.CreateSignal(),
    },
}

function NotificationService:PlaySound(player, sound: string | Sound)
    self.Client.PlaySound:Fire(player, sound)
end

function NotificationService:SendNotification(player, data: {})
    self.Client.SendNotification:Fire(player, data)
end

function NotificationService:SendError(player, data: {})
    self.Client.SendError:Fire(player, data)
end

function NotificationService:SendSuccess(player, data: {})
    self.Client.SendSuccess:Fire(player, data)
end

return NotificationService
