Utils = {}

function Utils.pseudo_normal_random(min, max)
    local sum = 0
    for _ = 1, 4 do
        sum = sum + math.random()
    end
    local avg = sum / 6
    return math.floor( min + (max - min) * avg )
end

function Utils.is_inside_room(point, room)
	-- check if it is a point
	if type(point) ~= "table" or point.x == nil or point.y == nil or point.z == nil then
		return
	end

	-- get room data
    local width = room[1]
    local height = room[2]
	local room_point = room[3]

	-- check bounds
	local x_bounds = ( room_point.x <= point.x ) and ( point.x <= room_point.x + width )
	local y_bounds = ( room_point.y <= point.y ) and ( point.y <= room_point.y )
	local z_bounds = ( room_point.z <= point.z ) and ( point.z <= room_point.z + height )

	local is_inside = false

	if x_bounds and y_bounds and z_bounds then
		is_inside = true
	end

	return is_inside
end

function Utils.manhattan_distance(origin, dest)
	return math.abs(origin.x - dest.x) + math.abs(origin.y - dest.y) + math.abs(origin.z - dest.z)
end

function Utils.contains(list, element)
	for _, value in pairs(list) do
		if value == element then
			return true, value
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

function Utils.pos(list, element)
	-- returns element position in list, if not returns 0
	for i, value in pairs(list) do
		if Utils.eq(value, element) then
			return i
		end
	end
	return 0
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

function Utils:connect_two_subdungeons(subdungeon1, subdungeon2)
	-- we can connect two subdungeons with a link either between two rooms, or a corridor and a room or two corridors

	-- room = {rand_width, rand_height, rand_point, doors}
	-- get the rooms list from each subdungeon
	local rooms1 = subdungeon1.rooms
	local rooms2 = subdungeon2.rooms

	-- function to calculate the middle point of a given room
	local function room_middle_point(room)
		local width = room[1]
		local height = room[2]
		local point = room[3]

		local mid_vector = vector.new(math.floor(width / 2), 0, math.floor(height / 2))

		return (point + mid_vector)
	end

	-- search for the pair of rooms with the lowest distance
	local min_distance = math.huge
	local mid_point1, mid_point2
	local orig_room, dest_room

	for _, room1 in ipairs(rooms1) do
		for _, room2 in ipairs(rooms2) do
			local mid1, mid2 = room_middle_point(room1), room_middle_point(room2)

			local distance = vector.distance(mid1, mid2)

			if distance < min_distance then
				mid_point1, mid_point2 = mid1, mid2
				orig_room, dest_room = room1, room2
				min_distance = distance
			end
		end
	end

	-- calculate the entry and exit point of the corridor using luanti's Raycast
	mid_point1 = mid_point1 + vector.new(0, 1, 0)
	mid_point2 = mid_point2 + vector.new(0, 1, 0)

	local ray = Raycast(mid_point1, mid_point2)
	local intersected_nodes = {}

	for pointed_thing in ray do
		-- check if the pointed thing is a node
		if pointed_thing.type == "node" then
			table.insert(intersected_nodes, pointed_thing.under)
		end
	end

	print("intersected_nodes: ", #intersected_nodes)

	-- select the first and last nodes, we must connect them with a corridor
	local orig_node, dest_node = intersected_nodes[1], intersected_nodes[#intersected_nodes]

	orig_node = orig_node - vector.new(0, 1, 0)
	dest_node = dest_node - vector.new(0, 1, 0)

	print(vector.direction(orig_node, dest_node))

	-- corridor building logic
	-- iterate while we have not reach the destination room

	-- move x
	while orig_node.x ~= dest_node.x do
		core.set_node(orig_node, {name="default:copperblock"})
		core.set_node({x = orig_node.x, y = orig_node.y + 1, z = orig_node.z}, {name="air"})
		core.set_node({x = orig_node.x, y = orig_node.y + 2, z = orig_node.z}, {name="air"})

		if orig_node.x < dest_node.x then
			orig_node.x = orig_node.x + 1
		else
			orig_node.x = orig_node.x - 1
		end
	end

	-- move z
	while orig_node.z ~= dest_node.z do
		core.set_node(orig_node, {name="default:copperblock"})
		core.set_node({x = orig_node.x, y = orig_node.y + 1, z = orig_node.z}, {name="air"})
		core.set_node({x = orig_node.x, y = orig_node.y + 2, z = orig_node.z}, {name="air"})

		if orig_node.z < dest_node.z then
			orig_node.z = orig_node.z + 1
		else
			orig_node.z = orig_node.z - 1
		end
	end

	core.set_node(dest_node, {name="default:copperblock"})
	core.set_node({x = dest_node.x, y = dest_node.y + 1, z = dest_node.z}, {name="air"})
	core.set_node({x = dest_node.x, y = dest_node.y + 2, z = dest_node.z}, {name="air"})
end
return Utils


