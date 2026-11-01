// 輸出網站：組成完整 HTML、匯出 ZIP（含 firebase.json 可直接 firebase deploy）、
// 以 Firebase Hosting REST API 部署到使用者自己的 Hosting 站台。
import { PLATFORM_ORIGIN } from "./config.js";

const esc = (s) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

export function buildHtml(editor, { slug, title, lang = "en" }) {
  return `<!DOCTYPE html>
<html lang="${esc(lang)}">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title || slug)}</title>
<style>${editor.getCss()}</style>
</head>
<body>
${editor.getHtml().replace(/^<body[^>]*>|<\/body>$/g, "")}
<script src="${PLATFORM_ORIGIN}/site-runtime.js" data-site="${esc(slug)}" defer></script>
</body>
</html>`;
}

function firebaseJson(site) {
  return JSON.stringify({ hosting: { ...(site ? { site } : {}), public: "public", ignore: ["firebase.json", "**/.*"] } }, null, 2);
}

export async function exportZip(html, slug) {
  const zip = new window.JSZip();
  zip.file("public/index.html", html);
  zip.file("firebase.json", firebaseJson());
  zip.file(
    "README.txt",
    `Deploy this site to your own Firebase project:

  npm install -g firebase-tools
  firebase login
  firebase use --add            # pick your Firebase project
  firebase deploy --only hosting

Bookings submitted on this site are stored for "${slug}" and appear in the Site Builder's Bookings panel.
`,
  );
  const blob = await zip.generateAsync({ type: "blob" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `${slug}.zip`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 5000);
}

async function gzip(text) {
  const stream = new Blob([text]).stream().pipeThrough(new CompressionStream("gzip"));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

async function sha256Hex(bytes) {
  const h = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  return [...h].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/// Firebase Hosting REST API：建立版本 → populateFiles → 上傳 gzip 檔 → FINALIZED → release
export async function deployToHosting({ token, siteId, html, onStep = () => {} }) {
  const api = "https://firebasehosting.googleapis.com/v1beta1";
  const call = async (url, opts = {}) => {
    const res = await fetch(url, {
      ...opts,
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", ...(opts.headers || {}) },
    });
    if (!res.ok) {
      let msg = `${res.status}`;
      try {
        msg = (await res.json()).error?.message || msg;
      } catch {}
      throw new Error(msg);
    }
    return res.status === 204 ? {} : res.json();
  };

  onStep("Creating version…");
  const version = await call(`${api}/sites/${siteId}/versions`, {
    method: "POST",
    body: JSON.stringify({ config: { headers: [{ glob: "/index.html", headers: { "Cache-Control": "no-cache" } }] } }),
  });

  const body = await gzip(html);
  const hash = await sha256Hex(body);
  onStep("Uploading files…");
  const pop = await call(`${api}/${version.name}:populateFiles`, {
    method: "POST",
    body: JSON.stringify({ files: { "/index.html": hash } }),
  });
  if ((pop.uploadRequiredHashes || []).includes(hash)) {
    await call(`${pop.uploadUrl}/${hash}`, { method: "POST", headers: { "Content-Type": "application/octet-stream" }, body });
  }

  onStep("Finalizing…");
  await call(`${api}/${version.name}?update_mask=status`, { method: "PATCH", body: JSON.stringify({ status: "FINALIZED" }) });
  onStep("Releasing…");
  await call(`${api}/sites/${siteId}/releases?versionName=${encodeURIComponent(version.name)}`, { method: "POST", body: "{}" });
  return `https://${siteId}.web.app`;
}
