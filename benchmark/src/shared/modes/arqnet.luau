local RunService = game:GetService("RunService")
local Data: Folder = script.Parent.Parent:WaitForChild("data") :: Folder
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local arqnet = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('libs'):WaitForChild('ARQNet'))
local squash = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('libs'):WaitForChild('Squash'))

-- Squash types
local float32    = squash.f32
local float64    = squash.f64
local uint8      = squash.u8
local uint16     = squash.u16
local int32      = squash.i32
local byteString = squash.string
local bool       = squash.boolean
local array      = squash.array
local struct     = squash.record
local map        = squash.map

local hitDataStruct = struct({
	hitX       = float32,
	hitY       = float32,
	hitZ       = float32,
	limbId     = uint8,
	normX      = float32,
	normY      = float32,
	normZ      = float32,
	materialId = uint8,
})

local inventoryItemStruct = struct({
	uuid         = byteString,
	name         = byteString,
	qty          = uint8,
	enchanted    = bool,
	durability   = float32,
})

local Packets = {
	fps_hitreg = struct({
		weaponId  = uint8,
		timestamp = float64,
		originX   = float32,
		originY   = float32,
		originZ   = float32,
		hitData   = array(hitDataStruct),
	}),

	input_stream = array(
		struct({
			dt     = float64,
			x      = float32,
			y      = float32,
			jump   = uint8,
			crouch = uint8,
		})
	),

	save_file_load = struct({
		userId          = float64,
		description     = byteString,
		inventory       = array(inventoryItemStruct),
		stats           = map(byteString, uint8),
		questsCompleted = array(bool),
	}),

	voxel_chunk = squash.buffer,
}

if RunService:IsServer() then

    arqnet.recieve(function(payload: buffer)  
        print('[ARQNet] Recieved')
    end)

	return {}
else
	return {
		[Data:WaitForChild("fps-hitreg")]     = function(data) arqnet.send(Packets.fps_hitreg.ser(squash.cursor(), data)) end,
		[Data:WaitForChild("input-stream")]   = function(data) arqnet.send(Packets.input_stream.ser(squash.cursor(), data)) end,
		[Data:WaitForChild("save-file-load")] = function(data) arqnet.send(Packets.save_file_load.ser(squash.cursor(), data)) end,
		[Data:WaitForChild("voxel-chunk")]    = function(data) arqnet.send(data) end,
	}
end
