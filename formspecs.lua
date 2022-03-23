local api = robot.internal_api

local S = api.translator

function api.update_formspec(nodeinfo)
	local meta = nodeinfo.meta()
	meta:set_string('formspec', api.formspecs.inventory(nodeinfo))
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

function api.formspecs.inventory(nodeinfo)
	local meta = nodeinfo.meta()
	-- local status = meta:get_string('status')
	local extras_enabled_list = string.split(meta:get_string('extras'),',')
	local extras_enabled = {}
	for _,def in ipairs(extras_enabled_list) do
		extras_enabled[def] = true
	end
	local inv = nodeinfo.inv()
	local main_size = inv:get_size('main')
	local fuel_size = inv:get_size('fuel')
	local abilities_size = inv:get_size('abilities')
	local info = nodeinfo.info()
	local is_connective = api.is_connective(nodeinfo)
	local has_connection = is_connective and api.is_connected(nodeinfo)
	-- if is_connective then
	-- 	has_connection = api.is_above_connective(nodeinfo)
	-- end

	local tier_def = api.tiers[info.tier]
	local exec_button = ''
	if info.status == 'stopped' then
		exec_button = minetest.formspec_escape(S("Run"))
	elseif info.status == 'error' then
		exec_button = minetest.formspec_escape(S("ERROR"))
	elseif info.status == 'running' then
		exec_button = minetest.formspec_escape(S("Stop"))
	elseif info.status == 'broken' then
		exec_button = minetest.formspec_escape(S("Broken"))
	end

	local size = tier_def.form_size
	local fuel_pos = {x=0,y=3}
	fuel_pos.y = 3 - math.floor((fuel_size-1)/2)
	local default_abilities = {}
	for _,ability in ipairs(api.parts[info.part].default_abilities or {}) do
		if api.ability_enabled(ability) then
			table.insert(default_abilities, ([[
				item_image[%i,3;1,1;%s]
			]]):format(3+#default_abilities, api.abilities_ability_index[ability].item))
		end
	end
	local extra_abilities = {}
	for i,ability in ipairs(tier_def.extra_abilities or {}) do
		if api.ability_enabled(ability) then
			local ability_obj = api.abilities_ability_index[ability]
			table.insert(extra_abilities, ([[
				item_image_button[%i,2;1,1;%s;ability_switch_%s;]
				tooltip[ability_switch_%s;%s]
			]]):format(
				2+#extra_abilities,
				ability_obj.item,
				ability,ability,
				minetest.formspec_escape(ability_obj.description)
			)..(extras_enabled[ability] and "" or ("item_image[%i,2;1,1;%s]"):format(2+#extra_abilities, api.config.ability_item)))
		end
	end


	return ("size[%f,8]"):format(size)..
		default.gui_bg..
		default.gui_bg_img..
		default.gui_slots..
		([[
			list[context;main;%f,0;%i,2;]
			list[context;abilities;%f,3;%i,1;]
			list[context;fuel;%i,%i;2,%i;]
			item_image[%i,%i;1,1;%s]
			item_image_button[2,3;1,1;%s;ability_reference;]
			tooltip[ability_reference;%s]
			list[current_player;main;%f,4.3;8,4;]
			listring[context;main]
			listring[current_player;main]
			%s
			%s
			%s
		]]):format(
			fuel_size > 4 and 2 or 0,
			fuel_size > 4 and size-2 or size,
			3+#default_abilities,
			abilities_size,
			fuel_pos.x,fuel_pos.y,math.ceil(fuel_size/2),
			fuel_pos.x,fuel_pos.y,
			api.config.fuel_item,
			api.config.ability_item,
			minetest.formspec_escape(S("Ability Reference")),
			(size-8)/2,
			is_connective
				and ("button[%f,2;6,1;connection;%s]")
						:format(
							2+#extra_abilities,
							has_connection and "Connected" or "Disconnected"
						)
				or ([[
					button[%f,2;4,1;program_edit;%s]
					button[%f,2;2,1;status;%s]
				]]):format(
					4+#extra_abilities,
					minetest.formspec_escape(S("Edit Program")),
					2+#extra_abilities,
					exec_button
				),
			table.concat(default_abilities, ""),
			table.concat(extra_abilities, "")
		)
end

function api.formspecs.ability(nodeinfo)
	local info = nodeinfo.info()
	local entries = {}
	for _,ability in ipairs(api.abilities) do
		if api.ability_enabled(ability.ability)
		and not ability.interface_enabled
		and (not ability.done_by or ability.done_by[info.part]) then
			local command = S("No command")
			if ability.action then
				command = S("Command")..": "
				if ability.command_example then
					command = command .. ability.command_example
				else
					command = command .. "robot."..ability.ability.."()"
				end
			end
			table.insert(entries, ([[
				item_image[0,%i;1,1;%s]
				label[1,%i;%s]
				label[1,%f;%s]
			]]):format(
				#entries, ability.item,
				#entries, minetest.formspec_escape(ability.description),
				#entries+0.4, command
			))
		end
	end
	return ("size[8,%i]"):format(#entries)..
		default.gui_bg..
		default.gui_bg_img..
		default.gui_slots..
		table.concat(entries, "")
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
	local nodeinfo = api.nodeinfo(pos)
	if fields.ability_reference then
		minetest.show_formspec(player_name, 'robot_abilities', api.formspecs.ability(nodeinfo))
		return
	end
	if fields.program_edit then
		api.formspec_data[player_name] = api.formspec_data[player_name] or {}
		api.formspec_data[player_name].pos = pos
		local meta = nodeinfo.meta()
		local code = meta:get_string('code')
		local err = meta:get_string('error')
		local ignore_errors = meta:get_int('ignore_errors')
		minetest.show_formspec(player_name, 'robot_program', api.formspecs.program(code, err, ignore_errors == 1))
		return
	end
	if fields.status then
		local meta = nodeinfo.meta()
		local status = nodeinfo.info().status
		if status == 'stopped' then
			meta:set_string('error', '')
			api.set_status(nodeinfo, 'running')
			minetest.show_formspec(player_name, '', '')
		elseif status == 'running' then
			api.set_status(nodeinfo, 'stopped')
		elseif status == 'error' then
			api.formspec_data[player_name] = api.formspec_data[player_name] or {}
			api.formspec_data[player_name].pos = pos
			minetest.show_formspec(player_name, 'robot_error', api.formspecs.error(meta:get_string('error')))
		elseif status == 'broken' then
			minetest.show_formspec(player_name, 'robot_broken', api.formspecs.broken())
		end
		return
	end
	local ability_switch
	for field,val in pairs(fields) do
		if val and string.sub(field, 1, 15) == 'ability_switch_' then
			ability_switch = string.sub(field, 16)
			break
		end
	end
	if ability_switch then
		local meta = nodeinfo.meta()
		local extras_enabled_list = string.split(meta:get_string('extras'),',')
		local extras_enabled_new = {}
		local found = false
		for _,def in ipairs(extras_enabled_list) do
			if def == ability_switch then
				found = true
				api.unapply_ability(nodeinfo, player_name, api.abilities_ability_index[def])
			else
				table.insert(extras_enabled_new, def)
			end
		end
		if not found then
			api.apply_ability(nodeinfo, player_name, api.abilities_ability_index[ability_switch])
			table.insert(extras_enabled_new, ability_switch)
		end
		meta:set_string('extras', table.concat(extras_enabled_new, ','))

		api.formspec_data[player_name] = api.formspec_data[player_name] or {}
		api.formspec_data[player_name].pos = pos
		api.formspec_data[player_name].psuedo_metadata = true
		api.update_formspec(nodeinfo)
		minetest.show_formspec(player_name, 'robot_inventory', meta:get_string('formspec'))
		return
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
			local nodeinfo = api.nodeinfo(pos)
			local meta = nodeinfo.meta()
			if nodeinfo.info().status == 'error' then
				meta:set_string('error', '')
				api.set_status(nodeinfo, 'stopped')
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
	local nodeinfo = api.nodeinfo(pos)
	local meta = nodeinfo.meta()

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
		if nodeinfo.info().status == 'error' then
			api.set_status(nodeinfo, 'stopped')
		end

		api.formspec_data[player_name].psuedo_metadata = true
		minetest.show_formspec(player_name, 'robot_inventory', meta:get_string('formspec'))
	end
end)
