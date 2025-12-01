# FocusSpark 未来设计方案

> 版本：v2.0+ 设计草案  
> 创建日期：2025年12月1日  
> 作者：PhaseEggplant

---

## 📋 目录

1. [设计哲学](#设计哲学)
2. [猫猫朋友系统](#猫猫朋友系统)
3. [解锁与收集机制](#解锁与收集机制)
4. [出场机制设计](#出场机制设计)
5. [抽卡系统](#抽卡系统)
6. [经验等级系统](#经验等级系统)
7. [成就系统](#成就系统)
8. [视觉风格规划](#视觉风格规划)
9. [实施路线图](#实施路线图)

---

## 设计哲学

### 核心定位

**FocusSpark 不是传统电子宠物，而是"工作伴侣"**

```
传统电子宠物的问题：
  ❌ "责任"变成"负担"
  ❌ 不玩就会死/生病（制造焦虑）
  ❌ 情感连接有"保质期"
  ❌ 缺乏有意义的终点

FocusSpark 的设计原则：
  ✅ 猫咪是"奖励"，不是"负担"
  ✅ 猫咪永远不会死、不会饿、不会生病
  ✅ 你不登录，猫咪不会惩罚你
  ✅ 猫咪为你加油，而不是向你索取
```

### 与 BongoCat 的区别

| 维度 | BongoCat | FocusSpark |
|------|----------|------------|
| 核心 | 视觉玩具 | 工作伴侣 |
| 互动 | 实时输入反馈 | 工作进度反馈 |
| 养成 | 无 | 有（但不强制） |
| 情感 | 装饰性 | 陪伴感 |

### 猫 Meme 兼容设计

**问题**：每只猫 Meme 有固定"人设"，一只猫无法同时扮演多个角色

**解决方案**：**朋友系统**

```
不是"一只猫变身"
而是"多只朋友来访"

主猫（你的专属猫）+ Meme 猫朋友（特殊场景出场）
```

---

## 猫猫朋友系统

### 系统架构

```
┌─────────────────────────────────────────────────────────┐
│                    猫猫朋友系统                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   解锁来源              朋友池                出场机制   │
│   ┌─────┐             ┌─────┐             ┌─────┐      │
│   │等级 │────┐        │     │   事件触发   │     │      │
│   │成就 │────┼───────▶│已解锁│────────────▶│出场 │      │
│   │抽卡 │────┤        │朋友 │   +概率判定  │动画 │      │
│   │活动 │────┘        │     │             │     │      │
│   └─────┘             └─────┘             └─────┘      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 朋友列表（可无限扩展）

#### 普通朋友（Common）

| ID | 名称 | Emoji | 触发场景 | 解锁条件 |
|----|------|-------|---------|---------|
| `banana_cat` | 香蕉猫 | 🍌😿 | 加班、截止日警告 | 等级3 / 首次加班成就 |
| `maxwell_cat` | 蹦迪猫 | 🎵😺 | 连击3+、连击5+ | 等级5 / 5连击成就 |
| `polite_cat` | 礼貌猫 | 😺👔 | 开始工作、新的一天 | 默认解锁 |

#### 稀有朋友（Rare）

| ID | 名称 | Emoji | 触发场景 | 解锁条件 |
|----|------|-------|---------|---------|
| `crying_cat` | 流泪猫 | 😿💧 | 严重加班、目标失败 | 等级10 / 抽卡 |
| `huh_cat` | 困惑猫 | 🤔😺 | 长时间闲置、无目标 | 特殊成就 / 抽卡 |
| `keyboard_cat` | 键盘猫 | 🎹😺 | 极速完成、10连击 | 等级15 / 速度成就 |

#### 史诗朋友（Epic）

| ID | 名称 | Emoji | 触发场景 | 解锁条件 |
|----|------|-------|---------|---------|
| `pop_cat` | 啵啵猫 | 👄😺 | 每次完成任务 | 等级25 / 高级抽卡 |
| `chipi_cat` | 跳舞猫 | 💃😺 | 完成每日目标 | 等级30 / 高级抽卡 |

#### 传说朋友（Legendary）

| ID | 名称 | Emoji | 触发场景 | 解锁条件 |
|----|------|-------|---------|---------|
| `nyan_cat` | 彩虹猫 | 🌈😺✨ | 里程碑100、完美周 | 传说成就 / 0.1%抽卡 |
| `grumpy_cat` | 不爽猫 | 😾👑 | 极端加班、周一早晨 | 生存成就 / 0.1%抽卡 |

### 朋友数据结构

```lua
Friends.CATALOG = {
    banana_cat = {
        id = "banana_cat",
        name = "香蕉猫",
        name_en = "Banana Cat",
        rarity = "common",
        emoji = "🍌😿",
        pixel_sprite = "banana_cat.png",
        
        -- 解锁条件（满足任一即可）
        unlock = {
            { type = "level", value = 3 },
            { type = "achievement", id = "first_overtime" },
        },
        
        -- 出场条件
        trigger = {
            events = { "overtime", "deadline_warning" },
            base_chance = 0.8,
        },
        
        -- 出场表现
        appearance = {
            animation = "cry_walk",
            duration = 5,
            messages = {
                "香蕉猫来陪你一起哭了...",
                "呜呜...加班好累...",
            },
            sound = "banana_cry.wav",
        },
    },
    -- ... 更多朋友
}
```

---

## 解锁与收集机制

### 解锁来源

| 来源 | 描述 | 示例 |
|------|------|------|
| 等级 | 达到特定等级自动解锁 | 等级5解锁蹦迪猫 |
| 成就 | 完成特定成就解锁 | "首次5连击"解锁对应朋友 |
| 抽卡 | 消耗抽卡券随机获得 | 标准池/高级池 |
| 活动 | 限时活动获得 | 春节限定猫 |
| 里程碑 | 累计完成特定数量 | 完成1000样本解锁彩虹猫 |

### 解锁判定逻辑

```lua
function Friends.checkUnlockConditions(user_data)
    local newly_unlocked = {}
    
    for id, friend in pairs(Friends.CATALOG) do
        if not Friends.isUnlocked(id, user_data) then
            for _, condition in ipairs(friend.unlock) do
                if Friends.meetsCondition(condition, user_data) then
                    table.insert(newly_unlocked, friend)
                    table.insert(user_data.unlocked_friends, id)
                    break
                end
            end
        end
    end
    
    return newly_unlocked
end
```

---

## 出场机制设计

### 出场判定流程

```
事件发生（如：完成任务）
    │
    ▼
筛选匹配事件的已解锁朋友
    │
    ▼
对每个朋友进行概率判定
    │
    ▼
限制同时出场数量（最多2个）
    │
    ▼
播放出场动画和消息
```

### 概率计算

```lua
function Friends.calculateChance(friend, state, user_data)
    local base = friend.trigger.base_chance
    
    -- 好感度加成
    local affinity_bonus = (user_data.affinity[friend.id] or 0) * 0.01
    
    -- 稀有度惩罚
    local rarity_penalty = {
        common = 0,
        rare = -0.1,
        epic = -0.2,
        legendary = -0.3,
    }
    
    -- 连击加成
    local combo_bonus = 0
    if state.combo_count >= 5 then
        combo_bonus = 0.2
    elseif state.combo_count >= 3 then
        combo_bonus = 0.1
    end
    
    local final = base + affinity_bonus + rarity_penalty[friend.rarity] + combo_bonus
    return math.max(0.01, math.min(1.0, final))
end
```

### 事件类型

| 事件 ID | 触发时机 | 可能出现的朋友 |
|---------|---------|---------------|
| `work_start` | 开始计时 | 礼貌猫 |
| `done` | 完成任务 | 啵啵猫 |
| `combo_3` | 3连击 | 蹦迪猫 |
| `combo_5` | 5连击 | 蹦迪猫、键盘猫 |
| `combo_10` | 10连击 | 蹦迪猫、键盘猫 |
| `overtime` | 预计加班 | 香蕉猫、流泪猫 |
| `overtime_severe` | 严重加班 | 流泪猫、不爽猫 |
| `target_complete` | 完成每日目标 | 跳舞猫、彩虹猫 |
| `idle_long` | 长时间无操作 | 困惑猫 |
| `new_day` | 新的一天 | 礼貌猫 |

---

## 抽卡系统

### 卡池设计

#### 标准池

| 稀有度 | 概率 | 颜色标识 |
|--------|------|---------|
| Common | 70% | 白色 |
| Rare | 25% | 蓝色 |
| Epic | 4.9% | 紫色 |
| Legendary | 0.1% | 金色 |

#### 高级池

| 稀有度 | 概率 | 颜色标识 |
|--------|------|---------|
| Common | 40% | 白色 |
| Rare | 40% | 蓝色 |
| Epic | 18% | 紫色 |
| Legendary | 2% | 金色 |

### 抽卡券获取途径

| 来源 | 数量 | 条件 |
|------|------|------|
| 升级 | 1张 | 每次升级 |
| 成就 | 1-3张 | 根据成就难度 |
| 里程碑 | 1-5张 | 100/500/1000样本 |
| 连续打卡 | 1-3张 | 7天/30天连续 |
| 活动 | 不定 | 限时活动 |

### 保底机制

```
标准池：
  - 10连保底至少1个 Rare
  - 50连保底至少1个 Epic
  - 100连保底1个 Legendary

高级池：
  - 10连保底至少1个 Epic
  - 50连保底1个 Legendary
```

### 重复处理

```
抽到已拥有的朋友：
  - 转换为"好感度点数"
  - Common → 10点
  - Rare → 30点
  - Epic → 100点
  - Legendary → 500点

好感度点数用途：
  - 提升朋友出场概率
  - 兑换特定朋友
  - 解锁特殊皮肤
```

---

## 经验等级系统

### 经验获取

| 行为 | 基础经验 | 加成 |
|------|---------|------|
| 完成1个样本 | 10 EXP | - |
| 连击加成 | +5 × 连击数 | 3连击+15 |
| 按时完成目标 | +50 EXP | - |
| 提前完成目标 | +100 EXP | - |
| 加班惩罚 | -20 EXP | 鼓励按时完成 |

### 等级需求

| 等级 | 累计经验 | 称号 | 解锁内容 |
|------|---------|------|---------|
| 1 | 0 | 见习音效师 | - |
| 2 | 100 | 初级音效师 | - |
| 3 | 300 | 音效学徒 | 香蕉猫 |
| 5 | 800 | 音效工匠 | 蹦迪猫 |
| 10 | 2000 | 资深音效师 | 流泪猫 |
| 15 | 4000 | 音效专家 | 键盘猫 |
| 20 | 7000 | 音效大师 | - |
| 25 | 10000 | 音效宗师 | 啵啵猫 |
| 30 | 15000 | 传奇音效师 | 跳舞猫 |
| 50 | 50000 | 音效之神 | 特殊称号 |

### 升级奖励

```lua
level_rewards = {
    [5] = { tickets = 1, message = "恭喜升级！获得1张抽卡券" },
    [10] = { tickets = 2, friend = "crying_cat" },
    [15] = { tickets = 2, friend = "keyboard_cat" },
    [20] = { tickets = 3, title = "音效大师" },
    [25] = { tickets = 3, friend = "pop_cat" },
    [30] = { tickets = 5, friend = "chipi_cat" },
    -- ...
}
```

---

## 成就系统

### 成就分类

#### 进度类

| ID | 名称 | 描述 | 奖励 |
|----|------|------|------|
| `first_sample` | 第一步 | 完成第一个样本 | 10 EXP |
| `samples_100` | 百样达成 | 累计完成100个样本 | 1张抽卡券 |
| `samples_1000` | 千样大师 | 累计完成1000个样本 | 彩虹猫解锁 |

#### 连击类

| ID | 名称 | 描述 | 奖励 |
|----|------|------|------|
| `combo_5` | 初露锋芒 | 达成5连击 | 蹦迪猫解锁 |
| `combo_10` | 势如破竹 | 达成10连击 | 1张抽卡券 |
| `combo_20` | 无人能挡 | 达成20连击 | 啵啵猫解锁 |

#### 坚持类

| ID | 名称 | 描述 | 奖励 |
|----|------|------|------|
| `streak_7` | 一周坚持 | 连续7天完成目标 | 1张抽卡券 |
| `streak_30` | 月度冠军 | 连续30天完成目标 | 3张抽卡券 |
| `perfect_week` | 完美一周 | 一周内无加班 | 彩虹猫出场机会 |

#### 特殊类

| ID | 名称 | 描述 | 奖励 |
|----|------|------|------|
| `first_overtime` | 加班初体验 | 首次加班 | 香蕉猫解锁 |
| `survived_overtime_10` | 加班战士 | 累计加班10次后仍完成目标 | 不爽猫解锁 |
| `speed_demon` | 速度恶魔 | 单个样本在1分钟内完成 | 键盘猫解锁 |

---

## 视觉风格规划

### 风格定位

**星露谷物语像素风 + 猫 Meme 元素**

```
特点：
  - 像素尺寸：32x32 或 48x48
  - 调色板：限制 8-16 色
  - 轮廓线：深棕色（不是纯黑）
  - 整体氛围：温暖、治愈、可爱
```

### 调色板参考（橘猫）

```
毛色主体：#E8A64C
毛色阴影：#C47F2B
毛色高光：#F5C97A
眼睛绿：#3D7A3D
眼睛蓝：#6B9BD1
鼻子：#E88B9A
轮廓：#5A4A3A
```

### 动画规格

| 状态 | 帧数 | FPS | 循环 |
|------|------|-----|------|
| Idle | 2-4 | 2 | ✅ |
| Happy | 3-4 | 4 | ✅ |
| Excited | 4-6 | 8 | ✅ |
| Sleepy | 2-3 | 1 | ✅ |
| Special | 4-8 | 6 | ❌ |

### 资源文件结构

```
PE-FocusSpark/
├── assets/
│   ├── sprites/
│   │   ├── cats/
│   │   │   ├── main_cat.png          # 主猫 spritesheet
│   │   │   ├── banana_cat.png        # 香蕉猫
│   │   │   ├── maxwell_cat.png       # 蹦迪猫
│   │   │   └── ...
│   │   ├── effects/
│   │   │   ├── hearts.png
│   │   │   ├── stars.png
│   │   │   └── ...
│   │   └── ui/
│   │       └── ...
│   └── sprites.json                   # 精灵配置
```

### Emoji 降级策略

```lua
-- 如果没有精灵图，自动降级到 Emoji
function getCatDisplay(cat_id, state)
    if hasSprite(cat_id) then
        return { type = "sprite", ... }
    else
        return { type = "emoji", emoji = getEmoji(cat_id, state) }
    end
end
```

---

## 实施路线图

### Phase 1：基础准备（v1.x）

**目标**：为未来系统打好数据基础

```
□ 扩展 UserData 数据结构
  ├── 添加 total_completed（累计完成数）
  ├── 添加 total_days（累计天数）
  ├── 添加 unlocked_friends 数组
  └── 添加 achievements 字典

□ 实现朋友系统基础
  ├── 定义 Friends.CATALOG 数据结构
  ├── 实现 3-5 个基础朋友（Emoji版）
  └── 实现简单的出场判定

□ 添加成就追踪
  ├── 记录首次事件
  ├── 记录最高连击
  └── 记录连续打卡天数
```

### Phase 2：游戏化系统（v2.0）

**目标**：实现完整的经验/等级/收集系统

```
□ 经验等级系统
  ├── 经验获取逻辑
  ├── 等级计算
  ├── 升级奖励
  └── 等级 UI 显示

□ 朋友系统完善
  ├── 扩展到 10-15 个朋友
  ├── 完善出场概率计算
  ├── 实现朋友图鉴 UI
  └── 解锁通知/动画

□ 抽卡系统
  ├── 卡池设计
  ├── 概率实现
  ├── 保底机制
  └── 抽卡 UI/动画

□ 成就系统
  ├── 成就定义
  ├── 达成判定
  ├── 成就 UI
  └── 奖励发放
```

### Phase 3：视觉升级（v2.x）

**目标**：添加像素精灵，提升视觉表现

```
□ 像素资源制作
  ├── 主猫 spritesheet
  ├── 朋友 spritesheet
  ├── 特效动画
  └── UI 元素

□ 精灵渲染系统
  ├── 图片加载
  ├── 动画播放
  ├── Emoji 降级
  └── 性能优化

□ 视觉打磨
  ├── 出场动画
  ├── 粒子特效
  └── UI 美化
```

### Phase 4：扩展内容（v3.0+）

**目标**：持续扩展内容，保持新鲜感

```
□ 内容扩展
  ├── 新朋友（持续添加）
  ├── 节日限定
  ├── 特殊活动
  └── 主题皮肤

□ 社区功能
  ├── 图鉴分享
  ├── 成就展示
  └── 数据统计

□ 高级功能
  ├── 云同步
  ├── 多设备
  └── 自定义主猫
```

---

## 附录

### A. 数据结构完整定义

```lua
-- UserData 完整结构
UserData = {
    -- ===== 基础进度 =====
    total_completed = 0,        -- 累计完成样本数
    total_days = 0,             -- 累计工作天数
    first_use_date = "",        -- 首次使用日期
    
    -- ===== 经验等级 =====
    exp = 0,                    -- 当前经验值
    level = 1,                  -- 当前等级
    
    -- ===== 主猫 =====
    main_cat = {
        id = "default_tabby",
        name = "小橘",          -- 用户自定义名称
        created_at = "",
    },
    
    -- ===== 朋友系统 =====
    unlocked_friends = {},      -- 已解锁的朋友 ID 列表
    friend_affinity = {},       -- 朋友好感度 { id = points }
    
    -- ===== 抽卡 =====
    gacha_tickets = 0,          -- 抽卡券数量
    gacha_pity = {              -- 保底计数
        standard = 0,
        premium = 0,
    },
    
    -- ===== 成就 =====
    achievements = {},          -- 已达成的成就 { id = timestamp }
    
    -- ===== 统计 =====
    stats = {
        max_combo = 0,
        fastest_sample = 9999,
        longest_streak = 0,
        total_overtime = 0,
    },
}
```

### B. 事件触发点

```lua
-- 在 FocusSpark_Main.lua 中的触发点

-- 开始计时时
handleAction({ type = "startWork" })
-- 触发事件: "work_start"

-- 完成任务时
handleAction({ type = "done" })
-- 触发事件: "done", "combo_X"（根据连击数）

-- 更新估算时
handleAction({ type = "updateEstimate" })
-- 触发事件: "overtime"（如果预计加班）

-- 每日首次打开
-- 触发事件: "new_day"

-- 完成每日目标时
-- 触发事件: "target_complete"
```

### C. 扩展新朋友模板

```lua
-- 添加新朋友时复制此模板
new_friend = {
    id = "unique_id",           -- 唯一标识符
    name = "中文名",
    name_en = "English Name",
    rarity = "common",          -- common/rare/epic/legendary
    emoji = "🐱",               -- Emoji 表示
    pixel_sprite = "xxx.png",   -- 精灵图文件名
    
    unlock = {
        { type = "level", value = X },
        { type = "achievement", id = "xxx" },
        { type = "gacha", pool = "standard" },
    },
    
    trigger = {
        events = { "event1", "event2" },
        base_chance = 0.5,
    },
    
    appearance = {
        animation = "animation_name",
        duration = 3,
        messages = {
            "消息1",
            "消息2",
        },
        sound = "sound.wav",    -- 可选
    },
}
```

---

## 更新日志

| 日期 | 版本 | 更新内容 |
|------|------|---------|
| 2025-12-01 | 草案 v1 | 初始设计方案 |

---

> **注意**：本文档为设计草案，具体实现可能根据开发过程调整。
