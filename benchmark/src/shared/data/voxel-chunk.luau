--!strict
--!native
--!optimize 2
--[[
    
    Workload: Massive Flat Array, Homogeneous. 
    
    Scenario: Sending a 16x16x16 chunk of terrain IDs. This tests raw memory copy speed 
    (buffer.copy vs looping). It exposes how efficiently the library handles buffer or table blobs.

]]

local function generateChunkData()
    -- 16x16x16 = 4096 blocks
    -- A naive library will iterate 4096 times. 
    local b = buffer.create(4096)
    for i = 0, 4095 do
        buffer.writeu8(b, i, math.random(0, 5)) -- 0=Air, 1=Dirt, etc
    end
    return b
end

return generateChunkData