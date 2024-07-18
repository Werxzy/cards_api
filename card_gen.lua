--[[pod_format="raw",created="2024-03-23 23:52:47",modified="2024-07-17 08:08:51",revision=2840]]

-- defaults were originally designed for Picotron Solitaire Suite

local default_suits = {
	--"Spades",
	--"Hearts",
	--"Clubs",
	--"Diamonds",
	--"Stars"
	"\|g\^:081c3e7f7f36081c",
	"\|g\^:00367f7f3e1c0800",
	"\|f\^:001c1c7f7f77081c",
	"\|g\^:081c3e7f3e1c0800",
	"\|g\^:081c7f7f3e362200"
}

local default_ranks = {
	"A",
	"2",
	"3",
	"4",
	"5",
	"6",
	"7",
	"8",
	"9",
	"10",
	"J",
	"Q",
	"K",
	
-- just extra to reach rank 16, no reason for these
	"X",
	"Y",
	"Z",
}

-- [suit] = text, dark, medium, light
local default_suit_colors = {
	{16, 1,16,12},
	{8, 24,8,14},
	{27, 19,3,27},
	{25, 4,25,9},
--	{13, 12,26,10}
	{13, 18,13,29}
}

-- [rank] = {{x,y}, ...}
local default_suit_pos = {
	{{19, 28}},
	{{19, 17}, {19, 39}},
	{{19, 17}, {19, 28}, {19, 39}},
	{{9, 17}, {9, 39}, {29, 17}, {29, 39}},
	{{9, 17}, {9, 39}, {29, 17}, {29, 39}, {19, 28}},
	{{9, 17}, {9, 39}, {9, 28}, {29, 17}, {29, 39}, {29, 28}},
	{{19, 17},{19, 39},{19, 28}, {9, 23},{9, 34}, {29, 23},{29, 34}},
	{{9, 17},{9, 39},{9, 28}, {19, 23},{19, 34}, {29, 17},{29, 39},{29, 28}},
	{{19, 17},{19, 39},{19, 28}, {9, 23},{9, 34},{9, 45}, {29, 12},{29, 23},{29, 34}},
	{{9, 18},{9, 29},{9, 40}, {19, 13},{19, 24},{19, 35},{19, 46}, {29, 18},{29, 29},{29, 40}},	
}

-- [rank] = sprite OR {sprite, sprite, ...} (number of sprites equal to suits)
local default_face_sprites = {
-- ace
	[1] = {67,68,69,70,71},

-- face cards
	[11] = 66,
	[12] = 65,
	[13] = 64
}

--[[
generates and returns a table of tables of sprites based on a the given param table
type(sprites[suit][rank]) == "userdata"

param can take the following values
suit = number of suites
	defaults 4
ranks = number of ranks for all suits
	includes face cards
	defaults 13
suit_chars = table of strings that will be drawn on each sprite of that suit
	defaults to default_suits
rank_chars = table of strings that will be drawn on each sprite of that rank
	defaults to default_ranks
suit_colors = table of colors that will be used for what's drawn on the sprite based on the suit
	defaults to suit_colors
suit_pos = table of locations of the suit sprites from suit_chars, where the index is the rank of the card
	indicies can be empty
	defaults to default_suit_pos
suit_show = table of booleans for if the suit sprite should be drawn in the top left
	any missing booleans default to true
face_sprites = table of sprites to be drawn instead of suit sprites for given ranks
	for a single rank a table of sprites can be given to be used for each suit
	when provided, no suit sprites will be drawn
	indices can be skipped
	defaults to default_face_sprites
width = width of the sprites in pixels
	defaults to 45
height = height of the sprites in pixels
	defaults to 60
]]
function card_gen_standard(param)
	
	param = param or {}

	-- default values
	local suits = param.suits or 4
	local ranks = param.ranks or 13
	
	local suit_chars = param.suit_chars or default_suits
	local rank_chars = param.rank_chars or default_ranks
	local suit_colors = param.suit_colors or default_suit_colors
	local suit_pos = param.suit_pos or default_suit_pos
	local suit_show = param.suit_show or {}
	while #suit_show < ranks do
		add(suit_show, true)
	end
	
	local face_sprites = param.face_sprites or default_face_sprites
	
	local width = param.width or 45
	local height = param.height or 60
	
	local card_sprites = {}
	
	-- for each suit and rank
	for suit = 1,suits do
		local card_set = add(card_sprites, {})
		local col = suit_colors[suit]
		local suit_char = suit_chars[suit]
		
		for rank = 1,ranks do
			local rank_char = rank_chars[rank]
			
			-- prepare render
			local new_sprite = userdata("u8", width, height)
			set_draw_target(new_sprite)
			
			-- draw card base
			nine_slice(8, 0, 0, width, height)
			
			-- draw rank/suit
			print(rank_char .. (suit_show[rank] and suit_char or ""), 3, 3, col[1])
			
			local sp = face_sprites[rank]
			local pos = suit_pos[rank]
			
			-- draw sprite if it calls for it
			if sp then 
				pal(24, col[2], 0)
				pal(8, col[3], 0)
				pal(14, col[4], 0)
				spr(type(sp) == "table" and sp[suit] or sp)
				pal(24,24,0)
				pal(8,8,0)
				pal(14,14,0)
			
			 -- draws the icons at given positions
			elseif pos then
				 -- shadows
				for p in all(pos) do
					print(suit_char, p[1]+1, p[2]+2, 32)
				end
				-- base
				color(col[1])
				for p in all(pos) do
					print(suit_char, p[1], p[2])
				end	
			end
			
			add(card_set, new_sprite)
		end
	end
	
	-- important to reset the draw target for future draw operations.
	set_draw_target()
	
	return card_sprites
end

--[[
generates and returns a card back sprite based on the given param table

param can take the following values

sprite = sprite drawn in the center of the card back, behind the border
	defaults to sprite 112, but this should always be replaced
border = sprite to be used with nineslice to draw at the edge of the generated sprite
	defaults to sprite 25
width, height = size of generated sprite, defaults to 45 and 60
left, right, top, bottom = pixels to cut off param.sprite
	defaults to 2
target_sprite = sprite to drawn on, will 
]]
function card_gen_back(param)

	-- expects sprite to be 100x100 pixels at least
	-- width a default size of 45x60

	param = param or {}

	local sprite = param.sprite or 112
	local border = param.border or 25
	local width = param.width or 45
	local height = param.height or 60
	
	local left = param.left or 2
	local right = param.right or 2
	local top = param.top or 2
	local bottom = param.bottom or 2
	
	local new_sprite = param.target_sprite or userdata("u8", width, height)
	set_draw_target(new_sprite)
	
	local ty = type(sprite)
	if ty == "number" then
		sprite, ty = get_spr(sprite), "userdata"
	end
	
	local w2 = width - left - right
	local h2 = height - top - bottom	
	
	if ty == "function" then
		camera(-left,-right)
		clip(left, right, w2, h2)
		sprite(w2, h2)
		camera()
		clip()
		
	elseif ty == "userdata" then		
		sspr(sprite, 
			(sprite:width() - width)\2 + left,
			(sprite:height() - height)\2 + top, 
			w2,h2, 
			left,top)
	end
	
	nine_slice(border, 0, 0, width, height)
	
	set_draw_target()
	camera()
	
	return new_sprite
end

