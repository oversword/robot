local api = robot.internal_api
local S = api.translator

if minetest.get_modpath('screwdriver') then
	api.basic_node.on_rotate = screwdriver.disallow
end


if minetest.global_exists('tubelib') then
	api.tubelib_options = {
		on_pull_item = function(pos, side, player_name)
			local nodeinfo = api.nodeinfo(pos)
			if api.has_ability(nodeinfo, 'fill') then
				local meta = nodeinfo.meta()
				return tubelib.get_item(meta, 'main')
			end
		end,
		on_push_item = function(pos, side, item, player_name)
			local nodeinfo = api.nodeinfo(pos)
			local meta = nodeinfo.meta()
			if item:get_name() == api.config.fuel_item then
				return tubelib.put_item(meta, 'fuel', item)
			elseif api.has_ability(nodeinfo, 'fill') then
				return tubelib.put_item(meta, 'main', item)
			end
			return false
		end,
		on_unpull_item = function(pos, side, item, player_name)
			local nodeinfo = api.nodeinfo(pos)
			local meta = nodeinfo.meta()
			if api.has_ability(nodeinfo, 'fill') then
				return tubelib.put_item(meta, 'main', item)
			end
			return false
		end,
	}
	if api.config.repair_item == 'tubelib:repairkit' then
		api.tubelib_options.on_node_repair = function(pos)
			local nodeinfo = api.nodeinfo(pos)
			if nodeinfo.info().status ~= 'broken' then return end
			api.clear_error(nodeinfo)
			api.set_status(nodeinfo, 'stopped')
			return true
		end
	end
end
