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
export type ARQNet = {
	send: (payload: buffer)->(),
	recieve: ((payload: buffer)->()) -> (),
	get_ping: () -> number,
}

local ARQNet = {}


local  RunService = game:GetService('RunService')
local  Players = game:GetService('Players')
local UDPRemote : UnreliableRemoteEvent
if RunService:IsServer() then
	UDPRemote = Instance.new('UnreliableRemoteEvent')
	UDPRemote.Name = 'ARQNetRemote'
	UDPRemote.Parent = script
else
	UDPRemote = script:WaitForChild('ARQNetRemote')
end

local ARQ = require('@self/arq')

if RunService:IsServer() then
	local Listeners = {}
	local function tx(packet : buffer)
		UDPRemote:FireAllClients(packet)
	end
	local function rx(payload : buffer)
		for k,v in pairs(Listeners) do
			v(payload)
		end
	end
	local arq = ARQ.makeARQ(tx,rx)
	UDPRemote.OnServerEvent:Connect(function(a0: Player, packet : buffer)  
		ARQ.process_rx(arq, packet)
	end)
	RunService.Heartbeat:Connect(function() 
		ARQ.process_tx(arq)
		ARQ.recieve(arq)
	end)
	ARQNet.send = function(payload : buffer)
		ARQ.transmit(arq,payload)
	end
	ARQNet.recieve = function(callback : (payload: buffer)->())
		table.insert(Listeners,callback)
	end
	ARQNet.get_ping = function()
		print('[RTO]',arq.rto)
		return math.round(arq.smoothed_rtt)
	end
else
	local Listeners = {}
	local function tx(packet: buffer)
		UDPRemote:FireServer(packet)
	end
	local function rx(payload : buffer)
		for k,v in pairs(Listeners) do
			v(payload)
		end
	end
	local arq = ARQ.makeARQ(tx,rx)
	UDPRemote.OnClientEvent:Connect(function(packet : buffer)  
		ARQ.process_rx(arq, packet)
	end)
	RunService.Heartbeat:Connect(function(...): ...any  
		ARQ.process_tx(arq)
		ARQ.recieve(arq)
	end)
	ARQNet.send = function(payload : buffer)
		ARQ.transmit(arq,payload)
	end
	ARQNet.recieve = function(callback : (payload: buffer)->())
		table.insert(Listeners,callback)
	end
	ARQNet.get_ping = function()
		print('[RTO]',arq.rto)
		return arq.smoothed_rtt
	end
end



return ARQNet