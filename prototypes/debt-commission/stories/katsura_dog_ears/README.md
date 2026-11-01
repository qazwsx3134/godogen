# 不是頭痛，是桂

作者指定的極短篇時機吐槽原型。核心台詞、阿銀改句、玩家抓時機、桂分句／停頓與認真表情依本對話；具體時限、提示文案與美術待作者試玩。

本機編輯器網址：`http://127.0.0.1:8000/tools/story_editor/?story=katsura_dog_ears`。先啟動 tools/story_editor/project_server.py；可直接編輯 graph 來源 dog_ears_story.json。遊戲章節選擇可切換本作品；獨立包不會覆寫既有第一章。Web 舊匯出版尚不包含此作品。

## 可調整處

- opening 節點最後的 freeze.duration：兩句間的停頓，初始 0.55 秒。
- timing 節點 boke_round.expression：serious；lines[0].text 是獨立第二句「咖紫拉打。」。
- timing.lines[0].slot.qte：duration=0.75、window=0.18、late_after=1.3，分別是圓環重疊時刻、容許誤差與錯過期限。
- scenes/katsura.tscn 的 Art：角色取景，可在 Godot 拖曳；生成候選已設為預覽，PosePlaceholder 暫時隱藏。

桂姿勢立繪已依作者的 MS Paint 鼠繪風格提示詞重繪、去背並接入；前一版保留，最新版仍待作者試看。Godot 實際畫面已檢查手勢、牌子與吐槽演出；真人手感與最終畫風仍待作者確認。神樂及銀時採畫外音，桂和伊莉莎白保留在畫面；成功播放新八漫畫吐槽。
