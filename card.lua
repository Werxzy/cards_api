--[[pod_format="raw",created="2024-03-16 12:26:44",modified="2024-06-24 17:51:12",revision=15054]]

card_back = {sprite = 10} -- sprite can be number or userdata

cards_all = {}
card_shadows_on = true

cards_animated = {}

function get_all_cards()
	return cards_all
end

--function card_new(sprite, x, y, a, w, h, back_sprite)
function card_new(param)
	local x = param.x or 0
	local y = param.y or 0
	local a = param.a or 0
	
	local w = param.w or param.width or 45
	local h = param.h or param.height or 60
	
-- todo??? make a card metatable with a weak reference to a stack
-- sometimes after a lot of testing, picotron runs out of memory
-- stacks/cards might not be garbage collected due to referencing eachother
-- I think this only occurs if exiting in the middle of a game

	-- expects sprite to be a number, userdata, or table with .sprite
	
--	!!! if x, y, a or their to values are changed, need to update stack_quick_swap
	return add(cards_all, {
		ty = "card",
		
		x = smooth_val(x, 0.7, 0.1), 
		y = smooth_val(y, 0.7, 0.1), 
		x_offset = smooth_val(0, 0.5, 0.3), 
		y_offset = smooth_val(0, 0.5, 0.3), 
		a = smooth_angle(a, 0.7, 0.12),
		
		x_to = x,
		y_to = y,
		x_offset_to = 0,
		y_offset_to = 0,
		a_to = a,
		
		width = w,
		height = h,
		wh_key = tostr(w) .. "," .. tostr(h),
		
		sprite = param.sprite,
		back_sprite = param.back_sprite,
		shadow = 0
		})
	
end

-- drawing function for cards
-- shifts vertical lines of pixels to give the illusion if the card turning
function card_draw(c)
	local facing_down = (c.a()-0.45) % 1 < 0.1 -- facing 45 degree limit for facing down
--	local sprite = facing_down and card_back.sprite or c.sprite
	local sprite = facing_down and c.back_sprite or c.sprite
	
	local x, y, width, height = c.x() + c.x_offset(), c.y() + c.y_offset(), c.width, c.height
	--local angle = (c.x"vel" + c.x_offset"vel") / -100 + c.a()
	local angle = c.a()
	local v = c.x"vel" + c.x_offset"vel"
	angle += sgn(v) * (0.25 / (abs(v)/10+1) - 0.25)
		
	local dx, dy = cos(angle), -sin(angle)*0.5
	if dx < 0 then
		sprite = c.back_sprite
		dx = -dx
		dy = -dy
	end
	
	if(type(sprite) == "table") sprite = sprite.sprite

	if	card_shadows_on then
		card_shadow_draw(c, x, y, width, height, dx, dy)
	end

	if abs(dy*c.width) < 1 then
		sspr(sprite, 0, 0, width, height, x, y)
		--sspr(sprite, 0, 0, width, 20, x, y) -- example of cutting off cards to save cpu
	else
		local x = x - dx*width/2 + width/2
		local sx = 0
		y -= dy * width / 2
		y += 0.5
		
		local last_drawn = -999
		for x2 = 0,width - 1 do
			-- only draw one vertical slice at a time
			-- could do this mathmatically, but nah :)
			if x\1 ~= last_drawn then
				sspr(sprite, x2, 0, 1, height, x, y)
				last_drawn = x\1
			end
			x += dx
			y += dy
		end
	end
end


function card_shadow_draw(c, x, y, width, height, dx, dy)

	c.shadow = lerp(c.shadow, c.stack == held_stack and 1 or -0.1, 0.2 - mid((abs(c.x"vel") - abs(c.y"vel"))/15, 0.15))
	
	--subtle effect for cards that are moving around
	--local v = c.stack == held_stack and 1 or mid((abs(c.x"vel") + abs(c.y"vel"))/5-0.1, 1, -0.1)
	--c.shadow = lerp(c.shadow or 0, v, 0.2 - mid((abs(c.x"vel") + abs(c.y"vel"))/15, 0.15))		
	
	if c.shadow > 0 then
		
		local xx = x - dx*width/2 + width/2
		local x1, y1, x2, y2 = xx, y+7 + height/3, xx+width*dx-1, y+height+6 + abs(dy)*c.width/3 - (1-c.shadow) * 10
		local xmid = (x1+x2)/2
		x1 = min(x1, xmid-7)
		x2 = max(x2, xmid+7)
		poke(0x5509, 0xff) -- only shadow once on a pixel
		poke(0x550b, 0xff)
		-- poke 4/8 here?
		
		fillp(0xa5a5a5a5a5a5a5a5)
	
		local xmid = (x1+x2)/2
		local xc1, xc2 = x1+4,  x2-4
		rectfill(x1, y1, x2, y2-4, 32)
		rectfill(x1+4, y2-8, x2-4, y2)
		circfill(x1+4, y2-4, 4)
		circfill(x2-4, y2-4, 4)
		circfill(xmid, y1, 7)
		fillp()
		
		x1 += 3
		x2 -= 3
		y2 -= 3
		
		rectfill(x1, y1, x2, y2-4)
		rectfill(x1+4, y2-8, x2-4, y2)
		circfill(x1+4,y2-4,4)
		circfill(x2-4,y2-4,4)
		circfill(xmid,y1,4)
		
		poke(0x5509, 0x3f)
		poke(0x550b, 0x3f)
	end
end

-- updates cards position and angle
function card_update(card)
	card.x(card.x_to)
	card.y(card.y_to)
	card.x_offset(card.x_offset_to)
	card.y_offset(card.y_offset_to)
	card.a(card.a_to - card.x"vel"/10000)
end

-- puts the given card above all other cards in drawing order
-- based on the card's stack's top_most value
-- should normally call AFTER changing the stack
-- 		if all stacks have the same priority, this won't matter
function card_to_top(card)
-- old method that just pushed the card to the top
--	add(cards_all, del(cards_all, card))

	del(cards_all, card)
	local tm = card.stack.top_most
	
	if #cards_all > 1 then
		for i = #cards_all, 1, -1 do
			local c2 = cards_all[i]
			if not c2.stack or c2.stack.top_most <= tm then
				add(cards_all, card, i+1)
				return
			end
		end
	end
	
	add(cards_all, card, 1)
end

function cards_into_stack_order(into_stack, held, i)
	local c_ins = into_stack.cards[i] 
	if c_ins then
		cards_to_insert(held, c_ins)
	else
		c_ins = into_stack.cards[i - 1] 
		if c_ins then
			cards_to_insert(held, c_ins, true)
		else
			stack_to_top(held)
		end
	end
end

-- puts the given stack of cards on top or below given card in drawing order
function cards_to_insert(stack, card, on_top)
	-- removes all cards first, to get correct insert position
	for c in all(stack.cards) do
		del(cards_all, c)
	end
	
	-- find position
	local c_ins = has(cards_all, card)
	if (on_top) c_ins += 1	
		
	-- reinsert cards
	for c in all(stack.cards) do
		add(cards_all, c, c_ins)
		c_ins += 1
	end
end

-- checks if the given card is on top of its stack
function card_is_top(card)
	return get_top_card(card.stack) == card
end

-- returns the top card of a stack
function get_top_card(stack)
	return stack.cards[#stack.cards]
end

-- makes a card back sprite that can be updated
function card_back_animated(data)

	local func = data.sprite
	
	data.gen = function(width, height)
		width = width or 45
		height = height or 60	

		local d2 = {}
		
		-- copy all values
		for k,v in pairs(data or {}) do
			d2[k] = v
		end
		
		-- unique param
		d2.param = {
			width = width, 
			height = height
		}
		for k,v in pairs(data.param or {}) do
			d2.param[k] = v
		end
		
		d2.sprite = userdata("u8", width, height)
		d2.param.target_sprite = d2.sprite
		
		d2.param.sprite = function(w, h)
			func(d2, w, h)
		end
		
		d2.update = function()			
			card_gen_back(d2.param)
		end
		
		d2.destroy = function()
			del(cards_animated, d2)
		end
						
		if type(data.init) == "function" then
			data.init(d2)
		end
		
		return add(cards_animated, d2)
	end
		
end

function card_back_animated_update()
	for c in all(cards_animated) do
		c.update()
	end
end

function card_position_reset_all()
	for s in all(stacks_all) do
		s:reposition()
	end
	foreach(cards_all, card_position_reset)
end

function card_position_reset(card)
	local s = card.stack
	if(not s) return
	
	card.x("pos", card.x_to)
	card.y("pos", card.y_to)
	card.x("vel", 0)
	card.y("vel", 0)

	card.a("pos", card.a_to)
	card.a("vel", 0)
end