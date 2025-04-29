local api = robot.internal_api
-- local S = api.translator

local abilities_by_item = {}
local abilities = {}

function api.ability_by_item(item)
	return abilities_by_item[item]
end
function api.ability(ability)
	return abilities[ability]
end
function api.abilities()
	local ret = {}
	for ability,_ in pairs(abilities) do
		table.insert(ret, ability)
	end
	return ret
end

function robot.add_ability(ability_obj)
	local existing_item_ability = api.ability_by_item(ability_obj.item)
	if existing_item_ability and existing_item_ability.ability ~= ability_obj.ability then
		error(("An ability already exists for this item: '%s'."):format(ability_obj.item))
		return
	end
	if not ability_obj.ability then
		error("You must define an ability name as ability_obj.ability")
		return
	end
	if api.part(ability_obj.ability) then
		error(("Ability cannot be called '%s' as it will conflict with robot.%s.[action] ect."):format(ability_obj.ability))
		return
	end
	if not ability_obj.description then
		error("You must define an ability description as ability_obj.description")
		return
	end
	if type(ability_obj.item) == 'function' then
		local item = ability_obj.item()
		ability_obj.item = item
	end
	if not ability_obj.item then
		core.log("warning", ("[robot] ability %s will not be usable until an item is set for it"):format(ability_obj.ability))
	end

	abilities_by_item[ability_obj.item] = ability_obj
	abilities[ability_obj.ability] = ability_obj
end

function robot.set_ability_item(ability, item)
	local ability_obj = abilities[ability]
	if not ability_obj then
		error("Cannot set the item of an ability that does not exist.")
		return
	end
	local existing_item_ability = abilities_by_item[item]
	if existing_item_ability then
		error(("An ability already exists for this item: '%s'."):format(item))
		return
	end
	abilities_by_item[ability_obj.item] = nil
	abilities_by_item[item] = ability_obj
	ability_obj.item = item
end

function api.ability_enabled(ability)
	local ability_obj = abilities[ability]
	if not ability_obj then return false end
	if ability_obj.disabled then return false end
	if not ability_obj.item then return false end
	return ability_obj
end

function api.any_has_ability(nodeinfo, ability, ignore_god_item)
	local ns = nodeinfo.robot_set()
	for _,n in ipairs(ns) do
		if api.has_ability(n, ability, ignore_god_item) then return n end
	end
end

function api.has_ability(nodeinfo, ability, ignore_god_item)
	local ability_obj = api.ability_enabled(ability)
	if not ability_obj then return end
	local info = nodeinfo.info()
	if not info.part then return end
	for _,def_ability in ipairs(api.part(info.part).default_abilities or {}) do
		if def_ability == ability then
			return true
		end
	end
	if ability_obj.done_by and not ability_obj.done_by[info.part] then return end

	local extras_enabled_list = string.split(nodeinfo.meta():get_string('extras'),',')
	for _,def in ipairs(extras_enabled_list) do
		if def == ability and api.tier(info.tier).extra_abilities then
			for _,ab in ipairs(api.tier(info.tier).extra_abilities) do
				if ab == ability then return true end
			end
		end
	end

	local inv = nodeinfo.inv()
	if not ignore_god_item and not ability_obj.interface_enabled and inv:contains_item('abilities', api.config.god_item) then
		return true
	end
	if inv:contains_item('abilities', ability_obj.item) then
		return true
	end
end

function api.can_have_ability_item(nodeinfo, item)
	if item == api.config.god_item then return true end
	local ability = abilities_by_item[item]
	if not ability then return end
	if ability.interface_enabled then return end
	local info = nodeinfo.info()
	if not info.part then return end
	for _,def_ability in ipairs(api.part(info.part).default_abilities or {}) do
		if def_ability == ability.ability then return end
	end
	if ability.done_by and not ability.done_by[info.part] then return end

	local inv = nodeinfo.inv()
	if inv:contains_item('abilities', item) then return end

	return true
end

function api.can_have_ability(nodeinfo, ability_name)
	local ability = abilities[ability_name]
	if not ability then return end
	if ability.interface_enabled then return end
	local info = nodeinfo.info()
	if not info.part then return end
	for _,def_ability in ipairs(api.part(info.part).default_abilities or {}) do
		if def_ability == ability.ability then return end
	end
	if ability.done_by and not ability.done_by[info.part] then return end

	local inv = nodeinfo.inv()
	if inv:contains_item('abilities', ability.item) then return end

	return true
end

function api.apply_ability(nodeinfo, player_name, ability)
	if ability.modifier then
		if not ability.un_modifier then
			core.log("error", "[robot] Ability modifier will not run unless it has an un-modfier method.")
			return
		end
		ability.modifier(nodeinfo, player_name)
	end
end

function api.unapply_ability(nodeinfo, player_name, ability)
	if ability.un_modifier then
		ability.un_modifier(nodeinfo, player_name)
	end
end

function api.stop_action (nodeinfo)
	api.set_status(nodeinfo, 'stopped')
	return nil, 0
end

function api.log_action (nodeinfo,_part,...)
	local meta = nodeinfo.meta()
	local owner = meta:get_string('player_name')
	core.chat_send_player(owner, "[robot] LOG: "..dump({...}))
	return nil, 0
end
