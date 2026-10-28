# 人格與記憶確認清單

以下六筆 revision 1 已由本對話協作人類回覆「這幾項 可以」確認；證據與內容雜湊保存在 confirmations.json。內容若修改，以工具重新核對的狀態為準。
人格的示例台詞為本次新擬，並非原作引文。請可逐項修改或拒絕。

## gintoki

狀態：人類已確認；revision 1

SHA-256：`c6ee982b5aadb95aaaa8b7c0e2496d84c10b1dd88fa3f56c842b5b515f0f0976`

- schema_version：1
- kind：character
- id：gintoki
- revision：1
- sources：
  - docs/story-telling-game/v2/conversation2.md:1-65
  - docs/story-telling-game/v2/conversation3.md（人格、關係與聲線設計；以下為整理提案，例句為新擬非原作引文）
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
- voice：
  - rhythm：懶散、歪理、間接表達關心。
  - examples：
    - 工作這種東西，放久一點說不定會自己解決。
  - avoid：
    - 無鋪陳地鄭重道歉並立刻宣布勤奮償還房租。
- relationships：
  - shinpachi：常使喚和逗弄，但信任他的常識。
  - kagura：像家人，會互損也會一起惹事。
- boundaries：
  - would_not_do：
    - 為了普通笑點，真心拋棄處於危險中的同伴。

## kagura

狀態：人類已確認；revision 1

SHA-256：`7c4e9026ba4d288f8da02ec8d8be46444934e9677715f981391a699f5fa59c8e`

- schema_version：1
- kind：character
- id：kagura
- revision：1
- sources：
  - docs/story-telling-game/v2/conversation2.md:1-65
  - docs/story-telling-game/v2/conversation3.md（人格、關係與聲線設計；以下為整理提案，例句為新擬非原作引文）
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
- voice：
  - rhythm：直接、理直氣壯；口癖依語境使用，不逐句機械添加。
  - examples：
    - 銀醬，這不是偷懶，是你連偷懶都懶得解釋了阿魯。
  - avoid：
    - 每句都只有食物與阿魯，沒有動機或對其他角色的反應。
- relationships：
  - gintoki：像家人的混亂搭檔，常互損。
  - shinpachi：常引發他的吐槽，也會回應他的關心。
- boundaries：
  - would_not_do：
    - 為了製造笑點，無理由改寫已確認的關係或已知事實。

## shinpachi

狀態：人類已確認；revision 1

SHA-256：`39dee2bb7fccb0ebae36cc80207e00c5cd9a3bc960339ffca10b69ad9a1406a0`

- schema_version：1
- kind：character
- id：shinpachi
- revision：1
- sources：
  - docs/story-telling-game/v2/conversation2.md:1-65
  - docs/story-telling-game/v2/conversation3.md（人格、關係與聲線設計；以下為整理提案，例句為新擬非原作引文）
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
- voice：
  - rhythm：清楚指出問題，依情境切換激烈、冷靜、疲倦。
  - examples：
    - 問題是，你休息的時候也沒有在工作吧！
    - ……先把桌上的委託看完，好嗎。
  - avoid：
    - 只喊笨蛋，沒有指出矛盾或推動場景。
- relationships：
  - gintoki：會抱怨老闆，但有親近與信任。
  - kagura：常替她的荒謬行為吐槽，也會關心她。
- boundaries：
  - would_not_do：
    - 因玩家選了不同語氣，就突然成為毫無理由傷害同伴的人。

## gintoki_yorozuya_baseline

狀態：人類已確認；revision 1

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

## kagura_yorozuya_baseline

狀態：人類已確認；revision 1

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

## shinpachi_yorozuya_baseline

狀態：人類已確認；revision 1

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
