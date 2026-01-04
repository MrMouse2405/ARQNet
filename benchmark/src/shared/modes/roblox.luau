local RunService = game:GetService("RunService")
local RemoteEvent : RemoteEvent
local Data: Folder = script.Parent.Parent:WaitForChild("data") :: Folder
if RunService:IsServer() then
    RemoteEvent = Instance.new('RemoteEvent', script)
    RemoteEvent.Name = "Remote"

    RemoteEvent.OnServerEvent:Connect(function(a0: Player, ...)  
        print('[ROBLOX] Recieved Event.')
    end)

    return {}
else
    RemoteEvent = script:WaitForChild('Remote') :: RemoteEvent

    local function fireServer(data: any)
        RemoteEvent:FireServer(data)
    end

    return {
        [Data:WaitForChild('fps-hitreg')] = fireServer,
        [Data:WaitForChild('input-stream')] = fireServer,
        [Data:WaitForChild('save-file-load')] = fireServer,
        [Data:WaitForChild('voxel-chunk')] = fireServer
    }
end
