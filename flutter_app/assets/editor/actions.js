// 網站編輯動作目錄：AI 聊天只負責「挑動作 + 填參數」，真正修改頁面的程式全部在這裡預先寫好。
// 每個動作都對應 GrapesJS 速查表裡的一種 API：
//   元件內容   component.components(html | JSON)         → set_text / set_row / add_row / remove_row / scale_prices
//   元件屬性   component.addAttributes({...})             → set_line_link
//   元件樣式   component.addStyle({...})                  → set_hero_image
//   CSS 規則   editor.Css.getRule(sel).addStyle({...})    → set_color / set_background
//   增刪元件   editor.addComponents(html, {at}) / c.remove() → set_section
//   選取與捲動 editor.select(c) + el.scrollIntoView()     → show
//   裝置       editor.setDevice(name)                     → set_device
// 目錄（名稱、說明、參數型別）會經由 catalog() 送到 Flutter 組成給模型的提示詞，
// 所以新增動作只要在 ACTIONS 加一筆，提示詞和驗證都會自動跟上。

const COLOR_NAMES = {
  pink: "#d6607f", rose: "#d6607f", red: "#c0392b", orange: "#d9822b", yellow: "#d4a72c", gold: "#b8922e",
  green: "#2f7d6d", teal: "#1f8a8a", blue: "#2f6fb3", navy: "#263c5c", purple: "#7b57c4", violet: "#7b57c4",
  brown: "#7a6657", beige: "#a68b76", black: "#2b2b2b", gray: "#6b7280", grey: "#6b7280", white: "#ffffff",
  粉紅: "#d6607f", 粉色: "#d6607f", 紅: "#c0392b", 紅色: "#c0392b", 橙: "#d9822b", 橘色: "#d9822b", 黃: "#d4a72c", 金色: "#b8922e",
  綠: "#2f7d6d", 綠色: "#2f7d6d", 藍: "#2f6fb3", 藍色: "#2f6fb3", 紫: "#7b57c4", 紫色: "#7b57c4", 棕: "#7a6657", 咖啡色: "#7a6657", 黑: "#2b2b2b", 黑色: "#2b2b2b", 灰: "#6b7280", 灰色: "#6b7280", 白: "#ffffff",
  ピンク: "#d6607f", 赤: "#c0392b", 青: "#2f6fb3", 緑: "#2f7d6d", オレンジ: "#d9822b", 茶色: "#7a6657", 黒: "#2b2b2b",
  rosa: "#d6607f", vermelho: "#c0392b", rojo: "#c0392b", azul: "#2f6fb3", verde: "#2f7d6d", laranja: "#d9822b", naranja: "#d9822b", roxo: "#7b57c4", morado: "#7b57c4", marrom: "#7a6657", marrón: "#7a6657", preto: "#2b2b2b", negro: "#2b2b2b",
};

const TEXT_TARGETS = ["brand", "brandSub", "h1", "h2", "lead", "cta", "addr"];
const LISTS = ["services", "prices", "hours", "faq"];
const SECTIONS = ["price", "hours", "float", "flow", "faq", "availability"];
const VIEW_SECTIONS = ["nav", "hero", "services", "flow", "price", "faq", "availability", "booking", "hours", "footer"];
const DEVICES = { desktop: "Desktop", tablet: "Tablet", mobile: "Mobile portrait" };
const PAL0 = ["#7a6657", "#a68b76", "#6a5a4d"]; // 範本的主色 / 淺色 / 深色
const MAX_ROWS = { services: 8, prices: 8, hours: 7, faq: 8 };
const MIN_ROWS = { services: 2, prices: 1, hours: 1, faq: 1 };

// ---- 參數型別：string(max) / number(min,max) / bool / enum(values) / row / color / url ----
const P = (name, type, extra = {}) => ({ name, type, required: true, ...extra });

/** 動作目錄。run(ctx, args) 回傳 { message, changed }；丟出 Error 代表這個動作失敗。 */
export const ACTIONS = [
  {
    name: "set_text",
    example: { say: "Change the headline to Nails you will love", args: { action: "set_text", target: "h1", text: "Nails you will love" } },
    description: "Change one piece of text on the page.",
    params: [P("target", "enum", { values: TEXT_TARGETS, hint: "brand=business name, brandSub=tagline under it, h1/h2=hero headlines, lead=sentence under the headlines, cta=booking button text, addr=address/contact line in the footer" }), P("text", "string", { max: 120 })],
    run(c, a) {
      const comps = c.q(`[data-f="${a.target}"]`);
      if (!comps.length) throw new Error(`"${a.target}" is not on this page`);
      comps.forEach((x) => x.components(c.html(a.text)));
      return { message: `${a.target} → "${a.text}"`, changed: true };
    },
  },
  {
    name: "set_row",
    example: { say: "We are closed on Mondays", args: { action: "set_row", list: "hours", row: "Monday", second: "Closed" } },
    description: "Change cells of an existing row in a list. first = service name / item / day / FAQ question, second = subtitle / price / time / FAQ answer. Give only the cells that change. A closed day is NOT removed: \"closed on Mondays\" (休み・定休 / 公休 / fechamos / cerramos) means set_row on the hours with second = Closed.",
    params: [
      P("list", "enum", { values: LISTS }),
      P("row", "row", { hint: "row number (1 = first) or a word that appears in the row, e.g. \"Monday\"" }),
      P("first", "string", { max: 40, required: false }),
      P("second", "string", { max: 120, required: false }),
    ],
    run(c, a) {
      const rows = c.readList(a.list);
      const i = c.findRow(rows, a.row);
      if (i < 0) throw new Error(`no row matches "${a.row}" in ${a.list}`);
      if (typeof a.first === "string") rows[i][0] = a.first;
      if (typeof a.second === "string") rows[i][1] = a.second;
      c.writeList(a.list, rows);
      return { message: `${a.list} row ${i + 1} → ${rows[i].join(" | ")}`, changed: true };
    },
  },
  {
    name: "add_row",
    example: { say: "Add a service called Facial for $60", args: { action: "add_row", list: "prices", first: "Facial", second: "$60" } },
    description: "Add a row at the end of a list (services, prices, opening hours, or the FAQ list of questions and answers).",
    params: [P("list", "enum", { values: LISTS }), P("first", "string", { max: 80 }), P("second", "string", { max: 120, required: false })],
    run(c, a) {
      const rows = c.readList(a.list);
      if (rows.length >= MAX_ROWS[a.list]) throw new Error(`${a.list} already has the maximum of ${MAX_ROWS[a.list]} rows`);
      rows.push([a.first, a.second || ""]);
      c.writeList(a.list, rows);
      return { message: `${a.list} + ${a.first}`, changed: true };
    },
  },
  {
    name: "remove_row",
    example: { say: "Remove the manicure price", args: { action: "remove_row", list: "prices", row: "Manicure" } },
    description: "Delete one row from a list completely (for example delete a price or a service). Never use it for a closed day: that is set_row.",
    params: [P("list", "enum", { values: LISTS }), P("row", "row", { hint: "row number or a word in the row" })],
    run(c, a) {
      const rows = c.readList(a.list);
      const i = c.findRow(rows, a.row);
      if (i < 0) throw new Error(`no row matches "${a.row}" in ${a.list}`);
      if (rows.length <= MIN_ROWS[a.list]) throw new Error(`${a.list} needs at least ${MIN_ROWS[a.list]} row(s)`);
      const [gone] = rows.splice(i, 1);
      c.writeList(a.list, rows);
      return { message: `${a.list} − ${gone[0]}`, changed: true };
    },
  },
  {
    name: "scale_prices",
    example: { say: "Make everything 10% cheaper", args: { action: "scale_prices", percent: -10 } },
    description: "Raise or lower every price in the price list by a percentage (negative = cheaper). The numbers are calculated by the app. (価格を安く・高く / 價格調低・調高 / deixar os preços mais baratos / hacer los precios más baratos)",
    params: [P("percent", "number", { min: -90, max: 300, hint: "a whole number of percent such as -10 or 15 (not a fraction like 0.15)" })],
    run(c, a) {
      const rows = c.readList("prices");
      const scale = (s) =>
        s.replace(/\d[\d,]*(?:\.\d+)?/g, (m) => {
          const n = parseFloat(m.replace(/,/g, "")) * (1 + a.percent / 100);
          const decimals = m.includes(".") ? m.split(".")[1].length : 0;
          const v = n.toFixed(decimals);
          return m.includes(",") ? Number(v).toLocaleString("en-US", { minimumFractionDigits: decimals, maximumFractionDigits: decimals }) : v;
        });
      c.writeList("prices", rows.map((r) => [r[0], scale(r[1] || "")]));
      return { message: `prices ${a.percent > 0 ? "+" : ""}${a.percent}%`, changed: true };
    },
  },
  {
    name: "set_color",
    example: { say: "Use pink as the main colour", args: { action: "set_color", color: "pink" } },
    description: "Change the main colour of buttons and accents. Use this for \"use blue\", \"change the colour\" (色を変える / 主色改成 / mudar a cor / cambiar el color), unless the owner says background.",
    params: [P("color", "color", { hint: "use the colour name the owner said (pink, blue, green, red, orange, purple, teal, brown, black, gray, …); use #rrggbb only if the owner gave a hex code" })],
    async run(c, a) {
      let hex = c.resolveColor(a.color);
      const safe = c.darkenForWhiteText(hex); // 按鈕是白字：太淺的顏色會自動調深到對比 4.5:1
      c.applyPalette(safe);
      await c.refreshFlows(); // 流程圖的顏色跟著主色
      return { message: safe === hex ? `main colour → ${hex}` : `main colour → ${safe} (${hex} was too light for white button text, so it was darkened to stay readable)`, changed: true };
    },
  },
  {
    name: "set_background",
    example: { say: "Make the footer black", args: { action: "set_background", target: "footer", color: "black" } },
    description: "Change the background colour of the whole page, the hero banner or the footer. Only when the owner says background (背景 / 背景色 / fundo / fondo).",
    params: [P("target", "enum", { values: ["page", "hero", "footer"] }), P("color", "color")],
    run(c, a) {
      const hex = c.resolveColor(a.color);
      const sel = { page: "body", hero: ".bk-hero", footer: ".bk-footer" }[a.target];
      const style = a.target === "hero" ? { "background-image": "none", "background-color": hex } : { "background-color": hex };
      (c.editor.Css.getRule(sel) || c.editor.Css.setRule(sel, {})).addStyle(style);
      const fixed = c.autofix(c.audit().filter((i) => i.rule === "contrast"));
      return { message: `${a.target} background → ${hex}${fixed ? ` (text colour adjusted in ${fixed} place(s) so it stays readable)` : ""}`, changed: true };
    },
  },
  {
    name: "set_hero_image",
    example: { say: "Use https://example.com/shop.jpg as the banner picture", args: { action: "set_hero_image", url: "https://example.com/shop.jpg" } },
    description: "Use a picture as the hero banner background. Needs a web address (https://…) of a picture written by the owner. An empty url removes the picture.",
    params: [P("url", "url", { allowEmpty: true })],
    run(c, a) {
      const hero = c.q(".bk-hero")[0];
      if (!hero) throw new Error("this page has no hero banner");
      if (!a.url) {
        const st = { ...hero.getStyle() };
        delete st["background-image"];
        hero.setStyle(st);
      } else {
        hero.addStyle({ "background-image": `linear-gradient(rgba(250,246,241,.55),rgba(250,246,241,.55)),url("${a.url.replace(/"/g, "%22")}")` });
      }
      return { message: a.url ? "hero picture set" : "hero picture removed", changed: true };
    },
  },
  {
    name: "set_line_link",
    example: { say: "Send the LINE button to https://line.me/R/ti/p/@mia", args: { action: "set_line_link", url: "https://line.me/R/ti/p/@mia" } },
    description: "Set where the green LINE button goes. Needs a web address (https://…) written by the owner.",
    params: [P("url", "url")],
    run(c, a) {
      const b = c.q(".bk-pill.line")[0];
      if (!b) throw new Error("this page has no LINE button");
      b.addAttributes({ href: a.url });
      return { message: `LINE button → ${a.url}`, changed: true };
    },
  },
  {
    name: "set_section",
    example: { say: "Hide the opening hours", args: { action: "set_section", section: "hours", visible: false } },
    description: "Hide or show a section of the page: the price list, the opening hours or the floating buttons (浮かぶボタン / 浮動按鈕 / botões flutuantes / botones flotantes). Hidden sections keep their content.",
    params: [P("section", "enum", { values: SECTIONS, hint: "price=the price list, hours=the opening hours, float=the floating buttons at the bottom right, flow=the flow charts of the booking and service steps, faq=the questions and answers, availability=the booking calendar showing busy times" }), P("visible", "bool", { hint: "false to hide, true to show" })],
    run(c, a) {
      const cur = c.sectionComp(a.section);
      const hidden = !cur || cur.getStyle().display === "none";
      if (a.visible) {
        if (!cur) c.insertSection(a.section); // 舊專案裡這個區塊已被刪掉：補回範本版本
        else if (hidden) c.setHidden(cur, false);
        else return { message: `${a.section} is already visible`, changed: false };
        return { message: `${a.section} shown`, changed: true };
      }
      if (!cur || hidden) return { message: `${a.section} is already hidden`, changed: false };
      c.setHidden(cur, true); // 只是隱藏（display:none），內容保留，之後可以再顯示
      return { message: `${a.section} hidden`, changed: true };
    },
  },
  {
    name: "show",
    example: { say: "Show me the prices", args: { action: "show", section: "price" } },
    description: "Scroll to a part of the page and select it in the editor so the owner can look at it.",
    params: [P("section", "enum", { values: VIEW_SECTIONS })],
    run(c, a) {
      const comp = c.sectionComp(a.section) || c.q({ nav: "header", hero: ".bk-hero", services: "#services", flow: "#flow", faq: "#faq", availability: "#availability", price: "#price", booking: "#booking", hours: ".bk-hours", footer: ".bk-footer" }[a.section])[0];
      if (!comp) throw new Error(`${a.section} is not on this page`);
      c.editor.select(comp);
      comp.getEl()?.scrollIntoView({ block: "start", behavior: "smooth" });
      return { message: `showing ${a.section}`, changed: false };
    },
  },
  {
    name: "set_device",
    example: { say: "Preview it on a phone", args: { action: "set_device", device: "mobile" } },
    description: "Preview the page as desktop, tablet or phone.",
    params: [P("device", "enum", { values: Object.keys(DEVICES) })],
    run(c, a) {
      c.editor.setDevice(DEVICES[a.device]);
      return { message: `preview: ${a.device}`, changed: false };
    },
  },
  {
    name: "set_flow",
    example: { say: "Show the booking steps as a chart: choose a menu, pick a time, enter details, get a confirmation", args: { action: "set_flow", which: "booking", steps: "Choose a menu; Pick a time; Enter your details; Get a confirmation" } },
    description: "Draw or change a flow chart (made with Mermaid) of the booking steps or of the service process on the day (流れ図 / 流程圖 / fluxograma / diagrama de flujo). Give the steps in order, separated by semicolons.",
    params: [
      P("which", "enum", { values: ["booking", "service"], hint: "booking=the steps to book online, service=what happens when the customer visits" }),
      P("steps", "string", { max: 300, hint: "2 to 7 short steps separated by semicolons, in the page language" }),
    ],
    async run(c, a) {
      const steps = c.parseSteps(a.steps);
      if (steps.length < 2) throw new Error("a flow chart needs at least two steps");
      await c.setFlow(a.which, steps);
      return { message: `flow chart (${a.which}) → ${steps.join(" → ")}`, changed: true };
    },
  },
  {
    name: "set_theme",
    example: { say: "Make the whole site look high-tech and dark", args: { action: "set_theme", theme: "tech" } },
    description: "Switch the look of the whole page: soft = warm light colors (default), tech = dark high-tech look with glowing accents (ハイテク・ダーク / 科技感・深色 / visual tecnológico escuro / aspecto tecnológico oscuro).",
    params: [P("theme", "enum", { values: ["soft", "tech"], hint: "tech=dark high-tech look, soft=warm light look" })],
    run(c, a) {
      const w = c.editor.getWrapper();
      const on = w.getClasses().includes("bk-tech");
      if (a.theme === "tech" && !on) w.addClass("bk-tech");
      else if (a.theme === "soft" && on) w.removeClass("bk-tech");
      else return { message: `theme already ${a.theme}`, changed: false };
      return { message: `theme → ${a.theme}`, changed: true };
    },
  },
  {
    name: "replace_list",
    internal: true,
    example: { say: "(app only)", args: { action: "replace_list", list: "faq", rows: "Question one|Answer one; Question two|Answer two" } },
    description: "Replace every row of a list at once. Only the app uses it, to regenerate a part of the page.",
    params: [P("list", "enum", { values: LISTS }), P("rows", "string", { max: 1500, hint: "rows separated by semicolons, cells separated by |" })],
    run(c, a) {
      const rows = a.rows.split(";").map((r) => r.split("|").map((x) => x.trim())).filter((r) => r[0]).slice(0, MAX_ROWS[a.list]);
      if (rows.length < MIN_ROWS[a.list]) throw new Error(`${a.list} needs at least ${MIN_ROWS[a.list]} row(s)`);
      c.writeList(a.list, rows);
      return { message: `${a.list} replaced with ${rows.length} rows`, changed: true };
    },
  },
  {
    name: "set_google_form",
    internal: true,
    example: { say: "(app only)", args: { action: "set_google_form", config: "{}" } },
    description: "Rebuild the booking form from the questions of a public Google Form; bookings are then sent to that form. Only the app uses it.",
    params: [P("config", "string", { max: 12000, hint: "JSON: {action, pages, fields:[{entry,label,kind,options,required}]}" })],
    run(c, a) {
      let cfg;
      try {
        cfg = JSON.parse(a.config);
      } catch {
        throw new Error("the Google Form settings could not be read");
      }
      const form = c.q("form.bk-form")[0];
      if (!form) throw new Error("this page has no booking form");
      if (!/^https:\/\/docs\.google\.com\/forms\/d\/e\/[\w-]+\/formResponse$/.test(cfg.action || "")) throw new Error("not a Google Form address");
      const fields = (cfg.fields || []).slice(0, 30);
      if (!fields.length) throw new Error("the Google Form has no questions");
      const e = c.esc;
      const req = (f) => (f.required ? ` <small class="bk-req">${e(c.requiredText())}</small>` : "");
      const attr = (f) => `name="${e(f.entry)}" data-label="${e(f.label)}"${f.required ? " required" : ""}`;
      const opt = (f) => (f.options || []).map((o) => `<option>${e(o)}</option>`).join("");
      const ctl = (f) => {
        const lab = f.label.toLowerCase();
        switch (f.kind) {
          case "paragraph":
            return `<label><span>${e(f.label)}${req(f)}</span><textarea ${attr(f)} rows="3"></textarea></label>`;
          case "dropdown":
            return `<label><span>${e(f.label)}${req(f)}</span><select ${attr(f)}><option value=""></option>${opt(f)}</select></label>`;
          case "radio":
            return `<fieldset class="bk-choice"><legend>${e(f.label)}${req(f)}</legend>${(f.options || []).map((o) => `<label><input type="radio" ${attr(f)} value="${e(o)}"> <span>${e(o)}</span></label>`).join("")}</fieldset>`;
          case "checkbox":
            return `<fieldset class="bk-choice"${f.required ? " data-required" : ""}><legend>${e(f.label)}${req(f)}</legend>${(f.options || []).map((o) => `<label><input type="checkbox" name="${e(f.entry)}" data-label="${e(f.label)}" value="${e(o)}"> <span>${e(o)}</span></label>`).join("")}</fieldset>`;
          case "date":
            return `<label><span>${e(f.label)}${req(f)}</span><input type="date" data-gdate ${attr(f)}></label>`;
          case "time":
            return `<label><span>${e(f.label)}${req(f)}</span><input type="time" data-gtime ${attr(f)}></label>`;
          default: {
            const type = /e-?mail|メール|correo|电子邮|電子郵|郵件/.test(lab) ? "email" : /phone|tel\b|電話|电话|telefone|teléfono|手機|手机/.test(lab) ? "tel" : "text";
            return `<label><span>${e(f.label)}${req(f)}</span><input type="${type}" ${attr(f)}></label>`;
          }
        }
      };
      const submit = form.getEl() ? form.getEl().querySelector("button[type=submit]")?.textContent.trim() : "";
      form.components(`${fields.map(ctl).join("\n")}<button type="submit" class="bk-pill lg">${e(submit || "OK")}</button><p data-booking-status role="status" aria-live="polite"></p>`);
      form.addAttributes({ "data-gform": cfg.action });
      if (cfg.pages > 1) form.addAttributes({ "data-pages": Array.from({ length: cfg.pages }, (_, i) => i).join(",") });
      else form.removeAttributes("data-pages");
      return { message: `booking form ← Google Form (${fields.length} questions, ${fields.filter((f) => f.required).length} required)`, changed: true };
    },
  },
  {
    name: "set_calendar",
    internal: true,
    example: { say: "(app only)", args: { action: "set_calendar", calendarId: "abc@group.calendar.google.com" } },
    description: "Show a public Google Calendar (free/busy only) as the availability section, above the booking form. Only the app uses it.",
    params: [P("calendarId", "string", { max: 200 })],
    run(c, a) {
      if (!/^[\w.%+-]+@[\w.-]+$/.test(a.calendarId)) throw new Error("not a calendar ID");
      let sec = c.sectionComp("availability");
      if (!sec) {
        c.insertSection("availability");
        sec = c.sectionComp("availability");
      } else if (sec.getStyle().display === "none") c.setHidden(sec, false);
      const findTag = (comp, tag) => {
        if (comp.get("tagName") === tag) return comp;
        for (const ch of comp.components().models) {
          const hit = findTag(ch, tag);
          if (hit) return hit;
        }
        return null;
      };
      const frame = findTag(sec, "iframe"); // 剛插入的區塊還沒有畫面元素，所以走元件樹而不是 DOM 查詢
      if (!frame) throw new Error("the availability section has no calendar frame");
      const tz = (Intl.DateTimeFormat().resolvedOptions().timeZone || "").replace(/[^\w/+-]/g, "");
      const src = `https://calendar.google.com/calendar/embed?src=${encodeURIComponent(a.calendarId)}&mode=WEEK&showTitle=0&showPrint=0&showTabs=0&showCalendars=0&showTz=0&hl=${encodeURIComponent(c.getLang())}${tz ? `&ctz=${encodeURIComponent(tz)}` : ""}`;
      frame.addAttributes({ src });
      return { message: `availability calendar → ${a.calendarId}`, changed: true };
    },
  },
  {
    name: "clear_calendar",
    internal: true,
    example: { say: "(app only)", args: { action: "clear_calendar" } },
    description: "Remove the availability calendar section. Only the app uses it.",
    params: [],
    run(c) {
      const sec = c.sectionComp("availability");
      if (!sec) return { message: "no calendar section", changed: false };
      sec.remove();
      return { message: "availability section removed", changed: true };
    },
  },
  {
    name: "clear_google_form",
    internal: true,
    example: { say: "(app only)", args: { action: "clear_google_form" } },
    description: "Stop sending bookings to a Google Form. Only the app uses it.",
    params: [],
    run(c) {
      const form = c.q("form.bk-form")[0];
      if (!form || !form.getAttributes()["data-gform"]) return { message: "no Google Form connected", changed: false };
      form.removeAttributes("data-gform");
      form.removeAttributes("data-pages");
      return { message: "Google Form disconnected", changed: true };
    },
  },
  {
    name: "add_form_field",
    description: "Add one more question to the booking form, for example the number of guests, the preferred stylist, first visit or return visit, allergies, or the purpose of use (質問を追加 / 新增問題 / adicionar pergunta / añadir pregunta). Use kind select when there are fixed choices.",
    example: { say: "Ask how many guests are coming", args: { action: "add_form_field", label: "Number of guests", kind: "number" } },
    params: [
      P("label", "string", { max: 30 }),
      P("kind", "enum", { values: ["text", "number", "select", "textarea"], hint: "number=a count, select=pick one of the options, text=short answer, textarea=long answer" }),
      P("options", "string", { max: 120, required: false, hint: "only for select: the choices separated by commas, e.g. \"First visit, Returning\"" }),
      P("required", "bool", { required: false }),
    ],
    run(c, a) {
      const form = c.q("form.bk-form")[0];
      const notes = c.q('textarea[name="notes"]')[0];
      if (!form || !notes) throw new Error("this page has no booking form");
      const extra = c.q("[data-extra]");
      if (extra.length >= 4) throw new Error("the booking form already has 4 extra questions");
      const labelOf = (x) => (x.getEl() ? x.getEl().querySelector("span").textContent.replace(/\s*\(.*?\)|（.*?）/g, "").trim() : "");
      if (extra.some((x) => labelOf(x).toLowerCase() === a.label.toLowerCase())) throw new Error(`the form already asks “${a.label}”`);
      const opts = (a.options || "").split(/[,、，]/).map((x) => x.trim()).filter(Boolean).slice(0, 6);
      if (a.kind === "select" && opts.length < 2) throw new Error("a select question needs at least two options");
      const n = Date.now().toString(36).slice(-4) + extra.length;
      const name = `field_${n}`;
      const req = a.required === true;
      const ctl = {
        text: `<input name="${name}" data-label="${c.esc(a.label)}"${req ? " required" : ""}>`,
        number: `<input name="${name}" data-label="${c.esc(a.label)}" type="number" min="1" inputmode="numeric"${req ? " required" : ""}>`,
        textarea: `<textarea name="${name}" data-label="${c.esc(a.label)}" rows="3"${req ? " required" : ""}></textarea>`,
        select: `<select name="${name}" data-label="${c.esc(a.label)}"${req ? " required" : ""}>${opts.map((o) => `<option>${c.esc(o)}</option>`).join("")}</select>`,
      }[a.kind];
      const html = `<label data-extra="1"><span>${c.esc(a.label)}${req ? ` <small class="bk-req">${c.esc(c.requiredText())}</small>` : ""}</span>${ctl}</label>`;
      const at = form.components().indexOf(notes.parent());
      form.append(html, at >= 0 ? { at } : undefined);
      return { message: `booking form + ${a.label}${a.kind === "select" ? ` (${opts.join(" / ")})` : ""}`, changed: true };
    },
  },
  {
    name: "remove_form_field",
    description: "Remove a question that was added to the booking form (not a button). The basic questions (name, phone, email, service, date, time, notes) stay.",
    example: { say: "Stop asking for the number of guests", args: { action: "remove_form_field", label: "guests" } },
    params: [P("label", "string", { max: 30, hint: "a word from the question" })],
    run(c, a) {
      const hit = c.q("[data-extra]").find((x) => x.getEl() && x.getEl().textContent.toLowerCase().includes(a.label.toLowerCase()));
      if (!hit) throw new Error(`no added question matches “${a.label}”`);
      hit.remove();
      return { message: `booking form − ${a.label}`, changed: true };
    },
  },
  {
    name: "check_quality",
    description: "Check the page against the accessibility and quality cheat sheet (text contrast, button size, headings, labels, landmarks) and fix what can be fixed automatically.",
    example: { say: "Check that the page is easy to read and accessible", args: { action: "check_quality" } },
    params: [],
    run(c) {
      const before = c.audit();
      const fixed = c.autofix(before);
      const after = c.audit();
      return {
        message: before.length === 0 ? "No problems found" : `${before.length} problem(s) found, ${fixed} fixed automatically, ${after.length} left`,
        details: after.map((i) => i.message),
        changed: fixed > 0,
      };
    },
  },
  {
    name: "undo",
    example: { say: "Undo that", args: { action: "undo" } },
    description: "Undo the last change made through chat.",
    params: [],
    run(c) {
      if (!c.undo()) throw new Error("nothing to undo");
      return { message: "undone", changed: false };
    },
  },
];

// ---- 參數驗證 ----
const URL_RE = /^(https?:\/\/|data:image\/)[^\s]+$/i;

function checkParam(spec, v, c) {
  const missing = v === undefined || v === null || (typeof v === "string" && v.trim() === "" && !spec.allowEmpty);
  if (missing) {
    if (spec.required) throw new Error(`"${spec.name}" is required`);
    return undefined;
  }
  switch (spec.type) {
    case "string": {
      const s = String(v).trim();
      if (!s && !spec.allowEmpty) throw new Error(`"${spec.name}" is empty`);
      if (/^[.…\-–—_?\s]+$/.test(s) && s) throw new Error(`"${spec.name}" looks like a placeholder`);
      return s.slice(0, spec.max || 120);
    }
    case "number": {
      const n = Number(v);
      if (!Number.isFinite(n)) throw new Error(`"${spec.name}" must be a number`);
      if (n < spec.min || n > spec.max) throw new Error(`"${spec.name}" must be between ${spec.min} and ${spec.max}`);
      return n;
    }
    case "bool":
      if (typeof v === "boolean") return v;
      if (/^(true|yes|show|on|1)$/i.test(String(v))) return true;
      if (/^(false|no|hide|off|0)$/i.test(String(v))) return false;
      throw new Error(`"${spec.name}" must be true or false`);
    case "enum": {
      const s = String(v).trim();
      const hit = spec.values.find((x) => x.toLowerCase() === s.toLowerCase());
      if (!hit) throw new Error(`"${spec.name}" must be one of ${spec.values.join(", ")}`);
      return hit;
    }
    case "row":
      return typeof v === "number" ? v : /^\d+$/.test(String(v).trim()) ? parseInt(v, 10) : String(v).trim();
    case "color":
      c.resolveColor(v); // 不合法會丟錯
      return String(v).trim();
    case "url": {
      const s = String(v).trim();
      if (!s && spec.allowEmpty) return "";
      if (!URL_RE.test(s)) throw new Error(`"${spec.name}" must start with http:// or https://`);
      return s;
    }
    default:
      throw new Error(`unknown parameter type ${spec.type}`);
  }
}

/** 建立動作執行器：editor 是 GrapesJS 實例，deps 是範本提供的 HTML 產生函式 */
export function createActions(editor, deps) {
  const { esc, svcRowsHtml, priceRowsHtml, faqRowsHtml, sectionHtml, getLang, requiredText, renderFlow } = deps;
  const undoStack = [];

  const q = (sel) => editor.getWrapper().find(sel);
  const html = (text) => esc(text).replace(/\n/g, "<br>");
  const textOf = (el) => {
    if (!el) return "";
    const c = el.cloneNode(true);
    c.querySelectorAll("br").forEach((b) => b.replaceWith("\n"));
    return c.textContent.trim();
  };

  // ---- 色彩 ----
  const hexToRgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
  const rgbToHex = (c) => "#" + c.map((v) => Math.round(v).toString(16).padStart(2, "0")).join("");
  function toHsl([r, g, b]) {
    r /= 255; g /= 255; b /= 255;
    const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2;
    if (mx === mn) return [0, 0, l];
    const d = mx - mn, s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
    const h = mx === r ? (g - b) / d + (g < b ? 6 : 0) : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
    return [h * 60, s, l];
  }
  function fromHsl([h, s, l]) {
    const c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs(((h / 60) % 2) - 1)), m = l - c / 2;
    const [r, g, b] = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
    return [(r + m) * 255, (g + m) * 255, (b + m) * 255];
  }
  const shade = (rgb, dl) => { const [h, s, l] = toHsl(rgb); return fromHsl([h, s, Math.min(1, Math.max(0, l + dl))]); };
  const palette = (hex) => { const p = hexToRgb(hex); return [hex, rgbToHex(shade(p, 0.1)), rgbToHex(shade(p, -0.06))]; };
  const currentPalette = () => {
    try { return JSON.parse(editor.getWrapper().getAttributes()["data-pal"]); } catch { return PAL0; }
  };
  function resolveColor(v) {
    const s = String(v).trim().toLowerCase();
    if (/^#[0-9a-f]{6}$/.test(s)) return s;
    if (/^#[0-9a-f]{3}$/.test(s)) return "#" + [...s.slice(1)].map((x) => x + x).join("");
    const hit = COLOR_NAMES[s] || COLOR_NAMES[String(v).trim()];
    if (!hit) throw new Error(`unknown colour "${v}" (use a common colour name or #rrggbb)`);
    return hit;
  }
  /** 把 CSS 裡舊的主色 / 淺色 / 深色（hex 或 rgb()）換成新色 */
  function recolor(oldPal, newPal) {
    const olds = oldPal.map(hexToRgb), news = newPal.map(hexToRgb);
    const sub = (v) =>
      String(v).replace(/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)|#([0-9a-fA-F]{6})\b/g, (m, r, g, b, a, h) => {
        const t = h ? hexToRgb("#" + h) : [+r, +g, +b];
        const i = olds.findIndex((o) => o[0] === t[0] && o[1] === t[1] && o[2] === t[2]);
        if (i < 0) return m;
        return h ? newPal[i] : a !== undefined ? `rgba(${news[i].join(", ")}, ${a})` : `rgb(${news[i].join(", ")})`;
      });
    editor.Css.getRules().forEach((rule) => {
      const st = rule.getStyle();
      let changed = false;
      for (const k of Object.keys(st)) {
        const nv = sub(st[k]);
        if (nv !== st[k]) { st[k] = nv; changed = true; }
      }
      if (changed) rule.setStyle(st);
    });
  }

  // ---- 列表（服務 / 價格 / 營業時間）----
  const LIST_SEL = { services: '[data-f="svc"]', prices: '[data-f="price"]', hours: '[data-f="hours"]', faq: '[data-f="faq"]' };
  function readList(name) {
    const doc = editor.Canvas.getDocument();
    const all = (sel) => [...doc.querySelectorAll(sel)];
    if (name === "services") return all(".bk-svc").map((e) => [textOf(e.querySelector("h3")), textOf(e.querySelector("small"))]);
    if (name === "prices") return all(".bk-price-list > div").map((e) => [textOf(e.querySelector("span")), textOf(e.querySelector("b"))]);
    if (name === "faq") return all(".bk-qa").map((e) => [textOf(e.querySelector("summary")), textOf(e.querySelector("p"))]);
    return all(".bk-hours tr").map((e) => [...e.querySelectorAll("td")].map(textOf));
  }
  function writeList(name, rows) {
    const c = q(LIST_SEL[name])[0];
    if (!c) throw new Error(`this page has no ${name} list`);
    if (name === "services") {
      c.components(svcRowsHtml(rows));
      const sel = q('[data-f="opts"]')[0];
      if (sel) sel.components(rows.map((r) => `<option>${esc(r[0])}</option>`).join(""));
    } else if (name === "prices") {
      c.components(priceRowsHtml(rows));
    } else if (name === "faq") {
      c.components(faqRowsHtml(rows.map((r) => [esc(r[0]), esc(r[1] || "")])));
    } else {
      // <tr> 在 HTML 字串解析時（不在 table 內）會被瀏覽器丟掉，所以營業時間用元件資料建立
      c.components(rows.map((r) => ({ tagName: "tr", components: [0, 1].map((i) => ({ tagName: "td", components: [{ type: "textnode", content: String(r[i] || "") }] })) })));
    }
  }
  /** 依列號（1 起算）或列內文字找列；找不到回傳 -1 */
  function findRow(rows, ref) {
    if (typeof ref === "number") return ref >= 1 && ref <= rows.length ? ref - 1 : -1;
    const s = String(ref).toLowerCase();
    if (s === "last") return rows.length - 1;
    if (s === "first") return 0;
    return rows.findIndex((r) => r.some((cell) => String(cell).toLowerCase().includes(s)));
  }

  // ---- 區塊 ----
  const sectionComp = (key) => {
    if (key === "price") return q("#price")[0];
    if (key === "flow") return q("#flow")[0];
    if (key === "faq") return q("#faq")[0];
    if (key === "availability") return q("#availability")[0];
    if (key === "float") return q(".bk-float")[0];
    if (key === "hours") {
      let c = q(".bk-hours")[0];
      while (c && c.get("tagName") !== "section") c = c.parent();
      return c;
    }
    const sel = { nav: "header", hero: ".bk-hero", services: "#services", booking: "#booking", footer: ".bk-footer" }[key];
    return sel ? q(sel)[0] : undefined;
  };
  /** 隱藏 / 顯示：用 display:none，內容與設定都保留（GrapesJS：component.addStyle / setStyle） */
  function setHidden(comp, hide) {
    if (hide) comp.addStyle({ display: "none" });
    else {
      const st = { ...comp.getStyle() };
      delete st.display;
      comp.setStyle(st);
    }
  }
  function insertSection(key) {
    const tplKey = { price: "pricing", hours: "hours", float: "float", flow: "flow", faq: "faq", availability: "availability" }[key];
    const before = { price: q("#booking")[0], hours: q("#contact")[0], flow: q("#price")[0], faq: q("#booking")[0], availability: q("#booking")[0] }[key];
    const parent = before ? before.parent() : editor.getWrapper();
    const at = before ? parent.components().indexOf(before) : -1;
    parent.append(sectionHtml(getLang(), tplKey), at >= 0 ? { at } : undefined);
  }

  // ---- 復原：每批動作前存整份專案 ----
  function undo() {
    const prev = undoStack.pop();
    if (!prev) return false;
    editor.loadProjectData(JSON.parse(prev));
    return true;
  }

  // ---- 對比與品質檢查（Digital Agency 網站指引 / SmartHR 無障礙準則的可檢查項目）----
  const view = () => editor.Canvas.getWindow();
  const cs = (el) => view().getComputedStyle(el);
  const parseColor = (s) => {
    const m = String(s).match(/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)/);
    return m ? { c: [+m[1], +m[2], +m[3]], a: m[4] === undefined ? 1 : +m[4] } : null;
  };
  const lum = (c) => {
    const f = c.map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); });
    return 0.2126 * f[0] + 0.7152 * f[1] + 0.0722 * f[2];
  };
  const ratio = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };
  const WHITE = [255, 255, 255], INK = [31, 27, 24];
  const MIN_RATIO = 4.5, MIN_RATIO_LARGE = 3;

  /** 元素背後的底色。底色是漸層時回傳漸層裡所有顏色（取最壞情況）；背景圖片則無法判斷（回傳 null） */
  function backdrop(el) {
    for (let e = el; e && e.nodeType === 1; e = e.parentElement) {
      const st = cs(e);
      const bg = parseColor(st.backgroundColor);
      if (bg && bg.a > 0.5) return [bg.c];
      if (st.backgroundImage && st.backgroundImage !== "none") {
        if (/url\(/.test(st.backgroundImage) && !/gradient/.test(st.backgroundImage)) return null;
        const cols = [...st.backgroundImage.matchAll(/rgba?\(\d+,\s*\d+,\s*\d+(?:,\s*[\d.]+)?\)/g)].map((m) => parseColor(m[0])).filter((x) => x && x.a > 0.5).map((x) => x.c);
        return cols.length ? cols : null;
      }
    }
    return [WHITE];
  }
  const describe = (el) => `${el.tagName.toLowerCase()}${el.className && typeof el.className === "string" ? "." + el.className.trim().split(/\s+/)[0] : ""} “${(el.textContent || "").trim().slice(0, 24)}”`;
  const compOf = (el) => (el.__gjsv && el.__gjsv.model) || null;
  const visible = (el) => { const st = cs(el); return st.display !== "none" && st.visibility !== "hidden" && el.getClientRects().length > 0; };
  const hasOwnText = (el) => [...el.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim());

  function applyPalette(hex) {
    const next = palette(hex);
    recolor(currentPalette(), next);
    editor.getWrapper().addAttributes({ "data-pal": JSON.stringify(next) });
    return next;
  }
  /** 主色與白字的對比不到 4.5 時，往深色調整到達標為止 */
  function darkenForWhiteText(hex) {
    let rgb = hexToRgb(hex), i = 0;
    while (ratio(WHITE, rgb) < MIN_RATIO && i++ < 40) rgb = shade(rgb, -0.02);
    return rgbToHex(rgb);
  }

  /** 檢查目前頁面，回傳問題清單 [{rule, message, kind, el}] */
  function audit() {
    const doc = editor.Canvas.getDocument();
    const issues = [];
    const add = (rule, message, kind, el) => issues.push({ rule, message, kind, el });

    // 對比：所有有文字的可見元素
    const seen = new Set();
    for (const el of doc.body.querySelectorAll("*")) {
      if (!hasOwnText(el) || el.closest("[aria-hidden='true']") || el.closest(".bk-skip") || !visible(el)) continue;
      const st = cs(el);
      const fg = parseColor(st.color);
      const bgs = backdrop(el);
      if (!fg || !bgs) continue;
      const px = parseFloat(st.fontSize), bold = parseInt(st.fontWeight, 10) >= 700;
      const need = px >= 24 || (px >= 18.66 && bold) ? MIN_RATIO_LARGE : MIN_RATIO;
      const worst = Math.min(...bgs.map((b) => ratio(fg.c, b)));
      if (worst < need) {
        const key = describe(el);
        if (seen.has(key)) continue;
        seen.add(key);
        const pill = el.matches(".bk-pill, .bk-float a");
        add("contrast", `Low contrast ${worst.toFixed(1)}:1 (needs ${need}:1): ${key}`, pill ? "pill" : "text", el);
      }
      if (px < 12) add("text-size", `Text is smaller than 12px: ${describe(el)}`, "size", el);
    }
    // 操作目標大小（至少 44px 高）
    for (const el of doc.querySelectorAll(".bk-pill, .bk-float a, button")) {
      if (!visible(el)) continue;
      const h = el.getBoundingClientRect().height;
      if (h < 43.5) add("tap-target", `Button is only ${Math.round(h)}px tall (44px or more is easier to tap): ${describe(el)}`, "tap", el);
    }
    // 標題：恰好一個 h1、層級不跳級
    const heads = [...doc.querySelectorAll("h1,h2,h3,h4,h5,h6")].filter(visible);
    const h1s = heads.filter((h) => h.tagName === "H1").length;
    if (h1s !== 1) add("headings", `The page needs exactly one main heading (h1); it has ${h1s}`, "info");
    let prev = 0;
    for (const h of heads) {
      const lv = +h.tagName[1];
      if (prev && lv > prev + 1) add("headings", `Heading level jumps from h${prev} to h${lv}: ${describe(h)}`, "info");
      prev = lv;
    }
    // 圖片替代文字
    for (const img of doc.querySelectorAll("img:not([alt])")) add("alt-text", "An image has no alt text", "info", img);
    // 連結 / 按鈕要有可辨識的名稱
    for (const el of doc.querySelectorAll("a[href], button")) {
      const name = (el.textContent || "").trim() || el.getAttribute("aria-label") || el.getAttribute("title") || (el.querySelector("img[alt]") || {}).alt;
      if (!name) add("link-text", "A link or button has no readable name", "info", el);
    }
    // 表單欄位要有標籤
    for (const el of doc.querySelectorAll("input:not([type=hidden]), select, textarea")) {
      const labelled = el.closest("label") || el.getAttribute("aria-label") || (el.id && doc.querySelector(`label[for="${el.id}"]`));
      if (!labelled) add("form-label", `A form field has no label: ${el.getAttribute("name") || el.tagName}`, "info", el);
    }
    // SEO：搜尋結果顯示的說明文字、在地搜尋的地址
    const leadEl = doc.querySelector('[data-f="lead"]');
    const leadLen = leadEl ? leadEl.textContent.trim().length : 0;
    if (leadEl && (leadLen < 12 || leadLen > 200)) add("seo", `The sentence under the headline becomes the search-result description; ${leadLen < 12 ? "it is very short" : "it is too long"} (aim for about 20 to 150 characters)`, "info");
    const addrEl = doc.querySelector('[data-f="addr"]');
    if (addrEl && !addrEl.textContent.trim()) add("seo", "The address is empty; local search results need the business address", "info");
    // 地標
    if (!doc.querySelector("main")) add("landmarks", "The page has no <main> area", "info");
    if (!doc.querySelector(".bk-skip")) add("landmarks", "There is no “skip to main content” link for keyboard users", "info");
    return issues;
  }

  /** 修正能自動修的問題（對比、操作目標大小）；回傳修了幾項 */
  function autofix(issues) {
    let fixed = 0;
    let darkenedPrimary = false;
    for (const i of issues) {
      if (i.kind === "pill" && !darkenedPrimary) {
        darkenedPrimary = true;
        const next = darkenForWhiteText(currentPalette()[0]);
        if (next !== currentPalette()[0]) { applyPalette(next); fixed++; }
      } else if (i.kind === "text" || i.kind === "pill") {
        const comp = compOf(i.el);
        const bgs = backdrop(i.el);
        if (!comp || !bgs) continue;
        const bg = bgs[0];
        comp.addStyle({ color: ratio(INK, bg) >= ratio(WHITE, bg) ? "#1f1b18" : "#ffffff" });
        fixed++;
      } else if (i.kind === "tap") {
        const comp = compOf(i.el);
        if (comp) { comp.addStyle({ "min-height": "44px" }); fixed++; }
      }
    }
    return fixed;
  }

  // ---- 流程圖（Mermaid）：steps 存在 <img> 的 data-steps，重新著色時用同樣的步驟重畫 ----
  const flowImg = (which) => q(`[data-f="flow-${which}"]`)[0];
  const parseSteps = (s) => s.split(/[;；→>\n|]/).map((x) => x.replace(/^\s*\d+[.)、]\s*/, "").trim()).filter(Boolean).map((x) => x.slice(0, 28)).slice(0, 7);
  async function setFlow(which, steps) {
    if (!flowImg(which)) insertSection("flow"); // 區塊被刪掉的舊專案：補回範本版本
    const img = flowImg(which);
    if (!img) throw new Error("this page has no flow chart section");
    const uri = await renderFlow(steps, currentPalette()[0]);
    img.set("src", uri); // 圖片元件的來源要用 src 屬性（property），改 attribute 編輯器畫布不會更新
    img.addAttributes({ alt: steps.join(" → "), "data-steps": steps.join("|") });
  }
  /** 範本剛套用或主色改變之後，把所有流程圖依目前步驟與主色重畫 */
  async function refreshFlows() {
    for (const which of ["booking", "service"]) {
      const img = flowImg(which);
      const steps = img ? String(img.getAttributes()["data-steps"] || "").split("|").filter(Boolean) : [];
      if (img && steps.length >= 2) await setFlow(which, steps);
    }
  }

  const ctx = { getLang, editor, esc, requiredText, parseSteps, setFlow, refreshFlows, audit, autofix, applyPalette, darkenForWhiteText, q, html, readList, writeList, findRow, resolveColor, palette, recolor, currentPalette, sectionComp, insertSection, setHidden, undo };

  return {
    /** 給模型看的目錄（可序列化） */
    /** 偵錯用：目前的品質問題清單（不修正） */
    auditMessages: () => audit().map((i) => i.message),

    catalog: () => ACTIONS.filter((x) => !x.internal).map(({ name, description, params, example }) => ({ name, description, params, example })),

    /** 目前網站內容的快照（給模型當上下文）。列表附列號。 */
    snapshot() {
      const doc = editor.Canvas.getDocument();
      const o = {};
      for (const f of TEXT_TARGETS) {
        const el = doc.querySelector(`[data-f="${f}"]`);
        if (el) o[f] = textOf(el);
      }
      o.services = readList("services");
      o.prices = readList("prices");
      o.hours = readList("hours");
      o.faq = readList("faq");
      o.theme = editor.getWrapper().getClasses().includes("bk-tech") ? "tech" : "soft";
      o.color = currentPalette()[0];
      o.flows = Object.fromEntries(["booking", "service"].map((w) => [w, flowImg(w) ? String(flowImg(w).getAttributes()["data-steps"] || "").split("|").filter(Boolean) : []]));
      o.formQuestions = q("[data-extra]").map((x) => (x.getEl() ? x.getEl().querySelector("span").textContent.trim() : ""));
      o.hidden = SECTIONS.filter((k) => {
        const c = sectionComp(k);
        return !c || c.getStyle().display === "none";
      });
      return o;
    },

    /** 依序執行動作；每個動作先驗證參數。回傳 { results: 每個動作的結果, undoable: 這批有沒有改到內容 }。 */
    async run(list) {
      const results = [];
      undoStack.push(JSON.stringify(editor.getProjectData()));
      if (undoStack.length > 15) undoStack.shift();
      let anyChange = false;
      let pushed = true;
      for (const item of Array.isArray(list) ? list.slice(0, 8) : []) {
        const name = item && item.action;
        const spec = ACTIONS.find((a) => a.name === name);
        if (!spec) { results.push({ action: String(name), ok: false, message: "unknown action" }); continue; }
        try {
          const args = {};
          for (const p of spec.params) {
            const v = checkParam(p, item[p.name], ctx);
            if (v !== undefined) args[p.name] = v;
          }
          if (name === "undo" && pushed) {
            undoStack.pop(); // 先把這批剛存的快照拿掉，再退回上一批
            pushed = false;
          }
          const r = await spec.run(ctx, args);
          anyChange = anyChange || !!r.changed;
          results.push({ action: name, ok: true, message: r.message });
          for (const d of r.details || []) results.push({ action: name, ok: false, message: d, detail: true });
        } catch (e) {
          results.push({ action: name, ok: false, message: e.message || String(e) });
        }
      }
      if (!anyChange && pushed) undoStack.pop();
      return { results, undoable: anyChange };
    },
    undo,
    refreshFlows,
  };
}
