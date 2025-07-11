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
    local room_mid_point1, room_mid_point2, closest_room1, closest_room2
    for _, room1 in ipairs(rooms1) do
        for _, room2 in ipairs(rooms2) do
            local mid1, mid2 = room_middle_point(room1), room_middle_point(room2)
            local dist = vector.distance(mid1, mid2)
            if dist < min_distance then
                min_distance = dist
                room_mid_point1, room_mid_point2 = mid1, mid2
				closest_room1, closest_room2 = room1, room2
            end
        end
    end

	print("rooms_mid_point " .. vector.to_string(room_mid_point1) .. ' ' .. vector.to_string(room_mid_point2))

	-- we need to be in y=1 to cast the raycasts, in y=0 they will collide against the floor
	room_mid_point1 = room_mid_point1 + vector.new(0, 1, 0)
	room_mid_point2 = room_mid_point2 + vector.new(0, 1, 0)

	--------------------------------------------
	-- CALCULATE ORIGIN AND DESTINATION NODES --
	--------------------------------------------
	local orig_node, dest_node, ray

	-- check if we can build a straight corridor from room_mid_point
	local aux_direction = vector.apply(vector.rotate_around_axis(sb_direction, vector.new(0, 1, 0), math.pi / 2), math.abs)
	local length = sb_direction * math.round(min_distance)	-- TODO, length should be til the end of the subdungeon
	local current_node = room_mid_point1

	local index

	if aux_direction.x == 1 then index = 1 else index = 2 end

	for i = 0, (closest_room1[index] / 2) - 1, 1 do
		-- alternate between + and -
		for _, sign in ipairs({1, -1}) do
			local pointed_things = {}

			-- from the middle point of the room to the direction of the other subdungeon
			current_node = room_mid_point1 + vector.multiply(aux_direction, i * sign)

			ray = Raycast(current_node + sb_direction, current_node + length)

			-- cast the ray and store all colissions in pointed_things table
			for pointed_thing in ray do
				if pointed_thing.type == "node" then
					table.insert(pointed_things, pointed_thing.under)
				end
			end

			print("Ray from ", vector.to_string(current_node), " to ", vector.to_string(current_node + length))

			-- first and second collision must be origin and destination nodes
			if pointed_things[2] and not Utils.is_room_corner(pointed_things[2], closest_room2) then
				orig_node = pointed_things[1]
				dest_node = pointed_things[2] + sb_direction
				break
			end
		end

		if dest_node then break end
	end

	-- finally, if dest_node still is nil we must build a L shaped corridor
	if not dest_node then
		print("we going L shape")

		-- calculate the possible origins points of the corridor using luanti's Raycast
		do
			ray = Raycast(room_mid_point1, room_mid_point2)
			for pointed_thing in ray do
				if pointed_thing.type == "node" then
					orig_node = pointed_thing.under
					break
				end
			end
		end

		-- room_mid_point1 and room_mid_point2 are diagonally nodes, we need the vectors in which we can approach dest_node
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

		local distance = math.abs( vector.dot(room_mid_point1, sb_direction) - vector.dot(room_mid_point2, sb_direction) )

		print("distance " .. distance)
		print(vector.multiply(sb_direction, distance))
		print("ray from ", vector.to_string(room_mid_point2), " to ", vector.to_string(room_mid_point1, vector.multiply(sb_direction, distance)))

		ray = Raycast(room_mid_point1, room_mid_point1 + vector.multiply(sb_direction, distance))
		for pointed_thing in ray do
			-- check if the pointed thing is a node
			if pointed_thing.type == "node" then
				orig_node = pointed_thing.under
				break
			end
		end

		ray = Raycast(room_mid_point2, room_mid_point1 + vector.multiply(sb_direction, distance))
		for pointed_thing in ray do
			-- check if the pointed thing is a node
			if pointed_thing.type == "node" then
				dest_node = pointed_thing.under
				break
			end
		end
	end

	-- fallback
	-- TODO fix this bug, sometime when the dungeon is big the L shape corridor fails
	if not dest_node then dest_node = room_mid_point2 print("mecachis") end

	-- return to y=0
	orig_node = orig_node - vector.new(0, 1, 0)
	dest_node = dest_node - vector.new(0, 1, 0)

	---------------------
	-- BUILD CORRIDORS --
	---------------------
	local function place_corridor_with_walls(pos, direction_axis)
		core.set_node(vector.offset(pos, 0, 3, 0), {name="default:copperblock"})
		core.set_node(vector.offset(pos, 0, 1, 0), {name="air"})
		core.set_node(vector.offset(pos, 0, 2, 0), {name="air"})
		core.set_node(pos, {name="default:copperblock"})

		-- rotate the direction axis pi/2 degrees in the y axis
		local aux_vector = vector.rotate_around_axis(direction_axis, vector.new(0, 1, 0), math.pi / 2)

		core.set_node(pos + aux_vector + vector.new(0, 1, 0), {name="default:copperblock"})
		core.set_node(pos + aux_vector + vector.new(0, 2, 0), {name="default:copperblock"})

		core.set_node(pos - aux_vector + vector.new(0, 1, 0), {name="default:copperblock"})
		core.set_node(pos - aux_vector + vector.new(0, 2, 0), {name="default:copperblock"})
	end

	-- variable is going to move in every iteration
	local walker = orig_node

	while vector.dot(walker, sb_direction) ~= vector.dot(dest_node, sb_direction) do
		place_corridor_with_walls(walker, sb_direction)
		walker = walker + sb_direction
	end

	-- we have not reach the destination, we need an L shaped corridor
	if other_direction then
		-- if other_direction is the sb_direction we must change the direction
		-- srry for bad explaining :(
		if sb_direction == other_direction then
		  other_direction = direction
		end

		-- fix the corner problem, place a wall in front of the walker and then turn
		core.set_node(walker + sb_direction + vector.new(0, 1, 0), {name="default:copperblock"})
		core.set_node(walker + sb_direction + vector.new(0, 2, 0), {name="default:copperblock"})

		core.set_node(walker - other_direction + vector.new(0, 1, 0), {name="default:copperblock"})
		core.set_node(walker - other_direction + vector.new(0, 2, 0), {name="default:copperblock"})

		core.set_node(vector.offset(walker, 0, 3, 0), {name="default:copperblock"})
		core.set_node(vector.offset(walker, 0, 0, 0), {name="default:copperblock"})

		walker = walker + other_direction

		-- check if we are approaching the destination node, if not we must not walk
		local distance1 = math.abs(vector.dot(walker, other_direction) - vector.dot(dest_node, other_direction))
		local distance2 = math.abs(vector.dot(walker + other_direction, other_direction) - vector.dot(dest_node, other_direction))

		local is_approaching = distance2 < distance1

		-- since we have stepped once, check if we have reach our destination
		if is_approaching then
			while vector.dot(walker, other_direction) ~= vector.dot(dest_node, other_direction) do
				place_corridor_with_walls(walker, other_direction)
				walker = walker + other_direction
			end
		end
	end

	core.set_node(walker + vector.new(0, 1, 0), {name="air"})
	core.set_node(walker + vector.new(0, 2, 0), {name="air"})
	---------------
	-- debugging --
	---------------
	print("from " .. vector.to_string(orig_node) .. " to " .. vector.to_string(dest_node))
	print("sb_direction ", vector.to_string(sb_direction))
	if direction and other_direction then
		print("direction ", vector.to_string(direction))
		print("o_direction ", vector.to_string(other_direction))
	end
	print("orig_node ", vector.to_string(orig_node))
	print("dest_node ", vector.to_string(dest_node), '\n')
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

function Dungeon:get_spawn_point()
	return {x = 25, z = 25, y = 20}
end

return Dungeon
