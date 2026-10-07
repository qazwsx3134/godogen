# 主角動作影片管線回報
狀態：第一步先決條件未通過，依 ANIM.md 停止；未 approve、未 plan/run/review/accept，未切換生成路徑。
doctor：overall WARN；media.api.xai=MISSING（本 session 環境與工具設定均未讀到 XAI_API_KEY），video=none。
route_media.py resolve --kind video：exit 3、status=no-route；xAI API 不可用，未發出生成請求。
ffmpeg：doctor=MISSING；ffmpeg -version 回報 command not found（exit 127），無法確認 5.1+；PATH 上沒有可用 ffmpeg。
男 master.json 預定路徑（未建立）：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/man/master.json
女 master.json 預定路徑（未建立）：/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/woman/master.json
男 idle：0 takes，QC 未執行；walk：0 takes，QC 未執行；attack：0 takes，QC 未執行。
review sheet：未產生；女主角動作未開始。
實際生成影片：0 支、0 秒；此次未發出付費影片生成請求。
問題：ANIM.md 所述已設定金鑰未反映於目前 session；須讓此 session/工具可讀到金鑰並讓 ffmpeg 5.1+ 進入 PATH 後再執行。
完整 doctor 紀錄：/tmp/survivor-anim-doctor.json；另有既有 ledger 未結案警告，未更動歷史紀錄。
