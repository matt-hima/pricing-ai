import 'package:flutter/material.dart';

import '../app_state.dart';
import '../i18n/i18n.dart';
import '../llm.dart';
import 'brand_logo.dart';
import 'get_app.dart';
import 'form_panel.dart';
import 'intro_page.dart';
import 'middle_pane.dart';
import 'sidebar.dart';

class HomePage extends StatefulWidget {
  final AppState state;
  const HomePage({super.key, required this.state});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _mobileTab = 0;

  AppState get s => widget.state;

  void toast(String msg) {
    if (msg.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, width: 420));
  }

  Future<void> _estimate() async {
    final msg = await s.runEstimate();
    toast(msg);
    if (s.ai != null && mounted && MediaQuery.sizeOf(context).width < 860) setState(() => _mobileTab = 1);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        if (!s.ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (s.showIntro) return IntroPage(state: s);
        final title = s.q.myName.isEmpty ? tr('app.title') : tr('app.titleWith', {'name': s.q.myName});
        final form = FormPanel(state: s, onEstimate: _estimate, onToast: toast);
        final pane = MiddlePane(state: s, onToast: toast);
        final side = Sidebar(state: s, onEstimate: _estimate, onToast: toast);

        return Title(
          title: '${tr('app.title')} · ${tr('app.tagline')}',
          color: cs.primary,
          child: Scaffold(
            backgroundColor: cs.surfaceContainerLow,
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF263C5C),
              surfaceTintColor: Colors.transparent,
              shape: const Border(bottom: BorderSide(color: Color(0xFFE2E6EE))),
              titleSpacing: 16,
              title: Row(children: [
                BrandLogo(height: 36, onTap: s.openIntro),
                if (s.q.myName.isNotEmpty && MediaQuery.sizeOf(context).width >= 700) ...[
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text('· ${s.q.myName}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, color: Color(0xFF5B6577))),
                  ),
                ],
              ]),
              actions: [
                IconButton(
                  tooltip: tr('help.tooltip'),
                  color: const Color(0xFF263C5C),
                  onPressed: s.openIntro,
                  icon: const Icon(Icons.help_outline),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Chip(
                    avatar: Icon(aiAvailable && s.gpu.ok ? Icons.memory : Icons.computer, size: 16),
                    label: Text(!aiAvailable ? tr('web.noAi') : (!s.gpuChecked ? tr('gpu.checking') : tr(s.gpu.ok ? 'eng.gpuOk' : 'gpu.cpu'))),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            body: Column(children: [
              _banner(context),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  if (c.maxWidth >= 1280) {
                    // 中欄高度有界：PDF 預覽填滿、報價單在內部捲動
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 420, child: _scroll(form)),
                      Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(0, 16, 0, 16), child: pane)),
                      SizedBox(width: 290, child: _scroll(side)),
                    ]);
                  }
                  if (c.maxWidth >= 860) {
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 400, child: _scroll(form)),
                      Expanded(child: _scroll(Column(children: [side, const SizedBox(height: 16), pane]))),
                    ]);
                  }
                  return IndexedStack(index: _mobileTab, children: [
                    _scroll(form),
                    _scroll(pane),
                    _scroll(side),
                  ]);
                }),
              ),
            ]),
            bottomNavigationBar: MediaQuery.sizeOf(context).width < 860
                ? NavigationBar(
                    selectedIndex: _mobileTab,
                    onDestinationSelected: (i) => setState(() => _mobileTab = i),
                    destinations: [
                      NavigationDestination(icon: const Icon(Icons.edit_note), label: tr('nav.form')),
                      NavigationDestination(icon: const Icon(Icons.receipt_long), label: tr('nav.quote')),
                      NavigationDestination(icon: const Icon(Icons.auto_awesome), label: tr('nav.ai')),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  /// 常駐警語：任何畫面都看得到
  Widget _banner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.amber.withValues(alpha: .18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tr(aiAvailable ? 'banner.ai' : 'web.banner'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface)),
          ),
          if (!aiAvailable) TextButton(onPressed: openDesktopDownload, child: Text(tr('web.getApp'))),
        ]),
      ),
    );
  }

  Widget _scroll(Widget child) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: child,
      );
}
