local RunService = game:GetService("RunService")
local Data: Folder = script.Parent.Parent:WaitForChild("data") :: Folder
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local arqnet = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('libs'):WaitForChild('ARQNet'))
local sera = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('libs'):WaitForChild('Sera'))

-- Sera Helpers
local function SeraArray(itemType)
	return table.freeze({
		Name = "Array",
		Ser = function(b, offset, value)
			local count = #value
			buffer.writeu16(b, offset, count)
			offset += 2
			for i = 1, count do
				offset = itemType.Ser(b, offset, value[i])
			end
			return offset
		end,
		Des = function(b, offset)
			local count = buffer.readu16(b, offset)
			offset += 2
			local result = table.create(count)
			for i = 1, count do
				local val
				val, offset = itemType.Des(b, offset)
				result[i] = val
			end
			return result, offset
		end,
	})
end

local function SeraStruct(params)
	local fields = {}
	for k, v in pairs(params) do
		table.insert(fields, {Key = k, Type = v})
	end
	table.sort(fields, function(a, b) return a.Key < b.Key end)

	return table.freeze({
		Name = "Struct",
		Ser = function(b, offset, value)
			for _, field in ipairs(fields) do
				offset = field.Type.Ser(b, offset, value[field.Key])
			end
			return offset
		end,
		Des = function(b, offset)
			local result = {}
			for _, field in ipairs(fields) do
				local val
				val, offset = field.Type.Des(b, offset)
				result[field.Key] = val
			end
			return result, offset
		end,
	})
end

local function SeraMap(keyType, valueType)
	return table.freeze({
		Name = "Map",
		Ser = function(b, offset, value)
			local count = 0
			for _ in pairs(value) do count += 1 end
			buffer.writeu16(b, offset, count)
			offset += 2
			for k, v in pairs(value) do
				offset = keyType.Ser(b, offset, k)
				offset = valueType.Ser(b, offset, v)
			end
			return offset
		end,
		Des = function(b, offset)
			local count = buffer.readu16(b, offset)
			offset += 2
			local result = {}
			for _ = 1, count do
				local k, v
				k, offset = keyType.Des(b, offset)
				v, offset = valueType.Des(b, offset)
				result[k] = v
			end
			return result, offset
		end,
	})
end

local function Serialize(type, value)
	local offset = type.Ser(sera.BB, 0, value)
	local b = buffer.create(offset)
	buffer.copy(b, 0, sera.BB, 0, offset)
	return b
end

local hitDataStruct = SeraStruct({
	hitX       = sera.Float32,
	hitY       = sera.Float32,
	hitZ       = sera.Float32,
	limbId     = sera.Uint8,
	normX      = sera.Float32,
	normY      = sera.Float32,
	normZ      = sera.Float32,
	materialId = sera.Uint8,
})

local inventoryItemStruct = SeraStruct({
	uuid         = sera.String8,
	name         = sera.String8,
	qty          = sera.Uint8,
	enchanted    = sera.Boolean,
	durability   = sera.Float32,
})

local Packets = {
	fps_hitreg = SeraStruct({
		weaponId  = sera.Uint8,
		timestamp = sera.Float64,
		originX   = sera.Float32,
		originY   = sera.Float32,
		originZ   = sera.Float32,
		hitData   = SeraArray(hitDataStruct),
	}),

	input_stream = SeraArray(
		SeraStruct({
			dt     = sera.Float64,
			x      = sera.Float32,
			y      = sera.Float32,
			jump   = sera.Uint8,
			crouch = sera.Uint8,
		})
	),

	save_file_load = SeraStruct({
		userId          = sera.Float64,
		description     = sera.String16,
		inventory       = SeraArray(inventoryItemStruct),
		stats           = SeraMap(sera.String8, sera.Uint8),
		questsCompleted = SeraArray(sera.Boolean),
	}),

	voxel_chunk = sera.Buffer32,
}

if RunService:IsServer() then

    arqnet.recieve(function(payload: buffer)  
        print('[ARQNet] Recieved')
    end)

	return {}
else
	return {
		[Data:WaitForChild("fps-hitreg")] = function(data)
            arqnet.send(Serialize(Packets.fps_hitreg, data))
        end,
		[Data:WaitForChild("input-stream")] = function(data)
            arqnet.send(Serialize(Packets.input_stream, data))
        end,
		[Data:WaitForChild("save-file-load")] = function(data)
            arqnet.send(Serialize(Packets.save_file_load, data))
        end,
		[Data:WaitForChild("voxel-chunk")]    = function(data)
            arqnet.send(Serialize(Packets.voxel_chunk, data))
        end,
	}
end
