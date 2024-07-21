
## Defineable Game Functions

```lua
-- caled every _draw, giving control when to draw with layer
function game_draw(layer)
	if layer == 0 then
		-- before anything else is drawn
		-- make sure to call cls
	
	elseif layer == 1 then
		-- after stack sprites and group 1 buttons are drawn, before cards
	
	elseif layer == 2 then
		-- after cards are drawn

	elseif layer == 3 then
	elseif layer == 4 then
		-- layers 3 and 4 are mostly reserved for ui
		-- drawn after button groups 2 and 3
	
	end
end

-- called every _update, after card and mouse updates
function game_update()
end

-- called after any action is taken
-- clicking, picking up a stack, letting go of a stack, animation finished, etc
function game_action_resolved()
	if not held_stack then
		-- it's sometimes a good idea to not update an object when the player is holding a stack of cards
	end
end

-- returns true when the game has reached a winning state
-- called right after game_action_resolved
-- when returning true, will set cards_frozen = true
function game_win_condition()
	return false
end

-- cards_frozen will prevent any mouse interaction with cards

-- called when game_win_condition returns true
function game_count_win()
	-- count score and/or play events
end
```

## API Functions to call

```lua
-- called when a game has started and mouse interaction should be allowed
cards_api_game_started()

-- clears the stacks, buttons, and cards from the tables and resets values of the api
-- when keep_func is falsey, game_draw, game_update, game_action_resolved, and game_win_condition will be set to nil
-- cards_api_clear(keep_func)

-- enabling will make color 32 draw shadows
cards_api_shadows_enable(enable)
-- custom remaping of colors (mostly for custom color palettes), color 32 is still reserved for shadows
cards_api_shadows_enable(enable, {0,4,1,3, ...})
```

## Card Functions

A card is just a table containing position information, a sprite, and the stack it belongs to.
You can assign other values like suit and rank to affect behaviours using the card.

```lua
-- creates and returns a card
local card = card_new({ ... })
--[[
param is a table that can have the following key values

x, y = position of card, though this usually isn't needed
	if param.stack is provided, then 
a = starting angle of the 
	0 = face up
	0.5 = face down
width, height = size of the card, usually should match the size of the card sprite
sprite = front face sprite of card, can be a sprite id or userdata
sprite_back = back face sprite of card, can be a sprite id or userdata
stack = stack the card will be place in
on_destroy = called when the card is to be destroyed

additional parameters can be provided to give the stack more properties
like suit and rank


x, y, a, x_offset, y_offset, should not be altered directly after creating the card
instead use x_to, y_to, a_to
x, y, a, x_offset, y_offset, are assigned smooth_val, which are allowed to be called like a function
	see util.lua

x_offset_to, y_offset_to = extra offsets for when drawing the card
]]

-- returns a table with all the cards
get_all_cards()

-- puts the card at the end of the cards table to draw the card on top of everything else
card_to_top(card)

-- returns true if the card iss the top card of the stack it is in
card_is_top(card)

-- destroys the card and removes it from the stack it's in
card:destroy()

-- resets the position of all cards to their proper position on 
-- useful for the start of loading a scene, prevening cards jumping around
card_position_reset_all()
```

## Stack Functions

Most of the mouse interactions with cards are automatically handled through stacks.

```lua
-- returns a table with all the stacks
get_all_stacks()

-- gets and sets the stack currently held by the mouse
-- though rarely needed, it's important to follow its usage in functions like on_click
get_held_stack()
set_held_stack(stack)

-- returns the top card of the stack
get_top_card(stack)

-- returns a new stack and adds it to the main stack table
local stack = stack_new(sprite, x, y, param)
--[[
sprites = table of sprite ids or userdata to be drawn with spr
x,y = top left position of stack
	will be assigned to x_to and y_to

param is a table that can have the following key values

x_off, y_off = draw offsets of the stack's sprite(s)
reposition = function called when changing the target position of the cards
	the function usually assigns all cards .x_to and .y_to values relative to the stack's position
	defaults to stack_repose_normal
perm = the stack is destroyed when there are no more cards if this is not set trues
	defaults to true
top_most = controls the draw order of cards between stacks
	the higher the number, the higher the stack
	defaults to 0
can_stack = function called when another stack of cards is placed on top (with restrictions)
	function(self, held)
	returns true if the "held" can be placed on top of "self"
on_click = function called when stack base or card in stack is clicked
	usually set to stack_on_click_unstack(...)
on_double = function called when stack base or card in stack is double clicked
resolve_stack = function called when can_stack returns true
	defaults to stack_cards
unresolved_stack = function called when a held card is released, but isn't placed onto a stack
	defaults to stack_unresolved_return
on_hover = function called when the cursor over the stack or card
	function(self, card, held)
	self = current stack
	card = the hovered card
	held = stack that is being held by the player
off_hover = function called when the cursor is no longer over the stack or card
	similar function to on_hover, called before the next on_hover function is called
on_destroy = function called when the stack is destroyed

additional parameters can be provided to give the stack more properties
]]

-- removes the stack from stacks_all
-- then calls stack:on_destroy() if provided
-- if cards_too is true, then the stack destroys all cards inside it
-- otherwise, just sets their stack to nil
stack:destroy(cards_too)

-- stack.cards[1] is the bottom card
-- stack.cards[#stack.cards] is the top card
-- literal stack

-- puts all cards from stack2 on top of stack1
-- ignores stack rule
stack_cards(stack1, stack2)

-- unstacks a card and any cards on top of it when clicked (if all rules return true)
-- one of the functions assigned to on_click in stack
-- can take any number of rule functions
stack_on_click_unstack(...)
-- rule functions take in a single parameter (card) and return true if the card can be unstacked
-- possible to give no parameters to always allow unstacking

-- unstack rule example (exists in stack.lua)
-- card must be face up to be picked up
function unstack_rule_face_up(card)
	return card.a_to == 0
end

-- creates a temporary stack starting from a given card
local temp_stack = unstack_cards(card)

-- returns a card repositioning function (for repos)
-- used to give cards a more floaty feel
stack_repose_normal(y_delta, decay, limit) -- defaults (12, 0.7, 220)

-- returns a card repositioning function
-- stiffer than the version above
stack_repose_static(y_delta) -- defaults (12)

-- example of a card repositioning function
function stack_repose_simple(stack)
	local y = stack.y_to
	for c in all(stack.cards) do
		c.x_to = stack.x_to
		c.y_to = y
		y += 12
	end
end

-- moves a card from it's old stack or table to a new one
stack_add_card(stack, card, old_stack)
-- if old_stack is not nil and a table, card will be removed from that stack
-- if old_stack is a number, the card will instead be inserted into that position in the new stack
-- (this should probably be more refined)

-- moves cards in an animation (see Animations section below) from given card stacks to "stack_to"
stack_collecting_anim(stack_to, ...)
-- example stack_collecting_anim(stack_to_recieve_cards, stack_goal, {stack1, stack2, stack3}, another_stack)

-- does a shuffling animation and randomizes position of cards
stack_shuffle_anim(stack)

--randomizes the position of all the cards in the stack
stack_quick_shuffle(stack)

-- uses stack_shuffle_anim 3 times, and then stack_quick_shuffle, for an easier shuffle
stack_standard_shuffle_anim(stack)

-- stack_hand_new is a special stack with precreated parameters
-- cards will be spaced horizontally instead of vertically, and will animate their position when hovered over with the mouse cursor
-- cards can be removed individually
stack_hand_new(sprites, x, y, param)
--[[
param has some additional values that can be given

hand_width = max pixel width that the cards can be stretched out
hand_max_delta = amount of pixels seperating the cards, unless the go beyond hand_width
]]
```

## Animations

If you want to have a set of actions occur over time
When an animation is occuring, no cards can be interacted with.

```lua
-- cards_coroutine contains the coroutine managed by the api

--example inside game_setup
function game_setup()

	-- ...

	-- creates a coroutine to be executed per frame
	cards_api_coroutine_add(game_setup_anim)

	-- cards_api_coroutine_add(co, stop, wait)
	-- extra parameters stop and wait help control multiple coroutines to occur at the same time
	-- when "stop" is nil or true, the next coroutines will not run
	-- when "wait" is true, the coroutine will wait for the previous coroutines to be done

	-- when all coroutines are done, game_action_resolved() will be called if it exists
end

--example from golf solitaire
function game_setup_anim()
	pause_frames(30) -- wait 30 frames
	
	for i = 1,5 do	
		for s in all(stacks_supply) do
			--  transfer a card from the stack
			local c = get_top_card(deck_stack)
			if(not c) break
			stack_add_card(s, c)
			c.a_to = 0 -- turn face up

			pause_frames(3) -- wait 3 frames to allow it not to be instant
		end
		pause_frames(5) -- wait 5 frames for extra effect
	end
	
	cards_api_game_started() -- lets the game start
end
```

## Card Sprite Generation

`card_gen.lua` is provided to simplify the creation of multiple sprites with the same style.

```lua
-- generates and returns a table of tables of sprites based on a the given param table
-- type(sprites[suit][rank]) == "userdata"

local sprites = card_gen_standard(param)

--[[
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

to see the default tables, look in card_gen.lua
]]

-- generates and returns a card back sprite based on the given param table
-- (This should usually not be used in Picotron Solitaire Suite)
local back = card_gen_back(param)
--[[
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
```

## Buttons

Buttons, from `button.lua` are elements that can be interacted with by the mouse.

```lua
-- creates a new button
local button = button_new(param)
--[[
param is a table that can take the following values

x, y = top left position of the interactable space of the button, in pixels
width, height = size of the interactable space of the button, in pixels
draw = function called when it's time to draw the button
on_click = function called when the button is clicked
enabled = boolean for if the button can be clicked
always_active = if true, the button can always be clicked if it's highlighted
	if false, the button will not be clickable when the game is frozen or if there is an coroutine playing
	see cards_api_set_frozen and cards_api_coroutine_add in cards_base.lua
on_destroy = called when the button is destroyed
group = layer that the buttons will be drawn on, forcing partial draw and click order
	1 = base game
	2,3 = primarily reserved for ui
bottom = when true, adds the button to the start of the list of buttons instead of the end
	this can help with the draw order


the button has some extra properties

hit = is set true when the cursor is over the button
highlight = same as hit, but false the button has no on_click function
]]

-- button_simple_text creates a simple animated button that fits a given string of text
local button = button_simple_text(s, x, y, on_click)
--[[
s = text displayed on the button
x, y = position of the button
on_click = function called when the button is clicked
]]
```
