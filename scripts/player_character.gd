extends Resource
class_name PlayerCharacter

# ===================================================
# player_character.gd — 攤位英雄資料
#
# 存放單一角色的武器數值與視覺識別，供 player.gd 在
# _ready() 時讀入。不含輸入來源（見 control_profile.gd）。
# ===================================================

@export var character_name : String = ""

@export_group("外觀")
@export var body_color   : Color  = Color.WHITE
@export var marker_shape : String = "circle"   # "circle" 或 "square"

@export_group("射擊")
@export var shoot_cooldown      : float = 0.30   # 發射間隔（秒，burst 時為 burst 後冷卻）
@export var burst_count         : int   = 1      # 每次發射顆數，1 = 單發
@export var burst_delay         : float = 0.0    # burst 內每發間隔（秒）
@export var proj_radius         : float = 12.0
@export var proj_speed          : float = 400.0
@export var proj_knockback_base : float = 950.0  # 友火擊退力（尚未乘上 ff_knockback_multiplier）
@export var proj_enemy_speed    : float = 420.0
@export var proj_hit_stop       : int   = 2
@export var proj_color          : Color = Color(1.0, 0.92, 0.1)
