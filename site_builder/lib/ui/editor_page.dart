import 'dart:async';

import 'package:flutter/material.dart';

import '../bridge/editor_bridge.dart';
import '../model.dart';
import '../platform/deploy.dart';
import '../platform/save_file.dart';
import '../platform/zip_export.dart';
import '../store.dart';
import 'deploy_dialog.dart';
import 'popup_observer.dart';
import 'pricing_dialog.dart';

class EditorPage extends StatefulWidget {
  final Store store;
  final PopupObserver popups;
  const EditorPage({super.key, required this.store, required this.popups});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  Store get store => widget.store;
  final bridge = EditorBridge();
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool ready = false;
  Timer? _hello;
  DateTime? _loadStarted;

  void _onPopups() => bridge.setInteractive(widget.popups.open.value == 0);

  @override
  void initState() {
    super.initState();
    widget.popups.open.addListener(_onPopups);
    _sub = bridge.events.listen((e) async {
      switch (e['type']) {
        case 'ready':
          _loadStarted = DateTime.now();
          try {
            await _loadCurrent();
            if (mounted) setState(() => ready = true);
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
        buildZip(await _html()),
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
    await _loadCurrent();
  }

  Future<void> _switch(String slug) async {
    await _flush();
    store.switchTo(slug);
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

  Future<void> _aiPricing() async {
    final url = '$pricingAiUrl/?apply=1&lang=${store.current.lang}';
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => PricingAiDialog(url: url));
    if (result == null) return;
    try {
      final n = await bridge.call<num>('applyPricing', [result]);
      if (mounted) _snack('Applied ${n ?? 0} price rows to the site');
    } catch (e) {
      if (mounted) _snack('Could not apply the quote: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _settings() async {
    final s = store.current;
    final name = TextEditingController(text: s.name);
    final slug = TextEditingController(text: s.slug);
    final mailto = TextEditingController(text: s.mailto);
    final endpoint = TextEditingController(text: s.endpoint);
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
      ..endpoint = endpoint.text.trim();
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
          body: Stack(
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
    return AppBar(
      backgroundColor: const Color(0xFF263C5C),
      foregroundColor: Colors.white,
      titleSpacing: 12,
      title: Row(
        children: [
          const Text(
            'Site Builder',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
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
      actions: [
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('AI pricing'),
          onPressed: ready ? _aiPricing : null,
        ),
        IconButton(
          tooltip: 'Site settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: _settings,
        ),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          icon: const Icon(Icons.archive_outlined),
          label: const Text('Export ZIP'),
          onPressed: ready ? _export : null,
        ),
        if (canDeploy)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF111827),
              ),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Deploy to Firebase'),
              onPressed: ready
                  ? () => showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          DeployDialog(store: store, getHtml: _html),
                    )
                  : null,
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}
