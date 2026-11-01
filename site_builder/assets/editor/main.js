// 編輯器頁面：GrapesJS + 預約網站區塊。與外層 Flutter 程式以訊息溝通：
//  - 進來的指令：{sb:true, id, method, args}（網頁版用 postMessage，桌面版用 evaluateJavascript 呼叫 sbCall）
//  - 出去的事件：ready、changed（專案 JSON）、result（指令的回傳值）
//    桌面版走 flutter_inappwebview 的 callHandler('sb')，網頁版走 parent.postMessage
import { PLATFORM_ORIGIN } from "./config.js";
import { BASE_CSS, starterHtml, registerBookingKit, registerBlocks, priceRowsHtml, pricingSectionHtml } from "./blocks.js";

const outbox = [];
function flush() {
  const bridge = window.flutter_inappwebview;
  while (outbox.length) {
    const msg = outbox[0];
    if (bridge && bridge.callHandler) bridge.callHandler("sb", msg);
    else if (window.parent !== window) window.parent.postMessage(msg, "*");
    else return;
    outbox.shift();
  }
}
function emit(type, payload) {
  outbox.push({ sb: true, type, payload });
  flush();
}
window.addEventListener("flutterInAppWebViewPlatformReady", flush);
setInterval(flush, 400); // 桌面 webview 的橋接準備好之前先排隊

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

let lang = "en";
const editor = grapesjs.init({
  container: "#gjs",
  height: "100%",
  fromElement: false,
  storageManager: false,
  plugins: ["gjs-blocks-basic"],
  pluginsOpts: { "gjs-blocks-basic": { flexGrid: true, category: "Basic" } },
  deviceManager: {
    devices: [
      { name: "Desktop", width: "" },
      { name: "Tablet", width: "768px", widthMedia: "992px" },
      { name: "Mobile portrait", width: "375px", widthMedia: "480px" },
    ],
  },
  assetManager: { embedAsBase64: true },
});
registerBookingKit(editor, lang);
editor.on("load", () => editor.Panels.getButton("views", "open-blocks")?.set("active", true));

let timer = 0;
editor.on("update", () => {
  clearTimeout(timer);
  timer = setTimeout(() => emit("changed", { project: JSON.stringify(editor.getProjectData()) }), 500);
});

function applyTemplate(l) {
  lang = l;
  registerBlocks(editor, l);
  editor.setComponents(starterHtml(l));
  editor.setStyle(BASE_CSS);
}

const api = {
  /// Flutter 端確認連線：重新回報 ready
  hello() {
    emit("ready", {});
    return true;
  },
  /// 載入專案；沒有專案資料就套用該語言的範本
  load(project, l) {
    clearTimeout(timer);
    lang = l || "en";
    registerBlocks(editor, lang);
    if (project) editor.loadProjectData(JSON.parse(project));
    else applyTemplate(lang);
    return true;
  },
  reset(l) {
    applyTemplate(l);
    return true;
  },
  /// 把 Pricing AI 的報價明細套用到網站的價格列表：payload = { items: [{name, amount}], currency, lang }
  applyPricing(payload) {
    const items = (payload && payload.items) || [];
    if (!items.length) throw new Error("No priced items to apply");
    const locale = lang === "zh" ? "zh-TW" : lang;
    const fmt = new Intl.NumberFormat(locale, { style: "currency", currency: payload.currency || "TWD", maximumFractionDigits: 0 });
    const rows = items.map((i) => [i.name, fmt.format(i.amount)]);
    const find = () => editor.getWrapper().find(".bk-price-list")[0];
    let list = find();
    if (!list) {
      editor.addComponents(pricingSectionHtml(lang));
      list = find();
    }
    list.components(priceRowsHtml(rows));
    editor.select(list);
    list.getEl()?.scrollIntoView({ block: "center" });
    return rows.length;
  },
  project() {
    clearTimeout(timer);
    return JSON.stringify(editor.getProjectData());
  },
  /// 完整網站 HTML（單一檔案）；opts：{ title, slug, lang, mailto, endpoint }
  html(opts) {
    const o = opts || {};
    editor.getWrapper().find("form[data-booking]").forEach((f) => {
      const set = (k, v) => (v ? f.addAttributes({ [k]: v }) : f.removeAttributes(k));
      set("data-mailto", (o.mailto || "").trim());
      set("data-endpoint", (o.endpoint || "").trim());
    });
    const body = editor.getHtml().replace(/^<body[^>]*>|<\/body>$/g, "");
    return `<!DOCTYPE html>
<html lang="${esc(o.lang || lang)}">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(o.title || o.slug || "My site")}</title>
<style>${editor.getCss()}</style>
</head>
<body>
${body}
<script src="${PLATFORM_ORIGIN}/site-runtime.js" data-site="${esc(o.slug || "")}" defer></script>
</body>
</html>
`;
  },
};

window.sbCall = (id, method, args) => {
  Promise.resolve()
    .then(() => api[method](...(args || [])))
    .then((result) => emit("result", { id, result }))
    .catch((e) => emit("result", { id, error: String(e && e.message ? e.message : e) }));
};
window.addEventListener("message", (e) => {
  const d = e.data;
  if (d && d.sb && d.method) window.sbCall(d.id, d.method, d.args);
});

emit("ready", {});
