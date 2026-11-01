// 下載鈕依作業系統切換（Mac / Windows / 其他）；「搶先使用」會打開聯絡表單並選好主題。
// 聯絡表單：公開 Google フォームの formResponse に直接 POST する（サーバー不要・応答は読めないので送れた時点で成功扱い）。
(function () {
  var box = document.querySelector(".dlbox");
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
