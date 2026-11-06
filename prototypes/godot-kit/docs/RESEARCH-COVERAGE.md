# 研究覆蓋表（2026-11-06）

這張表把「建立目錄」、「讀過關鍵實作」與「驗收」分開。用途是避免未來 AI 把檔頭／靜態引用當作完整研究。結論見 [跨原型研究](REUSE-RESEARCH.md)。

## Kit 全部 70 項的讀取深度

- **實作研究**：本次讀取下列指定範圍，只有寫「全文」才代表全檔。
- **前階段**：已實作／比較的部分，沒有重跑延期測試。
- **清單盤點**：已有用途、API、引用與範例；本次尚未完成實作深讀。
- 所有項目本輪均無新的 runtime／平台／視覺驗收。

| ID | 研究層級 | 範圍／後續 |
|---|---|---|
| `atomic_file` | 實作研究 | 全文；替換／失敗還原與 read 不恢復 .old |
| `auto_caster` | 實作研究 | step、learn、snapshot、選敵與 DOT；build persistence 邊界 |
| `camera_shake` | 實作研究 | 全文；關閉震動的 offset 清理 |
| `camera_shot` | 實作研究 | 第二批全文；語義與限制已回填 catalog/specs.json，見 KIT-RESEARCH-02.md |
| `card_draft` | 實作研究 | 第二批全文；語義與限制已回填 catalog/specs.json，見 KIT-RESEARCH-02.md |
| `chest_shop` | 前階段 | 前階段 weighted_choice 遷移；非本輪全檔深讀 |
| `combo_input` | 實作研究 | start／input／step 等核心路徑；未逐項驗所有設定 |
| `floating_stick` | 實作研究 | 全文；GUI mouse emulation 與 release |
| `font_check` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `gacha` | 實作研究 | 第二批全文；語義與限制已回填 catalog/specs.json，見 KIT-RESEARCH-02.md |
| `game_clock` | 實作研究 | 全文；焦點／暫停所有權 |
| `haptics` | 實作研究 | clock／rate limit／平台支持與 tier 入口；選讀 |
| `hd2d_demo` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `hd2d_gallery` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `hd2d_look` | 實作研究 | 第二批全文；語義與限制已回填 catalog/specs.json，見 KIT-RESEARCH-02.md |
| `hd2d_stage` | 實作研究 | 第二批全文；語義與限制已回填 catalog/specs.json，見 KIT-RESEARCH-02.md |
| `loot_ledger` | 實作研究 | 全文；收藏、掉落、裝備與 borrowed result |
| `march_strip` | 實作研究 | 第二批全文；語義與限制已回填 catalog/specs.json，見 KIT-RESEARCH-02.md |
| `music` | 實作研究 | 全文；voice／Tween／stream loop 修改 |
| `nine_slice` | 實作研究 | 第二批全文；語義與限制已回填 catalog/specs.json，見 KIT-RESEARCH-02.md |
| `orientation_guard` | 實作研究 | 全文；遮罩與 pause 邊界 |
| `pet_care` | 實作研究 | 第二批全文；語義與限制已回填 catalog/specs.json，見 KIT-RESEARCH-02.md |
| `pixel_card3d` | 實作研究 | 第二批全文；語義與限制已回填 catalog/specs.json，見 KIT-RESEARCH-02.md |
| `pixel_vfx` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `pixel_vfx3d` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `rarity` | 前階段 | 前階段 weighted_choice 遷移；非本輪全檔深讀 |
| `refine_ladder` | 前階段 | 前階段 weighted_choice 遷移；非本輪全檔深讀 |
| `run_goals` | 實作研究 | 全文；完成／claimed 與 snapshot 範圍 |
| `run_timeline` | 前階段 | 前階段 weighted_choice 遷移；非本輪全檔深讀 |
| `save_slots` | 實作研究 | 全文；備份輪替／版本／migration |
| `scene_builder` | 前階段 | 前階段讀取 save_scene 所有權；本輪未重審全檔 |
| `scene_loader` | 實作研究 | 全文；request／step／cancel |
| `scene_router` | 實作研究 | go 與轉場主要路徑 |
| `screenshot` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `sfx_bank` | 實作研究 | 全文；fallback／節流／signal／voice reuse |
| `shot_camera` | 實作研究 | home／play／peak transform 與釋放路徑 |
| `song_clock` | 實作研究 | 播放／注入時鐘／native-Web 分支／單調值；選讀 |
| `sprite3d_actor` | 實作研究 | 第二批全文；語義與限制已回填 catalog/specs.json，見 KIT-RESEARCH-02.md |
| `sprite3d_gallery` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `sprite3d_sheet` | 實作研究 | 全文；方向／frame／shader 編碼／JSON |
| `sprite_check` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `sprite_inspector` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `sprite_inspector_atlas` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `sprite_inspector_frame` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `store_front` | 實作研究 | 全文；mock backend／await／寫檔／timer |
| `synth` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `talent_tiers` | 實作研究 | 購買、門檻、loadout、restore；選讀 |
| `tap_picker_3d` | 實作研究 | 全文；screen nearest 與 ground raycast |
| `test_kit` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `time_control` | 實作研究 | 全文；全域 time_scale 所有權 |
| `ui.ui_theme` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `upgrade_tree` | 實作研究 | 全文；cost／gate／restore |
| `vfx.2d.sheet_effect` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `vfx.3d.00gamedevs.impact_demo` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `vfx.3d.00gamedevs.impact_frame` | 實作研究 | 全文；trigger／reset／step／UV |
| `vfx.3d.00gamedevs.source_effect` | 實作研究 | 前 150 行；生命週期、方向、endpoints、hit；其餘方程未重審 |
| `vfx.3d.00gamedevs.spell_indicator` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `vfx.3d.00gamedevs.trail_demo` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `vfx.3d.00gamedevs.weapon_smear` | 實作研究 | 前 160 行；attach／drain／採樣／mesh rebuild |
| `vfx.3d.pixel_burst` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `vfx.3d.sheet_effect` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `vfx.gallery` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `vfx.library` | 實作研究 | 載入結構／兩個查詢方法；metadata 僅選讀，未逐筆審素材 |
| `vfx.preview_2d` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `vfx.preview_3d` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `vfx.sheet_frames` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `vfx_gallery` | 實作研究 | 第三批全文；限制回填 specs，見 KIT-RESEARCH-03.md |
| `damage_numbers_3d` | 前階段 | 前階段已抽取與局部驗證；本輪未新增驗證 |
| `fixed_step` | 前階段 | 前階段已抽取；本輪比較來源的積欠政策 |
| `weighted_choice` | 前階段 | 前階段已實作，後段測試延期 |

累計實作研究 62 項（含選讀）；前階段 8 項；已沒有僅清單盤點的 kit 腳本項目。這不表示每個資源／原型／CLI 都已完整審查。項目含 demo／gallery／internal，不等於同數量的獨立遊戲功能。

## 16 原型的實作研究邊界

| 原型 | 已讀實作／重點 | 尚未覆蓋的代表範圍 |
|---|---|---|
| debt-commission | save_slots／save_transfer；story_builder build_text／fingerprint；StoryRunner 契約、snapshot／restore／normalize | StoryRunner 全部指令與 validator、整套編輯器、所有演出場景 |
| dreamling-idle | simulation_driver；save_repository 儲存與載入；game_model 裝備／容量／pending | 完整 model、戰鬥／進度／展示與 UI |
| erwin-run | main._direct 的刷怪與 pending callbacks；共用採用清單 | 主流程其他路徑、角色／Boss／結尾全部實作 |
| hero-horde-idle | progression 的離線計算、measure_march、add_item／equip | 完整 96 支來源、所有商店／抽卡／UI／HD2D 場景 |
| horde-25d | camera_rig；前階段傷害數字重複來源 | 完整敵群／MultiMesh 提交與 GPU 狀態 |
| kagura-dango | judge、safe_area；chart_timeline 前段映射與互動；kit song_clock | 所有回合與完整 chart editor |
| luffy-marineford | cutscene、glow_pool；camera_rig 前段；與 madara 重複輸入來源 | route／Beat 全流程、全部技能與場景 |
| madara-survivor | touch_stick／touch_button；前階段 damage_numbers 比較 | jutsu、所有敵人／技能／升級 |
| pachinko | sequence.beats／roll；kit synth 採用清單 | 全部盤面物理、賠率推導、stress 路徑 |
| pixel-monster | save_service 儲存／還原；time_service 離線入口；StepProvider 全文與 mock 前段 | 完整 steps 去重／結算、原生裝置 bridge、進化與戰鬥 |
| seal-meadow | save_store／validation、main save_game；inventory／shop／refine／quests／collection_book／combat／fishing／camera_rig | 完整 main、寵物／世界生命週期與介面 |
| seichi-pov | move_stick／look_pad | 巡覽、spot 與全場景 |
| skybound-blades | stepper、save_service；battle 前段 tick／同時傷害流程 | battle 全部 1,171 行、save_schema 全規則、完整重播路徑 |
| star-tide-harbor | fishing 前 180 行（核心狀態與結算） | 家具、景深、螢火蟲與其他場景 |
| survivor-series | grid 全文、spawn_schedule | 系列子玩法／全部內容；art_src 製作專案排除本次 runtime 盤點 |
| taskbar-hero | inventory_manager；save_manager save_profile／load_profile；前階段 damage_rules | registry／autoload 全部互動、完整 progression |

## 搜尋與證據限制

MCP graph 已索引此 repo。檔案 pattern 使用 glob（例如 `*story_runner.gd`）可取得函式；先前 regex 式 file_pattern 回零不能推論 GDScript 未索引。本次用 search_graph／get_code_snippet 查敘事、步數、機台與刷怪；不足時才讀來源。graph snippet 與工作區檔案仍需以路徑／實際內容核對。

本表不聲稱整個研究已窮盡。已足以決定下一批重構邊界；優先回收共用基礎保護與生命週期，剩餘深讀按實際遷移目標繼續。沒有新增模型框架、修改遊戲副本或執行完整測試。

第三批 graph search 連續回報 `Transport closed`，因此按既有清單直接讀取檔案；沒有把工具失敗當作零引用。來源語義／目錄一致性檢查與 runtime 驗證仍分開。
