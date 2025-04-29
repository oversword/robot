local api = robot.internal_api
local S = api.translator


api.add_formspec('program', function (code, errmsg, ignore_errors)
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
end)

api.add_formspec('inventory', function (nodeinfo)
	local meta = nodeinfo.meta()
	local extras_enabled_list = string.split(meta:get_string('extras'),',')
	local extras_enabled = {}
	for _,def in ipairs(extras_enabled_list) do
		extras_enabled[def] = true
	end
	local inv = nodeinfo.inv()
	local fuel_size = inv:get_size('fuel')
	local abilities_size = inv:get_size('abilities')
	local info = nodeinfo.info()
	local is_connective = api.is_connective(nodeinfo)
	local has_connection = is_connective and api.is_connected(nodeinfo)

	local tier_def = api.tier(info.tier)
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
	for _,ability in ipairs(api.part(info.part).default_abilities or {}) do
		if api.ability_enabled(ability) then
			table.insert(default_abilities, ([[
				item_image[%i,3;1,1;%s]
			]]):format(3+#default_abilities, api.ability(ability).item))
		end
	end
	local extra_abilities = {}
	for i,ability in ipairs(tier_def.extra_abilities or {}) do
		if api.ability_enabled(ability) then
			local ability_obj = api.ability(ability)
			table.insert(extra_abilities, ([[
				item_image_button[%i,2;1,1;%s;ability_switch_%s;]
				tooltip[ability_switch_%s;%s]
			]]):format(
				2+#extra_abilities,
				ability_obj.item,
				ability,ability,
				minetest.formspec_escape(ability_obj.description)
			)..(extras_enabled[ability] and ("item_image[%i,2;1,1;%s]"):format(2+#extra_abilities, "moretrees:coconut_1") or ""))
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
end)

api.add_formspec('ability', function (nodeinfo)
	local info = nodeinfo.info()
	local entries = {}
	for _,ability_name in ipairs(api.abilities()) do
		local ability = api.ability(ability_name)
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
end)

api.add_formspec('error', function (error)
	return ([[
		size[12,2]
		label[0.1,0.3;%s]
		button[4.75,1;3,1;dismiss_error;%s]
	]]):format(
		minetest.formspec_escape(error),
		minetest.formspec_escape(S("Dismiss error"))
	)
end)

api.add_formspec('broken', function ()
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
end)

minetest.register_on_player_receive_fields(api.global_on_receive_fields)
