local FILE_NAME = "floor-state"

local COLOR_TURTLE = colors.green
local COLOR_WALL   = colors.white
local COLOR_EMPTY  = colors.black

settings.load(FILE_NAME)

local radius = settings.get("radius", 0)
local floor = settings.get("floor", {})
local pos = settings.get("pos", {})

local size = (radius*2) + 1

term.clear()
for y=0,size do
  term.setCursorPos(0, y)
  term.write(string.format("%d", y))
  term.setCursorPos(8, y)
  for x=0,size do
    local n = (y*size) + x + 1

    if x == pos["x"] and y == pos["y"] then
      term.setBackgroundColor(COLOR_TURTLE)
    elseif floor[n] == -1 then
      term.setBackgroundColor(COLOR_WALL)
    else
      term.setBackgroundColor(COLOR_EMPTY)
    end
    term.write(" ")
  end
end

read()
