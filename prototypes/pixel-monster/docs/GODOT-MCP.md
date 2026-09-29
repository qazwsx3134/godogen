# Godot MCP 安裝指南（macOS / Godot 4.7 / Codex）

本文件針對這個專案。

- Repo：`/Users/peter/repo/godot/godogen`
- Godot 專案：`/Users/peter/repo/godot/godogen/prototypes/pixel-monster`
- Godot 執行檔：`/Applications/Godot.app/Contents/MacOS/Godot`
- MCP 用戶端：Codex CLI

查閱日期：2026-09-24。以下命令只供使用者自行執行；本次沒有下載套件、安裝外掛、修改 Codex 全域設定或啟動 Godot MCP。

## 先選一個：兩個工具不是同一個實作

| 工具 | 角色 | 這個專案需要的 Godot 設定 | 連線方式 |
| --- | --- | --- | --- |
| [Godot MCP Toolkit](https://github.com/NPGameDev/godot-mcp-toolkit)（[Asset Store](https://store.godotengine.org/asset/npgamedev/godot-mcp-toolkit/)） | Godot editor 外掛，加上 `@npgamedev/godot-mcp-server` bridge；可操作 editor、scene、node、script、resource，也有 runtime/playtest 通道 | 必須在 editor 的 Project Settings → Plugins 啟用 | Codex 啟動本機 stdio bridge；bridge 再連 editor 的 localhost WebSocket |
| [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) | 獨立 Node MCP server；透過 Godot CLI/GDScript 做 editor 啟動、執行專案、debug output、project/scene 操作 | README 沒有要求安裝 Godot editor 外掛或開啟某個 Project Settings plugin | Codex 啟動 `npx @coding-solo/godot-mcp` |

本專案建議先用 **Godot MCP Toolkit**：它明確支援 Godot 4.7、能連到已開啟的 editor，並提供只讀模式。需要較輕量的 CLI 啟動、執行與 debug 流程時，再單獨測試 Coding-Solo 版本。

兩者功能有重疊（例如啟動/執行 Godot、查專案、scene 操作），因此不建議同時啟用在同一個 Codex session 或同一個工作目錄。兩個不同的 Codex server 名稱只能避免設定項目名稱相同，不能避免兩個 agent 同時修改同一個專案，也不能保證工具名稱在 Codex 介面中不會語意重疊。

Toolkit 文件記載 editor server 會在 `127.0.0.1` 的 `6550–6560` 範圍監聽，runtime server 會使用 `6570–6585` 範圍；bridge 預設透過專案 registry 自動尋找，不要自行硬編 port。Coding-Solo 的 README 沒有公布 MCP listener port，所以不能宣稱它一定不會衝突。若要 A/B 測試，請一次只啟動一個 server，使用不同 Codex 名稱，並分開專案複本或 worktree。

## 共通 prerequisite

- 使用 Godot 4.7 desktop editor；本文件不把 MCP 當成 iOS runtime 元件。
- 使用 Node.js 與 npm。
- 從專案根目錄 `/Users/peter/repo/godot/godogen/prototypes/pixel-monster` 啟動 Codex，讓 server 能辨認含有 `project.godot` 的目錄。
- 第一次使用 `npx` 可能需要網路及 npm 的套件取得流程；這次沒有執行或預先快取任何套件。
- 先用只讀查詢做驗證。MCP server 可能具有建立 scene、加 node、保存 scene 等寫入能力；不要在未確認連線對象時給寫入指令。

本機唯讀版本檢查為 Node.js `v24.14.0`、npm `11.9.0`、Codex CLI `0.155.1`、Godot `4.7.stable.official.5b4e0cb0f`，已符合兩套工具公開的版本前提。

本次唯讀檢查顯示此專案目前沒有 `.mcp.json`，`project.godot` 也沒有 MCP 或 editor-plugin 設定；這不是安裝結果，只是目前基線。

## A. Godot MCP Toolkit

### Prerequisite

Toolkit 作者的 Asset Store 頁面列出 Godot 4.2–4.7 desktop 與 Node.js 22+；作者 README 也寫明最低 4.2、4.7.0 有測試紀錄。這與本專案的 Godot 4.7 目標相符，但仍不是這個專案已完成的相容性驗證。需要：

- Godot 4.7 editor 已安裝並能開啟上述專案。
- Node.js 22 或更新版本、npm、Codex CLI。
- 若使用預設 `npx` bridge，第一次連線可取得 `@npgamedev/godot-mcp-server`；作者也提供全域安裝選項，但本指南不要求全域安裝。

Asset Store 在查閱日把目前版本標為 unstable；建議先以只讀模式完成下方最小驗證，再開啟寫入工具。

### 安裝

以下是需要使用者在 Godot UI 手動完成的步驟：

1. 開啟 `/Users/peter/repo/godot/godogen/prototypes/pixel-monster/project.godot`。
2. 在 editor 的 **AssetLib** 搜尋 `Godot MCP Toolkit`，按 **Download**，再按 **Install**。
3. 若不用 AssetLib，改從 Toolkit GitHub Releases 下載，依作者說明解壓到本專案的 `addons/` 目錄。不要把整個 repo 任意放到專案根目錄，也不要猜測外掛資料夾名稱。
4. 若 editor 要求重新載入或重開專案，照 UI 指示完成。

### Godot editor 設定（手動）

1. 開啟 **Project → Project Settings → Plugins**。
2. 找到 **Godot MCP Toolkit**，勾選 **Active**。
3. 確認底部出現 MCP dock，並在 Output 看到類似 `[MCPServer] listening on 127.0.0.1:6550` 的訊息。實際 port 可能在 `6550–6560`，以 dock/Output 當下顯示為準。
4. Toolkit 的 **Project → Tools → MCP Toolkit → Write `.mcp.json`** 可產生通用 client 設定。對本文件的 Codex 路線，優先使用下一節的 `codex mcp add`；不要同時新增兩個等效 server entry。

Toolkit 的 runtime 通道是另一個只在 debug playtest 中出現的 localhost server，作者文件列出 `6570–6585`。不要在 Godot export 或 iOS 裝置上期待這個 editor/runtime MCP 外掛存在；作者說明 export 會移除 addon/token。

若要先限制 Toolkit 的寫入工具，可在 Codex server 的環境設定加入 `GODOT_MCP_READ_ONLY=1`。這是 server 端限制，不是 Codex prompt 的安全承諾。

### Codex MCP 設定

Toolkit 作者的 Codex client 文件給出的 stdio 設定是：

~~~bash
cd /Users/peter/repo/godot/godogen/prototypes/pixel-monster
codex mcp add godot-mcp-toolkit -- npx -y @npgamedev/godot-mcp-server
~~~

若要以只讀模式開始，可把同一個 entry 改成（不要再另外註冊第二個 Toolkit server）：

~~~bash
codex mcp add godot-mcp-toolkit --env GODOT_MCP_READ_ONLY=1 -- npx -y @npgamedev/godot-mcp-server
~~~

若 Codex 啟動 server 時沒有把目前目錄傳給子程序，可依 Toolkit 文件改用明確的專案路徑環境變數：

~~~bash
codex mcp add godot-mcp-toolkit --env GODOT_MCP_PROJECT_PATH=/Users/peter/repo/godot/godogen/prototypes/pixel-monster -- npx -y @npgamedev/godot-mcp-server
~~~

上面 `codex mcp add` 的 `--env KEY=VALUE` 與 `--` 形式已由本機安裝的 `codex mcp --help` 確認；執行它會改寫 Codex 設定，本次沒有執行。Toolkit 作者另記載設定檔為 `~/.codex/config.toml`，可信任專案也可能使用專案 `.codex/config.toml`；實際 scope 以目前 Codex 版本的設定與信任狀態為準。

### 啟動

1. 由使用者在 Godot editor 開啟專案並保持 Toolkit plugin Active。
2. 確認 MCP dock 顯示 listening，再重新連線或重啟 Codex。
3. 用下列唯讀命令確認 Codex 註冊狀態：

   ~~~bash
   codex mcp list
   ~~~

4. 不要手動指定 Toolkit editor port；官方 bridge 的預設流程會自動發現。只有在兩端同時設定相同 port 時才可 pin port。

### 最小驗證

先確認 Godot dock 的 peer/client 計數增加，且 Output 沒有 server error。接著在 Codex 輸入：

> 只讀檢查目前連線的 Godot 專案名稱、主場景路徑與 editor 版本；不要啟動 playtest、建立/修改/保存任何檔案。

通過條件是回覆的專案確實為 `prototypes/pixel-monster`，而不是另一個開啟中的 Godot 專案；Codex 的 MCP server list 有 `godot-mcp-toolkit`；Godot dock 有 client 連線。這個最小驗證不代表已驗證 iOS export、簽名或實機行為。

### 卸載

以下仍需使用者手動完成：

1. 先在 Codex 設定移除 server（命令格式由本機 Codex help 確認）：

   ~~~bash
   codex mcp remove godot-mcp-toolkit
   ~~~

2. 在 Godot **Project → Project Settings → Plugins** 取消 **Active**。
3. 關閉 Godot editor，再從本專案 `addons/` 移除實際安裝的 Toolkit addon 資料夾；只刪除確認屬於 Toolkit 的資料夾。
4. 若曾由 wizard 產生 `.mcp.json`，只在它不再被其他 MCP client 使用時移除，或刪除其中的 Toolkit entry。不要清空整個 npm cache。

## B. Coding-Solo/godot-mcp

### Prerequisite

Coding-Solo README 只要求已安裝 Godot、Node.js `>=18.0.0`、npm，以及支援 MCP 的 AI agent；它沒有宣稱 Godot 4.7 的測試矩陣，也沒有文件化固定 MCP port。因此本專案使用 Godot 4.7 屬於待驗證組合，不應把它寫成作者保證。

`GODOT_PATH` 可指定 Godot executable；本機目標值是：

`/Applications/Godot.app/Contents/MacOS/Godot`

原 repo 的 `package.json` 目前宣告 package version `0.1.1`，但 README 的 `npx @coding-solo/godot-mcp` 沒有 pin 版本；不要把 repo 版本當成 npm 解析結果的固定承諾。

### 安裝

Coding-Solo 的 README 沒有要求安裝 Godot addon；它是獨立 Node MCP server。直接使用作者文件中的 npx 入口即可：

~~~bash
cd /Users/peter/repo/godot/godogen/prototypes/pixel-monster
codex mcp add godot-coding-solo --env GODOT_PATH=/Applications/Godot.app/Contents/MacOS/Godot -- npx @coding-solo/godot-mcp
~~~

這裡刻意保留作者 README 的 `npx @coding-solo/godot-mcp`，沒有自行加 `-y` 或版本號。若使用者選擇從原始碼建置，README 給出的流程是：

~~~bash
git clone https://github.com/Coding-Solo/godot-mcp.git
cd godot-mcp
npm install
npm run build
~~~

建置後作者說明 client 應指向 `build/index.js`；本文件沒有替使用者 clone 或安裝依賴。`DEBUG=true` 只代表開啟 server 詳細 log，不是只讀模式。

### Godot editor 設定（手動）

原 README 沒有 Project Settings、Plugins 或 MCP dock 的步驟，因此這個工具沒有可據來源填寫的 Godot UI 啟用設定。使用者只需確認 Godot executable 可被 `GODOT_PATH` 使用，並且要操作的目錄含有 `project.godot`。

若已經開著 Toolkit 控制的 editor，先停止其中一個 MCP 流程再使用本工具；不要讓兩個 server 同時對 `pixel-monster` 啟動/停止/保存。

### Codex MCP 設定

上面的 `codex mcp add godot-coding-solo` 是把 README 的通用 MCP 設定轉成目前本機 Codex CLI 的 stdio 語法。需要 debug log 時可加上作者文件中的環境變數：

~~~bash
codex mcp add godot-coding-solo --env GODOT_PATH=/Applications/Godot.app/Contents/MacOS/Godot --env DEBUG=true -- npx @coding-solo/godot-mcp
~~~

不要與 `godot-mcp-toolkit` 同時註冊後再讓 Codex 自行選；若已選 Toolkit，請先移除或停用另一個 entry。這個 repo 沒有文件化 `GODOT_MCP_READ_ONLY`，所以不能把 Toolkit 的只讀環境變數套用到 Coding-Solo。

### 啟動

1. 從 `prototypes/pixel-monster` 根目錄啟動或重新連線 Codex。
2. 執行 `codex mcp list`，確認只有目前要測試的 server entry。
3. 由 Codex 使用 server 的 Godot 操作；README 列出的能力包括 `launch_editor`、`run_project`、`get_debug_output`、`stop_project`、`get_godot_version`、`list_projects`、`get_project_info` 等。具體工具清單以實際 MCP handshake 為準。

Coding-Solo README 描述它會直接使用 Godot CLI 命令及 bundled GDScript；它沒有說明會連到 Toolkit 的 6550/6570 port，也沒有說明兩者可互通。因此不要假設它能接管已由 Toolkit 開啟的 editor。

### 最小驗證

先執行：

~~~bash
codex mcp list
~~~

再在 Codex 輸入：

> 只讀回報目前 Godot 版本與 `pixel-monster` 專案資訊，不建立 scene、不加 node、不保存 scene、不啟動遊戲。

README 明確列出 `get_godot_version` 與 `get_project_info` 類能力；通過條件是回覆的 executable/專案路徑與目標一致，且沒有把另一份 `project.godot` 當成目前專案。若找不到 Godot，先檢查 `GODOT_PATH`；若需要 server 端診斷，再以 `DEBUG=true` 重連。

### 卸載

1. 移除 Codex entry：

   ~~~bash
   codex mcp remove godot-coding-solo
   ~~~

2. 這個工具沒有本文件可確認的 Godot addon，所以沒有 Project Settings plugin 要停用。
3. 若使用 source build，停止 Codex 後刪除使用者自己 clone 的 `godot-mcp` 工作目錄；不要刪除本專案或其他 npm cache。

## Codex 設定與安全界線

OpenAI 官方 Codex 文件使用 `codex mcp add` 加入 MCP server、使用 `codex mcp list` 驗證；本機 `codex mcp --help` 另外確認了本文件使用的 `--env`、`remove` 語法。這些命令會改動 Codex 設定，必須由使用者自行執行；本次沒有讀寫全域 config。

兩個 server 都是第三方本機工具。Toolkit README 說 editor listener 限制在 localhost，並提供 session token、專案檔案邊界與 read-only server 變數；這不等同於安全審計。Coding-Solo README 沒有提供同等的 port、token 或只讀保證。第一次測試請使用乾淨的工作副本、明確的絕對 Godot 路徑及只讀 prompt，並觀察 Godot Output 與 Codex server log。

## 來源與未確認事項

第一手/原始來源：

- [Godot Asset Store：Godot MCP Toolkit](https://store.godotengine.org/asset/npgamedev/godot-mcp-toolkit/)
- [Toolkit 原始碼與 README](https://github.com/NPGameDev/godot-mcp-toolkit)
- [Toolkit 架構說明](https://npgamedev.github.io/godot-mcp-toolkit/architecture/)
- [Toolkit Codex/client 設定](https://npgamedev.github.io/godot-mcp-server/mcp-clients/)
- [Coding-Solo/godot-mcp README](https://github.com/Coding-Solo/godot-mcp/blob/main/README.md)（[raw README](https://raw.githubusercontent.com/Coding-Solo/godot-mcp/main/README.md)）
- [Coding-Solo/godot-mcp package.json](https://raw.githubusercontent.com/Coding-Solo/godot-mcp/main/package.json)
- [OpenAI Codex 官方 Docs MCP 文件](https://developers.openai.com/learn/docs-mcp)

仍未確認的事項：

- 沒有實際安裝、下載、MCP handshake 或在本專案開啟外掛；因此不能宣稱兩者任何一個已在本機工作。
- Toolkit 作者的 client 頁面把 Codex 區段標為「documented, not yet verified」；Codex 版本更新後，config scope、信任規則、工具呈現方式仍需實測。
- Coding-Solo 原 repo 沒有 Godot 4.7 測試聲明、MCP listener port、與 Toolkit 的互通/衝突保證；Godot 4.7、已開啟 editor 及 iOS 專案的組合必須另做最小驗證。
- 沒有驗證兩者同時啟用時的實際 tool name 前綴、Codex 選擇策略、port 行為或寫入競爭；故本指南採一次只啟用一個的保守流程。
