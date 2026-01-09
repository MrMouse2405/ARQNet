local ARQNet = require(game:GetService('ReplicatedStorage'):WaitForChild('ARQNet'))

local Test : ARQNet.Event<string> = ARQNet.event(
    'Test',
    function(message: string): buffer  
        return buffer.fromstring(message)
    end,
    function(payload: buffer)  
        return buffer.readstring(payload, 0, buffer.len(payload))
    end
)

local Random : ARQNet.Event<number,number> = ARQNet.event(
    'Random',
    function(num1 : number, num2 : number): buffer  
        local b = buffer.create(8)
        buffer.writei32(b, 0, num1)
        buffer.writei32(b, 4, num2)
        return b
    end,
    function(payload: buffer)  
        return 
            buffer.readi32(payload, 0),
            buffer.readi32(payload, 4)
    end
)


return {
    Test = Test,
    Random = Random,
}