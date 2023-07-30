-- Floor settings
local RADIUS = 3
local BLOCK_FLOOR = "minecraft:deepslate_bricks"
local BLOCK_FLOOR_LIGHT = "projectred_illumination:red_inverted_illumar_lamp"

-- Constants
local INV_SIZE = 16

local ITEM_FUEL = "minecraft:coal"
local SIZE = (RADIUS * 2) + 1

local BLOCK_UNKNOWN = 0
local BLOCK_WALL = -1
local BLOCK_CORRECT = 1

local FACES = {
	{ x = 1, y = 0 },
	{ x = 0, y = 1 },
	{ x = -1, y = 0 },
	{ x = 0, y = -1 },
}

-- Variables

settings.load("floor-state")

g_floor = settings.get("floor", nil)
if floor == nil then
	-- Initialize floor
	-- 0-based floor array
	g_floor = {}
	for y = 0, SIZE do
		local y_offset = y * SIZE
		for x = 0, SIZE do
			g_floor[y_offset + x] = BLOCK_UNKNOWN
		end
	end
	settings.get("floor", g_floor)
end

g_pos = settings.get("pos", { x = RADIUS, y = RADIUS })
g_facing = settings.get("facing", 0)

-- Filters
function wallsToBreak(blockName)
	return blockName == "minecraft:torch"
end

function floorToReplace(blockName)
	return blockName == BLOCK_FLOOR or blockName == BLOCK_FLOOR_LIGHT or blockName:find("^minecraft:") ~= nil
end

function getFloorBlock()
	if g_pos["x"] % 5 == 0 and g_pos["y"] % 5 == 0 then
		return BLOCK_FLOOR_LIGHT
	end
	return BLOCK_FLOOR
end

-- Movement functions
function normaliseFacing()
	g_facing = between(g_facing, 4)
end

function between(n, range)
	n = n % range
	if n < 0 then
		n = n + range
	end
	return n
end

function turnLeft()
	if turtle.turnLeft() then
		g_facing = g_facing - 1
		normaliseFacing()
	end
end

function turnRight()
	if turtle.turnRight() then
		g_facing = g_facing + 1
		normaliseFacing()
	end
end

function forward()
	local success = turtle.forward()
	if not success then
		local exists, block = turtle.inspect()
		if exists and wallsToBreak(block["name"]) then
			turtle.dig()
			success = turtle.forward()
		end
	end

	if success then
		local face = FACES[g_facing + 1]
		g_pos["x"] = g_pos["x"] + face["x"]
		g_pos["y"] = g_pos["y"] + face["y"]
	end

	return success
end

-- Search through inventory to select item
function equipItem(itemName)
	-- Check if current slot has block
	local item = turtle.getItemDetail()
	if item ~= nil and item["name"] == itemName then
		return true
	end

	-- Iterate slots to find
	for slot = 1, INV_SIZE do
		local item = turtle.getItemDetail(slot)
		if item ~= nil and item["name"] == itemName then
			turtle.select(slot)
			return true
		end
	end
	return false
end

-- Place current floor block
function placeFloorBlock()
	local expectedFloorBlock = getFloorBlock()

	local present, block = turtle.inspectDown()
	if present then
		if block["name"] == expectedFloorBlock or not floorToReplace(block["name"]) then
			return true
		end
		turtle.digDown()
	end
	while not equipItem(expectedFloorBlock) do
		print("Out of items...")
		sleep(5)
	end
	return turtle.placeDown()
end

-- Check current fuel and if low refuel
function checkFuel()
	local fuelLevel = turtle.getFuelLevel()
	if fuelLevel < 100 then
		while not equipItem(ITEM_FUEL) do
			print("Out of fuel...")
			sleep(5)
		end
		turtle.refuel(500)
	end
end

function posAsN(pos)
	return (pos["y"] * SIZE) + pos["x"]
end

-- Update map position
function updatePos(pos, value)
	g_floor[posAsN(pos)] = value
end

-- Get map position
function getPos(pos)
	return g_floor[posAsN(pos)]
end

function addPos(a, b)
	return { x = a["x"] + b["x"], y = a["y"] + b["y"] }
end

function addValidEdge(edges, pos, offset)
	local newDir = between(pos["face"] + offset, 4)
	local face = FACES[newDir + 1]
	local p = addPos(pos, face)
	p["face"] = newDir
	if p["x"] <= SIZE and p["x"] >= 0 and p["y"] <= SIZE and p["y"] >= 0 then
		table.insert(edges, p)
	else
		--print(string.format("Edge %d,%d not valid", p["x"], p["y"]))
	end
end

function validEdges(pos)
	local edges = {}
	addValidEdge(edges, pos, 0)
	addValidEdge(edges, pos, -1)
	addValidEdge(edges, pos, 1)
	addValidEdge(edges, pos, 2)
	return edges
end

-- Find BFS nearest unexplored
-- https://en.wikipedia.org/wiki/Breadth-first_search
function bfsUnexplored(pos, facing)
	if getPos(pos) == BLOCK_UNKNOWN then
		return {}
	end

	local visited = {}
	visited[posAsN(pos)] = true
	pos["parent"] = nil
	pos["face"] = facing
	-- FIFO queue
	local queue = { pos }
	while true do
		local v = table.remove(queue, 1)
		if v == nil then
			return nil
		end

		-- If v is goal
		if getPos(v) == BLOCK_UNKNOWN then
			return v
		end

		--print(string.format("Exploring from %d,%d", v["x"], v["y"]))

		for _, edge in pairs(validEdges(v)) do
			--print(string.format("valid edge %d,%d", edge["x"], edge["y"]))
			if not visited[posAsN(edge)] then
				visited[posAsN(edge)] = true
				if getPos(edge) ~= BLOCK_WALL then
					edge["parent"] = v
					table.insert(queue, edge)
				else
					--print(string.format("Ignoring wall at %d,%d", edge["x"], edge["y"]))
				end
			end
		end
	end
end

function moveToClosestUnexplored()
	local moveStack = bfsUnexplored(g_pos, g_facing)
	if moveStack == nil then
		return false
	end

	print(string.format("Travelling to %d,%d from %d,%d", moveStack["x"], moveStack["y"], g_pos["x"], g_pos["y"]))

	local ordered = {}
	local node = moveStack
	while node ~= nil do
		table.insert(ordered, 1, node)
		node = node["parent"]
		ordered[1]["parent"] = nil
	end

	for i, node in pairs(ordered) do
		print(string.format("  %d,%d (%d)", node["x"], node["y"], node["face"]))
		if i > 1 then
			print(string.format("  at %d,%d", node["x"], node["y"]))
			if between(g_facing + 1, 4) == node["face"] then
				turnRight()
			end
			while g_facing ~= node["face"] do
				turnLeft()
			end

			-- Do movement
			if not forward() then
				updatePos(addPos(g_pos, FACES[g_facing + 1]), BLOCK_WALL)
				return true
			end
		end
	end
	return true
end

function printPercentages()
	local total = 0
	local explored = 0
	local walled = 0
	for _, pos in pairs(g_floor) do
		total = total + 1
		if pos == BLOCK_WALL then
			explored = explored + 1
			walled = walled + 1
		elseif pos == BLOCK_CORRECT then
			explored = explored + 1
		end
	end
	print(
		string.format(
			"Status explored=%d/%d (%d%%) blocked=%d%%",
			explored,
			total,
			explored / total * 100,
			walled / total * 100
		)
	)
end

function updateSettings()
	settings.set("floor", g_floor)
	settings.set("pos", g_pos)
	settings.set("facing", g_facing)
	settings.save("floor-state")
end

-- Main loop
while true do
	printPercentages()
	checkFuel()
	if placeFloorBlock() then
		updatePos(g_pos, BLOCK_CORRECT)
	end
	updateSettings()
	if not moveToClosestUnexplored() then
		break
	end
end

print("Nowhere left to go")
