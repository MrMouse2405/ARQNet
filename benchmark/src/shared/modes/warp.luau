local RunService = game:GetService('RunService')
local Warp = require(game:GetService('ReplicatedStorage'):WaitForChild('Packages'):WaitForChild('warp'))
 local Data: Folder = script.Parent.Parent:WaitForChild("data") :: Folder

local fps_hitreg = 'fps-hitreg'
local input_stream = 'input-stream'
local save_file = 'save-file-load'
local voxel_chunk = 'voxel-chunk'

if RunService:IsServer() then

    local r0 = Warp.Server(fps_hitreg)
    local r1 = Warp.Server(input_stream)
    local r2 = Warp.Server(save_file)
    local r3 = Warp.Server(voxel_chunk)

    r0:Connect(function(player: Player, ...)  
        print("[WARP] Received FPS Hit")
    end)

    r1:Connect(function(player: Player, ...)  
        print("[WARP] Received Input Stream")
    end)

    r2:Connect(function(player: Player, ...)  
        print("[WARP] Received Save File")
    end)

    r3:Connect(function(player: Player, ...)  
        print("[WARP] Received Voxel Chunk")
    end)

    return {}
else

    local r0 = Warp.Client(fps_hitreg)
    local r1 = Warp.Client(input_stream)
    local r2 = Warp.Client(save_file)
    local r3 = Warp.Client(voxel_chunk)

	return {
		[Data:WaitForChild("fps-hitreg")]     = function(data) r0:Fire(true,data) end,
		[Data:WaitForChild("input-stream")]   = function(data) r1:Fire(true,data) end,
		[Data:WaitForChild("save-file-load")] = function(data) r2:Fire(true,data) end,
		[Data:WaitForChild("voxel-chunk")]    = function(data) r3:Fire(true,data) end,
	}

end