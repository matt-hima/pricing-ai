// 編輯器頁面：GrapesJS + 預約網站區塊。與外層 Flutter 程式以訊息溝通：
//  - 進來的指令：{sb:true, id, method, args}（網頁版用 postMessage，桌面版用 evaluateJavascript 呼叫 sbCall）
//  - 出去的事件：ready、changed（專案 JSON）、result（指令的回傳值）
//    桌面版走 flutter_inappwebview 的 callHandler('sb')，網頁版走 parent.postMessage
import { PLATFORM_ORIGIN } from "./config.js";
import { BASE_CSS, starterHtml, registerBookingKit, registerBlocks, priceRowsHtml, pricingSectionHtml, svcRowsHtml, faqRowsHtml, sectionHtml, noscriptText, requiredText } from "./blocks.js";
import { createActions } from "./actions.js";
import { renderFlowDataUri } from "./flow.js";

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

async function applyTemplate(l, overrides) {
  lang = l;
  registerBlocks(editor, l, overrides);
  editor.setComponents(starterHtml(l, overrides));
  editor.setStyle(BASE_CSS);
  await actions.refreshFlows(); // 流程圖用 Mermaid 繪製（非同步）
}


const actions = createActions(editor, { esc, svcRowsHtml, priceRowsHtml, sectionHtml, requiredText: () => requiredText(lang), getLang: () => lang, renderFlow: renderFlowDataUri, faqRowsHtml });

const textOfComp = (c) => { const el = c.getEl(); return el ? el.textContent.trim() : ""; };
const q = (sel) => editor.getWrapper().find(sel);

const api = {
  /// Flutter 端確認連線：重新回報 ready
  hello() {
    emit("ready", {});
    return true;
  },
  /// 載入專案；沒有專案資料就套用該語言的範本
  async load(project, l) {
    clearTimeout(timer);
    lang = l || "en";
    registerBlocks(editor, lang);
    if (project) editor.loadProjectData(JSON.parse(project));
    else await applyTemplate(lang);
    return true;
  },
  async reset(l) {
    await applyTemplate(l);
    return true;
  },
  /// 用 AI 產生的文字（overrides：與範本字典同名的欄位）重新套用範本
  async applyContent(l, overrides) {
    await applyTemplate(l || lang, overrides || {});
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
  /// 編輯動作目錄（名稱、說明、參數）：Flutter 用它組成給模型的提示詞
  catalog() {
    return actions.catalog();
  },
  /// 目前網站內容的快照（給 AI 聊天當上下文）
  snapshot() {
    return actions.snapshot();
  },
  /// 依序執行模型挑選的動作；回傳每個動作的結果 [{action, ok, message}]
  runActions(list) {
    return actions.run(list);
  },
  /// 復原上一批動作
  undo() {
    return actions.undo();
  },
  auditMessages() {
    return actions.auditMessages();
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
    const l = o.lang || lang;
    const title = o.title || o.slug || "My site";
    const lead = (q('[data-f="lead"]')[0] ? textOfComp(q('[data-f="lead"]')[0]) : "") || title;
    const mail = (o.mailto || "").trim();
    const bodyClass = editor.getWrapper().getClasses().length ? ` class="${esc(editor.getWrapper().getClasses().join(" "))}"` : ""; // 主題（bk-tech）等類別要帶到匯出的 <body>
    // 沒有 JavaScript 時的替代說明（預約表單需要 JavaScript；Digital Agency 網站指引 7.3.1）
    const noscript = `<noscript><p style="margin:0;padding:12px 20px;background:#fff3cd;color:#3b2f00;font:16px/1.6 system-ui,sans-serif">${esc(noscriptText(l))}${mail ? ` <a href="mailto:${esc(mail)}" style="color:#3b2f00">${esc(mail)}</a>` : ""}</p></noscript>`;
    // ---- SEO：標準網址、社群預覽、結構化資料（schema.org LocalBusiness，Google 搜尋用）----
    const url = (o.url || "").trim().replace(/\/?$/, "/");
    const hasUrl = /^https?:\/\//i.test(url);
    const doc = () => editor.Canvas.getDocument();
    const txt = (sel) => (q(sel)[0] ? textOfComp(q(sel)[0]) : "");
    const brand = txt('[data-f="brand"]') || title;
    const addr = txt('[data-f="addr"]').split(/\s+[·・|]\s+/)[0]; // 「地址 · 信箱」的格式：只取地址
    const services = [...doc().querySelectorAll(".bk-svc h3")].map((e) => e.textContent.trim()).filter(Boolean);
    const faq = [...doc().querySelectorAll(".bk-qa")].map((e) => [e.querySelector("summary")?.textContent.trim(), e.querySelector("p")?.textContent.trim()]).filter((r) => r[0] && r[1]);
    const ld = [
      {
        "@context": "https://schema.org",
        "@type": "LocalBusiness",
        name: brand,
        description: lead.slice(0, 160),
        inLanguage: l,
        ...(hasUrl ? { url } : {}),
        ...(addr ? { address: addr } : {}),
        ...(o.mailto ? { email: o.mailto.trim() } : {}),
        ...(services.length ? { makesOffer: services.map((n) => ({ "@type": "Offer", itemOffered: { "@type": "Service", name: n } })) } : {}),
      },
      ...(faq.length ? [{ "@context": "https://schema.org", "@type": "FAQPage", mainEntity: faq.map((r) => ({ "@type": "Question", name: r[0], acceptedAnswer: { "@type": "Answer", text: r[1] } })) }] : []),
    ];
    const ldJson = JSON.stringify(ld).replace(/</g, "\\u003c");
    return `<!DOCTYPE html>
<html lang="${esc(l)}">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<meta name="description" content="${esc(lead.slice(0, 120))}">
<meta property="og:type" content="website">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(lead.slice(0, 120))}">
<meta property="og:locale" content="${esc(l)}">
<meta property="og:site_name" content="${esc(brand)}">
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="${esc(title)}">
<meta name="twitter:description" content="${esc(lead.slice(0, 120))}">
<meta name="robots" content="index, follow, max-image-preview:large">
${hasUrl ? `<link rel="canonical" href="${esc(url)}">\n<meta property="og:url" content="${esc(url)}">\n` : ""}<script type="application/ld+json">${ldJson}</script>
<style>${editor.getCss()}</style>
</head>
<body${bodyClass}>
${noscript}
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
