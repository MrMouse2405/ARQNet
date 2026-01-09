--[[
     /  \        /  \        /  \        /  \        /  \        /  \
__/        \__/        \__/        \__/        \__/        \__/       
  \        /  \        /  \        /  \        /  \        /  \       
     \__/        \__/        \__/        \__/        \__/        \__/
     /  \        /  \        /  \        /  \        /  \        /  \
__/        \__/        \__/        \__/        \__/        \__/       
  \        /  \        /  \        /  \        /  \        /  \       

		█████╗ ██████╗  ██████╗ ███╗   ██╗███████╗████████╗
		██╔══██╗██╔══██╗██╔═══██╗████╗  ██║██╔════╝╚══██╔══╝
		███████║██████╔╝██║   ██║██╔██╗ ██║█████╗     ██║   
		██╔══██║██╔══██╗██║▄▄ ██║██║╚██╗██║██╔══╝     ██║   
		██║  ██║██║  ██║╚██████╔╝██║ ╚████║███████╗   ██║   
		A High Performance, Low Latency, Roblox Networking Library

     \__/        \__/        \__/        \__/        \__/        \__/
     /  \        /  \        /  \        /  \        /  \        /  \
__/        \__/        \__/        \__/        \__/        \__/       
  \        /  \        /  \        /  \        /  \        /  \       
     \__/        \__/        \__/        \__/        \__/        \__/
     /  \        /  \        /  \        /  \        /  \        /  \
__/        \__/        \__/        \__/        \__/        \__/       
  \        /  \        /  \        /  \        /  \        /  \
]]
--[[

	ARQNet Segment

	This is the 'packet' sent over wire containing
	the ARQNet header and user payload.

	------------------------------------------
	|   conversation id < 4 bytes >
	------------------------------------------
	| command <byte> | fragement <byte> |
	------------------------------------------
    |   sequence number < 4 bytes >
	------------------------------------------
	|   timestamp < 4 bytes >
	------------------------------------------
	|   payload
	------------------------------------------


	Conversation ID: To differentiate different events...
	Command: ARQNet Commands
	Sequence Number: For ordering events.
	Timestamp: For Retransmission Timeout Calculations
	Payload: User Payload
]]

export type uint32 = number
export type Payload = buffer
export type Packet = buffer
export type ms = number
export type Command = number
type List<T> = {T}

local signature = require('./signature')
local types = require('./types')
local COMMAND_PUSH = types.COMMAND_PUSH
local COMMAND_ACKNOWLEDGE = types.COMMAND_ACKNOWLEDGE
local SIGN = signature.sign
local SIGNATURE_OFFSET = signature.size()
local HEADER_OFFSET = SIGNATURE_OFFSET + 4
-- header = signature + sequence number

@native
local function encodeSegmentPush(conversation_id : number, sequence_number : number, payload : buffer) : Packet
	local b = buffer.create(HEADER_OFFSET + buffer.len(payload))
	SIGN(conversation_id, COMMAND_PUSH, b)
	buffer.writeu32(b,SIGNATURE_OFFSET,sequence_number)
	buffer.copy(b, HEADER_OFFSET, payload)
	return b
end

--[[

	Returns Sequence Number and Payload
	from decoded Push Packet

]]
@native
local function decodeSegmentPush(packet: Packet)
	local sequence_number = buffer.readu32(packet, SIGNATURE_OFFSET)
	local payload = buffer.create(buffer.len(packet) - HEADER_OFFSET)
	buffer.copy(payload, 0, packet, HEADER_OFFSET)
	return sequence_number, payload
end


@native
local function encodeSegmentAcknowledge(conversation_id: number, sequence_number : number) : Packet
	local b = buffer.create(8)
	SIGN(conversation_id,COMMAND_ACKNOWLEDGE,b)
	buffer.writeu32(b, SIGNATURE_OFFSET, sequence_number)
	return b
end


--[[

	Returns sequence number from decoded Acknowledge Packet

]]
@native
local function decodeSegmentAcknowledge(packet : Packet) : number
	local sequence_number = buffer.readu32(packet, SIGNATURE_OFFSET)
	return sequence_number
end




export type InFlightPacket = {
    packet: Packet,
	sequence_number: number,
    first_sent_time: number,
    last_sent_time: number
}

return {
	encodeSegmentAcknowledge = encodeSegmentAcknowledge,
	decodeSegmentAcknowledge = decodeSegmentAcknowledge,
	
	encodeSegmentPush = encodeSegmentPush,
	decodeSegmentPush = decodeSegmentPush,
}