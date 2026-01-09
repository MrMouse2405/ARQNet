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

local types = require('./types')
local segment = require('./segment')
local decodeSegmentPush = segment.decodeSegmentPush
local encodeSegmentAcknowledge = segment.encodeSegmentAcknowledge
local decodeSegmentAcknowledge = segment.decodeSegmentAcknowledge


--[[

    Encoding Packets

]]



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
local function process_command_push(arq: types.ARQStateMachine, id: number, packet: types.Packet)
	local sequence_number : number, payload : buffer = decodeSegmentPush(packet)

    -- acknowledging
    local ack_seg : types.Packet = encodeSegmentAcknowledge(
        id, 
        sequence_number
    )
    arq.tx(ack_seg)

    -- ordering
    if sequence_number == arq.rx_nxt_sn then
        arq.rx(id, payload)
		arq.rx_nxt_sn += 1
        while arq.rx_out_of_order[arq.rx_nxt_sn] do
            arq.rx(arq.rx_nxt_sn,arq.rx_out_of_order[arq.rx_nxt_sn])
			arq.rx_out_of_order[arq.rx_nxt_sn] = nil
			arq.rx_nxt_sn += 1
		end
	elseif sequence_number > arq.rx_nxt_sn then
		-- future packet
		arq.rx_out_of_order[sequence_number] = payload
	else
		--it's a duplicate packet
	end
end

--[[

    Calculates the Round Trip Time (RTT) and updates the Retransmission Timeout (RTO).

    Implements the standard Jacobson/Karels algorithm (RFC 6298) to estimate
    network conditions. It also applies Karn's Algorithm, which ignores RTT
    samples from retransmitted segments to prevent skewed measurements.

    Params:
        arq: The ARQ state machine.
        packet: The in-flight packet structure containing the segment and send times.

]]
type ms = number
local INTERVAL : ms = 10 -- Granularity (approx 100hz tick)
local MIN_RTO : ms = 50 -- KCP default: 30-50ms (don't go lower than ~3 frames)
local MAX_RTO : ms = 5000 -- Fail fast cap
@native
local function calculate_rtt(arq: types.ARQStateMachine, packet: types.InFlightPacket)
    -- Karn's Algorithm: Ignore RTT samples from retransmitted segments
    -- We can't tell if this ACK is for the original or the retry.
    if packet.retransmission_count > 0 then
        return
    end

    -- Use os.clock() for high-precision local delta, then convert to ms
    local now = os.clock() 
    local rtt_seconds = now - packet.last_sent_time -- Use local timestamp
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

    -- KCP Optimization: Ensure variance doesn't decay to absolute zero
    -- This keeps the RTO responsive if a sudden spike occurs after stability.
    rttvar = math.max(1, rttvar)

    arq.rtt_variance = rttvar
    arq.smoothed_rtt = srtt

    -- Calculate RTO: SRTT + 4 * RTTVAR
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
local function process_command_acknowledge(arq: types.ARQStateMachine, id: number, packet: types.Packet)
    local sequence_number = decodeSegmentAcknowledge(packet)
    local inflight = arq.tx_inflight[sequence_number]
    if inflight then
        arq.tx_inflight[inflight] = nil
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
local function process_command_window_probe(arq: types.ARQStateMachine, segment: types.Packet)
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
local function process_command_window_size(arq: types.ARQStateMachine, segment: types.Packet)
	error('TODO: implement window size')
end

export type CommandFun = (types.ARQStateMachine, id: number,types.Packet)->()
local COMMANDS : {CommandFun} = table.freeze {
	[types.COMMAND_PUSH] = process_command_push,
	[types.COMMAND_ACKNOWLEDGE] = process_command_acknowledge,
	[types.COMMAND_WINDOW_PROBE] = process_command_window_probe,
	[types.COMMAND_WINDOW_SIZE] = process_command_window_size
}

return {
    COMMANDS_PROCESSORS = COMMANDS   
}