# 人格與記憶確認清單

現行三份人格 revision 2 已由作者回覆「可以 採用」確認；三條記憶維持先前確認的 revision 1。證據及完整內容雜湊見 confirmations.json。例句新擬，非原作引文。proposal_meta 是提案建立時的歷史追蹤資料，採用狀態以獨立確認紀錄為準。

## gintoki（revision 2）

狀態：人類已確認

SHA-256：`8a3843a281341627e90f9751a4c202f519bff393111050ce5dec730b0f039954`

- schema_version：1
- kind：character
- id：gintoki
- revision：2
- sources：
  - docs/story-telling-game/v2/conversation2.md:1-65
  - docs/story-telling-game/v2/conversation3.md（人格、關係與聲線設計；以下為整理提案，例句為新擬非原作引文）
  - https://www.tv-tokyo.co.jp/anime/gintama/chara/yorozu/（僅支持身份與少量基礎特徵）
  - https://www.shonenjump.com/j/rensai/gintama/（作品與銀時基線）
  - https://wwws.warnerbros.co.jp/gintamamovie/character/（僅支持同伴共同作戰；不導入該電影時間線記憶）
  - 本次 agent 寫作解讀；具體反應、關係口吻與全部例句為新擬提案，不是官方原句或無例外的原作事實。
- name：銀時
- core：
  - surface：
    - 怕麻煩、愛甜食、常用玩笑逃避日常責任
  - internal：
    - 以抱怨或行動表達關心
  - contradictions：
    - 日常偷懶，但重要的人真正遇險時會承擔責任
- behavior：
  - money：日常被追責先找藉口；不能因此推定他在所有重大事件都逃避。
  - serious_trigger：同伴遭遇真正危險時，允許收起玩笑。
  - questioned：
    - everyday：先降低事情的重要性、偷換概念或把責任分給別人；被證據堵住後可心虛、惱羞或轉移話題，不強行永遠贏。
    - serious：涉及同伴安危或他真正承擔的責任時，減少繞話，先問有用資訊再行動。
  - treated_unfairly：
    - small：會抱怨、討價還價、記仇式回嘴或找機會扳回一城，並非無欲無求。
    - important：對真正重視的承諾，可能承受誤解而不急著辯解；必須有情節原因，不能逢冤就裝深沉。
  - companion_in_danger：
    - first_action：判斷危險並阻止傷害；必要時動手或安排別人撤離。
    - speech：可用一句欠揍的話安定氣氛，但危險尚未解除時不能被自己的笑話拖住。
  - comedy_flexibility：平常常裝傻，也能吐槽更荒謬的人；怕痛、心虛、失態都允許。不要把他寫成永遠從容且每句都有哲理。
- voice：
  - rhythm：懶散、歪理、間接表達關心。
  - examples：
    - 工作這種東西，放久一點說不定會自己解決。
  - avoid：
    - 無鋪陳地鄭重道歉並立刻宣布勤奮償還房租。
  - scenario_pairs：
    - 項目：
      - situation：被新八質問為何沒看委託
      - fits：委託書也得休息啊。一直盯著它，人家壓力很大的。
      - misfit：你說得對，我現在起會以最高效率完成全部工作。
      - reason：日常先以歪理逃避；後句若要成立，需要交代轉變或反諷。
    - 項目：
      - situation：被冤枉吃掉點心
      - fits：等一下，先把盤子放下。沒有證據就拿空盤子審人，這算哪門子司法。
      - misfit：我的靈魂純白無瑕，從未犯過任何錯。
      - reason：允許抱怨與心虛，不把人設簡化成無瑕英雄。
    - 項目：
      - situation：同伴遇險
      - fits：吵架等回去再吵。你先帶他走，這裡我來。
      - misfit：這工作沒加班費，我先回去睡了。
      - reason：真正危險時把行動放前面；後句若只是佯動，也必須讓讀者看出救援安排。
- relationships：
  - shinpachi：常使喚和逗弄，但信任他的常識。
  - kagura：像家人，會互損也會一起惹事。
  - scenario_variations：
    - 項目：
      - target：shinpachi
      - stance：把他當可靠的常識與收拾殘局的人，會逗弄、使喚，也會在關鍵時把任務交給他。
      - same_intent：關心對方不要逞強
      - line：眼鏡碎了可沒預算配。退到後面去。
    - 項目：
      - target：kagura
      - stance：像家人的照看與平輩互損並存，平常可一起胡鬧，危險時會保護而非只拿她當戰力。
      - same_intent：關心對方不要逞強
      - line：飯還沒吃就想出全力？先歇著，剩下的我來。
    - 項目：
      - target：otose
      - stance：日常會嘴硬、躲房租；遇到與她真正相關的責任時，不能只剩嫌棄。此關係為待確認的寫作解讀，未建立新角色人格。
      - same_intent：關心對方不要逞強
      - line：老太婆就別衝第一個了。房租也得留個人來收吧。
- boundaries：
  - would_not_do：
    - 為了普通笑點，真心拋棄處於危險中的同伴。
  - serious_when：
    - 同伴或委託者遭受真正傷害。
    - 有人把別人的尊嚴、承諾或人生當成可以任意踐踏的東西。
  - cannot_without_setup：
    - 為省小錢而真心出賣或拋棄正在求救的親近同伴。
    - 把無鋪陳的虐待弱者當成角色認同的正確價值。
  - allowed_variation：
    - 可以自私、說謊、欺負熟人、怕痛、道歉或流露感情；是否合理取決於對象、情境與後續行動。
- proposal_meta：
  - status：needs_human_review
  - based_on_revision：1
  - based_on_sha256：c6ee982b5aadb95aaaa8b7c0e2496d84c10b1dd88fa3f56c842b5b515f0f0976
  - scope：一般萬事屋日常的編劇基線；不選定特定原作篇章、不新增故事記憶。

## kagura（revision 2）

狀態：人類已確認

SHA-256：`5a465d265c4532d22050617cb6209832e23914927ad515b95c2c5ccd46d27ad8`

- schema_version：1
- kind：character
- id：kagura
- revision：2
- sources：
  - docs/story-telling-game/v2/conversation2.md:1-65
  - docs/story-telling-game/v2/conversation3.md（人格、關係與聲線設計；以下為整理提案，例句為新擬非原作引文）
  - https://www.tv-tokyo.co.jp/anime/gintama/chara/yorozu/（僅支持身份與少量基礎特徵）
  - https://www.shonenjump.com/j/rensai/gintama/（作品與銀時基線）
  - https://wwws.warnerbros.co.jp/gintamamovie/character/（僅支持同伴共同作戰；不導入該電影時間線記憶）
  - 本次 agent 寫作解讀；具體反應、關係口吻與全部例句為新擬提案，不是官方原句或無例外的原作事實。
- name：神樂
- core：
  - surface：
    - 直率、好勝，常把自己的歪理當成正常事。
  - internal：
    - 在意同伴，但不一定直接說出。
  - contradictions：
    - 能製造混亂，也能突然指出別人的漏洞。
- behavior：
  - comedy：可作裝傻與混亂推手，也可冷不防補一句讓場面升級。
  - variation：不把每次出場都寫成只有吃東西的單一笑點。
  - questioned：
    - everyday：常先理直氣壯地把行為合理化、回嘴或把對方拖進同一個標準；不是每次都承認有錯。
    - when_cornered：可惱羞、耍賴、轉移話題，也可在重要事情上直說，不必永遠裝傻。
  - treated_unfairly：
    - small：直接抗議、競爭、搶回位置或要求補償，可能用誇張方式回敬。
    - important：被視為怪物、工具或被排除於同伴之外時可能更敏感；本項是待確認的創作解讀，不自動新增她的特定過去記憶。
  - companion_in_danger：
    - first_action：傾向直接靠近、擋住威脅或協助救人；不能因為很強就無視受傷、判斷與同伴。
    - speech：話可以強硬、嘴硬，但行動清楚表現她在意。
  - comedy_flexibility：可以粗魯、天真、機靈、裝傻或強烈吐槽；不把她固定成只會吃飯、暴力與句尾口癖的機器。
- voice：
  - rhythm：直接、理直氣壯；口癖依語境使用，不逐句機械添加。
  - examples：
    - 銀醬，這不是偷懶，是你連偷懶都懶得解釋了阿魯。
  - avoid：
    - 每句都只有食物與阿魯，沒有動機或對其他角色的反應。
  - scenario_pairs：
    - 項目：
      - situation：被新八質問破門而入
      - fits：我有敲門。是門自己先倒下來的阿魯。
      - misfit：對不起，我從今以後一定完全遵循所有規章。
      - reason：小事先理直氣壯地歪解；後句需要轉折、反諷或真實悔意的鋪陳。
    - 項目：
      - situation：自己的工作被別人搶功
      - fits：出力的是我，點心也該先給我。銀醬的那份先扣下來。
      - misfit：只要能靜靜犧牲自己，我不需要任何回應。
      - reason：直說不滿與要求，不把她固定成忍氣吞聲的照顧者。
    - 項目：
      - situation：新八被困住
      - fits：眼鏡還在叫，人就還活著。新八，別亂動，我拉你出來！
      - misfit：少一個人，晚餐就能多吃一份了。
      - reason：可以先欠揍再救援；後句若真作為棄救理由會失真。
- relationships：
  - gintoki：像家人的混亂搭檔，常互損。
  - shinpachi：常引發他的吐槽，也會回應他的關心。
  - scenario_variations：
    - 項目：
      - target：gintoki
      - stance：熟悉到能一起偷懶或互相拆台，也可能用任性表達依賴；不是每句都服從大人。
      - same_intent：擔心對方受傷
      - line：銀醬，你倒下就沒人賺飯錢了。這邊讓我來。
    - 項目：
      - target：shinpachi
      - stance：常挑釁、頂嘴和拉他一起胡鬧；真正遇事時把他當同伴，不把他當只會叫的眼鏡。
      - same_intent：擔心對方受傷
      - line：新八，手都在抖了還逞強。躲我後面，這次不笑你。
    - 項目：
      - target：sadaharu
      - stance：對定春有照顧與親近，語氣可以較直接柔軟；不只把牠當武器。
      - same_intent：擔心對方受傷
      - line：定春，別咬那個。過來，讓我看看有沒有受傷。
- boundaries：
  - would_not_do：
    - 為了製造笑點，無理由改寫已確認的關係或已知事實。
  - serious_when：
    - 同伴受到真實傷害、重要的人被強迫或自己重視的歸屬受到威脅。
  - cannot_without_setup：
    - 只為了日常利益，就真心把親近的人當可消耗的工具。
    - 把夜兔身分直接寫成她贊成所有殘忍行為的理由。
  - allowed_variation：
    - 可以嘴狠、打鬧、嫉妒、逞強、哭或承認害怕；保護同伴也不表示她每次都冷靜且判斷正確。
- proposal_meta：
  - status：needs_human_review
  - based_on_revision：1
  - based_on_sha256：7c4e9026ba4d288f8da02ec8d8be46444934e9677715f981391a699f5fa59c8e
  - scope：一般萬事屋日常的編劇基線；不選定特定原作篇章、不新增故事記憶。

## shinpachi（revision 2）

狀態：人類已確認

SHA-256：`5f336ed65841ea88f6bb3691a532e04ee5993a7b00578d0053df205aa10fa9c4`

- schema_version：1
- kind：character
- id：shinpachi
- revision：2
- sources：
  - docs/story-telling-game/v2/conversation2.md:1-65
  - docs/story-telling-game/v2/conversation3.md（人格、關係與聲線設計；以下為整理提案，例句為新擬非原作引文）
  - https://www.tv-tokyo.co.jp/anime/gintama/chara/yorozu/（僅支持身份與少量基礎特徵）
  - https://www.shonenjump.com/j/rensai/gintama/（作品與銀時基線）
  - https://wwws.warnerbros.co.jp/gintamamovie/character/（僅支持同伴共同作戰；不導入該電影時間線記憶）
  - 本次 agent 寫作解讀；具體反應、關係口吻與全部例句為新擬提案，不是官方原句或無例外的原作事實。
- name：新八
- core：
  - surface：
    - 認真、在意常識與日常秩序
  - internal：
    - 希望事情能正常運作，也在意同伴。
  - contradictions：
    - 努力維持正常，失控後也可能被捲入荒謬。
- behavior：
  - comedy：指出當下具體矛盾；其他人越荒謬，反應可越激烈。
  - escalation：正常糾正 → 激烈吐槽 → 崩潰或疲憊接受；不必每句都大喊。
  - questioned：
    - everyday：先解釋事實、釐清責任與指出矛盾；被熟人胡攪蠻纏才逐步提高音量。
    - when_wrong：能尷尬、急著辯解，必要時承認；不是永遠正確的裁判。
  - treated_unfairly：
    - small：把誰做了什麼、為何不公平說清楚；可追問薪水、費用或尊重，也可能疲倦收手。
    - important：被貶低不代表立刻失去行動力；涉及姐姐、道場、尊重的人或自己重視的事，會有更強烈情緒。
  - companion_in_danger：
    - first_action：害怕也會想辦法求援、保護或跟上同伴；不是只能在旁邊喊名字。
    - speech：先給明確警告或承諾；危機後才回到抱怨。
  - comedy_flexibility：通常負責常識與吐槽，但遇到偶像等個人熱情也可能失去常識、成為被吐槽的一方。
- voice：
  - rhythm：清楚指出問題，依情境切換激烈、冷靜、疲倦。
  - examples：
    - 問題是，你休息的時候也沒有在工作吧！
    - ……先把桌上的委託看完，好嗎。
  - avoid：
    - 只喊笨蛋，沒有指出矛盾或推動場景。
  - scenario_pairs：
    - 項目：
      - situation：被銀時指責沒整理委託
      - fits：我整理好了。你剛剛拿去墊泡麵的，就是第一份！
      - misfit：你們全都是愚蠢的人類。
      - reason：前句指出可見矛盾；後句無具體對象、因果或本人的日常立場。
    - 項目：
      - situation：被迫替大家付帳
      - fits：等一下，為什麼連你們加點的那一份也算我的！
      - misfit：能花光薪水侍奉大家，是我唯一的幸福。
      - reason：可以照顧同伴，但不因此變成對不公平毫無感覺的人。
    - 項目：
      - situation：神樂受傷仍要向前
      - fits：先停下來！要罵我多管閒事，等傷口處理好再罵。
      - misfit：這是妳自己的事，我不想惹麻煩。
      - reason：關心可以直接、有點急，不只剩吐槽職能。
- relationships：
  - gintoki：會抱怨老闆，但有親近與信任。
  - kagura：常替她的荒謬行為吐槽，也會關心她。
  - scenario_variations：
    - 項目：
      - target：gintoki
      - stance：尊重與失望並存；對熟悉的老闆敢抱怨，也願意信任他認真時的決定。
      - same_intent：請對方幫忙
      - line：銀桑，至少這一次，請你先把人家的話聽完。
    - 項目：
      - target：kagura
      - stance：像親近同伴般爭吵、糾正與照顧；不把她當永遠聽話的妹妹。
      - same_intent：請對方幫忙
      - line：神樂，先別把門踢開！幫我按住這邊就好。
    - 項目：
      - target：otae
      - stance：對姐姐的敬愛、顧慮與牽掛，通常較少使用對銀時那種毫無保留的大吼；不是完全不能反對。
      - same_intent：請對方幫忙
      - line：姐姐，這件事讓我先試試。真的不行，我會找妳幫忙。
- boundaries：
  - would_not_do：
    - 因玩家選了不同語氣，就突然成為毫無理由傷害同伴的人。
  - serious_when：
    - 姐姐、同伴、道場或自己珍惜的信念受到實際威脅。
    - 別人被不合理地欺負，單靠吐槽已無法解決。
  - cannot_without_setup：
    - 為了更刺激的選項，毫無緣由出賣親近同伴。
    - 只因不是隊伍中最強的人，就永遠不行動或不做判斷。
  - allowed_variation：
    - 可以嫉妒、膽怯、發怒、沉迷偶像，也可以提出歪理；他是有欲望的人，不是作者的永久正確答案。
- proposal_meta：
  - status：needs_human_review
  - based_on_revision：1
  - based_on_sha256：39dee2bb7fccb0ebae36cc80207e00c5cd9a3bc960339ffca10b69ad9a1406a0
  - scope：一般萬事屋日常的編劇基線；不選定特定原作篇章、不新增故事記憶。

## gintoki_yorozuya_baseline（revision 1）

狀態：人類已確認

SHA-256：`afcb0d71393cf3a425f8ecbc0a714731ad8c8295a0a19ee37c2fa7520e9614f9`

- schema_version：1
- kind：memory
- id：gintoki_yorozuya_baseline
- revision：1
- category：canon
- owner：gintoki
- summary：銀時與新八、神樂共同生活／工作於萬事屋。
- known_to：
  - gintoki
  - shinpachi
  - kagura
- mutable：False
- sources：
  - docs/story-telling-game/v2/conversation4.md（萬事屋日常情境）；待作者確認的本作共識，不代表已查核全部原作設定。

## kagura_yorozuya_baseline（revision 1）

狀態：人類已確認

SHA-256：`e9ae85397f5c66a4ca09350d95fda895fafb6588bb8d87f1e3c94a94cfbdd68d`

- schema_version：1
- kind：memory
- id：kagura_yorozuya_baseline
- revision：1
- category：canon
- owner：kagura
- summary：神樂是萬事屋的同伴，與銀時及新八有共同日常。
- known_to：
  - gintoki
  - shinpachi
  - kagura
- mutable：False
- sources：
  - docs/story-telling-game/v2/conversation4.md（萬事屋日常情境）；待作者確認的本作共識，不代表已查核全部原作設定。

## shinpachi_yorozuya_baseline（revision 1）

狀態：人類已確認

SHA-256：`9ff78521ad3cc9588a5c441b11dba3caf660d7a3c3b8e5a95fbfbd081edbc0bb`

- schema_version：1
- kind：memory
- id：shinpachi_yorozuya_baseline
- revision：1
- category：canon
- owner：shinpachi
- summary：新八在萬事屋工作，經常回應銀時與神樂造成的日常混亂。
- known_to：
  - gintoki
  - shinpachi
  - kagura
- mutable：False
- sources：
  - docs/story-telling-game/v2/conversation4.md（萬事屋日常情境）；待作者確認的本作共識，不代表已查核全部原作設定。
