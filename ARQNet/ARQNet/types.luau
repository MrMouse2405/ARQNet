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

	ALL MEMBERS TO BE USED BY ARQ PROTOCOL ONLY.

	NOT FOR DIRECT USE.
]]

export type InFlightPacket = {
    packet: Packet,
	sequence_number: uint32,
    first_sent_time: uint32,
    last_sent_time: uint32,
	current_rto: number,
	retransmission_count: number
}


--[[

	ARQ State Machine

	ALL MEMBERS ARE PRIVATE.

	NOT FOR DIRECT USE.
]]
export type ARQStateMachine = {
	tx_push_queue: List<InFlightPacket>,     -- Waiting to be processed
	tx_inflight: Map<SequenceNumber,InFlightPacket>,   -- In-flight (sent, waiting for ACK)

	rx_out_of_order: Map<SequenceNumber,Payload>,   -- Recieved, waiting to be ordered
	
	-- sliding window state
	tx_nxt_sn: uint32,
	rx_nxt_sn: uint32,

	-- round trip time calculations  
	smoothed_rtt : number,
	rtt_variance : number,
	rto: number,

	-- callbacks
	tx : (packet: Packet)->(),
	rx : (id: number, payload : Payload)->()
}


--[[

	RTO Configs

]]

local INTERVAL : ms = 10 -- Granularity (approx 100hz tick)
local MIN_RTO : ms = 50 -- KCP default: 30-50ms (don't go lower than ~3 frames)
local MAX_RTO : ms = 5000 -- Fail fast cap

--[[
================================================================================
                                ARQNet Commands
================================================================================

This module defines the command codes and processing logic for the ARQNet
protocol. Each segment header contains a command byte (cmd) that dictates
the segment's purpose and the receiver's response.

--------------------------------------------------------------------------------
1. COMMAND_PUSH (0)
--------------------------------------------------------------------------------
Description:
    Carries user data payload. This is the primary vehicle for reliable
    data transfer within the protocol.

Semantics:
    - Sequence Number (sn): Identifies the order of the segment in the stream.
    - Fragment (frg): Indicates the number of subsequent fragments required
      to reassemble the application message. 0 denotes the final fragment.

Behavior:
    - Sender: Wraps user data, assigns the next sequence number, and places
      the segment in the transmission queue. A retransmission timer is started.
    - Receiver: Validates the sequence number. If valid and in-order, the
      payload is delivered or buffered. An ACK must be generated immediately.

--------------------------------------------------------------------------------
2. COMMAND_ACKNOWLEDGE (1)
--------------------------------------------------------------------------------
Description:
    Confirms the successful receipt of a specific COMMAND_PUSH segment.

Semantics:
    - Sequence Number (sn): The sequence number of the received PUSH segment.
    - Timestamp (ts): The timestamp copied from the PUSH segment, used by the
      sender to calculate Round Trip Time (RTT).

Behavior:
    - Receiver: Generated automatically upon receipt of a valid PUSH segment.
    - Sender: Upon receipt, removes the corresponding segment from the
      retransmission buffer and updates RTT estimates.

--------------------------------------------------------------------------------
3. COMMAND_WINDOW_PROBE (2)
--------------------------------------------------------------------------------
Description:
    Queries the remote peer for its current receive window size.

Trigger:
    Sent by the sender when the remote window size (rmt_wnd) is known to be
    zero (congested/full), preventing further data transmission. This prevents
    deadlocks if a Window Size Update is lost in transit.

Behavior:
    - Receiver: Must immediately respond with a COMMAND_WINDOW_SIZE segment.

--------------------------------------------------------------------------------
4. COMMAND_WINDOW_SIZE (3)
--------------------------------------------------------------------------------
Description:
    Advertises the current available receive window size to the remote peer.

Trigger:
    - Response to COMMAND_WINDOW_PROBE.
    - (Optional) Asynchronous notification when the receive buffer clears.

Semantics:
    - Window (wnd): The number of segments the receiver can currently accept.
]]
local COMMAND_PUSH = 0
local COMMAND_ACKNOWLEDGE = 1
local COMMAND_WINDOW_PROBE = 2
local COMMAND_WINDOW_SIZE = 3
local TOTAL_COMMANDS = 4

return {
	COMMAND_PUSH = COMMAND_PUSH,
	COMMAND_ACKNOWLEDGE = COMMAND_ACKNOWLEDGE,
	COMMAND_WINDOW_PROBE = COMMAND_WINDOW_PROBE,
	COMMAND_WINDOW_SIZE = COMMAND_WINDOW_SIZE,
	TOTAL_COMMANDS = TOTAL_COMMANDS,
	INTERVAL = INTERVAL,
	MIN_RTO = MIN_RTO,
	MAX_RTO = MAX_RTO
}