--[[pod_format="raw",created="2024-03-18 02:31:29",modified="2024-06-19 12:25:10",revision=9285]]

-- this could use more work
-- the purpose is to allow for animated sprite buttons

-- group 2 is drawn on top of group 1
buttons_all = {
	{},
	{},
}

function button_draw_all(group)
	local buttons = buttons_all[group]
	for i = 1,2 do
		for b in all(buttons) do
			b:draw(i)
		end
	end
end

function button_destroy(button)
	if button.on_destroy then
		button:on_destroy()
	end
	for b in all(buttons_all) do
		del(b, button)
	end
end

function button_destroy_all()
	for buttons in all(buttons_all) do
		for b in all(buttons) do
			b:destroy()
		end
	end
end

function button_check_highlight(mx, my, force_off)
	local allow = not force_off
	
	for buttons in all(buttons_all) do
		for b in all(buttons) do
			b.highlight = b.on_click and allow and point_box(mx, my, b.x, b.y, b.w, b.h)
		end
	end
end

function button_check_click(group, interact)	
	local buttons = buttons_all[group]
	
	for j = #buttons, 1, -1 do
		local b = buttons[j]
		
		if b.enabled and b.highlight 
		and (b.always_active or interact) then
			if b.on_click then
				b:on_click()
			end
			return true
		end
	end
end

--function button_new(x, y, w, h, draw, on_click, layer)
function button_new(param)
	local buttons = buttons_all[param.group or 1]
	local b = {
		x = param.x, y = param.y,
		w = param.w, h = param.h,
		draw = param.draw,
		on_click = param.on_click,
		highlight = false,
		enabled = true,
		always_active = false,
		destroy = button_destroy
	}
	
	if param.bottom then
		add(buttons, b, 1)
	else
		add(buttons, b)
	end
	
	return b
end

function button_simple_text(t, x, y, on_click)
	local w, h = print_size(t)
	w += 9
	h += 4
	
	local bn = button_new({
		x = x, y = y, w = w, h = h, 
		draw = function(b, layer)
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
		on_click = function (b)
			b.ct = 1
			on_click(b)
		end
	})
	bn.ct = 0
	
	return bn
end

function button_center(b, x)
	b.x = (x or 240) - b.w/2
end
