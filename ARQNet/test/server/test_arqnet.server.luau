local Events = require(game:GetService('ReplicatedStorage'):WaitForChild('Shared'):WaitForChild('events'))

local test = Events.Test:into_server()
local random = Events.Random:into_server()

test:rx(function(player: Player, message: string)  
    print(`{player} sent {message}`)
end)

random:rx(function(player: Player, num1: number, num2: number)  
    print(`{player} sent {num1},{num2}`)
end)

while task.wait(1) do
    test:txAll('Hello from Server!')
end