# 不是頭痛，是桂

作者指定的極短篇時機吐槽原型。核心台詞、阿銀改句、玩家抓時機、桂分句／停頓與認真表情依本對話；具體時限、提示文案與美術待作者試玩。

在 repo 根目錄執行 `python3 preview/start.py`（Windows 也可雙擊 `preview/start.bat`），開啟本機編輯器網址：`http://127.0.0.1:8000/tools/story_editor/?story=katsura_dog_ears`。可直接編輯 graph 來源 dog_ears_story.json；選場景後展開「試玩這個場景」，由 Godot 開啟獨立試玩視窗。遊戲章節選擇也可切換本作品；獨立包不會覆寫既有第一章。Web 舊匯出版尚不包含此作品。

## 可調整處

- opening 節點最後的 freeze.duration：兩句間的停頓，初始 0.55 秒。
- timing 節點（「一本正經的咖紫拉打」）是三選一 `choice`，提示「下一句」：a「咖紫拉打」→ node_3、b「這是肉球隊長的耳朵」→ node_2、c「下一句是什麼來著？」→ node_1。原本的時機吐槽（QTE 圓環）已拿掉；要不要回來由作者決定。
- scenes/katsura.tscn 的 Art：角色取景，可在 Godot 拖曳；生成候選已設為預覽，PosePlaceholder 暫時隱藏。

桂姿勢立繪已依作者的 MS Paint 鼠繪風格提示詞重繪、去背並接入；前一版保留，最新版仍待作者試看。Godot 實際畫面已檢查手勢、牌子與吐槽演出；真人手感與最終畫風仍待作者確認。神樂及銀時採畫外音，桂和伊莉莎白保留在畫面；成功播放新八漫畫吐槽。

2026-11-02：依作者希望更貼近《銀魂》原作的背景風格，新增[萬事屋客廳動畫風背景](art/yorozuya_anime_bg_v2.png)，含「糖分」掛字。此故事的 catalog 覆寫客廳背景，其他故事與其調查熱區仍使用原本素材。圖片是生成候選，需作者在遊戲裡確認構圖與風格；來源與規格見 [art/README](art/README.md)。
