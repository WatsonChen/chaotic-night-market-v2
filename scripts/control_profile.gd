extends Resource
class_name ControlProfile

# ===================================================
# control_profile.gd — 玩家輸入來源設定
#
# 輕量版控制抽象：只描述「這個玩家從哪裡讀輸入」，
# 不處理網路輸入、動態加入玩家、房間配對。
#
# 鍵盤：靠 action_prefix 對應 project.godot 裡的
#       <prefix>up / <prefix>down / <prefix>left / <prefix>right
# 手把：InputMap action 不分裝置，因此手把改用
#       Input.get_joy_axis(device_id, ...) 直接依 device_id 讀值，
#       讓兩支手把可以各自綁定不同玩家。
# ===================================================

enum DeviceType { KEYBOARD, GAMEPAD }

@export var device_type : DeviceType = DeviceType.KEYBOARD

@export_group("鍵盤")
@export var action_prefix : String = "p1_"

@export_group("手把")
@export var device_id : int   = 0
@export var deadzone  : float = 0.35
