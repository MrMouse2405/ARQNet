local ARQNet = require(game:GetService('ReplicatedStorage'):WaitForChild('ARQNet'))
ARQNet.recieve(function(payload: buffer)  
    print(buffer.readstring(payload, 0, buffer.len(payload)))
end)

while task.wait() do
    ARQNet.send(buffer.fromstring('Hello from server!'))
end