local S = core.get_translator("linetrack")

local setaspectf = function(prefix)
	return function(pos, node, asp)
		if asp.main == 0 then
			if asp.shunt then
				advtrains.ndb.swap_node(pos, { name = prefix .. "_shunt", param2 = node.param2 })
			else
				advtrains.ndb.swap_node(pos, { name = prefix .. "_danger", param2 = node.param2 })
			end
		else
			if not asp.dst or asp.dst == -1 then
				advtrains.ndb.swap_node(pos, { name = prefix .. "_free", param2 = node.param2 })
			else
				advtrains.ndb.swap_node(pos, { name = prefix .. "_slow", param2 = node.param2 })
			end
		end
		local meta = core.get_meta(pos)
		if meta then
			meta:set_string("infotext", core.serialize(asp))
		end
	end
end

local suppasp = {
	main = {
		free = nil,
		speed = { 6, -1 },
	},
	dst = {
		free = nil,
		speed = nil,
	},
	shunt = {
		free = nil,
		proceed_as_main = true,
	},
	info = {
		call_on = false,
		dead_end = false,
		w_speed = nil,
	}
}

for typ, prts in pairs({
	danger = { asp = advtrains.interlocking.DANGER, n = "slow", ici = true },
	slow   = { asp = { main = { free = true, speed = 6 }, shunt = { proceed_as_main = true } }, n = "free" },
	free   = { asp = { main = { free = true, speed = -1 }, shunt = { proceed_as_main = true } }, n = "shunt" },
	shunt  = { asp = { main = { free = false }, shunt = { free = true } }, n = "danger" },
}) do
	core.register_node("linetrack:signal_" .. typ, {
		description = S("Generic Main Signal"),
		drawtype = "mesh",
		mesh = "linetrack_signal.obj",
		tiles = { "linetrack_signal_" .. typ .. ".png" },
		selection_box = {
			type = "fixed",
			fixed = { -5/16, -5/16, -5/16, 5/16, 5/16, 5/16 }
		},

		paramtype = "light",
		sunlight_propagates = true,
		light_source = 4,
		walkable = false,
		liquids_pointable = true,

		groups = {
			cracky = 2,
			advtrains_signal = 2,
			not_blocking_trains = 1,
			save_in_at_nodedb = 1,
			not_in_creative_inventory = prts.ici and 0 or 1,
		},
		drop = "linetrack:signal_danger",
		inventory_image = "linetrack_signal_danger.png",
		advtrains = {
			set_aspect = setaspectf("linetrack:signal"),
			supported_aspects = suppasp,
			get_aspect = function()
				return prts.asp
			end,
		},
		on_rightclick = advtrains.interlocking.signal_rc_handler,
		can_dig = advtrains.interlocking.signal_can_dig,
		use_texture_alpha = "blend",
	})

	core.register_node("linetrack:road_signal_" .. typ, {
		description = S("Road Main Signal"),
		drawtype = "nodebox",
		tiles = { "linetrack_lane_" .. typ .. ".png", "linetrack_transparent.png" },
		node_box = {
			type = "fixed",
			fixed = { -0.5, -0.5, -0.5, 0.5, -0.49, 0.5 }
		},

		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		walkable = false,

		groups = {
			cracky = 2,
			advtrains_signal = 2,
			not_blocking_trains = 1,
			save_in_at_nodedb = 1,
			not_in_creative_inventory = prts.ici and 0 or 1,
		},
		drop = "linetrack:road_signal_danger",
		inventory_image = "linetrack_lane_danger.png",
		advtrains = {
			set_aspect = setaspectf("linetrack:road_signal"),
			supported_aspects = suppasp,
			get_aspect = function()
				return prts.asp
			end,
		},
		on_rightclick = advtrains.interlocking.signal_rc_handler,
		can_dig = advtrains.interlocking.signal_can_dig,
		use_texture_alpha = "blend",
	})
end

local at_tcb = core.registered_nodes["advtrains_interlocking:tcb_node"]

core.register_node("linetrack:tcb_node", {
	drawtype = "mesh",
	paramtype = "light",
	paramtype2 = "facedir",
	walkable = false,
	mesh = "linetrack_signal.obj",
	tiles = { "linetrack_tcb.png" },
	description = S("Line Circuit Break"),
	sunlight_propagates = true,
	liquids_pointable = true,
	selection_box = {
		type = "fixed",
		fixed = { -5/16, -5/16, -5/16, 5/16, 5/16, 5/16 }
	},
	groups = {
		cracky = 3,
		not_blocking_trains = 1,
		--save_in_at_nodedb=2,
		at_il_track_circuit_break = 1,
	},
	after_place_node = at_tcb.after_place_node,
	on_rightclick = at_tcb.on_rightclick,
	can_dig = at_tcb.can_dig,
	after_dig_node = at_tcb.after_dig_node,
})

core.register_node("linetrack:road_tcb_node", {
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	walkable = false,
	tiles = { "linetrack_lane_tcb.png", "linetrack_transparent.png" },
	wield_image = "linetrack_lane_tcb.png",
	inventory_image = "linetrack_lane_tcb.png",
	description = S("Road Circuit Break"),
	sunlight_propagates = true,
	node_box = {
		type = "fixed",
		fixed = { -0.5, -0.5, -0.5, 0.5, -0.49, 0.5 }
	},
	groups = {
		cracky = 3,
		not_blocking_trains = 1,
		--save_in_at_nodedb=2,
		at_il_track_circuit_break = 1,
	},
	after_place_node = at_tcb.after_place_node,
	on_rightclick = at_tcb.on_rightclick,
	can_dig = at_tcb.can_dig,
	after_dig_node = at_tcb.after_dig_node,
})

-- tsr_rail.lua
-- Point speed restriction rails
-- Simple rail whose only purpose is to place a TSR on the position,
-- as a temporary solution until the timetable system covers everything.
-- This code resembles the code in lines/stoprail.lua

local function updateform(pos)
	local meta = core.get_meta(pos)
	local pe = advtrains.encode_pos(pos)
	local npr = advtrains.interlocking.npr_rails[pe] or 2

	meta:set_string("infotext", attrans("Point speed restriction: @1", npr))
	meta:set_string("formspec", "field[npr;" .. attrans("Set point speed restriction:") .. ";" .. npr .. "]")
end


local adefunc = function()
	return {
		after_place_node = function(pos)
			updateform(pos)
		end,
		after_dig_node = function(pos)
			local pe = advtrains.encode_pos(pos)
			advtrains.interlocking.npr_rails[pe] = nil -- luacheck: ignore
		end,
		on_receive_fields = function(pos, _, fields, player)
			local pname = player:get_player_name()
			if not core.check_player_privs(pname, { interlocking = true }) then
				core.chat_send_player(pname,
					attrans("You are not allowed to configure this track without the @1 privilege.", "interlocking"))
				return
			end
			if core.is_protected(pos, pname) then
				core.chat_send_player(pname, attrans("You are not allowed to configure this track."))
				core.record_protection_violation(pos, pname)
				return
			end
			if fields.npr then
				local pe = advtrains.encode_pos(pos)
				advtrains.interlocking.npr_rails[pe] = tonumber(fields.npr) -- luacheck: ignore
				updateform(pos)
			end
		end,
		advtrains = {
			on_train_approach = function(pos, _, train, index)
				if train.path_cn[index] == 1 then
					local pe = advtrains.encode_pos(pos)
					local npr = advtrains.interlocking.npr_rails[pe] or 2
					advtrains.lzb_add_checkpoint(train, index, npr, nil)
				end
			end,
		},
	}
end

local suitable_substrate = linetrack.suitable_substrate

advtrains.register_tracks("waterline", {
	nodename_prefix = "linetrack:watertrack_spd",
	texture_prefix = "advtrains_ltrack_spd",
	models_prefix = "advtrains_ltrack",
	models_suffix = ".obj",
	shared_texture = "linetrack_spd.png",
	description = S("Point Speed Restriction Water Track"),
	liquids_pointable = true,
	formats = {},
	suitable_substrate = suitable_substrate,
	get_additional_definiton = adefunc,
}, advtrains.trackpresets.t_30deg_straightonly)

advtrains.register_tracks("roadline", {
	nodename_prefix = "linetrack:roadtrack_spd",
	texture_prefix = "advtrains_rtrack_spd",
	models_prefix = "advtrains_ltrack",
	models_suffix = ".obj",
	shared_texture = "linetrack_road_spd.png",
	description = S("Point Speed Restriction Road Track"),
	formats = {},
	get_additional_definiton = adefunc,
}, advtrains.trackpresets.t_30deg_straightonly)
