# Godot 能力復用：跨原型實作研究

日期：2026-11-06。這份是原始碼比較與設計決策，不是執行驗收。承接 [盤點](REUSE-AUDIT.md) 與 [現有能力參考](capabilities/REFERENCE.md)。

後續狀態：本文保留研究當時的風險。camera_shake／scene_loader／music 已進行 [P0 來源修正](REFACTOR-P0.md)，尚未執行驗證或同步遊戲副本；存檔等其他項目仍待重構。

## 結論與範圍

值得復用的能力遠超四個模組。更大的收益是把遊戲內已成熟的保護機制回收進既有 kit，並補齊所有權、時間、座標、失敗與持久化契約。單純搬檔或增加更多參數，不能保證自由組合。

本次盤點涵蓋 checkout 中 16 個頂層 Godot 原型；先前清單含 666 支自有 GDScript（含製作工具／測試）、23 組完全相同來源，kit 70 支腳本項目、9 項 CLI。這些是靜態清單數量，**不是 666 支逐行研究或 70 項全部驗收完成**。本報告對下列關鍵路徑作深入比較；完整範圍與尚未深讀的 kit 項目見 [研究覆蓋表](RESEARCH-COVERAGE.md)。不涵蓋外移 repo、全部 git 歷史、第三方套件實作、素材授權重審與 GPU／手機實測。

```text
遊戲規則與內容
  ├─ adapter：道具目錄、獎勵政策、故事指令、平台來源
  ├─ 規則核心：時間累積、抽樣、交易預演、圖結構檢查
  └─ 場景元件：輸入、鏡頭、音訊、特效、載入畫面
                  ↑
      製作工具產生可編輯 scene／Resource／資料
                  ↑
      AI 目錄描述契約、限制、來源與組合配方
```

不新增統一 Entity、全域事件匯流排或萬用 Manager。純運算用小型函式／RefCounted；具有狀態不變量的能力保留完整模組；視覺物件以保存 scene＋Resource 交付。跨模組只交換實際需要的資料。

## 1. 存檔：優先回收驗證與保護政策

來源：kit [atomic_file](../addons/proto_kit/atomic_file.gd)、[save_slots](../addons/proto_kit/save_slots.gd)；seal [save_store](../../seal-meadow/scripts/save_store.gd)、[save_validation](../../seal-meadow/scripts/save_validation.gd)、main 的 `save_game`；taskbar [save_manager](../../taskbar-hero/autoload/save_manager.gd) 的 `save_profile/load_profile`；dreamling [save_repository](../../dreamling-idle/domain/save_repository.gd)；pixel [save_service](../../pixel-monster/domain/save_service.gd) 的儲存／還原路徑；skybound [save_service](../../skybound-blades/domain/save_service.gd)；debt [save_slots](../../debt-commission/scripts/save_slots.gd)、[save_transfer](../../debt-commission/scripts/save_transfer.gd)。

- kit 目前以 JSON Dictionary 與版本判斷為主；儲存前沒有遊戲 payload validator。可解析但無效的主檔可能取代有效備份。`int(version)` 也不是嚴格的 envelope 驗證。
- seal 有版本型別／整數驗證、payload 驗證、較新版本阻擋，以及還原備份後確認原始 bytes 未被其他操作改動的保護。taskbar 同時檢查主檔與備份的 future version，並維持禁止寫入狀態。這些比 kit 更值得回收。
- AtomicFile rename fallback 會先將原檔移至 `.old`；中途終止的恢復不由 `read_bytes()` 處理。單檔替換、備份選擇與跨檔交易是三件事。
- pixel 載入備份會修復主檔；其他版本偏向回報來源，交由上層決定。讀取介面必須明說是否寫磁碟。
- skybound 的死亡 tombstone 防止舊備份復活已結束 run，是遊戲 journal，不能被一般備份政策取代。
- debt 使用二進位 Variant slot；匯入先驗所有檔案，備份後逐檔刪／寫。它是可復原的多檔操作，**不是跨檔原子交易**。

**決策：演進既有 save_slots，底層沿用 AtomicFile。** 抽出 envelope／候選檔案檢查與提交；注入 codec、payload validator、migration。錯誤至少區分 missing、corrupt、future_version、migration_failed、conflict、io_error。檔案選擇、修復與寫入分開，不把 HUD 或遊戲物件帶入。第一個接入選 seal，第二個以 taskbar 的備份政策驗證；debt binary codec 與 skybound journal 保持 adapter。

## 2. 時間：共用步長，不統一所有時鐘

來源：kit [game_clock](../addons/proto_kit/game_clock.gd)、[time_control](../addons/proto_kit/time_control.gd)、[song_clock](../addons/proto_kit/song_clock.gd)、[combo_input](../addons/proto_kit/combo_input.gd)；skybound stepper、dreamling simulation_driver；hero progression 的 `offline_seconds/claim_march/measure_march`；pixel time_service 的離線入口；kagura judge。

| 時間領域 | 使用者 | 契約 |
|---|---|---|
| 模擬時間 | 固定戰鬥、成長 | `delta_seconds`；一個 owner 推進一次；retain/drop 明確 |
| 真實單調時間 | 音效節流、hit stop 恢復 | 不隨遊戲倍速；不可直接用於遊戲冷卻 |
| 歌曲播放時間 | 音遊 | 原生音訊位置／Web anchor 與延遲補償；保留專用 SongClock |
| UTC／離線間隔 | 放置收益、養成 | 倒退、上限、重複領取、日界線政策由遊戲決定 |

fixed_step 已抽出兩種積欠政策，但 skybound 舊版過載清空餘額，新版 drop 保留小數餘額；尚未接入，不稱無差異替換。

hero 前段以 20 Hz 模擬，後段以測得速率估算；`measure_march` 可能改變撤退樓層。pixel 依需求、睡眠與保護邊界處理時間，不能套相同收益估算器。可共用的是時間區間與提交識別，估算模型仍留遊戲。

GameClock 焦點恢復會還原舊 paused 值；TimeControl 會將 time_scale 還原 1。兩者都假設自己掌握對應全域狀態。先明訂單一 owner；真的出現多個暫停來源才增加 token／lease，避免多方覆寫。kagura 的判定窗口可作純資料＋函式，ComboInput 的連段／和弦狀態機繼續獨立。

## 3. 背包、交易與領獎：共用提交邊界

來源：seal [inventory](../../seal-meadow/scripts/inventory.gd)、[shop](../../seal-meadow/scripts/shop.gd)、[refine](../../seal-meadow/scripts/refine.gd)、[quests](../../seal-meadow/scripts/quests.gd)、[collection_book](../../seal-meadow/scripts/collection_book.gd)；hero progression `add_item/equip`；dreamling game_model 的裝備與 pending queue；taskbar inventory_manager；kit upgrade_tree、talent_tiers、run_goals、loot_ledger。

| 原型 | 容量／溢出 | 不能抹平的語義 |
|---|---|---|
| seal | trial bag，全成功才換 slots | 拒絕時不扣錢、不失物；裝備實例 UID |
| hero | 可自動分解成資源 | `add_item == false` 仍可能增加分解資源 |
| dreamling | 裝備不占背包；pending 等待領取 | 已獲得但尚未入袋不等於獲得失敗 |
| taskbar | UID → properties | 沒有 seal 的 stack／capacity 規則 |

seal 的 `load_data` 會丟未知品項、修正 UID；作為通用庫時須改成顯式 migration／diagnostics，不應默默改玩家資料。精煉 receipt 可以拒絕過期序號／回傳上一結果，但不能據此宣稱跨當機的 exactly-once。

**決策：先抽 item identity、stack 操作與交易預演，不做萬用背包 UI。** item catalog 注入；gold／items／裝備變更在同一候選 snapshot 驗證後提交；溢出由遊戲 adapter 回傳 kept／pending／salvaged／rejected。純預演不能消耗 RNG、發 signal 或寫檔。對外事件在提交後發出。

Quest 完成與 reward claimed 分開。kit RunGoals 的 `claimed()` 實際計已完成，snapshot 也未包含 per_run 與 tier；不能直接取代 seal 的 turn-in。UpgradeTree 的圖相鄰解鎖與 TalentTiers 的行數門檻保留兩個模組。TalentTiers restore 的 rank／點數驗證需補齊；LootLedger 是永久收藏，不是有數量的背包，且部分回傳 Dictionary 是內部參照。

## 4. 戰鬥、查詢與事件

來源：kit [auto_caster](../addons/proto_kit/auto_caster.gd)；skybound domain/battle 的 step 主流程；seal combat；survivor-series [grid](../../survivor-series/scripts/grid.gd)。

AutoCaster 產生 hit／heal／DOT 事件，宿主負責套用；heal 依預估傷害產生，未等待宿主確認實際扣血。每次 step 每招至多施放一次，不會完整追趕積欠。`to_dict()` 儲存配點與加成，沒有 timer、buff、DOT、RNG，故是 **build persistence，不是戰鬥 checkpoint**。`learn()` 借用 spell Dictionary，亦須明說不可在外部任意修改。

skybound 先算出同 tick 傷害再統一提交，處理死亡後才獎勵；seal 則即時呼叫 Node 的 take_damage。把三者包進一個 damage API 會改變同時擊殺、吸血與獎勵順序。

**決策：保留戰鬥模型；抽空間查詢與已確認事件的展示配方。** Grid 目前綁 Node2D、actor.definition.radius 與 dead；若抽核心，輸入 stable ID／位置／半徑快照，輸出 ID，alive 與攻擊陣營在 adapter 過濾。尚未確認第二個資料型消費者前不先建立 2D／3D 萬用索引。對同距離結果保留穩定順序；效能優化需測量後再做。

## 5. 輸入、安全區與遮罩

來源：kit floating_stick、tap_picker_3d、orientation_guard；madara touch_stick／touch_button（與 luffy 重複）；seichi move_stick／look_pad；kagura safe_area。

- floating_stick 走 GUI mouse emulation，沒有手指 ID；madara 使用 raw `_input` 與 finger index；seichi 固定式 GUI touch 排除模擬滑鼠，並輸出 y 向前。不能直接互換。
- OrientationGuard 是 GUI 遮罩，並未暫停 scene tree；raw `_input` 仍需宿主停用。按鈕 cooldown 是外觀，不等同輸入禁止。
- TapPicker 的螢幕最近目標沒有遮擋判定；ground raycast 才是物理查詢，二者不可混稱智慧選敵。
- kagura safe_area 已處理 CSS env／native rect 與縮放，適合獨立保存場景。只調整安全區根容器，保留內部布局的可編輯性。

**決策：一個搖桿數學核心＋固定／浮動兩個 scene adapter。** 對外向量統一螢幕 x 右、y 下，前進軸轉換留遊戲。失焦、隱藏、停用、手指取消都須 release 並輸出零；不直接代替遊戲決定 InputMap。先接 luffy／madara，保留 seichi 軸轉換。

## 6. 鏡頭、載入與非同步生命週期

來源：kit camera_shake、shot_camera、scene_loader、scene_router；horde、luffy、seal camera_rig。

| 靜態發現 | 影響 | 重構方向 |
|---|---|---|
| CameraShake 在 scale=0 清 trauma 後提前 return | 中途關閉震動可能留下上一幀 offset／rotation | 清除已施加偏移，保存基準；或改回傳 shake sample，由唯一鏡頭 owner 套用 |
| ShotCamera 用 local `_home`，focus 描述為 world | parent 有 transform 時座標不一致風險 | 明確空間並在邊界轉換 |
| SceneLoader request 覆寫尚未完成的 path | 舊請求失去本地追蹤 | 最簡單先拒絕 busy；只有真的需要取代才加 ticket |
| cancel 實作呼叫 load_threaded_get | 沒有實作取消工作；不能宣稱非阻塞取消 | 分開取消交付與回收結果，延遲行為待執行驗證 |
| SceneRouter 強制 tree.paused=false | 可能覆蓋別人的暫停狀態 | 暫停由單一 owner 控制 |
| SceneRouter 自行同步換場；Tween 未忽略 time_scale | 不等於 threaded loader 整合 | 轉場 owner 常駐 current_scene 之外；顯式選時間 |

horde 跟隨鏡頭分 game_dt／real_dt；luffy 有跟隨、FOV、cutscene borrow/release；seal 是簡單 orbit。共享的是 pose／偏移合成與交還所有權，不能把所有模式塞進 ShotCamera。

上述為原始碼靜態風險，本輪未做失效重現，也沒有修正 runtime。

## 7. 敘事與製作：先拆編譯，不搬整個 StoryRunner

來源：debt [story_builder](../../debt-commission/tools/story_build/story_builder.gd) 的 build_text／fingerprint；[story_runner](../../debt-commission/scripts/story_runner.gd) 的契約、snapshot／restore／normalize；luffy [cutscene](../../luffy-marineford/scripts/cutscene.gd)；pachinko [sequence](../../pachinko/scripts/sequence.gd) 的 beats／roll；erwin main `_direct`。

DM 與 Parley 已有共同 `{entry, nodes}` 邊界，但 builder 還會解決 comedy、investigate／boke blocks、讀取資產 catalog，再用 StoryRunner 驗證。fingerprint 排除文字，包含會改變存檔位置的結構；這個思想可復用，但哪些 opcode 欄位算結構仍須遊戲提供。

StoryRunner 有 128 次內部轉移上限與回滾；restore 先驗證再賦值。snapshot 會準備互動狀態，不能當無副作用 getter。這次只深讀特定路徑，未審完 2,869 行與全部指令。

luffy 的 cutscene 只演出，真正解鎖放在後續 Beat，skip 不跳過遊戲規則。它是很好的組合配方；但 `_over` 不在 start 重置，現有契約更接近每場一次的 instance，不應直接包成可重播播放器。

pachinko beats 是時間標記，連動機台節奏與派彩；erwin pending callbacks 連動刷怪。可共用穩定排序的事件游標，但輸出事件、不執行任意 Callable；進度、seek／skip 是否跳過事件需另訂。尚不值得把三種敘事硬合成框架。

**決策：先於 debt 內拆出 graph 檢查、格式轉換與遊戲指令 schema。** 兩個輸入格式證明轉換 seam 有價值，並不等於已有第二款遊戲採用通用 StoryRunner。先維持既有 JSON 兼容；第二個遊戲需要時再提升 runtime 部分進 kit。

## 8. 特效、Sprite 與渲染資源

來源：luffy [glow_pool](../../luffy-marineford/scripts/glow_pool.gd)；kit sprite3d_sheet；vfx/3d/00gamedevs source_effect 的前段生命週期、weapon_smear、impact_frame。

GlowPool 是每幀提交的批次 buffer，不是持續存在的特效物件池。它以 20 float stride 送出 transform/color/custom，超量靜默丟棄，commit 後清計數。抽取單位應含 MultiMesh、shader include、blend material 與 scene；輸入座標必須明訂。加 dropped_count 比先做通用 pooling framework 更有用。

Sprite3DSheet 已是好的 Resource 邊界：camera-relative 方向、每 actor 的 hysteresis、60 Hz tick、atlas 格、shader custom data 編碼集中。須補非法 grid／cell_px／frame 資料的驗證與 borrowed Dictionary 說明，不能只列方法名。其 alpha 承載 outline role，不是一般透明度。

現有 VFX 不該拆成一堆沒有編輯器預覽的小函式。source_effect 的 beam endpoints 是 parent space，hit 是 world space；weapon_smear 取 weapon local base/tip 轉世界後採樣；impact_frame 接 top-left normalized UV。這些差異應在目錄逐參數記錄，不能用一句「支援座標」帶過。

停止也是不同契約：source_effect burst 的 stop 不做事；trail stop 排空歷史；impact_frame reset 立即清畫面，trigger busy 回 false。pool recycle 必須按各效果的完成事件處理。材質是否 scene-local 必須隨場景驗證，光讀腳本不足以判定多 instance 隔離；本輪沒有重新驗證 46 個效果。

## 9. 音訊、裝置與商店 adapter

來源：kit music、sfx_bank、haptics、store_front；pixel [step_provider](../../pixel-monster/domain/step_provider.gd)、mock_step_provider 的前段。

- Music 的交叉淡出已有 voice reuse 與舊 Tween 中止，但 `_looped` 直接修改傳入 AudioStream 的 loop 設定。須決定複製資源或契約明訂移交修改權，避免同一 stream 被節奏播放重用時互相影響。
- SfxBank `played` 表示呼叫，不代表真的發聲；音效缺失與節流仍發出。fallback 遞迴沒有 cycle guard，應在設定入口驗證。聲音節流使用真實時間合理，不要移植到遊戲冷卻。
- Haptics 應明說 unsupported 與 emitted 不等於裝置確實震動，tier 與 pattern 需驗證。
- StoreFront 是測試 backend，不能列為真實付款能力。測試檔寫入結果目前未傳遞；`buy -> bool` 不足以表達 pending／cancelled／receipt。廣告 timer 使用 process_always=true，與註解「暫停不計時」不一致，列待確認契約。若接真實平台再建立 receipt／grant 邊界，不能由 UI 的成功旗標直接當驗證結果。
- StepProvider 已明確回傳 available／historical／background、coverage known／complete、today_steps=null；未知不偽裝成零是值得全庫採納的資料規範。現有 native base 回 unavailable，mock 才有模式；不可宣稱已有原生步數整合。

## 10. 名稱相同不一定該共用：釣魚

來源：seal [fishing](../../seal-meadow/scripts/fishing.gd) 全檔與 star-tide [fishing](../../star-tide-harbor/scripts/fishing.gd) 前 180 行。

seal 是 foreground-only 五秒活動，完成時 trial bag 同時扣餌／加獎勵，取消不扣餌；active 先歸 false 防止重複結算。star-tide 有 AIM／CAST／LURE／FIGHT／STRUGGLE／RESULT／FAILED，張力、收放線、連點與輔助操作均綁 scene。兩者共有「開始／取消／完成」不夠支持通用 FishingEngine。前者可採交易核心，後者保留可編輯玩法場景與調校 Resource。

## 11. 工具、目錄與版本管理

來源：kit sync.sh、tools/capabilities.py 的 API／inventory 掃描路徑、scene_builder 的既有所有權契約；逐項工具入口見 catalog/tools.json。

sync.sh 是整包 `rsync --delete`，不是選擇性安裝。capabilities plan 只追靜態引用，不涵蓋動態 load 路徑、所有材質與平台依賴；不能拿它當完整 package closure。產生的 API 宣告／uniform 清單仍需人工語義，不等於可供 AI 安全自由組合的完整 schema。

先增加每項能力的具體契約，再考慮安裝器：時間單位、座標空間、owner、RNG 消耗、copy/borrow、失敗是否變更狀態、snapshot 範圍、必要 scene、平台與副作用。維持 human specs 為來源，不直接修生成文件。工具資料另記 cwd、會寫哪些檔、覆寫政策、exit code、外部依賴。SceneBuilder.save_scene 接手釋放 root 的規則必須顯著標示。

CLI、展示、runtime 三種入口分別標記；不要把 gallery／demo 算成可直接呼叫的遊戲能力。舊副本先用既有 audit_copies／sync --check 讀差異，遷移一款才同步一款。

## 下一輪重構順序

| 次序 | 具體交付 | 第一／第二來源 | 完成邊界 |
|---|---|---|---|
| P0 | 校正現有能力契約與明確錯誤：save、camera、loader、audio | 既有 kit＋上述原型證據 | 不改名稱掩蓋行為；保留相容 wrapper 或註明破壞性變更 |
| P1 | validated snapshot store | seal／taskbar | 主備份 future-version、invalid payload、讀寫分離；不包含 journal |
| P1 | touch vector／release＋兩種可編輯搖桿 scene | luffy／madara；seichi 軸轉換 | 輸入阻擋、指標 owner、失焦取消；不批次換 UI |
| P1 | glow batch scene＋shader/material | luffy／madara | 明確座標、overflow、每幀 commit、資源隔離 |
| P2 | inventory trial／commit 與 receipt 邊界 | seal／dreamling，再評估 hero | gold/items 同步提交；pending／salvage 留 adapter |
| P2 | debt 編譯 seam；暫留遊戲內 | DM／Parley | 純 graph 診斷與遊戲 opcode schema 分開；維持存檔 fingerprint |
| P2 | safe-area scene 與已確認事件展示配方 | kagura／新手機消費者 | editor layout 保留；聲音／震動／VFX 不反向決定玩法 |
| 暫留 | full combat、離線收益、釣魚、任務、步數平台、真實付款 | 各遊戲 | 只抽已證實共用的邊界，不先造框架 |

研究文件屬「規劃」層，不執行測試。使用者延期的新重構測試仍延期；沒有把舊 PASS 當作本輪證據。下一輪若恢復驗證，先處理已改 weighted_choice 的消費者，再按實際改動做最小 L1/L2；完整 L3 仍待使用者手動驗收之後。
