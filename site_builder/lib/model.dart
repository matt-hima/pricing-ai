import 'dart:convert';
import 'dart:math';

/// Pricing AI 的網址（編輯器的「AI pricing」按鈕開啟它）；測試時可用 --dart-define=PRICING_AI_URL=… 覆寫
const pricingAiUrl = String.fromEnvironment('PRICING_AI_URL', defaultValue: 'https://ai-invoicing.web.app');

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

  /// 預約通知：endpoint（Formspree 等 POST JSON 的網址）優先，其次 mailto
  String mailto, endpoint;

  /// 部署記憶（桌面版）：Firebase 專案 ID 與 Hosting 站台 ID
  String deployProject, deploySite;

  Site({
    required this.name,
    required this.slug,
    required this.lang,
    this.project = '',
    this.mailto = '',
    this.endpoint = '',
    this.deployProject = '',
    this.deploySite = '',
  });

  factory Site.create(String lang) => Site(
        name: 'My booking site',
        slug: 'my-site-${Random().nextInt(1 << 30).toRadixString(36).padLeft(5, '0').substring(0, 5)}',
        lang: lang,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'slug': slug,
        'lang': lang,
        'project': project,
        'mailto': mailto,
        'endpoint': endpoint,
        'deployProject': deployProject,
        'deploySite': deploySite,
      };

  static Site fromJson(Map<String, dynamic> j) => Site(
        name: j['name'] as String? ?? 'Untitled',
        slug: j['slug'] as String? ?? 'my-site',
        lang: j['lang'] as String? ?? 'en',
        project: j['project'] as String? ?? '',
        mailto: j['mailto'] as String? ?? '',
        endpoint: j['endpoint'] as String? ?? '',
        deployProject: j['deployProject'] as String? ?? '',
        deploySite: j['deploySite'] as String? ?? '',
      );

  String encode() => jsonEncode(toJson());
  static Site decode(String s) => fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// 傳給編輯器產生 HTML 的選項
  Map<String, String> get htmlOptions => {'title': name, 'slug': slug, 'lang': lang, 'mailto': mailto, 'endpoint': endpoint};
}

final slugRe = RegExp(r'^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$');
final firebaseIdRe = RegExp(r'^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$');
