local RunService = game:GetService('RunService')
local Data: Folder = script.Parent.Parent:WaitForChild("data") :: Folder
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if RunService:IsServer() then

    local blink = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('definitions'):WaitForChild('blink_server'))

    blink.fps_hitreg.On(function(Player: Player, ...)  
        print("[BLINK] Received FPS Hit")
    end)

    blink.input_stream.On(function(Player, ...) 
        print('[BLINK] Received Input Stream')
    end)

    blink.save_file_load.On(function(Player, ...) 
        print('[BLINK] Received Save File')
    end)

    blink.voxel_chunk.On(function(Player, ...) 
        print('[BLINK] Received Voxel Chunk')
    end)

    return {}
else
    local blink = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('definitions'):WaitForChild('blink_client'))
    local fps_hitreg = blink.fps_hitreg.Fire
    local input_stream = blink.input_stream.Fire
    local save_file = blink.save_file_load.Fire
    local voxel_chunk = blink.voxel_chunk.Fire
    return {
		[Data:WaitForChild("fps-hitreg")]     = function(data) fps_hitreg(data) end,
		[Data:WaitForChild("input-stream")]   = function(data) input_stream(data) end,
		[Data:WaitForChild("save-file-load")] = function(data) save_file(data) end,
		[Data:WaitForChild("voxel-chunk")]    = function(data) voxel_chunk(data) end,
	}
end