local api = robot.internal_api
local S = api.translator


local anim_texture = function (image, dur, aspect)
	return {
		name = image,
		animation = {
			type = "vertical_frames",
			aspect_w = (aspect and aspect.w) or 8,
			aspect_h = (aspect and aspect.h) or 8,
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
	body = {
		stopped = anim_texture('robot_light_body.png', 2,{w=16,h=32}),
		running = 'robot_light_body_running.png',
		error = anim_texture('robot_light_body_error.png', 0.8,{w=16,h=32}),
		broken = anim_texture('robot_light_body_broken.png', 0.8,{w=16,h=32}),
	},
	legs = {
		stopped = anim_texture('robot_light_legs.png', 2,{w=16,h=32}),
		running = anim_texture('robot_light_legs_running.png', 0.8,{w=16,h=32}),
		error = anim_texture('robot_light_legs_error.png', 0.8,{w=16,h=32}),
		broken = anim_texture('robot_light_legs_broken.png', 0.8,{w=16,h=32}),
	},
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

api.add_part('head', {
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
})
api.add_part('body', {
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
			god_tiles.body,
		},
	},
	connects_above = {head=true},
	default_abilities = {"carry","fuel"}
})
api.add_part('legs', {
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
			god_tiles.legs,
		},
	},
	connects_above = {head=true,body=true},
	default_abilities = {"move","turn"}
})