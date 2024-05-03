local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")

local function play3d(sound: Instance | string, parent: Instance?)
    if typeof(sound) == "string" then
        sound = SoundService.Sounds:FindFirstChild(sound, true)
    end
    if sound == nil then
        return
    end
    sound = sound:Clone()
    sound.Parent = parent or Workspace
    sound.Ended:Connect(function()
        sound:Destroy()
    end)
    sound:Play()
end

local function play3dLooped(sound: Instance | string, parent: Instance?): Sound
    if typeof(sound) == "string" then
        sound = SoundService.Sounds:FindFirstChild(sound, true)
    end
    if sound == nil then
        return
    end
    sound = sound:Clone()
    sound.Parent = parent or Workspace
    sound.Looped = true
    sound:Play()
    return sound
end

local function isAudioValid(assetId: number): boolean
    local success, result = pcall(MarketplaceService.GetProductInfo, MarketplaceService, assetId)
    if success and result then
        return result.AssetTypeId == Enum.AssetType.Audio.Value
    end
    return false
end

return {
    play3dLooped = play3dLooped,
    play3d = play3d,
    isAudioValid = isAudioValid,
}