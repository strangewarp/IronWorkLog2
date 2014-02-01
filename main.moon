
love.load = () ->

	require "loveframes"
	export ftp = require "socket.ftp"
	export ltn12 = require "ltn12"
	funcs = require "funcs"
	funcs\tableToGlobals! -- Load functions into global namespace

	export PREFS = require "defaultprefs"
	defaultcss = require "defaultstyle"
	defaulthtml = require "defaulthtml"

	dfiles = {
		{"prefs.lua", "return {}"}
		{"data.lua", "return {}"}
		{"style.css", defaultcss.STYLESHEET}
		{"template.html", defaulthtml.HTMLDOC}
	}

	-- Create userdata files, if they don't exist
	for _, v in pairs dfiles
		if not love.filesystem.exists(v[1])
			f = love.filesystem.newFile v[1]
			f\open "w"
			f\write v[2]
			f\close!

	export HTML_TEMPLATE, _ = love.filesystem.read "template.html"

	-- Load user preferences, and then overwrite default prefs with user-defined prefs where applicable
	userprefs = require "prefs"
	for k, v in pairs userprefs
		PREFS[k] = v

	export data = require "data"

	--export SMALL_IRON_FONT = love.graphics.newImageFont "font.png", " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?-+/():;%&`'*#=[]\""
	export SMALL_IRON_FONT = love.graphics.newFont "mirai-seu.ttf", 23

	export IN_TASK = {"", "", ""}

	buildInputFrame!

	updateDataAndGUI!

	nil

love.update = (dt using oldtime) ->
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
