--[[pod_format="raw",created="2024-03-18 02:31:29",modified="2024-06-17 11:32:14",revision=8712]]

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
		b.highlight = b.on_click and allow and point_box(mx, my, b.x, b.y, b.w, b.h)
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
