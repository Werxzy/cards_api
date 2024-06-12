--[[pod_format="raw",created="2024-03-18 02:31:29",modified="2024-06-12 09:40:43",revision=7363]]

-- this could use more work
-- the purpose is to allow for animated sprite buttons

buttons_all = {}

function button_draw_all()
	for i = 1,2 do
		for b in all(buttons_all) do
			b:draw(i)
		end
	end
end

function button_destroy(button)
	if button.on_destroy then
		button:on_destroy()
	end
	del(buttons_all, button)
end

function button_destroy_all()
	for b in all(buttons_all) do
		b:destroy()
	end
end

function button_check_highlight(mx, my, force_off)
	local allow = not force_off
	for b in all(buttons_all) do
		b.highlight = allow and point_box(mx, my, b.x, b.y, b.w, b.h)
	end
end

function button_check_click(interact)
--	for b in all(buttons_all) do
	for i = #buttons_all, 1, -1 do
		local b = buttons_all[i]
		
		if b.enabled and b.highlight 
		and (b.always_active or interact) then
			if b.on_click then
				b:on_click()
			end
			return true
		end
	end
end

function button_new(x, y, w, h, draw, on_click)
	return add(buttons_all, {
		x = x, y = y,
		w = w, h = h,
		draw = draw,
		on_click = on_click,
		highlight = false,
		enabled = true,
		always_active = false,
		destroy = button_destroy
	})
end

function button_simple_text(t, x, y, on_click)
	local w, h = print_size(t)
	w += 9
	h += 4
	
	local bn = button_new(x, y, w, h, 
		function(b, layer)
			if layer == 1 then
				nine_slice(55, b.x, b.y+3, b.w, b.h)
				
			elseif layer == 2 then
				local click_y = sin(b.ct/2)*3
				nine_slice(b.highlight and 53 or 54, b.x, b.y-click_y, b.w, b.h)
				local x, y = b.x+5, b.y+3 - click_y
				print(t, x, y+1, 32)
				print(t, x, y, b.highlight and 3 or 19)
				b.ct = max(b.ct - 0.08)
			end
		end, 
		function (b)
			b.ct = 1
			on_click(b)
		end)
	bn.ct = 0
	
	return bn
end

function button_center(b, x)
	b.x = (x or 240) - b.w/2
end

local empty_target = userdata("u8", 1, 1)

function print_size(t)
	local old = get_draw_target()
	set_draw_target(empty_target)
	
	local w, h = print(t, 0, -1000)
	
	set_draw_target(old)	

	return w, h + 1000
end

function nine_slice(sprite, x, y, w, h, fillcol)
	-- expects a 16x16 sprite
	local sp_size = 16
	local smax = sp_size\2 -- size \ 2
	
	-- calculate width for each component
	local w1 = min(smax, w\2)
	local w3 = min(smax, w - w1)\1
	local w2 = w - w3 - w1
	
	-- calculate height of each component
	local h1 = min(smax, h\2)
	local h3 = min(smax, h - h1)\1
	local h2 = h - h3 - h1
	
	-- top (then left, middle, right)
	sspr(sprite, 0,0, w1,h1, x,y)
	if(w2 >= 1) sspr(sprite, smax,0, 1,h1, x+w1,y, w2,h1)
	sspr(sprite, sp_size-w3,0, w3,h1, x+w1+w2,y)

	-- middle
	if h2 >= 1 then
		sspr(sprite, 0,smax, w1,1, x,y+h1, w1,h2) -- top left corner
		
		if w2 >= 1 then 
			if fillcol then
				rectfill(x+w1,y+h1, x+w1+w2-1,y+h1+h2-1, fillcol)
			else
				sspr(sprite, smax,smax, 1,1, x+w1,y+h1, w2,h2)
			end
		end
		
		sspr(sprite, sp_size-w3,smax, w3,1, x+w1+w2,y+h1, w3,h2)
	end	

	-- bottom
	sspr(sprite, 0,sp_size-h3, w1,h3, x,y+h1+h2) -- top left corner
	if(w2 >= 1) sspr(sprite, smax,sp_size-h3, 1,h3, x+w1,y+h1+h2, w2,h3)
	sspr(sprite, sp_size-w3,sp_size-h3, w3,h3, x+w1+w2,y+h1+h2)
end