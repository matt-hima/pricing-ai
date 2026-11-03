// 語言：第一次打開 /（英文預設頁）時依瀏覽器的偏好語言換到對應語言頁；選過語言就記住，之後照選擇。
// 直接打開某個語言頁（/zh/ 等）不會被換掉，搜尋引擎仍看得到每個語言版本。
(function () {
  var KEY = "pricingai.lang", here = document.body.dataset.lang || "en", paths = {en: "/", zh: "/zh/", ja: "/ja/", pt: "/pt/", es: "/es/"};
  function get() { try { return localStorage.getItem(KEY); } catch (e) { return null; } }
  function set(v) { try { localStorage.setItem(KEY, v); } catch (e) {} }
  document.addEventListener("click", function (ev) {
    var a = ev.target.closest && ev.target.closest("a[data-lang]");
    if (a) set(a.dataset.lang);
    var open = document.querySelector("details.langsel[open]");
    if (open && !open.contains(ev.target)) open.removeAttribute("open"); // 點選單外面就關起來
  });
  // 選單打開時選邊：右邊放不下就靠左對齊，避免超出畫面（窄螢幕上按鈕會換到左邊）
  var sel = document.querySelector("details.langsel");
  if (sel) sel.addEventListener("toggle", function () {
    var m = sel.querySelector(".langs");
    if (!sel.open || !m) return;
    m.style.left = ""; m.style.right = "";
    var r = m.getBoundingClientRect();
    if (r.left < 8) { m.style.left = "0"; m.style.right = "auto"; }
  });
  if (location.pathname !== "/") return;
  var want = get();
  if (!want) {
    var list = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language || ""];
    for (var i = 0; i < list.length && !want; i++) {
      var l = (list[i] || "").toLowerCase().split(/[-_]/)[0];
      if (paths[l]) want = l;
    }
  }
  if (want && want !== here && paths[want]) location.replace(paths[want] + location.search + location.hash);
})();

// 下載鈕依作業系統切換（Mac / Windows / 其他）；「搶先使用」會打開聯絡表單並選好主題。
// 聯絡表單：公開 Google フォームの formResponse に直接 POST する（サーバー不要・応答は読めないので送れた時点で成功扱い）。
(function () {
  var box = document.querySelector(".dlbox");
  // 版本號直接取自 GitHub 最新發佈（tag v0.2.4 → 0.2.4）；查不到就維持建置時寫進頁面的版本
  var ver = document.getElementById("dl-ver");
  if (ver && window.fetch) {
    var show = function (v) { if (/^[0-9]+([.][0-9]+)*$/.test(v)) ver.textContent = v; };
    try { var c = sessionStorage.getItem("pricingai.ver"); if (c) show(c); } catch (e) {}
    fetch("https://api.github.com/repos/matt-hima/pricing-ai/releases/latest", { headers: { Accept: "application/vnd.github+json" } })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (j) {
        var v = j && typeof j.tag_name === "string" ? j.tag_name.replace(/^v/, "") : "";
        if (!v) return;
        show(v);
        try { sessionStorage.setItem("pricingai.ver", v); } catch (e) {}
      })
      .catch(function () {});
  }
  if (box) {
    var ua = navigator.userAgent || "", plat = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || "";
    var touch = navigator.maxTouchPoints > 1;
    var os = /Win/i.test(plat) || /Windows/.test(ua) ? "win" : (/Mac/i.test(plat) && !touch ? "mac" : "other");
    var d = box.dataset, main = document.getElementById("dl-main");
    if (os === "other") {
      document.getElementById("dl-other-os").hidden = false;
    } else {
      var other = os === "mac" ? "win" : "mac";
      main.textContent = d[os + "Label"];
      main.href = d[os + "Href"];
      if (box.querySelector("[data-early]") || d[os + "Href"] === "#contact") main.dataset.early = "1";
      var o = document.getElementById("dl-other");
      o.textContent = other === "mac" ? "macOS" : "Windows";
      o.href = "#plat-" + other;
      document.getElementById("dl-also").hidden = false;
      var card = document.getElementById("plat-" + os);
      if (card) card.classList.add("mine");
    }
  }
  // 「搶先使用」：跳到聯絡表單，主題選好 Mac / Windows 版搶先使用
  document.addEventListener("click", function (ev) {
    var a = ev.target.closest && ev.target.closest("a");
    if (!a || a.getAttribute("href") !== "#contact" || !(a.dataset.early || (a.id === "dl-main" && a.dataset.early))) return;
    var f = document.getElementById("contact-form");
    if (!f) return;
    var sel = f.elements.topic;
    for (var i = 0; i < sel.options.length; i++) if (sel.options[i].dataset.app) sel.selectedIndex = i;
    setTimeout(function () { f.elements.name.focus({ preventScroll: true }); }, 400);
  });

  var form = document.getElementById("contact-form");
  if (!form) return;
  var status = form.querySelector(".status");
  var btn = form.querySelector("button[type=submit]");
  var last = 0;
  try { last = +sessionStorage.getItem("contactSent") || 0; } catch (e) {}
  function say(text, cls) { status.textContent = text; status.className = "status" + (cls ? " " + cls : ""); }
  form.addEventListener("submit", function (ev) {
    ev.preventDefault();
    if (form.elements.website.value) return; // ボット（見えない欄に入力された）
    if (!form.checkValidity()) { form.reportValidity(); return; }
    if (Date.now() - last < 30000) { say(form.dataset.wait, "err"); return; }
    var d = form.dataset, f = form.elements, topic = f.topic, opt = topic.options[topic.selectedIndex];
    var msg = f.message.value.trim();
    if (opt && opt.dataset.app) msg = "[" + d.tag + "] " + msg;
    var body = new URLSearchParams();
    body.append(d.name, f.name.value.trim());
    body.append(d.email, f.email.value.trim());
    body.append(d.topic, topic.value);
    body.append(d.message, msg + "\n\n(" + location.pathname + " · " + (navigator.language || "") + ")");
    btn.disabled = true; say(d.sending);
    fetch(d.action, { method: "POST", mode: "no-cors", body: body }).then(function () {
      last = Date.now(); try { sessionStorage.setItem("contactSent", String(last)); } catch (e) {}
      form.reset(); say(d.ok, "ok");
    }).catch(function () { say(d.err, "err"); }).then(function () { btn.disabled = false; });
  });
})();
