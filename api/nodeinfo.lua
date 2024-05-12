local api = robot.internal_api
local S = api.translator

local nodeinfos = {}
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
	for name, def in pairs(nodeinfos) do
		nodeapi[name] = function (...)
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
				local val = def.method(nodeapi, ...)
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
	nodeinfos[name] = {method=method,depends=depends_on or {},opts=options or {}}
end