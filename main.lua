love.load = function()
  require("loveframes")
  ftp = require("socket.ftp")
  ltn12 = require("ltn12")
  local funcs = require("funcs")
  funcs:tableToGlobals()
  PREFS = require("defaultprefs")
  local defaultcss = require("defaultstyle")
  local defaulthtml = require("defaulthtml")
  local dfiles = {
    {
      "prefs.lua",
      "return {}"
    },
    {
      "data.lua",
      "return {}"
    },
    {
      "style.css",
      defaultcss.STYLESHEET
    },
    {
      "template.html",
      defaulthtml.HTMLDOC
    }
  }
  for _, v in pairs(dfiles) do
    if not love.filesystem.exists(v[1]) then
      local f = love.filesystem.newFile(v[1])
      f:open("w")
      f:write(v[2])
      f:close()
    end
  end
  HTML_TEMPLATE, _ = love.filesystem.read("template.html")
  local userprefs = require("prefs")
  for k, v in pairs(userprefs) do
    PREFS[k] = v
  end
  data = require("data")
  SMALL_IRON_FONT = love.graphics.newFont("mirai-seu.ttf", 23)
  IN_TASK = {
    "",
    "",
    ""
  }
  buildInputFrame()
  updateDataAndGUI()
  return nil
end
love.update = function(dt)
  loveframes.update(dt)
  return nil
end
love.draw = function()
  loveframes.draw()
  return nil
end
love.mousepressed = function(x, y, button)
  loveframes.mousepressed(x, y, button)
  return nil
end
love.mousereleased = function(x, y, button)
  loveframes.mousereleased(x, y, button)
  return nil
end
love.keypressed = function(key, unicode)
  loveframes.keypressed(key, unicode)
  return nil
end
love.keyreleased = function(key)
  loveframes.keyreleased(key)
  return nil
end
