extends Node

# ===================================================
# audio_manager.gd — 音效 + 適應性 BGM
#
# ── BGM 階段（依客訴數自動切換）─────────────────────
#   Phase 1  客訴 0–3   BPM 100，只有底鼓
#   Phase 2  客訴 4–7   BPM 130，加入小鼓（snare）
#   Phase 3  客訴 8–10  BPM 160，加入 hi-hat
#   Phase 4  最後 30 秒  密集 16th notes + stab
#
# ── 切換方式 ─────────────────────────────────────────
#   audio_mgr.update_complaints(count)   ← 每次客訴變化呼叫
#   audio_mgr.set_sprint_mode(true)      ← 最後 30 秒觸發 Phase 4
#
# ── 可調整 BPM（export var）─────────────────────────
#   bpm_phase_1   客訴 0–3   ← 目前 100
#   bpm_phase_2   客訴 4–7   ← 目前 130
#   bpm_phase_3   客訴 8–10  ← 目前 160
#   bpm_final     Phase 4    ← 目前 160
#   bgm_transition 淡入淡出秒數 ← 目前 1.0
# ===================================================

@export_group("Volume")
@export var master_volume : float = 0.85   # ← 總音量（0–1）
@export var sfx_volume    : float = 0.80   # ← 音效音量
@export var bgm_volume    : float = 0.40   # ← 背景音樂音量

@export_group("BGM BPM")
@export var bpm_phase_1    : float = 100.0  # ← 客訴 0–3
@export var bpm_phase_2    : float = 130.0  # ← 客訴 4–7
@export var bpm_phase_3    : float = 160.0  # ← 客訴 8–10
@export var bpm_final      : float = 160.0  # ← 最後 30 秒
@export var bgm_transition : float = 1.0    # ← BPM / 音量淡入淡出（秒）

@export_group("SFX Frequencies")
@export var sfx_hit_player_freq : float = 800.0
@export var sfx_hit_player_dur  : float = 0.10
@export var sfx_hit_enemy_freq  : float = 300.0
@export var sfx_hit_enemy_dur   : float = 0.08
@export var sfx_big_break_f0    : float = 600.0
@export var sfx_big_break_f1    : float = 200.0
@export var sfx_big_break_dur   : float = 0.30
@export var sfx_complaint_freq  : float = 200.0
@export var sfx_complaint_dur   : float = 0.15
@export var sfx_mutation_f0     : float = 400.0
@export var sfx_mutation_f1     : float = 800.0
@export var sfx_mutation_dur    : float = 0.20
@export var sfx_win_note_dur    : float = 0.18
@export var sfx_lose_note_dur   : float = 0.18

# ── SFX 名稱常數 ──────────────────────────────────
const HIT_PLAYER = "hit_player"
const HIT_ENEMY  = "hit_enemy"
const BIG_BREAK  = "big_break"
const COMPLAINT  = "complaint"
const MUTATION   = "mutation"
const WIN        = "win"
const LOSE       = "lose"

const _SR        = 44100   # 取樣率
const _POOL_SIZE = 8

# ── Phase 閾值（鏡像 main.gd 的 stage 設定）──────
const _PHASE2_AT = 4
const _PHASE3_AT = 8

# ── SFX ──────────────────────────────────────────
var _sfx_streams : Dictionary = {}
var _sfx_players : Array      = []
var _sfx_idx     : int        = 0

# ── BGM 即時節拍器狀態 ────────────────────────────
var _bpm         : float = 100.0   # 當前（平滑插值）BPM
var _bpm_target  : float = 100.0
var _bgm_phase   : int   = 1       # 1 / 2 / 3 / 4
var _beat_acc    : float = 0.0     # 距下一個 16th note 的累積時間
var _step        : int   = 0       # 0–15

# ── 音量層（0.0–1.0，由 Tween 平滑控制）─────────
var _vol_snare   : float = 0.0
var _vol_hat     : float = 0.0
var _vol_extra   : float = 0.0

# ── BGM AudioStreamPlayer ─────────────────────────
var _bgm_kick  : AudioStreamPlayer
var _bgm_snare : AudioStreamPlayer
var _bgm_hat   : AudioStreamPlayer
var _bgm_extra : AudioStreamPlayer   # Phase 4 tension stab


func _ready() -> void:
	add_to_group("audio_manager")

	# ── SFX 播放池 ────────────────────────────────
	for _i in range(_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)

	# ── BGM 鼓組 ──────────────────────────────────
	_bgm_kick  = _mk_bgm_player(_gen_kick())
	_bgm_snare = _mk_bgm_player(_gen_snare())
	_bgm_hat   = _mk_bgm_player(_gen_hat())
	_bgm_extra = _mk_bgm_player(_gen_stab())

	# ── 生成 SFX ──────────────────────────────────
	_build_sfx()

	_bpm        = bpm_phase_1
	_bpm_target = bpm_phase_1


func _process(delta: float) -> void:
	if Engine.time_scale == 0.0:
		return   # hit stop 中暫停節拍器

	# ── BPM 平滑插值 ──────────────────────────────
	if abs(_bpm - _bpm_target) > 0.05:
		_bpm = move_toward(_bpm, _bpm_target,
			abs(_bpm_target - _bpm) / max(bgm_transition, 0.01) * delta)

	# ── 節拍器 ─────────────────────────────────────
	var sixteenth := 60.0 / (_bpm * 4.0)
	_beat_acc += delta
	while _beat_acc >= sixteenth:
		_beat_acc -= sixteenth
		_bgm_tick(_step)
		_step = (_step + 1) % 16


func _bgm_tick(s: int) -> void:
	var base_vol := bgm_volume * master_volume

	# ── Kick：拍 1, 3（step 0, 8）──────────────────
	if s == 0 or s == 8:
		_bgm_play(_bgm_kick, base_vol)

	# ── Phase 4 附點踢鼓（step 10）─────────────────
	if _bgm_phase >= 4 and _vol_extra > 0.01 and s == 10:
		_bgm_play(_bgm_kick, base_vol * 0.42)

	# ── Snare：拍 2, 4（step 4, 12）────────────────
	if (s == 4 or s == 12) and _vol_snare > 0.01:
		_bgm_play(_bgm_snare, base_vol * _vol_snare * 0.88)

	# ── Hi-hat：8th notes（偶數 step）──────────────
	if s % 2 == 0 and _vol_hat > 0.01:
		_bgm_play(_bgm_hat, base_vol * _vol_hat * 0.65)

	# ── Phase 4：16th off-beat hat + tension stab ──
	if _bgm_phase >= 4 and _vol_extra > 0.01:
		if s % 2 == 1:
			_bgm_play(_bgm_hat, base_vol * _vol_extra * 0.34)
		if s == 6 or s == 14:
			_bgm_play(_bgm_extra, base_vol * _vol_extra * 0.90)


func _bgm_play(player: AudioStreamPlayer, vol_linear: float) -> void:
	player.volume_db = linear_to_db(maxf(vol_linear, 0.0001))
	player.play()


# ── 外部 API ─────────────────────────────────────

## 每次客訴數變化時呼叫（main.gd 的 _set_complaint_count 觸發）
func update_complaints(count: int) -> void:
	var target := 1
	if   count >= _PHASE3_AT: target = 3
	elif count >= _PHASE2_AT: target = 2
	if target > _bgm_phase:
		_bgm_set_phase(target)


## 播放一次性音效
func play(sfx_name: String) -> void:
	if not _sfx_streams.has(sfx_name):
		return
	var p := _sfx_players[_sfx_idx % _POOL_SIZE] as AudioStreamPlayer
	_sfx_idx += 1
	p.stream    = _sfx_streams[sfx_name]
	p.volume_db = linear_to_db(clampf(sfx_volume * master_volume, 0.001, 1.0))
	p.play()


## 最後 30 秒進入高壓衝刺模式（Phase 4）
func set_sprint_mode(active: bool) -> void:
	if active:
		_bgm_set_phase(4)


# ── Phase 切換 ────────────────────────────────────

func _bgm_set_phase(new_phase: int) -> void:
	if _bgm_phase == new_phase:
		return
	_bgm_phase = new_phase

	match new_phase:
		1:
			_bpm_target = bpm_phase_1
			_tween_vols(0.0, 0.0, 0.0)
		2:
			_bpm_target = bpm_phase_2
			_tween_vols(1.0, 0.0, 0.0)
		3:
			_bpm_target = bpm_phase_3
			_tween_vols(1.0, 1.0, 0.0)
		4:
			_bpm_target = bpm_final
			_tween_vols(1.0, 1.0, 1.0)


func _tween_vols(snare: float, hat: float, extra: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_vol_snare", snare, bgm_transition)
	tw.tween_property(self, "_vol_hat",   hat,   bgm_transition)
	tw.tween_property(self, "_vol_extra", extra, bgm_transition)


# ═══════════════════════════════════════════════════
#  BGM 鼓組合成
# ═══════════════════════════════════════════════════

func _mk_bgm_player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p       := AudioStreamPlayer.new()
	p.stream    = stream
	p.volume_db = -80.0   # 初始靜音，由 _bgm_play 動態設定
	p.bus       = "Master"
	add_child(p)
	return p


func _gen_kick() -> AudioStreamWAV:
	# 低頻正弦 + 音高快速下滑 → 踢鼓感
	var n    := int(_SR * 0.22)
	var buf  := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t     := float(i) / float(_SR)
		var env   := exp(-t * 16.0)
		var freq  := 55.0 + 110.0 * exp(-t * 32.0)
		buf[i]     = sin(TAU * freq * t) * env * 0.90
	return _to_wav(buf)


func _gen_snare() -> AudioStreamWAV:
	# 偽隨機 noise（多頻正弦乘積）+ 中頻底音
	var n   := int(_SR * 0.14)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t     := float(i) / float(_SR)
		var env   := exp(-t * 22.0)
		var noise := sin(float(i) * 1.9271) * sin(float(i) * 3.7193) * sin(float(i) * 7.3317)
		var tone  := sin(TAU * 185.0 * t) * 0.28
		buf[i]     = clampf((noise * 0.72 + tone) * env * 0.68, -1.0, 1.0)
	return _to_wav(buf)


func _gen_hat() -> AudioStreamWAV:
	# 高頻 noise 極短衰減 → 清脆嗒聲
	var n   := int(_SR * 0.04)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t     := float(i) / float(_SR)
		var env   := exp(-t * 90.0)
		var noise := sin(float(i) * 13.719) * sin(float(i) * 17.381) * sin(float(i) * 23.147)
		buf[i]     = clampf(noise * env * 0.42, -1.0, 1.0)
	return _to_wav(buf)


func _gen_stab() -> AudioStreamWAV:
	# 短促雙頻 stab，Phase 4 緊張感
	var n   := int(_SR * 0.07)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t   := float(i) / float(_SR)
		var env := exp(-t * 55.0)
		buf[i]   = (sin(TAU * 440.0 * t) + sin(TAU * 587.0 * t) * 0.6) * env * 0.32
	return _to_wav(buf)


# ═══════════════════════════════════════════════════
#  SFX 合成
# ═══════════════════════════════════════════════════

func _build_sfx() -> void:
	_sfx_streams[HIT_PLAYER] = _make_sine(sfx_hit_player_freq, sfx_hit_player_dur, 0.65)
	_sfx_streams[HIT_ENEMY]  = _make_sine(sfx_hit_enemy_freq,  sfx_hit_enemy_dur,  0.50)
	_sfx_streams[BIG_BREAK]  = _make_sweep(sfx_big_break_f0, sfx_big_break_f1,
	                                        sfx_big_break_dur, 0.75)
	_sfx_streams[COMPLAINT]  = _make_sine(sfx_complaint_freq, sfx_complaint_dur, 0.60)
	_sfx_streams[MUTATION]   = _make_sweep(sfx_mutation_f0, sfx_mutation_f1,
	                                        sfx_mutation_dur, 0.60)
	_sfx_streams[WIN]        = _make_melody([400.0, 600.0, 800.0], sfx_win_note_dur,  0.70)
	_sfx_streams[LOSE]       = _make_melody([600.0, 400.0, 200.0], sfx_lose_note_dur, 0.70)


func _make_sine(freq: float, dur: float, vol: float) -> AudioStreamWAV:
	var n   := int(_SR * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t  := float(i) / float(n)
		buf[i]  = sin(TAU * freq * float(i) / _SR) * vol * (1.0 - t)
	return _to_wav(buf)


func _make_sweep(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var n     := int(_SR * dur)
	var buf   := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in range(n):
		var t    := float(i) / float(n)
		var freq := lerpf(f0, f1, t)
		var env  := 1.0 - t
		phase    += TAU * freq / _SR
		buf[i]    = sin(phase) * vol * env
	return _to_wav(buf)


func _make_melody(freqs: Array, note_dur: float, vol: float) -> AudioStreamWAV:
	var gap_dur := 0.04
	var note_n  := int(_SR * note_dur)
	var gap_n   := int(_SR * gap_dur)
	var buf     := PackedFloat32Array()
	buf.resize((note_n + gap_n) * freqs.size())
	buf.fill(0.0)
	var idx := 0
	for freq in freqs:
		for i in range(note_n):
			var t    := float(i) / float(note_n)
			var env  := sin(PI * t)
			buf[idx]  = sin(TAU * float(freq) * float(i) / _SR) * vol * env
			idx      += 1
		idx += gap_n
	return _to_wav(buf)


# ── PCM 打包 ──────────────────────────────────────
func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var n     := buf.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in range(n):
		var s := clampi(int(buf[i] * 32767.0), -32768, 32767)
		bytes[i * 2]     = s & 0xFF
		bytes[i * 2 + 1] = (s >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format   = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = _SR
	wav.stereo   = false
	wav.data     = bytes
	return wav
