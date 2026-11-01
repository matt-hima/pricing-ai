// 網站建置器主程式：GrapesJS 編輯器 + 預約網站區塊 + AI 估價嵌入，
// 草稿先存在瀏覽器（localStorage），登入後可存到雲端、發佈到 /s/{site}、匯出 ZIP 或部署到自己的 Firebase Hosting。
import { PLATFORM_ORIGIN } from "./config.js";
import { BASE_CSS, starterHtml, registerBookingKit, registerBlocks } from "./blocks.js";
import { LANGS } from "./config.js";
import { buildHtml, exportZip, deployToHosting } from "./deploy.js";

const $ = (id) => document.getElementById(id);
const CURRENT_KEY = "builder.current";
const LOCAL_PREFIX = "builder.project.";

const store = {
  get: (k) => {
    try {
      return localStorage.getItem(k);
    } catch {
      return null;
    }
  },
  set: (k, v) => {
    try {
      localStorage.setItem(k, v);
    } catch {}
  },
};

const randomSlug = () => `my-site-${Math.random().toString(36).slice(2, 7)}`;

const browserLang = () => {
  const n = (navigator.language || "en").toLowerCase();
  return n.startsWith("zh") ? "zh" : LANGS.some((l) => l.id === n.slice(0, 2)) ? n.slice(0, 2) : "en";
};

let current = JSON.parse(store.get(CURRENT_KEY) || "null") || { slug: randomSlug(), name: "My booking site", lang: browserLang() };
current.lang ||= "en";
let user = null;
let cloud = null; // 動態載入：Firebase SDK 載入失敗時，編輯器仍可離線使用

function status(text) {
  $("status").textContent = text;
  $("status").title = text;
}

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
registerBookingKit(editor, current.lang);

// 預設開啟區塊面板
editor.on("load", () => editor.Panels.getButton("views", "open-blocks")?.set("active", true));

function loadLocal(slug) {
  const raw = store.get(LOCAL_PREFIX + slug);
  if (raw) {
    editor.loadProjectData(JSON.parse(raw));
  } else {
    editor.setComponents(starterHtml(current.lang));
    editor.setStyle(BASE_CSS);
  }
}

function saveLocal() {
  store.set(LOCAL_PREFIX + current.slug, JSON.stringify(editor.getProjectData()));
  store.set(CURRENT_KEY, JSON.stringify(current));
}

let saveTimer = 0;
editor.on("update", () => {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    saveLocal();
    status("Saved in this browser");
  }, 600);
});

$("siteLang").innerHTML = LANGS.map((l) => `<option value="${l.id}">${l.name}</option>`).join("");

$("siteLang").addEventListener("change", (e) => {
  const lang = e.target.value;
  if (!confirm("Replace the page with the starter template in this language? Your current edits will be lost.")) {
    e.target.value = current.lang;
    return;
  }
  current.lang = lang;
  registerBlocks(editor, lang);
  editor.setComponents(starterHtml(lang));
  editor.setStyle(BASE_CSS);
  saveLocal();
});

function syncInputs() {
  $("siteLang").value = current.lang;
  $("siteName").value = current.name;
  $("siteSlug").value = current.slug;
}

$("siteName").addEventListener("change", (e) => {
  current.name = e.target.value.trim() || "Untitled";
  saveLocal();
  refreshSitePicker();
});

$("siteSlug").addEventListener("change", (e) => {
  const v = e.target.value.trim().toLowerCase();
  if (!/^[a-z0-9](?:[a-z0-9-]{1,38}[a-z0-9])$/.test(v)) {
    alert("Site address must be 3–40 characters: lowercase letters, numbers and dashes.");
    e.target.value = current.slug;
    return;
  }
  current.slug = v;
  saveLocal();
  refreshSitePicker();
});

document.querySelectorAll("[data-dev]").forEach((b) =>
  b.addEventListener("click", () => {
    editor.setDevice(b.dataset.dev);
    document.querySelectorAll("[data-dev]").forEach((x) => x.classList.toggle("on", x === b));
  }),
);

// ---- 我的網站清單 ----
let mySites = [];
async function refreshSitePicker() {
  if (user && cloud) {
    try {
      mySites = await cloud.listMySites();
    } catch (e) {
      status(`Could not load sites: ${e.message}`);
    }
  }
  const sel = $("sitePick");
  const items = [...mySites];
  if (!items.some((s) => s.slug === current.slug)) items.unshift({ slug: current.slug, name: current.name });
  sel.innerHTML =
    items.map((s) => `<option value="${s.slug}">${(s.slug === current.slug ? current.name : s.name) || s.slug}</option>`).join("") +
    `<option value="__new">＋ New site</option>`;
  sel.value = current.slug;
}

$("sitePick").addEventListener("change", async (e) => {
  const v = e.target.value;
  saveLocal();
  if (v === "__new") {
    current = { slug: randomSlug(), name: "My booking site", lang: $("siteLang").value };
    registerBlocks(editor, current.lang);
    editor.setComponents(starterHtml(current.lang));
    editor.setStyle(BASE_CSS);
  } else {
    const s = mySites.find((x) => x.slug === v);
    current = { slug: v, name: s?.name || v, lang: s?.lang || "en" };
    registerBlocks(editor, current.lang);
    const draft = user && cloud ? await cloud.loadDraft(v).catch(() => null) : null;
    if (draft) editor.loadProjectData(draft.project);
    else loadLocal(v);
  }
  syncInputs();
  saveLocal();
  refreshSitePicker();
});

// ---- 登入 ----
function renderUser() {
  const el = $("user");
  if (!cloud) {
    el.innerHTML = "";
    return;
  }
  if (user) {
    el.innerHTML = `<img src="${user.photoURL || ""}" alt="" referrerpolicy="no-referrer"><button id="btnOut" title="${user.email || ""}">Sign out</button>`;
    $("btnOut").onclick = () => cloud.signOut();
  } else {
    el.innerHTML = `<button id="btnIn">Sign in with Google</button>`;
    $("btnIn").onclick = () => cloud.signIn().catch((e) => status(e.message));
  }
}

async function requireUser() {
  if (!cloud) throw new Error("Cloud features are unavailable (Firebase failed to load).");
  if (!user) await cloud.signIn();
}

async function run(btn, label, fn) {
  btn.disabled = true;
  status(label);
  try {
    await fn();
  } catch (e) {
    status(e.message || String(e));
    alert(e.message || String(e));
  } finally {
    btn.disabled = false;
  }
}

$("btnSave").onclick = () =>
  run($("btnSave"), "Saving…", async () => {
    saveLocal();
    await requireUser();
    await cloud.saveDraft(current.slug, current.name, editor.getProjectData(), current.lang);
    status("Saved to cloud");
    refreshSitePicker();
  });

const publishedUrl = () => `${PLATFORM_ORIGIN}/s/${current.slug}`;

$("btnPublish").onclick = () =>
  run($("btnPublish"), "Publishing…", async () => {
    saveLocal();
    await requireUser();
    await cloud.saveDraft(current.slug, current.name, editor.getProjectData(), current.lang);
    await cloud.publish(current.slug, current.name, buildHtml(editor, { slug: current.slug, title: current.name, lang: current.lang }));
    status("Published");
    const url = publishedUrl();
    dialog(
      "Published",
      `<p>Your site is live at<br><a href="${url}" target="_blank" rel="noopener">${url}</a></p>
       <p>Bookings from the site appear under <b>Bookings</b>. To use your own domain, choose <b>Deploy to my Firebase</b> or <b>Export ZIP</b>.</p>
       <button data-close>Close</button>`,
    );
    refreshSitePicker();
  });

$("btnExport").onclick = () =>
  run($("btnExport"), "Building ZIP…", async () => {
    saveLocal();
    await exportZip(buildHtml(editor, { slug: current.slug, title: current.name, lang: current.lang }), current.slug);
    status("ZIP downloaded");
  });

// ---- 部署到使用者自己的 Firebase Hosting ----
$("btnDeploy").onclick = () => {
  const box = dialog(
    "Deploy to your Firebase Hosting",
    `<p>Deploys this page to a Firebase Hosting site in <b>your own</b> Google account. Create a project and a Hosting site at
       <a href="https://console.firebase.google.com/" target="_blank" rel="noopener">console.firebase.google.com</a> first, then enter its site ID
       (the part before <code>.web.app</code>).</p>
     <p>Google will ask you to allow Firebase Hosting access. Bookings keep flowing into this builder's Bookings panel.</p>
     <label>Hosting site ID<input id="dSite" placeholder="my-salon" value="${store.get("builder.deploySite") || ""}"></label>
     <button id="dGo">Deploy</button><button class="ghost" data-close>Cancel</button>
     <div class="log" id="dLog"></div>`,
  );
  const log = (t) => (box.querySelector("#dLog").textContent += `${t}\n`);
  box.querySelector("#dGo").onclick = async (e) => {
    const siteId = box.querySelector("#dSite").value.trim().toLowerCase();
    if (!/^[a-z0-9-]{3,63}$/.test(siteId)) return log("Enter a valid site ID.");
    store.set("builder.deploySite", siteId);
    e.target.disabled = true;
    try {
      if (!cloud) throw new Error("Firebase failed to load.");
      log("Requesting Google permission…");
      const token = await cloud.hostingToken();
      const url = await deployToHosting({ token, siteId, html: buildHtml(editor, { slug: current.slug, title: current.name, lang: current.lang }), onStep: log });
      log(`Done: ${url}`);
      box.querySelector("#dLog").insertAdjacentHTML("beforeend", `<a href="${url}" target="_blank" rel="noopener">${url}</a>`);
      status(`Deployed to ${url}`);
    } catch (err) {
      log(`Error: ${err.message}\nYou can still use Export ZIP and run "firebase deploy" yourself.`);
    } finally {
      e.target.disabled = false;
    }
  };
};

// ---- 預約清單 ----
$("btnBookings").onclick = () =>
  run($("btnBookings"), "Loading bookings…", async () => {
    await requireUser();
    const rows = await cloud.listBookings(current.slug);
    status(`${rows.length} booking(s)`);
    const cols = ["name", "email", "phone", "service", "date", "time", "notes"];
    const cell = (v) => String(v ?? "").replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" })[c]);
    const box = dialog(
      `Bookings · ${current.slug}`,
      rows.length
        ? `<table class="bk-table"><thead><tr><th>Received</th>${cols.map((c) => `<th>${c}</th>`).join("")}<th></th></tr></thead><tbody>
           ${rows
             .map(
               (r) =>
                 `<tr><td>${r.createdAt?.toDate?.().toLocaleString() || ""}</td>${cols.map((c) => `<td>${cell(r[c])}</td>`).join("")}
                  <td><button data-del="${r.id}" title="Delete">✕</button></td></tr>`,
             )
             .join("")}</tbody></table>`
        : `<p>No bookings yet. Publish the site and share <a href="${publishedUrl()}" target="_blank" rel="noopener">${publishedUrl()}</a>.</p>`,
    );
    box.querySelectorAll("[data-del]").forEach((b) =>
      b.addEventListener("click", async () => {
        if (!confirm("Delete this booking?")) return;
        await cloud.deleteBooking(current.slug, b.dataset.del);
        b.closest("tr").remove();
      }),
    );
  });

function dialog(title, html) {
  const el = document.createElement("div");
  el.className = "dlg";
  el.innerHTML = html;
  el.querySelectorAll("[data-close]").forEach((b) => (b.onclick = () => editor.Modal.close()));
  editor.Modal.open({ title, content: el });
  return el;
}

// ---- 啟動 ----
syncInputs();
loadLocal(current.slug);
saveLocal();
refreshSitePicker();

import("./cloud.js")
  .then((m) => {
    cloud = m;
    renderUser();
    m.onUser((u) => {
      user = u;
      renderUser();
      refreshSitePicker();
    });
  })
  .catch((e) => {
    console.warn("Firebase unavailable", e);
    status("Offline mode: cloud features unavailable");
  });
