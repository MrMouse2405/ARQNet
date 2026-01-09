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
local RETRANSMISSION_TIMEOUT = 1000 -- ms (Simple fixed RTO)

--[[
================================================================================
                                Implementation
================================================================================
]]
local types = require('./types')
type ARQStateMachine = types.ARQStateMachine
type Packet = types.Packet
type Payload = types.Payload
type InFlightPacket = types.InFlightPacket
type CommandFun = (arq: ARQStateMachine, id: number, packet: Packet)->()
type ms = types.ms


local COMMANDS_PROCESSORS : {[number] : CommandFun} = require('./commands').COMMANDS_PROCESSORS


local segment = require('./segment')
local signature = require('./signature')
local breakdown = signature.breakdown
local encodeSegmentPush = segment.encodeSegmentPush
local encodeSegmentAcknowledge = segment.encodeSegmentAcknowledge


--[[

    Constructs a new ARQ State Machine.

    Params:
        tx: Callback function to transmit a packet (buffer) to the network.
        rx: Callback function to deliver a payload (buffer) to the application.

    Returns:
        A new ARQStateMachine instance.

]]
local function makeARQ(tx: (packet : Packet)->(), rx: (id: number, payload: Payload)->()) : ARQStateMachine 
	return {
		tx_push_queue = {},
		tx_inflight = {},

		rx_out_of_order = {},

		tx_nxt_sn = 0,
		rx_nxt_sn = 0,

		rtt_variance = 0,
		smoothed_rtt = 0,
		rto = RETRANSMISSION_TIMEOUT,

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
local function transmit(arq : types.ARQStateMachine, id: number, payload: types.Payload)
    local packet : InFlightPacket = {
        packet = encodeSegmentPush(id, arq.tx_nxt_sn, payload),
        sequence_number = arq.tx_nxt_sn,
        first_sent_time = 0,
        last_sent_time = 0,
        current_rto = 0,
        retransmission_count = 0
    }
    table.insert(
        arq.tx_push_queue,
        packet
    )
    arq.tx_nxt_sn += 1
end

--[[
    The main transmission loop (Heartbeat).
]]
local MAX_RTO = types.MAX_RTO
local function process_tx(arq: ARQStateMachine)
    local now = os.clock() 
    -- 1. PROCESS NEW PAYLOADS
    for _, awaiting : InFlightPacket in arq.tx_push_queue do
        awaiting.first_sent_time = now
        awaiting.last_sent_time = now
        awaiting.current_rto = arq.rto
        arq.tx_inflight[awaiting.sequence_number] = awaiting
        arq.tx(awaiting.packet)
    end
    table.clear(arq.tx_push_queue)

    -- RETRANSMISSION LOGIC
    for _, inflight in arq.tx_inflight do
        if now - inflight.last_sent_time > inflight.current_rto then
            -- Timeout detected! 
            inflight.retransmission_count += 1
            -- 1.5x Backoff Strategy
            -- If it failed once, wait 1.5x longer next time.
            -- (Standard TCP is 2x, but games need to be more aggressive)
            inflight.current_rto = math.min(inflight.current_rto * 1.5, MAX_RTO)
            -- Resend
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
	local id, command = breakdown(packet)
	local command_fun: CommandFun? = COMMANDS_PROCESSORS[command]
	if command_fun then
		command_fun(arq, id, packet)
	else
		warn('[ARQNET CRITICAL ERROR] MALFORMED PACKET! SKIPPED!')
	end
end

export type ARQ = {
    makeARQ    : (tx: (packet : Packet)->(), rx: (id: number, payload: Payload)->()) -> ARQ,
    transmit   : (self: ARQ, id: number, payload: buffer)->(),
    recieve    : (self : ARQ)->(),
    process_tx : (self: ARQ)->(),
    process_rx : (self : ARQ, packet: Packet)->(),
    getSRTT    : (self: ARQ) -> ms,
}

type ARQPrivate = types.ARQStateMachine & ARQ;

local ARQ = {}
ARQ.__index = ARQ
   
function ARQ.makeARQ(tx: (packet : Packet)->(), rx: (id: number, payload: Payload)->())
    return setmetatable(makeARQ(tx, rx), ARQ)
end
ARQ.transmit = transmit
ARQ.process_tx = process_tx
ARQ.process_rx = process_rx
function ARQ.getSRTT(self: types.ARQStateMachine):ms
    return self.smoothed_rtt
end

return ARQ