# Theme Dependency Audit

建立時間：2026-07-17
用途：實際盤點目前程式碼裡哪些地方綁死了夜市題材，分類記錄換主題時的處理方式跟大概成本。
**這份文件只盤點、不重構**——下面沒有任何一行程式碼被改動，純粹是為了讓「要不要保留夜市皮」
這個決定有具體依據，而不是憑印象猜。

方法：用 `grep` 對 `scripts/`、`scenes/`、`docs/`、`project.godot` 全文搜尋夜市相關字詞
（夜市、客訴、美食廣場、饕客、攤位、熱狗、珍奶、雞排等），逐一確認每個命中是「純顯示文字」
「內部命名」還是「檔案/資源命名」。

---

## A. UI 顯示文字（成本最低——改字串不影響任何邏輯）

這是目前最大宗的夜市綁定，但也是最好處理的一種：全部都是字串常數或 `@export var ... : String`，
換主題只要改文字內容，不動任何程式邏輯。

| 位置 | 內容 |
|---|---|
| [main_menu.gd:13,15](../scripts/main_menu.gd:13) | 遊戲標題「混亂夜市」、副標「2 人合作守護夜市」——**這是曝光度最高的一處**，玩家在主選單第一眼看到的就是這行字 |
| [main.gd:24](../scripts/main.gd:24) | `TXT_LOSE_TITLE = "夜市崩潰了！"` |
| [main.gd:92-93](../scripts/main.gd:92) | `stage2_message`/`stage3_message`：「夜市開始失控」「已經完全失控」 |
| [main.gd:1557-1561](../scripts/main.gd:1557) | 五個突變卡片的標題/描述文字（熱狗太興奮、珍珠大爆發、大胃王狂潮等），跟角色/題材綁定最深的顯示文字 |
| [main.gd:768](../scripts/main.gd:768) 等多處 | 「客訴 X / Y」、「補貨時間！」、「差點失控，但被你們救回來了！」等執行期組字串 |
| `project.godot:18` | `config/description="合作英雄射擊 + 物理混亂 + 夜市皮"`——**這行本身就已經把夜市定位成「皮」**，跟這次討論的結論一致，是專案 metadata 不是程式邏輯 |

這一類全部集中在 `main.gd`、`main_menu.gd` 兩個檔案裡，換主題時是一次性的文字置換工作，
不涉及邏輯風險。

---

## B. 內部程式碼命名（中成本——機械式重新命名，需要小心不要漏改）

這些是變數/函式/訊號名稱本身用了主題詞彙，邏輯不受影響，但改名字是全域重新命名，
需要用 IDE 的「重新命名符號」或仔細的全文取代，漏改會造成引用不到的 bug。

| 命名 | 出現範圍 | 說明 |
|---|---|---|
| `complaint_count`、`complaint_label`、`_set_complaint_count()`、`_on_enemy_reach_center()` 的 `complaint_delta` 參數 | `main.gd`、`enemy.gd`、`big_enemy.gd`、`player.gd`、`food_court.gd`、`audio_manager.gd` | 核心壓力計數器，命名上綁了「客訴」這個夜市限定的隱喻，但**機制本身（壓力值遞增→觸發階段轉換）完全主題中立**，換成 `alert_count`/`incident_count` 之類的中性詞不影響任何邏輯 |
| `food_court`（節點/變數/腳本）、`FoodCourt`（`main.tscn` 節點名） | `main.gd`、`main.tscn`、`food_court.gd` 檔名本身 | 場地中央的視覺+壓力區系統，機制是「中央目標區」，跟美食廣場的視覺無關 |
| `_roll_big_enemy_spawn()`、`sprint_big_spawn_min/max` 等變數名裡的「big_enemy」 | `main.gd` | 這個已經是英文命名、沒有中文題材詞，只有註解裡的「大型饕客」是中文顯示文字（見上面 A 類），命名本身已經算主題中立 |
| `enemy.gd` 檔頭註解「普通饕客（敵人）」 | `enemy.gd:4` | 純註解，不影響編譯或邏輯 |

---

## C. 檔案與資源命名（中成本——需要同步更新 preload 路徑）

| 檔案 | 綁定內容 | 被引用的地方 |
|---|---|---|
| `resources/characters/hotdog.tres`、`bubble_tea.tres`、`chicken_cutlet.tres` | 檔名跟角色名稱都是食物 | `main.gd` 的 `CHARACTER_HOTDOG`/`CHARACTER_BUBBLE_TEA`/`CHARACTER_CHICKEN_CUTLET` 三個 `preload()` 常數指到這些路徑；改檔名要同步改這三行 |
| `.tres` 內的 `character_name` 欄位（「熱狗攤」「珍奶攤」「雞排攤」） | 純資料值，不是程式碼 | 只有 `character_debug_label` 顯示用，改資料不用碰 `.gd` |
| `resources/controls/p1_keyboard.tres`、`p2_keyboard.tres` | 檔名跟主題無關（已經是中性命名） | — |
| `scripts/food_court.gd`、`scenes/main.tscn` 裡的 `FoodCourt` 節點 | 見上方 B 類 | `main.gd` 用 `$World/FoodCourt` 存取 |
| `scripts/grease_puddle.gd`（油漬/滑倒機制） | 檔名跟夜市地板油漬的視覺綁定，但機制（踩到會滑）本身通用（冰面、油、黏液都適用） | `main.gd` 多處 `preload`/`GREASE_PUDDLE_SCRIPT` |

---

## D. 專案層級中繼資料（文件工作，不是程式碼重構）

- `project.godot` 的 `config/name="chaotic-night-market-v2"`——專案代號本身帶夜市字樣，改這個不影響任何執行邏輯，純粹是專案識別
- [CLAUDE.md](../CLAUDE.md) 整份文件是以夜市為前提寫的專案架構說明（場景樹、碰撞層、輸入對應等技術內容其實完全主題中立，只有標題跟少數敘述文字提到夜市）
- `docs/character_roster.md`、`docs/sound_event_map.md`、`docs/level_event_plan.md`、`docs/playtest_checklist.md` 這幾份文件裡大量使用「熱狗攤」「補貨」等夜市詞彙描述現況——這些是**文件**，換主題的話文件本身也要跟著改寫，但這是寫作工作，不是程式重構

---

## E. 已經是主題中立的部分（好消息，不用改）

- **`audio_manager.gd` 的 SFX 常數全部已經是主題無關命名**（`HIT_ENEMY`、`HIT_PLAYER`、
  `BIG_BREAK`、`COMPLAINT`、`MUTATION`、`WIN`、`LOSE`、`CHAIN_HIT`、`MUTATION_APPLY`、
  `SPIKE_WARNING`）——沒有一個叫 `HOTDOG_HIT` 之類的名字，這個系統從一開始命名就沒有跟夜市綁定
- **`player_character.gd`（`PlayerCharacter` Resource）的欄位全部是通用武器數值**
  （`shoot_cooldown`、`proj_radius`、`proj_knockback_base`、`marker_shape` 等），沒有一個
  欄位假設角色一定跟食物有關——這也是為什麼雞排攤能在不改 `.gd` 的情況下加進來
- **`control_profile.gd`（`ControlProfile` Resource）完全跟主題無關**，純粹是輸入來源設定
- **`enemy.gd`/`big_enemy.gd`/`projectile.gd` 的核心邏輯**（`take_hit`、擊退、hit_stop、
  雙人破防判定）全部用中性命名，`reach_center` 訊號雖然帶了 `complaint_delta` 這個參數名
  （見 B 類），但訊號本身的意義（「敵人抵達中心，回報一個壓力值」）完全通用
- **`main.gd` 的 stage/wave/spike/sprint/mutation/restock 系統**——變數命名（`_get_stage()`、
  `wave_count`、`_in_spike`、`_is_sprint`）全部主題中立，唯一跟主題掛勾的是顯示給玩家看的
  文字內容（見 A 類），不是系統本身的設計

---

## F. 這輪新增的命名決策（清除障礙事件）

新增第二個中段事件時，刻意檢查了每個新名字是不是主題中立，記錄决策供之後參考：

| 用了什麼名字 | 沒用什麼名字 | 理由 |
|---|---|---|
| `hazard_event`（概念）、`HazardObject`、`hazard_object.gd`、`scenes/hazard.tscn` | ~~`clean_oil_event`~~、~~`trash_event`~~ | 事件本身的骨架是「主動清除多個目標」，跟障礙物具體是什麼無關 |
| `hazards` group、`hazard_trigger_elapsed`、`hazard_count_min/max`、`hazard_hits_required` | ~~`oil_barrel`~~、~~`trash_pile_count`~~ | `main.gd` 裡新增的所有 `hazard_*` 變數都沒有夜市詞彙 |
| `take_hit()`、`cleared` 訊號、`force_clear()` | — | 沿用 `enemy.gd`/`big_enemy.gd` 既有的命名風格（`take_hit`），保持一致性也保持中立 |

**唯一的妥協**：hazard 存在期間的壓力來源直接借用了既有的 `grease_puddle.gd`
（`HazardObject._spawn_grease_puddle()`），這個腳本本身的檔名/類別命名是夜市詞彙
（見上面 C 類），不是這輪新取的名字。這是刻意的取捨——重造一個中性命名的「滑地」系統
只是換個名字做一樣的事，沒有實質效益，優先級遠低於「先讓玩法成立」。如果之後真的要換
主題，`grease_puddle.gd` 改名／換皮的時候，`hazard_object.gd` 裡的 `preload` 路徑要跟著
更新，這點記錄在這裡，之後不會漏掉。

---

## 建議

**哪些東西可以保持抽象、現在不用管**：B 類的內部命名（`complaint_count`、`food_court` 等）。
這些改不改都不影響「現在能不能做別的主題」——就算保留這些命名，未來也能直接套一個新主題的
`PlayerCharacter`/`.tres`/顯示文字上去，玩家不會看到 `complaint_count` 這個變數名。**不要
為了「主題中立」而現在去重新命名這些變數**，那是沒有實際效益、只有風險（改壞引用）的工作。

**現在不用改的**：C 類的檔案命名（`hotdog.tres` 等）跟 D 類的專案 metadata。這些只有在
「真的確定要換主題」的那一刻才需要動，現在動只是提前花成本換一個現在用不到的好處。

**如果未來真的要換主題，最小成本會動哪些檔案**（依影響範圍排序）：
1. `main_menu.gd`（標題/副標，曝光度最高）
2. `main.gd`（所有 `TXT_*`、`@export var *_message`、突變卡片文字、`character_debug_label` 格式字串）
3. `resources/characters/*.tres` 三個角色檔（換成新主題的角色設定，含 `character_name` 欄位）
4. `project.godot` 的 `config/description`（非必要，但建議跟著換）
5. 場景/腳本的視覺呈現（`food_court.gd`、`enemy.gd`、`player.gd` 的 `_draw()`，這些是**視覺**
   不是主題邏輯——換皮的大頭在這裡，但這是美術/視覺工作，不是這份文件盤點的範圍）

完全不用動：`audio_manager.gd`、`player_character.gd`、`control_profile.gd`、
`projectile.gd`、`big_enemy.gd` 的核心邏輯、六個核心樂趣支柱本身。

**現階段是否仍建議暫時保留夜市皮**：建議保留。理由不是「夜市比較好」，是這輪盤點顯示
**換皮的實際成本比想像中低，而且現在動它拿不到任何好處**——A 類（顯示文字）改起來最快，
但沒有急迫性；B、C 類（命名/檔案）現在改反而增加這輪還在快速迭代期的出錯風險（前幾輪才因為
一次不小心的重寫漏掉兩個常數，導致 parser error）。比較合理的順序是：先用
[theme_options.md](theme_options.md) 想清楚要不要換、換哪個，決定了之後再一次性處理，而不是
現在就開始零星地把夜市字眼換成中性字眼——那樣反而兩邊都不到位，徒增風險。
