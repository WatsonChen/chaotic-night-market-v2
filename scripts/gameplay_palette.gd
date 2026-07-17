extends RefCounted
class_name GameplayPalette

# ===================================================
# gameplay_palette.gd — 讀圖性配色 v1
#
# 只定義「gameplay 角色」層級的顏色，不是美術風格 palette，
# 也不是最終美術素材的色票。命名用 gameplay role
# （PLAYER_HEAVY、TASK_MARKER、HAZARD...），不用主題詞彙
# （不寫 HOTDOG_ORANGE），換主題只要換這個檔案的數值，
# 呼叫端（player.gd、restock_event.gd...）完全不用動。
#
# 設計理由跟每個數值怎麼來的，見 docs/readability_palette.md。
#
# 注意：.tres 資源檔（hotdog.tres 等）的顏色是序列化的字面值，
# 沒辦法動態參照這裡的常數——改這裡的數值後，需要同步手動
# 更新對應的 .tres，這是 Godot 資源格式的限制，不是這份檔案
# 的責任範圍。
# ===================================================

# ── 玩家（風險定位，不是角色名）──────────────────────
const PLAYER_HEAVY         := Color(0.95, 0.40, 0.08)   # 慢重型主色（現在：熱狗攤）
const PLAYER_HEAVY_ACCENT  := Color(1.00, 0.55, 0.20)   # 慢重型次要色（子彈等）

const PLAYER_SPEEDY        := Color(0.20, 0.55, 1.00)   # 快速型主色（現在：珍奶攤）
const PLAYER_SPEEDY_ACCENT := Color(0.35, 0.85, 1.00)

const PLAYER_RISK          := Color(0.95, 0.80, 0.12)   # 高風險型主色（現在：雞排攤）
const PLAYER_RISK_ACCENT   := Color(1.00, 0.92, 0.55)

# ── 敵人 ──────────────────────────────────────────
const ENEMY             := Color(0.88, 0.15, 0.15)   # 一般敵人：紅
const BIG_ENEMY          := Color(0.55, 0.05, 0.18)   # 大型敵人：深紅偏紫，跟一般敵人拉開
const BIG_ENEMY_ACCENT   := Color(0.85, 0.20, 0.38)   # 大型敵人外框/強調色

# ── 任務 / 危害（跟玩家、警告都不同色系）────────────
const TASK_MARKER := Color(0.25, 0.90, 0.55)   # 任務標記（現在：補貨區）：青綠
const HAZARD        := Color(0.62, 0.30, 0.92)   # 危害物（現在：清除障礙）：紫
const SLIP_ZONE      := Color(0.70, 0.70, 0.20)   # 持續型地面危害（現在：滑地）：低飽和黃綠

# ── 警告 / 節奏 ────────────────────────────────────
const WARNING       := Color(1.00, 0.20, 0.15)   # 失控潮/衝刺警告：紅（跟 ENEMY 同色系，不同語境）
const WARNING_FLASH := Color(1.00, 0.35, 0.22)   # 警告閃爍態，比 WARNING 亮一點

# ── 中央目標 ────────────────────────────────────────
const OBJECTIVE_BASE   := Color(0.85, 0.80, 0.68)   # 中性底色，不屬於任何一方
const OBJECTIVE_STAGE2 := Color(1.00, 0.70, 0.16)   # 階段二外圈：偏黃，跟 PLAYER_HEAVY 拉開
const OBJECTIVE_STAGE3 := Color(1.00, 0.16, 0.14)   # 階段三外圈：危險，等同 WARNING
