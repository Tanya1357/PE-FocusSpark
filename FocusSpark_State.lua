-- FocusSpark_State.lua
-- 状态管理模块：Redux 风格的集中状态管理

local State = {}

-- ============================================
-- 初始状态
-- ============================================
function State.initial()
    return {
        -- 工作目标设定
        target_total = 0,           -- 今日目标总数
        work_start_time = "09:00",  -- 上班时间 (HH:MM)
        work_end_time = "18:00",    -- 下班时间 (HH:MM)
        
        -- 进度追踪
        completed_count = 0,        -- 已完成数量
        session_start = 0,          -- 本次会话开始时间戳
        completion_times = {},      -- 每次完成的时间戳记录，用于计算速度
        
        -- 计时器状态
        is_working = false,         -- 是否正在工作（计时中）
        current_work_start = 0,    -- 当前工作开始时间戳
        current_work_estimated_duration = 0,  -- 当前工作预计耗时（分钟，0表示不设置）
        last_estimated_duration = 0,  -- 上次使用的预计耗时（分钟，用于记忆）
        
        -- 连击系统
        combo_count = 0,            -- 当前连击数
        combo_max = 0,              -- 最高连击数
        last_done_time = 0,         -- 上次完成时间
        combo_window = 20,          -- 连击时间窗口（分钟）
        
        -- 猫咪状态
        cat_state = "idle",         -- idle, happy, excited, grumpy, sleepy, warning, hissing
        cat_mood = 100,             -- 猫咪心情值 (0-100)
        cat_animation_start = 0,    -- 动画开始时间
        
        -- 特效状态
        effects = {},               -- 活跃的特效列表 { type, start_time, x, y, ... }
        
        -- 加班预警
        overtime_warned = false,    -- 是否已发出加班预警
        overtime_alerted = false,   -- 是否已发出加班警报
        
        -- UI 状态
        show_settings = false,      -- 是否显示设置面板
        input_target = "",          -- 目标输入框内容
        input_start_time = "",      -- 上班时间输入
        input_end_time = "",        -- 下班时间输入
        ui_layout_mode = "normal",  -- UI 布局模式: normal, embedded
        embedded_layout_locked = false,  -- 嵌入布局是否锁定（锁定后记住当前布局）
        embedded_layout_spacing = 8,  -- 锁定状态下记录的间距值
        embedded_layout_progress_width = 60,  -- 锁定状态下记录的进度条宽度
        
        -- 统计数据
        avg_time_per_item = 0,      -- 平均每个样本耗时（秒）
        estimated_finish = 0,       -- 预估完成时间戳
        remaining_items = 0,        -- 剩余数量
        is_overtime = false,        -- 是否需要加班
        
        -- 状态消息
        status_message = "",
    }
end

-- ============================================
-- 动作处理器 (Reducer)
-- ============================================
function State.reduce(state, action)
    if not action or not action.type then return state end
    
    local new_state = {}
    for k, v in pairs(state) do
        new_state[k] = v
    end
    
    if action.type == "setTarget" then
        new_state.target_total = tonumber(action.value) or 0
        new_state.remaining_items = new_state.target_total - new_state.completed_count
        
    elseif action.type == "setWorkStartTime" then
        new_state.work_start_time = action.value or "09:00"
        
    elseif action.type == "setWorkEndTime" then
        new_state.work_end_time = action.value or "18:00"
        
    elseif action.type == "setSessionStart" then
        new_state.session_start = action.value or os.time()  -- 使用系统时间戳
        
    elseif action.type == "startWork" then
        -- 检查是否已完成所有目标
        if state.target_total > 0 and state.completed_count >= state.target_total then
            return state  -- 已完成所有目标，不允许再开始计时
        end
        
        -- 开始计时
        new_state.is_working = true
        new_state.current_work_start = reaper.time_precise()
        local estimated = action.estimated_duration or 0
        new_state.current_work_estimated_duration = estimated
        -- 如果设置了预计耗时，保存为上次使用的值
        if estimated > 0 then
            new_state.last_estimated_duration = estimated
        end
        
    elseif action.type == "cancelWork" then
        -- 取消当前计时（不计入完成）
        if not state.is_working then return state end  -- 如果未开始计时，忽略
        
        new_state.is_working = false
        new_state.current_work_start = 0
        new_state.current_work_estimated_duration = 0
        new_state.cat_state = "idle"
        new_state.status_message = "计时已取消"
        
    elseif action.type == "done" then
        -- 记录完成（独立于计时）
        -- 检查是否已完成所有目标
        if state.target_total > 0 and state.completed_count >= state.target_total then
            return state  -- 已完成所有目标，不允许再完成
        end
        
        local now = action.time or os.time()  -- 使用系统时间戳
        new_state.completed_count = new_state.completed_count + 1
        new_state.remaining_items = new_state.target_total - new_state.completed_count
        
        -- 添加完成时间记录（只保留最近50条，避免数组过大）
        local times = {}
        local old_times = state.completion_times or {}
        local max_records = 50
        local start_idx = math.max(1, #old_times - max_records + 2)  -- 保留最后49条 + 新的一条
        
        for i = start_idx, #old_times do
            table.insert(times, old_times[i])
        end
        table.insert(times, now)
        new_state.completion_times = times
        
        -- 连击判定（combo_window 是分钟，需要转换为秒）
        local combo_window_seconds = (state.combo_window or 20) * 60
        if state.last_done_time > 0 and (now - state.last_done_time) <= combo_window_seconds then
            new_state.combo_count = state.combo_count + 1
        else
            new_state.combo_count = 1
        end
        new_state.last_done_time = now
        
        -- 更新最高连击
        if new_state.combo_count > state.combo_max then
            new_state.combo_max = new_state.combo_count
        end
        
        -- 计算平均耗时
        if #times >= 2 then
            local total_time = times[#times] - times[1]
            new_state.avg_time_per_item = total_time / (#times - 1)
        else
            -- 只有一条记录时，无法计算平均耗时，保持为0
            new_state.avg_time_per_item = 0
        end
        
    elseif action.type == "undoDone" then
        -- 撤销完成（减少完成数）
        if state.completed_count <= 0 then
            return state  -- 已经是0，不能再减
        end
        
        new_state.completed_count = new_state.completed_count - 1
        new_state.remaining_items = new_state.target_total - new_state.completed_count
        
        -- 移除最后一条完成时间记录
        local times = {}
        local old_times = state.completion_times or {}
        for i = 1, #old_times - 1 do
            table.insert(times, old_times[i])
        end
        new_state.completion_times = times
        
        -- 重置连击计数（撤销后连击中断）
        new_state.combo_count = 0
        
        -- 重新计算平均耗时
        if #times >= 2 then
            local total_time = times[#times] - times[1]
            new_state.avg_time_per_item = total_time / (#times - 1)
        else
            new_state.avg_time_per_item = 0
        end
        
    elseif action.type == "setCatState" then
        new_state.cat_state = action.value or "idle"
        new_state.cat_animation_start = reaper.time_precise()
        
    elseif action.type == "setCatMood" then
        new_state.cat_mood = math.max(0, math.min(100, action.value or 100))
        
    elseif action.type == "addEffect" then
        local effects = {}
        for i, e in ipairs(state.effects or {}) do
            effects[i] = e
        end
        table.insert(effects, action.effect)
        new_state.effects = effects
        
    elseif action.type == "cleanupEffects" then
        -- 清理已过期的特效
        local now = reaper.time_precise()
        local active = {}
        for _, e in ipairs(state.effects or {}) do
            if e.start_time and e.duration and (now - e.start_time) < e.duration then
                table.insert(active, e)
            end
        end
        new_state.effects = active
        
    elseif action.type == "setOvertimeWarned" then
        new_state.overtime_warned = action.value
        
    elseif action.type == "setOvertimeAlerted" then
        new_state.overtime_alerted = action.value
        
    elseif action.type == "setShowSettings" then
        new_state.show_settings = action.value
        
    elseif action.type == "setComboWindow" then
        new_state.combo_window = math.max(1, math.min(120, action.value or 20))  -- 限制在1-120分钟之间
        
    elseif action.type == "setLastEstimatedDuration" then
        new_state.last_estimated_duration = math.max(0, math.min(60, action.value or 0))  -- 滑块最大60分钟
        
    elseif action.type == "setLayoutMode" then
        local valid_modes = { normal = true, embedded = true }
        if valid_modes[action.value] then
            new_state.ui_layout_mode = action.value
        end
        
    elseif action.type == "toggleEmbeddedLayoutLock" then
        new_state.embedded_layout_locked = not state.embedded_layout_locked
        -- 如果正在锁定，记录当前的布局参数
        if new_state.embedded_layout_locked and action.spacing and action.progress_width then
            new_state.embedded_layout_spacing = action.spacing
            new_state.embedded_layout_progress_width = action.progress_width
        end
        
    elseif action.type == "setEmbeddedLayoutLock" then
        new_state.embedded_layout_locked = action.value == true
        if action.spacing then
            new_state.embedded_layout_spacing = action.spacing
        end
        if action.progress_width then
            new_state.embedded_layout_progress_width = action.progress_width
        end
        
    elseif action.type == "updateEstimate" then
        -- 更新时间估算
        local now = os.time()  -- 使用系统时间戳，而不是 reaper.time_precise()
        local remaining = new_state.target_total - new_state.completed_count
        new_state.remaining_items = remaining
        
        if new_state.avg_time_per_item > 0 and remaining > 0 then
            new_state.estimated_finish = now + (remaining * new_state.avg_time_per_item)
        elseif remaining <= 0 then
            new_state.estimated_finish = 0
        end
        
        -- 检查是否需要加班
        local work_end_ts = State.parseTimeToday(new_state.work_end_time)
        if work_end_ts and new_state.estimated_finish > 0 then
            new_state.is_overtime = new_state.estimated_finish > work_end_ts
        else
            new_state.is_overtime = false
        end
        
    elseif action.type == "setStatus" then
        new_state.status_message = action.message or ""
        
    elseif action.type == "reset" then
        -- 重置今日进度（保留设置）
        new_state.completed_count = 0
        new_state.completion_times = {}
        new_state.combo_count = 0
        new_state.combo_max = 0
        new_state.last_done_time = 0
        new_state.session_start = os.time()  -- 使用系统时间戳
        new_state.avg_time_per_item = 0
        new_state.estimated_finish = 0
        new_state.remaining_items = new_state.target_total
        new_state.is_overtime = false
        new_state.overtime_warned = false
        new_state.overtime_alerted = false
        new_state.cat_state = "idle"
        new_state.cat_mood = 100
        new_state.effects = {}
        new_state.is_working = false
        new_state.current_work_start = 0
        new_state.current_work_estimated_duration = 0
        
    elseif action.type == "loadState" then
        -- 从持久化数据加载
        for k, v in pairs(action.data or {}) do
            new_state[k] = v
        end
    end
    
    return new_state
end

-- ============================================
-- 辅助函数
-- ============================================

-- 解析时间字符串为今天的时间戳
function State.parseTimeToday(time_str)
    if not time_str or time_str == "" then return nil end
    
    local h, m = time_str:match("(%d+):(%d+)")
    if not h then return nil end
    
    local now = os.time()
    local today = os.date("*t", now)
    
    return os.time({
        year = today.year,
        month = today.month,
        day = today.day,
        hour = tonumber(h) or 0,
        min = tonumber(m) or 0,
        sec = 0
    })
end

-- 格式化时间戳为时间字符串
function State.formatTime(timestamp)
    if not timestamp or timestamp <= 0 then return "--:--" end
    -- os.date 需要整数时间戳，转换为整数
    return os.date("%H:%M", math.floor(timestamp))
end

-- 格式化持续时间
function State.formatDuration(seconds)
    if not seconds or seconds <= 0 then return "0分钟" end
    
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    
    if hours > 0 then
        return string.format("%d小时%d分钟", hours, minutes)
    else
        return string.format("%d分钟", minutes)
    end
end

-- 计算进度百分比
function State.getProgress(state)
    if state.target_total <= 0 then return 0 end
    return math.min(1, state.completed_count / state.target_total)
end

-- 获取猫咪应该的状态（基于当前情况）
function State.suggestCatState(state)
    local now = os.time()  -- 使用系统时间戳，与 last_done_time 保持一致
    
    -- 刚完成任务：兴奋（3秒内）
    if state.last_done_time > 0 and (now - state.last_done_time) < 3 then
        if state.combo_count >= 5 then
            return "excited"  -- 大连击，超级兴奋
        else
            return "happy"    -- 普通开心
        end
    end
    
    -- 计时器状态检查（优先级高）- 这里需要用 reaper.time_precise() 因为 current_work_start 用的是它
    if state.is_working and state.current_work_start > 0 then
        local elapsed = reaper.time_precise() - state.current_work_start
        
        -- 如果有预计耗时，检查是否超时或接近超时
        if state.current_work_estimated_duration > 0 then
            local estimated_sec = state.current_work_estimated_duration * 60
            local remaining = estimated_sec - elapsed
            local progress = elapsed / estimated_sec
            
            if remaining <= 0 then
                -- 已经超时：哈气（更紧张）
                return "hissing"
            elseif progress >= 0.95 then
                -- 剩余时间少于5%：哈气警告
                return "hissing"
            elseif progress >= 0.9 then
                -- 剩余时间少于10%：警告状态
                return "warning"
            end
        end
    end
    
    -- 加班状态：焦躁/生气
    if state.is_overtime then
        local work_end = State.parseTimeToday(state.work_end_time)
        if work_end and os.time() > work_end then
            return "grumpy"   -- 已经加班，生气
        else
            return "warning"  -- 即将加班，警告
        end
    end
    
    -- 完成所有任务
    if state.target_total > 0 and state.completed_count >= state.target_total then
        return "sleepy"       -- 可以休息了
    end
    
    -- 长时间未操作
    if state.last_done_time > 0 and (now - state.last_done_time) > 300 then
        return "sleepy"       -- 打瞌睡
    end
    
    return "idle"
end

return State

