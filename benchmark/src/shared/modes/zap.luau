local RunService = game:GetService('RunService')
local Data: Folder = script.Parent.Parent:WaitForChild("data") :: Folder
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if RunService:IsServer() then

    local Zap = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('definitions'):WaitForChild('zap_server'))

    Zap.fps_hitreg.SetCallback(function(Player: Player, ...)  
        print("[ZAP] Received FPS Hit")
    end)

    Zap.input_stream.SetCallback(function(Player, ...) 
        print('[ZAP] Received Input Stream')
    end)

    Zap.save_file_load.SetCallback(function(Player, ...) 
        print('[ZAP] Received Save File')
    end)

    Zap.voxel_chunk.SetCallback(function(Player, ...) 
        print('[ZAP] Received Voxel Chunk')
    end)

    return {}
else

    local Zap = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('definitions'):WaitForChild('zap_client'))

    local fps_hitreg = Zap.fps_hitreg.Fire
    local input_stream = Zap.input_stream.Fire
    local save_file = Zap.save_file_load.Fire
    local voxel_chunk = Zap.voxel_chunk.Fire

    return {
		[Data:WaitForChild("fps-hitreg")]     = function(data) fps_hitreg(data) end,
		[Data:WaitForChild("input-stream")]   = function(data) input_stream(data) end,
		[Data:WaitForChild("save-file-load")] = function(data) save_file(data) end,
		[Data:WaitForChild("voxel-chunk")]    = function(data) voxel_chunk(data) end,
	}
end