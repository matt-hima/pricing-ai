import 'package:flutter/material.dart';

import '../app_state.dart';
import '../i18n/i18n.dart';
import '../site/site_link.dart';
import '../site/site_store.dart';
import '../site/ui/editor_page.dart';
import '../site/ui/popup_observer.dart';
import 'case_analysis_page.dart';
import 'home_page.dart';
import 'service_pricing_page.dart';
import 'settings_page.dart';

/// 兩個功能：報價（Pricing AI）與網站建置器。兩邊共用同一個本機 AI 模型與引擎。
class AppShell extends StatefulWidget {
  final AppState state;
  final Store siteStore;
  final PopupObserver popups;
  const AppShell({super.key, required this.state, required this.siteStore, required this.popups});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final link = SiteLink();
  int tab = 0;
  bool siteOpened = false; // 第一次切過去才建立編輯器，之後保持存活（避免重新載入）

  @override
  void initState() {
    super.initState();
    // 0 = サービス価格の設計（既定）、1 = サイト建置、2 = ソフトウェア開発の見積もり、3 = 案件分析（政府採購決標）
    link.showSite = () => _go(1);
    link.showPricing = () => _go(0);
    widget.state.applyToSite = link.applyPricing;
    widget.state.applyServicesToSite = link.applyServices;
  }

  void _go(int t) => setState(() {
        tab = t;
        if (t == 1) siteOpened = true;
      });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final s = widget.state;
        final home = HomePage(state: s);
        // 載入中不顯示功能切換；介紹頁（報價的免責聲明）也要能直接切到網站建置器，不必先同意報價聲明
        if (!s.ready) return home;
        return Column(children: [
          Material(
            color: const Color(0xFF263C5C),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(children: [
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      foregroundColor: Colors.white,
                      selectedForegroundColor: const Color(0xFF263C5C),
                      selectedBackgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                    // 視窗窄時只顯示圖示（四個分頁的文字會擠成兩行），名稱放在提示文字
                    segments: [
                      for (final (i, icon, key) in const [(0, Icons.sell_outlined, 'shell.servicePricing'), (1, Icons.web_outlined, 'shell.site'), (2, Icons.request_quote_outlined, 'shell.pricing'), (3, Icons.query_stats, 'shell.cases')])
                        ButtonSegment(value: i, icon: Icon(icon, size: 18), tooltip: tr(key), label: MediaQuery.sizeOf(context).width < 720 ? null : Text(tr(key))),
                    ],
                    selected: {tab},
                    onSelectionChanged: (v) => _go(v.first),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: tr('set.open'),
                    color: Colors.white,
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsPage(state: s))),
                  ),
                ]),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(index: tab, children: [
              ServicePricingPage(state: s),
              if (siteOpened)
                EditorPage(store: widget.siteStore, popups: widget.popups, app: s, link: link)
              else
                const SizedBox.shrink(),
              home,
              CaseAnalysisPage(state: s),
            ]),
          ),
        ]);
      },
    );
  }
}
