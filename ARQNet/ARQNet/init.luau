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

	Implements Automatic Repeat reQuest (ARQ) protocol over roblox's
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
local signature = require('@self/signature')
local signal = require('@self/lemon_signal')
local arq = require('@self/arq')

export type ms = number

export type ARQNet<U...> = {
	event       : (name : string, ser: (U...)->buffer, des: (payload: buffer)->U...) -> ServerEvent<U...>,
	player_ping : (player : Player) -> ms,
	local_ping  : () -> ms,
}

export type Event<U...> = {
	into_server : (self: Event<U...>)->ServerEvent<U...>,
	into_local : (self: Event<U...>)->ClientEvent<U...>
}

export type ServerEvent<U...> = {
	tx    : (self: ServerEvent<U...>, player: Player, U...) ->(),
	txAll : (self: ServerEvent<U...>, U...)->(),
	rx    : (self: ServerEvent<U...>, callback: (player: Player, U...)->())->(),
}

export type ClientEvent<U...> = {
	tx : (self: ClientEvent<U...>, U...) -> (),
	rx : (self: ClientEvent<U...>, callback: (U...)->())->(),
}

type EventPrivate<U...> = Event<U...> & {
	['1'] : string,
	['2'] : (U...)->buffer,
	['3'] : (buffer)->U...,
}

type ServerEventPrivate<U...> = ServerEvent<U...> & {
	new     : (name : string,  ser: (U...)->buffer, des: (payload: buffer)->U...) -> ServerEvent<U...>,
	signal  : signal.Signal<Player,buffer>,
	id      : number,
	ser     : (U...)->buffer,
	des     : (payload: buffer)->U..., 
}

type ClientEventPrivate<U...> = ClientEvent<U...> & {
	new     : (name : string,  ser: (U...)->buffer, des: (payload: buffer)->U...) -> ClientEvent<U...>,
	signal  : signal.Signal<buffer>,
	id      : number,
	ser     : (U...)->buffer,
	des     : (payload: buffer)->U..., 
}


--[[

	Implementation

]]

local ARQNet = {}

--[[

	Initialization Logic

]]
local UDPRemote : UnreliableRemoteEvent
if game:GetService('RunService'):IsServer() then
	--[[
		Locating Remote
	
	]]
	UDPRemote = Instance.new('UnreliableRemoteEvent')
	UDPRemote.Name = 'ARQNetRemote'
	UDPRemote.Parent = script
	--[[
	
		Creating ARQ Controllers
	
	]]
	local PlayerARQIndex : {[Player] : arq.ARQ} = {}
	local function createPlayerARQ(player: Player) : arq.ARQ
		local function tx(packet: buffer) : ()
			UDPRemote:FireClient(player,packet)
		end
		local function rx(id: number, payload: buffer) : ()
			local event = signature.get_event(id)
			if event then
				(event :: signal.Signal<Player,buffer>)
					:Fire(player,payload)
			end
		end
		return arq.makeARQ(tx, rx)
	end
	for _,player in game:GetService('Players'):GetPlayers() do
		PlayerARQIndex[player] = createPlayerARQ(player)
	end
	game:GetService('Players').PlayerAdded:Connect(function(player: Player)  
		PlayerARQIndex[player] = createPlayerARQ(player)
	end)
	game:GetService('Players').PlayerRemoving:Connect(function(player: Player)  
		PlayerARQIndex[player] = nil
	end)
	--[[
	
		Heart of ARQ Controller
	
	]]
	game:GetService('RunService').PostSimulation:Connect(function()  
		for _,arq in PlayerARQIndex do
			arq:process_tx()
		end
	end)
	UDPRemote.OnServerEvent:Connect(function(player: Player, packet: buffer)  
		PlayerARQIndex[player]:process_rx(packet)
	end)
	--[[
	
		Server Events
	
	]]
	local ServerEvent = {}
	ServerEvent.__index = ServerEvent
	function ServerEvent.new<U...>(
			name : string,
			ser: (U...)->buffer, 
			des : (payload: buffer)->U...) : ServerEventPrivate<U...>
		local self = setmetatable({}, ServerEvent)
		self.signal, self.id = signature.make(name)
		self.ser = ser
		self.des = des
		return self
	end
	function ServerEvent.tx<U...>(self: ServerEventPrivate<U...>, player : Player, ...: U...)
		assert(player and PlayerARQIndex[player],'[ARQNET ERROR] Expected Player Instance!')
		PlayerARQIndex[player]:transmit(self.id,self.ser(...))
	end
	function ServerEvent.txAll<U...>(self: ServerEventPrivate<U...>, ...: U...)
		local payload = self.ser(...) 
		for player, arq in PlayerARQIndex do
			arq:transmit(self.id,payload)
		end
	end
	function ServerEvent.rx<U...>(self: ServerEventPrivate<U...>, callback: (Player: Player, U...)->())
		self.signal:Connect(function(player: Player, payload: buffer)  
			callback(player, self.des(payload))
		end)
	end
	--[[
	
		Event API
	
	]]
	local Event = {}
	Event.__index = Event
	function Event.new<U...>(name: string, ser: (U...)->buffer, des: (buffer)->U...)
		return setmetatable({
			name,ser,des}, Event)
	end
	function Event.into_server<U...>(self : Event<U...>) : ServerEvent<U...>
		if self[4] then
			return self[4]
		end
		self[4] = ServerEvent.new(self[1],self[2],self[3])
		return self[4]
	end
	function Event.into_client()
		error('[ARQNET ERROR] This function is not available on client!')
	end
	--[[
	
		Server API
	]]
	function ARQNet.event<U...>(name: string, ser: (U...)->buffer, des: (buffer)->U...) : Event<U...>
		assert(name and type(name) == 'string', '[ARQNET ERROR] Invalid name value!')
		return Event.new(name, ser, des)
	end
	function ARQNet.player_ping(player: Player) : ms
		assert(player and PlayerARQIndex[player], '[ARQNET ERROR] Invalid player value!')
		return PlayerARQIndex[player]:getSRTT()
	end
	function ARQNet.local_ping(...)
		error('[ARQNET ERROR] This function is not available on client!')
	end
else
	--[[
	
		Locating Remotes
	]]
	UDPRemote = script:WaitForChild('ARQNetRemote')
	--[[
	
		Creating ARQ Controller
	
	]]
	local function tx(packet: buffer) : ()
		UDPRemote:FireServer(packet)
	end
	local function rx(id: number, payload: buffer)
		local event = signature.get_event(id)
		if event then
			(event :: signal.Signal<buffer>)
				:Fire(payload)
		end
	end
	local localARQ = arq.makeARQ(tx, rx)
	--[[
	
		Heart of ARQ Controller
	
	]]
	game:GetService('RunService').PostSimulation:Connect(function()  
		localARQ:process_tx()
	end)
	UDPRemote.OnClientEvent:Connect(function(packet: buffer)  
		localARQ:process_rx(packet)
	end)
	--[[
	
		Client Events
	
	]]
	local ClientEvent = {}
	ClientEvent.__index = ClientEvent
	function ClientEvent.new<U...>(name : string, ser: (U...)->buffer, des: (buffer)->U...) : ClientEvent<U...>
		local self = setmetatable({}, ClientEvent)
		self.signal, self.id = signature.make(name)
		self.ser,self.des = ser,des
		return self
	end
	function ClientEvent.tx<U...>(self: ClientEventPrivate<U...>, ...: U...)
		localARQ:transmit(self.id,self.ser(...))
	end
	function ClientEvent.rx<U...>(self: ClientEventPrivate<U...>, callback: (U...)->())
		self.signal:Connect(function(payload: buffer)  
			callback(self.des(payload))
		end)
	end
	--[[
	
		Event API
	
	]]
	local Event = {}
	Event.__index = Event
	function Event.new<U...>(name: string, ser: (U...)->buffer, des: (buffer)->U...)
		return setmetatable({
			name,ser,des}, Event)
	end
	function Event.into_local<U...>(self : Event<U...>) : ClientEvent<U...>
		if self[4] then
			return self[4]
		end
		self[4] = ClientEvent.new(self[1],self[2],self[3])
		return self[4]
	end
	function Event.into_server()
		error('[ARQNET ERROR] This function is not available on client!')
	end
	--[[
	
		Client API
	]]
	function ARQNet.event<U...>(name: string, ser: (U...)->buffer, des: (buffer)->U...) : Event<U...>
		assert(name and type(name) == 'string', '[ARQNET ERROR] Invalid name value!')
		return Event.new(name, ser, des)
	end
	function ARQNet.local_ping() : ms
		return localARQ:getSRTT()
	end
	function ARQNet.player_ping(...)
		error('[ARQNET ERROR] This function is not available on client!')
	end
end

return table.freeze(ARQNet)