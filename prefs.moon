
return {
	
	COLORBLIND_MODE: false

	MAX_ENTRY_HISTORY: 100

	STATS_PERIODS: {
		7
		15
		30
	}

	DEFAULT_TAB: 1

	STYLESHEET_FILE: "style.css"
	HTML_OUTPUT_FILE: "index.html"

	UPLOAD_FILES: {
		"data.lua" -- It's wise to backup your data file, but this line isn't absolutely required
		"style.css"
		"index.html"
	}

	FTP_PREFS: {
		HOST: "your-ftp-address"
		USER: "your-ftp-username"
		PASS: "your-ftp-password"
		PATH: "/folder/"
		COMMAND: "stor"
	}

	GRADE_THRESHOLDS: {
		{"A+", 5.7142}
		{"A", 5}
		{"A-", 4.5714}
		{"B+", 4.2857}
		{"B", 4}
		{"B-", 3.7142}
		{"C+", 3.4285}
		{"C", 3.1428}
		{"C-", 2.8571}
		{"D+", 2.4285}
		{"D", 2}
		{"D-", 1.5714}
		{"F", 0}
	}

	BAR_THRESHOLDS: {
		10
		9
		8
		7
		6
		5
		4
		3
		2
		1
	}

	ENTRIES_COLUMNS: 30

	INPUT_NAMES: {
		"Task"
		"Project"
		"Hours"
	}

	MONTH_NAMES: {
		"January"
		"February"
		"March"
		"April"
		"May"
		"June"
		"July"
		"August"
		"September"
		"October"
		"November"
		"December"
	}

	DAY_SUFFIXES: {
		"st", "nd", "rd", "th", "th", -- 1st to 5th
		"th", "th", "th", "th", "th", -- 6th to 10th
		"th", "th", "th", "th", "th", -- 11th to 15th
		"th", "th", "th", "th", "th", -- 16th to 20th
		"st", "nd", "rd", "th", "th", -- 21st to 25th
		"th", "th", "th", "th", "th", -- 26th to 30th
		"st", -- 31st
	}

}