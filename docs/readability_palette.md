# Readability Palette v1

建立時間：2026-07-17
用途：[art_readability_brief.md](art_readability_brief.md) 盤點後發現的撞色問題（同一組暖橙色
被玩家、任務、警告、場景壓力四五個不相關系統共用）在這輪修掉了。這不是正式美術，是
placeholder 階段的配色重分配——先把「顏色代表什麼」的分工定下來，之後換正式美術素材時
延續同一套語言即可。

**這輪只改顏色（少數情況下改 marker 形狀），沒有動任何玩法數值、判定範圍、時間、傷害/擊退數字。**

---

## 一、單一色票來源：`scripts/gameplay_palette.gd`

新增一個純資料檔，`class_name GameplayPalette`，只有 `const Color` 定義，命名用
**gameplay role**（`PLAYER_HEAVY`、`TASK_MARKER`、`HAZARD`⋯），不用主題詞彙。其他腳本
透過 class_name 直接存取（例如 `GameplayPalette.TASK_MARKER`），不用 `preload`。

| Gameplay Role | 顏色（RGB） | 目前對應到 | 選色理由 |
|---|---|---|---|
| `PLAYER_HEAVY` | (0.95, 0.40, 0.08) 深橙 | P1／熱狗攤 | 保留橘，但比原本更紅、更飽和，跟下面幾個暖色系拉開距離 |
| `PLAYER_HEAVY_ACCENT` | (1.00, 0.55, 0.20) | P1 子彈 | 同色系的亮版本 |
| `PLAYER_SPEEDY` | (0.20, 0.55, 1.00) 藍 | P2／珍奶攤 | 沿用原本的藍——盤點時這是全場唯一的冷色，本來就最好認，沒有理由改 |
| `PLAYER_SPEEDY_ACCENT` | (0.35, 0.85, 1.00) | P2 子彈 | 同上 |
| `PLAYER_RISK` | (0.95, 0.80, 0.12) 純黃 | P3／雞排攤 | 原本雞排是琥珀色，跟熱狗的橙幾乎撞色。改成純黃（不偏橙）——這個決定連動了下面的 `WARNING` 改成紅色系，才能空出黃色給雞排用，見「設計取捨」 |
| `PLAYER_RISK_ACCENT` | (1.00, 0.92, 0.55) 偏白金黃 | P3 子彈 | 對應你建議的「金黃偏白」方向 |
| `ENEMY` | (0.88, 0.15, 0.15) 紅 | 一般敵人 | 沿用原本的紅，沒有改 |
| `BIG_ENEMY` | (0.55, 0.05, 0.18) 深紅偏紫 | 大型敵人 | 原本跟一般敵人一樣是純紅，只靠尺寸分——現在往紫色偏移，跟一般敵人拉開 |
| `BIG_ENEMY_ACCENT` | (0.85, 0.20, 0.38) | 大型敵人外框 | 原本外框是金黃色（撞色來源之一），換成跟 body 同色系的亮版本 |
| `TASK_MARKER` | (0.25, 0.90, 0.55) 青綠 | 補貨區 | 全新指派給任務類，之前補貨區是金黃色，是撞色最嚴重的節點之一 |
| `HAZARD` | (0.62, 0.30, 0.92) 紫 | 清除障礙 | 全新指派，之前 hazard 是橙色，跟補貨區、P1 都撞 |
| `SLIP_ZONE` | (0.70, 0.70, 0.20) 低飽和黃綠 | 滑地 | 原本就已經是低飽和黃綠，幾乎沒動，正式記錄進色票 |
| `WARNING` | (1.00, 0.20, 0.15) 紅 | 失控潮/衝刺警告 | 原本衝刺計時器是黃色（撞 P1 跟現在的雞排），改成紅色——理由見下方「設計取捨」 |
| `WARNING_FLASH` | (1.00, 0.35, 0.22) | 警告閃爍態 | `WARNING` 的亮版本 |
| `OBJECTIVE_BASE` | (0.85, 0.80, 0.68) 中性米色 | 中央目標（美食廣場）基礎色 | 新指派的中性色，不屬於任何一方 |
| `OBJECTIVE_STAGE2` | (1.00, 0.70, 0.16) | 中央目標 stage2 外圈 | 原本 stage2 是 (1.0,0.48,0.08)，幾乎等同 P1 的橙——改得更黃、更淡，跟 `PLAYER_HEAVY` 拉開 |
| `OBJECTIVE_STAGE3` | (1.00, 0.16, 0.14) | 中央目標 stage3 外圈 | 跟 `WARNING` 同色系——stage3 本來就該讀成「危險」，這裡刻意跟警告語言重疊 |

---

## 二、設計取捨（為什麼有些顏色沒有完全照你列的方向）

你給的方向裡，**Player 3 建議「金黃偏白、綠、或洋紅系」**，但綠已經指派給 `TASK_MARKER`、
洋紅/紫已經指派給 `HAZARD`——如果 P3 也選這兩個方向之一，會立刻製造一個新的撞色（角色跟
任務物件/危害物同色，比原本熱狗跟雞排撞色還嚴重，因為角色是持續在畫面上的，任務物件也是）。

處理方式：把 `WARNING`（衝刺/失控潮警告）從原本的黃色改成紅色系（你給的選項本來就允許
「紅或黃黑警示」二選一），空出**黃色**給 P3 用。這樣：
- P3 = 純黃，跟 P1（紅橙）用不同的色相，不是同一色系的深淺差異
- WARNING 改用紅色，跟 `ENEMY`（紅）同色系——這是刻意的，兩者都是「壞消息」，語意上重疊
  是合理的，而且兩者從來不會被誤認（一個是有臉的生物，一個是螢幕邊緣暈影/計時器文字），
  情境夠不同，撞色風險低

這是唯一一個沒有完全照你原始清單走的地方，記錄在這裡方便你之後檢視這個判斷對不對。

---

## 三、套用到哪些檔案

| 檔案 | 改了什麼 |
|---|---|
| `scripts/gameplay_palette.gd`（新增） | 色票本體 |
| `resources/characters/hotdog.tres` | `body_color`/`proj_color` → `PLAYER_HEAVY`/`_ACCENT` |
| `resources/characters/bubble_tea.tres` | 沒改——原本數值已經完全等於 `PLAYER_SPEEDY`/`_ACCENT` |
| `resources/characters/chicken_cutlet.tres` | `body_color`/`proj_color` → `PLAYER_RISK`/`_ACCENT`；`marker_shape` 從 `"circle"` 改成 `"triangle"` |
| `scripts/player.gd` | `_fallback_character()` 的 P1/P2 硬編碼顏色改用 `GameplayPalette`；`_draw()` 的 marker 繪製新增 `"triangle"` 分支（三角形，最小擴充，沒有動 circle/square 既有邏輯） |
| `scripts/restock_event.gd` | `base_color` → `GameplayPalette.TASK_MARKER` |
| `scripts/hazard_object.gd` | `base_color` → `GameplayPalette.HAZARD` |
| `scripts/grease_puddle.gd` | `puddle_color` 預設值微調到跟 `SLIP_ZONE` 完全一致（原本已經很接近） |
| `scripts/big_enemy.gd` | `body_color`/`outline_color` → `BIG_ENEMY`/`_ACCENT`；`p1_bar_color`/`p2_bar_color` 改成直接對應 `PLAYER_HEAVY`/`PLAYER_SPEEDY`（破防條顏色現在跟打中它的玩家顏色一致，這是順手做的額外一致性，不在原始清單裡） |
| `scripts/food_court.gd` | stage1/stage2 外圈+內光暈顏色調整，避開跟 `PLAYER_HEAVY`/`PLAYER_RISK` 撞色；stage3 沒動（已經是紅色系，跟 `WARNING` 語意一致） |
| `scripts/main.gd` | 補貨/清除障礙的螢幕閃光、事件 toast 文字顏色、`stage2_banner_color`/`stage2_tint_color`（跟 food_court stage2 對齊）、`sprint_timer_color`/`sprint_timer_flash_color`（改用 `WARNING` 系） |

---

## 四、哪些撞色被拆開了

| 原本撞色的一組 | 現在 |
|---|---|
| P1 身體色、stage2 危險 banner、衝刺計時器閃爍色、美食廣場 stage2 光暈（全部 ≈(1.0,0.5,0.08)） | 只剩 `PLAYER_HEAVY` 是這個色相，其他三個都改到不同色相/明顯不同數值 |
| P1 子彈色、補貨區主色+閃光、hazard 警示色、衝刺計時器主色（全部 ≈(1.0,0.78,0.15)） | 拆成四種不同色相：`PLAYER_HEAVY_ACCENT`（橙）、`TASK_MARKER`（青綠）、`HAZARD`（紫）、`WARNING`（紅） |
| 大型饕客 P1 破防條、外框色、雞排攤原本的琥珀色（全部落在暖橙-琥珀帶） | `BIG_ENEMY_ACCENT`（紅紫）、`p1_bar_color`（直接對應 `PLAYER_HEAVY`）、`PLAYER_RISK`（改成純黃）三者現在色相明顯不同 |

## 五、仍然可能撞色、需要實機確認的地方

- **`ENEMY`（紅）跟 `WARNING`（紅）同色系**——刻意保留，理由見上面「設計取捨」，但這是
  唯一沒有做到「完全不同色相」的一組，實機測試時建議特別留意失控潮/衝刺期間會不會混淆
  「這是敵人」跟「這是警告特效」
- **`food_court.gd` 的 stage2 外圈跟 `PLAYER_HEAVY`**——已經把數值拉開（G channel 差 0.30），
  但兩者都還在「橙黃」大方向上，不是像 `TASK_MARKER`/`HAZARD` 那樣完全換色相，實機看
  中央目標處在 stage2 時，跟 P1 站在附近會不會還是有點糊
- **P1/P2 使用 override 換成別的角色時，大型饕客的破防條顏色不會跟著變**——`p1_bar_color`/
  `p2_bar_color` 是寫死對應「預設角色」的顏色，如果用 Inspector 把 P1 換成雞排攤（黃），
  破防條還是會顯示熱狗的橙色，這是已知的小落差，不在這輪範圍內修（跟角色資料動態綁定
  需要多一點工程，這輪只調色彩不調邏輯）

---

## 六、跟 art_readability_brief.md 的關係

這份文件是 v1 的**執行結果**，`art_readability_brief.md` 的「必須優先視覺化的 Gameplay
元素」章節已經同步標註哪些項目的撞色在這輪解決了。真正的美術素材進來之後，正式配色不
一定要完全照抄這裡的數值，但「一個 gameplay role 只對應一種主色相」這個分工原則建議延續。
