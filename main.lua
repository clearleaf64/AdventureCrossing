local btn = require "lib.btn"
local evo = require "lib.evolved"
local prefabs = require "ecs.prefabs"
local id = require "ecs.components"

local player

function spawn_entity(ent)
    local a = ent:build()
    --add_to_collision_world(a)
    return a
end


function _init()
  State = {}
  player = spawn_entity(prefabs.player)
  
end

function _update(dt)
  btn.update(dt)
end

function _draw(dt)
  gfx.clear(gfx.COLOR_BLACK)
  local x,y,s = evo.get(player,id.position_x,id.position_y,id.sprite)
  gfx.spr(s,x,y)
end
