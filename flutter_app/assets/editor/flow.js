// 流程圖（預約流程、服務流程）：用 Mermaid 繪製。
// 模型只提供「步驟文字」；Mermaid 語法由這裡依步驟確定地產生，所以語法一定正確、不會被模型寫壞。
// 結果是 SVG，以 data URI 放進 <img>（有替代文字，匯出的網站不需要任何 JavaScript 就能顯示）。

const MAX_STEPS = 7;
const MAX_LABEL = 28;

/** 把「a; b; c」或「a → b → c」或多行文字拆成步驟（2–7 個，每個最多 28 字） */
export function parseSteps(input) {
  const parts = Array.isArray(input) ? input : String(input || "").split(/[;；→>\n|]/);
  const steps = parts.map((s) => String(s).replace(/^\s*\d+[.)、]\s*/, "").trim()).filter(Boolean).map((s) => s.slice(0, MAX_LABEL));
  return steps.slice(0, MAX_STEPS);
}

/** Mermaid 標籤要避開會破壞語法的字元；太長的標籤換行 */
function label(text, i) {
  const clean = text.replace(/["`]/g, "'").replace(/[\[\](){}|<>#;&]/g, " ").replace(/\s+/g, " ").trim();
  const width = /[぀-ヿ㐀-鿿]/.test(clean) ? 7 : 14; // 中日文每行約 7 字，其他語言約 14 字元
  const lines = [];
  let line = "";
  const tokens = width === 7 ? [...clean] : clean.split(" ");
  for (const tk of tokens) {
    const next = width === 7 ? line + tk : line ? line + " " + tk : tk;
    if (next.length > width && line) {
      lines.push(line);
      line = tk;
    } else {
      line = next;
    }
  }
  if (line) lines.push(line);
  return `${i + 1}. ${lines.join("<br/>")}`.replace(/^(\d+)\. /, "$1  ");
}

/** 步驟 → Mermaid flowchart 原始碼。步驟少用橫向，多用直向。 */
export function flowSource(steps, colors) {
  const dir = steps.length <= 4 ? "LR" : "TD";
  const nodes = steps.map((s, i) => `  n${i}(["${label(s, i)}"])`);
  const edges = steps.slice(1).map((_, i) => `  n${i} --> n${i + 1}`);
  const last = steps.length - 1;
  return [
    `flowchart ${dir}`,
    ...nodes,
    ...edges,
    `  classDef step fill:${colors.tint},stroke:${colors.main},stroke-width:2px,color:${colors.ink}`,
    `  classDef done fill:${colors.main},stroke:${colors.main},color:#ffffff`,
    `  class ${steps.map((_, i) => `n${i}`).slice(0, last).join(",") || "n0"} step`,
    `  class n${last} done`,
  ].join("\n");
}

const mix = (hex, amount) => {
  const c = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
  return "#" + c.map((v) => Math.round(v + (255 - v) * amount).toString(16).padStart(2, "0")).join("");
};

let seq = 0;
let ready = false;

/** 以主色（hex）繪製流程圖，回傳 SVG 字串 */
export async function renderFlowSvg(steps, mainHex = "#7a6657") {
  if (!window.mermaid) throw new Error("Mermaid is not loaded");
  if (!ready) {
    window.mermaid.initialize({
      startOnLoad: false,
      securityLevel: "strict",
      theme: "base",
      flowchart: { htmlLabels: false, curve: "basis", useMaxWidth: true, padding: 14 },
      fontFamily: '"Hiragino Sans","Noto Sans JP","PingFang TC","Noto Sans TC",system-ui,sans-serif',
    });
    ready = true;
  }
  const colors = { main: mainHex, tint: mix(mainHex, 0.88), ink: "#1f1b18" };
  const { svg } = await window.mermaid.render(`flow${++seq}`, flowSource(steps, colors));
  return normalizeSvg(svg);
}

/** Mermaid 輸出的是 HTML 內嵌用的 SVG（含 &nbsp;、<br> 這類 XML 不接受的寫法）；放進 <img> 要是格式正確的 XML，
 *  所以先用 HTML 解析器讀進來，再用 XMLSerializer 輸出。 */
export function normalizeSvg(svg) {
  const holder = document.createElement("div");
  holder.innerHTML = svg;
  const el = holder.querySelector("svg");
  if (!el) throw new Error("Mermaid did not return an SVG");
  el.setAttribute("xmlns", "http://www.w3.org/2000/svg");
  el.removeAttribute("style"); // 寬度交給 CSS（img { width: 100% }）
  // 明確的固有尺寸（取自 viewBox）：圖片載入前後版面不會跳動，也避免 width="100%" 造成奇怪的固有寬度
  const vb = (el.getAttribute("viewBox") || "").split(/[\s,]+/).map(Number);
  if (vb.length === 4 && vb[2] > 0 && vb[3] > 0) {
    el.setAttribute("width", String(Math.round(vb[2])));
    el.setAttribute("height", String(Math.round(vb[3])));
  }
  el.removeAttribute("role");
  el.removeAttribute("aria-roledescription");
  return new XMLSerializer().serializeToString(el);
}

/** SVG → data URI（UTF-8 安全的 base64） */
export function svgDataUri(svg) {
  const bytes = new TextEncoder().encode(svg);
  let bin = "";
  bytes.forEach((b) => (bin += String.fromCharCode(b)));
  return "data:image/svg+xml;base64," + btoa(bin);
}

export async function renderFlowDataUri(steps, mainHex) {
  return svgDataUri(await renderFlowSvg(steps, mainHex));
}
