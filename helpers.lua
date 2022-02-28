local api = robot.internal_api

function api.stop_timer(pos)
	local timer = minetest.get_node_timer(pos)
	if timer:is_started() then
		timer:stop()
	end
end

function api.start_timer(pos, fast)
	local timer = minetest.get_node_timer(pos)
	if not timer:is_started() then
		if fast then
			timer:start(api.config.step_delay/2)
		else
			timer:start(api.config.step_delay)
		end
	end
end

function api.move_robot(node, meta, pos, new_pos)
	minetest.set_node(new_pos, node)
	local new_meta = minetest.get_meta(new_pos)
	new_meta:from_table(meta:to_table())
	new_meta:set_string('pos', minetest.pos_to_string(new_pos))
	new_meta:mark_as_private('code')
	new_meta:mark_as_private('memory')
	minetest.remove_node(pos)

	minetest.after(0.01, api.stop_timer, pos)
	-- minetest.sound_play("movestone", { pos = pos, max_hear_distance = 20, gain = 0.5 }, true)
	return new_meta
end

function api.can_move_to(pos)
	local node = minetest.get_node(pos)

	if minetest.registered_nodes[node.name] then
		return minetest.registered_nodes[node.name].buildable_to or false
	end

	return false
end

function api.set_status(pos, meta, status)
	local node = minetest.get_node(pos)
	if status == 'running' and node.name ~= "robot:robot_running" then
		node.name = 'robot:robot_running'
		minetest.swap_node(pos, node)
	elseif status == 'error' and node.name ~= "robot:robot_error" then
		node.name = 'robot:robot_error'
		minetest.swap_node(pos, node)
	elseif status == 'broken' and node.name ~= "robot:robot_broken" then
		node.name = 'robot:robot_broken'
		minetest.swap_node(pos, node)
	elseif status == 'stopped' and node.name ~= "robot:robot" then
		node.name = 'robot:robot'
		minetest.swap_node(pos, node)
	end

	if status == 'running' then
		api.start_timer(pos, node.param1 == 1)
	else
		api.stop_timer(pos)
	end

	meta:set_string('status', status)
	api.update_formspec(pos, meta)
end

function api.set_error(pos, meta, error)
	meta:set_string("error", error)
	if meta:get_int('ignore_errors') ~= 1 then
		api.set_status(pos, meta, 'error')
	end
end
