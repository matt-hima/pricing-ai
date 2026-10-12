import 'dart:math';

import 'config.dart';
import 'i18n/i18n.dart';
import 'models.dart';

double r1(num n) => (n * 10).round() / 10;

T byId<T extends Option>(List<T> list, String id, int fallback) =>
    list.firstWhere((o) => o.id == id, orElse: () => list[fallback]);

/// 前端倍率：依平台組合計算
double frontendFactor(Set<String> ps, String appTech) {
  final apps = ['ios', 'android'].where(ps.contains).length;
  var f = ps.contains('web') ? 1.0 : 0.0;
  if (apps == 1) f += 1.1;
  if (apps == 2) f += appTech == 'native' ? 2.0 : 1.35;
  return f == 0 ? 1 : f;
}

/// 從白話描述推估複雜度加成
double textComplexity(String text) {
  if (text.trim().isEmpty) return 1;
  final lower = text.toLowerCase();
  final hits = complexKeywords.where((k) => lower.contains(k.toLowerCase())).length;
  var bonus = min(0.4, hits * 0.08);
  if (text.length > 60) bonus += 0.05;
  return 1 + bonus;
}

/// 規則引擎：AI 評估的基準，也是不支援 WebGPU 時的備援
Estimate ruleEstimate(Quote q) {
  final type = byId(projectTypes, q.type, 1);
  final feF = frontendFactor(q.platforms, q.appTech);
  final mods = <ModuleEst>[];
  for (final def in modules) {
    if (!q.modules.containsKey(def.id)) continue;
    final note = q.modules[def.id]!;
    final k = textComplexity(note) * type.factor;
    final fe = r1(def.fe * feF * k), be = r1(def.be * k);
    mods.add(ModuleEst(id: def.id, name: def.name, desc: def.desc, note: note, fe: fe, be: be, tasks: [
      if (fe > 0) Task(tr('task.fe', {'name': def.name}), 'fe', fe),
      if (be > 0) Task(tr('task.be', {'name': def.name}), 'be', be),
    ]));
  }
  return buildPhases(mods, q);
}

/// 依模組工時推算設計、PM、測試部署等階段
Estimate buildPhases(List<ModuleEst> mods, Quote q, {List<ModuleEst> extras = const [], String? complexity}) {
  final all = [...mods, ...extras];
  final fe = all.fold(0.0, (s, m) => s + m.fe);
  final be = all.fold(0.0, (s, m) => s + m.be);
  final dev = fe + be;
  final design = byId(designLevels, q.design, 1);
  final infra = dev > 0 ? 24.0 + (q.hasApp ? 24 : 0) : 0.0; // 架構建置、CI/CD、上架作業
  final phases = dev == 0
      ? const Phases(0, 0, 0, 0, 0, 0)
      : Phases(
          r1(max(24, dev * 0.08)),
          r1((24 + fe * 0.18) * design.factor),
          r1(fe),
          r1(be + infra),
          r1(dev * 0.18 + (q.hasApp ? 16 : 0)),
          r1(dev * 0.08),
        );
  return Estimate(mods, extras, phases, infra, complexity);
}

String complexityOf(double mm) => mm < 3 ? 'low' : (mm < 8 ? 'medium' : 'high');

/// 把 AI 回傳的複雜度（任何語言）正規化為 low / medium / high；無法判斷回傳 null
String? normalizeComplexity(Object? v) {
  final s = '$v'.toLowerCase();
  if (RegExp(r'high|alt[ao]|高').hasMatch(s)) return 'high';
  if (RegExp(r'med|méd|中').hasMatch(s)) return 'medium';
  if (RegExp(r'low|baj[ao]|baix[ao]|低').hasMatch(s)) return 'low';
  return null;
}

/// 報價單明細列（Dolibarr 報價單列：說明 / 數量(人月) / 單價）
List<({String? group, String name, String sub, double hours, bool ai})> _rawLines(Estimate e) {
  if (e.totalHours == 0) return [];
  final p = e.phases;
  return [
    (group: tr('line.group.plan'), name: '', sub: '', hours: 0, ai: false),
    (group: null, name: tr('line.analysis.n'), sub: tr('line.analysis.s'), hours: p.analysis, ai: false),
    (group: null, name: tr('line.design.n'), sub: tr('line.design.s'), hours: p.design, ai: false),
    (group: tr('line.group.dev'), name: '', sub: '', hours: 0, ai: false),
    for (final m in e.all)
      (group: null, name: m.name, sub: m.tasks.map((t) => t.name).join(Lang.list), hours: r1(m.hours), ai: m.ai),
    (group: null, name: tr('line.infra.n'), sub: tr('line.infra.s'), hours: e.infra, ai: false),
    (group: tr('line.group.test'), name: '', sub: '', hours: 0, ai: false),
    (group: null, name: tr('line.qa.n'), sub: tr('line.qa.s'), hours: p.qa, ai: false),
    (group: null, name: tr('line.pm.n'), sub: tr('line.pm.s'), hours: p.pm, ai: false),
  ];
}

/// 金額計算：只在程式端計算，絕不採用 LLM 給的金額
Pricing price(Estimate e, Quote q) {
  final hpm = q.hoursPerMM <= 0 ? 176.0 : q.hoursPerMM;
  final mm = e.totalHours / hpm;
  final complexity = e.complexity ?? complexityOf(mm);
  final buffer = riskBuffer[complexity]!;
  final rate = (q.rate * (urgencyFactor[q.urgency] ?? 1)).round();
  final vatRate = q.vatPct / 100;

  // 數量以 2 位小數人月計，小計 = 數量 × 單價，確保報價單可逐列驗算
  final lines = _rawLines(e).map((l) {
    if (l.group != null) return Line.group(l.group!);
    final qty = (l.hours / hpm * 100).round() / 100;
    return Line(l.name, l.sub, l.hours, qty, (qty * rate).round(), ai: l.ai);
  }).toList();
  final ht = lines.fold(0, (s, l) => s + l.subtotal);
  final vat = (ht * vatRate).round();
  final htHigh = (ht * buffer).round();

  final team = mm <= 3 ? 2 : (mm <= 8 ? 3 : (mm <= 16 ? 4 : 5));
  final rushK = q.urgency == 'rush' ? 0.8 : (q.urgency == 'flex' ? 1.2 : 1.0);
  final monthsLow = r1((mm / team * rushK).clamp(0.5, 99));
  final maintMax = max(q.maintMinPct, q.maintMaxPct);

  return Pricing(
    lines: lines,
    mm: r1(mm),
    rate: rate,
    complexity: complexity,
    buffer: buffer,
    ht: ht,
    vat: vat,
    ttc: ht + vat,
    htHigh: htHigh,
    ttcHigh: (htHigh * (1 + vatRate)).round(),
    team: team,
    monthsLow: monthsLow,
    monthsHigh: r1(monthsLow * buffer),
    maintLow: (ht * q.maintMinPct / 100).round(),
    maintHigh: (htHigh * maintMax / 100).round(),
  );
}

/* ---------- 合併 AI 結果（程式端防護） ---------- */

double _sum(List<Task> ts) => ts.fold(0.0, (s, t) => s + t.hours);

List<Task> _cleanTasks(Object? raw, [String prefix = '']) {
  if (raw is! List) return [];
  final out = <Task>[];
  for (final t in raw.take(5)) {
    if (t is! Map) continue;
    var name = (t['name'] ?? '').toString().trim();
    // 小模型常輸出「會員系統 - 登入」，去掉重複的模組名稱前綴
    if (prefix.isNotEmpty && name.startsWith(prefix)) {
      final stripped = name.substring(prefix.length).replaceFirst(RegExp(r'^[\s\-–—:：、]+'), '');
      if (stripped.isNotEmpty) name = stripped;
    }
    final hours = t['hours'] is num ? (t['hours'] as num).toDouble() : double.tryParse('${t['hours']}');
    if (name.isEmpty || hours == null || !hours.isFinite || hours <= 0) continue;
    out.add(Task(name.length > 40 ? name.substring(0, 40) : name, t['kind'] == 'be' ? 'be' : 'fe', hours));
  }
  return out;
}

List<Task> _scale(List<Task> ts, double target) {
  final k = target / (_sum(ts) == 0 ? 1 : _sum(ts));
  return ts.map((t) => Task(t.name, t.kind, r1(t.hours * k))).toList();
}

ModuleEst _fromTasks(ModuleEst base, List<Task> ts) {
  final fe = r1(_sum(ts.where((t) => t.kind == 'fe').toList()));
  final be = r1(_sum(ts.where((t) => t.kind == 'be').toList()));
  return ModuleEst(id: base.id, name: base.name, desc: base.desc, note: base.note, fe: fe, be: be, tasks: ts, ai: true);
}

List<String> get defaultAssumptions => [tr('assume.1'), tr('assume.2'), tr('assume.3')];
List<String> get defaultRisks => [tr('risk.1'), tr('risk.2'), tr('risk.3')];

AiResult mergeAI(Estimate baseline, Map<String, dynamic> ai, Quote q) {
  final aiMods = ai['modules'] is List ? ai['modules'] as List : const [];
  final mods = baseline.modules.map((m) {
    final hit = aiMods.whereType<Map>().where((x) => x['id'] == m.id).firstOrNull;
    final ts = _cleanTasks(hit?['tasks'], m.name);
    if (ts.isEmpty) return m;
    // 工時限制在基準的 0.7–1.8 倍，避免 AI 幻覺造成離譜報價
    final target = _sum(ts).clamp(m.hours * 0.7, m.hours * 1.8);
    // 小模型常把前端工作標成 be：前後端比例沿用規則引擎，AI 只決定總工時與子項目
    final fe = r1(target * (m.hours == 0 ? 0 : m.fe / m.hours));
    return ModuleEst(
        id: m.id, name: m.name, desc: m.desc, note: m.note, fe: fe, be: r1(target - fe), tasks: _scale(ts, target), ai: true);
  }).toList();

  final extras = <ModuleEst>[];
  for (final x in (ai['extras'] is List ? ai['extras'] as List : const []).whereType<Map>().take(3)) {
    var ts = _cleanTasks(x['tasks']);
    final name = (x['name'] ?? '').toString().trim();
    if (ts.isEmpty || name.isEmpty) continue;
    if (_sum(ts) > 120) ts = _scale(ts, 120);
    final base = ModuleEst(id: 'x', name: name.length > 30 ? name.substring(0, 30) : name, fe: 0, be: 0, tasks: ts);
    extras.add(_fromTasks(base, ts));
  }

  // 複雜度取「計算值」與「AI 判斷」較高者，偏保守
  final pre = buildPhases(mods, q, extras: extras);
  const order = ['low', 'medium', 'high'];
  final calc = complexityOf(pre.totalHours / q.hoursPerMM);
  final aiC = order.indexOf(normalizeComplexity(ai['complexity']) ?? calc);
  final complexity = order[max(order.indexOf(calc), aiC)];
  final est = buildPhases(mods, q, extras: extras, complexity: complexity);

  List<String> strs(Object? a) =>
      a is List ? a.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).take(6).toList() : [];
  final assumptions = strs(ai['assumptions']), risks = strs(ai['risks']);
  return AiResult(
    est,
    assumptions.isEmpty ? defaultAssumptions : assumptions,
    risks.isEmpty ? defaultRisks : risks,
  );
}
