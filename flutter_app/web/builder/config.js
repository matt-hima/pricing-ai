// 網站建置器設定：Firebase 專案（與 ai-invoicing 同一個 project）與 Firestore 集合名稱。
// Web API key 本來就是公開的，權限由 Firestore 安全規則控管（見 firestore.builder.rules）。
export const FIREBASE = {
  apiKey: "AIzaSyBU1p2Bp2lzwbxGZZ9-h5w27okW0JEEgxc",
  authDomain: "task-exchange-f8f97.firebaseapp.com",
  projectId: "task-exchange-f8f97",
  storageBucket: "task-exchange-f8f97.firebasestorage.app",
  messagingSenderId: "499551530842",
  appId: "1:499551530842:web:2989b766086c07c017cd63",
};

// 同一個 Firebase 專案還有其他 app，集合名稱加上 builder 前綴避免撞名
export const COL_DRAFTS = "builderSites";       // 草稿（僅擁有者可讀寫）
export const COL_PUBLISHED = "builderPublished"; // 已發佈網站（公開讀取），底下 bookings 子集合存預約

export const FIREBASE_SDK = "https://www.gstatic.com/firebasejs/10.12.2";

// 平台網址：發佈的網站與嵌入的 AI 估價都指向建置器所在的網域
export const PLATFORM_ORIGIN = location.origin;

export const LANGS = [
  { id: "en", name: "English" },
  { id: "zh", name: "繁體中文" },
  { id: "ja", name: "日本語" },
  { id: "pt", name: "Português" },
  { id: "es", name: "Español" },
];
