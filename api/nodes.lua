local api = robot.internal_api
local S = api.translator


local tiers = {}

function api.tier(name)
	return tiers[name]
end
function api.tiers()
	local ret = {}
	for tier,_ in pairs(tiers) do
		table.insert(ret, tier)
	end
	return ret
end
function api.add_tier(name, tier_obj_input)
	local tier_obj = table.copy(tier_obj_input)
	if not name then
		error("A tier must have a name.")
		return
	end
	if type(name) ~= 'string' then
		error(("A tier's name must be a string, '%s' given."):format(type(name)))
		return
	end
	if tiers[name] then
		error(("A tier already exists with this name: '%s'."):format(name))
		return
	end
	if not tier_obj.name_prefix then
		error("A tier must have a name_prefix.")
		return
	end
	if type(tier_obj.name_prefix) ~= 'string' then
		error(("A tier's name_prefix must be a string, '%s' given."):format(type(tier_obj.name_prefix)))
		return
	end
	local found_tier
	for tier,def in pairs(tiers) do
		if def.name_prefix == tier_obj.name_prefix then
			found_tier = tier
			break
		end
	end
	if found_tier then
		error(("The tier '%s' already exists with the name_prefix: '%s'."):format(found_tier, tier_obj.name_prefix))
		return
	end
	if not tier_obj.delay then
		tier_obj.delay = 2
	end
	if not tier_obj.ability_slots then
		tier_obj.ability_slots = 5
	end
	if not tier_obj.inventory_size then
		tier_obj.inventory_size = 4
	end
	if not tier_obj.form_size then
		tier_obj.form_size = 8
	end
	if not tier_obj.max_fall then
		tier_obj.max_fall = 10
	end
	if type(tier_obj.delay) ~= 'number' then
		error(("A tier's delay must be a number, '%s' given."):format(type(tier_obj.delay)))
		return
	end
	if type(tier_obj.ability_slots) ~= 'number' then
		error(("A tier's ability_slots must be a number, '%s' given."):format(type(tier_obj.ability_slots)))
		return
	end
	if type(tier_obj.inventory_size) ~= 'number' then
		error(("A tier's inventory_size must be a number, '%s' given."):format(type(tier_obj.inventory_size)))
		return
	end
	if type(tier_obj.form_size) ~= 'number' then
		error(("A tier's form_size must be a number, '%s' given."):format(type(tier_obj.form_size)))
		return
	end
	if type(tier_obj.max_fall) ~= 'number' then
		error(("A tier's max_fall must be a number, '%s' given."):format(type(tier_obj.max_fall)))
		return
	end
	if tier_obj.extra_abilities and type(tier_obj.extra_abilities) ~= 'table' then
		error(("A tier's extra_abilities must be a table, '%s' given."):format(type(tier_obj.extra_abilities)))
		return
	end
	if tier_obj.extra_abilities then
		for _,ability in ipairs(tier_obj.extra_abilities) do
			if not api.ability_enabled(ability) then
				error(("The tier %s uses an extra ability %s that is not enabled."):format(name, ability))
				return
			end
		end
	end

	if tier_obj.node_boxes and type(tier_obj.node_boxes) ~= 'table' then
		error(("A tier's node_boxes must be a table, '%s' given."):format(type(tier_obj.node_boxes)))
		return
	end
	if tier_obj.node_boxes then
		for part,node_box in pairs(tier_obj.node_boxes) do
			if type(node_box) ~= 'table' then
				error(("A tier's node_boxes must be a table of tables, '%s' given for %s."):format(type(node_box), part))
				return
			end
		end
	end
	if tier_obj.models and type(tier_obj.models) ~= 'table' then
		error(("A tier's models must be a table, '%s' given."):format(type(tier_obj.models)))
		return
	end
	if tier_obj.models then
		for part,model in pairs(tier_obj.models) do
			if type(model) ~= 'string' then
				error(("A tier's models must be a table of strings, '%s' given for %s."):format(type(model), part))
				return
			end
		end
	end
	if tier_obj.extra_props and type(tier_obj.extra_props) ~= 'table' then
		error(("A tier's extra_props must be a table, '%s' given."):format(type(tier_obj.extra_props)))
		return
	end

	tiers[name] = tier_obj
end

local parts = {}

function api.part(name)
	return parts[name]
end
function api.parts()
	local ret = {}
	for part,_ in pairs(parts) do
		table.insert(ret, part)
	end
	return ret
end
function api.add_part(name, part_obj_input)
	local part_obj = table.copy(part_obj_input)
	if not name then
		error("A part must have a name.")
		return
	end
	if type(name) ~= 'string' then
		error(("A part's name must be a string, '%s' given."):format(type(name)))
		return
	end
	if tiers[name] then
		error(("A part already exists with this name: '%s'."):format(name))
		return
	end
	if not part_obj.description then
		error("A part must have a description.")
		return
	end
	if type(part_obj.description) ~= 'string' then
		error(("A part's description must be a string, '%s' given."):format(type(part_obj.description)))
		return
	end
	if not part_obj.name_postfix then
		part_obj.name_postfix = ""
	end
	if type(part_obj.name_postfix) ~= 'string' then
		error(("A part's name_postfix must be a string, '%s' given."):format(type(part_obj.name_postfix)))
		return
	end
	local found_part
	for oart,def in pairs(parts) do
		if def.name_postfix == part_obj.name_postfix then
			found_part = part
			break
		end
	end
	if found_part then
		error(("The part '%s' already exists with the name_postfix: '%s'."):format(found_part, part_obj.name_postfix))
		return
	end

	if part_obj.default_abilities and type(part_obj.default_abilities) ~= 'table' then
		error(("A part's default_abilities must be a table, '%s' given."):format(type(part_obj.default_abilities)))
		return
	end
	if part_obj.default_abilities then
		for _,ability in ipairs(part_obj.default_abilities) do
			if not api.ability_enabled(ability) then
				error(("The tier %s uses a default ability %s that is not enabled."):format(name, ability))
				return
			end
		end
	end

	if part_obj.tiles and type(part_obj.tiles) ~= 'table' then
		error(("A part's tiles must be a table, '%s' given."):format(type(part_obj.tiles)))
		return
	end
	if part_obj.tiles then
		for part,tile in pairs(part_obj.tiles) do
			if type(tile) ~= 'table' then
				error(("A part's tiles must be a table of tables, '%s' given for %s."):format(type(tile), part))
				return
			end
		end
	end
	if part_obj.connects_above and type(part_obj.connects_above) ~= 'table' then
		error(("A part's connects_above must be a table, '%s' given."):format(type(part_obj.connects_above)))
		return
	end
	if part_obj.connects_above then
		for part,model in pairs(part_obj.connects_above) do
			if type(model) ~= 'boolean' then
				error(("A part's connects_above must be a table of booleans, '%s' given for %s."):format(type(model), part))
				return
			end
		end
	end
	if part_obj.extra_props and type(part_obj.extra_props) ~= 'table' then
		error(("A part's extra_props must be a table, '%s' given."):format(type(part_obj.extra_props)))
		return
	end

	parts[name] = part_obj
end

function api.robot_name(tier, part, status)
	local ret = "robot:"..api.tier(tier).name_prefix.."robot"..api.part(part).name_postfix
	if status and status ~= 'stopped' then
		ret = ret .. "_" .. status
	end
	return ret
end


local node_index = {
	tier = {},
	part = {},
	status = {},
}

function api.robot_def(name)
	if string.sub(name,1,6) ~= 'robot:' then return end
	local tier = node_index.tier[name]
	local part = node_index.part[name]
	local status = node_index.status[name]
	if not tier or not part or not status then return end
	return tier, part, status
end

function api.record_robot_name(name, tier, part, status)
	node_index.tier[name] = tier
	node_index.part[name] = part
	node_index.status[name] = status
	return name
end
