extends RefCounted
class_name Spec

## 機台規格常數。對應 README.md 的〈機台規格〉〈狀態與終局〉〈節奏〉三節。
## README 是規格的單一事實來源；這裡是它的可執行副本。改一邊就要改另一邊。

# --- 旋鈕 ---------------------------------------------------------------
# ADR 0002：機率與球數是開發旋鈕，不是設計值。
# 用 `godot --path . -- --design` 切設計值，不必改原始碼。畫面上會印出當前旋鈕——
# 驗收若不小心跑在 1/99 上，測出來的「等待值不值得」整個作廢，而那從畫面上看不出來。
static var use_dev_knob := true

# --- 抽選 ---------------------------------------------------------------
const JACKPOT_NORMAL_DESIGN := 1.0 / 319.0
const JACKPOT_NORMAL_DEV := 1.0 / 99.0
const KAKUHEN_MULTIPLIER := 10.0          # 確變中大當率 = 通常 × 10
const KAKUHEN_ENTRY_RATE := 0.65          # 每次大當後都擲，含初回
const REACH_PASSED_RATE := 0.125          # 經過リーチ 1/8，含之後升級成 SP 的那些
const SP_RELIABILITY := 0.25              # ADR 0005

# --- 球數經濟 -----------------------------------------------------------
const BANK_DESIGN := 3000
const BANK_DEV := 1000
const START_POCKET_AWARD := 3             # 實體入賞即給，保留滿也給
const PENDING_MAX := 4
const START_RATE_STANDARD := 12.0         # 通常・左打，發/轉（釘調整範圍 10–16）
const START_RATE_SWEET := 10.0
const START_RATE_HARSH := 16.0
const START_RATE_KAKUHEN := 4.0           # 確變・右打，電チュー，不受釘調整影響
const PAYOUT_GROSS_10R := 450             # 總出玉，不是淨增加
const PAYOUT_GROSS_5R := 250

# --- 節奏（秒）---------------------------------------------------------
const FIRE_INTERVAL := 0.4                # ADR 0008：場次長度的旋鈕
const T_SPIN_NORMAL := 3.0                # 直接落空
const T_REACH := 2.0                      # リーチ 段
const T_NORMAL_TAIL := 1.0                # ノーマル止まり 的收尾
const T_ESCALATION_WINDOW := 1.5          # 升級窗口
const T_TAKEOVER := 11.0                  # 黑洞接管
const T_PRE_CLIMAX_SILENCE := 0.5         # 高潮前把聲音整個抽掉
const T_RESOLVE := 1.5                    # 決著：兩條 SP 路徑分岔（連珠起手／軌道崩解）
const T_SYZYGY := 2.0                     # 三星連珠，只有大當才有
const T_SPIN_KAKUHEN := 1.5               # 確變高速變動（敏感參數，見 README）
const T_PAYOUT_10R := 25.0
const T_PAYOUT_5R := 14.0

# 三條演出路徑的總長（README〈節奏〉表）
const T_PATH_STRAIGHT_MISS := T_SPIN_NORMAL                                  # 3.0
const T_PATH_NORMAL_STOP := T_SPIN_NORMAL + T_REACH + T_NORMAL_TAIL          # 6.0
const T_PATH_SP := T_SPIN_NORMAL + T_REACH + T_TAKEOVER + T_PRE_CLIMAX_SILENCE + T_RESOLVE  # 18.0

## SP 總長的硬上限：保留上限 × 通常時球間隔。超過就會在每一次 SP 系統性溢出。
static func sp_length_ceiling() -> float:
	return PENDING_MAX * START_RATE_STANDARD * FIRE_INTERVAL  # 19.2 秒

# --- 版面 ---------------------------------------------------------------
const VIEWPORT := Vector2(1080.0, 1920.0)
const MACHINE_ASPECT := 2.0 / 3.0         # 機台照實物 2:3 置中
const LCD_COVERAGE := 0.68                # 液晶佔盤面 65–70%

# --- 導出量 -------------------------------------------------------------

static func jackpot_normal() -> float:
	return JACKPOT_NORMAL_DEV if use_dev_knob else JACKPOT_NORMAL_DESIGN

static func jackpot_kakuhen() -> float:
	return jackpot_normal() * KAKUHEN_MULTIPLIER

static func bank() -> int:
	return BANK_DEV if use_dev_knob else BANK_DESIGN

## 給畫面用的一行摘要。驗收跑錯旋鈕從此看得見。
static func knob_label() -> String:
	return "KNOB: %s  1/%d  bank %d  SP every %.1f spins" % [
		"DEV" if use_dev_knob else "DESIGN",
		roundi(1.0 / jackpot_normal()), bank(), 1.0 / sp_rate()]

## SP 出現率由大當率導出，不是自由參數（ADR 0005）。
static func sp_rate() -> float:
	return jackpot_normal() / SP_RELIABILITY

## 四個互斥終點的機率。加總必為 1。
## 回傳 { straight_miss, normal_stop, sp_miss, sp_hit }
static func path_weights() -> Dictionary:
	var hit := jackpot_normal()
	var sp := sp_rate()
	return {
		"straight_miss": 1.0 - REACH_PASSED_RATE,
		"normal_stop": REACH_PASSED_RATE - sp,
		"sp_miss": sp - hit,
		"sp_hit": hit,
	}
