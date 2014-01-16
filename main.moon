
love.load = () ->

	-- Load all libraries, functions, and preference variables
	require "loveframes"
	socket = require "socket"
	funcs = require "funcs"
	prefs = require "prefs"

	export data = require "data"

	funcs.tableToGlobals(funcs)
	tableToGlobals(prefs)

	export IN_TASK = {"", "", ""}

	date = os.date '*t'

	buildInputFrame!

	updateDataAndGUI!

	nil



love.update = (dt using nil) ->
	loveframes.update(dt)
	nil

love.draw = (using nil) ->
	loveframes.draw!
	nil

love.mousepressed = (x, y, button using nil) ->
	loveframes.mousepressed(x, y, button)
	nil

love.mousereleased = (x, y, button using nil) ->
	loveframes.mousereleased(x, y, button)
	nil

love.keypressed = (key, unicode using nil) ->
	loveframes.keypressed(key, unicode)
	nil

love.keyreleased = (key using nil) ->
	loveframes.keyreleased(key)
	nil
