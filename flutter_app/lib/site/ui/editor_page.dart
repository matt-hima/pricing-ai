import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../i18n/i18n.dart';
import '../../llm.dart';
import '../../ui/get_app.dart';
import '../bridge/editor_bridge.dart';
import '../site_model.dart';
import '../platform/deploy.dart';
import '../platform/save_file.dart';
import '../platform/zip_export.dart';
import '../site_ai.dart';
import '../site_industry.dart';
import '../site_init.dart';
import '../site_link.dart';
import '../site_store.dart';
import 'deploy_dialog.dart';
import 'google_form_dialog.dart';
import '../google_form.dart';
import 'popup_observer.dart';
import 'site_chat.dart';

class EditorPage extends StatefulWidget {
  final Store store;
  final PopupObserver popups;
  final AppState app;
  final SiteLink link;
  const EditorPage({super.key, required this.store, required this.popups, required this.app, required this.link});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  Store get store => widget.store;
  final bridge = EditorBridge();
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool ready = false;
  bool chatOpen = false;
  Timer? _hello;
  DateTime? _loadStarted;

  void _onPopups() => bridge.setInteractive(widget.popups.open.value == 0);

  @override
  void initState() {
    super.initState();
    chatOpen = !store.current.initialized; // 新網站從聊天開始
    widget.popups.open.addListener(_onPopups);
    widget.link.addListener(_applyPending);
    _sub = bridge.events.listen((e) async {
      switch (e['type']) {
        case 'ready':
          _loadStarted = DateTime.now();
          try {
            await _loadCurrent();
            if (mounted) setState(() => ready = true);
            unawaited(_applyPending());
          } catch (err) {
            // 載入失敗（例如編輯器頁重新整理）：保持等待，下一次握手會重試
            if (mounted) _snack('Editor is not ready yet, retrying…');
          }
        case 'changed':
          final p = (e['payload'] as Map?)?['project'];
          if (p is String) {
            store.current.project = p;
            store.changed(notify: false);
          }
      }
    });
    // 握手保險：編輯器頁的 ready 訊息若在 Flutter 端準備好之前送出就會遺失，
    // 所以還沒就緒時定期喊一聲 hello，編輯器會重新回報 ready
    _hello = Timer.periodic(const Duration(seconds: 1), (_) {
      if (ready) return;
      final started = _loadStarted;
      if (started != null && DateTime.now().difference(started) < const Duration(seconds: 8)) return;
      bridge.send(-1, 'hello', const []);
    });
  }

  @override
  void dispose() {
    widget.popups.open.removeListener(_onPopups);
    widget.link.removeListener(_applyPending);
    _hello?.cancel();
    _sub?.cancel();
    bridge.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _loadCurrent() async {
    final s = store.current;
    await bridge.call('load', [s.project.isEmpty ? null : s.project, s.lang]);
  }

  /// 切換 / 新增 / 刪除網站之前，先把編輯器裡尚未回報的內容存回目前的網站
  Future<void> _flush() async {
    if (!ready) return;
    final p = await bridge.call<String>('project');
    if (p != null) {
      store.current.project = p;
      store.changed(notify: false);
    }
  }

  Future<String> _html() async =>
      (await bridge.call<String>('html', [store.current.htmlOptions]))!;

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('OK'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _export() async {
    try {
      final where = await saveZip(
        '${store.current.slug}.zip',
        buildZip(await _html(), url: store.current.effectiveUrl),
      );
      if (mounted) _snack(where);
    } catch (e) {
      if (mounted) _snack('Export failed: $e');
    }
  }

  Future<void> _newSite() async {
    final lang = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('New site — template language'),
        children: [
          for (final e in langs.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, e.key),
              child: Text(e.value),
            ),
        ],
      ),
    );
    if (lang == null) return;
    await _flush();
    store.createSite(lang);
    setState(() => chatOpen = true);
    await _loadCurrent();
  }

  Future<void> _switch(String slug) async {
    await _flush();
    store.switchTo(slug);
    setState(() => chatOpen = !store.current.initialized);
    await _loadCurrent();
  }

  Future<void> _delete() async {
    if (!await _confirm(
      'Delete site',
      'Delete "${store.current.name}" from this device?',
    )) {
      return;
    }
    store.deleteCurrent();
    setState(() => chatOpen = !store.current.initialized);
    await _loadCurrent();
  }

  Future<void> _changeLang(String lang) async {
    if (lang == store.current.lang) return;
    if (!await _confirm(
      'Change template language',
      'Replace the page with the ${langs[lang]} starter template? Your current edits will be lost.',
    )) {
      return;
    }
    await bridge.call('reset', [lang]);
    store.current.lang = lang;
    await _flush();
    store.changed();
  }

  /// 予約を Google フォームで受け取る：案内ダイアログ → 読み取った質問で予約フォームを作り替える
  Future<List<SuggestedQuestion>> _suggestedQuestions() async {
    final services = <String>[];
    final extras = <String>[];
    try {
      final snap = await bridge.call<Map>('snapshot');
      for (final r in (snap?['services'] as List? ?? const [])) {
        if (r is List && r.isNotEmpty && '${r.first}'.trim().isNotEmpty) services.add('${r.first}'.trim());
      }
      for (final q in (snap?['formQuestions'] as List? ?? const [])) {
        final t = '$q'.replaceAll(RegExp(r'\s*(\(.*?\)|（.*?）)'), '').trim();
        if (t.isNotEmpty) extras.add(t);
      }
    } catch (_) {}
    return [
      SuggestedQuestion(tr('gf.q.name'), 'text', true),
      SuggestedQuestion(tr('gf.q.phone'), 'text', false),
      SuggestedQuestion(tr('gf.q.email'), 'text', true),
      if (services.length >= 2) SuggestedQuestion(tr('gf.q.menu'), 'radio', true, services.take(8).toList()),
      SuggestedQuestion(tr('gf.q.date'), 'date', true),
      SuggestedQuestion(tr('gf.q.time'), 'time', true),
      for (final e in extras.take(6)) SuggestedQuestion(e, 'text', false),
      SuggestedQuestion(tr('gf.q.notes'), 'paragraph', false),
    ];
  }

  Future<void> _googleForm() async {
    final suggested = await _suggestedQuestions();
    if (!mounted) return;
    final r = await showDialog<Object>(context: context, builder: (_) => GoogleFormDialog(currentUrl: store.current.googleForm, suggested: suggested, siteName: store.current.name));
    if (r == null || !ready) return;
    try {
      if (r == GoogleFormDialog.disconnectResult) {
        await bridge.call<Map>('runActions', [
          [
            {'action': 'clear_google_form'},
            if (store.current.calendarId.isNotEmpty) {'action': 'clear_calendar'},
          ]
        ]);
        store.current.googleForm = '';
        store.current.calendarId = '';
        store.changed();
        if (mounted) _snack(tr('gf.disconnected'));
        return;
      }
      final result = r as GoogleFormResult;
      final f = result.form;
      final res = await bridge.call<Map>('runActions', [
        [
          {'action': 'set_google_form', 'config': f.config},
          if (result.calendarId != null) {'action': 'set_calendar', 'calendarId': result.calendarId},
        ]
      ]);
      for (final row in (res?['results'] as List? ?? const [])) {
        if (row is Map && row['ok'] != true) throw Exception(row['message'] ?? 'failed');
      }
      if (result.calendarId != null) store.current.calendarId = result.calendarId!;
      store.current.googleForm = 'https://docs.google.com/forms/d/e/${RegExp(r'/e/([\w-]+)/').firstMatch(f.action)![1]}/viewform';
      await _flush();
      store.changed();
      if (mounted) _snack(tr('gf.connected', {'n': '${f.fields.length}', 'r': '${f.requiredCount}'}));
    } catch (e) {
      if (mounted) _snack(tr('chat.r.fail', {'reason': e.toString().replaceFirst('Exception: ', '')}));
    }
  }

  void _deploy() => showDialog<void>(context: context, barrierDismissible: false, builder: (_) => DeployDialog(store: store, getHtml: _html));

  /// 報價功能送來的結果：就緒後套用到價格列表
  Future<void> _applyPending() async {
    if (!ready) return;
    final actions = widget.link.takeActions();
    final wantLang = widget.link.takeLang();
    if (actions != null) {
      try {
        // 価目表の言語がいまのサイトと違うとき：新しいサイト（その言語のひな形）に載せるか、いまのサイトに載せるか選ぶ
        if (wantLang != null && langs.containsKey(wantLang) && wantLang != store.current.lang) {
          final choice = await showDialog<String>(
            context: context,
            builder: (c) => AlertDialog(
              content: Text(tr('sp.langAsk', {'cur': langs[store.current.lang]!, 'want': langs[wantLang]!})),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, 'cancel'), child: Text(tr('btn.cancel'))),
                TextButton(onPressed: () => Navigator.pop(c, 'current'), child: Text(tr('sp.langCurrent', {'cur': langs[store.current.lang]!}))),
                FilledButton(onPressed: () => Navigator.pop(c, 'new'), child: Text(tr('sp.langNew', {'want': langs[wantLang]!}))),
              ],
            ),
          );
          if (choice == null || choice == 'cancel') return;
          if (choice == 'new') {
            await _flush();
            store.createSite(wantLang);
            store.current.initialized = true; // ひな形のまま使う（チャットでの初期設定は行わない）
            store.changed();
            setState(() => chatOpen = false);
            await _loadCurrent();
          }
        }
        final r = await bridge.call<Map>('runActions', [actions]);
        final failed = [for (final x in (r?['results'] as List? ?? const [])) if (x is Map && x['ok'] != true) '${x['message']}'];
        if (mounted) _snack(failed.isEmpty ? tr('mkt.applied') : tr('chat.r.fail', {'reason': failed.first}));
      } catch (e) {
        if (mounted) _snack(tr('chat.r.fail', {'reason': e.toString().replaceFirst('Exception: ', '')}));
      }
      return;
    }
    final payload = widget.link.takePricing();
    if (payload == null) return;
    try {
      final n = await bridge.call<num>('applyPricing', [payload]);
      if (mounted) _snack('Applied ${n ?? 0} price rows to the site');
    } catch (e) {
      if (mounted) _snack('Could not apply the quote: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  /// 用本機 AI 依描述產生網站文字（會取代目前頁面內容）
  Future<void> _generate() async {
    final desc = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Generate site text with AI'),
        content: SizedBox(
          width: 520,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Describe the business. The local AI model writes the headline, services, prices and hours in ${langs[store.current.lang]}. This replaces the current page content.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: desc,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(hintText: 'e.g. A small nail salon in Taipei. Gel nails, manicure, nail art. Open 11:00–20:00, closed Mondays.'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Generate')),
        ],
      ),
    );
    final text = desc.text.trim();
    if (go != true || text.isEmpty || !mounted) return;
    final lang = store.current.lang;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Generating…'),
          content: ListenableBuilder(
            listenable: widget.app,
            builder: (_, __) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              LinearProgressIndicator(value: widget.app.progress > 0 && widget.app.progress < 1 ? widget.app.progress : null),
              const SizedBox(height: 10),
              Text(widget.app.progressText, style: const TextStyle(fontSize: 13)),
            ]),
          ),
        ),
      ),
    );
    String? error;
    try {
      final overrides = await widget.app.withModel(
        (ask) => generateSiteContent(
          ask: (system, user, schema) => ask(system, user, schema: schema),
          siteLang: Lang.fromCode(_aiLang(lang)) ?? Lang.en,
          description: text,
        ),
      );
      if (overrides == null) {
        error = 'The AI answer could not be used. Try again or choose a larger model.';
      } else {
        await bridge.call('applyContent', [lang, overrides]);
        await bridge.call('runActions', [industryFieldActions('${overrides['industry'] ?? 'other'}', lang)]);
        _markInitialized('${overrides['brand'] ?? ''}');
        await _flush();
      }
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _snack(error ?? 'Site text generated');
  }

  /// 完成初始化（聊天產生了頁面，或選擇直接用範本）。網站名稱還是預設值時改成店名。
  void _markInitialized(String? brand) {
    final s = store.current;
    s.initialized = true;
    if (s.name == 'My booking site' && brand != null && brand.trim().isNotEmpty) s.name = brand.trim();
    store.changed();
  }

  /// 網站語言代碼（en/zh/ja/pt/es）→ Pricing AI 的 Lang.code
  String _aiLang(String l) => l == 'zh' ? 'zh-TW' : l;

  Future<void> _settings() async {
    final s = store.current;
    final name = TextEditingController(text: s.name);
    final slug = TextEditingController(text: s.slug);
    final mailto = TextEditingController(text: s.mailto);
    final endpoint = TextEditingController(text: s.endpoint);
    final siteUrl = TextEditingController(text: s.siteUrl);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Site settings'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Site name (page title)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: slug,
                  decoration: const InputDecoration(
                    labelText: 'Site address (slug)',
                    helperText: '3–40 characters: a-z, 0-9, dashes',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mailto,
                  decoration: const InputDecoration(
                    labelText: 'Booking notification email',
                    helperText:
                        'Booking requests open the visitor\'s email app addressed to you.',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: siteUrl,
                  decoration: const InputDecoration(
                    labelText: 'Public web address (for search engines)',
                    helperText: 'e.g. https://www.example.com/ . Used for the canonical link, sitemap.xml and social previews. Leave empty to use your Firebase address after deploying.',
                    helperMaxLines: 3,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: endpoint,
                  decoration: const InputDecoration(
                    labelText: 'Booking form endpoint (optional)',
                    helperText:
                        'A form service URL (e.g. Formspree). When set, bookings are POSTed there as JSON instead of using email.',
                    helperMaxLines: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    s
      ..name = name.text.trim().isEmpty ? s.name : name.text.trim()
      ..mailto = mailto.text.trim()
      ..endpoint = endpoint.text.trim()
      ..siteUrl = siteUrl.text.trim();
    final newSlug = slug.text.trim().toLowerCase();
    if (newSlug != s.slug && !store.rename(newSlug)) {
      _snack('Invalid or already used address');
    }
    store.changed();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final site = store.current;
        return Scaffold(
          appBar: _topBar(site),
          body: Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: bridge.build(context)),
                    if (!ready)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Colors.white,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                  ],
                ),
              ),
              // 聊天面板：關起來時保留對話（maintainState），切換網站時換成新的對話
              Visibility(
                visible: chatOpen,
                maintainState: true,
                child: SizedBox(
                  width: 360,
                  child: SiteChatPanel(
                    key: ValueKey(site.slug),
                    app: widget.app,
                    bridge: bridge,
                    siteLang: site.lang,
                    ready: ready,
                    initialized: site.initialized,
                    onInitialized: _markInitialized,
                    onSkipInit: () => _markInitialized(null),
                    onSiteName: (n) {
                      store.current.name = n;
                      store.changed();
                    },
                    onBookingEmail: (e) {
                      store.current.mailto = e;
                      store.changed();
                    },
                    onGoogleForm: (u) {
                      store.current.googleForm = u;
                      store.changed();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _topBar(Site site) {
    Widget dropdown<T>({
      required T value,
      required List<DropdownMenuItem<T>> items,
      required ValueChanged<T?> onChanged,
      bool expanded = false,
    }) => Theme(
      data: Theme.of(context).copyWith(canvasColor: const Color(0xFF263C5C)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: expanded,
          value: value,
          iconEnabledColor: Colors.white,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
    // 視窗寬時工具列用「圖示 + 文字」，窄時只留圖示（文字放在提示裡），避免右邊按鈕太多而溢位
    final wide = MediaQuery.sizeOf(context).width >= 1280;
    Widget action(IconData icon, String label, VoidCallback? onPressed) => wide
        ? TextButton.icon(style: TextButton.styleFrom(foregroundColor: Colors.white), icon: Icon(icon), label: Text(label), onPressed: onPressed)
        : IconButton(tooltip: label, icon: Icon(icon), onPressed: onPressed);
    return AppBar(
      backgroundColor: const Color(0xFF263C5C),
      foregroundColor: Colors.white,
      titleSpacing: 12,
      // FittedBox：視窗很窄時整排縮小而不是溢位（工具列右邊按鈕很多）
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            SizedBox(
              width: 190,
              child: dropdown<String>(
                expanded: true,
                value: site.slug,
                items: [
                  for (final s in store.sites.values)
                    DropdownMenuItem(
                      value: s.slug,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => v == null ? null : _switch(v),
              ),
            ),
            IconButton(
              tooltip: 'New site',
              icon: const Icon(Icons.add),
              onPressed: ready ? _newSite : null,
            ),
            IconButton(
              tooltip: 'Delete this site',
              icon: const Icon(Icons.delete_outline),
              onPressed: ready ? _delete : null,
            ),
            const SizedBox(width: 8),
            dropdown<String>(
              value: site.lang,
              items: [
                for (final e in langs.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => v == null || !ready ? null : _changeLang(v),
            ),
          ],
        ),
      ),
      actions: [
        if (aiAvailable) ...[
          action(chatOpen ? Icons.chat_bubble : Icons.chat_bubble_outline, tr('chat.button'), () => setState(() => chatOpen = !chatOpen)),
          action(Icons.auto_awesome, tr('chat.aiText'), ready ? _generate : null),
        ] else
          action(Icons.download, tr('web.getApp'), openDesktopDownload),
        // 報價：有 AI 時是 AI 報價，網頁版是內建價目表（沒有 AI）
        action(Icons.request_quote_outlined, tr(aiAvailable ? 'chat.aiPricing' : 'chat.pricing'), widget.link.showPricing),
        IconButton(
          tooltip: tr('gf.button'),
          icon: Icon(site.googleForm.isEmpty ? Icons.fact_check_outlined : Icons.fact_check),
          onPressed: ready ? _googleForm : null,
        ),
        IconButton(
          tooltip: 'Site settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: _settings,
        ),
        action(Icons.archive_outlined, 'Export ZIP', ready ? _export : null),
        if (canDeploy)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: wide
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: const Color(0xFF111827)),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Deploy to Firebase'),
                    onPressed: ready ? _deploy : null,
                  )
                : IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: const Color(0xFF111827)),
                    tooltip: 'Deploy to Firebase',
                    icon: const Icon(Icons.cloud_upload_outlined),
                    onPressed: ready ? _deploy : null,
                  ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}
