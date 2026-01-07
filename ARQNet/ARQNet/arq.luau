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

	Adapted from skywind3000's KCP.

	Impelent Automatic Repeat reQuest (ARQ) protocol over roblox's
	unreliable remote events (UDP).

	Optimized for low latency applications. Especially suitable for
	fast paced action games.

	Author: MouseBrilliant, aka MrMouse2405
	Art: Shoutout to www.asciiart.eu

	Other Contributors:
		< Could be you! :)) >
]]
--[[

	API Reference

]]


--[[
================================================================================
                                Configurations
================================================================================

These constants define the operating parameters of the ARQ protocol.
Only modify if you understand the implications on network behavior.
]]

local MAXIMUM_SEGMENT_SIZE = 800
local RETRANSMISSION_TIMEOUT = 1.0 -- Seconds (Simple fixed RTO)



--[[
================================================================================
                                Implementation
================================================================================
]]
local types = require('./types')
type ARQStateMachine = types.ARQStateMachine
type Packet = types.Packet
type Payload = types.Payload
type Segment = types.Segment
type InFlightPacket = types.InFlightPacket
type CommandFun = (arq: ARQStateMachine, segment: Segment)->()
type ms = types.ms

local COMMAND_PUSH : number
local COMMAND_ACKNOWLEDGE : number
local COMMAND_WINDOW_PROBE : number
local COMMAND_WINDOW_SIZE : number
local COMMAND_PROCESSORS : {[number] : CommandFun}
do
	local Commmands = require('./commands')
	COMMAND_PUSH = Commmands.COMMAND_PUSH
	COMMAND_ACKNOWLEDGE = Commmands.COMMAND_ACKNOWLEDGE
	COMMAND_WINDOW_PROBE = Commmands.COMMAND_WINDOW_PROBE
	COMMAND_WINDOW_SIZE = Commmands.COMMAND_WINDOW_SIZE
    COMMANDS_PROCESSORS = Commmands.COMMANDS_PROCESSORS
end


local PairingHeap = require('./pairing_heap')
local Segment = require('./segment')
local encode_packet = Segment.encode_packet
local decode_packet = Segment.decode_packet


--[[

    Constructs a new ARQ State Machine.

    Params:
        tx: Callback function to transmit a packet (buffer) to the network.
        rx: Callback function to deliver a payload (buffer) to the application.

    Returns:
        A new ARQStateMachine instance.

]]
local function makeARQ(tx: (packet : Packet)->(), rx: (payload: Payload)->()) : ARQStateMachine 
	return {
		tx_payload_queue = {},
		tx_inflight = {},

		rx_segment_queue = {},
		rx_out_of_order = {},

		tx_nxt_sn = 0,
		rx_nxt_sn = 0,

		tx = tx,
		rx = rx,
	}
end

--[[

    Queues a payload for transmission.

    The payload is added to the transmission queue and will be wrapped in a
    segment and sent during the next process_tx cycle.

    Params:
        arq: The ARQ state machine.
        payload: The raw data buffer to send.

]]
local function transmit(arq : types.ARQStateMachine, payload: types.Payload)
	table.insert(arq.tx_payload_queue,payload)
end

--[[

    Delivers ordered, reassembled payloads to the application.

    Iterates through the receive queue and calls the rx callback for each
    ready segment, then clears the queue.

    Params:
        arq: The ARQ state machine.

]]
local function recieve(arq: types.ARQStateMachine)
	for _,segment : Segment in ipairs(arq.rx_segment_queue) do
		arq.rx(segment.payload)
	end
	table.clear(arq.rx_segment_queue)
end

--[[

    The main transmission loop (Heartbeat).

    1. Assigns sequence numbers to queued payloads.
    2. Wraps payloads in segments and transmits them.
    3. Manages the retransmission timer for in-flight packets.

    Params:
        arq: The ARQ state machine.

]]
local function process_tx(arq: ARQStateMachine)
	local now : ms = math.floor(workspace:GetServerTimeNow() * 1000)
	local sequence_number = arq.tx_nxt_sn
	for _, payload : Payload in ipairs(arq.tx_payload_queue) do
		--[[
		
			1. Move from queue (Assign Sequence Numbers)
		
		]]
		local segment : Segment = {
			conversation_id = 0,
			command = COMMAND_PUSH,
			sequence_number = sequence_number,
			timestamp = now,
			payload = payload
		}
		--[[ 
		
			2. TX: Send new segments (Move to In-Flight)
	    
			In a real sliding window, we would check window size here before sending
		
		]]
		local packet = encode_packet(segment)
        local inflight : InFlightPacket = {
            segment = segment,
            packet = packet,
            first_sent_time = now,
            last_sent_time = now
        }
        arq.tx_inflight[sequence_number] = inflight
		arq.tx(packet)
		sequence_number += 1
	end
	arq.tx_nxt_sn = sequence_number
	table.clear(arq.tx_payload_queue)
	--[[
	
		3. Retransmission Logic (Check In-Flight Queue)
    
	]]
	for _, inflight in arq.tx_inflight do
        if now - inflight.last_sent_time > RETRANSMISSION_TIMEOUT then
            -- Timeout detected! Resend.
            inflight.last_sent_time = now
            arq.tx(inflight.packet)
        end
    end
end

--[[

    Processes an incoming raw packet from the network.

    Decodes the packet into a segment and dispatches it to the appropriate
    command processor (PUSH, ACK, etc.).

    Params:
        arq: The ARQ state machine.
        packet: The raw incoming buffer.

]]
local function process_rx(arq: ARQStateMachine, packet: Packet)
	local segment: Segment = decode_packet(packet)
	local command: CommandFun? = COMMANDS_PROCESSORS[segment.command]
	if command then
		command(arq, segment)
	else
		warn('[ARQNET CRITICAL ERROR] MALFORMED PACKET! SKIPPED!')
	end
end


return {
    makeARQ = makeARQ,
    transmit = transmit,
    recieve = recieve,
    process_tx = process_tx,
    process_rx = process_rx,
}