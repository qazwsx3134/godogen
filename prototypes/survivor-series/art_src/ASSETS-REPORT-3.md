# 第五輪資產候選報告（2026-10-09）
生成均指定 route=local:codex-cli，provider=openai，model=codex-image_gen；使用 Codex 登入額度，未呼叫 API；僅候選，未 approve／動畫。

A：吸塵器加粗 edit 已完成，來源 icons/vacuum/candidate-02.png。
輸出 icons/vacuum/edit-01.png、edit-02.png；比較 icons/vacuum/edit-contact.png 含原圖與兩張 edit，各附 32px 預覽。
key=magenta；614px 高框法保留，主體寬由 277px 增為 316／318px（alpha>16），比例更寬、金屬更亮，仍為同一直立吸塵器。
兩張均真透明 RGBA、完整、無文字／陰影；pad 無警告；原始 generated/prompt/job/run 留於 icons/vacuum/edit-r5/。

B：兩台車 s/e/ne/n 各兩張候選已完成；vehicles/<motorcycle|car>/dir-<s|e|ne|n>/candidate-01.png、candidate-02.png。
每台總覽 vehicles/<車>/directions-contact.png（se 核准原畫置中）；各方向也保留 contact、原始 generated/prompt/job/run 與修正前診斷圖。
候選均 RGBA 1024²、mob 框法／facing none；以核准車 FIRST、主角 STYLE SECOND，接地 baseline y=877。
已修正兩車 NE 初稿誤朝 SE、E 太近 SE、汽車 n-01 偏左上；汽車 e-02 仍略朝右下，保留為次候選，e-01 朝右較準。
投影寬度隨角度變動，未能保證五方向物理車長／像素密度完全一致；不能把共同框法視為完全比例一致，完整量測在 handoff/pad JSON。
汽車 n 修正僅有舊相對路徑警告：the style reference master_rgba.png is missing; its recorded sha256 is kept；實際 job 的 hero STYLE 附圖及雜湊正確。
汽車 E fix_ne.py PID43523／Codex PID43531 卡住逾3小時，依指示停止並確認子程序清空；舊 run ed8a04a874bf4026a8188c934856ab84 恢復回 ARTIFACT_MISSING。
唯一一次重跑 dir-e/fix-e-02 在360秒整批時限內成功取得兩張、生成無警告；舊失敗紀錄與所有原始 takes 保留，沒有再重跑。

C：tile_mode＋透明 prop kit 完成；可重排地磚／疊加層／道具，示例768×768（6×6 cells），未 approve／動畫。
風格取自 background/street_block/selected.png FIRST、hero STYLE SECOND；13 筆 codex-cli 原圖（含水窪重生）與 generated/prompt/job/run/cli-run 全留於 map/ground/raw-*、map/props/<raw-id>/。
地面 map/ground/pavement.png，五透明變化 manhole.png、drain_grate.png、puddle.png、cracks.png、zebra.png，均在 map/ground/；建議各128×128px canvas（內容 bounds 見 ground-kit.json）。
repo extract_terrain_tiles.py --edge-policy seamless --strict-qc --resampler nearest：X/Y seam ratio=0.441609/0.926504≤1.25，contrast=.117631≥.035，border delta=0≤.1，warnings=0；五 overlay isolated strict QA=pass。
3×3 視看無明顯 tile 邊界；工具 seamless_verified=false（精確無縫未證明），完整數字見 map/ground/extract-ground-runtime-01/terrain-bundle.json；未放寬門檻。
八道具均 map/props/<id>.png：stall-fruit、stall-snack、lantern_post（三燈串）、planter、cone、bollard、parked_scooter、fruit_crate；repo extract_prop_pack.py 接受8件、edge-touch=0。
遊戲尺寸（主角可見主體90px）：兩攤 stall-fruit/stall-snack 各128×112；lantern_post64×144、planter64×64、cone24×32、bollard20×52、parked_scooter96×80、fruit_crate40×32。
NN 等比縮放／接地 anchor／實際 bounds／來源 hash 見 map/props/prop-kit.json、postprocess/runtime/*.json；護柱原16×48觸框改為加透明2px邊、不裁切，舊版留診斷。
比較圖 map/ground/ground-contact-raw-runtime.png；道具 map/props/props-contact.png 與 postprocess/comparisons/<id>.png（主角實際44×90）；原稿皆保留。
Godot：map/godot/survivor-series-C-night-market.tileset.tres、同名.tscn、project.godot；export_godot.py --strict-qc parse-back=pass，Godot4.7實際editor匯入14圖／場景載入兩幀exit0，見 map/root-validation.json。
問題處理：水窪初稿內置鋪磚密度不符，已另生 water-only 新版並通過 strict QC；初稿留 map/ground/diagnostic/；舊 installed extractor 未測 seam，僅診斷，正式 QC 使用 repo v2。
預覽 map/preview/ground-repeat-3x3.png（384²）、night-market-composite.png（768²，地面＋8道具＋核准se主角90px）；bundle/nav/compose audit皆pass，詳細JSON在 map/data/、preview/。
匯出6個 flat sources 同型提示：tileset pavement (flat) has no complete wang or blob_mask data; no terrain set was made（5 overlays亦同，原文 map/godot/godot-export.json）；Atlas tiles可用，未建立Wang terrain brush；單base反光週期仍可辨，可重排overlay/props打散。
