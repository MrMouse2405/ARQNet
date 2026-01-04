local Players = game:GetService('Players')
Players.CharacterAutoLoads = false

local Shared = game:GetService('ReplicatedStorage'):WaitForChild('Shared')
for _,mode : ModuleScript in Shared:WaitForChild("modes"):GetChildren() do
    require(mode)
end