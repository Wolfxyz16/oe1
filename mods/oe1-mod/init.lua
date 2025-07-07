-- The Minetest map is split into MapBlocks, each MapBlocks being a cube of size 16

-- import dungeon file
local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath.."/dungeon.lua")
dofile(modpath.."/subdungeon.lua")

local d

-- Set singlenode
core.register_on_mapgen_init(function(mgparams)
	core.set_mapgen_setting("mgname","singlenode", true)
end)

core.register_on_newplayer(function(player)
	-- create dungeon object and calculate its nodes
	math.randomseed(os.time() * 22)
	d = Dungeon:new( Subdungeon:new({100, 100 ,vector.new(0, 0, 0)}) )
	-- d:create_dirt_floor()
	d:generate()
	print("There are " .. #d.root.rooms .. " rooms")
end)

-- Executed when the player joins the game
core.register_on_joinplayer(function(player, _last_login)
	-- Welcome message
	core.chat_send_all("Hello from oe1111")

    -- Disable HUD elements
    player:hud_set_flags({
		hotbar = false,
		crosshair = false,
		healthbar = false,
	})

    -- Set the player's initial position
    player:set_pos({x = 25, z = 25, y = 20})

	-- Set flying privilege
	local privs = core.get_player_privs(player:get_player_name())
	privs.fly = true
	core.set_player_privs(player:get_player_name(), privs)
end)

core.register_chatcommand("dungeon", {
	params = "",
	description = "",
	privs = {privs=true},
	func = function (name, params)
		print(d)
		return true
	end
})

-- core.register_mapgen_script(modpath.."/dungeon.lua")
