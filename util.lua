--[[pod_format="raw",created="2024-03-26 04:14:49",modified="2024-07-17 08:48:22",revision=4048]]
-- returns the key of a searched value inside a table
-- such that tab[has(tab, val)] == val
function has(tab, val)
	for k,v in pairs(tab) do
		if v == val then
			return k
		end
	end
end

-- returns the key of a searched value inside a table
-- such that tab[has(tab, key, val)][key] == val
function has_key(tab, key, val)
	for k,v in pairs(tab) do
		if v[key] == val then
			return v, k 
		end
	end
end

-- aabb point to box collision
function point_box(x1, y1, x2, y2, w, h)
	x1 -= x2
	y1 -= y2
	return x1 >= 0 and y1 >= 0 and x1 < w and y1 < h 
end 

-- you know what this is
function lerp(a, b, t)
	return a + (b-a) * t
end


-- yields a certain number of times
-- may need to be updated in case low battery mode causes halved update rate
function pause_frames(n)
	for i = 1,n do
		yield()
	end
end

-- maybe stuff these into userdata to evaluate all at once?
-- Returns a function that tracks a value as a position connected to a spring
-- pos - initial position
-- damp - dampening value, 0-1, reduces velocity each use
-- acc - acc, 0-1, acceleration value
-- lim - limit distance, that if position reachest the target
--
-- x = smooth-val(0, 0.9, 0.2)
-- x() -- returns current value
-- x(1) -- moves the value towards the parameter
-- x("pos", 2) -- sets the value
-- x("vel") -- returns velocity
-- x("vel", 2) -- sets the velocity
function smooth_val(pos, damp, acc, lim)
	lim = lim or 0.1
	local vel = 0
	return function(to, set)
		if to == "vel" then
			if set then
				vel = set
				return
			end
			return vel
			
		elseif to == "pos" then
			if set then
				pos = set
				return
			end
			return pos -- not necessary, but for consistency
		end
		
		if to then
			local dif = (to - pos) * acc
			vel += dif
			vel *= damp
			pos += vel
			--if abs(vel) < lim and abs(dif) < lim then
			if vel < lim and vel > -lim and dif < lim and dif > -lim then
				pos, vel = to, 0
			end
		end
		return pos
	end
end

-- same as smooth_val, but isntead for angles
-- tries to approach the target angle from the closest direction
function smooth_angle(pos, damp, acc)
	local vel = 0
	return function(to, set)
		if to == "vel" then
			if set then
				vel = set
				return
			end
			return vel
			
		elseif to == "pos" then
			if set then
				pos = set
				return
			end
			return pos -- not necessary, but for consistency
		end
		
		if to then
			local dif = ((to - pos + 0.5) % 1 - 0.5) * acc
			vel += dif
			vel *= damp
			pos += vel
			if abs(vel) < 0.0006 and abs(dif) < 0.007 then
				pos, vel = to, 0
			end
		end
		return pos
	end
end

-- sorts the table (in place), with a given key
function quicksort(tab, key)
	local function qs(a, lo, hi)
		if lo >= hi or lo < 1 then
			return
		end
			    
		-- find pivot
		local lo2, hi2 = lo, hi
		local pivot, p = a[hi2], lo2-1
		for j = lo2,hi2-1 do
			if a[j][key] <= pivot[key] then
				p += 1
				a[j], a[p] = a[p], a[j]
			end
		end
		p += 1
		a[hi2], a[p] = a[p], a[hi2]
		    
		-- quicksort next step
		qs(a, lo, p-1)
		qs(a, p+1, hi)
	end
    qs(tab, 1, #tab)
end

local empty_target = userdata("u8", 1, 1)

-- returns the size of the text
-- safe to use anywhere, even during init()
function print_size(s)
	local old = get_draw_target()
	set_draw_target(empty_target)
	
	local w, h = print(s, 0, 0)
	
	set_draw_target(old)	

	return w, h
end

-- cuts off the text and adds "..." so that the text is limited to a given pixel width
function print_cutoff(s, lim)
	local old = get_draw_target()
	set_draw_target(empty_target)
	
	local w = print(s, 0, 0)
	while w > lim do
		s = sub(s, 1, #s-4) .. "..."
		w = print(s, 0, 0)
	end

	set_draw_target(old)	

	return s, w
end

-- THE NORMAL PRINT WRAPPING CANNOT BE TRUSTED
-- wraps text to be limited to a given pixel width
function print_wrap_prep(s, width)
	local words = split(s, " ", false)
	local lines = {}
	local current_line = ""
	local final_w = 0
	
	for w in all(words) do
		local c2 = current_line == "" and w or current_line .. " " .. w
		local x = print_size(c2)
		if x > width then
			current_line = current_line .. "\n" .. w
		else
			current_line = c2
			final_w = max(final_w, x)
		end
	end
	local _, final_h = print_size(current_line)
	
	return current_line, final_w, final_h
end

-- prints the string with a shadow
function double_print(s, x, y, c)
	print(s, x+1, y+1, 6)
	print(s, x, y, c)
end

-- traverses all folders inside a starting folder
-- does not include itself
function folder_traversal(start_dir)

	local current_dir = start_dir
	local prev_folder = nil
	
	function exit_dir()
		current_dir, prev_folder = current_dir:dirname(), current_dir:basename()
	end
	
	return function(cmd, a)
		if cmd then
			if cmd == "exit" then -- exits current directory early
				exit_dir()
			elseif cmd == "find" then -- returns true if a specific file is found
				local l = ls(current_dir)
				if(l) return has(l, a)
			end
			
			return 
		end
		
		if not prev_folder then
			prev_folder = ""
			return current_dir
		end
		
		while #current_dir >= #start_dir do			
			local list = ls(current_dir)
			if list then
				for i, f in next, list, has(list, prev_folder) do
					if not f:ext() then -- folder
						current_dir ..= "/" .. f
						return current_dir
					end
				end
			end
			
			exit_dir()
		end
	end
end


-- draws a sprite with nineslice style
-- if fillcol is a number, then rectfill will be called instead (cheaper)
-- if fillcol is false, then nothing will be drawn in the center 
function nine_slice(sprite, x, y, w, h, fillcol)
	sprite = type(sprite) == "number" and get_spr(sprite) or sprite
	local sp_w, sp_h = sprite:width(), sprite:height()
	local s_max_w, s_max_h = sp_w\2, sp_h\2 -- size \ 2
	
	-- calculate width for each component
	local w1 = min(s_max_w, w\2)
	local w3 = min(s_max_w, w - w1)\1
	local w2 = w - w3 - w1
	
	-- calculate height of each component
	local h1 = min(s_max_h, h\2)
	local h3 = min(s_max_h, h - h1)\1
	local h2 = h - h3 - h1
	
	-- top (then left, middle, right)
	sspr(sprite, 0,0, w1,h1, x,y)
	if(w2 >= 1) sspr(sprite, s_max_w,0, 1,h1, x+w1,y, w2,h1)
	sspr(sprite, sp_w-w3,0, w3,h1, x+w1+w2,y)

	-- middle
	if h2 >= 1 then
		sspr(sprite, 0,s_max_h, w1,1, x,y+h1, w1,h2) -- top left corner
		
		if w2 >= 1 then 
			if fillcol then
				rectfill(x+w1,y+h1, x+w1+w2-1,y+h1+h2-1, fillcol)
			elseif fillcol ~= false then
				sspr(sprite, s_max_w,s_max_h, 1,1, x+w1,y+h1, w2,h2)
			end
		end
		
		sspr(sprite, sp_w-w3,s_max_h, w3,1, x+w1+w2,y+h1, w3,h2)
	end	

	-- bottom
	sspr(sprite, 0,sp_h-h3, w1,h3, x,y+h1+h2) -- top left corner
	if(w2 >= 1) sspr(sprite, s_max_w,sp_h-h3, 1,h3, x+w1,y+h1+h2, w2,h3)
	sspr(sprite, sp_w-w3,sp_h-h3, w3,h3, x+w1+w2,y+h1+h2)
end
