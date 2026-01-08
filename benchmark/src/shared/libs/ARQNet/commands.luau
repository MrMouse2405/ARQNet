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
================================================================================
                                ARQNet Commands
================================================================================

This module defines the command codes and processing logic for the ARQNet
protocol. Each segment header contains a command byte (cmd) that dictates
the segment's purpose and the receiver's response.

--------------------------------------------------------------------------------
1. COMMAND_PUSH (81)
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
2. COMMAND_ACKNOWLEDGE (82)
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
3. COMMAND_WINDOW_PROBE (83)
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
4. COMMAND_WINDOW_SIZE (84)
--------------------------------------------------------------------------------
Description:
    Advertises the current available receive window size to the remote peer.

Trigger:
    - Response to COMMAND_WINDOW_PROBE.
    - (Optional) Asynchronous notification when the receive buffer clears.

Semantics:
    - Window (wnd): The number of segments the receiver can currently accept.
]]
local COMMAND_PUSH = 81
local COMMAND_ACKNOWLEDGE = 82
local COMMAND_WINDOW_PROBE = 83
local COMMAND_WINDOW_SIZE = 84

local types = require('./types')
local segment = require('./segment')
local _empty_buffer = buffer.create(0)
local encode_packet = segment.encode_packet
local decode_packet = segment.decode_packet

--[[

    Processes a received PUSH command (Data Segment).

    1. Sends an immediate ACK for the received sequence number.
    2. Checks if the segment is in order.
    3. If in order, queues it for the application.
    4. If out of order (future), buffers it.
    5. If duplicate, ignores the payload (ACK is still sent).

    Params:
        arq: The ARQ state machine.
        segment: The decoded segment containing user data.

]]
local function process_command_push(arq: types.ARQStateMachine, segment: types.Segment)
	-- acknowledging
	local ack_seg : types.Segment = {
        conversation_id = segment.conversation_id,
        command = COMMAND_ACKNOWLEDGE,
        sequence_number = segment.sequence_number,
        timestamp = segment.timestamp,
        payload = _empty_buffer
    }
    arq.tx(encode_packet(ack_seg))
	-- ordering
	if segment.sequence_number == arq.rx_nxt_sn then
		table.insert(arq.rx_segment_queue,segment)
		arq.rx_nxt_sn += 1
		while arq.rx_out_of_order[arq.rx_nxt_sn] do
			table.insert(arq.rx_segment_queue,arq.rx_out_of_order[arq.rx_nxt_sn])
			arq.rx_out_of_order[arq.rx_nxt_sn] = nil
			arq.rx_nxt_sn += 1
		end
	elseif segment.sequence_number > arq.rx_nxt_sn then
		-- future packet
		arq.rx_out_of_order[segment.sequence_number] = segment
	else
		--it's a duplicate packet
	end
end

--[[

]]
type ms = number
local INTERVAL : ms = 10 -- Granularity (approx 100hz tick)
local MIN_RTO : ms = 50 -- KCP default: 30-50ms (don't go lower than ~3 frames)
local MAX_RTO : ms = 5000 -- Fail fast cap

-- Assumes segment.timestamp was set using os.clock() when sent
local function calculate_rtt(arq: types.ARQStateMachine, packet: types.InFlightPacket)
    -- 1. Karn's Algorithm: Ignore RTT samples from retransmitted segments
    -- We can't tell if this ACK is for the original or the retry.
    if packet.retransmission_count > 0 then
        return
    end
    local segment = packet.segment

    -- 2. Use os.clock() for high-precision local delta, then convert to ms
    local now = os.clock() 
    local rtt_seconds = now - segment.timestamp -- Use local timestamp
    local rtt : ms = math.floor(rtt_seconds * 1000)

    -- Sanity check for negative RTT (clock skew/reset edge cases)
    if rtt < 0 then return end

    local srtt = arq.smoothed_rtt
    local rttvar = arq.rtt_variance

    if srtt == 0 then
        -- First measurement
        srtt = rtt
        rttvar = rtt / 2
    else
        -- Standard Jacobson/Karels (RFC 6298)
        -- alpha = 1/8, beta = 1/4
        local delta = rtt - srtt
        srtt += delta / 8
        rttvar += (math.abs(delta) - rttvar) / 4
    end

    -- 3. KCP Optimization: Ensure variance doesn't decay to absolute zero
    -- This keeps the RTO responsive if a sudden spike occurs after stability.
    rttvar = math.max(1, rttvar)

    arq.rtt_variance = rttvar
    arq.smoothed_rtt = srtt

    -- 4. Calculate RTO: SRTT + 4 * RTTVAR
    -- We ensure the variation component is at least INTERVAL to account for tick delays
    local rto = srtt + math.max(INTERVAL, 4 * rttvar)
    
    arq.rto = math.clamp(rto, MIN_RTO, MAX_RTO)
end

--[[

    Processes a received ACK command.

    Removes the corresponding segment from the in-flight queue, stopping
    retransmission.

    Params:
        arq: The ARQ state machine.
        segment: The decoded ACK segment.

]]
local function process_command_acknowledge(arq: types.ARQStateMachine, segment: types.Segment)
    local inflight = arq.tx_inflight[segment.sequence_number]
    if inflight then
        arq.tx_inflight[segment.sequence_number] = nil
        -- Karn's Algorithm: Only update RTT if the packet was not retransmitted
        if inflight.first_sent_time == inflight.last_sent_time then
            calculate_rtt(arq, inflight)
        end
    end
end
--[[

    Processes a received Window Probe (WASK).

    The remote sender is asking for our current window size because they believe
    we are full. We must respond with a Window Size Update (WINS).

    Params:
        arq: The ARQ state machine.
        segment: The decoded probe segment.

]]
local function process_command_window_probe(arq: types.ARQStateMachine, segment: types.Segment)
	error('todo: implement window probe')
end

--[[

    Processes a received Window Size Update (WINS).

    Updates the known remote window size (rmt_wnd), allowing the sender to
    resume transmission if the window was previously closed.

    Params:
        arq: The ARQ state machine.
        segment: The decoded window size segment.

]]
local function process_command_window_size(arq: types.ARQStateMachine, segment: types.Segment)
	error('TODO: implement window size')
end

export type CommandFun = (types.ARQStateMachine,types.Segment)->()
local COMMANDS : {CommandFun} = table.freeze {
	[COMMAND_PUSH] = process_command_push,
	[COMMAND_ACKNOWLEDGE] = process_command_acknowledge,
	[COMMAND_WINDOW_PROBE] = process_command_window_probe,
	[COMMAND_WINDOW_SIZE] = process_command_window_size
}


return table.freeze {
    COMMAND_PUSH = COMMAND_PUSH,
    COMMAND_ACKNOWLEDGE = COMMAND_ACKNOWLEDGE,
    COMMAND_WINDOW_PROBE = COMMAND_WINDOW_PROBE,
    COMMAND_WINDOW_SIZE = COMMAND_WINDOW_SIZE,
	COMMANDS_PROCESSORS = COMMANDS,
}