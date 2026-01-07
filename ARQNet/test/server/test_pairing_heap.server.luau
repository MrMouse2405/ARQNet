local TEST_ENABLED = false
if not TEST_ENABLED then
    return
end

print('[TEST] Testing Pairing Heap!')

local ARQNet = game:GetService('ReplicatedStorage'):WaitForChild('ARQNet')
local PairingHeap = require(ARQNet:WaitForChild('pairing_heap'))

local function runTests()
	print("Running Pairing Heap Tests...")
	
	local passed = 0
	local failed = 0
	
	local function assertEq(actual: any, expected: any, msg: string)
		if actual ~= expected then
			warn(string.format("[FAIL] %s: Expected %s, got %s", msg, tostring(expected), tostring(actual)))
			failed += 1
		else
			passed += 1
		end
	end

	-- Test 1: Empty State
	do
		local heap = PairingHeap.new()
		assertEq(heap:isEmpty(), true, "New heap should be empty")
		assertEq(heap:peek(), nil, "Peeking empty heap returns nil")
		assertEq(heap:pop(), nil, "Popping empty heap returns nil")
	end

	-- Test 2: Basic Insert and Peek
	do
		local heap = PairingHeap.new()
		heap:insert(10)
		heap:insert(5)
		heap:insert(20)
		
		assertEq(heap:isEmpty(), false, "Heap should not be empty")
		assertEq(heap:peek(), 5, "Min value should be 5")
		assertEq(heap:count(), 3, "Count should be 3")
	end

	-- Test 3: Sorting Order (Pop)
	do
		local heap = PairingHeap.new()
		local input = {45, 12, 90, 3, 77, 20}
		for _, v in ipairs(input) do
			heap:insert(v)
		end
		
		local expected = {3, 12, 20, 45, 77, 90}
		for i, exp in ipairs(expected) do
			local val = heap:pop()
			assertEq(val, exp, "Popped value should match sorted order index " .. i)
		end
		assertEq(heap:isEmpty(), true, "Heap should be empty after popping all")
	end

	-- Test 4: Custom Comparator (Max Heap)
	do
		local maxHeap = PairingHeap.new(function(a, b) return a > b end)
		maxHeap:insert(10)
		maxHeap:insert(50)
		maxHeap:insert(20)
		
		assertEq(maxHeap:peek(), 50, "Max heap should peek largest value")
		assertEq(maxHeap:pop(), 50, "Max heap should pop 50")
		assertEq(maxHeap:pop(), 20, "Max heap should pop 20")
		assertEq(maxHeap:pop(), 10, "Max heap should pop 10")
	end

	-- Test 5: Stress Test (Large Dataset)
	do
		local heap = PairingHeap.new()
		local size = 5000
		
		-- Deterministic random seed for reproducibility
		local rng = Random.new(12345) 
		local verifyTable = {}
		
		for i = 1, size do
			local n = rng:NextInteger(1, 100000)
			heap:insert(n)
			table.insert(verifyTable, n)
		end
		
		table.sort(verifyTable)
		
		local correct = true
		for i = 1, size do
			local popped = heap:pop()
			if popped ~= verifyTable[i] then
				correct = false
				assertEq(popped, verifyTable[i], "Stress test mismatch at index " .. i)
				break
			end
		end
		
		if correct then
			print(" [PASS] Stress test with " .. size .. " items passed.")
			passed += 1
		end
	end

	print(string.format("---------------------------------"))
	print(string.format("Tests Completed: %d Passed, %d Failed", passed, failed))
end

runTests()

