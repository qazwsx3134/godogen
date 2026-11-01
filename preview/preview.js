'use strict';

fetch('/preview/status.json', { cache: 'no-store' })
  .then(response => {
    if (!response.ok) throw new Error('status unavailable');
    return response.json();
  })
  .then(status => {
    if (!status.godot_found) {
      document.getElementById('story-status').textContent =
        '找不到 Godot。可先開啟編輯器；驗證存檔或試玩前，請以 --godot 指定執行檔並重啟服務。';
    }
    if (status.vfx_ready) return;
    const link = document.getElementById('vfx-link');
    link.removeAttribute('href');
    link.setAttribute('aria-disabled', 'true');
    document.getElementById('vfx-status').textContent =
      '特效展示包尚未建立。請確認 Godot 4.7 與 Web 匯出範本，再重新啟動預覽服務。';
  })
  .catch(() => {
    document.getElementById('vfx-status').textContent = '無法確認特效展示包狀態，請檢查預覽服務是否仍在執行。';
  });
