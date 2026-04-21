extends Node

# ===================================================
# audio_manager.gd — 程序生成音效系統
#
# 所有音效以 AudioStreamWAV + PCM 方式即時生成，不需外部檔案。
# BGM 以 AudioStreamWAV 循環節拍生成，最後 30 秒自動加速。
#
# 外部呼叫範例：
#   audio_mgr.play(AudioManager.HIT_PLAYER)
#   audio_mgr.set_sprint_mode(true)
# ===================================================

@export_group("Volume")
@export var master_volume : float = 0.85   # ← 總音量（0-1）
@export var sfx_volume    : float = 0.80   # ← 音效音量
@export var bgm_volume    : float = 0.40   # ← 背景音樂音量

@export_group("BGM")
@export var bgm_bpm_normal : float = 120.0  # ← 正常 BPM
@export var bgm_bpm_sprint : float = 160.0  # ← 最後 30 秒 BPM

@export_group("SFX Frequencies")
@export var sfx_hit_player_freq : float = 800.0  # ← 命中玩家：頻率
@export var sfx_hit_player_dur  : float = 0.10   # ← 命中玩家：時長
@export var sfx_hit_enemy_freq  : float = 300.0  # ← 命中敵人：頻率
@export var sfx_hit_enemy_dur   : float = 0.08   # ← 命中敵人：時長
@export var sfx_big_break_f0    : float = 600.0  # ← 大型破防：起始頻率
@export var sfx_big_break_f1    : float = 200.0  # ← 大型破防：結束頻率
@export var sfx_big_break_dur   : float = 0.30   # ← 大型破防：時長
@export var sfx_complaint_freq  : float = 200.0  # ← 客訴+1：頻率
@export var sfx_complaint_dur   : float = 0.15   # ← 客訴+1：時長
@export var sfx_mutation_f0     : float = 400.0  # ← 突變出現：起始頻率
@export var sfx_mutation_f1     : float = 800.0  # ← 突變出現：結束頻率
@export var sfx_mutation_dur    : float = 0.20   # ← 突變出現：時長
@export var sfx_win_note_dur    : float = 0.18   # ← 勝利每音符時長
@export var sfx_lose_note_dur   : float = 0.18   # ← 失敗每音符時長

# ── SFX 名稱常數（外部使用這些字串）──────────────────
const HIT_PLAYER = "hit_player"
const HIT_ENEMY  = "hit_enemy"
const BIG_BREAK  = "big_break"
const COMPLAINT  = "complaint"
const MUTATION   = "mutation"
const WIN        = "win"
const LOSE       = "lose"

const _SAMPLE_RATE = 44100
const _POOL_SIZE   = 8

var _sfx_streams : Dictionary = {}
var _sfx_players : Array      = []
var _sfx_idx     : int        = 0

var _bgm_player    : AudioStreamPlayer
var _bgm_in_sprint : bool = false


func _ready() -> void:
	add_to_group("audio_manager")

	# ── SFX 播放池 ────────────────────────────────────
	for _i in range(_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)

	# ── BGM 播放器 ────────────────────────────────────
	_bgm_player     = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	add_child(_bgm_player)

	# 生成所有音效並啟動 BGM
	_build_sfx()
	_start_bgm(bgm_bpm_normal)


# ── 播放音效（外部呼叫）────────────────────────────────
func play(sfx_name: String) -> void:
	if not _sfx_streams.has(sfx_name):
		return
	var p := _sfx_players[_sfx_idx % _POOL_SIZE] as AudioStreamPlayer
	_sfx_idx += 1
	p.stream    = _sfx_streams[sfx_name]
	p.volume_db = linear_to_db(clampf(sfx_volume * master_volume, 0.001, 1.0))
	p.play()


# ── BGM 衝刺模式（最後 30 秒加速）──────────────────────
func set_sprint_mode(active: bool) -> void:
	if active == _bgm_in_sprint:
		return
	_bgm_in_sprint = active
	_start_bgm(bgm_bpm_sprint if active else bgm_bpm_normal)


# ═══════════════════════════════════════════════════
#  內部：音效生成
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


# ── 單音正弦 ─────────────────────────────────────────
func _make_sine(freq: float, dur: float, vol: float) -> AudioStreamWAV:
	var n   := int(_SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t  := float(i) / float(n)
		buf[i]  = sin(TAU * freq * float(i) / _SAMPLE_RATE) * vol * (1.0 - t)
	return _to_wav(buf)


# ── 掃頻（頻率從 f0 線性掃到 f1）────────────────────────
func _make_sweep(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var n     := int(_SAMPLE_RATE * dur)
	var buf   := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in range(n):
		var t    := float(i) / float(n)
		var freq := lerpf(f0, f1, t)
		var env  := 1.0 - t
		phase    += TAU * freq / _SAMPLE_RATE
		buf[i]    = sin(phase) * vol * env
	return _to_wav(buf)


# ── 旋律（多個音符依序播放，音符間有短暫靜音）──────────
func _make_melody(freqs: Array, note_dur: float, vol: float) -> AudioStreamWAV:
	var gap_dur := 0.04
	var note_n  := int(_SAMPLE_RATE * note_dur)
	var gap_n   := int(_SAMPLE_RATE * gap_dur)
	var buf     := PackedFloat32Array()
	buf.resize((note_n + gap_n) * freqs.size())
	buf.fill(0.0)
	var idx := 0
	for freq in freqs:
		for i in range(note_n):
			var t    := float(i) / float(note_n)
			var env  := sin(PI * t)                # 鐘形包絡，有 attack & decay
			buf[idx]  = sin(TAU * float(freq) * float(i) / _SAMPLE_RATE) * vol * env
			idx      += 1
		idx += gap_n
	return _to_wav(buf)


# ── BGM 節拍循環 ─────────────────────────────────────
func _start_bgm(bpm: float) -> void:
	var stream := _make_bgm(bpm)
	_bgm_player.stream    = stream
	_bgm_player.volume_db = linear_to_db(clampf(bgm_volume * master_volume, 0.001, 1.0))
	_bgm_player.play()


func _make_bgm(bpm: float) -> AudioStreamWAV:
	var beat    := 60.0 / bpm
	var measure := beat * 4.0
	var loop    := measure * 2.0                   # 2 小節循環
	var n       := int(_SAMPLE_RATE * loop)
	var buf     := PackedFloat32Array()
	buf.resize(n)
	buf.fill(0.0)

	# ── Kick：第 1、3 拍 ─────────────────────────────
	for m in range(2):
		for b in [0, 2]:
			var t0    := int((m * measure + b * beat) * _SAMPLE_RATE)
			var kick_n := int(0.20 * _SAMPLE_RATE)
			var ph    := 0.0
			for i in range(kick_n):
				if t0 + i >= n:
					break
				var t    := float(i) / float(kick_n)
				var env  := exp(-t * 16.0)
				var freq := 110.0 * exp(-t * 9.0) + 50.0   # 音調下滑感
				ph      += TAU * freq / _SAMPLE_RATE
				buf[t0 + i] += sin(ph) * env * 0.75

	# ── Hi-hat：每個 8th note ────────────────────────
	for m in range(2):
		for h in range(8):
			var t0    := int((m * measure + h * beat * 0.5) * _SAMPLE_RATE)
			var hat_n := int(0.035 * _SAMPLE_RATE)
			for i in range(hat_n):
				if t0 + i >= n:
					break
				var t   := float(i) / float(hat_n)
				var env := exp(-t * 85.0)
				var s   := sin(TAU * 7200.0  * float(i) / _SAMPLE_RATE) * 0.55
				s       += sin(TAU * 10800.0 * float(i) / _SAMPLE_RATE) * 0.35
				buf[t0 + i] += s * env * 0.28

	# ── Bass pulse：每拍淡入淡出 ─────────────────────
	for m in range(2):
		for b in range(4):
			var t0     := int((m * measure + b * beat) * _SAMPLE_RATE)
			var bass_n := int(beat * 0.65 * _SAMPLE_RATE)
			for i in range(bass_n):
				if t0 + i >= n:
					break
				var t   := float(i) / float(bass_n)
				var env := exp(-t * 5.0)
				buf[t0 + i] += sin(TAU * 100.0 * float(i) / _SAMPLE_RATE) * env * 0.18

	# 正規化至 0.88 峰值，避免破音
	var peak := 0.0
	for s in buf:
		peak = maxf(peak, abs(s))
	if peak > 0.001:
		for i in range(n):
			buf[i] = buf[i] / peak * 0.88

	var wav := _to_wav(buf)
	wav.loop_mode  = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end   = n
	return wav


# ── PCM 打包（PackedFloat32Array → AudioStreamWAV）──
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
	wav.mix_rate = _SAMPLE_RATE
	wav.stereo   = false
	wav.data     = bytes
	return wav
