local api = robot.internal_api

function api.stop_timer(nodeinfo)
	local timer = minetest.get_node_timer(nodeinfo.pos())
	if timer:is_started() then
		timer:stop()
	end
end

function api.start_timer(nodeinfo)
	local timer = minetest.get_node_timer(nodeinfo.pos())
	if not timer:is_started() then
		local info = nodeinfo.info()
		local delay = api.tiers[info.tier].delay
		if nodeinfo.speed_enabled() then
			delay = delay / 2
		end
		if nodeinfo.boost_enabled() then
			delay = delay / 2
		end
		timer:start(delay)
	end
end

function api.move_robot(nodeinfo, new_pos)
	nodeinfo.set_pos(new_pos)
	local new_meta = nodeinfo.meta()
	-- new_meta:set_string('pos', minetest.pos_to_string(new_pos))
	new_meta:mark_as_private('code')
	new_meta:mark_as_private('memory')
end

function api.can_move_to(pos)
	local node = minetest.get_node(pos)

	if minetest.registered_nodes[node.name] then
		return minetest.registered_nodes[node.name].buildable_to or false
	end

	return false
end

function api.set_status(nodeinfo, status)
	minetest.log("error", dump(nodeinfo.robot_set()))
	for _, n in ipairs(nodeinfo.robot_set()) do
		local info = n.info()
		local meta = n.meta()

		if status ~= info.status then
			n.set_node({ name = api.robot_name(info.tier, info.part, status) })
		end
		-- meta:set_string('status', status)
	end

	if status == 'running' then
		api.start_timer(nodeinfo)
	else
		api.stop_timer(nodeinfo)
	end

	api.update_formspec(nodeinfo)
end

function api.set_error(nodeinfo, error)
	local meta = nodeinfo.meta()
	meta:set_string("error", error)
	if meta:get_int('ignore_errors') ~= 1 then
		api.set_status(nodeinfo, 'error')
	end
end
