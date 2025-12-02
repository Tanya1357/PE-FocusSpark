-- @description PhaseEggplant FocusSpark - 摸鱼猫咪工作伴侣
-- @version 1.0
-- @author PhaseEggplant
-- @about
--   一个可爱的工作进度追踪工具，用猫咪陪伴你完成每一个音效样本！
--   
--   功能特点：
--   - 🐱 可爱猫咪根据工作状态变化表情
--   - ✨ 完成任务触发特效动画和音效
--   - 🔥 连击系统：快速完成多个样本获得连击奖励
--   - ⏰ 智能加班预警：根据平均速度预估完成时间
--   - 🎵 支持自定义音效（如瓦罗兰特连杀音效）
--   
--   依赖: ReaImGui v0.9+
--   数据存储: 脚本同目录下的配置文件

-- ============================================
-- 路径设置
-- ============================================
local function get_script_dir()
    local info = debug.getinfo(1, 'S')
    local src = info and info.source or ''
    if src:sub(1, 1) == '@' then src = src:sub(2) end
    return src:match('^(.+[\\/])[^\\/]+$') or ''
end

local SCRIPT_DIR = get_script_dir()

-- 添加脚本目录到 package.path
if SCRIPT_DIR ~= '' and not package.path:find(SCRIPT_DIR, 1, true) then
    package.path = SCRIPT_DIR .. '?.lua;' .. package.path
end

-- ============================================
-- 检查依赖
-- ============================================
if not reaper or not reaper.ImGui_CreateContext then
    reaper.MB(
        '需要安装 ReaImGui 扩展！\n\n' ..
        '请通过 ReaPack 安装:\n' ..
        '1. Extensions > ReaPack > Browse packages\n' ..
        '2. 搜索 "ReaImGui"\n' ..
        '3. 安装后重启 REAPER',
        'FocusSpark - 缺少依赖',
        0
    )
    return
end

-- ============================================
-- 加载模块
-- ============================================
local State = require('FocusSpark_State')
local Data = require('FocusSpark_Data')
local Sound = require('FocusSpark_Sound')
local Cat = require('FocusSpark_Cat')
local UI = require('FocusSpark_UI')

-- 初始化模块
Sound.init(Data)
UI.init(State, Cat)

-- ============================================
-- 创建 ImGui 上下文
-- ============================================
local ctx = reaper.ImGui_CreateContext('FocusSpark')

-- ============================================
-- 应用状态
-- ============================================
local state = State.initial()
local last_save_time = 0
local SAVE_INTERVAL = 5  -- 每5秒自动保存（减少延迟）
local pending_save = false  -- 标记是否有待保存的更改

-- ============================================
-- 初始化：加载已保存的数据
-- ============================================
local function init()
    -- 尝试加载今日进度
    local saved = Data.loadDayProgress()
    if saved then
        state = State.reduce(state, { type = "loadState", data = saved })
        state = State.reduce(state, { type = "updateEstimate" })
    else
        -- 新的一天，加载设置
        local settings = Data.loadSettings()
        if settings then
            if settings.target_total then
                state = State.reduce(state, { type = "setTarget", value = settings.target_total })
            end
            if settings.work_start_time then
                state = State.reduce(state, { type = "setWorkStartTime", value = settings.work_start_time })
            end
            if settings.work_end_time then
                state = State.reduce(state, { type = "setWorkEndTime", value = settings.work_end_time })
            end
            if settings.combo_window then
                state = State.reduce(state, { type = "setComboWindow", value = settings.combo_window })
            end
            if settings.last_estimated_duration then
                state = State.reduce(state, { type = "setLastEstimatedDuration", value = settings.last_estimated_duration })
            end
            if settings.ui_layout_mode then
                state = State.reduce(state, { type = "setLayoutMode", value = settings.ui_layout_mode })
            end
            if settings.embedded_layout_locked ~= nil then
                state = State.reduce(state, { 
                    type = "setEmbeddedLayoutLock", 
                    value = settings.embedded_layout_locked,
                    spacing = settings.embedded_layout_spacing,
                    progress_width = settings.embedded_layout_progress_width
                })
            end
        end
        state = State.reduce(state, { type = "setSessionStart", value = os.time() })
    end
end

init()

-- ============================================
-- 动作处理
-- ============================================
local function handleAction(action)
    if not action or not action.type then return end
    
    local prev_completed = state.completed_count
    local prev_overtime_warned = state.overtime_warned
    
    -- 处理状态更新
    state = State.reduce(state, action)
    
    -- 特殊处理
    if action.type == "cancelWork" then
        -- 取消计时时的处理
        state = State.reduce(state, { type = "setCatState", value = "idle" })
        
    elseif action.type == "startWork" then
        -- 开始计时时的处理
        state = State.reduce(state, { type = "setCatState", value = "happy" })
        -- 如果设置了预计耗时，立即保存设置（因为会更新 last_estimated_duration）
        if action.estimated_duration and action.estimated_duration > 0 then
            Data.saveSettings({
                target_total = state.target_total,
                work_start_time = state.work_start_time,
                work_end_time = state.work_end_time,
                combo_window = state.combo_window,
                last_estimated_duration = state.last_estimated_duration,
                ui_layout_mode = state.ui_layout_mode,
                embedded_layout_locked = state.embedded_layout_locked,
            })
        end
        
    elseif action.type == "undoDone" then
        -- 撤销完成时的处理
        state = State.reduce(state, { type = "updateEstimate" })
        state = State.reduce(state, { type = "setCatState", value = "idle" })
        pending_save = true
        
    elseif action.type == "done" then
        -- 更新估算
        state = State.reduce(state, { type = "updateEstimate" })
        
        -- 播放音效
        Sound.playDone(state.combo_count)
        
        -- 添加粒子特效
        local effect_type = "heart"
        local effect_count = 5
        
        if state.combo_count >= 5 then
            effect_type = "star"
            effect_count = 12
        elseif state.combo_count >= 3 then
            effect_type = "spark"
            effect_count = 8
        end
        
        state = State.reduce(state, {
            type = "addEffect",
            effect = {
                type = effect_type,
                start_time = reaper.time_precise(),
                duration = 1.5,
                count = effect_count,
                color = state.combo_count >= 5 and 0xFFD700 or 0xFF69B4
            }
        })
        
        -- 更新猫咪状态
        local new_cat_state = state.combo_count >= 5 and "excited" or "happy"
        state = State.reduce(state, { type = "setCatState", value = new_cat_state })
        
        -- 检查是否完成全部目标
        if state.target_total > 0 and state.completed_count >= state.target_total then
            Sound.playComplete()
            state = State.reduce(state, {
                type = "addEffect",
                effect = {
                    type = "star",
                    start_time = reaper.time_precise(),
                    duration = 3,
                    count = 20,
                    color = 0xFFD700
                }
            })
        end
        
        -- 标记需要保存（由定期任务处理，避免阻塞）
        pending_save = true
        
    elseif action.type == "setTarget" then
        state = State.reduce(state, { type = "updateEstimate" })
        pending_save = true
        Data.saveSettings({
            target_total = state.target_total,
            work_start_time = state.work_start_time,
            work_end_time = state.work_end_time,
            combo_window = state.combo_window,
            last_estimated_duration = state.last_estimated_duration,
            ui_layout_mode = state.ui_layout_mode,
        })
        
    elseif action.type == "setWorkStartTime" or action.type == "setWorkEndTime" then
        state = State.reduce(state, { type = "updateEstimate" })
        pending_save = true
        Data.saveSettings({
            target_total = state.target_total,
            work_start_time = state.work_start_time,
            work_end_time = state.work_end_time,
            combo_window = state.combo_window,
            last_estimated_duration = state.last_estimated_duration,
            ui_layout_mode = state.ui_layout_mode,
            embedded_layout_locked = state.embedded_layout_locked,
            embedded_layout_spacing = state.embedded_layout_spacing,
            embedded_layout_progress_width = state.embedded_layout_progress_width,
        })
        
    elseif action.type == "reset" then
        state = State.reduce(state, { type = "updateEstimate" })
        pending_save = true
        
    elseif action.type == "setLayoutMode" then
        -- 切换布局模式并保存设置
        pending_save = true
        Data.saveSettings({
            target_total = state.target_total,
            work_start_time = state.work_start_time,
            work_end_time = state.work_end_time,
            combo_window = state.combo_window,
            last_estimated_duration = state.last_estimated_duration,
            ui_layout_mode = state.ui_layout_mode,
            embedded_layout_locked = state.embedded_layout_locked,
            embedded_layout_spacing = state.embedded_layout_spacing,
            embedded_layout_progress_width = state.embedded_layout_progress_width,
        })
        
    elseif action.type == "toggleEmbeddedLayoutLock" then
        -- 切换嵌入布局锁定状态并保存
        pending_save = true
        Data.saveSettings({
            target_total = state.target_total,
            work_start_time = state.work_start_time,
            work_end_time = state.work_end_time,
            combo_window = state.combo_window,
            last_estimated_duration = state.last_estimated_duration,
            ui_layout_mode = state.ui_layout_mode,
            embedded_layout_locked = state.embedded_layout_locked,
            embedded_layout_spacing = state.embedded_layout_spacing,
            embedded_layout_progress_width = state.embedded_layout_progress_width,
        })
        
    elseif action.type == "saveSettings" then
        Data.saveSettings({
            target_total = state.target_total,
            work_start_time = state.work_start_time,
            work_end_time = state.work_end_time,
            combo_window = state.combo_window,
            last_estimated_duration = state.last_estimated_duration,
            ui_layout_mode = state.ui_layout_mode,
            embedded_layout_locked = state.embedded_layout_locked,
            embedded_layout_spacing = state.embedded_layout_spacing,
            embedded_layout_progress_width = state.embedded_layout_progress_width,
        })
    end
    
    -- 加班预警检测
    if state.is_overtime and not prev_overtime_warned and not state.overtime_warned then
        state = State.reduce(state, { type = "setOvertimeWarned", value = true })
        Sound.playOvertimeWarn()
        state = State.reduce(state, { type = "setCatState", value = "warning" })
        state = State.reduce(state, {
            type = "addEffect",
            effect = {
                type = "warning",
                start_time = reaper.time_precise(),
                duration = 2,
                count = 6,
                color = 0xFF6B6B
            }
        })
    end
end

-- ============================================
-- 定期任务
-- ============================================
local function periodicTasks()
    local now = reaper.time_precise()
    
    -- 清理过期特效
    state = State.reduce(state, { type = "cleanupEffects" })
    
    -- 自动更新估算
    state = State.reduce(state, { type = "updateEstimate" })
    
    -- 自动保存（只在有更改时保存）
    if pending_save and (now - last_save_time > SAVE_INTERVAL) then
        Data.saveDayProgress(state)
        last_save_time = now
        pending_save = false
    end
    
    -- 检查加班警报（已过下班时间）
    local work_end = State.parseTimeToday(state.work_end_time)
    if work_end and os.time() > work_end then
        if state.remaining_items > 0 and not state.overtime_alerted then
            state = State.reduce(state, { type = "setOvertimeAlerted", value = true })
            Sound.playOvertimeAlert()
            state = State.reduce(state, { type = "setCatState", value = "grumpy" })
        end
    end
end

-- ============================================
-- 主循环
-- ============================================
local open = true
local last_layout_mode = nil  -- 追踪布局模式变化

local function loop()
    if not open then
        -- 退出前保存（如果有待保存的更改）
        if pending_save then
            Data.saveDayProgress(state)
        end
        reaper.ImGui_DestroyContext(ctx)
        return
    end
    
    -- 定期任务
    periodicTasks()
    
    -- 窗口样式（根据布局模式调整）
    local layout_mode = state.ui_layout_mode or "normal"
    local layout_size = UI.getLayoutSize(layout_mode)
    local padding = layout_mode == "normal" and 15 or 8
    local rounding = layout_mode == "normal" and 10 or 6
    
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), rounding)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 6)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), padding, padding)
    
    -- 颜色主题
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), 0x2A2D3EFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(), 0x363A4FFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(), 0x4ECDC4FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xE8E8E8FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), 0x363A4FFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x4A4E5FFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x5A5E6FFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Separator(), 0x444444FF)
    
    -- 窗口尺寸设置
    if last_layout_mode ~= layout_mode then
        -- 布局模式改变，强制调整窗口大小
        reaper.ImGui_SetNextWindowSize(ctx, layout_size.width, layout_size.height, reaper.ImGui_Cond_Always())
        last_layout_mode = layout_mode
    else
        -- 首次使用时设置默认大小
        reaper.ImGui_SetNextWindowSize(ctx, layout_size.width, layout_size.height, reaper.ImGui_Cond_FirstUseEver())
    end
    
    -- 窗口标题（根据布局模式调整）
    local window_title = layout_mode == "normal" and '🐱 FocusSpark' or '🐱'
    local window_flags = reaper.ImGui_WindowFlags_NoCollapse()
    
    -- 嵌入模式允许调整大小（适应不同宽度），但保持最小高度
    -- 不设置 NoResize，让用户可以调整宽度以适应嵌入位置
    
    local visible, new_open = reaper.ImGui_Begin(ctx, window_title, true, window_flags)
    open = new_open
    
    if visible then
        -- 绘制 UI 并获取动作
        local actions = UI.draw(ctx, state)
        
        -- 处理动作
        if actions then
            for _, action in ipairs(actions) do
                handleAction(action)
            end
        end
        
        -- 状态栏（仅普通模式显示）
        if layout_mode == "normal" and state.status_message and state.status_message ~= "" then
            reaper.ImGui_Separator(ctx)
            reaper.ImGui_TextDisabled(ctx, state.status_message)
        end
    end
    
    reaper.ImGui_End(ctx)
    
    reaper.ImGui_PopStyleColor(ctx, 8)
    reaper.ImGui_PopStyleVar(ctx, 3)
    
    reaper.defer(loop)
end

-- ============================================
-- 启动
-- ============================================
reaper.defer(loop)

