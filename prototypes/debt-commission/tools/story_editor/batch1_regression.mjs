import assert from 'node:assert/strict';
export async function batch1Regression(browser, base, out) {
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, acceptDownloads: true });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', err => errors.push(err.message));
  page.on('dialog', dialog => dialog.accept());
  const open = async () => {
    await page.goto(base);
    await page.waitForFunction(() => window.StoryEditor);
    await page.evaluate(() => window.StoryEditor.ready);
  };
  const state = () => page.evaluate(() => JSON.parse(JSON.stringify({ story: StoryEditor.story, layout: StoryEditor.state.layout, dirty: StoryEditor.state.dirty })));
  const select = id => page.evaluate(id => { StoryEditor.centerOn(id, .8); StoryEditor.select({ type: 'node', id }); }, id);
  const stepText = () => page.locator('#inspector .step textarea').first();
  const drag = async (from, to) => { await page.mouse.move(from.x, from.y); await page.mouse.down(); await page.mouse.move(to.x, to.y, { steps: 12 }); await page.mouse.up(); };
  const center = async locator => { const r = await locator.boundingBox(); assert.ok(r); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; };
  const fixture = { id: 'batch1', version: 's-original', title: '第一批', entry: 'start', initial_flags: {}, nodes: {
    start: { title: '起點', steps: [{ op: 'say', speaker: 'gintoki', text: '保留原始台詞', source_id: 'P01', offscreen: false },
      { op: 'choice', prompt: '分支', options: [{ id: 'a', label: 'A', next: 'end' }, { id: 'b', label: 'B', next: 'end' }] }] },
    end: { title: '結尾', steps: [{ op: 'end', text: '完成' }] },
  } };
  try {
    await open();
    await page.evaluate(f => StoryEditor.loadStory(f, 'batch1.json'), fixture);
    const original = await state();
    await page.locator('#btnAddNode').click();
    assert.ok((await state()).story.nodes.node_1);
    await page.locator('#btnUndo').click();
    assert.deepEqual((await state()).story, fixture);
    assert.equal((await state()).dirty, false, 'undo to the imported content restores clean state');
    await page.locator('#btnRedo').click();
    assert.ok((await state()).story.nodes.node_1);
    await select('node_1');
    const idInput = page.locator('#inspector input[type=text]').first();
    await idInput.fill('renamed'); await idInput.press('Enter');
    assert.ok((await state()).story.nodes.renamed);
    await page.locator('#btnUndo').click();
    assert.ok((await state()).story.nodes.node_1);
    await page.locator('#btnRedo').click();
    await page.getByRole('button', { name: '刪除節點', exact: true }).click();
    assert.equal((await state()).story.nodes.renamed, undefined);
    await page.locator('#btnUndo').click();
    assert.ok((await state()).story.nodes.renamed, 'undo restores deleted node');
    await page.setInputFiles('#layoutOpen', { name: 'batch1.layout.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify({ story: 'batch1', nodes: { start: { x: 0, y: 0 }, end: { x: 900, y: 0 }, renamed: { x: 430, y: 350 } } })) });
    await page.waitForFunction(() => StoryEditor.state.layout.renamed.y === 350);
    await page.evaluate(() => StoryEditor.fit(.6));
    const beforeEdge = (await state()).story.nodes.start.steps[1].options[0].next;
    const port = page.locator('.card[data-node=start] .prow').first().locator('.dot');
    await drag(await center(port), await center(page.locator('.card[data-node=renamed] .head')));
    assert.equal((await state()).story.nodes.start.steps[1].options[0].next, 'renamed');
    await page.locator('#btnUndo').click();
    assert.equal((await state()).story.nodes.start.steps[1].options[0].next, beforeEdge);
    await page.locator('#btnRedo').click();
    const beforeMove = (await state()).layout.renamed;
    const head = await center(page.locator('.card[data-node=renamed] .head'));
    await drag(head, { x: head.x + 60, y: head.y + 40 });
    const moved = (await state()).layout.renamed;
    assert.notDeepEqual(moved, beforeMove);
    await page.locator('#btnUndo').click(); assert.deepEqual((await state()).layout.renamed, beforeMove);
    await page.locator('#btnRedo').click(); assert.deepEqual((await state()).layout.renamed, moved);
    console.log('ok  batch1 history: add/delete/rename/connect/drag undo and redo');

    await select('start');
    await stepText().focus();
    await stepText().press('End'); await stepText().pressSequentially('ABC');
    await stepText().press('Control+z');
    assert.equal((await state()).story.nodes.start.steps[0].text, fixture.nodes.start.steps[0].text, 'continuous typing is one undo');
    await page.locator('#btnRedo').click();
    assert.match((await state()).story.nodes.start.steps[0].text, /ABC$/);
    await page.locator('#searchInput').fill('ABC');
    await page.locator('#searchResults button').first().click();
    assert.equal(await page.evaluate(() => StoryEditor.state.sel.id), 'start');
    assert.equal(await page.locator('#inspector [data-step="0"].search-hit').count(), 1);
    assert.equal((await state()).story.nodes.start.steps[0].source_id, 'P01');
    await page.locator('#searchInput').fill('GINTOKI');
    assert.ok(await page.locator('#searchResults button').count());
    console.log('ok  batch1 grouped text undo + search text/role and jump to its step, unknown fields preserved');

    const draftBefore = await state();
    await page.reload(); await page.waitForFunction(() => window.StoryEditor?.story);
    await page.locator('#draftRecovery button').filter({ hasText: '復原草稿' }).click();
    assert.deepEqual((await state()).story, draftBefore.story);
    assert.deepEqual((await state()).layout, draftBefore.layout);
    assert.equal((await state()).dirty, true);
    console.log('ok  batch1 edited local document reload offers explicit draft recovery with layout');

    const exportedEvent = page.waitForEvent('download'); await page.locator('#btnExport').click();
    const download = await exportedEvent;
    const file = `${out}/batch1-saved.json`; await download.saveAs(file);
    assert.equal((await state()).dirty, true, 'download alone never acknowledges saving');
    await page.locator('#verifySaved').setInputFiles({ name: 'wrong.json', mimeType: 'application/json', buffer: Buffer.from('{}') });
    await page.getByText(/確認下載失敗：.*檔案內容與這次匯出不同/).waitFor();
    assert.equal((await state()).dirty, true);
    assert.match(await page.locator('#banner').innerText(), /檔案內容與這次匯出不同/);
    await page.locator('#verifySaved').setInputFiles(file);
    await page.waitForFunction(() => !StoryEditor.state.dirty);
    assert.equal((await state()).dirty, false);
    assert.equal(await page.locator('#exportPending').count(), 0);
    console.log('ok  batch1 download stays dirty until actual downloaded bytes match; wrong file refused');

    await select('start'); await stepText().fill('匯出版本');
    const olderDownloadEvent = page.waitForEvent('download'); await page.locator('#btnExport').click();
    const older = await olderDownloadEvent; const olderFile = `${out}/batch1-older.json`; await older.saveAs(olderFile);
    await stepText().fill('下載期間又修改');
    await page.locator('#verifySaved').setInputFiles(olderFile);
    await page.getByText('下載檔已比對成功，但頁面另有後續修改，請再次匯出。', { exact: true }).waitFor();
    assert.equal((await state()).dirty, true, 'confirming an older export must not clear newer edits');
    await page.evaluate(() => { window.originalObjectURL = URL.createObjectURL; URL.createObjectURL = () => { throw new Error('download denied'); }; });
    await page.locator('#btnExport').click();
    assert.match(await page.locator('#banner').innerText(), /下載失敗.*download denied/);
    assert.equal((await state()).story.nodes.start.steps[0].text, '下載期間又修改');
    assert.equal((await state()).dirty, true);
    await page.evaluate(() => { URL.createObjectURL = window.originalObjectURL; });
    console.log('ok  batch1 confirmation of older export and failed download both preserve newer dirty edits');

    // Force quota failure; error must survive selection and later successful edits cannot erase it while writes fail.
    await page.evaluate(() => { window.savedSetItem = Storage.prototype.setItem; Storage.prototype.setItem = function () { throw new DOMException('test quota', 'QuotaExceededError'); }; });
    await select('start'); await stepText().fill('空間不足仍留在記憶體');
    assert.match(await page.locator('#storageError').innerText(), /儲存失敗/);
    await select('end'); assert.equal(await page.locator('#storageError').count(), 1);
    assert.equal((await state()).dirty, true);
    await page.evaluate(() => { Storage.prototype.setItem = window.savedSetItem; });
    await select('start'); await stepText().fill('可復原草稿');
    assert.equal(await page.locator('#storageError').count(), 0, 'successful retry clears only storage warning');
    console.log('ok  batch1 quota failure stays visible without dropping edits; later successful save recovers');

    await page.evaluate(async () => { await StoryEditor.readStoryFile({ name: 'unreadable.json', text: async () => { throw new Error('read denied'); } }); });
    assert.match(await page.locator('#banner').innerText(), /讀檔失敗.*read denied/);
    assert.equal((await state()).story.nodes.start.steps[0].text, '可復原草稿');
    await page.evaluate(async () => {
      const slow = StoryEditor.readStoryFile({ name: 'slow.json', text: () => new Promise(resolve => { window.finishSlow = resolve; }) });
      window.slowRead = slow;
      await StoryEditor.readStoryFile({ name: 'fast.json', text: async () => JSON.stringify({ id: 'fast', version: '1', entry: 'start', nodes: { start: { steps: [{ op: 'end', text: '' }] } } }) });
      window.finishSlow(JSON.stringify({ id: 'slow', entry: 'start', nodes: {} })); await slow;
    });
    assert.equal((await state()).story.id, 'fast');
    console.log('ok  batch1 rejected file reads keep current story; stale slow read cannot replace newer document');

    // Simulate two project fetches completing in the wrong order, including the response body await.
    await page.evaluate(() => {
      window.nativeFetch = window.fetch; window.fetchResolvers = {};
      StoryEditor.state.stories = [{ id: 'slow', path: 'slow.json' }, { id: 'fast', path: 'fast.json' }];
      const picker = document.getElementById('storySelect'); picker.hidden = false;
      picker.replaceChildren(new Option('slow', 'slow'), new Option('fast', 'fast'));
      window.fetch = url => new Promise(resolve => { window.fetchResolvers[url.includes('slow') ? 'slow' : 'fast'] = resolve; });
      picker.value = 'slow'; picker.dispatchEvent(new Event('change'));
      picker.value = 'fast'; picker.dispatchEvent(new Event('change'));
      window.fetchResolvers.fast({ ok: true, text: async () => JSON.stringify({ id: 'fast2', version: '1', entry: 'end', nodes: { end: { steps: [{ op: 'end', text: '' }] } } }) });
    });
    await page.waitForFunction(() => StoryEditor.story.id === 'fast2');
    await page.evaluate(() => { window.fetchResolvers.slow({ ok: true, text: async () => '{"bad":true}' }); window.fetch = window.nativeFetch; });
    await page.waitForTimeout(100);
    assert.equal((await state()).story.id, 'fast2');
    console.log('ok  batch1 fast project switch wins over obsolete response');

    // Same-origin tab conflict must preserve the other tab's draft rather than overwrite it.
    await page.evaluate(f => StoryEditor.loadStory(f, 'conflict.json'), fixture);
    await select('start'); await stepText().fill('第一分頁');
    const other = await context.newPage(); await other.goto(base); await other.waitForFunction(() => window.StoryEditor);
    await other.evaluate(f => StoryEditor.loadStory(f, 'conflict.json'), fixture);
    await other.locator('#draftRecovery button').filter({ hasText: '復原草稿' }).click();
    await other.evaluate(() => StoryEditor.select({ type: 'node', id: 'start' }));
    await other.locator('#inspector .step textarea').first().fill('第二分頁');
    await stepText().fill('第一分頁稍後改');
    assert.match(await page.locator('#storageError').innerText(), /另一個分頁/);
    const stored = await page.evaluate(() => JSON.parse(localStorage.getItem('debtStoryEditor.draft.' + JSON.stringify(['conflict.json', 'batch1']))));
    assert.equal(stored.story.nodes.start.steps[0].text, '第二分頁');
    await other.close();
    console.log('ok  batch1 two-tab conflict keeps newer persisted draft and shows persistent warning');
    await page.evaluate(f => {
      const key = 'debtStoryEditor.draft.' + JSON.stringify(['corrupt.json', f.id]);
      localStorage.setItem(key, '{broken draft'); StoryEditor.loadStory(f, 'corrupt.json');
    }, fixture);
    assert.equal(await page.locator('#storageError').count(), 1);
    await select('start'); await stepText().fill('損壞草稿仍可編輯');
    const corruptRaw = await page.evaluate(() => localStorage.getItem('debtStoryEditor.draft.' + JSON.stringify(['corrupt.json', 'batch1'])));
    assert.equal(corruptRaw, '{broken draft', 'corrupt stored record is never silently overwritten');
    await page.getByRole('button', { name: '刪除損壞草稿（需確認）' }).click();
    assert.equal(await page.locator('#storageError').count(), 0);
    assert.equal((await state()).story.nodes.start.steps[0].text, '損壞草稿仍可編輯');
    console.log('ok  batch1 corrupt draft stays untouched until explicit removal; current edits survive');
    assert.deepEqual(errors, []);
    console.log('BATCH1 REGRESSIONS PASSED');
  } catch (err) {
    await page.screenshot({ path: `${out}/batch1-failure.png`, fullPage: true });
    console.log('BATCH1 FAILURE STATE', JSON.stringify(await state()));
    throw err;
  } finally { await context.close(); }
}
