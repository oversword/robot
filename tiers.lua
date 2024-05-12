local api = robot.internal_api
local S = api.translator

api.add_tier('man', {
	name_prefix = "norm_",
	delay = 2,
	ability_slots = 5,
	inventory_size = 1,
	form_size = 8,
	max_fall = 10,
})
api.add_tier('devil', {
	name_prefix = "dark_",
	delay = 3,
	ability_slots = 6,
	inventory_size = 2,
	form_size = 9,
	max_fall = 13,
	extra_abilities = {
		"boost",
	}
})
api.add_tier('god', {
	name_prefix = "light_",
	delay = 4,
	ability_slots = 7,
	inventory_size = 4,
	form_size = 10,
	max_fall = 16,
	models = {
		body = 'octohedron.obj',
		legs = 'dome.obj',
	},
	node_boxes = {
		head = {
			type = "fixed",
			fixed = {
				{-1/4, -1/4, -1/4, 1/4, 1/4, 1/4},
			},
		}
	},
	extra_props = {
		paramtype = "light",
		light_source = 1,
		collision_box = {
			type = "fixed",
			fixed = {
				{-3/8, -3/8, -3/8, 3/8, 3/8, 3/8},
			},
		},
		selection_box = {
			type = "fixed",
			fixed = {
				{-3/8, -3/8, -3/8, 3/8, 3/8, 3/8},
			},
		},
	},
	extra_abilities = {
		"fuel_swap",
		"boost",
	}
})