local btn = {}

btn.action_list = {
  LEFT = 0, RIGHT = 0, 
  UP = 0, DOWN = 0,
  BTN1 = 0, BTN2 = 0, BTN3 = 0
}

setmetatable(btn, {
  __index = btn.action_list,
})

function btn.update(dt)
  dt = dt or 1.0
  for action, value in pairs(btn.action_list) do
    if input.held(input[action]) then
      btn.action_list[action] = value < 0 and 0 or value + dt
    else
      btn.action_list[action] = value >= 0 and -1 or value - dt
    end
  end
end


return btn

