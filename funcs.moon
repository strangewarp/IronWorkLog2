
return {

	-- Recursively copy all sub-tables and sub-items, as values instead of references. Invoke as: newtable = deepCopy(oldtable, {})
	deepCopy: (t = {}, t2 = {} using nil) ->
		for k, v in pairs t
			switch type v
				when "table" then t2[k] = deepCopy(v)
				else t2[k] = v
		t2

	-- Continued from within deepTableToString, lay down table values into the string itself
	buildTableStringEntry: (k, v, tnum using nil) ->
		o, putk = "", ""

		if type(k) == "string"
			putk = "[\"" .. k .. "\"] = "
		if type(v) == "table"
			o ..= string.rep("\t", tnum) .. putk .. "{\n"
			o ..= deepTableToString(v, tnum)
			o ..= string.rep("\t", tnum) .. "},\n"
		else
			o ..= string.rep("\t", tnum) .. putk .. (((type(v) == "string") and ("\"" .. v .. "\"")) or tostring(v)) .. ",\n"

		o

	-- Convert an arbitrary table into the contents of a Lua table-file
	deepTableToString: (t = {}, depth = 0 using nil) ->

		out = ""
		dplus = depth + 1

		if t[1]
			for k, v in ipairs t
				out ..= buildTableStringEntry k, v, dplus
		else
			for k, v in pairs t
				out ..= buildTableStringEntry k, v, dplus

		if depth == 0
			out = "return {\n\n" .. out .. "\n\n}\n"

		out


	-- Round number num, at decimal place idp
	round: (num, idp = 0 using nil) ->
		mult = 10 ^ idp
		math.floor((num * mult) + 0.5) / mult

	-- Convert a table's contents to globals
	tableToGlobals: (tab using nil) ->
		_G[k] = v for k, v in pairs tab
		nil

	-- Convert a date to an RGB value
	dateToColor: (dtab using nil) ->
		dtab[1] = (((dtab[1] % 8) + 1) * 32) - 1 -- Year
		dtab[2] = round(dtab[2] * 21.25, 0) -- Month
		dtab[3] = (((dtab[3] % 8) + 1) * 32) - 1 -- Day
		dtab

	-- Get two complementary colors based on the current date
	getDayColors: (dyear, dmonth, dday using PREFS) ->

		drgb = dateToColor {dyear, dmonth, dday}
		hsl = RGBtoHSL drgb
		--hsl = dateToColor {dyear, dmonth, dday}
		invhsl = [(hsl[i] + 127) % 256 for i = 1, 3]

		if PREFS.COLORBLIND_MODE
			hsl[2] = 0
			invhsl[2] = 0

		hsl[4] = 255
		invhsl[4] = 255

		rgb = HSLtoRGB hsl
		invrgb = HSLtoRGB invhsl

		rgb, invrgb

	-- Converts RGB to HSL
	RGBtoHSL: (rgb using nil) ->

		r, g, b, a = rgb[1], rgb[2], rgb[3], (rgb[4] or 255)
		h, s, l = 0, 0, 0

		r /= 255
		g /= 255
		b /= 255

		vmin = math.min(r, g, b)
		vmax = math.max(r, g, b)
		delmax = vmax - vmin

		l = (vmax + vmin) / 2

		if delmax ~= 0

			if l < 0.5 then s = delmax / (vmax + vmin)
			else s = delmax / (2 - vmax - vmin)

			delr = (((vmax - r) / 6) + (delmax / 2)) / delmax
			delg = (((vmax - g) / 6) + (delmax / 2)) / delmax
			delb = (((vmax - b) / 6) + (delmax / 2)) / delmax

			if r == vmax then h = delb - delg
			elseif g == vmax then h = (1 / 3) + delr - delb
			elseif b == vmax then h = (2 / 3) + delg - delr

			if h < 0 then h += 1
			elseif h > 1 then h -= 1

		h = round(h * 255, 0)
		s = round(s * 255, 0)
		l = round(l * 255, 0)

		{h, s, l, a}

	-- Converts HSL to RGB
	HSLtoRGB: (hsl using nil) ->

		h, s, l, a = hsl[1], hsl[2], hsl[3], (hsl[4] or 255)
		r, g, b = 0, 0, 0

		if s <= 0 then return {l, l, l, a}

		h = (h / 256) * 6
		s /= 255
		l /= 255

		c = (1 - math.abs(2 * l - 1)) * s
		x = (1 - math.abs(h % 2 - 1)) * c
		m = (l - 0.5 * c)

		if h < 1 then r, g, b = c, x, 0
		elseif h < 2 then r, g, b = x, c, 0
		elseif h < 3 then r, g, b = 0, c, x
		elseif h < 4 then r, g, b = 0, x, c
		elseif h < 5 then r, g, b = x, 0, c
		else r, g, b = c, 0, x

		r = (r + m) * 255
		g = (g + m) * 255
		b = (b + m) * 255

		{r, g, b, a}

	-- Convert a table of R, G, B values (0-255) into a HEX color-code
	RGBtoHEX: (rgb using nil) ->

		outhex = ""

		if rgb[4] then table.remove rgb, 4

		for k, v in ipairs rgb
			h = ""
			while v > 0
				digit = math.fmod(v, 16) + 1
				v = math.floor(v / 16)
				h = string.sub("0123456789ABCDEF", digit, digit) .. h
			outhex ..= h

		outhex

	-- Count backwards by 1 day from an arbitrary date
	dateCountBack: (iyear, imonth, iday using nil) ->

		iday -= 1
		if iday < 1
			imonth -= 1
			if imonth < 1
				iyear -= 1
				imonth = 12
			iday = tonumber os.date('*t', os.time{year: iyear, month: imonth, day: 0})['day']

		iyear, imonth, iday

	-- Discern how far in the past the oldest work entry was logged, down to day-wide resolution
	getOldestTime: (using data) ->

		oldest = os.time!
		for _, v in pairs data
			if oldest < v.time
				oldest = v.time

		oldest

	-- Arrange data based on time of data entry, at a day-wide resolution, and aggregate related hours and entries data
	dataToTimedata: (using data) ->

		timedata = {}

		for k, v in pairs data do
			stamp = os.date('*t', v.time)
			y = tonumber stamp.year
			m = tonumber stamp.month
			d = tonumber stamp.day
			timedata[y] or= {}
			timedata[y][m] or= {}
			timedata[y][m][d] or= {hours: 0, entries: 0}
			timedata[y][m][d].hours += v.hours
			timedata[y][m][d].entries += 1

		timedata

	-- Build tables for every date between the present and the earliest entry, inclusive
	timedataToEradata: (timedata, date using PREFS) ->

		speriods = PREFS.STATS_PERIODS

		eradata = {}
		eradata[p] = {} for _, p in pairs speriods

		iyear = tonumber date.year
		imonth = tonumber date.month
		iday = tonumber date.day

		entries = 0

		-- While the current number of entry-days is smaller than that of the largest metrics period...
		while entries < speriods[#speriods]

			-- Build tables for era-based metrics, one for each STATS_PERIODS entry
			for _, p in ipairs speriods
				if entries < p
					eradata[p][iyear] or= {}
					eradata[p][iyear][imonth] or= {}
					eradata[p][iyear][imonth][iday] or= {hours: 0, entries: 0}
					if (timedata[iyear] ~= nil) and (timedata[iyear][imonth] ~= nil) and (timedata[iyear][imonth][iday] ~= nil)
						eradata[p][iyear][imonth][iday] = {hours: timedata[iyear][imonth][iday].hours, entries: timedata[iyear][imonth][iday].entries}

			iyear, imonth, iday = dateCountBack iyear, imonth, iday
			entries += 1

		eradata

	-- Create scores for every eradata period
	eradataToScoredata: (eradata, date using PREFS) ->

		scoredata = {}

		for _, p in pairs PREFS.STATS_PERIODS

			-- Gather total hours, entries, successful-days, and average-hours from the eradata, for each given era
			scoredata[p] = {hours: 0, entries: 0, successdays: 0}
			for yeark, year in pairs eradata[p]
				for monthk, month in pairs year
					for dayk, day in pairs month
						scoredata[p].hours += day.hours
						scoredata[p].entries += day.entries
						if day.hours > 0
							scoredata[p].successdays += 1
			scoredata[p].avghours = scoredata[p].hours / p

			-- Assign a grade-score to each scoredata period
			scoredata[p].grade = "???"
			for i = 1, #PREFS.GRADE_THRESHOLDS
				if scoredata[p].avghours >= PREFS.GRADE_THRESHOLDS[i][2]
					scoredata[p].grade = PREFS.GRADE_THRESHOLDS[i][1]
					break

			-- Generate Earned Iron Average scores for each scoredata period
			h = scoredata[p].hours / PREFS.GRADE_THRESHOLDS[1][2]
			y = scoredata[p].entries
			z = scoredata[p].successdays
			scoredata[p].hourmean = round((2 * p) / (h + z), 2)
			scoredata[p].houradj = round(((4 * p) * (p - z)) / ((2 * p * h) - (2 * h * z) + (p * z)), 2)
			scoredata[p].entrymean = round((2 * p) / (y + z), 2)
			scoredata[p].entryadj = round(((4 * p) * (p - z)) / ((2 * p * y) - (2 * y * z) + (p * z)), 2)

		scoredata

	-- Translate archived workdata into time-based entries, era-based entries, and scores
	generateMetrics: (date using data) ->

		oldest = getOldestTime!

		timedata = dataToTimedata!
		eradata = timedataToEradata timedata, date
		scoredata = eradataToScoredata eradata, date

		timedata, eradata, scoredata

	-- Archive the data table as a lua file
	updateArchivedData: (using data) ->

		-- Build a Lua-table-file output string from the data table's contents
		outdata = "return {\r\n"
		for _, v in ipairs data
			outdata ..= "\t{"
			outdata ..= "time = " .. v.time .. ","
			outdata ..= " hours = " .. v.hours .. ","
			outdata ..= " task = \"" .. v.task .. "\","
			outdata ..= " project = \"" .. v.project .. "\""
			outdata ..= "},\r\n"
		outdata ..= "}"

		-- Save the Lua file to LOVE2D's save directory
		f = love.filesystem.newFile "data.lua"
		f\open "w"
		f\write outdata
		f\close!

		nil


	-- Remove the most recently-entered task from a given data table, and update the corresponding archived data
	removeLatestTask: (using data) ->

		table.remove data, 1

		updateArchivedData data

		nil

	-- Add a task to the data table, and archive it
	taskToData: (task using data) ->

		-- Make no modifications to any data if the entered task is incomplete
		if (task[1]\len! == 0) or (task[2]\len! == 0) or (tonumber(task[3]) == nil)
			return data

		-- Insert task into data table, with current date information
		outtask = {
			time: tonumber(os.time!)
			hours: tonumber(task[3])
			task: task[1]
			project: task[2]
		}
		table.insert data, 1, outtask

		updateArchivedData data

		nil

	-- Save all global prefs to a 
	savePrefs: (using PREFS) ->

		outprefs = deepTableToString PREFS

		f = love.filesystem.newFile "prefs.lua"
		f\open "w"
		f\write outprefs
		f\close!

		nil

	-- Publish current data as an HTML file
	publishToHTML: (using data, HTML_TEMPLATE, PREFS) ->
		
		date = os.date '*t'
		origdate = date.year .. "-" .. date.month .. "-" .. date.day
		timedata, eradata, scoredata = generateMetrics date

		dechex, decinvhex = getDayColors tonumber(date.year), tonumber(date.month), tonumber(date.day)
		curhex, curinvhex = RGBtoHEX(dechex), RGBtoHEX(decinvhex)

		outhtml = "<div id='holder'>\n"

		outhtml ..= "<div class='textheader'>\n"
		outhtml ..= "<p>\n"
		outhtml ..= "IRON WORK LOG<br/>\n"
		outhtml ..= "Updated " .. PREFS.MONTH_NAMES[tonumber date.month] .. " " .. date.day .. PREFS.DAY_SUFFIXES[tonumber date.day] .. ", " .. date.year .. "<br/>\n"
		outhtml ..= "<br/>\n"
		outhtml ..= "</p>\n"
		outhtml ..= "</div>\n"

		scoretiles = {}

		-- Assemble HTML tiles for all periods' scores
		for k, v in pairs PREFS.STATS_PERIODS

			table.insert(scoretiles, v .. "-DAY:")
			table.insert(scoretiles, "&nbsp;")

			table.insert(scoretiles, "Tasks:")
			table.insert(scoretiles, scoredata[v].entries)

			table.insert(scoretiles, "Work Hours:")
			table.insert(scoretiles, scoredata[v].hours)

			table.insert(scoretiles, "Hours/Day:")
			table.insert(scoretiles, round(scoredata[v].avghours, 2))

			table.insert(scoretiles, "HourIronAvg:")
			table.insert(scoretiles, scoredata[v].hourmean .. "; " .. scoredata[v].houradj)

			table.insert(scoretiles, "EntryIronAvg:")
			table.insert(scoretiles, scoredata[v].entrymean .. "; " .. scoredata[v].entryadj)

			table.insert(scoretiles, "Grade:")
			table.insert(scoretiles, scoredata[v].grade)

			table.insert(scoretiles, "&nbsp;") for i = 1, 2

		for k, v in ipairs scoretiles

			outhtml ..= "<div class='scorechunk'>"
			outhtml ..= "<p>"
			outhtml ..= v
			outhtml ..= "</p>"
			outhtml ..= "</div>\n"

		-- Assemble HTML rows for all data entries, up to the limit for displayed entries
		lastdate = origdate
		for k, v in pairs data

			edate = os.date '*t', v.time
			newdate = edate.year .. "-" .. edate.month .. "-" .. edate.day

			cdate = edate
			if data[k + 1] ~= nil
				cdate = os.date '*t', data[k + 1].time
			nextdate = cdate.year .. "-" .. cdate.month .. "-" .. cdate.day

			dechex, decinvhex = getDayColors tonumber(edate.year), tonumber(edate.month), tonumber(edate.day)
			ehex, einvhex = RGBtoHEX(dechex), RGBtoHEX(decinvhex)
			
			if (newdate ~= lastdate) or (k == 1)
				outhtml ..= "<div class='unitrow' style='border-color:#" .. ehex .. ";'>"
				outhtml ..= "<p>"
				outhtml ..= PREFS.MONTH_NAMES[tonumber edate.month] .. " " .. edate.day .. PREFS.DAY_SUFFIXES[tonumber edate.day] .. ", " .. edate.year

			outhtml ..= "<br/>"
			outhtml ..= v.task .. " on " .. v.project .. " ::: " .. v.hours .. " hours"

			if (nextdate ~= newdate) or (k == PREFS.ENTRIES_LIMIT) or (k == #data)
				outhtml ..= "</p>"
				outhtml ..= "</div>\n"

			if k == PREFS.ENTRIES_LIMIT
				break

			lastdate = newdate

		outhtml ..= "</div>\n"

		-- Find the insertion point in the HTML template, and replace the insertion marker with the HTML-formatted worklog data
		splitleft, splitright = HTML_TEMPLATE\find "IronWorkLogContents"
		outfull = HTML_TEMPLATE\sub(1, splitleft - 1) .. outhtml .. HTML_TEMPLATE\sub(splitright + 1)

		-- Make the composite HTML page into a new file
		f = love.filesystem.newFile "index.html"
		f\open "w"
		f\write outfull
		f\close!

		nil

	-- FTP style.css, index.html, and data.lua to the user's webspace
	uploadFilesToWebspace: (using ftp, ltn12, PREFS) ->

		files = {"style.css", "index.html", "data.lua"}

		for k, v in pairs files
			if love.filesystem.exists v
				fstring, fsize = love.filesystem.read(v)
				f, e = ftp.put {
					host: PREFS.FTP_HOST
					user: PREFS.FTP_USER
					password: PREFS.FTP_PASS
					command: PREFS.FTP_COMMAND
					argument: PREFS.FTP_PATH .. v
					source: ltn12.source.string(fstring)
				}

		nil

	-- Build the pop-up prefs window
	buildPrefsWindow: (using PREFS) ->

		export prefsframe = loveframes.Create "frame"
		prefsframe\SetName "Preferences"
		prefsframe\SetPos 0, 0
		prefsframe\SetSize 800, 600
		prefsframe\SetDraggable false
		prefsframe\ShowCloseButton true

		colorcheck = loveframes.Create "checkbox", prefsframe
		colorcheck\SetPos 50, 50
		colorcheck\SetText "Colorblind Mode"
		colorcheck\SetChecked PREFS.COLORBLIND_MODE

		deftabinput = loveframes.Create "textinput", prefsframe
		deftabinput\SetPos 50, 100
		deftabinput\SetWidth 200
		deftabinput\SetText PREFS.DEFAULT_TAB

		deftabtext = loveframes.Create "text", prefsframe
		deftabtext\SetPos 255, 100
		deftabtext\SetText "Default Metrics Tab"

		htmlfileinput = loveframes.Create "textinput", prefsframe
		htmlfileinput\SetPos 50, 130
		htmlfileinput\SetWidth 200
		htmlfileinput\SetText PREFS.HTML_OUTPUT_FILE

		htmlfiletext = loveframes.Create "text", prefsframe
		htmlfiletext\SetPos 255, 130
		htmlfiletext\SetText "HTML Output File"

		ftphostinput = loveframes.Create "textinput", prefsframe
		ftphostinput\SetPos 50, 160
		ftphostinput\SetWidth 200
		ftphostinput\SetText PREFS.FTP_HOST

		ftphosttext = loveframes.Create "text", prefsframe
		ftphosttext\SetPos 255, 160
		ftphosttext\SetText "FTP Host"

		ftpuserinput = loveframes.Create "textinput", prefsframe
		ftpuserinput\SetPos 50, 190
		ftpuserinput\SetWidth 200
		ftpuserinput\SetText PREFS.FTP_USER

		ftpusertext = loveframes.Create "text", prefsframe
		ftpusertext\SetPos 255, 190
		ftpusertext\SetText "FTP User"

		ftppassinput = loveframes.Create "textinput", prefsframe
		ftppassinput\SetPos 50, 220
		ftppassinput\SetWidth 200
		ftppassinput\SetMasked true
		ftppassinput\SetMaskChar "*"
		ftppassinput\SetText PREFS.FTP_PASS

		ftppasstext = loveframes.Create "text", prefsframe
		ftppasstext\SetPos 255, 220
		ftppasstext\SetText "FTP Password"

		ftppathinput = loveframes.Create "textinput", prefsframe
		ftppathinput\SetPos 50, 250
		ftppathinput\SetWidth 200
		ftppathinput\SetText PREFS.FTP_PATH

		ftppathtext = loveframes.Create "text", prefsframe
		ftppathtext\SetPos 255, 250
		ftppathtext\SetText "FTP Path"

		ftpcommandinput = loveframes.Create "textinput", prefsframe
		ftpcommandinput\SetPos 50, 280
		ftpcommandinput\SetWidth 200
		ftpcommandinput\SetText PREFS.FTP_COMMAND

		ftpcommandtext = loveframes.Create "text", prefsframe
		ftpcommandtext\SetPos 255, 280
		ftpcommandtext\SetText "FTP Command"

		entrycolsinput = loveframes.Create "textinput", prefsframe
		entrycolsinput\SetPos 50, 310
		entrycolsinput\SetWidth 200
		entrycolsinput\SetText PREFS.ENTRIES_COLUMNS

		entrycolstext = loveframes.Create "text", prefsframe
		entrycolstext\SetPos 255, 310
		entrycolstext\SetText "Entries-Panel Columns"

		entrylimitinput = loveframes.Create "textinput", prefsframe
		entrylimitinput\SetPos 50, 340
		entrylimitinput\SetWidth 200
		entrylimitinput\SetText PREFS.ENTRIES_LIMIT

		entrylimittext = loveframes.Create "text", prefsframe
		entrylimittext\SetPos 255, 340
		entrylimittext\SetText "Max Entries-Panel Items"

		applybutton = loveframes.Create "button", prefsframe
		applybutton\SetPos 490, 495
		applybutton\SetSize 150, 100
		applybutton\SetText "Apply"

		applybutton.OnClick = (object using nil) ->

			cblnd = colorcheck\GetChecked!
			dtab = deftabinput\GetText!
			hfile = htmlfileinput\GetText!
			ecols = entrycolsinput\GetText!
			elim = entrylimitinput\GetText!
			fhost = ftphostinput\GetText!
			fuser = ftpuserinput\GetText!
			fpass = ftppassinput\GetText!
			fpath = ftppathinput\GetText!
			fcomm = ftpcommandinput\GetText!

			-- Sanitize the new default-tab number
			dtab = (string.match(dtab, '%d+') and dtab) or 1
			dtab = tonumber dtab
			dtab = math.min dtab, #PREFS.STATS_PERIODS

			-- Put a ".html" onto the HTML filename if one isn't there already
			if hfile\sub(-5) ~= ".html"
				hfile ..= ".html"

			-- Sanitize the new entries-panel GUI limits
			ecols = (string.match(ecols, '%d+') and ecols) or 30
			ecols = tonumber ecols
			ecols = math.min ecols, 50
			elim = (string.match(elim, '%d+') and elim) or 500
			elim = tonumber elim
			elim = math.min elim, 1000

			-- Pass new data into prefs
			PREFS.COLORBLIND_MODE = cblnd
			PREFS.DEFAULT_TAB = dtab
			PREFS.HTML_OUTPUT_FILE = hfile
			PREFS.ENTRIES_COLUMNS = ecols
			PREFS.ENTRIES_LIMIT = elim
			PREFS.FTP_HOST = fhost
			PREFS.FTP_USER = fuser
			PREFS.FTP_PASS = fpass
			PREFS.FTP_PATH = fpath
			PREFS.FTP_COMMAND = fcomm

			savePrefs!

			prefsframe\Remove!
			clearDynamicGUI!

			updateDataAndGUI!

			nil

		closebutton = loveframes.Create "button", prefsframe
		closebutton\SetPos 645, 495
		closebutton\SetSize 150, 100
		closebutton\SetText "Close"

		closebutton.OnClick = (object using nil) ->
			prefsframe\Remove!
			nil

		nil

	-- Create input window
	buildInputFrame: (using PREFS) ->

		inputframe = loveframes.Create "frame"
		inputframe\SetName "Input"
		inputframe\SetPos 0, 0
		inputframe\SetSize 200, 300
		inputframe\SetDraggable false
		inputframe\ShowCloseButton false

		uinput = {}
		for k, v in pairs PREFS.INPUT_NAMES

			uinput[k] = loveframes.Create "textinput", inputframe
			uinput[k]\SetPos 5, (30 * k)
			uinput[k]\SetWidth 190
			uinput[k]\SetEditable true
			uinput[k]\SetText v
			uinput[k]\SetTabReplacement ""

			uinput[k].OnFocusGained = (object using nil) ->
				for kk, vv in pairs PREFS.INPUT_NAMES
					if #tostring(uinput[kk]\GetText!) == 0
						uinput[kk]\SetText vv
				object\SetText ""
				nil

			uinput[k].OnFocusLost = (object using nil) ->
				if #tostring(object\GetText!) == 0
					object\SetText v
				nil

			uinput[k].OnEnter = (object using nil) ->
				for kk, vv in pairs PREFS.INPUT_NAMES
					IN_TASK[kk] = object\GetText!
					object\SetText vv
				data = taskToData data, IN_TASK
				clearDynamicGUI!
				updateDataAndGUI!
				nil

		submitbutton = loveframes.Create "button", inputframe
		submitbutton\SetPos 10, 120
		submitbutton\SetSize 180, 60
		submitbutton\SetText "Submit"

		submitbutton.OnClick = (object using nil) ->
			for k, v in pairs PREFS.INPUT_NAMES
				IN_TASK[k] = uinput[k]\GetText!
				uinput[k]\SetText v
			data = taskToData IN_TASK
			clearDynamicGUI!
			updateDataAndGUI!
			nil

		removebutton = loveframes.Create "button", inputframe
		removebutton\SetPos 10, 185
		removebutton\SetSize 180, 20
		removebutton\SetText "Delete Latest Entry"

		removebutton.OnClick = (object using nil) ->
			removeLatestTask!
			clearDynamicGUI!
			updateDataAndGUI!
			nil
		
		publishbutton = loveframes.Create "button", inputframe
		publishbutton\SetPos 10, 215
		publishbutton\SetSize 180, 20
		publishbutton\SetText "Publish To HTML"

		publishbutton.OnClick = (object using nil) ->
			for k, v in pairs PREFS.INPUT_NAMES
				IN_TASK[k] = uinput[k]\GetText!
				uinput[k]\SetText v
			publishToHTML!
			nil

		uploadbutton = loveframes.Create "button", inputframe
		uploadbutton\SetPos 10, 240
		uploadbutton\SetSize 180, 20
		uploadbutton\SetText "FTP To Web"
		
		uploadbutton.OnClick = (object using nil) ->
			uploadFilesToWebspace!
			nil

		refreshbutton = loveframes.Create "button", inputframe
		refreshbutton\SetPos 10, 270
		refreshbutton\SetSize 85, 20
		refreshbutton\SetText "Refresh"

		refreshbutton.OnClick = (object using nil) ->
			clearDynamicGUI!
			updateDataAndGUI!
			nil

		prefsbutton = loveframes.Create "button", inputframe
		prefsbutton\SetPos 105, 270
		prefsbutton\SetSize 85, 20
		prefsbutton\SetText "Preferences"

		prefsbutton.OnClick = (object using nil) ->
			buildPrefsWindow!
			nil

		nil

	-- Create metrics window
	buildMetricsFrame: (using nil) ->

		export metricsframe = loveframes.Create "frame"
		metricsframe\SetName "Metrics"
		metricsframe\SetPos 200, 0
		metricsframe\SetSize 600, 300
		metricsframe\SetDraggable false
		metricsframe\ShowCloseButton false

		nil

	-- Create metrics tabs, and their contents
	buildMetricsTabs: (eradata, scoredata, date, frame using PREFS, SMALL_IRON_FONT) ->
		
		metricstabs = loveframes.Create "tabs", frame
		metricstabs\SetPos 5, 30
		metricstabs\SetSize 590, 265
		metricstabs\SetPadding 0

		tabimage = "tabimage.png"

		for k, p in pairs PREFS.STATS_PERIODS

			panel = loveframes.Create "panel", metricstabs
			panel.Draw = (object using nil) ->
				love.graphics.setColor(30, 30, 30, 255)
				love.graphics.rectangle("fill", object\GetX!, object\GetY!, object\GetWidth!, object\GetHeight!)
				nil

			buildMetricsGrid eradata[p], p, date, panel

			stext = "Hours Worked: \n " .. scoredata[p].hours .. " : " .. round(scoredata[p].avghours, 2) .. "/day"
			stext ..= " \n  \n Hour Scores: \n " .. scoredata[p].hourmean .. ", " .. scoredata[p].houradj
			stext ..= " \n  \n Entry Scores: \n " .. scoredata[p].entrymean .. ", " .. scoredata[p].entryadj
			stext ..= " \n  \n Grade: " .. scoredata[p].grade

			scoretext = loveframes.Create "text", panel
			scoretext\SetPos 360, 5
			scoretext\SetSize 230, 260
			scoretext\SetFont SMALL_IRON_FONT
			scoretext\SetIgnoreNewlines false
			scoretext\SetText stext

			metricstabs\AddTab (p .. "-DAY"), panel, (p .. "-DAY"), tabimage

		metricstabs\SwitchToTab PREFS.DEFAULT_TAB

		nil

	-- Build the metrics grid within a given metrics-period tab
	buildMetricsGrid: (pdata, period, date, frame using PREFS) ->

		grid = loveframes.Create "grid", frame
		grid\SetPos 0, 0
		grid\SetColumns period
		grid\SetRows #PREFS.BAR_THRESHOLDS
		grid\SetCellWidth 350 / period
		grid\SetCellHeight 240 / #PREFS.BAR_THRESHOLDS
		grid\SetCellPadding 0
		grid\SetItemAutoSize true

		iyear = tonumber date.year
		imonth = tonumber date.month
		iday = tonumber date.day

		-- Draw metrics bars and score text
		for p = 1, period

			for y, thresh in pairs PREFS.BAR_THRESHOLDS

				fullhex, invhex = getDayColors iyear, imonth, iday
				hex = {60, 60, 60, 255}
				invhex = (PREFS.COLORBLIND_MODE and {220, 220, 220, 255}) or invhex
				exists = false
				if (pdata[iyear] ~= nil) and (pdata[iyear][imonth] ~= nil) and (pdata[iyear][imonth][iday] ~= nil)
					exists = true
					if pdata[iyear][imonth][iday].hours >= thresh
						hex = (PREFS.COLORBLIND_MODE and {160, 160, 160, 255}) or fullhex
						invhex = (PREFS.COLORBLIND_MODE and {20, 20, 20, 255}) or invhex

				f = loveframes.Create "frame"
				f\SetName ""
				f\SetSize 20, 20
				f\SetDraggable false
				f\ShowCloseButton false
				f.Draw = (object using nil) ->
					love.graphics.setColor(unpack hex)
					love.graphics.rectangle("fill", object\GetX!, object\GetY!, object\GetWidth!, object\GetHeight!)
					nil

				tip = loveframes.Create "tooltip"
				tip\SetObject f
				tip\SetPadding 10
				tip\SetText {
					{color: invhex},
					PREFS.MONTH_NAMES[imonth] .. " " .. iday .. PREFS.DAY_SUFFIXES[iday] .. ", " .. iyear .. " ::: " .. ((exists and pdata[iyear][imonth][iday].hours) or "0") .. " hours worked"
				}
				tip.Draw = (object using nil) ->
					love.graphics.setColor(unpack hex)
					love.graphics.rectangle("fill", object\GetX!, object\GetY!, object\GetWidth!, object\GetHeight!)
					nil

				grid\AddItem f, y, p

			iyear, imonth, iday = dateCountBack iyear, imonth, iday

		nil

	-- Create entries window
	buildEntriesFrame: (using nil) ->

		export entriesframe = loveframes.Create "frame"
		entriesframe\SetName "Entries"
		entriesframe\SetPos 0, 300
		entriesframe\SetSize 800, 300
		entriesframe\SetDraggable false
		entriesframe\ShowCloseButton false

		nil

	-- Create entries grid, and associated tooltips, and populate them with the relevant data
	buildEntriesList: (container using data, PREFS) ->

		listscroll = loveframes.Create "list", container
		listscroll\EnableHorizontalStacking true
		listscroll\SetPos 0, 35
		listscroll\SetSize 800, 265

		cols = PREFS.ENTRIES_COLUMNS
		cwidth = container\GetWidth! / cols

		for k, v in pairs data

			-- If there are more data entries than ENTRIES_LIMIT, stop rendering past that point
			if k > PREFS.ENTRIES_LIMIT
				break

			-- Translate a given entry's timestamp into a date
			d = os.date('*t', v.time)

			-- Translate a given date into color values
			hex, invhex = getDayColors tonumber(d.year), tonumber(d.month), tonumber(d.day)

			-- Make task data human-readable for tooltips
			fulldate = PREFS.MONTH_NAMES[d.month] .. " " .. d.day .. PREFS.DAY_SUFFIXES[d.day] .. ", " .. d.year
			fulltime = string.rep("0", 2 - #tostring(d.hour)) .. d.hour .. ":" .. string.rep("0", 2 - #tostring(d.min)) .. d.min
			task = v.task .. " on " .. v.project .. " for " .. v.hours .. " hours"

			-- Create an entry's colorbox
			frame = loveframes.Create "frame", listscroll
			frame\SetName ""
			frame\SetSize cwidth, cwidth
			frame\SetDraggable false
			frame\ShowCloseButton false
			frame.Draw = (object using nil) ->
				love.graphics.setColor(unpack hex)
				love.graphics.rectangle("fill", object\GetX!, object\GetY!, object\GetWidth!, object\GetHeight!)
				nil

			-- Create a colorbox's tooltip, containing a summary of the unit of work it represents
			tip = loveframes.Create "tooltip", frame
			tip\SetObject frame
			tip\SetFollowCursor false
			tip\SetX container\GetX!
			tip\SetY container\GetY!
			tip\SetPadding 10
			tip\SetText {
				{color: invhex},
				fulldate .. " :: " .. fulltime .. " :: " .. task
			}
			tip.Draw = (object using nil) ->
				love.graphics.setColor(hex[1], hex[2], hex[3], 255)
				love.graphics.rectangle("fill", object\GetX!, object\GetY!, object\GetWidth!, object\GetHeight!)
				nil

			-- Add the colorbox and tooltip to the grid
			listscroll\AddItem frame

		nil

	-- Clear current dynamic GUI elements
	clearDynamicGUI: (using metricsframe, entriesframe) ->

		metricsframe\Remove!
		entriesframe\Remove!

		nil

	-- Update data tables, and build an updated GUI
	updateDataAndGUI: (using nil) ->

		date = os.date '*t'

		timedata, eradata, scoredata = generateMetrics date

		buildMetricsFrame!
		buildMetricsTabs eradata, scoredata, date, metricsframe

		buildEntriesFrame!
		buildEntriesList entriesframe

		nil

}
