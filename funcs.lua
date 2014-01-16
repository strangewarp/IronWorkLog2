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
  round = function(num, idp)
    if idp == nil then
      idp = 0
    end
    local mult = 10 ^ idp
    return math.floor(num * mult + 0.5) / mult
  end,
  tableToGlobals = function(tab)
    for k, v in pairs(tab) do
      _G[k] = v
    end
    return nil
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
    local eradata = { }
    for _, p in pairs(STATS_PERIODS) do
      eradata[p] = { }
    end
    local iyear = tonumber(date.year)
    local imonth = tonumber(date.month)
    local iday = tonumber(date.day)
    while #eradata[STATS_PERIODS[#STATS_PERIODS]] < STATS_PERIODS[#STATS_PERIODS] do
      for _, p in ipairs(STATS_PERIODS) do
        if #eradata[p] < p then
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
    end
    return eradata
  end,
  eradataToScoredata = function(eradata, date)
    local scoredata = { }
    for _, p in pairs(STATS_PERIODS) do
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
      for i = 1, #GRADE_THRESHOLDS do
        if scoredata[p].avghours >= GRADE_THRESHOLDS[i][2] then
          scoredata[p].grade = GRADE_THRESHOLDS[i][1]
          break
        end
      end
      local h = scoredata[p].hours / GRADE_THRESHOLDS[1][2]
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
  publishToHTML = function()
    return nil
  end,
  uploadFilesToWebspace = function()
    return nil
  end,
  clearDynamicGUI = function(grid, tabs)
    grid:Remove()
    for i = 1, #STATS_PERIODS do
      tabs[i]:RemoveTab()
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
    for k, v in pairs(INPUT_NAMES) do
      uinput[k] = loveframes.Create("textinput", inputframe)
      uinput[k]:SetPos(5, (30 * k))
      uinput[k]:SetWidth(190)
      uinput[k]:SetText(v)
      uinput[k]:SetTabReplacement("")
      uinput[k].OnFocusGained = function(object)
        for kk, vv in pairs(INPUT_NAMES) do
          if #tostring(uinput[kk]:GetText()) == 0 then
            uinput[kk]:SetText(vv)
          end
        end
        uinput[k]:SetText("")
        return nil
      end
      uinput[k].OnFocusLost = function(object)
        if #tostring(uinput[k]:GetText()) == 0 then
          uinput[k]:SetText(v)
        end
        return nil
      end
      uinput[k].OnEnter = function(object)
        for kk, vv in pairs(INPUT_NAMES) do
          IN_TASK[kk] = uinput[kk]:GetText()
          uinput[kk]:SetText(vv)
        end
        local data = taskToData(data, IN_TASK)
        updateGUI()
        return nil
      end
    end
    local submitbutton = loveframes.Create("button", inputframe)
    submitbutton:SetPos(10, 120)
    submitbutton:SetWidth(180)
    submitbutton:SetHeight(60)
    submitbutton:SetText("Submit")
    submitbutton.OnClick = function(object)
      for k, v in pairs(INPUT_NAMES) do
        IN_TASK[k] = uinput[k]:GetText()
        uinput[k]:SetText(v)
      end
      local data = taskToData(IN_TASK)
      updateGUI()
      return nil
    end
    local removebutton = loveframes.Create("button", inputframe)
    removebutton:SetPos(10, 185)
    removebutton:SetWidth(180)
    removebutton:SetHeight(25)
    removebutton:SetText("Delete Latest Entry")
    removebutton.OnClick = function(object)
      removeLatestTask()
      updateGUI()
      return nil
    end
    local publishbutton = loveframes.Create("button", inputframe)
    publishbutton:SetPos(10, 225)
    publishbutton:SetWidth(180)
    publishbutton:SetHeight(25)
    publishbutton:SetText("Publish To HTML")
    publishbutton.OnClick = function(object)
      for k, v in pairs(INPUT_NAMES) do
        IN_TASK[k] = uinput[k]:GetText()
        uinput[k]:SetText(v)
      end
      publishToHTML()
      return nil
    end
    local uploadbutton = loveframes.Create("button", inputframe)
    uploadbutton:SetPos(10, 255)
    uploadbutton:SetWidth(180)
    uploadbutton:SetHeight(25)
    uploadbutton:SetText("FTP To Web")
    uploadbutton.OnClick = function(object)
      uploadFilesToWebspace()
      return nil
    end
    return nil
  end,
  buildMetricsFrame = function()
    local frame = loveframes.Create("frame")
    frame:SetName("Metrics")
    frame:SetPos(200, 0)
    frame:SetSize(600, 300)
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    return frame
  end,
  buildMetricsTabs = function(eradata, scoredata, date, frame)
    local tabs = loveframes.Create("tabs", frame)
    tabs:SetPos(5, 30)
    tabs:SetSize(590, 265)
    tabs:SetPadding(0)
    local panels = { }
    for k, p in ipairs(STATS_PERIODS) do
      panels[k] = loveframes.Create("panel")
      panels[k].Draw = function(object)
        love.graphics.setColor(30, 30, 30, 255)
        love.graphics.rectangle("fill", object:GetX(), object:GetY(), object:GetWidth(), object:GetHeight())
        return nil
      end
      buildMetricsGrid(eradata[p], p, date, panels[k])
      local gradetext = loveframes.Create("text", panels[p])
      gradetext:SetPos(400, 35)
      gradetext:SetText({
        255,
        255,
        255,
        "Grade: " .. scoredata[p].grade
      })
      local hourtext = loveframes.Create("text", panels[p])
      hourtext:SetPos(400, 100)
      hourtext:SetText({
        255,
        255,
        255,
        "Hour Scores: " .. scoredata[p].hourmean .. " - " .. scoredata[p].houradj
      })
      local entrytext = loveframes.Create("text", panels[p])
      entrytext:SetPos(400, 165)
      entrytext:SetText({
        255,
        255,
        255,
        "Entry Scores: " .. scoredata[p].entrymean .. " - " .. scoredata[p].entryadj
      })
      tabs:AddTab((p .. "-DAY"), panels[k], _, _)
    end
    tabs:SwitchToTab(DEFAULT_TAB)
    return nil
  end,
  buildMetricsGrid = function(pdata, period, date, frame)
    local grid = loveframes.Create("grid", frame)
    grid:SetPos(0, 0)
    grid:SetColumns(period)
    grid:SetRows(#BAR_THRESHOLDS)
    grid:SetCellWidth((350 - (2 * period)) / period)
    grid:SetCellHeight((240 - (2 * #BAR_THRESHOLDS)) / #BAR_THRESHOLDS)
    grid:SetCellPadding(1)
    grid:SetItemAutoSize(true)
    local fullhex = (COLORBLIND_MODE and {
      170,
      170,
      170
    }) or {
      130,
      230,
      130
    }
    local emptyhex = {
      60,
      60,
      60
    }
    local iyear = tonumber(date.year)
    local imonth = tonumber(date.month)
    local iday = tonumber(date.day)
    for p = 1, period do
      for y, thresh in pairs(BAR_THRESHOLDS) do
        local hex = emptyhex
        if pdata[iyear][imonth][iday].hours >= thresh then
          hex = fullhex
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
          {
            0,
            0,
            0
          },
          MONTH_NAMES[imonth] .. " " .. iday .. DAY_SUFFIXES[iday],
          ", " .. iyear .. " ::: " .. pdata[iyear][imonth][iday].hours .. " hours worked"
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
    local frame = loveframes.Create("frame")
    frame:SetName("Entries")
    frame:SetPos(0, 300)
    frame:SetSize(800, 400)
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    return frame
  end,
  buildEntriesGrid = function(data, container)
    local cols = 40
    local cwidth = (container:GetWidth() / cols) - 2
    local grid = loveframes.Create("grid", container)
    grid:SetPos(0, 30)
    grid:SetColumns(cols)
    grid:SetRows(math.ceil(#data / cols))
    grid:SetCellWidth(cwidth)
    grid:SetCellHeight(cwidth)
    grid:SetCellPadding(1)
    grid:SetItemAutoSize(true)
    for k, v in pairs(data) do
      local d = os.date('*t', v.time)
      local hexdate = string.rep("0", 2 - #tostring(d.day)) .. d.day .. string.rep("0", 2 - #tostring(d.month)) .. d.month .. d.year
      local fulldate = MONTH_NAMES[d.month] .. " " .. d.day .. DAY_SUFFIXES[d.day] .. ", " .. d.year
      local fulltime = string.rep("0", 2 - #tostring(d.hour)) .. d.hour .. ":" .. string.rep("0", 2 - #tostring(d.min)) .. d.min
      local task = v.task .. " on " .. v.project .. " for " .. v.hours .. " hours"
      local outsha = sha1(hexdate)
      local hex
      do
        local _accum_0 = { }
        local _len_0 = 1
        for i = 1, 3 do
          _accum_0[_len_0] = tonumber(string.sub(outsha, ((i - 1) * 2) + 1, i * 2), 16)
          _len_0 = _len_0 + 1
        end
        hex = _accum_0
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
      hex = (COLORBLIND_MODE and {
        hex[1],
        hex[1],
        hex[1]
      }) or hex
      invhex = (COLORBLIND_MODE and {
        invhex[1],
        invhex[1],
        invhex[1]
      }) or invhex
      local frame = loveframes.Create("frame")
      frame:SetName("")
      frame:SetSize(20, 20)
      frame:SetDraggable(false)
      frame:ShowCloseButton(false)
      frame.Draw = function(object)
        love.graphics.setColor(hex[1], hex[2], hex[3], 255)
        love.graphics.rectangle("fill", object:GetX(), object:GetY(), object:GetWidth(), object:GetHeight())
        return nil
      end
      local tip = loveframes.Create("tooltip")
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
      grid:AddItem(frame, math.floor((k - 1) / cols) + 1, ((k - 1) % cols) + 1)
    end
    return nil
  end
}
