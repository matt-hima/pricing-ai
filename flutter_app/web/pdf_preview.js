// PDF 即時預覽：以 pdf.js 把 XeLaTeX 產生的 PDF 畫成 canvas。
// 重新整理時只替換頁面內容並保留捲動位置，避免 iframe 重載造成閃爍與跳回頂端。
(() => {
  let host = null;
  let lastBytes = null;
  let token = 0;
  let observer = null;
  let resizeTimer = null;

  if (window.pdfjsLib) {
    pdfjsLib.GlobalWorkerOptions.workerSrc = new URL("vendor/pdf.worker.min.js", document.baseURI).href;
  }

  function attach(el) {
    host = el;
    observer?.disconnect();
    observer = new ResizeObserver(() => {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(() => lastBytes && render(lastBytes), 250);
    });
    observer.observe(el);
    if (lastBytes) render(lastBytes);
  }

  async function render(bytes) {
    lastBytes = bytes;
    if (!host || !window.pdfjsLib) return;
    const mine = ++token;
    // getDocument 會轉移緩衝區所有權，傳入副本以保留 lastBytes
    const doc = await pdfjsLib.getDocument({ data: bytes.slice() }).promise;
    try {
      const width = Math.max(240, host.clientWidth - 24);
      const dpr = window.devicePixelRatio || 1;
      const frag = document.createDocumentFragment();
      for (let i = 1; i <= doc.numPages; i++) {
        const page = await doc.getPage(i);
        if (mine !== token) return;
        const scale = width / page.getViewport({ scale: 1 }).width;
        const vp = page.getViewport({ scale: scale * dpr });
        const canvas = document.createElement("canvas");
        canvas.width = Math.floor(vp.width);
        canvas.height = Math.floor(vp.height);
        canvas.style.cssText =
          `display:block;margin:0 auto 12px;width:${vp.width / dpr}px;height:${vp.height / dpr}px;` +
          "background:#fff;box-shadow:0 1px 4px rgba(0,0,0,.25);";
        await page.render({ canvasContext: canvas.getContext("2d"), viewport: vp }).promise;
        frag.appendChild(canvas);
      }
      if (mine !== token) return;
      const top = host.scrollTop;
      host.replaceChildren(frag);
      host.scrollTop = top;
    } finally {
      // 每次重畫都會建立一個 pdf.js worker；用完要釋放，否則預覽越刷新越吃記憶體
      doc.destroy();
    }
  }

  window.quotePreview = { attach, render };
})();
