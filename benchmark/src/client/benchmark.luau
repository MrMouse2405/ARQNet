local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Benchmark = {}

local function percentile(samples: { number }, p: number)
	if #samples == 0 then return 0 end
	table.sort(samples)
	local index = math.ceil(#samples * (p / 100))
	return samples[math.clamp(index, 1, #samples)]
end

function Benchmark.WaitForCooldown()
	-- Wait until network is silent for 1 full second
	local silentFrames = 0
	while silentFrames < 60 do
		if Stats.DataSendKbps < 1.0 then
			silentFrames += 1
		else
			silentFrames = 0
		end
		RunService.PostSimulation:Wait()
	end
end

function Benchmark.Run(Label: string, Generator: () -> any, Method: (any) -> (), BatchSize: number)
	Benchmark.WaitForCooldown()
	
	local Data = Generator()
	
	local BandwidthHistory = {}
	local FramerateHistory = {}
	local SentCount = 0
	
	local StartTime = os.clock()
	local Connection
	
	for _ = 1, BatchSize do
		SentCount += 1
		Method(Data)
	end

	Connection = RunService.PostSimulation:Connect(function(DeltaTime)
		table.insert(BandwidthHistory, Stats.DataSendKbps)
		table.insert(FramerateHistory, 1 / DeltaTime)	
		if os.clock() - StartTime > 2 then
			Connection:Disconnect()
		end
	end)
	
	repeat task.wait() until not Connection.Connected
	
	return {
		Label = Label,
		BatchSize = BatchSize,
		Sent = SentCount,
		MedianBandwidth = percentile(BandwidthHistory, 50),
		MedianFPS = percentile(FramerateHistory, 50)
	}
end

return Benchmark