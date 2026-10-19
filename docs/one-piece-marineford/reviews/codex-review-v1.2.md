# v1.2 與 sprite-actors-3d：第三輪審查

2026-10-19，wJ:p13 Codex → wJ:pZ Claude。**結論：方向符合本輪使用者決定，但共用 skill 的資料契約與幾項來源陳述尚須修正，暫不 ACK。** 只審 brief 指定的設計與 skill；沒有審正在抽取的 kit 新程式／diff，沒有改設計、程式或 erwin-run，唯一寫入本報告。S＝`prototypes/godot-kit/skills/sprite-actors-3d/SKILL.md`；D＝`docs/one-piece-marineford/README.md`；B＝`docs/pokebonk-com/codex-bundle-analysis.md`；M/H＝`prototypes/madara-survivor/`、`prototypes/horde-25d/`。行號以本輪讀取版本為準。B 是既有公開 bundle 的靜態拆解，本輪未重新下載／執行第三方遊戲，不把未目視的方向素材或本案 Web 效能當成已驗證。

## 1. skill 的數值、公式與來源忠實度

**結論：核心方向公式與多數數值正確；「全部素材同密度」、任意相機角度、描邊能力與現成實作狀態有不正確或過度的陳述。** B:59 的 `atan2(dot(d,right),-dot(d,forward))` 確實推得 row0 朝鏡頭、2 右、4 背、6 左，與 S:67–80 相符；B:71 的 .074、fallback .04 及角色 scale，B:79 的橢圓 .6／alpha .38，B:81 的四鄰整圖 texel／溶解邊緣 .12，B:93 的 4×4 網點最多挖 .75，B:138 的角色亮度 `.85+.15*light` 均有對應。建議如下。

- **區分來源與本案設計。** S:32 稱角色與地面像素相同，是 `.074 ≈ 1/13.5` 的近似，但 B:93 的樹是 .085m/px、小物 .05、地標 .10–.13，B:126 水面為 8px/m，天空另為 4 個螢幕 pixel 的量化（B:140），並非全素材一把尺。S:31 的統一角色密度可作新專案規範，不能擴張成原作全場的客觀事實；D:39 的同類說法也要改。方向列順序是公式推導、未下載 PNG 目視（B:59、306）；五列鏡像、方向遲滯與 Godot x-ray 都是移植建議，不是已證實原作有的功能。S:117 說 shader 描邊能解決圖內細節，實際 S:113 的 alpha 四鄰只畫透明／實體交界，無法產生兩個不透明色塊間的內部線條；眼睛、衣紋等仍由原圖畫。應區分角色 alpha 邊界與地形深度邊緣。
- **billboard 限定有效相機範圍。** S:49–51 是 M shader:70–73 的水平 right 版本；B:70 記原作 right 為 camera right，本案在相機無 roll 時等價。S:58 的 lean=1 只有在無 roll 等條件下才可稱完整 camera-facing；任意 roll 時水平 right 與 camera up 未必正交。S:3／21 的「不管什麼角度」過廣：精確俯視時水平 forward 可趨近零、方向選列退化，right 投影亦可能退化；新共用 skill 應明定不支援頂視／相機 roll，或加入正交化與退化 fallback。八方向也只提供方位角素材，改變很大的俯角並不保證同張圖的繪製透視仍正確。S:60 依圖選 lean 合理，但需說明 0→1 是逐漸向 camera up 對齊，不能以「往後仰」描述 lean=1 的反效果。三種俯角截圖是需要的美術驗收。
- **方向計算缺幾個必要定義。** S:67 的 f/r 必須是正規化的地面投影；若 f 未 normalize，26°與45°俯角會改斜向分界。Godot forward 用相機 `-basis.z`，不是 `basis.z`；列用 `posmod(round(angle/step),N)`，避免負角對負餘數落到 row−1。補實測用表：鏡頭朝世界 −Z 時，d=+Z→0、+X→2、−Z→4、−X→6；相機 yaw 改90°後重新驗。停下與攻擊優先權要有持續狀態，不能每幀在移動／瞄準間搶列。四方向素材的列義也要明寫（前／右／後／左），不得直接拿八列索引解讀。
- **腳底、陰影、深度的共用規格須完整。** S:38–42 要以 `frame_width/height × meters_per_px` 決定 quad 世界尺寸，不能用同一方形 scale 填滿所有框；foot_gutter=.047 是既有圖集約定，不能讓新工具固定再加一次。建議存 `foot_anchor_px`／基準原點，以同角色整段動作的共同縮放／定位為準；若每格各自 trim 再底對齊，跳躍、受擊離地與突進的原始位移會被抹掉。M/tools/build_atlas.py 的 group 確有共同縮放，但不等於已保留每個來源動作的全部相對錨點。B:79 的影子離地 .06，M/shaders/blob_shadow.gdshader:16 是固定世界 y=.03；兩者應標來源／範例，不能宣稱現成 shader 已支援任意高度場。S:104 說取地形高度正確，但實例資料需同時表達 `ground_y` 與 `air_height`，否則原有 shrink 把整座高台的世界 y 當飛行高度。M x-ray 與本體有相同 UV／lean／gutter，但本體的 squash/bob/spin 未全部同步到 x-ray，不能只保證同原點就保證無自身露影；另加未遮擋、受擊、翻滾時不出剪影的驗收。quad 的 alpha discard＋寫深度可免 alpha 排序，但不能宣稱所有 billboard 交叉幾何永遠不穿插；它們仍是面片。
- **更正現成能力與陰影開關。** S:201 說兩份現成 shader 都沒做 shader 描邊不成立：H/shaders/sprite_billboard.gdshader:90–105 已有本格 clamp 的一 texel 四鄰描邊；M 版本沒有。抽取時應保留此既有功能，不誤當全新。S:98 不投射陰影需由 GeometryInstance3D 的 cast_shadow 關閉；`render_mode shadows_disabled` 不能單獨替代投射設定。角色自行亮度與霧應在同一色彩空間、固定順序下處理，不因 unshaded 就遺漏距離霧。

## 2. skill 新增建議與 Compatibility 契約

**結論：5°–8°遲滯、透明邊、facing 鏡像與 custom/color 分工本身合理；目前的圖集 schema 與數值通道還不足以作可共用規格。**

- **遲滯與透明邊同意，但補邊界行為。** 八方向每半扇區22.5°，在原分界外再5°–8°才換列是合理起點，須保存上一列，用 circular angular difference 處理359°↔0°與快速180°轉身，允許直接跨多列；別逐列爬或用定時延遲。對一方向不啟用；四方向可另調。outline 半徑1 texel至少一圈透明 padding 正確，並須在所有變形／動畫極限仍留足；若未來描邊半徑2，padding相應增加。clamp取樣到本格 texel center、圖集 nearest/repeat_disable／不生角色 mipmap，否則透明邊仍會串格。
- **五列鏡像是合理的新格式，但目前 JSON 自相矛盾。** S:133–137 的 rows=8 配 `mirror:true`（S:142 解釋物理只畫5列），y=0／320／640 又沿用原作40px×8列的排法。到底 rows 是邏輯方向數還是儲存列數？是保留8列槽、只填5列，還是緊密打包5列？兩種都能做，但同一工具不能猜。建議明分 `direction_count=8`、`stored_rows=5`、顯式 `direction_map=[0,1,2,3,4,3,2,1]`、鏡像 flags，動作另有 `start_cell` 或完整rect；JSON保留原作 schema 時就別把鏡像含義混入未改寫的 rows。S:166 的 `row * 每列格數 + frame` 還缺**動作起始偏移與整張圖集 stride**：walk／idle／attack 的 n 不同、y 不同，不能一律把 n 當atlas columns。統一大cell後用 `start_cell + stored_row*atlas_columns + frame` 或查表映射，定義CPU repack輸出，並由播放Resource保存。還需規定idle的非均勻ticks、non-loop完成後狀態／訊號與一次性終了，非法n／d／rect在匯入時報錯；不能只把全部缺動作都默默走walk當驗收成功。
- **facing鏡像能沿用；資料通道要明確，不能寫「tint與身分」就算分配。** S:82／166 用z=−1及格號指向實存列，與現有M shader:46–60相容，cull_disabled避免翻面消失。建議固定 custom=(absolute_cell, flash, mirror_sign, phase)，COLOR.rgb=tint、COLOR.a=outline_role的規範化碼；若還要dissolve，須決定phase通道在死亡時複用或另分批／資料貼圖，否則 S:114 的功能無處輸入。COLOR.a當role就不要寫入ALPHA。Mesh原始頂點色保持白色並自行解碼，single actor用uniform時需與MultiMesh效果一致。陰影批次若共用帶color的buffer，須忽略role與tint alpha，不能把Boss身分值當影子透明度。
- **Web精度與opaque路徑是必改規則。** [Godot4.7 MultiMesh](https://docs.godotengine.org/en/4.7/classes/class_multimesh.html#class-multimesh-method-set-instance-custom-data) 明載Compatibility的custom data和instance color各分量打包16 bits；不得把每個通道當任意高精度整數／bitfield。以本案85格或136格等小索引沒問題，共用skill仍應限格號範圍、規定role編碼與round解碼、以Web測邊界值；大圖集分批或資料貼圖，不能只因資料來源是Color就假設full float。use_colors/use_custom_data要在instance_count前設定；M/horde舊STRIDE16是transform12＋custom4，加COLOR後須同步成transform12＋color4＋custom4（20 floats），sprite／shadow兩批需一致。另 [Godot4.7 spatial shader](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html#fragment-built-ins) 說讀寫ALPHA會進透明路徑；S:90「留下alpha=1」若照字面寫`ALPHA=1`會破壞「不透明批次」的契約。應明寫採discard、只寫ALBEDO等不透明輸出、不讀寫ALPHA，或採經驗證的alpha-scissor專門路徑；不得只靠`depth_draw_opaque`聲稱仍在opaque pass。Xray／ghost才另用透明材質。
- **共用分發還缺自足性與邊界驗收。** S:8 要其他遊戲回godogen找參考，對可攜skill不夠；應有隨套件可取得的schema／範例與相對路徑，註明本輪仍未抽取完成。新增方位軸／wrap／鏡像不對稱、單人與MultiMesh同格同影、最高cell、非loop結束、opaque深度、resize／viewport邊緣、地面高度與自身x-ray負例；代表性角色與道具在editor已可見，擴大的billboard／擊飛需正確custom_aabb，避免視錐邊緣消失。以上是規格與後續驗收要求，不是提前審新kit程式。

## 3. 像素更精細與圖集估算

**結論：0.025m/px合理作候選；數學正確，但統一密度的來源說法、96px共用格容量及螢幕可見精細度需修正。** D:34–42 的13.5px/m約等於.074m/px，.025為40px/m、1.8m為72px；96×17=1632、96×5=480，RGBA8不含mipmap約2.99MiB／角色，均算對。但17個frame是**所有動作橫排合計17格**才成立；若每動作都17格則需另乘動作數；8列不鏡像為1632×768，約4.78MiB。96px cell在.025時世界寬高2.4m，72px高角色可放，但伸縮手槍、火箭／巨人拳、較大大將與擊飛伸展不保證放得下；.02時1.8m已90px，再扣padding／腳底帶空間很緊。應按角色／動作最大畫布估算，不把同密度等於同cell；伸長招式適合另有拳／手臂效果物件。貼圖維度小於4096只是初步篩選，需驗手機MAX_TEXTURE_SIZE與**常駐總解碼記憶體**；八名同伴、多個敵人與圖集重載同時常駐才是成本，不能只看一張小於上限。

D:39、70 的統一素材密度可以是本作美術選擇，並非原作事實（B:93、112、126、140）。64px VFX cell（B:157）只是包裝尺寸，不代表固定world texel density：若64px效果寬4m，素材密度只有16px/m，與40px/m不同；效果size隨時間變化也會改texel footprint。要一致，需為主要硬邊特效定world_size／有效像素數，或按world位置／效果局部世界尺度量化；大型光圈、柔煙、天空可列有意識的密度例外。D:58引用pixel-vfx時特別注意該skill:16明說不適用3D，:20要求位置格點對齊與22.5°旋轉，是2D工作流；只借配色與硬邊層次，**不能直接套它的位置吸附到3D角色**，與S:183會衝突。

還有螢幕取樣限制：以垂直FOV70、view-depth9m、render高度360px的理想例子，1.8m高物體投影約51px；即使素材72px也會被minify，最近點可能跳動或吃掉細節。這是透視公式估算，不是本機畫面量測。三種密度並排時須固定世界身高、FOV、距離與render resolution，重新供應約55／72／90px的有效角色內容，不能只是把同張圖縮放改世界身高；在手機實際DPR與品質設定觀察1px輪廓、眼睛、拳頭和移動閃爍。地面40px/m比原作13.5高近3倍，遠處仍需mipmap／程序抗走樣，成本與穩定性不由atlas尺寸保證。建議0.025保留為候選，交使用者手機比圖決定，不先當最終標準。

## 4. 固定鏡頭、手機輸入與推進契約

**結論：同意已解決第二輪「相機沿路轉但輸入未定」的核心P0；不應再要求自由視角，仍有高度場與固定構圖缺口。** D:114–125 明定不旋轉、上推前進、路線大方向不轉、樓梯過場、後方方向標與真機雙指，是與本輪決定一致的做法。三鍵不是第四個拖鏡頭動作，按鈕與Safe Area也已列驗收。剩餘修正如下：D:48用26°與FOV70，D:122卻說俯角比PokeBonk高，二者不一致；給實際選定pitch而非兩個敘述。FOV須在Camera3D設KEEP_HEIGHT時才作縱向解釋，pitch<FOV/2只是對稱視錐、無v_offset時地平線可能入鏡的必要幾何條件，不保證有限高的處刑台可見，更不保證主角在下1/3。指定aim/target高度、distance與必要frustum offset，再以spike確認；縮放／FOV punch／震屏也不能把地標與危險提示推出可用區。

D:353說主要改Camera3D scene transform，不能涵蓋新高度場：M/scripts/camera_rig.gd:48–52目前三軸一起follow，沒有B:137的地形視線抬升／回落與獨立XZ18/Y10平滑；照抄數值與保留現成邏輯要分清楚。固定相機可只平移升降避地形、保持旋轉固定，或由關卡設計嚴格限制遮擋；但要選擇策略，否則台地、峭壁可能把相機放入地面。角色行走／影子／生怪與地面height sampler亦須用同一份高度場，本輪只把地形改成有高低、角色仍在y=0不是成立的完整契約。D:120「後面不留東西」只寫回收敵人，XP、肉仍可能掉後方；明定過路點吸附／搬移／自然失效等選擇，以及追兵例外，不然玩家仍會為升級回頭。路點觸發區橫跨路寬還須連續線段掃掠檢查；火箭一tick從區前到區後可能兩端都不在區內，不能只靠觸發區較寬保證不跳點。

D:60把Ultimate沿參考放左下，D:230–232卻要求右手三鍵，需以本案右手位置為準，左下留槽位但不要再放第二顆可操作Ultimate；搖桿左半的touch ownership也需避開左下HUD互動。手機橫向鎖可能失敗，D:49不應只依orientation=4，保留portrait overlay和fullscreen/lock失敗處理（B:280）；加入pagehide／blur／pointercancel／重進頁面清手指（B:283），不只選單暫停清理。D:404說手機結果才是效能門檻，但只寫「記fps」沒有門檻，須定目標手機／瀏覽器與判準，例如同情境p95≤33.3ms、列>100ms卡頓，或明定以20ms作手機門檻；不必沿用桌機50fps級標準。D:408的改平台只能是使用者另行改需求，不能作「只做Web」任務的自動退路。

## 5. 候選渲染圖的 Compatibility 可行性

**結論：這個精簡方向可行，不再有多個3D讀屏quad自動串接的根本錯誤；但需明定transparent順序與PixelOutline覆蓋對象，才算可實作的設計。** D:88–95 的一次opaque讀屏→透明VFX→內建Glow→SubViewport color→一個2D調色shader→HUD，是合理候選；第二輪已核實 [4.7 renderer表](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html#environment-and-post-processing) 支援GL screen/depth texture、fullscreen quad、Glow，不支援CompositorEffects。這輪不推翻該結論，也不把候選說成實測通過。明確規定PixelOutline fullscreen quad屬transparent queue、`depth_draw_never`／不遮蔽其他物件、正確不受世界遮擋，render_priority早於所有透明物（含影子／水／x-ray／VFX）；使用同viewport的opaque color/depth，不試從SubViewportTexture直接讀深度。後續3D透明物直接blend到已有描邊結果，Glow應包含這些效果，再輸出一張顏色紋理，2D直接採樣這張viewport texture而非另賭自動backbuffer；HUD與閃屏在最終調色之後。若不定優先級，讀屏quad可能在VFX後才覆寫畫面，把已畫特效抹掉。依 [官方screen-reading](https://docs.godotengine.org/en/4.7/tutorials/shaders/screen-reading_shaders.html#behind-the-scenes)，transparent不在opaque screen copy中，這是此候選需刻意處理的行為。

另有一個**skill與渲染圖的直接衝突**：S:117要求全畫面描邊只用地形道具，D:89卻把sprite也寫opaque；四鄰depth包含sprite深度，普通PixelOutline自然也會描角色，不能因已做局部描邊就說它不靠這條鏈。可先明確接受「角色也參與全屏depth邊緣」並以spike驗沒有雙描邊／群體黑塊，或設計獨立mask／深度來源排除actors並列額外成本；不要假設有現成每材質排除mask。D:97的x-ray半透明不寫深度，屬透明階段，仍會吃Glow與2D調色；這不同於最後HUD保護層，需驗白色／身分彩色描邊在霧、閃白、蒸氣下仍可辨。

D:56把參考的複合EffectPass概括成有先後的tint/grade/bloom沒有足夠依據：B:143只確認RenderPass→PixelOutline→複合EffectPass；本候選Glow在最終grade之前，屬Godot近似鏈，照D:97列差異比圖就可，不必另造昂貴管線追求未證實的逐效果順序。GL Glow的threshold .92可作LDR調參起點，但與原套件的strength/radius不保證等價；AA關閉與最近點不是低解析固定渲染，保持D:57的區分。spike的通過項應補「8方向含鏡像、受擊／倒地、自身x-ray負例、outline與透明VFX有無覆寫、低密度／高密度角色在手機實際大小」。必要時先保留角色alpha描邊與手動霧／tint，分開開關PixelOutline與Glow量成本，以證據決定Web品質，不自動換平台。

## 必改

P0＝共用skill／新模組接口定案前須補；P1＝相應場景與視覺spike驗收前補。

- **P0 — 圖集與方向schema**：分邏輯8方向／實存5列、明訂mirror map、每動作起點與atlas stride、變尺寸統一cell轉換、tick與單次動畫結束；方向基底normalize、forward符號與posmod寫明。
- **P0 — 通道、opaque與Web契約**：列custom/color各分量與dissolve來源；補16-bit打包與格號／role範圍；use_colors初始化及20-float buffer結構；不以ALPHA=1保證opaque，避免把role寫到透明度。
- **P0 — 渲染圖一致性**：PixelOutline排序在所有transparent之前、禁止寫深度；決定角色是否參與全屏depth邊緣，與skill「只描地形道具」統一；標清x-ray吃後製的層次。圖目前可作候選，不能稱已完成驗收。
- **P1 — 修正來源與共用範圍**：原作各類像素密度不同、方向圖像未目視、鏡像為移植選項；alpha輪廓不生成內部細節；H已有outline；補固定無roll／非頂視限制與可攜schema／參考路徑。
- **P1 — 密度與記憶體驗收**：三密度比較保持世界身高／構圖／render解析度；96px格按動作與大角色預算，64px特效不等於40px/m；整體常駐atlas成本與手機實際可見細節一起驗。
- **P1 — 高度場／固定鏡頭／手機細節**：腳底anchor與地面／飛行高度分離、shadow/x-ray變形一致性、Camera高度避障／aim、pitch矛盾、後方掉落處理、火箭掃掠路點；Ultimate右手版位、取消與失焦清理、橫向鎖失敗提示、明確手機效能通過門檻。
