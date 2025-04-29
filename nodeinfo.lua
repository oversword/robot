local api = robot.internal_api
-- local S = api.translator

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

api.add_nodeinfo('node', function (nodeapi, cache)
	return core.get_node(nodeapi.pos())
end, {'pos'}, {split_obj = true})
api.add_nodeinfo('meta', function (nodeapi)
	return core.get_meta(nodeapi.pos())
end, {'pos'})
api.add_nodeinfo('inv', function (nodeapi)
	return nodeapi.meta():get_inventory()
end, {'meta'})

api.add_nodeinfo('direction', function (nodeapi)
	return vector.subtract({x=0,y=0,z=0}, core.facedir_to_dir(nodeapi.node().param2))
end, {'node.param2'})
api.add_nodeinfo('front', function (nodeapi)
	return vector.add(nodeapi.pos(), nodeapi.direction())
end, {'direction','pos'})

api.add_nodeinfo('info', function (nodeapi)
	local tier, part, status = api.robot_def(nodeapi.node().name)
	return {tier=tier, part=part, status=status}
end, {'node.name'}, {split_obj = true})
api.add_nodeinfo('speed_enabled', function (nodeapi)
	return nodeapi.meta():get_int('robot_speed') == 1
end, {'node.param1'})
api.add_nodeinfo('boost_enabled', function (nodeapi)
	return nodeapi.meta():get_int('robot_boost') == 1
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

api.add_nodeinfo('parts', function (nodeapi)
	local ret = {}
	for _,n in ipairs(nodeapi.robot_set()) do
		ret[n.info().part] = n
	end
	return ret
end, {'robot_set'})