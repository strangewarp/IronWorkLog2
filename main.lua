love.load = function()
  require("loveframes")
  require("sha1")
  local socket = require("socket")
  local funcs = require("funcs")
  local prefs = require("prefs")
  data = require("data")
  funcs.tableToGlobals(funcs)
  tableToGlobals(prefs)
  IN_TASK = {
    "",
    "",
    ""
  }
  local date = os.date('*t')
  local timedata, eradata, scoredata = generateMetrics(date)
  local inputframe = buildInputFrame()
  local metricsframe = buildMetricsFrame()
  buildMetricsTabs(eradata, scoredata, date, metricsframe)
  local entriesframe = buildEntriesFrame()
  buildEntriesGrid(data, entriesframe)
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