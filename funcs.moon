
return {

	-- Recursively copy all sub-tables and sub-items, as values instead of references. Invoke as: newtable = deepCopy(oldtable, {})
	deepCopy: (t = {}, t2 = {} using nil) ->
		for k, v in pairs t
			switch type v
				when "table" then t2[k] = deepCopy(v)
				else t2[k] = v
		t2

	-- Round number num, at decimal place idp
	round: (num, idp = 0 using nil) ->
		mult = 10 ^ idp
		math.floor(num * mult + 0.5) / mult

	-- Convert a table's contents to globals
	tableToGlobals: (tab using nil) ->
		_G[k] = v for k, v in pairs tab
		nil

	-- Convert a date to a HEX value
	dateToColor: (dtab using nil) ->
		out = {}
		for k, v in ipairs dtab
			out[k] = round(v * 21.25, 0)
		out

	-- Get two complementary colors based on the current date
	getDayColors: (dyear, dmonth, dday using COLORBLIND_MODE) ->

		hex = dateToColor {dyear, dmonth, dday}
		if COLORBLIND_MODE
			greyhex = math.floor((hex[1] + hex[2] + hex[3]) / 3)
			hex[i] = greyhex for i = 1, 3
		invhex = [(hex[i] + 127) % 256 for i = 1, 3]

		hex, invhex

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
	timedataToEradata: (timedata, date using STATS_PERIODS) ->

		eradata = {}
		eradata[p] = {} for _, p in pairs STATS_PERIODS

		iyear = tonumber date.year
		imonth = tonumber date.month
		iday = tonumber date.day

		-- While the current time-difference is shorter than that of the oldest entry...
		while #eradata[STATS_PERIODS[#STATS_PERIODS]] < STATS_PERIODS[#STATS_PERIODS]

			-- Build tables for era-based metrics, one for each STATS_PERIODS entry
			for _, p in ipairs STATS_PERIODS
				if #eradata[p] < p
					eradata[p][iyear] or= {}
					eradata[p][iyear][imonth] or= {}
					eradata[p][iyear][imonth][iday] or= {hours: 0, entries: 0}
					if (timedata[iyear] ~= nil) and (timedata[iyear][imonth] ~= nil) and (timedata[iyear][imonth][iday] ~= nil)
						eradata[p][iyear][imonth][iday] = {hours: timedata[iyear][imonth][iday].hours, entries: timedata[iyear][imonth][iday].entries}

			iyear, imonth, iday = dateCountBack iyear, imonth, iday

		eradata

	-- Create scores for every eradata period
	eradataToScoredata: (eradata, date using STATS_PERIODS, GRADE_THRESHOLDS) ->

		scoredata = {}

		for _, p in pairs STATS_PERIODS

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
			for i = 1, #GRADE_THRESHOLDS
				if scoredata[p].avghours >= GRADE_THRESHOLDS[i][2]
					scoredata[p].grade = GRADE_THRESHOLDS[i][1]
					break

			-- Generate Earned Iron Average scores for each scoredata period
			h = scoredata[p].hours / GRADE_THRESHOLDS[1][2]
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
		f = love.filesystem.newFile("data.lua")
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

	-- TODO: Publish current data as an HTML file
	publishToHTML: (using nil) ->

		nil

	-- TODO: FTP all current UPLOAD_FILES to the user's webspace
	uploadFilesToWebspace: (using UPLOAD_FILES, FTP_PREFS) ->

		nil

	-- Create input window
	buildInputFrame: (using INPUT_NAMES) ->

		-- FIX THIS		
		inputframe = loveframes.Create("frame")
		inputframe\SetName "Input"
		inputframe\SetPos 0, 0
		inputframe\SetSize 200, 300
		inputframe\SetDraggable false
		inputframe\ShowCloseButton false

		uinput = {}
		for k, v in pairs INPUT_NAMES
			uinput[k] = loveframes.Create("textinput", inputframe)
			uinput[k]\SetPos 5, (30 * k)
			uinput[k]\SetWidth 190
			uinput[k]\SetText v
			uinput[k]\SetTabReplacement ""
			uinput[k].OnFocusGained = (object using nil) ->
				for kk, vv in pairs INPUT_NAMES
					if #tostring(uinput[kk]\GetText!) == 0
						uinput[kk]\SetText vv
				uinput[k]\SetText ""
				nil
			uinput[k].OnFocusLost = (object using nil) ->
				if #tostring(uinput[k]\GetText!) == 0
					uinput[k]\SetText v
				nil
			uinput[k].OnEnter = (object using nil) ->
				for kk, vv in pairs INPUT_NAMES
					IN_TASK[kk] = uinput[kk]\GetText!
					uinput[kk]\SetText vv
				data = taskToData data, IN_TASK
				clearDynamicGUI!
				updateDataAndGUI!
				nil

		submitbutton = loveframes.Create("button", inputframe)
		submitbutton\SetPos 10, 120
		submitbutton\SetWidth 180
		submitbutton\SetHeight 60
		submitbutton\SetText "Submit"

		submitbutton.OnClick = (object using nil) ->
			for k, v in pairs INPUT_NAMES
				IN_TASK[k] = uinput[k]\GetText!
				uinput[k]\SetText v
			data = taskToData IN_TASK
			clearDynamicGUI!
			updateDataAndGUI!
			nil

		removebutton = loveframes.Create("button", inputframe)
		removebutton\SetPos 10, 185
		removebutton\SetWidth 180
		removebutton\SetHeight 25
		removebutton\SetText "Delete Latest Entry"

		removebutton.OnClick = (object using nil) ->
			removeLatestTask!
			clearDynamicGUI!
			updateDataAndGUI!
			nil
		
		publishbutton = loveframes.Create("button", inputframe)
		publishbutton\SetPos 10, 225
		publishbutton\SetWidth 180
		publishbutton\SetHeight 25
		publishbutton\SetText "Publish To HTML"

		publishbutton.OnClick = (object using nil) ->
			for k, v in pairs INPUT_NAMES
				IN_TASK[k] = uinput[k]\GetText!
				uinput[k]\SetText v
			publishToHTML!
			nil

		uploadbutton = loveframes.Create("button", inputframe)
		uploadbutton\SetPos 10, 255
		uploadbutton\SetWidth 180
		uploadbutton\SetHeight 25
		uploadbutton\SetText "FTP To Web"
		
		uploadbutton.OnClick = (object using nil) ->
			uploadFilesToWebspace!
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
	buildMetricsTabs: (eradata, scoredata, date, frame using STATS_PERIODS, DEFAULT_TAB) ->

		metricstabs = loveframes.Create "tabs", frame
		metricstabs\SetPos 5, 30
		metricstabs\SetSize 590, 265
		metricstabs\SetPadding 0

		panels = {}
		for k, p in ipairs STATS_PERIODS

			panels[k] = loveframes.Create "panel", metricstabs
			panels[k].Draw = (object using nil) ->
				love.graphics.setColor(30, 30, 30, 255)
				love.graphics.rectangle("fill", object\GetX!, object\GetY!, object\GetWidth!, object\GetHeight!)
				nil

			buildMetricsGrid eradata[p], p, date, panels[k]

			gradetext = loveframes.Create "text", panels[k]
			gradetext\SetPos 400, 35
			gradetext\SetText({255, 255, 255, "Grade: " .. scoredata[p].grade})

			hourtext = loveframes.Create "text", panels[k]
			hourtext\SetPos 400, 100
			hourtext\SetText({255, 255, 255, "Hour Scores: " .. scoredata[p].hourmean .. " - " .. scoredata[p].houradj})

			entrytext = loveframes.Create "text", panels[k]
			entrytext\SetPos 400, 165
			entrytext\SetText({255, 255, 255, "Entry Scores: " .. scoredata[p].entrymean .. " - " .. scoredata[p].entryadj})

			metricstabs\AddTab (p .. "-DAY"), panels[k], _, _

		metricstabs\SwitchToTab DEFAULT_TAB

		nil

	-- Build the metrics grid within a given metrics-period tab
	buildMetricsGrid: (pdata, period, date, frame using GRADE_THRESHOLDS, BAR_THRESHOLDS, COLORBLIND_MODE, MONTH_NAMES, DAY_SUFFIXES) ->

		grid = loveframes.Create "grid", frame
		grid\SetPos 0, 0
		grid\SetColumns period
		grid\SetRows #BAR_THRESHOLDS
		grid\SetCellWidth 350 / period
		grid\SetCellHeight 240 / #BAR_THRESHOLDS
		grid\SetCellPadding 0
		grid\SetItemAutoSize true

		emptyhex = {60, 60, 60}

		iyear = tonumber date.year
		imonth = tonumber date.month
		iday = tonumber date.day

		-- Draw metrics bars and score text
		for p = 1, period

			for y, thresh in pairs BAR_THRESHOLDS

				fullhex, fullinvhex = getDayColors iyear, imonth, iday
				hex = emptyhex
				invhex = fullhex
				if pdata[iyear][imonth][iday].hours >= thresh
					hex = fullhex
					invhex = fullinvhex

				f = loveframes.Create "frame"
				f\SetName ""
				f\SetSize 20, 20
				f\SetDraggable false
				f\ShowCloseButton false
				f.Draw = (object using nil) ->
					love.graphics.setColor(hex[1], hex[2], hex[3], 255)
					love.graphics.rectangle("fill", object\GetX!, object\GetY!, object\GetWidth!, object\GetHeight!)
					nil

				tip = loveframes.Create "tooltip"
				tip\SetObject f
				tip\SetPadding 10
				tip\SetText {{0, 0, 0}, MONTH_NAMES[imonth] .. " " .. iday .. DAY_SUFFIXES[iday], ", " .. iyear .. " ::: " .. pdata[iyear][imonth][iday].hours .. " hours worked"}
				tip.Draw = (object using nil) ->
					love.graphics.setColor(invhex[1], invhex[2], invhex[3], 255)
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
		entriesframe\SetSize 800, 400
		entriesframe\SetDraggable false
		entriesframe\ShowCloseButton false

		nil

	-- Create entries grid, and associated tooltips, and populate them with the relevant data
	buildEntriesGrid: (data, container using COLORBLIND_MODE, MONTH_NAMES, DAY_SUFFIXES, ENTRIES_COLUMNS) ->

		cols = ENTRIES_COLUMNS
		cwidth = (container\GetWidth! / cols) - 2

		grid = loveframes.Create "grid", container
		grid\SetPos 0, 30
		grid\SetColumns cols
		grid\SetRows math.ceil(#data / cols)
		grid\SetCellWidth cwidth
		grid\SetCellHeight cwidth
		grid\SetCellPadding 1
		grid\SetItemAutoSize true

		for k, v in pairs data

			-- Translate a given entry's timestamp into a date
			d = os.date('*t', v.time)

			-- Translate a given date into color values
			hex, invhex = getDayColors d.year, d.month, d.day

			-- Make task data human-readable for tooltips
			fulldate = MONTH_NAMES[d.month] .. " " .. d.day .. DAY_SUFFIXES[d.day] .. ", " .. d.year
			fulltime = string.rep("0", 2 - #tostring(d.hour)) .. d.hour .. ":" .. string.rep("0", 2 - #tostring(d.min)) .. d.min
			task = v.task .. " on " .. v.project .. " for " .. v.hours .. " hours"

			-- Create an entry's colorbox
			frame = loveframes.Create "frame", grid
			frame\SetName ""
			frame\SetSize 20, 20
			frame\SetDraggable false
			frame\ShowCloseButton false
			frame.Draw = (object using nil) ->
				love.graphics.setColor(hex[1], hex[2], hex[3], 255)
				love.graphics.rectangle("fill", object\GetX!, object\GetY!, object\GetWidth!, object\GetHeight!)
				nil

			-- Create a colorbox's tooltip, containing a summary of the unit of work it represents
			tip = loveframes.Create "tooltip", frame
			tip\SetObject frame
			tip\SetFollowCursor false
			tip\SetX container\GetX!
			tip\SetY container\GetY!
			tip\SetPadding 10
			tip\SetText {invhex, fulldate .. " :: " .. fulltime .. " :: " .. task}
			tip.Draw = (object using nil) ->
				love.graphics.setColor(hex[1], hex[2], hex[3], 255)
				love.graphics.rectangle("fill", object\GetX!, object\GetY!, object\GetWidth!, object\GetHeight!)
				nil

			-- Add the colorbox and tooltip to the grid
			grid\AddItem frame, math.floor((k - 1) / cols) + 1, ((k - 1) % cols) + 1

		nil

	-- Clear current dynamic GUI elements
	clearDynamicGUI: (using metricsframe, entriesframe) ->

		metricsframe\Remove!
		entriesframe\Remove!

		nil

	-- Update data tables, and build an updated GUI
	updateDataAndGUI: (using nil) ->

		date = os.date '*t'

		_, eradata, scoredata = generateMetrics date

		buildMetricsFrame!
		buildMetricsTabs eradata, scoredata, date, metricsframe

		buildEntriesFrame!
		buildEntriesGrid data, entriesframe

		nil

}
