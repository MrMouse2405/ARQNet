--!strict
--!native
--!optimize 2
--[[
    Workload: Extremely Small, High Frequency (60Hz). 
    
    Scenario: A fighting game or vehicle chassis sending inputs every frame. 
    This benchmarks the overhead cost. 
    
    If a library adds 10 bytes of header for 3 bytes of data, this test will expose it.
]]

local function generateInputData()
    return {
        -- Packed boolean flags (Jump, Crouch, Sprint, Shoot)
        -- A smart library handles this as a single byte (bitmasking)
        inputs = 14, 
        
        -- Camera Look Vector (2 floats usually enough for Pitch/Yaw)
        yaw = math.rad(math.random(0, 360)),
        pitch = math.rad(math.random(-45, 45)),
        
        -- 8-bit Sequence ID to track packet loss
        seq = math.random(0, 255) 
    }
end

return generateInputData