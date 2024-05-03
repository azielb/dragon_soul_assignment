local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

require(ReplicatedStorage.Shared.MoveHandler) --require the client side move handler to initialize the network setup
Knit.AddControllersDeep(script.Parent.Controllers)
Knit.Start()