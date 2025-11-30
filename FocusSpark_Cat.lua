-- FocusSpark_Cat.lua
-- 猫咪动画模块：ASCII/Emoji 风格的猫咪状态表现

local Cat = {}

-- ============================================
-- 猫咪 ASCII 艺术（多帧动画）
-- ============================================

-- 闲置状态：慵懒趴着
Cat.FRAMES_IDLE = {
    [[
   /\_/\  
  ( o.o ) 
   > ^ <  
  /|   |\  
 (_|   |_)
]],
    [[
   /\_/\  
  ( -.- ) 
   > ^ <  
  /|   |\  
 (_|   |_)
]],
}

-- 开心状态：摇尾巴
Cat.FRAMES_HAPPY = {
    [[
   /\_/\  
  ( ^.^ ) 
   > ~ <  
  /|   |\~
 (_|   |_)
]],
    [[
   /\_/\  
  ( ^.^ ) 
   > ~ <  
 ~/|   |\  
 (_|   |_)
]],
}

-- 超级兴奋：跳跃 + 爱心
Cat.FRAMES_EXCITED = {
    [[
  ♥ /\_/\ ♥
   ( ★.★ ) 
    > ▽ <  
   /|   |\ 
  ~ |   | ~
]],
    [[
 ♥  /\_/\  ♥
   ( ★.★ )  
    > ▽ <   
    /   \   
   ~     ~  
]],
    [[
♥   /\_/\   ♥
   ( ★.★ )   
    > ▽ <    
    \   /    
     ~ ~     
]],
}

-- 困倦/打瞌睡
Cat.FRAMES_SLEEPY = {
    [[
   /\_/\  
  ( -.- ) z
   > ~ <  Z
  /|   |\  
 (_|   |_)
]],
    [[
   /\_/\   z
  ( -.- )  Z
   > ~ <   z
  /|   |\  
 (_|   |_)
]],
}

-- 加班预警：焦躁
Cat.FRAMES_WARNING = {
    [[
   /\_/\  !
  ( >.< ) !
   > n <  
  /|   |\  
 (_|   |_)?
]],
    [[
  !/\_/\  
  ( >.< )!
   > n <  
   |   |   
  /|   |\  
]],
}

-- 生气/加班中：炸毛
Cat.FRAMES_GRUMPY = {
    [[
  \\ | //
   /\_/\  
  ( =.= ) 
   > ω <  
  /|###|\  
 (_|###|_)
]],
    [[
   \\ //  
   /\_/\  
  ( ≖_≖ ) 
   > ω <  
  /|###|\  
 (_|###|_)
]],
    [[
  \\   //  
   /\_/\   
  ( `Д´ )  
   > ω <   
  /#|###|#\  
]],
}

-- 哈气/计时器预警：紧张哈气
Cat.FRAMES_HISSING = {
    [[
   /\_/\  
  ( >.< ) 
   > n <  
  /|   |\  
 (_|   |_)
  "sss..."
]],
    [[
   /\_/\  
  ( >.< ) 
   > n <  
  /|   |\  
 (_|   |_)
  "SSS!"
]],
    [[
   /\_/\  
  ( >.< ) 
   > n <  
  /|   |\  
 (_|   |_)
  "sss..."
]],
}

-- ============================================
-- Emoji 版本（更简洁）
-- ============================================
Cat.EMOJI = {
    idle = {"🐱", "😺"},
    happy = {"😸", "😻"},
    excited = {"🙀✨", "😻💖", "🎉😺🎉"},
    sleepy = {"😿💤", "😾💤"},
    warning = {"😾⚠️", "🙀⏰"},
    grumpy = {"😾💢", "🙀💢💢", "👊😾👊"},
    hissing = {"😾💨", "🙀💨💨", "😾💨💨💨"},
}

-- ============================================
-- 特效粒子
-- ============================================
Cat.PARTICLES = {
    heart = {"♥", "💖", "💕", "❤️"},
    star = {"★", "✨", "⭐", "🌟"},
    spark = {"✦", "✧", "・", "°"},
    warning = {"!", "⚠", "⏰", "💢"},
    zzz = {"z", "Z", "💤"},
}

-- ============================================
-- 动画控制
-- ============================================
local current_frame = 1
local last_frame_time = 0
local FRAME_DURATION = {
    idle = 1.5,
    happy = 0.3,
    excited = 0.15,
    sleepy = 0.8,
    warning = 0.25,
    grumpy = 0.2,
    hissing = 0.2,
}

function Cat.getFrame(cat_state)
    local now = reaper.time_precise()
    local duration = FRAME_DURATION[cat_state] or 0.5
    
    if now - last_frame_time > duration then
        current_frame = current_frame + 1
        last_frame_time = now
    end
    
    local frames
    if cat_state == "idle" then
        frames = Cat.FRAMES_IDLE
    elseif cat_state == "happy" then
        frames = Cat.FRAMES_HAPPY
    elseif cat_state == "excited" then
        frames = Cat.FRAMES_EXCITED
    elseif cat_state == "sleepy" then
        frames = Cat.FRAMES_SLEEPY
    elseif cat_state == "warning" then
        frames = Cat.FRAMES_WARNING
    elseif cat_state == "grumpy" then
        frames = Cat.FRAMES_GRUMPY
    elseif cat_state == "hissing" then
        frames = Cat.FRAMES_HISSING
    else
        frames = Cat.FRAMES_IDLE
    end
    
    local idx = ((current_frame - 1) % #frames) + 1
    return frames[idx]
end

function Cat.getEmoji(cat_state)
    local now = reaper.time_precise()
    local duration = FRAME_DURATION[cat_state] or 0.5
    
    if now - last_frame_time > duration then
        current_frame = current_frame + 1
        last_frame_time = now
    end
    
    local emojis = Cat.EMOJI[cat_state] or Cat.EMOJI.idle
    local idx = ((current_frame - 1) % #emojis) + 1
    return emojis[idx]
end

-- ============================================
-- 绘制函数（使用 ImGui DrawList）
-- ============================================

-- 绘制 ASCII 猫咪
function Cat.drawAscii(ctx, draw_list, x, y, cat_state, scale)
    scale = scale or 1
    local frame = Cat.getFrame(cat_state)
    local lines = {}
    
    for line in frame:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    
    local line_height = 14 * scale
    local char_width = 8 * scale
    
    -- 根据状态选择颜色
    local color = 0xFFFFFFFF  -- 默认白色
    if cat_state == "happy" then
        color = 0xFFE4B5FF  -- 暖橙色
    elseif cat_state == "excited" then
        color = 0xFFD700FF  -- 金色
    elseif cat_state == "sleepy" then
        color = 0x9999CCFF  -- 淡紫色
    elseif cat_state == "warning" then
        color = 0xFFA500FF  -- 橙色
    elseif cat_state == "grumpy" then
        color = 0xFF6B6BFF  -- 红色
    elseif cat_state == "hissing" then
        color = 0xFF8C00FF  -- 深橙色（哈气警告）
    end
    
    for i, line in ipairs(lines) do
        reaper.ImGui_DrawList_AddText(draw_list, x, y + (i-1) * line_height, color, line)
    end
end

-- 绘制粒子特效
function Cat.drawParticles(ctx, draw_list, effects, center_x, center_y)
    local now = reaper.time_precise()
    
    for _, effect in ipairs(effects or {}) do
        local elapsed = now - effect.start_time
        local progress = elapsed / effect.duration
        
        if progress < 1 then
            local particles
            if effect.type == "heart" then
                particles = Cat.PARTICLES.heart
            elseif effect.type == "star" then
                particles = Cat.PARTICLES.star
            elseif effect.type == "spark" then
                particles = Cat.PARTICLES.spark
            elseif effect.type == "warning" then
                particles = Cat.PARTICLES.warning
            elseif effect.type == "zzz" then
                particles = Cat.PARTICLES.zzz
            else
                particles = Cat.PARTICLES.spark
            end
            
            -- 计算粒子位置（从中心扩散）
            local count = effect.count or 5
            for i = 1, count do
                local angle = (i / count) * math.pi * 2 + effect.start_time
                local radius = 20 + progress * 60 * (1 + math.sin(angle * 3) * 0.3)
                
                local px = center_x + math.cos(angle + progress * 2) * radius
                local py = center_y + math.sin(angle + progress * 2) * radius - progress * 30  -- 上升效果
                
                local alpha = math.floor((1 - progress) * 255)
                local color = (effect.color or 0xFFD700) << 8 | alpha
                
                local char = particles[((i + math.floor(elapsed * 10)) % #particles) + 1]
                reaper.ImGui_DrawList_AddText(draw_list, px, py, color, char)
            end
        end
    end
end

-- ============================================
-- 进度条绘制（猫粮/鱼干条）
-- ============================================
function Cat.drawProgressBar(ctx, draw_list, x, y, width, height, progress, cat_state)
    local rounding = height / 2
    
    -- 背景
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x, y, x + width, y + height, 0x333333FF, rounding)
    
    -- 进度条颜色（根据状态）
    local bar_color = 0x4ECDC4FF  -- 薄荷绿
    if cat_state == "warning" then
        bar_color = 0xFFA500FF  -- 橙色
    elseif cat_state == "grumpy" then
        bar_color = 0xFF6B6BFF  -- 红色
    elseif progress >= 1 then
        bar_color = 0xFFD700FF  -- 金色（完成）
    end
    
    -- 进度填充
    local fill_width = width * math.min(1, progress)
    if fill_width > 0 then
        reaper.ImGui_DrawList_AddRectFilled(draw_list, x, y, x + fill_width, y + height, bar_color, rounding)
    end
    
    -- 边框
    reaper.ImGui_DrawList_AddRect(draw_list, x, y, x + width, y + height, 0x666666FF, rounding, 0, 2)
    
    -- 装饰：鱼干图标
    if progress > 0.1 then
        local fish_x = x + fill_width - 12
        local fish_y = y + height / 2 - 6
        reaper.ImGui_DrawList_AddText(draw_list, fish_x, fish_y, 0xFFFFFFFF, "🐟")
    end
end

-- ============================================
-- 连击显示
-- ============================================
function Cat.drawCombo(ctx, draw_list, center_x, top_y, combo_count, last_done_time)
    if combo_count < 2 then return end
    
    local now = reaper.time_precise()
    local since_done = now - last_done_time
    
    -- 连击文字动画
    local scale = 1 + math.sin(now * 8) * 0.1
    local alpha = math.max(0, 1 - since_done / 3)  -- 3秒后淡出
    
    if alpha <= 0 then return end
    
    local text
    local color
    
    if combo_count >= 10 then
        text = "🔥 LEGENDARY! x" .. combo_count
        color = 0xFF00FF
    elseif combo_count >= 5 then
        text = "⭐ ACE! x" .. combo_count
        color = 0xFFD700
    elseif combo_count >= 3 then
        text = "✨ COMBO x" .. combo_count
        color = 0x00FFFF
    else
        text = "x" .. combo_count
        color = 0xFFFFFF
    end
    
    color = (color << 8) | math.floor(alpha * 255)
    
    -- 计算文本大小
    local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, text)
    
    -- 震动效果
    local shake_x = 0
    local shake_y = 0
    if since_done < 0.3 then
        shake_x = (math.random() - 0.5) * 4
        shake_y = (math.random() - 0.5) * 4
    end
    
    -- 文本显示在指定位置上方（水平居中，垂直在top_y上方）
    -- 文本底部距离top_y有10像素间距
    local text_x = center_x - text_w / 2 + shake_x
    local text_y = top_y - text_h - 10 + shake_y
    
    reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, color, text)
end

-- ============================================
-- 加班预警显示
-- ============================================
function Cat.drawOvertimeWarning(ctx, draw_list, x, y, width, is_overtime, overtime_minutes)
    if not is_overtime then return end
    
    local now = reaper.time_precise()
    local blink = math.sin(now * 4) > 0
    
    local bg_color = blink and 0xFF6B6B88 or 0xFF6B6B44
    local text_color = 0xFF6B6BFF
    
    local height = 24
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x, y, x + width, y + height, bg_color, 4)
    
    local text
    if overtime_minutes then
        text = string.format("⚠️ 预计加班 %d 分钟", overtime_minutes)
    else
        text = "⚠️ 需要加班才能完成！"
    end
    
    local text_w = reaper.ImGui_CalcTextSize(ctx, text)
    reaper.ImGui_DrawList_AddText(draw_list, x + (width - text_w) / 2, y + 4, text_color, text)
end

return Cat

