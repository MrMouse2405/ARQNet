--!strict
--!native
--!optimize 2
--[[

    Workload: Large Payload, Deep Nesting, Strings. 
    
    Scenario: A player joins an RPG. The server sends their entire inventory, stats, 
    and quest log. This is the "Stress Test" for serialization logic because strings have variable lengths, 
    which are harder to optimize than numbers.

]]
local function generateProfileData()
    local inventory = {}
    local itemNames = {"Sword of Truth", "Rusty Dagger", "Health Potion", "Leather Tunic"}
    
    for i = 1, 50 do
        table.insert(inventory, {
            uuid = "123e4567-e89b-12d3-a456-426614174000", -- Fixed length string
            name = itemNames[math.random(1, #itemNames)], -- Variable length string
            qty = math.random(1, 99),
            enchanted = math.random() > 0.5,
            durability = math.random() -- Float 0-1
        })
    end

    return {
        userId = 123456789,
        description = "A brave warrior from the north...", -- Long string
        inventory = inventory,
        stats = { str = 10, dex = 5, int = 20, luk = 99 }, -- Key-Value map
        questsCompleted = {true, false, true, true, false} -- Boolean array
    }
end

return generateProfileData