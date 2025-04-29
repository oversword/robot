local api = robot.internal_api
-- local S = api.translator

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