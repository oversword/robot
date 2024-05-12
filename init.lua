robot = {}

robot.internal_api = {}

local api = robot.internal_api

api.modname = minetest.get_current_modname()
api.modpath = minetest.get_modpath(api.modname)
api.dofile = function (name)
	return dofile(api.modpath..'/'..name..'.lua')
end

api.dofile('api/_index')


api.dofile('nodeinfo')
api.dofile('abilities')
api.dofile('formspecs')
api.dofile('tiers')
api.dofile('parts')
api.dofile('nodes')

robot.internal_api = nil
