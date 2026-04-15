# chaotic-night-market-v2 — 專案架構說明

## 概要

Top-down 合作派對遊戲。兩名玩家在夜市廣場阻擋源源不絕的饕客（敵人）進入美食廣場，
若有 10 隻饕客成功抵達中央即觸發 Game Over。

---

## 技術規格

- 引擎：Godot 4.2+（GDScript）
- 視窗：1280 × 720，不可縮放
- 所有腳本使用繁體中文註解

---

## 目錄結構

```
chaotic-night-market-v2/
├── project.godot          # 專案設定（視窗、輸入動作）
├── CLAUDE.md              # 本文件
├── scenes/
│   ├── main.tscn          # 主場景（Arena）
│   ├── player.tscn        # 玩家預製件
│   ├── projectile.tscn    # 食物投射物預製件
│   └── enemy.tscn         # 饕客（敵人）預製件
└── scripts/
    ├── main.gd            # 主遊戲邏輯
    ├── food_court.gd      # 美食廣場視覺效果
    ├── player.gd          # 玩家控制
    ├── projectile.gd      # 投射物行為
    └── enemy.gd           # 敵人行為
```

---

## 場景節點樹（main.tscn）

```
Main (Node2D)              ← main.gd
├── Background (ColorRect) ← 深色背景 1280×720
├── FoodCourt (Node2D)     ← food_court.gd，位於 (640,360)
├── Players (Node2D)       ← 玩家容器
├── Enemies (Node2D)       ← 敵人容器
├── Projectiles (Node2D)   ← 投射物容器
└── UI (CanvasLayer)       ← 客訴標籤、Game Over 面板（程式動態建立）
```

---

## 碰撞層設計

| 節點類型         | collision_layer | collision_mask | 說明                         |
|-----------------|-----------------|----------------|------------------------------|
| Player (CharacterBody2D) | 1 | 1 | 玩家互相物理推擠         |
| Enemy  (CharacterBody2D) | 2 | 0 | 僅被 Area2D 偵測，不主動碰撞 |
| Projectile (Area2D)      | 4 | 3 | 偵測 layer 1（玩家）+ layer 2（敵人） |

---

## 輸入對應

| 動作        | P1         | P2         |
|------------|------------|------------|
| 移動上      | W          | I          |
| 移動下      | S          | K          |
| 移動左      | A          | J          |
| 移動右      | D          | L          |
| 射擊        | 滑鼠左鍵   | Space      |
| 瞄準方式    | 滑鼠游標   | 最後移動方向 |

---

## 核心邏輯

### 敵人生成（main.gd）

- 初始每 3 秒生成 1 隻，隨 `wave_count` 遞增縮短間隔
- 最短間隔 0.8 秒
- 從地圖四邊緣（稍超出畫面外）隨機位置生成

### 客訴計數（main.gd）

- `enemy.reach_center` 信號 → `_add_complaint()`
- Label 彈跳縮放動畫（Tween）
- 達 10 次 → `_trigger_game_over()`

### 擊退系統（player.gd + projectile.gd）

- 投射物命中玩家：`apply_knockback(dir, 600.0)`
- `_knockback` 向量透過 `lerp` 衰減（係數 8.0/秒）
- 射擊者有 0.15 秒免疫期，避免自傷

---

## 第二階段擴充建議（尚未實作）

- 波次系統：顯示當前波次，特殊饕客類型
- 音效：夜市環境音、食物命中音、客訴音效
- 動畫：玩家受擊閃爍、敵人消失粒子效果
- 地圖障礙物：桌椅阻擋敵人直線路徑
- 更多食物武器：持續推擠型、範圍爆炸型
