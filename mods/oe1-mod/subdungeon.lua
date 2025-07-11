---------------------------------------------------------------------------------------------------
-- Subdungeon represents a node in the tree. It's data is {x_length, y_length, point(api)} --
---------------------------------------------------------------------------------------------------
Subdungeon = {}

-- Subdungeon metadata
-- WARNING
-- MIN_ROOM_LENGTH^2 must be less than MAX_M2, rooms need space to spawn in the subdungeon area
Subdungeon.ROOM_BLOCK = {name = "default:cobble", param2 = 1}
Subdungeon.CORRIDOR_BLOCK = {name = "default:copperblock", param2 = 1}
Subdungeon.MAX_M2 = 1000
Subdungeon.MAX_ROOM_HEIGTH = 4
Subdungeon.MIN_ROOM_LENGTH = 5
Subdungeon.FULL_ROOM_PROB = 0.01

function Subdungeon:new(data)
	local obj = {}

	-- data: must have this structure: {width, height, {vector}}
	-- parent: the parent the node
	-- left and right: siblings of the current node
	-- rooms: list containing all rooms inside this subdungeon. If this sb is a leaf will contain a list of 1 room
	-- min_width and min_height: minimum length a room can have inside this subdungeon
    obj.data = data
	obj.parent = nil
    obj.left = nil
    obj.right = nil
	obj.rooms = {}

	obj.min_width = 5
	obj.min_height = 5

	self.__index = self
    setmetatable(obj, Subdungeon)

    return obj
end

function Subdungeon:split_subdungeon()
	print("spliting " .. self:__tostring())

	local data = self.data

	-- point is the origin point of the self
	local width = data[1]
	local height = data[2]
	local point = data[3]

	-- if the space is less than max m2, this is a leaf
	print(width .. '*' .. height .. '=' .. width*height .. ' < ' .. self.MAX_M2 .. ' | ' .. tostring(width*height<self.MAX_M2))
	if width * height < self.MAX_M2 then
		return
	end

	-- define and create the two new subdungeons
	local subdungeon1, subdungeon2
	local random_direction, random_position
	local are_both_valid = false

	while not are_both_valid do
		-- choose a random direction (horizontal or vertical)
		random_direction = math.random(1, 2)

		-- select a random split point, this is a number
		random_position = Utils.pseudo_normal_random(1, data[random_direction])

		if random_direction == 2 then
			-- horizontal
			subdungeon1 = Subdungeon:new({width, random_position, point})
			subdungeon2 = Subdungeon:new({width, height-random_position, {x=point.x, y=point.y, z=point.z+random_position+1}})
		else
			-- vertical
			subdungeon1 = Subdungeon:new({random_position, height, point})
			subdungeon2 = Subdungeon:new({width-random_position, height, {x=point.x+random_position+1, y=point.y, z=point.z}})
		end

		are_both_valid = subdungeon1:is_valid() and subdungeon2:is_valid()
	end

	print("random_position = " .. random_position)
	print("A:\t" .. subdungeon1:__tostring())
	print("B:\t" .. subdungeon2:__tostring())
	print('\n')

	-- insert in the binary tree
	self:insert(subdungeon1, subdungeon2)

	-- recursive call
	subdungeon1:split_subdungeon()
	subdungeon2:split_subdungeon()
end

function Subdungeon:create_room()
	-- given a subdungeon, creates a random rectangle inside that subdungeon
	-- 1. Select a random point
	-- 2. Select a random height and width (can not exceed the max)
	-- 3. set_node callback

	print("Creating room in " .. self:__tostring())

	local block = Subdungeon.ROOM_BLOCK

	local space = self.data

	local width = space[1]
	local height = space[2]
	local point = space[3]

	local minp = {
		x = point.x,
		y = point.y,
		z = point.z
	}

	local maxp = {
		x = point.x + width,
		y = point.y + Subdungeon.MAX_ROOM_HEIGTH,
		z = point.z + height
	}

	local vm = VoxelManip(minp, maxp)

	-- a room is valid if it is at least 5x5 nodes
	local threshold = Subdungeon.MIN_ROOM_LENGTH
	local is_invalid = true
	local rand_point, rand_height, rand_width

	while is_invalid do
		-- select a random point for the room
		rand_point = vector.new(
			math.random( width ) + point.x,
			point.y,
			math.random( height ) + point.z
		)

		-- select a random width and height for the room
		rand_width = math.random(point.x + width - rand_point.x)
		rand_height = math.random(point.z + height - rand_point.z)

		-- a room is invalid if it width or height is less than 5
		is_invalid = rand_width < threshold or rand_height < threshold
	end

	-- we should place this before the rand points are calculated
	if math.random() < Subdungeon.FULL_ROOM_PROB then
		print("full room")
		block = {name="default:goldblock"}
		rand_width = width
		rand_height = height
		rand_point = point
	end

	print("rand_width = " .. rand_width)
	print("rand_height = " .. rand_height)

	for i = 0, rand_width do
		for j = 0, rand_height do
			vm:set_node_at({x = i + rand_point.x, y = 0, z = j + rand_point.z}, block)

			if i == 0 or j == 0 or i == rand_width or j == rand_height then
				-- create the walls
				for k = rand_point.y, Subdungeon.MAX_ROOM_HEIGTH do
					local pos = rand_point + vector.new(i, k, j)
					vm:set_node_at(pos, block)
				end
			end
		end
	end

	-- place all the blocks in the world and save the room location info
	print("writing to map")
	vm:write_to_map()
	local created_room = {rand_width, rand_height, rand_point}

	-- store the room info into this subdungeon and all her antecessors
	print("loading info into bsp\n")
	local parent_ref = self
	-- iterate the tree from bottom to top, all the parent subdungeons get this room into rooms table
	while parent_ref ~= nil do
		table.insert(parent_ref.rooms, created_room)
		parent_ref = parent_ref.parent
	end
end

function Subdungeon:get_room_middle_point()
	--- from a random room in the subdungeon, get its middle point
	if #self.rooms == 0 then return end

	-- choose a random room from the room_list
	local room = self.rooms[math.random(#self.rooms)]

    local width = room[1]
    local height = room[2]
    local point = room[3]

	local mid_vector = vector.new(math.floor(width / 2), 0, math.floor(height / 2))

	return (point + mid_vector), room
end

function Subdungeon:get_middle_point()
    local width = self.data[1]
    local height = self.data[2]
    local point = self.data[3]

	local mid_vector = vector.new(math.floor(width / 2), 0, math.floor(height / 2))

	return point + mid_vector
end

function Subdungeon:is_valid()
	-- check if the subdungeon has the minimum height and width
	local aspect_ratio = math.max(self.data[1], self.data[2]) / math.min(self.data[1], self.data[2])
	return Subdungeon.MIN_ROOM_LENGTH < self.data[1] and Subdungeon.MIN_ROOM_LENGTH < self.data[2] and aspect_ratio < 10
end

-- @return boolean indicating if the point is inside the subdungeon
function Subdungeon:is_inside(point)
	-- check if it is a point
	if not vector.check(point) then
		return
	end

	local is_inside = false

	-- get room data
	local width = self.data[1]
	local height = self.data[2]
	local sb_point = self.data[3]

	-- check bounds
	local x_bounds = ( sb_point.x <= point.x ) and ( point.x <= sb_point.x + width )
	local y_bounds = ( sb_point.y <= point.y ) and ( point.y <= sb_point.y )
	local z_bounds = ( sb_point.z <= point.z ) and ( point.z <= sb_point.z + height )

	if x_bounds and y_bounds and z_bounds then
		is_inside = true
	end

	return is_inside
end

function Subdungeon:is_inside_room(point)
	-- check if it is a point
	if not vector.check(point) then
		return
	end

	local is_inside = true

	for _, room in ipairs(self.rooms) do
		-- get room data
		local width = room[1]
		local height = room[2]
		local room_point = room[3]

		-- check bounds
		local x_bounds = ( room_point.x <= point.x ) and ( point.x <= room_point.x + width )
		local y_bounds = ( room_point.y <= point.y ) and ( point.y <= room_point.y )
		local z_bounds = ( room_point.z <= point.z ) and ( point.z <= room_point.z + height )

		if x_bounds and y_bounds and z_bounds then
			is_inside = true
			break
		else
			is_inside = false
		end
	end

	return is_inside
end

function Subdungeon:__tostring()
	-- for debugging and printintg
    local width = self.data[1]
    local height = self.data[2]
    local point = self.data[3]

    return string.format(
        "Subdungeon => width: %d | height: %d | origin: {x = %d, y = %d, z = %d}",
        width, height, point.x, point.y, point.z
    )
end

function Subdungeon:insert(data1, data2)
	-- data1 and data2 must be Subdungeon instances
	-- insert sibling into bsp structure
	self.left = data1
	self.right = data2

	data1.parent = self
	data2.parent = self
end

return Subdungeon
