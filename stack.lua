--[[pod_format="raw",created="2024-03-16 15:18:21",modified="2024-06-03 23:26:14",revision=13978]]

stacks_all = {}
stack_border = 3

--[[
Stacks are essentially tables containing cards.
Each stack has a set of rules for how cards interact with it.

sprites = table of sprite ids or userdata to be drawn with sspr
x,y = top left position of stack
reposition = function called when changing the target position of the cards
perm = if the stack is removed when there is no more cards
can_stack = function called when another stack of cards is placed on top (with restrictions)
on_click = function called when stack base or card in stack is clicked
on_double = function caled when stack base or card in stack is double clicked
resolve_stack = called when can_stack returns true
]]

function stack_new(sprites, x, y, param)

	local s = {
		ty = "stack",
		sprites = type(sprites) == "table" and sprites or {sprites},
		x_to = x,
		y_to = y,
		cards = {},
		perm = true,
		reposition = stack_repose_normal(),
		can_stack = stack_cant,
		on_click = stack_cant,
		on_double = on_double,
		resolve_stack = stack_cards,
		unresolved_stack = stack_unresolved_return,
		-- on_hover = ... function(self, card, held_stack)
		-- off_hover = ... function(self, card, held_stack)
		
	}	
	
	for k,v in pairs(param) do
		s[k] = v
	end

	return add(stacks_all, s)
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

function stack_to_top(stack)
	foreach(stack.cards, card_to_top)
	--for c in all(stack2.cards) do
	--	card_to_top(c)
	--end
end

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
	local new_stack = stack_held_new(old_stack, card)
	new_stack._unresolved = old_stack:unresolved_stack(new_stack)

	local i = has(old_stack.cards, card)
	while #old_stack.cards >= i do
		local c = add(new_stack.cards, deli(old_stack.cards, i))
		card_to_top(c) -- puts cards on top of all the others
		c.stack = new_stack
	end
	
	stack_delete_check(old_stack)
	
	return new_stack
end

function stack_held_new(old_stack, card)
	local st = stack_new(
		nil,
		card.x_to, card.y_to,
--		old_stack.x_to, old_stack.y_to, 
--		0, 0, 
		{
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
		del(stacks_all, stack)
	end	
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
			--sfx(3)
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

function stack_unresolved_return(old_stack, held_stack)
	return function()
		stack_cards(old_stack, held_stack)
	end
end


-- hand specific event functions

function stack_unresolved_return_insert(old_stack, held_stack, old_pos)
	return function()
		insert_cards(old_stack, held_stack, old_pos)
	end
end

function stack_unresolved_return_rel_x(old_stack, held_stack)
	return function()
		local ins = hand_find_insert_x(old_stack, held_stack)
		insert_cards(old_stack, held_stack, ins)
		old_stack.ins_offset = nil
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
	limit = limit or 140
	
	return function(stack, dx)
		local x, xd = stack.x_to, min(x_delta, limit / (#stack.cards + (stack.ins_offset and 1 or 0)))
		for i, c in pairs(stack.cards) do
		--	instead
		--	c.x_to = x
		--	c.x_offset_to = stack.ins_offset and stack.ins_offset <= i and xd or 0
		
			c.x_to = x + (stack.ins_offset and stack.ins_offset <= i and xd or 0)
		
			c.y_to = stack.y_to
			c.y_offset_to = c.hovered and -15 or 0
			x += xd
		end
	end
end

-- designed to pick up a single card
function unstack_hand_card(card)
	if not card then
		return
	end
	
	-- TODO? would rather not have to do this
	card.x_offset_to = 0
	card.y_offset_to = 0
	card.hovered = false
	
	local old_stack = card.stack
	local new_stack = stack_held_new(old_stack, card)
	new_stack.old_pos = has(old_stack.cards, card)
	new_stack._unresolved = old_stack:unresolved_stack(new_stack, has(old_stack.cards, card))
	old_stack.ins_offset = new_stack.old_pos
	
	-- moves card to new stack
	add(new_stack.cards, del(old_stack.cards, card))
	card.stack = new_stack
	stack_delete_check(old_stack)
	
	held_stack = new_stack
	--return new_stack
end

function hand_on_hover(self, card, held)
	
	if held then
		-- shift cards and insert held stack into cards_all order
		self.ins_offset = hand_find_insert_x(self, held)
		--self.ins_offset = has(self.cards, card) -- something like this??
		cards_into_stack_order(self, held, self.ins_offset)

	else
		self.ins_offset = nil
		if card then
			card.hovered = true
		end
	end
	
end

function hand_off_hover(self, card, held)
	if held then
		-- shift cards and back and put held cards back on top
		self.ins_offset = nil
		stack_update_card_order(held)
	end
	
	if card then
		card.hovered = nil
	end
end