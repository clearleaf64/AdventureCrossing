local btn = require "lib.btn"
local evo = require "lib.evolved"

function _init()
  -- Live reload preserves globals across saved edits but resets locals.
  -- Stash mutable game state in a capitalized global like `State` so it
  -- survives reloads; F5 calls _init again to reset.
  State = {}
end

function _update(dt)
  btn.update(dt)
end

function _draw(dt)
  
  local a = btn.LEFT
  gfx.clear(gfx.COLOR_BLACK)
  if a == 0 then
    gfx.clear(gfx.COLOR_RED)
  end
  if a > 0 then
    gfx.clear(gfx.COLOR_BLACK)
  end
  gfx.text(a, 10, 10, gfx.COLOR_WHITE)
end
