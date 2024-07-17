--[[pod_format="raw",created="2024-03-18 02:31:29",modified="2024-07-17 08:02:54",revision=11202]]

-- this could use more work
-- the purpose is to allow for animated sprite buttons

-- group 2 is drawn on top of group 1
buttons_all = {
	{},
	{},
	{},
}

function button_draw_all(group)
	local buttons = buttons_all[group]
	for b in all(buttons) do
		b:draw()
	end
end

function button_destroy(button)
	if button.on_destroy then
		button:on_destroy()
	end
	
	del(buttons_all[button.group], button)
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
	local layer_hit = force_off and 0 or nil
	
	--for buttons in all(buttons_all) do
		--for b in all(buttons) do
	for i = #buttons_all, 1, -1 do
		local buttons = buttons_all[i]
		
		for j = #buttons, 1, -1 do
			local b = buttons[j]
			b.hit = allow and point_box(mx, my, b.x, b.y, b.width, b.height)
			b.highlight = b.on_click and b.hit
			allow = allow and not b.hit
		end
		
		-- find the highest layer highlighted
		if not allow and not layer_hit then
			layer_hit = i
		end
	end
	
	return layer_hit or 0
end

function button_check_click(group, interact)	
	local buttons = buttons_all[group]
	
	for j = #buttons, 1, -1 do
		local b = buttons[j]
		
		if b.enabled and b.hit
		and (b.always_active or interact) then
			if b.on_click then
				b:on_click()
			end
			return true
		end
	end
	
	return false
end

function button_new(param)
	local b = {
		x = 0, y = 0,
		width = 16, height = 16,
		--draw = param.draw,
		--on_click = param.on_click,
		hit = false,
		highlight = false,
		enabled = true,
		always_active = false,
		destroy = button_destroy,
	}
	
	param.group = param.group or 1
	local buttons = buttons_all[param.group or 1]
	if param.bottom then
		add(buttons, b, 1)
	else
		add(buttons, b)
	end
	param.bottom = nil
	
	for k,v in pairs(param) do
		b[k] = v
	end
	
	return b
end

function button_simple_text(t, x, y, on_click)
	local w, h = print_size(t)
	w += 9
	h += 4
	
	return button_new({
		x = x, y = y, 
		width = w, height = h, 
		draw = function(b)
			nine_slice(55, b.x, b.y+3, b.width, b.height)
			
			local click_y = sin(b.ct/2)*3
			nine_slice(b.highlight and 53 or 54, b.x, b.y-click_y, b.width, b.height)
			local x, y = b.x+5, b.y+3 - click_y
			print(t, x, y+1, 32)
			print(t, x, y, b.highlight and 3 or 19)
			b.ct = max(b.ct - 0.08)
		end, 
		on_click = function (b)
			b.ct = 1
			on_click(b)
		end,
		ct = 0
	})
end

function button_center(b, x)
	b.x = (x or 240) - b.width/2
end
