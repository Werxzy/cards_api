--[[pod_format="raw",created="2024-03-16 15:34:19",modified="2024-07-03 21:58:52",revision=22247]]

include"cards_api/util.lua"
include"cards_api/stack.lua"
include"cards_api/card.lua"
include"cards_api/button.lua"

--suite_save_folder = "/appdata/solitaire_suite"

mouse_last = 0
mouse_last_click = time() - 100
mouse_last_clicked = nil

hover_last = nil

local cards_coroutine = {}

-- main drawing function
function cards_api_draw()
	card_back_animated_update()
	
	card_back_last = card_back
	
	if(game_draw) game_draw(0)
	
	foreach(stacks_all, stack_draw)
	button_draw_all(1)
	
	if(game_draw) game_draw(1)
		
	foreach(cards_all, card_draw)
	
	if(game_draw) game_draw(2)
	
	button_draw_all(2)
	
	if(game_draw) game_draw(3)
	
	button_draw_all(3)
	
	if(game_draw) game_draw(4)
end

-- main update function
function cards_api_update()
	
	-- don't accept mouse input when there is a coroutine
	-- though, coroutines are a bit annoying to debug
	if #cards_coroutine > 0 then
		local i = 1
		while i <= #cards_coroutine do
			local c = cards_coroutine[i]
			
			if(c[3] and i~=1) break -- wait if not first
			
			-- run coroutine
			local co = c[1]
			assert(coresume(co)) -- TODO, make this error be presented betters
			if not co or costatus(co) == "dead" then -- exit coroutine
				deli(cards_coroutine, i)
			end
			
			if(c[2]) break -- stop
			i += 1
		end

		cards_api_mouse_update(false)
		if #cards_coroutine == 0 then
			cards_api_action_resolved()
		end
		
		
	else
		cards_api_mouse_update(true)
	end

	for s in all(stacks_all) do
		s:reposition()
	end
	foreach(cards_all, card_update)	
	
	if(game_update) game_update()
end

-- updates mouse interactions
-- not meant to be called outside
function cards_api_mouse_update(interact)
	local mx, my, md = mouse()
	local mouse_down = md & ~mouse_last
	local mouse_up = ~md & mouse_last
	local double_click = time() - mouse_last_click < 0.3	
	local clicked = false
	
	-- fix mouse interaction based on camera
	local cx, cy = camera()
	camera(cx, cy)
	mx += cx
	my += cy
		
	local layer_hit = button_check_highlight(mx, my, held_stack)
		
	if interact then
	
		-- check what is being hovered over this frame
		local hover_new = nil
		
		if not cards_frozen then 
			if held_stack then
				-- find closest card
				local dist = 99999
				for i = #cards_all, 1, -1 do
				
					local c = cards_all[i]
					if c.stack != held_stack then
					
						local d = card_overlaps_card(c, held_stack.cards[1]) 	
						if d and d < dist then
							dist, hover_new = d, c
						end
					end
				end
				
				-- if no closest card, find closest overlapping stack
				if not hover_new then
					for s in all(stacks_all) do
						if s != held_stack then
						
							local d = held_overlaps_stack(held_stack, s)
							if d and d < dist then
								dist, hover_new = d, s					
							end
						end
					end
				end


			else -- find what card the cursor is over
				for i = #cards_all, 1, -1 do
					local c = cards_all[i]
					if point_box(mx, my, c.x(), c.y(), c.width, c.height) then
						hover_new = c
						break
					end
				end
				
				-- check stacks instead
				if not hover_new then
					for s in all(stacks_all) do
						if point_box(mx, my, s.x_to, s.y_to, s.width, s.height) then
							hover_new = s
							break
						end
					end
				end
			end	
		end
		
		-- if a button is highlighted, then the cards below should not be hovered
		if layer_hit >= 2 then
			hover_new = nil
		end
		
		-- update on what has been hovered
		if hover_last != hover_new then
			--notify(tostr(hover_new) .. " " .. (hover_new and hover_new.ty or " "))
			
			if hover_last then
				cards_api_hover_event(hover_last, false)
			end
			if hover_new then
				cards_api_hover_event(hover_new, true, true)
			end
						
		elseif hover_last then
			cards_api_hover_event(hover_last, true)
		end
		
		hover_last = hover_new
		
	
		-- on mouse press and no held stack
		if mouse_down&1 == 1 and not held_stack then
			if not clicked then
				clicked = button_check_click(3, interact)
			end
			
			if not clicked then
				clicked = button_check_click(2, interact)
			end	
	
			if not clicked
			and not cards_frozen 
			and hover_last 
			and hover_last.ty == "card" then	
				
				if double_click 
				and mouse_last_clicked == hover_last
				and hover_last.stack.on_double then
					hover_last.stack.on_double(hover_last)
					mouse_last_clicked = nil
					
				else
					hover_last.stack.on_click(hover_last)
					mouse_last_clicked = hover_last
				end

				clicked = true
			end
			
			if not clicked then
				clicked = button_check_click(1, interact)
			end
			
			if not clicked 
			and not cards_frozen 
			and hover_last
			and hover_last.ty == "stack" then
			
				if time() - mouse_last_click < 0.5 
				and mouse_last_clicked == hover_last 
				and hover_last.on_double then
					hover_last.on_double()
					mouse_last_clicked = nil
					
				else
					hover_last.on_click()
					mouse_last_clicked = hover_last
				end
				clicked = true
			end
			
			if clicked then
				cards_api_action_resolved()
			end
		end
		
		-- mouse release and holding stack
		if mouse_up&1 == 1 and held_stack then
			--[[
			local dist_to_stack, stack_to = 9999
			--TODO? instead use hover_last, though it can contain cards, though this can be fine?
			
			--find closest stack that s:can_stack returns true
			for s in all(stacks_all) do
				if s ~= held_stack 
				and s:can_stack(held_stack) then
					local d = held_overlaps_stack(held_stack, s)
					if d and d < dist_to_stack then
						dist_to_stack, stack_to = d, s
					end
				end
			end
			
			if stack_to then -- closest valid stack found, drop stack on top
				stack_to:resolve_stack(held_stack)
				held_stack = nil
			end
			
			]]
			
			if hover_last then
				local s, c = nil
				if hover_last.ty == "stack" then
					s = hover_last
				elseif hover_last.ty == "card" then
					s, c = hover_last.stack, hover_last
				end
				
				if s and s:can_stack(held_stack, c) then
					s:resolve_stack(held_stack, c)
					held_stack = nil
				end
			end
			
			-- when a held stack hasn't been placed anywhere
			if held_stack then
				-- todo? allows for holding onto a stack that can't be returned
				-- will need to check if a stack is held when clicking
				-- which could just use the same release stack check
				
				-- if not func() then
				-- 		held_stack = nil
				-- end
				
				
				stack_apply_unresolved(held_stack)
				held_stack = nil
			end
			cards_api_action_resolved()
		end
		
		if held_stack then
			--held_stack.x_to = mx - c.width/2
			--held_stack.y_to = my - c.height/2
			held_stack.x_to += mx - mlx
			held_stack.y_to += my - mly
		end
		
	else -- not interact	
		if mouse_down&1 == 1 and not held_stack then
			if not clicked then
				clicked = button_check_click(3)
			end
			if not clicked then
				clicked = button_check_click(2)
			end
			if not clicked then
				clicked = button_check_click(1)
			end
		end
		
		highlighted_last = nil
	end

	if mouse_down&1 == 1 then
		mouse_last_click = time(s)
	end
	mouse_last = md
	mlx, mly = mx, my
end
mlx, mly = 0, 0

-- when an action is resolved, call the game's reaction function and check win condition
function cards_api_action_resolved()

	if(game_action_resolved) game_action_resolved()
	
	-- check if win condition is met
	if not cards_frozen and game_win_condition and game_win_condition() then
		if game_count_win then
			game_count_win()
			cards_frozen = true
		end
	end
end

-- co is a coroutine to run
-- stop waits for this coroutine to finish before running the next one
-- wait prevents the coroutine from running unless it's the first
function cards_api_coroutine_add(co, stop, wait)
	if type(co) == "function" then
		co = cocreate(co)
	end
	assert(type(co) == "thread", "The first parameter must be a coroutine or function")
	add(cards_coroutine, {co, stop == nil or stop, wait})
end

function cards_api_coroutine_clear()
	cards_coroutine = {}
end


-- allows card interaction
-- may have more uses in the future
function cards_api_game_started()
	 cards_frozen = false
end

-- clears any objects being stored
function cards_api_clear(keep_func)
	-- removes recursive connection between cards to safely remove them from memory
	-- at least I believe this is needed
	for c in all(cards_all) do
		c.stack = nil
	end
	
	cards_all = {}
	stacks_all = {}
	button_destroy_all()
	
	cards_api_coroutine_clear()
	cards_frozen = false
	
	if not keep_func then
		game_update = nil
		game_draw = nil
		game_action_resolved = nil
		game_win_condition = nil
	end
end

function cards_api_shadows_enable(enable, remap)
	
	cards_shadows_enabled = enable
	remap = remap or {0,1,21,19,20,21,22,6,24,25,9,27,16,18,13,31,1,16,2,1,21,1,5,14,2,4,11,3,12,13,2,4}

	if enable then
		poke(0x550b, 0x3f) -- target shapes
		
		-- shadow mask color
		for i, b in pairs(remap) do
			-- bit 0x40 is to change the table color to prevent writing onto shaded areas
			-- kinda like some of the old shadow techniques in 3d games
			poke(0x8000 + 32*64 + i-1, 0x40|b)
		end
		
	else
		poke(0x550b, 0x0) -- target shapes

		-- resets the colors
		for i, b in pairs(remap) do
			poke(0x8000 + 32*64 + i-1, 32)
		end
	end


	--[[ old version (no idea what is actually needed)
	if cards_shadows_enabled ~= enable then
		cards_shadows_enabled = enable
		
		if enable then
		--	poke(0x5508, 0xff) -- read
		--	poke(0x550a, 0xff) -- target sprite
			poke(0x550b, 0x3f) -- target shapes
			
			-- shadow mask color
			for i, b in pairs{0,1,21,19,20,21,22,6,24,25,9,27,16,18,13,31,1,16,2,1,21,1,5,14,2,4,11,3,12,13,2,4} do
				-- bit 0x40 is to change the table color to prevent writing onto shaded areas
				-- kinda like some of the old shadow techniques in 3d games
				poke(0x8000 + 32*64 + i-1, 0x40|b)
			end
			-- poke(0x5509, 0xff) -- enable writing new color table
			-- draw shadow
			-- poke(0x5509, 0x3f) -- disable
		
		else
		--	poke(0x5508, 0x3f) -- read
		--	poke(0x550a, 0x3f) -- target sprite
		--	poke(0x550b, 0x3f) -- target shapes
			-- todo, reset color table (probably not necessary
		end
	end
	]]
end

-- returns a distance to the stack if they overlap
function held_overlaps_stack(h, s)
	local y = stack_y_pos(s)
	local c = h.cards[1] -- expects there to be a card in the held stack
	
	if point_box(
		-- point
		h.x_to + c.width/2, 
		h.y_to + c.height/2,
		-- overlaps box (top left corner)
		s.x_to - s.width*0.25, 
		y - s.height*0.125, 
		-- box size (extended)
		s.width*1.5, s.height*1.25) then
		
		return abs(h.x_to - s.x_to) + abs(h.y_to - y)
	end
end

function card_overlaps_card(a, b)
	if point_box(
		-- point
		a.x_to + a.width/2, 
		a.y_to + a.height/2,
		-- overlaps box (top left corner) 
		b.x_to - b.width * 0.25, 
		b.y_to - b.height * 0.125,
		-- box size (extended) 
		b.width * 1.5, b.height * 1.25) then
		
		return abs(a.x_to - b.x_to) + abs(a.y_to - b.y_to)
	end
end

-- st = stack or card being hovered
-- hovering = true if it's being hovered over
-- first_frame = true if it's the first frame being hovered
function cards_api_hover_event(st, hovering, first_frame)
	local c = nil	

	if st.ty == "card" then -- card is specifically being hovered over
		st, c = st.stack, st
	
	elseif st.ty == "stack" then -- stack is hovered over
		-- st already is the stack
	else
		return -- invalid object somehow
	end
	
	if st then
		if hovering then
			if st.on_hover then -- stack is hovered and has a response
				st:on_hover(c, held_stack)  -- stack, card, held stack
			end
		elseif st.off_hover then
			st:off_hover(c, held_stack)
		end
	end
end