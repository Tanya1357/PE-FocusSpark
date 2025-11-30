-- FocusSpark_Data.lua
-- 数据持久化模块：保存/加载用户设置和进度数据

local Data = {}

-- ============================================
-- 配置
-- ============================================
local function get_script_path()
    local info = debug.getinfo(1, 'S')
    local src = info and info.source or ''
    if src:sub(1, 1) == '@' then src = src:sub(2) end
    return src:match('^(.+[\\/])[^\\/]+$') or ''
end

local SCRIPT_PATH = get_script_path()
local DATA_FILE = SCRIPT_PATH .. "FocusSpark_UserData.txt"
local SETTINGS_FILE = SCRIPT_PATH .. "FocusSpark_Settings.txt"

-- ============================================
-- 辅助：简易序列化/反序列化
-- ============================================
local function serialize_table(t, indent)
    indent = indent or ""
    local parts = {}
    
    for k, v in pairs(t) do
        local key = type(k) == "number" and ("[" .. k .. "]") or k
        local value
        
        if type(v) == "table" then
            value = "{\n" .. serialize_table(v, indent .. "  ") .. indent .. "}"
        elseif type(v) == "string" then
            value = string.format("%q", v)
        elseif type(v) == "boolean" then
            value = v and "true" or "false"
        else
            value = tostring(v)
        end
        
        table.insert(parts, indent .. "  " .. key .. " = " .. value)
    end
    
    return table.concat(parts, ",\n") .. "\n"
end

local function deserialize_string(str)
    if not str or str == "" then return nil end
    
    -- 安全加载（简易版本，只支持基本类型）
    local fn, err = load("return {" .. str .. "}", "data", "t", {})
    if fn then
        local ok, result = pcall(fn)
        if ok then return result end
    end
    return nil
end

-- ============================================
-- 设置存储
-- ============================================
function Data.saveSettings(settings)
    local f = io.open(SETTINGS_FILE, "w")
    if not f then return false, "无法写入设置文件" end
    
    local content = serialize_table(settings)
    f:write(content)
    f:close()
    
    return true
end

function Data.loadSettings()
    local f = io.open(SETTINGS_FILE, "r")
    if not f then return nil end
    
    local content = f:read("*all")
    f:close()
    
    return deserialize_string(content)
end

-- ============================================
-- 今日进度存储
-- ============================================
function Data.saveDayProgress(state)
    local today = os.date("%Y-%m-%d")
    
    -- 只保存需要持久化的字段
    local data = {
        date = today,
        target_total = state.target_total,
        completed_count = state.completed_count,
        completion_times = state.completion_times,
        combo_max = state.combo_max,
        session_start = state.session_start,
        work_start_time = state.work_start_time,
        work_end_time = state.work_end_time,
    }
    
    local f = io.open(DATA_FILE, "w")
    if not f then return false, "无法写入进度文件" end
    
    f:write("date = " .. string.format("%q", today) .. ",\n")
    f:write("target_total = " .. tostring(data.target_total) .. ",\n")
    f:write("completed_count = " .. tostring(data.completed_count) .. ",\n")
    f:write("combo_max = " .. tostring(data.combo_max) .. ",\n")
    f:write("session_start = " .. tostring(data.session_start) .. ",\n")
    f:write("work_start_time = " .. string.format("%q", data.work_start_time or "09:00") .. ",\n")
    f:write("work_end_time = " .. string.format("%q", data.work_end_time or "18:00") .. ",\n")
    
    -- 保存完成时间列表（使用紧凑格式，兼容旧格式）
    local times = data.completion_times or {}
    f:write("completion_times = {\n")
    for i, t in ipairs(times) do
        f:write("  [" .. i .. "] = " .. tostring(t) .. ",\n")
    end
    f:write("},\n")
    
    f:close()
    return true
end

function Data.loadDayProgress()
    local f = io.open(DATA_FILE, "r")
    if not f then return nil end
    
    local content = f:read("*all")
    f:close()
    
    local data = deserialize_string(content)
    if not data then return nil end
    
    -- 检查是否是今天的数据
    local today = os.date("%Y-%m-%d")
    if data.date ~= today then
        -- 不是今天的数据，返回 nil（将开始新的一天）
        return nil
    end
    
    return data
end

-- ============================================
-- 历史记录（可选功能）
-- ============================================
local HISTORY_FILE = SCRIPT_PATH .. "FocusSpark_History.txt"

function Data.appendHistory(state)
    local today = os.date("%Y-%m-%d")
    
    -- 追加模式写入历史
    local f = io.open(HISTORY_FILE, "a")
    if not f then return false end
    
    -- 格式: 日期|目标|完成|最高连击|总耗时
    local total_time = 0
    local times = state.completion_times or {}
    if #times >= 2 then
        total_time = times[#times] - times[1]
    end
    
    f:write(string.format("%s|%d|%d|%d|%.0f\n",
        today,
        state.target_total,
        state.completed_count,
        state.combo_max,
        total_time
    ))
    f:close()
    
    return true
end

function Data.loadHistory(days)
    days = days or 30
    
    local f = io.open(HISTORY_FILE, "r")
    if not f then return {} end
    
    local history = {}
    for line in f:lines() do
        local date, target, completed, combo, time = line:match("^(.+)|(%d+)|(%d+)|(%d+)|(%d+)$")
        if date then
            table.insert(history, {
                date = date,
                target = tonumber(target),
                completed = tonumber(completed),
                combo_max = tonumber(combo),
                total_time = tonumber(time)
            })
        end
    end
    f:close()
    
    -- 只返回最近 N 天
    local start = math.max(1, #history - days + 1)
    local recent = {}
    for i = start, #history do
        table.insert(recent, history[i])
    end
    
    return recent
end

-- ============================================
-- 音效文件扫描
-- ============================================
function Data.scanSoundFiles()
    local sounds_path = SCRIPT_PATH .. "assets" .. package.config:sub(1,1) .. "sounds"
    local sounds = {
        done = {},      -- done_1.wav, done_2.wav, ...
        overtime_warn = nil,
        overtime_alert = nil,
        complete = nil,
    }
    
    -- 使用 reaper.EnumerateFiles 扫描目录
    local idx = 0
    while true do
        local filename = reaper.EnumerateFiles(sounds_path, idx)
        if not filename then break end
        
        local lower = filename:lower()
        
        -- 完成音效
        local done_num = lower:match("^done_(%d+)%.")
        if done_num then
            sounds.done[tonumber(done_num)] = sounds_path .. package.config:sub(1,1) .. filename
        end
        
        -- 加班预警音效
        if lower:match("^overtime_warn%.") then
            sounds.overtime_warn = sounds_path .. package.config:sub(1,1) .. filename
        end
        
        -- 加班警报音效
        if lower:match("^overtime_alert%.") then
            sounds.overtime_alert = sounds_path .. package.config:sub(1,1) .. filename
        end
        
        -- 完成全部目标音效
        if lower:match("^complete%.") then
            sounds.complete = sounds_path .. package.config:sub(1,1) .. filename
        end
        
        idx = idx + 1
    end
    
    return sounds
end

-- ============================================
-- 获取路径
-- ============================================
function Data.getScriptPath()
    return SCRIPT_PATH
end

function Data.getSoundsPath()
    return SCRIPT_PATH .. "assets" .. package.config:sub(1,1) .. "sounds" .. package.config:sub(1,1)
end

return Data

