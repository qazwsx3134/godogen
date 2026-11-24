# A-erwin 正式素材 QC 報告 — 480×270；9 張舊圖保留於 art/_rejected/；生成記錄在 .forge/

| 檔案 | 尺寸 / 大小 | 檢查結果 |
|---|---:|---|
| `sky.png` | 1080×360 | 全不透明；首尾相等；byte-identical reused |
| `sky_night.png` | 1080×360 | 全不透明；首尾相等 |
| `far.png` | 1662×230 | alpha 0/255；首尾相等；byte-identical reused |
| `mid.png` | 1320×230 | alpha 0/255；首尾相等；byte-identical reused |
| `near.png` | 480×270 | alpha 0/255；左右接縫相等；purple/spill=0 |
| `closest.png` | 480×270 | alpha 0/255；左右接縫相等；purple/spill=0 |
| `fg_occluder.png` | 480×270 | alpha 0/255；中央留空；purple/spill=0 |
| `ground.png` | 492×120 | 全不透明；首尾相等；byte-identical reused |
| `preview.png` | 480×270 | 不透明；修色後由圖層重合成並目視確認 |
| `props/campfire_sheet.png` | 384×64 | 6×64 格；alpha 0/255；嚴格 spill QC pass；purple=0 |
| `props/tent.png` | 128×128 | alpha 0/255；spill/purple=0 |
| `props/item_rack.png` | 128×128 | alpha 0/255；spill/purple=0 |
| `props/cook_rack.png` | 128×128 | alpha 0/255；spill/purple=0 |
| `props/street_lamp.png` | 256×256 | alpha 0/255；spill/purple=0 |
| `hero/idle.png` | 256×64 | 4×64 格；alpha 0/255；frames QC pass |
| `hero/walk.png` | 256×64 | 4×64 格；frames QC 有 leg-alternation 提示，無失敗項 |
| `hero/jump.png` | 256×64 | 4×64 格；alpha 0/255；frames QC pass |
| `hero/frames.json` | 5,265 bytes | JSON 有效；12 格座標、可見框與共用錨點吻合 |
| `prompts/manifest.json` | 17,527 bytes | JSON 有效；9 組 Codex CLI 提示詞與兩項清理量測 |
| `prompts/bg_far.txt` | 937 bytes | reused far 圖提示詞 |
| `prompts/bg_mid.txt` | 904 bytes | reused mid 圖提示詞 |
| `prompts/bg_sky.txt` | 790 bytes | reused sky 圖提示詞 |
| `prompts/ground.txt` | 824 bytes | reused ground 圖提示詞 |
magenta spill：各檔殘留像素數=0（8 鄰可見 alpha 邊緣判定；far=0、mid=0、near=0、closest=0、fg_occluder=0、props/campfire_sheet=0、props/tent=0、props/item_rack=0、props/cook_rack=0、props/street_lamp=0、hero/idle=0、hero/walk=0、hero/jump=0；透明 RGB 殘留=0）
purple interior：各檔=0（判準 r>0.4、b>0.35、g<0.7×min(r,b)；near=0、closest=0、fg_occluder=0、props/campfire_sheet=0、props/tent=0、props/item_rack=0、props/cook_rack=0、props/street_lamp=0）
