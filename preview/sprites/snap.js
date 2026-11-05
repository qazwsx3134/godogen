// 像素對齊：把 AI 生成的「假像素圖」吸附到真正的像素格。
// 流程移植自 spritefusion-pixel-snapper（MIT，Hugo Duprez，https://github.com/Hugo-Dz/spritefusion-pixel-snapper）：
//   1. 先量化成 16 色去掉雜訊（k-means，抽樣擬合）
//   2. 灰階梯度投影成 x／y 剖面，取峰值間距的中位數當格距
//   3. walk：從每個預期格線往附近找最強的邊緣當切點（格線可以跟著 AI 圖的漂移）
//   4. 每格取出現最多的顏色
// 授權聲明見同資料夾 THIRD_PARTY.md。純函式，瀏覽器與 Node 都能用（測試：node preview/sprites/snap_test.mjs）。
;(function (root) {
  'use strict'

  const CFG = {
    analysisColors: 16,
    peakThreshold: 0.2, // 峰值至少是最高峰的 20%
    peakMinDistance: 4, // 峰值之間至少隔 4 px
    searchRatio: 0.35, // walk 搜尋範圍＝格距 × 0.35
    minSearch: 2,
    strength: 0.5, // 搜尋範圍內的最強邊緣要高於平均的 0.5 倍才採用
    maxStepRatio: 1.8,
    realPixelError: 16, // 對齊後放大回去、像素色差的第 75 百分位數超過這個值（實測：真像素圖 23～55，AI 假像素圖 2～10），就當作原圖已經是真像素
  }

  function rng(seed) {
    let a = seed >>> 0
    return () => {
      a = (a + 0x6d2b79f5) >>> 0
      let t = Math.imul(a ^ (a >>> 15), a | 1)
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296
    }
  }

  /** k-means 量化到 k 色：用最多 20000 個不透明像素擬合中心，再套到全圖。k <= 0 時原樣回傳。 */
  function quantize(img, k, iterations = 15) {
    if (!k || k <= 0) return img
    const d = img.data
    const opaque = []
    for (let i = 0; i < d.length; i += 4) if (d[i + 3] >= 128) opaque.push(i)
    if (!opaque.length) return img
    const r = rng(42)
    const sample = opaque.length > 20000 ? Array.from({ length: 20000 }, () => opaque[Math.floor(r() * opaque.length)]) : opaque
    k = Math.min(k, sample.length)
    const dist2 = (i, c) => (d[i] - c[0]) ** 2 + (d[i + 1] - c[1]) ** 2 + (d[i + 2] - c[2]) ** 2
    // 初始化：從樣本裡依序挑離現有中心最遠的點
    let centers = [[d[sample[0]], d[sample[0] + 1], d[sample[0] + 2]]]
    while (centers.length < k) {
      let far = sample[0]
      let best = -1
      for (const i of sample) {
        let m = Infinity
        for (const c of centers) m = Math.min(m, dist2(i, c))
        if (m > best) (best = m), (far = i)
      }
      if (best <= 0) break
      centers.push([d[far], d[far + 1], d[far + 2]])
    }
    const nearest = (i) => {
      let bi = 0
      let bd = Infinity
      for (let c = 0; c < centers.length; c++) {
        const v = dist2(i, centers[c])
        if (v < bd) (bd = v), (bi = c)
      }
      return bi
    }
    for (let it = 0; it < iterations; it++) {
      const sum = centers.map(() => [0, 0, 0, 0])
      for (const i of sample) {
        const s = sum[nearest(i)]
        s[0] += d[i]
        s[1] += d[i + 1]
        s[2] += d[i + 2]
        s[3]++
      }
      centers = centers.map((c, j) => (sum[j][3] ? [sum[j][0] / sum[j][3], sum[j][1] / sum[j][3], sum[j][2] / sum[j][3]] : c))
    }
    const out = new Uint8ClampedArray(d)
    for (const i of opaque) {
      const c = centers[nearest(i)]
      out[i] = Math.round(c[0])
      out[i + 1] = Math.round(c[1])
      out[i + 2] = Math.round(c[2])
      out[i + 3] = 255
    }
    for (let i = 0; i < d.length; i += 4) if (d[i + 3] < 128) out[i + 3] = 0
    return { width: img.width, height: img.height, data: out }
  }

  /** 灰階梯度（[-1, 0, 1]）投影：每一欄／每一列的梯度總和。透明像素當 0。 */
  function profiles(img) {
    const { width: w, height: h, data: d } = img
    const gray = new Float64Array(w * h)
    for (let i = 0; i < w * h; i++) gray[i] = d[i * 4 + 3] ? 0.299 * d[i * 4] + 0.587 * d[i * 4 + 1] + 0.114 * d[i * 4 + 2] : 0
    const px = new Float64Array(w)
    const py = new Float64Array(h)
    for (let y = 0; y < h; y++) for (let x = 1; x < w - 1; x++) px[x] += Math.abs(gray[y * w + x + 1] - gray[y * w + x - 1])
    for (let x = 0; x < w; x++) for (let y = 1; y < h - 1; y++) py[y] += Math.abs(gray[(y + 1) * w + x] - gray[(y - 1) * w + x])
    return [px, py]
  }

  function peaks(prof) {
    let max = 0
    for (const v of prof) max = Math.max(max, v)
    if (!max) return []
    const out = []
    for (let i = 1; i < prof.length - 1; i++)
      if (prof[i] > max * CFG.peakThreshold && prof[i] > prof[i - 1] && prof[i] > prof[i + 1]) {
        if (!out.length || i - out[out.length - 1] >= CFG.peakMinDistance) out.push(i)
      }
    return out
  }

  function stepSize(prof) {
    const p = peaks(prof)
    if (p.length < 2) return null
    const diffs = p
      .slice(1)
      .map((v, i) => v - p[i])
      .sort((a, b) => a - b)
    return diffs[Math.floor(diffs.length / 2)]
  }

  /** 沿剖面逐格找切點。第一個明顯邊緣若在一格之內，就從那裡開始（處理偏移）。 */
  function walk(prof, step, limit) {
    let mean = 0
    for (const v of prof) mean += v
    mean /= prof.length || 1
    const cuts = [0]
    const first = peaks(prof)[0]
    let pos = 0
    if (first !== undefined && first > 0 && first < step * 0.95) {
      cuts.push(first)
      pos = first
    }
    const win = Math.max(step * CFG.searchRatio, CFG.minSearch)
    while (pos < limit) {
      const target = pos + step
      if (target >= limit - step * 0.5) {
        cuts.push(limit)
        break
      }
      const a = Math.max(Math.floor(target - win), Math.floor(pos) + 1)
      const b = Math.min(Math.ceil(target + win), limit - 1)
      let best = -1
      let bi = a
      for (let i = a; i <= b; i++) if (prof[i] > best) (best = prof[i]), (bi = i)
      if (best > mean * CFG.strength) {
        cuts.push(bi)
        pos = bi
      } else {
        cuts.push(Math.round(target))
        pos = target
      }
    }
    return [...new Set(cuts)].sort((x, y) => x - y)
  }

  /** 手動指定格距與偏移時的等距切點。 */
  function uniformCuts(limit, size, offset) {
    const cuts = [0]
    if (offset > 0.5) cuts.push(Math.round(offset))
    for (let x = offset + size; x < limit - size * 0.5; x += size) cuts.push(Math.round(x))
    cuts.push(limit)
    return [...new Set(cuts)].sort((a, b) => a - b)
  }

  /** 平均格寬（不算頭尾可能不完整的兩格）。 */
  function avgStep(cuts) {
    if (cuts.length < 4) return (cuts[cuts.length - 1] - cuts[0]) / Math.max(1, cuts.length - 1)
    return (cuts[cuts.length - 2] - cuts[1]) / (cuts.length - 3)
  }

  /**
   * 兩張同尺寸圖、每個像素平均通道色差的第 75 百分位數（只算原圖不透明的像素）。
   * 少數格線錯開不影響結果；真像素圖被壓扁時大部分像素都會變色，值會很高。
   */
  function reconstructionError(a, b) {
    const hist = new Uint32Array(256)
    let n = 0
    for (let i = 0; i < a.data.length; i += 4)
      if (a.data[i + 3] >= 128) {
        const v = (Math.abs(a.data[i] - b.data[i]) + Math.abs(a.data[i + 1] - b.data[i + 1]) + Math.abs(a.data[i + 2] - b.data[i + 2])) / 3
        hist[Math.min(255, Math.round(v))]++
        n++
      }
    let acc = 0
    for (let v = 0; v < 256; v++) if ((acc += hist[v]) >= n * 0.75) return v
    return 0
  }

  const identity = (n) => Array.from({ length: n + 1 }, (_, i) => i)

  /** 自動偵測格子：回傳格距、偏移與實際切點（cols／rows）。已經是真像素圖時格距＝1。 */
  function detectGrid(img) {
    const [px, py] = profiles(quantize(img, CFG.analysisColors))
    let sx = stepSize(px)
    let sy = stepSize(py)
    if (sx && sy) {
      if (Math.max(sx / sy, sy / sx) > CFG.maxStepRatio) sx = sy = Math.min(sx, sy)
      else sx = sy = (sx + sy) / 2
    } else sx = sy = sx || sy || Math.max(1, Math.min(img.width, img.height) / 64)
    const cols = walk(px, sx, img.width)
    const rows = walk(py, sy, img.height)
    const sizeX = avgStep(cols)
    const sizeY = avgStep(rows)
    // 驗證：用這組格子對齊再放大回去，和原圖差太多代表會抹掉真細節＝原圖已經是真像素
    const err = reconstructionError(img, expand(snap(img, { cols, rows }), cols, rows))
    if (err > CFG.realPixelError)
      return { size: 1, sizeX: 1, sizeY: 1, offsetX: 0, offsetY: 0, cols: identity(img.width), rows: identity(img.height), alreadyPixel: true, err }
    return {
      err,
      size: (sizeX + sizeY) / 2,
      sizeX,
      sizeY,
      offsetX: cols[1] < sizeX * 0.95 ? cols[1] : 0,
      offsetY: rows[1] < sizeY * 0.95 ? rows[1] : 0,
      cols,
      rows,
    }
  }

  /**
   * 依切點（或手動的格距＋偏移）取樣：用量化後的顏色投票找出格子裡最多的那一群，
   * 輸出那一群在原圖裡的平均色（1×1 時就是原色，不會被壓成 16 色）；透明佔多數就輸出透明。
   */
  function snap(img, grid) {
    const cols = grid.cols || uniformCuts(img.width, grid.sizeX ?? grid.size, grid.offsetX ?? 0)
    const rows = grid.rows || uniformCuts(img.height, grid.sizeY ?? grid.size, grid.offsetY ?? 0)
    const q = quantize(img, CFG.analysisColors).data
    const d = img.data
    const w = img.width
    const nx = cols.length - 1
    const ny = rows.length - 1
    const out = new Uint8ClampedArray(nx * ny * 4)
    for (let cy = 0; cy < ny; cy++)
      for (let cx = 0; cx < nx; cx++) {
        const votes = new Map()
        for (let y = rows[cy]; y < rows[cy + 1]; y++)
          for (let x = cols[cx]; x < cols[cx + 1]; x++) {
            const i = (y * w + x) * 4
            const key = d[i + 3] < 128 ? -1 : (q[i] << 16) | (q[i + 1] << 8) | q[i + 2]
            const v = votes.get(key) || { n: 0, r: 0, g: 0, b: 0 }
            v.n++
            v.r += d[i]
            v.g += d[i + 1]
            v.b += d[i + 2]
            votes.set(key, v)
          }
        let bk = -1
        let best = { n: 0 }
        for (const [k, v] of votes) if (v.n > best.n) (best = v), (bk = k)
        const o = (cy * nx + cx) * 4
        if (bk !== -1) {
          out[o] = Math.round(best.r / best.n)
          out[o + 1] = Math.round(best.g / best.n)
          out[o + 2] = Math.round(best.b / best.n)
          out[o + 3] = 255
        }
      }
    return { width: nx, height: ny, data: out, cols, rows }
  }

  /** 把縮小後的真像素圖放大回原圖尺寸：每格用它的顏色填滿（像素對齊、解析度不變）。 */
  function expand(small, cols, rows) {
    const W = cols[cols.length - 1]
    const H = rows[rows.length - 1]
    const out = new Uint8ClampedArray(W * H * 4)
    for (let cy = 0; cy < rows.length - 1; cy++)
      for (let cx = 0; cx < cols.length - 1; cx++) {
        const s = (cy * small.width + cx) * 4
        for (let y = rows[cy]; y < rows[cy + 1]; y++)
          for (let x = cols[cx]; x < cols[cx + 1]; x++) {
            const o = (y * W + x) * 4
            out[o] = small.data[s]
            out[o + 1] = small.data[s + 1]
            out[o + 2] = small.data[s + 2]
            out[o + 3] = small.data[s + 3]
          }
      }
    return { width: W, height: H, data: out }
  }

  const api = { CFG, quantize, profiles, peaks, stepSize, walk, uniformCuts, reconstructionError, detectGrid, snap, expand }
  if (typeof module === 'object' && module.exports) module.exports = api
  else root.PixelSnap = api
})(typeof self !== 'undefined' ? self : this)
