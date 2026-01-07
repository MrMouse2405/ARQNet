--!strict
--!native
--[[
     /  \        /  \        /  \        /  \        /  \        /  \
__/        \__/        \__/        \__/        \__/        \__/       
  \        /  \        /  \        /  \        /  \        /  \       
     \__/        \__/        \__/        \__/        \__/        \__/
     /  \        /  \        /  \        /  \        /  \        /  \
__/        \__/        \__/        \__/        \__/        \__/       
  \        /  \        /  \        /  \        /  \        /  \       

		█████╗ ██████╗  ██████╗ ███╗   ██╗███████╗████████╗
		██╔══██╗██╔══██╗██╔═══██╗████╗  ██║██╔════╝╚══██╔══╝
		███████║██████╔╝██║   ██║██╔██╗ ██║█████╗     ██║   
		██╔══██║██╔══██╗██║▄▄ ██║██║╚██╗██║██╔══╝     ██║   
		██║  ██║██║  ██║╚██████╔╝██║ ╚████║███████╗   ██║   
		A High Performance, Low Latency, Roblox Networking Library

     \__/        \__/        \__/        \__/        \__/        \__/
     /  \        /  \        /  \        /  \        /  \        /  \
__/        \__/        \__/        \__/        \__/        \__/       
  \        /  \        /  \        /  \        /  \        /  \       
     \__/        \__/        \__/        \__/        \__/        \__/
     /  \        /  \        /  \        /  \        /  \        /  \
__/        \__/        \__/        \__/        \__/        \__/       
  \        /  \        /  \        /  \        /  \        /  \
]]
--[[

    Pairing Heap

    Note: 
        This module implements left-child right-sibling 
        representation of heap.

]]
local PairingHeap = {}
PairingHeap.__index = PairingHeap

export type PairingHeap<T> = typeof(setmetatable(
	{} :: {
		_root: Node<T>?,
		_comparator: Comparator<T>,
		_count: number
	},
	PairingHeap
))

export type Comparator<T> = (a: T, b: T) -> boolean

type Node<T> = {
	value: T,
	child: Node<T>?, -- Pointer to the first child
	next: Node<T>?,  -- Pointer to the next sibling
}


--[[

    Default comparator (Min-Heap behavior)

]] 

local function defaultComparator(a: any, b: any): boolean
	return a < b
end

function PairingHeap.new<T>(comparator: Comparator<T>?): PairingHeap<T>
	local self = setmetatable({}, PairingHeap)
	self._root = nil
	self._count = 0
	self._comparator = comparator or defaultComparator
	return self
end

--[[

    Core operation: Merges two heap roots.

    Returns the new root (the smaller of the two).

]]
local function merge<T>(node1: Node<T>?, node2: Node<T>?, comparator: Comparator<T>): Node<T>?
	if not node1 then return node2 end
	if not node2 then return node1 end

	-- Ensure node1 is the smaller value (based on comparator)
	if comparator(node2.value, node1.value) then
		node1, node2 = node2, node1
	end

	-- Link node2 as the leftmost child of node1
	-- 1. node2's sibling pointer takes over node1's current child
	-- 2. node1's child becomes node2
	node2.next = node1.child
	node1.child = node2

	return node1
end

--[[

    Merges a list of siblings (children of a deleted root)
    using the standard two-pass method:
    
    1. Merge pairs from left to right.
    2. Merge the resulting list from right to left.

]]
local function mergePairs<T>(firstChild: Node<T>?, comparator: Comparator<T>): Node<T>?
	if not firstChild then return nil end
	if not firstChild.next then return firstChild end

	local nextSibling = firstChild.next
	local rest = nextSibling.next
	
	-- Break links for clean merging
	firstChild.next = nil
	nextSibling.next = nil

	-- Recursively merge the rest, then merge the result with the merged pair (first + second)
	-- This effectively handles the two-pass logic in the recursion stack
	return merge(
		merge(firstChild, nextSibling, comparator),
		mergePairs(rest, comparator),
		comparator
	)
end

function PairingHeap.insert<T>(self: PairingHeap<T>, item: T)
	local newNode: Node<T> = {
		value = item,
		child = nil,
		next = nil
	}

	self._root = merge(self._root, newNode, self._comparator)
	self._count += 1
end

function PairingHeap.peek<T>(self: PairingHeap<T>): T?
	if not self._root then return nil end
	return self._root.value
end

function PairingHeap.pop<T>(self: PairingHeap<T>): T?
	local oldRoot = self._root
	if not oldRoot then return nil end

	self._root = mergePairs(oldRoot.child, self._comparator)
	self._count -= 1
	
	return oldRoot.value
end

function PairingHeap.isEmpty<T>(self: PairingHeap<T>): boolean
	return self._root == nil
end

function PairingHeap.count<T>(self: PairingHeap<T>): number
	return self._count
end

return PairingHeap