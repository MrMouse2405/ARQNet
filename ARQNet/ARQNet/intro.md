# Intro

If you have never heard about Automatic Repeat Request algorithms, here's a quick introduction ARQNet's algorithm.

- Reliable (TCP / Remote Events): Packets are guaranteed to be sent / recieved in order.
- Unreliable (UDP / Unreliable Remote Events): Packets may or may not be sent or recieved (they may be lost in transit).

All protocols technically function over UDP (surprise! internet is pretty unreliable!).

Remote events / TCP have their own mechanisms (Automatic Repeat reQuest) to ensure packets are actually sent / recieved.

ARQNet implements a custom low latency ARQ mechanism over roblox remote events!

# Phase 1: The Foundation (Basic Sliding Window ARQ)

In this stage, we establish the core buffers (snd_buf, rcv_buf) and the basic mechanism of assigning Sequence Numbers (sn) and acknowledging them.

Core Data Structures"

```
class Segment:
    conv: uint32       # Conversation ID
    cmd: byte          # Command (PUSH, ACK)
    sn: uint32         # Sequence Number
    ts: uint32         # Timestamp
    data: byte[]

class KCP:
    snd_queue: List[Segment] # Waiting to be sent
    snd_buf: List[Segment]   # In-flight (sent, waiting for ACK)
    rcv_queue: List[Segment] # Ready for user to read
    rcv_buf: Heap[Segment]   # Received, waiting to be ordered
    
    snd_nxt: uint32 = 0      # Next SN to assign
    rcv_nxt: uint32 = 0      # Next SN we expect to receive
```

Step 1.1: Sending Data (User -> KCP) The user calls this. We just wrap data and queue it.

```
function Send(buffer):
    # Fragment buffer if > MSS (simplified here)
    seg = new Segment(data=buffer)
    seg.cmd = PUSH
    snd_queue.push(seg)
```

Step 1.2: Flushing (KCP -> Network) This moves packets from "Waiting" to "In-Flight" and actually transmits them.

```
function Flush():
    # 1. Move from Queue to Buffer (Assign Sequence Numbers)
    while snd_queue is not empty:
        seg = snd_queue.pop()
        seg.sn = snd_nxt
        snd_nxt++
        snd_buf.push(seg)

    # 2. Transmit In-Flight Packets
    current_time = Now()
    for seg in snd_buf:
        # Simple Retransmission: If time elapsed > RTO
        if current_time - seg.last_send_time > RTO:
            seg.last_send_time = current_time
            Output(seg) # Send over UDP
```

Step 1.3: Receiving Data (Network -> KCP) Handle incoming ACKs (to clear buffer) and Data (to user).
Python

function Input(packet):
    seg = Decode(packet)
    
    if seg.cmd == ACK:
        # Remove from sender buffer
        RemoveFromList(snd_buf, where sn == seg.sn)
        
    else if seg.cmd == PUSH:
        # Send ACK back immediately
        SendAck(seg.sn)
        
        # If this is the packet we expected
        if seg.sn == rcv_nxt:
            rcv_queue.push(seg)
            rcv_nxt++
            # Check if rcv_buf has the next ones waiting
            while rcv_buf.has(rcv_nxt):
                rcv_queue.push(rcv_buf.pop(rcv_nxt))
                rcv_nxt++
        elif seg.sn > rcv_nxt:
            # Out of order, save in buffer for later
            rcv_buf.push(seg)

Phase 2: Adding Cumulative ACKs (una)

KCP optimizes bandwidth by using una (Unacknowledged). Instead of only ACKing specific packets, every packet tells the sender: "I have received everything before X."

Changes:

    Add una field to Segment.

    Sender cleans up snd_buf based on una.

Python

# In Input() function
function Input(packet):
    seg = Decode(packet)
    
    # 1. Cumulative ACK Logic
    # Remove EVERYTHING in snd_buf strictly less than seg.una
    # Because 'una' means "I want X", implying X-1 is received.
    RemoveFromList(snd_buf, where sn < seg.una)
    
    # 2. Specific ACK Logic (same as before)
    if seg.cmd == ACK:
        RemoveFromList(snd_buf, where sn == seg.sn)
        
    # ... handle PUSH ...

Phase 3: The "Fast Resend" (Major KCP Feature)

Standard ARQ waits for a timeout (RTO) to resend. KCP notices if packets after a missing one are ACKed. If I send 1, 2, 3, 4 and get ACKs for 1, 3, 4, I know 2 is lost without waiting for a timer.

Changes:

    Track fastack counter on segments in snd_buf.

    Trigger resend if fastack hits a threshold (usually 2).

Python

# In Input() function
function Input(packet):
    seg = Decode(packet)
    
    if seg.cmd == ACK:
        max_ack_sn = seg.sn
        # Iterate flight buffer to find skipped packets
        for inflight_seg in snd_buf:
            if inflight_seg.sn < max_ack_sn:
                # This packet (inflight_seg) was sent BEFORE the one we just got an ACK for.
                # Since we didn't get an ACK for inflight_seg yet, it was likely skipped.
                inflight_seg.fastack++

# In Flush() function
function Flush():
    # ... queue to buf logic ...
    
    for seg in snd_buf:
        needs_send = False
        
        # 1. First time sending?
        if seg.xmit == 0:
            needs_send = True
            
        # 2. RTO Timeout? (Standard ARQ)
        elif current_time > seg.resend_ts:
            needs_send = True
            seg.rto = seg.rto * 2 # Exponential backoff
            
        # 3. Fast Resend? (The KCP Magic)
        elif seg.fastack >= resend_threshold:
            needs_send = True
            seg.fastack = 0 # Reset counter
            seg.rto = seg.rto # Do NOT double RTO for fast resend (aggressive)
            
        if needs_send:
            seg.xmit++
            seg.resend_ts = current_time + seg.rto
            Output(seg)

Phase 4: Calculating Accurate RTT

To make the RTO (timeout) accurate, we need to measure how long packets take.
Python

# In Input()
if seg.cmd == ACK:
    rtt = current_time - seg.ts
    UpdateRTO(rtt)

function UpdateRTO(rtt):
    # Standard TCP RTO calculation (RFC 6298)
    if srtt == 0:
        srtt = rtt
        rttvar = rtt / 2
    else:
        delta = rtt - srtt
        srtt += delta / 8
        if delta < 0: delta = -delta
        rttvar += (delta - rttvar) / 4
        
    # KCP adds 'interval' to be conservative
    rto = srtt + max(interval, 4 * rttvar)
    rto = clamp(rto, min_rto, max_rto)

Phase 5: Flow Control (Windows)

We must ensure we don't overwhelm the receiver (rmt_wnd) and we respect our own congestion window (cwnd - optional in KCP, but good for completeness).

Changes:

    Read wnd from incoming packets.

    Limit snd_queue -> snd_buf movement.

Python

class KCP:
    rmt_wnd: uint32 = 32  # Remote window size
    cwnd: uint32 = 32     # Congestion window
    
# In Input()
function Input(packet):
    seg = Decode(packet)
    rmt_wnd = seg.wnd # Update what the other guy can handle
    # ... rest of logic ...

# In Flush()
function Flush():
    # Calculate how many packets we are allowed to have in flight
    # The limit is the Minimum of what remote can take and what network can take
    flight_limit = min(rmt_wnd, cwnd)
    
    # Only move from Queue to Buf if we are under the limit
    while snd_queue is not empty and Size(snd_buf) < flight_limit:
        seg = snd_queue.pop()
        seg.sn = snd_nxt
        snd_nxt++
        snd_buf.push(seg)
        
    # If remote window is 0, we can't send data.
    # We must probe them to ask "Do you have space yet?"
    if rmt_wnd == 0:
        if current_time > probe_timer:
            SendWindowProbe() # Sends IKCP_CMD_WASK
            probe_timer = current_time + probe_interval

Phase 6: Nodelay Mode (Optimizations)

This is a configuration step rather than new logic, but it alters how the variables are calculated.
Python

function NoDelay(nodelay, interval, resend, nc):
    if nodelay == 1:
        min_rto = 30  # Much faster timeouts
    else:
        min_rto = 100
        
    this.interval = interval 
    this.resend_threshold = resend
    
    if nc == 1:
        # Disable Congestion Control
        cwnd = infinity # Always trust rmt_wnd, ignore network congestion
    else:
        cwnd = 1 # Start slow (Slow Start)

Final Summary: The Complete KCP Flush Loop

If we combine all features, the Flush loop (the heart of KCP) looks like this:

    Flush ACKs: Send any pending ACKs we owe the other side.

    Probe Window: If rmt_wnd == 0, send Probe (WASK).

    Fill Window: Move packets from Queue to Buf up to min(cwnd, rmt_wnd).

    Iterate Buffer:

        If xmit == 0: Send (Fresh).

        If fastack >= resend: Send (Fast Retransmit). Don't backoff RTO.

        If time > resend_ts: Send (Timeout). Backoff RTO.

    Update CWND: (If Congestion Control is on) Increase/Decrease cwnd based on ACKs or Timeouts.