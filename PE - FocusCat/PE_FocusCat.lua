-- PE_FocusCat.lua
-- Reaper计时猫咪伴侣脚本
-- Version: 1.0.0
-- Author: PhaseEggplant

-----------------------------------
-- 配置和全局变量
-----------------------------------

local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
local data_file = script_path .. "data.json"

-- 默认配置
local Config = {
    settings = {
        off_time = "19:30",
        time_presets = {10, 20, 30, 60},
        volume = 0.8
    },
    today = {
        date = os.date("%Y-%m-%d"),
        completed = 0,
        total_time = 0,
        on_time = 0,
        overtime = 0
    },
    combo = {
        current = 0,
        max = 0
    },
    sounds = {
        complete = "",
        combo3 = "",
        combo5 = "",
        combo10 = "",
        alarm = "",
        warning = ""
    },
    timer = {
        running = false,
        seconds = 0,
        target = 0,
        start_time = 0
    }
}

-- UI常量
local UI = {
    width = 450,
    height = 600,
    padding = 20,
    button_height = 35,
    button_width = 70,
    timer_font_size = 48,
    normal_font_size = 14,
    title_font_size = 18
}

-- 颜色
local Colors = {
    bg = {0.15, 0.15, 0.18},
    panel = {0.2, 0.2, 0.23},
    button = {0.3, 0.5, 0.7},
    button_hover = {0.4, 0.6, 0.8},
    button_active = {0.25, 0.45, 0.65},
    text = {0.9, 0.9, 0.9},
    text_dim = {0.6, 0.6, 0.6},
    success = {0.3, 0.8, 0.4},
    warning = {0.9, 0.5, 0.2},
    danger = {0.9, 0.3, 0.3},
    combo = {1.0, 0.8, 0.0}
}

-- 猫咪状态
local CatStates = {
    IDLE = "idle",
    WORKING = "working",
    HAPPY = "happy",
    ALARM = "alarm",
    ANGRY = "angry"
}

local CatState = {
    current = CatStates.IDLE,
    animation_time = 0,
    animation_frame = 0
}

-- 闹钟状态
local Alarm = {
    active = false,
    flash_time = 0
}

-- 计时器系统（前置声明，具体实现在后面）
local Timer = {}

-- 音效管理器（前置声明，具体实现在后面）
local SoundManager = {}

-- 加班预警系统（前置声明，具体实现在后面）
local OvertimeWarning = {
    is_overtime = false,
    last_check = 0
}

-- 完成系统（前置声明，具体实现在后面）
local Completion = {}

-- 粒子系统
local Particles = {}

-- 音频预览对象
local audio_preview = nil

-- 鼠标状态
local mouse = {
    x = 0,
    y = 0,
    down = false,
    last_down = false
}

-- UI状态
local ui_state = {
    show_settings = false,
    hovered_button = nil,
    custom_time_input = "25"
}

local last_time = reaper.time_precise()

-----------------------------------
-- JSON 编解码（简易版）
-----------------------------------

local function EncodeJSON(t)
    local function encode_value(v)
        local vtype = type(v)
        if vtype == "string" then
            return '"' .. v:gsub('"', '\\"') .. '"'
        elseif vtype == "number" or vtype == "boolean" then
            return tostring(v)
        elseif vtype == "table" then
            local is_array = #v > 0
            local result = is_array and "[" or "{"
            local first = true
            
            if is_array then
                for i, val in ipairs(v) do
                    if not first then result = result .. "," end
                    result = result .. encode_value(val)
                    first = false
                end
            else
                for k, val in pairs(v) do
                    if not first then result = result .. "," end
                    result = result .. '"' .. k .. '":' .. encode_value(val)
                    first = false
                end
            end
            
            result = result .. (is_array and "]" or "}")
            return result
        end
        return "null"
    end
    
    return encode_value(t)
end

local function DecodeJSON(str)
    if not str or str == "" then return nil end
    
    -- 简易JSON解码（仅支持基本类型）
    local function parse_value(s, pos)
        local c = s:sub(pos, pos)
        
        if c == '{' then
            local obj = {}
            pos = pos + 1
            while s:sub(pos, pos) ~= '}' do
                -- Skip whitespace
                while s:sub(pos, pos):match("[%s,]") do pos = pos + 1 end
                if s:sub(pos, pos) == '}' then break end
                
                -- Parse key
                local key_start = s:find('"', pos)
                local key_end = s:find('"', key_start + 1)
                local key = s:sub(key_start + 1, key_end - 1)
                pos = key_end + 1
                
                -- Skip to value
                while s:sub(pos, pos):match("[%s:]") do pos = pos + 1 end
                
                -- Parse value
                local value, new_pos = parse_value(s, pos)
                obj[key] = value
                pos = new_pos
            end
            return obj, pos + 1
        elseif c == '[' then
            local arr = {}
            pos = pos + 1
            while s:sub(pos, pos) ~= ']' do
                while s:sub(pos, pos):match("[%s,]") do pos = pos + 1 end
                if s:sub(pos, pos) == ']' then break end
                
                local value, new_pos = parse_value(s, pos)
                table.insert(arr, value)
                pos = new_pos
            end
            return arr, pos + 1
        elseif c == '"' then
            local str_end = s:find('"', pos + 1)
            return s:sub(pos + 1, str_end - 1), str_end + 1
        elseif c:match("[0-9%-]") then
            local num_end = pos
            while s:sub(num_end + 1, num_end + 1):match("[0-9%.]") do
                num_end = num_end + 1
            end
            return tonumber(s:sub(pos, num_end)), num_end + 1
        elseif s:sub(pos, pos + 3) == "true" then
            return true, pos + 4
        elseif s:sub(pos, pos + 4) == "false" then
            return false, pos + 5
        elseif s:sub(pos, pos + 3) == "null" then
            return nil, pos + 4
        end
        
        return nil, pos + 1
    end
    
    local value, _ = parse_value(str, 1)
    return value
end

-----------------------------------
-- 数据持久化
-----------------------------------

function SaveData()
    local file = io.open(data_file, "w")
    if file then
        file:write(EncodeJSON(Config))
        file:close()
    end
end

function LoadData()
    local file = io.open(data_file, "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        local loaded = DecodeJSON(content)
        if loaded then
            -- 合并加载的数据
            for k, v in pairs(loaded) do
                if Config[k] then
                    if type(v) == "table" then
                        for k2, v2 in pairs(v) do
                            Config[k][k2] = v2
                        end
                    else
                        Config[k] = v
                    end
                end
            end
        end
    end
    
    -- 检查日期是否变化，重置今日统计
    CheckDateReset()
end

function CheckDateReset()
    local today = os.date("%Y-%m-%d")
    if Config.today.date ~= today then
        Config.today = {
            date = today,
            completed = 0,
            total_time = 0,
            on_time = 0,
            overtime = 0
        }
        Config.combo.current = 0
        SaveData()
    end
end

-----------------------------------
-- 音效系统（方法实现）
-----------------------------------

SoundManager.Play = function(event_type)
    local sound_path = SoundManager.GetPath(event_type)
    if sound_path and sound_path ~= "" and reaper.file_exists(sound_path) then
        -- 停止之前的预览
        if audio_preview then
            reaper.StopPreview(audio_preview)
            audio_preview = nil
        end
        
        -- 创建新的预览
        local source = reaper.PCM_Source_CreateFromFile(sound_path)
        if source then
            audio_preview = reaper.PlayPreviewEx(source, 0, Config.settings.volume, {0, 1})
        end
    end
end

SoundManager.GetPath = function(event_type)
    -- 优先使用自定义音效
    if Config.sounds[event_type] and Config.sounds[event_type] ~= "" then
        if reaper.file_exists(Config.sounds[event_type]) then
            return Config.sounds[event_type]
        end
    end
    
    -- 使用默认音效
    local default_path = script_path .. "sounds/default/" .. event_type .. ".wav"
    if reaper.file_exists(default_path) then
        return default_path
    end
    
    return nil
end

SoundManager.BrowseSound = function(event_type)
    local retval, file_path = reaper.GetUserFileNameForRead("", "选择音效文件", "WAV files (.wav)|*.wav|MP3 files (.mp3)|*.mp3|OGG files (.ogg)|*.ogg||")
    if retval then
        Config.sounds[event_type] = file_path
        SaveData()
    end
end

-----------------------------------
-- 计时器系统（方法实现）
-----------------------------------

Timer.SetTime = function(minutes)
    Config.timer.seconds = minutes * 60
    Config.timer.target = minutes * 60
    Config.timer.running = false
    Alarm.Dismiss()
end

Timer.Start = function()
    if Config.timer.seconds > 0 then
        Config.timer.running = true
        Config.timer.start_time = os.time()
        CatState.Set(CatStates.WORKING)
    end
end

Timer.Pause = function()
    Config.timer.running = false
end

Timer.Stop = function()
    Config.timer.running = false
    Config.timer.seconds = 0
    Config.timer.target = 0
    CatState.Set(CatStates.IDLE)
    Alarm.Dismiss()
end

Timer.Update = function(delta_time)
    if Config.timer.running then
        Config.timer.seconds = Config.timer.seconds - delta_time
        
        if Config.timer.seconds <= 0 then
            Config.timer.seconds = 0
            Config.timer.running = false
            Alarm.Trigger()
        end
    end
end

Timer.Format = function(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", mins, secs)
end

-----------------------------------
-- 闹钟系统
-----------------------------------

Alarm.Trigger = function()
    Alarm.active = true
    Alarm.flash_time = 0
    SoundManager.Play("alarm")
    CatState.Set(CatStates.ALARM)
end

Alarm.Dismiss = function()
    Alarm.active = false
    if CatState.current == CatStates.ALARM then
        CatState.Set(CatStates.IDLE)
    end
end

-----------------------------------
-- 完成系统（方法实现）
-----------------------------------

Completion.Complete = function()
    if Config.timer.target == 0 then return end
    
    -- 更新统计
    Config.today.completed = Config.today.completed + 1
    
    -- 计算实际用时
    local task_time = Config.timer.target - Config.timer.seconds
    Config.today.total_time = Config.today.total_time + task_time
    
    -- 判断是否按时完成
    if Config.timer.seconds > 0 then
        Config.today.on_time = Config.today.on_time + 1
    else
        Config.today.overtime = Config.today.overtime + 1
    end
    
    -- Combo计数
    Config.combo.current = Config.combo.current + 1
    if Config.combo.current > Config.combo.max then
        Config.combo.max = Config.combo.current
    end
    
    -- 触发奖励
    Completion.TriggerReward()
    
    -- 重置计时器
    Timer.Stop()
    
    -- 保存数据
    SaveData()
end

Completion.TriggerReward = function()
    -- 猫咪开心动画
    CatState.Set(CatStates.HAPPY)
    
    -- 生成粒子
    for i = 1, 10 do
        table.insert(Particles, {
            x = UI.width / 2,
            y = UI.height / 2,
            vx = (math.random() - 0.5) * 100,
            vy = -math.random() * 150 - 50,
            life = 1.0,
            type = "heart"
        })
    end
    
    -- 根据Combo播放音效
    if Config.combo.current >= 10 then
        SoundManager.Play("combo10")
    elseif Config.combo.current >= 5 then
        SoundManager.Play("combo5")
    elseif Config.combo.current >= 3 then
        SoundManager.Play("combo3")
    else
        SoundManager.Play("complete")
    end
end

-----------------------------------
-- 加班预警系统（方法实现）
-----------------------------------

OvertimeWarning.Check = function()
    local current_time = os.time()
    if current_time - OvertimeWarning.last_check < 60 then
        return -- 每分钟检查一次
    end
    OvertimeWarning.last_check = current_time
    
    local time_table = os.date("*t")
    local hour = time_table.hour
    local min = time_table.min
    
    -- 解析下班时间
    local off_hour, off_min = Config.settings.off_time:match("(%d+):(%d+)")
    off_hour = tonumber(off_hour) or 19
    off_min = tonumber(off_min) or 30
    
    -- 检查是否超时
    local current_minutes = hour * 60 + min
    local off_minutes = off_hour * 60 + off_min
    
    if current_minutes >= off_minutes then
        if not OvertimeWarning.is_overtime then
            OvertimeWarning.is_overtime = true
            OvertimeWarning.Trigger()
        end
    else
        OvertimeWarning.is_overtime = false
    end
end

OvertimeWarning.Trigger = function()
    -- 猫咪变愤怒
    if CatState.current ~= CatStates.WORKING and 
       CatState.current ~= CatStates.HAPPY then
        CatState.Set(CatStates.ANGRY)
    end
    
    -- 播放警告音效
    SoundManager.Play("warning")
end

-----------------------------------
-- 猫咪状态机
-----------------------------------

CatState.Set = function(new_state)
    CatState.current = new_state
    CatState.animation_time = 0
    CatState.animation_frame = 0
end

CatState.Update = function(delta_time)
    CatState.animation_time = CatState.animation_time + delta_time
    
    -- 状态转换
    if CatState.current == CatStates.HAPPY then
        if CatState.animation_time > 1.5 then
            CatState.Set(CatStates.IDLE)
        end
    end
    
    -- 检查加班状态
    OvertimeWarning.Check()
end

-----------------------------------
-- 粒子系统
-----------------------------------

local function UpdateParticles(delta_time)
    for i = #Particles, 1, -1 do
        local p = Particles[i]
        p.x = p.x + p.vx * delta_time
        p.y = p.y + p.vy * delta_time
        p.vy = p.vy + 200 * delta_time -- 重力
        p.life = p.life - delta_time
        
        if p.life <= 0 then
            table.remove(Particles, i)
        end
    end
end

-----------------------------------
-- 绘图函数
-----------------------------------

local function SetColor(color, alpha)
    alpha = alpha or 1.0
    gfx.set(color[1], color[2], color[3], alpha)
end

local function DrawRect(x, y, w, h, filled)
    if filled then
        gfx.rect(x, y, w, h, 1)
    else
        gfx.rect(x, y, w, h, 0)
    end
end

local function DrawRoundRect(x, y, w, h, r, filled)
    if filled then
        gfx.rect(x + r, y, w - r * 2, h, 1)
        gfx.rect(x, y + r, w, h - r * 2, 1)
        gfx.circle(x + r, y + r, r, 1, 1)
        gfx.circle(x + w - r, y + r, r, 1, 1)
        gfx.circle(x + r, y + h - r, r, 1, 1)
        gfx.circle(x + w - r, y + h - r, r, 1, 1)
    else
        gfx.roundrect(x, y, w, h, r, 0)
    end
end

local function DrawText(text, x, y, align)
    align = align or 0 -- 0=left, 1=center, 2=right
    gfx.x = x
    gfx.y = y
    if align == 1 then
        local w, h = gfx.measurestr(text)
        gfx.x = x - w / 2
    elseif align == 2 then
        local w, h = gfx.measurestr(text)
        gfx.x = x - w
    end
    gfx.drawstr(text)
end

local function DrawButton(text, x, y, w, h, id)
    local hovered = mouse.x >= x and mouse.x <= x + w and 
                    mouse.y >= y and mouse.y <= y + h
    local clicked = hovered and mouse.down and not mouse.last_down
    
    -- 绘制按钮
    if hovered and mouse.down then
        SetColor(Colors.button_active)
    elseif hovered then
        SetColor(Colors.button_hover)
    else
        SetColor(Colors.button)
    end
    DrawRoundRect(x, y, w, h, 5, true)
    
    -- 绘制文字
    gfx.setfont(1, "Arial", UI.normal_font_size)
    SetColor(Colors.text)
    DrawText(text, x + w / 2, y + h / 2 - 7, 1)
    
    return clicked
end

local function DrawCat(x, y, size)
    local state = CatState.current
    local t = CatState.animation_time
    
    -- 猫咪身体
    if state == CatStates.ANGRY then
        SetColor(Colors.danger, 0.8)
    elseif state == CatStates.HAPPY then
        SetColor(Colors.success, 0.8)
    elseif state == CatStates.WORKING then
        SetColor(Colors.button, 0.8)
    else
        SetColor(Colors.text_dim, 0.8)
    end
    
    -- 简单的猫咪像素画
    local s = size / 8
    
    -- 耳朵
    gfx.triangle(x + s, y, x + s * 2, y + s * 2, x, y + s * 2, 1)
    gfx.triangle(x + s * 7, y, x + s * 8, y + s * 2, x + s * 6, y + s * 2, 1)
    
    -- 头
    gfx.circle(x + s * 4, y + s * 3, s * 3, 1, 1)
    
    -- 眼睛
    SetColor({0, 0, 0})
    if state == CatStates.ANGRY then
        -- 愤怒的眼睛
        gfx.line(x + s * 2.5, y + s * 2.5, x + s * 3, y + s * 3)
        gfx.line(x + s * 5, y + s * 3, x + s * 5.5, y + s * 2.5)
    else
        gfx.circle(x + s * 3, y + s * 3, s * 0.5, 1, 1)
        gfx.circle(x + s * 5, y + s * 3, s * 0.5, 1, 1)
    end
    
    -- 鼻子
    gfx.triangle(x + s * 4, y + s * 4, x + s * 3.7, y + s * 4.5, x + s * 4.3, y + s * 4.5, 1)
    
    -- 嘴
    gfx.arc(x + s * 3.5, y + s * 4.5, s * 0.5, math.pi, math.pi * 2, 1)
    gfx.arc(x + s * 4.5, y + s * 4.5, s * 0.5, math.pi, math.pi * 2, 1)
    
    -- 状态特效
    if state == CatStates.HAPPY then
        -- 跳跃动画
        local jump = math.sin(t * 10) * 10
        y = y - math.abs(jump)
        
        -- 爱心
        SetColor(Colors.danger)
        local heart_x = x + s * 4 + math.sin(t * 3) * 30
        local heart_y = y - 20 - t * 20
        gfx.circle(heart_x - 5, heart_y, 5, 1, 1)
        gfx.circle(heart_x + 5, heart_y, 5, 1, 1)
        gfx.triangle(heart_x - 10, heart_y, heart_x + 10, heart_y, heart_x, heart_y + 12, 1)
    elseif state == CatStates.ALARM then
        -- 跳动提醒
        local pulse = math.sin(t * 15) * 5
        y = y + pulse
    elseif state == CatStates.ANGRY then
        -- 愤怒符号
        SetColor(Colors.danger)
        local anger_x = x + s * 7
        local anger_y = y - 10
        gfx.line(anger_x - 5, anger_y, anger_x + 5, anger_y)
        gfx.line(anger_x, anger_y - 5, anger_x, anger_y + 5)
    end
end

local function DrawParticles()
    for _, p in ipairs(Particles) do
        SetColor(Colors.danger, p.life)
        local size = 8 * p.life
        
        -- 爱心形状
        gfx.circle(p.x - size/4, p.y, size/4, 1, 1)
        gfx.circle(p.x + size/4, p.y, size/4, 1, 1)
        gfx.triangle(p.x - size/2, p.y, p.x + size/2, p.y, p.x, p.y + size * 0.75, 1)
    end
end

-----------------------------------
-- 主界面绘制
-----------------------------------

local function DrawMainUI()
    local w, h = gfx.w, gfx.h
    
    -- 背景
    SetColor(Colors.bg)
    DrawRect(0, 0, w, h, true)
    
    -- 标题
    gfx.setfont(1, "Arial", UI.title_font_size, 'b')
    SetColor(Colors.text)
    DrawText("FocusCat - 计时猫咪伴侣", w / 2, 15, 1)
    
    -- 当前时间
    gfx.setfont(1, "Arial", UI.normal_font_size)
    SetColor(Colors.text_dim)
    local current_time = os.date("%H:%M")
    DrawText(current_time, w - 20, 15, 2)
    
    local y = 50
    
    -- 计时器面板
    SetColor(Colors.panel)
    DrawRoundRect(UI.padding, y, w - UI.padding * 2, 200, 10, true)
    
    -- 倒计时显示
    gfx.setfont(1, "Arial", UI.timer_font_size, 'b')
    local timer_color = Config.timer.running and Colors.success or Colors.text
    if Config.timer.seconds <= 0 and Config.timer.target > 0 then
        timer_color = Colors.danger
    end
    SetColor(timer_color)
    local time_str = Timer.Format(Config.timer.seconds)
    DrawText(time_str, w / 2, y + 30, 1)
    
    -- 时间预设按钮
    gfx.setfont(1, "Arial", UI.normal_font_size)
    local btn_y = y + 100
    local btn_spacing = 10
    local total_btn_width = #Config.settings.time_presets * (UI.button_width + btn_spacing) - btn_spacing + UI.button_width
    local btn_x = (w - total_btn_width) / 2
    
    for i, minutes in ipairs(Config.settings.time_presets) do
        if DrawButton(minutes .. "m", btn_x, btn_y, UI.button_width, UI.button_height, "preset_" .. i) then
            Timer.SetTime(minutes)
        end
        btn_x = btn_x + UI.button_width + btn_spacing
    end
    
    -- 自定义时间按钮
    if DrawButton("自定义", btn_x, btn_y, UI.button_width, UI.button_height, "custom") then
        local retval, input = reaper.GetUserInputs("自定义时间", 1, "时间(分钟):", ui_state.custom_time_input)
        if retval then
            local minutes = tonumber(input)
            if minutes and minutes > 0 then
                ui_state.custom_time_input = input
                Timer.SetTime(minutes)
            end
        end
    end
    
    -- 控制按钮
    btn_y = btn_y + UI.button_height + 15
    btn_x = (w - (UI.button_width * 3 + btn_spacing * 2)) / 2
    
    if DrawButton("开始", btn_x, btn_y, UI.button_width, UI.button_height, "start") then
        Timer.Start()
    end
    btn_x = btn_x + UI.button_width + btn_spacing
    
    if DrawButton("暂停", btn_x, btn_y, UI.button_width, UI.button_height, "pause") then
        Timer.Pause()
    end
    btn_x = btn_x + UI.button_width + btn_spacing
    
    if DrawButton("停止", btn_x, btn_y, UI.button_width, UI.button_height, "stop") then
        Timer.Stop()
    end
    
    y = y + 220
    
    -- 猫咪
    DrawCat(w / 2 - 40, y, 80)
    
    y = y + 100
    
    -- 统计面板
    SetColor(Colors.panel)
    DrawRoundRect(UI.padding, y, w - UI.padding * 2, 100, 10, true)
    
    gfx.setfont(1, "Arial", UI.normal_font_size)
    SetColor(Colors.text)
    local stats_y = y + 15
    DrawText("今日统计:", UI.padding + 15, stats_y, 0)
    
    stats_y = stats_y + 25
    local total_hours = math.floor(Config.today.total_time / 3600)
    local total_mins = math.floor((Config.today.total_time % 3600) / 60)
    DrawText(string.format("完成: %d个  |  总耗时: %dh %dm", 
        Config.today.completed, total_hours, total_mins), UI.padding + 15, stats_y, 0)
    
    stats_y = stats_y + 20
    DrawText(string.format("按时: %d个  |  超时: %d个", 
        Config.today.on_time, Config.today.overtime), UI.padding + 15, stats_y, 0)
    
    y = y + 110
    
    -- Combo显示
    gfx.setfont(1, "Arial", UI.normal_font_size)
    SetColor(Colors.text_dim)
    DrawText(string.format("Combo: %d  |  最高: %d", 
        Config.combo.current, Config.combo.max), w / 2, y, 1)
    
    y = y + 30
    
    -- 底部按钮
    local bottom_btn_width = 120
    btn_x = (w - (bottom_btn_width * 2 + btn_spacing)) / 2
    
    if DrawButton("完成", btn_x, y, bottom_btn_width, UI.button_height + 10, "complete") then
        Completion.Complete()
    end
    
    btn_x = btn_x + bottom_btn_width + btn_spacing
    if DrawButton("音效设置", btn_x, y, bottom_btn_width, UI.button_height + 10, "settings") then
        ui_state.show_settings = true
    end
    
    -- 绘制粒子
    DrawParticles()
    
    -- 闹钟闪烁效果
    if Alarm.active then
        Alarm.flash_time = Alarm.flash_time + 0.1
        local alpha = (math.sin(Alarm.flash_time * 10) + 1) / 2 * 0.3
        SetColor(Colors.danger, alpha)
        DrawRect(0, 0, w, h, true)
        
        -- 提示文字
        gfx.setfont(1, "Arial", 24, 'b')
        SetColor(Colors.text)
        DrawText("时间到了！", w / 2, h / 2 - 100, 1)
        
        -- 关闭按钮
        if DrawButton("关闭闹钟", w / 2 - 60, h / 2 - 50, 120, 40, "dismiss_alarm") then
            Alarm.Dismiss()
        end
    end
    
    -- 加班警告
    if OvertimeWarning.is_overtime then
        SetColor(Colors.warning, 0.1)
        DrawRect(0, 0, w, h, true)
        
        gfx.setfont(1, "Arial", UI.normal_font_size)
        SetColor(Colors.warning)
        local off_time_parts = {}
        for part in Config.settings.off_time:gmatch("%d+") do
            table.insert(off_time_parts, tonumber(part))
        end
        local off_minutes = (off_time_parts[1] or 19) * 60 + (off_time_parts[2] or 30)
        local current_time_parts = os.date("*t")
        local current_minutes = current_time_parts.hour * 60 + current_time_parts.min
        local overtime_mins = current_minutes - off_minutes
        DrawText(string.format("⚠ 已加班 %d 分钟", overtime_mins), w / 2, h - 30, 1)
    end
end

local function DrawSettingsUI()
    local w, h = gfx.w, gfx.h
    
    -- 半透明背景
    SetColor({0, 0, 0}, 0.7)
    DrawRect(0, 0, w, h, true)
    
    -- 设置面板
    local panel_w = 400
    local panel_h = 450
    local panel_x = (w - panel_w) / 2
    local panel_y = (h - panel_h) / 2
    
    SetColor(Colors.panel)
    DrawRoundRect(panel_x, panel_y, panel_w, panel_h, 10, true)
    
    -- 标题
    gfx.setfont(1, "Arial", UI.title_font_size, 'b')
    SetColor(Colors.text)
    DrawText("自定义音效设置", panel_x + panel_w / 2, panel_y + 20, 1)
    
    local y = panel_y + 60
    local row_height = 50
    
    gfx.setfont(1, "Arial", UI.normal_font_size)
    
    local sound_types = {
        {id = "complete", name = "普通完成"},
        {id = "combo3", name = "三连击"},
        {id = "combo5", name = "五连击(ACE)"},
        {id = "combo10", name = "十连击"},
        {id = "alarm", name = "闹钟提醒"},
        {id = "warning", name = "加班警告"}
    }
    
    for i, sound in ipairs(sound_types) do
        SetColor(Colors.text)
        DrawText(sound.name, panel_x + 20, y, 0)
        
        local has_custom = Config.sounds[sound.id] ~= "" and 
                          reaper.file_exists(Config.sounds[sound.id])
        SetColor(Colors.text_dim)
        local status = has_custom and "[自定义]" or "[默认]"
        DrawText(status, panel_x + 150, y, 0)
        
        if DrawButton("浏览", panel_x + panel_w - 90, y - 5, 70, 25, "browse_" .. sound.id) then
            SoundManager.BrowseSound(sound.id)
        end
        
        y = y + row_height
    end
    
    -- 底部按钮
    y = panel_y + panel_h - 60
    
    if DrawButton("恢复默认", panel_x + 20, y, 100, UI.button_height, "reset_sounds") then
        for k, _ in pairs(Config.sounds) do
            Config.sounds[k] = ""
        end
        SaveData()
    end
    
    if DrawButton("关闭", panel_x + panel_w - 120, y, 100, UI.button_height, "close_settings") then
        ui_state.show_settings = false
    end
end

-----------------------------------
-- 主循环
-----------------------------------

function MainLoop()
    -- 计算delta time
    local current_time = reaper.time_precise()
    local delta_time = current_time - last_time
    last_time = current_time
    
    -- 更新系统
    Timer.Update(delta_time)
    CatState.Update(delta_time)
    UpdateParticles(delta_time)
    
    -- 更新鼠标状态
    mouse.last_down = mouse.down
    mouse.x = gfx.mouse_x
    mouse.y = gfx.mouse_y
    mouse.down = gfx.mouse_cap & 1 == 1
    
    -- 绘制界面
    if ui_state.show_settings then
        DrawMainUI()
        DrawSettingsUI()
    else
        DrawMainUI()
    end
    
    -- 更新显示
    gfx.update()
    
    -- 检查窗口是否关闭
    if gfx.getchar() >= 0 then
        reaper.defer(MainLoop)
    else
        -- 保存数据
        SaveData()
        
        -- 清理音频预览
        if audio_preview then
            reaper.StopPreview(audio_preview)
        end
    end
end

-----------------------------------
-- 初始化
-----------------------------------

function Init()
    -- 加载数据
    LoadData()
    
    -- 初始化窗口
    gfx.init("FocusCat - 计时猫咪伴侣", UI.width, UI.height, 0)
    gfx.setfont(1, "Arial", UI.normal_font_size)
    
    -- 开始主循环
    MainLoop()
end

-- 启动脚本
Init()
