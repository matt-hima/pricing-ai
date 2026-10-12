import { COMPANY, PRICING, PROJECT_TYPES, PLATFORMS, APP_TECH, DESIGN_LEVELS, MODULES } from "./config.js";
import { ruleEstimate, buildPhases, price, complexityOf } from "./estimator.js";
import { MODEL_OPTIONS, detectGPU, modelId, loadModel, askLLM } from "./llm.js";

const $ = (s) => document.querySelector(s);
const $$ = (s) => [...document.querySelectorAll(s)];
const esc = (s = "") => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const money = (n) => `$${Math.round(n).toLocaleString("zh-TW")}`;
const fmtDate = (d) => d.toISOString().slice(0, 10);
const STORE_KEY = "selfquote.draft.v1";

// 我的公司與計價參數（使用者自行填寫）
const ME_FIELDS = ["my_name", "my_taxid", "my_address", "my_phone", "my_email", "rate", "hpm", "vat", "warranty", "maintmin", "maintmax"];
const FIELDS = [...ME_FIELDS, "company", "taxid", "contact", "email", "phone", "refclient", "project", "date", "validity", "payterm", "paymode", "urgency", "budget", "source", "summary", "extra", "refsite"];
const PAYTERM_LABEL = { "3-4-3": "簽約 30% / 期中 40% / 驗收 30%", "5-5": "簽約 50% / 驗收 50%", monthly: "依里程碑按月請款" };

let gpu = { ok: false };
let aiResult = null;   // { est, assumptions, risks }
let busy = false;

/* ---------- 初始化 ---------- */
function chips(container, items, name, type) {
  $(container).innerHTML = items.map((it) =>
    `<label class="chip"><input type="${type}" name="${name}" value="${it.id}"><span>${esc(it.name)}</span></label>`).join("");
}

function renderModules() {
  $("#moduleList").innerHTML = MODULES.map((m) => `
    <div class="module" data-id="${m.id}">
      <label><input type="checkbox" name="module" value="${m.id}"><b>${esc(m.name)}</b><small>${esc(m.desc)}</small></label>
      <div class="detail"><textarea name="note_${m.id}" rows="2" placeholder="${esc(m.ph)}"></textarea></div>
    </div>`).join("");
}

function newRef() {
  const d = new Date();
  const yymm = `${String(d.getFullYear()).slice(2)}${String(d.getMonth() + 1).padStart(2, "0")}`;
  return `${PRICING.refPrefix}${yymm}-${String(Math.floor(Math.random() * 9000) + 1000)}`;
}

function defaults() {
  return {
    ref: newRef(), date: fmtDate(new Date()), validity: 30, payterm: "3-4-3", paymode: "銀行匯款", urgency: "normal",
    source: "官網", type: "app", platforms: ["web"], appTech: "cross", design: "custom",
    modules: [{ id: "member", note: "" }, { id: "admin", note: "" }],
    my_name: COMPANY.name, my_taxid: COMPANY.taxid, my_address: COMPANY.address, my_phone: COMPANY.phone, my_email: COMPANY.email,
    logo: "", ...PRICING_DEFAULTS,
  };
}

// 計價參數以表單上的單位（%、元）儲存
const BASE = { ...PRICING };
const PRICING_DEFAULTS = {
  rate: BASE.ratePerMM, hpm: BASE.hoursPerMM, vat: BASE.vatRate * 100, warranty: BASE.warrantyMonths,
  maintmin: BASE.maintMin * 100, maintmax: BASE.maintMax * 100,
};

/** 將使用者填寫的計價參數套用到 PRICING（估價引擎共用） */
function applyPricing(s) {
  const num = (v, d, lo, hi) => { const n = parseFloat(v); return Number.isFinite(n) ? Math.min(hi, Math.max(lo, n)) : d; };
  const mMin = num(s.maintmin, PRICING_DEFAULTS.maintmin, 0, 100);
  Object.assign(PRICING, {
    ratePerMM: num(s.rate, BASE.ratePerMM, 0, 1e7),
    hoursPerMM: num(s.hpm, BASE.hoursPerMM, 1, 400),
    vatRate: num(s.vat, PRICING_DEFAULTS.vat, 0, 100) / 100,
    warrantyMonths: Math.round(num(s.warranty, BASE.warrantyMonths, 0, 120)),
    maintMin: mMin / 100,
    maintMax: Math.max(mMin, num(s.maintmax, PRICING_DEFAULTS.maintmax, 0, 100)) / 100,
  });
}

function loadDraft() {
  try { return { ...defaults(), ...JSON.parse(localStorage.getItem(STORE_KEY) || "{}") }; } catch { return defaults(); }
}
function saveDraft(s) { try { localStorage.setItem(STORE_KEY, JSON.stringify(s)); } catch {} }

function applyState(s) {
  for (const f of FIELDS) { const el = $(`#f_${f}`); if (el) el.value = s[f] ?? ""; }
  $$("input[name=type]").forEach((i) => (i.checked = i.value === s.type));
  $$("input[name=platform]").forEach((i) => (i.checked = s.platforms.includes(i.value)));
  $$("input[name=appTech]").forEach((i) => (i.checked = i.value === s.appTech));
  $$("input[name=design]").forEach((i) => (i.checked = i.value === s.design));
  $$(".module").forEach((el) => {
    const hit = s.modules.find((m) => m.id === el.dataset.id);
    el.querySelector("input").checked = !!hit;
    el.querySelector("textarea").value = hit?.note || "";
    el.classList.toggle("on", !!hit);
  });
}

function collect() {
  const s = { ref: state.ref, logo: state.logo };
  for (const f of FIELDS) s[f] = $(`#f_${f}`)?.value.trim() ?? "";
  s.type = $("input[name=type]:checked")?.value || "app";
  s.platforms = $$("input[name=platform]:checked").map((i) => i.value);
  s.appTech = $("input[name=appTech]:checked")?.value || "cross";
  s.design = $("input[name=design]:checked")?.value || "custom";
  s.modules = $$(".module").filter((el) => el.querySelector("input").checked)
    .map((el) => ({ id: el.dataset.id, note: el.querySelector("textarea").value.trim() }));
  return s;
}

function labels(s) {
  return {
    type: PROJECT_TYPES.find((t) => t.id === s.type)?.name,
    platforms: s.platforms.map((p) => PLATFORMS.find((x) => x.id === p).name).join("、") || "響應式網站",
    design: DESIGN_LEVELS.find((d) => d.id === s.design)?.name,
  };
}

/* ---------- 合併 AI 結果（程式端防護） ---------- */
const sumH = (tasks) => tasks.reduce((s, t) => s + t.hours, 0);
const r1 = (n) => Math.round(n * 10) / 10;

function cleanTasks(raw, prefix = "") {
  // 小模型常輸出「會員系統 - 登入」，去掉重複的模組名稱前綴
  const strip = (n) => (prefix && n.startsWith(prefix) ? n.slice(prefix.length).replace(/^[\s\-–—:：、]+/, "") : n) || n;
  return (Array.isArray(raw) ? raw : [])
    .map((t) => ({ name: strip(String(t?.name || "").trim()).slice(0, 40), kind: t?.kind === "be" ? "be" : "fe", hours: Number(t?.hours) }))
    .filter((t) => t.name && Number.isFinite(t.hours) && t.hours > 0)
    .slice(0, 5);
}

function scaleTasks(tasks, target) {
  const k = target / (sumH(tasks) || 1);
  return tasks.map((t) => ({ ...t, hours: r1(t.hours * k) }));
}

function mergeAI(baseline, ai, s) {
  const modules = baseline.modules.map((m) => {
    const hit = (ai.modules || []).find((x) => x?.id === m.id);
    const tasks = cleanTasks(hit?.tasks, m.name);
    if (!tasks.length) return m;
    // 工時限制在基準的 0.7–1.8 倍，避免 AI 幻覺造成離譜報價
    const target = Math.min(m.hours * 1.8, Math.max(m.hours * 0.7, sumH(tasks)));
    // 小模型常把前端工作標成 be：前後端比例沿用規則引擎，AI 只決定總工時與子項目
    const fe = r1(target * (m.hours ? m.fe / m.hours : 0));
    return { ...m, tasks: scaleTasks(tasks, target), fe, be: r1(target - fe), hours: r1(target), source: "ai" };
  });

  const extras = (ai.extras || []).slice(0, 3).map((x) => {
    let tasks = cleanTasks(x?.tasks);
    if (!tasks.length || !x?.name) return null;
    if (sumH(tasks) > 120) tasks = scaleTasks(tasks, 120);
    const fe = r1(sumH(tasks.filter((t) => t.kind === "fe")));
    const be = r1(sumH(tasks.filter((t) => t.kind === "be")));
    return { id: "x", name: String(x.name).slice(0, 30), desc: "", fe, be, hours: r1(fe + be), tasks, source: "ai" };
  }).filter(Boolean);

  const design = DESIGN_LEVELS.find((d) => d.id === s.design) || DESIGN_LEVELS[1];
  const hasApp = s.platforms.some((p) => p === "ios" || p === "android");
  const est = buildPhases(modules, { design, hasApp, extras });
  // 複雜度取「計算值」與「AI 判斷」較高者，偏保守
  const order = ["低", "中", "高"];
  const calc = complexityOf(est.totalHours / PRICING.hoursPerMM);
  est.complexity = order[Math.max(order.indexOf(calc), order.indexOf(ai.complexity))] || calc;
  const strs = (a) => (Array.isArray(a) ? a : []).map(String).filter(Boolean).slice(0, 6);
  const assumptions = strs(ai.assumptions);
  const risks = strs(ai.risks);
  return {
    est,
    assumptions: assumptions.length ? assumptions : DEFAULT_ASSUMPTIONS,
    risks: risks.length ? risks : DEFAULT_RISKS,
  };
}

// 小模型偶爾漏填時使用的預設內容
const DEFAULT_ASSUMPTIONS = [
  "客戶於開發期間指派單一窗口，並於 5 個工作天內回覆確認事項。",
  "設計稿確認後的功能範圍變更，將另行評估工時。",
  "第三方服務（金流、簡訊、地圖等）帳號由客戶申請並提供。",
];
const DEFAULT_RISKS = [
  "第三方 API 文件不完整或審核延遲，可能影響時程。",
  "不含伺服器、網域、第三方服務之使用費用。",
  "不含內容建置（文案撰寫、商品上架、資料轉移）。",
];

/* ---------- 報價單渲染 ---------- */
function render() {
  const s = collect();
  saveDraft(s);
  applyPricing(s);
  renderCompany(s);
  const est = aiResult?.est ?? ruleEstimate(s);
  const p = price(est, s);
  const hpm = PRICING.hoursPerMM;

  // 公司與客戶
  $("#docRef").textContent = s.ref;
  const client = [
    s.company ? `<b>${esc(s.company)}</b>` : `<span style="color:var(--muted)">（請填寫公司 / 客戶名稱）</span>`,
    s.taxid && `統一編號 ${esc(s.taxid)}`,
    s.contact && `聯絡人：${esc(s.contact)}`,
    s.email && esc(s.email), s.phone && esc(s.phone),
    s.project && `專案：${esc(s.project)}`,
  ].filter(Boolean).join("<br>");
  $("#docClient").innerHTML = client;
  const d = s.date ? new Date(s.date) : new Date();
  const valid = new Date(d); valid.setDate(valid.getDate() + (Number(s.validity) || 30));
  $("#docDate").textContent = fmtDate(d);
  $("#docValid").textContent = fmtDate(valid);
  $("#docRefClient").textContent = s.refclient || "—";
  $("#docPayterm").textContent = PAYTERM_LABEL[s.payterm];
  $("#docPaymode").textContent = s.paymode;
  $("#docDelivery").textContent = est.totalHours ? `${p.monthsLow} – ${p.monthsHigh} 個月` : "—";

  // 狀態（Dolibarr：草稿 / 已驗證）
  const st = $("#docStatus");
  st.className = `status ${aiResult ? "s1" : "s0"}`;
  st.textContent = aiResult ? "已驗證 · AI 評估" : "草稿 · 規則估算";

  // 明細列
  const vat = `${PRICING.vatRate * 100}%`;
  $("#docLines").innerHTML = p.lines.length ? p.lines.map((l) => l.group
    ? `<tr class="group"><td colspan="7">${esc(l.group)}</td></tr>`
    : `<tr>
        <td class="desc"><b>${esc(l.name)}${l.ai ? '<span class="ai-tag">AI</span>' : ""}</b><small>${esc(l.sub)} · 約 ${Math.round(l.hours)} 工時</small></td>
        <td class="num">${vat}</td><td class="num">${money(p.rate)}</td><td class="num">${l.qty.toFixed(2)}</td>
        <td style="white-space:nowrap">人月</td><td class="num">0%</td><td class="num">${money(l.subtotal)}</td></tr>`).join("")
    : `<tr><td class="empty" colspan="7">請於「平台與模組」勾選至少一個功能模組</td></tr>`;

  $("#tVatRate").textContent = vat;
  $("#tHT").textContent = money(p.ht);
  $("#tVAT").textContent = money(p.vat);
  $("#tTTC").textContent = money(p.ttc);
  $("#tRange").textContent = `${money(p.ttc)} – ${money(p.ttcHigh)}`;
  $("#docBuffer").textContent = `${p.buffer} 倍`;
  $("#docNote").innerHTML = [
    `<b>專案類型：</b>${esc(labels(s).type)}　<b>平台：</b>${esc(labels(s).platforms)}　<b>設計：</b>${esc(labels(s).design)}`,
    s.summary && `<b>需求摘要：</b>${esc(s.summary)}`,
    s.extra && `<b>特殊需求：</b>${esc(s.extra)}`,
    s.urgency === "rush" && "<b>急件加成：</b>人月單價 +25%",
    s.urgency === "flex" && "<b>彈性時程折讓：</b>人月單價 -5%",
  ].filter(Boolean).map((x) => `<p style="margin:0 0 6px">${x}</p>`).join("");

  // 1. 總價範圍
  $("#docKpis").innerHTML = [
    ["預估總費用（未稅）", `${money(p.ht)} – ${money(p.htHigh)}`],
    ["專案複雜度", p.complexity],
    ["總工時", `${p.mm} 人月 · ${Math.round(est.totalHours)} 工時`],
    ["預估開發時程", `${p.monthsLow} – ${p.monthsHigh} 個月（${p.team} 人）`],
  ].map(([k, v]) => `<div class="kpi"><div class="k">${k}</div><div class="v">${v}</div></div>`).join("");

  // 2. 人月拆解
  const all = [...est.modules, ...est.extras];
  // 依模組列出前後端工時（子項目名稱顯示於報價明細）
  const feTasks = all.filter((m) => m.fe > 0).map((m) => ({ name: m.name, hours: m.fe }));
  const beTasks = all.filter((m) => m.be > 0).map((m) => ({ name: m.name, hours: m.be }));
  if (est.infra) beTasks.push({ name: "系統架構、雲端環境與 CI/CD", hours: est.infra });
  const ph = est.phases;
  const groups = [
    ["📋 需求分析與 UI/UX 設計", ph.analysis + ph.design, [{ name: "需求訪談與系統分析", hours: ph.analysis }, { name: "UI / UX 設計", hours: ph.design }]],
    ["💻 前端 / 客戶端開發", ph.frontend, feTasks],
    ["⚙️ 後端架構與 API 開發", ph.backend, beTasks],
    ["🧪 系統整合測試與上線佈署", ph.qa, []],
    ["📌 專案管理", ph.pm, []],
  ];
  $("#docMM").innerHTML = est.totalHours ? groups.filter((g) => g[1] > 0).map(([name, h, subs]) => `
    <li><div class="row"><b>${name}</b><span>${(h / hpm).toFixed(2)} 人月（約 ${Math.round(h)} 工時）</span></div>
      <div class="bar"><i style="width:${(h / est.totalHours) * 100}%"></i></div>
      ${subs.length ? `<ul>${subs.map((t) => `<li><span>${esc(t.name)}</span><span>${Math.round(t.hours)} 工時</span></li>`).join("")}</ul>` : ""}
    </li>`).join("") : `<li class="empty">尚未選擇功能模組</li>`;

  // 3. 維護
  $("#docMaint").innerHTML = `
    <li><b>保固期：</b>驗收上線後提供 ${PRICING.warrantyMonths} 個月免費基礎保固（Bug 修復）。</li>
    <li><b>年度維護合約（SLA）：</b>建議為總開發費用的 ${PRICING.maintMin * 100}% – ${PRICING.maintMax * 100}% / 年
      （約 ${money(p.maintLow)} – ${money(p.maintHigh)}，未稅；約每月 ${money(p.maintLow / 12)} – ${money(p.maintHigh / 12)}）。</li>
    <li><b>包含內容：</b>伺服器監控、第三方 API 升級維護、作業系統 / App Store 政策更新適配、每月固定時數的微調優化。</li>
    <li><b>不含：</b>雲端主機、網域、SSL、簡訊與第三方服務之使用費用，依實際用量另計。</li>`;

  // AI 假設與風險
  $("#docAiSection").hidden = !aiResult;
  if (aiResult) {
    $("#docAssume").innerHTML = aiResult.assumptions.map((x) => `<li>${esc(x)}</li>`).join("") || "<li>—</li>";
    $("#docRisk").innerHTML = aiResult.risks.map((x) => `<li>${esc(x)}</li>`).join("") || "<li>—</li>";
  }

  // 寄給業務
  const subject = `報價詢問 ${s.ref} ${s.company}`;
  const body = summaryText(s, p, est);
  const mail = $("#btnMail");
  if (s.my_email) {
    mail.href = `mailto:${s.my_email.replace(/[?&#\s]/g, "")}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
    mail.removeAttribute("aria-disabled"); mail.style.opacity = ""; mail.title = "";
  } else {
    mail.removeAttribute("href");
    mail.setAttribute("aria-disabled", "true"); mail.style.opacity = ".55"; mail.title = "請先在「我的公司」填寫業務信箱";
  }
  return { s, p, est };
}

/** 報價單位：公司名稱、Logo、聯絡資訊 */
function renderCompany(s) {
  const name = s.my_name;
  const initial = (name || "").trim().charAt(0) || "₪";
  const logo = $("#docLogo");
  if (s.logo) {
    logo.className = "logo img";
    logo.innerHTML = `<img src="${s.logo}" alt="${esc(name || "Logo")}">`;
  } else {
    logo.className = "logo";
    logo.textContent = initial;
  }
  $("#brandLogo").textContent = initial;
  $("#brandName").textContent = name ? `${name} · 自助估價` : "軟體開發自助估價";
  document.title = name ? `軟體開發自助估價 · ${name}` : "軟體開發自助估價";
  $("#docCompany").innerHTML = name ? esc(name) : `<span class="placeholder">（請於「我的公司」填寫公司名稱）</span>`;
  $("#docCompanyInfo").innerHTML = [
    s.my_taxid && `統一編號 ${esc(s.my_taxid)}`,
    s.my_address && esc(s.my_address),
    [s.my_phone, s.my_email].filter(Boolean).map(esc).join(" · "),
  ].filter(Boolean).join("<br>");
}

function summaryText(s, p, est) {
  return [
    `報價單 ${s.ref}（${aiResult ? "AI 評估" : "規則估算"}）`,
    `客戶：${s.company || "—"} / ${s.contact || "—"} ${s.email}`,
    `專案：${s.project || "—"}｜${labels(s).type}｜${labels(s).platforms}`,
    `功能模組：${[...est.modules, ...est.extras].map((m) => m.name).join("、") || "—"}`,
    `預估總價（未稅）：${money(p.ht)} – ${money(p.htHigh)} TWD`,
    `含稅：${money(p.ttc)} – ${money(p.ttcHigh)} TWD`,
    `總工時：${p.mm} 人月（${Math.round(est.totalHours)} 工時）｜複雜度：${p.complexity}`,
    `時程：${p.monthsLow} – ${p.monthsHigh} 個月`,
    `年度維護：${money(p.maintLow)} – ${money(p.maintHigh)} / 年`,
    s.summary ? `需求摘要：${s.summary}` : null,
    "",
    "※ 本估算由 AI 初步評估，僅供預算規劃參考，正式報價以商務人員評估為準。",
  ].filter((x) => x != null).join("\n");
}

/* ---------- AI 評估流程 ---------- */
function progress(p, text) {
  $("#progBar").style.width = `${Math.round(p * 100)}%`;
  $("#progText").textContent = text;
}

function setBusy(b, label) {
  busy = b;
  for (const id of ["#btnEstimate", "#btnEstimate2"]) {
    $(id).disabled = b;
    $(id).textContent = b ? label : "⚡ 產生 AI 評估報價";
  }
}

async function runAI() {
  if (busy) return;
  const s = collect();
  if (!s.modules.length) { toast("請先勾選至少一個功能模組"); switchTab("spec"); return; }
  if (!s.company || !s.contact) { toast("請填寫客戶名稱與聯絡人"); switchTab("card"); return; }
  if (!gpu.ok) { aiResult = null; render(); toast(`無法使用 AI（${gpu.reason}），已改用規則引擎估算`); return; }

  const id = modelId($("#modelSel").value, gpu.f16);
  try {
    setBusy(true, "載入模型中…");
    await loadModel(id, (p, t) => progress(p, t));
    progress(1, `已載入 ${id}`);
    setBusy(true, "AI 評估中…");
    const baseline = ruleEstimate(s);
    const ai = await askLLM(s, baseline, labels(s), (n) => progress(1, `AI 拆解功能中… 已產生 ${n} tokens`), (p, t) => progress(p, `重新載入模型後重試：${t}`));
    progress(1, `已完成評估（${id}）`);
    aiResult = mergeAI(baseline, ai, s);
    render();
    toast("AI 評估完成，報價單已更新");
    document.getElementById("paper").scrollIntoView({ behavior: "smooth", block: "start" });
  } catch (e) {
    console.error(e);
    aiResult = null;
    render();
    progress(0, `錯誤：${e.message}`);
    toast("AI 評估失敗，已改用規則引擎估算");
  } finally {
    setBusy(false);
  }
}

/* ---------- UI ---------- */
function switchTab(name) {
  $$(".tab").forEach((t) => t.classList.toggle("active", t.dataset.tab === name));
  $$(".tabpane").forEach((p) => p.classList.toggle("active", p.dataset.pane === name));
}

let toastTimer;
function toast(msg) {
  const t = $("#toast");
  t.textContent = msg; t.classList.add("show");
  clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.remove("show"), 2800);
}

let state;
async function init() {
  chips("#typeChips", PROJECT_TYPES, "type", "radio");
  chips("#platformChips", PLATFORMS, "platform", "checkbox");
  chips("#appTechChips", APP_TECH, "appTech", "radio");
  chips("#designChips", DESIGN_LEVELS, "design", "radio");
  renderModules();
  $("#modelSel").innerHTML = MODEL_OPTIONS.map((m) => `<option value="${m.base}">${esc(m.label)}</option>`).join("");

  state = loadDraft();
  applyState(state);
  render();
  if (!state.my_name) switchTab("me"); // 首次使用：先填寫自己的公司資料

  // Logo 上傳（以 data URL 存在瀏覽器）
  $("#f_my_logo").addEventListener("change", (e) => {
    const file = e.target.files[0];
    if (!file) return;
    if (file.size > 300 * 1024) { toast("Logo 檔案請小於 300 KB"); e.target.value = ""; return; }
    const reader = new FileReader();
    reader.onload = () => { state.logo = reader.result; render(); toast("已更新 Logo"); };
    reader.readAsDataURL(file);
  });
  $("#btnLogoClear").addEventListener("click", () => { state.logo = ""; $("#f_my_logo").value = ""; render(); });

  // 任何輸入變更：即時以規則引擎重算，並使 AI 結果失效
  document.querySelector(".form-col").addEventListener("input", (e) => {
    if (e.target.name === "module") e.target.closest(".module").classList.toggle("on", e.target.checked);
    if (aiResult) { aiResult = null; progress(0, "需求已變更，請重新產生 AI 評估"); }
    render();
  });
  $$(".tab").forEach((t) => t.addEventListener("click", () => switchTab(t.dataset.tab)));
  $$("[data-goto]").forEach((b) => b.addEventListener("click", () => { switchTab(b.dataset.goto); window.scrollTo({ top: 0, behavior: "smooth" }); }));

  $("#btnEstimate").addEventListener("click", runAI);
  $("#btnEstimate2").addEventListener("click", runAI);
  $("#btnRule").addEventListener("click", () => { aiResult = null; render(); toast("已用規則引擎重新估算"); });
  $("#btnPrint").addEventListener("click", () => window.print());
  $("#btnCopy").addEventListener("click", async () => {
    const { s, p, est } = render();
    try { await navigator.clipboard.writeText(summaryText(s, p, est)); toast("已複製報價摘要"); } catch { toast("無法存取剪貼簿"); }
  });
  $("#btnJson").addEventListener("click", () => {
    const { s, p, est } = render();
    const data = { quote: s, pricing: p, estimate: est, ai: aiResult && { assumptions: aiResult.assumptions, risks: aiResult.risks } };
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], { type: "application/json" }));
    a.download = `${s.ref}.json`; a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  });
  $("#btnReset").addEventListener("click", () => {
    if (!confirm("確定要清除所有填寫內容？")) return;
    try { localStorage.removeItem(STORE_KEY); } catch {}
    // 只清除報價內容，保留「我的公司」資料與計價參數
    const cur = collect();
    const keep = Object.fromEntries([...ME_FIELDS, "logo"].map((k) => [k, cur[k]]));
    aiResult = null; state = { ...defaults(), ...keep }; applyState(state); render(); switchTab("card");
  });

  // WebGPU 偵測
  gpu = await detectGPU();
  const badge = $("#gpuBadge");
  if (gpu.ok) {
    badge.className = "gpu-badge ok"; badge.textContent = "WebGPU 可用 · 本地 AI";
    // 手機或無 f16 時預設輕量模型
    const mobile = /Android|iPhone|iPad/i.test(navigator.userAgent);
    $("#modelSel").value = mobile ? MODEL_OPTIONS[0].base : MODEL_OPTIONS[1].base;
    $("#modelHint").textContent = "首次使用需下載模型，之後會快取於瀏覽器。";
  } else {
    badge.className = "gpu-badge no"; badge.textContent = "規則引擎模式";
    $("#modelSel").disabled = true;
    $("#modelHint").textContent = `${gpu.reason}，將使用規則引擎估算。建議使用最新版 Chrome / Edge 桌機版。`;
  }
}

init();
