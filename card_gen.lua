--[[pod_format="raw",created="2024-03-23 23:52:47",modified="2024-06-09 07:04:46",revision=894]]

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

-- text, dark, medium, light
local default_suit_colors = {
	{16, 1,16,12},
	{8, 24,8,14},
	{27, 19,3,27},
	{25, 4,25,9},
--	{13, 12,26,10}
	{13, 18,13,29}
}

-- x left, middle, right = {9, 19, 29}
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

local default_face_sprites = {
	[1] = {67,68,69,70,71},
	[11] = 66,
	[12] = 65,
	[13] = 64
}

--[[
function card_gen_standard(suits, ranks, 
	suit_chars, rank_chars, suit_colors, face_sprites,
	icon_pos)
]]
function card_gen_standard(param)

	-- default values
	local suits = param.suits or 4
	local ranks = param.ranks or 13
	
	local suit_chars = param.suit_chars or default_suits
	local rank_chars = param.rank_chars or default_ranks
	local suit_colors = param.suit_colors or default_suit_colors
	local suit_pos = param.suit_pos or default_suit_pos
	
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
			print(rank_char .. suit_char, 3, 3, col[1])
			
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
	
	local new_sprite = userdata("u8", width, height)
	set_draw_target(new_sprite)
	
	sprite = type(sprite) == "number" and get_spr(sprite) or sprite
	local sp_w, sp_h = sprite:width(), sprite:height()

	local w2 = width - left - right
	local h2 = height - top - bottom

	sspr(sprite, (sp_w - width)\2 + left,(sp_h - height)\2 + top, w2,h2, left,top)

	nine_slice(border, 0, 0, width, height)
	
	return new_sprite
end

