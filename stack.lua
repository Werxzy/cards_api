--[[pod_format="raw",created="2024-03-16 15:18:21",modified="2024-07-20 17:49:49",revision=17315]]

stacks_all = {}

-- these three functions are primarily to help with env encapsulation
-- returns all stacks
function get_all_stacks()
	return stacks_all
end

-- returns currently held stack
function get_held_stack()
	return held_stack
end

-- sets the held stack
function set_held_stack(stack)
	held_stack = stack
end

--[[
Stacks are essentially tables containing cards.
Each stack has a set of rules for how cards interact with it.
stack_new() returns a table that has been added to stack_all.

sprites = table of sprite ids or userdata to be drawn with spr
x,y = top left position of stack
	will be assigned to x_to and y_to

param is a table that can have the following key values

x_off, y_off = draw offsets of the stack's sprite(s)
reposition = function called when changing the target position of the cards
	the function usually assigns all cards .x_to and .y_to values relative to the stack's position
	defaults to stack_repose_normal
perm = the stack is destroyed when there are no more cards if this is not set trues
	defaults to true
top_most = controls the draw order of cards between stacks
	the higher the number, the higher the stack
	defaults to 0
can_stack = function called when another stack of cards is placed on top (with restrictions)
	function(self, held)
	returns true if the "held" can be placed on top of "self"
on_click = function called when stack base or card in stack is clicked
	usually set to stack_on_click_unstack(...)
on_double = function called when stack base or card in stack is double clicked
resolve_stack = function called when can_stack returns true
	defaults to stack_cards
unresolved_stack = function called when a held card is released, but isn't placed onto a stack
	defaults to stack_unresolved_return
on_hover = function called when the cursor over the stack or card
	function(self, card, held)
	self = current stack
	card = the hovered card
	held = stack that is being held by the player
off_hover = function called when the cursor is no longer over the stack or card
	similar function to on_hover, called before the next on_hover function is called
on_destroy = function called when the stack is destroyed

additional parameters can be provided to give the stack more properties
]]

function stack_new(sprites, x, y, param)

	local s = {
		ty = "stack",
		sprites = type(sprites) == "table" and sprites or {sprites},
		x_to = x,
		y_to = y,
		x_off = param.offset or -3,
		y_off = param.offset or -3,
		width = 45,
		height = 60,
		cards = {},
		perm = true,
		top_most = 0,
		reposition = stack_repose_normal(),
		can_stack = stack_cant,
		on_click = stack_cant,
		on_double = on_double,
		resolve_stack = stack_cards,
		unresolved_stack = stack_unresolved_return,
		-- on_hover = ... function(self, card, held_stack)
		-- off_hover = ... function(self, card, held_stack)
		
		destroy = stack_destroy
		-- on_destroy = ...
	}	
	
	for k,v in pairs(param) do
		s[k] = v
	end
	
	return add(stacks_all, s)
end

-- removes a stack from the game
-- if cards_too is true, then all cards that were assigned to the stack are also removed from the game
function stack_destroy(s, cards_too)
	if s.on_destroy then
		s:on_destroy()
	end
	
	if cards_too then
		foreach(s.cards, card_destroy)
	
	-- stack no longer exists, so cards' stack must be unassigned
	else	
		for c in all(s.cards) do
			c.stack = nil
		end
	end
	
	s.cards = {} -- remove references justs in case
	del(stacks_all, s)
end

-- drawing function for stacks
-- always drawn below cards
function stack_draw(s)
	if s.perm then
		local x, y = s.x_to + s.x_off, s.y_to + s.y_off
		for sp in all(s.sprites) do
			spr(sp, x, y)
		end
	end
end

-- Places cards from stack2 to onto stack
function stack_cards(stack, stack2)
	for c in all(stack2.cards) do
		add(stack.cards, del(stack2.cards, c))
		c.stack = stack
		card_to_top(c)
	end
	stack2.old_stack = nil
	if not stack2.perm then
		stack2:destroy()
	end
end

-- pushes each of the cards in the given stack to the top of the card draw order
function stack_to_top(stack)
	foreach(stack.cards, card_to_top)
	--for c in all(stack2.cards) do
	--	card_to_top(c)
	--end
end

-- inserts cards from stack2 into stack, starting from position i
function insert_cards(stack, stack2, i)
	
	-- determines where the cards will be reordered inside cards_all
	cards_into_stack_order(stack, stack2, i)
		
	for c in all(stack2.cards) do		
		add(stack.cards, del(stack2.cards, c), i)
		i += 1
		c.stack = stack
	end
	
	stack2.old_stack = nil
	stack_delete_check(stack2)
end

-- on_click event that unstacks cards starting from the given card
-- if a given rule function returns true
function stack_on_click_unstack(...)
	local rules = {...}
	
	return function(card)
		if card then
			for r in all(rules) do
				if(not r(card))return
			end
			
			set_held_stack(unstack_cards(card))
		end
	end
end

-- version for the hand stack, picking out a single card
function stack_hand_on_click_unstack(...)
	local rules = {...}
	
	return function(card)
		if card then
			for r in all(rules) do
				if(not r(card))return
			end
			
			set_held_stack(unstack_hand_card(card, true))
		end
	end
end

function unstack_rule_face_up(card)
	return card.a_to == 0
end

-- creates a new stack by taking cards from the given card's stack.
-- cards starting from the given card to the top of the stack (stack[#stack])
function unstack_cards(card)
	local old_stack = card.stack
	local new_stack = stack_held_new(old_stack, card)
	new_stack._unresolved = old_stack:unresolved_stack(new_stack)

	local i = has(old_stack.cards, card)
	while #old_stack.cards >= i do
		local c = add(new_stack.cards, deli(old_stack.cards, i))
		c.stack = new_stack
		card_to_top(c) -- puts cards on top of all the others
	end
	
	stack_delete_check(old_stack)
	
	return new_stack
end

-- old_stack is where the cards are coming from
-- card is the base position of the stack
function stack_held_new(old_stack, card)
	local st = stack_new(
		nil,
		card.x_to, card.y_to,
--		old_stack.x_to, old_stack.y_to, 
--		0, 0, 
		{
			top_most = 999,
			reposition = stack_repose_normal(10), 
			perm = false,
			old_stack = old_stack
		})

	return st
end

-- reposition calculation for a stack that allows for more floaty cards
function stack_repose_normal(y_delta, decay, limit)
	y_delta = y_delta or 12
	decay = decay or 0.7
	limit = limit or 220
	
	return function(stack)
		local y, yd = stack.y_to, min(y_delta, limit / #stack.cards)
		local lasty, lastx = y, stack.x_to
		for i, c in pairs(stack.cards) do
			local t = decay / (i+1)
			c.x_to = lerp(lastx, stack.x_to, t)
			c.y_to = lerp(lasty, y, t)
			y += yd
			
			lastx = c.x()
			lasty = c.y() + yd
		end
	end
end

-- reposition calculation that has fixed positions
function stack_repose_static(y_delta)
	y_delta = y_delta or 12
	
	return function(stack)
		local y = stack.y_to
		for c in all(stack.cards) do
			c.x_to = stack.x_to
			c.y_to = y
			y += y_delta
		end
	end
end

-- returns the y position of the top of the stack
function stack_y_pos(stack)
	local top = stack.cards[#stack.cards]
	return top and top.y_to or stack.y_to
end

-- basically always returns false for
-- more just for nice naming
-- could still be used for other events like sound effects
function stack_cant()
end

-- deletes a stack if it has no cards and if it is not permanent
function stack_delete_check(stack)
	if #stack.cards == 0 and not stack.perm then
		stack:destroy()
	end	
end

-- adds a card to the top of a stack
-- if an old stack is given, the card is removed from that table/stack instead
function stack_add_card(stack, card, old_stack)
	if card then
		if type(old_stack) == "table" then
			del(old_stack, card)
		elseif card.stack then
			del(card.stack.cards, card)
		end
		
		if type(old_stack) == "number" then
			add(stack.cards, card, old_stack).stack = stack
		else
			add(stack.cards, card).stack = stack
		end
		
		card_to_top(card)
	end
end

-- move all cards from "..." (stacks or table of stacks) to "stack_to" 
function stack_collecting_anim(stack_to, ...)
	local facing = 0.5
	
	local function collect(s)
		if s == stack_to then
			return
		end
		while #s.cards > 0 do
			local c = get_top_card(s)
			stack_add_card(stack_to, c)
			c.a_to = facing
			--sfx(3)
			pause_frames(3)
		end
	end
	
	for a in all{...} do
		local ty = type(a)
		if ty == "number" then
			facing = a
			
		elseif ty == "table" then
			if a.cards then -- single stack	
				collect(a)
				
			else -- table of stacks	
				foreach(a, collect)	
			end
		end
	end
end
	
function stack_standard_shuffle_anim(stack)
	stack_shuffle_anim(stack)
	stack_shuffle_anim(stack)
	stack_shuffle_anim(stack)
	stack_quick_shuffle(stack)
end

-- animation for physically shuffle the cards
function stack_shuffle_anim(stack)
	local c = stack.cards[1]
	local w = c and c.width or 45
	local temp_stack = stack_new(
		nil, stack.x_to + w + 4, stack.y_to, 
		{
			reposition = stack_repose_static(-0.16), 
			perm = false
		})
		
	for i = 1, rnd(10)-5 + #stack.cards/2 do
		stack_add_card(temp_stack, get_top_card(stack))
	end
	
	--sfx(3)
	pause_frames(30)
	--sfx(3)	
	
	for c in all(temp_stack.cards) do
		stack_add_card(stack, c, rnd(#stack.cards+1)\1+1)
	end
	
	del(stacks_all, temp_stack)
	
	stack_to_top(stack)
	
	pause_frames(20)
end

-- randomizes the position of all the cards in the stack, while preventing any odd jumps in the cards
function stack_quick_shuffle(stack)
	local temp, cards = {}, stack.cards
	local temp_data = {}
	
	for c in all(cards) do
		local d = add(temp_data, {})
		for k in all{"x","x_to","y","y_to","a","a_to","shadow"} do
			d[k] = c[k]
		end
	end	
		
	while #cards > 0 do
		add(temp, deli(cards, rnd(#cards)\1 + 1))
	end
	
	for i, c in pairs(temp) do
		for k,v in pairs(temp_data[i]) do
			c[k] = v
		end
		add(cards, c)
	end
	
--[[
		-- secretly randomize cards a bit
	local c = #stack.cards
	if c > 1 then -- must have more than 1 card to swap
		for i = 1, rnd(2)+9 do
			local i, j = 1, 1
			while i == j do -- guarantee cards are different
				 i, j = rnd(c)\1 + 1, rnd(c)\1 + 1
			end
			stack_quick_swap(stack,i,j) 
		end
	end
]]
	
	stack_to_top(stack)
end

-- swaps two cards instantly with no animation
-- will need to call stack_to_top to fix the draw order
function stack_quick_swap(stack, i, j)
	local c1, c2 = stack.cards[i], stack.cards[j]
	if(not c1 or not c2) return -- not the same
	
	-- swap position in stack
	stack.cards[i], stack.cards[j] = c2, c1
	
	-- swap positional properties
	for k in all{"x","x_to","y","y_to","a","a_to","shadow"} do
		c1[k], c2[k] = c2[k], c1[k]
	end
end


-- creates a function for returning cards to the top of their old stack
function stack_unresolved_return(old_stack, held_stack)
	return function()
		stack_cards(old_stack, held_stack)
	end
end

-- if a stack was unstacked and it wasn't resolved, the _unresolved function will be called
function stack_apply_unresolved(stack)
	if stack._unresolved then
		stack._unresolved()
		stack._unresolved = nil
		stack.old_stack = nil
	end
end

-- hand specific event functions

-- creates a basic stack for holding cards in a hand
-- cards can be reordered without needing to check can_stack
function stack_hand_new(sprites, x, y, param)
	local param_base = {
		top_most = 100,
		reposition = stack_repose_hand(param.hand_max_delta, param.hand_width),
		
		--can_stack = function() return true end,
		on_click = stack_hand_on_click_unstack(),
		resolve_stack = stack_insert_cards,
		unresolved_stack = stack_unresolved_return_rel_x,
		
		on_hover = hand_on_hover,
		off_hover = hand_off_hover,
		
		width = param.hand_width,
	}
	
	for k,v in pairs(param) do
		param_base[k] = v
	end
	
	return stack_new(sprites, x, y, param_base)
end

function stack_insert_cards(self, held, card)
	local ins = hand_find_insert_x(self, held)
	insert_cards(self, held, ins)
	self.ins_offset = nil
end

function stack_unresolved_return_insert(old_stack, held_stack, old_pos)
	return function()
		insert_cards(old_stack, held_stack, old_pos)
	end
end

function stack_unresolved_return_rel_x(old_stack, held_stack)
	return function()
		stack_insert_cards(old_stack, held_stack)
		--[[
		local ins = hand_find_insert_x(old_stack, held_stack)
		insert_cards(old_stack, held_stack, ins)
		old_stack.ins_offset = nil
		]]
	end
end

-- find the i-th location to insert the held stack into the ins_stack
function hand_find_insert_x(ins_stack, held_stack)
	local cards, x2 = ins_stack.cards, held_stack.x_to
	for i = 1, #ins_stack.cards do
		if x2 < cards[i].x_to then
			return i
		end
	end
	
	return #ins_stack.cards + 1

--[[ another idea, but not needed
	local cards, x2 = ins_stack.cards, held_stack.x_to
	local min_dif, closest = 9999
	for i = 1, #ins_stack.cards do
		local d = abs(cards[i].x_to - x2)
		if d < min_dif then
			min_dif, closest = d, i
		end
	end
	-- missing check for being after the last card
	return closest
--]]
end


function stack_repose_hand(x_delta, limit)
	x_delta = x_delta or 25
	limit = limit or 200
	
	return function(stack, dx)
		local c = stack.cards[1]
		
		local lim = (limit - (c and c.width or 45)) / (#stack.cards + (stack.ins_offset and 1 or 0) - 1)
		
		--local x, xd = stack.x_to, min(x_delta, limit / (#stack.cards + (stack.ins_offset and 1 or 0)))
		local x, xd = stack.x_to, min(x_delta, lim)
		
		for i, c in pairs(stack.cards) do
		--	instead of applying an offset
		--	c.x_to = x
		--	c.x_offset_to = stack.ins_offset and stack.ins_offset <= i and xd or 0
		
			c.x_to = x + (stack.ins_offset and stack.ins_offset <= i and xd or 0)
		
			c.y_to = stack.y_to
			-- applies an additional offset to the card if hovered
			c.y_offset_to = c.hovered and -15 or 0
			x += xd
		end
	end
end

-- designed to pick up a single card
-- store_offset is primarily for the hand stack itself, for keeping the insert position when a card is picked up.
-- (normally it doesn't look right)
function unstack_hand_card(card, store_offset)
	if not card then
		return
	end
	
	-- resets the offset of the card
	card.x_offset_to = 0
	card.y_offset_to = 0
	card.hovered = false
	
	local old_stack = card.stack
	local new_stack = stack_held_new(old_stack, card)
	new_stack.old_pos = has(old_stack.cards, card)
	new_stack._unresolved = old_stack:unresolved_stack(new_stack, has(old_stack.cards, card))
	if store_offset then
		old_stack.ins_offset = new_stack.old_pos
	end
	
	-- moves card to new stack
	add(new_stack.cards, del(old_stack.cards, card))
	card.stack = new_stack
	stack_delete_check(old_stack)
	
	return new_stack
end

function hand_on_hover(self, card, held)
	
	if held then
		-- shift cards and insert held stack into cards_all order
		self.ins_offset = hand_find_insert_x(self, held)
		cards_into_stack_order(self, held, self.ins_offset)

	else
		self.ins_offset = nil
		if card then
			card.hovered = true
		end
	end
	
end

function hand_off_hover(self, card, held)
	self.ins_offset = nil
	if held then
		-- shift cards and back and put held cards back on top
		stack_to_top(held)
	end
	
	if card then
		card.hovered = nil
	end
end