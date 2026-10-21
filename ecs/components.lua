local evolved = require "lib.evolved"


local function clone_table(value)
        local copy = {}
        for key, item in pairs(value) do
            copy[key] = item
        end
        return copy
end


local function fragment(default, duplicate)
    local builder = evolved.builder():default(default)
    if duplicate then
        builder = builder:duplicate(duplicate)
    end
    return builder:build()
end


local id = {}

id.name            = fragment("Noname")

id.hitbox_width    = fragment(8)
id.hitbox_height   = fragment(8)

id.position_x      = fragment(0)
id.position_y      = fragment(0)
id.position_z      = fragment(0)

id.velocity_x      = fragment(0)
id.velocity_y      = fragment(0)
id.velocity_z      = fragment(0)

id.sprite          = fragment(1)
id.sprite_width    = fragment(1)
id.sprite_height   = fragment(1)
id.animation_length = fragment(1)

id.entity_list     = fragment({}, clone_table)

id.room_tag = evolved.builder()
    :tag()
    :require(
        id.position_x,
        id.position_y,
        id.sprite_width,
        id.sprite_height,
        id.entity_list,
        id.name
    )
    :build()

id.physical = evolved.builder()
    :tag()
    :require(
        id.position_x,
        id.position_y,
        id.sprite,
        id.sprite_width,
        id.sprite_height,
        id.hitbox_width,
        id.hitbox_height
        
    )
    :build()

return id
