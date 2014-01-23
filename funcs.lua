return {
  deepCopy = function(t, t2)
    if t == nil then
      t = { }
    end
    if t2 == nil then
      t2 = { }
    end
    for k, v in pairs(t) do
      local _exp_0 = type(v)
      if "table" == _exp_0 then
        t2[k] = deepCopy(v)
      else
        t2[k] = v
      end
    end
    return t2
  end,
  deepTableToString = function(t, depth)
    if t == nil then
      t = { }
    end
    if depth == nil then
      depth = 0
    end
    local out = ""
    local dplus = depth + 1
    for k, v in pairs(t) do
      local putk = "[" .. k .. "]"
      if type(k) == "string" then
        putk = "[\"" .. k .. "\"]"
      end
      if type(v) == "table" then
        out = out .. (string.rep("\t", dplus) .. putk .. " = {\n")
        out = out .. deepTableToString(v, dplus)
        out = out .. (string.rep("\t", dplus) .. "},\n")
      else
        out = out .. (string.rep("\t", dplus) .. putk .. " = " .. (((type(v) == "string") and ("\"" .. v .. "\"")) or tostring(v)) .. ",\n")
      end
    end
    if depth == 0 then
      out = "return {\n\n" .. out .. "\n\n}\n"
    end
    return out
  end,
  round = function(num, idp)
    if idp == nil then
      idp = 0
    end
    local mult = 10 ^ idp
    return math.floor((num * mult) + 0.5) / mult
  end,
  tableToGlobals = function(tab)
    for k, v in pairs(tab) do
      _G[k] = v
    end
    return nil
  end,
  dateToColor = function(dtab)
    local out = { }
    for k, v in ipairs(dtab) do
      out[k] = round(v * 21.25, 0) % 256
    end
    return out
  end,
  getDayColors = function(dyear, dmonth, dday)
    local hex = dateToColor({
      dyear,
      dmonth,
      dday
    })
    if PREFS.COLORBLIND_MODE then
      local greyhex = math.floor((hex[1] + hex[2] + hex[3]) / 3)
      for i = 1, 3 do
        hex[i] = greyhex
      end
    end
    local invhex
    do
      local _accum_0 = { }
      local _len_0 = 1
      for i = 1, 3 do
        _accum_0[_len_0] = (hex[i] + 127) % 256
        _len_0 = _len_0 + 1
      end
      invhex = _accum_0
    end
    return hex, invhex
  end,
  dateCountBack = function(iyear, imonth, iday)
    iday = iday - 1
    if iday < 1 then
      imonth = imonth - 1
      if imonth < 1 then
        iyear = iyear - 1
        imonth = 12
      end
      iday = tonumber(os.date('*t', os.time({
        year = iyear,
        month = imonth,
        day = 0
      }))['day'])
    end
    return iyear, imonth, iday
  end,
  getOldestTime = function()
    local oldest = os.time()
    for _, v in pairs(data) do
      if oldest < v.time then
        oldest = v.time
      end
    end
    return oldest
  end,
  dataToTimedata = function()
    local timedata = { }
    for k, v in pairs(data) do
      local stamp = os.date('*t', v.time)
      local y = tonumber(stamp.year)
      local m = tonumber(stamp.month)
      local d = tonumber(stamp.day)
      timedata[y] = timedata[y] or { }
      timedata[y][m] = timedata[y][m] or { }
      timedata[y][m][d] = timedata[y][m][d] or {
        hours = 0,
        entries = 0
      }
      timedata[y][m][d].hours = timedata[y][m][d].hours + v.hours
      timedata[y][m][d].entries = timedata[y][m][d].entries + 1
    end
    return timedata
  end,
  timedataToEradata = function(timedata, date)
    local speriods = PREFS.STATS_PERIODS
    local eradata = { }
    for _, p in pairs(speriods) do
      eradata[p] = { }
    end
    local iyear = tonumber(date.year)
    local imonth = tonumber(date.month)
    local iday = tonumber(date.day)
    local entries = 0
    while entries < speriods[#speriods] do
      for _, p in ipairs(speriods) do
        if entries < p then
          eradata[p][iyear] = eradata[p][iyear] or { }
          eradata[p][iyear][imonth] = eradata[p][iyear][imonth] or { }
          eradata[p][iyear][imonth][iday] = eradata[p][iyear][imonth][iday] or {
            hours = 0,
            entries = 0
          }
          if (timedata[iyear] ~= nil) and (timedata[iyear][imonth] ~= nil) and (timedata[iyear][imonth][iday] ~= nil) then
            eradata[p][iyear][imonth][iday] = {
              hours = timedata[iyear][imonth][iday].hours,
              entries = timedata[iyear][imonth][iday].entries
            }
          end
        end
      end
      iyear, imonth, iday = dateCountBack(iyear, imonth, iday)
      entries = entries + 1
    end
    return eradata
  end,
  eradataToScoredata = function(eradata, date)
    local scoredata = { }
    for _, p in pairs(PREFS.STATS_PERIODS) do
      scoredata[p] = {
        hours = 0,
        entries = 0,
        successdays = 0
      }
      for yeark, year in pairs(eradata[p]) do
        for monthk, month in pairs(year) do
          for dayk, day in pairs(month) do
            scoredata[p].hours = scoredata[p].hours + day.hours
            scoredata[p].entries = scoredata[p].entries + day.entries
            if day.hours > 0 then
              scoredata[p].successdays = scoredata[p].successdays + 1
            end
          end
        end
      end
      scoredata[p].avghours = scoredata[p].hours / p
      scoredata[p].grade = "???"
      for i = 1, #PREFS.GRADE_THRESHOLDS do
        if scoredata[p].avghours >= PREFS.GRADE_THRESHOLDS[i][2] then
          scoredata[p].grade = PREFS.GRADE_THRESHOLDS[i][1]
          break
        end
      end
      local h = scoredata[p].hours / PREFS.GRADE_THRESHOLDS[1][2]
      local y = scoredata[p].entries
      local z = scoredata[p].successdays
      scoredata[p].hourmean = round((2 * p) / (h + z), 2)
      scoredata[p].houradj = round(((4 * p) * (p - z)) / ((2 * p * h) - (2 * h * z) + (p * z)), 2)
      scoredata[p].entrymean = round((2 * p) / (y + z), 2)
      scoredata[p].entryadj = round(((4 * p) * (p - z)) / ((2 * p * y) - (2 * y * z) + (p * z)), 2)
    end
    return scoredata
  end,
  generateMetrics = function(date)
    local oldest = getOldestTime()
    local timedata = dataToTimedata()
    local eradata = timedataToEradata(timedata, date)
    local scoredata = eradataToScoredata(eradata, date)
    return timedata, eradata, scoredata
  end,
  updateArchivedData = function()
    local outdata = "return {\r\n"
    for _, v in ipairs(data) do
      outdata = outdata .. "\t{"
      outdata = outdata .. ("time = " .. v.time .. ",")
      outdata = outdata .. (" hours = " .. v.hours .. ",")
      outdata = outdata .. (" task = \"" .. v.task .. "\",")
      outdata = outdata .. (" project = \"" .. v.project .. "\"")
      outdata = outdata .. "},\r\n"
    end
    outdata = outdata .. "}"
    local f = love.filesystem.newFile("data.lua")
    f:open("w")
    f:write(outdata)
    f:close()
    return nil
  end,
  removeLatestTask = function()
    table.remove(data, 1)
    updateArchivedData(data)
    return nil
  end,
  taskToData = function(task)
    if (task[1]:len() == 0) or (task[2]:len() == 0) or (tonumber(task[3]) == nil) then
      return data
    end
    local outtask = {
      time = tonumber(os.time()),
      hours = tonumber(task[3]),
      task = task[1],
      project = task[2]
    }
    table.insert(data, 1, outtask)
    updateArchivedData(data)
    return nil
  end,
  savePrefs = function()
    local outprefs = deepTableToString(PREFS)
    local f = love.filesystem.newFile("prefs.lua")
    f:open("w")
    f:write(outprefs)
    f:close()
    return nil
  end,
  publishToHTML = function()
    local date = os.date('*t')
    local timedata, eradata, scoredata = generateMetrics(date)
    local curhex, curinvhex = getDayColors(tonumber(date.year), tonumber(date.month), tonumber(date.day))
    local outhtml = outhtml .. "<div id='holder'>\n"
    local scoretiles = {
      "IRON",
      "WORK",
      "LOG",
      "",
      "Updated",
      PREFS.MONTH_NAMES[tonumber(date.month)],
      date.day .. PREFS.DAY_SUFFIXES[tonumber(date.day)] .. ",",
      date.year,
      "",
      "",
      "",
      ""
    }
    for k, v in pairs(PREFS.STATS_PERIODS) do
      for i = 1, 3 do
        table.insert(scoretiles, "")
      end
      table.insert(scoretiles, #scoretiles - 2, v .. "-DAY:")
      table.insert(scoretiles, "Work Hours:")
      table.insert(scoretiles, scoredata[v].hours)
      table.insert(scoretiles, "Tasks:")
      table.insert(scoretiles, scoredata[v].entries)
      table.insert(scoretiles, "Hour Avg:")
      table.insert(scoretiles, scoredata[v].hourmean)
      table.insert(scoretiles, scoredata[v].houradj)
      table.insert(scoretiles, "")
      table.insert(scoretiles, "Entry Avg:")
      table.insert(scoretiles, scoredata[v].entrymean)
      table.insert(scoretiles, scoredata[v].entryadj)
      table.insert(scoretiles, "")
      table.insert(scoretiles, "Grade:")
      table.insert(scoretiles, scoredata[v].grade)
      for i = 1, 2 do
        table.insert(scoretiles, "")
      end
      for i = 1, 4 do
        table.insert(scoretiles, "------")
      end
    end
    for k, v in ipairs(scoretiles) do
      outhtml = outhtml .. ("<div class='scorechunk' style='background-color:#" .. curhex .. ";border-color:#" .. curhex .. ";'>")
      outhtml = outhtml .. ("<p style='color:#" .. curinvhex .. ";'>")
      outhtml = outhtml .. v
      outhtml = outhtml .. "</p>"
      outhtml = outhtml .. "</div>\n"
    end
    for k, v in pairs(data) do
      if k > PREFS.ENTRIES_LIMIT then
        break
      end
    end
    outhtml = outhtml .. "</div>\n"
    return nil
  end,
  uploadFilesToWebspace = function()
    return nil
  end,
  buildPrefsWindow = function()
    local prefsframe = loveframes.Create("frame")
    prefsframe:SetName("Preferences")
    prefsframe:SetPos(0, 0)
    prefsframe:SetSize(800, 600)
    prefsframe:SetDraggable(false)
    prefsframe:ShowCloseButton(true)
    local colorcheck = loveframes.Create("checkbox", prefsframe)
    colorcheck:SetPos(50, 50)
    colorcheck:SetText("Colorblind Mode")
    local deftabinput = loveframes.Create("textinput", prefsframe)
    deftabinput:SetPos(50, 100)
    deftabinput:SetWidth(200)
    deftabinput:SetText(PREFS.DEFAULT_TAB)
    local deftabtext = loveframes.Create("text", prefsframe)
    deftabtext:SetPos(255, 100)
    deftabtext:SetText("Default Metrics Tab")
    local htmlfileinput = loveframes.Create("textinput", prefsframe)
    htmlfileinput:SetPos(50, 130)
    htmlfileinput:SetWidth(200)
    htmlfileinput:SetText(PREFS.HTML_OUTPUT_FILE)
    local htmlfiletext = loveframes.Create("text", prefsframe)
    htmlfiletext:SetPos(255, 130)
    htmlfiletext:SetText("HTML Output File")
    local ftphostinput = loveframes.Create("textinput", prefsframe)
    ftphostinput:SetPos(50, 160)
    ftphostinput:SetWidth(200)
    ftphostinput:SetText(PREFS.FTP_HOST)
    local ftphosttext = loveframes.Create("text", prefsframe)
    ftphosttext:SetPos(255, 160)
    ftphosttext:SetText("FTP Host")
    local ftpuserinput = loveframes.Create("textinput", prefsframe)
    ftpuserinput:SetPos(50, 190)
    ftpuserinput:SetWidth(200)
    ftpuserinput:SetText(PREFS.FTP_USER)
    local ftpusertext = loveframes.Create("text", prefsframe)
    ftpusertext:SetPos(255, 190)
    ftpusertext:SetText("FTP User")
    local ftppassinput = loveframes.Create("textinput", prefsframe)
    ftppassinput:SetPos(50, 220)
    ftppassinput:SetWidth(200)
    ftppassinput:SetMaskChar("*")
    ftppassinput:SetText(PREFS.FTP_PASS)
    local ftppasstext = loveframes.Create("text", prefsframe)
    ftppasstext:SetPos(255, 220)
    ftppasstext:SetText("FTP Password")
    local ftppathinput = loveframes.Create("textinput", prefsframe)
    ftppathinput:SetPos(50, 250)
    ftppathinput:SetWidth(200)
    ftppathinput:SetText(PREFS.FTP_PATH)
    local ftppathtext = loveframes.Create("text", prefsframe)
    ftppathtext:SetPos(255, 250)
    ftppathtext:SetText("FTP Path")
    local ftpcommandinput = loveframes.Create("textinput", prefsframe)
    ftpcommandinput:SetPos(50, 280)
    ftpcommandinput:SetWidth(200)
    ftpcommandinput:SetText(PREFS.FTP_COMMAND)
    local ftpcommandtext = loveframes.Create("text", prefsframe)
    ftpcommandtext:SetPos(255, 280)
    ftpcommandtext:SetText("FTP Command")
    local entrycolsinput = loveframes.Create("textinput", prefsframe)
    entrycolsinput:SetPos(50, 310)
    entrycolsinput:SetWidth(200)
    entrycolsinput:SetText(PREFS.ENTRIES_COLUMNS)
    local entrycolstext = loveframes.Create("text", prefsframe)
    entrycolstext:SetPos(255, 310)
    entrycolstext:SetText("Entries-Panel Columns")
    local entrylimitinput = loveframes.Create("textinput", prefsframe)
    entrylimitinput:SetPos(50, 340)
    entrylimitinput:SetWidth(200)
    entrylimitinput:SetText(PREFS.ENTRIES_LIMIT)
    local entrylimittext = loveframes.Create("text", prefsframe)
    entrylimittext:SetPos(255, 340)
    entrylimittext:SetText("Max Entries-Panel Items")
    local applybutton = loveframes.Create("button", prefsframe)
    applybutton:SetPos(490, 495)
    applybutton:SetSize(150, 100)
    applybutton:SetText("Apply")
    applybutton.OnClick = function(object)
      local cblnd = colorcheck:GetChecked()
      local dtab = deftabinput:GetText()
      local hfile = htmlfileinput:GetText()
      local ecols = entrycolsinput:GetText()
      local elim = entrylimitinput:GetText()
      local fhost = ftphostinput:GetText()
      local fuser = ftpuserinput:GetText()
      local fpass = ftppassinput:GetText()
      local fpath = ftppathinput:GetText()
      local fcomm = ftpcommandinput:GetText()
      dtab = (string.match(dtab, '%d+') and dtab) or 1
      dtab = tonumber(dtab)
      dtab = math.min(dtab, #PREFS.STATS_PERIODS)
      if hfile:sub(-5) ~= ".html" then
        hfile = hfile .. ".html"
      end
      ecols = (string.match(ecols, '%d+') and ecols) or 30
      ecols = tonumber(ecols)
      ecols = math.min(ecols, 50)
      elim = (string.match(elim, '%d+') and elim) or 500
      elim = tonumber(elim)
      elim = math.min(elim, 1000)
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
      savePrefs()
      prefsframe:Remove()
      clearDynamicGUI()
      updateDataAndGUI()
      return nil
    end
    local closebutton = loveframes.Create("button", prefsframe)
    closebutton:SetPos(645, 495)
    closebutton:SetSize(150, 100)
    closebutton:SetText("Close")
    closebutton.OnClick = function(object)
      prefsframe:Remove()
      return nil
    end
    return nil
  end,
  buildInputFrame = function()
    local inputframe = loveframes.Create("frame")
    inputframe:SetName("Input")
    inputframe:SetPos(0, 0)
    inputframe:SetSize(200, 300)
    inputframe:SetDraggable(false)
    inputframe:ShowCloseButton(false)
    local uinput = { }
    for k, v in pairs(PREFS.INPUT_NAMES) do
      uinput[k] = loveframes.Create("textinput", inputframe)
      uinput[k]:SetPos(5, (30 * k))
      uinput[k]:SetWidth(190)
      uinput[k]:SetEditable(true)
      uinput[k]:SetText(v)
      uinput[k]:SetTabReplacement("")
      uinput[k].OnFocusGained = function(object)
        for kk, vv in pairs(PREFS.INPUT_NAMES) do
          if #tostring(uinput[kk]:GetText()) == 0 then
            uinput[kk]:SetText(vv)
          end
        end
        object:SetText("")
        return nil
      end
      uinput[k].OnFocusLost = function(object)
        if #tostring(object:GetText()) == 0 then
          object:SetText(v)
        end
        return nil
      end
      uinput[k].OnEnter = function(object)
        for kk, vv in pairs(PREFS.INPUT_NAMES) do
          IN_TASK[kk] = object:GetText()
          object:SetText(vv)
        end
        local data = taskToData(data, IN_TASK)
        clearDynamicGUI()
        updateDataAndGUI()
        return nil
      end
    end
    local submitbutton = loveframes.Create("button", inputframe)
    submitbutton:SetPos(10, 120)
    submitbutton:SetSize(180, 60)
    submitbutton:SetText("Submit")
    submitbutton.OnClick = function(object)
      for k, v in pairs(PREFS.INPUT_NAMES) do
        IN_TASK[k] = uinput[k]:GetText()
        uinput[k]:SetText(v)
      end
      local data = taskToData(IN_TASK)
      clearDynamicGUI()
      updateDataAndGUI()
      return nil
    end
    local removebutton = loveframes.Create("button", inputframe)
    removebutton:SetPos(10, 185)
    removebutton:SetSize(180, 20)
    removebutton:SetText("Delete Latest Entry")
    removebutton.OnClick = function(object)
      removeLatestTask()
      clearDynamicGUI()
      updateDataAndGUI()
      return nil
    end
    local publishbutton = loveframes.Create("button", inputframe)
    publishbutton:SetPos(10, 215)
    publishbutton:SetSize(180, 20)
    publishbutton:SetText("Publish To HTML")
    publishbutton.OnClick = function(object)
      for k, v in pairs(PREFS.INPUT_NAMES) do
        IN_TASK[k] = uinput[k]:GetText()
        uinput[k]:SetText(v)
      end
      publishToHTML()
      return nil
    end
    local uploadbutton = loveframes.Create("button", inputframe)
    uploadbutton:SetPos(10, 240)
    uploadbutton:SetSize(180, 20)
    uploadbutton:SetText("FTP To Web")
    uploadbutton.OnClick = function(object)
      uploadFilesToWebspace()
      return nil
    end
    local prefsbutton = loveframes.Create("button", inputframe)
    prefsbutton:SetPos(100, 270)
    prefsbutton:SetSize(90, 20)
    prefsbutton:SetText("Preferences")
    prefsbutton.OnClick = function(object)
      buildPrefsWindow()
      return nil
    end
    return nil
  end,
  buildMetricsFrame = function()
    metricsframe = loveframes.Create("frame")
    metricsframe:SetName("Metrics")
    metricsframe:SetPos(200, 0)
    metricsframe:SetSize(600, 300)
    metricsframe:SetDraggable(false)
    metricsframe:ShowCloseButton(false)
    return nil
  end,
  buildMetricsTabs = function(eradata, scoredata, date, frame)
    local metricstabs = loveframes.Create("tabs", frame)
    metricstabs:SetPos(5, 30)
    metricstabs:SetSize(590, 265)
    metricstabs:SetPadding(0)
    local tabimage = "tabimage.png"
    for k, p in pairs(PREFS.STATS_PERIODS) do
      local panel = loveframes.Create("panel", metricstabs)
      panel.Draw = function(object)
        love.graphics.setColor(30, 30, 30, 255)
        love.graphics.rectangle("fill", object:GetX(), object:GetY(), object:GetWidth(), object:GetHeight())
        return nil
      end
      buildMetricsGrid(eradata[p], p, date, panel)
      local stext = "Hours Worked: \n " .. scoredata[p].hours .. " : " .. round(scoredata[p].avghours, 2) .. "/day"
      stext = stext .. (" \n  \n Hour Scores: \n " .. scoredata[p].hourmean .. ", " .. scoredata[p].houradj)
      stext = stext .. (" \n  \n Entry Scores: \n " .. scoredata[p].entrymean .. ", " .. scoredata[p].entryadj)
      stext = stext .. (" \n  \n Grade: " .. scoredata[p].grade)
      local scoretext = loveframes.Create("text", panel)
      scoretext:SetPos(360, 5)
      scoretext:SetSize(230, 260)
      scoretext:SetFont(SMALL_IRON_FONT)
      scoretext:SetIgnoreNewlines(false)
      scoretext:SetText(stext)
      metricstabs:AddTab((p .. "-DAY"), panel, (p .. "-DAY"), tabimage)
    end
    metricstabs:SwitchToTab(PREFS.DEFAULT_TAB)
    return nil
  end,
  buildMetricsGrid = function(pdata, period, date, frame)
    local grid = loveframes.Create("grid", frame)
    grid:SetPos(0, 0)
    grid:SetColumns(period)
    grid:SetRows(#PREFS.BAR_THRESHOLDS)
    grid:SetCellWidth(350 / period)
    grid:SetCellHeight(240 / #PREFS.BAR_THRESHOLDS)
    grid:SetCellPadding(0)
    grid:SetItemAutoSize(true)
    local emptyhex = {
      60,
      60,
      60
    }
    local iyear = tonumber(date.year)
    local imonth = tonumber(date.month)
    local iday = tonumber(date.day)
    for p = 1, period do
      for y, thresh in pairs(PREFS.BAR_THRESHOLDS) do
        local fullhex, invhex = getDayColors(iyear, imonth, iday)
        local hex = (PREFS.COLORBLIND_MODE and invhex) or emptyhex
        local exists = false
        if (pdata[iyear] ~= nil) and (pdata[iyear][imonth] ~= nil) and (pdata[iyear][imonth][iday] ~= nil) then
          exists = true
          if pdata[iyear][imonth][iday].hours >= thresh then
            hex = fullhex
          end
        end
        local f = loveframes.Create("frame")
        f:SetName("")
        f:SetSize(20, 20)
        f:SetDraggable(false)
        f:ShowCloseButton(false)
        f.Draw = function(object)
          love.graphics.setColor(hex[1], hex[2], hex[3], 255)
          love.graphics.rectangle("fill", object:GetX(), object:GetY(), object:GetWidth(), object:GetHeight())
          return nil
        end
        local tip = loveframes.Create("tooltip")
        tip:SetObject(f)
        tip:SetPadding(10)
        tip:SetText({
          invhex,
          PREFS.MONTH_NAMES[imonth] .. " " .. iday .. PREFS.DAY_SUFFIXES[iday],
          ", " .. iyear .. " ::: " .. ((exists and pdata[iyear][imonth][iday].hours) or "0") .. " hours worked"
        })
        tip.Draw = function(object)
          love.graphics.setColor(hex[1], hex[2], hex[3], 255)
          love.graphics.rectangle("fill", object:GetX(), object:GetY(), object:GetWidth(), object:GetHeight())
          return nil
        end
        grid:AddItem(f, y, p)
      end
      iyear, imonth, iday = dateCountBack(iyear, imonth, iday)
    end
    return nil
  end,
  buildEntriesFrame = function()
    entriesframe = loveframes.Create("frame")
    entriesframe:SetName("Entries")
    entriesframe:SetPos(0, 300)
    entriesframe:SetSize(800, 300)
    entriesframe:SetDraggable(false)
    entriesframe:ShowCloseButton(false)
    return nil
  end,
  buildEntriesList = function(container)
    local listscroll = loveframes.Create("list", container)
    listscroll:EnableHorizontalStacking(true)
    listscroll:SetPos(0, 35)
    listscroll:SetSize(800, 265)
    local cols = PREFS.ENTRIES_COLUMNS
    local cwidth = container:GetWidth() / cols
    for k, v in pairs(data) do
      if k > PREFS.ENTRIES_LIMIT then
        break
      end
      local d = os.date('*t', v.time)
      local hex, invhex = getDayColors(d.year, d.month, d.day)
      local fulldate = PREFS.MONTH_NAMES[d.month] .. " " .. d.day .. PREFS.DAY_SUFFIXES[d.day] .. ", " .. d.year
      local fulltime = string.rep("0", 2 - #tostring(d.hour)) .. d.hour .. ":" .. string.rep("0", 2 - #tostring(d.min)) .. d.min
      local task = v.task .. " on " .. v.project .. " for " .. v.hours .. " hours"
      local frame = loveframes.Create("frame", listscroll)
      frame:SetName("")
      frame:SetSize(cwidth, cwidth)
      frame:SetDraggable(false)
      frame:ShowCloseButton(false)
      frame.Draw = function(object)
        love.graphics.setColor(hex[1], hex[2], hex[3], 255)
        love.graphics.rectangle("fill", object:GetX(), object:GetY(), object:GetWidth(), object:GetHeight())
        return nil
      end
      local tip = loveframes.Create("tooltip", frame)
      tip:SetObject(frame)
      tip:SetFollowCursor(false)
      tip:SetX(container:GetX())
      tip:SetY(container:GetY())
      tip:SetPadding(10)
      tip:SetText({
        invhex,
        fulldate .. " :: " .. fulltime .. " :: " .. task
      })
      tip.Draw = function(object)
        love.graphics.setColor(hex[1], hex[2], hex[3], 255)
        love.graphics.rectangle("fill", object:GetX(), object:GetY(), object:GetWidth(), object:GetHeight())
        return nil
      end
      listscroll:AddItem(frame)
    end
    return nil
  end,
  clearDynamicGUI = function()
    metricsframe:Remove()
    entriesframe:Remove()
    return nil
  end,
  updateDataAndGUI = function()
    local date = os.date('*t')
    local timedata, eradata, scoredata = generateMetrics(date)
    buildMetricsFrame()
    buildMetricsTabs(eradata, scoredata, date, metricsframe)
    buildEntriesFrame()
    buildEntriesList(entriesframe)
    return nil
  end
}
