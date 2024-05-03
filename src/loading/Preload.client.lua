--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

--// Variables
local Assets = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Assets")
ContentProvider:PreloadAsync({Assets})