--[[pod_format="raw",created="2024-03-16 15:34:19",modified="2024-04-01 00:45:54",revision=12966]]

include"cards_api/util.lua"
include"cards_api/stack.lua"
include"cards_api/card.lua"
include"cards_api/button.lua"

--suite_save_folder = "/appdata/solitaire_suite"

mouse_last = 0
mouse_last_click = time() - 100
mouse_last_clicked = nil

cards_coroutine = nil

-- main drawing function
function cards_api_draw()
	if card_back.update then
		local upd = card_back_last ~= card_back
		
		if not upd then
			local sp = card_back.sprite
			sp = type(sp) == "number" and get_spr(sp) or sp
			
			-- if card size changed
			upd = sp:width() ~= card_width and sp:height() ~= card_height
		end
		
		card_back.update(upd)
	end
	card_back_last = card_back
	
	if(game_draw) game_draw(0)
	
	foreach(stacks_all, stack_draw)
	
	for b in all(buttons_all) do
		b:draw()
	end
	
	if(game_draw) game_draw(1)
		
	foreach(cards_all, card_draw)
	
	if(game_draw) game_draw(2)
end

-- main update function
function cards_api_update()
	
	-- don't accept mouse input when there is a coroutine
	-- though, coroutines are a bit annoying to debug
	if cards_coroutine then
		coresume(cards_coroutine)
		cards_api_mouse_update(false)
		if not cards_coroutine or costatus(cards_coroutine) == "dead" then
			cards_coroutine = nil
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
	
	function buttons_click() 
		for b in all(buttons_all) do
			if b.enabled and b.highlight 
			and (b.always_active or interact) then
				b:on_click()
				clicked = true
				break
			end
		end
	end
	
	for b in all(buttons_all) do
		b.highlight = not held_stack and point_box(mx, my, b.x, b.y, b.w, b.h)
	end
		
	if interact then
		if mouse_down&1 == 1 and not held_stack then
			
			if not cards_frozen then
				for i = #cards_all, 1, -1 do
					local c = cards_all[i]
					if point_box(mx, my, c.x(), c.y(), card_width, card_height) then
						
						if double_click 
						and mouse_last_clicked == c
						and c.stack.on_double then
							c.stack.on_double(c)
							mouse_last_clicked = nil
						else
							c.stack.on_click(c)
							mouse_last_clicked = c
						end
						clicked = true
						break
					end
				end
			end
			
			if not clicked then
				buttons_click() 
			end
			
			if not clicked and not cards_frozen then
				for s in all(stacks_all) do
					if point_box(mx, my, s.x_to, s.y_to, card_width, card_height) then
					
						if time() - mouse_last_click < 0.5 
						and mouse_last_clicked == s 
						and s.on_double then
							s.on_double()
							mouse_last_clicked = nil
						else
							s.on_click()
							mouse_last_clicked = s
						end
						clicked = true
						break
					end
				end
			end
			
			if clicked then
				cards_api_action_resolved()
			end
		end
		
		if mouse_up&1 == 1 and held_stack then
			local dist_to_stack, stack_to = 9999
			
			--find closest stack that s:can_stack returns true
			for s in all(stacks_all) do
				local y = stack_y_pos(s)
				if s ~= held_stack and s:can_stack(held_stack) 
				and point_box(
				held_stack.x_to + card_width/2, 
				held_stack.y_to + card_height/2, 
				s.x_to - card_width * 0.25, y - card_height * 0.125, 
				card_width * 1.5, card_height * 1.25) then
					
					-- TODO: update this range based on the stack and card size
					-- (mostly when they can be controlled individually)	
			
					local d = abs(held_stack.x_to - s.x_to)
						+ abs(held_stack.y_to - y)
						
					if d < dist_to_stack then
						dist_to_stack, stack_to = d, s
					end
				end
			end
			
			if stack_to then -- closest valid stack found, drop stack on top
				stack_to:resolve_stack(held_stack)
				held_stack = nil
			end
			
			if held_stack ~= nil then
				stack_cards(held_stack.old_stack, held_stack)
				held_stack = nil
			end
			cards_api_action_resolved()
		end
		
		if held_stack then
			held_stack.x_to = mx - card_width/2
			held_stack.y_to = my - card_height/2
		end
		
	else		
		if mouse_down&1 == 1 and not held_stack then
			buttons_click()
		end
	end

	if mouse_down&1 == 1 then
		mouse_last_click = time(s)
	end
	mouse_last = md
end

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
	buttons_all = {}
	
	cards_coroutine = nil
	cards_frozen = false
	
	if not keep_func then
		game_update = nil
		game_draw = nil
		game_action_resolved = nil
		game_win_condition = nil
	end
end

function cards_api_shadows_enable(enable)
	
	if cards_shadows_enabled ~= enable then
		cards_shadows_enabled = enable
		
		if enable then
		--	poke(0x5508, 0xff) -- read
		--	poke(0x550a, 0xff) -- target sprite
			poke(0x550b, 0xff) -- target shapes
			
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
			poke(0x550b, 0x3f) -- target shapes
			-- todo, reset color table (probably not necessary
		end
	end
	
end