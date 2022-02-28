local api = robot.internal_api

local S = api.translator

function api.update_formspec(pos, meta)
	if not meta then meta = minetest.get_meta(pos) end
	local inv = meta:get_inventory()

	meta:set_string('formspec', api.formspecs.inventory(meta:get_string('status'), inv:get_size('fuel')))
end

api.formspecs = {}

function api.formspecs.program(code, errmsg, ignore_errors)
	return ([[
		size[12,10]
		style_type[label,textarea;font=mono]
		label[0.1,8.3;%s]
		textarea[0.2,0.2;12.2,9.5;code;;%s]
		button[4.75,9;3,1;program;%s]
		checkbox[1,9;ignore_errors;%s;%s]
		button[9,9;3,1;reset_memory;%s]
	]]):format(
		minetest.formspec_escape(errmsg),
		minetest.formspec_escape(code),
		minetest.formspec_escape(S("Save Program")),
		minetest.formspec_escape(S("Ignore errors")),
		ignore_errors and 'true' or 'false',
		minetest.formspec_escape(S("Reset memory"))
	)
end

function api.formspecs.inventory(status, fuel_size)
	local exec_button = ''
	if status == 'stopped' then
		exec_button = minetest.formspec_escape(S("Run"))
	elseif status == 'error' then
		exec_button = minetest.formspec_escape(S("ERROR"))
	elseif status == 'running' then
		exec_button = minetest.formspec_escape(S("Stop"))
	elseif status == 'broken' then
		exec_button = minetest.formspec_escape(S("Broken"))
	end

	local fuel_pos = 2
	if fuel_size == 1 then
		fuel_pos = 3
	end

	return "size[8,8]"..
		default.gui_bg..
		default.gui_bg_img..
		default.gui_slots..
		([[
			list[context;main;0,0;8,2;]
			list[context;abilities;3,3;5,1;]
			list[context;fuel;0,%i;2,2;]
			item_image[0,%i;1,1;%s]
			item_image_button[2,3;1,1;%s;ability_reference;]
			tooltip[ability_reference;%s]
			button[4,2;4,1;program_edit;%s]
			button[2,2;2,1;status;%s]
			list[current_player;main;0,4.3;8,4;]
			listring[context;main]
			listring[current_player;main]
		]]):format(
			fuel_pos,fuel_pos,
			api.config.fuel_item,
			api.config.ability_item,
			minetest.formspec_escape(S("Ability Reference")),
			minetest.formspec_escape(S("Edit Program")),
			exec_button
		)
end

function api.formspecs.ability()
	local entries = ""
	for i,ability in ipairs(api.abilities) do
		local command = S("No command")
		if ability.action then
			command = S("Command")..": "
			if ability.command_example then
				command = command .. ability.command_example
			else
				command = command .. "robot."..ability.ability.."()"
			end
		end
		entries = entries .. ([[
			item_image[0,%i;1,1;%s]
			label[1,%i;%s]
			label[1,%f;%s]
		]]):format(
			i-1, ability.item,
			i-1, minetest.formspec_escape(ability.description),
			(i-1)+0.4, command
		)
	end
	return ("size[8,%i]"):format(#api.abilities)..
		default.gui_bg..
		default.gui_bg_img..
		default.gui_slots..
		entries
end

function api.formspecs.error(error)
	return ([[
		size[12,2]
		label[0.1,0.3;%s]
		button[4.75,1;3,1;dismiss_error;%s]
	]]):format(
		minetest.formspec_escape(error),
		minetest.formspec_escape(S("Dismiss error"))
	)
end

function api.formspecs.broken()
	local item_description = api.config.repair_item
	local item_def = minetest.registered_nodes[api.config.repair_item] or minetest.registered_items[api.config.repair_item]
	if item_def then
		item_description = item_def.description
	end
	return ([[
		size[8,2]
		item_image[0,0;2,2;%s]
		label[2,0.5;%s]
		label[2,1;%s]
	]]):format(
		api.config.repair_item,
		minetest.formspec_escape(S("The robot is broken")),
		minetest.formspec_escape(S("Use a").." "..item_description.." "..S("to repair it"))
	)
end

api.formspec_data = {}

function api.on_receive_fields(pos, form_name, fields, sender)
	local player_name = sender:get_player_name()
	if fields.quit then
		api.formspec_data[player_name] = nil
		return
	end
	if fields.ability_reference then
		minetest.show_formspec(player_name, 'robot_abilities', api.formspecs.ability())
		return
	end
	if fields.program_edit then
		api.formspec_data[player_name] = api.formspec_data[player_name] or {}
		api.formspec_data[player_name].pos = pos
		local meta = minetest.get_meta(pos)
		local code = meta:get_string('code')
		local err = meta:get_string('error')
		local ignore_errors = meta:get_int('ignore_errors')
		minetest.show_formspec(player_name, 'robot_program', api.formspecs.program(code, err, ignore_errors == 1))
		return
	end
	if fields.status then
		local meta = minetest.get_meta(pos)
		local status = meta:get_string('status')
		if status == 'stopped' then
			meta:set_string('error', '')
			api.set_status(pos, meta, 'running')
			minetest.show_formspec(player_name, '', '')
		elseif status == 'running' then
			api.set_status(pos, meta, 'stopped')
		elseif status == 'error' then
			api.formspec_data[player_name] = api.formspec_data[player_name] or {}
			api.formspec_data[player_name].pos = pos
			minetest.show_formspec(player_name, 'robot_error', api.formspecs.error(meta:get_string('error')))
		elseif status == 'broken' then
			minetest.show_formspec(player_name, 'robot_broken', api.formspecs.broken())
		end
	end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == 'robot_inventory' then
		local player_name = player:get_player_name()
		local pos = api.formspec_data[player_name].pos
		api.on_receive_fields(pos, formname, fields, player)
		return
	end
	if formname == 'robot_error' then
		local player_name = player:get_player_name()
		if fields.quit then
			api.formspec_data[player_name] = nil
			return
		end
		if fields.dismiss_error then
			local pos = api.formspec_data[player_name].pos
			local meta = minetest.get_meta(pos)
			if meta:get_string('status') == 'error' then
				meta:set_string('error', '')
				api.set_status(pos, meta, 'stopped')
			end

			api.formspec_data[player_name].psuedo_metadata = true
			minetest.show_formspec(player_name, 'robot_inventory', meta:get_string('formspec'))
		end
		return
	end

	if formname ~= 'robot_program' then return end

	local player_name = player:get_player_name()
	if fields.quit then
		api.formspec_data[player_name] = nil
		return
	end

	local pos = api.formspec_data[player_name].pos
	local meta = minetest.get_meta(pos)

	if fields.ignore_errors then
		if fields.ignore_errors == 'true' then
			meta:set_int('ignore_errors', 1)
		else
			meta:set_int('ignore_errors', 0)
		end
	elseif fields.reset_memory then
		meta:set_string('memory', minetest.serialize({}))
	elseif fields.code then
		meta:set_string('code', fields.code)
		meta:mark_as_private('code')
		if meta:get_string('status') == 'error' then
			api.set_status(pos, meta, 'stopped')
		end

		api.formspec_data[player_name].psuedo_metadata = true
		minetest.show_formspec(player_name, 'robot_inventory', meta:get_string('formspec'))
	end
end)
