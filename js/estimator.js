import { PRICING, PROJECT_TYPES, DESIGN_LEVELS, MODULES, COMPLEX_KEYWORDS } from "./config.js";

const round1 = (n) => Math.round(n * 10) / 10;
const clamp = (n, lo, hi) => Math.min(hi, Math.max(lo, n));

/** 前端倍率：依平台組合計算 */
export function frontendFactor(platforms, appTech) {
  const web = platforms.includes("web");
  const apps = ["ios", "android"].filter((p) => platforms.includes(p)).length;
  let f = web ? 1 : 0;
  if (apps === 1) f += 1.1;
  if (apps === 2) f += appTech === "native" ? 2.0 : 1.35;
  return f || 1;
}

/** 從白話描述推估複雜度加成 */
export function textComplexity(text = "") {
  if (!text.trim()) return { factor: 1, hits: [] };
  const lower = text.toLowerCase();
  const hits = COMPLEX_KEYWORDS.filter((k) => lower.includes(k.toLowerCase()));
  let bonus = Math.min(0.4, hits.length * 0.08);
  if (text.length > 60) bonus += 0.05;
  return { factor: 1 + bonus, hits };
}

/**
 * 規則引擎：產出每個模組的前後端工時與各階段工時。
 * 這是 AI 評估的基準（baseline），也是不支援 WebGPU 時的備援。
 */
export function ruleEstimate(input) {
  const type = PROJECT_TYPES.find((t) => t.id === input.type) || PROJECT_TYPES[1];
  const design = DESIGN_LEVELS.find((d) => d.id === input.design) || DESIGN_LEVELS[1];
  const feF = frontendFactor(input.platforms, input.appTech);
  const hasApp = input.platforms.some((p) => p === "ios" || p === "android");

  const modules = input.modules.map(({ id, note }) => {
    const m = MODULES.find((x) => x.id === id);
    const { factor, hits } = textComplexity(note);
    const k = factor * type.factor;
    const fe = round1(m.fe * feF * k);
    const be = round1(m.be * k);
    // 預設子項目拆解（AI 會覆寫）
    const tasks = [];
    if (fe) tasks.push({ name: `${m.name}介面開發`, hours: fe, kind: "fe" });
    if (be) tasks.push({ name: `${m.name} API 與資料庫`, hours: be, kind: "be" });
    return { id, name: m.name, desc: m.desc, note, fe, be, hours: round1(fe + be), hits, tasks, source: "rule" };
  });

  return buildPhases(modules, { design, hasApp, extras: [] });
}

/** 依模組工時推算設計、PM、測試部署等階段 */
export function buildPhases(modules, { design, hasApp, extras = [] }) {
  const all = [...modules, ...extras];
  const fe = all.reduce((s, m) => s + m.fe, 0);
  const be = all.reduce((s, m) => s + m.be, 0);
  const dev = fe + be;
  const infra = dev ? 24 + (hasApp ? 24 : 0) : 0; // 架構建置、CI/CD、上架作業
  const phases = {
    analysis: round1(dev ? Math.max(24, dev * 0.08) : 0),
    design: round1(dev ? (24 + fe * 0.18) * design.factor : 0),
    frontend: round1(fe),
    backend: round1(be + infra),
    qa: round1(dev ? dev * 0.18 + (hasApp ? 16 : 0) : 0),
    pm: round1(dev ? dev * 0.08 : 0),
  };
  const totalHours = round1(Object.values(phases).reduce((s, h) => s + h, 0));
  return { modules, extras, phases, infra, totalHours };
}

/** 依總人月決定複雜度、團隊人數與時程 */
export function complexityOf(mm) {
  if (mm < 3) return "低";
  if (mm < 8) return "中";
  return "高";
}

/** 報價單明細列（Dolibarr 報價單列：說明 / 數量(人月) / 單價） */
export function buildLines(est) {
  const { phases, modules, extras, infra } = est;
  const L = [];
  if (!est.totalHours) return L;
  L.push({ group: "規劃與設計" });
  L.push({ name: "需求訪談與系統分析", sub: "需求確認、功能規格書（SRS）、系統架構規劃", hours: phases.analysis });
  L.push({ name: "UI / UX 設計", sub: "使用者流程、線框稿、視覺設計稿與設計規範", hours: phases.design });
  L.push({ group: "功能開發" });
  for (const m of [...modules, ...extras]) {
    L.push({ name: m.name, sub: m.tasks.map((t) => t.name).join("、"), hours: round1(m.fe + m.be), ai: m.source === "ai" });
  }
  L.push({ name: "系統架構與部署環境", sub: "專案框架、雲端環境、CI/CD、App 上架作業", hours: infra });
  L.push({ group: "測試與上線" });
  L.push({ name: "系統整合測試與上線佈署", sub: "功能測試、跨裝置相容性測試、UAT 協助、正式上線", hours: phases.qa });
  L.push({ name: "專案管理", sub: "時程控管、週會、進度報告", hours: phases.pm });
  return L;
}

/** 金額計算：只在程式端計算，絕不採用 LLM 給的金額 */
export function price(est, input) {
  const { ratePerMM, hoursPerMM, vatRate, riskBuffer, urgency, maintMin, maintMax } = PRICING;
  const mm = est.totalHours / hoursPerMM;
  const complexity = est.complexity || complexityOf(mm);
  const buffer = riskBuffer[complexity];
  const urg = urgency[input.urgency] ?? 1;
  const rate = Math.round(ratePerMM * urg);

  // 數量以 2 位小數人月計，小計 = 數量 × 單價，確保報價單可逐列驗算
  const lines = buildLines(est).map((l) => {
    if (l.group) return l;
    const qty = Math.round((l.hours / hoursPerMM) * 100) / 100;
    return { ...l, qty, subtotal: Math.round(qty * rate) };
  });
  const ht = lines.reduce((s, l) => s + (l.subtotal || 0), 0);
  const vat = Math.round(ht * vatRate);
  const ttc = ht + vat;
  const htHigh = Math.round(ht * buffer);
  const ttcHigh = Math.round(htHigh * (1 + vatRate));

  const team = mm <= 3 ? 2 : mm <= 8 ? 3 : mm <= 16 ? 4 : 5;
  const rushK = input.urgency === "rush" ? 0.8 : input.urgency === "flex" ? 1.2 : 1;
  const monthsLow = clamp(round1((mm / team) * rushK), 0.5, 99);
  const monthsHigh = round1(monthsLow * buffer);

  return {
    lines, mm: round1(mm), rate, complexity, buffer, ht, vat, ttc, htHigh, ttcHigh, team, monthsLow, monthsHigh,
    maintLow: Math.round(ht * maintMin), maintHigh: Math.round(htHigh * maintMax),
  };
}
