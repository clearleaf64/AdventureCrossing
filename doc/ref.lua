local evolved = require("./evolved")
local bump = require("./bump")
local vector = require("vector")

local last_time = time()
local delta_time = 0.0
local world = bump.newWorld(8)
local t = 0
local current_room
local player
local rooms = {}
local entities = {}
local prefabs = {}
local KEYS = { A = 1, W = 23, S = 19, D = 4 }

--tiles to be auto-tiled
b_list={[18]=true,[22]=true,[26]=true,[82]=true,[86]=true}
function tile_chk(x,y) return b_list[mget(x,y)] or false end

function remap(tile,x,y)
	local out,flip,rota=tile,0,0
	--Auto tiles start here
	if tile_chk(x,y)then	
	 local aux=tile
			--> check in  Horizontal(Y)
	  if tile~=mget(x,y-1) and tile~=mget(x,y+1)then aux=aux+32 
			elseif tile~=mget(x,y-1)then aux=aux-16 
	  elseif tile~=mget(x,y+1)then aux=aux+16 end
			--> check in Vertical(X)
			if tile~=mget(x-1,y) and tile~=mget(x+1,y)then aux=aux+1
			elseif tile~=mget(x-1,y)then aux=aux-1 
			elseif tile~=mget(x+1,y)then aux=aux-1 flip=1 end
			--> Corners
			if aux==tile then
			  if tile~=mget(x-1,y-1)then aux=aux-14	
					elseif tile~=mget(x-1,y+1)then aux=aux+2						
				 elseif tile~=mget(x+1,y-1)then flip=1 aux=aux-14
				 elseif tile~=mget(x+1,y+1)then flip=1 aux=aux+2 
				else 
				  -->Atlas (random stuff)
				  if aux==tile then aux=(x*(y*3))%7==1 and aux+18 or tile end
				end
			end
			out=aux --> done..
	end
 -- From here you can use the remap function normaly...
	return out,flip,rota
end


local function clone_table(value)
        local copy = {}
        for key, item in pairs(value) do
            copy[key] = item
        end
        return copy
end

local function table_contains(tbl, target)
    for _, value in pairs(tbl) do
        if value == target then
            return true
        end
    end
    return false
end

function clamp(val, minVal, maxVal)
    return math.max(minVal, math.min(val, maxVal))
end

local function set_bpp(bpp)
    local value = ({[1] = 8, [2] = 4, [4] = 2})[bpp]
    if value then
        poke4(2 * 0x3ffc, value)
    else
        trace("Not a valid bpp mode.")
    end
end


function swap_pal(c0,c1)
 if(c0==nil and c1==nil)then for i=0,15 do poke4(0x3FF0*2+i,i)end
 else poke4(0x3FF0*2+c0,c1) end
end

function remap_pallette(pal)
    for i=1,#pal,1 do
        swap_pal(i,pal[i])
    end
end

-- ECS component IDs

local wanderer = evolved.id()

-- Palette swap map. List length is variable, eg {0,4,2,1} is valid for 2bpp mode. 
local palette = evolved.builder()
    :default({1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16})
    :duplicate(clone_table)
    :build()

local to_room = evolved.builder()
    :default(rooms.test_room)
    :build()

-- An 8 character name that might be saved in PMEM
local short_name = evolved.builder()  
    :default("UNSET")
    :build()


local sign_text = evolved.builder()
    :default("No text set :(")
    :build()

--[[local doors = evolved.builder()
    :default({})
    :duplicate(clone_table)
    :build()]]

--[[local room_ent_list = evolved.builder()
    :default({})
    :duplicate(clone_table)
    :build()]]

local hitbox_width = evolved.builder()
    :default(8)
    :build()

local hitbox_height = evolved.builder()
    :default(8)
    :build()

local position_x = evolved.builder()
    :default(0)
    :build()

local position_y = evolved.builder()
    :default(0)
    :build()

local position_z = evolved.builder()
    :default(0)
    :build()

local velocity = evolved.builder()
    :default(vector(0, 0))
    :duplicate(function(v)
        return v:clone()
    end)
    :build()

local room_entity_list = evolved.builder()
    :default({})
    :build()

local bpp_mode = evolved.builder()
    :default(2)
    :build()

local sprite_width = evolved.builder()
    :default(1)
    :build()

local sprite_height = evolved.builder()
    :default(1)
    :build()

local animation_length = evolved.builder()
    :default(1)
    :build()

local sprite = evolved.builder()
    :require(sprite_width,sprite_height,bpp_mode,animation_length,palette)
    :default(304)
    :build()

local target_x = evolved.builder()
    :default(0)
    :build()

local target_y = evolved.builder()
    :default(0)
    :build()

local target_z = evolved.builder()
    :default(0)
    :build()

-- ECS Component tags

local room_tag = evolved.builder()
    :tag()
    :require(
        position_x,
        position_y,
        sprite_width,
        sprite_height,
        room_entity_list,
        short_name
    )
    :build()

local physical = evolved.builder()
    :tag()
    :require(
        position_x,
        position_y,
        velocity,
        sprite,
        sprite_width,
        sprite_height,
        hitbox_width,
        hitbox_height
    )
    :build()

local portal_tag = evolved.builder()
    :tag()
    :require(position_x, position_y, to_room, hitbox_width, hitbox_height,target_x,target_y)
    :build()

-- Hitbox is centered horizontally and extends upward from position.y.
local function hitbox_rect(entity, p)
    local w, h = evolved.get(entity, hitbox_width, hitbox_height)
    return p.x - w / 2, p.y - h, w, h
end

local function add_to_collision_world(entity, target_world)
    target_world = target_world or world

    local px, py = evolved.get(entity, position_x, position_y)
    local x, y, w, h = hitbox_rect(entity, { x = px, y = py })

    target_world:add(entity, x, y, w, h)
end

local spawn_enemy

local function switch_room(new_room)
    trace("Hello!")
    current_room = new_room:build()
    local ent_list = evolved.get(current_room,room_entity_list)
    if #ent_list == 0 then return end
    for i=1, #ent_list, 1 do
        spawn_entity(ent_list[i])
    end
    --create_room_tile_colliders()
end

local function load_room(data)
    current_room = evolved.builder()
        :set(name_fragment, data.name)
        :set(map_region, {
            x = data.x,
            y = data.y,
            width = data.width,
            height = data.height,
        })
        :set(room_ent_list, data.entities or {})
        :set(doors, data.doors or {})
        :build()

    local room_entities = evolved.get(current_room, room_ent_list)

    for i = 1, #room_entities do
        local definition = room_entities[i]

        spawn_enemy(
            definition[1],
            definition[2],
            definition[3],
            definition[4] or {}
        )
    end
end

function spawn_entity(ent)
    local a = ent:build()
    add_to_collision_world(a)
    return a
end

spawn_enemy = function(prefab, spawn_position, spawn_velocity,overrides)
    local entity = prefab:build()
    overrides = overrides or {}

    evolved.set(entity, position_x, spawn_position.x)
    evolved.set(entity, position_y, spawn_position.y)
    evolved.set(entity, velocity, spawn_velocity)
    for i,v in ipairs(overrides) do 
        evolved.set(entity,v[1],v[2])
    end
    table.insert(entities, entity)
    add_to_collision_world(entity)

    return entity
end

local room_tile_colliders = {}

local function create_room_tile_colliders()
    -- Remove colliders from the previous room.
    for _, collider in ipairs(room_tile_colliders) do
        if world:hasItem(collider) then
            world:remove(collider)
        end
    end
    room_tile_colliders = {}

    local mx,my,mw,mh = evolved.get(current_room, position_x,position_y,sprite_width,sprite_height)

    -- Match the map's centered screen position in DRW().
    local map_x = (240 / 2) - ((mw * 8) / 2)
    local map_y = (136 / 2) - ((mh * 8) / 2)

    for ty = 0, mh - 1 do
        for tx = 0, mw - 1 do
            local tile = mget(mx + tx, my + ty)

            if fget(tile, 0) then
                local collider = {}
                local x = map_x + tx * 8
                local y = map_y + ty * 8

                world:add(collider, x, y, 8, 8)
                room_tile_colliders[#room_tile_colliders + 1] = collider
            end
        end
    end
end

local function change_room(room_data, spawn)
    -- Remove room-owned entities, keeping the player.
    for i = #entities, 1, -1 do
        local entity = entities[i]

        if entity ~= player then
            if world:hasItem(entity) then
                world:remove(entity)
            end
            evolved.destroy(entity)
            table.remove(entities, i)
        end
    end

    -- Load the new room and spawn its entities.
    load_room(room_data)
    create_room_tile_colliders()
    -- Relocate the player and update its collision rectangle.
    evolved.set(player, position_x, spawn.x)
    evolved.set(player, position_y, spawn.y)
    evolved.set(player, velocity, vector(0, 0))

    local x, y, w, h = hitbox_rect(player, spawn)
    world:update(player, x, y, w, h)
end



local function draw_hitboxes()
    set_bpp(4)

    for _, entity in ipairs(entities) do
        local px, py = evolved.get(entity, position_x, position_y)
        local x, y, w, h = hitbox_rect(entity, { x = px, y = py })

        rectb(
            math.floor(x),
            math.floor(y),
            math.floor(w),
            math.floor(h),
            12
        )
    end
end

-- Systems
local portal_query = evolved.builder()
    :include(portal_tag, to_room, position_x, position_y,hitbox_width,hitbox_height)
    :build()

local portal_system = evolved.builder()
    :query(portal_query)
    :execute(function(chunk, entity_list, entity_count)
        local to_rooms = chunk:components(to_room)
        local position_xs = chunk:components(position_x)
        local position_ys = chunk:components(position_y)
        local hb_width = chunk:components(hitbox_width)
        local hb_height = chunk:components(hitbox_height)

        for i = 1, entity_count do
            local portal = entity_list[i]
            local to_room_val = to_rooms[i]
            local px = position_xs[i]
            local py = position_ys[i]
            local width = hb_width[i]
            local height = hb_height[i]
            
            
            -- Adjust w and h based on how your portals store dimensions
            local items = world:queryRect(px, py, width, height)

            for _, item in ipairs(items) do
                if item == player then
                    switch_room(to_room_val)
                    -- TODO: Handle portal collision with player
                end
            end
        end
    end)
    :build()

local function check_doors()
    evolved.process(portal_system)
end



local function player_input_system()
    local dx, dy = 0, 0

    if btn(2) or key(KEYS.A) then dx = dx - 1 end
    if btn(3) or key(KEYS.D) then dx = dx + 1 end
    if btn(0) or key(KEYS.W) then dy = dy - 1 end
    if btn(1) or key(KEYS.S) then dy = dy + 1 end

    local speed = 30
    local diagonal = 0.70710678

    if dx ~= 0 and dy ~= 0 then
        dx = dx * diagonal
        dy = dy * diagonal
    end

    evolved.set(player, velocity, vector(dx * speed, dy * speed))
end

local sign_query = evolved:builder()
    :include(position_x,position_y,sign_text)
    :build()

local draw_query = evolved:builder()
    :include(position_x, position_y, sprite, sprite_width, sprite_height, bpp_mode)
    :build()

local function animated_sprite_id(base_id, sw, sh, frame_count)
    frame_count = math.max(1, frame_count)

    -- t counts TIC frames; hold each animation frame for 8 ticks.
    local frame = (t // 8) % frame_count

    local base_x = base_id % 32
    local base_y = base_id // 32
    local frames_per_row = math.max(1, (32 - base_x) // sw)

    local frame_x = base_x + (frame % frames_per_row) * sw
    local frame_y = base_y + (frame // frames_per_row) * sh

    return frame_y * 32 + frame_x
end

local function sign_system()
    local sign_list = {}

    local collect_signs = evolved.builder()
        :query(sign_query)
        :execute(function(chunk, entity_list, entity_count)
            local xs = chunk:components(position_x)
            local ys = chunk:components(position_y)
            local texts = chunk:components(sign_text)

            for i = 1, entity_count do
                sign_list[#sign_list + 1] = {
                    x = xs[i],
                    y = ys[i],
                    text = texts[i],
                }
            end
        end)
        :build()

    evolved.process(collect_signs)


    for _, item in ipairs(sign_list) do
        local px, py = evolved.get(player, position_x, position_y)
        local dx = px - item.x
        local dy = py - item.y
        local dist = math.sqrt(dx * dx + dy * dy)

        local a = 0
        while a < item.text:len() do 
            item.text = item.text:sub(1, a - 1) .. "\n" .. item.text:sub(a)
            a = a + 10
        end
        
        if dist < 7 and item.y < py then
            rect(2,2,60,240,1)
            rectb(2,2,60,240,9)
            print(item.text,4,4,3,true)
        end
    end

end

local function drawing_system()
    local draw_list = {}

    local collect_drawables = evolved.builder()
        :query(draw_query)
        :execute(function(chunk, entity_list, entity_count)
            local xs = chunk:components(position_x)
            local ys = chunk:components(position_y)
            local sprites = chunk:components(sprite)
            local widths = chunk:components(sprite_width)
            local heights = chunk:components(sprite_height)
            local bpps = chunk:components(bpp_mode)
            local pals = chunk:components(palette)

            for i = 1, entity_count do
                draw_list[#draw_list + 1] = {
                    y = ys[i],
                    x = xs[i],
                    sprite = sprites[i],
                    width = widths[i],
                    height = heights[i],
                    bpp = bpps[i],
                    pal = pals[i],
                }
            end
        end)
        :build()

    evolved.process(collect_drawables)

    table.sort(draw_list, function(a, b)
        return a.y < b.y
    end)

    for _, item in ipairs(draw_list) do
        set_bpp(item.bpp)
        remap_pallette(item.pal)
        local draw_x = math.floor(item.x + 0.5)
        local draw_y = math.floor(item.y + 0.5)
        spr(
            item.sprite,
            --item.sprite + t % 60 // (30 * item.width),
            draw_x - item.width * 4,
            draw_y - item.height * 8,
            0, 1, 0, 0, item.width, item.height
        )
        pix(item.x, item.y, t % 15)
    end
    remap_pallette({1,2,3,4,5,6,7,8,9,10})
    set_bpp(4)
end



local wander_query = evolved.builder()
    :include(wanderer, velocity)
    :build()

local wander_system = evolved.builder()
    :query(wander_query)
    :execute(function(chunk, entity_list, entity_count)
        local velocities = chunk:components(velocity)

        for i = 1, entity_count do
            if math.random() > 0.6 then
                local v = velocities[i]
                v.x = clamp(v.x, -30, 30)
                v.y = clamp(v.y, -30, 30)

                velocities[i] = vector(
                    v.x + math.random(-10, 10),
                    v.y + math.random(-10, 10)
                )
            end
        end
    end)
    :build()

local function wander_ai_system()
    evolved.process(wander_system)
end


local movement_query = evolved.builder()
    :include(position_x, position_y, velocity)
    :build()

local movement_system_obj = evolved.builder()
    :query(movement_query)
    :execute(function(chunk, entity_list, entity_count)
        local position_xs = chunk:components(position_x)
        local position_ys = chunk:components(position_y)
        local velocities = chunk:components(velocity)

        for i = 1, entity_count do
            local entity = entity_list[i]
            local px = position_xs[i]
            local py = position_ys[i]
            local v = velocities[i]
            local x, y, w, h = hitbox_rect(entity, { x = px, y = py })

            local actual_x, actual_y = world:move(
                entity,
                x + v.x * delta_time,
                y + v.y * delta_time
            )

            position_xs[i] = actual_x + w / 2
            position_ys[i] = actual_y + h
        end
    end)
    :build()

local function movement_system()
    evolved.process(movement_system_obj)
end


-- Prefabs

prefabs.bat = evolved.builder()
    :set(wanderer)
    :set(physical)
    :set(sprite,640)

prefabs.player = evolved.builder()
    :set(physical)
    :set(bpp_mode, 4)
    :set(sprite, 256)
    :set(sprite_width, 2)
    :set(sprite_height, 2)
    :set(hitbox_width, 5)
    :set(hitbox_height, 5)

prefabs.tablet = evolved.builder()
    :set(physical)
    :set(sprite_height,2)
    :set(sprite,672)
    :set(hitbox_height,4)

prefabs.message_box = evolved.builder()
    :set(sprite,2)

prefabs.door_portal = evolved.builder()
    :set(portal_tag)

-- Room prefabs

rooms.silly_closet = evolved.builder()
    :set(room_tag)
    :set(position_x,0)
    :set(position_y,11)
    :set(sprite_width,11)
    :set(sprite_height,8)
    :set(room_entity_list,{
            prefabs.bat:set(position_x,40):set(position_y,80),
            prefabs.door_portal:set(position_x,163):set(position_y,60):set(to_room,rooms.silly_closet)
    })

rooms.awakening_room = evolved.builder()
    :set(room_tag)
    :set(position_x,20)
    :set(position_y,20)
    :set(sprite_width,10)
    :set(sprite_height,20)
    :set(room_entity_list,
        {
            prefabs.bat
                :set(palette,{7,4,9})
                :set(position_x,50)
                :set(position_y,50),
            prefabs.tablet
                :set(position_x,10)
                :set(position_y,50)
                :set(sign_text,"What a mysterious room")
        }
    )


-- TIC-80 callbacks

function BOOT()
    set_bpp(4)
    player = prefabs.player:set(position_x,118):set(position_y,70):build()
    add_to_collision_world(player)
    switch_room(rooms.silly_closet)
    create_room_tile_colliders()
end

function TIC()
    local current_time = time()
    delta_time = (current_time - last_time) / 1000.0
    delta_time = math.min(delta_time, 0.05)
    player_input_system()
    wander_ai_system()
    movement_system(delta_time)
    check_doors()
    
    DRW()
    
    t = t + 1
    last_time = current_time
    DRW()
end

function DRW()
    cls(13)
    set_bpp(4)
    -- Draw current room map.
    local mx,my = evolved.get(current_room, position_x,position_y)
    local w,h = evolved.get(current_room, sprite_width,sprite_height)
    map(mx, my, w, h, 120-(w*4), 68-(h*4),-1,1,remap)

    drawing_system()
   -- sign_system()
   -- set_bpp(4)
    local mx, my = mouse()
    print(mx .. ", " .. my,120,3,11)
  --  draw_hitboxes()
end

