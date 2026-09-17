#!/usr/bin/env bash
# 匯出 Web 版並在 LAN 上開一個 HTTPS server，讓 iPhone Safari 連得到。
#
# **必須是 HTTPS。** Godot Web 需要 secure context，而 secure context 只認 https://
# 和 localhost——手機連過來用的是 LAN IP，所以純 http 會在載入時就死掉：
#   "the following features required to run godot projects on the Web are missing:
#    secure context - check web server config (use HTTPS)"
#
# thread support 是關的，所以**不需要** COOP/COEP header（ADR 0004 選這個組合的實際
# 好處）。要的只有 HTTPS 本身，而那是另一件事——兩者常被混為一談。
#
# 憑證由 Caddy 的內部 CA 簽，不裝進系統鑰匙圈（那是系統安全設定的變更）。
# iPhone 上第一次會看到憑證警告：點「顯示詳細資訊」→「瀏覽此網站」。
# 點過之後 origin 就是 https，secure context 成立。
set -euo pipefail

GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# 輸出留在試作目錄內：prototype-code.md 明文禁止試作改動 prototypes/ 以外的檔案。
OUT="$ROOT/build/web"
PORT=${PORT:-8443}

command -v caddy >/dev/null || { echo "需要 caddy：brew install caddy"; exit 1; }

mkdir -p "$OUT"
echo "==> 匯出 Web（Compatibility / thread support off / 無 VRAM 壓縮）"
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$OUT/index.html"

IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")

pkill -f "caddy run --config $ROOT/tools/Caddyfile" 2>/dev/null || true
SERVE_HOST="$IP" SERVE_PORT="$PORT" SERVE_ROOT="$OUT" \
	caddy run --config "$ROOT/tools/Caddyfile" &
CADDY_PID=$!
trap 'kill $CADDY_PID 2>/dev/null || true' EXIT
sleep 3

cat <<EOF

==> 手機打開這個網址（要同一個網路）：

    https://$IP:$PORT/

    第一次會看到憑證警告（自簽）：顯示詳細資訊 → 瀏覽此網站。
    第一次載入要抓約 39 MB 的 wasm，白畫面十幾秒是正常的。

    除錯：Mac 與 iPhone 用 USB 相接，iPhone 設定 > Safari > 進階 > 網頁檢閱器，
    然後 Mac 的 Safari > 開發 > <你的 iPhone>。那給的是 iOS 上真正的 console 與時間軸。

EOF
wait $CADDY_PID
