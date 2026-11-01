import 'dart:convert';
import 'dart:math';

/// サービス業の価格設計：1 件あたりの原価（人件費 + 固定費の配賦 + 材料費）から、目標の利益率に合う販売価格を計算する。
/// すべて決まった式で計算する（AI は価格を決めない）。AI は「どんなサービスがあるか」の案出しにだけ使う。

class ServiceRow {
  String name;
  int minutes; // 1 件にかかる時間（準備・片付けを含む）
  double materials; // 材料・消耗品などの原価（1 件）
  double? priceOverride; // 自分で決めた価格（空なら計算結果）

  ServiceRow(this.name, this.minutes, {this.materials = 0, this.priceOverride});

  Map<String, Object?> toJson() => {'name': name, 'minutes': minutes, 'materials': materials, if (priceOverride != null) 'price': priceOverride};

  static ServiceRow fromJson(Map j) => ServiceRow(
        '${j['name'] ?? ''}',
        (j['minutes'] as num?)?.toInt() ?? 60,
        materials: (j['materials'] as num?)?.toDouble() ?? 0,
        priceOverride: (j['price'] as num?)?.toDouble(),
      );
}

class ServicePlan {
  String currency; // TWD | JPY | USD | EUR | BRL
  String industry;
  String siteLang; // サイトに載せる文章の言語（en / ja / zh / pt / es）。サービス名の例と「60分」などの表記に使う
  double laborPerHour; // 自分（スタッフ）の 1 時間あたりの人件費（目標の時給）
  double fixedPerMonth; // 家賃・光熱費・システム費など毎月の固定費
  double billableHoursPerMonth; // 1 か月に実際に接客できる（予約が入る）見込みの時間
  double marginPct; // 目標の利益率（売上に対する %）
  double taxPct;
  bool taxIncluded; // 価格表示が税込か
  double roundTo; // 価格をこの単位に丸める（切り上げ）
  List<ServiceRow> rows;

  ServicePlan({
    this.currency = 'TWD',
    this.industry = 'salon',
    this.siteLang = 'en',
    this.laborPerHour = 400,
    this.fixedPerMonth = 30000,
    this.billableHoursPerMonth = 80,
    this.marginPct = 30,
    this.taxPct = 5,
    this.taxIncluded = true,
    this.roundTo = 10,
    List<ServiceRow>? rows,
  }) : rows = rows ?? [];

  Map<String, Object?> toJson() => {
        'currency': currency,
        'industry': industry,
        'siteLang': siteLang,
        'laborPerHour': laborPerHour,
        'fixedPerMonth': fixedPerMonth,
        'billableHoursPerMonth': billableHoursPerMonth,
        'marginPct': marginPct,
        'taxPct': taxPct,
        'taxIncluded': taxIncluded,
        'roundTo': roundTo,
        'rows': [for (final r in rows) r.toJson()],
      };

  String encode() => jsonEncode(toJson());

  static ServicePlan fromJson(Map j) => ServicePlan(
        currency: '${j['currency'] ?? 'TWD'}',
        industry: '${j['industry'] ?? 'salon'}',
        siteLang: '${j['siteLang'] ?? 'en'}',
        laborPerHour: (j['laborPerHour'] as num?)?.toDouble() ?? 400,
        fixedPerMonth: (j['fixedPerMonth'] as num?)?.toDouble() ?? 30000,
        billableHoursPerMonth: (j['billableHoursPerMonth'] as num?)?.toDouble() ?? 80,
        marginPct: (j['marginPct'] as num?)?.toDouble() ?? 30,
        taxPct: (j['taxPct'] as num?)?.toDouble() ?? 5,
        taxIncluded: j['taxIncluded'] as bool? ?? true,
        roundTo: (j['roundTo'] as num?)?.toDouble() ?? 10,
        rows: [for (final r in (j['rows'] as List? ?? const [])) ServiceRow.fromJson(r as Map)],
      );

  static ServicePlan? decode(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return fromJson(jsonDecode(s) as Map);
    } catch (_) {
      return null;
    }
  }
}

class ServiceResult {
  final String name;
  final int minutes;
  final double labor, overhead, materials, cost; // 1 件あたり
  final double priceExTax; // 税抜の販売価格（丸め後）
  final double shownPrice; // お客様に見せる価格（税込設定なら税込）
  final double profit; // 税抜価格 − 原価
  final double marginPct; // 実際の利益率（税抜価格に対する %）
  final bool overridden;
  const ServiceResult(this.name, this.minutes, this.labor, this.overhead, this.materials, this.cost, this.priceExTax, this.shownPrice, this.profit, this.marginPct, this.overridden);
}

class ServiceSummary {
  final List<ServiceResult> rows;
  final double overheadPerHour;
  final double avgPricePerHourExTax;
  final double? breakEvenHours; // 固定費を回収するのに必要な 1 か月の接客時間。回収できない価格設定なら null
  final double monthlyProfitAtPlan; // 見込み時間いっぱい予約が入った場合の月の利益（固定費を引いた後）
  const ServiceSummary(this.rows, this.overheadPerHour, this.avgPricePerHourExTax, this.breakEvenHours, this.monthlyProfitAtPlan);
}

double roundUpTo(double v, double step) => step <= 0 ? v : (v / step).ceil() * step;

ServiceSummary computeServices(ServicePlan p) {
  final margin = p.marginPct.clamp(0, 90) / 100;
  final tax = max(0, p.taxPct) / 100;
  final overheadPerHour = p.billableHoursPerMonth > 0 ? p.fixedPerMonth / p.billableHoursPerMonth : 0.0;
  final out = <ServiceResult>[];
  for (final r in p.rows) {
    final hours = max(1, r.minutes) / 60;
    final labor = hours * p.laborPerHour;
    final overhead = hours * overheadPerHour;
    final cost = labor + overhead + r.materials;
    double shown, exTax;
    final over = r.priceOverride;
    if (over != null && over > 0) {
      shown = over;
      exTax = p.taxIncluded ? over / (1 + tax) : over;
    } else {
      final target = cost / (1 - margin);
      shown = roundUpTo(p.taxIncluded ? target * (1 + tax) : target, p.roundTo);
      exTax = p.taxIncluded ? shown / (1 + tax) : shown;
    }
    final profit = exTax - cost;
    out.add(ServiceResult(r.name, r.minutes, labor, overhead, r.materials, cost, exTax, shown, profit, exTax > 0 ? profit / exTax * 100 : 0, over != null && over > 0));
  }
  final totalHours = out.fold<double>(0, (a, r) => a + max(1, r.minutes) / 60);
  final totalEx = out.fold<double>(0, (a, r) => a + r.priceExTax);
  final avgPerHour = totalHours > 0 ? totalEx / totalHours : 0.0;
  final avgMaterialsPerHour = totalHours > 0 ? out.fold<double>(0, (a, r) => a + r.materials) / totalHours : 0.0;
  final contribution = avgPerHour - p.laborPerHour - avgMaterialsPerHour; // 1 時間接客するごとに固定費へ回せる金額
  final breakEven = contribution > 0 ? p.fixedPerMonth / contribution : null;
  final monthly = p.billableHoursPerMonth * contribution - p.fixedPerMonth;
  return ServiceSummary(out, overheadPerHour, avgPerHour, breakEven, monthly);
}

/// 通貨記号と桁区切り（ja / zh / en の表記は共通）
String formatMoney(double v, String currency) {
  const sym = {'TWD': 'NT\$', 'JPY': '¥', 'USD': '\$', 'EUR': '€', 'BRL': 'R\$', 'GBP': '£', 'CNY': 'CN¥', 'HKD': 'HK\$', 'KRW': '₩', 'SGD': 'S\$', 'AUD': 'A\$', 'CAD': 'C\$', 'MXN': 'MX\$', 'THB': '฿'};
  final noCents = currency == 'TWD' || currency == 'JPY' || currency == 'KRW'; // 小数のない通貨は常に整数で表示
  final whole = noCents || v == v.roundToDouble();
  final s = whole ? v.round().toString() : v.toStringAsFixed(2);
  final parts = s.split('.');
  final grouped = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '${sym[currency] ?? ''}$grouped${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// 通貨ごとの既定値：丸める単位、税率
const currencyDefaults = {
  'TWD': (roundTo: 10.0, tax: 5.0, included: true),
  'JPY': (roundTo: 100.0, tax: 10.0, included: true),
  'USD': (roundTo: 1.0, tax: 0.0, included: false),
  'EUR': (roundTo: 1.0, tax: 21.0, included: true),
  'BRL': (roundTo: 1.0, tax: 0.0, included: false),
  'GBP': (roundTo: 1.0, tax: 20.0, included: true),
  'CNY': (roundTo: 1.0, tax: 6.0, included: true),
  'HKD': (roundTo: 1.0, tax: 0.0, included: false),
  'KRW': (roundTo: 100.0, tax: 10.0, included: true),
  'SGD': (roundTo: 1.0, tax: 9.0, included: false),
  'AUD': (roundTo: 1.0, tax: 10.0, included: true),
  'CAD': (roundTo: 1.0, tax: 5.0, included: false),
  'MXN': (roundTo: 1.0, tax: 16.0, included: true),
  'THB': (roundTo: 1.0, tax: 7.0, included: true),
};

/// サイトの言語での「60分」の表記
const minutesLabels = {'en': '{n} min', 'ja': '{n}分', 'zh': '{n} 分鐘', 'pt': '{n} min', 'es': '{n} min'};

String minutesText(int n, String lang) => (minutesLabels[lang] ?? minutesLabels['en']!).replaceAll('{n}', '$n');

/// 例のサービス（言語を変えたとき）：行がまだどれかの言語の例のままなら、新しい言語の例に置き換える。使う人が書き換えた行は触らない
bool rowsAreUntouchedPresets(List<ServiceRow> rows) {
  if (rows.isEmpty) return true;
  for (final list in servicePresets.values) {
    for (final lang in ['en', 'ja', 'zh', 'pt', 'es']) {
      final names = [for (final p in list) p.name[lang] ?? p.name['en']!];
      if (rows.length == names.length && [for (final r in rows) r.name].join('|') == names.join('|') && rows.every((r) => r.materials == 0 && r.priceOverride == null)) return true;
    }
  }
  return false;
}

/// 業種ごとの最初のサービス案（時間だけ。金額は使う人が入れる）。名前は言語コード別。
const servicePresets = <String, List<({Map<String, String> name, int minutes})>>{
  'salon': [
    (name: {'en': 'Haircut', 'ja': 'カット', 'zh': '剪髮', 'pt': 'Corte', 'es': 'Corte'}, minutes: 60),
    (name: {'en': 'Colour', 'ja': 'カラー', 'zh': '染髮', 'pt': 'Coloração', 'es': 'Color'}, minutes: 120),
    (name: {'en': 'Treatment', 'ja': 'トリートメント', 'zh': '護髮', 'pt': 'Tratamento', 'es': 'Tratamiento'}, minutes: 45),
    (name: {'en': 'Perm', 'ja': 'パーマ', 'zh': '燙髮', 'pt': 'Permanente', 'es': 'Permanente'}, minutes: 150),
  ],
  'restaurant': [
    (name: {'en': 'Lunch set', 'ja': 'ランチセット', 'zh': '午間套餐', 'pt': 'Almoço executivo', 'es': 'Menú del día'}, minutes: 45),
    (name: {'en': 'Dinner course', 'ja': 'ディナーコース', 'zh': '晚間套餐', 'pt': 'Menu de jantar', 'es': 'Menú de cena'}, minutes: 90),
    (name: {'en': 'Group booking (per person)', 'ja': '団体予約（1名）', 'zh': '團體預約（每人）', 'pt': 'Grupo (por pessoa)', 'es': 'Grupo (por persona)'}, minutes: 120),
  ],
  'school': [
    (name: {'en': 'Trial lesson', 'ja': '体験レッスン', 'zh': '體驗課程', 'pt': 'Aula experimental', 'es': 'Clase de prueba'}, minutes: 45),
    (name: {'en': 'Private lesson', 'ja': '個人レッスン', 'zh': '個人課程', 'pt': 'Aula particular', 'es': 'Clase particular'}, minutes: 60),
    (name: {'en': 'Group lesson (per person)', 'ja': 'グループレッスン（1名）', 'zh': '團體課程（每人）', 'pt': 'Aula em grupo (por pessoa)', 'es': 'Clase en grupo (por persona)'}, minutes: 60),
  ],
  'space': [
    (name: {'en': 'Hourly rental', 'ja': '1時間利用', 'zh': '每小時租借', 'pt': 'Aluguel por hora', 'es': 'Alquiler por hora'}, minutes: 60),
    (name: {'en': 'Half day (4 hours)', 'ja': '半日（4時間）', 'zh': '半天（4 小時）', 'pt': 'Meio dia (4 horas)', 'es': 'Medio día (4 horas)'}, minutes: 240),
    (name: {'en': 'Full day (8 hours)', 'ja': '1日（8時間）', 'zh': '整天（8 小時）', 'pt': 'Dia inteiro (8 horas)', 'es': 'Día completo (8 horas)'}, minutes: 480),
  ],
  'clinic': [
    (name: {'en': 'First visit', 'ja': '初診', 'zh': '初診', 'pt': 'Primeira consulta', 'es': 'Primera visita'}, minutes: 30),
    (name: {'en': 'Return visit', 'ja': '再診', 'zh': '複診', 'pt': 'Retorno', 'es': 'Revisión'}, minutes: 15),
    (name: {'en': 'Health check', 'ja': '健康診断', 'zh': '健康檢查', 'pt': 'Check-up', 'es': 'Chequeo'}, minutes: 45),
  ],
  'other': [
    (name: {'en': 'Standard service', 'ja': '標準サービス', 'zh': '基本服務', 'pt': 'Serviço padrão', 'es': 'Servicio estándar'}, minutes: 60),
    (name: {'en': 'Premium service', 'ja': 'プレミアムサービス', 'zh': '進階服務', 'pt': 'Serviço premium', 'es': 'Servicio premium'}, minutes: 90),
  ],
};

List<ServiceRow> presetRows(String industry, String lang) => [
      for (final s in servicePresets[industry] ?? servicePresets['other']!) ServiceRow(s.name[lang] ?? s.name['en']!, s.minutes),
    ];
