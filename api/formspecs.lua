local api = robot.internal_api
local S = api.translator


local formspecs = {}

function api.add_formspec(name, method)
	formspecs[name] = method
end

local formspec_data = {}
api.formspec_data = {}
function api.formspec_data.set(player_name, attrs)
	formspec_data[player_name] = formspec_data[player_name] or {}
	for k,v in pairs(attrs) do
		formspec_data[player_name][k] = v
	end
end
function api.formspec_data.clear(player_name, attr)
	if not formspec_data[player_name] then return end

	if attr then
		formspec_data[player_name][attr] = nil
	else
		formspec_data[player_name] = nil
	end
end
function api.formspec_data.get(player_name, attr)
	if not formspec_data[player_name] then return end

	if attr then
		return formspec_data[player_name][attr]
	else
		return formspec_data[player_name]
	end
end

function api.update_formspec(nodeinfo)
	local meta = nodeinfo.meta()
	meta:set_string('formspec', formspecs.inventory(nodeinfo))
end

function api.on_receive_fields(pos, _formname, fields, sender)
	minetest.log('error', 'B: '.._formname)
	local player_name = sender:get_player_name()
	if fields.quit then
		api.formspec_data.clear(player_name)
		return
	end
	local nodeinfo = api.nodeinfo(pos)
	if fields.ability_reference then
		minetest.show_formspec(player_name, 'robot_abilities', formspecs.ability(nodeinfo))
		return
	end
	if fields.program_edit then
		api.formspec_data.set(player_name, { pos=pos })
		local meta = nodeinfo.meta()
		local code = meta:get_string('code')
		local err = meta:get_string('error')
		local ignore_errors = meta:get_int('ignore_errors')
		minetest.show_formspec(player_name, 'robot_program', formspecs.program(code, err, ignore_errors == 1))
		return
	end
	if fields.status then
		local status = nodeinfo.info().status
		if status == 'stopped' then
			api.clear_error(nodeinfo)
			api.set_status(nodeinfo, 'running')
			minetest.show_formspec(player_name, '', '')
		elseif status == 'running' then
			api.set_status(nodeinfo, 'stopped')
		elseif status == 'error' then
			api.formspec_data.set(player_name, { pos=pos })
			minetest.show_formspec(player_name, 'robot_error', formspecs.error(nodeinfo.meta():get_string('error')))
		elseif status == 'broken' then
			minetest.show_formspec(player_name, 'robot_broken', formspecs.broken())
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
				api.unapply_ability(nodeinfo, player_name, api.ability(def))
			else
				table.insert(extras_enabled_new, def)
			end
		end
		if not found then
			api.apply_ability(nodeinfo, player_name, api.ability(ability_switch))
			table.insert(extras_enabled_new, ability_switch)
		end
		meta:set_string('extras', table.concat(extras_enabled_new, ','))

		api.formspec_data.set(player_name, { pos=pos, psuedo_metadata=true })
		api.update_formspec(nodeinfo)
		minetest.show_formspec(player_name, 'robot_inventory', meta:get_string('formspec'))
		return
	end
end


function api.global_on_receive_fields(player, formname, fields)
	minetest.log('error', 'A: '..formname)
	if formname == 'robot_inventory' then
		local player_name = player:get_player_name()
		local pos = api.formspec_data.get(player_name, 'pos')
		if not pos then return end

		api.on_receive_fields(pos, formname, fields, player)
		return
	end
	if formname == 'robot_error' then
		local player_name = player:get_player_name()
		if fields.quit then
			api.formspec_data.clear(player_name)
			return
		end
		if fields.dismiss_error then
			local pos = api.formspec_data.get(player_name, 'pos')
			if not pos then return end

			local nodeinfo = api.nodeinfo(pos)
			local meta = nodeinfo.meta()
			if nodeinfo.info().status == 'error' then
				meta:set_string('error', '')
				api.set_status(nodeinfo, 'stopped')
			end

			api.formspec_data.set(player_name, {psuedo_metadata = true})
			minetest.show_formspec(player_name, 'robot_inventory', meta:get_string('formspec'))
		end
		return
	end

	if formname ~= 'robot_program' then return end

	local player_name = player:get_player_name()
	if fields.quit then
		api.formspec_data.clear(player_name)
		return
	end

	local pos = api.formspec_data.get(player_name, 'pos')
	if not pos then return end

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

		api.formspec_data.set(player_name, {psuedo_metadata = true})
		minetest.show_formspec(player_name, 'robot_inventory', meta:get_string('formspec'))
	end
end