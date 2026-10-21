local c = require "ecs.components"
local evolved = require "lib.evolved"

local prefabs = {}

prefabs.player = evolved.builder()
    :set(c.physical)
    :set(c.sprite, 2)
    :set(c.sprite_width, 2)
    :set(c.sprite_height, 2)
--    :set(c.hitbox_width, 5)
--    :set(c.hitbox_height, 5)

return prefabs
