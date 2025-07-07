local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath.."/subdungeon.lua")
dofile(modpath.."/utils.lua")

-----------------------------------------------------------------------------------------
-- Dungeon represents a binary tree. Each node is a subdungeon inside the root dungeon --
-----------------------------------------------------------------------------------------
Dungeon = {}

-- Dungeon metadata
Dungeon.BLOCK = {name = "default:stone"}
Dungeon.FLOOR_BLOCK = {name = "default:dirt"}
Dungeon.BLOCK_ID = core.get_content_id("default:copperblock")

-- Dungeon functions
function Dungeon:new(sb)
	local obj = {}

    obj.root = sb
	obj.width = sb.data[1]
	obj.height = sb.data[2]
	obj.point = sb.data[3]
	obj.room_counter = 0

	-- place goldblocks in the corners for debugging
	core.set_node(obj.point, {name = "default:goldblock"})
	core.set_node({x=obj.point.x + obj.width, y=obj.point.y, z=obj.point.z + obj.height	}, {name = "default:goldblock"})
	core.set_node({x=obj.point.x			, y=obj.point.y, z=obj.point.z + obj.height	}, {name = "default:goldblock"})
	core.set_node({x=obj.point.x + obj.width, y=obj.point.y, z=obj.point.z				}, {name = "default:goldblock"})
	-- debugging

	self.__index = self
    setmetatable(obj, Dungeon)

    return obj
end

function Dungeon:__tostring()
	-- not working dunno why

	local p1 = self.point
	local p2 = vector.new(p1.x + self.width, p1.y, p1.z + self.height)

	-- load the area from the map
	core.emerge_area(p1, p2)

	-- create a voxelmanip object and read from the map
	local vm = VoxelManip(p1, p2)
	vm:read_from_map(p1, p2)
	local pos1, pos2 = vm:get_emerged_area()

	print(p1)
	print(p2)
	print(pos1)
	print(pos2)

	-- initialize the dungeon string representation
	local dungeon_string = ""

	-- when we match a cobble id we will place and '#'
	local cobble_id = core.get_content_id("cobble")

	-- get the maximum index
	local max = (p2.x - p1.z + 1) * (p2.z - p1.z + 1)

	-- retrive the content_id flat array
	local content_id = vm:get_data()

	print(#content_id)

	for i = 1, max, 1 do
		local current_content_id = content_id[i]
		-- print(current_content_id)
		local char = '·'

		-- when we match and cobble node print '#'
		if current_content_id == cobble_id then
			char = '#'
		end

		dungeon_string = dungeon_string .. char

		-- if we reach the end of the row we print a newline
		if i % self.width == 0 then
			dungeon_string = dungeon_string .. '\n'
		end
	end

	-- should be calling close for performance. only in luanti 5.13
	-- vm:close()

	return dungeon_string
end

function Dungeon:create_dirt_floor()
	-- set dirt floor, will be deleted later
	local p1 = self.point
	local p2 = vector.new(p1.x + self.width, -1, p1.z + self.height)

	-- create a voxelmanip object and read from the map
	local vm = VoxelManip(p1, p2)

	local data = vm:get_data()
	local point1, point2 = vm:get_emerged_area()
	local dirt_id = core.get_content_id(Dungeon.FLOOR_BLOCK.name)

	local va = VoxelArea(point1, point2)

	for z = point1.z, point2.z do
		for x = point1.x, point2.x do
			local index = va:index(x, -1, z)
			data[index] = dirt_id
		end
	end

	vm:set_data(data)
	vm:write_to_map()
	-- vm:close()
end

function Dungeon:connect_two_leaves(subdungeon1, subdungeon2)
	-- calculate the center point of each room subdungeon
	local sb1 = subdungeon1:get_middle_point()
	local sb2 = subdungeon2:get_middle_point()

	-- iterate while we have not reach the destination room
	while sb1.x ~= sb2.x or sb1.z ~= sb2.z do
		if sb1.x < sb2.x then
			sb1.x = sb1.x + 1
		elseif sb1.x > sb2.x then
			sb1.x = sb1.x - 1
		elseif sb1.z < sb2.z then
			sb1.z = sb1.z + 1
		elseif sb1.z > sb2.z then
			sb1.z = sb1.z - 1
		end

		core.set_node(sb1, {name="default:copperblock"})

		-- TODO: Missing wall building for corridors
		-- core.set_node({x = sb1.x, y = sb1.y + 3, z = sb1.z}, {name="default:copperblock"})

		-- core.set_node({x = sb1.x + 1, y = sb1.y + 1, z = sb1.z}, {name="default:copperblock"})
		-- core.set_node({x = sb1.x - 1, y = sb1.y + 1, z = sb1.z}, {name="default:copperblock"})

		-- core.set_node({x = sb1.x + 1, y = sb1.y + 2, z = sb1.z}, {name="default:copperblock"})
		-- core.set_node({x = sb1.x - 1, y = sb1.y + 2, z = sb1.z}, {name="default:copperblock"})

		-- core.set_node({x = sb1.x, y = sb1.y + 1, z = sb1.z + 1}, {name="default:copperblock"})
		-- core.set_node({x = sb1.x, y = sb1.y + 1, z = sb1.z - 1}, {name="default:copperblock"})

		-- core.set_node({x = sb1.x, y = sb1.y + 2, z = sb1.z + 1}, {name="default:copperblock"})
		-- core.set_node({x = sb1.x, y = sb1.y + 2, z = sb1.z - 1}, {name="default:copperblock"})

		core.set_node({x = sb1.x, y = sb1.y + 1, z = sb1.z}, {name="air"})
		core.set_node({x = sb1.x, y = sb1.y + 2, z = sb1.z}, {name="air"})
	end
end

function Dungeon:connect_two_subdungeons(subdungeon1, subdungeon2)
	-- we can connect two subdungeons with a link either between two rooms, or a corridor and a room or two corridors
	-- ASSUMPTION, we always start at subdungeon1 and end in subdungeon2
	-- this means that direction always indicates from subdungeon1 to subdungeon2
    local rooms1 = subdungeon1.rooms
    local rooms2 = subdungeon2.rooms
	local sb_point1, sb_point2 = subdungeon1.data[3], subdungeon2.data[3]

	-- get the direction in which we must place the corridor,
	-- in some cases, when is diagonally placed, we do need an extra direction
	local sb_direction, direction, other_direction

	-- check in which direction are the subdungeons connected
	if sb_point1.x == sb_point2.x and sb_point1.z < sb_point2.z then
		sb_direction = vector.new(0, 0, 1)
	elseif sb_point1.x == sb_point2.x and sb_point1.z > sb_point2.z then
		sb_direction = vector.new(0, 0, -1)
	elseif sb_point1.z == sb_point2.z and sb_point1.x < sb_point2.x then
		sb_direction = vector.new(1, 0, 0)
	elseif sb_point1.z == sb_point2.z and sb_point1.x > sb_point2.x then
		sb_direction = vector.new(-1, 0, 0)
	end

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
    local room_mid_point1, room_mid_point2
    for _, room1 in ipairs(rooms1) do
        for _, room2 in ipairs(rooms2) do
            local mid1, mid2 = room_middle_point(room1), room_middle_point(room2)
            local dist = vector.distance(mid1, mid2)
            if dist < min_distance then
                min_distance = dist
                room_mid_point1, room_mid_point2 = mid1, mid2
            end
        end
    end

	-- we need to be in y=1 to cast the raycasts, in y=0 they will collide against the floor
	room_mid_point1 = room_mid_point1 + vector.new(0, 1, 0)
	room_mid_point2 = room_mid_point2 + vector.new(0, 1, 0)

	-- room_mid_point1 and room_mid_point2 are diagonally nodes, we need an L shaped corridor
	if room_mid_point1.x < room_mid_point2.x and room_mid_point1.z < room_mid_point2.z then
		direction = vector.new(1, 0 , 0)
		other_direction = vector.new(0, 0, 1)
	elseif room_mid_point1.x < room_mid_point2.x and room_mid_point1.z > room_mid_point2.z then
		direction = vector.new(1, 0, 0)
		other_direction = vector.new(0, 0, -1)
	elseif room_mid_point1.x > room_mid_point2.x and room_mid_point1.z > room_mid_point2.z then
		direction = vector.new(-1, 0, 0)
		other_direction = vector.new(0, 0, -1)
	elseif room_mid_point1.x > room_mid_point2.x and room_mid_point1.z < room_mid_point2.z then
		direction = vector.new(-1, 0, 0)
		other_direction = vector.new(0, 0, 1)
	elseif room_mid_point1.x == room_mid_point2.x and room_mid_point1.z < room_mid_point2.z then
		direction = vector.new(0, 0, 1)
	elseif room_mid_point1.x == room_mid_point2.x and room_mid_point1.z > room_mid_point2.z then
		direction = vector.new(0, 0, -1)
	elseif room_mid_point1.z == room_mid_point2.z and room_mid_point1.x < room_mid_point2.x then
		direction = vector.new(1, 0, 0)
	elseif room_mid_point1.z == room_mid_point2.z and room_mid_point1.x > room_mid_point2.x then
		direction = vector.new(-1, 0, 0)
	end

	print("rooms_mid_point " .. vector.to_string(room_mid_point1) .. ' ' .. vector.to_string(room_mid_point2))


	--------------------------------------------
	-- CALCULATE ORIGIN AND DESTINATION NODES --
	--------------------------------------------
	local orig_node, orig_node2, dest_node, ray

	-- calculate the possible origins points of the corridor using luanti's Raycast
	do
		local pointed_nodes = {}
		ray = Raycast(room_mid_point1, room_mid_point2)
		for pointed_thing in ray do
			if pointed_thing.type == "node" then
				table.insert(pointed_nodes, pointed_thing.under)
			end
		end

		orig_node = pointed_nodes[1]
		orig_node2 = pointed_nodes[#pointed_nodes]
	end

	-- check if we can build a straight corridor from orig_node
	do
		local length = sb_direction * math.round(min_distance)
		ray = Raycast(orig_node + sb_direction, orig_node + length)

		print("ray from ", vector.to_string(orig_node), " to ", vector.to_string(orig_node + length))

		for pointed_thing in ray do
			-- check if the pointed thing is a node
			if pointed_thing.type == "node" then
				dest_node = pointed_thing.under
				break
			end
		end
	end

	-- if straight corridor from orig_node is not possible check if we can build straight corridor from orig_node2
	if not dest_node then
		local length = sb_direction * math.round(min_distance)
		ray = Raycast(orig_node2 - sb_direction, orig_node2 - length)

		print("ray from ", vector.to_string(orig_node2), " to ", vector.to_string(orig_node2 + length))

		for pointed_thing in ray do
			-- check if the pointed thing is a node
			if pointed_thing.type == "node" then
				orig_node = pointed_thing.under
				dest_node = orig_node2
				break
			end
		end
	end

	-- finally, if dest_node still is nil we must build a L shaped corridor
	-- TODO, the destination node is not the room middle point, must be one of the nearest border node
	if not dest_node then
		ray = Raycast(room_mid_point2, room_mid_point2 - direction * 1000)
		for pointed_thing in ray do
			-- check if the pointed thing is a node
			if pointed_thing.type == "node" then
				dest_node = pointed_thing.under
				break
			end
		end
	end

	-- return to y=0
	orig_node = orig_node - vector.new(0, 1, 0)
	dest_node = dest_node - vector.new(0, 1, 0)

	print("from " .. vector.to_string(orig_node) .. " to " .. vector.to_string(dest_node))

	---------------------
	-- BUILD CORRIDORS --
	---------------------

	local function place_corridor_with_walls(pos, direction_axis)
		core.set_node(pos, {name="default:copperblock"})
		core.set_node({x=pos.x, y=pos.y + 1, z=pos.z}, {name="air"})
		core.set_node({x=pos.x, y=pos.y + 2, z=pos.z}, {name="air"})
		-- core.set_node({x=pos.x, y=pos.y + 3, z=pos.z}, {name="default:copperblock"})

		-- -- walls
		if direction_axis == "x" then
			-- when moving in the x axis, walls must go in the z
			core.set_node({x=pos.x, y=pos.y + 1, z=pos.z + 1}, {name="default:copperblock"})
			core.set_node({x=pos.x, y=pos.y + 2, z=pos.z + 1}, {name="default:copperblock"})
			core.set_node({x=pos.x, y=pos.y + 1, z=pos.z - 1}, {name="default:copperblock"})
			core.set_node({x=pos.x, y=pos.y + 2, z=pos.z - 1}, {name="default:copperblock"})
		elseif direction_axis == "z" then
			-- when moving in the z axis, walls must go in the x
			core.set_node({x=pos.x + 1, y=pos.y + 1, z=pos.z}, {name="default:copperblock"})
			core.set_node({x=pos.x + 1, y=pos.y + 2, z=pos.z}, {name="default:copperblock"})
			core.set_node({x=pos.x - 1, y=pos.y + 1, z=pos.z}, {name="default:copperblock"})
			core.set_node({x=pos.x - 1, y=pos.y + 2, z=pos.z}, {name="default:copperblock"})
		end

		-- TODO fix corners
	end

	print("sb_direction ", vector.to_string(sb_direction))
	print("direction ", vector.to_string(direction))
	if other_direction then
		print("o_direction ", vector.to_string(other_direction))
	end
	print("orig_node ", vector.to_string(orig_node))
	print("dest_node ", vector.to_string(dest_node), '\n')

	-- TODO we must go first in the sb_direction and then in the other, however we dont know which of the directions holds the sb_direction
	-- check it with and if and select first direction and then the other

	while vector.dot(orig_node, direction) ~= vector.dot(dest_node, direction) do
		core.set_node(orig_node, {name="default:copperblock"})
		core.set_node(vector.offset(orig_node, 0, 1, 0), {name="air"})
		core.set_node(vector.offset(orig_node, 0, 2, 0), {name="air"})
		core.set_node(vector.offset(orig_node, 0, 3, 0), {name="default:copperblock"})

		core.set_node(vector.offset(orig_node, 1, 1, 0), {name="default:copperblock"})
		core.set_node(vector.offset(orig_node, -1, 1, 0), {name="default:copperblock"})

		orig_node = orig_node + direction
	end

	-- we have not reach the destination, we need an L shaped corridor
	if other_direction then
		while vector.dot(orig_node, other_direction) ~= vector.dot(dest_node, other_direction) do
			core.set_node(orig_node, {name="default:copperblock"})
			core.set_node(vector.offset(orig_node, 0, 1, 0), {name="air"})
			core.set_node(vector.offset(orig_node, 0, 2, 0), {name="air"})
			core.set_node(vector.offset(orig_node, 0, 3, 0), {name="default:copperblock"})

			orig_node = orig_node + other_direction
		end
	end

	-- while orig_node.x ~= dest_node.x do
	-- 	place_corridor_with_walls(orig_node, "x")
	-- 	if orig_node.x < dest_node.x then
	-- 		orig_node.x = orig_node.x + 1
	-- 	else
	-- 		orig_node.x = orig_node.x - 1
	-- 	end
	-- end
	--
	-- while orig_node.z ~= dest_node.z do
	-- 	place_corridor_with_walls(orig_node, "z")
	-- 	if orig_node.z < dest_node.z then
	-- 		orig_node.z = orig_node.z + 1
	-- 	else
	-- 		orig_node.z = orig_node.z - 1
	-- 	end
	-- end

	-- place_corridor_with_walls(dest_node, orig_node.x == dest_node.x and "z" or "x")
end

function Dungeon:build_dungeon(subdungeon)
	-- traverse the BSP tree building rooms and corridors
	-- first creates the rooms when it reaches a leaf subdungeon, then it places the corridors

	local is_leaf = subdungeon.left == nil and subdungeon.right == nil

	if is_leaf then
		subdungeon:create_room()
	else
		self:build_dungeon(subdungeon.left)
		self:build_dungeon(subdungeon.right)

		-- self:connect_two_leaves(subdungeon.left, subdungeon.right)
		self:connect_two_subdungeons(subdungeon.left, subdungeon.right)
	end
end

function Dungeon:generate()
	-- split subdungeon call with the main dungeon area
	local main_sb = self.root

	print("generating bsp...")
	main_sb:split_subdungeon()

	print("building walls, floors and corridors...")
	self:build_dungeon(main_sb)
end

return Dungeon
