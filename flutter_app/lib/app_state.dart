import 'dart:convert';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'estimator.dart';
import 'i18n/i18n.dart';
import 'pdf_export.dart';
import 'platform.dart';
import 'llm.dart';
import 'models.dart';

const _storeKey = 'selfquote.draft.v1';
const _introKey = 'selfquote.intro.v1';
const _langKey = 'selfquote.lang.v1';

String money(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}\$$b';
}

String fmtDate(DateTime d) =>
    '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';

String fmtNum(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

class AppState extends ChangeNotifier {
  Quote q = Quote();
  AiResult? ai;
  GpuInfo gpu = const GpuInfo(false, false, '');
  bool gpuChecked = false;
  bool busy = false;
  String busyLabel = '';
  double progress = 0;
  String? _progressText;
  String get progressText => _progressText ?? tr('prog.notLoaded');
  Lang get lang => I18n.lang;
  String modelBase = modelOptions[1].base;
  bool pdfBusy = false;
  String pdfStatus = '';

  /// 首頁介紹：首次進入必須閱讀並勾選了解，之後可由「使用說明」重新開啟
  bool ready = false; // 已讀完本機儲存，避免回訪者閃現介紹頁
  bool showIntro = true; // 每次開啟都先看到說明頁；曾同意過的人，勾選框會預先勾好，可直接繼續
  bool introAccepted = false;

  /// 即時 PDF 預覽（XeLaTeX）：只有切到 PDF 檢視時才編譯，避免白白下載 145 MB 引擎
  bool previewOn = false;
  bool previewBusy = false;
  bool previewStale = false;
  bool previewEverRendered = false;
  String previewStatus = '';
  String previewError = '';
  String _lastPreviewKey = '';
  bool _previewAgain = false;
  Timer? _previewTimer;
  SharedPreferences? _prefs;

  /// 目前可選的模型：WebGPU 可用時全部；否則只剩 CPU 版
  List<ModelOption> get availableModels =>
      !gpuChecked || gpu.ok ? modelOptions : [for (final m in modelOptions) if (m.isCpu) m];

  /// CPU 版（WebAssembly）模型：不需要 WebGPU
  bool get usingCpuModel => modelBase.startsWith('cpu:');

  /// 每次重設會換新的 ref，表單欄位以此為 key 重建
  String get formKey => q.ref;

  Estimate get estimate => ai?.est ?? ruleEstimate(q);
  Pricing get pricing => price(estimate, q);

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_storeKey);
      if (raw != null) q = Quote.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      introAccepted = _prefs!.getBool(_introKey) ?? false;
      I18n.lang = Lang.fromParam(queryLanguage()) ?? Lang.fromCode(_prefs!.getString(_langKey)) ?? Lang.detect(browserLanguage());
    } catch (_) {
      I18n.lang = Lang.fromParam(queryLanguage()) ?? Lang.detect(browserLanguage());
    }
    _applyLangToPage();
    ready = true;
    notifyListeners();
    try {
      gpu = await detectGPU();
    } catch (e) {
      gpu = GpuInfo(false, false, errText(e));
    }
    gpuChecked = true;
    if (gpu.ok) {
      final mobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
      modelBase = modelOptions[mobile ? 0 : 1].base;
    } else {
      // WebGPU 不可用或上限不足：預設改用 CPU 版（WebAssembly）本地模型
      modelBase = 'cpu:qwen2.5-0.5b';
    }
    notifyListeners();
  }

  void _save() {
    try {
      _prefs?.setString(_storeKey, jsonEncode(q.toJson()));
    } catch (_) {}
  }

  /// 任何需求變更：即時以規則引擎重算，並使 AI 結果失效
  void update(void Function(Quote q) fn, {bool invalidate = true}) {
    fn(q);
    if (invalidate && ai != null) {
      ai = null;
      _progressText = tr('prog.stale');
      progress = 0;
    }
    _save();
    notifyListeners();
    _schedulePreview();
  }

  void reset() {
    q = q.resetKeepingCompany();
    ai = null;
    _save();
    notifyListeners();
    _schedulePreview();
  }

  void useRules() {
    ai = null;
    notifyListeners();
    _schedulePreview();
  }

  /// 切換介面語言：AI 結果是用舊語言產生的，所以一併失效，其餘內容即時換語言
  void setLang(Lang l) {
    if (l == I18n.lang) return;
    I18n.lang = l;
    if (ai != null) {
      ai = null;
      _progressText = tr('prog.stale');
      progress = 0;
    }
    try {
      _prefs?.setString(_langKey, l.code);
    } catch (_) {}
    _applyLangToPage();
    notifyListeners();
    _schedulePreview(delay: const Duration(milliseconds: 300));
  }

  /// 同步 <html lang> 與分頁標題（輔助科技、搜尋引擎與瀏覽器分頁用）
  void _applyLangToPage() {
    try {
      applyPageLanguage(I18n.lang.code, '${tr('app.title')} · ${tr('app.tagline')}');
    } catch (_) {}
  }

  void openIntro() {
    showIntro = true;
    notifyListeners();
  }

  void startQuoting() {
    introAccepted = true;
    showIntro = false;
    try {
      _prefs?.setBool(_introKey, true);
    } catch (_) {}
    notifyListeners();
  }

  /* ---------- 即時 PDF 預覽 ---------- */

  void setPreviewOn(bool on) {
    if (previewOn == on) return;
    previewOn = on;
    if (on) {
      _schedulePreview(delay: const Duration(milliseconds: 150));
    } else {
      _previewTimer?.cancel();
      previewStale = false;
    }
    notifyListeners();
  }

  /// 立即重新編譯（忽略內容是否改變）
  void refreshPreview() {
    _lastPreviewKey = '';
    previewError = '';
    _schedulePreview(delay: Duration.zero);
  }

  void _schedulePreview({Duration delay = const Duration(milliseconds: 1200)}) {
    if (!previewOn) return;
    _previewTimer?.cancel();
    if (previewKey(this) != _lastPreviewKey) {
      previewStale = true;
      notifyListeners();
    }
    _previewTimer = Timer(delay, _runPreview);
  }

  Future<void> _runPreview() async {
    if (!previewOn) return;
    if (previewBusy) {
      _previewAgain = true; // 編譯中又有變更：完成後再編一次
      return;
    }
    final key = previewKey(this);
    if (key == _lastPreviewKey) {
      previewStale = false;
      notifyListeners();
      return;
    }
    previewBusy = true;
    previewStatus = tr('pv.preparing');
    notifyListeners();
    try {
      final err = await previewQuotePdf(this, (t) {
        previewStatus = t;
        notifyListeners();
      });
      if (err.isEmpty) {
        _lastPreviewKey = key;
        previewError = '';
        previewEverRendered = true;
        previewStale = _previewAgain;
      } else {
        previewError = err;
        previewStale = false;
      }
    } catch (e) {
      previewError = '$e';
      previewStale = false;
    } finally {
      previewBusy = false;
      notifyListeners();
    }
    if (_previewAgain) {
      _previewAgain = false;
      _schedulePreview(delay: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  void setModel(String base) {
    modelBase = base;
    notifyListeners();
  }

  /// 回傳給使用者的訊息（toast）
  Future<String> runEstimate() async {
    if (busy) return '';
    if (q.modules.isEmpty) return tr('msg.needModule');
    if (q.company.trim().isEmpty || q.contact.trim().isEmpty) return tr('msg.needClient');
    if (!gpu.ok && !usingCpuModel) {
      ai = null;
      notifyListeners();
      return tr('msg.noAI', {'reason': gpu.reasonText});
    }
    final id = modelId(modelBase, gpu.f16);
    void prog(double p, String t) {
      progress = p;
      _progressText = t;
      notifyListeners();
    }

    try {
      busy = true;
      busyLabel = tr('busy.loading');
      notifyListeners();
      await loadModel(id, prog);
      prog(1, tr('prog.loaded', {'id': id}));
      busyLabel = tr('busy.running');
      ai = await runAI(q, onToken: (n) => prog(1, tr('prog.tokens', {'n': '$n'})), onProgress: prog);
      prog(1, tr('prog.done', {'id': id}));
      _schedulePreview(delay: const Duration(milliseconds: 300));
      return tr('msg.aiDone');
    } catch (e) {
      debugPrint('AI error: $e');
      ai = null;
      prog(0, tr('prog.error', {'e': errText(e)}));
      return tr('msg.aiFail');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// 以瀏覽器端 XeLaTeX（ctex）產生 PDF；回傳給使用者的訊息
  Future<String> buildPdf() async {
    if (pdfBusy) return '';
    pdfBusy = true;
    pdfStatus = tr('pv.preparing');
    notifyListeners();
    try {
      final err = await compileQuotePdf(this, (t) {
        pdfStatus = t;
        notifyListeners();
      });
      if (err.isNotEmpty) {
        pdfStatus = tr('js.pdf_failed');
        debugPrint(err);
        return tr('msg.pdfFail', {'err': err.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => err)});
      }
      pdfStatus = tr('js.pdf_done');
      return tr('msg.pdfDone', {'ref': q.ref});
    } catch (e) {
      pdfStatus = tr('js.pdf_failed');
      return tr('msg.pdfFail', {'err': errText(e)});
    } finally {
      pdfBusy = false;
      notifyListeners();
    }
  }

  String summaryText() {
    final p = pricing, e = estimate;
    String dash(String v) => v.isEmpty ? '—' : v;
    return [
      tr('sum.title', {'ref': q.ref, 'mode': tr(ai != null ? 'sum.ai' : 'sum.rules')}),
      tr('sum.client', {'company': dash(q.company), 'contact': dash(q.contact), 'email': q.email}),
      tr('sum.project', {'project': dash(q.project), 'type': byId(projectTypes, q.type, 1).name, 'platforms': platformLabel()}),
      tr('sum.modules', {'list': e.all.isEmpty ? '—' : e.all.map((m) => m.name).join(Lang.list)}),
      tr('sum.net', {'lo': money(p.ht), 'hi': money(p.htHigh)}),
      tr('sum.gross', {'lo': money(p.ttc), 'hi': money(p.ttcHigh)}),
      tr('sum.hours', {'mm': '${p.mm}', 'h': '${e.totalHours.round()}', 'cx': tr('cx.${p.complexity}')}),
      tr('sum.schedule', {'a': '${p.monthsLow}', 'b': '${p.monthsHigh}'}),
      tr('sum.maint', {'lo': money(p.maintLow), 'hi': money(p.maintHigh)}),
      if (q.summary.isNotEmpty) tr('sum.desc', {'v': q.summary}),
      '',
      tr('sum.footer'),
    ].join('\n');
  }

  String platformLabel() {
    final s = platforms.where((p) => q.platforms.contains(p.id)).map((p) => p.name).join(Lang.list);
    return s.isEmpty ? tr('plat.web') : s;
  }

  String exportJson() {
    final p = pricing, e = estimate;
    return const JsonEncoder.withIndent('  ').convert({
      'quote': q.toJson()..remove('logo'),
      'pricing': {
        'mm': p.mm, 'rate': p.rate, 'complexity': p.complexity, 'buffer': p.buffer, 'ht': p.ht, 'vat': p.vat,
        'ttc': p.ttc, 'htHigh': p.htHigh, 'ttcHigh': p.ttcHigh, 'team': p.team, 'monthsLow': p.monthsLow,
        'monthsHigh': p.monthsHigh, 'maintLow': p.maintLow, 'maintHigh': p.maintHigh,
      },
      'estimate': {
        'totalHours': e.totalHours, 'infra': e.infra, 'phases': e.phases.toJson(),
        'modules': e.all.map((m) => m.toJson()).toList(),
      },
      if (ai != null) 'ai': {'assumptions': ai!.assumptions, 'risks': ai!.risks},
    });
  }
}
