# 第三方音效與修改紀錄

以下素材各自保留原作者授權；本專案程式的授權不替換音效授權。來源由使用者提供，2026-11-11 整理。處理後版本位於 `runtime/`；原始檔 SHA-256、裁切區間、增益、輸出量測與雜湊見 `manifest.json`。

| 原始素材／處理後版本 | 作者與來源 | 授權／說明 |
|---|---|---|
| `ai-start-moving.wav`、`ai-talking.wav` → `ai_boot.ogg`、`ai_radio.ogg` | Hove Audio — [Free SCI-FI UI Sound Effects Pack](https://hoveaudio.itch.io/free-sci-fi-ui-sound-effects-pack) | 原作者頁面允許用於各種專案，並在商用修改問題下說明為 royalty-free；屬作者自訂使用說明，未宣稱為 CC0。署名 Hove Audio。 |
| `explodemini.wav` → `explosion.ogg` | Michel Baradari，qubodup 提交 — [2 High Quality Explosions](https://opengameart.org/content/2-high-quality-explosions) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/)；署名 Michel Baradari，保留來源與授權連結，修改如下。 |
| `impactGlass_heavy_001.ogg` → `hit_heavy.ogg` | Kenney — Impact Sounds 1.0；隨附 [License.txt](hit/License.txt)，[Kenney](https://kenney.nl/) | [CC0](https://creativecommons.org/publicdomain/zero/1.0/)。 |
| `417688__superphat__lightmachinegun1.wav` → `scout_gun_a/b/c.ogg`、`scout_gun_burst.ogg` | SuperPhat — [LightMachineGun1.wav](https://freesound.org/people/SuperPhat/sounds/417688/) | CC0，依原始 Freesound 素材頁。 |
| `557594__breviceps__battle-mech-walks-fast-slow-sequence.wav` → `mech_step_a/b.ogg`、`mech_walk_sequence.ogg` | Breviceps — [Battle Mech walks (fast & slow sequence)](https://freesound.org/people/Breviceps/sounds/557594/) | CC0，依原始 Freesound 素材頁。 |
| `robot1.wav`、`robotstep3.wav`、`jumpland44100.mp3` → `mech_servo.ogg`、`mech_contact.ogg`、`mech_land.ogg` | Lee Barkovich，來源依隨附 [info.txt](machine-walk/info.txt)：[Berklee44Barkovich](https://archive.org/details/Berklee44Barkovich)，由 OpenGameArt.org 分發 | 隨附資料記載 CC BY 3.0；保留其署名與來源，未額外宣稱已逐檔核對原始包。 |

本專案修改：裁切較長錄音中的單發／短點射與短步伐、轉單聲道 44.1 kHz、去直流偏移、RMS 增益配對（受 -6 dBFS 編碼前峰值上限限制）、短淡入淡出及 Vorbis 品質 4 壓縮；AI 與原始走路整段另保留處理後版本。沒有生成新的 AI 聲音。

可用於遊戲署名的文字：

> Sound effects: Hove Audio; Michel Baradari (CC BY 3.0, via qubodup / OpenGameArt); Lee Barkovich (CC BY 3.0, via OpenGameArt); Kenney, SuperPhat and Breviceps (CC0). Edited and encoded for walker-tps. Source and license links are listed in assets/sound/CREDITS.md.

發佈遊戲時請隨附這份署名與相關連結；不要把這些第三方音效標成自行創作。
