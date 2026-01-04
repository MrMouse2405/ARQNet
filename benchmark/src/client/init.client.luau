-- Create a ScreenGui to hold the graphs
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Benchmark = require('@self/benchmark')
local GraphModule = require('@self/graph')

-- Load Modes
local Shared = game:GetService('ReplicatedStorage'):WaitForChild('Shared')
local RobloxMode = require(Shared:WaitForChild("modes"):WaitForChild("roblox"))
local ByteNetMode = require(Shared:WaitForChild("modes"):WaitForChild("bytenet"))
local RedNetMode = require(Shared:WaitForChild('modes'):WaitForChild('rednet'))
local WarpMode = require(Shared:WaitForChild('modes'):WaitForChild('warp'))

local MODES = {
	{ Name = "Roblox", Module = RobloxMode },
	{ Name = "ByteNet", Module = ByteNetMode },
	{ Name = "RedNet", Module = RedNetMode },
	{ Name = "Warp", Module = WarpMode },
}

-- Setup Environment
local Camera = workspace.CurrentCamera
Camera.FieldOfView = 1
Camera.CFrame = CFrame.new(0, 10000, 0)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)

-- UI Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BenchmarkResults"
-- ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.fromScale(1, 1)
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScrollFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ScrollFrame.Parent = ScreenGui

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 10)
ListLayout.Parent = ScrollFrame

local BATCH_SIZES = {}
for i = 10, 50, 10 do
	table.insert(BATCH_SIZES, i)
end

local function updateXLabels(Frame, labels)
	Frame:ClearAllChildren()
	local count = #labels
	for i, text in ipairs(labels) do
		local xPos = 0.05 + ((i/count)*0.9)
		local l = Instance.new("TextLabel")
		l.Text = tostring(text)
		l.Size = UDim2.fromScale(0.05, 0.8)
		l.Position = UDim2.fromScale(xPos, 0.5)
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.TextColor3 = Color3.fromRGB(200, 200, 200)
		l.BackgroundTransparency = 1
		l.TextScaled = true
		l.Parent = Frame
	end
end

local function createGraphContainer(title)
	local Container = Instance.new("Frame")
	Container.Size = UDim2.new(0.95, 0, 0, 500)
	Container.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	Container.Parent = ScrollFrame
	
	local GraphFrame = Instance.new("Frame")
	GraphFrame.Size = UDim2.new(1, 0, 0.9, -30)
	GraphFrame.Position = UDim2.new(0, 0, 0, 30)
	GraphFrame.BackgroundTransparency = 1
	GraphFrame.Parent = Container
	
	local XAxisFrame = Instance.new("Frame")
	XAxisFrame.Size = UDim2.new(0.9, 0, 0.1, 0)
	XAxisFrame.Position = UDim2.new(0.1, 0, 0.9, 0)
	XAxisFrame.BackgroundTransparency = 1
	XAxisFrame.Parent = Container
	
	local Label = Instance.new("TextLabel")
	Label.Text = title
	Label.Size = UDim2.new(1, 0, 0, 30)
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.BackgroundTransparency = 1
	Label.Parent = Container
	Label.ZIndex = 10
	Label.TextScaled = true
	
	return GraphFrame, XAxisFrame
end

-- Sort datasets for consistent order
local datasets = {}
for dataModule, _ in pairs(RobloxMode) do
	table.insert(datasets, dataModule)
end
table.sort(datasets, function(a, b) return a.Name < b.Name end)

task.spawn(function()
	for _, dataModule in ipairs(datasets) do
		local dataName = dataModule.Name
		local generator = require(dataModule)
		
		local bandwidthGraphFrame, bandwidthXAxis = createGraphContainer(dataName .. " - Bandwidth (KBps)")
		local bandwidthGraph = GraphModule.new(bandwidthGraphFrame)
		bandwidthGraph.Resolution = 10
		-- bandwidthGraph.BaselineZero = true


		local fpsGraphFrame, fpsXAxis = createGraphContainer(dataName .. " - FPS (Hz)")
		local fpsGraph = GraphModule.new(fpsGraphFrame)
		fpsGraph.Resolution = 10
		fpsGraph.BaselineZero = true
        
		local results = {}
		for _, mode in ipairs(MODES) do
			results[mode.Name] = { Bandwidth = {}, FPS = {} }
		end

		local currentLabels = {}
		
		for _, size in ipairs(BATCH_SIZES) do
			table.insert(currentLabels, size)
			
			for _, mode in ipairs(MODES) do
				local method = mode.Module[dataModule]
				if method then
					local result = Benchmark.Run(mode.Name.."_"..dataName, generator, method, size)
					table.insert(results[mode.Name].Bandwidth, result.MedianBandwidth)
					table.insert(results[mode.Name].FPS, result.MedianFPS)
				end
			end
			
			-- Update graph live
			local bandwidthData, fpsData = {}, {}
			for name, data in pairs(results) do
				if #data.Bandwidth > 0 then
					bandwidthData[name] = data.Bandwidth
					fpsData[name] = data.FPS
				end
			end
			
			bandwidthGraph.Data = bandwidthData
			fpsGraph.Data = fpsData
			updateXLabels(bandwidthXAxis, currentLabels)
			updateXLabels(fpsXAxis, currentLabels)

			task.wait()
		end
	end
end)