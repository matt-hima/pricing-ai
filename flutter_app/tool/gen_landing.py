#!/usr/bin/env python3
"""Pricing AI のトップページ（ランディング）を 5 言語ぶん生成する。出力は landing/ 。
`/` = 英語（x-default）、`/zh/ /ja/ /pt/ /es/` = 各言語。アプリ本体は `/app/`（tool/build_site.sh）。
お問い合わせは公開 Google フォームの formResponse に POST する（サーバー不要）。"""
import html, json, os, sys

ORIGIN = "https://pricingai.minervaelectronics.com"
FORM_ACTION = "https://docs.google.com/forms/d/e/1FAIpQLSftIALXY-dzznZsvA9nrszx723XOYqCrMdj4Arj8bzMfWZDPg/formResponse"
ENTRY = {"name": "entry.1903040876", "email": "entry.776373827", "topic": "entry.905709046", "message": "entry.570311151"}
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "landing")

LANGS = {  # code: (path, html lang, hreflang, og locale, native name)
    "en": ("/", "en", "en", "en_US", "English"),
    "zh": ("/zh/", "zh-Hant", "zh-TW", "zh_TW", "繁體中文"),
    "ja": ("/ja/", "ja", "ja", "ja_JP", "日本語"),
    "pt": ("/pt/", "pt-BR", "pt-BR", "pt_BR", "Português"),
    "es": ("/es/", "es", "es", "es_ES", "Español"),
}

T = {
"en": dict(
  title="Pricing AI · Price your services, build your booking site", desc="Work out what each service costs, set prices that reach your profit target, and publish a multilingual booking website with a Google Form and Calendar. Free web version, local AI on Mac and Windows.",
  nav=["Features", "How it works", "FAQ", "Contact"], badge=["Free web version", "Data stays on your computer", "No sign-up"],
  h1="Price your services. Build your booking site. Take bookings.", lead="Pricing AI helps salons, clinics, restaurants, schools and rental spaces set profitable prices, publish a booking website in minutes, and receive bookings in a Google Form and Google Calendar.",
  cta1="Open the web app", cta2="Contact us",
  f_title="Everything a small service business needs", f_sub="From the first price to the first booking.",
  feats=[("Service pricing calculator","Enter your hourly pay, fixed costs and target profit. Pricing AI works out the real cost of every service and the price that reaches your margin, with tax and rounding for 14 currencies."),
         ("Booking website builder","Start from a clean template in English, 繁體中文, 日本語, Português or Español. Edit visually, add a FAQ, flow charts and a dark high-tech look. Export a ZIP or deploy to Firebase."),
         ("Bookings in Google Forms and Calendar","One Apps Script creates the booking form and a calendar that shows busy times publicly. Every booking becomes a calendar event, and the site shows availability."),
         ("Local AI on Mac and Windows","The desktop app runs open models on your own GPU: it writes your site from a chat, rewrites parts on request and can draw banner pictures. Nothing is sent to a cloud AI.")],
  h_title="How it works", steps=[("Set your prices","Enter costs and the target profit; get a price list for each service."),("Build the site","Add the price list to a template or describe your business in a chat."),("Connect bookings","Paste your Google Form link, or create the form and calendar with one script."),("Publish","Download a ZIP for any web host, or deploy to Firebase from the desktop app.")],
  who_title="Made for service providers", who=["Hair and beauty salons","Clinics and dental offices","Restaurants and cafés","Schools and lessons","Meeting rooms and rental spaces"],
  faq_title="Frequently asked questions",
  faq=[("Is it free?","The web version is free to use: the price calculator, the site builder and ZIP export. The Mac and Windows apps add local AI and one-click deploy."),
       ("Does the AI send my data to the cloud?","No. In the desktop app the AI models run on your own computer. The web version has no AI and keeps your data in your browser."),
       ("Do I need to know how to code?","No. You edit the page visually or by chat, and the booking form connects through a Google Form."),
       ("Which languages are supported?","The app and the site templates come in English, Traditional Chinese, Japanese, Brazilian Portuguese and Spanish."),
       ("How do I receive bookings?","Visitors fill in your Google Form from your site. A script adds each booking to a Google Calendar, and you can turn on email notifications in Google Forms.")],
  c_title="Contact us", c_sub="Questions, feature requests or early access to the Mac and Windows app? Send us a message.",
  c_name="Name", c_email="Email", c_topic="Topic", c_msg="Message", c_send="Send message", c_sending="Sending…", c_ok="Thank you! Your message has been sent.", c_err="Could not send. Please try again.", c_wait="Please wait a moment before sending another message.", c_req="required",
  topics=[("Question","Question"),("Feature request","Feature request"),("Partnership","Partnership"),("Bug report","Bug report"),("Other","Mac / Windows app early access"),],
  foot="Pricing AI helps you plan prices and bookings. Prices and estimates are a planning aid, not advice.",
  app_tag="App early access"),
"zh": dict(
  title="Pricing AI · 設計服務價格，建立預約網站", desc="算出每項服務的成本，訂出能達到目標利潤的價格，並用 Google 表單與日曆發布多語言預約網站。網頁版免費，Mac 與 Windows 版在本機執行 AI。",
  nav=["功能", "使用方式", "常見問題", "聯絡我們"], badge=["網頁版免費", "資料留在你的電腦", "免註冊"],
  h1="設計服務價格，建立預約網站，接收預約。", lead="Pricing AI 幫美髮、診所、餐廳、教室與場地租借等服務業，訂出有利潤的價格、幾分鐘內發布預約網站，並用 Google 表單與 Google 日曆接收預約。",
  cta1="開啟網頁版", cta2="聯絡我們",
  f_title="小型服務業需要的一切", f_sub="從第一個價格到第一筆預約。",
  feats=[("服務定價計算器","輸入你的時薪、固定成本與目標利潤，Pricing AI 算出每項服務的真實成本，以及能達到利潤率的價格，並支援 14 種幣別的稅額與進位。"),
         ("預約網站編輯器","從英文、繁體中文、日文、葡萄牙文或西班牙文的乾淨範本開始，可視覺化編輯，加入常見問題、流程圖與科技感深色外觀，匯出 ZIP 或部署到 Firebase。"),
         ("用 Google 表單與日曆接收預約","一支 Apps Script 就能建立預約表單與公開「忙碌」時段的日曆，每筆預約都會成為日曆事件，網站也會顯示空檔。"),
         ("Mac 與 Windows 的本機 AI","桌面版在你自己的 GPU 上執行開源模型：用對話寫出網站、依需求重寫段落，還能繪製主圖。不會把資料送到雲端 AI。")],
  h_title="使用方式", steps=[("訂出價格","輸入成本與目標利潤，得到每項服務的價目表。"),("建立網站","把價目表加進範本，或用對話描述你的店。"),("連接預約","貼上 Google 表單連結，或用一支腳本建立表單與日曆。"),("發布","下載 ZIP 放到任何主機，或在桌面版部署到 Firebase。")],
  who_title="為服務業打造", who=["美髮與美容沙龍","診所與牙科","餐廳與咖啡店","教室與課程","會議室與租借空間"],
  faq_title="常見問題",
  faq=[("要收費嗎？","網頁版可免費使用：價格計算器、網站編輯器與 ZIP 匯出。Mac 與 Windows 版另外提供本機 AI 與一鍵部署。"),
       ("AI 會把我的資料送到雲端嗎？","不會。桌面版的 AI 模型在你自己的電腦上執行；網頁版沒有 AI，資料只留在瀏覽器。"),
       ("需要會寫程式嗎？","不需要。你可以用視覺化或對話編輯頁面，預約表單透過 Google 表單連接。"),
       ("支援哪些語言？","App 與網站範本提供英文、繁體中文、日文、巴西葡萄牙文與西班牙文。"),
       ("怎麼收到預約？","訪客在你的網站填寫 Google 表單，腳本會把每筆預約加到 Google 日曆，你也可以在 Google 表單開啟電子郵件通知。")],
  c_title="聯絡我們", c_sub="有問題、功能建議，或想搶先使用 Mac / Windows 版？歡迎留言給我們。",
  c_name="姓名", c_email="電子郵件", c_topic="主題", c_msg="訊息", c_send="送出訊息", c_sending="送出中…", c_ok="謝謝！已收到你的訊息。", c_err="送出失敗，請再試一次。", c_wait="請稍候再送出下一則訊息。", c_req="必填",
  topics=[("Question","問題"),("Feature request","功能建議"),("Partnership","合作洽談"),("Bug report","回報問題"),("Other","Mac / Windows 版搶先使用")],
  foot="Pricing AI 協助你規劃價格與預約。價格與估算僅供規劃參考，不構成建議。",
  app_tag="App early access"),
"ja": dict(
  title="Pricing AI · サービスの価格を設計し、予約サイトを作る", desc="サービスごとの原価を計算し、目標の利益に届く価格を決め、GoogleフォームとGoogleカレンダーで受け付ける多言語の予約サイトを公開できます。Web版は無料、MacとWindowsではローカルAI。",
  nav=["機能", "使い方", "よくある質問", "お問い合わせ"], badge=["Web版は無料", "データは自分のパソコンに", "登録不要"],
  h1="サービスの価格を設計して、予約サイトを作り、予約を受け付ける。", lead="Pricing AIは、美容室・クリニック・飲食店・教室・レンタルスペースが、利益の出る価格を決め、数分で予約サイトを公開し、GoogleフォームとGoogleカレンダーで予約を受け取れるようにします。",
  cta1="Web版を開く", cta2="お問い合わせ",
  f_title="小さなサービス業に必要なものを、ひとつに", f_sub="最初の価格から、最初の予約まで。",
  feats=[("サービス価格の計算","時給・固定費・目標の利益を入力すると、サービスごとの本当の原価と、利益率に届く価格を計算します。14通貨の税と丸めに対応。"),
         ("予約サイトの作成","英語・繁體中文・日本語・Português・Españolのひな形から始めて、画面で編集。よくある質問や流れ図、ハイテクなダーク表示も。ZIPで書き出すか、Firebaseに公開。"),
         ("Googleフォームとカレンダーで予約","Apps Script 1つで、予約フォームと「予定あり」だけ公開のカレンダーを作成。予約は自動でカレンダーに入り、サイトに空き状況が表示されます。"),
         ("Mac・WindowsのローカルAI","デスクトップ版は自分のGPUでオープンモデルを動かし、チャットでサイトを作成、部分的な書き直し、バナー画像の生成までこなします。クラウドのAIにデータは送りません。")],
  h_title="使い方", steps=[("価格を決める","コストと目標の利益を入力して、サービスごとの料金表を作ります。"),("サイトを作る","料金表をひな形に追加するか、チャットでお店を説明します。"),("予約をつなぐ","Googleフォームのリンクを貼るか、スクリプト1つでフォームとカレンダーを作ります。"),("公開する","ZIPを任意のサーバーに置くか、デスクトップ版からFirebaseへ公開します。")],
  who_title="サービス業のために", who=["美容室・ヘアサロン","クリニック・歯科","飲食店・カフェ","教室・習い事","会議室・レンタルスペース"],
  faq_title="よくある質問",
  faq=[("無料ですか？","Web版の価格計算・サイト作成・ZIP書き出しは無料です。MacとWindows版では、ローカルAIとワンクリック公開が加わります。"),
       ("AIにデータがクラウドへ送られますか？","いいえ。デスクトップ版のAIモデルは自分のパソコン上で動きます。Web版にAIはなく、データはブラウザ内に留まります。"),
       ("プログラミングは必要ですか？","不要です。画面やチャットでページを編集でき、予約フォームはGoogleフォームでつなぎます。"),
       ("対応言語は？","アプリとサイトのひな形は、英語・繁体字中国語・日本語・ブラジルのポルトガル語・スペイン語です。"),
       ("予約はどう受け取りますか？","訪問者があなたのサイトからGoogleフォームを送信します。スクリプトが予約をGoogleカレンダーに追加し、Googleフォームでメール通知もオンにできます。")],
  c_title="お問い合わせ", c_sub="ご質問、機能のご要望、Mac / Windows版の先行利用などはこちらから。",
  c_name="お名前", c_email="メールアドレス", c_topic="件名", c_msg="メッセージ", c_send="送信", c_sending="送信中…", c_ok="ありがとうございます。メッセージを送信しました。", c_err="送信できませんでした。もう一度お試しください。", c_wait="次のメッセージは少し待ってから送信してください。", c_req="必須",
  topics=[("Question","質問"),("Feature request","機能のご要望"),("Partnership","提携のご相談"),("Bug report","不具合の報告"),("Other","Mac / Windows版の先行利用")],
  foot="Pricing AIは価格と予約の計画を支援します。価格や見積もりは計画用の目安であり、助言ではありません。",
  app_tag="App early access"),
"pt": dict(
  title="Pricing AI · Defina preços de serviços e crie seu site de reservas", desc="Calcule quanto cada serviço custa, defina preços que atinjam seu lucro-alvo e publique um site de reservas multilíngue com Google Forms e Agenda. Versão web gratuita, IA local no Mac e no Windows.",
  nav=["Recursos", "Como funciona", "Perguntas", "Contato"], badge=["Versão web gratuita", "Seus dados ficam no seu computador", "Sem cadastro"],
  h1="Defina preços. Crie seu site de reservas. Receba reservas.", lead="O Pricing AI ajuda salões, clínicas, restaurantes, escolas e espaços de aluguel a definir preços lucrativos, publicar um site de reservas em minutos e receber reservas no Google Forms e na Google Agenda.",
  cta1="Abrir o app web", cta2="Fale conosco",
  f_title="Tudo o que um pequeno negócio de serviços precisa", f_sub="Do primeiro preço à primeira reserva.",
  feats=[("Calculadora de preços de serviços","Informe seu valor por hora, custos fixos e lucro-alvo. O Pricing AI calcula o custo real de cada serviço e o preço que atinge sua margem, com impostos e arredondamento para 14 moedas."),
         ("Editor de site de reservas","Comece com um modelo limpo em inglês, 繁體中文, 日本語, Português ou Español. Edite visualmente, adicione FAQ, fluxogramas e um visual tecnológico escuro. Exporte um ZIP ou publique no Firebase."),
         ("Reservas no Google Forms e na Agenda","Um Apps Script cria o formulário e uma agenda que mostra os horários ocupados publicamente. Cada reserva vira um evento e o site mostra a disponibilidade."),
         ("IA local no Mac e no Windows","O app desktop roda modelos abertos na sua própria GPU: escreve seu site por chat, reescreve partes e desenha imagens de banner. Nada é enviado a uma IA na nuvem.")],
  h_title="Como funciona", steps=[("Defina os preços","Informe custos e lucro-alvo e obtenha a lista de preços de cada serviço."),("Crie o site","Adicione a lista a um modelo ou descreva seu negócio em um chat."),("Conecte as reservas","Cole o link do Google Forms ou crie o formulário e a agenda com um script."),("Publique","Baixe um ZIP para qualquer hospedagem ou publique no Firebase pelo app desktop.")],
  who_title="Feito para prestadores de serviços", who=["Salões de beleza","Clínicas e consultórios odontológicos","Restaurantes e cafés","Escolas e aulas","Salas de reunião e espaços para alugar"],
  faq_title="Perguntas frequentes",
  faq=[("É gratuito?","A versão web é gratuita: calculadora de preços, editor de site e exportação em ZIP. Os apps para Mac e Windows acrescentam IA local e publicação com um clique."),
       ("A IA envia meus dados para a nuvem?","Não. No app desktop os modelos de IA rodam no seu computador. A versão web não tem IA e mantém seus dados no navegador."),
       ("Preciso saber programar?","Não. Você edita a página visualmente ou por chat, e o formulário de reservas se conecta por um Google Forms."),
       ("Quais idiomas são suportados?","O app e os modelos de site estão em inglês, chinês tradicional, japonês, português do Brasil e espanhol."),
       ("Como recebo as reservas?","Os visitantes preenchem seu Google Forms no seu site. Um script adiciona cada reserva à Google Agenda e você pode ativar notificações por e-mail no Google Forms.")],
  c_title="Fale conosco", c_sub="Dúvidas, pedidos de recursos ou acesso antecipado ao app para Mac e Windows? Envie uma mensagem.",
  c_name="Nome", c_email="E-mail", c_topic="Assunto", c_msg="Mensagem", c_send="Enviar mensagem", c_sending="Enviando…", c_ok="Obrigado! Sua mensagem foi enviada.", c_err="Não foi possível enviar. Tente novamente.", c_wait="Aguarde um momento antes de enviar outra mensagem.", c_req="obrigatório",
  topics=[("Question","Dúvida"),("Feature request","Pedido de recurso"),("Partnership","Parceria"),("Bug report","Relato de erro"),("Other","Acesso antecipado ao app Mac / Windows")],
  foot="O Pricing AI ajuda a planejar preços e reservas. Preços e estimativas são apoio ao planejamento, não aconselhamento.",
  app_tag="App early access"),
"es": dict(
  title="Pricing AI · Fija precios de servicios y crea tu web de reservas", desc="Calcula cuánto cuesta cada servicio, fija precios que alcancen tu beneficio objetivo y publica una web de reservas multilingüe con Google Forms y Calendar. Versión web gratuita, IA local en Mac y Windows.",
  nav=["Funciones", "Cómo funciona", "Preguntas", "Contacto"], badge=["Versión web gratuita", "Tus datos se quedan en tu ordenador", "Sin registro"],
  h1="Fija precios. Crea tu web de reservas. Recibe reservas.", lead="Pricing AI ayuda a peluquerías, clínicas, restaurantes, escuelas y espacios de alquiler a fijar precios rentables, publicar una web de reservas en minutos y recibir reservas en Google Forms y Google Calendar.",
  cta1="Abrir la app web", cta2="Contáctanos",
  f_title="Todo lo que necesita un pequeño negocio de servicios", f_sub="Del primer precio a la primera reserva.",
  feats=[("Calculadora de precios de servicios","Introduce tu pago por hora, costes fijos y beneficio objetivo. Pricing AI calcula el coste real de cada servicio y el precio que alcanza tu margen, con impuestos y redondeo para 14 monedas."),
         ("Editor de web de reservas","Empieza con una plantilla limpia en inglés, 繁體中文, 日本語, Português o Español. Edita visualmente, añade preguntas frecuentes, diagramas y un aspecto tecnológico oscuro. Exporta un ZIP o publica en Firebase."),
         ("Reservas en Google Forms y Calendar","Un Apps Script crea el formulario y un calendario que muestra públicamente los horarios ocupados. Cada reserva se convierte en un evento y la web muestra la disponibilidad."),
         ("IA local en Mac y Windows","La app de escritorio ejecuta modelos abiertos en tu propia GPU: escribe tu web por chat, reescribe partes y dibuja imágenes de banner. No se envía nada a una IA en la nube.")],
  h_title="Cómo funciona", steps=[("Fija los precios","Introduce costes y beneficio objetivo y obtén la lista de precios de cada servicio."),("Crea la web","Añade la lista a una plantilla o describe tu negocio en un chat."),("Conecta las reservas","Pega el enlace de Google Forms o crea el formulario y el calendario con un script."),("Publica","Descarga un ZIP para cualquier alojamiento o publica en Firebase desde la app de escritorio.")],
  who_title="Hecho para proveedores de servicios", who=["Peluquerías y salones de belleza","Clínicas y consultas dentales","Restaurantes y cafeterías","Escuelas y clases","Salas de reuniones y espacios de alquiler"],
  faq_title="Preguntas frecuentes",
  faq=[("¿Es gratis?","La versión web es gratuita: calculadora de precios, editor de web y exportación en ZIP. Las apps para Mac y Windows añaden IA local y publicación con un clic."),
       ("¿La IA envía mis datos a la nube?","No. En la app de escritorio los modelos de IA se ejecutan en tu ordenador. La versión web no tiene IA y mantiene tus datos en el navegador."),
       ("¿Necesito saber programar?","No. Editas la página visualmente o por chat, y el formulario de reservas se conecta con un Google Forms."),
       ("¿Qué idiomas admite?","La app y las plantillas de web están en inglés, chino tradicional, japonés, portugués de Brasil y español."),
       ("¿Cómo recibo las reservas?","Los visitantes rellenan tu Google Forms desde tu web. Un script añade cada reserva a Google Calendar y puedes activar avisos por correo en Google Forms.")],
  c_title="Contáctanos", c_sub="¿Preguntas, ideas de funciones o acceso anticipado a la app para Mac y Windows? Envíanos un mensaje.",
  c_name="Nombre", c_email="Correo electrónico", c_topic="Asunto", c_msg="Mensaje", c_send="Enviar mensaje", c_sending="Enviando…", c_ok="¡Gracias! Tu mensaje se ha enviado.", c_err="No se pudo enviar. Inténtalo de nuevo.", c_wait="Espera un momento antes de enviar otro mensaje.", c_req="obligatorio",
  topics=[("Question","Pregunta"),("Feature request","Idea de función"),("Partnership","Colaboración"),("Bug report","Informar de un error"),("Other","Acceso anticipado a la app Mac / Windows")],
  foot="Pricing AI ayuda a planificar precios y reservas. Los precios y estimaciones son una ayuda de planificación, no un consejo.",
  app_tag="App early access"),
}

# ===== 下載優先（像 VPN 軟體的官網）：主要動作是下載 Mac / Windows App，網頁版是次要選項 =====
VERSION = "0.1.0"
# 安裝檔網址：填好就是直接下載；空字串 = 還沒公開，按鈕改成「搶先使用」並打開聯絡表單
DOWNLOADS = {"mac": "", "win": ""}

D = {
"en": dict(
  nav="Download", badges=["Free download", "AI runs on your own computer", "No account needed"],
  mac="Download for macOS", win="Download for Windows", any="Download the app",
  early_mac="Get the Mac app", early_win="Get the Windows app", early_any="Get early access",
  meta="Free · Version {v} · macOS 10.15+ · Windows 10/11 (64-bit)", also="Also available for", web="or use the browser version (no AI)",
  early_note="The installers are in early access: leave your email and we will send you the download link.",
  other_os="On a phone or tablet? Open this page on your Mac or Windows computer to download.",
  d_title="Download Pricing AI", d_sub="One app for service pricing, booking sites, project estimates and government case analysis.",
  mac_card=("macOS", "macOS 10.15 or later · Apple silicon or Intel", ".dmg"), win_card=("Windows", "Windows 10 or 11 · 64-bit", ".exe"),
  web_card=("Browser version", "No install. Pricing, the site builder and ZIP export work in your browser, without AI.", "Open in browser"),
  i_title="Install in 3 steps", i_steps=[("Download", "Click the download button for your computer."), ("Install", "Mac: open the .dmg and drag Pricing AI to Applications. Windows: run the installer."), ("Open", "Start Pricing AI. The first AI task downloads the AI engine and a model once (0.5–5 GB). After that the AI runs on your computer.")],
  cmp_title="Desktop app or browser?", cmp_sub="The browser version, including a shortcut that Chrome offers to install, is not the desktop app: it has no AI.",
  cmp_cols=("Feature", "Desktop app", "Browser"),
  cmp=[("Service pricing calculator", 1, 1), ("Booking site builder and ZIP export", 1, 1), ("Project estimate from the built-in price table", 1, 1), ("AI estimates and writing your site by chat", 1, 0), ("Government case analysis and AI summary of past cases", 1, 0), ("Competitor records and Google AI Mode lookups", 1, 0), ("One-click deploy to Firebase", 1, 0), ("Your data stays on your computer", 1, 1)],
  r_title="System requirements", req=[("macOS", "10.15 or later. Apple silicon recommended (picture generation needs Apple silicon)."), ("Windows", "10 or 11, 64-bit. A graphics card with Vulkan support is recommended (NVIDIA, AMD or Intel)."), ("Memory", "8 GB RAM or more; 16 GB for the larger AI models."), ("Disk", "About 1–6 GB free for the AI engine and model."), ("Internet", "To download the AI model once, and to look up procurement cases.")],
  feat_case=("Government case analysis", "Search Taiwan's Government e-Procurement System inside the app: award amounts, competitors and their win records, with a local AI summary and Google AI Mode lookups."),
  faq_more=[("What is the difference between the app and the browser version?", "The desktop app adds local AI, government case analysis, competitor lookups and one-click deploy. The browser version is free and needs no install, but has no AI."), ("Chrome offers to install Pricing AI. Is that the app?", "No. Chrome installs the browser version as a shortcut called Pricing AI Web. For AI and case analysis, download the Mac or Windows app from this page.")],
  mock=["Service pricing", "Site builder", "Project estimate", "Case analysis"], mock_stats=[("Median award", "NT$982,500"), ("Middle 50%", "NT$426K – 1.71M"), ("Your quote", "Low end")]),
"zh": dict(
  nav="下載", badges=["免費下載", "AI 在你的電腦上執行", "免註冊帳號"],
  mac="下載 macOS 版", win="下載 Windows 版", any="下載 App",
  early_mac="取得 Mac 版", early_win="取得 Windows 版", early_any="搶先使用",
  meta="免費 · 版本 {v} · macOS 10.15 以上 · Windows 10/11（64 位元）", also="也有", web="或使用網頁版（沒有 AI）",
  early_note="安裝檔目前開放搶先使用：留下電子郵件，我們會寄下載連結給你。",
  other_os="正在用手機或平板？請在 Mac 或 Windows 電腦上打開這個網頁下載。",
  d_title="下載 Pricing AI", d_sub="服務定價、預約網站、專案估價與政府標案分析，一個 App 全部搞定。",
  mac_card=("macOS", "macOS 10.15 以上 · Apple 晶片或 Intel", ".dmg"), win_card=("Windows", "Windows 10 或 11 · 64 位元", ".exe"),
  web_card=("網頁版", "免安裝。價格計算、網站編輯與 ZIP 匯出都能在瀏覽器使用，但沒有 AI。", "在瀏覽器開啟"),
  i_title="三個步驟完成安裝", i_steps=[("下載", "按下符合你電腦的下載按鈕。"), ("安裝", "Mac：打開 .dmg，把 Pricing AI 拖到「應用程式」。Windows：執行安裝程式。"), ("開啟", "啟動 Pricing AI。第一次使用 AI 時會下載一次 AI 引擎與模型（0.5–5 GB），之後 AI 就在你的電腦上執行。")],
  cmp_title="桌面 App 還是網頁版？", cmp_sub="網頁版（包括 Chrome 提示「安裝」的捷徑）不是桌面 App，沒有 AI。",
  cmp_cols=("功能", "桌面 App", "網頁版"),
  cmp=[("服務定價計算", 1, 1), ("預約網站編輯與 ZIP 匯出", 1, 1), ("依內建價目表的專案估價", 1, 1), ("AI 估價、用對話寫網站", 1, 0), ("政府標案分析與歷史案件 AI 摘要", 1, 0), ("競爭對手紀錄與 Google AI 模式查詢", 1, 0), ("一鍵部署到 Firebase", 1, 0), ("資料留在你的電腦", 1, 1)],
  r_title="系統需求", req=[("macOS", "10.15 以上。建議 Apple 晶片（繪製圖片需要 Apple 晶片）。"), ("Windows", "10 或 11，64 位元。建議有支援 Vulkan 的顯示卡（NVIDIA、AMD 或 Intel）。"), ("記憶體", "8 GB 以上；較大的 AI 模型建議 16 GB。"), ("硬碟", "AI 引擎與模型約需 1–6 GB 空間。"), ("網路", "第一次下載 AI 模型，以及查詢採購案件時需要。")],
  feat_case=("政府標案分析", "在 App 內查詢政府電子採購網：決標金額、競爭對手與他們的得標紀錄，並有本機 AI 摘要與 Google AI 模式查詢。"),
  faq_more=[("桌面 App 和網頁版有什麼不同？", "桌面 App 多了本機 AI、政府標案分析、競爭對手查詢與一鍵部署。網頁版免費、免安裝，但沒有 AI。"), ("Chrome 提示可以「安裝」Pricing AI，那是桌面 App 嗎？", "不是。Chrome 安裝的是網頁版的捷徑（名稱為 Pricing AI Web）。要使用 AI 與標案分析，請從這個網頁下載 Mac 或 Windows App。")],
  mock=["服務定價", "網站建置", "專案估價", "案件分析"], mock_stats=[("決標金額中位數", "NT$982,500"), ("中間 50%", "NT$42.6萬 – 171萬"), ("你的報價", "低價區")]),
"ja": dict(
  nav="ダウンロード", badges=["無料ダウンロード", "AIは自分のパソコンで動作", "アカウント登録不要"],
  mac="macOS版をダウンロード", win="Windows版をダウンロード", any="アプリをダウンロード",
  early_mac="Mac版を入手", early_win="Windows版を入手", early_any="先行利用を申し込む",
  meta="無料 · バージョン {v} · macOS 10.15以降 · Windows 10/11（64ビット）", also="こちらも：", web="またはブラウザ版を使う（AIなし）",
  early_note="インストーラーは先行利用で提供中です。メールアドレスを送っていただければ、ダウンロードリンクをお送りします。",
  other_os="スマートフォンやタブレットをお使いですか？ MacまたはWindowsのパソコンでこのページを開いてダウンロードしてください。",
  d_title="Pricing AIをダウンロード", d_sub="サービス価格・予約サイト・開発の見積もり・政府調達の案件分析を、ひとつのアプリで。",
  mac_card=("macOS", "macOS 10.15以降 · Apple シリコンまたはIntel", ".dmg"), win_card=("Windows", "Windows 10 / 11 · 64ビット", ".exe"),
  web_card=("ブラウザ版", "インストール不要。価格計算、サイト作成、ZIP書き出しがブラウザで使えます（AIなし）。", "ブラウザで開く"),
  i_title="3ステップでインストール", i_steps=[("ダウンロード", "お使いのパソコン用のダウンロードボタンを押します。"), ("インストール", "Mac：.dmgを開き、Pricing AIを「アプリケーション」にドラッグ。Windows：インストーラーを実行。"), ("起動", "Pricing AIを起動します。最初のAI作業でAIエンジンとモデルを一度だけダウンロードします（0.5〜5 GB）。その後はパソコン上でAIが動きます。")],
  cmp_title="デスクトップアプリとブラウザ版", cmp_sub="ブラウザ版（Chromeが「インストール」を勧めるショートカットを含む）はデスクトップアプリではなく、AIがありません。",
  cmp_cols=("機能", "デスクトップアプリ", "ブラウザ版"),
  cmp=[("サービス価格の計算", 1, 1), ("予約サイトの作成とZIP書き出し", 1, 1), ("内蔵の料金表による開発の見積もり", 1, 1), ("AIの見積もり、チャットでのサイト作成", 1, 0), ("政府調達の案件分析と過去案件のAI要約", 1, 0), ("競合企業の記録とGoogle AIモードでの調査", 1, 0), ("Firebaseへのワンクリック公開", 1, 0), ("データは自分のパソコンに", 1, 1)],
  r_title="動作環境", req=[("macOS", "10.15以降。Apple シリコン推奨（画像生成にはApple シリコンが必要）。"), ("Windows", "10 / 11（64ビット）。Vulkan対応のグラフィックス推奨（NVIDIA、AMD、Intel）。"), ("メモリ", "8 GB以上。大きいAIモデルには16 GB。"), ("ディスク", "AIエンジンとモデル用に約1〜6 GBの空き。"), ("インターネット", "AIモデルの初回ダウンロードと、調達案件の検索に使います。")],
  feat_case=("政府調達の案件分析", "アプリ内で台湾の政府電子調達システムを検索：落札金額、競合企業とその落札実績を、ローカルAIの要約やGoogle AIモードと合わせて確認できます。"),
  faq_more=[("デスクトップアプリとブラウザ版の違いは？", "デスクトップアプリには、ローカルAI、政府調達の案件分析、競合企業の調査、ワンクリック公開があります。ブラウザ版は無料でインストール不要ですが、AIはありません。"), ("Chromeが Pricing AI の「インストール」を勧めてきます。これはアプリですか？", "いいえ。Chromeがインストールするのはブラウザ版のショートカット（Pricing AI Web）です。AIや案件分析を使うには、このページからMacまたはWindowsのアプリをダウンロードしてください。")],
  mock=["サービス価格", "サイト作成", "開発の見積もり", "案件分析"], mock_stats=[("落札金額の中央値", "NT$982,500"), ("中間50%", "NT$42.6萬 – 171萬"), ("あなたの見積もり", "低価格帯")]),
"pt": dict(
  nav="Baixar", badges=["Download gratuito", "A IA roda no seu computador", "Sem cadastro"],
  mac="Baixar para macOS", win="Baixar para Windows", any="Baixar o app",
  early_mac="Obter o app para Mac", early_win="Obter o app para Windows", early_any="Pedir acesso antecipado",
  meta="Grátis · Versão {v} · macOS 10.15+ · Windows 10/11 (64 bits)", also="Também para", web="ou use a versão do navegador (sem IA)",
  early_note="Os instaladores estão em acesso antecipado: deixe seu e-mail e enviaremos o link de download.",
  other_os="Está no celular ou tablet? Abra esta página no seu computador Mac ou Windows para baixar.",
  d_title="Baixe o Pricing AI", d_sub="Um app para preços de serviços, sites de reservas, orçamentos de projetos e análise de licitações públicas.",
  mac_card=("macOS", "macOS 10.15 ou posterior · Apple silicon ou Intel", ".dmg"), win_card=("Windows", "Windows 10 ou 11 · 64 bits", ".exe"),
  web_card=("Versão do navegador", "Sem instalação. Preços, editor de site e exportação em ZIP no navegador, sem IA.", "Abrir no navegador"),
  i_title="Instale em 3 passos", i_steps=[("Baixe", "Clique no botão de download do seu computador."), ("Instale", "Mac: abra o .dmg e arraste o Pricing AI para Aplicativos. Windows: execute o instalador."), ("Abra", "Inicie o Pricing AI. A primeira tarefa de IA baixa o motor e um modelo uma vez (0,5–5 GB). Depois, a IA roda no seu computador.")],
  cmp_title="App desktop ou navegador?", cmp_sub="A versão do navegador, inclusive o atalho que o Chrome oferece instalar, não é o app desktop: não tem IA.",
  cmp_cols=("Recurso", "App desktop", "Navegador"),
  cmp=[("Calculadora de preços de serviços", 1, 1), ("Editor de site de reservas e exportação em ZIP", 1, 1), ("Orçamento de projeto pela tabela embutida", 1, 1), ("Orçamentos com IA e site escrito por chat", 1, 0), ("Análise de licitações e resumo com IA", 1, 0), ("Histórico de concorrentes e Google Modo IA", 1, 0), ("Publicação no Firebase com um clique", 1, 0), ("Seus dados ficam no seu computador", 1, 1)],
  r_title="Requisitos do sistema", req=[("macOS", "10.15 ou posterior. Recomendado Apple silicon (gerar imagens exige Apple silicon)."), ("Windows", "10 ou 11, 64 bits. Recomendada placa de vídeo com Vulkan (NVIDIA, AMD ou Intel)."), ("Memória", "8 GB de RAM ou mais; 16 GB para os modelos maiores."), ("Disco", "Cerca de 1–6 GB livres para o motor e o modelo de IA."), ("Internet", "Para baixar o modelo de IA uma vez e consultar licitações.")],
  feat_case=("Análise de licitações públicas", "Pesquise o Sistema de Compras do governo de Taiwan dentro do app: valores adjudicados, concorrentes e seus históricos, com resumo por IA local e consultas no Google Modo IA."),
  faq_more=[("Qual a diferença entre o app e a versão do navegador?", "O app desktop acrescenta IA local, análise de licitações, consulta de concorrentes e publicação com um clique. A versão do navegador é gratuita e sem instalação, mas não tem IA."), ("O Chrome oferece instalar o Pricing AI. É o app?", "Não. O Chrome instala a versão do navegador como atalho (Pricing AI Web). Para IA e análise de licitações, baixe o app para Mac ou Windows nesta página.")],
  mock=["Preços", "Criar site", "Orçamento", "Licitações"], mock_stats=[("Mediana", "NT$982,500"), ("50% centrais", "NT$426K – 1.71M"), ("Seu orçamento", "Faixa baixa")]),
"es": dict(
  nav="Descargar", badges=["Descarga gratuita", "La IA funciona en tu ordenador", "Sin cuenta"],
  mac="Descargar para macOS", win="Descargar para Windows", any="Descargar la app",
  early_mac="Obtener la app para Mac", early_win="Obtener la app para Windows", early_any="Pedir acceso anticipado",
  meta="Gratis · Versión {v} · macOS 10.15+ · Windows 10/11 (64 bits)", also="También para", web="o usa la versión de navegador (sin IA)",
  early_note="Los instaladores están en acceso anticipado: déjanos tu correo y te enviaremos el enlace de descarga.",
  other_os="¿Estás en un móvil o tableta? Abre esta página en tu ordenador Mac o Windows para descargar.",
  d_title="Descarga Pricing AI", d_sub="Una app para precios de servicios, webs de reservas, presupuestos de proyectos y análisis de licitaciones públicas.",
  mac_card=("macOS", "macOS 10.15 o posterior · Apple silicon o Intel", ".dmg"), win_card=("Windows", "Windows 10 u 11 · 64 bits", ".exe"),
  web_card=("Versión de navegador", "Sin instalación. Precios, editor de webs y exportación en ZIP en tu navegador, sin IA.", "Abrir en el navegador"),
  i_title="Instala en 3 pasos", i_steps=[("Descarga", "Pulsa el botón de descarga de tu ordenador."), ("Instala", "Mac: abre el .dmg y arrastra Pricing AI a Aplicaciones. Windows: ejecuta el instalador."), ("Abre", "Inicia Pricing AI. La primera tarea de IA descarga una vez el motor y un modelo (0,5–5 GB). Después, la IA funciona en tu ordenador.")],
  cmp_title="¿App de escritorio o navegador?", cmp_sub="La versión de navegador, incluido el acceso directo que Chrome ofrece instalar, no es la app de escritorio: no tiene IA.",
  cmp_cols=("Función", "App de escritorio", "Navegador"),
  cmp=[("Calculadora de precios de servicios", 1, 1), ("Editor de web de reservas y exportación en ZIP", 1, 1), ("Presupuesto de proyecto con la tabla incluida", 1, 1), ("Presupuestos con IA y web escrita por chat", 1, 0), ("Análisis de licitaciones y resumen con IA", 1, 0), ("Historial de competidores y Google Modo IA", 1, 0), ("Publicación en Firebase con un clic", 1, 0), ("Tus datos se quedan en tu ordenador", 1, 1)],
  r_title="Requisitos del sistema", req=[("macOS", "10.15 o posterior. Se recomienda Apple silicon (generar imágenes requiere Apple silicon)."), ("Windows", "10 u 11, 64 bits. Se recomienda una tarjeta gráfica con Vulkan (NVIDIA, AMD o Intel)."), ("Memoria", "8 GB de RAM o más; 16 GB para los modelos grandes."), ("Disco", "Unos 1–6 GB libres para el motor y el modelo de IA."), ("Internet", "Para descargar el modelo de IA una vez y consultar licitaciones.")],
  feat_case=("Análisis de licitaciones públicas", "Busca en el Sistema de Compras del gobierno de Taiwán dentro de la app: importes adjudicados, competidores y su historial, con resumen por IA local y consultas en Google Modo IA."),
  faq_more=[("¿En qué se diferencia la app de la versión de navegador?", "La app de escritorio añade IA local, análisis de licitaciones, consulta de competidores y publicación con un clic. La versión de navegador es gratuita y sin instalación, pero no tiene IA."), ("Chrome ofrece instalar Pricing AI. ¿Es la app?", "No. Chrome instala la versión de navegador como acceso directo (Pricing AI Web). Para la IA y el análisis de licitaciones, descarga la app para Mac o Windows desde esta página.")],
  mock=["Precios", "Crear web", "Presupuesto", "Licitaciones"], mock_stats=[("Mediana", "NT$982,500"), ("50 % central", "NT$426K – 1.71M"), ("Tu presupuesto", "Franja baja")]),
}

e = html.escape

def page(code):
    path, hl, hreflang, locale, native = LANGS[code]
    t = T[code]
    url = ORIGIN + path
    alts = "\n".join(f'<link rel="alternate" hreflang="{LANGS[c][2]}" href="{ORIGIN}{LANGS[c][0]}">' for c in LANGS) + f'\n<link rel="alternate" hreflang="x-default" href="{ORIGIN}/">'
    langnav = "".join(f'<a href="{LANGS[c][0]}" hreflang="{LANGS[c][2]}" lang="{LANGS[c][1]}"{" aria-current=\"page\"" if c == code else ""}>{LANGS[c][4]}</a>' for c in LANGS)
    ld = [
      {"@context": "https://schema.org", "@type": "Organization", "name": "Pricing AI", "url": ORIGIN + "/", "logo": ORIGIN + "/logo.svg"},
      {"@context": "https://schema.org", "@type": "SoftwareApplication", "name": "Pricing AI", "url": url, "description": t["desc"], "applicationCategory": "BusinessApplication", "operatingSystem": "macOS, Windows, Web", "softwareVersion": VERSION, "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"}, "downloadUrl": url + "#download", "inLanguage": hreflang},
      {"@context": "https://schema.org", "@type": "FAQPage", "mainEntity": [{"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in [*D[code]["faq_more"], *t["faq"]]]},
    ]
    ldjson = json.dumps(ld, ensure_ascii=False).replace("</", "<\\/")
    d = D[code]
    feats = "".join(f'<article class="card"><h3>{e(h)}</h3><p>{e(p)}</p></article>' for h, p in [d["feat_case"], *t["feats"]])
    steps = "".join(f'<li><b>{e(h)}</b><span>{e(p)}</span></li>' for h, p in t["steps"])
    who = "".join(f"<li>{e(w)}</li>" for w in t["who"])
    faqs = [*d["faq_more"], *t["faq"]]
    faq = "".join(f'<details><summary>{e(q)}</summary><p>{e(a)}</p></details>' for q, a in faqs)
    topics = "".join(f'<option value="{e(v)}"{" data-app=\"1\"" if v == "Other" else ""}>{e(l)}</option>' for v, l in t["topics"])
    nav = t["nav"]
    app = f"/app/?lang={code}"
    released = bool(DOWNLOADS["mac"] or DOWNLOADS["win"])
    # 下載鈕：有安裝檔就直接下載；還沒公開就打開聯絡表單並選好「搶先使用」
    def href(os_):
        return DOWNLOADS[os_] or "#contact"
    def label(os_):
        return d[os_] if DOWNLOADS[os_] else d["early_" + os_]
    early = "" if released else ' data-early="1"'
    dlattrs = (f'data-mac-href="{e(href("mac"))}" data-mac-label="{e(label("mac"))}" data-win-href="{e(href("win"))}" data-win-label="{e(label("win"))}" '
               f'data-any-label="{e(d["any"] if released else d["early_any"])}"')
    check = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 16.2 4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4z"/></svg>'
    cross = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M19 6.4 17.6 5 12 10.6 6.4 5 5 6.4 10.6 12 5 17.6 6.4 19 12 13.4 17.6 19 19 17.6 13.4 12z"/></svg>'
    laptop = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 5h16a1 1 0 0 1 1 1v10H3V6a1 1 0 0 1 1-1zm1 2v7h14V7zM1 17h22v1a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2z"/></svg>'
    desktop = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 4h18a1 1 0 0 1 1 1v11a1 1 0 0 1-1 1h-7v2h3v2H7v-2h3v-2H3a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zm1 2v9h16V6z"/></svg>'
    globe = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm6.9 6h-3a15.7 15.7 0 0 0-1.4-3.6A8 8 0 0 1 18.9 8zM12 4c.8 1.2 1.5 2.5 1.9 4h-3.8c.4-1.5 1.1-2.8 1.9-4zM4.3 14a8 8 0 0 1 0-4h3.4a16.5 16.5 0 0 0 0 4zm.8 2h3a15.7 15.7 0 0 0 1.4 3.6A8 8 0 0 1 5.1 16zm3-8h-3a8 8 0 0 1 4.4-3.6A15.7 15.7 0 0 0 8.1 8zM12 20c-.8-1.2-1.5-2.5-1.9-4h3.8c-.4 1.5-1.1 2.8-1.9 4zm2.3-6H9.7a14.7 14.7 0 0 1 0-4h4.6a14.7 14.7 0 0 1 0 4zm.3 5.6c.6-1.1 1.1-2.3 1.4-3.6h3a8 8 0 0 1-4.4 3.6zM16.3 14a16.5 16.5 0 0 0 0-4h3.4a8 8 0 0 1 0 4z"/></svg>'
    def platform(os_, card, icon):
        name, req, ext = card
        return (f'<article class="plat" id="plat-{os_}"><div class="pi">{icon}</div><h3>{e(name)}</h3><p>{e(req)}</p>'
                f'<a class="btn solid dl-{os_}" href="{e(href(os_))}"{early}>{e(label(os_))}{"" if not DOWNLOADS[os_] else f" <small>{e(ext)}</small>"}</a></article>')
    wname, wdesc, wbtn = d["web_card"]
    cmp_rows = "".join(f'<tr><th scope="row">{e(f)}</th><td class="{"y" if a_ else "n"}">{check if a_ else cross}<span class="vh">{"✓" if a_ else "—"}</span></td><td class="{"y" if w_ else "n"}">{check if w_ else cross}<span class="vh">{"✓" if w_ else "—"}</span></td></tr>' for f, a_, w_ in d["cmp"])
    req = "".join(f'<div><dt>{e(k)}</dt><dd>{e(v)}</dd></div>' for k, v in d["req"])
    isteps = "".join(f'<li><b>{e(h)}</b><span>{e(p)}</span></li>' for h, p in d["i_steps"])
    mock_tabs = "".join(f'<span{" class=\"on\"" if i == 3 else ""}>{e(x)}</span>' for i, x in enumerate(d["mock"]))
    mock_stats = "".join(f'<div><small>{e(k)}</small><b>{e(v)}</b></div>' for k, v in d["mock_stats"])
    return f"""<!doctype html>
<html lang="{hl}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{e(t['title'])}</title>
<meta name="description" content="{e(t['desc'])}">
<meta name="robots" content="index, follow, max-image-preview:large">
<link rel="canonical" href="{url}">
{alts}
<meta property="og:type" content="website">
<meta property="og:site_name" content="Pricing AI">
<meta property="og:title" content="{e(t['title'])}">
<meta property="og:description" content="{e(t['desc'])}">
<meta property="og:url" content="{url}">
<meta property="og:image" content="{ORIGIN}/og-image.png">
<meta property="og:locale" content="{locale}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{e(t['title'])}">
<meta name="twitter:description" content="{e(t['desc'])}">
<meta name="twitter:image" content="{ORIGIN}/og-image.png">
<meta name="theme-color" content="#263c5c">
<link rel="icon" type="image/png" href="/favicon.png">
<link rel="stylesheet" href="/landing.css">
<script type="application/ld+json">{ldjson}</script>
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header class="top"><div class="wrap bar">
<a class="brand" href="{path}" aria-label="Pricing AI"><img src="/logo.svg" alt="Pricing AI" width="168" height="44"></a>
<nav aria-label="Main"><a href="#features">{e(nav[0])}</a><a href="#compare">{e(d['cmp_title'])}</a><a href="#faq">{e(nav[2])}</a><a href="#contact">{e(nav[3])}</a><a class="navdl" href="#download">{e(d['nav'])}</a></nav>
<nav class="langs" aria-label="Language">{langnav}</nav>
</div></header>
<main id="main">
<section class="hero"><div class="wrap herogrid">
<div>
<ul class="badges">{"".join(f"<li>{e(b)}</li>" for b in d['badges'])}</ul>
<h1>{e(t['h1'])}</h1>
<p class="lead">{e(t['lead'])}</p>
<div class="dlbox" {dlattrs}>
<a id="dl-main" class="btn primary big" href="#download">{e(d['any'] if released else d['early_any'])}</a>
<p class="meta">{e(d['meta'].format(v=VERSION))}</p>
<p class="alt"><span id="dl-also" hidden>{e(d['also'])} <a id="dl-other" href="#download"></a> · </span><a href="{app}">{e(d['web'])}</a></p>
<p class="note" id="dl-other-os" hidden>{e(d['other_os'])}</p>
</div>
</div>
<div class="mock" aria-hidden="true"><div class="mbar"><i></i><i></i><i></i></div><div class="mtabs">{mock_tabs}</div><div class="mbody"><div class="mstats">{mock_stats}</div><div class="mchart"><span style="height:22%"></span><span style="height:48%"></span><span style="height:100%"></span><span style="height:96%"></span><span style="height:36%"></span><span style="height:8%"></span></div></div></div>
</div></section>
<section id="download" class="sec"><div class="wrap"><h2>{e(d['d_title'])}</h2><p class="sub">{e(d['d_sub'])}</p>
<div class="plats">{platform("mac", d["mac_card"], laptop)}{platform("win", d["win_card"], desktop)}
<article class="plat web"><div class="pi">{globe}</div><h3>{e(wname)}</h3><p>{e(wdesc)}</p><a class="btn" href="{app}">{e(wbtn)}</a></article></div>
{"" if released else f'<p class="early">{e(d["early_note"])}</p>'}
<h2 class="mt">{e(d['i_title'])}</h2><ol class="steps">{isteps}</ol></div></section>
<section id="features" class="sec alt"><div class="wrap"><h2>{e(t['f_title'])}</h2><p class="sub">{e(t['f_sub'])}</p><div class="grid">{feats}</div></div></section>
<section id="compare" class="sec"><div class="wrap narrow"><h2>{e(d['cmp_title'])}</h2><p class="sub">{e(d['cmp_sub'])}</p>
<div class="tablewrap"><table class="cmp"><thead><tr><th scope="col">{e(d['cmp_cols'][0])}</th><th scope="col" class="app">{e(d['cmp_cols'][1])}</th><th scope="col">{e(d['cmp_cols'][2])}</th></tr></thead><tbody>{cmp_rows}</tbody></table></div>
<h2 class="mt">{e(d['r_title'])}</h2><dl class="req">{req}</dl></div></section>
<section id="how" class="sec alt"><div class="wrap"><h2>{e(t['h_title'])}</h2><ol class="steps">{steps}</ol>
<h2 class="mt">{e(t['who_title'])}</h2><ul class="who">{who}</ul></div></section>
<section id="faq" class="sec"><div class="wrap narrow"><h2>{e(t['faq_title'])}</h2>{faq}</div></section>
<section id="contact" class="sec alt"><div class="wrap narrow"><h2>{e(t['c_title'])}</h2><p class="sub">{e(t['c_sub'])}</p>
<form id="contact-form" class="form" novalidate data-action="{FORM_ACTION}" data-name="{ENTRY['name']}" data-email="{ENTRY['email']}" data-topic="{ENTRY['topic']}" data-message="{ENTRY['message']}" data-tag="{e(t['app_tag'])}" data-sending="{e(t['c_sending'])}" data-ok="{e(t['c_ok'])}" data-err="{e(t['c_err'])}" data-wait="{e(t['c_wait'])}" data-send="{e(t['c_send'])}">
<label><span>{e(t['c_name'])} <small>({e(t['c_req'])})</small></span><input name="name" autocomplete="name" required maxlength="100"></label>
<label><span>{e(t['c_email'])} <small>({e(t['c_req'])})</small></span><input name="email" type="email" autocomplete="email" required maxlength="200"></label>
<label><span>{e(t['c_topic'])}</span><select name="topic">{topics}</select></label>
<label><span>{e(t['c_msg'])} <small>({e(t['c_req'])})</small></span><textarea name="message" rows="5" required maxlength="4000"></textarea></label>
<div class="hp" aria-hidden="true"><label>Website<input name="website" tabindex="-1" autocomplete="off"></label></div>
<button class="btn primary" type="submit">{e(t['c_send'])}</button>
<p class="status" role="status" aria-live="polite"></p>
</form>
<noscript><p>JavaScript is required to send the form.</p></noscript></div></section>
</main>
<footer class="foot"><div class="wrap"><p>© Pricing AI</p><p>{e(t['foot'])}</p></div></footer>
<script src="/contact.js" defer></script>
</body>
</html>
"""

CSS = """:root{--bg:#f6f7fb;--fg:#1c2433;--mut:#4d586b;--card:#fff;--brand:#263c5c;--acc:#3b6fd4;--line:#dde1ea;--ok:#1a7f4b;--no:#a3acbb;--hero1:#1d2f4a;--hero2:#34507a;--onacc:#fff}
@media(prefers-color-scheme:dark){:root{--bg:#10141c;--fg:#e8ebf2;--mut:#a9b4c6;--card:#181e2a;--brand:#9db8e8;--acc:#7aa2ec;--line:#2a3243;--ok:#5fd39a;--no:#5b6577;--hero1:#0d1626;--hero2:#22385a;--onacc:#0d1626}}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.65 system-ui,-apple-system,"Segoe UI","PingFang TC","Hiragino Sans","Noto Sans","Microsoft JhengHei",sans-serif}
.skip{position:absolute;left:-999px}.skip:focus{left:8px;top:8px;background:#fff;color:#000;padding:8px 12px;z-index:10}
.vh{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0)}
.wrap{max-width:1120px;margin:0 auto;padding:0 20px}.narrow{max-width:820px}
.top{position:sticky;top:0;background:color-mix(in srgb,var(--bg) 92%,transparent);backdrop-filter:blur(8px);border-bottom:1px solid var(--line);z-index:5}
.bar{display:flex;flex-wrap:wrap;gap:8px 20px;align-items:center;justify-content:space-between;padding-top:10px;padding-bottom:10px}
.brand{display:block;background:#fff;border-radius:12px;padding:4px 10px;line-height:0}.brand img{height:40px;width:auto}
nav{display:flex;flex-wrap:wrap;align-items:center;gap:4px 16px;font-size:15px}nav a{color:var(--fg);text-decoration:none;padding:6px 2px}nav a:hover{color:var(--acc);text-decoration:underline}
nav a.navdl{background:var(--acc);color:var(--onacc);border-radius:99px;padding:6px 16px;font-weight:700}nav a.navdl:hover{text-decoration:none;filter:brightness(1.08);color:var(--onacc)}
.langs{font-size:13px}.langs a{color:var(--mut)}.langs a[aria-current]{color:var(--fg);font-weight:700}
.hero{padding:64px 0 56px;background:radial-gradient(1200px 500px at 80% -10%,#3b6fd455,transparent),linear-gradient(135deg,var(--hero1),var(--hero2));color:#fff;overflow:hidden}
.herogrid{display:grid;grid-template-columns:minmax(0,1.1fr) minmax(0,.9fr);gap:40px;align-items:center}
.badges{list-style:none;display:flex;flex-wrap:wrap;gap:8px;padding:0;margin:0 0 20px}.badges li{background:rgba(255,255,255,.14);border-radius:99px;padding:4px 14px;font-size:14px}
h1{font-size:clamp(30px,5vw,50px);line-height:1.15;margin:0 0 16px}.lead{font-size:clamp(17px,2.1vw,20px);opacity:.95;margin:0 0 28px}
.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;min-height:44px;padding:11px 24px;border-radius:99px;border:2px solid currentColor;font:inherit;font-weight:700;text-decoration:none;cursor:pointer;background:transparent;color:inherit;text-align:center}
.btn small{font-weight:400;opacity:.8}
.btn.primary{background:#fff;color:#1d2f4a;border-color:#fff}.btn.big{font-size:19px;padding:15px 34px;min-height:58px;box-shadow:0 10px 30px rgba(0,0,0,.25)}
.btn.solid{background:var(--acc);color:var(--onacc);border-color:var(--acc);width:100%}.form .btn.primary{background:var(--brand);color:var(--bg);border-color:var(--brand)}
.btn:focus-visible,a:focus-visible,input:focus-visible,select:focus-visible,textarea:focus-visible,summary:focus-visible{outline:3px solid #f5a524;outline-offset:2px}
.dlbox .meta{margin:12px 0 4px;font-size:14px;opacity:.85}.dlbox .alt{margin:0;font-size:14px}.dlbox .alt a{color:#fff}.dlbox .note{margin:8px 0 0;font-size:14px;background:rgba(255,255,255,.12);border-radius:10px;padding:8px 12px}
.mock{background:#0f1726;border:1px solid rgba(255,255,255,.18);border-radius:16px;box-shadow:0 30px 60px rgba(0,0,0,.35);overflow:hidden;transform:perspective(1200px) rotateY(-6deg)}
.mbar{display:flex;gap:6px;padding:10px 12px;background:#1b2538}.mbar i{width:11px;height:11px;border-radius:50%;background:#ff5f57}.mbar i+i{background:#febc2e}.mbar i+i+i{background:#28c840}
.mtabs{display:flex;gap:4px;padding:8px 10px;background:#263c5c;font-size:12px;flex-wrap:wrap}.mtabs span{padding:4px 10px;border-radius:99px;border:1px solid rgba(255,255,255,.3);color:#dfe7f5;white-space:nowrap}.mtabs span.on{background:#fff;color:#263c5c}
.mbody{padding:16px;background:#f3f5fa;color:#1c2433}.mstats{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}.mstats div{background:#e6eaf2;border-radius:10px;padding:8px 10px;min-width:0}.mstats small{display:block;font-size:11px;color:#4d586b}.mstats b{font-size:13px;display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.mchart{display:flex;align-items:flex-end;gap:8px;height:110px;margin-top:14px;padding:0 4px;border-bottom:2px solid #cfd6e3}.mchart span{flex:1;background:linear-gradient(#3b6fd4,#5d8be0);border-radius:6px 6px 0 0}.mchart span:nth-child(3){background:linear-gradient(#7c5cd6,#9b80e8)}
.sec{padding:60px 0}.sec.alt{background:color-mix(in srgb,var(--card) 70%,var(--bg))}
h2{font-size:clamp(24px,3.6vw,34px);line-height:1.25;margin:0 0 6px;color:var(--brand)}.mt{margin-top:44px}.sub{color:var(--mut);margin:0 0 24px}
.plats{display:grid;gap:16px;grid-template-columns:repeat(3,minmax(0,1fr))}.plat{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:22px;display:flex;flex-direction:column;gap:8px}
.plat h3{margin:0;font-size:20px}.plat p{margin:0 0 8px;color:var(--mut);flex:1}.plat .pi svg{width:40px;height:40px;fill:var(--acc)}.plat.web{border-style:dashed}.plat.web .pi svg{fill:var(--mut)}
.plat.mine{border-color:var(--acc);box-shadow:0 0 0 3px color-mix(in srgb,var(--acc) 25%,transparent)}
.early{margin:16px 0 0;padding:12px 16px;border-radius:12px;background:color-mix(in srgb,var(--acc) 12%,var(--card));border:1px solid color-mix(in srgb,var(--acc) 35%,var(--line))}
.grid{display:grid;gap:16px;grid-template-columns:repeat(auto-fit,minmax(240px,1fr))}.card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:20px}.card h3{margin:0 0 8px;font-size:18px}.card p{margin:0;color:var(--mut)}
.grid .card:first-child{border-color:var(--acc)}
.tablewrap{overflow-x:auto;border:1px solid var(--line);border-radius:14px;background:var(--card)}
.cmp{width:100%;border-collapse:collapse;font-size:15px}.cmp th,.cmp td{padding:12px 14px;border-bottom:1px solid var(--line);text-align:left}.cmp tbody tr:last-child th,.cmp tbody tr:last-child td{border-bottom:0}
.cmp thead th{font-size:14px;color:var(--mut)}.cmp thead th.app{color:var(--acc)}.cmp td{text-align:center;width:22%}.cmp thead th+th{text-align:center}.cmp th[scope=row]{font-weight:500}
.cmp svg{width:22px;height:22px;vertical-align:middle}.cmp td.y svg{fill:var(--ok)}.cmp td.n svg{fill:var(--no)}
.req{display:grid;gap:0;margin:16px 0 0;border:1px solid var(--line);border-radius:14px;background:var(--card);overflow:hidden}.req div{display:grid;grid-template-columns:140px 1fr;gap:12px;padding:12px 16px;border-bottom:1px solid var(--line)}.req div:last-child{border-bottom:0}.req dt{font-weight:700}.req dd{margin:0;color:var(--mut)}
.steps{counter-reset:s;list-style:none;padding:0;margin:20px 0 0;display:grid;gap:14px;grid-template-columns:repeat(auto-fit,minmax(220px,1fr))}
.steps li{counter-increment:s;background:var(--card);border:1px solid var(--line);border-radius:14px;padding:18px 18px 18px 58px;position:relative}
.steps li:before{content:counter(s);position:absolute;left:16px;top:16px;width:30px;height:30px;border-radius:50%;background:var(--brand);color:var(--bg);display:grid;place-items:center;font-weight:700}
.steps b{display:block;margin-bottom:4px}.steps span{color:var(--mut)}
.who{display:flex;flex-wrap:wrap;gap:10px;list-style:none;padding:0;margin:14px 0 0}.who li{background:var(--card);border:1px solid var(--line);border-radius:99px;padding:6px 16px}
details{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:4px 18px;margin:0 0 10px}summary{cursor:pointer;font-weight:600;padding:12px 0}details p{margin:0 0 14px;color:var(--mut)}
.form{display:grid;gap:14px;background:var(--card);border:1px solid var(--line);border-radius:16px;padding:24px}.form label{display:grid;gap:4px;font-size:14px;color:var(--mut)}
.form small{font-weight:400}.form input,.form select,.form textarea{font:inherit;padding:10px 12px;border:1px solid var(--line);border-radius:10px;background:var(--bg);color:var(--fg);width:100%}
.hp{position:absolute;left:-9999px;height:0;overflow:hidden}.status{min-height:1.5em;margin:0;font-weight:600}.status.ok{color:#1a7f4b}.status.err{color:#c0392b}
.foot{padding:28px 0 40px;color:var(--mut);font-size:14px;border-top:1px solid var(--line)}.foot p{margin:4px 0}
@media(max-width:900px){.herogrid{grid-template-columns:1fr}.mock{transform:none;max-width:520px}.plats{grid-template-columns:1fr}}
@media(max-width:640px){.top{position:static}.brand img{height:32px}nav{gap:2px 12px;font-size:14px}nav a{padding:4px 0}nav a.navdl{padding:4px 14px}.hero{padding:28px 0 36px}.bar{gap:4px 12px}.btn.big{width:100%}.req div{grid-template-columns:1fr;gap:2px}.cmp th,.cmp td{padding:10px 8px}.mtabs span:nth-child(-n+2){display:none}}
"""

JS = """// 下載鈕依作業系統切換（Mac / Windows / 其他）；「搶先使用」會打開聯絡表單並選好主題。
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
    body.append(d.message, msg + "\\n\\n(" + location.pathname + " · " + (navigator.language || "") + ")");
    btn.disabled = true; say(d.sending);
    fetch(d.action, { method: "POST", mode: "no-cors", body: body }).then(function () {
      last = Date.now(); try { sessionStorage.setItem("contactSent", String(last)); } catch (e) {}
      form.reset(); say(d.ok, "ok");
    }).catch(function () { say(d.err, "err"); }).then(function () { btn.disabled = false; });
  });
})();
"""

def main():
    os.makedirs(OUT, exist_ok=True)
    for code in LANGS:
        path = LANGS[code][0]
        d = os.path.join(OUT, path.strip("/"))
        os.makedirs(d, exist_ok=True)
        open(os.path.join(d, "index.html"), "w", encoding="utf-8").write(page(code))
    open(os.path.join(OUT, "landing.css"), "w", encoding="utf-8").write(CSS)
    open(os.path.join(OUT, "contact.js"), "w", encoding="utf-8").write(JS)
    urls = "\n".join(
        f'<url><loc>{ORIGIN}{LANGS[c][0]}</loc>' + "".join(f'<xhtml:link rel="alternate" hreflang="{LANGS[o][2]}" href="{ORIGIN}{LANGS[o][0]}"/>' for o in LANGS) + f'<xhtml:link rel="alternate" hreflang="x-default" href="{ORIGIN}/"/></url>'
        for c in LANGS)
    open(os.path.join(OUT, "sitemap.xml"), "w", encoding="utf-8").write(
        f'<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n{urls}\n</urlset>\n')
    open(os.path.join(OUT, "robots.txt"), "w").write(f"User-agent: *\nAllow: /\nDisallow: /app/\nDisallow: /s/\n\nSitemap: {ORIGIN}/sitemap.xml\n")
    print("landing generated:", sorted(os.listdir(OUT)))

if __name__ == "__main__":
    main()
