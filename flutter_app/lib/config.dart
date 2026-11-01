import 'i18n/i18n.dart';

/// 估價常數：專案類型、平台、模組基準工時。顯示文字一律走 i18n（tr），
/// 存進草稿的值都是語言無關的 id，切換語言不會讓已填資料失效。

class Option {
  final String id;
  final String key;
  final double factor;
  const Option(this.id, this.key, [this.factor = 1]);
  String get name => tr(key);
}

class ModuleDef {
  final String id;

  /// fe = 前端/客戶端工時（單一平台基準），be = 後端/API 工時
  final double fe, be;
  const ModuleDef(this.id, this.fe, this.be);
  String get name => tr('mod.$id.n');
  String get desc => tr('mod.$id.d');
  String get hint => tr('mod.$id.h');
}

const projectTypes = [
  Option('corporate', 'type.corporate', 0.8),
  Option('ecommerce', 'type.ecommerce', 1.0),
  Option('app', 'type.app', 1.0),
  Option('saas', 'type.saas', 1.15),
  Option('erp', 'type.erp', 1.1),
];

const platforms = [
  Option('web', 'plat.web'),
  Option('ios', 'plat.ios'),
  Option('android', 'plat.android'),
];

const appTechs = [
  Option('cross', 'tech.cross'),
  Option('native', 'tech.native'),
];

const designLevels = [
  Option('template', 'design.template', 0.6),
  Option('custom', 'design.custom', 1.0),
  Option('premium', 'design.premium', 1.5),
];

Map<String, String> get payTerms => {
      '3-4-3': tr('pay.343'),
      '5-5': tr('pay.55'),
      'monthly': tr('pay.monthly'),
    };
Map<String, String> get payModes => {
      'transfer': tr('mode.transfer'),
      'check': tr('mode.check'),
      'card': tr('mode.card'),
    };
Map<String, String> get urgencies => {
      'normal': tr('urg.normal'),
      'rush': tr('urg.rush'),
      'flex': tr('urg.flex'),
    };
const urgencyFactor = {'normal': 1.0, 'rush': 1.25, 'flex': 0.95};
Map<String, String> get budgets => {
      'undecided': tr('bud.undecided'),
      'lt30': tr('bud.lt30'),
      '30_80': tr('bud.30_80'),
      '80_200': tr('bud.80_200'),
      'gt200': tr('bud.gt200'),
    };
Map<String, String> get sources => {
      'website': tr('src.website'),
      'referral': tr('src.referral'),
      'search': tr('src.search'),
      'social': tr('src.social'),
      'other': tr('src.other'),
    };

const modules = [
  ModuleDef('member', 40, 40),
  ModuleDef('profile', 24, 36),
  ModuleDef('catalog', 60, 44),
  ModuleDef('cart', 60, 60),
  ModuleDef('payment', 30, 60),
  ModuleDef('logistics', 16, 40),
  ModuleDef('booking', 50, 50),
  ModuleDef('chat', 50, 64),
  ModuleDef('notify', 16, 32),
  ModuleDef('map', 40, 28),
  ModuleDef('cms', 30, 30),
  ModuleDef('admin', 80, 60),
  ModuleDef('report', 40, 48),
  ModuleDef('integration', 0, 80),
  ModuleDef('ai', 24, 90),
  ModuleDef('i18n', 24, 12),
  ModuleDef('seo', 16, 8),
];

/// 白話描述中代表複雜度上升的關鍵字（每個 +8%，上限 +40%）；涵蓋五種介面語言
const complexKeywords = [
  // 繁中
  '分期', '多幣', '跨境', '即時', '串接', '整合', '同步', '客製', '權限', '審核', '簽核', '高併發', '大量', '百萬',
  '離線', '區塊鏈', '辨識', '推薦', '影音', '直播', '排程', '自動', '多角色', '多店', '加盟', '訂閱', '定期',
  '發票', '電子發票', '資安', '加密', '硬體', '藍牙',
  // 日本語
  '分割払い', 'リアルタイム', '連携', '同期', 'カスタム', '承認', 'オフライン', 'サブスク', '請求書', '暗号', '多店舗', '自動',
  // English
  'installment', 'real-time', 'realtime', 'integration', 'integrate', 'sync', 'custom', 'permission', 'approval', 'offline',
  'blockchain', 'recognition', 'recommend', 'streaming', 'live stream', 'subscription', 'recurring', 'invoice', 'franchise',
  'multi-store', 'automatic', 'encryption', 'security', 'bluetooth', 'hardware', 'multi-currency', 'cross-border',
  // Português
  'parcel', 'tempo real', 'integração', 'sincroniz', 'personaliz', 'permiss', 'aprovação', 'assinatura', 'nota fiscal',
  'automátic', 'criptograf', 'segurança', 'multimoeda',
  // Español
  'cuotas', 'tiempo real', 'integración', 'sincroniz', 'personaliz', 'permisos', 'aprobación', 'sin conexión',
  'suscripción', 'factura', 'cifrado', 'seguridad', 'multimoneda', 'franquicia',
  // 共通
  'POS', 'ERP', 'AI', 'OCR', 'IoT',
];

/// 依專案複雜度決定的風險係數（顯示總價上限用）
const riskBuffer = {'low': 1.2, 'medium': 1.3, 'high': 1.5};

class ModelOption {
  final String base, key;
  const ModelOption(this.base, this.key);
  String get label => tr(key);

  /// CPU 版（WebAssembly）模型：不需要 WebGPU，ID 以 cpu: 開頭
  bool get isCpu => base.startsWith('cpu:');
}

const modelOptions = [
  ModelOption('Qwen2.5-0.5B-Instruct', 'model.0_5b'),
  ModelOption('Qwen2.5-1.5B-Instruct', 'model.1_5b'),
  ModelOption('Qwen2.5-7B-Instruct', 'model.7b'),
  ModelOption('Llama-3.1-8B-Instruct', 'model.llama8b'),
  ModelOption('cpu:qwen2.5-0.5b', 'model.cpu05'),
  ModelOption('cpu:qwen2.5-1.5b', 'model.cpu15'),
];
