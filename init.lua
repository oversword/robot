robot = {}

robot.internal_api = {}

local api = robot.internal_api

api.modname = minetest.get_current_modname()
api.modpath = minetest.get_modpath(api.modname)
api.dofile = function (name)
	return dofile(api.modpath..'/'..name..'.lua')
end
local added_nodeinfos = {}
api.nodeinfo = function(pos)
	local cache = {pos=pos}
	local cache_vers = {pos=0}
	local dep_vers = {pos={}}
	local nodeapi = {}
	nodeapi.pos = function ()
		return cache.pos
	end
	nodeapi.set_node = function (props)
		local node = nodeapi.node()
		local changes = false
		for p,v in pairs(props) do
			if v ~= node[p] then
				node[p] = v
				local n = 'node.'..p
				cache_vers[n] = (cache_vers[n] or -1) + 1
				changes = true
			end
		end
		if changes then
			minetest.swap_node(nodeapi.pos(), node)
			cache_vers.node = (cache_vers.node or -1) + 1
		end
	end
	nodeapi.set_pos = function(new_pos)
		local node = nodeapi.node()
		local meta = nodeapi.meta():to_table()

		minetest.set_node(new_pos, node)
		cache.pos = new_pos
		cache_vers.pos = cache_vers.pos+1
		nodeapi.meta():from_table(meta)

		minetest.remove_node(pos)
		minetest.after(0.01, api.stop_timer, api.nodeinfo(pos))
		-- TODO: any sound design at all
		-- minetest.sound_play("movestone", { pos = pos, max_hear_distance = 20, gain = 0.5 }, true)
	end
	for name, def in pairs(added_nodeinfos) do
		nodeapi[name] = function ()
			local do_run = not cache_vers[name]
			if not do_run then
				for i,d in ipairs(def.depends) do
					if dep_vers[name][i] < cache_vers[d] then
						do_run = true
						break
					end
				end
			end
			if do_run then
				local val = def.method(nodeapi)
				if def.opts.split_obj and type(val) == 'table' then
					for n,v in pairs(val) do
						if v ~= (type(cache[name]) == 'table' and cache[name] or {})[n] then
							local p = name..'.'..n
							cache_vers[p] = (cache_vers[p] or -1) + 1
						end
					end
				end
				dep_vers[name] = {}
				for i,d in ipairs(def.depends) do
					dep_vers[name][i] = cache_vers[d]
				end
				cache[name] = val
				cache_vers[name] = (cache_vers[name] or -1) + 1
			end
			return cache[name]
		end
	end
	return nodeapi
end
api.add_nodeinfo = function(name, method, depends_on, options)
	added_nodeinfos[name] = {method=method,depends=depends_on or {},opts=options or {}}
end

-- api.add_nodeinfo()
api.add_nodeinfo('node', function (nodeapi, cache)
	return minetest.get_node(nodeapi.pos())
end, {'pos'}, {split_obj = true})
api.add_nodeinfo('meta', function (nodeapi)
	return minetest.get_meta(nodeapi.pos())
end, {'pos'})
api.add_nodeinfo('inv', function (nodeapi)
	return nodeapi.meta():get_inventory()
end, {'meta'})

api.add_nodeinfo('direction', function (nodeapi)
	return vector.subtract({x=0,y=0,z=0}, minetest.facedir_to_dir(nodeapi.node().param2))
end, {'node.param2'})
api.add_nodeinfo('front', function (nodeapi)
	return vector.add(nodeapi.pos(), nodeapi.direction())
end, {'direction','pos'})


api.add_nodeinfo('info', function (nodeapi)
	local tier, part, status = api.robot_def(nodeapi.node().name)
	return {tier=tier, part=part, status=status}
end, {'node.name'}, {split_obj = true})
api.add_nodeinfo('speed_enabled', function (nodeapi)
	local param1 = nodeapi.node().param1
	return param1 % 2 == 1
end, {'node.param1'})
api.add_nodeinfo('boost_enabled', function (nodeapi)
	local param1 = nodeapi.node().param1
	return math.floor(param1 / 2) % 2 == 1
end, {'node.param1'})
api.add_nodeinfo('any_speed_enabled', function (nodeapi)
	for _,n in ipairs(nodeapi.robot_set()) do
		if n.speed_enabled() then return true end
	end
end, {'speed_enabled','pos','robot_set'})
api.add_nodeinfo('any_boost_enabled', function (nodeapi)
	for _,n in ipairs(nodeapi.robot_set()) do
		if n.boost_enabled() then return true end
	end
end, {'boost_enabled','pos','robot_set'})



function api.set_connected(nodeinfo, connected)
	local meta = nodeinfo.meta()
	local current = meta:get_int('connected')
	local new_val = connected and 1 or 0
	if new_val ~= current then
		meta:set_int('connected', new_val)
		api.update_formspec(nodeinfo)
	end
end
function api.is_connected(nodeinfo)
	local meta = nodeinfo.meta()
	local current = meta:get_int('connected')
	return current == 1
end
function api.is_connective(nodeinfo, to_part)
	local info = nodeinfo.info()
	if not info.part then return end
	local connects_above = api.parts[info.part].connects_above
	if not connects_above then return end
	if not api.has_ability(nodeinfo, 'connectivity') then return end
	if not to_part then return true end
	return connects_above[to_part]
end
function api.is_above_connective(nodeinfo)
	local pos = nodeinfo.pos()
	local uppos = vector.add(pos, {x=0,y=1,z=0})
	local upinfo = api.nodeinfo(uppos)
	if nodeinfo.node().param2 ~= upinfo.node().param2 then return end
	local info = upinfo.info()
	if not info.part or not api.is_connective(nodeinfo, info.part) then return end
	return upinfo
end
function api.is_below_connective(nodeinfo)
	local pos = nodeinfo.pos()
	local downpos = vector.subtract(pos, {x=0,y=1,z=0})
	local downinfo = api.nodeinfo(downpos)
	if nodeinfo.node().param2 ~= downinfo.node().param2 then return end
	local info = nodeinfo.info()
	if not info.part or not api.is_connective(downinfo, info.part) then return end
	return downinfo
end
function look_above(nodeinfo)
	local upinfo = api.is_above_connective(nodeinfo)
	if not upinfo then return {} end
	local ret = {}
	for _, i in ipairs(look_above(upinfo)) do
		table.insert(ret, i)
	end
	table.insert(ret, upinfo)
	return ret
end
function look_below(nodeinfo)
	local downinfo = api.is_below_connective(nodeinfo)
	if not downinfo then return {} end
	local ret = {downinfo}
	for _, i in ipairs(look_below(downinfo)) do
		table.insert(ret, i)
	end
	return ret
end
api.add_nodeinfo('robot_set', function (nodeapi)
	-- look above if connectve
	local above = {}
	if api.is_connective(nodeapi) then
		above = look_above(nodeapi)
	end
	-- look below for connectives
	local below = look_below(nodeapi)
	local ret = {}
	for _,a in ipairs(above) do
		table.insert(ret, a)
	end
	table.insert(ret, nodeapi)
	for _,b in ipairs(below) do
		table.insert(ret, b)
	end
	return ret
end, {'pos','info.part'})

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

api.dofile('helpers')
api.dofile('abilities')
api.dofile('lua_exec')
api.dofile('formspecs')
api.dofile('node_def')
api.dofile('nodes')

robot.internal_api = nil
