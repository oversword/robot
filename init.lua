-- local mod_name = minetest.get_cu

robot = {}

robot.internal_api = {}

local api = robot.internal_api

api.modname = minetest.get_current_modname()
api.modpath = minetest.get_modpath(api.modname)
api.dofile = function (name)
	return dofile(api.modpath..'/'..name..'.lua')
end

api.translator = minetest.get_translator(api.modname)
local S = api.translator

api.translations = {
	cant = S("Can't"),
	onlyone = S("can only perform one action at a time"),
	noability = S("robot does not have this ability")
}

api.config = {}

api.config.god_item = 'robot:god_ability'

api.config.fuel_item = 'default:coal_lump'
if minetest.get_modpath('tubelib_addons1') then
	api.config.fuel_item = 'tubelib_addons1:biofuel'
end

api.config.ability_item = 'default:skeleton_key'

api.config.repair_item = 'default:mese_crystal'
if minetest.get_modpath('tubelib') then
	api.config.repair_item = 'tubelib:repairkit'
end

-- TODO: settings
api.config.max_push = 1--mesecon.setting("movestone_max_push", 50)
api.config.step_delay = 2
api.config.max_fall = 10

api.dofile('helpers')
api.dofile('abilities')
api.dofile('lua_exec')
api.dofile('formspecs')
api.dofile('node_def')
api.dofile('nodes')

robot.internal_api = nil
