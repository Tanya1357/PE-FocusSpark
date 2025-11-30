-- FocusSpark_UI.lua
-- 界面模块：绘制主界面、处理用户交互

local UI = {}

-- 依赖模块（由 Main 注入）
local State, Cat

function UI.init(StateModule, CatModule)
    State = StateModule
    Cat = CatModule
end

-- ============================================
-- 布局模式配置
-- ============================================
UI.LAYOUT_MODES = {
    NORMAL = "normal",      -- 普通布局（完整功能）
    EMBEDDED = "embedded",  -- 嵌入式布局（横向长条形）
}

-- 各布局的窗口尺寸
UI.LAYOUT_SIZES = {
    normal = { width = 350, height = 480 },
    embedded = { width = 400, height = 50 },  -- 横向长条形（紧凑高度）
}

-- 获取当前布局的窗口尺寸
function UI.getLayoutSize(layout_mode)
    return UI.LAYOUT_SIZES[layout_mode] or UI.LAYOUT_SIZES.normal
end

-- ============================================
-- 颜色配置（可爱俏皮风格）
-- ============================================
local COLORS = {
    bg = 0x2A2D3EFF,                -- 深蓝灰背景
    bg_panel = 0x363A4FFF,          -- 面板背景
    accent = 0x4ECDC4FF,            -- 薄荷绿强调色
    accent_hover = 0x6EDDD6FF,      -- 悬停色
    warning = 0xFFA500FF,           -- 橙色警告
    danger = 0xFF6B6BFF,            -- 红色危险
    success = 0x98D8C8FF,           -- 成功绿（用于开始按钮）
    gold = 0xFFD700FF,              -- 金色
    text = 0xE8E8E8FF,              -- 主文字
    text_dim = 0x888888FF,          -- 次要文字
    text_bright = 0xFFFFFFFF,       -- 高亮文字
    separator = 0x444444FF,         -- 分隔线
}

-- ============================================
-- 主绘制入口（根据布局模式路由）
-- ============================================
function UI.draw(ctx, state)
    local layout_mode = state.ui_layout_mode or UI.LAYOUT_MODES.NORMAL
    
    if layout_mode == UI.LAYOUT_MODES.EMBEDDED then
        return UI.drawEmbedded(ctx, state)
    else
        return UI.drawNormal(ctx, state)
    end
end

-- ============================================
-- 普通布局（完整功能）
-- ============================================
function UI.drawNormal(ctx, state)
    local actions = {}
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local content_width = reaper.ImGui_GetContentRegionAvail(ctx)
    
    -- ========== 标题栏 ==========
    UI.drawHeader(ctx, state, actions)
    
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    
    -- ========== 猫咪区域 ==========
    UI.drawCatArea(ctx, draw_list, state)
    
    reaper.ImGui_Spacing(ctx)
    
    -- ========== 进度区域 ==========
    UI.drawProgressArea(ctx, draw_list, state, content_width, actions)
    
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    
    -- ========== 统计信息 ==========
    UI.drawStats(ctx, state)
    
    reaper.ImGui_Spacing(ctx)
    
    -- ========== 操作按钮 ==========
    UI.drawActions(ctx, state, actions, content_width)
    
    -- ========== 设置面板 ==========
    if state.show_settings then
        UI.drawSettingsPanel(ctx, state, actions)
    end
    
    return actions
end

-- ============================================
-- 标题栏
-- ============================================
function UI.drawHeader(ctx, state, actions)
    local content_width = reaper.ImGui_GetContentRegionAvail(ctx)
    
    -- 左侧：标题和日期
    reaper.ImGui_TextColored(ctx, COLORS.accent, "🐱 FocusSpark")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextDisabled(ctx, " - " .. os.date("%Y年%m月%d日"))
    
    -- 右侧按钮组
    -- 布局切换按钮
    reaper.ImGui_SameLine(ctx, content_width - 55)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x44444444)
    
    if reaper.ImGui_Button(ctx, "▪️", 22, 22) then
        table.insert(actions, { type = "setLayoutMode", value = "embedded" })
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "切换到嵌入模式")
    end
    
    reaper.ImGui_PopStyleColor(ctx, 2)
    
    -- 设置按钮
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "⚙️") then
        table.insert(actions, { type = "setShowSettings", value = not state.show_settings })
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "设置")
    end
end

-- ============================================
-- 猫咪显示区域
-- ============================================
function UI.drawCatArea(ctx, draw_list, state)
    local avail_w = reaper.ImGui_GetContentRegionAvail(ctx)
    local cat_height = 100
    
    -- 背景面板
    local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x, y, x + avail_w, y + cat_height, COLORS.bg_panel, 8)
    
    -- 获取当前猫咪状态
    local cat_state = State.suggestCatState(state)
    
    -- 绘制大号 Emoji 猫咪（居中）
    local emoji = Cat.getEmoji(cat_state)
    
    local emoji_w, emoji_h = reaper.ImGui_CalcTextSize(ctx, emoji)
    local emoji_x = x + (avail_w - emoji_w) / 2
    local emoji_y = y + (cat_height - emoji_h) / 2  -- 垂直居中
    
    -- 添加动画效果
    local now = reaper.time_precise()
    local bounce = 0
    local shake_x = 0
    
    if cat_state == "excited" then
        bounce = math.sin(now * 10) * 5
    elseif cat_state == "happy" then
        bounce = math.sin(now * 5) * 3
    elseif cat_state == "grumpy" then
        shake_x = math.sin(now * 20) * 3
    elseif cat_state == "warning" then
        shake_x = math.sin(now * 15) * 2
    elseif cat_state == "hissing" then
        shake_x = math.sin(now * 25) * 4  -- 哈气时更剧烈的震动
    end
    
    -- 计算猫咪位置（考虑动画）
    local cat_center_x = emoji_x + emoji_w / 2 + shake_x
    local cat_top_y = emoji_y - bounce  -- 猫咪顶部位置
    
    -- 绘制猫咪 Emoji（使用 Text 因为 DrawList 对 emoji 支持有限）
    reaper.ImGui_SetCursorScreenPos(ctx, emoji_x + shake_x, emoji_y - bounce)
    
    local emoji_color = COLORS.text_bright
    if cat_state == "grumpy" then
        emoji_color = COLORS.danger
    elseif cat_state == "warning" then
        emoji_color = COLORS.warning
    elseif cat_state == "excited" then
        emoji_color = COLORS.gold
    elseif cat_state == "hissing" then
        emoji_color = COLORS.warning  -- 深橙色警告色
    end
    
    reaper.ImGui_TextColored(ctx, emoji_color, emoji)
    
    -- 绘制粒子特效
    Cat.drawParticles(ctx, draw_list, state.effects, x + avail_w / 2, y + cat_height / 2)
    
    -- 连击显示（在猫咪头上方）
    if state.combo_count >= 2 then
        -- 特效位置：水平居中，垂直在猫咪顶部上方
        Cat.drawCombo(ctx, draw_list, cat_center_x, cat_top_y, state.combo_count, state.last_done_time)
    end
    
    -- 状态描述
    local status_text = UI.getCatStatusText(cat_state, state)
    local status_w = reaper.ImGui_CalcTextSize(ctx, status_text)
    reaper.ImGui_SetCursorScreenPos(ctx, x + (avail_w - status_w) / 2, y + cat_height - 22)
    reaper.ImGui_TextDisabled(ctx, status_text)
    
    -- 预留空间
    reaper.ImGui_SetCursorScreenPos(ctx, x, y + cat_height + 5)
    reaper.ImGui_Dummy(ctx, avail_w, 5)
end

function UI.getCatStatusText(cat_state, state)
    -- 只使用状态切换时间作为种子，确保同一状态下台词固定，状态切换时才会变化
    local anim_time = state.cat_animation_start or 0
    local seed = math.floor(anim_time * 100) % 1000
    
    if cat_state == "idle" then
        local texts = {
            "猫咪在等你工作...",
            "喵~ 准备好了吗？",
            "猫咪在打盹...等你开始~",
            "🐱 猫咪在观察你...",
            "该开始工作了喵~",
        }
        return texts[(seed % #texts) + 1]
        
    elseif cat_state == "happy" then
        local texts = {
            "喵~ 干得不错！",
            "😸 很棒哦！继续加油！",
            "猫咪很开心！做得很好~",
            "喵喵~ 真厉害！",
            "😻 猫咪为你骄傲！",
            "做得好！猫咪很满意~",
        }
        return texts[(seed % #texts) + 1]
        
    elseif cat_state == "excited" then
        if state.combo_count >= 5 then
            local texts = {
                "🔥 猫咪已经疯狂！" .. state.combo_count .. "连击！",
                "🎉 太强了！" .. state.combo_count .. "连击！猫咪震惊！",
                "💥 不可思议！" .. state.combo_count .. "连击！",
                "🌟 猫咪被震撼了！" .. state.combo_count .. "连击！",
                "⚡ 这速度！" .. state.combo_count .. "连击！猫咪兴奋！",
            }
            return texts[(seed % #texts) + 1]
        else
            local texts = {
                "✨ 猫咪超级开心！",
                "🎊 太棒了！猫咪在欢呼！",
                "💖 猫咪兴奋得跳起来！",
                "🌟 做得好！猫咪超开心！",
                "🎈 猫咪为你庆祝！",
            }
            return texts[(seed % #texts) + 1]
        end
        
    elseif cat_state == "sleepy" then
        if state.completed_count >= state.target_total and state.target_total > 0 then
            local texts = {
                "目标完成！猫咪满足地睡着了~",
                "🎉 全部完成！猫咪安心地睡了~",
                "✨ 任务完成！猫咪心满意足~",
                "💤 做完了！猫咪可以休息了~",
                "😴 完美！猫咪满足地打盹~",
            }
            return texts[(seed % #texts) + 1]
        else
            local texts = {
                "Zzz... 该休息一下了...",
                "💤 猫咪在打瞌睡...",
                "😴 猫咪困了...休息一下吧~",
                "Zzz... 长时间没动静...",
                "💤 猫咪在等你...",
            }
            return texts[(seed % #texts) + 1]
        end
        
    elseif cat_state == "warning" then
        local texts = {
            "⚠️ 猫咪有点焦虑...要加班了吗？",
            "😾 猫咪在担心...时间不多了",
            "⚠️ 猫咪提醒你：注意时间！",
            "😿 猫咪有点紧张...快下班了",
            "⚠️ 猫咪在观察...时间紧迫",
        }
        return texts[(seed % #texts) + 1]
        
    elseif cat_state == "grumpy" then
        local texts = {
            "💢 猫咪生气了！太晚了！",
            "😾 猫咪很生气！该下班了！",
            "💢 猫咪炸毛了！已经加班了！",
            "😡 猫咪不满！太晚了！",
            "💢 猫咪在抗议！该休息了！",
        }
        return texts[(seed % #texts) + 1]
        
    elseif cat_state == "hissing" then
        -- 检查是否是计时器相关
        if state.is_working and state.current_work_estimated_duration > 0 then
            local elapsed = reaper.time_precise() - state.current_work_start
            local estimated_sec = state.current_work_estimated_duration * 60
            if elapsed >= estimated_sec then
                local texts = {
                    "💨 猫咪在哈气！时间超了！",
                    "😾💨 超时了！猫咪很紧张！",
                    "💨 时间过了！猫咪在警告！",
                    "😿💨 超时了！猫咪很担心！",
                }
                return texts[(seed % #texts) + 1]
            else
                local texts = {
                    "💨 猫咪紧张地哈气...时间快到了！",
                    "😾💨 时间紧迫！猫咪在提醒！",
                    "💨 快没时间了！猫咪很紧张！",
                    "😿💨 时间快到了！猫咪在警告！",
                }
                return texts[(seed % #texts) + 1]
            end
        else
            local texts = {
                "💨 猫咪在哈气...",
                "😾💨 猫咪有点紧张...",
                "💨 猫咪在警告...",
            }
            return texts[(seed % #texts) + 1]
        end
    end
    return ""
end

-- ============================================
-- 进度区域
-- ============================================
function UI.drawProgressArea(ctx, draw_list, state, width, actions)
    actions = actions or {}
    local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
    local progress = State.getProgress(state)
    local cat_state = State.suggestCatState(state)
    
    -- 进度条
    local bar_height = 20
    Cat.drawProgressBar(ctx, draw_list, x, y, width, bar_height, progress, cat_state)
    
    -- 进度文字
    local progress_text = string.format("%d / %d", state.completed_count, state.target_total)
    local percent_text = string.format("%.0f%%", progress * 100)
    
    reaper.ImGui_SetCursorScreenPos(ctx, x + 10, y + 2)
    reaper.ImGui_Text(ctx, progress_text)
    
    local percent_w = reaper.ImGui_CalcTextSize(ctx, percent_text)
    reaper.ImGui_SetCursorScreenPos(ctx, x + width - percent_w - 25, y + 2)  -- 留空间给鱼干图标
    reaper.ImGui_Text(ctx, percent_text)
    
    -- 添加不可见按钮来检测滚轮（覆盖整个进度条区域）
    reaper.ImGui_SetCursorScreenPos(ctx, x, y)
    reaper.ImGui_InvisibleButton(ctx, "##progress_area", width, bar_height)
    
    -- 检测滚轮调整目标数量
    if reaper.ImGui_IsItemHovered(ctx) then
        local wheel = reaper.ImGui_GetMouseWheel(ctx)
        if wheel ~= 0 then
            local new_target = state.target_total + (wheel > 0 and 1 or -1)
            new_target = math.max(0, math.min(999, new_target))  -- 限制范围 0-999
            if new_target ~= state.target_total then
                table.insert(actions, { type = "setTarget", value = new_target })
            end
        end
        
        -- 工具提示
        reaper.ImGui_SetTooltip(ctx, "滚动鼠标滚轮调整目标数量\n当前: " .. state.target_total .. " 个样本")
    end
    
    -- 预留空间
    reaper.ImGui_SetCursorScreenPos(ctx, x, y + bar_height + 5)
    reaper.ImGui_Dummy(ctx, width, 5)
    
    -- 加班预警（如果需要）
    if state.is_overtime then
        local overtime_minutes = 0
        local work_end = State.parseTimeToday(state.work_end_time)
        if work_end and state.estimated_finish > 0 then
            overtime_minutes = math.ceil((state.estimated_finish - work_end) / 60)
        end
        
        Cat.drawOvertimeWarning(ctx, draw_list, x, y + bar_height + 10, width, true, overtime_minutes)
        reaper.ImGui_Dummy(ctx, width, 30)
    end
end

-- ============================================
-- 统计信息
-- ============================================
function UI.drawStats(ctx, state)
    local avail_w = reaper.ImGui_GetContentRegionAvail(ctx)
    local col_w = avail_w / 3
    
    -- 表格布局
    if reaper.ImGui_BeginTable(ctx, "stats", 3) then
        reaper.ImGui_TableNextRow(ctx)
        
        -- 平均速度
        reaper.ImGui_TableNextColumn(ctx)
        reaper.ImGui_TextDisabled(ctx, "平均速度")
        if state.avg_time_per_item > 0 then
            reaper.ImGui_TextColored(ctx, COLORS.accent, State.formatDuration(state.avg_time_per_item) .. "/个")
        else
            reaper.ImGui_Text(ctx, "--")
        end
        
        -- 剩余数量
        reaper.ImGui_TableNextColumn(ctx)
        reaper.ImGui_TextDisabled(ctx, "剩余数量")
        local remain_color = state.remaining_items > 0 and COLORS.text or COLORS.success
        reaper.ImGui_TextColored(ctx, remain_color, tostring(state.remaining_items))
        
        -- 预计完成
        reaper.ImGui_TableNextColumn(ctx)
        reaper.ImGui_TextDisabled(ctx, "预计完成")
        if state.estimated_finish > 0 then
            local finish_color = state.is_overtime and COLORS.danger or COLORS.success
            reaper.ImGui_TextColored(ctx, finish_color, State.formatTime(state.estimated_finish))
        else
            reaper.ImGui_Text(ctx, "--:--")
        end
        
        reaper.ImGui_EndTable(ctx)
    end
    
    -- 第二行统计
    if reaper.ImGui_BeginTable(ctx, "stats2", 3) then
        reaper.ImGui_TableNextRow(ctx)
        
        -- 最高连击
        reaper.ImGui_TableNextColumn(ctx)
        reaper.ImGui_TextDisabled(ctx, "最高连击")
        local combo_color = state.combo_max >= 5 and COLORS.gold or COLORS.text
        reaper.ImGui_TextColored(ctx, combo_color, tostring(state.combo_max) .. "x")
        
        -- 下班时间
        reaper.ImGui_TableNextColumn(ctx)
        reaper.ImGui_TextDisabled(ctx, "下班时间")
        reaper.ImGui_Text(ctx, state.work_end_time)
        
        -- 当前时间
        reaper.ImGui_TableNextColumn(ctx)
        reaper.ImGui_TextDisabled(ctx, "当前时间")
        reaper.ImGui_Text(ctx, os.date("%H:%M"))
        
        reaper.ImGui_EndTable(ctx)
    end
end

-- ============================================
-- 操作按钮
-- ============================================
function UI.drawActions(ctx, state, actions, width)
    local btn_width = (width - 20) / 2
    local btn_height = state.is_working and 60 or 50  -- 计时中需要更多空间显示时间
    
    -- 检查是否已完成所有目标
    local is_completed = state.target_total > 0 and state.completed_count >= state.target_total
    
    if state.is_working then
        -- ===== 正在计时：显示 DONE 按钮和倒计时 =====
        local elapsed = reaper.time_precise() - state.current_work_start
        local elapsed_min = math.floor(elapsed / 60)
        local elapsed_sec = math.floor(elapsed % 60)
        local elapsed_text = string.format("%02d:%02d", elapsed_min, elapsed_sec)
        
        -- 计算倒计时或已用时间
        local display_text = ""
        local time_color = COLORS.accent
        local button_color = COLORS.accent
        
        if state.current_work_estimated_duration > 0 then
            -- 有预计耗时：显示倒计时
            local estimated_sec = state.current_work_estimated_duration * 60
            local remaining = estimated_sec - elapsed
            local remaining_min = math.floor(remaining / 60)
            local remaining_sec = math.floor(remaining % 60)
            
            if remaining > 0 then
                display_text = string.format("剩余 %02d:%02d", remaining_min, remaining_sec)
                -- 剩余时间少于10%时变橙色，少于5%时变红色
                local progress = elapsed / estimated_sec
                if progress >= 0.95 then
                    time_color = COLORS.danger
                    button_color = COLORS.danger
                elseif progress >= 0.9 then
                    time_color = COLORS.warning
                    button_color = COLORS.warning
                end
            else
                -- 超时了
                local overtime_min = math.floor(-remaining / 60)
                local overtime_sec = math.floor(-remaining % 60)
                display_text = string.format("超时 +%02d:%02d", overtime_min, overtime_sec)
                time_color = COLORS.danger
                button_color = COLORS.danger
            end
        else
            -- 没有预计耗时：显示已用时间
            display_text = "已用 " .. elapsed_text
        end
        
        -- DONE 按钮（主按钮）
        if is_completed then
            -- 已完成所有目标，禁用按钮
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x444444FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x444444FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x888888FF)
            reaper.ImGui_Button(ctx, "✅ DONE!\n" .. display_text, btn_width, btn_height)
            reaper.ImGui_PopStyleColor(ctx, 3)
            
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_SetTooltip(ctx, "已完成所有目标！\n请重置目标或调整目标数量")
            end
        else
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), button_color)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), button_color | 0x00000020)  -- 稍微变亮
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x000000FF)
            
            local done_text = "✅ DONE!\n" .. display_text
            if reaper.ImGui_Button(ctx, done_text, btn_width, btn_height) then
                table.insert(actions, { type = "done", time = reaper.time_precise() })
            end
            
            reaper.ImGui_PopStyleColor(ctx, 3)
            
            if reaper.ImGui_IsItemHovered(ctx) then
                local tooltip = "完成当前样本！\n已用时: " .. elapsed_text
                if state.current_work_estimated_duration > 0 then
                    tooltip = tooltip .. "\n预计: " .. state.current_work_estimated_duration .. "分钟"
                end
                reaper.ImGui_SetTooltip(ctx, tooltip)
            end
        end
        
    else
        -- ===== 未开始：显示开始计时按钮 =====
        -- 预计耗时（通过滚轮在按钮上调整）
        local current_input = state.last_estimated_duration or 0
        
        -- 开始计时按钮（支持滚轮调整预计耗时）
        if is_completed then
            -- 已完成所有目标，禁用按钮
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x444444FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x444444FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x888888FF)
            
            local start_text = "⏱ 开始计时"
            if current_input > 0 then
                start_text = start_text .. "\n预计 " .. current_input .. " 分钟"
            end
            
            reaper.ImGui_Button(ctx, start_text, btn_width, btn_height)
            reaper.ImGui_PopStyleColor(ctx, 3)
            
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_SetTooltip(ctx, "已完成所有目标！\n请重置目标或调整目标数量")
            end
        else
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLORS.success)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xA8E6CFFF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x000000FF)
            
            local start_text = "⏱ 开始计时"
            if current_input > 0 then
                start_text = start_text .. "\n预计 " .. current_input .. " 分钟"
            end
            
            if reaper.ImGui_Button(ctx, start_text, btn_width, btn_height) then
                table.insert(actions, { 
                    type = "startWork", 
                    estimated_duration = current_input > 0 and current_input or nil
                })
            end
            
            reaper.ImGui_PopStyleColor(ctx, 3)
            
            -- 检测滚轮事件（在按钮上）
            if reaper.ImGui_IsItemHovered(ctx) then
                local wheel = reaper.ImGui_GetMouseWheel(ctx)
                if wheel ~= 0 then
                    -- 滚轮调整预计耗时（0-60分钟）
                    local new_value = current_input + (wheel > 0 and 1 or -1)
                    new_value = math.max(0, math.min(60, new_value))
                    if new_value ~= current_input then
                        table.insert(actions, { type = "setLastEstimatedDuration", value = new_value })
                    end
                end
                
                -- 工具提示
                local tooltip = "开始制作新样本的计时\n"
                if current_input > 0 then
                    tooltip = tooltip .. "预计: " .. current_input .. " 分钟\n"
                end
                tooltip = tooltip .. "在按钮上滚动鼠标滚轮调整预计耗时"
                reaper.ImGui_SetTooltip(ctx, tooltip)
            end
        end
    end
    
    reaper.ImGui_SameLine(ctx)
    
    -- 重置按钮
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x444444FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x555555FF)
    
    if reaper.ImGui_Button(ctx, "🔄 重置今日", btn_width, btn_height) then
        table.insert(actions, { type = "reset" })
    end
    
    reaper.ImGui_PopStyleColor(ctx, 2)
    
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "清零今日进度，重新开始")
    end
end

-- ============================================
-- 设置面板
-- ============================================
function UI.drawSettingsPanel(ctx, state, actions)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    
    reaper.ImGui_TextColored(ctx, COLORS.accent, "⚙️ 设置")
    reaper.ImGui_Spacing(ctx)
    
    local changed = false
    local avail_w = reaper.ImGui_GetContentRegionAvail(ctx)
    
    -- 今日目标
    reaper.ImGui_Text(ctx, "今日目标:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 100)
    local ret, val = reaper.ImGui_InputInt(ctx, "##target", state.target_total, 1, 10)
    if ret and val ~= state.target_total then
        table.insert(actions, { type = "setTarget", value = val })
        changed = true
    end
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextDisabled(ctx, "个样本")
    
    -- 上班时间
    reaper.ImGui_Text(ctx, "上班时间:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 80)
    local ret1, val1 = reaper.ImGui_InputText(ctx, "##start_time", state.work_start_time, 16)
    if ret1 and val1 ~= state.work_start_time then
        table.insert(actions, { type = "setWorkStartTime", value = val1 })
        changed = true
    end
    
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, "下班时间:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 80)
    local ret2, val2 = reaper.ImGui_InputText(ctx, "##end_time", state.work_end_time, 16)
    if ret2 and val2 ~= state.work_end_time then
        table.insert(actions, { type = "setWorkEndTime", value = val2 })
        changed = true
    end
    
    -- 连击时间窗口
    reaper.ImGui_Text(ctx, "连击窗口:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 100)
    local ret3, val3 = reaper.ImGui_InputInt(ctx, "##combo_window", state.combo_window, 1, 10)
    if ret3 and val3 ~= state.combo_window then
        table.insert(actions, { type = "setComboWindow", value = val3 })
        changed = true
    end
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextDisabled(ctx, "分钟内算连击")
    
    reaper.ImGui_Spacing(ctx)
    
    -- 音效信息
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_TextDisabled(ctx, "📁 音效文件夹: assets/sounds/")
    reaper.ImGui_TextDisabled(ctx, "   放入 done_1.wav, done_2.wav... 自定义音效")
    
    reaper.ImGui_Spacing(ctx)
    
    -- 关闭设置按钮
    if reaper.ImGui_Button(ctx, "关闭设置", -1, 30) then
        table.insert(actions, { type = "setShowSettings", value = false })
    end
    
    -- 标记保存
    if changed then
        table.insert(actions, { type = "saveSettings" })
    end
end

-- ============================================
-- 嵌入式布局（横向长条形）
-- ============================================
function UI.drawEmbedded(ctx, state)
    local actions = {}
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local content_width, content_height = reaper.ImGui_GetContentRegionAvail(ctx)
    
    -- 检查是否已完成所有目标
    local is_completed = state.target_total > 0 and state.completed_count >= state.target_total
    
    -- 布局切换按钮和锁定按钮（右上角）
    UI.drawEmbeddedControls(ctx, state, actions, content_width)
    
    -- 基础组件尺寸（固定）
    local cat_width = 50
    local btn_width = 90  -- 按钮宽度增加，因为要显示时间
    local progress_min_width = 60
    
    -- 计算间距和进度条宽度
    local spacing, progress_width
    if state.embedded_layout_locked then
        -- 锁定模式：使用记录的布局参数
        spacing = state.embedded_layout_spacing or 8
        progress_width = state.embedded_layout_progress_width or progress_min_width
    else
        -- 自适应模式：根据可用空间动态调整间距
        local components_width = cat_width + btn_width + progress_min_width
        local available_space = content_width - components_width
        
        if available_space > 0 then
            -- 有剩余空间，平均分配给间距和进度条
            -- 3个间距 + 进度条额外宽度
            local spacing_count = 3
            local base_spacing = 4  -- 最小间距
            local extra_space = available_space - (base_spacing * spacing_count)
            
            if extra_space > 0 then
                -- 60% 分配给间距，40% 分配给进度条
                spacing = base_spacing + math.floor(extra_space * 0.6 / spacing_count)
                progress_width = progress_min_width + math.floor(extra_space * 0.4)
            else
                spacing = math.max(2, math.floor(available_space / spacing_count))
                progress_width = progress_min_width
            end
        else
            -- 空间不足，使用最小间距
            spacing = 2
            progress_width = progress_min_width
        end
        
        -- 如果当前未锁定，将计算出的值传递给锁定按钮（用于记录）
        -- 这个值会在点击锁定时被使用
    end
    
    -- 计算起始位置（垂直居中，基于实际内容高度）
    local start_x, start_y = reaper.ImGui_GetCursorScreenPos(ctx)
    local actual_content_height = 50  -- 实际内容高度（猫咪50像素高）
    -- 控制按钮高度22，所以内容从start_y开始，垂直居中在可用空间
    local y_center = start_y + actual_content_height / 2
    
    -- 1. 猫咪（左侧）
    UI.drawCatEmbeddedHorizontal(ctx, draw_list, state, start_x, y_center - 25, cat_width, 50)
    
    -- 2. 按钮（中间，包含时间显示）
    local btn_x = start_x + cat_width + spacing
    UI.drawActionEmbedded(ctx, state, actions, btn_x, y_center - 20, btn_width, 40, is_completed)
    
    -- 3. 进度（右侧，自适应宽度）
    local progress_x = btn_x + btn_width + spacing
    UI.drawProgressEmbeddedHorizontal(ctx, draw_list, state, progress_x, y_center - 10, progress_width, 20, actions)
    
    -- 只预留实际需要的最小空间（不预留整个content_height）
    reaper.ImGui_SetCursorScreenPos(ctx, start_x, start_y + actual_content_height)
    reaper.ImGui_Dummy(ctx, content_width, 0)  -- 不预留垂直空间，让窗口自动适应内容
    
    return actions
end

-- 嵌入布局的控制按钮（布局切换 + 锁定）
function UI.drawEmbeddedControls(ctx, state, actions, content_width)
    local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
    
    -- 计算当前的自适应布局参数（用于锁定时的记录）
    local cat_width = 50
    local btn_width = 90
    local progress_min_width = 60
    local components_width = cat_width + btn_width + progress_min_width
    local available_space = content_width - components_width
    
    local current_spacing = 8
    local current_progress_width = progress_min_width
    
    if available_space > 0 then
        local spacing_count = 2  -- 只有2个间距（猫咪-按钮，按钮-进度）
        local base_spacing = 4
        local extra_space = available_space - (base_spacing * spacing_count)
        
        if extra_space > 0 then
            current_spacing = base_spacing + math.floor(extra_space * 0.6 / spacing_count)
            current_progress_width = progress_min_width + math.floor(extra_space * 0.4)
        else
            current_spacing = math.max(2, math.floor(available_space / spacing_count))
        end
    else
        current_spacing = 2
    end
    
    -- 锁定按钮（左侧，小按钮）
    local lock_icon = state.embedded_layout_locked and "🔒" or "🔓"
    reaper.ImGui_SetCursorScreenPos(ctx, x, y)
    
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x44444444)
    
    if reaper.ImGui_Button(ctx, lock_icon, 20, 20) then
        -- 如果正在锁定，传递当前的布局参数
        if not state.embedded_layout_locked then
            table.insert(actions, { 
                type = "toggleEmbeddedLayoutLock",
                spacing = current_spacing,
                progress_width = current_progress_width
            })
        else
            table.insert(actions, { type = "toggleEmbeddedLayoutLock" })
        end
    end
    
    reaper.ImGui_PopStyleColor(ctx, 2)
    
    if reaper.ImGui_IsItemHovered(ctx) then
        local tooltip = state.embedded_layout_locked and "解锁布局（恢复自适应）" or "锁定布局（记住当前布局）"
        reaper.ImGui_SetTooltip(ctx, tooltip)
    end
    
    -- 布局切换按钮（右侧，小按钮）
    reaper.ImGui_SetCursorScreenPos(ctx, x + content_width - 22, y)
    
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x44444444)
    
    if reaper.ImGui_Button(ctx, "📋", 20, 20) then
        table.insert(actions, { type = "setLayoutMode", value = "normal" })
    end
    
    reaper.ImGui_PopStyleColor(ctx, 2)
    
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "切换到普通模式")
    end
    
    -- 重置光标位置到控制按钮下方，为内容留出空间
    reaper.ImGui_SetCursorScreenPos(ctx, x, y + 22)
end

-- 嵌入式猫咪（横向，左侧）
function UI.drawCatEmbeddedHorizontal(ctx, draw_list, state, x, y, width, height)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x, y, x + width, y + height, COLORS.bg_panel, 4)
    
    local cat_state = State.suggestCatState(state)
    local emoji = Cat.getEmoji(cat_state)
    
    local emoji_w = reaper.ImGui_CalcTextSize(ctx, emoji)
    local emoji_x = x + (width - emoji_w) / 2
    local emoji_y = y + (height - 20) / 2
    
    -- 简化动画
    local now = reaper.time_precise()
    local shake_x = 0
    if cat_state == "grumpy" or cat_state == "hissing" or cat_state == "warning" then
        shake_x = math.sin(now * 15) * 1.5
    end
    
    reaper.ImGui_SetCursorScreenPos(ctx, emoji_x + shake_x, emoji_y)
    
    local emoji_color = COLORS.text_bright
    if cat_state == "grumpy" or cat_state == "hissing" then
        emoji_color = COLORS.danger
    elseif cat_state == "warning" then
        emoji_color = COLORS.warning
    elseif cat_state == "excited" then
        emoji_color = COLORS.gold
    end
    
    reaper.ImGui_TextColored(ctx, emoji_color, emoji)
    
    -- 粒子特效（中心点）
    Cat.drawParticles(ctx, draw_list, state.effects, x + width / 2, y + height / 2)
    
    -- 连击显示（右上角小字）
    if state.combo_count >= 2 then
        local combo_text = state.combo_count
        local combo_w = reaper.ImGui_CalcTextSize(ctx, tostring(combo_text))
        reaper.ImGui_SetCursorScreenPos(ctx, x + width - combo_w - 3, y + 2)
        reaper.ImGui_TextColored(ctx, COLORS.gold, tostring(combo_text))
    end
end

-- 嵌入式计时显示（横向）
function UI.drawTimerEmbedded(ctx, state, x, y, width, height)
    local now = reaper.time_precise()
    local display_text = ""
    local text_color = COLORS.text_bright
    
    if state.is_working then
        local elapsed = now - state.current_work_start
        
        if state.current_work_estimated_duration > 0 then
            local estimated_sec = state.current_work_estimated_duration * 60
            local remaining = estimated_sec - elapsed
            
            if remaining > 0 then
                local remaining_min = math.floor(remaining / 60)
                local remaining_sec = math.floor(remaining % 60)
                display_text = string.format("%02d:%02d", remaining_min, remaining_sec)
                
                local progress = elapsed / estimated_sec
                if progress >= 0.95 then
                    text_color = COLORS.danger
                elseif progress >= 0.9 then
                    text_color = COLORS.warning
                end
            else
                local overtime = -remaining
                local overtime_min = math.floor(overtime / 60)
                local overtime_sec = math.floor(overtime % 60)
                display_text = string.format("+%02d:%02d", overtime_min, overtime_sec)
                text_color = COLORS.danger
            end
        else
            local elapsed_min = math.floor(elapsed / 60)
            local elapsed_sec = math.floor(elapsed % 60)
            display_text = string.format("%02d:%02d", elapsed_min, elapsed_sec)
        end
    else
        display_text = state.last_estimated_duration > 0 
            and string.format("%d分", state.last_estimated_duration)
            or "待开始"
        text_color = COLORS.text_dim
    end
    
    -- 居中显示
    local text_w = reaper.ImGui_CalcTextSize(ctx, display_text)
    reaper.ImGui_SetCursorScreenPos(ctx, x + (width - text_w) / 2, y + (height - 15) / 2)
    reaper.ImGui_TextColored(ctx, text_color, display_text)
end

-- 嵌入式按钮（横向，包含时间显示和滚轮调整）
function UI.drawActionEmbedded(ctx, state, actions, x, y, width, height, is_completed)
    reaper.ImGui_SetCursorScreenPos(ctx, x, y)
    
    -- 检查是否已完成所有目标（如果未传入参数，则计算）
    if is_completed == nil then
        is_completed = state.target_total > 0 and state.completed_count >= state.target_total
    end
    
    if state.is_working then
        -- DONE 按钮（显示时间）
        local now = reaper.time_precise()
        local elapsed = now - state.current_work_start
        local button_color = COLORS.accent
        local display_text = ""
        local text_color = 0x000000FF
        
        if state.current_work_estimated_duration > 0 then
            local estimated_sec = state.current_work_estimated_duration * 60
            local remaining = estimated_sec - elapsed
            
            if remaining > 0 then
                local remaining_min = math.floor(remaining / 60)
                local remaining_sec = math.floor(remaining % 60)
                display_text = string.format("DONE\n%02d:%02d", remaining_min, remaining_sec)
                
                local progress = elapsed / estimated_sec
                if progress >= 0.95 then
                    button_color = COLORS.danger
                    text_color = 0xFFFFFFFF
                elseif progress >= 0.9 then
                    button_color = COLORS.warning
                    text_color = 0x000000FF
                end
            else
                local overtime = -remaining
                local overtime_min = math.floor(overtime / 60)
                local overtime_sec = math.floor(overtime % 60)
                display_text = string.format("DONE\n+%02d:%02d", overtime_min, overtime_sec)
                button_color = COLORS.danger
                text_color = 0xFFFFFFFF
            end
        else
            local elapsed_min = math.floor(elapsed / 60)
            local elapsed_sec = math.floor(elapsed % 60)
            display_text = string.format("DONE\n%02d:%02d", elapsed_min, elapsed_sec)
        end
        
        if is_completed then
            -- 已完成所有目标，禁用按钮
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x444444FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x444444FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x888888FF)
            reaper.ImGui_Button(ctx, "DONE", width, height)
            reaper.ImGui_PopStyleColor(ctx, 3)
            
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_SetTooltip(ctx, "已完成所有目标！")
            end
        else
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), button_color)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), button_color | 0x00000020)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), text_color)
            
            if reaper.ImGui_Button(ctx, display_text, width, height) then
                table.insert(actions, { type = "done", time = now })
            end
            
            reaper.ImGui_PopStyleColor(ctx, 3)
        end
    else
        -- 开始按钮（显示预计耗时，支持滚轮调整）
        local estimated_duration = state.last_estimated_duration or 0
        local button_text = "⏱ 开始"
        
        if estimated_duration > 0 then
            button_text = string.format("⏱ 开始\n%d分", estimated_duration)
        end
        
        if is_completed then
            -- 已完成所有目标，禁用按钮
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x444444FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x444444FF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x888888FF)
            reaper.ImGui_Button(ctx, button_text, width, height)
            reaper.ImGui_PopStyleColor(ctx, 3)
            
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_SetTooltip(ctx, "已完成所有目标！")
            end
        else
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLORS.success)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xA8E6CFFF)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x000000FF)
            
            if reaper.ImGui_Button(ctx, button_text, width, height) then
                table.insert(actions, { 
                    type = "startWork", 
                    estimated_duration = estimated_duration > 0 and estimated_duration or nil
                })
            end
            
            -- 滚轮调整预计耗时
            if reaper.ImGui_IsItemHovered(ctx) then
                local wheel = reaper.ImGui_GetMouseWheel(ctx)
                if wheel ~= 0 then
                    local new_duration = estimated_duration + (wheel > 0 and 1 or -1)
                    new_duration = math.max(0, math.min(60, new_duration))
                    if new_duration ~= estimated_duration then
                        table.insert(actions, { type = "setLastEstimatedDuration", value = new_duration })
                    end
                end
                
                local tooltip = "开始制作新样本的计时\n"
                if estimated_duration > 0 then
                    tooltip = tooltip .. "预计: " .. estimated_duration .. " 分钟\n"
                end
                tooltip = tooltip .. "在按钮上滚动鼠标滚轮调整预计耗时"
                reaper.ImGui_SetTooltip(ctx, tooltip)
            end
            
            reaper.ImGui_PopStyleColor(ctx, 3)
        end
    end
end

-- 嵌入式进度（横向，右侧）
function UI.drawProgressEmbeddedHorizontal(ctx, draw_list, state, x, y, width, height, actions)
    actions = actions or {}
    local progress = 0
    if state.target_total > 0 then
        progress = math.min(1, state.completed_count / state.target_total)
    end
    
    -- 背景
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x, y, x + width, y + height, 0x333333FF, 3)
    
    -- 进度条
    if progress > 0 then
        local fill_color = COLORS.accent
        reaper.ImGui_DrawList_AddRectFilled(draw_list, x, y, x + width * progress, y + height, fill_color, 3)
    end
    
    -- 进度文字（覆盖在进度条上）
    local progress_text = string.format("%d/%d", state.completed_count, state.target_total)
    local text_w = reaper.ImGui_CalcTextSize(ctx, progress_text)
    reaper.ImGui_SetCursorScreenPos(ctx, x + (width - text_w) / 2, y + (height - 15) / 2)
    
    -- 根据进度选择文字颜色（确保可见性）
    local text_color = progress > 0.5 and 0xFFFFFFFF or COLORS.text_bright
    reaper.ImGui_TextColored(ctx, text_color, progress_text)
    
    -- 添加不可见按钮来检测滚轮（覆盖整个进度条区域）
    reaper.ImGui_SetCursorScreenPos(ctx, x, y)
    reaper.ImGui_InvisibleButton(ctx, "##progress_embedded", width, height)
    
    -- 检测滚轮调整目标数量
    if reaper.ImGui_IsItemHovered(ctx) then
        local wheel = reaper.ImGui_GetMouseWheel(ctx)
        if wheel ~= 0 then
            local new_target = state.target_total + (wheel > 0 and 1 or -1)
            new_target = math.max(0, math.min(999, new_target))  -- 限制范围 0-999
            if new_target ~= state.target_total then
                table.insert(actions, { type = "setTarget", value = new_target })
            end
        end
        
        -- 工具提示
        reaper.ImGui_SetTooltip(ctx, "滚动鼠标滚轮调整目标数量\n当前: " .. state.target_total .. " 个样本")
    end
end

-- ============================================
-- 布局切换器（通用组件）
-- ============================================
function UI.drawLayoutSwitcher(ctx, state, actions, current_layout)
    local avail_w = reaper.ImGui_GetContentRegionAvail(ctx)
    
    -- 右上角的小按钮
    local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
    
    -- 布局图标
    local icons = {
        normal = "📋",      -- 完整
        embedded = "▪️",    -- 横向
    }
    
    local next_layout = {
        normal = "embedded",
        embedded = "normal",
    }
    
    local icon = icons[current_layout] or "📋"
    local next = next_layout[current_layout] or "normal"
    
    -- 右对齐按钮
    reaper.ImGui_SetCursorScreenPos(ctx, x + avail_w - 25, y)
    
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x44444444)
    
    if reaper.ImGui_Button(ctx, icon, 22, 22) then
        table.insert(actions, { type = "setLayoutMode", value = next })
    end
    
    reaper.ImGui_PopStyleColor(ctx, 2)
    
    if reaper.ImGui_IsItemHovered(ctx) then
        local tooltips = {
            normal = "切换到嵌入模式",
            embedded = "切换到普通模式",
        }
        reaper.ImGui_SetTooltip(ctx, tooltips[current_layout] or "切换布局")
    end
    
    -- 重置光标位置
    reaper.ImGui_SetCursorScreenPos(ctx, x, y)
end

return UI

