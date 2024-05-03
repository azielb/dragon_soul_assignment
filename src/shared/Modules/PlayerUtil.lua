local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Util = require(ReplicatedStorage.Shared.Util)
local ThreadUtil = require(ReplicatedStorage.Shared.Modules.ThreadUtil)

local PlayerModule

local function getPlayerModule(): {}
    PlayerModule = PlayerModule or require(Util.waitForChild(Players.LocalPlayer, "PlayerScripts.PlayerModule"))
    return PlayerModule
end

local function getCharacterFromPlayer(player: Player | Model): Model?
    return if player and player:IsA("Player") then player.Character else player
end

local function getCharacter(player: Player | Model): Model?
    local character = getCharacterFromPlayer(player)
    if character == nil then
        return
    end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildWhichIsA("Humanoid")
    if not humanoidRootPart or not humanoid or humanoid.Health <= 0 then
        return
    end
    return character
end

local function getBodyPart(player: Player | Model, bodyPart: string, character: Model?): Instance?
    character = getCharacter(player)
    return character and character:FindFirstChild(bodyPart)
end

local function onCharacterAdded(player: Player, callback: (character: Model?)->()): RBXScriptConnection
    local function charAdded(character: Model?)
        if character == nil then
            return
        end
        if not character:IsDescendantOf(Workspace) then
            character.AncestryChanged:Wait()
        end
        task.spawn(callback, character)
    end
    charAdded(player.Character)
    return player.CharacterAdded:Connect(charAdded)
end

local function onCharacterDied(player: Player, callback: ()->()): RBXScriptConnection
    return onCharacterAdded(player, function(character: Model)
        local humanoid = Util.waitForChild(character, "Humanoid", 10)
        if humanoid == nil then
            return
        end
        humanoid.Died:Once(callback)
    end)
end

local function toggleControls(state: boolean)
    local playerModule = getPlayerModule()
    local controls = playerModule:GetControls()
    local humanoid = getBodyPart(Players.LocalPlayer, "Humanoid")
    if humanoid then
        humanoid.JumpPower = state and StarterPlayer.CharacterJumpPower or 0 --disable the jump button on mobile
    end
    if state then
        controls:Enable()
    else
        controls:Disable()
    end
end

local function isPlayer(arg: any?): boolean
    return typeof(arg) == "Instance" and arg:IsA("Player")
end

local function loadCharacter(player: Player)
    ThreadUtil.Retry(function()
        player:LoadCharacter()
    end)
end

return {
    LoadCharacter = loadCharacter,
    IsPlayer = isPlayer,
    GetBodyPart = getBodyPart,
    ToggleControls = toggleControls,
    OnCharacterAdded = onCharacterAdded,
    OnCharacterDied = onCharacterDied,
    GetCharacterFromPlayer = getCharacterFromPlayer,
    GetCharacter = getCharacter,
}