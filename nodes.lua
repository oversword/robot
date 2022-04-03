local api = robot.internal_api
local S = api.translator



local function on_timer (pos, dtime)
	local nodeinfo = api.nodeinfo(pos)

	if nodeinfo.info().status ~= 'running' then
		return false
	end
	local meta = nodeinfo.meta()

	local empty = true
	for _,n in ipairs(nodeinfo.robot_set()) do
		if not n.inv():is_empty('fuel') then
			empty = false
			break
		end
	end
	if empty then
		api.set_error(nodeinfo, S("Out of fuel"))
		return false
	end

	-- If there's no code, stop running but keep the skin
	-- so builders can use the running face
	if meta:get_string('code') == "" then
		local count = 1
		for _,n in ipairs(nodeinfo.robot_set()) do
			local removed = n.inv():remove_item('fuel', ItemStack({
				name=api.config.fuel_item,
				count=count
			}))
			count = count - removed:get_count()
			if count <= 0 then
				break
			end
		end

		return false
	end

	local ok, errmsg, newinfo, fuel_used = api.execute(nodeinfo)
	if newinfo then
		nodeinfo = newinfo
	end
	if nodeinfo.any_boost_enabled() and math.random() > 0.5 then
		fuel_used = (fuel_used or 0) + 1
	end
	if fuel_used and fuel_used > 0 then
		local count = fuel_used
		for _,n in ipairs(nodeinfo.robot_set()) do
			local removed = n.inv():remove_item('fuel', ItemStack({
				name=api.config.fuel_item,
				count=count
			}))
			count = count - removed:get_count()
			if count <= 0 then
				break
			end
		end
	end

	if not ok then
		-- minetest.log("error",  errmsg)
		return not api.set_error(nodeinfo, errmsg)
	end

	if errmsg ~= "" then
		nodeinfo.meta():set_string('error', errmsg)
	end

	return true
end

local anim_texture = function (image, dur)
	return {
		name = image,
		animation = {
		type = "vertical_frames",
			aspect_w = 8,
			aspect_h = 8,
			length = dur,
		}
	}
end

local devil_tiles = {
	top = 'robot_dark_top.png',
	front = {
		stopped = 'robot_dark_front.png',
		running = 'robot_dark_front_running.png',
		error = 'robot_dark_front_error.png',
		broken = 'robot_dark_front_broken.png',
	},
	front_body = {
		stopped = 'robot_dark_body_front.png',
		running = anim_texture('robot_dark_body_front_running.png', 1),
		error = 'robot_dark_body_front.png',
		broken = 'robot_dark_body_front_broken.png',
	},
	front_legs = {
		stopped = anim_texture('robot_dark_legs_front.png', 1),
		running = anim_texture('robot_dark_legs_front_running.png', 0.5),
		error = anim_texture('robot_dark_legs_front.png', 1),
		broken = 'robot_dark_legs_front_broken.png',
	},
	back = {
		stopped = 'robot_dark_back.png',
		running = anim_texture('robot_dark_back_running.png', 1),
		error = anim_texture('robot_dark_back_error.png', 1),
		broken = 'robot_dark_back_broken.png',
	},
	side = {
		stopped = 'robot_dark_side.png',
		running = anim_texture('robot_dark_side_running.png', 1),
		error = anim_texture('robot_dark_side_error.png', 1),
		broken = 'robot_dark_side_broken.png',
	},
	side_flipped = {
		stopped = 'robot_dark_side.png^[transform4',
		running = anim_texture('robot_dark_side_running.png^[transform4', 1),
		error = anim_texture('robot_dark_side_error.png^[transform4', 1),
		broken = 'robot_dark_side_broken.png^[transform4',
	},
}
local god_tiles = {
	top = 'robot_light_top.png',
	front = {
		stopped = 'robot_light_front.png',
		running = 'robot_light_front_running.png',
		error = 'robot_light_front_error.png',
		broken = 'robot_light_front_broken.png',
	},
	side = {
		stopped = anim_texture('robot_light_side.png', 2),
		running = 'robot_light_top.png',
		error = anim_texture('robot_light_side_error.png', 0.8),
		broken = anim_texture('robot_light_side_broken.png',  0.8),
	},
	side_legs = {
		stopped = anim_texture('robot_light_legs_side.png', 2),
		running = anim_texture('robot_light_legs_side_running.png', 0.8),
		error = anim_texture('robot_light_legs_side_error.png', 0.8),
		broken = anim_texture('robot_light_legs_side_broken.png', 0.8),
	}
}
local man_tiles = {
	top = 'robot_norm_top.png',
	top_connectable = 'robot_norm_top_connectable.png',
	bottom = 'robot_norm_bottom.png',
	bottom_legs = 'robot_norm_legs_bottom.png',
	front_legs = 'robot_norm_legs_front.png',
	side_body = 'robot_norm_body_side.png',
	side = {
		stopped = 'robot_norm_side.png',
		running = anim_texture('robot_norm_side_running.png', 1),
		error = anim_texture('robot_norm_side_error.png', 1),
		broken = 'robot_norm_side_broken.png'
	},
	side_legs = {
		stopped = 'robot_norm_legs_side.png',
		running = anim_texture('robot_norm_legs_side_running.png', 1),
		error = anim_texture('robot_norm_legs_side_error.png', 1),
		broken = 'robot_norm_legs_side_broken.png'
	},
	front_body = {
		stopped = 'robot_norm_body_front.png',
		running = anim_texture('robot_norm_body_front_running.png', 1),
		error = anim_texture('robot_norm_body_front_error.png', 1),
		broken = 'robot_norm_body_front_broken.png'
	},
	back = {
		stopped = 'robot_norm_back.png',
		running = 'robot_norm_back_running.png',
		error = 'robot_norm_back_error.png',
		broken = 'robot_norm_back_error.png',
	},
	front = {
		stopped = 'robot_norm_front.png',
		running = 'robot_norm_front_running.png',
		error = 'robot_norm_front_error.png',
		broken = 'robot_norm_front_broken.png',
	}
}

api.parts = {
	head = {
		description = S("Head"),
		name_postfix = "",
		tiles = {
			-- up, down, right, left, back, front
			man = {
				man_tiles.top,
				man_tiles.bottom,
				man_tiles.side,
				man_tiles.side,
				man_tiles.back,
				man_tiles.front,
			},
			devil = {
				devil_tiles.top,
				devil_tiles.top,
				devil_tiles.side,
				devil_tiles.side_flipped,
				devil_tiles.back,
				devil_tiles.front,
			},
			god = {
				god_tiles.side,
				god_tiles.top,
				god_tiles.side,
				god_tiles.side,
				god_tiles.side,
				god_tiles.front,
			}
		}
	},
	body = {
		description = S("Body"),
		name_postfix = "_body",
		tiles = {
			-- up, down, right, left, back, front
			man = {
				man_tiles.top_connectable,
				man_tiles.top,
				man_tiles.side_body,
				man_tiles.side_body,
				man_tiles.side,
				man_tiles.front_body,
			},
			devil = {
				devil_tiles.top,
				devil_tiles.top,
				devil_tiles.back,
				devil_tiles.back,
				devil_tiles.top,
				devil_tiles.front_body,
			},
			god = {
				god_tiles.side,
				god_tiles.top,
				god_tiles.side,
				god_tiles.side,
				god_tiles.side,
				god_tiles.side,
			},
		},
		connects_above = {head=true},
		default_abilities = {"carry","fuel"}
	},
	legs = {
		description = S("Legs"),
		name_postfix = "_legs",
		tiles = {
			-- up, down, right, left, back, front
			man = {
				man_tiles.top_connectable,
				man_tiles.bottom_legs,
				man_tiles.side_legs,
				man_tiles.side_legs,
				man_tiles.front_legs,
				man_tiles.front_legs,
			},
			devil = {
				devil_tiles.top,
				devil_tiles.top,
				devil_tiles.front_legs,
				devil_tiles.front_legs,
				devil_tiles.front_legs,
				devil_tiles.front_legs,
			},
			god = {
				god_tiles.side,
				god_tiles.top,
				god_tiles.side_legs,
				god_tiles.side_legs,
				god_tiles.side_legs,
				god_tiles.side_legs,
			},
		},
		connects_above = {head=true,body=true},
		default_abilities = {"move","turn"}
	}
}

api.tiers = {
	man = {
		name_prefix = "norm_",
		delay = 2,
		ability_slots = 5,
		inventory_size = 1,
		form_size = 8,
		max_fall = 10,
	},
	devil = {
		name_prefix = "dark_",
		delay = 3,
		ability_slots = 6,
		inventory_size = 2,
		form_size = 9,
		max_fall = 13,
		extra_abilities = {
			"boost",
		}
	},
	god = {
		name_prefix = "light_",
		delay = 4,
		ability_slots = 7,
		inventory_size = 4,
		form_size = 10,
		max_fall = 16,
		extra_abilities = {
			"fuel_swap",
			"boost",
		}
	}
}
local function get_tiles(tile_set, state)
	local ret = {}
	for i,tile in ipairs(tile_set) do
		if type(tile) == 'string' then
			ret[i] = tile
		elseif tile[state] then
			ret[i] = tile[state]
		else
			ret[i] = tile
		end
	end
	return ret
end

api.index = {
	tier = {},
	part = {},
	status = {},
}


local function gen_robot_name(tier, part, status)
	local name = api.robot_name(tier, part, status)
	api.index.tier[name] = tier
	api.index.part[name] = part
	api.index.status[name] = status
	return name
end

function api.robot_name(tier, part, status)
	local ret = "robot:"..api.tiers[tier].name_prefix.."robot"..api.parts[part].name_postfix
	if status and status ~= 'stopped' then
		ret = ret .. "_" .. status
	end
	return ret
end

function api.robot_def(name)
	if string.sub(name,1,6) ~= 'robot:' then return end
	local tier = api.index.tier[name]
	local part = api.index.part[name]
	local status = api.index.status[name]
	if not tier or not part or not status then return end
	return tier, part, status
end

for tier,tier_def in pairs(api.tiers) do
local tier_props = table.copy(api.basic_node)

for part,part_def in pairs(api.parts) do
local part_props = table.copy(tier_props)

if part_def.description then
	part_props.description = part_props.description .. " ("..part_def.description..")"
end

local stopped_props = table.copy(part_props)
stopped_props.tiles = get_tiles(part_def.tiles[tier], 'stopped')
minetest.register_node(gen_robot_name(tier, part, 'stopped'), stopped_props)


local running_props = table.copy(part_props)
running_props.tiles = get_tiles(part_def.tiles[tier], 'running')
running_props.groups.not_in_creative_inventory = 1
running_props.on_timer = on_timer
minetest.register_node(gen_robot_name(tier, part, 'running'), running_props)


local error_props = table.copy(part_props)
error_props.tiles = get_tiles(part_def.tiles[tier], 'error')
error_props.groups.not_in_creative_inventory = 1
minetest.register_node(gen_robot_name(tier, part, 'error'), error_props)


local broken_props = table.copy(part_props)
broken_props.tiles = get_tiles(part_def.tiles[tier], 'broken')
broken_props.groups.not_in_creative_inventory = 1
broken_props.description = S("Broken Automated Robot")
if api.config.repair_item ~= 'tubelib:repairkit' then
	broken_props.on_punch = function (pos, node, puncher, pointed_thing)
		if not (puncher and puncher:is_player()) then return end

		local nodeinfo = api.nodeinfo(pos, node)
		local info = nodeinfo.info()
		if info.status ~= 'broken' then return end

		local item = puncher:get_wielded_item()
		if item:is_empty() then return end
		if item:get_name() ~= api.config.repair_item then return end

		local taken = item:take_item(1)
		if taken:is_empty() then return end

		api.clear_error(nodeinfo)
		api.set_status(nodeinfo, 'stopped')

		return puncher:set_wielded_item(item)
	end
end
minetest.register_node(gen_robot_name(tier, part, 'broken'), broken_props)

if api.tubelib_options then
	tubelib.register_node(
		api.robot_name(tier, part, 'stopped'),
		{
			api.robot_name(tier, part, 'stopped'),
			api.robot_name(tier, part, 'error'),
			api.robot_name(tier, part, 'broken'),
			api.robot_name(tier, part, 'running')
		},
		api.tubelib_options
	)
end

end

end
