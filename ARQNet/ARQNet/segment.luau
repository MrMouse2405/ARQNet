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
export type ms = uint32
export type Command = number
type List<T> = {T}

export type Segment  = {
	conversation_id: uint32,
	command : Command,
	sequence_number: uint32,
	timestamp: ms,
	payload: Payload
}

export type InFlightPacket = {
    segment: Segment,
    packet: Packet,
    first_sent_time: number,
    last_sent_time: number
}


@native 
local function encode_packet(segment: Segment) : Packet
	local b = buffer.create(4 + 1 + 4 + 4 + buffer.len(segment.payload))
	buffer.writeu32(b, 0, segment.conversation_id)
	buffer.writeu8(b, 4, segment.command)
	buffer.writeu32(b, 5, segment.sequence_number)
	buffer.writeu32(b, 9, segment.timestamp)
	buffer.copy(b, 13, segment.payload)
	return b
end

@native 
local function decode_packet(packet : Packet) : Segment
	local payload = buffer.create(buffer.len(packet) - 13)
	buffer.copy(payload, 0, packet, 13)
	local segment = {
		conversation_id = buffer.readu32(packet, 0),
		command =  buffer.readu8(packet, 4),
		sequence_number = buffer.readu32(packet, 5),
		timestamp = buffer.readu32(packet, 9),
		payload = payload
	}
	return segment
end

return {
	encode_packet = encode_packet, 
	decode_packet = decode_packet
}