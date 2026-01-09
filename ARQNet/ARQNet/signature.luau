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

    Packet Signature

    # Motivation

    A packet would need these 2 fields atleast:

    ------------------------------------
    |  conversation id / discriminator | -- to differentiate events
    ------------------------------------
    | command                          | -- ARQ Protocol
    -------------------------------------

    Since, ARQNet only has 4 commands:
    PUSH, ACK, PROBE, REPLY

    2 bits is all we would need.

    Now there is no way to encode 2 bits directly
    in the standard library, so we will have to use
    some funny bit manipulation.

    Instead, we decided just introduce signatures.

    Each packet will have a signature, the signature
    essentially tells us the conversation id and the command.

    # Signature Specifications

    sign(conversation_id, command) -> numbers
    breakdown(signature) -> (conversation_id, command)

    # Algorithm.

    We just assign 4 numbers per events.

    For example,

    conv_id 0 has: 0,1,2,3
    conv_id 1 has: 4,5,6,7
    conv_id 2 has: 8,9,10,11
    and so on.


    # Good and Bad:

    Good: if we only need to deal with 64 events,
          len(signature) = 8 bits.

    Bad: if we only need to deal with 64 events,
          len(signature) = 8 bits.

        .. we only have 64 events possible!!!

    We instead let programmers decide what's best for them.

    Very unlikely to have more than 64 events unless it's a
    big game. However, they still have the option to have
    more events with slightly more bandwidth.
    
    Wait no, the implementation will be too complex
    if we let programmers decide. We will just use
    2 bytes instead of 1 byte for id. 2 bytes allows us
    16K events. Which, let's be honest, should be sufficient
    for a roblox game.

    If they have somehow go above ~16K, or, to be more specific,
    above (2^16)/4, skill issue.

]]
local types = require('./types')
local TOTAL_COMMANDS = types.TOTAL_COMMANDS

local MAX_EVENTS = (2^16)/TOTAL_COMMANDS --u16
local SIGNATURE_OFFSET = 2 --bytes


--[[

    ID Management

]]
local RunService = game:GetService('RunService')
local signal = require('./lemon_signal')
local RemoteFunction : RemoteFunction

if RunService:IsServer() then
    RemoteFunction = Instance.new('RemoteFunction')
    RemoteFunction.Name = 'SignatureSync'
    RemoteFunction.Parent = script
else
    RemoteFunction = script:WaitForChild('SignatureSync')
end



--[[

    Signatures!

]]

local ID_COUNT = 0
local name_to_id = {}
local id_to_signal = {}

local Signature = {}
function Signature.make(name : string) -- signal : signal.Signal<buffer> | signal.Signal<Player,buffer>, ID : number
    if RunService:IsServer() then
        assert(not name_to_id[name],`[ARQNET ERROR 0]{name} is already defined!`)
        assert(
            ID_COUNT + 1 < MAX_EVENTS,
            `[ARQNET ERR0R 1] Current mode cannot handle any more new events! How did u manage to get more than 16k events?`)
        local sig = signal.new()
        name_to_id[name] = ID_COUNT
        id_to_signal[ID_COUNT] = sig 
        ID_COUNT += 1
        return sig, name_to_id[name]
    else
        if name_to_id[name] then
            local id = name_to_id[name]
            return id_to_signal[id], id
        end
        local id = RemoteFunction:InvokeServer('ASK',name)
        local sig = signal.new()
        if id then
            name_to_id[name] = id
            id_to_signal[name] = sig
            print('2',name,name_to_id, id_to_signal)
            print(id_to_signal[name], name_to_id[signal])
            return sig, id
        else
            error('[ARQNET ERROR 2] Event is not registered on server!!!')
        end
    end
end

function Signature.sign(id: number, command: number, buf: buffer)
    buffer.writeu16(buf, 0, id * TOTAL_COMMANDS + command)
end

function Signature.breakdown(buf: buffer)
    local signature = buffer.readu16(buf, 0)
    local command = signature % TOTAL_COMMANDS
    local id = (signature - command) / TOTAL_COMMANDS
    return id, command
end

function Signature.get_event(id : number) :  signal.Signal<Player, buffer> | signal.Signal<buffer> | nil
    local sig = id_to_signal[id]
    if sig then
        return sig
    end
    if RunService:IsClient() then
        local start = os.clock()
        while os.clock() - start < 3 do
            if id_to_signal[id] then
                return id_to_signal[id]
            end
            task.wait()
        end
        warn('[ARQNet] Server fired an unknown / unregistered event!')
        return nil
    else
        warn('[ARQNet] Client fired an unknown / malformed packet!')
        return nil
    end
end

function Signature.size() : number
    return SIGNATURE_OFFSET
end


--[[

    Signature Sync

]]

if RunService:IsClient() then
    local ids : {[string]: number} = RemoteFunction:InvokeServer('SYNC')
    for name,id in ids do
        name_to_id[name] = id
        id_to_signal[id] = signal.new()
    end
else
    RemoteFunction.OnServerInvoke = function(player, request, param) 
        if request == 'SYNC' then
            return name_to_id
        elseif request == 'ASK' then
            if not param then
                return nil
            end
            if name_to_id[param] then
                return name_to_id[param]
            end
        end
        return nil
    end
end

return Signature