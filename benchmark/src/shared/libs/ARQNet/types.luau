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
export type uint32 = number
export type Payload = buffer
export type Packet = buffer
export type ms = uint32
export type Command = number
export type SequenceNumber = uint32


type List<T> = {T}
type Map<K,V> = {[K]: V}



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


--[[

	ARQ State Machine
]]

export type ARQStateMachine = {
	tx_payload_queue: List<Payload>,     -- Waiting to be processed
	tx_inflight: Map<SequenceNumber,InFlightPacket>,   -- In-flight (sent, waiting for ACK)

	rx_segment_queue: List<Segment>, -- Ready for user to read
	rx_out_of_order: Map<SequenceNumber,Segment>,   -- Recieved, waiting to be ordered
	
	tx_nxt_sn: uint32,
	rx_nxt_sn: uint32,

	tx : (packet: Packet)->(),
	rx : (payload : Payload)->()
}

return {}