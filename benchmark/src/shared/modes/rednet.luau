local RunService = game:GetService('RunService')
local Data: Folder = script.Parent.Parent:WaitForChild("data") :: Folder
local RedNet = require(game:GetService('ReplicatedStorage'):WaitForChild('Packages'):WaitForChild('rednet'))

local Namespace = 'Benchmark'
local fps_hitreg = 'fps-hitreg'
local input_stream = 'input-stream'
local save_file = 'save-file-load'
local voxel_chunk = 'voxel-chunk'


if RunService:IsServer() then
    local Net = RedNet.Server(Namespace)
    Net:On(fps_hitreg, function(player, ...) 
        print("[REDNET] Received FPS Hit")
    end)
    Net:On(input_stream, function(player, ...) 
        print("[REDNET] Received Input Stream")
    end)
    Net:On(save_file, function(player, ...) 
        print("[REDNET] Received Save File")
    end)
    Net:On(voxel_chunk, function(player, ...) 
        print("[REDNET] Received Voxel Chunk")
    end)

    return {}
else
    local Net = RedNet.Client(Namespace)
	return {
		[Data:WaitForChild("fps-hitreg")]     = function(data) Net:Fire(fps_hitreg,data) end,
		[Data:WaitForChild("input-stream")]   = function(data) Net:Fire(input_stream,data) end,
		[Data:WaitForChild("save-file-load")] = function(data) Net:Fire(save_file,data) end,
		[Data:WaitForChild("voxel-chunk")]    = function(data) Net:Fire(voxel_chunk,data) end,
	}
end