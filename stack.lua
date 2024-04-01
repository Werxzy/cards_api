--[[pod_format="raw",created="2024-03-16 15:18:21",modified="2024-03-31 23:40:02",revision=12076]]

stacks_all = {}
stack_border = 3

--[[
Stacks are essentially tables containing cards.
Each stack has a set of rules for how cards interact with it.

sprites = table of sprite ids or userdata to be drawn with sspr
x,y = top left position of stack
repos = function called when changing the target position of the cards
perm = if the stack is removed when there is no more cards
stack_rule = function called when another stack of cards is placed on top (with restrictions)
on_click = function called when stack base or card in stack is clicked
on_double = function caled when stack base or card in stack is double clicked
resolve_stack = called when can_stack returns true
]]

function stack_new(sprites, x, y, repos, perm, stack_rule, on_click, on_double)
	return add(stacks_all, {
		sprites = type(sprites) == "table" and sprites or {sprites},
		x_to = x,
		y_to = y,
		cards = {},
		perm = perm,
		reposition = repos or stack_repose_normal(),
		can_stack = stack_rule or stack_cant,
		on_click = on_click or stack_cant,
		on_double = on_double,
		resolve_stack = stack_cards
		})
end

-- drawing function for stacks
-- always drawn below cards
function stack_draw(s)
	if s.perm then
		local x, y = s.x_to - stack_border, s.y_to - stack_border
		for sp in all(s.sprites) do
			spr(sp, x, y)
		end
	end
end

-- Places cards from stack2 to onto stack
function stack_cards(stack, stack2)
	for c in all(stack2.cards) do
		add(stack.cards, del(stack2.cards, c))
		card_to_top(c)
		c.stack = stack
	end
	stack2.old_stack = nil
	if not stack2.perm then
		del(stacks_all, stack2)
	end
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
			
			held_stack = unstack_cards(card)
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
	
	local new_stack = stack_new(nil, 0, 0, stack_repose_normal(10), false, stack_cant, stack_cant)
	new_stack.old_stack = old_stack

	local i = has(old_stack.cards, card)
	while #old_stack.cards >= i do
		local c = add(new_stack.cards, deli(old_stack.cards, i))
		card_to_top(c) -- puts cards on top of all the others
		c.stack = new_stack
	end
	
	if #old_stack.cards == 0 and not old_stack.perm then
		del(stacks_all, old_stack)
	end	
	
	return new_stack
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

-- adds a card to the top of a stack
-- if an old stack is given, the card is removed from that table/stack instead
function stack_add_card(stack, card, old_stack)
	if card then
		card_to_top(card)
		
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
	end
end

-- move all cards from "..." (stacks or table of stacks) to "stack_to" 
function stack_collecting_anim(stack_to, ...)
	local function collect(s)
		while #s.cards > 0 do
			local c = get_top_card(s)
			stack_add_card(stack_to, c)
			c.a_to = 0.5
			pause_frames(3)
		end
	end
	
	for a in all{...} do
		if type(a) == "table" then
			if a.cards then -- single stack	
				collect(a)
				
			else -- table of stacks	
				foreach(a, collect)	
			end
		end
	end
	
	pause_frames(35)

	stack_shuffle_anim(stack_to)
	stack_shuffle_anim(stack_to)
	stack_shuffle_anim(stack_to)
end

-- animation for physically shuffle the cards
function stack_shuffle_anim(stack)
	local temp_stack = stack_new(
		nil, stack.x_to + card_width + 4, stack.y_to, 
		stack_repose_static(-0.16), 
		false, stack_cant, stack_cant)
		
	for i = 1, rnd(10)-5 + #stack.cards/2 do
		stack_add_card(temp_stack, get_top_card(stack))
	end
	
	pause_frames(30)
	
	for c in all(temp_stack.cards) do
		stack_add_card(stack, c, rnd(#stack.cards+1)\1+1)
	end
	
	del(stacks_all, temp_stack)
	
	-- secretly randomize cards a bit
	local c = #stack.cards
	if c > 1 then -- must have more than 1 card to swap
		for i = 1,rnd(2)+9 do
			local i, j = 1, 1
			while i == j do -- guarantee cards are different
				 i, j = rnd(c)\1 + 1, rnd(c)\1 + 1
			end
			stack_quick_swap(stack,i,j) 
		end
	end
	
	stack_update_card_order(stack)
	
	pause_frames(20)
end

-- swaps two cards instantly with no animation
-- will need to call stack_update_card_order to fix the draw order
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

-- if the draw order of cards in a stack need to be updated
function stack_update_card_order(stack)
	for c in all(stack.cards) do
		card_to_top(c)
	end
end