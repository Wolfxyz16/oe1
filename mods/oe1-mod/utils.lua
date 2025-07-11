Utils = {}

function Utils.pseudo_normal_random(min, max)
    local sum = 0
    for _ = 1, 6 do
        sum = sum + math.random()
    end
    local avg = sum / 6
    return math.floor( min + (max - min) * avg )
end

function Utils.is_room_corner(point, room)
	-- check if it is a point
	if type(point) ~= "table" or point.x == nil or point.y == nil or point.z == nil then
		return
	end

	-- get room data
    local width = room[1]
    local height = room[2]
	local room_point = room[3]

	-- the point we recive is in y=1, we must add y=y+1 in the room point
	room_point = vector.offset(room_point, 0, 1, 0)

	-- corners
	local c1 = vector.offset(room_point, 0, 0, 0)
	local c2 = vector.offset(room_point, width, 0, 0)
	local c3 = vector.offset(room_point,		 0,	0, height)
	local c4 = vector.offset(room_point, width, 0, height)

	-- debugging
	print("===ROOM===")
	print("room_point: ", vector.to_string(room_point))
	print("width: ", width)
	print("height: ", height)
	print("===CORNERS===")
	print("point: ", point)
	print("c1: ", c1, " ", c1 == point)
	print("c2: ", c2, " ", c2 == point)
	print("c3: ", c3, " ", c3 == point)
	print("c4: ", c4, " ", c4 == point)
	print("=============")

	return c1 == point or c2 == point or c3 == point or c4 == point
end

function Utils.is_room_border(point, room)
	-- check if a valid point
	if not vector.check(point) then return end

	-- get room data
    local width = room[1]
    local height = room[2]
	local room_point = room[3]

    local x_min = room_point.x
    local x_max = room_point.x + width - 1
    local z_min = room_point.z
    local z_max = room_point.z + height - 1

    -- check if point is inside room
    if point.x >= x_min and point.x <= x_max and
       point.z >= z_min and point.z <= z_max then

        -- check if it is in the border
        return point.x == x_min or point.x == x_max or
               point.z == z_min or point.z == z_max
    end

    return false
end

function Utils.manhattan_distance(origin, dest)
	return math.abs(origin.x - dest.x) + math.abs(origin.y - dest.y) + math.abs(origin.z - dest.z)
end

function Utils.contains(list, element)
	for _, index in pairs(list) do
		if index == element then
			return true, index
		end
	end
	return false, nil
end

--- Checks that in the open_list the node already exists and returns true if it is a shorter path
--- @param list table
--- @param new_element table
--- @return boolean
function Utils.exits_shorter_path(list, new_element)
	for _, value in pairs(list) do
		if value == new_element then
			return value.g > new_element.g
		end
	end
	return false
end

function Utils.reconstruct_path(dest)
	local path = {}
	local current = dest

	while current ~= nil do
		table.insert(path, current)
		current = current.parent
	end

	return path
end

function Utils.a_star(origin, dest)
	local heur = Utils.manhattan_distance

	local open_list = {origin}
	local closed = {}

	origin.g = 0
	origin.h = heur(origin, dest)
	origin.f = origin.g + origin.h

	print("origin" .. vector.to_string(origin))
	print("dest" .. vector.to_string(dest))

	local desp = {
		vector.new(1, 0, 0),
		vector.new(-1, 0, 0),
		-- vector.new(0, 1, 0),
		-- vector.new(0, -1, 0),
		vector.new(0, 0, 1),
		vector.new(0, 0, -1),
	}

	while #open_list ~= 0 do

		print(#open_list)

		-- get the node in open_list with lowest f
		local min = math.huge
		local current_pos = 1
		for i = 2, #open_list do
			if open_list[i].f < min then
				current_pos = i
				min = open_list[i].f
			end
		end

		local current = open_list[current_pos]

		-- if we reached the goal calculate the path
		if current == dest then
			Utils.reconstruct_path(current)
		end

		-- move current from open to closed
		table.insert(closed, table.remove(open_list, current_pos))

		-- for each neighbour of current
		for _, d in ipairs(desp) do
			local neighbour = current + d

			-- read the new node and check that it is an air node
			local node = core.get_node(neighbour)

			-- if the node is in the closed list or it is a stone (room node)
			-- if Utils.contains(closed, neighbour) or node.name ~= "default:stone" then
			if Utils.contains(closed, neighbour) then
				goto continue
			end

			local tentative_g = current.g + heur(current, neighbour)

			-- calculate the neighbour g, h and f
			neighbour.g = tentative_g
			neighbour.h = heur(neighbour, dest)
			neighbour.f = neighbour.g + neighbour.h
			neighbour.parent = current

			if Utils.exits_shorter_path(open_list, neighbour) then
				goto continue
			end

			-- we insert the neighbour into the open_list
			table.insert(open_list, neighbour)

			::continue::
		end
	end

	-- no path found
	return {}
end

return Utils
