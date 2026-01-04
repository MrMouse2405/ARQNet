local RunService = game:GetService("RunService")
local Data: Folder = script.Parent.Parent:WaitForChild("data") :: Folder
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local bytenet = require(ReplicatedStorage.Packages.bytenet)
local ByteNet =
	require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("bytenet"))

-- ByteNet type aliases
local float32    = ByteNet.float32
local float64    = ByteNet.float64
local uint8      = ByteNet.uint8
local uint16     = ByteNet.uint16
local int32      = ByteNet.int32
local byteString = ByteNet.string
local bool       = ByteNet.bool
local array      = ByteNet.array
local struct     = ByteNet.struct
local map        = ByteNet.map
local packet     = ByteNet.definePacket

-- Namespace
local namespace = ByteNet.defineNamespace("Benchmark", function()

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

	-- Packet definitions
	return {
		fps_hitreg = packet({
			value = struct({
				weaponId  = uint8,
				timestamp = float64,
				originX   = float32,
				originY   = float32,
				originZ   = float32,
				hitData   = array(hitDataStruct),
			}),
		}),

		input_stream = packet({
			value = array(
				struct({
					dt     = float64,
					x      = float32,
					y      = float32,
					jump   = uint8,
					crouch = uint8,
				})
			)
		}),

		save_file_load = packet({
			value = struct({
				userId          = float64,
				description     = byteString,
				inventory       = array(inventoryItemStruct),
				stats           = map(byteString, uint8),
				questsCompleted = array(bool),
			}),
		}),

		voxel_chunk = packet({
			value = bytenet.buff,
		}),
	}
end)

-- Runtime behavior
if RunService:IsServer() then
	namespace.fps_hitreg.listen(function(data, player)
		print("[BYTENET] Received FPS Hit")
	end)

	namespace.input_stream.listen(function(data, player)
		print("[BYTENET] Received Input Stream")
	end)

	namespace.save_file_load.listen(function(data, player)
		print("[BYTENET] Received Save File")
	end)

	namespace.voxel_chunk.listen(function(data, player)
		print("[BYTENET] Received Voxel Chunk")
	end)

	return {}
else
	local fps_hitreg    = namespace.fps_hitreg.send
	local input_stream = namespace.input_stream.send
	local save_file    = namespace.save_file_load.send
	local voxel_chunk  = namespace.voxel_chunk.send

	return {
		[Data:WaitForChild("fps-hitreg")]     = function(data) fps_hitreg(data) end,
		[Data:WaitForChild("input-stream")]   = function(data) input_stream(data) end,
		[Data:WaitForChild("save-file-load")] = function(data) save_file(data) end,
		[Data:WaitForChild("voxel-chunk")]    = function(data) voxel_chunk(data) end,
	}
end
