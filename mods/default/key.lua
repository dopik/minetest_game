local S = default.get_translator

minetest.register_tool("default:key", {
	description = S("Key"),
	inventory_image = "default_key.png",
	groups = {key = 1, not_in_creative_inventory = 1},
	stack_max = 1,
	on_place = function(itemstack, placer, pointed_thing)
		local under = pointed_thing.under
		local node = minetest.get_node(under)
		local def = minetest.registered_nodes[node.name]
		if def and def.on_rightclick and
				not (placer and placer:is_player() and
				placer:get_player_control().sneak) then
			return def.on_rightclick(under, node, placer, itemstack,
				pointed_thing) or itemstack
		end
		if pointed_thing.type ~= "node" then
			return itemstack
		end

		local pos = pointed_thing.under
		node = minetest.get_node(pos)

		if not node or node.name == "ignore" then
			return itemstack
		end

		local ndef = minetest.registered_nodes[node.name]
		if not ndef then
			return itemstack
		end

		local on_key_use = ndef.on_key_use
		if on_key_use then
			on_key_use(pos, placer)
		end

		return nil
	end,
	on_secondary_use = function(itemstack, user, pointed_thing)
		minetest.show_formspec(
			user:get_player_name(),
			"default:rename_key",
			string.format("field[keyname;%s;%s]", S("Key name"), itemstack:get_meta():get_string("description"))
		)
	end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "default:rename_key" or not fields.keyname then
		return
	end
	
	local item = player:get_wielded_item()
	if minetest.get_item_group(item:get_name(), "key") == 1 then
		item:get_meta():set_string("description", fields.keyname)
		player:set_wielded_item(item)
	end
end)

minetest.register_craftitem("default:skeleton_key", {
	description = S("Skeleton Key"),
	inventory_image = "default_key_skeleton.png",
	on_use = function(itemstack, user, pointed_thing)
		if pointed_thing.type ~= "node" then
			return itemstack
		end

		local pos = pointed_thing.under
		local node = minetest.get_node(pos)

		if not node then
			return itemstack
		end

		local on_skeleton_key_use = minetest.registered_nodes[node.name].on_skeleton_key_use
		if not on_skeleton_key_use then
			return itemstack
		end

		-- make a new key secret in case the node callback needs it
		local random = math.random
		local newsecret = string.format(
			"%04x%04x%04x%04x",
			random(2^16) - 1, random(2^16) - 1,
			random(2^16) - 1, random(2^16) - 1)

		local secret, _, _ = on_skeleton_key_use(pos, user, newsecret)

		if secret then
			local inv = minetest.get_inventory({type="player", name=user:get_player_name()})

			-- update original itemstack
			itemstack:take_item()

			-- finish and return the new key
			local new_stack = ItemStack("default:key")
			local meta = new_stack:get_meta()
			meta:set_string("secret", secret)
			meta:set_string("owner", user:get_player_name())
			meta:set_string("description", S("Key to @1's @2", user:get_player_name(),
				minetest.registered_nodes[node.name].description))

			if itemstack:get_count() == 0 then
				itemstack = new_stack
			else
				if inv:add_item("main", new_stack):get_count() > 0 then
					minetest.add_item(user:get_pos(), new_stack)
				end -- else: added to inventory successfully
			end
			
			return itemstack
		end
	end
})

-- crafting recipes

minetest.register_craft({
	output = "default:skeleton_key",
	recipe = {
		{"default:gold_ingot"},
	}
})

minetest.register_craft({
	type = "cooking",
	output = "default:gold_ingot",
	recipe = "default:key",
	cooktime = 5,
})

minetest.register_craft({
	type = "cooking",
	output = "default:gold_ingot",
	recipe = "default:skeleton_key",
	cooktime = 5,
})

-- overwrite default.can_interact_with_node

local old_can_interact_with_node = default.can_interact_with_node or
		function() return false end
		
default.can_interact_with_node = function(player, pos)
	local item = player:get_wielded_item()
	if minetest.get_item_group(item:get_name(), "key") == 1 then
		local key_meta = item:get_meta()

		if key_meta:get_string("secret") == "" then
			local key_oldmeta = item:get_metadata()
			if key_oldmeta == "" or not minetest.parse_json(key_oldmeta) then
				return false
			end

			key_meta:set_string("secret", minetest.parse_json(key_oldmeta).secret)
			item:set_metadata("")
		end

		return meta:get_string("key_lock_secret") == key_meta:get_string("secret")
	end
	
	return old_can_interact_with_node(player, pos)
end