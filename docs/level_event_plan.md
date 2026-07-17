# Level Event Plan

建立時間：2026-07-17（第一關 prototype 第一個攤位事件：補貨時間）

目標不是做關卡系統，是驗證「在現有 2 分鐘生存場的時間軸上插入一段任務」這個模式
能不能成立、好不好玩。沿用 `main.gd` 現有的 stage/wave/spike/sprint 時間軸，
沒有新增關卡管理器、沒有分區地圖、沒有事件佇列——目前就是一個寫死在
`_process()` 裡的 if 判斷，正是原本工作包要求的範圍。

---

## 第一關事件節奏總表（這輪新增，供快速參考）

一局 120 秒目前長這樣：

| 時間 | 階段 | 說明 |
|---|---|---|
| 0–45s | **Warmup**（Early Game Grace） | 敵人量/波次間隔都被壓低，不出大型饕客，讓玩家熟悉操作 |
| ~45s | **補貨事件觸發** | `restock_trigger_elapsed=45.0`，固定時間點，跟 warmup 結束對齊 |
| 45s–~59s | 補貨事件進行中 | 最長 `restock_timeout=14s`，實際通常更早結束 |
| ~62–70s | **清除障礙事件觸發**（浮動） | `hazard_trigger_elapsed=64.0` 起算，實際觸發時間依排程保護浮動——如果補貨拖到很晚結束，會延後到補貨結束 + `hazard_min_delay_after_restock`（8s）之後；如果太靠近衝刺，會跳過或縮短 |
| 90s | **最後衝刺開始** | `warning_time=30`，BGM/生成節奏全部拉到最高 |
| 120s | 結束 | 勝利或客訴 10/10 落敗 |

**跟上一輪的差異**：`hazard_trigger_elapsed` 從 70 降到 64（使用者建議的 62–65 秒區間），
且不再是保證觸發時間，是「最早可能觸發」的時間點，真正的觸發時機取決於補貨事件什麼時候
結束、還有離衝刺還有多久。詳細規則見下面「事件二」的「排程保護」章節。

---

## 第一關前期節奏（Early Game Grace）——已實作

### 為什麼要做這個

補貨事件（下面「事件一」）預設開場 45 秒才觸發，但實測發現玩家可能在事件出現前就
先 Game Over 了（客訴 10/10）——第一關中段任務根本沒有機會成立，因為玩家活不到那個時間點。
根因是原本的 stage/wave 節奏從 0 秒就用「正式強度」在跑，沒有給新手/剛開局的玩家任何緩衝。

### 做法：疊加乘數，不改 stage 判斷本身

`_get_enemy_multiplier()`（[main.gd:676](../scripts/main.gd:676)）、
`_get_interval_multiplier()`（[main.gd:694](../scripts/main.gd:694)）在算完原本 stage1/2/3 的乘數後，
如果還在 `_in_early_grace()`（[main.gd:672](../scripts/main.gd:672)）範圍內，會再乘上
`early_enemy_multiplier`（預設 0.65，每波敵人變少）跟 `early_wave_interval_multiplier`
（預設 1.35，波次間隔拉長）。**是疊加不是取代**——就算緩衝期內客訴意外衝到 stage 2/3，
壓低的效果還是會套用，不會因為進了 stage 2 就突然打回原本強度。

`_roll_big_enemy_spawn()`（[main.gd:567](../scripts/main.gd:567)）在緩衝期內直接整個跳過，
不管當下 `stage` 判斷到哪——大型饕客對新手來說風險不對稱（打不掉、擋路、還會連累隊友被撞飛），
這個階段先不出現。

`_in_early_grace()` 跟 `_time_left` 走同一個時鐘（`(game_duration - _time_left) < early_grace_duration`），
倒數/暫停/突變選擇期間 `_time_left` 本來就不會動，緩衝期會跟著暫停，行為跟 sprint/warning
那套邏輯一致，沒有另外開一個計時器。

### 45 秒後會不會完全回到原本節奏？——會

`_in_early_grace()` 過了 `early_grace_duration` 秒之後永遠回傳 `false`，三個函式的早期
乘數分支就不會再進去，直接用原本的 stage1/2/3 邏輯，**一行都沒改**。`_get_stage()`、
`_build_wave_queue()`、`_update_spike_timer()`、sprint 系統全部原封不動。

### 跟補貨事件的關係

`early_grace_duration` 預設 `45.0`，刻意跟 `restock_trigger_elapsed`（也是 `45.0`）對齊——
兩個是完全獨立的參數，只是預設值相同，設計意圖是「緩衝期結束的那一刻，正好是玩家第一次
遇到明確任務（補貨事件）的時候」。如果之後要調其中一個，記得順手看一下另一個是否也該跟著調，
不然緩衝期結束後會有一段「已經沒有保護、但補貨事件還沒出現」的真空期，或反過來緩衝期還沒結束
補貨事件就先觸發了。

---

## 事件一：補貨時間（Restock Event）——已實作

### 接進第一關節奏的位置

```
0s ─────────────── 45s ─────────── 90s ────────────── 120s
開場                觸發補貨事件      最後衝刺開始         結束
↑── Early Grace ──↑ + Early Grace  (warning_time=30)
   （早期節奏緩衝）    在此結束
```

- 開場 45 秒（`restock_trigger_elapsed`）觸發，這也正好是 Early Game Grace 結束的時間點——
  玩家離開「有保護」的階段時，同時遇到第一個明確任務，銜接是刻意設計的
- 距離最後衝刺開始（開場 90 秒）還有 45 秒緩衝，事件本身 timeout 最多 14 秒，不會跟衝刺撞在一起
- 補貨事件跟波次/失控潮完全不互斥：事件進行中敵人照常生成，這是刻意的（玩法設計要求「補貨期間敵人照常進攻」）

### 觸發時機
`_update_restock_event()`（[main.gd:877](../scripts/main.gd:877)）每幀檢查 `_time_left <= game_duration - restock_trigger_elapsed`，
用 `_restock_triggered` 旗標保證一局只觸發一次。跟現有 `_is_sprint`、`_in_spike` 用的是同一套「布林旗標 + 每幀檢查」模式，沒有另外做狀態機/Timer 節點。

### 補貨區怎麼決定位置（已加防呆）
`_restock_zone_position(edge)` 在指定邊緣內縮 `radius + 34px`，確保落點在玩家移動邊界
（跟 `player.gd` 的 `ARENA_X/Y_MIN/MAX` 同一組數字）以內，玩家一定走得到。

`edge` 不是純隨機了——`_pick_restock_edge()` 會先算四個邊緣**中點**到最近玩家的直線距離，
排序後只從距離較近的兩個候選裡隨機選一個，避免補貨區出現在兩位玩家都在對角另一側的極端情況。
沒有做路徑尋路，純直線距離判斷，跟專案裡其他防呆判斷（例如擊退連鎖的 `KNOCKBACK_HIT_RANGE`）
是同一個量級的簡化，不是嚴謹的可達性驗證。

### 成功條件
玩家（任一位）站進補貨區（半徑 `restock_zone_radius = 56px`）累積 `restock_required_time = 3` 秒。
**累積時間離開區域不會歸零，只會暫停**——這是刻意的設計選擇：這款遊戲的擊退連鎖非常頻繁
（[docs/sound_event_map.md](sound_event_map.md) 那個 `CHAIN_HIT` 就是為了這個做的），
如果站到一半被隊友友火打飛出去就整個歸零重來，會變成懲罰「這款遊戲最大的樂趣來源」，
體驗會很差。所以站進去攢時間、被打飛也不虧，只是暫停，符合「隊友要掩護」但不會因為
一次意外撞飛而整段作廢。

**離開區域時的行為現在是可調參數**，預設維持上面說的「暫停不歸零」：
- `restock_progress_decays_when_empty`（預設 `false`）：關閉時完全維持凍結行為，這是目前的預設值，沒有實作硬歸零
- 開啟後，沒人站在區內時 `_restock_occupied_time` 會以 `restock_progress_decay_rate`（預設每秒 0.5，即攢 1 秒的量要花 2 秒空場才會退光）緩慢下降，不會瞬間清零，給「暫停」跟「歸零重來」之間留一個可以慢慢調的中間地帶

成功結果：
- 客訴 `-restock_success_relief`（預設 2）
- `_spawn_pause_timer` 暫停生成壓力 `restock_success_pause`（預設 2 秒）
- 播放 `_spawn_green_burst()`（跟 comeback 共用同一個粒子效果）
- 文字提示 + 借用 `MUTATION_APPLY` 音效當「成功」placeholder

### 失敗條件
`restock_timeout`（預設 14 秒）內累積不到 3 秒站在區內。**不會直接 Game Over**，
懲罰是立即在隨機邊緣多生成 `restock_fail_spawn_count`（預設 2）隻普通饕客，
不直接扣客訴（原因：失敗的後果已經透過「多的敵人如果沒擋住就會變成客訴」間接體現，
不想疊加雙重懲罰讓一次沒站到位就直接雪崩）。文字提示 + 借用 `COMPLAINT` 音效當「壞消息」placeholder。

### 音效
指示裡明確要求「不要新增新音效 hook」，所以三個時機（開始/成功/失敗）都是借用現有常數：
- 開始：`SPIKE_WARNING`（警報感最接近）
- 成功：`MUTATION_APPLY`（現有音效裡唯一的「正向確認」音）
- 失敗：`COMPLAINT`（現有音效裡唯一的「壞消息」音）

沒有新增任何 `audio_manager.gd` 的常數或 `_build_sfx()` 項目。

### 視覺
[restock_event.gd](../scripts/restock_event.gd) 是獨立的純 `_draw()` Node2D，風格照抄
`grease_puddle.gd`/`hit_effect.gd`：外圈範圍環、順時針進度環、中央箱子 icon（有人站進來變綠），
成功/失敗各自的閃色+放大+淡出收尾動畫。沒有用任何美術素材。

### UI 提示（開始/進度/成功/失敗都有文字了）
- `restock_label`：事件性 toast，開始/成功/失敗各觸發一次，淡入淡出後消失（`_show_restock_banner()`）
- `restock_progress_label`（新增）：事件進行中**持續顯示**，格式類似「補貨進度 1.4 / 3.0 秒（剩餘 9 秒）— 有人在區內」，
  事件開始時 `show()`，成功/失敗判定當下 `hide()`。這是這輪補的——之前只有事件性 toast，
  玩家在事件進行中途看不到任何文字提示，只能靠場上的補貨箱視覺自己猜進度

### Debug 測試方式（新增）
把 `restock_debug_key_enabled` 打開（`main.tscn` 選到 Main 節點，Inspector 裡 Restock Event 分組），
遊戲中按 **R 或 F9** 立即觸發補貨事件，不用等 45 秒（R 是備用鍵——Mac 上 F9 常被系統快捷鍵佔用不好按，兩個鍵效果完全一樣，用哪個都行）。這兩個鍵：
- 無視 45 秒等待，也無視「一局一次」限制——只要事件目前沒在進行中，按幾次都可以重新觸發，方便同一次 Play 反覆測
- 遊戲結束、倒數中、突變選擇畫面時按了沒反應（[main.gd:410-419](../scripts/main.gd:410)）
- 正式版預設 `restock_debug_key_enabled = false`，關掉之後這段程式碼完全不會被觸發，不影響任何正式行為，也不需要事後刪掉

### 對現有 wave/stage/spike 的副作用
- **沒有修改** `_update_wave_timer`/`_update_spike_timer`/`_get_stage()` 任何一行，事件是外掛在旁邊的獨立系統
- 補貨事件觸發/進行中，波次照常生成（玩法要求如此）
- 成功時的 `_spawn_pause_timer` 用的是原本就有的變數（跟 comeback 共用），不是新機制，行為完全可預期
- 遊戲提前結束（win/lose）時，若事件還在進行，`_clear_state_overlays()`（[main.gd:1394](../scripts/main.gd:1394)）
  會強制收掉視覺節點，避免半成品進度環卡在結算畫面後面——這是這輪順手補的邊界情況

---

## 實測調參建議

用 R 或 F9（見上面 Debug 測試方式）反覆測，這三個是最該先調的，都在 `main.gd` 的
`@export_group("Restock Event")` 裡，Inspector 直接改不用碰程式碼：

| 參數 | 預設值 | 調大會怎樣 | 調小會怎樣 | 觀察重點 |
|---|---|---|---|---|
| `restock_zone_radius` | 56px | 區域更好站進去、更容錯 | 逼玩家精準站位，配合擊退連鎖可能常常「差一點點」滑出去 | 兩位玩家同時擠進去時會不會卡到彼此走不進去（`player.gd` 的 `RADIUS=24`，兩人加起來直徑 96，區域太小會物理卡住） |
| `restock_required_time` | 3 秒 | 任務感更重，但要撐更久，中途被打飛的風險視窗更長 | 幾乎站一下就過，事件感會很淡 | 配合擊退連鎖的頻率一起看，別讓「累積」變得跟「一次站滿」沒差別 |
| `restock_timeout` | 14 秒 | 更寬鬆，幾乎不會失敗 | 逼玩家立刻放下手邊戰鬥往補貨區跑，可能太趕 | 從補貨區出現在最遠的那個候選邊緣（防呆後只會是距離較近的兩個之一）算起，玩家實際跑過去要花幾秒，`timeout` 要明顯大於這個數字才合理 |

另外兩個這輪新加的開關，建議先維持預設值跑幾局，覺得不對再動：
- `restock_progress_decays_when_empty`（預設關）——如果實測覺得「站到一半被打飛也不虧」太寬鬆、事件太容易過，可以先開這個做漸進懲罰，比直接做硬歸零溫和
- `_pick_restock_edge()` 的「只從最近兩個候選裡選」——如果覺得補貨區位置太好猜（永遠在玩家附近，缺乏「要探索」的感覺），這裡的候選池大小（目前寫死 2）是最直接能調的地方

---

## 事件二：清除障礙（Hazard Event）——已實作

跟補貨事件刻意選了**不同的任務形狀**：補貨是「站著不動攢時間、單點」，清除障礙是
「主動攻擊、多點、分散注意力」。這是驗證「多種事件交替出現」撐不撐得住的第一步，
不是重複驗證同一件事。

命名刻意主題中立（`hazard_event`/`HazardObject`，不叫 `clean_oil_event` 之類的夜市詞彙），
見 [theme_dependency_audit.md](theme_dependency_audit.md) 的紀錄。

### 接進第一關節奏的位置

```
0s ── warmup ── 45s(補貨觸發) ── ~59s(補貨最晚結束) ── 62-70s(清除障礙，依排程保護浮動) ── 90s(最後衝刺) ── 120s
```

**這一輪的重點是把上面這條時間軸從「寫死的數字」改成「有保護的排程」。** 原本
`hazard_trigger_elapsed=70` 搭配 `hazard_timeout=15`，最晚 85 秒結束、離衝刺只留 5 秒緩衝，
如果玩家補貨事件拖到很晚才結束，兩個事件會擠在一起變成資訊噪音而不是關卡節奏。這輪把
觸發時間下修到 `64.0` 秒（使用者建議的 62–65 秒區間），並加了三層排程保護，讓「幾秒觸發」
不再是保證值，而是「最早可能觸發的時間點」。

### 排程保護（新增）

`_try_trigger_hazard_event()`（[main.gd:1163](../scripts/main.gd:1163)）在
`hazard_trigger_elapsed` 到了之後，不會馬上觸發，會依序檢查三件事：

1. **補貨事件還在進行中？** → 直接 `return`，不設 `_hazard_triggered`，讓下一幀再檢查一次。
   等於「延後到補貨結束」，不用額外寫一個「等待中」狀態。
2. **補貨事件剛結束沒多久？** → `_restock_finished_at`（[main.gd:319](../scripts/main.gd:319)，
   在 `_finish_restock_event()` 裡記錄「結束當下經過了幾秒」）+ `hazard_min_delay_after_restock`
   （預設 8 秒）沒過，一樣先 `return`。
3. **太靠近最後衝刺？** → 算 `_time_left - warning_time`（離衝刺開始還有幾秒），如果小於
   `hazard_min_time_before_sprint`（預設 12 秒）：
   - `hazard_skip_if_too_late = true`（預設）→ 直接標記 `_hazard_triggered = true`，這局
     跳過，不硬塞一個沒空間跑完的事件
   - `= false` → 照樣觸發，但 `_start_hazard_event()`（[main.gd:1195](../scripts/main.gd:1195)）
     會把 `hazard_timeout` 收緊到 `time_before_sprint - 2.0`（且不低於 4 秒的可玩下限），
     保證不會真的跑進 sprint 裡

三個條件都通過才會真的呼叫 `_start_hazard_event()`，在中央壓力區外圍（離 `MAP_CENTER`
160–380px）隨機生成 `hazard_count_min`–`hazard_count_max`（預設 2–3）個 `HazardObject`，
`_hazard_spawn_position()` 簡單防呆彼此間距，避免兩個 hazard 疊在一起。

### hazard 怎麼清除
每個 `HazardObject`（[hazard_object.gd](../scripts/hazard_object.gd)）是 `StaticBody2D`，
`collision_layer` 沿用敵人那個 bit（跟 `enemy.tscn` 一樣是 layer 2），這樣既有的
`projectile.gd` 不用改碰撞遮罩就能偵測到它。`projectile.gd` 的 `_on_body_entered()`
（[projectile.gd:141](../scripts/projectile.gd:141)）新增一個 `elif body.is_in_group("hazards")`
分支，命中時呼叫 `body.take_hit()`，累積到 `hits_required`（預設 3 下）才會真的消失並
發出 `cleared` 訊號。跟敵人共用命中特效/`hit_enemy` 音效，沒有新增 SFX。

### hazard 存在時造成什麼壓力（方案 A：週期性滑地）
使用者給的三個方案裡選了最簡單可控的 A。`HazardObject` 存在期間每隔
`grease_interval`（預設 2.5 秒）秒在自己周圍生成一次滑地——**直接借用既有的
`grease_puddle.gd`**，沒有重造一個新的滑地系統。這代表 hazard 本身不會主動攻擊，
但放著不管會讓周圍越來越滑，逼玩家不能完全無視它。

### 成功條件
場上所有 hazard 都被打到消失（`_hazard_remaining` 歸零，[main.gd:1232](../scripts/main.gd:1232)）。
成功結果：客訴 `-hazard_success_relief`（預設 1）、暫停生成壓力 `hazard_success_pause`
（預設 1.5 秒）、文字提示 + 借用 `MUTATION_APPLY` 音效。

### 失敗條件
`hazard_timeout`（實際值受上面排程保護收緊，預設上限 15 秒）內沒清完
（[main.gd:1240](../scripts/main.gd:1240)）。**不會 Game Over**，逾時強制清掉場上剩下的
hazard（`force_clear()`，不計入成功、不重複觸發 `cleared`），懲罰是立即在隨機邊緣多生成
`hazard_fail_spawn_count`（預設 3）隻普通饕客，文字提示 + 借用 `COMPLAINT` 音效。

### UI（這輪加了互斥防疊字）
跟補貨事件共用同一塊畫面位置（`hazard_label`/`hazard_progress_label` 疊在
`restock_label`/`restock_progress_label` 同樣的座標）。顏色調成偏紅橙（區別於補貨事件的
金黃），方便一眼看出「這是不同的事件」。

排程保護讓兩個事件在**正常情況下**不會同時出現文字，但為了防止 debug 鍵或極端數值調整
製造出邊界情況，`_show_restock_banner()`/`_show_hazard_banner()`
（[main.gd:1115](../scripts/main.gd:1115)、[main.gd:1292](../scripts/main.gd:1292)）現在
互相防呆：顯示自己的 toast 之前，會先強制清掉（`kill()` tween + `hide()`）對方還在淡出的
那則，保證畫面上同時最多只有一個事件 toast，不會疊字。

### Debug 測試方式
- **補貨事件**：`restock_debug_key_enabled` 打開後按 **R 或 F9**
- **清除障礙事件**（新增）：`hazard_debug_key_enabled` 打開後按 **H**
  （[main.gd:471](../scripts/main.gd:471)），一樣只在事件目前沒進行中才會生效，而且**仍然
  尊重「補貨事件還在進行中就不啟動」這條排程保護**（[main.gd:1186](../scripts/main.gd:1186)）
  ——按 H 的當下如果補貨還在跑，會直接被擋掉，不會製造出這輪要修的疊字問題。如果想確認
  這個保護邏輯本身有沒有生效，可以故意在補貨事件進行中按 H，確認畫面上真的沒有反應

兩個開關互相獨立，也可以同時打開，兩個 debug 鍵不會互相干擾。

### 對現有系統的副作用
沒有修改 `_update_wave_timer`/`_update_spike_timer`/`_get_stage()`/補貨事件任何一行，
是外掛在旁邊的獨立系統。`hazard` 用的是全新的 `"hazards"` group，不會被
`player.gd` 的擊退連鎖判定（掃 `"enemies"` group）或 `enemy.gd`/`big_enemy.gd`
的互相推擠邏輯（也是掃 `"enemies"`/`"small_enemies"`/`"players"` group）誤觸——
雖然 collision_layer 借用了敵人那個 bit，但所有會影響行為的系統都是靠 group 判斷，
不是靠 collision_layer，所以沒有跨系統汙染的風險。

---

## 下一個事件建議（未實作，排序供參考）

補貨（單點、靜態、攢時間）跟清除障礙（多點、主動攻擊、分散注意力）已經是兩種不同形狀
的中段任務。下一個建議選一個**還沒被驗證過的形狀**：

1. **推餐車**——需要雙人同時在場才會移動，直接對應「合作但互雷」的設計目標，跟大型饕客的
   雙人破防機制形成呼應，這會是第一個「必須兩人同時在場，不能一人分身應付」的事件類型
2. **精英怪限時獵殺**——測試「戰鬥類」事件（打一隻特定強敵，不是清一群雜物）跟補貨/清除
   障礙這兩種「任務類」事件交替出現的節奏落差
3. **防守型**（例如保護某個定點不被饕客碰到 N 秒）——補貨跟清除障礙都是「主動完成」，
   這個會是第一個「被動防守、失敗條件是被動觸發」的類型，測試節奏會不會太像客訴機制本身

這些都還沒做，等清除障礙事件實機測完、確認好不好玩之後再排優先度。
