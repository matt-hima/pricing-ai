// 建置器產生之網站的執行期腳本（發佈到平台或匯出自架都會載入）：
//  1. <form data-booking>：預約表單送出後寫入 Firestore builderPublished/{site}/bookings
//  2. <div data-ai-invoicing>：嵌入 AI 估價（inline iframe）
//  3. [data-ai-invoicing-open]：點擊後以對話框開啟 AI 估價（服務項目卡片的按鈕）
// 也可以單獨放進任何網站：<script src="https://pricingai.minervaelectronics.com/site-runtime.js" data-site="my-site"></script>
// 使用 Firestore REST API，不載入 Firebase SDK，讓訪客端維持輕量。
(() => {
  const PROJECT = "task-exchange-f8f97";
  const API_KEY = "AIzaSyBU1p2Bp2lzwbxGZZ9-h5w27okW0JEEgxc";
  const COL_PUBLISHED = "builderPublished";

  const me = document.currentScript;
  const origin = me ? new URL(me.src).origin : location.origin;
  const site = (me && me.dataset.site) || "";

  const MSG = {
    en: ["Sending…", "Thank you! Your booking request has been received.", "Booking failed", "Please choose at least one option for each required question."],
    ja: ["送信中…", "ありがとうございます。ご予約を承りました。", "送信に失敗しました", "必須の質問は、少なくとも1つ選んでください。"],
    zh: ["送出中…", "謝謝您！已收到您的預約申請。", "送出失敗", "必填的問題請至少選擇一個選項。"],
    pt: ["Enviando…", "Obrigado! Recebemos seu pedido de agendamento.", "Falha ao enviar", "Escolha pelo menos uma opção em cada pergunta obrigatória."],
    es: ["Enviando…", "¡Gracias! Hemos recibido tu solicitud de reserva.", "Error al enviar", "Elige al menos una opción en cada pregunta obligatoria."],
  };
  const msg = () => MSG[(document.documentElement.lang || "en").slice(0, 2)] || MSG.en;

  const estimatorUrl = (lang) => `${origin}/app/${lang ? `?lang=${encodeURIComponent(lang)}` : ""}`;

  function frame(lang, height) {
    const f = document.createElement("iframe");
    f.src = estimatorUrl(lang);
    f.title = "AI Invoicing";
    f.loading = "lazy";
    f.allow = "clipboard-write; fullscreen";
    f.style.cssText = `width:100%;height:${height || 860}px;border:0;border-radius:12px;background:#fff`;
    return f;
  }

  function mountInline() {
    document.querySelectorAll("[data-ai-invoicing]").forEach((el) => {
      if (el.dataset.mounted) return;
      el.dataset.mounted = "1";
      el.replaceChildren(frame(el.dataset.lang, el.dataset.height));
    });
  }

  let modal = null;
  function openModal(lang) {
    if (!modal) {
      modal = document.createElement("div");
      modal.style.cssText =
        "position:fixed;inset:0;z-index:2147483000;background:rgba(15,23,42,.6);display:flex;align-items:center;justify-content:center;padding:16px";
      const box = document.createElement("div");
      box.style.cssText = "position:relative;width:min(1200px,100%);height:min(92vh,960px);background:#fff;border-radius:14px;overflow:hidden";
      const close = document.createElement("button");
      close.type = "button";
      close.textContent = "×";
      close.setAttribute("aria-label", "Close");
      close.style.cssText =
        "position:absolute;top:8px;right:10px;z-index:1;width:36px;height:36px;border:0;border-radius:50%;background:#263c5c;color:#fff;font-size:22px;cursor:pointer";
      close.onclick = () => (modal.style.display = "none");
      modal.onclick = (e) => e.target === modal && (modal.style.display = "none");
      const f = frame(lang);
      f.style.height = "100%";
      f.style.borderRadius = "0";
      box.append(close, f);
      modal.append(box);
      document.body.append(modal);
    }
    modal.style.display = "flex";
  }

  document.addEventListener("click", (e) => {
    const t = e.target.closest && e.target.closest("[data-ai-invoicing-open]");
    if (!t) return;
    e.preventDefault();
    openModal(t.dataset.lang || t.getAttribute("data-ai-invoicing-open"));
  });

  // ---- 預約表單 ----
  const fieldName = (n) => n.replace(/[^A-Za-z0-9_]/g, "_").slice(0, 40) || "field";

  // 送出方式（由表單的 data-* 決定）：data-endpoint → POST JSON 到該網址（Formspree 等）；
  // data-mailto → 開啟使用者的郵件軟體；都沒有 → 寫入平台 Firestore（網站建置器網頁版發佈的網站）
  // Google フォーム連携：訪問者のブラウザからフォームの formResponse に直接 POST する（サーバー不要）。
  // 応答は読めない（no-cors）ので、送信できた時点で成功として扱う。日付・時刻は Google の形式（_year/_month/_day, _hour/_minute）に分ける。
  async function submitGoogleForm(form) {
    for (const fs of form.querySelectorAll("fieldset[data-required]")) {
      if (!fs.querySelector("input:checked")) throw new Error(msg()[3]);
    }
    const body = new URLSearchParams();
    for (const [k, v] of new FormData(form)) {
      if (typeof v !== "string" || !k.startsWith("entry.") || v === "") continue;
      const el = form.querySelector(`[name="${k}"]`);
      if (el && el.hasAttribute("data-gdate")) {
        const [y, m, d] = v.split("-").map(Number);
        body.append(`${k}_year`, y);
        body.append(`${k}_month`, m);
        body.append(`${k}_day`, d);
      } else if (el && el.hasAttribute("data-gtime")) {
        const [h, mi] = v.split(":").map(Number);
        body.append(`${k}_hour`, h);
        body.append(`${k}_minute`, mi);
      } else body.append(k, v.slice(0, 5000));
    }
    if (form.dataset.pages) body.append("pageHistory", form.dataset.pages);
    await fetch(form.dataset.gform, { method: "POST", mode: "no-cors", body });
  }

  async function submitBooking(form) {
    if (form.dataset.gform) return submitGoogleForm(form);
    const plain = {};
    // 欄位的顯示名稱（data-label，例如「人數」）優先，這樣寄出的信 / 資料看得懂；沒有就用 name
    for (const [k, v] of new FormData(form)) {
      if (typeof v !== "string") continue;
      const label = form.elements[k] && form.elements[k].dataset && form.elements[k].dataset.label;
      plain[label || fieldName(k)] = v.slice(0, 2000);
    }
    const endpoint = form.dataset.endpoint;
    const mailto = form.dataset.mailto;
    if (endpoint) {
      const res = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({ ...plain, page: location.href }),
      });
      if (!res.ok) throw new Error(`${msg()[2]} (${res.status})`);
      return;
    }
    if (mailto) {
      const body = Object.entries(plain).map(([k, v]) => `${k}: ${v}`).join("\n");
      location.href = `mailto:${mailto}?subject=${encodeURIComponent("Booking request")}&body=${encodeURIComponent(body)}`;
      return;
    }
    if (!site) throw new Error("This site is not published yet.");
    const fields = {};
    for (const [k, v] of Object.entries(plain)) {
      if (Object.keys(fields).length >= 15) break;
      fields[k] = { stringValue: v };
    }
    fields.createdAt = { timestampValue: new Date().toISOString() };
    fields.page = { stringValue: location.href.slice(0, 500) };
    const url = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/${COL_PUBLISHED}/${encodeURIComponent(site)}/bookings?key=${API_KEY}`;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ fields }),
    });
    if (!res.ok) throw new Error(`${msg()[2]} (${res.status})`);
  }

  document.addEventListener("submit", async (e) => {
    const form = e.target.closest && e.target.closest("form[data-booking]");
    if (!form) return;
    e.preventDefault();
    const btn = form.querySelector("[type=submit]");
    const out = form.querySelector("[data-booking-status]") || form.appendChild(document.createElement("p"));
    out.setAttribute("data-booking-status", "");
    if (btn) btn.disabled = true;
    out.textContent = msg()[0];
    try {
      await submitBooking(form);
      form.reset();
      out.textContent = form.dataset.success || msg()[1];
    } catch (err) {
      out.textContent = err.message;
    } finally {
      if (btn) btn.disabled = false;
    }
  });

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", mountInline);
  else mountInline();
})();
