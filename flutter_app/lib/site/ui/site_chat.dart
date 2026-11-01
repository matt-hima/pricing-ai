import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../engine_admin.dart';
import '../../i18n/i18n.dart';
import '../bridge/editor_bridge.dart';
import '../chat_results.dart';
import '../google_form.dart';
import '../google_form_loader.dart';
import '../site_actions.dart';
import '../site_ai.dart';
import '../site_industry.dart';
import '../site_init.dart';
import '../site_planner.dart';
import '../site_regen.dart';

class _Res {
  final bool ok;
  final String text;
  const _Res(this.ok, this.text);
}

class _Msg {
  final bool user;
  final String text;
  final List<_Res> results;
  bool canUndo;
  _Msg(this.user, this.text, {this.results = const [], this.canUndo = false});
}

/// 和本機 AI 聊天來設定網站：「把價格調低 10%」「主色改成粉紅」「週一公休」…
/// 模型回覆 JSON（說明 + 要修改的欄位），這裡整理後交給編輯器套用，每次修改都可以復原。
class SiteChatPanel extends StatefulWidget {
  /// 目前對話裡累計的訊息數（只給整合測試等待「訊息送出並得到回覆」用，避免用畫面上的元件數量判斷）
  @visibleForTesting
  static final messageCount = ValueNotifier<int>(0);

  final AppState app;
  final EditorBridge bridge;
  final String siteLang; // 網站語言代碼：en / zh / ja / pt / es
  final bool ready;

  /// false = 新網站：第一則訊息用來描述店家，模型據此產生整頁文字
  final bool initialized;
  final void Function(String? brand) onInitialized;
  final VoidCallback onSkipInit;

  /// 應用程式端的動作（網站設定）由外層執行
  final void Function(String name) onSiteName;
  final void Function(String email) onBookingEmail;
  final void Function(String viewUrl) onGoogleForm;
  const SiteChatPanel({
    super.key,
    required this.app,
    required this.bridge,
    required this.siteLang,
    required this.ready,
    required this.initialized,
    required this.onInitialized,
    required this.onSkipInit,
    required this.onSiteName,
    required this.onBookingEmail,
    required this.onGoogleForm,
  });

  @override
  State<SiteChatPanel> createState() => _SiteChatPanelState();
}

class _SiteChatPanelState extends State<SiteChatPanel> {
  late final _msgs = <_Msg>[
    _Msg(
      false,
      widget.initialized ? tr('chat.hello.edit') : tr('chat.hello.init'),
    ),
  ];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  List<ActionSpec>? _catalog; // 編輯器提供的動作目錄（第一次送訊息時取得）

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _add(_Msg m) {
    setState(() => _msgs.add(m));
    SiteChatPanel.messageCount.value++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy || !widget.ready) return;
    _input.clear();
    final history = [for (final m in _msgs.skip(1)) ChatTurn(m.user, m.text)];
    _add(_Msg(true, text));
    setState(() => _busy = true);
    try {
      if (!widget.initialized) {
        await _initFromChat(text);
        return;
      }
      final raw = await widget.bridge.call<Map>('snapshot');
      final snapshot = Map<String, dynamic>.from(raw ?? const {});
      if (!snapshot.containsKey('brand')) {
        _add(_Msg(false, tr('chat.oldPage')));
        return;
      }
      _catalog ??= parseCatalog(await widget.bridge.call<List>('catalog') ?? const []);
      final lang = Lang.fromCode(widget.siteLang == 'zh' ? 'zh-TW' : widget.siteLang) ?? Lang.en;
      // 同一次忙碌裡連問三小步：選動作 → 填實體 → （執行後）回覆
      final plan = await widget.app.withModel(
        (ask) => planChat(
          ask: (system, user, schema) => ask(system, user, schema: schema),
          editorActions: _catalog!,
          snapshot: snapshot,
          history: history,
          message: text,
          siteLang: lang,
        ),
      );
      final results = <_Res>[];
      var undoable = false;
      final editorActions = [for (final a in plan.actions) if (!isAppAction('${a['action']}')) a];
      if (editorActions.isNotEmpty) {
        final r = await widget.bridge.call<Map>('runActions', [editorActions]);
        for (final l in localizedRows(editorActions, r?['results'] as List? ?? const [])) {
          results.add(_Res(l.ok, l.text));
        }
        undoable = r?['undoable'] == true;
      }
      for (final a in plan.actions.where((a) => isAppAction('${a['action']}'))) {
        final err = validateAppAction(a);
        if (err != null) {
          results.add(_Res(false, tr('chat.r.fail', {'reason': '${a['action']}: $err'})));
          continue;
        }
        if (a['action'] == 'connect_google_form') {
          try {
            final f = await loadGoogleForm('${a['url']}');
            final r = await widget.bridge.call<Map>('runActions', [
              [
                {'action': 'set_google_form', 'config': f.config}
              ]
            ]);
            final ok = ((r?['results'] as List?)?.firstOrNull as Map?)?['ok'] == true;
            if (ok) widget.onGoogleForm('https://docs.google.com/forms/d/e/${RegExp(r'/e/([\w-]+)/').firstMatch(f.action)![1]}/viewform');
            results.add(_Res(ok, ok ? '${localizedResult(a, true, '')}: ${tr('gf.found', {'n': '${f.fields.length}', 'r': '${f.requiredCount}'})}' : tr('chat.r.fail', {'reason': 'google form'})));
            undoable = undoable || r?['undoable'] == true;
          } catch (e) {
            results.add(_Res(false, tr('chat.r.fail', {'reason': tr(googleFormErrorKey(e), {'d': e is GoogleFormException ? e.detail : ''})})));
          }
          continue;
        }
        if (a['action'] == 'generate_image') {
          try {
            final bytes = await widget.app.withBusy(tr('img.busy'), (prog) => generateImage('${a['prompt']}'.trim(), prog));
            final r = await widget.bridge.call<Map>('runActions', [
              [
                {'action': 'set_hero_image', 'url': 'data:image/jpeg;base64,${base64Encode(bytes)}'}
              ]
            ]);
            final ok = ((r?['results'] as List?)?.firstOrNull as Map?)?['ok'] == true;
            results.add(_Res(ok, ok ? localizedResult(a, true, '') : tr('chat.r.fail', {'reason': 'generate_image'})));
            undoable = undoable || r?['undoable'] == true;
          } catch (e) {
            results.add(_Res(false, tr('chat.r.fail', {'reason': e.toString().replaceFirst('Bad state: ', '').replaceFirst('Unsupported operation: ', '')})));
          }
          continue;
        }
        if (a['action'] == 'regenerate') {
          final part = '${a['part']}';
          final gen = await widget.app.withModel(
            (ask) => regenerateActions(
              ask: (system, user, schema) => ask(system, user, schema: schema),
              siteLang: lang,
              snapshot: snapshot,
              part: part,
              hint: '${a['hint'] ?? ''}'.trim(),
            ),
          );
          if (gen.isEmpty) {
            results.add(_Res(false, tr('chat.r.fail', {'reason': tr('chat.part.$part')})));
            continue;
          }
          final r = await widget.bridge.call<Map>('runActions', [gen]);
          final rows = r?['results'] as List? ?? const [];
          final failed = rows.any((x) => x is Map && x['ok'] != true);
          results.add(_Res(!failed, failed ? tr('chat.r.fail', {'reason': tr('chat.part.$part')}) : localizedResult(a, true, '')));
          undoable = undoable || r?['undoable'] == true;
          continue;
        }
        if (a['action'] == 'set_site_name') {
          widget.onSiteName('${a['name']}'.trim());
        } else {
          widget.onBookingEmail('${a['email']}'.trim());
        }
        results.add(_Res(true, localizedResult(a, true, '')));
      }
      for (final n in plan.notes) {
        results.add(_Res(false, n));
      }
      // 回覆由程式依結果決定（不讓模型寫：它會把沒做的事說成做了、也常用錯語言）
      final reply = results.isEmpty ? tr('chat.nothing') : (results.any((r) => !r.ok) ? tr('chat.someFailed') : tr('chat.done'));
      if (undoable) {
        for (final m in _msgs) {
          m.canUndo = false; // 只有最新一批可以復原
        }
      }
      _add(_Msg(false, reply, results: results, canUndo: undoable));
    } catch (e) {
      _add(_Msg(false, tr('chat.sorry', {'e': e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '')})));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 新網站的第一則訊息：依描述產生整頁文字，套用到範本，再依設計小抄檢查一次
  Future<void> _initFromChat(String text) async {
    final lang = Lang.fromCode(widget.siteLang == 'zh' ? 'zh-TW' : widget.siteLang) ?? Lang.en;
    final content = await widget.app.withModel(
      (ask) => generateSiteContent(ask: (system, user, schema) => ask(system, user, schema: schema), siteLang: lang, description: text),
    );
    if (content == null) {
      _add(_Msg(false, tr('chat.noPage')));
      return;
    }
    await widget.bridge.call('applyContent', [widget.siteLang, content]);
    final brand = '${content['brand'] ?? ''}';
    widget.onInitialized(brand);
    // 依業種加上該業種的預約問題（例如餐廳的人數、診所的初診 / 再診），最後依設計小抄檢查一次
    final industry = '${content['industry'] ?? 'other'}';
    final initActions = <Map<String, Object?>>[
      ...industryFieldActions(industry, widget.siteLang),
      {'action': 'check_quality'},
    ];
    final r = await widget.bridge.call<Map>('runActions', [initActions]);
    final results = [for (final l in localizedRows(initActions, r?['results'] as List? ?? const [])) _Res(l.ok, l.text)];
    final services = (content['svc'] as List?)?.length ?? 0;
    final prices = (content['price'] as List?)?.length ?? 0;
    final head = brand.isEmpty ? tr('chat.ready.headNoBrand') : tr('chat.ready.head', {'brand': brand});
    final body = industry == 'other'
        ? tr('chat.ready.body', {'services': '$services', 'prices': '$prices'})
        : tr('chat.ready.bodyIndustry', {'services': '$services', 'prices': '$prices', 'industry': tr('chat.industry.$industry')});
    _add(_Msg(
      false,
      '$head $body\n\n${tr('chat.ready.next')}',
      results: results,
    ));
  }

  Future<void> _undo(_Msg m) async {
    final ok = await widget.bridge.call<bool>('undo');
    setState(() => m.canUndo = false);
    if (ok == true) _add(_Msg(false, tr('chat.undone')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      child: Column(children: [
        Container(
          width: double.infinity,
          color: cs.surfaceContainerHigh,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(children: [
            const Icon(Icons.auto_awesome, size: 18),
            const SizedBox(width: 8),
            Text(tr('chat.title'), style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            itemCount: _msgs.length,
            itemBuilder: (_, i) {
              final m = _msgs[i];
              return Align(
                alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(maxWidth: 290),
                  decoration: BoxDecoration(
                    color: m.user ? cs.primaryContainer : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SelectableText(m.text, style: const TextStyle(fontSize: 13.5)),
                    if (m.results.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      for (final r in m.results)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(r.ok ? Icons.check_circle : Icons.error_outline, size: 14, color: r.ok ? Colors.teal : cs.error),
                            const SizedBox(width: 5),
                            Expanded(child: Text(r.text, style: TextStyle(fontSize: 11.5, color: r.ok ? cs.onSurfaceVariant : cs.error))),
                          ]),
                        ),
                    ],
                    if (m.canUndo) TextButton.icon(onPressed: () => _undo(m), icon: const Icon(Icons.undo, size: 16), label: Text(tr('chat.undo'))),
                  ]),
                ),
              );
            },
          ),
        ),
        if (_busy)
          ListenableBuilder(
            listenable: widget.app,
            builder: (_, __) => Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LinearProgressIndicator(value: widget.app.progress > 0 && widget.app.progress < 1 ? widget.app.progress : null, minHeight: 3),
                const SizedBox(height: 4),
                Text(widget.app.progressText, style: Theme.of(context).textTheme.labelSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),
        if (!widget.initialized)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: TextButton(onPressed: _busy ? null : widget.onSkipInit, child: Text(tr('chat.skipInit'))),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                enabled: widget.ready && !_busy,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(hintText: widget.initialized ? tr('chat.hint.edit') : tr('chat.hint.init')),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: widget.ready && !_busy ? _send : null, icon: const Icon(Icons.send)),
          ]),
        ),
      ]),
    );
  }
}
