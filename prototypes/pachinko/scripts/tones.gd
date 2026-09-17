extends RefCounted
class_name Tones

## 程序合成的佔位音。M1 要驗的是**時序**不是音色，所以不下載素材。
##
## 關鍵：探測音必須帶 pitch／音量斜坡。Web 的 Sample 播放模式限制的是執行期參數
## 控制，而混音設計正好押在斜坡上（リーチ 聲音長出來、SP 高潮前抽掉再爆）。
## 單發短音會通過，斜坡才會暴露問題。

const RATE := 22050

## 一段帶頻率與音量斜坡的正弦波。curve > 1 讓斜坡後段更陡。
static func ramp(freq_a: float, freq_b: float, dur: float,
		vol_a: float = 0.5, vol_b: float = 0.5, curve: float = 1.0) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var fade_len := maxf(1.0, 0.006 * RATE)
	for i in n:
		var t := pow(float(i) / float(n), curve)
		phase += TAU * lerpf(freq_a, freq_b, t) / float(RATE)
		# 端點淡入淡出，否則每個音都會有爆音，那會蓋掉我們要聽的時序
		var fade := minf(1.0, minf(float(i), float(n - i)) / fade_len)
		var s := sin(phase) * lerpf(vol_a, vol_b, t) * fade
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wrap(data)

## 短促的噪音衝擊。球撞釘、天體停止用。
static func click(dur: float, vol: float = 0.4, decay: float = 24.0) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260917
	for i in n:
		var t := float(i) / float(RATE)
		var s := rng.randf_range(-1.0, 1.0) * vol * exp(-decay * t)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wrap(data)

## 純靜默。用來在時間軸上佔住「高潮前抽掉聲音」的那半秒，
## 讓靜默本身是一個可被排程與量測的事件，而不是「什麼都沒排」。
static func silence(dur: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(int(dur * RATE) * 2)
	return _wrap(data)

static func _wrap(data: PackedByteArray) -> AudioStreamWAV:
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = data
	return st
