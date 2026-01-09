local Events = require(game:GetService('ReplicatedStorage'):WaitForChild('Shared'):WaitForChild('events'))
local ARQNet = require(game:GetService('ReplicatedStorage'):WaitForChild('ARQNet'))

local Test = Events.Test:into_local()
local Random = Events.Random:into_local()

Test:rx(function(message: string)  
    print(`Server sent {message}`)
end)

while task.wait(1) do 
    Test:tx("Hello from Client!")
    Random:tx(math.random(-10,0),math.random(0,10))
    print(`player ping is {ARQNet.local_ping()}ms`)
end