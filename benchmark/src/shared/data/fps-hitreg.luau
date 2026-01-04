--!strict
--!native
--!optimize 2
--[[
    Workload: Bursty, Nested Tables, Mixed Types. 
    
    Scenario: A player fires a shotgun. The client sends 12 raycast hits in a single packet. 
    This tests how well the library handles arrays of structures (tables inside tables).
]]
local function generateShotgunData()
    local hits = {}
    -- 12 pellets (standard shotgun spread)
    for i = 1, 12 do
        table.insert(hits, {
            -- High precision floats for hit position
            hitX = math.random() * 100,
            hitY = math.random() * 50,
            hitZ = math.random() * 100,
            -- Integer ID for the body part hit
            limbId = math.random(1, 15), 
            -- Surface Normal (quantized to -1 to 1)
            normX = math.random(), 
            normY = math.random(),
            normZ = math.random(),
            -- Material Enum (u8)
            materialId = math.random(1, 24) 
        })
    end

    return {
        weaponId = 42,
        timestamp = os.clock(),
        originX = 100.5,
        originY = 10.2,
        originZ = -50.5,
        hitData = hits -- The heavy nested part
    }
end

return generateShotgunData