// 報價單位預設值：留空，由使用者在「我的公司」分頁自行填寫
export const COMPANY = { name: "", taxid: "", address: "", phone: "", email: "" };

// 計價參數預設值（使用者可在「我的公司」分頁修改人月單價、工時、稅率與維護費比例）
export const PRICING = {
  currency: "TWD",
  ratePerMM: 120000,      // 每人月單價（台灣行情 10–15 萬）
  hoursPerMM: 176,        // 每人月工時（22 天 × 8 小時）
  vatRate: 0.05,          // 營業稅
  refPrefix: "PR",        // Dolibarr 報價單編號前綴
  warrantyMonths: 3,
  maintMin: 0.15,         // 年度維護費下限（佔開發費）
  maintMax: 0.20,
  // 依專案複雜度決定的風險係數（顯示總價上限用）
  riskBuffer: { 低: 1.2, 中: 1.3, 高: 1.5 },
  urgency: { normal: 1.0, rush: 1.25, flex: 0.95 },
};

export const PROJECT_TYPES = [
  { id: "corporate", name: "企業形象網站", factor: 0.8 },
  { id: "ecommerce", name: "電商 / 購物", factor: 1.0 },
  { id: "app", name: "會員 / 服務型 App", factor: 1.0 },
  { id: "saas", name: "SaaS / 平台", factor: 1.15 },
  { id: "erp", name: "企業內部系統 / ERP", factor: 1.1 },
];

export const PLATFORMS = [
  { id: "web", name: "響應式網站" },
  { id: "ios", name: "iOS App" },
  { id: "android", name: "Android App" },
];

export const APP_TECH = [
  { id: "cross", name: "跨平台（Flutter / RN）" },
  { id: "native", name: "原生分別開發" },
];

export const DESIGN_LEVELS = [
  { id: "template", name: "套版微調", factor: 0.6 },
  { id: "custom", name: "客製化設計", factor: 1.0 },
  { id: "premium", name: "品牌級高質感", factor: 1.5 },
];

// fe = 前端/客戶端工時（單一平台基準），be = 後端/API 工時
export const MODULES = [
  { id: "member", name: "會員系統", desc: "註冊、登入、忘記密碼、社群登入", fe: 40, be: 40, ph: "例如：要 LINE / Google 登入，手機簡訊驗證" },
  { id: "profile", name: "角色權限", desc: "多角色、權限控管、個人資料", fe: 24, be: 36, ph: "例如：分店長、店員、總部三種角色" },
  { id: "catalog", name: "商品 / 內容瀏覽", desc: "分類、搜尋、篩選、詳情頁", fe: 60, be: 44, ph: "例如：約 500 項商品，需規格與庫存" },
  { id: "cart", name: "購物車與訂單", desc: "購物車、結帳流程、訂單查詢", fe: 60, be: 60, ph: "例如：需要優惠券與滿額折扣" },
  { id: "payment", name: "金流支付", desc: "信用卡、行動支付、退款", fe: 30, be: 60, ph: "例如：綁定 LINE Pay 和信用卡分期" },
  { id: "logistics", name: "物流出貨", desc: "超商取貨、宅配、出貨單", fe: 16, be: 40, ph: "例如：7-11 / 全家取貨，自動產生託運單" },
  { id: "booking", name: "預約排程", desc: "時段預約、行事曆、提醒", fe: 50, be: 50, ph: "例如：依服務人員與時段預約" },
  { id: "chat", name: "即時通訊 / 客服", desc: "一對一聊天、客服工單", fe: 50, be: 64, ph: "例如：客人可與門市即時文字對話" },
  { id: "notify", name: "通知推播", desc: "App 推播、Email、簡訊", fe: 16, be: 32, ph: "例如：訂單狀態變更時推播" },
  { id: "map", name: "地圖定位", desc: "門市地圖、定位、導航", fe: 40, be: 28, ph: "例如：顯示最近門市與營業時間" },
  { id: "cms", name: "內容管理 / 部落格", desc: "最新消息、文章、Banner", fe: 30, be: 30, ph: "例如：行銷人員自行上稿" },
  { id: "admin", name: "後台管理系統", desc: "資料管理、審核、設定", fe: 80, be: 60, ph: "例如：訂單、會員、商品管理與匯出 Excel" },
  { id: "report", name: "報表與數據分析", desc: "儀表板、統計圖表、匯出", fe: 40, be: 48, ph: "例如：每日營收、熱銷商品排行" },
  { id: "integration", name: "第三方系統串接", desc: "ERP / POS / CRM / API", fe: 0, be: 80, ph: "例如：與現有 POS 系統同步會員點數" },
  { id: "ai", name: "AI 功能", desc: "推薦、聊天機器人、影像辨識", fe: 24, be: 90, ph: "例如：客服 FAQ 聊天機器人" },
  { id: "i18n", name: "多語系", desc: "中英日等多語介面", fe: 24, be: 12, ph: "例如：繁中、英文、日文" },
  { id: "seo", name: "SEO 與追蹤", desc: "SEO 設定、GA4、Pixel", fe: 16, be: 8, ph: "例如：GA4 電商事件追蹤" },
];

// 白話描述中代表複雜度上升的關鍵字（每個 +8%，上限 +40%）
export const COMPLEX_KEYWORDS = [
  "分期", "多幣", "跨境", "即時", "串接", "整合", "同步", "客製", "權限", "審核", "簽核", "高併發", "大量", "百萬",
  "離線", "區塊鏈", "AI", "辨識", "推薦", "影音", "直播", "排程", "自動", "多角色", "多店", "加盟", "訂閱", "定期",
  "發票", "電子發票", "POS", "ERP", "資安", "加密", "OCR", "IoT", "藍牙", "硬體",
];
