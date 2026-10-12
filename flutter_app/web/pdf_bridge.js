// 報價單 PDF：pdfmake（約 1 MB 的純 JavaScript）在瀏覽器內直接排版，不需要 TeX。
// - pdfmake 與字型都在第一次需要時才載入（不影響首頁載入速度）。
// - 字型優先從 jsDelivr（已釘選到固定版本）下載，不佔 Firebase 流量；失敗才改抓網站自己的備份。
// - 只有文件內真的出現中日文字元時才下載 CJK 字型（拉丁文字報價單只需 Source Sans 3，約 0.7 MB）。
//
// 狀態與錯誤訊息一律以「@代碼」回傳（例如 @pdf_fonts），由 Flutter 端依介面語言翻譯。
(() => {
  const local = new URL("fonts/", document.baseURI).href;
  const NOTO = "https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@165c01b46ea533872e002e0785ff17e44f6d97d8/Sans/SubsetOTF/";
  const SANS = "https://cdn.jsdelivr.net/gh/adobe-fonts/source-sans@7c691c2772570a0d3a9e1bffe8a9d6074257d985/OTF/";
  const CDN = {
    NotoSansTC: NOTO + "TC/",
    NotoSansJP: NOTO + "JP/",
    SourceSans3: SANS,
  };
  const CJK_RE = /[⺀-鿿぀-ヿ가-힯豈-﫿＀-￯]/;

  let pdfMakePromise = null;
  const fontPromises = {}; // 檔名 → Promise<base64>
  let loadedFamilies = "";
  let lastPdf = null;

  function status(cb, text) { try { cb?.(text); } catch {} }

  function loadScript(src) {
    return new Promise((resolve, reject) => {
      const s = document.createElement("script");
      s.src = src;
      s.onload = resolve;
      s.onerror = () => reject(new Error("@pdf_failed"));
      document.head.appendChild(s);
    });
  }

  function ensurePdfMake() {
    pdfMakePromise ??= loadScript(new URL("vendor/pdfmake.min.js", document.baseURI).href).then(() => {
      // 只有外框與細線的簡潔表格樣式（函式無法用 JSON 傳遞，所以在這裡註冊、由文件以名稱引用）
      pdfMake.addTableLayouts({
        quoteLines: {
          hLineWidth: (i, node) => (i === 0 || i === node.table.body.length ? 0 : 0.5),
          vLineWidth: () => 0,
          hLineColor: () => "#E2E8F0",
          paddingLeft: () => 6, paddingRight: () => 6, paddingTop: () => 5, paddingBottom: () => 5,
        },
        kv: {
          hLineWidth: () => 0, vLineWidth: () => 0,
          paddingLeft: () => 0, paddingRight: () => 0, paddingTop: () => 2, paddingBottom: () => 2,
        },
        totals: {
          hLineWidth: (i, node) => (i === 0 || i === node.table.body.length ? 0.8 : 0.5),
          vLineWidth: () => 0,
          hLineColor: () => "#CBD5E0",
          paddingLeft: () => 8, paddingRight: () => 8, paddingTop: () => 5, paddingBottom: () => 5,
        },
        boxes: {
          hLineWidth: () => 0.6, vLineWidth: () => 0.6,
          hLineColor: () => "#CBD5E0", vLineColor: () => "#CBD5E0",
          paddingLeft: () => 8, paddingRight: () => 8, paddingTop: () => 6, paddingBottom: () => 6,
        },
        none: {
          hLineWidth: () => 0, vLineWidth: () => 0,
          paddingLeft: () => 0, paddingRight: () => 0, paddingTop: () => 0, paddingBottom: () => 0,
        },
      });
    });
    pdfMakePromise.catch(() => { pdfMakePromise = null; });
    return pdfMakePromise;
  }

  async function fetchBytes(url, timeoutMs) {
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), timeoutMs);
    try {
      const r = await fetch(url, { signal: ctl.signal });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return await r.blob();
    } finally { clearTimeout(timer); }
  }

  function toBase64(blob) {
    return new Promise((resolve, reject) => {
      const fr = new FileReader();
      fr.onload = () => resolve(String(fr.result).split(",")[1]);
      fr.onerror = () => reject(fr.error);
      fr.readAsDataURL(blob);
    });
  }

  /** 先試 CDN（30 秒逾時），失敗再用網站內的備份 */
  function loadFont(file) {
    fontPromises[file] ??= (async () => {
      const family = file.split("-")[0];
      let blob;
      try { blob = await fetchBytes(CDN[family] + file, 30000); }
      catch (e) { console.warn(`字型 CDN 失敗，改用備份：${file}`, e); blob = await fetchBytes(local + file, 60000); }
      return toBase64(blob);
    })();
    fontPromises[file].catch(() => { delete fontPromises[file]; });
    return fontPromises[file];
  }

  async function ensureFonts(needCjk, cjkSet) {
    const cjk = cjkSet === "jp" ? "NotoSansJP" : "NotoSansTC";
    const files = ["SourceSans3-Regular.otf", "SourceSans3-Bold.otf"];
    if (needCjk) files.push(`${cjk}-Regular.otf`, `${cjk}-Bold.otf`);
    const data = await Promise.all(files.map(loadFont));
    const vfs = {};
    files.forEach((f, i) => { vfs[f] = data[i]; });
    pdfMake.addVirtualFileSystem(vfs);
    const fonts = {
      Latin: { normal: files[0], bold: files[1], italics: files[0], bolditalics: files[1] },
    };
    if (needCjk) fonts.CJK = { normal: files[2], bold: files[3], italics: files[2], bolditalics: files[3] };
    pdfMake.setFonts(fonts);
    loadedFamilies = Object.keys(fonts).join();
  }

  /** 把 Flutter 傳來的簡化文件轉成 pdfmake 文件（頁尾需要函式，所以在這裡補） */
  function finalize(doc) {
    const f = doc.x_footer;
    delete doc.x_footer;
    if (f) {
      doc.footer = (page, total) => ({
        margin: [36, 8, 36, 0],
        columns: [
          { text: f.left, color: "#5F6B78", fontSize: 8 },
          { text: f.right.replace("{page}", page).replace("{total}", total), alignment: "right", color: "#5F6B78", fontSize: 8 },
        ],
      });
    }
    return doc;
  }

  /** 產生 PDF 位元組 */
  async function render(docJson, cjkSet, cb) {
    status(cb, "@pdf_fonts");
    await ensurePdfMake();
    await ensureFonts(CJK_RE.test(docJson), cjkSet);
    status(cb, "@pdf_making");
    const doc = finalize(JSON.parse(docJson));
    const buf = await pdfMake.createPdf(doc).getBuffer();
    return new Uint8Array(buf);
  }

  function saveBlob(bytes, filename) {
    const url = URL.createObjectURL(new Blob([bytes], { type: "application/pdf" }));
    const a = document.createElement("a");
    a.href = url; a.download = filename; a.click();
    setTimeout(() => URL.revokeObjectURL(url), 60000);
  }

  /** 產生並下載；成功回傳空字串，失敗回傳錯誤訊息 */
  async function download(docJson, cjkSet, filename, cb) {
    try {
      const pdf = await render(docJson, cjkSet, cb);
      lastPdf = pdf;
      saveBlob(pdf, filename);
      status(cb, "@pdf_done");
      return "";
    } catch (e) {
      console.error(e);
      status(cb, "@pdf_failed");
      return String(e?.message || e);
    }
  }

  /** 產生並畫到預覽面板（pdf_preview.js）；成功回傳空字串，失敗回傳錯誤訊息 */
  async function preview(docJson, cjkSet, cb) {
    try {
      const pdf = await render(docJson, cjkSet, cb);
      lastPdf = pdf;
      await window.quotePreview?.render(pdf);
      status(cb, "@pdf_synced");
      return "";
    } catch (e) {
      console.error(e);
      status(cb, "@pdf_failed");
      return String(e?.message || e);
    }
  }

  /** 下載最近一次產生的 PDF */
  function downloadLast(filename) {
    if (!lastPdf) return false;
    saveBlob(lastPdf, filename);
    return true;
  }

  window.quotePdf = { download, preview, downloadLast, render, get fonts() { return loadedFamilies; } };
})();
