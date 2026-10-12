import 'dart:math';

/// 報價單草稿：所有欄位皆由使用者填寫，存於瀏覽器（shared_preferences）。
class Quote {
  // 我的公司（Dolibarr：設定 › 公司/組織）
  String myName = '', myTaxId = '', myAddress = '', myPhone = '', myEmail = '';
  String logo = ''; // data URL

  // 計價參數
  double rate = 120000, hoursPerMM = 176, vatPct = 5, warrantyMonths = 3, maintMinPct = 15, maintMaxPct = 20;

  // 報價卡片
  String ref = newRef();
  String company = '', taxId = '', contact = '', email = '', phone = '', refClient = '', project = '';
  DateTime date = DateTime.now();
  int validityDays = 30;
  String payTerm = '3-4-3', payMode = 'transfer', urgency = 'normal', budget = 'undecided', source = 'website';

  // 規格
  String type = 'app';
  Set<String> platforms = {'web'};
  String appTech = 'cross', design = 'custom';
  Map<String, String> modules = {'member': '', 'admin': ''}; // 模組 id → 白話描述

  // 備註
  String summary = '', extra = '', refSite = '';

  static String newRef() {
    final d = DateTime.now();
    final yymm = '${d.year % 100}'.padLeft(2, '0') + '${d.month}'.padLeft(2, '0');
    return '$refPrefix$yymm-${1000 + Random().nextInt(9000)}';
  }

  static const refPrefix = 'PR';

  bool get hasApp => platforms.contains('ios') || platforms.contains('android');

  Map<String, dynamic> toJson() => {
        'myName': myName, 'myTaxId': myTaxId, 'myAddress': myAddress, 'myPhone': myPhone, 'myEmail': myEmail, 'logo': logo,
        'rate': rate, 'hoursPerMM': hoursPerMM, 'vatPct': vatPct, 'warrantyMonths': warrantyMonths,
        'maintMinPct': maintMinPct, 'maintMaxPct': maintMaxPct,
        'ref': ref, 'company': company, 'taxId': taxId, 'contact': contact, 'email': email, 'phone': phone,
        'refClient': refClient, 'project': project, 'date': date.toIso8601String(), 'validityDays': validityDays,
        'payTerm': payTerm, 'payMode': payMode, 'urgency': urgency, 'budget': budget, 'source': source,
        'type': type, 'platforms': platforms.toList(), 'appTech': appTech, 'design': design, 'modules': modules,
        'summary': summary, 'extra': extra, 'refSite': refSite,
      };

  static Quote fromJson(Map<String, dynamic> j) {
    final q = Quote();
    String s(String k, String d) => j[k] is String ? j[k] as String : d;
    double n(String k, double d) => j[k] is num ? (j[k] as num).toDouble() : d;
    q
      ..myName = s('myName', '')
      ..myTaxId = s('myTaxId', '')
      ..myAddress = s('myAddress', '')
      ..myPhone = s('myPhone', '')
      ..myEmail = s('myEmail', '')
      ..logo = s('logo', '')
      ..rate = n('rate', q.rate)
      ..hoursPerMM = n('hoursPerMM', q.hoursPerMM)
      ..vatPct = n('vatPct', q.vatPct)
      ..warrantyMonths = n('warrantyMonths', q.warrantyMonths)
      ..maintMinPct = n('maintMinPct', q.maintMinPct)
      ..maintMaxPct = n('maintMaxPct', q.maintMaxPct)
      ..ref = s('ref', q.ref)
      ..company = s('company', '')
      ..taxId = s('taxId', '')
      ..contact = s('contact', '')
      ..email = s('email', '')
      ..phone = s('phone', '')
      ..refClient = s('refClient', '')
      ..project = s('project', '')
      ..date = DateTime.tryParse(s('date', '')) ?? DateTime.now()
      ..validityDays = n('validityDays', 30).round()
      ..payTerm = s('payTerm', q.payTerm)
      ..payMode = s('payMode', q.payMode)
      ..urgency = s('urgency', q.urgency)
      ..budget = s('budget', q.budget)
      ..source = s('source', q.source)
      ..type = s('type', q.type)
      ..platforms = (j['platforms'] is List) ? (j['platforms'] as List).whereType<String>().toSet() : q.platforms
      ..appTech = s('appTech', q.appTech)
      ..design = s('design', q.design)
      ..modules = (j['modules'] is Map)
          ? (j['modules'] as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
          : q.modules
      ..summary = s('summary', '')
      ..extra = s('extra', '')
      ..refSite = s('refSite', '');
    return q;
  }

  /// 重設報價內容，保留「我的公司」與計價參數
  Quote resetKeepingCompany() {
    final q = Quote();
    q
      ..myName = myName
      ..myTaxId = myTaxId
      ..myAddress = myAddress
      ..myPhone = myPhone
      ..myEmail = myEmail
      ..logo = logo
      ..rate = rate
      ..hoursPerMM = hoursPerMM
      ..vatPct = vatPct
      ..warrantyMonths = warrantyMonths
      ..maintMinPct = maintMinPct
      ..maintMaxPct = maintMaxPct;
    return q;
  }
}

class Task {
  final String name;
  final String kind; // fe | be
  final double hours;
  const Task(this.name, this.kind, this.hours);
  Map<String, dynamic> toJson() => {'name': name, 'kind': kind, 'hours': hours};
}

class ModuleEst {
  final String id, name, desc, note;
  final double fe, be;
  final List<Task> tasks;
  final bool ai;
  const ModuleEst({
    required this.id,
    required this.name,
    this.desc = '',
    this.note = '',
    required this.fe,
    required this.be,
    required this.tasks,
    this.ai = false,
  });
  double get hours => fe + be;
  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'fe': fe, 'be': be, 'ai': ai, 'tasks': tasks.map((t) => t.toJson()).toList()};
}

class Phases {
  final double analysis, design, frontend, backend, qa, pm;
  const Phases(this.analysis, this.design, this.frontend, this.backend, this.qa, this.pm);
  double get total => analysis + design + frontend + backend + qa + pm;
  Map<String, dynamic> toJson() =>
      {'analysis': analysis, 'design': design, 'frontend': frontend, 'backend': backend, 'qa': qa, 'pm': pm};
}

class Estimate {
  final List<ModuleEst> modules, extras;
  final Phases phases;
  final double infra;
  final String? complexity; // AI 判斷（已與計算值取較高者）
  const Estimate(this.modules, this.extras, this.phases, this.infra, [this.complexity]);
  double get totalHours => phases.total;
  List<ModuleEst> get all => [...modules, ...extras];
}

class Line {
  final String? group;
  final String name, sub;
  final double hours, qty;
  final int subtotal;
  final bool ai;
  const Line.group(String g)
      : group = g,
        name = '',
        sub = '',
        hours = 0,
        qty = 0,
        subtotal = 0,
        ai = false;
  const Line(this.name, this.sub, this.hours, this.qty, this.subtotal, {this.ai = false}) : group = null;
}

class Pricing {
  final List<Line> lines;
  final double mm, buffer, monthsLow, monthsHigh;
  final int rate, ht, vat, ttc, htHigh, ttcHigh, team, maintLow, maintHigh;
  final String complexity;
  const Pricing({
    required this.lines,
    required this.mm,
    required this.rate,
    required this.complexity,
    required this.buffer,
    required this.ht,
    required this.vat,
    required this.ttc,
    required this.htHigh,
    required this.ttcHigh,
    required this.team,
    required this.monthsLow,
    required this.monthsHigh,
    required this.maintLow,
    required this.maintHigh,
  });
}

class AiResult {
  final Estimate est;
  final List<String> assumptions, risks;
  const AiResult(this.est, this.assumptions, this.risks);
}
