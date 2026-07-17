# Sound Event Map

初版盤點：2026-07-17
更新（優先級/cooldown + 3 個新 hook）：2026-07-17
範圍：`scripts/audio_manager.gd`、`scripts/main.gd`、`scripts/projectile.gd`、`scripts/player.gd`（全專案音效呼叫只在這四個檔案，已用
`grep -rn "AudioStreamPlayer\|\.play("` 全域確認過，沒有其他散落的音效節點）。

所有音效目前都是 `audio_manager.gd` 用 `_make_sine` / `_make_sweep` / `_make_melody` 即時合成的
**placeholder**，沒有匯入任何正式音檔。之後要換成真正音色時，只要在 `_build_sfx()` 把對應的
`_sfx_streams[常數]` 換成載入 `.wav`/`.ogg` 即可，事件架構、優先級、cooldown 都不用動。

---

## 一、優先級 / Cooldown 保護（本輪新增）

`audio_manager.gd` 的 `play(sfx_name)` API 沒變，呼叫端完全不用改。內部做了兩層輕量保護：

**① 雙通道池，LOW 不會搶到 HIGH 的播放器**

| 池 | 大小 | 涵蓋音效 |
|---|---|---|
| LOW（`_sfx_players_low`） | 6 | `hit_enemy`、`hit_player`、`chain_hit` |
| HIGH（`_sfx_players_high`） | 3 | `complaint`、`big_break`、`mutation`、`mutation_apply`、`spike_warning`、`win`、`lose` |

`_PRIORITY` 這個 Dictionary（[audio_manager.gd:82](../scripts/audio_manager.gd:82)）決定一個音效名稱查哪個池。命中類音效（頻率最高、最吵）永遠只會搶自己那組 6 個播放器，不會再把訊息性音效直接打斷。

**② 每個音效自己的最短重播間隔**（`_MIN_RETRIGGER_INTERVAL`，[audio_manager.gd:98](../scripts/audio_manager.gd:98)）

| 音效 | 最短間隔 | 為什麼 |
|---|---|---|
| `complaint` | 0.06s | 失控潮/衝刺時可能多隻同時抵達中央 |
| `chain_hit` | 0.08s | 玩家擊退連鎖是 per-physics-frame 判定（見下方②），最容易洗版 |
| `spike_warning` | 1.5s | 失控潮警告跟衝刺開始警告共用同一個常數，兩處短時間內都觸發時只留第一次 |

沒列進表的音效（`hit_enemy`、`hit_player`、`big_break`、`mutation`、`mutation_apply`、`win`、`lose`）不限制重播間隔——`hit_enemy`/`hit_player` 本來就該跟手感同步，稀疏事件也不需要。

判斷順序：先查 cooldown（超時間隔內直接跳過不播），沒被擋才進去選通道池。

---

## 二、SFX 事件總表（共 10 個常數，全部有實際呼叫）

| 事件名稱 | 常數 | 優先級 | 觸發位置 | 音效類型（placeholder） |
|---|---|---|---|---|
| 敵人被打中 | `HIT_ENEMY` | LOW | [projectile.gd:126](../scripts/projectile.gd:126) `_on_body_entered` | sine 300Hz / 0.08s |
| 玩家被打中（友火） | `HIT_PLAYER` | LOW | [projectile.gd:136](../scripts/projectile.gd:136) `_on_body_entered` | sine 800Hz / 0.10s |
| **玩家連鎖擊退命中（新）** | `CHAIN_HIT` | LOW + cooldown 0.08s | [player.gd:279](../scripts/player.gd:279)、[player.gd:286](../scripts/player.gd:286) `_physics_process` 高速撞飛判定，撞敵人/撞隊友各呼叫一次 | sine 500Hz / 0.06s |
| 大型饕客破防 | `BIG_BREAK` | HIGH | [main.gd:649](../scripts/main.gd:649) `_on_big_enemy_armor_broken` | sweep 600→200Hz / 0.30s |
| 客訴 +1 | `COMPLAINT` | HIGH + cooldown 0.06s | [main.gd:635](../scripts/main.gd:635) `_on_enemy_reach_center` | sine 200Hz / 0.15s |
| 突變選擇畫面出現 | `MUTATION` | HIGH | [main.gd:1420](../scripts/main.gd:1420) `_show_mutation_choice` | sweep 400→800Hz / 0.20s |
| **突變生效瞬間（新）** | `MUTATION_APPLY` | HIGH | [main.gd:1434](../scripts/main.gd:1434) `_hide_mutation_choice`，玩家選完/自動選完、效果真正套用的那一刻 | sweep 500→1000Hz / 0.14s |
| **失控潮 / 衝刺警告（新）** | `SPIKE_WARNING` | HIGH + cooldown 1.5s | [main.gd:796](../scripts/main.gd:796) `_show_spike_warning`；[main.gd:1113](../scripts/main.gd:1113) `_start_sprint_pressure` | 雙擊 melody 880Hz×2 / 0.09s |
| 勝利 | `WIN` | HIGH | [main.gd:1143](../scripts/main.gd:1143) `_trigger_win` | melody [400,600,800] |
| 失敗 | `LOSE` | HIGH | [main.gd:1075](../scripts/main.gd:1075) `_trigger_game_over` | melody [600,400,200] |

`CHAIN_HIT` 的優先級歸類特別說明一下：雖然它是這次新增、且是「本作最有辨識度的瞬間」，但它跟 `hit_enemy` 一樣是 per-frame 高頻事件（見下方②），如果放進 HIGH 池反而會把 `complaint`/`big_break` 擠掉，所以刻意跟 `hit_enemy`/`hit_player` 同一級，靠 cooldown 而不是靠優先級來控制密度。

## 三、BGM 連動 Hook（非一次性 SFX，屬於節奏機系統，本輪未動）

| Hook | 觸發位置 | 行為 |
|---|---|---|
| `audio_mgr.update_complaints(count)` | [main.gd:683](../scripts/main.gd:683) `_set_complaint_count` | 只會升階，不會因 comeback 降階（刻意設計：壓力只漲不退） |
| `audio_mgr.set_sprint_mode(true)` | [main.gd:1112](../scripts/main.gd:1112) `_start_sprint_pressure` | 強制切到 Phase 4（160 BPM + 密集 16th note） |

## 三之一、角色武器音色（新增第三個角色時順手記錄，本輪未動）

`HIT_ENEMY`/`HIT_PLAYER` 目前是**全角色共用**同一個音效——不管開槍的是熱狗攤、珍奶攤還是
新加入的雞排攤（`resources/characters/chicken_cutlet.tres`），命中音都是同一組
sine 300Hz/800Hz。這在只有兩個手感差異不大的角色時不明顯，但雞排攤定位是「近距離重擊、
一發入魂」（見 [docs/character_roster.md](character_roster.md)），數值上 `proj_hit_stop=6`、
`proj_radius=20.0` 全場最大，命中卻跟熱狗攤共用同一顆 300Hz 短音，聽感跟數值手感會對不上。

未來方向：`HIT_ENEMY`/`HIT_PLAYER` 可以考慮從「單一音效」改成「依 `shooter.character.proj_radius`
或角色名稱挑音色」，例如雞排攤命中用更低頻、更悶的「啪」聲對應大顆重擊，珍奶攤維持現在清脆的
高頻音對應小顆連射。這一步需要先有多套音色（或多組合成參數），這輪只記錄方向，沒有實作。

## 四、還沒接音效的事件（更新後剩下的缺口）

| 事件 | 觸發位置 | 目前狀態 |
|---|---|---|
| 階段轉換（stage 2/3） | [main.gd:705](../scripts/main.gd:705) `_on_stage_changed` | 只有閃光/震動/banner |
| Comeback（客訴 -1） | [main.gd:661](../scripts/main.gd:661) `_trigger_comeback` | 有綠色粒子噴發+閃光，但沒有「鬆一口氣」音效，跟 `COMPLAINT` 不對稱 |
| 油漬滑倒 | `grease_puddle.gd` | 全檔案無任何音效呼叫 |
| 倒數 3-2-1-GO | [main.gd:1754](../scripts/main.gd:1754) `_run_countdown` | 純視覺 |
| 暫停/取消暫停 | [main.gd:1784](../scripts/main.gd:1784) `_toggle_pause` | 純視覺 |

## 五、風險筆記

**① （已處理）共用音效池互相蓋台** —— 原本所有音效共用一組 8 個播放器的 round-robin，高頻命中音會蓋掉訊息音。這輪拆成 LOW/HIGH 雙池 + cooldown 解決，見第一節。

**② `_play_sfx` 每次命中都重新查 group（未動）**——[projectile.gd:143](../scripts/projectile.gd:143)、[player.gd:386](../scripts/player.gd:386) 都用 `get_tree().get_nodes_in_group("audio_manager")` 而非快取引用，效能上非必要，但目前規模下無感，這輪沒有動。`_play_chain_sfx()`（[player.gd:384](../scripts/player.gd:384)）是照同一個模式寫的，維持一致性優先於效能微調。

**③（新發現，已處理）連鎖擊退是 per-frame 判定，不是單次事件**——[player.gd:272-287](../scripts/player.gd:272) 這段在玩家擊退速度超過閾值期間，每個 `_physics_process`（60Hz）都會重新掃一次範圍內的敵人/隊友並呼叫 hit。擊退速度衰減需要一小段時間才會降到閾值以下，如果撞飛瞬間剛好卡在一群敵人中間，同一批目標可能連續好幾幀都在範圍內，若沒有 cooldown 會變成機關槍式重複播放。這是 `CHAIN_HIT` 需要 0.08s cooldown 的直接原因，不是套用「以防萬一」的保守值，而是這個觸發點的真實行為逼出來的。

---

## 六、下一個最值得補的音效事件（更新後建議）

前一輪盤點列的前三名（連鎖擊退、突變生效、失控潮警告）這輪都做完了。剩下缺口裡優先度最高的：

1. **Comeback 鬆一口氣音效**——跟 `COMPLAINT` 現在不對稱：客訴 +1 有聲音，客訴 -1（comeback）卻無聲。這是唯一「正向回饋」時刻卻沒有音效強化，情緒張力沒接住。
2. **階段轉換音效**（stage 2 / stage 3）——目前只靠螢幕閃光/震動傳達「更難了」，加一個音效可以讓玩家在還沒看清畫面文字前就先感覺到情境升級。
3. **暫停/取消暫停 UI 音**——工程成本最低（不涉及遊戲節奏、不用擔心洗版），但玩家每次操作都會聽到，體感上「這遊戲有打磨」的性價比最高。
