// GrapesJS 區塊：預約網站常用段落（導覽、首圖、服務、價目表、預約表單、營業時間、頁尾、浮動按鈕）。
// 視覺風格：日系美容診所（奶油米色、暖棕色、明朝體標題、圓形服務圖示、膠囊按鈕、右下浮動 CTA）。
// 預約表單只輸出 data-* 屬性，實際送出行為由 /site-runtime.js 在發佈後的網站接手。價格列表可由 AI 報價（Pricing AI）套用。

export const BASE_CSS = `
*{box-sizing:border-box}
body{margin:0;font-family:"Hiragino Sans","Noto Sans JP","PingFang TC","Noto Sans TC",system-ui,sans-serif;color:#4a3f38;background:#faf6f1;line-height:1.8}
h1,h2,h3,.bk-serif{font-family:"Noto Serif JP","Hiragino Mincho ProN","Songti TC","Noto Serif TC",serif;font-weight:500}
.bk-wrap{max-width:1000px;margin:0 auto;padding:0 20px}
.bk-nav{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:12px 24px;background:#fff;box-shadow:0 1px 6px rgba(90,70,50,.08);flex-wrap:wrap}
.bk-brand{text-decoration:none;color:#4a3f38;font-size:20px;line-height:1.2;font-family:"Noto Serif JP","Hiragino Mincho ProN",serif}
.bk-brand small{display:block;font-size:12px;letter-spacing:.2em;color:#6f6257;font-family:inherit}
.bk-links{display:flex;align-items:center;gap:6px;font-size:13px;flex-wrap:wrap}
.bk-links a{color:#4a3f38;text-decoration:none}
.bk-links a.bk-pill{color:#fff}
.bk-links .sep{color:#b8aa9d}
.bk-pill{display:inline-block;background:#7a6657;color:#fff;padding:9px 20px;line-height:26px;border-radius:999px;text-decoration:none;font-size:14px;border:0;cursor:pointer;font-family:inherit}
.bk-pill.line{background:#04753a}
.bk-pill.soft{background:#efe4d8;color:#4a3f38}
.bk-pill.lg{padding:14px 34px;font-size:16px}
.bk-hero{position:relative;padding:110px 24px 90px;background:linear-gradient(110deg,#fbf7f2 0%,#f3e6dc 55%,#ead6cc 100%);overflow:hidden}
.bk-hero:after{content:"";position:absolute;right:-80px;top:-60px;width:460px;height:460px;border-radius:50%;background:radial-gradient(circle,rgba(255,255,255,.75),rgba(255,255,255,0) 70%)}
.bk-hero .bk-wrap{position:relative;z-index:1}
.bk-hero h1{font-size:44px;line-height:1.5;margin:0 0 36px;color:#3d332c}
.bk-hero h2{font-size:26px;line-height:1.6;margin:0 0 12px;color:#3d332c}
.bk-hero p{margin:0 0 30px;color:#6a5d53}
.bk-section{padding:80px 0}
.bk-section.tint{background:#f3ebe2}
.bk-section h2{text-align:center;font-size:30px;margin:0 0 6px;color:#3d332c}
.bk-eyebrow{text-align:center;font-size:12px;letter-spacing:.3em;color:#6f6257;text-transform:uppercase;margin:0 0 36px}
.bk-svc-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:32px 20px}
.bk-svc{display:block;text-align:center;text-decoration:none;color:#4a3f38}
.bk-svc .ico{width:150px;height:150px;border-radius:50%;margin:0 auto 14px;background:#fff;border:1px solid #e3d6c9;display:flex;align-items:center;justify-content:center;box-shadow:0 10px 24px -12px rgba(122,102,87,.5);position:relative}
.bk-svc .ico:before{content:"";position:absolute;left:-14px;bottom:-8px;width:90px;height:70px;border-radius:50%;background:rgba(238,214,204,.55);z-index:-1}
.bk-svc svg{width:64px;height:64px;stroke:#7a6657;fill:none;stroke-width:1.4;stroke-linecap:round;stroke-linejoin:round}
.bk-svc h3{margin:0;font-size:19px}
.bk-svc small{display:block;color:#6f6257;font-size:13px;font-family:Georgia,serif;font-style:italic}
.bk-price-list{max-width:720px;margin:0 auto;border-top:1px solid #dccfc2}
.bk-price-list div{display:flex;justify-content:space-between;gap:16px;padding:16px 4px;border-bottom:1px solid #dccfc2}
.bk-price-list b{font-weight:500;color:#7a6657}
.bk-form{max-width:580px;margin:0 auto;display:grid;gap:16px;background:#fff;padding:32px;border-radius:18px;box-shadow:0 12px 30px -18px rgba(90,70,50,.35)}
.bk-form label{display:grid;gap:4px;font-size:14px;color:#6a5d53}
.bk-form fieldset.bk-choice{border:0;margin:0;padding:0;display:grid;gap:8px}
.bk-form fieldset.bk-choice legend{padding:0;margin-bottom:6px;font-size:14px;color:#6a5d53}
.bk-form fieldset.bk-choice label{display:flex;align-items:center;gap:8px;font-size:15px;color:#4a3f38}
.bk-form fieldset.bk-choice input{width:auto;margin:0}
.bk-tech .bk-form fieldset.bk-choice legend,.bk-tech .bk-form fieldset.bk-choice label{color:#c7d6ea}
.bk-form input,.bk-form select,.bk-form textarea{font:inherit;padding:10px 12px;border:1px solid #dccfc2;border-radius:10px;width:100%;background:#fdfbf8;color:#4a3f38}
.bk-row{display:grid;grid-template-columns:1fr 1fr;gap:14px}
.bk-hours{max-width:440px;margin:0 auto;width:100%;border-collapse:collapse}
.bk-hours td{padding:10px 0;border-bottom:1px solid #dccfc2}
.bk-hours td:last-child{text-align:right}
.bk-footer{background:#6a5a4d;color:#e8ddd2;padding:44px 20px 100px;text-align:center;font-size:14px}
.bk-footer p{margin:4px 0}
.bk-float{position:fixed;right:18px;bottom:18px;z-index:50;display:grid;gap:10px;justify-items:stretch}
.bk-float a{background:#7a6657;color:#fff;padding:12px 22px;line-height:20px;border-radius:999px;text-decoration:none;font-size:14px;text-align:center;box-shadow:0 6px 16px -6px rgba(60,45,35,.5)}
.bk-float a.dark{background:#6a5a4d}
.bk-flows{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:28px}
.bk-flow{margin:0;background:#fff;border-radius:16px;padding:20px;box-shadow:0 12px 30px -18px rgba(90,70,50,.35)}
.bk-flow figcaption{font-family:"Noto Serif JP","Hiragino Mincho ProN","Songti TC",serif;font-size:18px;color:#3d332c;margin-bottom:10px}
.bk-flow img{width:100%;height:auto;display:block}
.bk-avail iframe{display:block;width:100%;height:520px;border:0;border-radius:14px;background:#fff;box-shadow:0 12px 30px -18px rgba(90,70,50,.35)}
.bk-note{max-width:640px;margin:14px auto 0;text-align:center;font-size:14px;color:#5a4e45}
.bk-tech .bk-note{color:#c7d6ea}
.bk-faq{max-width:720px;margin:0 auto}
.bk-qa{border-bottom:1px solid #dccfc2;padding:14px 4px}
.bk-qa summary{cursor:pointer;font-weight:500;color:#3d332c;font-size:17px}
.bk-qa p{margin:10px 0 0;color:#4a3f38}
body.bk-tech{background:#070b17;color:#dbe7f5;font-family:"Inter","SF Pro Text","Hiragino Sans","Noto Sans JP","PingFang TC","Noto Sans TC",system-ui,sans-serif}
.bk-tech h1,.bk-tech h2,.bk-tech h3,.bk-tech .bk-serif,.bk-tech .bk-brand,.bk-tech .bk-flow figcaption{font-family:"Inter","SF Pro Display","Hiragino Sans","Noto Sans JP","PingFang TC","Noto Sans TC",system-ui,sans-serif;font-weight:700;letter-spacing:-.01em}
.bk-tech .bk-nav{background:#0a1022;box-shadow:0 1px 0 rgba(120,200,255,.2)}
.bk-tech .bk-brand,.bk-tech .bk-links a{color:#e6edf7}
.bk-tech .bk-brand small{color:#a9bdd6}
.bk-tech .bk-hero{background:radial-gradient(900px 420px at 85% -10%,#12395a 0%,rgba(18,57,90,0) 65%),linear-gradient(135deg,#0a1226,#101a3a 60%,#0b1430)}
.bk-tech .bk-hero:after{display:none}
.bk-tech .bk-hero h1,.bk-tech .bk-hero h2,.bk-tech .bk-section h2{color:#f2f7ff}
.bk-tech .bk-hero p{color:#c3d3e8}
.bk-tech .bk-section{background:#070b17;color:#dbe7f5}
.bk-tech .bk-section h2,.bk-tech .bk-section h3,.bk-tech .bk-price-list span{color:#f2f7ff}
.bk-tech .bk-section.tint{background:#0b1226}
.bk-tech .bk-eyebrow{color:#a9bdd6}
.bk-tech .bk-svc{color:#dbe7f5}
.bk-tech .bk-svc .ico{background:#0f1830;border-color:rgba(120,200,255,.3);box-shadow:0 0 0 1px rgba(34,211,238,.15),0 10px 30px -12px rgba(34,211,238,.4)}
.bk-tech .bk-svc small{color:#a9bdd6}
.bk-tech .bk-price-list,.bk-tech .bk-price-list div,.bk-tech .bk-hours td,.bk-tech .bk-qa{border-color:rgba(120,200,255,.22)}
.bk-tech .bk-price-list b{color:#67e8f9}
.bk-tech .bk-form,.bk-tech .bk-flow{background:#0f1830;box-shadow:0 0 0 1px rgba(120,200,255,.2)}
.bk-tech .bk-form label{color:#c7d6ea}
.bk-tech .bk-form input,.bk-tech .bk-form select,.bk-tech .bk-form textarea{background:#0a1226;border-color:rgba(120,200,255,.35);color:#e6edf7}
.bk-tech .bk-req{color:#a9bdd6}
.bk-tech .bk-flow figcaption,.bk-tech .bk-qa summary{color:#f2f7ff}
.bk-tech .bk-flow img{background:#f3f8ff;border-radius:12px;padding:10px}
.bk-tech .bk-qa p{color:#c7d6ea}
.bk-tech .bk-footer{background:#04070f;color:#a9bdd6}
.bk-req{font-size:12px;font-weight:400;color:#6f6257}
.bk-skip{position:absolute;left:-9999px;top:0;background:#fff;color:#111;padding:10px 16px;z-index:100}
.bk-skip:focus{left:8px;top:8px}
a:focus-visible,button:focus-visible,input:focus-visible,select:focus-visible,textarea:focus-visible{outline:3px solid #1a73e8;outline-offset:2px}
@media (max-width:640px){.bk-hero h1{font-size:30px}.bk-hero h2{font-size:20px}.bk-row{grid-template-columns:1fr}.bk-links{gap:10px}.bk-links .sep{display:none}.bk-form{padding:22px}}
`;

// 各語言的範本文字（HTML 字串，需要的字元已跳脫）。en 為預設與後備。
const T = {
  en: {
    availTitle: "Availability", availEyebrow: "See which times are already taken", availNote: "Grey “Busy” blocks are already booked. Pick a free time in the form below.",
    faqTitle: "Questions", faqEyebrow: "Before you book", faq: [["How do I change or cancel a booking?", "Please contact us as early as you can and we will find another time."], ["Can I book by phone?", "Yes. Online booking is open at any time, and you can also call us during opening hours."], ["Where can I find you?", "The address is at the bottom of this page."]],
    flowTitle: "How it works", flowEyebrow: "From booking to your visit", flowBookingTitle: "Booking steps", flowServiceTitle: "On the day", bookingSteps: ["Choose a service", "Pick a date and time", "Enter your details", "We confirm by email"], serviceSteps: ["Arrive", "Consultation", "Service", "Payment and next visit"],
    skip: "Skip to main content", navLabel: "Main menu", req: "(required)", noscript: "This page works best with JavaScript turned on, and the booking form needs it. Please turn it on, or contact us directly.",
    brand: "Sakura Clinic", brandSub: "YOUR CLINIC",
    nav: ["About", "Services", "Pricing", "Access"], book: "Book online", line: "LINE",
    h1: "“Be more yourself,<br>more beautiful.”", h2: "“Gentle, grown-up care<br>that stays close to you.”",
    lead: "We listen to every person's skin and bring out natural, healthy beauty.", cta: "Free counseling",
    svcTitle: "Services", svcEyebrow: "Our treatments",
    svc: [["Aging care", "Aging Care"], ["Skin &amp; pores", "Skin &amp; Pores"], ["Eyelid &amp; eyes", "Double Eyelid"], ["Hair removal", "Medical Epilation"]],
    priceTitle: "Pricing", priceEyebrow: "Price list", cur: "$",
    price: [["Free counseling", "Free"], ["Aging care (first visit)", "$120"], ["Skin &amp; pores course", "$180"], ["Medical hair removal (per area)", "$90"]],
    bookTitle: "Online booking", bookEyebrow: "Reserve your visit",
    f: { name: "Name", phone: "Phone", email: "Email", service: "Service", date: "Date", time: "Time", notes: "Notes", submit: "Request booking", ok: "Thank you! We will confirm your booking by email." },
    opts: ["Free counseling", "Skin care", "Eyelid &amp; eye area", "Medical hair removal"],
    hoursTitle: "Opening hours", hoursEyebrow: "Hours",
    hours: [["Mon – Fri", "10:00 – 19:00"], ["Saturday", "10:00 – 17:00"], ["Sunday / holidays", "Closed"]],
    addr: "123 Main Street · hello@example.com", fl: ["Free counseling", "Contact us"],
  },
  ja: {
    availTitle: "空き状況", availEyebrow: "すでに埋まっている時間をご確認ください", availNote: "「予定あり」と表示されている時間はご予約済みです。空いている時間をフォームからお選びください。",
    faqTitle: "よくある質問", faqEyebrow: "ご予約の前に", faq: [["予約の変更やキャンセルはできますか。", "できるだけ早めにご連絡ください。別の日時をご案内します。"], ["電話でも予約できますか。", "はい。ネット予約は24時間受け付けており、営業時間中はお電話でもご予約いただけます。"], ["お店の場所を教えてください。", "住所はこのページの下部に記載しています。"]],
    flowTitle: "ご利用の流れ", flowEyebrow: "ご予約からご来店まで", flowBookingTitle: "ご予約の流れ", flowServiceTitle: "当日の流れ", bookingSteps: ["メニューを選ぶ", "日時を選ぶ", "お名前などを入力", "メールで確認をお送りします"], serviceSteps: ["ご来店", "カウンセリング", "施術", "お会計・次回のご予約"],
    skip: "本文へスキップ", navLabel: "メインメニュー", req: "（必須）", noscript: "このページはJavaScriptを使用します。予約フォームを使うにはJavaScriptを有効にするか、直接お問い合わせください。",
    brand: "桜エステクリニック", brandSub: "SAKURA CLINIC",
    nav: ["初めての方へ", "診療科目", "料金表", "アクセス"], book: "WEB予約", line: "LINE相談",
    h1: "「自分らしさを、<br>もっと美しく。」", h2: "「心に寄り添う、大人の美容医療。」",
    lead: "一人ひとりの肌と向き合い、自然で健康的な美しさを引き出します。", cta: "無料カウンセリング予約",
    svcTitle: "診療科目", svcEyebrow: "Treatments",
    svc: [["エイジングケア", "Aging Care"], ["美肌・毛穴", "Skin &amp; Pores"], ["二重・目元", "Double Eyelid"], ["医療脱毛", "Medical Epilation"]],
    priceTitle: "料金表", priceEyebrow: "Price list", cur: "¥",
    price: [["無料カウンセリング", "無料"], ["エイジングケア（初回）", "¥12,000"], ["美肌・毛穴コース", "¥18,000"], ["医療脱毛（1部位）", "¥9,000"]],
    bookTitle: "WEB予約", bookEyebrow: "Online booking",
    f: { name: "お名前", phone: "電話番号", email: "メールアドレス", service: "ご希望のメニュー", date: "日付", time: "時間", notes: "ご要望", submit: "予約を申し込む", ok: "ありがとうございます。ご予約内容をメールでご確認ください。" },
    opts: ["無料カウンセリング", "美肌・毛穴", "二重・目元", "医療脱毛"],
    hoursTitle: "診療時間", hoursEyebrow: "Hours",
    hours: [["月〜金", "10:00 – 19:00"], ["土曜", "10:00 – 17:00"], ["日曜・祝日", "休診"]],
    addr: "東京都〇〇区〇〇 1-2-3 · hello@example.com", fl: ["無料カウンセリング予約", "お問い合わせ"],
  },
  zh: {
    availTitle: "空檔查詢", availEyebrow: "先看看哪些時段已被預約", availNote: "標示「忙碌」的時段已被預約，請在下方表單選擇空檔時段。",
    faqTitle: "常見問題", faqEyebrow: "預約之前", faq: [["可以更改或取消預約嗎？", "請盡早與我們聯絡，我們會為你安排其他時間。"], ["可以用電話預約嗎？", "可以。線上預約隨時開放，營業時間內也可以來電預約。"], ["店面在哪裡？", "地址寫在本頁最下方。"]],
    flowTitle: "預約與服務流程", flowEyebrow: "從預約到到店", flowBookingTitle: "預約流程", flowServiceTitle: "到店當天", bookingSteps: ["選擇服務", "選擇日期與時間", "填寫聯絡資料", "我們以電子郵件確認"], serviceSteps: ["到店", "諮詢", "進行服務", "結帳與預約下次"],
    skip: "跳到主要內容", navLabel: "主選單", req: "（必填）", noscript: "此頁面需要啟用 JavaScript，預約表單才能使用。請啟用 JavaScript，或直接與我們聯絡。",
    brand: "櫻花美學診所", brandSub: "SAKURA CLINIC",
    nav: ["初診須知", "診療項目", "價目表", "交通資訊"], book: "線上預約", line: "LINE 諮詢",
    h1: "「做自己，<br>更美麗。」", h2: "「貼近內心，成熟大人的醫美。」",
    lead: "傾聽每一位的肌膚需求，引出自然而健康的美。", cta: "免費諮詢預約",
    svcTitle: "診療項目", svcEyebrow: "Treatments",
    svc: [["抗老保養", "Aging Care"], ["美肌・毛孔", "Skin &amp; Pores"], ["雙眼皮・眼周", "Double Eyelid"], ["醫療除毛", "Medical Epilation"]],
    priceTitle: "價目表", priceEyebrow: "Price list", cur: "NT$",
    price: [["免費諮詢", "免費"], ["抗老保養（初診）", "NT$3,800"], ["美肌・毛孔療程", "NT$5,600"], ["醫療除毛（單一部位）", "NT$2,800"]],
    bookTitle: "線上預約", bookEyebrow: "Online booking",
    f: { name: "姓名", phone: "電話", email: "電子郵件", service: "預約項目", date: "日期", time: "時間", notes: "備註", submit: "送出預約", ok: "謝謝您！我們將以電子郵件確認預約。" },
    opts: ["免費諮詢", "美肌・毛孔", "雙眼皮・眼周", "醫療除毛"],
    hoursTitle: "營業時間", hoursEyebrow: "Hours",
    hours: [["週一至週五", "10:00 – 19:00"], ["週六", "10:00 – 17:00"], ["週日／國定假日", "休診"]],
    addr: "台北市〇〇區〇〇路 123 號 · hello@example.com", fl: ["免費諮詢預約", "聯絡我們"],
  },
  pt: {
    availTitle: "Disponibilidade", availEyebrow: "Veja quais horários já estão ocupados", availNote: "Os blocos “Ocupado” já estão reservados. Escolha um horário livre no formulário abaixo.",
    faqTitle: "Perguntas frequentes", faqEyebrow: "Antes de reservar", faq: [["Como mudo ou cancelo uma reserva?", "Fale conosco o quanto antes e encontraremos outro horário."], ["Posso reservar por telefone?", "Sim. A reserva online está aberta a qualquer hora e você também pode ligar no horário de atendimento."], ["Onde fica o local?", "O endereço está no fim desta página."]],
    flowTitle: "Como funciona", flowEyebrow: "Da reserva até a visita", flowBookingTitle: "Passos da reserva", flowServiceTitle: "No dia", bookingSteps: ["Escolha um serviço", "Escolha data e hora", "Preencha seus dados", "Confirmamos por e-mail"], serviceSteps: ["Chegada", "Conversa inicial", "Atendimento", "Pagamento e próxima visita"],
    skip: "Ir para o conteúdo principal", navLabel: "Menu principal", req: "(obrigatório)", noscript: "Esta página funciona melhor com JavaScript ativado, e o formulário de agendamento precisa dele. Ative-o ou entre em contato diretamente.",
    brand: "Clínica Sakura", brandSub: "SUA CLÍNICA",
    nav: ["Sobre", "Serviços", "Preços", "Como chegar"], book: "Agendar online", line: "LINE",
    h1: "“Seja mais você,<br>ainda mais bela.”", h2: "“Cuidado gentil e maduro,<br>sempre perto de você.”",
    lead: "Ouvimos a pele de cada pessoa e revelamos uma beleza natural e saudável.", cta: "Consulta gratuita",
    svcTitle: "Serviços", svcEyebrow: "Tratamentos",
    svc: [["Antienvelhecimento", "Aging Care"], ["Pele e poros", "Skin &amp; Pores"], ["Pálpebras e olhar", "Double Eyelid"], ["Depilação médica", "Medical Epilation"]],
    priceTitle: "Preços", priceEyebrow: "Tabela de preços", cur: "R$",
    price: [["Consulta gratuita", "Grátis"], ["Antienvelhecimento (1ª visita)", "R$ 350"], ["Curso de pele e poros", "R$ 520"], ["Depilação médica (por área)", "R$ 280"]],
    bookTitle: "Agendamento online", bookEyebrow: "Reserve sua visita",
    f: { name: "Nome", phone: "Telefone", email: "E-mail", service: "Serviço", date: "Data", time: "Hora", notes: "Observações", submit: "Solicitar agendamento", ok: "Obrigado! Confirmaremos seu agendamento por e-mail." },
    opts: ["Consulta gratuita", "Pele e poros", "Pálpebras e olhar", "Depilação médica"],
    hoursTitle: "Horário de atendimento", hoursEyebrow: "Horários",
    hours: [["Seg – Sex", "10:00 – 19:00"], ["Sábado", "10:00 – 17:00"], ["Domingo / feriados", "Fechado"]],
    addr: "Rua Principal, 123 · hello@example.com", fl: ["Consulta gratuita", "Fale conosco"],
  },
  es: {
    availTitle: "Disponibilidad", availEyebrow: "Consulta qué horarios ya están ocupados", availNote: "Los bloques “Ocupado” ya están reservados. Elige un horario libre en el formulario de abajo.",
    faqTitle: "Preguntas frecuentes", faqEyebrow: "Antes de reservar", faq: [["¿Cómo cambio o cancelo una reserva?", "Contáctanos lo antes posible y buscaremos otro horario."], ["¿Puedo reservar por teléfono?", "Sí. La reserva en línea está abierta a cualquier hora y también puedes llamarnos en horario de atención."], ["¿Dónde estáis?", "La dirección está al final de esta página."]],
    flowTitle: "Cómo funciona", flowEyebrow: "De la reserva a tu visita", flowBookingTitle: "Pasos de la reserva", flowServiceTitle: "El día de la cita", bookingSteps: ["Elige un servicio", "Elige fecha y hora", "Escribe tus datos", "Confirmamos por correo"], serviceSteps: ["Llegada", "Conversación inicial", "Servicio", "Pago y próxima visita"],
    skip: "Saltar al contenido principal", navLabel: "Menú principal", req: "(obligatorio)", noscript: "Esta página funciona mejor con JavaScript activado, y el formulario de reserva lo necesita. Actívalo o contáctanos directamente.",
    brand: "Clínica Sakura", brandSub: "TU CLÍNICA",
    nav: ["Nosotros", "Servicios", "Precios", "Cómo llegar"], book: "Reservar en línea", line: "LINE",
    h1: "“Sé más tú,<br>más hermosa.”", h2: "“Un cuidado amable y maduro,<br>siempre a tu lado.”",
    lead: "Escuchamos la piel de cada persona y realzamos una belleza natural y saludable.", cta: "Consulta gratuita",
    svcTitle: "Servicios", svcEyebrow: "Tratamientos",
    svc: [["Antienvejecimiento", "Aging Care"], ["Piel y poros", "Skin &amp; Pores"], ["Párpados y ojos", "Double Eyelid"], ["Depilación médica", "Medical Epilation"]],
    priceTitle: "Precios", priceEyebrow: "Lista de precios", cur: "€",
    price: [["Consulta gratuita", "Gratis"], ["Antienvejecimiento (primera visita)", "90 €"], ["Curso de piel y poros", "130 €"], ["Depilación médica (por zona)", "70 €"]],
    bookTitle: "Reserva en línea", bookEyebrow: "Reserva tu visita",
    f: { name: "Nombre", phone: "Teléfono", email: "Correo electrónico", service: "Servicio", date: "Fecha", time: "Hora", notes: "Notas", submit: "Solicitar reserva", ok: "¡Gracias! Confirmaremos tu reserva por correo electrónico." },
    opts: ["Consulta gratuita", "Piel y poros", "Párpados y ojos", "Depilación médica"],
    hoursTitle: "Horario", hoursEyebrow: "Horario",
    hours: [["Lun – Vie", "10:00 – 19:00"], ["Sábado", "10:00 – 17:00"], ["Domingo / festivos", "Cerrado"]],
    addr: "Calle Mayor 123 · hello@example.com", fl: ["Consulta gratuita", "Contáctanos"],
  },
};

const icons = {
  sparkle: `<svg viewBox="0 0 64 64"><circle cx="32" cy="26" r="11"/><path d="M14 56c2-12 10-16 18-16s16 4 18 16"/><path d="M50 10v8M46 14h8"/></svg>`,
  drop: `<svg viewBox="0 0 64 64"><path d="M32 8C22 22 16 30 16 40a16 16 0 0 0 32 0c0-10-6-18-16-32z"/><path d="M26 42a6 6 0 0 0 6 6"/></svg>`,
  eye: `<svg viewBox="0 0 64 64"><path d="M6 32c8-12 18-18 26-18s18 6 26 18c-8 12-18 18-26 18S14 44 6 32z"/><circle cx="32" cy="32" r="8"/></svg>`,
  leaf: `<svg viewBox="0 0 64 64"><path d="M12 52C12 28 28 12 52 12c0 24-16 40-40 40z"/><path d="M12 52L36 28"/></svg>`,
};
const svcIcons = ["sparkle", "drop", "eye", "leaf"];

const svc = (icon, name, sub, href = "#booking") => `
<a class="bk-svc" href="${href}">
  <div class="ico">${icons[icon]}</div>
  <h3>${name}</h3><small>${sub}</small>
</a>`;

/// 服務圖示列表 / 營業時間列的 HTML（範本與 AI 聊天編輯共用）
export const svcRowsHtml = (items) => items.map((x, i) => svc(svcIcons[i % svcIcons.length], x[0], x[1] || "")).join("\n    ");
export const hoursRowsHtml = (items) => items.map((r) => `<tr><td>${r[0]}</td><td>${r[1] || ""}</td></tr>`).join("\n    ");

/// 常見問題列：用 <details> / <summary>（不需要 JavaScript 就能展開，鍵盤與讀屏都支援）
export const faqRowsHtml = (items) => items.map((r) => `<details class="bk-qa"><summary>${r[0]}</summary><p>${r[1] || ""}</p></details>`).join("\n    ");

/// 流程圖區塊裡的一張圖：<img> 的 src 由編輯器用 Mermaid 繪製後填入（見 main.js / actions.js 的 set_flow）
const flowFigure = (which, title, steps) => `<figure class="bk-flow">
      <figcaption>${title}</figcaption>
      <img data-f="flow-${which}" data-steps="${steps.join("|")}" alt="${steps.join(" → ")}" src="">
    </figure>`;

const bookingForm = (t) => `
<form class="bk-form" data-booking aria-label="${t.bookTitle}" data-success="${t.f.ok}">
  <div class="bk-row">
    <label><span>${t.f.name} <small class="bk-req">${t.req}</small></span><input name="name" autocomplete="name" required></label>
    <label><span>${t.f.phone}</span><input name="phone" type="tel" autocomplete="tel"></label>
  </div>
  <label><span>${t.f.email} <small class="bk-req">${t.req}</small></span><input name="email" type="email" autocomplete="email" required></label>
  <label><span>${t.f.service}</span>
    <select name="service" data-f="opts">${t.opts.map((o) => `<option>${o}</option>`).join("")}</select>
  </label>
  <div class="bk-row">
    <label><span>${t.f.date} <small class="bk-req">${t.req}</small></span><input name="date" type="date" required></label>
    <label><span>${t.f.time} <small class="bk-req">${t.req}</small></span><input name="time" type="time" required></label>
  </div>
  <label><span>${t.f.notes}</span><textarea name="notes" rows="3"></textarea></label>
  <button type="submit" class="bk-pill lg">${t.f.submit}</button>
  <p data-booking-status role="status" aria-live="polite"></p>
</form>`;

const sectionsFor = (lang, overrides) => {
  const clean = (v) => (typeof v === "string" ? esc(v).replace(/\n/g, "<br>") : Array.isArray(v) ? v.map(clean) : v);
  const over = Object.fromEntries(Object.entries(overrides || {}).map(([k, v]) => [k, clean(v)]));
  const t = { ...(T[lang] || T.en), ...over };
  const l = T[lang] ? lang : "en";
  const s = {
    nav: `
<header><nav class="bk-nav" aria-label="${t.navLabel}">
  <a href="#" class="bk-brand"><span data-f="brand">${t.brand}</span><small data-f="brandSub">${t.brandSub}</small></a>
  <div class="bk-links">
    <a href="#about">${t.nav[0]}</a><span class="sep" aria-hidden="true">/</span><a href="#services">${t.nav[1]}</a><span class="sep" aria-hidden="true">/</span><a href="#price">${t.nav[2]}</a><span class="sep" aria-hidden="true">/</span><a href="#contact">${t.nav[3]}</a>
    <a href="#booking" class="bk-pill">${t.book}</a>
    <a href="#contact" class="bk-pill line">${t.line}</a>
  </div>
</nav></header>`,
    hero: `
<section class="bk-hero" id="about"><div class="bk-wrap">
  <h1 data-f="h1">${t.h1}</h1>
  <h2 data-f="h2">${t.h2}</h2>
  <p data-f="lead">${t.lead}</p>
  <a href="#booking" class="bk-pill lg" data-f="cta">${t.cta}</a>
</div></section>`,
    services: `
<section class="bk-section" id="services"><div class="bk-wrap">
  <h2>${t.svcTitle}</h2>
  <p class="bk-eyebrow">${t.svcEyebrow}</p>
  <div class="bk-svc-grid" data-f="svc">
    ${svcRowsHtml(t.svc)}
  </div>
</div></section>`,
    flow: `
<section class="bk-section" id="flow"><div class="bk-wrap">
  <h2>${t.flowTitle}</h2>
  <p class="bk-eyebrow">${t.flowEyebrow}</p>
  <div class="bk-flows">
    ${flowFigure("booking", t.flowBookingTitle, t.bookingSteps)}
    ${flowFigure("service", t.flowServiceTitle, t.serviceSteps)}
  </div>
</div></section>`,
    pricing: `
<section class="bk-section tint" id="price"><div class="bk-wrap">
  <h2>${t.priceTitle}</h2>
  <p class="bk-eyebrow">${t.priceEyebrow}</p>
  <div class="bk-price-list" data-f="price">
    ${t.price.map((r) => `<div><span>${r[0]}</span><b>${r[1]}</b></div>`).join("\n    ")}
  </div>
</div></section>`,
    faq: `
<section class="bk-section" id="faq"><div class="bk-wrap">
  <h2>${t.faqTitle}</h2>
  <p class="bk-eyebrow">${t.faqEyebrow}</p>
  <div class="bk-faq" data-f="faq">
    ${faqRowsHtml(t.faq)}
  </div>
</div></section>`,
    availability: `
<section class="bk-section tint" id="availability"><div class="bk-wrap">
  <h2>${t.availTitle}</h2>
  <p class="bk-eyebrow">${t.availEyebrow}</p>
  <div class="bk-avail" data-f="avail"><iframe title="${t.availTitle}" src="about:blank" loading="lazy"></iframe></div>
  <p class="bk-note">${t.availNote}</p>
</div></section>`,
    booking: `
<section class="bk-section" id="booking"><div class="bk-wrap">
  <h2>${t.bookTitle}</h2>
  <p class="bk-eyebrow">${t.bookEyebrow}</p>
  ${bookingForm(t)}
</div></section>`,
    hours: `
<section class="bk-section"><div class="bk-wrap">
  <h2>${t.hoursTitle}</h2>
  <p class="bk-eyebrow">${t.hoursEyebrow}</p>
  <table class="bk-hours"><tbody data-f="hours">
    ${hoursRowsHtml(t.hours)}
  </tbody></table>
</div></section>`,
    footer: `
<footer class="bk-footer" id="contact">
  <p class="bk-serif" style="font-size:18px" data-f="brand">${t.brand}</p>
  <p data-f="addr">${t.addr}</p>
  <p>© ${new Date().getFullYear()} <span data-f="brand">${t.brand}</span></p>
</footer>`,
    float: `
<div class="bk-float">
  <a href="#booking">${t.fl[0]}</a>
  <a href="#contact" class="dark">${t.fl[1]}</a>
</div>`,
  };
  return { t, l, s };
};

export const starterHtml = (lang, overrides) => {
  const { s } = sectionsFor(lang, overrides);
  const { t } = sectionsFor(lang, overrides);
  return [`<a class="bk-skip" href="#main">${t.skip}</a>`, s.nav, '<main id="main">', s.hero, s.services, s.flow, s.pricing, s.faq, s.booking, s.hours, "</main>", s.footer, s.float].join("\n");
};

const BLOCK_IDS = ["bk-nav", "bk-hero", "bk-services", "bk-service-item", "bk-pricing", "bk-booking", "bk-form", "bk-hours", "bk-float", "bk-footer"];

/// 區塊內容跟著網站語言走；切換語言時重新註冊
export function registerBlocks(editor, lang, overrides) {
  const { t, s } = sectionsFor(lang, overrides);
  const bm = editor.BlockManager;
  BLOCK_IDS.forEach((id) => bm.get(id) && bm.remove(id));
  const cat = { booking: "Booking site" };
  const add = (id, label, content, category, icon) =>
    bm.add(id, { label: `<div class="blk-ico">${icon}</div><div>${label}</div>`, category, content });

  add("bk-nav", "Navigation", s.nav, cat.booking, "☰");
  add("bk-hero", "Hero", s.hero, cat.booking, "★");
  add("bk-services", "Services", s.services, cat.booking, "◎");
  add("bk-service-item", "Service icon", svc("sparkle", t.svc[0][0], t.svc[0][1]), cat.booking, "○");
  add("bk-pricing", "Price list", s.pricing, cat.booking, "¥");
  add("bk-booking", "Booking section", s.booking, cat.booking, "📅");
  add("bk-form", "Booking form", bookingForm(t), cat.booking, "✎");
  add("bk-hours", "Opening hours", s.hours, cat.booking, "🕘");
  add("bk-float", "Floating buttons", s.float, cat.booking, "◔");
  add("bk-footer", "Footer", s.footer, cat.booking, "▁");
}

export function registerBookingKit(editor, lang) {
  const dc = editor.DomComponents;

  dc.addType("booking-form", {
    extend: "form",
    isComponent: (el) => el.tagName === "FORM" && el.hasAttribute("data-booking"),
    model: {
      defaults: {
        name: "Booking form",
        traits: [{ name: "data-success", label: "Success message" }],
      },
    },
  });

  registerBlocks(editor, lang);
}

const esc = (v) => String(v).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

/// 價格列表的內容列：rows = [[項目, 價格], …]
export const priceRowsHtml = (rows) => rows.map((r) => `<div><span>${esc(r[0])}</span><b>${esc(r[1])}</b></div>`).join("\n    ");

/// 「必填」標記文字
export const requiredText = (lang) => (T[lang] || T.en).req;

/// 沒有 JavaScript 時顯示的說明（預約表單需要 JavaScript）
export const noscriptText = (lang) => (T[lang] || T.en).noscript;

/// 單一區塊的 HTML（key：nav / hero / services / pricing / booking / hours / footer / float）
export const sectionHtml = (lang, key) => sectionsFor(lang).s[key];

/// 完整的價目表區塊（網站上沒有價格列表時，套用 AI 報價會先補上這個區塊）
export const pricingSectionHtml = (lang) => sectionsFor(lang).s.pricing;
