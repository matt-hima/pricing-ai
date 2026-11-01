import 'dart:convert';
import 'dart:math';

/// Pricing AI 的網址（編輯器的「AI pricing」按鈕開啟它）；測試時可用 --dart-define=PRICING_AI_URL=… 覆寫
const pricingAiUrl = String.fromEnvironment('PRICING_AI_URL', defaultValue: 'https://pricingai.minervaelectronics.com/app/');

const langs = {
  'en': 'English',
  'zh': '繁體中文',
  'ja': '日本語',
  'pt': 'Português',
  'es': 'Español',
};

/// 一個網站專案。內容（GrapesJS 專案資料）以 JSON 字串存放，空字串代表「還沒編輯過，套用語言範本」。
class Site {
  String name, slug, lang;
  String project;

  /// 已經完成「從聊天開始」的初始化（或選擇直接用範本）。舊的專案讀進來一律視為已初始化。
  bool initialized;

  /// 預約通知：endpoint（Formspree 等 POST JSON 的網址）優先，其次 mailto
  String mailto, endpoint;

  /// 部署記憶（桌面版）：Firebase 專案 ID 與 Hosting 站台 ID
  String deployProject, deploySite;

  /// 公開網址（SEO 的標準網址與 sitemap 用）；空白時若已部署過就用 https://<站台>.web.app/
  String siteUrl;

  /// 予約を受け取る Google フォームの公開リンク（空 = 未接続）。フォームの内容は編集中のページ側に保存される
  String googleForm;

  /// 予約カレンダー（空き時間だけ公開）の ID。設定するとページに「空き状況」が表示される
  String calendarId;

  Site({
    required this.name,
    required this.slug,
    required this.lang,
    this.project = '',
    this.initialized = true,
    this.mailto = '',
    this.endpoint = '',
    this.deployProject = '',
    this.deploySite = '',
    this.siteUrl = '',
    this.googleForm = '',
    this.calendarId = '',
  });

  factory Site.create(String lang) => Site(
        name: 'My booking site',
        slug: 'my-site-${Random().nextInt(1 << 30).toRadixString(36).padLeft(5, '0').substring(0, 5)}',
        lang: lang,
        initialized: false,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'slug': slug,
        'lang': lang,
        'project': project,
        'initialized': initialized,
        'mailto': mailto,
        'endpoint': endpoint,
        'deployProject': deployProject,
        'deploySite': deploySite,
        'siteUrl': siteUrl,
        'googleForm': googleForm,
        'calendarId': calendarId,
      };

  static Site fromJson(Map<String, dynamic> j) => Site(
        name: j['name'] as String? ?? 'Untitled',
        slug: j['slug'] as String? ?? 'my-site',
        lang: j['lang'] as String? ?? 'en',
        project: j['project'] as String? ?? '',
        initialized: j['initialized'] as bool? ?? true,
        mailto: j['mailto'] as String? ?? '',
        endpoint: j['endpoint'] as String? ?? '',
        deployProject: j['deployProject'] as String? ?? '',
        deploySite: j['deploySite'] as String? ?? '',
        siteUrl: j['siteUrl'] as String? ?? '',
        googleForm: j['googleForm'] as String? ?? '',
        calendarId: j['calendarId'] as String? ?? '',
      );

  String encode() => jsonEncode(toJson());
  static Site decode(String s) => fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// 傳給編輯器產生 HTML 的選項
  Map<String, String> get htmlOptions => {'title': name, 'slug': slug, 'lang': lang, 'mailto': mailto, 'endpoint': endpoint, 'url': effectiveUrl};

  String get effectiveUrl {
    final u = siteUrl.trim();
    if (RegExp(r'^https?://', caseSensitive: false).hasMatch(u)) return u.endsWith('/') ? u : '$u/';
    return deploySite.isEmpty ? '' : 'https://$deploySite.web.app/';
  }
}

final slugRe = RegExp(r'^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$');
final firebaseIdRe = RegExp(r'^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$');
