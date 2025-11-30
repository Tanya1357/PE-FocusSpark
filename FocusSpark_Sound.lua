-- FocusSpark_Sound.lua
-- 音效系统模块：处理音效播放和自定义音效加载

local Sound = {}

-- 音效文件缓存
local sound_files = nil
local last_scan_time = 0
local SCAN_INTERVAL = 5  -- 每5秒最多扫描一次

-- ============================================
-- 初始化
-- ============================================
function Sound.init(Data)
    Sound.Data = Data
    Sound.rescan()
end

function Sound.rescan()
    local now = reaper.time_precise()
    if now - last_scan_time < SCAN_INTERVAL then return end
    
    last_scan_time = now
    if Sound.Data then
        sound_files = Sound.Data.scanSoundFiles()
    end
end

-- ============================================
-- 播放音效
-- ============================================

-- 播放指定音频文件
local active_previews = {}  -- 跟踪活跃的预览，用于自动清理

local function playFile(filepath)
    if not filepath then return false end
    
    -- 使用 SWS 扩展的 CF_CreatePreview API（参考 Soundmole）
    -- 需要先创建 PCM_Source，然后创建 Preview
    if reaper.CF_CreatePreview and reaper.PCM_Source_CreateFromFile then
        local source = reaper.PCM_Source_CreateFromFile(filepath)
        if source then
            local preview = reaper.CF_CreatePreview(source)
            if preview then
                -- 设置音量（可选）
                if reaper.CF_Preview_SetValue then
                    reaper.CF_Preview_SetValue(preview, "D_VOLUME", 1.0)
                end
                -- 播放
                reaper.CF_Preview_Play(preview)
                
                -- 记录预览对象，稍后自动清理
                table.insert(active_previews, {
                    preview = preview,
                    source = source,
                    start_time = reaper.time_precise()
                })
                
                return true
            else
                -- 如果创建预览失败，释放 source
                reaper.PCM_Source_Destroy(source)
            end
        end
    end
    
    -- 如果没有 SWS 扩展，静默失败（不播放）
    return false
end

-- 清理过期的预览对象（在每次播放时调用）
local function cleanupPreviews()
    local now = reaper.time_precise()
    local active = {}
    local max_age = 5  -- 最多保留5秒
    
    for _, item in ipairs(active_previews) do
        local elapsed = now - item.start_time
        if elapsed < max_age then
            -- 还在有效期内，保留
            table.insert(active, item)
        else
            -- 超时，清理资源
            if reaper.CF_Preview_Stop then
                reaper.CF_Preview_Stop(item.preview)
            end
            if item.source and reaper.PCM_Source_Destroy then
                reaper.PCM_Source_Destroy(item.source)
            end
        end
    end
    
    active_previews = active
end

-- 播放完成音效（根据连击数）
function Sound.playDone(combo_count)
    cleanupPreviews()  -- 清理旧的预览
    Sound.rescan()
    
    if not sound_files or not sound_files.done then
        -- 没有自定义音效，静默（不播放）
        return
    end
    
    -- 查找对应连击数的音效，如果没有则使用最高的
    local max_num = 0
    for num, _ in pairs(sound_files.done) do
        if num > max_num then max_num = num end
    end
    
    local target_num = math.min(combo_count, max_num)
    local file = sound_files.done[target_num] or sound_files.done[1]
    
    if file then
        playFile(file)
    end
end

-- 播放加班预警音效
function Sound.playOvertimeWarn()
    cleanupPreviews()
    Sound.rescan()
    
    if sound_files and sound_files.overtime_warn then
        playFile(sound_files.overtime_warn)
    end
end

-- 播放加班警报音效
function Sound.playOvertimeAlert()
    cleanupPreviews()
    Sound.rescan()
    
    if sound_files and sound_files.overtime_alert then
        playFile(sound_files.overtime_alert)
    end
end

-- 播放完成全部目标音效
function Sound.playComplete()
    cleanupPreviews()
    Sound.rescan()
    
    if sound_files and sound_files.complete then
        playFile(sound_files.complete)
    end
end

-- ============================================
-- 获取音效信息
-- ============================================
function Sound.getSoundInfo()
    Sound.rescan()
    
    local info = {
        has_done = false,
        done_count = 0,
        has_overtime_warn = false,
        has_overtime_alert = false,
        has_complete = false,
    }
    
    if sound_files then
        for _ in pairs(sound_files.done or {}) do
            info.done_count = info.done_count + 1
        end
        info.has_done = info.done_count > 0
        info.has_overtime_warn = sound_files.overtime_warn ~= nil
        info.has_overtime_alert = sound_files.overtime_alert ~= nil
        info.has_complete = sound_files.complete ~= nil
    end
    
    return info
end

return Sound

